#include "System.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QHostInfo>
#include <QStorageInfo>
#include <QFile>
#include <QRegularExpression>
#include <QDebug>

QByteArray System::run(const QString &prog, const QStringList &args, int timeoutMs, bool *ok) const {
    QProcess p; p.start(prog, args);
    const bool fin = p.waitForFinished(timeoutMs);
    const bool good = fin && p.exitCode() == 0;
    if (ok) *ok = good;
    const QByteArray out = p.readAllStandardOutput();
    if (!good) qWarning().noquote() << "system:" << prog << args.join(' ') << "failed:" << (fin ? QString::fromUtf8(p.readAllStandardError() + out).simplified().left(200) : QStringLiteral("timeout"));
    return out;
}

void System::runAsync(const QString &label, const QString &prog, const QStringList &args, std::function<void(bool, const QString &)> done) {
    if (!m_busy.isEmpty()) { done(false, QStringLiteral("Busy: ") + m_busy); return; }
    m_busy = label; emit busyChanged();
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, done, prog, args](int code, QProcess::ExitStatus) {
        const QString out = QString::fromUtf8(p->readAllStandardOutput() + p->readAllStandardError()).trimmed();
        qInfo().noquote() << "system:" << prog << args.join(' ') << "->" << code << out.simplified().left(200);
        m_busy.clear(); emit busyChanged();
        done(code == 0, out);
        p->deleteLater();
    });
    p->start(prog, args);
}

