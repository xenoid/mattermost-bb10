#include "MmClient.hpp"
#include "Emoji.hpp"
#include "ImageStore.hpp"
#include "Markdown.hpp"

#include <bb/data/JsonDataAccess>
#include <bb/platform/Notification.hpp>
#include <bb/system/ApplicationStartupMode.hpp>
#include <bb/system/InvokeManager.hpp>
#include <bb/system/InvokeRecurrenceRule.hpp>
#include <bb/system/InvokeReply.hpp>
#include <bb/system/InvokeRequest.hpp>
#include <bb/system/InvokeTargetReply.hpp>
#include <bb/system/InvokeTimerRequest.hpp>

#include <QCoreApplication>
#include <QDebug>
#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocale>
#include <QHttpMultiPart>
#include <QMap>
#include <QRegExp>
#include <QSet>
#include <QSettings>
#include <QTimer>
#include <QNetworkProxy>
#include <QSslCertificate>
#include <QSslConfiguration>
#include <QSslError>
#include <QSslSocket>
#include <QUrl>
#include <QtAlgorithms>
#include <dlfcn.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

using bb::data::JsonDataAccess;

namespace {

const int kPollMs = 8000;           // Takt für das stille Nachladen im Vordergrund
const int kBgPollMs = 30000;        // Takt im Hintergrund, fürs Nachrichtencenter
const int kPerPage = 60;            // Nachrichten pro Abruf
const qint64 kGroupMs = 240000;     // gleiche Person innerhalb von 4 Minuten: zusammenfassen
const double kImageMaxW = 580.0;    // Platz neben dem Profilbild
const double kImageMaxH = 400.0;

void imageBox(int w, int h, int &outW, int &outH)
{
    outW = int(kImageMaxW);
    outH = 330;
    if (w > 0 && h > 0) {
        double scale = qMin(kImageMaxW / w, kImageMaxH / h);
        if (scale > 1.4)
            scale = 1.4;
        outW = qMax(80, int(w * scale));
        outH = qMax(60, int(h * scale));
    }
}

QString reactionSig(const QVariantMap &post)
{
    const QVariantList reactions = post.value("metadata").toMap().value("reactions").toList();
    QString sig;
    for (int i = 0; i < reactions.size(); ++i) {
        const QVariantMap reaction = reactions.at(i).toMap();
        sig += reaction.value("emoji_name").toString();
        sig += reaction.value("user_id").toString();
        sig += ";";
    }
    return sig;
}
const int kAvatarMaxAgeDays = 3;

QString netText(int code)
{
    switch (code) {
    case QNetworkReply::ConnectionRefusedError:
        return QCoreApplication::translate("MmClient", "Server refused the connection");
    case QNetworkReply::HostNotFoundError:
        return QCoreApplication::translate("MmClient", "Server not found");
    case QNetworkReply::TimeoutError:
    case QNetworkReply::OperationCanceledError:
        return QCoreApplication::translate("MmClient", "Timed out");
    case QNetworkReply::SslHandshakeFailedError:
        return QCoreApplication::translate("MmClient", "Certificate not trusted");
    default:
        return QCoreApplication::translate("MmClient", "No connection");
    }
}

bool lessTitle(const QVariantMap &a, const QVariantMap &b)
{
    return a.value("title").toString().toLower() < b.value("title").toString().toLower();
}

bool moreRecent(const QVariantMap &a, const QVariantMap &b)
{
    return a.value("last").toLongLong() > b.value("last").toLongLong();
}

QString safeName(QString name)
{
    name.replace(QRegExp("[/\\\\:*?\"<>|]"), "_");
    name = name.trimmed();
    return name.isEmpty() ? QString("datei") : name;
}

// Der Cache heißt out- plus Zeitstempel plus Originalname. Beim Upload zählt der Originalname.
QString uploadName(const QString &name)
{
    const QRegExp cache("^out-\\d+-(.+)$");
    if (cache.exactMatch(name) && !cache.cap(1).isEmpty())
        return cache.cap(1);
    return name;
}

QList<QSslCertificate> g_trust;

void applyTrust(QNetworkRequest &request)
{
    QSslConfiguration ssl = QSslConfiguration::defaultConfiguration();
    ssl.setPeerVerifyMode(QSslSocket::VerifyPeer);
    ssl.setSslOption(QSsl::SslOptionDisableServerNameIndication, false);
    if (!g_trust.isEmpty())
        ssl.setCaCertificates(g_trust);
    request.setSslConfiguration(ssl);
}

QString localPath(const QString &path)
{
    if (path.startsWith("file://"))
        return QUrl(path).toLocalFile();
    return path;
}

bool isStaged(const QString &path)
{
    const QFileInfo info(path);
    if (!info.fileName().startsWith("out-"))
        return false;
    return info.absolutePath() == QDir(ImageStore::dir()).absolutePath();
}

QString copyIntoCache(const QString &path)
{
    const QString local = localPath(path);
    if (local.isEmpty() || !QFileInfo(local).isFile())
        return QString();
    const QString dest = ImageStore::dir() + "/out-"
        + QString::number(QDateTime::currentMSecsSinceEpoch()) + "-"
        + safeName(QFileInfo(local).fileName());
    if (!QFile::copy(local, dest))
        return QString();
    return dest;
}

}

namespace {
bool g_deferHeavy = false;
}

void MmClient::deferUntilLoop()
{
    g_deferHeavy = true;
}

void MmClient::bootHeadless()
{
    enterHeadless();
}

MmClient::MmClient(QObject *parent)
    : QObject(parent),
      m_invoke(new bb::system::InvokeManager(this)),
      m_loggedIn(false),
      m_active(true),
      m_chansBusy(false),
      m_chansSilent(false),
      m_postsBusy(false),
      m_postsAgain(false),
      m_threadBusy(false),
      m_threadAgain(false),
      m_usersLoaded(false),
      m_notesReady(false),
      m_chanParts(0),
      m_listTick(0),
      m_filesBusy(0),
      m_aroundLeft(0),
      m_aroundGen(0),
      m_anchored(false),
      m_headless(false),
      m_hasOlder(false),
      m_hasNewer(false),
      m_trustReady(false),
      m_showPreview(true),
      m_debugLog(false),
      m_focusNudged(false),
      m_mfaSent(false)
{
    loadTrust();
    ImageStore::sweepLegacy();
    m_iconSend = ImageStore::iconSend();
    m_iconSearch = ImageStore::iconSearch();
    m_iconPlus = ImageStore::iconPlus();
    m_iconEmoji = ImageStore::iconEmoji();
    m_iconBack = ImageStore::iconBack();
    m_iconSettings = ImageStore::tileGear();

    connect(m_invoke, SIGNAL(invoked(const bb::system::InvokeRequest&)),
            this, SLOT(onInvoked(const bb::system::InvokeRequest&)));
    connect(&m_net, SIGNAL(finished(QNetworkReply*)), this, SLOT(onFinished(QNetworkReply*)));
    m_timer.setInterval(kPollMs);
    connect(&m_timer, SIGNAL(timeout()), this, SLOT(onTick()));
    if (g_deferHeavy)
        return;
    m_timer.start();

    QSettings settings("hollweck", "mattermost");
    m_serverUrl = settings.value("serverUrl").toString();
    m_username = settings.value("username").toString();
    m_token = settings.value("token").toString();
    m_userId = settings.value("userId").toString();
    m_showPreview = settings.value("showPreview", true).toBool();
    m_debugLog = settings.value("debugLog", false).toBool();
    if (!m_token.isEmpty() && !m_serverUrl.isEmpty()) {
        setLoggedIn(true);
        loadMe();
    }
}

// ---------------------------------------------------------------- Hilfen

QString MmClient::shortWhen(qint64 ms) const
{
    const QDateTime dt = QDateTime::fromMSecsSinceEpoch(ms);
    const QDate today = QDate::currentDate();
    if (dt.date() == today)
        return dt.toString("HH:mm");
    if (dt.date() == today.addDays(-1))
        return tr("Yesterday");
    if (dt.date().year() == today.year())
        return dt.toString("dd.MM.");
    return dt.toString("dd.MM.yy");
}

QString MmClient::dayLabel(const QDate &day) const
{
    const QDate today = QDate::currentDate();
    if (day == today)
        return tr("Today");
    if (day == today.addDays(-1))
        return tr("Yesterday");
    return QLocale::system().toString(day, QLocale::LongFormat);
}

QString MmClient::sizeText(qint64 bytes) const
{
    if (bytes < 1024)
        return QString("%1 B").arg(bytes);
    const QLocale loc = QLocale::system();
    if (bytes < 1024 * 1024)
        return QString("%1 KB").arg(loc.toString(bytes / 1024.0, 'f', 0));
    return QString("%1 MB").arg(loc.toString(bytes / 1048576.0, 'f', 1));
}

QString MmClient::normalizeUrl(QString url) const
{
    url = url.trimmed();
    while (url.endsWith("/"))
        url.chop(1);
    if (!url.startsWith("http://") && !url.startsWith("https://"))
        url.prepend("https://");
    return url;
}

QString MmClient::repairText(const QString &in) const
{
    // Doppelt kodiertes UTF-8 (Ã¼ statt ü) zurückholen, sonst unverändert lassen.
    if (in.isEmpty())
        return in;
    bool high = false;
    bool suspicious = false;
    const ushort *units = in.utf16();
    for (int i = 0; i < in.size(); ++i) {
        const ushort u = units[i];
        if (u > 0x00FF)
            high = true;
        if (u == 0x00C3 || u == 0x00C2)
            suspicious = true;
    }
    if (high || !suspicious)
        return in;
    const QByteArray latin = in.toLatin1();
    const QString fixed = QString::fromUtf8(latin.constData(), latin.size());
    if (fixed.isEmpty() || fixed.contains(QChar(0xFFFD)))
        return in;
    return fixed;
}

QString MmClient::firstUrl(const QString &message, bool *linkOnly) const
{
    if (linkOnly)
        *linkOnly = false;
    QRegExp rx("https?://[^\\s<>\"']+");
    if (rx.indexIn(message) < 0)
        return QString();
    QString url = rx.cap(0);
    while (!url.isEmpty()) {
        const QChar tail = url.at(url.size() - 1);
        if (tail == ')') {
            if (url.count(QLatin1Char('(')) >= url.count(QLatin1Char(')')))
                break;
            url.chop(1);
            continue;
        }
        if (tail == ']') {
            if (url.count(QLatin1Char('[')) >= url.count(QLatin1Char(']')))
                break;
            url.chop(1);
            continue;
        }
        if (tail != '.' && tail != ',' && tail != ';' && tail != ':')
            break;
        url.chop(1);
    }
    if (linkOnly) {
        QString rest = message;
        rest.remove(rx.cap(0));
        *linkOnly = rest.trimmed().isEmpty();
    }
    return url;
}

QString MmClient::channelTitle(const QString &id) const
{
    for (int i = 0; i < m_channelRows.size(); ++i) {
        const QVariantMap row = m_channelRows.at(i).toMap();
        if (row.value("channelId").toString() == id)
            return row.value("title").toString();
    }
    return tr("Channel");
}

QString MmClient::personLabel(const QVariantMap &user) const
{
    const QString nick = user.value("nickname").toString().trimmed();
    if (!nick.isEmpty())
        return repairText(nick);
    const QString full = (user.value("first_name").toString() + " "
                          + user.value("last_name").toString()).trimmed();
    if (!full.isEmpty())
        return repairText(full);
    const QString username = user.value("username").toString().trimmed();
    if (!username.isEmpty())
        return repairText(username);
    return tr("Unknown");
}

QString MmClient::nameOf(const QString &userId) const
{
    if (m_users.contains(userId))
        return m_users.value(userId).label;
    if (userId == m_userId && !m_username.isEmpty())
        return m_username;
    return tr("Unknown");
}

// ---------------------------------------------------------------- Status

void MmClient::setStatus(const QString &text)
{
    if (m_status == text)
        return;
    m_status = text;
    emit statusChanged();
}

QString MmClient::appVersion() const
{
    return QCoreApplication::applicationVersion();
}

