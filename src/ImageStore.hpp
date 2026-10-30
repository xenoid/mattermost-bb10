#ifndef IMAGESTORE_HPP
#define IMAGESTORE_HPP

#include <QByteArray>
#include <QString>

// Bild-Cache der App und alles, was selbst gezeichnet wird.
// Liegt im Home-Verzeichnis der App (beschreibbar, nur für diese App sichtbar).
namespace ImageStore {

QString dir();                                   // <home>/mm-cache
QString fileUrl(const QString &path);            // file:///...
bool isImage(const QByteArray &head);            // PNG, JPEG, GIF, WebP
QString colorFor(const QString &key);            // stabile Farbe je Name/ID

// Profilbild: {id}.avatar (roh) -> {id}.round.png (rund). Leer, wenn es keins gibt.
QString avatarUrl(const QString &userId);
QString makeAvatar(const QString &userId);

// Gezeichnete Symbole, jeweils einmal erzeugt und zwischengespeichert.
QString disc(const QString &hex);                // Vollkreis
QString tileChannel(const QString &hex);         // Kreis mit #
QString tileLock(const QString &hex);            // Kreis mit Schloss
QString tileGear();                              // grauer Kreis mit Zahnrad
QString iconSend();                              // blauer Kreis mit Pfeil
QString iconSearch();                            // graue Lupe
QString iconPlus();                              // graues Plus für den Anhang
QString iconEmoji();                             // Smiley für die Emoji-Tafel
QString iconBack();                              // Chevron für die eigene Zurück-Taste

void sweepLegacy();                              // alte Cache-Dateien entfernen

}

#endif
