#include "MmSocket.hpp"

#include <QDateTime>
#include <QSslConfiguration>
#include <QSslSocket>
#include <QUrl>
#include <QVariantMap>

#include <bb/data/JsonDataAccess>

using bb::data::JsonDataAccess;

MmSocket::MmSocket(QObject *parent)
    : QObject(parent),
      m_sock(new QSslSocket(this)),
      m_state(Idle),
      m_plain(false),
      m_upgraded(false),
      m_sentUpgrade(false),
      m_seq(0),
      m_port(443),
      m_fragOp(0)
{
    connect(m_sock, SIGNAL(connected()), this, SLOT(onConnected()));
    connect(m_sock, SIGNAL(encrypted()), this, SLOT(onEncrypted()));
    connect(m_sock, SIGNAL(readyRead()), this, SLOT(onReadyRead()));
    connect(m_sock, SIGNAL(error(QAbstractSocket::SocketError)),
            this, SLOT(onError(QAbstractSocket::SocketError)));
    connect(m_sock, SIGNAL(disconnected()), this, SLOT(onDisconnected()));
}

void MmSocket::open(const QString &serverUrl, const QString &token)
{
    QUrl url(serverUrl);
    QString host = url.host();
    if (host.isEmpty() || token.isEmpty()) {
        fail();
        return;
    }
    const bool plain = url.scheme() == QLatin1String("http");
    int port = url.port();
    if (port < 1)
        port = plain ? 80 : 443;
    if (m_state != Idle && m_host == host && m_port == port && m_token == token && m_plain == plain)
        return;
    close();
    m_token = token;
    m_host = host;
    m_port = port;
    m_plain = plain;
    m_state = Connecting;
    m_seq = 0;
    qsrand((uint)QDateTime::currentMSecsSinceEpoch());
    QSslConfiguration ssl = QSslConfiguration::defaultConfiguration();
    ssl.setPeerVerifyMode(QSslSocket::VerifyPeer);
    m_sock->setSslConfiguration(ssl);
    if (plain)
        m_sock->connectToHost(host, port);
    else
        m_sock->connectToHostEncrypted(host, port);
}

void MmSocket::close()
{
    m_state = Idle;
    m_upgraded = false;
    m_sentUpgrade = false;
    m_buf.clear();
    m_frag.clear();
    m_fragOp = 0;
    m_sock->blockSignals(true);
    if (m_sock->state() != QAbstractSocket::UnconnectedState)
        m_sock->abort();
    m_sock->blockSignals(false);
}

void MmSocket::fail()
{
    if (m_state == Idle && !m_upgraded)
        return;
    close();
    emit failed();
}

void MmSocket::onConnected()
{
    if (m_plain)
        onEncrypted();
}

void MmSocket::onEncrypted()
{
    if (m_state != Connecting || m_sentUpgrade)
        return;
    writeUpgrade();
}

void MmSocket::writeUpgrade()
{
    m_sentUpgrade = true;
    QByteArray raw(16, 0);
    for (int i = 0; i < raw.size(); ++i)
        raw[i] = (char)(qrand() & 0xff);
    const QByteArray key = raw.toBase64();
    QString host = m_host;
    if (!((m_plain && m_port == 80) || (!m_plain && m_port == 443)))
        host += QString(":%1").arg(m_port);
    QByteArray req;
    req += "GET /api/v4/websocket HTTP/1.1\r\n";
    req += "Host: " + host.toUtf8() + "\r\n";
    req += "Upgrade: websocket\r\n";
    req += "Connection: Upgrade\r\n";
    req += "Sec-WebSocket-Key: " + key + "\r\n";
    req += "Sec-WebSocket-Version: 13\r\n";
    req += "Authorization: Bearer " + m_token.toUtf8() + "\r\n";
    req += "\r\n";
    m_sock->write(req);
}

void MmSocket::sendTyping(const QString &channelId, const QString &parentId)
{
    if (m_state != Open || channelId.isEmpty())
        return;
    QVariantMap data;
    data["channel_id"] = channelId;
    data["parent_id"] = parentId;
    QVariantMap msg;
    msg["seq"] = ++m_seq;
    msg["action"] = QString("user_typing");
    msg["data"] = data;
    QByteArray bytes;
    JsonDataAccess json;
    json.saveToBuffer(msg, &bytes);
    sendText(bytes);
}

void MmSocket::sendText(const QByteArray &payload)
{
    sendFrame(0x1, payload);
}

