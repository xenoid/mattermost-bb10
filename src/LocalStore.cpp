#include "LocalStore.hpp"

#include <bb/data/JsonDataAccess>

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantMap>

namespace {

const char *kConn = "mm";

QString dbPath()
{
    return QDir::homePath() + "/mm.db";
}

QSqlDatabase db()
{
    return QSqlDatabase::database(kConn, false);
}

QString toJson(const QVariantList &rows)
{
    QByteArray bytes;
    bb::data::JsonDataAccess json;
    json.saveToBuffer(rows, &bytes);
    return QString::fromUtf8(bytes);
}

QVariantList fromJson(const QString &text)
{
    if (text.isEmpty())
        return QVariantList();
    bb::data::JsonDataAccess json;
    const QByteArray bytes = text.toUtf8();
    const QVariant parsed = json.loadFromBuffer(bytes);
    if (json.hasError())
        return QVariantList();
    return parsed.toList();
}

}

bool LocalStore::open()
{
    if (QSqlDatabase::contains(kConn) && db().isOpen())
        return true;
    if (QSqlDatabase::contains(kConn))
        QSqlDatabase::removeDatabase(kConn);
    QSqlDatabase database = QSqlDatabase::addDatabase("QSQLITE", kConn);
    database.setDatabaseName(dbPath());
    if (!database.open())
        return false;
    QSqlQuery query(database);
    query.exec("CREATE TABLE IF NOT EXISTS blobs (k TEXT PRIMARY KEY, v TEXT)");
    query.exec("CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, label TEXT, username TEXT)");
    query.exec("CREATE TABLE IF NOT EXISTS outbox ("
               "id TEXT PRIMARY KEY, kind TEXT, channel_id TEXT, root_id TEXT, "
               "post_id TEXT, emoji TEXT, message TEXT, file_path TEXT, created INTEGER)");
    query.exec("ALTER TABLE outbox ADD COLUMN file_name TEXT");
    query.exec("PRAGMA busy_timeout=3000");
    return true;
}

bool LocalStore::isOpen() const
{
    return QSqlDatabase::contains(kConn) && db().isOpen();
}

void LocalStore::clear()
{
    if (!isOpen()) {
        QFile::remove(dbPath());
        return;
    }
    QSqlQuery query(db());
    query.exec("DELETE FROM blobs");
    query.exec("DELETE FROM users");
    query.exec("DELETE FROM outbox");
}

void LocalStore::saveBlob(const QString &key, const QVariantList &rows)
{
    if (!isOpen())
        return;
    QSqlQuery query(db());
    query.prepare("INSERT OR REPLACE INTO blobs (k, v) VALUES (?, ?)");
    query.addBindValue(key);
    query.addBindValue(toJson(rows));
    query.exec();
}

QVariantList LocalStore::loadBlob(const QString &key) const
{
    if (!isOpen())
        return QVariantList();
    QSqlQuery query(db());
    query.prepare("SELECT v FROM blobs WHERE k = ?");
    query.addBindValue(key);
    if (!query.exec() || !query.next())
        return QVariantList();
    return fromJson(query.value(0).toString());
}

void LocalStore::saveChannels(const QVariantList &rows)
{
    saveBlob("channels", rows);
}

QVariantList LocalStore::channels() const
{
    return loadBlob("channels");
}

void LocalStore::savePosts(const QString &channelId, const QVariantList &rows)
{
    saveBlob("posts:" + channelId, rows);
}

QVariantList LocalStore::posts(const QString &channelId) const
{
    return loadBlob("posts:" + channelId);
}

void LocalStore::saveThread(const QString &rootId, const QVariantList &rows)
{
    saveBlob("thread:" + rootId, rows);
}

QVariantList LocalStore::thread(const QString &rootId) const
{
    return loadBlob("thread:" + rootId);
}

void LocalStore::saveUser(const QString &id, const QString &label, const QString &username)
{
    if (!isOpen() || id.isEmpty())
        return;
    QSqlQuery query(db());
    query.prepare("INSERT OR REPLACE INTO users (id, label, username) VALUES (?, ?, ?)");
    query.addBindValue(id);
    query.addBindValue(label);
    query.addBindValue(username);
    query.exec();
}

QVariantList LocalStore::users() const
{
    QVariantList list;
    if (!isOpen())
        return list;
    QSqlQuery query(db());
    if (!query.exec("SELECT id, label, username FROM users"))
        return list;
    while (query.next()) {
        QVariantMap row;
        row["id"] = query.value(0).toString();
        row["label"] = query.value(1).toString();
        row["username"] = query.value(2).toString();
        list.append(row);
    }
    return list;
}

void LocalStore::enqueue(const OutItem &item)
{
    if (!isOpen() || item.id.isEmpty())
        return;
    QSqlQuery query(db());
    query.prepare("INSERT OR REPLACE INTO outbox "
                  "(id, kind, channel_id, root_id, post_id, emoji, message, file_path, file_name, created) "
                  "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    query.addBindValue(item.id);
    query.addBindValue(item.kind);
    query.addBindValue(item.channelId);
    query.addBindValue(item.rootId);
    query.addBindValue(item.postId);
    query.addBindValue(item.emoji);
    query.addBindValue(item.message);
    query.addBindValue(item.filePath);
    query.addBindValue(item.fileName);
    query.addBindValue(QDateTime::currentMSecsSinceEpoch());
    query.exec();
}

QList<OutItem> LocalStore::outbox() const
{
    QList<OutItem> list;
    if (!isOpen())
        return list;
    QSqlQuery query(db());
    if (!query.exec("SELECT id, kind, channel_id, root_id, post_id, emoji, message, file_path, file_name "
                    "FROM outbox ORDER BY created"))
        return list;
    while (query.next()) {
        OutItem item;
        item.id = query.value(0).toString();
        item.kind = query.value(1).toString();
        item.channelId = query.value(2).toString();
        item.rootId = query.value(3).toString();
        item.postId = query.value(4).toString();
        item.emoji = query.value(5).toString();
        item.message = query.value(6).toString();
        item.filePath = query.value(7).toString();
        item.fileName = query.value(8).toString();
        list.append(item);
    }
    return list;
}

void LocalStore::remove(const QString &id)
{
    if (!isOpen() || id.isEmpty())
        return;
    QSqlQuery query(db());
    query.prepare("DELETE FROM outbox WHERE id = ?");
    query.addBindValue(id);
    query.exec();
}
