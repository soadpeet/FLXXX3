#pragma once

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include <QObject>
#include <QtQml/qqmlregistration.h>

namespace mixxx {
namespace qml {

/// FLXXX3: the product switch for QML (Mixxx.Product.ui), the same on Android and Windows
/// (CMake option FLXXX3). It depends on nothing else, so the splash screen can read it before
/// the core services and Mixxx.Config exist.
class QmlProductProxy : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool ui READ ui CONSTANT)
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
};

} // namespace qml
} // namespace mixxx
