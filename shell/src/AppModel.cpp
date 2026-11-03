#include "AppModel.h"
#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>

static QString appsConf() { const QString d = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/ottoman"; QDir().mkpath(d); return d + "/apps.conf"; }

AppModel::AppModel(Sway *sway, QObject *parent) : QAbstractListModel(parent), m_sway(sway) {
    // TV-ready catalogue (docs/DESIGN.md 4.4). app_id is what the window reports to sway; for Flatpaks it is the app ID.
    m_apps = {
        {"Jellyfin",  "org.jellyfin.JellyfinDesktop",  "org.jellyfin.JellyfinDesktop",  "#00a4dc", {"--tv", "--fullscreen"}},
        {"YouTube",   "rocks.shy.VacuumTube",          "rocks.shy.VacuumTube",          "#c4302b"},
        {"Plex",      "tv.plex.PlexHTPC",              "tv.plex.PlexHTPC",              "#e5a00d"},
        {"Kodi",      "tv.kodi.Kodi",                  "tv.kodi.Kodi",                  "#17b2e7"},
        {"RetroArch", "org.libretro.RetroArch",        "org.libretro.RetroArch",        "#6f42c1"},
        {"Steam Link","com.valvesoftware.SteamLink",   "com.valvesoftware.SteamLink",   "#1b2838"},
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
        switch (role) { case Name: return m_busy.isEmpty() ? QStringLiteral("Add app") : m_busy; case Color: return "#2a2f38"; case Installed: return true; case Running: return false; case IsAdd: return true; }
        return {};
    }
    if (idx.row() > m_rows.size()) return {};
    const AppEntry &a = m_apps[m_rows[idx.row()]];
    switch (role) {
    case Name: return a.name; case FlatpakId: return a.flatpakId; case AppId: return a.appId;
    case Color: return a.color; case Installed: return a.installed; case Running: return a.running; case IsAdd: return false;
    }
    return {};
}
QHash<int, QByteArray> AppModel::roleNames() const {
    return {{Name,"name"},{FlatpakId,"flatpakId"},{AppId,"appId"},{Color,"color"},{Installed,"installed"},{Running,"running"},{IsAdd,"isAdd"}};
}
int AppModel::installedCount() const { int n = 0; for (const auto &a : m_apps) n += a.installed; return n; }

void AppModel::launch(int row) {
    if (row < 0 || row >= m_rows.size()) return;
    AppEntry &a = m_apps[m_rows[row]];
    if (a.running) { qInfo() << "resume" << a.appId; m_sway->showApp(a.appId); return; }
    qInfo() << "launch" << a.flatpakId;
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
    for (const AppEntry &a : m_apps) l << QVariantMap{{"name", a.name}, {"flatpakId", a.flatpakId}, {"installed", a.installed}, {"hidden", a.hidden}};
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
    runFlatpak("Installing", {"--user", "install", "-y", "--noninteractive", "flathub", flatpakId}, flatpakId);
}
void AppModel::uninstall(int row) {
    if (row < 0 || row >= m_rows.size()) return;
    const QString id = m_apps[m_rows[row]].flatpakId;
    runFlatpak("Removing", {"--user", "uninstall", "-y", "--noninteractive", id}, id);
}
