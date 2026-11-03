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

if [ -f @PKGNAME@-@VERSION@.@RPMARCH@.rpm ]; then
	rm -f @PKGNAME@-@VERSION@.@RPMARCH@.rpm
fi

umask 022
TMPDIR=`mktemp -d /tmp/@CMAKE_PROJECT_NAME@-build.XXXXXX`

mkdir -p $TMPDIR/RPMS
ln -fs `pwd` $TMPDIR/BUILD
rpmbuild -bb --define "_blddir $TMPDIR/buildroot" --define "_topdir $TMPDIR" \
	--target @RPMARCH@ pkgscripts/rpm.spec; \
cp $TMPDIR/RPMS/@RPMARCH@/@PKGNAME@-@VERSION@-@BUILD@.@RPMARCH@.rpm \
	@PKGNAME@-@VERSION@.@RPMARCH@.rpm
