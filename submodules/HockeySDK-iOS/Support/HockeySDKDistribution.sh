#!/bin/sh

# Default config
# Sets the target folders and the final framework product.
FMK_NAME=HockeySDK
FMK_RESOURCE_BUNDLE=HockeySDKResources
FMK_iOS8_NAME="HockeySDK Framework"

# Documentation
HOCKEYSDK_DOCSET_VERSION_NAME="de.bitstadium.${HOCKEYSDK_DOCSET_NAME}-${VERSION_STRING}"

# Install dir will be the final output to the framework.
# The following line creates it in the root folder of the current project.
PRODUCTS_DIR=${SRCROOT}/../Products
ZIP_FOLDER=HockeySDK-iOS
TEMP_DIR=${PRODUCTS_DIR}/${ZIP_FOLDER}
INSTALL_DIR=${TEMP_DIR}/${FMK_NAME}.framework
ALL_FEATURES_INSTALL_DIR=${TEMP_DIR}/HockeySDKAllFeatures/${FMK_NAME}.framework
FEEDBACK_ONLY_INSTALL_DIR=${TEMP_DIR}/HockeySDKFeedbackOnly/${FMK_NAME}.framework

# Working dir will be deleted after the framework creation.
WRK_DIR=build
DEVICE_DIR=${WRK_DIR}/ReleaseDefault-iphoneos
SIMULATOR_DIR=${WRK_DIR}/ReleaseDefault-iphonesimulator
DEVICE_DIR_ALL_FEATURES=${WRK_DIR}/Release-iphoneos
SIMULATOR_DIR_ALL_FEATURES=${WRK_DIR}/Release-iphonesimulator
DEVICE_CRASH_ONLY_DIR=${WRK_DIR}/ReleaseCrashOnly-iphoneos
SIMULATOR_CRASH_ONLY_DIR=${WRK_DIR}/ReleaseCrashOnly-iphonesimulator
DEVICE_EXTENSIONS_CRASH_ONLY_DIR=${WRK_DIR}/ReleaseCrashOnlyExtensions-iphoneos
SIMULATOR_EXTENSIONS_CRASH_ONLY_DIR=${WRK_DIR}/ReleaseCrashOnlyExtensions-iphonesimulator
DEVICE_WATCH_CRASH_ONLY_DIR=${WRK_DIR}/ReleaseCrashOnlyWatchOS-iphoneos
SIMULATOR_WATCH_CRASH_ONLY_DIR=${WRK_DIR}/ReleaseCrashOnlyWatchOS-iphonesimulator
DEVICE_DIR_ONLY_FEEDBACK=${WRK_DIR}/ReleaseFeedbackOnly-iphoneos
SIMULATOR_DIR_ONLY_FEEDBACK=${WRK_DIR}/ReleaseFeedbackOnly-iphonesimulator

# //////////////////////////////
# Building the  SDK with all features except the Feedback Feature
# //////////////////////////////

# Building both architectures.
xcodebuild -project "HockeySDK.xcodeproj" -configuration "ReleaseDefault" -target "${FMK_NAME}" -sdk iphoneos
xcodebuild -project "HockeySDK.xcodeproj" -configuration "ReleaseDefault" -target "${FMK_NAME}" -sdk iphonesimulator

# Cleaning the oldest.
if [ -d "${TEMP_DIR}" ]
then
rm -rf "${TEMP_DIR}"
fi

# Creates and renews the final product folder.
mkdir -p "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}/Headers"
mkdir -p "${INSTALL_DIR}/Modules"

# Copy the swift import file
cp -f "${SRCROOT}/module_default.modulemap" "${INSTALL_DIR}/Modules/module.modulemap"

