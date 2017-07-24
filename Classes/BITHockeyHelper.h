/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HockeySDKEnums.h"

@interface BITHockeyHelper : NSObject

FOUNDATION_EXPORT NSString *const kBITExcludeApplicationSupportFromBackup;

+ (BOOL)isURLSessionSupported;

/*
 * Checks if the privacy description for iOS 10+ has been set in info plist.
 * @return YES for < iOS 10. YES/NO in iOS 10+ if NSPhotoLibraryUsageDescription is present in the app's Info.plist.
 */
+ (BOOL)isPhotoAccessPossible;

@end

NSString *bit_settingsDir(void);

BOOL bit_validateEmail(NSString *email);
NSString *bit_keychainHockeySDKServiceName(void);

/* Fix bug where Application Support was excluded from backup. */
void bit_fixBackupAttributeForURL(NSURL *directoryURL);

NSComparisonResult bit_versionCompare(NSString *stringA, NSString *stringB);
NSString *bit_mainBundleIdentifier(void);
NSString *bit_encodeAppIdentifier(NSString *inputString);
NSString *bit_appIdentifierToGuid(NSString *appIdentifier);
NSString *bit_appName(NSString *placeHolderString);
NSString *bit_UUID(void);
NSString *bit_appAnonID(BOOL forceNewAnonID);
BOOL bit_isPreiOS8Environment(void);
BOOL bit_isPreiOS10Environment(void);
BOOL bit_isAppStoreReceiptSandbox(void);
BOOL bit_hasEmbeddedMobileProvision(void);
BITEnvironment bit_currentAppEnvironment(void);
BOOL bit_isRunningInAppExtension(void);

/**
 * Check if the debugger is attached
 *
 * Taken from https://github.com/plausiblelabs/plcrashreporter/blob/2dd862ce049e6f43feb355308dfc710f3af54c4d/Source/Crash%20Demo/main.m#L96
 *
 * @return `YES` if the debugger is attached to the current process, `NO` otherwise
 */
BOOL bit_isDebuggerAttached(void);

/* NSString helpers */
NSString *bit_URLEncodedString(NSString *inputString);
NSString *bit_base64String(NSData * data, unsigned long length);

/* Context helpers */
NSString *bit_utcDateString(NSDate *date);
NSString *bit_devicePlatform(void);
NSString *bit_devicePlatform(void);
NSString *bit_deviceType(void);
NSString *bit_osVersionBuild(void);
NSString *bit_osName(void);
NSString *bit_deviceLocale(void);
NSString *bit_deviceLanguage(void);
NSString *bit_screenSize(void);
NSString *bit_sdkVersion(void);
NSString *bit_appVersion(void);

#if !defined (HOCKEYSDK_CONFIGURATION_ReleaseCrashOnly) && !defined (HOCKEYSDK_CONFIGURATION_ReleaseCrashOnlyExtensions)
/* AppIcon helper */
NSString *bit_validAppIconStringFromIcons(NSBundle *resourceBundle, NSArray *icons);
NSString *bit_validAppIconFilename(NSBundle *bundle, NSBundle *resourceBundle);

/* UIImage helpers */
UIImage *bit_roundedCornerImage(UIImage *inputImage, CGFloat cornerSize, NSInteger borderSize);
UIImage *bit_imageToFitSize(UIImage *inputImage, CGSize fitSize, BOOL honorScaleFactor);
UIImage *bit_reflectedImageWithHeight(UIImage *inputImage, NSUInteger height, CGFloat fromAlpha, CGFloat toAlpha);

UIImage *bit_newWithContentsOfResolutionIndependentFile(NSString * path);
UIImage *bit_imageWithContentsOfResolutionIndependentFile(NSString * path);
UIImage *bit_imageNamed(NSString *imageName, NSString *bundleName);
UIImage *bit_screenshot(void);
UIImage *bit_appIcon(void);

#endif
