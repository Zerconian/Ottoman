#include "Sway.h"
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

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
