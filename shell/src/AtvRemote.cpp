#include "AtvRemote.h"
#include <QCryptographicHash>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QHostInfo>
#include <QNetworkAccessManager>
#include <QNetworkInterface>
#include <QNetworkReply>
#include <QProcess>
#include <QRandomGenerator>
#include <QSslKey>
#include <QSslServer>
#include <QSslSocket>
#include <QStandardPaths>
#include <QtDebug>

// ---- a protobuf codec small enough to read: varints and length-delimited fields are all these messages use ---------
namespace {
struct Field { int num; int wt; quint64 vi = 0; QByteArray ld; };

QByteArray varint(quint64 v) { QByteArray b; do { quint8 x = v & 0x7f; v >>= 7; if (v) x |= 0x80; b.append(char(x)); } while (v); return b; }
bool readVarint(const QByteArray &b, int &pos, quint64 &v) {
    v = 0; for (int shift = 0; pos < b.size() && shift < 64; shift += 7) { const quint8 x = quint8(b[pos++]); v |= quint64(x & 0x7f) << shift; if (!(x & 0x80)) return true; }
    return false;
}
QList<Field> decode(const QByteArray &b) {
    QList<Field> out; int pos = 0;
    while (pos < b.size()) {
        quint64 key; if (!readVarint(b, pos, key)) break;
        Field f{int(key >> 3), int(key & 7)};
        if (f.wt == 0) { if (!readVarint(b, pos, f.vi)) break; }
        else if (f.wt == 2) { quint64 len; if (!readVarint(b, pos, len) || pos + qint64(len) > b.size()) break; f.ld = b.mid(pos, int(len)); pos += int(len); }
        else if (f.wt == 5) { pos += 4; continue; }     // fixed32, unused here
        else if (f.wt == 1) { pos += 8; continue; }     // fixed64, unused here
        else break;
        out << f;
    }
    return out;
}
const Field *field(const QList<Field> &fs, int num) { for (const Field &f : fs) if (f.num == num) return &f; return nullptr; }
QByteArray fv(int num, quint64 v) { return varint(quint64(num) << 3) + varint(v); }                            // varint field
QByteArray fl(int num, const QByteArray &d) { return varint((quint64(num) << 3) | 2) + varint(quint64(d.size())) + d; }   // length-delimited field
QByteArray fs(int num, const QString &s) { return fl(num, s.toUtf8()); }

// OuterMessage (polo.proto): protocol_version=1, status=2 (200 OK), then one phase message.
QByteArray outer(int status, const QByteArray &phase = {}) { return fv(1, 2) + fv(2, quint64(status)) + phase; }
QByteArray frame(const QByteArray &msg) { return varint(quint64(msg.size())) + msg; }

// RSA public key modulus/exponent out of a certificate's SubjectPublicKeyInfo (DER): a four-level ASN.1 walk.
struct Asn { int tag = 0; QByteArray val; int next = 0; };
Asn asn(const QByteArray &d, int pos) {
    Asn a; if (pos + 2 > d.size()) return a; a.tag = quint8(d[pos]); int p = pos + 1; int len = quint8(d[p++]);
    if (len & 0x80) { const int n = len & 0x7f; len = 0; for (int i = 0; i < n && p < d.size(); ++i) len = (len << 8) | quint8(d[p++]); }
    a.val = d.mid(p, len); a.next = p + len; return a;
}
bool rsaParts(const QSslCertificate &c, QByteArray &modulus, QByteArray &exponent) {
    const QByteArray spki = c.publicKey().toDer();          // SEQUENCE { SEQUENCE { oid, null }, BIT STRING { SEQUENCE { INTEGER n, INTEGER e } } }
    const Asn seq = asn(spki, 0); if (seq.tag != 0x30) return false;
    const Asn alg = asn(seq.val, 0); const Asn bits = asn(seq.val, alg.next); if (bits.tag != 0x03 || bits.val.isEmpty()) return false;
    const Asn rsa = asn(bits.val, 1); if (rsa.tag != 0x30) return false;                       // skip the unused-bits byte
    const Asn n = asn(rsa.val, 0); const Asn e = asn(rsa.val, n.next); if (n.tag != 0x02 || e.tag != 0x02) return false;
    modulus = n.val; exponent = e.val;
    while (modulus.startsWith('\0')) modulus.remove(0, 1);  // the client hashes the big integers without leading zero bytes
    while (exponent.startsWith('\0')) exponent.remove(0, 1);
    return true;
}
const QHash<int, QString> KEYS = {   // Android key codes -> inputd names
    {19, "up"}, {20, "down"}, {21, "left"}, {22, "right"}, {23, "ok"}, {66, "ok"}, {4, "back"}, {3, "home"}, {82, "menu"},
    {85, "play"}, {126, "play"}, {127, "play"}, {24, "volup"}, {25, "voldown"}, {164, "mute"}, {84, "menu"},
};
constexpr int FEATURES = 639;   // what Google TV boxes answer in remote_configure.code1 (captures quoted by the client ports); verify on a phone
}

