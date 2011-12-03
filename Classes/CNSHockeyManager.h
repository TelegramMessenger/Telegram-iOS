//  Copyright 2011 Codenauts UG (haftungsbeschränkt). All rights reserved.
//  See LICENSE.txt for author information.
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

@class BWHockeyManager;

@protocol CNSHockeyManagerDelegate <NSObject>

@optional

// Invoked when the manager is configured
// 
// Implement to force the usage of the live identifier, e.g. for enterprise apps
// which are distributed inside your company
- (BOOL)shouldUseLiveIdenfitier;

// Invoked when the internet connection is started
// 
// Implement to let the delegate enable the activity indicator
- (void)connectionOpened;

// Invoked when the internet connection is closed
// 
// Implement to let the delegate disable the activity indicator
- (void)connectionClosed;

// Invoked via the alert view to define the presenting view controller
// 
// Default is the root view controller of the main window instance
- (UIViewController *)viewControllerForHockeyController:(BWHockeyManager *)hockeyController;

// Invoked before a crash report will be sent
// 
// Return a userid or similar which the crashreport should contain
// 
// Maximum length: 255 chars
// 
// Default: empty
- (NSString *)crashReportUserID;

// Invoked before a crash report will be sent
// 
// Return contact data, e.g. an email address, for the crash report
// Maximum length: 255 chars
// 
// Default: empty
-(NSString *)crashReportContact;

// Invoked before a crash report will be sent
// 
// Return a the description for the crashreport should contain; the string
// will automatically be wrapped into <[DATA[ ]]>, so make sure you don't do 
// that in your string.
// 
// Default: empty 
-(NSString *)crashReportDescription;

// Invoked before the user is asked to send a crash report
// 
// Implement to do additional actions, e.g. to make sure to not to ask the 
// user for an app rating :) 
- (void)willShowSubmitCrashReportAlert;

@end

@interface CNSHockeyManager : NSObject {
@private
  id delegate;
  NSString *appIdentifier;
}

// Custom language style; set to a string which will be appended to 
// to the localization file name; the Hockey SDK includes an alternative
// file, to use this, set to @"Alternate"
// 
// Default: nil
@property (nonatomic, retain) NSString *languageStyle;

// Show button "Always" in crash alert; this will cause the dialog not to 
// show the alert description text landscape mode! (default)
//
// Default: NO
@property (nonatomic, assign, getter=isShowingAlwaysButton) BOOL showAlwaysButton;

// Show feedback from server with status of the crash; if you set a crash
// to resolved on HockeyApp and assign a fixed version, this version will
// be reported to the user
//
// Default: NO
@property (nonatomic, assign, getter=isFeedbackActivated) BOOL feedbackActivated;

// Submit crash report without asking the user
//
// Default: NO
@property (nonatomic, assign, getter=isAutoSubmitCrashReport) BOOL autoSubmitCrashReport;

// Submit the device's UDID in the field UserID if crashReportUserID is not
// implemented (see CNSHockeyManagerDelegate); DO NOT USE THIS FOR LIVE
// VERSION OF YOUR APP AS THIS VIOLATES THE USERS PRIVACY!
//
// Default: NO
@property (nonatomic, assign, getter=isAutoSubmitDeviceUDID) BOOL autoSubmitDeviceUDID;

// Returns the shared manager object
+ (CNSHockeyManager *)sharedHockeyManager;

// Configure HockeyApp with a single app identifier and delegate; use this
// only for debug or beta versions of your app!
- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id)delegate;

// Configure HockeyApp with different app identifiers for beta and live versions
// of the app; the update alert will only be shown for the beta identifier
- (void)configureWithBetaIdentifier:(NSString *)betaIdentifier liveIdentifier:(NSString *)liveIdentifier delegate:(id)delegate;

// Returns true if the app crashes in the last session
- (BOOL)didCrashInLastSession;

@end