void MmClient::setShowPreview(bool on)
{
    if (m_showPreview == on)
        return;
    m_showPreview = on;
    QSettings("hollweck", "mattermost").setValue("showPreview", on);
    emit prefsChanged();
}

void MmClient::setDebugLog(bool on)
{
    if (m_debugLog == on)
        return;
    m_debugLog = on;
    QSettings("hollweck", "mattermost").setValue("debugLog", on);
    emit prefsChanged();
}

void MmClient::setLoggedIn(bool on)
{
    if (m_loggedIn == on)
        return;
    m_loggedIn = on;
    if (on)
        armHubTimer();
    else
        disarmHubTimer();
    emit loggedInChanged();
}

void MmClient::resetSession()
{
    m_mfaPassword.clear();
    m_mfaSent = false;
    m_token.clear();
    m_userId.clear();
    m_teamId.clear();
    m_teamName.clear();
    m_channelId.clear();
    m_channelName.clear();
    m_channelRows.clear();
    m_postRows.clear();
    m_searchRows.clear();
    m_fileQueue.clear();
    m_users.clear();
    m_avatarTried.clear();
    m_lastPostId.clear();
    m_postsSig.clear();
    m_threadRoot.clear();
    m_threadSig.clear();
    m_inflight.clear();
    m_pendingFull.clear();
    m_pendingAttach.clear();
    m_replyRows.clear();
    m_chansBusy = false;
    m_postsBusy = false;
    m_postsAgain = false;
    m_threadBusy = false;
    m_threadAgain = false;
    m_usersLoaded = false;
    m_chanParts = 0;
    m_noteKeys.clear();
    m_noteUnread.clear();
    m_notesReady = false;
    m_pendingInbox.clear();
    m_focusPost.clear();
    m_rawOrder.clear();
    m_rawPosts.clear();
    m_teamChoices.clear();
    m_hasOlder = false;
    m_hasNewer = false;
    m_aroundLeft = 0;
    m_aroundGen = 0;
    m_anchored = false;
    bb::platform::Notification::deleteAllFromInbox();
    m_store.clear();
}

// ---------------------------------------------------------------- Aufrufe aus QML

bool MmClient::headlessLaunch() const
{
    if (!m_invoke)
        return false;
    const bb::system::ApplicationStartupMode::Type mode = m_invoke->startupMode();
    return mode == bb::system::ApplicationStartupMode::InvokeHeadless
        || mode == bb::system::ApplicationStartupMode::LaunchHeadless;
}

void MmClient::enterHeadless()
{
    m_headless = true;
    m_timer.stop();
    if (g_deferHeavy) {
        loadTrust();
        QSettings settings("hollweck", "mattermost");
        m_serverUrl = settings.value("serverUrl").toString();
        m_username = settings.value("username").toString();
        m_token = settings.value("token").toString();
        m_userId = settings.value("userId").toString();
        m_showPreview = settings.value("showPreview", true).toBool();
        m_debugLog = settings.value("debugLog", false).toBool();
        m_net.setProxy(QNetworkProxy(QNetworkProxy::NoProxy));
        if (!m_token.isEmpty() && !m_serverUrl.isEmpty()) {
            setLoggedIn(true);
            loadMe();
        }
    }
    QSslSocket::supportsSsl();
    void *sslLib = dlopen("libssl.so.2", RTLD_NOW);
    typedef const char *(*SslVerFn)(int);
    SslVerFn sslVerFn = 0;
    if (sslLib)
        sslVerFn = (SslVerFn)dlsym(sslLib, "OpenSSL_version");
    if (sslLib && !sslVerFn)
        sslVerFn = (SslVerFn)dlsym(sslLib, "SSLeay_version");
    const char *sslVer = sslVerFn ? sslVerFn(0) : "none";
    qDebug("mm-hub trust %d ssl %d ciphers %d ver %s", g_trust.size(),
           QSslSocket::supportsSsl() ? 1 : 0, QSslSocket::supportedCiphers().size(),
           sslVer);
    qDebug("mm-hub start");
    if (m_token.isEmpty() || m_serverUrl.isEmpty())
        quitIfHeadless();
}

static QString exeDir()
{
    char exe[256];
    int fd;
    int slash;
    memset(exe, 0, sizeof(exe));
    fd = open("/proc/self/exefile", O_RDONLY);
    if (fd < 0)
        return QString();
    read(fd, exe, sizeof(exe) - 1);
    close(fd);
    const QString path = QString::fromLocal8Bit(exe);
    slash = path.lastIndexOf(QLatin1Char('/'));
    if (slash <= 0)
        return QString();
    return path.left(slash);
}

void MmClient::loadTrust()
{
    QStringList paths;
    const QString dir = exeDir();
    if (!dir.isEmpty())
        paths << dir + "/assets/cacert.pem";
    paths << QCoreApplication::applicationDirPath() + "/assets/cacert.pem";
    paths << QCoreApplication::applicationDirPath() + "/../assets/cacert.pem";
    paths << QString("app/native/assets/cacert.pem");
    for (int i = 0; i < paths.size(); ++i) {
        if (!QFileInfo(paths.at(i)).isFile())
            continue;
        const QList<QSslCertificate> certs = QSslCertificate::fromPath(paths.at(i), QSsl::Pem);
        if (certs.isEmpty())
            continue;
        g_trust = certs;
        QSslSocket::setDefaultCaCertificates(certs);
        m_trustReady = true;
        return;
    }
}

void MmClient::armHubTimer()
{
    if (!m_invoke || m_headless || headlessLaunch())
        return;
    bb::system::InvokeRecurrenceRule rule(bb::system::InvokeRecurrenceRuleFrequency::Minutely);
    rule.setInterval(6);
    if (!rule.isValid())
        return;
    bb::system::InvokeTimerRequest request(QLatin1String("mm-hub"), rule,
                                           QLatin1String("com.hollweck.mattermost.hub"));
    bb::system::InvokeReply *reply = m_invoke->registerTimer(request);
    if (reply)
        reply->setParent(this);
}

void MmClient::disarmHubTimer()
{
    if (!m_invoke || headlessLaunch())
        return;
    bb::system::InvokeReply *reply = m_invoke->deregisterTimer(QLatin1String("mm-hub"));
    if (reply)
        reply->setParent(this);
}

void MmClient::quitIfHeadless()
{
    if (!m_headless || !QCoreApplication::instance())
        return;
    qDebug("mm-hub done");
    QTimer::singleShot(300, QCoreApplication::instance(), SLOT(quit()));
}

void MmClient::noteSsl(const QList<QSslError> &errs)
{
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply || errs.isEmpty())
        return;
    reply->setProperty("ssl", int(errs.at(0).error()));
}

void MmClient::abortTimedOut()
{
    QTimer *timer = qobject_cast<QTimer *>(sender());
    if (!timer)
        return;
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(timer->parent());
    timer->setParent(0);
    if (reply && reply->isRunning())
        reply->abort();
    timer->deleteLater();
}

void MmClient::armAbort(QNetworkReply *reply, int timeoutMs)
{
    if (!reply)
        return;
    QTimer *timer = new QTimer(reply);
    timer->setSingleShot(true);
    connect(timer, SIGNAL(timeout()), this, SLOT(abortTimedOut()));
    timer->start(timeoutMs);
}

void MmClient::applyTeam(const QString &id, const QString &name)
{
    if (id.isEmpty())
        return;
    m_teamId = id;
    m_teamName = name;
    QSettings settings("hollweck", "mattermost");
    settings.setValue("teamId", id);
    m_channelId.clear();
    m_channelName.clear();
    m_postRows.clear();
    m_rawOrder.clear();
    m_rawPosts.clear();
    emit sessionChanged();
    emit channelChanged();
    loadChannels(false);
}

void MmClient::offerTeams(const QVariantList &teams)
{
    m_teamChoices.clear();
    QString savedId;
    QString savedName;
    const QString wanted = QSettings("hollweck", "mattermost").value("teamId").toString();
    for (int i = 0; i < teams.size(); ++i) {
        const QVariantMap team = teams.at(i).toMap();
        const QString id = team.value("id").toString();
        const QString name = repairText(team.value("display_name").toString());
        if (id.isEmpty())
            continue;
        QVariantMap row;
        row["id"] = id;
        row["name"] = name.isEmpty() ? team.value("name").toString() : name;
        m_teamChoices.append(row);
        if (id == wanted) {
            savedId = id;
            savedName = row.value("name").toString();
        }
    }
    emit sessionChanged();
    if (m_teamChoices.isEmpty()) {
        setStatus(tr("No team on this account"));
        quitIfHeadless();
        return;
    }
    if (m_headless) {
        if (savedId.isEmpty()) {
            savedId = m_teamChoices.at(0).toMap().value("id").toString();
            savedName = m_teamChoices.at(0).toMap().value("name").toString();
        }
        applyTeam(savedId, savedName);
        return;
    }
    if (m_teamChoices.size() == 1 || !savedId.isEmpty()) {
        if (savedId.isEmpty()) {
            savedId = m_teamChoices.at(0).toMap().value("id").toString();
            savedName = m_teamChoices.at(0).toMap().value("name").toString();
        }
        applyTeam(savedId, savedName);
        return;
    }
    setStatus(tr("Choose a team"));
    emit chooseTeam();
}

void MmClient::login(const QString &serverUrl, const QString &user, const QString &password)
{
    resetSession();
    m_serverUrl = normalizeUrl(serverUrl);
    m_username = user.trimmed();
    emit channelChanged();
    emit sessionChanged();

    if (m_serverUrl.isEmpty() || m_username.isEmpty() || password.isEmpty()) {
        setStatus(tr("Server, name, and password are missing"));
        return;
    }
    if (!m_trustReady) {
        setStatus(tr("Trust store missing"));
        return;
    }
    m_mfaPassword = password;
    m_mfaSent = false;
    QVariantMap body;
    body["login_id"] = m_username;
    body["password"] = password;
    QByteArray bytes;
    JsonDataAccess json;
    json.saveToBuffer(body, &bytes);
    setStatus(tr("Signing in…"));
    start(StepLogin, "/api/v4/users/login", bytes, "POST");
}

void MmClient::submitMfa(const QString &code)
{
    const QString token = code.trimmed();
    if (m_mfaPassword.isEmpty() || m_username.isEmpty() || m_serverUrl.isEmpty()) {
        setStatus(tr("Sign-in cancelled"));
        return;
    }
    if (token.isEmpty()) {
        setStatus(tr("Code missing"));
        emit mfaRequired();
        return;
    }
    QVariantMap body;
    body["login_id"] = m_username;
    body["password"] = m_mfaPassword;
    body["token"] = token;
    m_mfaSent = true;
    QByteArray bytes;
    JsonDataAccess json;
    json.saveToBuffer(body, &bytes);
    setStatus(tr("Signing in…"));
    start(StepLogin, "/api/v4/users/login", bytes, "POST");
}

void MmClient::cancelMfa()
{
    m_mfaPassword.clear();
    m_mfaSent = false;
    setStatus(tr("Sign-in cancelled"));
}

void MmClient::selectTeam(const QString &id)
{
    for (int i = 0; i < m_teamChoices.size(); ++i) {
        const QVariantMap team = m_teamChoices.at(i).toMap();
        if (team.value("id").toString() == id) {
            applyTeam(id, team.value("name").toString());
            return;
        }
    }
}

QVariantList MmClient::teamChoices() const
{
    return m_teamChoices;
}

void MmClient::logout()
{
    QSettings settings("hollweck", "mattermost");
    settings.remove("token");
    settings.remove("userId");
    resetSession();
    setLoggedIn(false);
    setStatus("Abgemeldet");
    emit channelChanged();
    emit sessionChanged();
    emit channelsLoaded(QVariantList());
    emit postsLoaded(QVariantList());
}

void MmClient::openAt(const QString &id, const QString &name, const QString &postId)
{
    m_focusPost = postId;
    openChannel(id, name);
}

void MmClient::nudgeFocus()
{
    if (m_focusNudged)
        return;
    m_focusNudged = true;
    // Der Puffer braucht die Zeilen, bevor der Sprung sitzt. 100 ms hat ihn abgebrochen.
    QTimer::singleShot(400, this, SLOT(emitFocusNudge()));
}

