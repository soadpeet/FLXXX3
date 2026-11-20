// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include "qml/qmlproductproxy.h"

#include <QFile>

#include "moc_qmlproductproxy.cpp"

namespace mixxx {
namespace qml {

// static
QString QmlProductProxy::version() {
#ifdef FLXXX3_VERSION
    return QStringLiteral(FLXXX3_VERSION);
#else
    return QString();
#endif
}

QString QmlProductProxy::licenseText(const QString& name) const {
    if (name != QStringLiteral("GPL-3.0") && name != QStringLiteral("THIRD_PARTY")) {
        return QString();
    }
    QFile file(QStringLiteral(":/licenses/") + name + QStringLiteral(".txt"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }
    return QString::fromUtf8(file.readAll());
}

} // namespace qml
} // namespace mixxx