AtvRemote::AtvRemote(QObject *parent) : QObject(parent) {
    m_dir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/ottoman/atv";
    m_nam = new QNetworkAccessManager(this);
    m_ping.setInterval(5000);
    connect(&m_ping, &QTimer::timeout, this, [this] {
        for (auto it = m_conns.begin(); it != m_conns.end(); ++it)
            if (it.key()->localPort() == 6466 && it.value().configured) send(it.key(), fl(8, fv(1, quint64(++it.value().pings))));
    });
}

void AtvRemote::start() {
    if (!QSslSocket::supportsSsl()) { qWarning() << "atv: no TLS backend, remote server off"; return; }
    QDir().mkpath(m_dir);
    if (!ensureCertificate()) return;
    loadPaired();
    m_ssl = QSslConfiguration::defaultConfiguration();
    m_ssl.setPeerVerifyMode(QSslSocket::QueryPeer);       // ask for the phone's self-signed certificate, do not judge it
    m_ssl.setProtocol(QSsl::TlsV1_2OrLater);
    {
        QFile c(m_dir + "/server.crt"), k(m_dir + "/server.key"); c.open(QIODevice::ReadOnly); k.open(QIODevice::ReadOnly);
        m_ssl.setLocalCertificate(QSslCertificate(c.readAll()));
        m_ssl.setPrivateKey(QSslKey(k.readAll(), QSsl::Rsa));
        if (m_ssl.localCertificate().isNull() || m_ssl.privateKey().isNull()) { qWarning() << "atv: server certificate unreadable"; return; }
    }
    const bool a = listen(m_pairing, 6467, "pairing"), b = listen(m_remote, 6466, "remote");
    if (!(a && b)) return;
    connect(m_pairing, &QSslServer::pendingConnectionAvailable, this, [this] { while (auto *s = qobject_cast<QSslSocket *>(m_pairing->nextPendingConnection())) onPairingConnection(s); });
    connect(m_remote, &QSslServer::pendingConnectionAvailable, this, [this] { while (auto *s = qobject_cast<QSslSocket *>(m_remote->nextPendingConnection())) onRemoteConnection(s); });
    m_ping.start();
    publishMdns();
    m_running = true; emit runningChanged();
    qInfo() << "atv: Android TV remote server up (pairing 6467, remote 6466), paired phones:" << m_paired.size();
}

