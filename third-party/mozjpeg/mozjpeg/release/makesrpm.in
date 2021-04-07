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

PKGNAME=@PKGNAME@
PROJECT=@CMAKE_PROJECT_NAME@
VERSION=@VERSION@
BUILD=@BUILD@

if [ -f $PKGNAME-$VERSION.src.rpm ]; then
	rm -f $PKGNAME-$VERSION.src.rpm
fi

umask 022
TMPDIR=`mktemp -d /tmp/$PKGNAME-build.XXXXXX`

mkdir -p $TMPDIR/RPMS
mkdir -p $TMPDIR/SRPMS
mkdir -p $TMPDIR/BUILD
mkdir -p $TMPDIR/SOURCES
mkdir -p $TMPDIR/SPECS

if [ ! -f $PROJECT-$VERSION.tar.gz ]; then
	echo "ERROR: $PROJECT-$VERSION.tar.gz does not exist."
fi

cp $PROJECT-$VERSION.tar.gz $TMPDIR/SOURCES/$PROJECT-$VERSION.tar.gz

cat pkgscripts/rpm.spec | sed s/%{_blddir}/%{_tmppath}/g \
	| sed s/#--\>//g > $TMPDIR/SPECS/$PKGNAME.spec

rpmbuild -bs --define "_topdir $TMPDIR" $TMPDIR/SPECS/$PKGNAME.spec
mv $TMPDIR/SRPMS/$PKGNAME-$VERSION-$BUILD.src.rpm $PKGNAME-$VERSION.src.rpm

exit
