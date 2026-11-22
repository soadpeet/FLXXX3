#include "controllers/midi/flx10jogscreen.h"

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <mutex>
#include <thread>
#include <vector>

#include "mixer/playerinfo.h"
#include "track/beats.h"
#include "track/track.h"
#include "waveform/waveform.h"

#ifdef __ANDROID__
#include "soundio/androidusbaudio.h"
#elif defined(__HID__)
#include <hidapi.h>

#include <QtDebug>
#endif

namespace flxxx3::jogscreen {

namespace {

constexpr int kEntriesPerSecond = 150;
constexpr int kEntriesPerReport = 19;
constexpr unsigned char kDeckByte[4] = {0x10, 0x20, 0x30, 0x40};

struct DeckWave {
    // Track and analysis state the entries were made from.
    const void* pTrack = nullptr;
    int completion = -1;
    std::vector<uint16_t> entries;
    bool uploading = false;
};

std::mutex s_mutex;
std::array<DeckWave, 4> s_decks;

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

std::array<unsigned char, 128> waveReport(int deck, const std::vector<uint16_t>& entries, int at) {
    std::array<unsigned char, 128> p{};
    p[0] = kDeckByte[deck];
    p[1] = 0x36;
    p[6] = 0x13;
    p[10] = static_cast<unsigned char>(at & 0xFF);
    p[11] = static_cast<unsigned char>((at >> 8) & 0xFF);
    p[12] = static_cast<unsigned char>((at >> 16) & 0xFF);
    p[13] = static_cast<unsigned char>((at >> 24) & 0xFF);
    const int end = std::min(at + kEntriesPerReport, static_cast<int>(entries.size()));
    int offset = 14;
    for (int i = at; i < end; ++i) {
        p[offset++] = static_cast<unsigned char>(entries[i] & 0xFF);
        p[offset++] = static_cast<unsigned char>(entries[i] >> 8);
    }
    return p;
}

// Beat grid of the track as xx 2f reports: after a start record (80 02 01 00) one
// record per beat: its place in the bar (03 04 00 02 for beats 1..4, as Serato sends
// them) and its time in samples at 22050 Hz (24 bit LE); 30 records a report after
// the header <deck> 2f <segment 1..> 00 15 00. The first beat of the grid counts as
// beat 1 of a bar.
std::vector<std::array<unsigned char, 128>> beatGridReports(int deck, const Track& track) {
    std::vector<std::array<unsigned char, 128>> reports;
    const mixxx::BeatsPointer pBeats = track.getBeats();
    const double sampleRate = track.getSampleRate().toDouble();
    if (!pBeats || sampleRate <= 0) {
        return reports;
    }
    static constexpr unsigned char kBeatType[4] = {0x03, 0x04, 0x00, 0x02};
    std::vector<std::array<unsigned char, 4>> records = {{0x80, 0x02, 0x01, 0x00}};
    const double endFrame = track.getDuration() * sampleRate;
    int index = 0;
    for (auto it = pBeats->iteratorFrom(mixxx::audio::kStartFramePos);
            it != pBeats->cend() && it->value() <= endFrame && records.size() < 20000;
            ++it, ++index) {
        const auto samples = static_cast<uint32_t>(std::lround(it->value() / sampleRate * 22050.0)) &
                0xFFFFFF;
        records.push_back({kBeatType[index & 3],
                static_cast<unsigned char>(samples & 0xFF),
                static_cast<unsigned char>((samples >> 8) & 0xFF),
                static_cast<unsigned char>((samples >> 16) & 0xFF)});
    }
    constexpr size_t kPerReport = 30;
    for (size_t first = 0, segment = 1; first < records.size(); first += kPerReport, ++segment) {
        std::array<unsigned char, 128> p{};
        p[0] = kDeckByte[deck];
        p[1] = 0x2f;
        p[2] = static_cast<unsigned char>(segment & 0xFF);
        p[4] = 0x15;
        size_t offset = 6;
        for (size_t i = first; i < std::min(records.size(), first + kPerReport); ++i) {
            for (unsigned char byte : records[i]) {
                p[offset++] = byte;
            }
        }
        reports.push_back(p);
    }
    return reports;
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

// PWV5 entries of the track's waveform (empty while it is not analysed).
std::vector<uint16_t> pwv5Of(const Waveform& waveform, double durationSeconds) {
    std::vector<uint16_t> out;
    const int frames = waveform.getDataSize() / 2; // left and right per visual frame
    if (frames <= 0 || durationSeconds <= 0 ||
            waveform.getCompletion() < waveform.getDataSize()) {
        return out;
    }
    const int count = static_cast<int>(durationSeconds * kEntriesPerSecond);
    const double framesPerEntry = static_cast<double>(frames) / std::max(1, count);
    out.resize(static_cast<size_t>(count));
    for (int o = 0; o < count; ++o) {
        const int start = static_cast<int>(o * framesPerEntry);
        const int end = std::min(frames, std::max(start + 1, static_cast<int>((o + 1) * framesPerEntry)));
        int all = 0;
        int low = 0;
        int mid = 0;
        int high = 0;
        for (int f = start; f < end; ++f) {
            for (int side = 0; side < 2; ++side) {
                const int i = f * 2 + side;
                all = std::max(all, static_cast<int>(waveform.getAll(i)));
                low = std::max(low, static_cast<int>(waveform.getLow(i)));
                mid = std::max(mid, static_cast<int>(waveform.getMid(i)));
                high = std::max(high, static_cast<int>(waveform.getHigh(i)));
            }
        }
        const int h = std::min(31, all * 31 / 255);
        const int r = std::min(7, low * 7 / 255);
        const int g = std::min(7, mid * 7 / 255);
        const int b = std::min(7, high * 7 / 255);
        out[static_cast<size_t>(o)] = static_cast<uint16_t>((r << 13) | (g << 10) | (b << 7) | (h << 2));
    }
    return out;
}

void uploadWaveform(int deck, bool withBeatGrid) {
    const TrackPointer pTrack = PlayerInfo::instance().getTrackInfo(
            QStringLiteral("[Channel%1]").arg(deck + 1));
    if (!pTrack) {
        return;
    }
    const ConstWaveformPointer pWaveform = pTrack->getWaveform();
    if (!pWaveform) {
        return;
    }
    {
        std::lock_guard<std::mutex> lock(s_mutex);
        DeckWave& state = s_decks[deck];
        if (state.uploading ||
                (state.pTrack == pTrack.get() &&
                        state.completion == pWaveform->getCompletion())) {
            return;
        }
    }
    std::vector<uint16_t> entries = pwv5Of(*pWaveform, pTrack->getDuration());
    if (entries.empty()) {
        return; // not analysed yet: the script asks again
    }
    std::vector<std::array<unsigned char, 128>> grid;
    if (withBeatGrid) {
        grid = beatGridReports(deck, *pTrack);
    }
    {
        std::lock_guard<std::mutex> lock(s_mutex);
        DeckWave& state = s_decks[deck];
        state.pTrack = pTrack.get();
        state.completion = pWaveform->getCompletion();
        state.entries = entries;
        state.uploading = true;
    }
    // The whole track takes a few seconds (one report per ms): not in the
    // controller thread.
    std::thread([deck, entries = std::move(entries), grid = std::move(grid)]() {
        for (int at = 0; at < static_cast<int>(entries.size()); at += kEntriesPerReport) {
            sendWaiting(waveReport(deck, entries, at));
        }
        for (const auto& report : grid) {
            sendWaiting(report);
        }
        std::lock_guard<std::mutex> lock(s_mutex);
        s_decks[deck].uploading = false;
    }).detach();
}

void sendPlayhead(int deck, int entry) {
    std::array<unsigned char, 128> report;
    {
        std::lock_guard<std::mutex> lock(s_mutex);
        const DeckWave& state = s_decks[deck];
        if (state.uploading || state.entries.empty()) {
            return;
        }
        const int last = std::max(0, static_cast<int>(state.entries.size()) - kEntriesPerReport);
        report = waveReport(deck, state.entries, std::clamp(entry, 0, last));
    }
    sendReport(report.data(), static_cast<int>(report.size()));
}

} // namespace

bool handleRequest(const QByteArray& data) {
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
        return kind == 0x57 || kind == 0x50;
    }
    if (kind == 0x57) {
        // F0 7D 46 57 <deck> [<beat grid 0/1>] F7
        uploadWaveform(deck, data.size() < 7 || data[5] != 0);
        return true;
    }
    if (kind == 0x50 && data.size() >= 10) {
        int entry = 0;
        for (int i = 0; i < 4; ++i) {
            entry |= (static_cast<uint8_t>(data[5 + i]) & 0x7F) << (7 * i);
        }
        sendPlayhead(deck, entry);
        return true;
    }
    return false;
}

} // namespace flxxx3::jogscreen
