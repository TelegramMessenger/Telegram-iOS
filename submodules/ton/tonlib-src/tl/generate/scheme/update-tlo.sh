#!/bin/sh
cd $(dirname $0)
tl-parser -e ton_api.tlo ton_api.tl
tl-parser -e tonlib_api.tlo tonlib_api.tl
tl-parser -e lite_api.tlo lite_api.tl
