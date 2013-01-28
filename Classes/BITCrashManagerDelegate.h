/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
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

@class BITCrashManager;

/**
 The `BITCrashManagerDelegate` formal protocol defines methods further configuring
 the behaviour of `BITCrashManager`.
 */

@protocol BITCrashManagerDelegate <NSObject>

@optional


///-----------------------------------------------------------------------------
/// @name Additional meta data
///-----------------------------------------------------------------------------

/** Return any log string based data the crash report being processed should contain

 @param crashManager The `BITCrashManager` instance invoking this delegate
 @see userNameForCrashManager:
 @see userEmailForCrashManager:
 */
-(NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager;



/** Return the user name or userid that should be send along each crash report
 
 @param crashManager The `BITCrashManager` instance invoking this delegate
 @see applicationLogForCrashManager:
 @see userEmailForCrashManager:
 @deprecated Please use `BITHockeyManagerDelegate userNameForHockeyManager:componentManager:` instead
 @warning When returning a non nil value, crash reports are not anonymous any
 more and the alerts will not show the "anonymous" word!
 */
-(NSString *)userNameForCrashManager:(BITCrashManager *)crashManager DEPRECATED_ATTRIBUTE;



/** Return the users email address that should be send along each crash report
 
 @param crashManager The `BITCrashManager` instance invoking this delegate
 @see applicationLogForCrashManager:
 @see userNameForCrashManager:
 @deprecated Please use `BITHockeyManagerDelegate userEmailForHockeyManager:componentManager:` instead
 @warning When returning a non nil value, crash reports are not anonymous any
 more and the alerts will not show the "anonymous" word!
 */
-(NSString *)userEmailForCrashManager:(BITCrashManager *)crashManager DEPRECATED_ATTRIBUTE;



///-----------------------------------------------------------------------------
/// @name Alert
///-----------------------------------------------------------------------------

/** Invoked before the user is asked to send a crash report, so you can do additional actions.
 E.g. to make sure not to ask the user for an app rating :)
 
 @param crashManager The `BITCrashManager` instance invoking this delegate
 */
-(void)crashManagerWillShowSubmitCrashReportAlert:(BITCrashManager *)crashManager;


/** Invoked after the user did choose _NOT_ to send a crash in the alert
 
 @param crashManager The `BITCrashManager` instance invoking this delegate
 */
-(void)crashManagerWillCancelSendingCrashReport:(BITCrashManager *)crashManager;


/** Invoked after the user did choose to send crashes always in the alert
 
 @param crashManager The `BITCrashManager` instance invoking this delegate
 */
-(void)crashManagerWillSendCrashReportsAlways:(BITCrashManager *)crashManager;


///-----------------------------------------------------------------------------
/// @name Networking
///-----------------------------------------------------------------------------

/** Invoked right before sending crash reports will start
 
 @param crashManager The `BITCrashManager` instance invoking this delegate
 */
- (void)crashManagerWillSendCrashReport:(BITCrashManager *)crashManager;

/** Invoked after sending crash reports failed
 
 @param crashManager The `BITCrashManager` instance invoking this delegate
 @param error The error returned from the NSURLConnection call or `kBITCrashErrorDomain`
 with reason of type `BITCrashErrorReason`.
 */
- (void)crashManager:(BITCrashManager *)crashManager didFailWithError:(NSError *)error;

/** Invoked after sending crash reports succeeded
 
 @param crashManager The `BITCrashManager` instance invoking this delegate
 */
- (void)crashManagerDidFinishSendingCrashReport:(BITCrashManager *)crashManager;

@end
