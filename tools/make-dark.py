#!/usr/bin/env python3
"""Erzeugt assets/dark/*.qml aus assets/*.qml mit dunkler Farbpalette.

Nach jeder Änderung an einer QML-Seite neu laufen lassen, bevor die BAR gebaut wird:
    python3 tools/make-dark.py
Die App lädt assets/dark/main.qml, wenn in den Einstellungen das dunkle Design an ist.
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'assets')
DST = os.path.join(SRC, 'dark')

# Helle Farbe -> dunkle Farbe. Rot, Bernstein und Lila bleiben, sie lesen sich auf beiden Hintergründen.
PALETTE = {
    '#ffffff': '#16191d',  # Seitenhintergrund
    '#f3f5f7': '#22262b',  # Abschnittsköpfe
    '#f4f6f8': '#1f2328',  # Eingabezeile, Hinweise
    '#eceff2': '#2a2f35',  # Bild-Platzhalter
    '#e6eaee': '#30353b',  # Trennlinien
    '#dfe3e7': '#353a40',
    '#eef2fc': '#26324a',
    '#e7eefc': '#24304a',
    '#1b1f23': '#e6e9ec',  # Haupttext
    '#6b747d': '#9aa3ab',  # Nebentext
    '#8a929a': '#80898f',
    '#5e6770': '#a2aab1',
    '#3b4248': '#c3c9ce',
    '#1c58d9': '#6b9bf2',  # Akzent
    '#1544a8': '#8fb0f5',  # eigener Name
    '#fff4d6': '#3a3220',  # Banner-Hintergrund
    '#5c4400': '#f0d58a',  # Banner-Text
}

COLOR = re.compile(r'"(#[0-9a-fA-F]{6})"')
PAGE = re.compile(r'asset:///([A-Za-z0-9_]+\.qml)')


def convert(text):
    text = COLOR.sub(lambda m: '"%s"' % PALETTE.get(m.group(1).lower(), m.group(1)), text)
    text = text.replace('Color.White', 'Color.create("#16191d")')
    return PAGE.sub(r'asset:///dark/\1', text)


def main():
    os.makedirs(DST, exist_ok=True)
    count = 0
    for name in sorted(os.listdir(SRC)):
        if not name.endswith('.qml'):
            continue
        with open(os.path.join(SRC, name), encoding='utf-8') as source:
            text = convert(source.read())
        with open(os.path.join(DST, name), 'w', encoding='utf-8') as target:
            target.write(text)
        count += 1
    print('dark pages:', count)


if __name__ == '__main__':
    main()
