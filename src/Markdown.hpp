#ifndef MARKDOWN_HPP
#define MARKDOWN_HPP

#include <QString>

// Kleines, festes HTML für Cascades-Labels. Erst escapen, dann fett, kursiv,
// Code, Zitat und http(s)-Links. Kein Skript, keine fremden Schemes.
namespace Markdown {
QString html(const QString &plain);
}

#endif