void MmSocket::sendFrame(unsigned char opcode, const QByteArray &payload)
{
    if (m_sock->state() != QAbstractSocket::ConnectedState)
        return;
    QByteArray frame;
    frame.append((char)(0x80 | opcode));
    const int n = payload.size();
    if (n < 126) {
        frame.append((char)(0x80 | n));
    } else {
        frame.append((char)(0x80 | 126));
        frame.append((char)((n >> 8) & 0xff));
        frame.append((char)(n & 0xff));
    }
    unsigned char mask[4];
    for (int i = 0; i < 4; ++i)
        mask[i] = (unsigned char)(qrand() & 0xff);
    frame.append((char)mask[0]);
    frame.append((char)mask[1]);
    frame.append((char)mask[2]);
    frame.append((char)mask[3]);
    for (int i = 0; i < n; ++i)
        frame.append((char)(payload.at(i) ^ mask[i % 4]));
    m_sock->write(frame);
}

void MmSocket::onReadyRead()
{
    m_buf += m_sock->readAll();
    pump();
}

void MmSocket::pump()
{
    if (!m_upgraded) {
        const int mark = m_buf.indexOf("\r\n\r\n");
        if (mark < 0) {
            if (m_buf.size() > 8192)
                fail();
            return;
        }
        const QByteArray head = m_buf.left(mark);
        m_buf.remove(0, mark + 4);
        if (!head.startsWith("HTTP/1.1 101") && !head.startsWith("HTTP/1.0 101")) {
            fail();
            return;
        }
        m_upgraded = true;
        m_state = Open;
        QVariantMap data;
        data["token"] = m_token;
        QVariantMap msg;
        msg["seq"] = ++m_seq;
        msg["action"] = QString("authentication_challenge");
        msg["data"] = data;
        QByteArray bytes;
        JsonDataAccess json;
        json.saveToBuffer(msg, &bytes);
        sendText(bytes);
        emit ready();
    }
    while (m_upgraded && m_state == Open) {
        if (m_buf.size() < 2)
            return;
        const unsigned char b0 = (unsigned char)m_buf.at(0);
        const unsigned char b1 = (unsigned char)m_buf.at(1);
        const bool fin = (b0 & 0x80) != 0;
        const unsigned char op = b0 & 0x0f;
        const bool masked = (b1 & 0x80) != 0;
        quint64 len = b1 & 0x7f;
        int hdr = 2;
        if (len == 126) {
            if (m_buf.size() < 4)
                return;
            len = ((unsigned char)m_buf.at(2) << 8) | (unsigned char)m_buf.at(3);
            hdr = 4;
        } else if (len == 127) {
            if (m_buf.size() < 10)
                return;
            len = 0;
            for (int i = 0; i < 8; ++i)
                len = (len << 8) | (unsigned char)m_buf.at(2 + i);
            hdr = 10;
        }
        if (len > 262144) {
            fail();
            return;
        }
        const int maskAt = hdr;
        if (masked)
            hdr += 4;
        if ((quint64)m_buf.size() < (quint64)hdr + len)
            return;
        QByteArray payload = m_buf.mid(hdr, (int)len);
        if (masked) {
            for (int i = 0; i < payload.size(); ++i)
                payload[i] = payload.at(i) ^ m_buf.at(maskAt + (i % 4));
        }
        m_buf.remove(0, hdr + (int)len);
        if (op == 0x0 || op == 0x1) {
            m_frag.append(payload);
            if (op != 0x0)
                m_fragOp = op;
            if (fin) {
                if (m_fragOp == 0x1)
                    handleText(m_frag);
                m_frag.clear();
                m_fragOp = 0;
            }
        } else if (op == 0x8) {
            fail();
            return;
        } else if (op == 0x9) {
            sendFrame(0xA, payload);
        }
    }
}

void MmSocket::handleText(const QByteArray &payload)
{
    JsonDataAccess json;
    const QVariant parsed = json.loadFromBuffer(payload);
    if (json.hasError())
        return;
    const QVariantMap msg = parsed.toMap();
    // Interaktive Dialoge kommen als JSON-Text im Feld "dialog".
    if (msg.value("event").toString() == QLatin1String("open_dialog")) {
        emit dialog(msg.value("data").toMap().value("dialog").toString());
        return;
    }
    if (msg.value("event").toString() != QLatin1String("typing"))
        return;
    const QVariantMap data = msg.value("data").toMap();
    const QVariantMap broadcast = msg.value("broadcast").toMap();
    const QString userId = data.value("user_id").toString();
    QString channelId = broadcast.value("channel_id").toString();
    if (channelId.isEmpty())
        channelId = data.value("channel_id").toString();
    emit typing(channelId, userId, data.value("parent_id").toString());
}

void MmSocket::onError(QAbstractSocket::SocketError)
{
    if (m_state == Idle)
        return;
    fail();
}

void MmSocket::onDisconnected()
{
    if (m_state == Idle)
        return;
    fail();
}
