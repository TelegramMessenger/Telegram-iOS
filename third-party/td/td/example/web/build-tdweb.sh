#!/bin/sh
cd $(dirname $0)

cd tdweb || exit 1
npm install --no-save || exit 1
npm run build || exit 1
cd ..
