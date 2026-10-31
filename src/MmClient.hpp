#ifndef MMCLIENT_HPP
#define MMCLIENT_HPP

#include "LocalStore.hpp"

#include <QDate>
#include <QDateTime>
#include <QHash>
#include <QList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QSet>
#include <QSslError>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

namespace bb { namespace system { class InvokeManager; class InvokeRequest; } }

// Fassade für die QML-Oberfläche: Anmeldung, Mattermost-API v4, Bild-Cache.
// Alles Netz läuft über einen einzigen QNetworkAccessManager.
class MmClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loggedIn READ loggedIn NOTIFY loggedInChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString serverUrl READ serverUrl NOTIFY sessionChanged)
    Q_PROPERTY(QString username READ username NOTIFY sessionChanged)
    Q_PROPERTY(QString channelId READ channelId NOTIFY channelChanged)
    Q_PROPERTY(QString channelName READ channelName NOTIFY channelChanged)
    Q_PROPERTY(QString teamName READ teamName NOTIFY sessionChanged)
    Q_PROPERTY(QString iconSend READ iconSend CONSTANT)
    Q_PROPERTY(QString iconSearch READ iconSearch CONSTANT)
    Q_PROPERTY(QString iconPlus READ iconPlus CONSTANT)
    Q_PROPERTY(QString iconEmoji READ iconEmoji CONSTANT)
    Q_PROPERTY(QString iconBack READ iconBack CONSTANT)
    Q_PROPERTY(QString iconSettings READ iconSettings CONSTANT)
    Q_PROPERTY(int teamCount READ teamCount NOTIFY sessionChanged)
    Q_PROPERTY(bool hasOlder READ hasOlder NOTIFY historyChanged)
    Q_PROPERTY(bool hasNewer READ hasNewer NOTIFY historyChanged)
    Q_PROPERTY(bool showPreview READ showPreview WRITE setShowPreview NOTIFY prefsChanged)
    Q_PROPERTY(bool showImages READ showImages WRITE setShowImages NOTIFY prefsChanged)
    Q_PROPERTY(bool clock24 READ clock24 WRITE setClock24 NOTIFY prefsChanged)
    Q_PROPERTY(bool notifyHub READ notifyHub WRITE setNotifyHub NOTIFY prefsChanged)
    Q_PROPERTY(bool notifyMentions READ notifyMentions WRITE setNotifyMentions NOTIFY prefsChanged)
    Q_PROPERTY(bool debugLog READ debugLog WRITE setDebugLog NOTIFY prefsChanged)
    Q_PROPERTY(bool trustReady READ trustReady CONSTANT)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)

