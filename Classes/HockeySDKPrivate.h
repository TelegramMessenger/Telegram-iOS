/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde & Kent Sutherland.
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

#ifndef HockeySDK_HockeySDKPrivate_h
#define HockeySDK_HockeySDKPrivate_h

#define BITHOCKEY_NAME @"HockeySDK"
#define BITHOCKEY_IDENTIFIER @"net.hockeyapp.sdk.ios"
#define BITHOCKEY_CRASH_SETTINGS @"BITCrashManager.plist"
#define BITHOCKEY_CRASH_ANALYZER @"BITCrashManager.analyzer"

#define BITHOCKEY_FEEDBACK_SETTINGS @"BITFeedbackManager.plist"

#define BITHOCKEY_USAGE_DATA @"BITUpdateManager.plist"

#define kBITHockeyMetaUserName  @"BITHockeyMetaUserName"
#define kBITHockeyMetaUserEmail @"BITHockeyMetaUserEmail"
#define kBITHockeyMetaUserID    @"BITHockeyMetaUserID"

#define kBITUpdateInstalledUUID              @"BITUpdateInstalledUUID"
#define kBITUpdateInstalledVersionID         @"BITUpdateInstalledVersionID"
#define kBITUpdateCurrentCompanyName         @"BITUpdateCurrentCompanyName"
#define kBITUpdateArrayOfLastCheck           @"BITUpdateArrayOfLastCheck"
#define kBITUpdateDateOfLastCheck            @"BITUpdateDateOfLastCheck"
#define kBITUpdateDateOfVersionInstallation  @"BITUpdateDateOfVersionInstallation"
#define kBITUpdateUsageTimeOfCurrentVersion  @"BITUpdateUsageTimeOfCurrentVersion"
#define kBITUpdateUsageTimeForUUID           @"BITUpdateUsageTimeForUUID"
#define kBITUpdateInstallationIdentification @"BITUpdateInstallationIdentification"

#define kBITStoreUpdateDateOfLastCheck       @"BITStoreUpdateDateOfLastCheck"
#define kBITStoreUpdateLastStoreVersion      @"BITStoreUpdateLastStoreVersion"
#define kBITStoreUpdateLastUUID              @"BITStoreUpdateLastUUID"
#define kBITStoreUpdateIgnoreVersion         @"BITStoreUpdateIgnoredVersion"

#define BITHOCKEY_INTEGRATIONFLOW_TIMESTAMP  @"BITIntegrationFlowStartTimestamp"

#define BITHOCKEYSDK_BUNDLE @"HockeySDKResources.bundle"
#define BITHOCKEYSDK_URL @"https://sdk.hockeyapp.net/"

#define BITHockeyLog(fmt, ...) do { if([BITHockeyManager sharedHockeyManager].isDebugLogEnabled && ![BITHockeyManager sharedHockeyManager].isAppStoreEnvironment) { NSLog((@"[HockeySDK] %s/%d " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); }} while(0)

#define BIT_RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]

NSBundle *BITHockeyBundle(void);
NSString *BITHockeyLocalizedString(NSString *stringToken);
NSString *BITHockeyMD5(NSString *str);

#ifndef __IPHONE_8_0
#define __IPHONE_8_0     80000
#endif

#ifdef __IPHONE_6_0

#define kBITTextLabelAlignmentCenter        NSTextAlignmentCenter
#define kBITTextLabelAlignmentLeft          NSTextAlignmentLeft
#define kBITTextLabelAlignmentRight         NSTextAlignmentRight
#define kBITLineBreakModeMiddleTruncation   NSLineBreakByTruncatingMiddle

#else

#define kBITTextLabelAlignmentCenter        UITextAlignmentCenter
#define kBITTextLabelAlignmentLeft          UITextAlignmentLeft
#define kBITTextLabelAlignmentRight         UITextAlignmentRight
#define kBITLineBreakModeMiddleTruncation   UILineBreakModeMiddleTruncation

#endif /* __IPHONE_6_0 */

#if __IPHONE_OS_VERSION_MIN_REQUIRED > __IPHONE_6_1

#define kBITButtonTypeSystem                UIButtonTypeSystem

#else

#define kBITButtonTypeSystem                UIButtonTypeRoundedRect

#endif

#endif //HockeySDK_HockeySDKPrivate_h
