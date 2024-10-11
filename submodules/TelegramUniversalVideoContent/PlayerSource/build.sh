#!/bin/sh

rm -rf ../HlsBundle
mkdir ../HlsBundle
npm run build-$1
cp ./dist/* ../HlsBundle/