void MmClient::emitFocusNudge()
{
    m_focusNudged = false;
    emit focusNudge();
}

void MmClient::openChannel(const QString &id, const QString &name)
{
    m_channelId = id;
    m_channelName = name;
    m_lastPostId.clear();
    m_postsSig.clear();
    m_rawOrder.clear();
    m_rawPosts.clear();
    m_aroundLeft = 0;
    ++m_aroundGen;
    m_aroundSelf.clear();
    setHistory(false, false);
    ensureStore();
    m_postRows = m_store.posts(id);
    for (int i = 0; i < m_channelRows.size(); ++i) {
        QVariantMap row = m_channelRows.at(i).toMap();
        if (row.value("channelId").toString() == id) {
            row["unread"] = 0;
            row["mentions"] = 0;
            m_channelRows[i] = row;
        }
    }
    emit channelChanged();
    clearInbox(id);
    m_noteUnread.insert(id, 0);
    if (!m_postRows.isEmpty() && m_focusPost.isEmpty())
        emit postsLoaded(withPending(m_postRows, false));
    loadPosts(false);
}

void MmClient::closeChannel()
{
    if (m_channelId.isEmpty() && m_channelName.isEmpty())
        return;
    m_channelId.clear();
    m_channelName.clear();
    m_postRows.clear();
    m_aroundSelf.clear();
    m_focusPost.clear();
    emit channelChanged();
    loadChannels(true);
}

void MmClient::sendMessage(const QString &text)
{
    submit(m_channelId, QString(), text.trimmed(), QString(), QString());
}

void MmClient::sendReply(const QString &rootId, const QString &text)
{
    submit(m_channelId, rootId, text.trimmed(), QString(), QString());
}

void MmClient::askReplies(const QString &rootId)
{
    if (!rootId.isEmpty())
        emit repliesRequested(rootId);
}

void MmClient::askReact(const QString &postId)
{
    if (!postId.isEmpty())
        emit reactRequested(postId);
}

QVariantList MmClient::emojiChoices() const
{
    return Emoji::choices();
}

QVariantList MmClient::emojiCatalog(const QString &query) const
{
    return Emoji::catalog(query);
}

void MmClient::showCached()
{
    if (!m_loggedIn)
        return;
    ensureStore();
    const QVariantList rows = m_store.channels();
    if (!rows.isEmpty())
        emit channelsLoaded(rows);
}

void MmClient::refresh()
{
    if (!m_threadRoot.isEmpty())
        loadThread(false);
    if (!m_channelId.isEmpty())
        loadPosts(false);
    else if (m_threadRoot.isEmpty())
        loadChannels(false);
}

void MmClient::search(const QString &terms)
{
    const QString query = terms.trimmed();
    if (query.isEmpty() || m_teamId.isEmpty())
        return;
    m_searchRows.clear();
    setStatus(tr("Searching…"));
    QVariantMap body;
    body["terms"] = query;
    body["is_or_search"] = false;
    body["page"] = 0;
    body["per_page"] = 30;
    QByteArray bytes;
    JsonDataAccess json;
    json.saveToBuffer(body, &bytes);
    start(StepSearch, "/api/v4/teams/" + m_teamId + "/posts/search", bytes, "POST");
}

void MmClient::openFromSearch(const QString &id, const QString &name, const QString &postId)
{
    emit threadRequested(id, name, postId);
}

void MmClient::openLink(const QString &url)
{
    if (url.isEmpty() || !m_invoke)
        return;
    bb::system::InvokeRequest request;
    request.setAction("bb.action.OPEN");
    request.setMimeType("text/html");
    request.setUri(QUrl(url));
    bb::system::InvokeTargetReply *reply = m_invoke->invoke(request);
    if (reply)
        reply->setParent(this);
}

void MmClient::openFile(const QString &path, const QString &mime)
{
    if (!m_invoke)
        return;
    bb::system::InvokeRequest request;
    request.setAction("bb.action.OPEN");
    request.setMimeType(mime.isEmpty() ? QString("application/octet-stream") : mime);
    request.setUri(QUrl::fromLocalFile(path));
    bb::system::InvokeTargetReply *reply = m_invoke->invoke(request);
    if (reply)
        reply->setParent(this);
}

void MmClient::onForeground()
{
    m_active = true;
    m_timer.setInterval(kPollMs);
    m_timer.start();
    if (!m_loggedIn)
        return;
    if (!m_channelId.isEmpty())
        loadPosts(true);
    else
        loadChannels(true);
}

void MmClient::onBackground()
{
    m_active = false;
    m_timer.setInterval(kBgPollMs);
    m_timer.start();
}

void MmClient::onTick()
{
    if (m_headless || !m_loggedIn || m_token.isEmpty())
        return;
    if (!m_active) {
        loadChannels(true);
        flushOutbox();
        return;
    }
    if (!m_channelId.isEmpty())
        loadPosts(true);
    if (!m_threadRoot.isEmpty())
        loadThread(true);
    if (++m_listTick % 4 == 0)
        loadChannels(true);
    flushOutbox();
}

void MmClient::onInvoked(const bb::system::InvokeRequest &request)
{
    if (request.target() != QLatin1String("com.hollweck.mattermost.open"))
        return;
    const QString id = QString::fromUtf8(request.data()).trimmed();
    if (id.isEmpty())
        return;
    m_pendingInbox = id;
    QMetaObject::invokeMethod(this, "flushInbox", Qt::QueuedConnection);
}

void MmClient::flushInbox()
{
    if (m_pendingInbox.isEmpty() || !m_loggedIn || m_channelRows.isEmpty())
        return;
    const QString id = m_pendingInbox;
    m_pendingInbox.clear();
    emit inboxRequested(id, channelTitle(id));
}

void MmClient::clearInbox(const QString &channelId)
{
    const QString stable = QString("mm-") + channelId;
    bb::platform::Notification::deleteFromInbox(stable);
    const QString key = m_noteKeys.value(channelId);
    if (!key.isEmpty() && key != stable)
        bb::platform::Notification::deleteFromInbox(key);
    m_noteKeys.remove(channelId);
}

void MmClient::postInbox(const QString &channelId, const QString &title, int unread, int mentions, bool alert)
{
    clearInbox(channelId);
    const QString key = QString("mm-") + channelId;
    bb::platform::Notification note(key);
    note.setTitle(title.isEmpty() ? QString("Mattermost") : title);
    QString body;
    if (mentions > 0 && unread > mentions)
        body = tr("%1 new messages, %2 mentions").arg(unread).arg(mentions);
    else if (mentions > 1)
        body = tr("%1 mentions").arg(mentions);
    else if (mentions == 1)
        body = tr("Mention");
    else if (unread <= 1)
        body = tr("New message");
    else
        body = tr("%1 new messages").arg(unread);
    note.setBody(body);
    note.setType(alert ? bb::platform::NotificationType::Default
                       : bb::platform::NotificationType::AllAlertsOff);
    bb::system::InvokeRequest request;
    request.setTarget("com.hollweck.mattermost.open");
    request.setAction("bb.action.OPEN");
    request.setMimeType("text/plain");
    request.setData(channelId.toUtf8());
    note.setInvokeRequest(request);
    if (note.notify() == bb::platform::NotificationError::None)
        m_noteKeys.insert(channelId, key);
}

void MmClient::syncInbox()
{
    if (!m_notesReady && !m_headless)
        bb::platform::Notification::deleteAllFromInbox();

    QSet<QString> live;
    for (int i = 0; i < m_channelRows.size(); ++i) {
        const QVariantMap row = m_channelRows.at(i).toMap();
        const QString id = row.value("channelId").toString();
        if (id.isEmpty())
            continue;
        live.insert(id);
        const int unread = row.value("unread").toInt();
        const int mentions = row.value("mentions").toInt();
        const int attention = unread > mentions ? unread : mentions;
        const int seen = m_noteUnread.value(id, 0);
        if (attention <= 0)
            clearInbox(id);
        else if (!m_notesReady || attention < seen)
            postInbox(id, row.value("title").toString(), unread, mentions, false);
        else if (attention > seen)
            postInbox(id, row.value("title").toString(), unread, mentions, true);
        m_noteUnread.insert(id, attention);
    }
    const QStringList keys = m_noteKeys.keys();
    for (int i = 0; i < keys.size(); ++i) {
        if (!live.contains(keys.at(i)))
            clearInbox(keys.at(i));
    }
    const QStringList seenIds = m_noteUnread.keys();
    for (int i = 0; i < seenIds.size(); ++i) {
        if (!live.contains(seenIds.at(i)))
            m_noteUnread.remove(seenIds.at(i));
    }
    m_notesReady = true;
    if (!m_headless && !m_pendingInbox.isEmpty())
        flushInbox();
    quitIfHeadless();
}

// ---------------------------------------------------------------- Netz

QNetworkRequest MmClient::makeRequest(const QString &path) const
{
    QNetworkRequest request(QUrl(m_serverUrl + path));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Accept", "application/json");
    if (!m_token.isEmpty())
        request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    applyTrust(request);
    return request;
}

QNetworkReply *MmClient::start(Step step, const QString &path, const QByteArray &body,
                               const QByteArray &verb, bool silent, int timeoutMs)
{
    const QNetworkRequest request = makeRequest(path);
    QNetworkReply *reply = 0;
    if (verb == "POST")
        reply = m_net.post(request, body);
    else if (verb == "DELETE")
        reply = m_net.deleteResource(request);
    else
        reply = m_net.get(request);
    reply->setProperty("step", int(step));
    reply->setProperty("silent", silent);
    reply->setProperty("ssl", 0);
    connect(reply, SIGNAL(sslErrors(QList<QSslError>)), this, SLOT(noteSsl(QList<QSslError>)));
    armAbort(reply, timeoutMs);
    return reply;
}

void MmClient::failed(Step step, bool silent, int http, int netCode)
{
    QString text;
    if (http < 0)
        text = tr("Invalid response from the server");
    else if (http >= 400)
        text = tr("Server error (HTTP %1)").arg(http);
    else
        text = netText(netCode);

    switch (step) {
    case StepMembers:
    case StepChannelUsers:
        partDone();
        return;
    case StepUsers:
        finishPosts();
        return;
    case StepSearchUsers:
        finishSearch();
        return;
    case StepSend:
    case StepUpload:
        return;
    case StepThread:
        m_threadBusy = false;
        if (!silent && !m_replyRows.isEmpty()) {
            setStatus(tr("Offline. Saved thread."));
            quitIfHeadless();
            return;
        }
        break;
    case StepThreadUsers:
        finishThread();
        return;
    case StepChannels:
        m_chansBusy = false;
        if (!silent && !m_store.channels().isEmpty()) {
            setStatus(tr("Offline. Saved channels."));
            quitIfHeadless();
            return;
        }
        break;
    case StepPosts:
        m_postsBusy = false;
        if (!silent && !m_postRows.isEmpty()) {
            setStatus(tr("Offline. Saved messages."));
            quitIfHeadless();
            return;
        }
        break;
    default:
        break;
    }
    if (!silent)
        setStatus(text);
    quitIfHeadless();
}

void MmClient::loadMe()
{
    setStatus(tr("Loading account…"));
    start(StepMe, "/api/v4/users/me");
}

void MmClient::loadTeams()
{
    start(StepTeams, "/api/v4/users/me/teams");
}

void MmClient::loadChannels(bool silent)
{
    if (!m_loggedIn)
        return;
    if (m_userId.isEmpty()) {
        loadMe();
        return;
    }
    if (m_teamId.isEmpty()) {
        loadTeams();
        return;
    }
    if (m_chansBusy)
        return;
    ensureStore();
    if (!silent && m_channelRows.isEmpty()) {
        const QVariantList cached = m_store.channels();
        if (!cached.isEmpty())
            emit channelsLoaded(cached);
    }
    m_chansBusy = true;
    m_chansSilent = silent;
    if (!silent)
        setStatus(tr("Loading channels…"));
    start(StepChannels, "/api/v4/users/me/teams/" + m_teamId + "/channels",
          QByteArray(), "GET", silent);
}

