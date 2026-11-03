#pragma once
#include <QAbstractListModel>
#include <QTimer>
#include "Sway.h"
// The APPS row: the TV-ready catalogue, filtered to what is installed, with a running flag from sway's tree.
// M2.1 keeps the catalogue static; M2.5 adds the Add-app tile and ordering.
struct AppEntry { QString name, flatpakId, appId, color; bool installed = false; bool running = false; };
class AppModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int installedCount READ installedCount NOTIFY changed)
public:
    enum Roles { Name = Qt::UserRole + 1, FlatpakId, AppId, Color, Installed, Running };
    explicit AppModel(Sway *sway, QObject *parent = nullptr);
    int rowCount(const QModelIndex & = {}) const override { return m_apps.size(); }
    QVariant data(const QModelIndex &idx, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int installedCount() const;
    Q_INVOKABLE void launch(int row);     // run if not running, else bring forward
    Q_INVOKABLE void refresh();           // installed (flatpak list) + running (sway tree)
signals:
    void changed();
private:
    void refreshInstalled();
    void refreshRunning();
    Sway *m_sway;
    QList<AppEntry> m_apps;
    QTimer m_poll;
};
