#!/bin/sh
# Build Python 2.7.18 natively on SCO OpenServer 5.0.7 with GCC 2.95.3.
#
# Run this script ON the SCO machine, in a writable directory.
#
# Required:
#   /usr/gnu/bin/{gcc,gmake} and /bin/{patch,sed,gunzip}
#   wget or curl, OR drop Python-2.7.18.tgz next to this script
#   For TLS support (recommended): static OpenSSL 1.0.2 at
#       /usr/local/lib/{libssl,libcrypto}.a with headers at
#       /usr/local/include/openssl/. The script will build without
#       TLS if it can't find them.
#
# Output: ./py_install/ (about 30 MB stripped) — a relocatable Python
# install. tar+gzip and ship.

set -e

SCRIPT_DIR=`cd \`dirname "$0"\` && pwd`
VERSION=2.7.18
TARBALL=Python-${VERSION}.tgz
SRCDIR=Python-${VERSION}

PATH=/usr/gnu/bin:/usr/ccs/bin:$PATH
export PATH

if [ ! -f "$TARBALL" ]; then
    echo "Fetching $TARBALL..."
    if which wget >/dev/null 2>&1; then
        wget --no-check-certificate "https://www.python.org/ftp/python/${VERSION}/${TARBALL}"
    elif which curl >/dev/null 2>&1; then
        curl -kLO "https://www.python.org/ftp/python/${VERSION}/${TARBALL}"
    else
        echo "ERROR: no wget or curl. Please drop $TARBALL next to this script." >&2
        exit 1
    fi
fi

if [ ! -d "$SRCDIR" ]; then
    echo "Unpacking $TARBALL..."
    gtar xzf "$TARBALL"
fi

echo "Applying patches..."
cd "$SRCDIR"
if [ -f .sco_patched ]; then
    echo "  (already applied — skipping)"
else
    patch -p0 < "$SCRIPT_DIR/patches/pidt-short.patch"
    patch -p0 < "$SCRIPT_DIR/patches/socket-inet-addrstrlen.patch"
    touch .sco_patched
fi

echo "Configuring..."
./configure --prefix="$SCRIPT_DIR/py_install"

# SCO has <sys/event.h> from one of the network/event packages but not the
# full BSD kqueue API — configure auto-enables HAVE_KQUEUE, then
# Modules/selectmodule.c fails to compile (EV_ERROR undeclared) and the
# select extension silently doesn't get built. Without select, subprocess
# and several other modules are unimportable. Disable HAVE_KQUEUE here.
echo "Disabling kqueue (incomplete API on SCO)..."
sed "s|^#define HAVE_KQUEUE 1\$|/* #undef HAVE_KQUEUE */|" pyconfig.h > pyconfig.h.new
mv pyconfig.h.new pyconfig.h

echo "Compiling (this takes a while on SCO — go make tea)..."
gmake

echo "Installing to $SCRIPT_DIR/py_install/..."
gmake -s install

echo "Stripping binaries..."
strip "$SCRIPT_DIR/py_install/bin/python" 2>/dev/null || true
strip "$SCRIPT_DIR/py_install/bin/python2.7" 2>/dev/null || true
find "$SCRIPT_DIR/py_install" -name "*.so" -exec strip {} \; 2>/dev/null

ls -l "$SCRIPT_DIR/py_install/bin/python"
echo
echo "Built: $SCRIPT_DIR/py_install/"
echo "Test it: $SCRIPT_DIR/py_install/bin/python --version"
echo
echo "To package: gtar czf python-${VERSION}-sco.tar.gz py_install"
