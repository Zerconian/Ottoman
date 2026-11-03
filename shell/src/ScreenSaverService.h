#pragma once
#include <QObject>
#include <QDBusContext>
#include <QDBusServiceWatcher>
#include <QHash>
#include "Sway.h"
// org.freedesktop.ScreenSaver on the session bus: apps (Kodi, mpv, browsers, Jellyfin Desktop) call
// Inhibit while they play. While any inhibit is held the shell marks its own always-open window with
// `inhibit_idle open`, which blocks swayidle globally; when the last one is released (or its owner
// drops off the bus) the inhibit goes away. swayidle itself does not implement this interface.
class ScreenSaverService : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.ScreenSaver")
public:
    explicit ScreenSaverService(Sway *sway, QObject *parent = nullptr);
    bool registered() const { return m_registered; }
public slots:
    uint Inhibit(const QString &application_name, const QString &reason_for_inhibit);
    void UnInhibit(uint cookie);
    bool GetActive() { return false; }
    uint GetActiveTime() { return 0; }
    uint GetSessionIdleTime() { return 0; }
    void SimulateUserActivity() {}
    void Lock() {}
    bool SetActive(bool) { return false; }
    uint Throttle(const QString &, const QString &) { return 0; }
    void UnThrottle(uint) {}
signals:
    void ActiveChanged(bool);
private:
    void apply();
    Sway *m_sway;
    QHash<uint, QString> m_holders;   // cookie -> D-Bus sender
    QDBusServiceWatcher m_watcher;
    uint m_next = 1;
    bool m_active = false, m_registered = false;
};
