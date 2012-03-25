//
//  BWGlobal.h
//
//  Created by Andreas Linde on 08/17/10.
//  Copyright 2010-2011 Andreas Linde, Peter Steinberger. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BWHockeyManager.h"
#import "BWApp.h"

#define SDK_NAME @"HockeySDK"
#define SDK_VERSION @"2.2.6"

#ifndef HOCKEY_BLOCK_UDID
#define HOCKEY_BLOCK_UDID 1
#endif

// uncomment this line to enable NSLog-debugging output
//#define kHockeyDebugEnabled

#define kArrayOfLastHockeyCheck		@"ArrayOfLastHockeyCheck"
#define kDateOfLastHockeyCheck		@"DateOfLastHockeyCheck"
#define kDateOfVersionInstallation	@"DateOfVersionInstallation"
#define kUsageTimeOfCurrentVersion	@"UsageTimeOfCurrentVersion"
#define kUsageTimeForVersionString	@"kUsageTimeForVersionString"
#define kHockeyAutoUpdateSetting	@"HockeyAutoUpdateSetting"
#define kHockeyAllowUserSetting		@"HockeyAllowUserSetting"
#define kHockeyAllowUsageSetting	@"HockeyAllowUsageSetting"
#define kHockeyAutoUpdateSetting	@"HockeyAutoUpdateSetting"
#define kHockeyAuthorizedVersion	@"HockeyAuthorizedVersion"
#define kHockeyAuthorizedToken		@"HockeyAuthorizedToken"

#define kHockeyBundleName @"Hockey.bundle"

// Notification message which HockeyManager is listening to, to retry requesting updated from the server
#define BWHockeyNetworkBecomeReachable @"NetworkDidBecomeReachable"

#define BWHockeyLog(fmt, ...) do { if([BWHockeyManager sharedHockeyManager].isLoggingEnabled) { NSLog((@"[HockeyLib] %s/%d " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); }} while(0)

NSBundle *hockeyBundle(void);
NSString *BWmd5(NSString *str);
NSString *BWHockeyLocalize(NSString *stringToken);

// compatibility helper
#ifdef HOCKEYLIB_STATIC_LIBRARY
// If HockeyLib is built as a static library and linked into the project
// we can't use this project's deployment target to statically decide if
// native JSON is available
#define BW_NATIVE_JSON_AVAILABLE 0
#else
#define BW_NATIVE_JSON_AVAILABLE __IPHONE_OS_VERSION_MIN_REQUIRED >= 50000
#endif

#ifndef kCFCoreFoundationVersionNumber_iPhoneOS_3_2
#define kCFCoreFoundationVersionNumber_iPhoneOS_3_2 478.61
#endif
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
#define BW_IF_3_2_OR_GREATER(...) \
if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iPhoneOS_3_2) \
{ \
__VA_ARGS__ \
}
#else
#define BW_IF_3_2_OR_GREATER(...)
#endif
#define BW_IF_PRE_3_2(...) \
if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iPhoneOS_3_2) \
{ \
__VA_ARGS__ \
}

#ifndef kCFCoreFoundationVersionNumber_iPhoneOS_4_0
#define kCFCoreFoundationVersionNumber_iPhoneOS_4_0 550.32
#endif
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#define BW_IF_IOS4_OR_GREATER(...) \
if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iPhoneOS_4_0) \
{ \
__VA_ARGS__ \
}
#else
#define BW_IF_IOS4_OR_GREATER(...)
#endif

#define BW_IF_PRE_IOS4(...)  \
if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iPhoneOS_4_0)  \
{ \
__VA_ARGS__ \
}



#ifndef kCFCoreFoundationVersionNumber_iPhoneOS_5_0
#define kCFCoreFoundationVersionNumber_iPhoneOS_5_0 674.0
#endif
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
#define BW_IF_IOS5_OR_GREATER(...) \
if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iPhoneOS_5_0) \
{ \
__VA_ARGS__ \
}
#else
#define BW_IF_IOS5_OR_GREATER(...)
#endif

#define BW_IF_PRE_IOS5(...)  \
if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iPhoneOS_5_0)  \
{ \
__VA_ARGS__ \
}
