/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
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


typedef enum BITCrashAlertType {
  BITCrashAlertTypeSend = 0,
  BITCrashAlertTypeFeedback = 1,
} BITCrashAlertType;

typedef enum BITCrashStatus {
  BITCrashStatusQueued = -80,
  BITCrashStatusUnknown = 0,
  BITCrashStatusAssigned = 1,
  BITCrashStatusSubmitted = 2,
  BITCrashStatusAvailable = 3,
} BITCrashStatus;


@protocol BITCrashManagerDelegate;

/**
 The crash reporting module.
 
 This is the principal SDK class. It represents the entry point for the HockeySDK. The main promises of the class are initializing the SDK modules, providing access to global properties and to all modules. Initialization is divided into several distinct phases:
 
 1. Setup the [HockeyApp](http://hockeyapp.net/) app identifier and the optional delegate: This is the least required information on setting up the SDK and using it. It does some simple validation of the app identifier and checks if the app is running from the App Store or not. If the [Atlassian JMC framework](http://www.atlassian.com/jmc/) is found, it will disable its Crash Reporting module and configure it with the Jira configuration data from [HockeyApp](http://hockeyapp.net/).
 2. Provides access to the SDK modules `BITCrashManager` and `BITUpdateManager`. This way all modules can be further configured to personal needs, if the defaults don't fit the requirements.
 3. Start up all modules.
 
 Example:
 [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<AppIdentifierFromHockeyApp>" delegate:nil];
 [[BITHockeyManager sharedHockeyManager] startManager];
 
 */

@interface BITCrashManager : NSObject {
@private
  id <BITCrashManagerDelegate> _delegate;
  
  NSString *_appIdentifier;
  
  NSString *_feedbackRequestID;
  float _feedbackDelayInterval;
  
  BITCrashStatus _serverResult;
  
  int _analyzerStarted;
  NSString *_crashesDir;
  NSFileManager *_fileManager;
  
  BOOL _crashIdenticalCurrentVersion;
  BOOL _crashReportActivated;
  
  NSMutableArray *_crashFiles;
	
  NSMutableData *_responseData;
  NSInteger _statusCode;
  
  NSURLConnection *_urlConnection;
  
  NSData *_crashData;
  
  BOOL _sendingInProgress;
}

// delegate is optional
@property (nonatomic, assign) id <BITCrashManagerDelegate> delegate;

///////////////////////////////////////////////////////////////////////////////////////////////////
// settings

/** Define the users name or userid that should be send along each crash report
 */
@property (nonatomic, copy) NSString *userName;

/** Define the users email address that should be send along each crash report
 */
@property (nonatomic, copy) NSString *userEmail;

// if YES, the user will get the option to choose "Always" for sending crash reports. This will cause the dialog not to show the alert description text landscape mode! (default)
// if NO, the dialog will not show a "Always" button
@property (nonatomic, assign, getter=isShowingAlwaysButton) BOOL showAlwaysButton;

// if YES, the user will be presented with a status of the crash, if known
// if NO, the user will not see any feedback information (default)
@property (nonatomic, assign, getter=isFeedbackActivated) BOOL feedbackActivated;

// if YES, the crash report will be submitted without asking the user
// if NO, the user will be asked if the crash report can be submitted (default)
@property (nonatomic, assign, getter=isAutoSubmitCrashReport) BOOL autoSubmitCrashReport;

// will return YES if the last session crashed, to e.g. make sure a "rate my app" alert will not show up
@property (nonatomic, readonly) BOOL didCrashInLastSession;

// will return the timeinterval from startup to the crash in seconds, default is -1
@property (nonatomic, readonly) NSTimeInterval timeintervalCrashInLastSessionOccured;

@end
