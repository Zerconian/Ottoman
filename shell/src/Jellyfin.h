#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>
#include <functional>
#include "ItemModel.h"
// Jellyfin adapter for the content rows (DESIGN.md 4.10 #5): sign in once, keep a token, fill
// Continue watching (Resume + NextUp) and Recently added (Latest), deep-link by remote-controlling the
// Jellyfin Desktop session. Jellyfin 12 needs the `Authorization: MediaBrowser ...` header; the legacy
// X-Emby-Authorization form returns 400 (measured 2026-11-03).
class Jellyfin : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString serverUrl READ serverUrl NOTIFY changed)
    Q_PROPERTY(QString userName READ userName NOTIFY changed)
    Q_PROPERTY(QString state READ state NOTIFY changed)          // disconnected | connecting | connected | error
    Q_PROPERTY(QString errorText READ errorText NOTIFY changed)
    Q_PROPERTY(QString quickConnectCode READ quickConnectCode NOTIFY changed)
    Q_PROPERTY(ItemModel *continueModel READ continueModel CONSTANT)
    Q_PROPERTY(ItemModel *latestModel READ latestModel CONSTANT)
public:
    explicit Jellyfin(QObject *parent = nullptr);
    QString serverUrl() const { return m_url; }
    QString userName() const { return m_userName; }
    QString state() const { return m_state; }
    QString errorText() const { return m_error; }
    QString quickConnectCode() const { return m_qcCode; }
    ItemModel *continueModel() { return &m_continue; }
    ItemModel *latestModel() { return &m_latest; }
    Q_INVOKABLE void signIn(const QString &url, const QString &user, const QString &password);
    Q_INVOKABLE void quickConnectStart(const QString &url);
    Q_INVOKABLE void quickConnectCancel();
    Q_INVOKABLE void signOut();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void play(const QString &itemId);   // remote-control the Jellyfin Desktop session
signals:
    void changed();
    void needApp();                                 // play() found no Jellyfin Desktop session: launch it
    void played(const QString &itemId, bool ok);
private:
    using Handler = std::function<void(int status, const QJsonDocument &)>;
    void request(const QByteArray &verb, const QString &path, const QJsonObject &body, Handler h, bool withToken = true);
    QByteArray authHeader() const;
    void setState(const QString &s, const QString &err = {});
    void load(); void save();
    void finishSignIn(const QJsonDocument &d);
    void playOnSession(const QString &itemId, int attempt);
    QNetworkAccessManager m_net;
    QString m_url, m_token, m_userId, m_userName, m_deviceId, m_state = "disconnected", m_error, m_qcCode, m_qcSecret;
    QTimer m_qcPoll, m_refresh, m_retry;
    int m_retries = 0;
    ItemModel m_continue, m_latest;
};