public:
    explicit MmClient(QObject *parent = 0);

    bool loggedIn() const { return m_loggedIn; }
    QString status() const { return m_status; }
    QString serverUrl() const { return m_serverUrl; }
    QString username() const { return m_username; }
    QString channelId() const { return m_channelId; }
    QString channelName() const { return m_channelName; }
    QString teamName() const { return m_teamName; }
    QString iconSend() const { return m_iconSend; }
    QString iconSearch() const { return m_iconSearch; }
    QString iconPlus() const { return m_iconPlus; }
    QString iconEmoji() const { return m_iconEmoji; }
    QString iconBack() const { return m_iconBack; }
    QString iconSettings() const { return m_iconSettings; }
    int teamCount() const { return m_teamChoices.size(); }
    bool hasOlder() const { return m_hasOlder; }
    bool hasNewer() const { return m_hasNewer; }
    bool showPreview() const { return m_showPreview; }
    bool showImages() const { return m_showImages; }
    bool clock24() const { return m_clock24; }
    bool notifyHub() const { return m_notifyHub; }
    bool notifyMentions() const { return m_notifyMentions; }
    bool debugLog() const { return m_debugLog; }
    bool trustReady() const { return m_trustReady; }
    QString appVersion() const;
    void setShowPreview(bool on);
    void setShowImages(bool on);
    void setClock24(bool on);
    void setNotifyHub(bool on);
    void setNotifyMentions(bool on);
    void setDebugLog(bool on);
    bool headlessLaunch() const;

    Q_INVOKABLE void login(const QString &serverUrl, const QString &user, const QString &password);
    Q_INVOKABLE void submitMfa(const QString &code);
    Q_INVOKABLE void cancelMfa();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void selectTeam(const QString &id);
    Q_INVOKABLE QVariantList teamChoices() const;
    Q_INVOKABLE void openChannel(const QString &id, const QString &name);
    Q_INVOKABLE void openAt(const QString &id, const QString &name, const QString &postId);
    Q_INVOKABLE void nudgeFocus();
    Q_INVOKABLE void loadOlder();
    Q_INVOKABLE void loadNewer();
    Q_INVOKABLE void closeChannel();
    Q_INVOKABLE void sendMessage(const QString &text);
    Q_INVOKABLE void sendReply(const QString &rootId, const QString &text);
    Q_INVOKABLE bool attachFile(const QString &path, const QString &message, const QString &rootId,
                                const QString &displayName);
    Q_INVOKABLE QString stageFile(const QString &path);
    Q_INVOKABLE void dropStaged(const QString &path);
    Q_INVOKABLE bool fileIsImage(const QString &path) const;
    Q_INVOKABLE void toggleReaction(const QString &postId, const QString &emojiName);
    Q_INVOKABLE void askReplies(const QString &rootId);
    Q_INVOKABLE void askReact(const QString &postId);
    Q_INVOKABLE void editPost(const QString &postId, const QString &message);
    Q_INVOKABLE void deletePost(const QString &postId);
    Q_INVOKABLE void pinPost(const QString &postId);
    Q_INVOKABLE void savePost(const QString &postId);
    Q_INVOKABLE void openThread(const QString &rootId);
    Q_INVOKABLE void closeThread();
    Q_INVOKABLE void showCached();
    Q_INVOKABLE QVariantList emojiChoices() const;
    Q_INVOKABLE QVariantList emojiCatalog(const QString &query) const;
    Q_INVOKABLE void loadCustomEmoji();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void search(const QString &terms);
    Q_INVOKABLE void openFromSearch(const QString &id, const QString &name, const QString &postId);
    Q_INVOKABLE void openImage(const QString &fileId);
    Q_INVOKABLE void openAttachment(const QString &fileId, const QString &name, const QString &mime);
    Q_INVOKABLE void openLink(const QString &url);
    void enterHeadless();
    static void deferUntilLoop();

public slots:
    void onForeground();
    void onBackground();

signals:
    void loggedInChanged();
    void statusChanged();
    void sessionChanged();
    void channelChanged();
    void channelsLoaded(const QVariantList &channels);
    void postsLoaded(const QVariantList &posts);
    void repliesLoaded(const QVariantList &posts);
    void searchLoaded(const QVariantList &rows);
    void repliesRequested(const QString &rootId);
    void reactRequested(const QString &postId);
    void threadRequested(const QString &id, const QString &name, const QString &postId);
    void focusNudge();
    void mfaRequired();
    void chooseTeam();
    void historyChanged();
    void imageReady(const QString &fileId, const QString &path);
    void emojiReady(const QString &name, const QString &path);
    void customEmojiChanged();
    void avatarReady(const QString &userId, const QString &path);
    void showImage(const QString &path);
    void sendFailed(const QString &text);
    void inboxRequested(const QString &id, const QString &name);
    void prefsChanged();

private slots:
    void onFinished(QNetworkReply *reply);
    void onTick();
    void abortTimedOut();
    void noteSsl(const QList<QSslError> &errs);
    void onInvoked(const bb::system::InvokeRequest &request);
    void flushInbox();
    void bootHeadless();
    void emitFocusNudge();

