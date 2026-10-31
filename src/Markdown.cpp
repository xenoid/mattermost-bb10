#include "Markdown.hpp"

#include <QRegExp>
#include <QStringList>

namespace {

QString safeHref(const QString &url)
{
    if (!url.startsWith("https://") && !url.startsWith("http://"))
        return QString();
    if (url.contains('"') || url.contains('\'') || url.contains('<') || url.contains('>'))
        return QString();
    if (url.contains(' ') || url.contains('\n'))
        return QString();
    return url;
}

QString inlineFormat(const QString &input)
{
    QString text = input;
    QStringList codes;
    QRegExp codeSpan("`([^`]+)`");
    int guard = 0;
    while (text.indexOf(codeSpan) >= 0 && guard < 40) {
        const QString body = codeSpan.cap(1);
        const QString token = QString("\x01%1\x01").arg(codes.size());
        codes.append(body);
        text.replace(codeSpan.pos(0), codeSpan.matchedLength(), token);
        ++guard;
    }

    text.replace(QRegExp("\\*\\*([^*]+)\\*\\*"), "<b>\\1</b>");
    text.replace(QRegExp("__([^_]+)__"), "<b>\\1</b>");
    text.replace(QRegExp("\\*([^*\\n]+)\\*"), "<i>\\1</i>");

    QRegExp uitalic("_([^_\\n]+)_");
    int from = 0;
    guard = 0;
    while (from < text.size() && text.indexOf(uitalic, from) >= 0 && guard < 40) {
        const int at = uitalic.pos(0);
        const int end = at + uitalic.matchedLength();
        const QChar before = at > 0 ? text.at(at - 1) : QChar(' ');
        const QChar after = end < text.size() ? text.at(end) : QChar(' ');
        const bool left = at == 0 || before.isSpace() || before == '(';
        const bool right = end == text.size() || after.isSpace()
            || QString(").,!?:;").contains(after);
        if (!left || !right) {
            from = at + 1;
            ++guard;
            continue;
        }
        const QString replacement = QString("<i>%1</i>").arg(uitalic.cap(1));
        text.replace(at, uitalic.matchedLength(), replacement);
        from = at + replacement.size();
        ++guard;
    }

    QRegExp mdlink("\\[([^\\]]+)\\]\\((https?://[^\\s\\)]+)\\)");
    guard = 0;
    while (text.indexOf(mdlink) >= 0 && guard < 20) {
        const QString href = safeHref(mdlink.cap(2));
        QString replacement = mdlink.cap(1);
        if (!href.isEmpty())
            replacement = QString("<a href=\"%1\">%2</a>").arg(href, mdlink.cap(1));
        text.replace(mdlink.pos(0), mdlink.matchedLength(), replacement);
        ++guard;
    }

    QRegExp raw("(https?://[^\\s<]+)");
    guard = 0;
    from = 0;
    while (from < text.size() && text.indexOf(raw, from) >= 0 && guard < 20) {
        const int at = raw.pos(0);
        const int endAnchor = text.lastIndexOf("</a>", at);
        const int startAnchor = text.lastIndexOf("<a ", at);
        if (startAnchor >= 0 && (endAnchor < 0 || startAnchor > endAnchor)) {
            from = at + raw.matchedLength();
            ++guard;
            continue;
        }
        const QString href = safeHref(raw.cap(1));
        if (href.isEmpty()) {
            from = at + raw.matchedLength();
            ++guard;
            continue;
        }
        const QString replacement = QString("<a href=\"%1\">%2</a>").arg(href, raw.cap(1));
        text.replace(at, raw.matchedLength(), replacement);
        from = at + replacement.size();
        ++guard;
    }

    for (int i = 0; i < codes.size(); ++i) {
        text.replace(QString("\x01%1\x01").arg(i),
                     QString("<span style='font-family:\"courier new\"'>%1</span>").arg(codes.at(i)));
    }
    return text;
}

}

QString Markdown::html(const QString &plain)
{
    if (plain.isEmpty())
        return plain;
    QString escaped = plain;
    escaped.replace("&", "&amp;");
    escaped.replace("<", "&lt;");
    escaped.replace(">", "&gt;");
    escaped.replace("\r\n", "\n");
    escaped.replace('\r', '\n');

    const QStringList lines = escaped.split('\n');
    QStringList out;
    bool code = false;
    for (int i = 0; i < lines.size(); ++i) {
        const QString line = lines.at(i);
        if (line.startsWith("```")) {
            code = !code;
            continue;
        }
        if (code) {
            out.append(QString("<span style='font-family:\"courier new\"'>%1</span>").arg(line));
            continue;
        }
        if (line.startsWith("&gt;")) {
            QString body = line.mid(4);
            if (body.startsWith(" "))
                body = body.mid(1);
            out.append(QString("<span style='background-color:rgb(214,220,226)'><i>%1</i></span>")
                       .arg(inlineFormat(body)));
            continue;
        }
        out.append(inlineFormat(line));
    }
    return QString("<html>%1</html>").arg(out.join("<br/>"));
}
