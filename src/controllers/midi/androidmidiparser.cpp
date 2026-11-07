#include "controllers/midi/androidmidiparser.h"

int AndroidMidiParser::messageLength(uint8_t status) {
    if (status >= 0x80 && status < 0xC0) {
        return 3; // Note off/on, polyphonic pressure, control change
    }
    if (status >= 0xC0 && status < 0xE0) {
        return 2; // Program change, channel pressure
    }
    if (status >= 0xE0 && status < 0xF0) {
        return 3; // Pitch bend
    }
    switch (status) {
    case 0xF1: // MTC quarter frame
    case 0xF3: // Song select
        return 2;
    case 0xF2: // Song position pointer
        return 3;
    default:
        return 1;
    }
}

void AndroidMidiParser::reset() {
    m_runningStatus = 0;
    m_status = 0;
    m_dataCount = 0;
    m_expectedData = 0;
    m_inSysex = false;
    m_sysex.clear();
}

void AndroidMidiParser::feed(const uint8_t* data,
        size_t length,
        const ShortMessageHandler& onShort,
        const SysexHandler& onSysex) {
    for (size_t i = 0; i < length; ++i) {
        const uint8_t byte = data[i];

        if (byte >= 0xF8) {
            // Real-time messages may occur anywhere, even inside other messages.
            onShort(byte, 0, 0);
            continue;
        }

        if (byte & 0x80) {
            // Status byte
            if (m_inSysex) {
                if (byte == 0xF7) {
                    m_sysex.append(static_cast<char>(0xF7));
                    onSysex(m_sysex);
                    m_inSysex = false;
                    m_sysex.clear();
                    m_status = 0;
                    m_dataCount = 0;
                    continue;
                }
                // Any other status byte aborts the SysEx message.
                m_inSysex = false;
                m_sysex.clear();
            }
            if (byte == 0xF0) {
                m_inSysex = true;
                m_sysex.clear();
                m_sysex.append(static_cast<char>(0xF0));
                m_runningStatus = 0;
                m_status = 0;
                m_dataCount = 0;
                continue;
            }
            if (byte == 0xF7) {
                // Stray end-of-exclusive without a start.
                continue;
            }
            m_status = byte;
            m_dataCount = 0;
            m_expectedData = messageLength(byte) - 1;
            // Only channel messages take part in running status.
            m_runningStatus = (byte < 0xF0) ? byte : 0;
            if (m_expectedData == 0) {
                onShort(byte, 0, 0);
                m_status = 0;
            }
            continue;
        }

        // Data byte
        if (m_inSysex) {
            if (m_sysex.size() < kMaxSysexLength) {
                m_sysex.append(static_cast<char>(byte));
            }
            continue;
        }
        if (m_status == 0) {
            if (m_runningStatus == 0) {
                continue; // Data without a status: ignore
            }
            m_status = m_runningStatus;
            m_dataCount = 0;
            m_expectedData = messageLength(m_status) - 1;
        }
        m_data[m_dataCount++] = byte;
        if (m_dataCount >= m_expectedData) {
            onShort(m_status, m_data[0], m_expectedData > 1 ? m_data[1] : 0);
            m_dataCount = 0;
            if (m_status >= 0xF0) {
                m_status = 0; // System common messages end running status.
            }
        }
    }
}