private:
    enum Step {
        StepNone = 0,
        StepLogin,
        StepMe,
        StepTeams,
        StepChannels,
        StepMembers,
        StepChannelUsers,
        StepPosts,
        StepUsers,
        StepSend,
        StepView,
        StepSearch,
        StepSearchUsers,
        StepThread,
        StepThreadUsers,
        StepReact,
        StepUpload,
        StepFile,
        StepPost,
        StepEmojiList,
        StepPreview,
        StepMutate,
        StepFlagged
    };

    enum FileKind {
        FilePreview = 0,   // Vorschaubild in der Nachricht
        FileFull,          // Original für die Bildansicht
        FileAvatar,        // Profilbild
        FileAttach,        // sonstiger Anhang
        FileEmoji,         // Bild eines Server-Emoji
        FileEmojiName      // Name → Id, danach das Bild
    };

    struct CustomEmoji {
        QString id;
        QString name;
    };

    struct FileJob {
        FileKind kind;
        QString id;        // Datei-ID, bei Profilbildern die Nutzer-ID
        QString name;      // nur Anhänge
        QString mime;      // nur Anhänge
        int attempt;
    };

    struct UserInfo {
        QString label;
        QString username;
    };

    // Netz
    QNetworkRequest makeRequest(const QString &path) const;
    QNetworkReply *start(Step step, const QString &path, const QByteArray &body = QByteArray(),
                         const QByteArray &verb = "GET", bool silent = false, int timeoutMs = 25000);
    void setStatus(const QString &text);
    void setLoggedIn(bool on);
    void failed(Step step, bool silent, int http, int netCode);
    void armAbort(QNetworkReply *reply, int timeoutMs);

    // Sitzung und Listen
    void loadMe();
    void loadFlagged();
    void enqueueMutate(const QString &kind, const QString &postId, const QString &message);
    bool flagOn(const QString &postId, const QString &key) const;
    void paintFlag(const QString &postId, const QString &key, const QString &value);
    void dropPost(const QString &postId);
    void loadTeams();
    void loadChannels(bool silent);
    void loadPosts(bool silent);
    void loadAround(const QString &postId);
    void loadTrust();
    void armHubTimer();
    void disarmHubTimer();
    void quitIfHeadless();
    void offerTeams(const QVariantList &teams);
    void applyTeam(const QString &id, const QString &name);
    void absorbAround(const QString &page, const QVariant &parsed);
    void finishAround();
    bool aroundMatches(const QNetworkReply *reply) const;
    void postsIdle();
    void commitPosts(bool mark);
    void mergePosts(const QString &mode, const QVariantList &order, const QVariantMap &posts);
    void setHistory(bool older, bool newer);
    QString edgePostId(bool newest) const;
    void loadThread(bool silent);
    void loadUsers(const QStringList &ids, Step step);
    QStringList unknownUsers(const QStringList &ids) const;
    void learnUsers(const QVariantList &users);
    void markRead(const QString &channelId);
    void resetSession();
    void partDone();
    void finishChannels();
    void syncInbox();
    void postInbox(const QString &channelId, const QString &title, int unread, int mentions, bool alert);
    void queuePreviews();
    void applyPreview(const QString &channelId, const QVariant &parsed);
    void clearInbox(const QString &channelId);
    void finishPosts();
    void finishThread();
    void finishSearch();
    void ensureStore();
    void publishPosts();
    void publishThread();
    QVariantList withPending(const QVariantList &rows, bool inThread) const;
    QVariantMap pendingRow(const struct OutItem &item, bool inThread) const;
    bool ownsReaction(const QString &postId, const QString &emojiName) const;
    void submit(const QString &channelId, const QString &rootId, const QString &message,
                const QString &filePath, const QString &fileName);
    void flushOutbox();
    void sendOut(const struct OutItem &item);
    void startUpload(const struct OutItem &item);
    void outgoingDone(const QString &localId, bool ok, bool network, const QString &message);
    void ackOutbox(const QVariantList &rows);

    // Zeilen für die Oberfläche
    QVariantList buildConversation(const QVariantList &order, const QVariantMap &posts,
                                   bool inThread, QStringList &userIds);
    QVariantMap makePostRow(const QVariantMap &post, const QVariantMap &all, bool inThread = false);
    void decorate(QVariantMap &row) const;
    QString personLabel(const QVariantMap &user) const;
    QString nameOf(const QString &userId) const;

    // Dateien
    void queuePreview(const QString &fileId);
    void queueAvatar(const QString &userId);
    void queueEmoji(const QString &emojiId, const QString &name);
    void queueEmojiName(const QString &name);
    void takeEmojiPage(const QVariantList &list);
    void queueJob(const FileJob &job, bool front);
    void pumpFiles();
    void startJob(const FileJob &job);
    void finishFile(int kind, const QString &id, const QString &name, const QString &mime,
                    int attempt, const QString &savePath, int http, const QByteArray &payload);
    void storeAvatar(const QString &userId, const QString &url);
    void storePreview(const QString &fileId, const QString &url);
    void storeEmoji(const QString &name, const QString &url);
    void openFile(const QString &path, const QString &mime);

    // Hilfen
    QString repairText(const QString &in) const;
    QString normalizeUrl(QString url) const;
    QString shortWhen(qint64 ms) const;
    QString clockTime(const QDateTime &dt) const;
    QString dayLabel(const QDate &day) const;
    QString channelTitle(const QString &id) const;
    QString firstUrl(const QString &message, bool *linkOnly) const;
    QString sizeText(qint64 bytes) const;

    QNetworkAccessManager m_net;
    QTimer m_timer;
    bb::system::InvokeManager *m_invoke;

    QString m_serverUrl;
    QString m_username;
    QString m_userId;
    QString m_token;
    QString m_teamId;
    QString m_teamName;
    QString m_channelId;
    QString m_channelName;
    QString m_status;
    QString m_iconSend;
    QString m_iconSearch;
    QString m_iconPlus;
    QString m_iconEmoji;
    QString m_iconBack;
    QString m_iconSettings;

    bool m_loggedIn;
    bool m_active;
    bool m_chansBusy;
    bool m_chansSilent;
    bool m_postsBusy;
    bool m_postsAgain;
    bool m_threadBusy;
    bool m_threadAgain;
    bool m_usersLoaded;
    bool m_notesReady;
    int m_chanParts;
    int m_listTick;
    int m_filesBusy;
    int m_aroundLeft;
    int m_aroundGen;
    bool m_anchored;

    bool m_headless;
    bool m_hasOlder;
    bool m_hasNewer;
    bool m_trustReady;
    bool m_showPreview;
    bool m_showImages;
    bool m_clock24;
    bool m_notifyHub;
    bool m_notifyMentions;
    bool m_debugLog;
    bool m_focusNudged;
    bool m_mfaSent;

    QString m_mfaPassword;
    QString m_focusPost;
    QString m_aroundSelf;
    QString m_aroundChan;
    QStringList m_idsAfter;
    QStringList m_idsBefore;
    QStringList m_rawOrder;
    QVariantMap m_aroundPosts;
    QVariantMap m_rawPosts;
    QVariantList m_teamChoices;

    QString m_lastSent;
    QString m_lastPostId;
    QString m_postsSig;
    QString m_threadRoot;
    QString m_threadSig;
    QString m_inflight;
    QString m_pendingFull;
    QString m_pendingAttach;
    QString m_pendingInbox;
    QHash<QString, QString> m_noteKeys;
    QHash<QString, int> m_noteUnread;

    QVariantList m_channelRows;
    QVariantList m_postRows;
    QVariantList m_replyRows;
    QVariantList m_searchRows;
    LocalStore m_store;
    QList<FileJob> m_fileQueue;
    QSet<QString> m_avatarTried;
    QSet<QString> m_emojiMiss;
    QSet<QString> m_saved;
    QList<CustomEmoji> m_customEmoji;
    int m_emojiPage;
    bool m_emojiListBusy;
    qint64 m_emojiListedAt;
    int m_previewLeft;
    QHash<QString, UserInfo> m_users;
};

#endif
