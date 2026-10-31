#ifndef MARKDOWN_HPP
#define MARKDOWN_HPP

#include <QString>

// Kleines, festes HTML für Cascades-Labels. Fett, kursiv, Code, Zitat, Link.
// Überschriften werden fett. Listen, Tabellen und Durchgestrichenes bleiben
// lesbarer Text. Kein Skript, keine fremden Schemes.
namespace Markdown {
QString html(const QString &plain);
}

#endif