# Copies the headers and resources files to the final product folder.
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITAuthenticator.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITCrashAttachment.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITCrashDetails.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITCrashManager.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITCrashManagerDelegate.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITCrashMetaData.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITHockeyAttachment.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITHockeyBaseManager.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITHockeyBaseViewController.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITHockeyManager.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITHockeyManagerDelegate.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITMetricsManager.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITStoreUpdateManager.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITStoreUpdateManagerDelegate.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITUpdateManager.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITUpdateManagerDelegate.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/BITUpdateViewController.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/HockeySDK.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/HockeySDKEnums.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/HockeySDKFeatureConfig.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR}/include/HockeySDK/HockeySDKNullability.h" "${INSTALL_DIR}/Headers/"

# Copy the patched feature header
cp -f "${SRCROOT}/HockeySDKFeatureConfigDefault.h" "${INSTALL_DIR}/Headers/HockeySDKFeatureConfig.h"

# Uses the Lipo Tool to merge both binary files (i386 + armv6/armv7) into one Universal final product.
lipo -create "${DEVICE_DIR}/lib${FMK_NAME}.a" "${SIMULATOR_DIR}/lib${FMK_NAME}.a" -output "${INSTALL_DIR}/${FMK_NAME}"

# Combine the CrashReporter static library into a new Hockey static library file if they are not already present and copy the public headers too
if [ -z $(otool -L "${INSTALL_DIR}/${FMK_NAME}" | grep 'libCrashReporter') ]
then
libtool -static -o "${INSTALL_DIR}/${FMK_NAME}" "${INSTALL_DIR}/${FMK_NAME}" "${SRCROOT}/../Vendor/CrashReporter.framework/Versions/A/CrashReporter"
fi

# build embeddedframework folder and move framework into it
mkdir "${INSTALL_DIR}/../${FMK_NAME}.embeddedframework"
mv "${INSTALL_DIR}" "${INSTALL_DIR}/../${FMK_NAME}.embeddedframework/${FMK_NAME}.framework"
mv "${DEVICE_DIR}/${FMK_RESOURCE_BUNDLE}.bundle" "${TEMP_DIR}/${FMK_NAME}.embeddedframework/"

rm -r "${WRK_DIR}"

# //////////////////////////////
# Building the full featured SDK
# //////////////////////////////

# Building both architectures.
xcodebuild -project "HockeySDK.xcodeproj" -configuration "Release" -target "${FMK_NAME}" -sdk iphoneos
xcodebuild -project "HockeySDK.xcodeproj" -configuration "Release" -target "${FMK_NAME}" -sdk iphonesimulator

# Creates and renews the final product folder.
mkdir -p "${ALL_FEATURES_INSTALL_DIR}"
mkdir -p "${ALL_FEATURES_INSTALL_DIR}/Headers"
mkdir -p "${ALL_FEATURES_INSTALL_DIR}/Modules"

# Copy the swift import file
cp -f "${SRCROOT}/module_allfeatures.modulemap" "${ALL_FEATURES_INSTALL_DIR}/Modules/module.modulemap"

# Copies the headers and resources files to the final product folder.
cp -R "${DEVICE_DIR_ALL_FEATURES}/include/HockeySDK/" "${ALL_FEATURES_INSTALL_DIR}/Headers/"

# Use the Lipo Tool to merge both binary files (i386/x86_64 + armv7/armv7s/arm64) into one Universal final product.
lipo -create "${DEVICE_DIR_ALL_FEATURES}/lib${FMK_NAME}.a" "${SIMULATOR_DIR_ALL_FEATURES}/lib${FMK_NAME}.a" -output "${ALL_FEATURES_INSTALL_DIR}/${FMK_NAME}"

# Combine the CrashReporter static library into a new Hockey static library file if they are not already present and copy the public headers too
if [ -z $(otool -L "${ALL_FEATURES_INSTALL_DIR}/${FMK_NAME}" | grep 'libCrashReporter') ]
then
libtool -static -o "${ALL_FEATURES_INSTALL_DIR}/${FMK_NAME}" "${ALL_FEATURES_INSTALL_DIR}/${FMK_NAME}" "${SRCROOT}/../Vendor/CrashReporter.framework/Versions/A/CrashReporter"
fi

