#ifndef MMSOCKET_HPP
#define MMSOCKET_HPP

#include <QAbstractSocket>
#include <QByteArray>
#include <QObject>
#include <QString>

class QSslSocket;

// Mattermost-Websocket über QSslSocket. Qt 4.8 hat keinen Websocket-Client.
// Die Verbindung bleibt für die Sitzung offen und trägt die Schreibanzeige.
class MmSocket : public QObject
{
    Q_OBJECT
public:
    explicit MmSocket(QObject *parent = 0);
    void open(const QString &serverUrl, const QString &token);
    void close();
    bool ready() const { return m_state == Open; }
    void sendTyping(const QString &channelId, const QString &parentId);

signals:
    void ready();
    void failed();
    void typing(const QString &channelId, const QString &userId, const QString &parentId);
    void dialog(const QString &json);
    void posted(const QString &channelId);

private slots:
    void onConnected();
    void onEncrypted();
    void onReadyRead();
    void onError(QAbstractSocket::SocketError);
    void onDisconnected();

private:
    enum State { Idle, Connecting, Open };

    void fail();
    void writeUpgrade();
    void sendFrame(unsigned char opcode, const QByteArray &payload);
    void sendText(const QByteArray &payload);
    void pump();
    void handleText(const QByteArray &payload);

    QSslSocket *m_sock;
    State m_state;
    bool m_plain;
    bool m_upgraded;
    bool m_sentUpgrade;
    int m_seq;
    QString m_token;
    QString m_host;
    int m_port;
    QByteArray m_buf;
    QByteArray m_frag;
    unsigned char m_fragOp;
};

#endif
