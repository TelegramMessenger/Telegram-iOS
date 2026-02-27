#!/bin/sh

mkdir -p ../HlsBundle
rm -rf ../HlsBundle/index
mkdir ../HlsBundle/index
npm run build-$1
cp ./dist/* ../HlsBundle/index/
