#include "ShellControl.h"
#include <QDBusConnection>
#include <QDebug>
ShellControl::ShellControl(QObject *parent) : QObject(parent) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerObject(QStringLiteral("/Shell"), this, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals);
    qInfo() << "shell: D-Bus org.ottoman.Shell" << (bus.registerService(QStringLiteral("org.ottoman.Shell")) ? "registered" : "NOT registered");
}
