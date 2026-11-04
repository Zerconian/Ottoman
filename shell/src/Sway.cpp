#include "Sway.h"
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QLocalSocket>
#include <QTimer>
#include <QtEndian>

static QByteArray run(const QStringList &args, bool *ok) {
    QProcess p;
    p.start(QStringLiteral("swaymsg"), args);
    *ok = p.waitForFinished(3000) && p.exitCode() == 0;
    if (!*ok) qWarning().noquote() << "swaymsg failed:" << args.join(' ') << p.readAllStandardError();
    return p.readAllStandardOutput();
}

bool Sway::command(const QString &cmd) const {
    bool ok;
    const QByteArray out = run({cmd}, &ok);
    qInfo().noquote() << "sway:" << cmd << (ok ? "ok" : "FAILED") << QString::fromUtf8(out).simplified().left(120);
    return ok;
}

static void walk(const QJsonObject &n, QStringList &ids) {
    const QJsonValue id = n.value(QStringLiteral("app_id"));
    if (id.isString() && !id.toString().isEmpty()) ids << id.toString();
    for (const char *key : {"nodes", "floating_nodes"})
        for (const QJsonValue &c : n.value(QLatin1String(key)).toArray()) walk(c.toObject(), ids);
}

QStringList Sway::appIds() const {
    bool ok;
    const QByteArray out = run({QStringLiteral("-t"), QStringLiteral("get_tree")}, &ok);
    QStringList ids;
    if (ok) walk(QJsonDocument::fromJson(out).object(), ids);
    return ids;
}

void Sway::hideApp(const QString &appId) const { command(QStringLiteral("[app_id=\"%1\"] move scratchpad").arg(appId)); }
void Sway::showApp(const QString &appId) const { command(QStringLiteral("[app_id=\"%1\"] scratchpad show, fullscreen enable").arg(appId)); }
void Sway::killApp(const QString &appId) const { command(QStringLiteral("[app_id=\"%1\"] kill").arg(appId)); }
void Sway::focusShell() const { command(QStringLiteral("[app_id=\"ottoman-shell\"] scratchpad show, fullscreen enable, focus")); }

// --- fullscreen guard: i3-ipc framing is "i3-ipc" + u32 length + u32 type (little endian) + payload.
static QByteArray ipcFrame(quint32 type, const QByteArray &payload) {
    QByteArray f("i3-ipc");
    const quint32 len = quint32(payload.size());
    f.append(reinterpret_cast<const char *>(&len), 4).append(reinterpret_cast<const char *>(&type), 4).append(payload);
    return f;
}

void Sway::startFullscreenGuard() {
    const QString sock = qEnvironmentVariable("SWAYSOCK");
    if (sock.isEmpty()) { qWarning() << "fullscreen guard: SWAYSOCK unset, guard off"; return; }
    m_ipc = new QLocalSocket(this);
    connect(m_ipc, &QLocalSocket::connected, this, [this] {
        m_ipc->write(ipcFrame(2, QByteArrayLiteral("[\"window\"]")));   // 2 = SUBSCRIBE
        qInfo() << "fullscreen guard: subscribed to sway window events";
    });
    connect(m_ipc, &QLocalSocket::readyRead, this, &Sway::onIpcReady);
    auto retry = [this, sock](const char *why) {
        qWarning() << "fullscreen guard:" << why << "- reconnecting in 2 s";
        m_buf.clear();
        QTimer::singleShot(2000, this, [this, sock] { m_ipc->connectToServer(sock); });
    };
    connect(m_ipc, &QLocalSocket::disconnected, this, [retry] { retry("sway IPC closed"); });
    connect(m_ipc, &QLocalSocket::errorOccurred, this, [retry, this](QLocalSocket::LocalSocketError) {
        if (m_ipc->state() == QLocalSocket::UnconnectedState) retry("sway IPC error");
    });
    m_ipc->connectToServer(sock);
}

void Sway::onIpcReady() {
    m_buf += m_ipc->readAll();
    while (m_buf.size() >= 14) {
        if (!m_buf.startsWith("i3-ipc")) { qWarning() << "fullscreen guard: bad IPC magic, dropping buffer"; m_buf.clear(); return; }
        const quint32 len = qFromLittleEndian<quint32>(m_buf.constData() + 6);
        const quint32 type = qFromLittleEndian<quint32>(m_buf.constData() + 10);
        if (quint64(m_buf.size()) < 14 + quint64(len)) return;   // frame not complete yet
        const QByteArray payload = m_buf.mid(14, int(len));
        m_buf.remove(0, 14 + int(len));
        if (type != 0x80000003u) continue;   // only WINDOW events (bit 31 set, type 3)
        const QJsonObject e = QJsonDocument::fromJson(payload).object();
        const QString change = e.value(QStringLiteral("change")).toString();
        // A window leaving fullscreen, a window closing (the fullscreen app quits: the launcher underneath never gets a
        // fullscreen_mode event, measured 2026-11-04) or focus moving: each may leave nothing fullscreen.
        const bool dropped = change == QLatin1String("fullscreen_mode")
            && e.value(QStringLiteral("container")).toObject().value(QStringLiteral("fullscreen_mode")).toInt() == 0;
        if (!dropped && change != QLatin1String("close") && change != QLatin1String("focus")) continue;
        if (!m_checkPending) { m_checkPending = true; QTimer::singleShot(300, this, &Sway::checkFullscreen); }
    }
}

// After a window left fullscreen: if nothing is fullscreen any more, give it back to the focused app window.
static void scan(const QJsonObject &n, bool &anyFullscreen, QJsonObject &focused) {
    const bool view = n.value(QStringLiteral("app_id")).isString() && !n.value(QStringLiteral("app_id")).toString().isEmpty();
    if (view && n.value(QStringLiteral("fullscreen_mode")).toInt() != 0 && n.value(QStringLiteral("visible")).toBool()) anyFullscreen = true;
    if (view && n.value(QStringLiteral("focused")).toBool() && n.value(QStringLiteral("visible")).toBool()) focused = n;
    for (const char *key : {"nodes", "floating_nodes"})
        for (const QJsonValue &c : n.value(QLatin1String(key)).toArray()) scan(c.toObject(), anyFullscreen, focused);
}

void Sway::checkFullscreen() {
    m_checkPending = false;
    bool ok;
    const QByteArray out = run({QStringLiteral("-t"), QStringLiteral("get_tree")}, &ok);
    if (!ok) return;
    bool anyFullscreen = false; QJsonObject focused;
    scan(QJsonDocument::fromJson(out).object(), anyFullscreen, focused);
    if (anyFullscreen || focused.isEmpty()) return;
    const QString appId = focused.value(QStringLiteral("app_id")).toString();
    qInfo().noquote() << "fullscreen guard:" << appId << "left fullscreen with nothing on top; restoring";
    command(QStringLiteral("[con_id=%1] fullscreen enable").arg(focused.value(QStringLiteral("id")).toInt()));
}
