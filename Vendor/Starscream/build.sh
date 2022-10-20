#!/bin/bash

set -o pipefail && xcodebuild -project Starscream.xcodeproj -scheme Starscream CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build | xcpretty
swift build
pod repo update
pod lib lint --verbose --allow-warnings