void MmClient::loadPosts(bool silent)
{
    if (!m_loggedIn || m_channelId.isEmpty() || m_headless)
        return;
    // Eine laufende Liste darf die Fundstelle nicht auf die neueste Seite umbiegen.
    if (!m_focusPost.isEmpty()) {
        if (m_postsBusy) {
            m_postsAgain = true;
            return;
        }
        const QString focus = m_focusPost;
        m_focusPost.clear();
        loadAround(focus);
        return;
    }
    // Die Umgebung bleibt, bis der Kanal neu geladen wird. Eine stille
    // Abfrage darf sie nicht durch die neueste Seite ersetzen.
    if (m_aroundLeft > 0) {
        if (!silent)
            m_postsAgain = true;
        return;
    }
    if (silent && (m_anchored || m_hasNewer))
        return;
    if (m_postsBusy) {
        m_postsAgain = true;
        return;
    }
    m_postsBusy = true;
    if (!silent) {
        m_anchored = false;
        m_rawOrder.clear();
        m_rawPosts.clear();
        setHistory(false, false);
        setStatus(tr("Loading messages…"));
    }
    QNetworkReply *reply = start(StepPosts,
        QString("/api/v4/channels/%1/posts?per_page=%2").arg(m_channelId).arg(kPerPage),
        QByteArray(), "GET", silent);
    reply->setProperty("chan", m_channelId);
    reply->setProperty("page", QString("latest"));
}

void MmClient::loadOlder()
{
    if (m_postsBusy || m_channelId.isEmpty() || !m_hasOlder)
        return;
    const QString oldest = edgePostId(false);
    if (oldest.isEmpty())
        return;
    m_postsBusy = true;
    setStatus(tr("Loading older messages…"));
    QNetworkReply *reply = start(StepPosts,
        QString("/api/v4/channels/%1/posts?per_page=%2&before=%3")
            .arg(m_channelId).arg(kPerPage).arg(oldest),
        QByteArray(), "GET", true);
    reply->setProperty("chan", m_channelId);
    reply->setProperty("page", QString("older"));
}

void MmClient::loadNewer()
{
    if (m_postsBusy || m_channelId.isEmpty() || !m_hasNewer)
        return;
    const QString newest = edgePostId(true);
    if (newest.isEmpty())
        return;
    m_postsBusy = true;
    QNetworkReply *reply = start(StepPosts,
        QString("/api/v4/channels/%1/posts?per_page=%2&after=%3")
            .arg(m_channelId).arg(kPerPage).arg(newest),
        QByteArray(), "GET", true);
    reply->setProperty("chan", m_channelId);
    reply->setProperty("page", QString("newer"));
}

void MmClient::loadAround(const QString &postId)
{
    if (postId.isEmpty() || m_channelId.isEmpty())
        return;
    m_postsBusy = true;
    m_anchored = true;
    ++m_aroundGen;
    m_aroundLeft = 3;
    m_aroundSelf = postId;
    m_aroundChan = m_channelId;
    m_aroundPosts.clear();
    m_idsAfter.clear();
    m_idsBefore.clear();
    m_rawOrder.clear();
    m_rawPosts.clear();
    setStatus(tr("Loading messages…"));
    QNetworkReply *self = start(StepPost, "/api/v4/posts/" + postId, QByteArray(), "GET", true);
    self->setProperty("chan", m_channelId);
    self->setProperty("page", QString("self"));
    self->setProperty("gen", m_aroundGen);
    QNetworkReply *before = start(StepPosts,
        QString("/api/v4/channels/%1/posts?per_page=30&before=%2").arg(m_channelId, postId),
        QByteArray(), "GET", true);
    before->setProperty("chan", m_channelId);
    before->setProperty("page", QString("before"));
    before->setProperty("gen", m_aroundGen);
    QNetworkReply *after = start(StepPosts,
        QString("/api/v4/channels/%1/posts?per_page=30&after=%2").arg(m_channelId, postId),
        QByteArray(), "GET", true);
    after->setProperty("chan", m_channelId);
    after->setProperty("page", QString("after"));
    after->setProperty("gen", m_aroundGen);
}

bool MmClient::aroundMatches(const QNetworkReply *reply) const
{
    return reply && reply->property("gen").toInt() == m_aroundGen;
}

QString MmClient::edgePostId(bool newest) const
{
    if (m_rawOrder.isEmpty())
        return QString();
    const int start = newest ? 0 : m_rawOrder.size() - 1;
    const int step = newest ? 1 : -1;
    for (int i = start; i >= 0 && i < m_rawOrder.size(); i += step) {
        const QString id = m_rawOrder.at(i);
        const QString type = m_rawPosts.value(id).toMap().value("type").toString();
        if (!id.isEmpty() && !type.startsWith("system_"))
            return id;
    }
    return QString();
}

void MmClient::setHistory(bool older, bool newer)
{
    if (m_hasOlder == older && m_hasNewer == newer)
        return;
    m_hasOlder = older;
    m_hasNewer = newer;
    emit historyChanged();
}

void MmClient::postsIdle()
{
    m_postsBusy = false;
    if (!m_postsAgain)
        return;
    m_postsAgain = false;
    loadPosts(true);
}

void MmClient::mergePosts(const QString &mode, const QVariantList &order, const QVariantMap &posts)
{
    QVariantMap::const_iterator it = posts.constBegin();
    for (; it != posts.constEnd(); ++it)
        m_rawPosts.insert(it.key(), it.value());
    QStringList ids;
    for (int i = 0; i < order.size(); ++i) {
        const QString id = order.at(i).toString();
        if (!id.isEmpty())
            ids.append(id);
    }
    if (mode == "older") {
        for (int i = 0; i < ids.size(); ++i) {
            if (!m_rawOrder.contains(ids.at(i)))
                m_rawOrder.append(ids.at(i));
        }
        return;
    }
    if (m_rawOrder.isEmpty()) {
        m_rawOrder = ids;
        return;
    }
    QStringList prefix;
    for (int i = 0; i < ids.size(); ++i) {
        if (m_rawOrder.contains(ids.at(i)))
            break;
        prefix.append(ids.at(i));
    }
    for (int i = prefix.size() - 1; i >= 0; --i)
        m_rawOrder.prepend(prefix.at(i));
}

void MmClient::commitPosts(bool mark)
{
    QVariantList order;
    for (int i = 0; i < m_rawOrder.size(); ++i)
        order.append(m_rawOrder.at(i));
    QStringList ids;
    m_postRows = buildConversation(order, m_rawPosts, false, ids);
    if (mark) {
        const QString newest = edgePostId(true);
        if (!newest.isEmpty() && newest != m_lastPostId) {
            m_lastPostId = newest;
            markRead(m_channelId);
        }
    }
    const QStringList missing = unknownUsers(ids);
    if (missing.isEmpty())
        finishPosts();
    else
        loadUsers(missing, StepUsers);
}

void MmClient::absorbAround(const QString &page, const QVariant &parsed)
{
    if (page == "self") {
        const QVariantMap post = parsed.toMap();
        const QString id = post.value("id").toString();
        if (id.isEmpty())
            return;
        m_aroundSelf = id;
        m_aroundPosts.insert(id, post);
        return;
    }
    const QVariantMap root = parsed.toMap();
    const QVariantList order = root.value("order").toList();
    const QVariantMap posts = root.value("posts").toMap();
    QStringList ids;
    for (int i = 0; i < order.size(); ++i) {
        const QString id = order.at(i).toString();
        if (!id.isEmpty())
            ids.append(id);
    }
    if (page == "before")
        m_idsBefore = ids;
    else
        m_idsAfter = ids;
    QVariantMap::const_iterator it = posts.constBegin();
    for (; it != posts.constEnd(); ++it)
        m_aroundPosts.insert(it.key(), it.value());
}

void MmClient::finishAround()
{
    m_aroundLeft = 0;
    if (m_aroundChan != m_channelId) {
        m_anchored = false;
        m_aroundPosts.clear();
        postsIdle();
        return;
    }
    QStringList order = m_idsAfter;
    if (!m_aroundSelf.isEmpty() && m_aroundPosts.contains(m_aroundSelf) && !order.contains(m_aroundSelf))
        order.append(m_aroundSelf);
    for (int i = 0; i < m_idsBefore.size(); ++i) {
        if (!order.contains(m_idsBefore.at(i)))
            order.append(m_idsBefore.at(i));
    }
    const bool older = m_idsBefore.size() >= 30;
    const bool newer = m_idsAfter.size() >= 30;
    m_idsAfter.clear();
    m_idsBefore.clear();
    if (order.isEmpty()) {
        m_anchored = false;
        m_aroundPosts.clear();
        postsIdle();
        setStatus(tr("Message not loaded"));
        return;
    }
    m_rawOrder = order;
    m_rawPosts = m_aroundPosts;
    m_aroundPosts.clear();
    setHistory(older, newer);
    commitPosts(true);
}

void MmClient::loadUsers(const QStringList &ids, Step step)
{
    QVariantList list;
    for (int i = 0; i < ids.size(); ++i)
        list.append(ids.at(i));
    QByteArray bytes;
    JsonDataAccess json;
    json.saveToBuffer(list, &bytes);
    start(step, "/api/v4/users/ids", bytes, "POST", true);
}

QStringList MmClient::unknownUsers(const QStringList &ids) const
{
    QStringList missing;
    for (int i = 0; i < ids.size(); ++i) {
        const QString id = ids.at(i);
        if (!id.isEmpty() && !m_users.contains(id) && !missing.contains(id))
            missing.append(id);
    }
    return missing;
}

void MmClient::learnUsers(const QVariantList &users)
{
    if (!m_userId.isEmpty())
        ensureStore();
    for (int i = 0; i < users.size(); ++i) {
        const QVariantMap user = users.at(i).toMap();
        const QString id = user.value("id").toString();
        if (id.isEmpty())
            continue;
        UserInfo info;
        info.label = personLabel(user);
        info.username = repairText(user.value("username").toString());
        m_users.insert(id, info);
        if (m_store.isOpen())
            m_store.saveUser(id, info.label, info.username);
    }
}

void MmClient::markRead(const QString &channelId)
{
    QVariantMap body;
    body["channel_id"] = channelId;
    QByteArray bytes;
    JsonDataAccess json;
    json.saveToBuffer(body, &bytes);
    start(StepView, "/api/v4/channels/members/me/view", bytes, "POST", true);
}

// ---------------------------------------------------------------- Zeilen

