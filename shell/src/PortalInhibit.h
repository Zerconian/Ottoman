#pragma once
// xdg-desktop-portal backend for org.freedesktop.impl.portal.Inhibit (DESIGN.md 4.10 #7, found 2026-11-05): Flutter
// (Plezy's wakelock_plus), Flatpak Firefox and other portal-first apps hold their "keep the screen on" through the
// portal, and Fedora's sway-portals.conf maps Inhibit to none (xdg-desktop-portal-gtk's version needs gnome-session),
// so on a sway session no app could stop the screensaver that way. The shell already serves org.freedesktop.ScreenSaver;
// this is the same inhibit behind the portal's door: Inhibit(handle, ...) holds one, Close() on the request releases it.
// Wired by /usr/share/xdg-desktop-portal/portals/ottoman.portal and /etc/xdg-desktop-portal/sway-portals.conf in the image.
#include <QObject>
#include <QDBusContext>
#include <QDBusObjectPath>
#include <QHash>
#include <QVariantMap>
class ScreenSaverService;

class PortalInhibit : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.impl.portal.Inhibit")
    Q_PROPERTY(uint version READ version)
public:
    explicit PortalInhibit(ScreenSaverService *saver, QObject *parent = nullptr);
    uint version() const { return 3; }
    bool registered() const { return m_registered; }
public slots:
    void Inhibit(const QDBusObjectPath &handle, const QString &app_id, const QString &window, uint flags, const QVariantMap &options);
    uint CreateMonitor(const QDBusObjectPath &handle, const QDBusObjectPath &session_handle, const QString &app_id, const QString &window);
    void QueryEndResponse(const QDBusObjectPath &session_handle);
private:
    void release(const QString &handle);
    ScreenSaverService *m_saver;
    QHash<QString, uint> m_cookies;   // request handle path -> screensaver cookie
    bool m_registered = false;
    friend class PortalRequest;
};

// The request object the portal frontend closes when the app releases its inhibit (or dies).
class PortalRequest : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.impl.portal.Request")
public:
    PortalRequest(PortalInhibit *owner, const QString &handle) : QObject(owner), m_owner(owner), m_handle(handle) {}
public slots:
    void Close();
private:
    PortalInhibit *m_owner; QString m_handle;
};
