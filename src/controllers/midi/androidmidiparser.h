#pragma once

#include <QByteArray>
#include <cstddef>
#include <cstdint>
#include <functional>

/// Splits the raw MIDI byte stream delivered by the Android MIDI API (AMidi)
/// into short messages and SysEx messages. Handles running status, real-time
/// messages in the middle of other messages and SysEx messages that are spread
/// over several packets. Has no Android dependencies, so it is unit-testable.
class AndroidMidiParser {
  public:
    using ShortMessageHandler =
            std::function<void(uint8_t status, uint8_t data1, uint8_t data2)>;
    /// Called with the complete SysEx message including 0xF0 and 0xF7.
    using SysexHandler = std::function<void(const QByteArray& sysex)>;

    static constexpr int kMaxSysexLength = 1024 * 1024;

    void feed(const uint8_t* data,
            size_t length,
            const ShortMessageHandler& onShort,
            const SysexHandler& onSysex);
    void reset();

    /// Total length in bytes including the status byte, for all messages
    /// except SysEx. Returns 1 for unknown/undefined status bytes.
    static int messageLength(uint8_t status);

  private:
    uint8_t m_runningStatus = 0;
    uint8_t m_status = 0;
    uint8_t m_data[2] = {0, 0};
    int m_dataCount = 0;
    int m_expectedData = 0;
    bool m_inSysex = false;
    QByteArray m_sysex;
};