QVariantMap MmClient::makePostRow(const QVariantMap &post, const QVariantMap &all, bool inThread) const
{
    const QString uid = post.value("user_id").toString();
    const QString postId = post.value("id").toString();
    const QString rootId = post.value("root_id").toString();
    const int replyCount = post.value("reply_count").toInt();
    const qint64 created = post.value("create_at").toLongLong();
    const QString source = repairText(post.value("message").toString());
    const QString message = Emoji::apply(source);

    QString imageId;
    QString imageId2;
    int images = 0;
    int imgW = 0;
    int imgH = 0;
    int imgW2 = 0;
    int imgH2 = 0;
    QString attachId;
    QString attachName;
    QString attachMime;
    QString attachInfo;
    QString attachId2;
    QString attachName2;
    QString attachMime2;
    QString attachInfo2;
    const QVariantList files = post.value("metadata").toMap().value("files").toList();
    for (int i = 0; i < files.size(); ++i) {
        const QVariantMap file = files.at(i).toMap();
        const QString mime = file.value("mime_type").toString();
        if (mime.startsWith("image/")) {
            ++images;
            if (imageId.isEmpty()) {
                imageId = file.value("id").toString();
                imgW = file.value("width").toInt();
                imgH = file.value("height").toInt();
            } else if (imageId2.isEmpty()) {
                imageId2 = file.value("id").toString();
                imgW2 = file.value("width").toInt();
                imgH2 = file.value("height").toInt();
            }
        } else if (attachId.isEmpty()) {
            attachId = file.value("id").toString();
            attachName = repairText(file.value("name").toString());
            attachMime = mime;
            attachInfo = sizeText(file.value("size").toLongLong());
        } else if (attachId2.isEmpty()) {
            attachId2 = file.value("id").toString();
            attachName2 = repairText(file.value("name").toString());
            attachMime2 = mime;
            attachInfo2 = sizeText(file.value("size").toLongLong());
        }
    }
    int showW = 0;
    int showH = 0;
    int showW2 = 0;
    int showH2 = 0;
    imageBox(imgW, imgH, showW, showH);
    imageBox(imgW2, imgH2, showW2, showH2);

    QStringList reactBits;
    QStringList reactOwn;
    const QVariantList reactions = post.value("metadata").toMap().value("reactions").toList();
    QStringList reactNames;
    QMap<QString, int> reactCount;
    for (int i = 0; i < reactions.size(); ++i) {
        const QVariantMap reaction = reactions.at(i).toMap();
        const QString name = reaction.value("emoji_name").toString();
        if (name.isEmpty())
            continue;
        if (!reactCount.contains(name))
            reactNames.append(name);
        reactCount[name] = reactCount.value(name) + 1;
        if (reaction.value("user_id").toString() == m_userId && !reactOwn.contains(name))
            reactOwn.append(name);
    }
    for (int i = 0; i < reactNames.size() && reactBits.size() < 4; ++i) {
        const QString name = reactNames.at(i);
        QString glyph = Emoji::glyph(name);
        if (glyph.isEmpty())
            glyph = ":" + name + ":";
        reactBits.append(glyph + " " + QString::number(reactCount.value(name)));
    }

    bool linkOnly = false;
    const QString link = firstUrl(message, &linkOnly);
    const QDateTime when = QDateTime::fromMSecsSinceEpoch(created);

    QVariantMap row;
    row["id"] = post.value("id").toString();
    row["mark"] = (!m_aroundSelf.isEmpty() && postId == m_aroundSelf) ? QString("1") : QString();
    row["type"] = QString("post");
    row["userId"] = uid;
    row["mine"] = !m_userId.isEmpty() && uid == m_userId;
    row["plain"] = source;
    row["message"] = Markdown::html(message);
    row["whenTime"] = when.toString("HH:mm");
    row["whenFull"] = when.toString("dd.MM. HH:mm");
    row["createAt"] = created;
    row["title"] = QString();
    row["initial"] = QString();
    row["avatar"] = QString();
    row["disc"] = QString();
    row["grouped"] = false;
    row["channelId"] = post.value("channel_id").toString();
    row["channelTitle"] = QString();
    row["rootId"] = rootId;
    row["isReply"] = !rootId.isEmpty();
    row["replyTo"] = QString();
    row["quoteBody"] = QString();
    row["quote"] = QString();
    row["threadRoot"] = rootId.isEmpty() ? postId : rootId;
    row["threadMark"] = QString();
    row["inThread"] = inThread ? QString("1") : QString();
    row["pending"] = QString();
    row["react"] = reactBits.join(QString("   "));
    row["reactOwn"] = reactOwn.join(",");
    row["imageId"] = imageId;
    row["imagePath"] = QString();
    row["imgW"] = showW;
    row["imgH"] = showH;
    row["imageId2"] = imageId2;
    row["imagePath2"] = QString();
    row["imgW2"] = showW2;
    row["imgH2"] = showH2;
    row["extraImages"] = images > 2 ? tr("+%1 more images").arg(images - 2) : QString();
    row["attachId"] = attachId;
    row["attachName"] = attachName;
    row["attachMime"] = attachMime;
    row["attachInfo"] = attachInfo;
    row["attachId2"] = attachId2;
    row["attachName2"] = attachName2;
    row["attachMime2"] = attachMime2;
    row["attachInfo2"] = attachInfo2;
    row["link"] = link;
    row["linkOnly"] = linkOnly;
    row["rev"] = post.value("update_at").toString() + ":" + QString::number(replyCount) + ":" + row["react"].toString();

    if (!imageId.isEmpty()) {
        const QString pv = ImageStore::dir() + "/" + imageId + ".pv";
        if (QFileInfo(pv).size() > 100)
            row["imagePath"] = ImageStore::fileUrl(pv);
    }
    if (!imageId2.isEmpty()) {
        const QString pv = ImageStore::dir() + "/" + imageId2 + ".pv";
        if (QFileInfo(pv).size() > 100)
            row["imagePath2"] = ImageStore::fileUrl(pv);
    }
    if (!inThread && !rootId.isEmpty()) {
        const QVariantMap root = all.value(rootId).toMap();
        row["replyTo"] = root.value("user_id").toString();
        QString snippet = Emoji::apply(repairText(root.value("message").toString())).simplified();
        if (snippet.length() > 70)
            snippet = snippet.left(70) + QString::fromUtf8("…");
        row["quoteBody"] = snippet;
    } else if (!inThread && rootId.isEmpty() && replyCount == 1) {
        row["threadMark"] = tr("1 reply");
    } else if (!inThread && rootId.isEmpty() && replyCount > 1) {
        row["threadMark"] = tr("%1 replies").arg(replyCount);
    }
    return row;
}

void MmClient::decorate(QVariantMap &row) const
{
    const QString uid = row.value("userId").toString();
    if (uid.isEmpty())
        return;
    const bool mine = row.value("mine").toBool();
    const QString label = nameOf(uid);
    row["title"] = mine ? tr("You") : label;
    row["initial"] = label.left(1).toUpper();
    row["avatar"] = ImageStore::avatarUrl(uid);
    row["disc"] = ImageStore::disc(ImageStore::colorFor(uid));

    if (row.value("isReply").toBool() && row.value("inThread").toString() != "1") {
        const QString body = row.value("quoteBody").toString();
        const QString to = row.value("replyTo").toString();
        QString who;
        if (!to.isEmpty())
            who = (to == m_userId) ? tr("you") : nameOf(to);
        QString quote = tr("Reply");
        if (!who.isEmpty() && who != tr("Unknown"))
            quote = tr("Reply to %1").arg(who);
        if (!body.isEmpty())
            quote += ": " + body;
        row["quote"] = quote;
    }
}

// ---------------------------------------------------------------- Dateien

void MmClient::queueJob(const FileJob &job, bool front)
{
    for (int i = 0; i < m_fileQueue.size(); ++i) {
        const FileJob &other = m_fileQueue.at(i);
        if (other.kind == job.kind && other.id == job.id)
            return;
    }
    if (front)
        m_fileQueue.prepend(job);
    else
        m_fileQueue.append(job);
}

void MmClient::queuePreview(const QString &fileId)
{
    if (fileId.isEmpty())
        return;
    if (QFileInfo(ImageStore::dir() + "/" + fileId + ".pv").size() > 100)
        return;
    FileJob job;
    job.kind = FilePreview;
    job.id = fileId;
    job.attempt = 0;
    queueJob(job, false);
}

void MmClient::queueAvatar(const QString &userId)
{
    if (userId.isEmpty() || m_avatarTried.contains(userId))
        return;
    const QFileInfo raw(ImageStore::dir() + "/" + userId + ".avatar");
    if (raw.size() > 32 && raw.lastModified().daysTo(QDateTime::currentDateTime()) < kAvatarMaxAgeDays)
        return;
    m_avatarTried.insert(userId);
    FileJob job;
    job.kind = FileAvatar;
    job.id = userId;
    job.attempt = 0;
    queueJob(job, false);
}

void MmClient::pumpFiles()
{
    while (m_filesBusy < 2 && !m_fileQueue.isEmpty())
        startJob(m_fileQueue.takeFirst());
}

void MmClient::startJob(const FileJob &job)
{
    QString api;
    QString save;
    int timeout = 30000;
    switch (job.kind) {
    case FilePreview:
        api = "/api/v4/files/" + job.id;
        if (job.attempt == 0)
            api += "/preview";
        else if (job.attempt == 1)
            api += "/thumbnail";
        save = ImageStore::dir() + "/" + job.id + ".pv";
        break;
    case FileFull:
        api = "/api/v4/files/" + job.id;
        save = ImageStore::dir() + "/" + job.id + ".full";
        timeout = 120000;
        break;
    case FileAvatar:
        api = "/api/v4/users/" + job.id + "/image";
        save = ImageStore::dir() + "/" + job.id + ".avatar";
        break;
    case FileAttach: {
        api = "/api/v4/files/" + job.id;
        const QString folder = ImageStore::dir() + "/att-" + job.id;
        QDir().mkpath(folder);
        save = folder + "/" + safeName(job.name);
        timeout = 120000;
        break;
    }
    }
    ++m_filesBusy;
    QNetworkReply *reply = start(StepFile, api, QByteArray(), "GET", true, timeout);
    reply->setProperty("kind", int(job.kind));
    reply->setProperty("fid", job.id);
    reply->setProperty("fname", job.name);
    reply->setProperty("fmime", job.mime);
    reply->setProperty("attempt", job.attempt);
    reply->setProperty("savePath", save);
}

void MmClient::finishFile(int kind, const QString &id, const QString &name, const QString &mime,
                          int attempt, const QString &savePath, int http, const QByteArray &payload)
{
    m_filesBusy = qMax(0, m_filesBusy - 1);
    bool ok = http == 200 && payload.size() > 32;
    if (ok && (kind == FileAvatar || kind == FilePreview))
        ok = ImageStore::isImage(payload.left(12));
    if (ok && kind == FileFull)
        ok = !payload.startsWith("{") && !payload.startsWith("<");
    if (ok) {
        QFile file(savePath);
        ok = file.open(QIODevice::WriteOnly) && file.write(payload) == payload.size();
        file.close();
    }

    if (ok) {
        const QString url = ImageStore::fileUrl(savePath);
        if (kind == FileAvatar) {
            QString round = ImageStore::makeAvatar(id);
            if (round.isEmpty())
                round = url;
            storeAvatar(id, round);
            emit avatarReady(id, round);
        } else if (kind == FilePreview) {
            storePreview(id, url);
            emit imageReady(id, url);
        } else if (kind == FileFull) {
            if (id == m_pendingFull) {
                m_pendingFull.clear();
                setStatus("");
                emit showImage(url);
            }
        } else if (kind == FileAttach) {
            if (id == m_pendingAttach) {
                m_pendingAttach.clear();
                setStatus("");
                openFile(savePath, mime);
            }
        }
    } else if (kind == FilePreview && attempt < 2 && http != 401) {
        FileJob retry;
        retry.kind = FilePreview;
        retry.id = id;
        retry.attempt = attempt + 1;
        queueJob(retry, true);
    } else if (kind == FileFull && id == m_pendingFull) {
        m_pendingFull.clear();
        setStatus(tr("Image could not be loaded"));
    } else if (kind == FileAttach && id == m_pendingAttach) {
        m_pendingAttach.clear();
        setStatus(tr("Attachment could not be loaded"));
    }
    Q_UNUSED(name);
    pumpFiles();
    if (http == 401)
        logout();
}

void MmClient::storeAvatar(const QString &userId, const QString &url)
{
    for (int i = 0; i < m_postRows.size(); ++i) {
        QVariantMap row = m_postRows.at(i).toMap();
        if (row.value("userId").toString() == userId) {
            row["avatar"] = url;
            m_postRows[i] = row;
        }
    }
    for (int i = 0; i < m_searchRows.size(); ++i) {
        QVariantMap row = m_searchRows.at(i).toMap();
        if (row.value("userId").toString() == userId) {
            row["avatar"] = url;
            m_searchRows[i] = row;
        }
    }
}

void MmClient::storePreview(const QString &fileId, const QString &url)
{
    for (int i = 0; i < m_postRows.size(); ++i) {
        QVariantMap row = m_postRows.at(i).toMap();
        if (row.value("imageId").toString() == fileId) {
            row["imagePath"] = url;
            m_postRows[i] = row;
        }
    }
    for (int i = 0; i < m_searchRows.size(); ++i) {
        QVariantMap row = m_searchRows.at(i).toMap();
        if (row.value("imageId").toString() == fileId) {
            row["imagePath"] = url;
            m_searchRows[i] = row;
        }
    }
}

