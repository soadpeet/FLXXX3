#include "controllers/midi/flx10jogscreen.h"

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

#include "control/controlproxy.h"
#include "mixer/playerinfo.h"
#include "track/beats.h"
#include "track/track.h"
#include "waveform/waveform.h"

#ifdef __ANDROID__
#include "soundio/androidusbaudio.h"
#elif defined(__HID__)
#include <hidapi.h>
#endif

#include <QtDebug>

namespace flxxx3::jogscreen {

namespace {

constexpr int kEntriesPerSecond = 150;
constexpr unsigned char kDeckByte[4] = {0x10, 0x20, 0x30, 0x40};

std::mutex s_mutex;

#if !defined(__ANDROID__) && defined(__HID__)
// The screens' HID interface, opened on the first report (again after a failure, at
// most every 2 s: the controller may be plugged in later).
std::mutex s_hidMutex;
hid_device* s_pHid = nullptr;
std::chrono::steady_clock::time_point s_lastOpenTry;

hid_device* openScreens() {
    const auto now = std::chrono::steady_clock::now();
    if (now - s_lastOpenTry < std::chrono::seconds(2)) {
        return nullptr;
    }
    s_lastOpenTry = now;
    hid_device* pDevice = nullptr;
    hid_device_info* pList = hid_enumerate(0x2B73, 0x0041);
    for (hid_device_info* pInfo = pList; pInfo; pInfo = pInfo->next) {
        if (pInfo->interface_number == 5) {
            pDevice = hid_open_path(pInfo->path);
            break;
        }
    }
    hid_free_enumeration(pList);
    qInfo() << "FLXXX3: DDJ-FLX10 jog screens" << (pDevice ? "opened" : "not found");
    return pDevice;
}
#endif

#if !defined(__ANDROID__) && defined(__HID__)
// FLXXX3: jog position from the HID input reports. Like rekordbox, the DDJ-FLX10 sends a
// 64 byte report about 1000 times a second (endpoint 0x84 of the screens' interface) with the
// absolute position of the jog wheels as 16 bit counters: bytes 5-6 (left wheel), 7-8 (right
// wheel; the right one is a guess, a USB capture only shows the left one moving). Unlike its
// MIDI messages, which only come above a minimum speed, the position also follows the slowest
// movement. The reader writes the counters to [AndroidDJ] hid_jog_left / hid_jog_right; the
// mapping script uses the changes (loop adjust).
std::once_flag s_readerOnce;

void readerLoop() {
    hid_device* pHid = nullptr;
    std::unique_ptr<ControlProxy> pLeft;
    std::unique_ptr<ControlProxy> pRight;
    int lastLeft = -1;
    int lastRight = -1;
    int logged = 0;
    int loggedRight = 0;
    while (true) {
        if (!pHid) {
            std::this_thread::sleep_for(std::chrono::seconds(2));
            hid_device_info* pList = hid_enumerate(0x2B73, 0x0041);
            for (hid_device_info* pInfo = pList; pInfo; pInfo = pInfo->next) {
                if (pInfo->interface_number == 5) {
                    pHid = hid_open_path(pInfo->path);
                    break;
                }
            }
            hid_free_enumeration(pList);
            if (!pHid) {
                continue;
            }
            qInfo() << "FLXXX3: DDJ-FLX10 jog position reader started";
        }
        if (!pLeft || !pLeft->valid() || !pRight || !pRight->valid()) {
            pLeft = std::make_unique<ControlProxy>(
                    QStringLiteral("[AndroidDJ]"), QStringLiteral("hid_jog_left"));
            pRight = std::make_unique<ControlProxy>(
                    QStringLiteral("[AndroidDJ]"), QStringLiteral("hid_jog_right"));
        }
        unsigned char buffer[65] = {0};
        const int count = hid_read_timeout(pHid, buffer, sizeof(buffer), 100);
        if (count < 0) {
            hid_close(pHid);
            pHid = nullptr;
            lastLeft = lastRight = -1;
            continue;
        }
        if (count < 9 || !pLeft->valid() || !pRight->valid()) {
            continue;
        }
        const int left = buffer[5] | (buffer[6] << 8);
        const int right = buffer[7] | (buffer[8] << 8);
        if (left != lastLeft) {
            if (lastLeft >= 0 && logged < 12) {
                qInfo() << "FLXXX3 jog HID left" << left << "right" << right;
                ++logged;
            }
            lastLeft = left;
            pLeft->set(left);
        }
        if (right != lastRight) {
            if (lastRight >= 0 && loggedRight < 12) {
                qInfo() << "FLXXX3 jog HID RIGHT left" << left << "right" << right;
                ++loggedRight;
            }
            lastRight = right;
            pRight->set(right);
        }
    }
}

void startReader() {
    std::call_once(s_readerOnce, [] {
        std::thread(readerLoop).detach();
    });
}
#endif

// Sends one report to the jog screens; false when it cannot (now).
bool sendReport(const unsigned char* pData, int length) {
#ifdef __ANDROID__
    return AndroidUsbAudio::sendScreenReport(pData, length);
#elif defined(__HID__)
    std::lock_guard<std::mutex> lock(s_hidMutex);
    if (!s_pHid) {
        s_pHid = openScreens();
        if (!s_pHid) {
            return false;
        }
    }
    // Report ID 0 first (the device has no numbered reports).
    unsigned char buffer[129] = {0};
    const int size = std::min(length, 128);
    std::copy(pData, pData + size, buffer + 1);
    if (hid_write(s_pHid, buffer, static_cast<size_t>(size) + 1) < 0) {
        hid_close(s_pHid);
        s_pHid = nullptr;
        return false;
    }
    return true;
#else
    Q_UNUSED(pData);
    Q_UNUSED(length);
    return false;
#endif
}

// Sends a report; waits while the driver has too many in flight.
void sendWaiting(const std::array<unsigned char, 128>& report) {
    for (int attempt = 0; attempt < 200; ++attempt) {
        if (sendReport(report.data(), static_cast<int>(report.size()))) {
            return;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
}

// ---- rekordbox mode ------------------------------------------------------------
// The reports rekordbox sends for a loaded track (from a USB capture, see
// docs/flx10-jog-screens.md): xx 37 overview, xx 2F beat grid, xx 38 detail waveform.
// Times are in real time at the deck's tempo (rate), as rekordbox does.

struct RekordboxDeck {
    const void* pTrack = nullptr;
    int completion = -1;
    int rate10000 = 0;
    int parts = 0;
    bool uploading = false;
};
std::array<RekordboxDeck, 4> s_rbDecks;

using Report = std::array<unsigned char, 128>;

// Reports of a byte stream, 122 bytes each after a 6 byte header.
template<typename Header>
std::vector<Report> streamReports(const std::vector<unsigned char>& stream, Header header) {
    constexpr size_t kPayload = 122;
    const size_t count = std::max<size_t>(1, (stream.size() + kPayload - 1) / kPayload);
    std::vector<Report> reports;
    for (size_t i = 0; i < count; ++i) {
        Report p{};
        header(p, i, count);
        for (size_t k = 0; k < kPayload && i * kPayload + k < stream.size(); ++k) {
            p[6 + k] = stream[i * kPayload + k];
        }
        reports.push_back(p);
    }
    return reports;
}

// Low / mid / high (0..127) of the waveform over [from, to) of its visual frames.
void bands(const Waveform& waveform, int from, int to, unsigned char* pOut) {
    int low = 0;
    int mid = 0;
    int high = 0;
    for (int f = from; f < to; ++f) {
        for (int side = 0; side < 2; ++side) {
            const int i = f * 2 + side;
            low = std::max(low, static_cast<int>(waveform.getLow(i)));
            mid = std::max(mid, static_cast<int>(waveform.getMid(i)));
            high = std::max(high, static_cast<int>(waveform.getHigh(i)));
        }
    }
    pOut[0] = static_cast<unsigned char>(low >> 1);
    pOut[1] = static_cast<unsigned char>(mid >> 1);
    pOut[2] = static_cast<unsigned char>(high >> 1);
}

std::vector<Report> rekordboxReports(
        int deck, const Track& track, const Waveform& waveform, double rate, int parts) {
    std::vector<Report> out;
    const unsigned char db = kDeckByte[deck];
    const int frames = waveform.getDataSize() / 2;
    const double duration = track.getDuration();
    if (frames <= 0 || duration <= 0 || rate <= 0) {
        return out;
    }
    const double wallSeconds = duration / rate;

    // xx 37 overview: 0x80, then 1219 entries over the whole track (30 reports).
    if (parts & 1) {
        constexpr int kOverview = 1219;
        std::vector<unsigned char> stream(1 + kOverview * 3, 0);
        stream[0] = 0x80;
        for (int o = 0; o < kOverview; ++o) {
            const int from = static_cast<int>(static_cast<double>(o) * frames / kOverview);
            const int to = std::max(from + 1, static_cast<int>(static_cast<double>(o + 1) * frames / kOverview));
            bands(waveform, from, std::min(to, frames), &stream[1 + o * 3]);
        }
        stream.resize(30 * 122, 0);
        auto reports = streamReports(stream, [db](Report& p, size_t i, size_t) {
            p[0] = db;
            p[1] = 0x37;
            p[2] = static_cast<unsigned char>(i + 1);
            p[4] = 0x1E;
        });
        out.insert(out.end(), reports.begin(), reports.end());
    }

    // xx 2F beat grid: count (LE16), then per beat its place in the bar (1..4) and its time
    // in ms (LE24).
    const mixxx::BeatsPointer pBeats = track.getBeats();
    const double sampleRate = track.getSampleRate().toDouble();
    if ((parts & 2) && pBeats && sampleRate > 0) {
        std::vector<unsigned char> stream = {0, 0};
        int count = 0;
        const double endFrame = duration * sampleRate;
        for (auto it = pBeats->iteratorFrom(mixxx::audio::kStartFramePos);
                it != pBeats->cend() && it->value() <= endFrame && count < 0xFFFF;
                ++it, ++count) {
            const auto ms = static_cast<uint32_t>(
                    std::lround(it->value() / sampleRate * 1000.0 / rate));
            stream.push_back(static_cast<unsigned char>(count % 4 + 1));
            stream.push_back(static_cast<unsigned char>(ms & 0xFF));
            stream.push_back(static_cast<unsigned char>((ms >> 8) & 0xFF));
            stream.push_back(static_cast<unsigned char>((ms >> 16) & 0xFF));
        }
        stream[0] = static_cast<unsigned char>(count & 0xFF);
        stream[1] = static_cast<unsigned char>(count >> 8);
        auto reports = streamReports(stream, [db](Report& p, size_t i, size_t total) {
            p[0] = db;
            p[1] = 0x2F;
            p[2] = static_cast<unsigned char>(i + 1);
            p[4] = static_cast<unsigned char>(total);
        });
        out.insert(out.end(), reports.begin(), reports.end());
    }

    // xx 38 detail: count (LE16) and 2 zero bytes, then 150 entries per second (real time).
    if (parts & 4) {
        const int count = std::min(0xFFFF, static_cast<int>(wallSeconds * kEntriesPerSecond));
        std::vector<unsigned char> stream(4 + static_cast<size_t>(count) * 3, 0);
        stream[0] = static_cast<unsigned char>(count & 0xFF);
        stream[1] = static_cast<unsigned char>(count >> 8);
        const double framesPerEntry = static_cast<double>(frames) / std::max(1, count);
        for (int o = 0; o < count; ++o) {
            const int from = static_cast<int>(o * framesPerEntry);
            const int to = std::max(from + 1, static_cast<int>((o + 1) * framesPerEntry));
            bands(waveform, std::min(from, frames - 1), std::min(to, frames), &stream[4 + o * 3]);
        }
        auto reports = streamReports(stream, [db](Report& p, size_t i, size_t total) {
            p[0] = db;
            p[1] = 0x38;
            p[2] = static_cast<unsigned char>((i + 1) & 0xFF);
            p[3] = static_cast<unsigned char>((i + 1) >> 8);
            p[4] = static_cast<unsigned char>(total & 0xFF);
            p[5] = static_cast<unsigned char>(total >> 8);
        });
        out.insert(out.end(), reports.begin(), reports.end());
    }
    return out;
}

void uploadRekordbox(int deck, int rate10000, int parts) {
    const TrackPointer pTrack = PlayerInfo::instance().getTrackInfo(
            QStringLiteral("[Channel%1]").arg(deck + 1));
    if (!pTrack || rate10000 <= 0) {
        return;
    }
    const ConstWaveformPointer pWaveform = pTrack->getWaveform();
    if (!pWaveform || pWaveform->getCompletion() < pWaveform->getDataSize()) {
        return; // not analysed yet: the script asks again
    }
    {
        std::lock_guard<std::mutex> lock(s_mutex);
        RekordboxDeck& state = s_rbDecks[deck];
        if (state.uploading ||
                (state.pTrack == pTrack.get() && state.completion == pWaveform->getCompletion() &&
                        state.rate10000 == rate10000 && state.parts == parts)) {
            return;
        }
        state.pTrack = pTrack.get();
        state.completion = pWaveform->getCompletion();
        state.rate10000 = rate10000;
        state.parts = parts;
        state.uploading = true;
    }
    std::vector<Report> reports = rekordboxReports(deck, *pTrack, *pWaveform, rate10000 / 10000.0, parts);
    qInfo() << "FLXXX3: DDJ-FLX10 jog screen waveform of deck" << deck + 1 << ":"
            << reports.size() << "reports";
    std::thread([deck, reports = std::move(reports)]() {
        for (const auto& report : reports) {
            sendWaiting(report);
        }
        std::lock_guard<std::mutex> lock(s_mutex);
        s_rbDecks[deck].uploading = false;
    }).detach();
}

} // namespace

bool handleRequest(const QByteArray& data) {
#if !defined(__ANDROID__) && defined(__HID__)
    startReader();
#endif
    if (data.size() < 6 || static_cast<uint8_t>(data[1]) != 0x7D ||
            static_cast<uint8_t>(data[2]) != 0x46) {
        return false;
    }
    const uint8_t kind = static_cast<uint8_t>(data[3]);
    if (kind == 0x48) {
        return sendReport(reinterpret_cast<const unsigned char*>(data.constData()) + 4,
                       static_cast<int>(data.size()) - 5) ||
                true; // never to the MIDI port
    }
    const int deck = static_cast<uint8_t>(data[4]) - 1;
    if (deck < 0 || deck > 3) {
        return kind == 0x52;
    }
    if (kind == 0x52 && data.size() >= 9) {
        // F0 7D 46 52 <deck> <rate x 10000, 3 x 7 bit> [<parts>] F7: rekordbox mode upload
        // (parts: 1 overview, 2 beat grid, 4 detail; default all)
        int rate10000 = 0;
        for (int i = 0; i < 3; ++i) {
            rate10000 |= (static_cast<uint8_t>(data[5 + i]) & 0x7F) << (7 * i);
        }
        const int parts = data.size() >= 10 ? static_cast<uint8_t>(data[8]) & 0x07 : 7;
        uploadRekordbox(deck, rate10000, parts);
        return true;
    }
    return false;
}

} // namespace flxxx3::jogscreen
