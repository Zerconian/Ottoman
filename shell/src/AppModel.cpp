#include "AppModel.h"
#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QRegularExpression>
#include <QFile>

static QString appsConf() { const QString d = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/ottoman"; QDir().mkpath(d); return d + "/apps.conf"; }

AppModel::AppModel(Sway *sway, QObject *parent) : QAbstractListModel(parent), m_sway(sway) {
    // TV-ready catalogue (docs/DESIGN.md 4.4). app_id is what the window reports to sway; for Flatpaks it is the app ID.
    m_apps = {
        // Order = zerc's priority (2026-11-03): Jellyfin > Plex > YouTube > Firefox (streaming tiles) > RetroArch, Steam Link > the rest.
        // byDefault (last field) = installed by the first-run setup screen, in this order.
        {"Jellyfin",  "org.jellyfin.JellyfinDesktop",  "org.jellyfin.JellyfinDesktop",  "#00a4dc", {"--tv", "--fullscreen"}, {}, "", "", true},
        {"Plex",      "tv.plex.PlexHTPC",              "tv.plex.PlexHTPC",              "#e5a00d", {}, {}, "", "", true},
        // VacuumTube ships with --socket=x11 and the session has no XWayland: force Wayland (crashed in zypak otherwise, 2026-11-03).
        {"YouTube",   "rocks.shy.VacuumTube",          "rocks.shy.VacuumTube",          "#c4302b", {}, {"--nosocket=x11", "--socket=wayland"}, "", "", true},
        // Streaming sites run through webapp.sh in Firefox kiosk (DESIGN.md 4.5). Same Flatpak, own profile each.
        {"Netflix",   "org.mozilla.firefox", "org.mozilla.firefox", "#b1060f", {}, {}, "https://www.netflix.com/browse", "up to 1080p (Widevine L3)", true},
        {"Disney+",   "org.mozilla.firefox", "org.mozilla.firefox", "#0a3d91", {}, {}, "https://www.disneyplus.com/home", "up to 1080p (Widevine L3)"},
        {"Max",       "org.mozilla.firefox", "org.mozilla.firefox", "#5b2ccd", {}, {}, "https://play.max.com", "up to 1080p (Widevine L3)"},
        // More web players, all opt-in via Add app; same runner, same cap. Tubi and Pluto need no account (testable).
        {"Hulu",        "org.mozilla.firefox", "org.mozilla.firefox", "#1ce783", {}, {}, "https://www.hulu.com/hub/home", "up to 1080p (Widevine L3)"},
        {"Tubi",        "org.mozilla.firefox", "org.mozilla.firefox", "#fa382f", {}, {}, "https://tubitv.com/home", "free, up to 1080p"},
        {"Pluto TV",    "org.mozilla.firefox", "org.mozilla.firefox", "#f5c518", {}, {}, "https://pluto.tv/live-tv", "free, up to 1080p"},
        {"Discovery+",  "org.mozilla.firefox", "org.mozilla.firefox", "#1e4ed8", {}, {}, "https://www.discoveryplus.com/home", "up to 1080p (Widevine L3)"},
        {"Peacock",     "org.mozilla.firefox", "org.mozilla.firefox", "#0b0b0b", {}, {}, "https://www.peacocktv.com/watch/home", "up to 1080p (Widevine L3)"},
        {"Paramount+",  "org.mozilla.firefox", "org.mozilla.firefox", "#0064ff", {}, {}, "https://www.paramountplus.com/home/", "up to 1080p (Widevine L3)"},
        {"Crunchyroll", "org.mozilla.firefox", "org.mozilla.firefox", "#f47521", {}, {}, "https://www.crunchyroll.com/", "up to 1080p (Widevine L3)"},
        {"Prime Video", "org.mozilla.firefox", "org.mozilla.firefox", "#00a8e1", {}, {}, "https://www.primevideo.com/", "Linux browsers get SD/720p"},
        {"RetroArch", "org.libretro.RetroArch",        "org.libretro.RetroArch",        "#6f42c1", {}, {}, "", "", true},
        {"Steam Link","com.valvesoftware.SteamLink",   "com.valvesoftware.SteamLink",   "#1b2838", {}, {}, "", "", true},
        {"Kodi",      "tv.kodi.Kodi",                  "tv.kodi.Kodi",                  "#17b2e7"},
        {"Moonlight", "com.moonlight_stream.Moonlight","com.moonlight_stream.Moonlight","#2d7a3e"},
    };
    load();
    refresh();
    connect(&m_poll, &QTimer::timeout, this, &AppModel::refresh);
    m_poll.start(2000);
}

void AppModel::load() {
    QSettings s(appsConf(), QSettings::IniFormat);
    m_order = s.value("order").toStringList(); m_hidden = s.value("hidden").toStringList();
    for (AppEntry &a : m_apps) a.hidden = m_hidden.contains(a.flatpakId);
}
void AppModel::save() {
    QSettings s(appsConf(), QSettings::IniFormat);
    s.setValue("order", m_order); s.setValue("hidden", m_hidden); s.sync();
}

void AppModel::rebuildRows() {
    // installed and not hidden, in saved order; apps missing from the order go to the end in catalogue order
    QList<int> rows;
    for (const QString &id : m_order) for (int i = 0; i < m_apps.size(); ++i) if (m_apps[i].flatpakId == id && m_apps[i].installed && !m_apps[i].hidden && !rows.contains(i)) rows << i;
    for (int i = 0; i < m_apps.size(); ++i) if (m_apps[i].installed && !m_apps[i].hidden && !rows.contains(i)) rows << i;
    if (rows != m_rows) { beginResetModel(); m_rows = rows; endResetModel(); }
}

QVariant AppModel::data(const QModelIndex &idx, int role) const {
    if (!idx.isValid()) return {};
    if (idx.row() == m_rows.size()) {   // Add tile
        switch (role) { case Name: return m_busy.isEmpty() ? QStringLiteral("Add app") : m_busy; case Color: return "#2a2f38"; case Installed: return true; case Running: return false; case IsAdd: return true; case Note: return QString(); case IconUrl: return QString(); case Monogram: return QString(); }
        return {};
    }
    if (idx.row() > m_rows.size()) return {};
    const AppEntry &a = m_apps[m_rows[idx.row()]];
    switch (role) {
    case Name: return a.name; case FlatpakId: return a.flatpakId; case AppId: return a.appId;
    case Color: return a.color; case Installed: return a.installed; case Running: return a.running; case IsAdd: return false; case Note: return a.note;
    case IconUrl: return a.webUrl.isEmpty() ? iconFor(a) : QString();      // web apps get a monogram, never a third-party mark
    case Monogram: return a.webUrl.isEmpty() ? QString() : a.name.left(1).toUpper();
    }
    return {};
}
QString AppModel::iconFor(const AppEntry &a) const {
    // Installed Flatpaks export their own icon here; showing an installed app's icon in its launcher is what the icon ships for.
    const QString base = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/flatpak/exports/share/icons/hicolor/";
    for (const char *dir : {"scalable/apps/", "512x512/apps/", "256x256/apps/", "128x128/apps/", "64x64/apps/"})
        for (const char *ext : {".svg", ".png"}) { const QString f = base + dir + a.flatpakId + ext; if (QFile::exists(f)) return "file://" + f; }
    return {};
}
QHash<int, QByteArray> AppModel::roleNames() const {
    return {{Name,"name"},{FlatpakId,"flatpakId"},{AppId,"appId"},{Color,"color"},{Installed,"installed"},{Running,"running"},{IsAdd,"isAdd"},{Note,"note"},{IconUrl,"iconUrl"},{Monogram,"monogram"}};
}
int AppModel::installedCount() const { int n = 0; for (const auto &a : m_apps) n += a.installed; return n; }

void AppModel::launch(int row) {
    if (row < 0 || row >= m_rows.size()) return;
    AppEntry &a = m_apps[m_rows[row]];
    if (a.running) { qInfo() << "resume" << a.appId; m_sway->showApp(a.appId); return; }
    qInfo() << "launch" << a.name << a.flatpakId;
    if (!a.webUrl.isEmpty()) { QProcess::startDetached(QStringLiteral("/usr/libexec/ottoman/webapp.sh"), {a.name.toLower().remove(QRegularExpression("[^a-z0-9]")), a.webUrl}); return; }
    QProcess::startDetached(QStringLiteral("flatpak"), QStringList{QStringLiteral("--user"), QStringLiteral("run"), a.flatpakId} + a.args);
}
void AppModel::launchFlatpak(const QString &flatpakId) {
    for (int r = 0; r < m_rows.size(); ++r) if (m_apps[m_rows[r]].flatpakId == flatpakId) { launch(r); return; }
    for (const AppEntry &a : m_apps) if (a.flatpakId == flatpakId && a.installed) { QProcess::startDetached(QStringLiteral("flatpak"), QStringList{QStringLiteral("--user"), QStringLiteral("run"), a.flatpakId} + a.args); return; }
}

void AppModel::refresh() { refreshInstalled(); refreshRunning(); rebuildRows(); emit changed(); }

void AppModel::refreshInstalled() {
    QProcess p;
    p.start(QStringLiteral("flatpak"), {QStringLiteral("--user"), QStringLiteral("list"), QStringLiteral("--app"), QStringLiteral("--columns=application")});
    if (!p.waitForFinished(5000)) { qWarning() << "flatpak list timed out"; return; }
    const QStringList ids = QString::fromUtf8(p.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts);
    for (AppEntry &a : m_apps) a.installed = ids.contains(a.flatpakId);
}
void AppModel::refreshRunning() {
    const QStringList ids = m_sway->appIds();
    for (int i = 0; i < m_apps.size(); ++i) {
        const bool run = ids.contains(m_apps[i].appId);
        if (run != m_apps[i].running) { m_apps[i].running = run; const int r = m_rows.indexOf(i); if (r >= 0) emit dataChanged(index(r), index(r), {Running}); }
    }
}

// ---- management ----------------------------------------------------------------------------------
void AppModel::move(int row, int delta) {
    const int to = row + delta;
    if (row < 0 || row >= m_rows.size() || to < 0 || to >= m_rows.size()) return;
    QStringList order; for (int i : m_rows) order << m_apps[i].flatpakId;
    order.move(row, to); m_order = order; save();
    qInfo() << "apps: moved" << m_apps[m_rows[row]].name << "to" << to;
    rebuildRows(); emit changed();
}
void AppModel::hide(int row) {
    if (row < 0 || row >= m_rows.size()) return;
    AppEntry &a = m_apps[m_rows[row]]; a.hidden = true; if (!m_hidden.contains(a.flatpakId)) m_hidden << a.flatpakId; save();
    qInfo() << "apps: hid" << a.name; rebuildRows(); emit changed();
}
void AppModel::unhide(const QString &flatpakId) {
    m_hidden.removeAll(flatpakId); for (AppEntry &a : m_apps) if (a.flatpakId == flatpakId) a.hidden = false; save();
    qInfo() << "apps: unhid" << flatpakId; rebuildRows(); emit changed();
}
QVariantList AppModel::catalogue() const {
    QVariantList l;
    for (const AppEntry &a : m_apps) l << QVariantMap{{"name", a.name}, {"flatpakId", a.flatpakId}, {"installed", a.installed}, {"hidden", a.hidden}, {"note", a.note}};
    return l;
}
void AppModel::runFlatpak(const QString &label, const QStringList &args, const QString &flatpakId) {
    if (!m_busy.isEmpty()) { emit opDone(false, "Busy: " + m_busy); return; }
    m_busy = label; emit changed(); emit dataChanged(index(m_rows.size()), index(m_rows.size()), {Name});
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, label, flatpakId](int code, QProcess::ExitStatus) {
        const QString out = QString::fromUtf8(p->readAllStandardError() + p->readAllStandardOutput()).simplified().left(200);
        qInfo().noquote() << "apps:" << label << flatpakId << "->" << code << out;
        m_busy.clear(); refresh(); emit dataChanged(index(m_rows.size()), index(m_rows.size()), {Name});
        emit opDone(code == 0, code == 0 ? label + " done" : label + " failed: " + out);
        p->deleteLater();
    });
    p->start(QStringLiteral("flatpak"), args);
}
void AppModel::install(const QString &flatpakId) {
    unhide(flatpakId);
    for (const AppEntry &a : m_apps) if (a.flatpakId == flatpakId && !a.overrides.isEmpty()) {
        QProcess::execute(QStringLiteral("flatpak"), QStringList{QStringLiteral("override"), QStringLiteral("--user")} + a.overrides + QStringList{flatpakId});
        qInfo() << "apps: applied overrides for" << flatpakId << a.overrides;
    }
    runFlatpak("Installing", {"--user", "install", "-y", "--noninteractive", "flathub", flatpakId}, flatpakId);
}
void AppModel::uninstall(int row) {
    if (row < 0 || row >= m_rows.size()) return;
    const QString id = m_apps[m_rows[row]].flatpakId;
    runFlatpak("Removing", {"--user", "uninstall", "-y", "--noninteractive", id}, id);
}