void MmClient::openImage(const QString &fileId)
{
    if (fileId.isEmpty())
        return;
    const QString path = ImageStore::dir() + "/" + fileId + ".full";
    if (QFileInfo(path).size() > 100) {
        emit showImage(ImageStore::fileUrl(path));
        return;
    }
    m_pendingFull = fileId;
    setStatus(tr("Loading image…"));
    FileJob job;
    job.kind = FileFull;
    job.id = fileId;
    job.attempt = 0;
    queueJob(job, true);
    pumpFiles();
}

void MmClient::openAttachment(const QString &fileId, const QString &name, const QString &mime)
{
    if (fileId.isEmpty())
        return;
    const QString path = ImageStore::dir() + "/att-" + fileId + "/" + safeName(name);
    if (QFileInfo(path).size() > 0) {
        openFile(path, mime);
        return;
    }
    m_pendingAttach = fileId;
    setStatus(tr("Loading attachment…"));
    FileJob job;
    job.kind = FileAttach;
    job.id = fileId;
    job.name = name;
    job.mime = mime;
    job.attempt = 0;
    queueJob(job, true);
    pumpFiles();
}

// ---------------------------------------------------------------- Abschluss der Abrufe

void MmClient::partDone()
{
    if (--m_chanParts <= 0)
        finishChannels();
}

void MmClient::finishChannels()
{
    m_chanParts = 0;
    QList<QVariantMap> channels;
    QList<QVariantMap> directs;
    QStringList avatarIds;
    avatarIds.append(m_userId);

    for (int i = 0; i < m_channelRows.size(); ++i) {
        QVariantMap row = m_channelRows.at(i).toMap();
        const QString kind = row.value("kind").toString();
        const QString peer = row.value("peerId").toString();
        row["type"] = QString("channel");
        row["badge"] = ImageStore::disc(row.value("mentions").toInt() > 0 ? "#d6322e" : "#1c58d9");

        if (kind == "D") {
            const QString who = peer.isEmpty() ? m_userId : peer;
            QString title = peer.isEmpty() ? tr("Note to self") : nameOf(peer);
            row["title"] = title;
            row["subtitle"] = (m_users.contains(who) && !m_users.value(who).username.isEmpty())
                ? "@" + m_users.value(who).username : QString();
            row["tile"] = ImageStore::disc(ImageStore::colorFor(who));
            row["initial"] = title.left(1).toUpper();
            row["avatar"] = ImageStore::avatarUrl(who);
            avatarIds.append(who);
            directs.append(row);
        } else if (kind == "G") {
            row["subtitle"] = QString("Gruppe");
            row["tile"] = ImageStore::disc(ImageStore::colorFor(row.value("channelId").toString()));
            row["initial"] = row.value("title").toString().left(1).toUpper();
            row["avatar"] = QString();
            directs.append(row);
        } else {
            row["tile"] = (kind == "P") ? ImageStore::tileLock("#b9822a")
                                        : ImageStore::tileChannel("#1c58d9");
            row["initial"] = QString();
            row["avatar"] = QString();
            channels.append(row);
        }
        m_channelRows[i] = row;
    }
    qSort(channels.begin(), channels.end(), lessTitle);
    qSort(directs.begin(), directs.end(), moreRecent);

    QVariantList view;
    if (!channels.isEmpty()) {
        QVariantMap header;
        header["type"] = QString("header");
        header["title"] = tr("CHANNELS");
        view.append(header);
        for (int i = 0; i < channels.size(); ++i)
            view.append(channels.at(i));
    }
    if (!directs.isEmpty()) {
        QVariantMap header;
        header["type"] = QString("header");
        header["title"] = tr("DIRECT");
        view.append(header);
        for (int i = 0; i < directs.size(); ++i)
            view.append(directs.at(i));
    }
    m_chansBusy = false;
    ensureStore();
    m_store.saveChannels(view);
    emit channelsLoaded(view);
    if (m_status.endsWith(QChar(0x2026)))
        setStatus("");
    for (int i = 0; i < avatarIds.size(); ++i)
        queueAvatar(avatarIds.at(i));
    pumpFiles();
    syncInbox();
}

void MmClient::finishPosts()
{
    m_postsBusy = false;
    QStringList seen;
    for (int i = 0; i < m_postRows.size(); ++i) {
        QVariantMap row = m_postRows.at(i).toMap();
        decorate(row);
        m_postRows[i] = row;
        const QString uid = row.value("userId").toString();
        if (!uid.isEmpty() && !seen.contains(uid)) {
            seen.append(uid);
            queueAvatar(uid);
        }
    }
    ackOutbox(m_postRows);
    publishPosts();
    if (m_status.endsWith(QChar(0x2026)))
        setStatus("");
    pumpFiles();
    if (m_postsAgain) {
        m_postsAgain = false;
        loadPosts(true);
    }
}

void MmClient::finishSearch()
{
    QStringList seen;
    for (int i = 0; i < m_searchRows.size(); ++i) {
        QVariantMap row = m_searchRows.at(i).toMap();
        decorate(row);
        m_searchRows[i] = row;
        const QString uid = row.value("userId").toString();
        if (!uid.isEmpty() && !seen.contains(uid)) {
            seen.append(uid);
            queueAvatar(uid);
        }
    }
    emit searchLoaded(m_searchRows);
    if (m_status.endsWith(QChar(0x2026)))
        setStatus("");
    pumpFiles();
}

// ---------------------------------------------------------------- Antworten verarbeiten