# build embeddedframework folder and move framework into it
mkdir "${ALL_FEATURES_INSTALL_DIR}/../${FMK_NAME}.embeddedframework"
mv "${ALL_FEATURES_INSTALL_DIR}/" "${ALL_FEATURES_INSTALL_DIR}/../${FMK_NAME}.embeddedframework/${FMK_NAME}.framework"
mv "${DEVICE_DIR_ALL_FEATURES}/${FMK_RESOURCE_BUNDLE}.bundle" "${TEMP_DIR}/HockeySDKAllFeatures/${FMK_NAME}.embeddedframework/"

# do some cleanup
rm -r "${WRK_DIR}"

# /////////////////////////////////////////////
# Building the crash only SDK without resources
# /////////////////////////////////////////////

# Building both architectures.
xcodebuild -project "HockeySDK.xcodeproj" -configuration "ReleaseCrashOnly" -target "${FMK_NAME}" -sdk iphoneos
xcodebuild -project "HockeySDK.xcodeproj" -configuration "ReleaseCrashOnly" -target "${FMK_NAME}" -sdk iphonesimulator

# Creates and renews the final product folder.
mkdir -p "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}/Headers"
mkdir -p "${INSTALL_DIR}/Modules"

# Copy the swift import file
cp -f "${SRCROOT}/module_crashonly.modulemap" "${INSTALL_DIR}/Modules/module.modulemap"

# Copies the headers without the resources files to the final product folder.
cp -R "${SRCROOT}/${DEVICE_CRASH_ONLY_DIR}"/include/HockeySDK/BITCrash*.h "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_CRASH_ONLY_DIR}/include/HockeySDK/BITHockeyAttachment.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_CRASH_ONLY_DIR}/include/HockeySDK/BITHockeyBaseManager.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_CRASH_ONLY_DIR}/include/HockeySDK/BITHockeyManager.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_CRASH_ONLY_DIR}/include/HockeySDK/BITHockeyManagerDelegate.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_CRASH_ONLY_DIR}/include/HockeySDK/HockeySDK.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_CRASH_ONLY_DIR}/include/HockeySDK/HockeySDKNullability.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_CRASH_ONLY_DIR}/include/HockeySDK/HockeySDKEnums.h" "${INSTALL_DIR}/Headers/"

# Copy the patched feature header
cp -f "${SRCROOT}/HockeySDKCrashOnlyConfig.h" "${INSTALL_DIR}/Headers/HockeySDKFeatureConfig.h"

# Uses the Lipo Tool to merge both binary files (i386/x86_64 + armv7/armv7s/arm64) into one Universal final product.
lipo -create "${SRCROOT}/${DEVICE_CRASH_ONLY_DIR}/lib${FMK_NAME}.a" "${SRCROOT}/${SIMULATOR_CRASH_ONLY_DIR}/lib${FMK_NAME}.a" -output "${INSTALL_DIR}/${FMK_NAME}"

# Combine the CrashReporter static library into a new Hockey static library file if they are not already present and copy the public headers too
if [ -z $(otool -L "${INSTALL_DIR}/${FMK_NAME}" | grep 'libCrashReporter') ]
then
libtool -static -o "${INSTALL_DIR}/${FMK_NAME}" "${INSTALL_DIR}/${FMK_NAME}" "${SRCROOT}/../Vendor/CrashReporter.framework/Versions/A/CrashReporter"
fi

# Move the crash reporting only framework into a new folder
mkdir "${INSTALL_DIR}/../${FMK_NAME}CrashOnly"
mv "${INSTALL_DIR}" "${INSTALL_DIR}/../${FMK_NAME}CrashOnly/${FMK_NAME}.framework"

rm -r "${WRK_DIR}"

# ////////////////////////////////////////////////////////
# Building the extensions crash only SDK without resources
# ////////////////////////////////////////////////////////

# Building both architectures.
xcodebuild -project "HockeySDK.xcodeproj" -configuration "ReleaseCrashOnlyExtensions" -target "${FMK_NAME}" -sdk iphoneos
xcodebuild -project "HockeySDK.xcodeproj" -configuration "ReleaseCrashOnlyExtensions" -target "${FMK_NAME}" -sdk iphonesimulator