// ---- Display -------------------------------------------------------------------------------------
QVariantList System::outputs() const {
    QVariantList res;
    const QJsonArray arr = QJsonDocument::fromJson(run("swaymsg", {"-t", "get_outputs"})).array();
    for (const QJsonValue &v : arr) {
        const QJsonObject o = v.toObject();
        const QJsonObject cm = o.value("current_mode").toObject();
        // value "1920x1080@59.940Hz" is what `swaymsg output NAME mode` accepts (Hz suffix required, measured 2026-11-03);
        // label "1920x1080@60" is what the user sees.
        auto modeOf = [](const QJsonObject &mo) { return QStringLiteral("%1x%2@%3Hz").arg(mo.value("width").toInt()).arg(mo.value("height").toInt()).arg(mo.value("refresh").toInt() / 1000.0, 0, 'f', 3); };
        auto labelOf = [](const QJsonObject &mo) { return QStringLiteral("%1x%2@%3").arg(mo.value("width").toInt()).arg(mo.value("height").toInt()).arg(qRound(mo.value("refresh").toInt() / 1000.0)); };
        QVariantList modes; QSet<QString> seen;
        for (const QJsonValue &m : o.value("modes").toArray()) {
            const QJsonObject mo = m.toObject();
            const QString v = modeOf(mo);
            if (!seen.contains(v)) { seen.insert(v); modes << QVariantMap{{"value", v}, {"label", labelOf(mo)}}; }
        }
        res << QVariantMap{{"name", o.value("name").toString()}, {"make", o.value("make").toString() + " " + o.value("model").toString()},
                           {"current", modeOf(cm)}, {"currentLabel", labelOf(cm)}, {"modes", modes}};
    }
    return res;
}
bool System::setMode(const QString &output, const QString &mode) const {
    bool ok; run("swaymsg", {QStringLiteral("output %1 mode %2").arg(output, mode)}, 8000, &ok);
    qInfo().noquote() << "system: set mode" << output << mode << (ok ? "ok" : "FAILED");
    return ok;
}
static QString cfg(const QString &name) { const QString d = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/ottoman"; QDir().mkpath(d); return d + "/" + name; }
void System::saveMode(const QString &output, const QString &mode) const { QSettings s(cfg("display.conf"), QSettings::IniFormat); s.setValue(output, mode); }
void System::applySavedModes() const {
    QSettings s(cfg("display.conf"), QSettings::IniFormat);
    for (const QString &k : s.allKeys()) setMode(k, s.value(k).toString());
}

// ---- Audio ---------------------------------------------------------------------------------------
QVariantList System::sinks() const {
    // wpctl status prints a "Sinks:" block under "Audio" with lines like " │  *   43. Built-in Audio Analog Stereo [vol: 0.40]"
    QVariantList res;
    const QStringList lines = QString::fromUtf8(run("wpctl", {"status"})).split('\n');
    bool inSinks = false;
    static const QRegularExpression re(R"(^\s*[│├└]?\s*(\*?)\s*(\d+)\.\s+(.+?)\s+\[vol:)");
    for (const QString &l : lines) {
        if (l.contains("Sinks:")) { inSinks = true; continue; }
        if (inSinks && (l.contains("Sources:") || l.trimmed().isEmpty() || l.contains("Filters:"))) break;
        if (!inSinks) continue;
        const auto m = re.match(l);
        if (m.hasMatch()) res << QVariantMap{{"id", m.captured(2).toInt()}, {"name", m.captured(3)}, {"isDefault", m.captured(1) == "*"}};
    }
    return res;
}
bool System::setDefaultSink(int id) const { bool ok; run("wpctl", {"set-default", QString::number(id)}, 5000, &ok); return ok; }

// ---- Network -------------------------------------------------------------------------------------
QVariantMap System::netStatus() const {
    QVariantMap st{{"kind", "none"}, {"iface", ""}, {"ip", ""}, {"connection", ""}, {"wifiAvailable", false}};
    const QStringList devs = QString::fromUtf8(run("nmcli", {"-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"})).split('\n', Qt::SkipEmptyParts);
    for (const QString &d : devs) {
        const QStringList f = d.split(':');
        if (f.size() < 4) continue;
        if (f[1] == "wifi") st["wifiAvailable"] = true;
        if (f[2].startsWith("connected") && st["kind"] == "none" && (f[1] == "ethernet" || f[1] == "wifi")) {
            st["kind"] = f[1]; st["iface"] = f[0]; st["connection"] = f[3];
            const QString ip4 = QString::fromUtf8(run("nmcli", {"-g", "IP4.ADDRESS", "dev", "show", f[0]})).trimmed();
            st["ip"] = ip4.section('/', 0, 0).section('|', 0, 0);
        }
    }
    return st;
}
QVariantList System::wifiList() const {
    QVariantList res; QSet<QString> seen;
    const QStringList lines = QString::fromUtf8(run("nmcli", {"-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"}, 15000)).split('\n', Qt::SkipEmptyParts);
    for (const QString &l : lines) {
        const QStringList f = l.split(':');
        if (f.size() < 4 || f[1].isEmpty() || seen.contains(f[1])) continue;
        seen.insert(f[1]);
        res << QVariantMap{{"ssid", f[1]}, {"signal", f[2].toInt()}, {"security", f[3]}, {"active", f[0] == "yes"}};
    }
    return res;
}
void System::wifiJoin(const QString &ssid, const QString &password) {
    QStringList args{"dev", "wifi", "connect", ssid};
    if (!password.isEmpty()) args << "password" << password;
    runAsync("Joining " + ssid, "nmcli", args, [this](bool ok, const QString &out) { emit joined(ok, ok ? "Connected" : out); });
}

// ---- Updates -------------------------------------------------------------------------------------
QVariantMap System::updateStatus() const {
    QVariantMap st{{"booted", "?"}, {"bootedDigest", ""}, {"staged", ""}, {"rollback", ""}, {"image", ""}};
    bool ok; const QJsonObject s = QJsonDocument::fromJson(run("sudo", {"-n", "/usr/bin/bootc", "status", "--format", "json"}, 15000, &ok)).object().value("status").toObject();
    if (!ok) return st;
    auto desc = [](const QJsonObject &d, QString *digest) {
        const QJsonObject img = d.value("image").toObject();
        if (digest) *digest = img.value("imageDigest").toString();
        // version label + short digest: rebuilt images share the Fedora version label, the digest tells them apart
        return img.value("version").toString() + " (" + img.value("imageDigest").toString().mid(7, 12) + ")";
    };
    QString dg;
    if (s.value("booted").isObject()) { st["booted"] = desc(s.value("booted").toObject(), &dg); st["bootedDigest"] = dg; st["image"] = s.value("booted").toObject().value("image").toObject().value("image").toObject().value("image").toString(); }
    if (s.value("staged").isObject()) st["staged"] = desc(s.value("staged").toObject(), nullptr);
    if (s.value("rollback").isObject()) st["rollback"] = desc(s.value("rollback").toObject(), nullptr);
    return st;
}
void System::updateCheck() { runAsync("Checking for updates", "sudo", {"-n", "/usr/bin/bootc", "upgrade", "--check"}, [this](bool ok, const QString &out) { emit updateResult(ok, out.isEmpty() ? "Up to date" : out); }); }
void System::updateApply() { runAsync("Downloading update", "sudo", {"-n", "/usr/bin/bootc", "upgrade"}, [this](bool ok, const QString &out) { emit updateResult(ok, ok ? "Update ready, it applies on the next restart" : out); }); }
void System::rollback()    { runAsync("Preparing rollback", "sudo", {"-n", "/usr/bin/bootc", "rollback"}, [this](bool ok, const QString &out) { emit updateResult(ok, ok ? "Previous version will boot on the next restart" : out); }); }
void System::reboot() const { run("systemctl", {"reboot"}, 5000); }

// ---- About ---------------------------------------------------------------------------------------
QVariantMap System::about() const {
    QStorageInfo st("/var");
    QFile up("/proc/uptime"); up.open(QIODevice::ReadOnly);
    const int secs = QString::fromUtf8(up.readAll()).section(' ', 0, 0).toDouble();
    QFile kv("/proc/sys/kernel/osrelease"); kv.open(QIODevice::ReadOnly);
    QFile bi("/usr/share/ottoman/build-info"); bi.open(QIODevice::ReadOnly);   // commit=..., built=... (image/Containerfile)
    QString build; for (const QString &l : QString::fromUtf8(bi.readAll()).split('\n')) { if (l.startsWith("commit=")) build = l.mid(7); else if (l.startsWith("built=")) build += " (" + l.mid(6) + ")"; }
    return {{"hostname", QHostInfo::localHostName()}, {"build", build.isEmpty() ? QStringLiteral("unknown") : build}, {"uptime", QStringLiteral("%1 h %2 min").arg(secs / 3600).arg((secs % 3600) / 60)},
            {"diskFree", QString::number(st.bytesAvailable() / (1024.0 * 1024 * 1024), 'f', 1) + " GB"}, {"diskTotal", QString::number(st.bytesTotal() / (1024.0 * 1024 * 1024), 'f', 1) + " GB"},
            {"kernel", QString::fromUtf8(kv.readAll()).trimmed()}};
}

void System::log(const QString &line) const { qInfo().noquote() << "ui:" << line; }

bool System::firstRunDone() const { return QFile::exists(cfg("firstrun-done")); }
void System::markFirstRunDone() const { QFile f(cfg("firstrun-done")); f.open(QIODevice::WriteOnly); f.write("done\n"); qInfo() << "system: first run done"; }

void System::setLocale(const QString &lang) const {
    bool ok; run("sudo", {"-n", "/usr/bin/localectl", "set-locale", "LANG=" + lang}, 10000, &ok);
    qInfo().noquote() << "system: set-locale" << lang << (ok ? "ok" : "FAILED");
}
