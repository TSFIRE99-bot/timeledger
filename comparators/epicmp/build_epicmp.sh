#!/usr/bin/env bash
# Build WFDB 10.7.0 epicmp from source without network (NETFILES) support.
# On Linux/macOS: CC=cc. On Windows the binary in bin/ was built with
#   python -m pip install --target zig ziglang   (zig 0.17.1)
#   CC="python -m ziglang cc -target x86_64-windows-gnu"
set -euo pipefail
CC=${CC:-cc}
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d)
curl -sfL https://physionet.org/physiotools/archives/wfdb-10.7/wfdb-10.7.0.tar.gz -o "$W/wfdb.tar.gz"
echo "a12b9c87cf69bb3e759c4c6ab946f82b9fafdc62f3c8022db8a629bb2732d4b6  $W/wfdb.tar.gz" | sha256sum -c -
tar xzf "$W/wfdb.tar.gz" -C "$W"
S="$W/wfdb-10.7.0"
mkdir -p "$W/b/include/wfdb" "$W/b/lib"
cp "$S"/lib/*.c "$S"/lib/*.h "$W/b/lib/"
sed -i.bak 's/^#define WFDB_NETFILES 1.*/#define WFDB_NETFILES 0/; s/^#define WFDB_NETFILES_LIBCURL 1/#define WFDB_NETFILES_LIBCURL 0/' "$W/b/lib/wfdb.h"
cp "$W"/b/lib/wfdb.h "$W"/b/lib/ecgcodes.h "$W"/b/lib/ecgmap.h "$W/b/include/wfdb/"
cd "$W/b"
for f in annot calib signal wfdbinit wfdbio; do $CC -O2 -w -std=gnu89 -I"$W/b/include" -I"$W/b/lib" -c lib/$f.c -o $f.o; done
$CC -O2 -w -std=gnu89 -Wno-implicit-int -Wno-implicit-function-declaration -I"$W/b/include" -c "$S/app/epicmp.c" -o epicmp.o
mkdir -p "$HERE/bin"
$CC -o "$HERE/bin/epicmp" epicmp.o annot.o calib.o signal.o wfdbinit.o wfdbio.o -lm
echo "built $HERE/bin/epicmp"
