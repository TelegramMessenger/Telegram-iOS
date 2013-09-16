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

#import "BITHockeyBaseManager.h"


/**
 * Crash Manager status
 */
typedef NS_ENUM(NSUInteger, BITCrashManagerStatus) {
  /**
   *	Crash reporting is disabled
   */
  BITCrashManagerStatusDisabled = 0,
  /**
   *	User is asked each time before sending
   */
  BITCrashManagerStatusAlwaysAsk = 1,
  /**
   *	Each crash report is send automatically
   */
  BITCrashManagerStatusAutoSend = 2
};


@protocol BITCrashManagerDelegate;

/**
 The crash reporting module.
 
 This is the HockeySDK module for handling crash reports, including when distributed via the App Store.
 As a foundation it is using the open source, reliable and async-safe crash reporting framework
 [PLCrashReporter](https://code.google.com/p/plcrashreporter/).
 
 This module works as a wrapper around the underlying crash reporting framework and provides functionality to
 detect new crashes, queues them if networking is not available, present a user interface to approve sending
 the reports to the HockeyApp servers and more.
 
 It also provides options to add additional meta information to each crash report, like `userName`, `userEmail`,
 additional textual log information via `BITCrashManagerDelegate` protocol and a way to detect startup crashes so
 you can adjust your startup process to get these crash reports too and delay your app initialization.
 
 Crashes are send the next time the app starts. If `crashManagerStatus` is set to `BITCrashManagerStatusAutoSend`,
 crashes will be send without any user interaction, otherwise an alert will appear allowing the users to decide
 whether they want to send the report or not. This module is not sending the reports right when the crash happens
 deliberately, because if is not safe to implement such a mechanism while being async-safe (any Objective-C code
 is _NOT_ async-safe!) and not causing more danger like a deadlock of the device, than helping. We found that users
 do start the app again because most don't know what happened, and you will get by far most of the reports.
 
 Sending the reports on startup is done asynchronously (non-blocking). This is the only safe way to ensure
 that the app won't be possibly killed by the iOS watchdog process, because startup could take too long
 and the app could not react to any user input when network conditions are bad or connectivity might be
 very slow.
 
 More background information on this topic can be found in the following blog post by Landon Fuller, the
 developer of [PLCrashReporter](https://www.plcrashreporter.org), about writing reliable and
 safe crash reporting: [Reliable Crash Reporting](http://goo.gl/WvTBR)
 
 @warning If you start the app with the Xcode debugger attached, detecting crashes will _NOT_ be enabled!
 */

@interface BITCrashManager : BITHockeyBaseManager


///-----------------------------------------------------------------------------
/// @name Delegate
///-----------------------------------------------------------------------------

/**
 Sets the optional `BITCrashManagerDelegate` delegate.
 */
@property (nonatomic, weak) id delegate;


///-----------------------------------------------------------------------------
/// @name Configuration
///-----------------------------------------------------------------------------

/** Set the default status of the Crash Manager
 
 Defines if the crash reporting feature should be disabled, ask the user before
 sending each crash report or send crash reportings automatically without
 asking.
 
 The default value is `BITCrashManagerStatusAlwaysAsk`. You can allow the user
 to switch from `BITCrashManagerStatusAlwaysAsk` to
 `BITCrashManagerStatusAutoSend` by setting `showAlwaysButton`
 to _YES_.
 
 The current value is always stored in User Defaults with the key
 `BITCrashManagerStatus`.
 
 If you intend to implement a user setting to let them enable or disable
 crash reporting, this delegate should be used to return that value. You also
 have to make sure the new value is stored in the UserDefaults with the key
 `BITCrashManagerStatus`.
 
 @see showAlwaysButton
 */
@property (nonatomic, assign) BITCrashManagerStatus crashManagerStatus;


/**
 *  Trap fatal signals via a Mach exception server.
 *
 *  By default the SDK is using the safe and proven in-process BSD Signals for catching crashes.
 *  This option provides an option to enable catching fatal signals via a Mach exception server
 *  instead.
 *
 *  We strongly advice _NOT_ to enable Mach exception handler in release versions of your apps!
 *
 *  Default: _NO_
 *
 * @warning The Mach exception handler executes in-process, and will interfere with debuggers when
 *  they attempt to suspend all active threads (which will include the Mach exception handler).
 *  Mach-based handling should _NOT_ be used when a debugger is attached. The SDK will not
 *  enabled catching exceptions if the app is started with the debugger running. If you attach
 *  the debugger during runtime, this may cause issues the Mach exception handler is enabled!
 * @see isDebuggerAttached
 */
@property (nonatomic, assign, getter=isMachExceptionHandlerEnabled) BOOL enableMachExceptionHandler;


/**
 Flag that determines if an "Always" option should be shown
 
 If enabled the crash reporting alert will also present an "Always" option, so
 the user doesn't have to approve every single crash over and over again.
 
 If If `crashManagerStatus` is set to `BITCrashManagerStatusAutoSend`, this property
 has no effect, since no alert will be presented.
 
 @warning This will cause the dialog not to show the alert description text landscape mode!
 @see crashManagerStatus
 */
@property (nonatomic, assign, getter=shouldShowAlwaysButton) BOOL showAlwaysButton;


///-----------------------------------------------------------------------------
/// @name Crash Meta Information
///-----------------------------------------------------------------------------

/**
 Indicates if the app crash in the previous session

 Use this on startup, to check if the app starts the first time after it crashed
 previously. You can use this also to disable specific events, like asking
 the user to rate your app.
 
 @warning This property only has a correct value, once `[BITHockeyManager startManager]` was
 invoked!
 */
@property (nonatomic, readonly) BOOL didCrashInLastSession;


/**
 Provides the time between startup and crash in seconds
 
 Use this in together with `didCrashInLastSession` to detect if the app crashed very
 early after startup. This can be used to delay app initialization until the crash
 report has been sent to the server or if you want to do any other actions like
 cleaning up some cache data etc.
 
 Note that sending a crash reports starts as early as 1.5 seconds after the application
 did finish launching!
 
 The `BITCrashManagerDelegate` protocol provides some delegates to inform if sending
 a crash report was finished successfully, ended in error or was cancelled by the user.
 
 *Default*: _-1_
 @see didCrashInLastSession
 @see BITCrashManagerDelegate
 */
@property (nonatomic, readonly) NSTimeInterval timeintervalCrashInLastSessionOccured;


///-----------------------------------------------------------------------------
/// @name Helper
///-----------------------------------------------------------------------------

/**
 *  Detect if a debugger is attached to the app process
 *
 *  This is only invoked once on app startup and can not detect if the debugger is being
 *  attached during runtime!
 *
 *  @return BOOL if the debugger is attached on app startup
 */
- (BOOL)isDebuggerAttached;

@end
