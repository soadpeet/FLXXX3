// FLXXX3: tests of the list of supported controllers (src/controllers/supportedcontrollers.h).
// AI disclaimer: written autonomously by an AI agent (Claude).

#include "controllers/supportedcontrollers.h"

#include <gtest/gtest.h>

#include <QFileInfo>

#include "test/mixxxtest.h"

namespace {

TEST(SupportedControllersTest, FindsTheControllerInSystemNames) {
    // MIDI port (Android, Windows), sound device (Android, WASAPI, ASIO).
    EXPECT_STREQ("DDJ-FLX4", flxxx3::findSupportedController(QStringLiteral("DDJ-FLX4"))->name);
    EXPECT_STREQ("DDJ-FLX4",
            flxxx3::findSupportedController(QStringLiteral("Line (2- DDJ-FLX4)"))->name);
    EXPECT_STREQ("DDJ-FLX10",
            flxxx3::findSupportedController(QStringLiteral("DDJ-FLX10: USB device"))->name);
    EXPECT_STREQ("DDJ-FLX10",
            flxxx3::findSupportedController(QStringLiteral("ASIO ddj-flx10"))->name);
    EXPECT_EQ(nullptr, flxxx3::findSupportedController(QStringLiteral("DDJ-400")));
    EXPECT_EQ(nullptr, flxxx3::findSupportedController(QStringLiteral("Speakers")));
}

TEST(SupportedControllersTest, NoNameContainsAnother) {
    for (const auto& a : flxxx3::kSupportedControllers) {
        for (const auto& b : flxxx3::kSupportedControllers) {
            if (&a != &b) {
                EXPECT_FALSE(QString::fromLatin1(a.name).contains(
                        QLatin1String(b.name), Qt::CaseInsensitive))
                        << a.name << " contains " << b.name;
            }
        }
    }
}

TEST(SupportedControllersTest, FindsTheControllerByUsbIds) {
    EXPECT_STREQ("DDJ-FLX4", flxxx3::findSupportedController(0x2B73, 0x0045)->name);
    const auto* pFlx10 = flxxx3::findSupportedController(0x2B73, 0x0041);
    ASSERT_NE(nullptr, pFlx10);
    EXPECT_STREQ("DDJ-FLX10", pFlx10->name);
    EXPECT_EQ(44100, pFlx10->sampleRate);
    EXPECT_EQ(7, pFlx10->audioUnlockCount);
    EXPECT_TRUE(pFlx10->startClockViaSystem);
    EXPECT_TRUE(pFlx10->implicitFeedback);
    EXPECT_EQ(nullptr, flxxx3::findSupportedController(0x2B73, 0x0001));
}

class SupportedControllersMappingTest : public MixxxTest {};

TEST_F(SupportedControllersMappingTest, MappingsExist) {
    for (const auto& controller : flxxx3::kSupportedControllers) {
        const QString path = getTestDir().filePath(QStringLiteral("../../res/controllers/") +
                QString::fromLatin1(controller.mappingFile));
        EXPECT_TRUE(QFileInfo::exists(path)) << qPrintable(path);
    }
}

} // namespace
