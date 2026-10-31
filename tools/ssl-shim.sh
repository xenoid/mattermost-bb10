#!/bin/sh
# Qt 4.8 ruft SSLv23_client_method. Dieser Server verlangt TLS 1.2.
# Das Shim liegt als libssl.so.2 im Paket und reicht jeden anderen
# Aufruf an die Systembibliothek OpenSSL 1.0.2 weiter.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
stock=${1:?path to the device libssl.so.2}
python3 - "$stock" "$root/lib/libsslmm.so" << 'PY'
import sys
src = open(sys.argv[1], "rb").read()
old = b"libssl.so.2"
new = b"libsslmm.so"
if src.count(old) != 1 or len(old) != len(new):
    raise SystemExit("unexpected SONAME")
open(sys.argv[2], "wb").write(src.replace(old, new, 1))
PY
qcc -Vgcc_ntoarmv7le -shared -fPIC -o "$root/lib/libssl.so.2" "$root/tools/sslshim.c" \
  -Wl,-h,libssl.so.2 -Wl,--filter,libsslmm.so \
  -L"$root/lib" -lsslmm
