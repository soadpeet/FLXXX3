// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include "util/androidcrashlog.h"

#include <dlfcn.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/system_properties.h>
#include <unistd.h>
#include <unwind.h>

#include <QDateTime>
#include <QDir>
#include <QStandardPaths>
#include <QtDebug>
#include <cstdint>
#include <cstring>

namespace mixxx {
namespace androidcrashlog {

namespace {

int s_crashFd = -1;
constexpr int kSignals[] = {SIGSEGV, SIGABRT, SIGBUS, SIGILL, SIGFPE};
struct sigaction s_oldActions[std::size(kSignals)];
char s_altStack[64 * 1024];

// Only async-signal-safe calls below (write, no allocation).
void writeText(const char* text) {
    if (s_crashFd >= 0) {
        [[maybe_unused]] const ssize_t n = write(s_crashFd, text, strlen(text));
    }
}

void writeHex(uintptr_t value) {
    char buffer[2 + 2 * sizeof(uintptr_t) + 1];
    buffer[0] = '0';
    buffer[1] = 'x';
    int pos = 2;
    bool started = false;
    for (int shift = static_cast<int>(sizeof(uintptr_t) * 8) - 4; shift >= 0; shift -= 4) {
        const int digit = static_cast<int>((value >> shift) & 0xF);
        if (digit != 0 || started || shift == 0) {
            started = true;
            buffer[pos++] = "0123456789abcdef"[digit];
        }
    }
    buffer[pos] = '\0';
    writeText(buffer);
}

void writeDecimal(int value) {
    char buffer[16];
    int pos = 15;
    buffer[pos] = '\0';
    bool negative = value < 0;
    unsigned int v = negative ? static_cast<unsigned int>(-value) : static_cast<unsigned int>(value);
    do {
        buffer[--pos] = static_cast<char>('0' + v % 10);
        v /= 10;
    } while (v != 0 && pos > 1);
    if (negative) {
        buffer[--pos] = '-';
    }
    writeText(buffer + pos);
}

struct BacktraceState {
    uintptr_t* frames;
    int count;
    int max;
};

_Unwind_Reason_Code unwindCallback(struct _Unwind_Context* context, void* arg) {
    auto* state = static_cast<BacktraceState*>(arg);
    const uintptr_t pc = _Unwind_GetIP(context);
    if (pc != 0) {
        if (state->count >= state->max) {
            return _URC_END_OF_STACK;
        }
        state->frames[state->count++] = pc;
    }
    return _URC_NO_REASON;
}

void crashHandler(int signal, siginfo_t* info, void* /*context*/) {
    writeText("\n=== FLXXX3 crash: signal ");
    writeDecimal(signal);
    writeText(" code ");
    writeDecimal(info ? info->si_code : 0);
    writeText(" fault address ");
    writeHex(info ? reinterpret_cast<uintptr_t>(info->si_addr) : 0);
    writeText(" thread ");
    writeDecimal(gettid());
    writeText("\n");

    uintptr_t frames[64];
    BacktraceState state{frames, 0, 64};
    _Unwind_Backtrace(unwindCallback, &state);
    for (int i = 0; i < state.count; ++i) {
        writeText("#");
        writeDecimal(i);
        writeText(" pc ");
        Dl_info dlInfo;
        if (dladdr(reinterpret_cast<void*>(frames[i]), &dlInfo) != 0 && dlInfo.dli_fname) {
            // Offset in the library: llvm-symbolizer --obj=<library> <offset>
            writeHex(frames[i] - reinterpret_cast<uintptr_t>(dlInfo.dli_fbase));
            writeText(" ");
            const char* slash = strrchr(dlInfo.dli_fname, '/');
            writeText(slash ? slash + 1 : dlInfo.dli_fname);
            if (dlInfo.dli_sname) {
                writeText(" (");
                writeText(dlInfo.dli_sname);
                writeText(")");
            }
        } else {
            writeHex(frames[i]);
        }
        writeText("\n");
    }
    writeText("=== end of crash report\n");
    if (s_crashFd >= 0) {
        fsync(s_crashFd);
    }

    // Let Android handle the crash as before (tombstone, "app stopped" dialog).
    for (size_t i = 0; i < std::size(kSignals); ++i) {
        if (kSignals[i] == signal) {
            sigaction(signal, &s_oldActions[i], nullptr);
            break;
        }
    }
    raise(signal);
}

QString property(const char* name) {
    char value[PROP_VALUE_MAX] = {0};
    __system_property_get(name, value);
    return QString::fromUtf8(value);
}

} // namespace

QString logFolder() {
    // Qt: getExternalFilesDir(DIRECTORY_DOCUMENTS), i.e.
    // /storage/emulated/0/Android/data/<package>/files/Documents.
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (folder.isEmpty() || !QDir().mkpath(folder)) {
        return QString();
    }
    return folder;
}

void install(const QString& folder) {
    qWarning().noquote() << "FLXXX3 start" << QDateTime::currentDateTime().toString(Qt::ISODate)
                         << "| device" << property("ro.product.manufacturer")
                         << property("ro.product.model") << "| Android"
                         << property("ro.build.version.release") << "(API"
                         << property("ro.build.version.sdk") + ") | chip"
                         << property("ro.soc.manufacturer") << property("ro.soc.model")
                         << property("ro.board.platform") << "| ABI"
                         << property("ro.product.cpu.abi");

    if (folder.isEmpty()) {
        return;
    }
    const QByteArray path = QDir(folder).filePath(QStringLiteral("crash.txt")).toLocal8Bit();
    s_crashFd = open(path.constData(), O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644);
    if (s_crashFd < 0) {
        qWarning() << "FLXXX3: cannot write the crash report" << path;
        return;
    }

    // The crash may be a stack overflow: the handler runs on its own stack.
    stack_t altStack{};
    altStack.ss_sp = s_altStack;
    altStack.ss_size = sizeof(s_altStack);
    sigaltstack(&altStack, nullptr);

    struct sigaction action {};
    action.sa_sigaction = crashHandler;
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
    sigemptyset(&action.sa_mask);
    for (size_t i = 0; i < std::size(kSignals); ++i) {
        sigaction(kSignals[i], &action, &s_oldActions[i]);
    }
}

} // namespace androidcrashlog
} // namespace mixxx
