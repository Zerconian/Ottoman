#pragma once
#include <QAbstractListModel>
#include <QTimer>
#include <QProcess>
#include "Sway.h"
// The APPS row (DESIGN.md 4.10 #6): the TV-ready catalogue filtered to installed-and-not-hidden apps in the
// user's saved order, plus an "Add app" tile at the end. Order and hidden set live in ~/.config/ottoman/apps.conf.
struct AppEntry { QString name, flatpakId, appId, color; QStringList args; QStringList overrides; QString webUrl; QString note; bool byDefault = false; QString wrapper; bool installed = false; bool running = false; bool hidden = false; };
class AppModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int installedCount READ installedCount NOTIFY changed)
    Q_PROPERTY(QString busyText READ busyText NOTIFY changed)
public:
    enum Roles { Name = Qt::UserRole + 1, FlatpakId, AppId, Color, Installed, Running, IsAdd, Note, IconUrl, Monogram };
    explicit AppModel(Sway *sway, QObject *parent = nullptr);
    int rowCount(const QModelIndex & = {}) const override { return m_rows.size() + 1; }   // + Add tile
    QVariant data(const QModelIndex &idx, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int installedCount() const;
    QString busyText() const { return m_busy; }
    Q_INVOKABLE void launch(int row);
    Q_INVOKABLE void launchFlatpak(const QString &flatpakId);
    Q_INVOKABLE void refresh();
    // row management
    Q_INVOKABLE bool isAddRow(int row) const { return row == m_rows.size(); }
    Q_INVOKABLE void move(int row, int delta);
    Q_INVOKABLE void hide(int row);
    Q_INVOKABLE void uninstall(int row);
    Q_INVOKABLE QVariantList catalogue() const;        // every catalogue app: {name, flatpakId, installed, hidden}
    Q_INVOKABLE void install(const QString &flatpakId);
    Q_INVOKABLE void unhide(const QString &flatpakId);
    // first-run setup: install the default set one by one, reporting each step (DESIGN.md 4.10 #8 revised 2026-11-03)
    Q_INVOKABLE QVariantList defaults() const;          // [{name, flatpakId, installed}] unique by flatpakId
    Q_INVOKABLE void installDefaults();                 // emits setupProgress(name, state) per app, setupDone(failedCount)
signals:
    void changed();
    void opDone(bool ok, const QString &text);
    void setupProgress(const QString &name, const QString &state);   // state: installing | done | failed | skipped
    void setupDone(int failed);
private:
    void refreshInstalled();
    void refreshRunning();
    void rebuildRows();
    void load(); void save();
    QString iconFor(const AppEntry &a) const;   // file:// of the Flatpak's exported icon, or empty
    void runFlatpak(const QString &label, const QStringList &args, const QString &flatpakId);
    Sway *m_sway;
    QList<AppEntry> m_apps;      // catalogue
    QList<int> m_rows;           // indices into m_apps shown in the row, in order
    QStringList m_order, m_hidden;
    QString m_busy;
    QStringList m_queue; int m_queueFailed = 0;
    bool m_setupRunning = false;
public:
    Q_INVOKABLE bool setupRunning() const { return m_setupRunning; }
private:
    void nextInQueue();
    QTimer m_poll;
};
