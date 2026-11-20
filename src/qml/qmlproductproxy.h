#pragma once

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

namespace mixxx {
namespace qml {

/// FLXXX3: the product switch for QML (Mixxx.Product.ui), the same on Android and Windows
/// (CMake option FLXXX3). It depends on nothing else, so the splash screen can read it before
/// the core services and Mixxx.Config exist.
class QmlProductProxy : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool ui READ ui CONSTANT)
    // Version of FLXXX3 (versionName of the Android manifest), "" in other builds.
    Q_PROPERTY(QString version READ version CONSTANT)
    // Where the source code of FLXXX3 is published.
    Q_PROPERTY(QString sourceUrl READ sourceUrl CONSTANT)
    QML_NAMED_ELEMENT(Product)
    QML_SINGLETON

  public:
    explicit QmlProductProxy(QObject* pParent = nullptr)
            : QObject(pParent) {
    }

    static constexpr bool ui() {
#ifdef FLXXX3
        return true;
#else
        return false;
#endif
    }

    static QString version();
    static QString sourceUrl() {
        return QStringLiteral("https://github.com/soadpeet/FLXXX3");
    }
    /// Text of a license shown in ADVANCED SETTINGS > ABOUT: "GPL-3.0" or "THIRD_PARTY".
    Q_INVOKABLE QString licenseText(const QString& name) const;
};

} // namespace qml
} // namespace mixxx
