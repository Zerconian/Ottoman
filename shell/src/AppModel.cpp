#include "AppModel.h"
#include <QProcess>
#include <QDebug>

AppModel::AppModel(Sway *sway, QObject *parent) : QAbstractListModel(parent), m_sway(sway) {
    // TV-ready catalogue (docs/DESIGN.md 4.4). app_id is what the window reports to sway; for Flatpaks it is the app ID.
    m_apps = {
        {"Jellyfin",  "org.jellyfin.JellyfinDesktop",  "org.jellyfin.JellyfinDesktop",  "#00a4dc", {"--tv", "--fullscreen"}},
        {"Plex",      "tv.plex.PlexHTPC",              "tv.plex.PlexHTPC",              "#e5a00d"},
        {"Kodi",      "tv.kodi.Kodi",                  "tv.kodi.Kodi",                  "#17b2e7"},
        {"RetroArch", "org.libretro.RetroArch",        "org.libretro.RetroArch",        "#6f42c1"},
        {"Steam Link","com.valvesoftware.SteamLink",   "com.valvesoftware.SteamLink",   "#1b2838"},
        {"Moonlight", "com.moonlight_stream.Moonlight","com.moonlight_stream.Moonlight","#2d7a3e"},
    };
    refresh();
    connect(&m_poll, &QTimer::timeout, this, &AppModel::refresh);
    m_poll.start(2000);
}

QVariant AppModel::data(const QModelIndex &idx, int role) const {
    if (!idx.isValid() || idx.row() >= m_apps.size()) return {};
    const AppEntry &a = m_apps[idx.row()];
    switch (role) {
    case Name: return a.name; case FlatpakId: return a.flatpakId; case AppId: return a.appId;
    case Color: return a.color; case Installed: return a.installed; case Running: return a.running;
    }
    return {};
}
QHash<int, QByteArray> AppModel::roleNames() const {
    return {{Name,"name"},{FlatpakId,"flatpakId"},{AppId,"appId"},{Color,"color"},{Installed,"installed"},{Running,"running"}};
}
int AppModel::installedCount() const { int n = 0; for (const auto &a : m_apps) n += a.installed; return n; }

void AppModel::launch(int row) {
    if (row < 0 || row >= m_apps.size()) return;
    AppEntry &a = m_apps[row];
    if (a.running) { qInfo() << "resume" << a.appId; m_sway->showApp(a.appId); return; }
    if (!a.installed) { qInfo() << "not installed:" << a.flatpakId; return; }
    qInfo() << "launch" << a.flatpakId;
    QProcess::startDetached(QStringLiteral("flatpak"), QStringList{QStringLiteral("--user"), QStringLiteral("run"), a.flatpakId} + a.args);
}
void AppModel::launchFlatpak(const QString &flatpakId) {
    for (int i = 0; i < m_apps.size(); ++i) if (m_apps[i].flatpakId == flatpakId) { launch(i); return; }
}

void AppModel::refresh() { refreshInstalled(); refreshRunning(); emit changed(); }

void AppModel::refreshInstalled() {
    QProcess p;
    p.start(QStringLiteral("flatpak"), {QStringLiteral("--user"), QStringLiteral("list"), QStringLiteral("--app"), QStringLiteral("--columns=application")});
    if (!p.waitForFinished(5000)) { qWarning() << "flatpak list timed out"; return; }
    const QStringList ids = QString::fromUtf8(p.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts);
    for (int i = 0; i < m_apps.size(); ++i) {
        const bool inst = ids.contains(m_apps[i].flatpakId);
        if (inst != m_apps[i].installed) { m_apps[i].installed = inst; emit dataChanged(index(i), index(i), {Installed}); }
    }
}
void AppModel::refreshRunning() {
    const QStringList ids = m_sway->appIds();
    for (int i = 0; i < m_apps.size(); ++i) {
        const bool run = ids.contains(m_apps[i].appId);
        if (run != m_apps[i].running) { m_apps[i].running = run; emit dataChanged(index(i), index(i), {Running}); }
    }
}
