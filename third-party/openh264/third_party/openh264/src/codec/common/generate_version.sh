#!/bin/bash
git rev-list HEAD | sort > config.git-hash
SRC_PATH=$1
LOCALVER=`wc -l config.git-hash | awk '{print $1}'`
if [ $LOCALVER \> 1 ] ; then
    VER="$(git rev-list HEAD -n 1 | cut -c 1-7)"
    if git status | grep -q "modified:" ; then
        VER="${VER}+M"
    fi
    GIT_VERSION=$VER
else
    GIT_VERSION=
    VER="x"
fi
GIT_VERSION='"'$GIT_VERSION'"'
rm -f config.git-hash

mkdir -p codec/common/inc
cat $SRC_PATH/codec/common/inc/version_gen.h.template | sed "s/\$FULL_VERSION/$GIT_VERSION/g" > codec/common/inc/version_gen.h.new
if cmp codec/common/inc/version_gen.h.new codec/common/inc/version_gen.h > /dev/null 2>&1; then
    # Identical to old version, don't touch it (to avoid unnecessary rebuilds)
    rm codec/common/inc/version_gen.h.new
    echo "Keeping existing codec/common/inc/version_gen.h"
    exit 0
fi
mv codec/common/inc/version_gen.h.new codec/common/inc/version_gen.h

echo "Generated codec/common/inc/version_gen.h"
