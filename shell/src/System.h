#pragma once
#include <QObject>
#include <QVariant>
#include <QProcess>
// Settings backend (DESIGN.md 4.10 #3): thin, synchronous wrappers over the system tools the image ships.
// swaymsg (display), wpctl (audio), nmcli (network), bootc via a narrow sudoers allowlist (updates).
// Each call logs failures to the journal; nothing here is clever, the tools are the source of truth.
class System : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString busyText READ busyText NOTIFY busyChanged)
public:
    explicit System(QObject *parent = nullptr) : QObject(parent) {}
    QString busyText() const { return m_busy; }
    // Display
    Q_INVOKABLE QVariantList outputs() const;                       // [{name, current:"1920x1080@60", modes:[..]}]
    Q_INVOKABLE bool setMode(const QString &output, const QString &mode) const;
    Q_INVOKABLE void saveMode(const QString &output, const QString &mode) const;
    Q_INVOKABLE void applySavedModes() const;
    // Audio
    Q_INVOKABLE QVariantList sinks() const;                         // [{id, name, isDefault}]
    Q_INVOKABLE bool setDefaultSink(int id) const;
    // Network
    Q_INVOKABLE QVariantMap netStatus() const;                      // {kind, iface, ip, connection, wifiAvailable}
    Q_INVOKABLE QVariantList wifiList() const;                      // [{ssid, signal, security, active}]
    Q_INVOKABLE void wifiJoin(const QString &ssid, const QString &password);   // async, busyText + joined()
    // Updates (sudo bootc ... via /etc/sudoers.d/ottoman)
    Q_INVOKABLE QVariantMap updateStatus() const;                   // {booted, bootedDigest, staged, rollback, image}
    Q_INVOKABLE void updateCheck();                                 // async -> updateResult(text)
    Q_INVOKABLE void updateApply();                                 // async -> updateResult(text)
    Q_INVOKABLE void rollback();                                    // async -> updateResult(text)
    Q_INVOKABLE void reboot() const;
    // About
    Q_INVOKABLE QVariantMap about() const;
    Q_INVOKABLE void log(const QString &line) const;
    Q_INVOKABLE bool firstRunDone() const;
    Q_INVOKABLE void setLocale(const QString &lang) const;   // sudo localectl (allowlisted)
    Q_INVOKABLE void markFirstRunDone() const;                 // UI state to the journal, for driving tests                          // {hostname, uptime, diskFree, diskTotal, kernel}
signals:
    void busyChanged();
    void joined(bool ok, const QString &text);
    void updateResult(bool ok, const QString &text);
private:
    QByteArray run(const QString &prog, const QStringList &args, int timeoutMs = 8000, bool *ok = nullptr) const;
    void runAsync(const QString &label, const QString &prog, const QStringList &args, std::function<void(bool, const QString &)> done);
    QString m_busy;
};
