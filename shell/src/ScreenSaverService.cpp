#include "ScreenSaverService.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDebug>

ScreenSaverService::ScreenSaverService(Sway *sway, QObject *parent) : QObject(parent), m_sway(sway) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerObject(QStringLiteral("/ScreenSaver"), this, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals);
    bus.registerObject(QStringLiteral("/org/freedesktop/ScreenSaver"), this, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals);
    m_registered = bus.registerService(QStringLiteral("org.freedesktop.ScreenSaver"));
    qInfo() << "screensaver: D-Bus org.freedesktop.ScreenSaver" << (m_registered ? "registered" : "NOT registered (another provider?)");
    m_watcher.setConnection(bus);
    m_watcher.setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(&m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, [this](const QString &name) {
        const int before = m_holders.size();
        for (auto it = m_holders.begin(); it != m_holders.end();) { if (it.value() == name) it = m_holders.erase(it); else ++it; }
        if (m_holders.size() != before) { qInfo() << "screensaver: holder left the bus, dropped" << before - m_holders.size() << "inhibit(s)"; m_watcher.removeWatchedService(name); apply(); }
    });
}

uint ScreenSaverService::Inhibit(const QString &app, const QString &reason) {
    const uint cookie = m_next++;
    const QString sender = calledFromDBus() ? message().service() : QString();
    m_holders.insert(cookie, sender);
    if (!sender.isEmpty()) m_watcher.addWatchedService(sender);
    qInfo().noquote() << "screensaver: inhibit" << cookie << "from" << app << "(" << reason << ")";
    apply();
    return cookie;
}
void ScreenSaverService::UnInhibit(uint cookie) {
    if (m_holders.remove(cookie)) { qInfo() << "screensaver: uninhibit" << cookie; apply(); }
}
void ScreenSaverService::apply() {
    const bool active = !m_holders.isEmpty();
    if (active == m_active) return;
    m_active = active;
    m_sway->command(QStringLiteral("[app_id=\"ottoman-shell\"] inhibit_idle %1").arg(active ? "open" : "none"));
    emit ActiveChanged(active);
}