void MmClient::onFinished(QNetworkReply *reply)
{
    const Step step = Step(reply->property("step").toInt());
    const bool silent = reply->property("silent").toBool();
    const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const int netCode = int(reply->error());
    const QByteArray payload = reply->readAll();
    const QByteArray tokenHeader = reply->rawHeader("Token");
    const QString chan = reply->property("chan").toString();
    const int kind = reply->property("kind").toInt();
    const QString fid = reply->property("fid").toString();
    const QString fname = reply->property("fname").toString();
    const QString fmime = reply->property("fmime").toString();
    const QString savePath = reply->property("savePath").toString();
    const int attempt = reply->property("attempt").toInt();
    const QString localId = reply->property("localId").toString();
    const QString msg = reply->property("msg").toString();
    const QString root = reply->property("root").toString();
    if (m_debugLog)
        qDebug("mm-net step %d http %d net %d", int(step), http, netCode);
    if (m_headless && netCode != 0) {
        QString why = reply->errorString();
        why.replace(QRegExp("https?://\\S+"), "");
        const QByteArray whyBytes = why.left(72).toLatin1();
        const QSslCertificate peer = reply->sslConfiguration().peerCertificate();
        void *crypto = dlopen("libcrypto.so", RTLD_NOW);
        typedef unsigned long (*ErrGetFn)();
        typedef const char *(*ErrStrFn)(unsigned long);
        ErrGetFn errGet = crypto ? (ErrGetFn)dlsym(crypto, "ERR_get_error") : 0;
        ErrStrFn errStr = crypto ? (ErrStrFn)dlsym(crypto, "ERR_reason_error_string") : 0;
        const unsigned long err = errGet ? errGet() : 0;
        const char *reason = (err && errStr && errStr(err)) ? errStr(err) : "none";
        qDebug("mm-hub fail step %d net %d ssl %d trust %d peer %d err %s why %s",
               int(step), netCode, reply->property("ssl").toInt(), g_trust.size(),
               peer.isNull() ? 0 : 1, reason, whyBytes.constData());
    }
    reply->deleteLater();

    if (step == StepFile) {
        finishFile(kind, fid, fname, fmime, attempt, savePath, http, payload);
        return;
    }
    if (step == StepView)
        return;
    if (step != StepLogin && !m_loggedIn)
        return;

    if (http == 401) {
        if (step == StepLogin) {
            const QString body = QString::fromUtf8(payload);
            const bool needCode = body.contains("mfa");
            // Dieselbe Marke bad_code kommt auch, wenn noch kein Code gesendet wurde.
            const bool badCode = m_mfaSent
                && (body.contains("invalid_credentials_mfa") || body.contains("bad_code"));
            if (needCode && !m_mfaPassword.isEmpty()) {
                setStatus(badCode ? tr("Code is wrong")
                                  : tr("One-time code required"));
                emit mfaRequired();
                return;
            }
            m_mfaPassword.clear();
            m_mfaSent = false;
            setStatus(tr("Name or password is wrong"));
        } else {
            logout();
            setStatus(tr("Session expired. Please sign in again."));
        }
        return;
    }
    const QString page = reply->property("page").toString();
    const bool around = (step == StepPosts || step == StepPost)
        && (page == "self" || page == "before" || page == "after");
    if (around && (http >= 400 || (http == 0 && netCode != 0) || chan != m_channelId)) {
        if (!aroundMatches(reply))
            return;
        if (--m_aroundLeft <= 0)
            finishAround();
        return;
    }
    if ((step == StepSend || step == StepUpload || step == StepReact)
            && (http >= 400 || http == 0 || netCode != 0)) {
        const bool network = http < 400;
        outgoingDone(localId, false, network, msg);
        return;
    }
    if (step == StepReact) {
        outgoingDone(localId, true, false, QString());
        return;
    }
    if (http >= 400 || (http == 0 && netCode != 0)) {
        const bool heldPage = step == StepPosts
            && (m_aroundLeft > 0 || (m_anchored && page != "older" && page != "newer"));
        if (heldPage)
            return;
        failed(step, silent, http, netCode);
        return;
    }

    JsonDataAccess json;
    QVariant parsed;
    if (step != StepLogin) {
        parsed = json.loadFromBuffer(payload);
        if (json.hasError()) {
            if (around) {
                if (!aroundMatches(reply))
                    return;
                if (--m_aroundLeft <= 0)
                    finishAround();
                return;
            }
            if (step == StepPosts
                    && (m_aroundLeft > 0 || (m_anchored && page != "older" && page != "newer")))
                return;
            if (step == StepUpload || step == StepSend)
                outgoingDone(localId, false, false, msg);
            else
                failed(step, silent, -1, 0);
            return;
        }
    }

    if (step == StepLogin) {
        if (tokenHeader.isEmpty()) {
            setStatus(tr("No token in the response"));
            return;
        }
        m_mfaPassword.clear();
        m_mfaSent = false;
        m_token = QString::fromUtf8(tokenHeader);
        const QVariantMap user = json.loadFromBuffer(payload).toMap();
        m_userId = user.value("id").toString();
        QVariantList me;
        me.append(user);
        learnUsers(me);
        QSettings settings("hollweck", "mattermost");
        settings.setValue("serverUrl", m_serverUrl);
        settings.setValue("username", m_username);
        settings.setValue("token", m_token);
        settings.setValue("userId", m_userId);
        setLoggedIn(true);
        emit sessionChanged();
        queueAvatar(m_userId);
        pumpFiles();
        loadTeams();
        return;
    }

    if (step == StepMe) {
        const QVariantMap user = parsed.toMap();
        m_userId = user.value("id").toString();
        QVariantList me;
        me.append(user);
        learnUsers(me);
        if (m_username.isEmpty())
            m_username = personLabel(user);
        QSettings settings("hollweck", "mattermost");
        settings.setValue("userId", m_userId);
        queueAvatar(m_userId);
        pumpFiles();
        loadTeams();
        return;
    }

    if (step == StepTeams) {
        const QVariantList teams = parsed.toList();
        if (teams.isEmpty()) {
            setStatus(tr("No team on this account"));
            quitIfHeadless();
            return;
        }
        offerTeams(teams);
        return;
    }

    if (step == StepChannels) {
        m_channelRows.clear();
        QStringList peers;
        const QVariantList channels = parsed.toList();
        for (int i = 0; i < channels.size(); ++i) {
            const QVariantMap channel = channels.at(i).toMap();
            if (channel.value("delete_at").toLongLong() != 0)
                continue;
            const QString type = channel.value("type").toString();
            if (type != "O" && type != "P" && type != "D" && type != "G")
                continue;
            QString title = channel.value("display_name").toString().trimmed();
            QString peer;
            if (type == "D") {
                const QStringList parts = channel.value("name").toString().split("__");
                for (int p = 0; p < parts.size(); ++p) {
                    if (!parts.at(p).isEmpty() && parts.at(p) != m_userId)
                        peer = parts.at(p);
                }
            } else if (title.isEmpty()) {
                title = channel.value("name").toString();
                if (title.contains("__"))
                    title = tr("Conversation");
            }
            QString subtitle = channel.value("purpose").toString().simplified();
            if (subtitle.isEmpty())
                subtitle = channel.value("header").toString().simplified();
            if (subtitle.length() > 80)
                subtitle = subtitle.left(80) + QString::fromUtf8("…");

            QVariantMap row;
            row["channelId"] = channel.value("id").toString();
            row["kind"] = type;
            row["title"] = repairText(title);
            row["subtitle"] = (type == "O" || type == "P") ? repairText(subtitle) : QString();
            row["peerId"] = peer;
            row["last"] = channel.value("last_post_at").toLongLong();
            row["total"] = channel.value("total_msg_count").toLongLong();
            const qint64 last = channel.value("last_post_at").toLongLong();
            row["when"] = last > 0 ? shortWhen(last) : QString();
            row["unread"] = 0;
            row["mentions"] = 0;
            row["tile"] = QString();
            row["initial"] = QString();
            row["avatar"] = QString();
            m_channelRows.append(row);
            if (type == "D" && !peer.isEmpty() && !peers.contains(peer))
                peers.append(peer);
        }
        const QStringList missing = unknownUsers(peers);
        m_chanParts = missing.isEmpty() ? 1 : 2;
        start(StepMembers, "/api/v4/users/me/teams/" + m_teamId + "/channels/members",
              QByteArray(), "GET", m_chansSilent);
        if (!missing.isEmpty())
            loadUsers(missing, StepChannelUsers);
        return;
    }

    if (step == StepMembers) {
        const QVariantList members = parsed.toList();
        for (int i = 0; i < members.size(); ++i) {
            const QVariantMap member = members.at(i).toMap();
            const QString cid = member.value("channel_id").toString();
            for (int r = 0; r < m_channelRows.size(); ++r) {
                QVariantMap row = m_channelRows.at(r).toMap();
                if (row.value("channelId").toString() != cid)
                    continue;
                qint64 unread = row.value("total").toLongLong() - member.value("msg_count").toLongLong();
                if (unread < 0)
                    unread = 0;
                const QString mark = member.value("notify_props").toMap().value("mark_unread").toString();
                if (mark == "mention")
                    unread = 0;
                int mentions = member.value("mention_count").toInt();
                if (cid == m_channelId) {
                    unread = 0;
                    mentions = 0;
                }
                row["unread"] = int(unread);
                row["mentions"] = mentions;
                m_channelRows[r] = row;
                break;
            }
        }
        partDone();
        return;
    }

    if (step == StepChannelUsers) {
        learnUsers(parsed.toList());
        partDone();
        return;
    }

    if (step == StepPost || (step == StepPosts && (page == "before" || page == "after"))) {
        if (!aroundMatches(reply))
            return;
        if (chan == m_channelId)
            absorbAround(page, parsed);
        if (--m_aroundLeft <= 0)
            finishAround();
        return;
    }

    if (step == StepPosts) {
        const bool hold = m_aroundLeft > 0
            || (m_anchored && page != "older" && page != "newer");
        if (hold)
            return;
        if (chan != m_channelId) {
            if (m_anchored)
                return;
            const bool jump = !m_focusPost.isEmpty();
            if (jump)
                m_postsAgain = true;
            postsIdle();
            if (!jump && !m_channelId.isEmpty())
                loadPosts(false);
            return;
        }
        if (!m_focusPost.isEmpty()) {
            m_postsAgain = true;
            postsIdle();
            return;
        }
        const QVariantMap root = parsed.toMap();
        const QVariantList order = root.value("order").toList();
        const QVariantMap posts = root.value("posts").toMap();
        if (page != "older" && page != "newer") {
            QString sig;
            for (int i = 0; i < order.size(); ++i) {
                const QString id = order.at(i).toString();
                const QVariantMap post = posts.value(id).toMap();
                sig += id + ":" + post.value("update_at").toString() + ":"
                    + post.value("reply_count").toString() + ":" + reactionSig(post) + ";";
            }
            if (silent && sig == m_postsSig && !m_postRows.isEmpty()) {
                postsIdle();
                return;
            }
            m_postsSig = sig;
        }
        mergePosts(page.isEmpty() ? QString("latest") : page, order, posts);
        const bool atEdge = page != "older" && page != "newer";
        if (page == "older")
            setHistory(order.size() >= kPerPage, m_hasNewer);
        else if (page == "newer")
            setHistory(m_hasOlder, order.size() >= kPerPage);
        else if (!silent)
            setHistory(order.size() >= kPerPage, false);
        commitPosts(atEdge && !order.isEmpty());
        return;
    }

    if (step == StepUsers) {
        learnUsers(parsed.toList());
        finishPosts();
        return;
    }

    if (step == StepSend) {
        outgoingDone(localId, true, false, QString());
        return;
    }

    if (step == StepUpload) {
        const QVariantList infos = parsed.toMap().value("file_infos").toList();
        if (infos.isEmpty()) {
            outgoingDone(localId, false, false, msg);
            return;
        }
        const QString fileId = infos.at(0).toMap().value("id").toString();
        QVariantMap body;
        body["channel_id"] = chan;
        body["message"] = msg;
        body["pending_post_id"] = localId;
        if (!root.isEmpty())
            body["root_id"] = root;
        QVariantList fileIds;
        fileIds.append(fileId);
        body["file_ids"] = fileIds;
        QByteArray bytes;
        json.saveToBuffer(body, &bytes);
        QNetworkReply *next = start(StepSend, "/api/v4/posts", bytes, "POST", true);
        next->setProperty("localId", localId);
        next->setProperty("msg", msg);
        next->setProperty("root", root);
        next->setProperty("chan", chan);
        return;
    }

    if (step == StepThread) {
        if (root != m_threadRoot) {
            m_threadBusy = false;
            return;
        }
        const QVariantMap body = parsed.toMap();
        const QVariantList order = body.value("order").toList();
        const QVariantMap posts = body.value("posts").toMap();
        QString sig;
        for (int i = 0; i < order.size(); ++i) {
            const QString id = order.at(i).toString();
            const QVariantMap post = posts.value(id).toMap();
            sig += id + ":" + post.value("update_at").toString() + ":" + reactionSig(post) + ";";
        }
        if (silent && sig == m_threadSig && !m_replyRows.isEmpty()) {
            m_threadBusy = false;
            return;
        }
        m_threadSig = sig;
        QStringList ids;
        m_replyRows = buildConversation(order, posts, true, ids);
        const QStringList missing = unknownUsers(ids);
        if (missing.isEmpty())
            finishThread();
        else
            loadUsers(missing, StepThreadUsers);
        return;
    }

    if (step == StepThreadUsers) {
        learnUsers(parsed.toList());
        finishThread();
        return;
    }

    if (step == StepSearch) {
        const QVariantMap root = parsed.toMap();
        const QVariantList order = root.value("order").toList();
        const QVariantMap posts = root.value("posts").toMap();
        m_searchRows.clear();
        QStringList ids;
        for (int i = 0; i < order.size(); ++i) {
            const QVariantMap post = posts.value(order.at(i).toString()).toMap();
            if (post.value("type").toString().startsWith("system_"))
                continue;
            QVariantMap row = makePostRow(post, posts);
            row["type"] = QString("result");
            row["channelTitle"] = channelTitle(row.value("channelId").toString());
            const QString imageId = row.value("imageId").toString();
            if (!imageId.isEmpty() && row.value("imagePath").toString().isEmpty())
                queuePreview(imageId);
            m_searchRows.append(row);
            const QString uid = row.value("userId").toString();
            if (!uid.isEmpty() && !ids.contains(uid))
                ids.append(uid);
        }
        const QStringList missing = unknownUsers(ids);
        if (missing.isEmpty())
            finishSearch();
        else
            loadUsers(missing, StepSearchUsers);
        return;
    }

    if (step == StepSearchUsers) {
        learnUsers(parsed.toList());
        finishSearch();
        return;
    }
}

// ---------------------------------------------------------------- Threads, Reaktionen, Ausgangskorb

void MmClient::ensureStore()
{
    if (m_headless || m_userId.isEmpty() || !m_store.open() || m_usersLoaded)
        return;
    m_usersLoaded = true;
    const QVariantList list = m_store.users();
    for (int i = 0; i < list.size(); ++i) {
        const QVariantMap row = list.at(i).toMap();
        const QString id = row.value("id").toString();
        if (id.isEmpty() || m_users.contains(id))
            continue;
        UserInfo info;
        info.label = row.value("label").toString();
        info.username = row.value("username").toString();
        m_users.insert(id, info);
    }
}

QVariantList MmClient::buildConversation(const QVariantList &order, const QVariantMap &posts,
                                         bool inThread, QStringList &userIds)
{
    QVariantList rows;
    QDate lastDay;
    QString prevUser;
    QString prevRoot;
    qint64 prevTime = 0;
    bool havePrev = false;
    for (int i = order.size() - 1; i >= 0; --i) {
        const QVariantMap post = posts.value(order.at(i).toString()).toMap();
        if (post.value("type").toString().startsWith("system_"))
            continue;
        const qint64 created = post.value("create_at").toLongLong();
        const QDate day = QDateTime::fromMSecsSinceEpoch(created).date();
        if (day != lastDay) {
            QVariantMap sep;
            sep["id"] = "day-" + day.toString("yyyyMMdd");
            sep["type"] = QString("day");
            sep["title"] = dayLabel(day);
            sep["rev"] = dayLabel(day);
            rows.append(sep);
            lastDay = day;
            havePrev = false;
        }
        QVariantMap row = makePostRow(post, posts, inThread);
        const QString uid = row.value("userId").toString();
        const QString rootId = row.value("rootId").toString();
        row["grouped"] = havePrev && uid == prevUser && rootId == prevRoot && created - prevTime < kGroupMs;
        prevUser = uid;
        prevRoot = rootId;
        prevTime = created;
        havePrev = true;
        rows.append(row);
        if (!uid.isEmpty() && !userIds.contains(uid))
            userIds.append(uid);
        if (!row.value("imageId").toString().isEmpty() && row.value("imagePath").toString().isEmpty())
            queuePreview(row.value("imageId").toString());
        if (!row.value("imageId2").toString().isEmpty() && row.value("imagePath2").toString().isEmpty())
            queuePreview(row.value("imageId2").toString());
    }
    return rows;
}

void MmClient::publishPosts()
{
    ensureStore();
    if (!m_channelId.isEmpty())
        m_store.savePosts(m_channelId, m_postRows);
    emit postsLoaded(withPending(m_postRows, false));
}

void MmClient::publishThread()
{
    ensureStore();
    if (!m_threadRoot.isEmpty())
        m_store.saveThread(m_threadRoot, m_replyRows);
    emit repliesLoaded(withPending(m_replyRows, true));
}

QVariantMap MmClient::pendingRow(const OutItem &item, bool inThread) const
{
    QVariantMap row;
    row["id"] = item.id;
    row["type"] = QString("post");
    row["userId"] = m_userId;
    row["mine"] = true;
    row["plain"] = item.message;
    row["message"] = Markdown::html(Emoji::apply(item.message));
    row["whenTime"] = tr("Sending…");
    row["whenFull"] = row["whenTime"];
    row["createAt"] = QDateTime::currentMSecsSinceEpoch();
    row["title"] = QString("Du");
    row["initial"] = m_username.left(1).toUpper();
    row["avatar"] = ImageStore::avatarUrl(m_userId);
    row["disc"] = ImageStore::disc(ImageStore::colorFor(m_userId));
    row["grouped"] = false;
    row["channelId"] = item.channelId;
    row["channelTitle"] = QString();
    row["rootId"] = item.rootId;
    row["isReply"] = !item.rootId.isEmpty();
    row["replyTo"] = QString();
    row["quoteBody"] = QString();
    row["quote"] = QString();
    row["threadRoot"] = item.rootId;
    row["threadMark"] = QString();
    row["inThread"] = inThread ? QString("1") : QString();
    row["pending"] = QString("1");
    row["react"] = QString();
    row["reactOwn"] = QString();
    row["imageId"] = QString();
    row["imagePath"] = QString();
    row["imgW"] = 360;
    row["imgH"] = 240;
    row["imageId2"] = QString();
    row["imagePath2"] = QString();
    row["imgW2"] = 0;
    row["imgH2"] = 0;
    row["extraImages"] = QString();
    row["attachId"] = QString();
    row["attachName"] = QString();
    row["attachMime"] = QString();
    row["attachInfo"] = QString();
    row["attachId2"] = QString();
    row["attachName2"] = QString();
    row["attachMime2"] = QString();
    row["attachInfo2"] = QString();
    row["link"] = QString();
    row["linkOnly"] = false;
    row["rev"] = item.id;
    if (!item.filePath.isEmpty()) {
        const QString ext = QFileInfo(item.filePath).suffix().toLower();
        const bool image = ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "gif" || ext == "webp";
        row["attachName"] = item.fileName.isEmpty()
            ? QFileInfo(item.filePath).fileName() : item.fileName;
        row["attachInfo"] = tr("Sending");
        if (image) {
            row["imageId"] = QString("local");
            row["imagePath"] = ImageStore::fileUrl(item.filePath);
        } else {
            row["attachId"] = QString("local");
        }
    }
    return row;
}

