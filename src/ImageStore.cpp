#include "ImageStore.hpp"

#include <QColor>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QPen>
#include <QStringList>
#include <QUrl>

namespace ImageStore {

namespace {

const int kBig = 512;      // gezeichnet wird groß und dann glatt verkleinert
const int kTile = 128;     // Kantenlänge der Symbole
const int kAvatar = 128;   // Kantenlänge der runden Profilbilder

QImage blank()
{
    QImage img(kBig, kBig, QImage::Format_ARGB32_Premultiplied);
    img.fill(0);
    return img;
}

bool saveSmall(const QImage &big, int px, const QString &path)
{
    const QImage small = big.scaled(px, px, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    return small.save(path, "PNG");
}

QString pathFor(const QString &name)
{
    return dir() + "/" + name;
}

bool present(const QString &path)
{
    return QFileInfo(path).size() > 64;
}

QPointF pt(double x, double y)
{
    return QPointF(x * kBig, y * kBig);
}

void paintDisc(QPainter &p, const QColor &color)
{
    p.setPen(Qt::NoPen);
    p.setBrush(color);
    p.drawEllipse(QRectF(0, 0, kBig, kBig));
}

QPen whitePen(double width)
{
    QPen pen(Qt::white);
    pen.setWidthF(width * kBig);
    pen.setCapStyle(Qt::RoundCap);
    pen.setJoinStyle(Qt::RoundJoin);
    return pen;
}

}

QString dir()
{
    const QString path = QDir::homePath() + "/mm-cache";
    QDir().mkpath(path);
    return path;
}

QString fileUrl(const QString &path)
{
    return QUrl::fromLocalFile(path).toString();
}

bool isImage(const QByteArray &head)
{
    if (head.size() < 4)
        return false;
    return head.startsWith("\x89" "PNG") || head.startsWith("\xFF\xD8")
        || head.startsWith("GIF8") || head.startsWith("RIFF");
}

QString colorFor(const QString &key)
{
    static const char *palette[] = {
        "#0f8b8d", "#1d6fbf", "#7a4ea3", "#c2622d",
        "#2a8ca3", "#c4476b", "#5d6b7a", "#8a7a1f"
    };
    unsigned int sum = 7;
    for (int i = 0; i < key.size(); ++i)
        sum = sum * 31 + key.at(i).unicode();
    return QString::fromLatin1(palette[sum % 8]);
}

QString avatarUrl(const QString &userId)
{
    if (userId.isEmpty())
        return QString();
    const QString round = pathFor(userId + ".round.png");
    if (present(round))
        return fileUrl(round);
    if (present(pathFor(userId + ".avatar")))
        return makeAvatar(userId);
    return QString();
}

QString makeAvatar(const QString &userId)
{
    const QString raw = pathFor(userId + ".avatar");
    const QString out = pathFor(userId + ".round.png");
    QImage src;
    if (!src.load(raw))
        return present(raw) ? fileUrl(raw) : QString();
    QImage square = src.scaled(kAvatar, kAvatar, Qt::KeepAspectRatioByExpanding,
                               Qt::SmoothTransformation);
    square = square.copy((square.width() - kAvatar) / 2, (square.height() - kAvatar) / 2,
                         kAvatar, kAvatar);
    QImage result(kAvatar, kAvatar, QImage::Format_ARGB32_Premultiplied);
    result.fill(0);
    QPainter p(&result);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::SmoothPixmapTransform, true);
    p.setPen(Qt::NoPen);
    p.setBrush(QBrush(square));
    p.drawEllipse(QRectF(0.5, 0.5, kAvatar - 1, kAvatar - 1));
    p.end();
    if (!result.save(out, "PNG"))
        return present(raw) ? fileUrl(raw) : QString();
    return fileUrl(out);
}

QString disc(const QString &hex)
{
    const QString path = pathFor("disc-" + hex.mid(1) + ".png");
    if (!present(path)) {
        QImage big = blank();
        QPainter p(&big);
        p.setRenderHint(QPainter::Antialiasing, true);
        paintDisc(p, QColor(hex));
        p.end();
        saveSmall(big, kTile, path);
    }
    return fileUrl(path);
}

QString tileChannel(const QString &hex)
{
    const QString path = pathFor("hash-" + hex.mid(1) + ".png");
    if (!present(path)) {
        QImage big = blank();
        QPainter p(&big);
        p.setRenderHint(QPainter::Antialiasing, true);
        paintDisc(p, QColor(hex));
        p.setPen(whitePen(0.07));
        p.drawLine(pt(0.44, 0.27), pt(0.38, 0.73));
        p.drawLine(pt(0.63, 0.27), pt(0.57, 0.73));
        p.drawLine(pt(0.28, 0.42), pt(0.74, 0.42));
        p.drawLine(pt(0.26, 0.59), pt(0.72, 0.59));
        p.end();
        saveSmall(big, kTile, path);
    }
    return fileUrl(path);
}

QString tileLock(const QString &hex)
{
    const QString path = pathFor("lock-" + hex.mid(1) + ".png");
    if (!present(path)) {
        QImage big = blank();
        QPainter p(&big);
        p.setRenderHint(QPainter::Antialiasing, true);
        paintDisc(p, QColor(hex));
        p.setPen(Qt::NoPen);
        p.setBrush(Qt::white);
        p.drawRoundedRect(QRectF(0.30 * kBig, 0.47 * kBig, 0.40 * kBig, 0.28 * kBig),
                          0.05 * kBig, 0.05 * kBig);
        QPainterPath shackle;
        shackle.moveTo(pt(0.40, 0.48));
        shackle.lineTo(pt(0.40, 0.38));
        shackle.arcTo(QRectF(0.40 * kBig, 0.26 * kBig, 0.20 * kBig, 0.24 * kBig), 180, -180);
        shackle.lineTo(pt(0.60, 0.48));
        p.setPen(whitePen(0.065));
        p.setBrush(Qt::NoBrush);
        p.drawPath(shackle);
        p.end();
        saveSmall(big, kTile, path);
    }
    return fileUrl(path);
}

QString tileGear()
{
    const QString path = pathFor("tile-gear.png");
    if (!present(path)) {
        QImage big = blank();
        QPainter p(&big);
        p.setRenderHint(QPainter::Antialiasing, true);
        paintDisc(p, QColor("#5c6770"));
        p.setPen(Qt::NoPen);
        p.setBrush(Qt::white);
        p.translate(kBig / 2.0, kBig / 2.0);
        for (int i = 0; i < 8; ++i) {
            p.drawRoundedRect(QRectF(-0.055 * kBig, -0.40 * kBig, 0.11 * kBig, 0.18 * kBig),
                              0.04 * kBig, 0.04 * kBig);
            p.rotate(45);
        }
        p.resetTransform();
        p.setBrush(Qt::white);
        p.drawEllipse(QRectF(0.34 * kBig, 0.34 * kBig, 0.32 * kBig, 0.32 * kBig));
        p.setBrush(QColor("#5c6770"));
        p.drawEllipse(QRectF(0.43 * kBig, 0.43 * kBig, 0.14 * kBig, 0.14 * kBig));
        p.end();
        saveSmall(big, kTile, path);
    }
    return fileUrl(path);
}

QString iconSend()
{
    const QString path = pathFor("icon-send-blue.png");
    if (!present(path)) {
        QImage big = blank();
        QPainter p(&big);
        p.setRenderHint(QPainter::Antialiasing, true);
        paintDisc(p, QColor("#1c58d9"));
        QPolygonF plane;
        plane << pt(0.28, 0.30) << pt(0.77, 0.50) << pt(0.28, 0.70) << pt(0.38, 0.50);
        p.setPen(Qt::NoPen);
        p.setBrush(Qt::white);
        p.drawPolygon(plane);
        p.end();
        saveSmall(big, kTile, path);
    }
    return fileUrl(path);
}

QString iconPlus()
{
    const QString path = pathFor("icon-plus.png");
    if (!present(path)) {
        QImage big = blank();
        QPainter p(&big);
        p.setRenderHint(QPainter::Antialiasing, true);
        QPen pen(QColor("#5c656e"));
        pen.setWidthF(0.09 * kBig);
        pen.setCapStyle(Qt::RoundCap);
        p.setPen(pen);
        p.drawLine(pt(0.50, 0.22), pt(0.50, 0.78));
        p.drawLine(pt(0.22, 0.50), pt(0.78, 0.50));
        p.end();
        saveSmall(big, kTile, path);
    }
    return fileUrl(path);
}

QString iconEmoji()
{
    const QString path = pathFor("icon-emoji.png");
    if (!present(path)) {
        QImage big = blank();
        QPainter p(&big);
        p.setRenderHint(QPainter::Antialiasing, true);
        paintDisc(p, QColor("#f5c518"));
        p.setPen(Qt::NoPen);
        p.setBrush(QColor("#3a3320"));
        p.drawEllipse(QRectF(0.32 * kBig, 0.34 * kBig, 0.09 * kBig, 0.11 * kBig));
        p.drawEllipse(QRectF(0.59 * kBig, 0.34 * kBig, 0.09 * kBig, 0.11 * kBig));
        QPen smile(QColor("#3a3320"));
        smile.setWidthF(0.045 * kBig);
        smile.setCapStyle(Qt::RoundCap);
        p.setPen(smile);
        p.setBrush(Qt::NoBrush);
        QPainterPath arc;
        arc.moveTo(pt(0.32, 0.58));
        arc.quadTo(pt(0.50, 0.78), pt(0.68, 0.58));
        p.drawPath(arc);
        p.end();
        saveSmall(big, kTile, path);
    }
    return fileUrl(path);
}

QString iconBack()
{
    const QString path = pathFor("icon-back.png");
    if (!present(path)) {
        QImage big = blank();
        QPainter p(&big);
        p.setRenderHint(QPainter::Antialiasing, true);
        QPen pen(QColor("#1b1f23"));
        pen.setWidthF(0.075 * kBig);
        pen.setCapStyle(Qt::RoundCap);
        pen.setJoinStyle(Qt::RoundJoin);
        p.setPen(pen);
        p.drawLine(pt(0.62, 0.18), pt(0.30, 0.50));
        p.drawLine(pt(0.30, 0.50), pt(0.62, 0.82));
        p.end();
        saveSmall(big, kTile, path);
    }
    return fileUrl(path);
}

QString iconSearch()
{
    const QString path = pathFor("icon-search.png");
    if (!present(path)) {
        QImage big = blank();
        QPainter p(&big);
        p.setRenderHint(QPainter::Antialiasing, true);
        QPen pen(QColor("#8a95a0"));
        pen.setWidthF(0.085 * kBig);
        pen.setCapStyle(Qt::RoundCap);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(QRectF(0.20 * kBig, 0.18 * kBig, 0.40 * kBig, 0.40 * kBig));
        p.drawLine(pt(0.56, 0.56), pt(0.79, 0.79));
        p.end();
        saveSmall(big, kTile, path);
    }
    return fileUrl(path);
}

void sweepLegacy()
{
    QDir d(dir());
    QStringList old;
    old << "*.thumb";
    const QStringList files = d.entryList(old, QDir::Files);
    for (int i = 0; i < files.size(); ++i)
        d.remove(files.at(i));
}

}
