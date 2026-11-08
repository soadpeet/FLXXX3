#pragma once

#include <QJSEngine>
#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QQmlEngine>
#include <QString>
#include <QTimer>

namespace mixxx {
namespace qml {

/// Android only: values for the status bar of the touch UI (battery, MIDI
/// controller, removable media, background cache copy). Polled every 2 s.
class QmlAndroidStatusProxy : public QObject {
    Q_OBJECT
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY changed)
    Q_PROPERTY(bool batteryCharging READ batteryCharging NOTIFY changed)
    Q_PROPERTY(bool controllerConnected READ controllerConnected NOTIFY changed)
    Q_PROPERTY(QString controllerName READ controllerName NOTIFY changed)
    Q_PROPERTY(bool stickPresent READ stickPresent NOTIFY changed)
    Q_PROPERTY(int cacheCopies READ cacheCopies NOTIFY changed)
    // Up to two removable volumes (USB1 / USB2). A stick keeps its slot while
    // it is plugged in. "Busy" while files of it are being copied: do not
    // remove it then.
    Q_PROPERTY(bool stick1Present READ stick1Present NOTIFY changed)
    Q_PROPERTY(bool stick2Present READ stick2Present NOTIFY changed)
    Q_PROPERTY(bool stick1Busy READ stick1Busy NOTIFY changed)
    Q_PROPERTY(bool stick2Busy READ stick2Busy NOTIFY changed)
    QML_NAMED_ELEMENT(AndroidStatus)
    QML_SINGLETON
  public:
    explicit QmlAndroidStatusProxy(QObject* parent = nullptr);

    static QmlAndroidStatusProxy* create(
            QQmlEngine* pQmlEngine, [[maybe_unused]] QJSEngine* pJsEngine) {
        return new QmlAndroidStatusProxy(pQmlEngine);
    }

    int batteryPercent() const {
        return m_batteryPercent;
    }
    bool batteryCharging() const {
        return m_batteryCharging;
    }
    bool controllerConnected() const {
        return m_controllerConnected;
    }
    QString controllerName() const {
        return m_controllerName;
    }
    bool stickPresent() const {
        return m_stickPresent;
    }
    int cacheCopies() const {
        return m_cacheCopies;
    }
    bool stick1Present() const {
        return m_slotPresent[0];
    }
    bool stick2Present() const {
        return m_slotPresent[1];
    }
    bool stick1Busy() const {
        return m_slotBusy[0];
    }
    bool stick2Busy() const {
        return m_slotBusy[1];
    }

    // Details of the stick in slot 1 or 2 (present, label, path, total, free).
    Q_INVOKABLE QVariantMap stickInfo(int slot) const;
    // The internal storage of the tablet (own music folders live here).
    Q_INVOKABLE QVariantMap tabletInfo() const;
    // Sub folders of `path` (names, sorted, without hidden ones) for the folder picker.
    Q_INVOKABLE QStringList subDirectories(const QString& path) const;
    // Brightness of the screen of this app: 0 - 1, or a negative value for the
    // brightness of the system settings.
    Q_INVOKABLE void setScreenBrightness(double value);
    // Hides the system bars (no app pinning).
    Q_INVOKABLE void lockScreen();
    // TEMP-DIAG: writes a line to the Android log (tag mixxx-qml).
    Q_INVOKABLE void log(const QString& text);
    // Unpins and closes the app.
    Q_INVOKABLE void quitApp();

  signals:
    void changed();

  private slots:
    void update();

  private:
    void readBattery();
    void keepMaxVolume();

    QTimer m_timer;
    int m_batteryPercent = -1;
    bool m_batteryCharging = false;
    bool m_controllerConnected = false;
    QString m_controllerName;
    bool m_stickPresent = false;
    int m_cacheCopies = 0;
    QString m_slotIds[2];
    bool m_slotPresent[2] = {false, false};
    bool m_slotBusy[2] = {false, false};
};

} // namespace qml
} // namespace mixxx
