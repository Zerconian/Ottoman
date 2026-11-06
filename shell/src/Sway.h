#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QByteArray>
class QLocalSocket;
// Thin wrapper over swaymsg (SWAYSOCK is inherited from sway's exec). Every call logs its command and
// result to stderr (the journal) so a stacking bug is visible without a debugger.
class Sway : public QObject {
    Q_OBJECT
public:
    explicit Sway(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE bool command(const QString &cmd) const;
    // app_ids of all mapped toplevels (scratchpad included), from get_tree.
    QStringList appIds() const;
    Q_INVOKABLE void hideApp(const QString &appId) const;   // fullscreen disable, then move to scratchpad (two messages, see .cpp)
    Q_INVOKABLE void hideAll() const;                       // Home: hide every visible app that way, then focus the shell
    Q_INVOKABLE void showApp(const QString &appId) const;   // scratchpad show + fullscreen
    Q_INVOKABLE void killApp(const QString &appId) const;
    Q_INVOKABLE void focusShell() const;
    // Fullscreen guard (DESIGN.md 4.15): an app that drops its own fullscreen (Plezy does on Esc) would otherwise sit
    // tiled beside the launcher. Subscribes to sway window events over the IPC socket; when a window leaves fullscreen
    // and 300 ms later nothing on the output is fullscreen, the focused app window gets it back. A hide (move
    // scratchpad) or a new app taking fullscreen leaves something fullscreen, so the guard stays quiet for those.
    void startFullscreenGuard();   // triggers: fullscreen_mode -> 0, close, focus
private:
    void onIpcReady();
    void checkFullscreen();
    QLocalSocket *m_ipc = nullptr;
    QByteArray m_buf;
    bool m_checkPending = false;
};
