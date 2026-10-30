#ifndef EMOJI_HPP
#define EMOJI_HPP

#include <QString>
#include <QVariantList>

// Kurzcodes (:thumbsup:) und die üblichen Text-Emoticons werden zu Unicode.
namespace Emoji {

QString glyph(const QString &name);
QString apply(const QString &text);
QVariantList choices();
QVariantList catalog(const QString &query);

}

#endif
