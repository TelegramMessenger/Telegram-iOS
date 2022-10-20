#!/bin/sh

set -u
set -e
trap onexit INT
trap onexit TERM
trap onexit EXIT

TMPDIR=
SUDO=

onexit()
{
	if [ ! "$TMPDIR" = "" ]; then
		rm -rf $TMPDIR
	fi
}

uid()
{
	id | cut -f2 -d = | cut -f1 -d \(;
}

PKGNAME=@PKGNAME@
VERSION=@VERSION@
ARCH=@CPU_TYPE@
OS=@CMAKE_SYSTEM_NAME@
PREFIX=@CMAKE_INSTALL_PREFIX@

umask 022
rm -f $PKGNAME-$VERSION-$OS-$ARCH.tar.bz2
TMPDIR=`mktemp -d /tmp/$PKGNAME-build.XXXXXX`
mkdir -p $TMPDIR/install

make install DESTDIR=$TMPDIR/install
echo tartest >$TMPDIR/tartest
GNUTAR=0
BSDTAR=0
tar cf $TMPDIR/tartest.tar --owner=root --group=root -C $TMPDIR tartest >/dev/null 2>&1 && GNUTAR=1
if [ "$GNUTAR" = "1" ]; then
	tar cf - --owner=root --group=root -C $TMPDIR/install .$PREFIX | bzip2 -c >$PKGNAME-$VERSION-$OS-$ARCH.tar.bz2
else
	tar cf $TMPDIR/tartest.tar --uid 0 --gid 0 -C $TMPDIR tartest >/dev/null 2>&1 && BSDTAR=1
	if [ "$BSDTAR" = "1" ]; then
		tar cf - --uid=0 --gid=0 -C $TMPDIR/install .$PREFIX | bzip2 -c >$PKGNAME-$VERSION-$OS-$ARCH.tar.bz2
	else
		tar cf - -C $TMPDIR/install .$PREFIX | bzip2 -c >$PKGNAME-$VERSION-$OS-$ARCH.tar.bz2
	fi
fi

exit
