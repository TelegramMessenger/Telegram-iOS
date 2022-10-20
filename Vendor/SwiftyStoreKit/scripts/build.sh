#!/bin/bash
bold=$(tput bold)
normal=$(tput sgr0)

echo "${bold}/*****************************/"
echo "/* Build: SwiftyStoreKit_iOS */"
echo "/*****************************/${normal}"
set -o pipefail && xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_iOS | tee xcodebuild.log | xcpretty

echo ""
echo "${bold}/*******************************/"
echo "/* Build: SwiftyStoreKit_macOS */"
echo "/*******************************/${normal}"
set -o pipefail && xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_macOS | tee xcodebuild.log | xcpretty

echo ""
echo "${bold}/******************************/"
echo "/* Build: SwiftyStoreKit_tvOS */"
echo "/******************************/${normal}"
set -o pipefail && xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_tvOS | tee xcodebuild.log | xcpretty

echo ""
echo "${bold}/******************************/"
echo "/* Build: SwiftyStoreKit_watchOS */"
echo "/******************************/${normal}"
set -o pipefail && xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_watchOS | tee xcodebuild.log | xcpretty

echo ""
echo "${bold}/****************************/"
echo "/* Run: SwiftyStoreKitTests */"
echo "/****************************/${normal}"
set -o pipefail && xcodebuild test -project SwiftyStoreKit.xcodeproj -scheme SwiftyStoreKitTests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 6,OS=12.0' | tee xcodebuild.log | xcpretty
