#ifndef LOCALSTORE_HPP
#define LOCALSTORE_HPP

#include <QList>
#include <QString>
#include <QVariantList>

// Lokaler Verlauf und Ausgangskorb. Eine SQLite-Datei im Home der App.
struct OutItem {
    QString id;
    QString kind;        // post, file, react, unreact
    QString channelId;
    QString rootId;
    QString postId;
    QString emoji;
    QString message;
    QString filePath;
    QString fileName;    // Originalname, nicht der Cache-Dateiname
};

class LocalStore
{
public:
    bool open();
    bool isOpen() const;
    void clear();

    void saveChannels(const QVariantList &rows);
    QVariantList channels() const;
    void savePosts(const QString &channelId, const QVariantList &rows);
    QVariantList posts(const QString &channelId) const;
    void saveThread(const QString &rootId, const QVariantList &rows);
    QVariantList thread(const QString &rootId) const;

    void saveUser(const QString &id, const QString &label, const QString &username);
    QVariantList users() const;

    void enqueue(const OutItem &item);
    QList<OutItem> outbox() const;
    void remove(const QString &id);

private:
    void saveBlob(const QString &key, const QVariantList &rows);
    QVariantList loadBlob(const QString &key) const;
};

#endif
