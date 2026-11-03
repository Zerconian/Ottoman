#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
// Thin wrapper over swaymsg (SWAYSOCK is inherited from sway's exec). Every call logs its command and
// result to stderr (the journal) so a stacking bug is visible without a debugger.
class Sway : public QObject {
    Q_OBJECT
public:
    explicit Sway(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE bool command(const QString &cmd) const;
    // app_ids of all mapped toplevels (scratchpad included), from get_tree.
    QStringList appIds() const;
    Q_INVOKABLE void hideApp(const QString &appId) const;   // move to scratchpad, keep running
    Q_INVOKABLE void showApp(const QString &appId) const;   // scratchpad show + fullscreen
    Q_INVOKABLE void killApp(const QString &appId) const;
    Q_INVOKABLE void focusShell() const;
};