# Creates and renews the final product folder.
mkdir -p "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}/Headers"
mkdir -p "${INSTALL_DIR}/Modules"

# Copy the swift import file
cp -f "${SRCROOT}/module_crashonly.modulemap" "${INSTALL_DIR}/Modules/module.modulemap"

# Copies the headers without the resources files to the final product folder.
cp -R "${SRCROOT}/${DEVICE_EXTENSIONS_CRASH_ONLY_DIR}"/include/HockeySDK/BITCrash*.h "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_EXTENSIONS_CRASH_ONLY_DIR}/include/HockeySDK/BITHockeyAttachment.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_EXTENSIONS_CRASH_ONLY_DIR}/include/HockeySDK/BITHockeyBaseManager.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_EXTENSIONS_CRASH_ONLY_DIR}/include/HockeySDK/BITHockeyManager.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_EXTENSIONS_CRASH_ONLY_DIR}/include/HockeySDK/BITHockeyManagerDelegate.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_EXTENSIONS_CRASH_ONLY_DIR}/include/HockeySDK/HockeySDK.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_EXTENSIONS_CRASH_ONLY_DIR}/include/HockeySDK/HockeySDKNullability.h" "${INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_EXTENSIONS_CRASH_ONLY_DIR}/include/HockeySDK/HockeySDKEnums.h" "${INSTALL_DIR}/Headers/"

# Copy the patched feature header
cp -f "${SRCROOT}/HockeySDKCrashOnlyExtensionConfig.h" "${INSTALL_DIR}/Headers/HockeySDKFeatureConfig.h"

# Uses the Lipo Tool to merge both binary files (i386/x86_64 + armv7/armv7s/arm64) into one Universal final product.
lipo -create "${SRCROOT}/${DEVICE_EXTENSIONS_CRASH_ONLY_DIR}/lib${FMK_NAME}.a" "${SRCROOT}/${SIMULATOR_EXTENSIONS_CRASH_ONLY_DIR}/lib${FMK_NAME}.a" -output "${INSTALL_DIR}/${FMK_NAME}"

# Combine the CrashReporter static library into a new Hockey static library file if they are not already present and copy the public headers too
if [ -z $(otool -L "${INSTALL_DIR}/${FMK_NAME}" | grep 'libCrashReporter') ]
then
libtool -static -o "${INSTALL_DIR}/${FMK_NAME}" "${INSTALL_DIR}/${FMK_NAME}" "${SRCROOT}/../Vendor/CrashReporter.framework/Versions/A/CrashReporter"
fi

# Move the crash reporting only framework into a new folder
mkdir "${INSTALL_DIR}/../${FMK_NAME}CrashOnlyExtension"
mv "${INSTALL_DIR}" "${INSTALL_DIR}/../${FMK_NAME}CrashOnlyExtension/${FMK_NAME}.framework"

rm -r "${WRK_DIR}"

# //////////////////////////////
# Building the Feedback-Only SDK
# //////////////////////////////

# Building both architectures.
xcodebuild -project "HockeySDK.xcodeproj" -configuration "ReleaseFeedbackOnly" -target "${FMK_NAME}" -sdk iphoneos
xcodebuild -project "HockeySDK.xcodeproj" -configuration "ReleaseFeedbackOnly" -target "${FMK_NAME}" -sdk iphonesimulator

# Creates and renews the final product folder.
mkdir -p "${FEEDBACK_ONLY_INSTALL_DIR}"
mkdir -p "${FEEDBACK_ONLY_INSTALL_DIR}/Headers"
mkdir -p "${FEEDBACK_ONLY_INSTALL_DIR}/Modules"

# Copy the swift import file
cp -f "${SRCROOT}/module_feedbackonly.modulemap" "${FEEDBACK_ONLY_INSTALL_DIR}/Modules/module.modulemap"

