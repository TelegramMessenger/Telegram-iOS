//
//  CNSCrashReportManagerDelegate.h
//  HockeySDK
//
//  Created by Andreas Linde on 29.03.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

// This protocol is used to send the image updates
@protocol BWQuincyManagerDelegate <NSObject>

@optional

// Return the userid the crashreport should contain, empty by default
-(NSString *) crashReportUserID;

// Return the contact value (e.g. email) the crashreport should contain, empty by default
-(NSString *) crashReportContact;

// Return the description the crashreport should contain, empty by default. The string will automatically be wrapped into <[DATA[ ]]>, so make sure you don't do that in your string.
-(NSString *) crashReportDescription;

// Invoked when the internet connection is started, to let the app enable the activity indicator
-(void) connectionOpened;

// Invoked when the internet connection is closed, to let the app disable the activity indicator
-(void) connectionClosed;

// Invoked before the user is asked to send a crash report, so you can do additional actions. E.g. to make sure not to ask the user for an app rating :) 
-(void) willShowSubmitCrashReportAlert;

// Invoked after the user did choose to send crashes always in the alert 
-(void) userDidChooseSendAlways;

// Invoked right before sending crash reports to the server succeeded
-(void) sendingCrashReportsDidStart;

// Invoked after sending crash reports to the server failed
-(void) sendingCrashReportsDidFailWithError:(NSError *)error;

// Invoked after sending crash reports to the server succeeded
-(void) sendingCrashReportsDidFinish;

@end