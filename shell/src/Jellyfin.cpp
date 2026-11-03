#include "Jellyfin.h"
#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QUuid>
#include <QNetworkRequest>
#include <QUrlQuery>
#include <QDebug>

static QString settingsPath() {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/ottoman";
    QDir().mkpath(dir);
    return dir + "/jellyfin.conf";
}

Jellyfin::Jellyfin(QObject *parent) : QObject(parent) {
    load();
    if (m_deviceId.isEmpty()) { m_deviceId = QUuid::createUuid().toString(QUuid::WithoutBraces); save(); }
    connect(&m_qcPoll, &QTimer::timeout, this, [this] {
        request("GET", "/QuickConnect/Connect?secret=" + m_qcSecret, {}, [this](int st, const QJsonDocument &d) {
            if (st != 200) { m_qcPoll.stop(); setState("error", "Quick Connect lost (" + QString::number(st) + ")"); return; }
            if (d.object().value("Authenticated").toBool()) {
                m_qcPoll.stop();
                request("POST", "/Users/AuthenticateWithQuickConnect", {{"Secret", m_qcSecret}},
                        [this](int st2, const QJsonDocument &d2) { if (st2 == 200) finishSignIn(d2); else setState("error", "Quick Connect sign-in failed (" + QString::number(st2) + ")"); }, false);
            }
        }, false);
    });
    m_refresh.setInterval(60000);
    connect(&m_refresh, &QTimer::timeout, this, &Jellyfin::refresh);
    if (!m_token.isEmpty()) { setState("connected"); refresh(); m_refresh.start(); }
}

QByteArray Jellyfin::authHeader() const {
    QString h = QStringLiteral("MediaBrowser Client=\"Ottoman\", Device=\"Ottoman\", DeviceId=\"%1\", Version=\"0.1\"").arg(m_deviceId);
    if (!m_token.isEmpty()) h += QStringLiteral(", Token=\"%1\"").arg(m_token);
    return h.toUtf8();
}