// ---- first-run setup ----------------------------------------------------------------------------
QVariantList AppModel::defaults() const {
    QVariantList l; QSet<QString> seen;
    for (const AppEntry &a : m_apps) if (a.byDefault && !seen.contains(a.flatpakId)) { seen.insert(a.flatpakId); l << QVariantMap{{"name", a.flatpakId == "org.mozilla.firefox" ? QStringLiteral("Firefox (Netflix, Disney+, Max)") : a.name}, {"flatpakId", a.flatpakId}, {"installed", a.installed}}; }
    return l;
}
void AppModel::installDefaults() {
    refreshInstalled();
    m_queue.clear(); m_queueFailed = 0;
    for (const QVariant &v : defaults()) { const QVariantMap m = v.toMap(); if (m["installed"].toBool()) emit setupProgress(m["name"].toString(), "skipped"); else m_queue << m["flatpakId"].toString(); }
    nextInQueue();
}
void AppModel::nextInQueue() {
    if (m_queue.isEmpty()) { refresh(); emit setupDone(m_queueFailed); return; }
    const QString id = m_queue.takeFirst();
    QString name = id; for (const AppEntry &a : m_apps) if (a.flatpakId == id) { name = a.flatpakId == "org.mozilla.firefox" ? QStringLiteral("Firefox (Netflix, Disney+, Max)") : a.name; break; }
    emit setupProgress(name, "installing");
    for (const AppEntry &a : m_apps) if (a.flatpakId == id && !a.overrides.isEmpty()) QProcess::execute(QStringLiteral("flatpak"), QStringList{QStringLiteral("override"), QStringLiteral("--user")} + a.overrides + QStringList{id});
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, id, name](int code, QProcess::ExitStatus) {
        const QString out = QString::fromUtf8(p->readAllStandardError() + p->readAllStandardOutput()).simplified().left(200);
        qInfo().noquote() << "setup:" << id << "->" << code << out;
        if (code != 0) m_queueFailed++;
        emit setupProgress(name, code == 0 ? "done" : "failed");
        p->deleteLater(); nextInQueue();
    });
    p->start(QStringLiteral("flatpak"), {"--user", "install", "-y", "--noninteractive", "flathub", id});
}
