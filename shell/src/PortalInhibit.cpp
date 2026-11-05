#include "PortalInhibit.h"
#include "ScreenSaverService.h"
#include <QDBusConnection>
#include <QDebug>

PortalInhibit::PortalInhibit(ScreenSaverService *saver, QObject *parent) : QObject(parent), m_saver(saver) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerObject(QStringLiteral("/org/freedesktop/portal/desktop"), this, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllProperties);
    m_registered = bus.registerService(QStringLiteral("org.freedesktop.impl.portal.desktop.ottoman"));
    qInfo() << "portal: impl.portal.Inhibit backend" << (m_registered ? "registered" : "NOT registered");
}

// flags: 1 logout, 2 user switch, 4 suspend, 8 idle. A TV box never suspends on its own (DESIGN.md 4.10 #7), so every
// flag that could matter here means "keep the screen on"; logout/switch alone are no-ops that still get a request object.
void PortalInhibit::Inhibit(const QDBusObjectPath &handle, const QString &app_id, const QString &window, uint flags, const QVariantMap &options) {
    Q_UNUSED(window);
    const QString h = handle.path();
    auto *req = new PortalRequest(this, h);
    if (!QDBusConnection::sessionBus().registerObject(h, req, QDBusConnection::ExportAllSlots)) { qWarning() << "portal: could not export request" << h; delete req; return; }
    if (flags & (4 | 8)) {
        const uint cookie = m_saver->Inhibit(app_id.isEmpty() ? QStringLiteral("portal") : app_id, options.value("reason").toString());
        m_cookies.insert(h, cookie);
    }
    qInfo().noquote() << "portal: inhibit from" << app_id << "flags" << flags << (flags & (4 | 8) ? "(held)" : "(no idle flag, ignored)");
}
void PortalInhibit::release(const QString &handle) {
    if (m_cookies.contains(handle)) m_saver->UnInhibit(m_cookies.take(handle));
    QDBusConnection::sessionBus().unregisterObject(handle);
}
uint PortalInhibit::CreateMonitor(const QDBusObjectPath &handle, const QDBusObjectPath &session_handle, const QString &app_id, const QString &window) {
    Q_UNUSED(handle); Q_UNUSED(session_handle); Q_UNUSED(window);
    qInfo() << "portal: CreateMonitor from" << app_id << "(session state is always active here)";
    return 0;
}
void PortalInhibit::QueryEndResponse(const QDBusObjectPath &) {}

void PortalRequest::Close() { m_owner->release(m_handle); qInfo() << "portal: inhibit released" << m_handle; deleteLater(); }