void Jellyfin::request(const QByteArray &verb, const QString &path, const QJsonObject &body, Handler h, bool withToken) {
    QNetworkRequest req(QUrl(m_url + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", "application/json");
    QString auth = QString::fromUtf8(authHeader());
    if (!withToken) auth = QStringLiteral("MediaBrowser Client=\"Ottoman\", Device=\"Ottoman\", DeviceId=\"%1\", Version=\"0.1\"").arg(m_deviceId);
    req.setRawHeader("Authorization", auth.toUtf8());
    req.setTransferTimeout(10000);
    QNetworkReply *r = m_net.sendCustomRequest(req, verb, body.isEmpty() ? QByteArray() : QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(r, &QNetworkReply::finished, this, [r, h, verb, path] {
        const int st = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray data = r->readAll();
        if (st == 0) qWarning().noquote() << "jellyfin:" << verb << path << "network error:" << r->errorString();
        else if (st >= 400) qWarning().noquote() << "jellyfin:" << verb << path << "->" << st << QString::fromUtf8(data).left(160);
        h(st, QJsonDocument::fromJson(data));
        r->deleteLater();
    });
}

void Jellyfin::setState(const QString &s, const QString &err) { m_state = s; m_error = err; if (!err.isEmpty()) qWarning().noquote() << "jellyfin:" << err; emit changed(); }

void Jellyfin::load() {
    QSettings s(settingsPath(), QSettings::IniFormat);
    m_url = s.value("url").toString(); m_token = s.value("token").toString();
    m_userId = s.value("userId").toString(); m_userName = s.value("userName").toString(); m_deviceId = s.value("deviceId").toString();
}
void Jellyfin::save() {
    QSettings s(settingsPath(), QSettings::IniFormat);
    s.setValue("url", m_url); s.setValue("token", m_token); s.setValue("userId", m_userId);
    s.setValue("userName", m_userName); s.setValue("deviceId", m_deviceId); s.sync();
    QFile::setPermissions(settingsPath(), QFile::ReadOwner | QFile::WriteOwner);   // the token is a credential
}

static QString normalizeUrl(QString url) {
    url = url.trimmed();
    if (!url.startsWith("http://") && !url.startsWith("https://")) url.prepend("http://");
    while (url.endsWith('/')) url.chop(1);
    if (QUrl(url).port() == -1 && url.startsWith("http://") && url.count(':') == 1) url += ":8096";
    return url;
}

void Jellyfin::signIn(const QString &url, const QString &user, const QString &password) {
    m_url = normalizeUrl(url); m_qcPoll.stop(); m_qcCode.clear();
    setState("connecting");
    request("POST", "/Users/AuthenticateByName", {{"Username", user}, {"Pw", password}}, [this](int st, const QJsonDocument &d) {
        if (st == 200) finishSignIn(d);
        else setState("error", st == 401 ? "Wrong user name or password" : st == 0 ? "Server not reachable" : "Sign-in failed (" + QString::number(st) + ")");
    }, false);
}

void Jellyfin::quickConnectStart(const QString &url) {
    m_url = normalizeUrl(url); m_qcCode.clear(); setState("connecting");
    request("POST", "/QuickConnect/Initiate", {}, [this](int st, const QJsonDocument &d) {
        if (st != 200) { setState("error", st == 0 ? "Server not reachable" : "Quick Connect is off on this server"); return; }
        m_qcSecret = d.object().value("Secret").toString(); m_qcCode = d.object().value("Code").toString();
        m_qcPoll.start(2000); emit changed();
    }, false);
}
void Jellyfin::quickConnectCancel() { m_qcPoll.stop(); m_qcCode.clear(); if (m_token.isEmpty()) setState("disconnected"); else emit changed(); }

void Jellyfin::finishSignIn(const QJsonDocument &d) {
    const QJsonObject o = d.object();
    m_token = o.value("AccessToken").toString();
    m_userId = o.value("User").toObject().value("Id").toString();
    m_userName = o.value("User").toObject().value("Name").toString();
    m_qcCode.clear(); save();
    qInfo().noquote() << "jellyfin: signed in as" << m_userName << "at" << m_url;
    setState("connected"); refresh(); m_refresh.start();
}

void Jellyfin::signOut() {
    m_refresh.stop(); m_qcPoll.stop(); m_token.clear(); m_userId.clear(); m_userName.clear(); save();
    m_continue.reset({}); m_latest.reset({}); setState("disconnected");
}

void Jellyfin::refresh() {
    if (m_token.isEmpty()) return;
    auto toItem = [this](const QJsonObject &i) {
        MediaItem m; m.id = i.value("Id").toString(); m.name = i.value("Name").toString();
        if (i.value("Type").toString() == "Episode") {
            m.name = i.value("SeriesName").toString();
            m.subtitle = QStringLiteral("S%1E%2  %3").arg(i.value("ParentIndexNumber").toInt()).arg(i.value("IndexNumber").toInt()).arg(i.value("Name").toString());
        } else if (i.contains("ProductionYear")) m.subtitle = QString::number(i.value("ProductionYear").toInt());
        const QJsonObject ud = i.value("UserData").toObject();
        m.progress = ud.value("PlayedPercentage").toDouble() / 100.0;
        // Episodes have a 16:9 Primary; movies a poster, so prefer the series/parent thumb when present.
        const QString thumbId = i.value("ParentThumbItemId").toString(); const QString thumbTag = i.value("ParentThumbImageTag").toString();
        if (!thumbId.isEmpty() && !thumbTag.isEmpty()) m.imageUrl = QStringLiteral("%1/Items/%2/Images/Thumb?maxWidth=600&tag=%3&api_key=%4").arg(m_url, thumbId, thumbTag, m_token);
        else if (i.value("ImageTags").toObject().contains("Primary")) m.imageUrl = QStringLiteral("%1/Items/%2/Images/Primary?maxWidth=600&api_key=%3").arg(m_url, m.id, m_token);
        return m;
    };
    request("GET", "/Users/" + m_userId + "/Items/Resume?Limit=12&MediaTypes=Video&Fields=ParentThumbItemId", {}, [this, toItem](int st, const QJsonDocument &d) {
        if (st == 401) { setState("error", "Session expired, sign in again"); m_token.clear(); save(); return; }
        QList<MediaItem> items;
        for (const QJsonValue &v : d.object().value("Items").toArray()) items << toItem(v.toObject());
        request("GET", "/Shows/NextUp?UserId=" + m_userId + "&Limit=12&Fields=ParentThumbItemId", {}, [this, toItem, items](int st2, const QJsonDocument &d2) mutable {
            if (st2 == 200) for (const QJsonValue &v : d2.object().value("Items").toArray()) { MediaItem m = toItem(v.toObject()); if (!std::any_of(items.cbegin(), items.cend(), [&](const MediaItem &x){ return x.id == m.id; })) items << m; }
            m_continue.reset(items);
        });
    });
    request("GET", "/Users/" + m_userId + "/Items/Latest?Limit=16&Fields=ParentThumbItemId", {}, [this, toItem](int st, const QJsonDocument &d) {
        if (st != 200) return;
        QList<MediaItem> items;
        for (const QJsonValue &v : d.array()) items << toItem(v.toObject());
        m_latest.reset(items);
    });
}

void Jellyfin::play(const QString &itemId) { playOnSession(itemId, 0); }

void Jellyfin::playOnSession(const QString &itemId, int attempt) {
    request("GET", "/Sessions", {}, [this, itemId, attempt](int st, const QJsonDocument &d) {
        QString best; QString bestSeen;
        for (const QJsonValue &v : d.array()) {
            const QJsonObject s = v.toObject();
            const QString client = s.value("Client").toString();
            if (!client.contains("Jellyfin", Qt::CaseInsensitive) || client.contains("Ottoman")) continue;
            if (!s.value("SupportsRemoteControl").toBool()) continue;
            const QString seen = s.value("LastActivityDate").toString();
            if (best.isEmpty() || seen > bestSeen) { best = s.value("Id").toString(); bestSeen = seen; }
        }
        if (best.isEmpty()) {
            if (attempt == 0) { qInfo() << "jellyfin: no Jellyfin Desktop session, launching the app"; emit needApp(); }
            if (attempt < 20) { QTimer::singleShot(1500, this, [this, itemId, attempt] { playOnSession(itemId, attempt + 1); }); return; }
            qWarning() << "jellyfin: gave up waiting for a Jellyfin Desktop session"; emit played(itemId, false); return;
        }
        request("POST", "/Sessions/" + best + "/Playing?playCommand=PlayNow&itemIds=" + itemId, {}, [this, itemId](int st2, const QJsonDocument &) {
            qInfo().noquote() << "jellyfin: PlayNow" << itemId << "->" << st2;
            emit played(itemId, st2 == 204 || st2 == 200);
        });
    });
}