QVariantList MmClient::withPending(const QVariantList &rows, bool inThread) const
{
    QVariantList out = rows;
    if (!m_store.isOpen())
        return out;
    const QList<OutItem> items = m_store.outbox();
    for (int i = 0; i < items.size(); ++i) {
        const OutItem &item = items.at(i);
        if (item.kind != "post" && item.kind != "file")
            continue;
        if (item.channelId != m_channelId)
            continue;
        if (inThread && item.rootId != m_threadRoot)
            continue;
        out.append(pendingRow(item, inThread));
    }
    return out;
}

bool MmClient::ownsReaction(const QString &postId, const QString &emojiName) const
{
    for (int pass = 0; pass < 2; ++pass) {
        const QVariantList &rows = pass == 0 ? m_postRows : m_replyRows;
        for (int i = 0; i < rows.size(); ++i) {
            const QVariantMap row = rows.at(i).toMap();
            if (row.value("id").toString() != postId)
                continue;
            return row.value("reactOwn").toString().split(",").contains(emojiName);
        }
    }
    return false;
}

void MmClient::ackOutbox(const QVariantList &rows)
{
    if (!m_store.isOpen())
        return;
    const QList<OutItem> items = m_store.outbox();
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    for (int i = 0; i < items.size(); ++i) {
        const OutItem &item = items.at(i);
        if (item.id == m_inflight || item.message.isEmpty())
            continue;
        if (item.kind != "post" && item.kind != "file")
            continue;
        for (int r = 0; r < rows.size(); ++r) {
            const QVariantMap row = rows.at(r).toMap();
            const QString shown = row.value("plain").toString().isEmpty()
                ? row.value("message").toString() : row.value("plain").toString();
            if (!row.value("mine").toBool() || shown != item.message)
                continue;
            const qint64 created = row.value("createAt").toLongLong();
            if (created > 0 && now - created < 30000 && now - created >= 0) {
                m_store.remove(item.id);
                break;
            }
        }
    }
}

void MmClient::submit(const QString &channelId, const QString &rootId,
                      const QString &message, const QString &filePath, const QString &fileName)
{
    if (channelId.isEmpty() || (message.isEmpty() && filePath.isEmpty()))
        return;
    ensureStore();
    OutItem item;
    item.id = "local-" + QString::number(QDateTime::currentMSecsSinceEpoch());
    item.kind = filePath.isEmpty() ? QString("post") : QString("file");
    item.channelId = channelId;
    item.rootId = rootId;
    item.message = message;
    item.filePath = filePath;
    item.fileName = fileName;
    m_store.enqueue(item);
    m_lastSent = message;
    if (channelId == m_channelId)
        publishPosts();
    if (!rootId.isEmpty() && rootId == m_threadRoot)
        publishThread();
    flushOutbox();
}

bool MmClient::attachFile(const QString &path, const QString &message, const QString &rootId,
                          const QString &displayName)
{
    const QString text = message.trimmed();
    QString dest = localPath(path);
    if (!isStaged(dest))
        dest = copyIntoCache(dest);
    if (dest.isEmpty() || !QFileInfo(dest).isFile()) {
        if (!text.isEmpty())
            emit sendFailed(text);
        setStatus(tr("File is not readable"));
        return false;
    }
    QString name = displayName.trimmed();
    if (name.isEmpty())
        name = QFileInfo(localPath(path)).fileName();
    submit(m_channelId, rootId, text, dest, uploadName(safeName(name)));
    return true;
}

QString MmClient::stageFile(const QString &path)
{
    const QString dest = copyIntoCache(path);
    if (dest.isEmpty())
        setStatus(tr("File is not readable"));
    return dest;
}

void MmClient::dropStaged(const QString &path)
{
    const QString local = localPath(path);
    if (!isStaged(local))
        return;
    QFile::remove(local);
}

bool MmClient::fileIsImage(const QString &path) const
{
    QFile file(localPath(path));
    if (!file.open(QIODevice::ReadOnly))
        return false;
    return ImageStore::isImage(file.read(12));
}

void MmClient::toggleReaction(const QString &postId, const QString &emojiName)
{
    if (postId.isEmpty() || emojiName.isEmpty() || postId.startsWith("local-"))
        return;
    ensureStore();
    OutItem item;
    item.id = "local-rx-" + QString::number(QDateTime::currentMSecsSinceEpoch());
    item.kind = ownsReaction(postId, emojiName) ? QString("unreact") : QString("react");
    item.postId = postId;
    item.emoji = emojiName;
    item.channelId = m_channelId;
    m_store.enqueue(item);
    flushOutbox();
}

void MmClient::flushOutbox()
{
    if (!m_loggedIn || !m_inflight.isEmpty() || m_token.isEmpty())
        return;
    ensureStore();
    const QList<OutItem> items = m_store.outbox();
    if (!items.isEmpty())
        sendOut(items.first());
}

void MmClient::sendOut(const OutItem &item)
{
    m_inflight = item.id;
    if (item.kind == "file") {
        startUpload(item);
        return;
    }
    if (item.kind == "react" || item.kind == "unreact") {
        QNetworkReply *reply = 0;
        if (item.kind == "unreact") {
            reply = start(StepReact, "/api/v4/users/" + m_userId + "/posts/" + item.postId
                          + "/reactions/" + item.emoji, QByteArray(), "DELETE", true);
        } else {
            QVariantMap body;
            body["user_id"] = m_userId;
            body["post_id"] = item.postId;
            body["emoji_name"] = item.emoji;
            QByteArray bytes;
            JsonDataAccess json;
            json.saveToBuffer(body, &bytes);
            reply = start(StepReact, "/api/v4/reactions", bytes, "POST", true);
        }
        reply->setProperty("localId", item.id);
        reply->setProperty("chan", item.channelId);
        return;
    }
    QVariantMap body;
    body["channel_id"] = item.channelId;
    body["message"] = item.message;
    body["pending_post_id"] = item.id;
    if (!item.rootId.isEmpty())
        body["root_id"] = item.rootId;
    QByteArray bytes;
    JsonDataAccess json;
    json.saveToBuffer(body, &bytes);
    QNetworkReply *reply = start(StepSend, "/api/v4/posts", bytes, "POST", true);
    reply->setProperty("localId", item.id);
    reply->setProperty("msg", item.message);
    reply->setProperty("root", item.rootId);
    reply->setProperty("chan", item.channelId);
}

void MmClient::startUpload(const OutItem &item)
{
    QFile *file = new QFile(item.filePath);
    if (!file->open(QIODevice::ReadOnly)) {
        delete file;
        outgoingDone(item.id, false, false, item.message);
        return;
    }
    QString name = item.fileName.trimmed();
    if (name.isEmpty())
        name = QFileInfo(item.filePath).fileName();
    name = uploadName(safeName(name));
    QString mime = "application/octet-stream";
    const QString ext = QFileInfo(item.filePath).suffix().toLower();
    if (ext == "png")
        mime = "image/png";
    else if (ext == "jpg" || ext == "jpeg")
        mime = "image/jpeg";
    else if (ext == "gif")
        mime = "image/gif";
    else if (ext == "webp")
        mime = "image/webp";
    else if (ext == "pdf")
        mime = "application/pdf";
    else if (ext == "txt")
        mime = "text/plain";

    QHttpMultiPart *multi = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    QHttpPart channelPart;
    channelPart.setHeader(QNetworkRequest::ContentDispositionHeader,
                          QVariant("form-data; name=\"channel_id\""));
    channelPart.setBody(item.channelId.toUtf8());
    multi->append(channelPart);
    QHttpPart filePart;
    const QByteArray disposition = QByteArray("form-data; name=\"files\"; filename=\"")
        + name.toUtf8() + "\"";
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant(disposition));
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant(mime));
    filePart.setBodyDevice(file);
    file->setParent(multi);
    multi->append(filePart);

    QNetworkRequest request(QUrl(m_serverUrl + "/api/v4/files"));
    applyTrust(request);
    request.setRawHeader("Accept", "application/json");
    if (!m_token.isEmpty())
        request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    QNetworkReply *reply = m_net.post(request, multi);
    multi->setParent(reply);
    reply->setProperty("step", int(StepUpload));
    reply->setProperty("silent", true);
    reply->setProperty("localId", item.id);
    reply->setProperty("msg", item.message);
    reply->setProperty("root", item.rootId);
    reply->setProperty("chan", item.channelId);
    armAbort(reply, 120000);
}

void MmClient::outgoingDone(const QString &localId, bool ok, bool network, const QString &message)
{
    if (m_inflight == localId)
        m_inflight.clear();
    if (ok) {
        m_store.remove(localId);
        m_anchored = false;
        if (!m_channelId.isEmpty())
            loadPosts(true);
        if (!m_threadRoot.isEmpty())
            loadThread(true);
        flushOutbox();
        return;
    }
    if (network) {
        setStatus(tr("No connection. It will be sent when you are online."));
        if (!m_channelId.isEmpty())
            publishPosts();
        if (!m_threadRoot.isEmpty())
            publishThread();
        return;
    }
    m_store.remove(localId);
    if (!message.isEmpty())
        emit sendFailed(message);
    setStatus(tr("Not sent"));
    if (!m_channelId.isEmpty())
        publishPosts();
    if (!m_threadRoot.isEmpty())
        publishThread();
    flushOutbox();
}

void MmClient::openThread(const QString &rootId)
{
    m_threadRoot = rootId;
    m_threadSig.clear();
    ensureStore();
    m_replyRows = m_store.thread(rootId);
    if (!m_replyRows.isEmpty())
        emit repliesLoaded(withPending(m_replyRows, true));
    loadThread(false);
}

void MmClient::closeThread()
{
    m_threadRoot.clear();
    m_threadSig.clear();
    m_replyRows.clear();
    m_threadBusy = false;
    m_threadAgain = false;
}

void MmClient::loadThread(bool silent)
{
    if (!m_loggedIn || m_threadRoot.isEmpty())
        return;
    if (m_threadBusy) {
        m_threadAgain = true;
        return;
    }
    m_threadBusy = true;
    if (!silent)
        setStatus(tr("Loading thread…"));
    QNetworkReply *reply = start(StepThread, "/api/v4/posts/" + m_threadRoot + "/thread",
                                 QByteArray(), "GET", silent);
    reply->setProperty("root", m_threadRoot);
}

void MmClient::finishThread()
{
    m_threadBusy = false;
    QStringList seen;
    for (int i = 0; i < m_replyRows.size(); ++i) {
        QVariantMap row = m_replyRows.at(i).toMap();
        decorate(row);
        m_replyRows[i] = row;
        const QString uid = row.value("userId").toString();
        if (!uid.isEmpty() && !seen.contains(uid)) {
            seen.append(uid);
            queueAvatar(uid);
        }
    }
    publishThread();
    if (m_status.endsWith(QChar(0x2026)))
        setStatus("");
    pumpFiles();
    if (m_threadAgain) {
        m_threadAgain = false;
        loadThread(true);
    }
}
