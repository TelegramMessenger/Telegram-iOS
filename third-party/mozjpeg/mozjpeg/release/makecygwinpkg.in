#!/bin/sh

set -u
set -e
trap onexit INT
trap onexit TERM
trap onexit EXIT

TMPDIR=

onexit()
{
	if [ ! "$TMPDIR" = "" ]; then
		rm -rf $TMPDIR
	fi
}

safedirmove ()
{
	if [ "$1" = "$2" ]; then
		return 0
	fi
	if [ "$1" = "" -o ! -d "$1" ]; then
		echo safedirmove: source dir $1 is not valid
		return 1
	fi
	if [ "$2" = "" -o -e "$2" ]; then
		echo safedirmove: dest dir $2 is not valid
		return 1
	fi
	if [ "$3" = "" -o -e "$3" ]; then
		echo safedirmove: tmp dir $3 is not valid
		return 1
	fi
	mkdir -p $3
	mv $1/* $3/
	rmdir $1
	mkdir -p $2
	mv $3/* $2/
	rmdir $3
	return 0
}

PKGNAME=@PKGNAME@
VERSION=@VERSION@
BUILD=@BUILD@

PREFIX=@CMAKE_INSTALL_PREFIX@
DOCDIR=@CMAKE_INSTALL_FULL_DOCDIR@
LIBDIR=@CMAKE_INSTALL_FULL_LIBDIR@

umask 022
rm -f $PKGNAME-$VERSION-$BUILD.tar.bz2
TMPDIR=`mktemp -d /tmp/ljtbuild.XXXXXX`
__PWD=`pwd`
make install DESTDIR=$TMPDIR/pkg
if [ "$PREFIX" = "@CMAKE_INSTALL_DEFAULT_PREFIX@" -a "$DOCDIR" = "@CMAKE_INSTALL_DEFAULT_PREFIX@/doc" ]; then
	safedirmove $TMPDIR/pkg$DOCDIR $TMPDIR/pkg/usr/share/doc/$PKGNAME-$VERSION $TMPDIR/__tmpdoc
	ln -fs /usr/share/doc/$PKGNAME-$VERSION $TMPDIR/pkg$DOCDIR
fi
cd $TMPDIR/pkg
tar cfj ../$PKGNAME-$VERSION-$BUILD.tar.bz2 *
cd $__PWD
mv $TMPDIR/*.tar.bz2 .

exit 0