# Copies the headers and resources files to the final product folder.
cp -R "${SRCROOT}/${DEVICE_DIR_ONLY_FEEDBACK}"/include/HockeySDK/BITFeedback*.h "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR_ONLY_FEEDBACK}/include/HockeySDK/BITHockeyAttachment.h" "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR_ONLY_FEEDBACK}/include/HockeySDK/BITHockeyBaseManager.h" "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR_ONLY_FEEDBACK}/include/HockeySDK/BITHockeyBaseViewController.h" "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR_ONLY_FEEDBACK}/include/HockeySDK/BITHockeyManager.h" "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR_ONLY_FEEDBACK}/include/HockeySDK/BITHockeyManagerDelegate.h" "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR_ONLY_FEEDBACK}/include/HockeySDK/HockeySDK.h" "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR_ONLY_FEEDBACK}/include/HockeySDK/HockeySDKEnums.h" "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR_ONLY_FEEDBACK}/include/HockeySDK/HockeySDKFeatureConfig.h" "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/"
cp -R "${SRCROOT}/${DEVICE_DIR_ONLY_FEEDBACK}/include/HockeySDK/HockeySDKNullability.h" "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/"

# Copy the patched feature header
cp -f "${SRCROOT}/HockeySDKFeedbackOnlyConfig.h" "${FEEDBACK_ONLY_INSTALL_DIR}/Headers/HockeySDKFeatureConfig.h"

# Use the Lipo Tool to merge both binary files (i386/x86_64 + armv7/armv7s/arm64) into one Universal final product.
lipo -create "${DEVICE_DIR_ONLY_FEEDBACK}/lib${FMK_NAME}.a" "${SIMULATOR_DIR_ONLY_FEEDBACK}/lib${FMK_NAME}.a" -output "${FEEDBACK_ONLY_INSTALL_DIR}/${FMK_NAME}"

# build embeddedframework folder and move framework into it
mkdir "${FEEDBACK_ONLY_INSTALL_DIR}/../${FMK_NAME}.embeddedframework"
mv "${FEEDBACK_ONLY_INSTALL_DIR}/" "${FEEDBACK_ONLY_INSTALL_DIR}/../${FMK_NAME}.embeddedframework/${FMK_NAME}.framework"
mv "${DEVICE_DIR_ONLY_FEEDBACK}/${FMK_RESOURCE_BUNDLE}.bundle" "${TEMP_DIR}/HockeySDKFeedbackOnly/${FMK_NAME}.embeddedframework/"

# do some cleanup
rm -r "${WRK_DIR}"

# //////////////////////////////
# Final steps: move documentation and create zip-file
# //////////////////////////////

# copy license, changelog, documentation, integration json
cp -f "${SRCROOT}/../Documentation/Guides/Changelog.md" "${TEMP_DIR}/CHANGELOG"
cp -f "${SRCROOT}/../Documentation/Guides/Installation & Setup.md" "${TEMP_DIR}/README.md"
cp -f "${SRCROOT}/../LICENSE" "${TEMP_DIR}"
cp -R "${SRCROOT}/../Documentation/HockeySDK/Generated/docsets/HockeySDK.docset" "${TEMP_DIR}"
mv "${TEMP_DIR}/HockeySDK.docset" "${TEMP_DIR}/${HOCKEYSDK_DOCSET_VERSION_NAME}.docset"

# build zip
cd "${PRODUCTS_DIR}"
rm -f "${FMK_NAME}-iOS-${VERSION_STRING}.zip"
zip -yr "${FMK_NAME}-iOS-${VERSION_STRING}.zip" "${ZIP_FOLDER}" -x \*/.*

cd "${ZIP_FOLDER}"
rm -f "${FMK_NAME}-iOS-documentation-${VERSION_STRING}.zip"
zip -yr "${FMK_NAME}-iOS-documentation-${VERSION_STRING}.zip" "${HOCKEYSDK_DOCSET_VERSION_NAME}.docset" -x \*/.*
mv "${FMK_NAME}-iOS-documentation-${VERSION_STRING}.zip" "../"