bool AtvRemote::ensureCertificate() {
    if (QFile::exists(m_dir + "/server.crt") && QFile::exists(m_dir + "/server.key")) return true;
    QProcess p;   // a 10-year self-signed RSA certificate, generated once per box (the client pins nothing; the pairing hash binds it)
    p.start("openssl", {"req", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256", "-days", "3650", "-subj", "/CN=Ottoman",
                        "-keyout", m_dir + "/server.key", "-out", m_dir + "/server.crt"});
    if (!p.waitForFinished(20000) || p.exitCode() != 0) { qWarning() << "atv: openssl req failed:" << p.readAllStandardError().left(200); return false; }
    QFile::setPermissions(m_dir + "/server.key", QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    qInfo() << "atv: generated the server certificate";
    return true;
}

bool AtvRemote::listen(QSslServer *&srv, quint16 port, const char *what) {
    srv = new QSslServer(this);
    srv->setSslConfiguration(m_ssl);
    srv->setHandshakeTimeout(10000);
    connect(srv, &QSslServer::errorOccurred, this, [what](QSslSocket *, QAbstractSocket::SocketError e) { qInfo() << "atv:" << what << "socket error" << e; });
    if (!srv->listen(QHostAddress::Any, port)) { qWarning() << "atv:" << what << "listen on" << port << "failed:" << srv->errorString(); return false; }
    return true;
}

void AtvRemote::readFrames(QSslSocket *s, void (AtvRemote::*handler)(QSslSocket *, const QByteArray &)) {
    Conn &c = m_conns[s]; c.buf += s->readAll();
    for (;;) {
        int pos = 0; quint64 len;
        if (!readVarint(c.buf, pos, len)) return;                    // length not complete yet
        if (len > 1 << 20) { qWarning() << "atv: absurd frame length, dropping the connection"; s->abort(); return; }
        if (pos + qint64(len) > c.buf.size()) return;                // body not complete yet
        const QByteArray msg = c.buf.mid(pos, int(len)); c.buf.remove(0, pos + int(len));
        (this->*handler)(s, msg);
        if (!m_conns.contains(s)) return;                            // handler closed it
    }
}

void AtvRemote::send(QSslSocket *s, const QByteArray &msg) { s->write(frame(msg)); }

// ---- pairing --------------------------------------------------------------------------------------------------------
void AtvRemote::onPairingConnection(QSslSocket *s) {
    m_conns.insert(s, {});
    connect(s, &QSslSocket::readyRead, this, [this, s] { readFrames(s, &AtvRemote::handlePairing); });
    connect(s, &QSslSocket::disconnected, this, [this, s] { if (m_conns.remove(s) && !m_code.isEmpty()) setCode(""); s->deleteLater(); });
    qInfo() << "atv: pairing connection from" << s->peerAddress().toString() << "cert" << !s->peerCertificate().isNull();
}

void AtvRemote::handlePairing(QSslSocket *s, const QByteArray &msg) {
    const QList<Field> fs_ = decode(msg);
    const Field *st = field(fs_, 2);
    if (st && st->vi != 200) { qInfo() << "atv: pairing peer reported status" << st->vi; s->disconnectFromHost(); return; }
    Conn &c = m_conns[s];
    if (const Field *req = field(fs_, 10)) {                                   // pairing_request{service_name, client_name}
        const QList<Field> r = decode(req->ld); if (const Field *n = field(r, 2)) c.clientName = QString::fromUtf8(n->ld);
        qInfo() << "atv: pairing request from" << c.clientName;
        send(s, outer(200, fl(11, fs(1, "Ottoman"))));                        // pairing_request_ack{server_name}
    } else if (field(fs_, 20)) {                                               // options -> our options: we OUTPUT a 6-char hex code
        send(s, outer(200, fl(20, fl(2, fv(1, 3) + fv(2, 6)) + fv(3, 2))));
    } else if (field(fs_, 30)) {                                               // configuration -> configuration_ack, then the code
        const QSslCertificate client = s->peerCertificate();
        if (client.isNull()) { qWarning() << "atv: pairing peer sent no certificate"; send(s, outer(401)); s->disconnectFromHost(); return; }
        QByteArray tail(2, 0);
        tail[0] = char(QRandomGenerator::system()->bounded(256)); tail[1] = char(QRandomGenerator::system()->bounded(256));
        c.hash = pairingHash(client, tail);
        if (c.hash.isEmpty()) { send(s, outer(400)); s->disconnectFromHost(); return; }
        send(s, outer(200, fl(31, QByteArray())));
        setCode((QByteArray(1, c.hash[0]) + tail).toHex().toUpper());        // first two characters check the hash, last four are the nonce
    } else if (const Field *sec = field(fs_, 40)) {                            // secret{secret} -> compare
        const QList<Field> r = decode(sec->ld); const Field *v = field(r, 1);
        if (!v || c.hash.isEmpty() || v->ld != c.hash) {
            qInfo() << "atv: pairing secret mismatch from" << c.clientName; send(s, outer(402)); s->disconnectFromHost(); setCode(""); return;
        }
        storePaired(s->peerCertificate(), c.clientName);
        send(s, outer(200, fl(41, fl(1, c.hash))));
        qInfo() << "atv: paired" << c.clientName; emit paired(c.clientName); setCode("");
    }
}

QByteArray AtvRemote::pairingHash(const QSslCertificate &client, const QByteArray &codeTail) const {
    QByteArray cm, ce, sm, se;
    if (!rsaParts(client, cm, ce) || !rsaParts(m_ssl.localCertificate(), sm, se)) { qWarning() << "atv: certificates are not RSA"; return {}; }
    // The client hashes hex strings: modulus as-is, exponent with a leading "0" (65537 -> 010001), i.e. one extra zero nibble;
    // for the usual odd-digit exponent that is the same bytes as the integer itself, which is what we hash here.
    QCryptographicHash h(QCryptographicHash::Sha256);
    h.addData(cm); h.addData(ce); h.addData(sm); h.addData(se); h.addData(codeTail);
    return h.result();
}

// The code goes to the journal too (root-readable only, single use, bound to the asking phone's certificate): it is what
// a driven test reads, and what a user who cannot see the TV can ask the box for.
void AtvRemote::setCode(const QString &c) { if (m_code == c) return; m_code = c; emit pairingCodeChanged(); if (!c.isEmpty()) qInfo().noquote() << "atv: pairing code" << c; }
void AtvRemote::cancelPairing() { for (auto it = m_conns.begin(); it != m_conns.end(); ++it) if (it.key()->localPort() == 6467) it.key()->disconnectFromHost(); setCode(""); }

void AtvRemote::loadPaired() {
    m_paired.clear();
    for (const QString &f : QDir(m_dir + "/clients").entryList({"*.pem"}, QDir::Files)) m_paired.insert(QByteArray::fromHex(f.section('.', 0, 0).toLatin1()));
    emit pairedCountChanged();
}
void AtvRemote::storePaired(const QSslCertificate &c, const QString &name) {
    const QByteArray d = c.digest(QCryptographicHash::Sha256);
    QDir().mkpath(m_dir + "/clients");
    QFile f(m_dir + "/clients/" + d.toHex() + ".pem");
    if (f.open(QIODevice::WriteOnly)) { f.write("# " + name.toUtf8() + "\n" + c.toPem()); }
    m_paired.insert(d); emit pairedCountChanged();
}
void AtvRemote::forgetAll() {
    QDir d(m_dir + "/clients"); for (const QString &f : d.entryList({"*.pem"}, QDir::Files)) d.remove(f);
    loadPaired(); qInfo() << "atv: forgot every paired phone";
}

// ---- remote channel -------------------------------------------------------------------------------------------------
void AtvRemote::onRemoteConnection(QSslSocket *s) {
    const QSslCertificate c = s->peerCertificate();
    if (c.isNull() || !m_paired.contains(c.digest(QCryptographicHash::Sha256))) {
        qInfo() << "atv: remote connection from" << s->peerAddress().toString() << "is not paired, closing"; s->disconnectFromHost(); s->deleteLater(); return;
    }
    m_conns.insert(s, {});
    connect(s, &QSslSocket::readyRead, this, [this, s] { readFrames(s, &AtvRemote::handleRemote); });
    connect(s, &QSslSocket::disconnected, this, [this, s] { m_conns.remove(s); s->deleteLater(); qInfo() << "atv: remote disconnected"; });
    qInfo() << "atv: remote connected from" << s->peerAddress().toString();
    // The TV speaks first: remote_configure{code1, device_info}, the client answers with its own.
    send(s, fl(1, fv(1, FEATURES) + fl(2, fs(1, "Ottoman") + fs(2, "Ottoman") + fv(3, 1) + fs(4, "1") + fs(5, "ottoman") + fs(6, "1.0"))));
}

void AtvRemote::handleRemote(QSslSocket *s, const QByteArray &msg) {
    const QList<Field> fs_ = decode(msg); Conn &c = m_conns[s];
    if (field(fs_, 1)) {                                                       // client's remote_configure -> set_active, start
        send(s, fl(2, fv(1, FEATURES)));
        send(s, fl(40, fv(1, 1)));
        c.configured = true;
    } else if (field(fs_, 2)) {                                                // remote_set_active ack: nothing to do
    } else if (const Field *p = field(fs_, 8)) {                               // the client may ping too: answer with val1
        const QList<Field> r = decode(p->ld); const Field *v = field(r, 1); send(s, fl(9, fv(1, v ? v->vi : 0)));
    } else if (field(fs_, 9)) {                                                // pong
    } else if (const Field *k = field(fs_, 10)) {                              // remote_key_inject{key_code, direction}
        const QList<Field> r = decode(k->ld); const Field *code = field(r, 1); const Field *dir = field(r, 2);
        const int kc = code ? int(code->vi) : 0, d = dir ? int(dir->vi) : 3;
        const QString name = KEYS.value(kc);
        if (name.isEmpty()) { qInfo() << "atv: unmapped key" << kc; return; }
        if (d == 2) return;                                                    // END_LONG: the START_LONG already sent a held press
        forwardKey(name, d == 1 ? 800 : 0);
    } else if (field(fs_, 3)) { qInfo() << "atv: remote_error from the phone"; }
}

void AtvRemote::forwardKey(const QString &name, int holdMs) {
    QNetworkRequest req(QUrl(QString("http://127.0.0.1:18820/key?name=%1%2").arg(name, holdMs ? QString("&hold=%1").arg(holdMs) : QString())));
    QNetworkReply *r = m_nam->post(req, QByteArray());
    connect(r, &QNetworkReply::finished, this, [this, r, name] { if (r->error()) qWarning() << "atv: inputd refused" << name << r->errorString(); else emit keyReceived(name); r->deleteLater(); });
}

// ---- discovery: avahi over D-Bus (avahi-daemon is enabled in the image; the shell has QtDBus already) ---------------
void AtvRemote::publishMdns() {
    QString mac;
    for (const QNetworkInterface &i : QNetworkInterface::allInterfaces())
        if (!(i.flags() & QNetworkInterface::IsLoopBack) && !i.hardwareAddress().isEmpty() && i.hardwareAddress() != "00:00:00:00:00:00") { mac = i.hardwareAddress(); break; }
    QDBusInterface server("org.freedesktop.Avahi", "/", "org.freedesktop.Avahi.Server", QDBusConnection::systemBus());
    if (!server.isValid()) { qWarning() << "atv: avahi not on the system bus, the phone will not find this box by itself"; return; }
    QDBusReply<QDBusObjectPath> group = server.call("EntryGroupNew");
    if (!group.isValid()) { qWarning() << "atv: avahi EntryGroupNew failed:" << group.error().message(); return; }
    QDBusInterface eg("org.freedesktop.Avahi", group.value().path(), "org.freedesktop.Avahi.EntryGroup", QDBusConnection::systemBus());
    qDBusRegisterMetaType<QList<QByteArray>>();                       // avahi's TXT argument is "aay"
    QList<QByteArray> txt; txt << ("bt=" + mac.toUtf8());
    QDBusMessage r = eg.call("AddService", int(-1), int(-1), uint(0), QHostInfo::localHostName(), QStringLiteral("_androidtvremote2._tcp"),
                             QString(), QString(), QVariant::fromValue<quint16>(6466), QVariant::fromValue(txt));   // "q": a bare quint16 arrives as int
    if (r.type() == QDBusMessage::ErrorMessage) { qWarning() << "atv: avahi AddService failed:" << r.errorMessage(); return; }
    r = eg.call("Commit");
    if (r.type() == QDBusMessage::ErrorMessage) { qWarning() << "atv: avahi Commit failed:" << r.errorMessage(); return; }
    qInfo() << "atv: mDNS _androidtvremote2._tcp published as" << QHostInfo::localHostName() << "bt" << mac;
}
