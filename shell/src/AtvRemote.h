#pragma once
// Android TV Remote protocol v2 server (DESIGN.md 4.6, "phone without an app", zerc 2026-11-05): the box shows up in
// the Google TV remote built into Android phones (and the Android 11+ quick-settings tile), pairs with a 6-character
// code on screen and takes the phone's key presses. Protocol facts (reverse-engineered client: tronikos/androidtvremote2,
// louis49/androidtv-remote): TLS on 6467 for pairing (Google's "Polo" protobuf messages, the code binds both
// certificates through a SHA-256), TLS on 6466 for the remote channel (a paired client certificate only), every
// message a varint-length-prefixed protobuf, mDNS `_androidtvremote2._tcp` with a `bt=<mac>` TXT record.
// Why here and not in inputd: Python's ssl module cannot accept a self-signed CLIENT certificate (no verify callback);
// QSslSocket's QueryPeer mode asks for it without judging it. Keys are forwarded to inputd's HTTP API on :18820, which
// owns the uinput keyboard (root). The browser remote stays the fallback (zerc).
#include <QObject>
#include <QHash>
#include <QSet>
#include <QSslCertificate>
#include <QSslConfiguration>
#include <QTimer>

class QSslServer;
class QSslSocket;
class QNetworkAccessManager;

class AtvRemote : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString pairingCode READ pairingCode NOTIFY pairingCodeChanged)   // "" when no pairing is in progress
    Q_PROPERTY(int pairedCount READ pairedCount NOTIFY pairedCountChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
public:
    explicit AtvRemote(QObject *parent = nullptr);
    void start();                                   // certificate, both listeners, mDNS; logs what failed and carries on
    QString pairingCode() const { return m_code; }
    int pairedCount() const { return m_paired.size(); }
    bool running() const { return m_running; }
    Q_INVOKABLE void cancelPairing();               // Back on the code overlay
    Q_INVOKABLE void forgetAll();                   // Settings: unpair every phone
signals:
    void pairingCodeChanged();
    void pairedCountChanged();
    void runningChanged();
    void paired(const QString &clientName);
    void keyReceived(const QString &name);          // after it went to inputd, for the journal / tests

private:
    struct Conn { QByteArray buf; QString clientName; QByteArray hash; int pings = 0; bool configured = false; QSet<QString> held; };
    bool ensureCertificate();
    bool listen(QSslServer *&srv, quint16 port, const char *what);
    void onPairingConnection(QSslSocket *s);
    void onRemoteConnection(QSslSocket *s);
    void readFrames(QSslSocket *s, void (AtvRemote::*handler)(QSslSocket *, const QByteArray &));
    void handlePairing(QSslSocket *s, const QByteArray &msg);
    void handleRemote(QSslSocket *s, const QByteArray &msg);
    void send(QSslSocket *s, const QByteArray &msg);
    QByteArray pairingHash(const QSslCertificate &client, const QByteArray &codeTail) const;
    void setCode(const QString &c);
    void loadPaired();
    void storePaired(const QSslCertificate &c, const QString &name);
    void publishMdns();
    void forwardKey(const QString &name, const QString &extra);   // extra: "" tap, "&state=down" / "&state=up"

    QString m_dir;                                  // ~/.config/ottoman/atv
    QSslConfiguration m_ssl;
    QSslServer *m_pairing = nullptr, *m_remote = nullptr;
    QHash<QSslSocket *, Conn> m_conns;
    QSet<QByteArray> m_paired;                      // SHA-256 digests of paired client certificates
    QString m_code;
    bool m_running = false;
    QNetworkAccessManager *m_nam = nullptr;
    QTimer m_ping;
};
