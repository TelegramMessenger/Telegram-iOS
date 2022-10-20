#!/bin/sh

cd "$(dirname "$0")" >/dev/null && [ -f x264.h ] || exit 1

api="$(grep '#define X264_BUILD' < x264.h | sed 's/^.* \([1-9][0-9]*\).*$/\1/')"
ver="x"
version=""

if [ -d .git ] && command -v git >/dev/null 2>&1 ; then
    localver="$(($(git rev-list HEAD | wc -l)))"
    if [ "$localver" -gt 1 ] ; then
        ver_diff="$(($(git rev-list origin/master..HEAD | wc -l)))"
        ver="$((localver-ver_diff))"
        echo "#define X264_REV $ver"
        echo "#define X264_REV_DIFF $ver_diff"
        if [ "$ver_diff" -ne 0 ] ; then
            ver="$ver+$ver_diff"
        fi
        if git status | grep -q "modified:" ; then
            ver="${ver}M"
        fi
        ver="$ver $(git rev-list -n 1 HEAD | cut -c 1-7)"
        version=" r$ver"
    fi
fi

echo "#define X264_VERSION \"$version\""
echo "#define X264_POINTVER \"0.$api.$ver\""
