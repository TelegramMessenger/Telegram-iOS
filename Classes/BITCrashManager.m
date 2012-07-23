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

#import <CrashReporter/CrashReporter.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIKit.h>
#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITCrashManagerPrivate.h"
#import "BITCrashReportTextFormatter.h"

#include <sys/sysctl.h>

// flags if the crashreporter should automatically send crashes without asking the user again
#define kBITCrashAutomaticallySendReports @"BITCrashAutomaticallySendReports"

// flags if the crashlog analyzer is started. since this may theoretically crash we need to track it
#define kBITCrashAnalyzerStarted @"HockeySDKCrashAnalyzerStarted"

// stores the set of crashreports that have been approved but aren't sent yet
#define kBITCrashApprovedReports @"HockeySDKCrashApprovedReports"

// stores the user name entered in the UI
#define kBITCrashUserName @"HockeySDKCrashUserName"

// stores the user email address entered in the UI
#define kBITCrashUserEmail @"HockeySDKCrashUserEmail"


typedef enum BITCrashAlertType {
  BITCrashAlertTypeSend = 0,
  BITCrashAlertTypeFeedback = 1,
} BITCrashAlertType;


@interface BITCrashManager ()

@property (nonatomic, retain) NSFileManager *fileManager;

@end

@implementation BITCrashManager

@synthesize delegate = _delegate;
@synthesize crashManagerStatus = _crashManagerStatus;
@synthesize showAlwaysButton = _showAlwaysButton;
@synthesize feedbackActivated = _feedbackActivated;
@synthesize didCrashInLastSession = _didCrashInLastSession;
@synthesize timeintervalCrashInLastSessionOccured = _timeintervalCrashInLastSessionOccured;

@synthesize fileManager = _fileManager;


- (id)initWithAppIdentifier:(NSString *)appIdentifier {
  if ((self = [super init])) {
    BITHockeyLog(@"Initializing CrashReporter");
    
    _appIdentifier = appIdentifier;
    
    _delegate = nil;
    _feedbackActivated = NO;
    _showAlwaysButton = NO;

    _serverResult = BITCrashStatusUnknown;
    _crashIdenticalCurrentVersion = YES;
    _crashData = nil;
    _urlConnection = nil;
    _responseData = nil;
    _sendingInProgress = NO;
    _didCrashInLastSession = NO;
    _timeintervalCrashInLastSessionOccured = -1;
    _fileManager = [[NSFileManager alloc] init];
    
    NSString *testValue = [[NSUserDefaults standardUserDefaults] stringForKey:kBITCrashAnalyzerStarted];
    if (testValue) {
      _analyzerStarted = [[NSUserDefaults standardUserDefaults] integerForKey:kBITCrashAnalyzerStarted];
    } else {
      _analyzerStarted = 0;		
    }
		
    _crashManagerStatus = BITCrashManagerStatusAlwaysAsk;
    
    testValue = [[NSUserDefaults standardUserDefaults] stringForKey:kBITCrashManagerStatus];
    if (testValue) {
      _crashManagerStatus = [[NSUserDefaults standardUserDefaults] integerForKey:kBITCrashManagerStatus];
    } else {
      [[NSUserDefaults standardUserDefaults] setInteger:_crashManagerStatus forKey:kBITCrashManagerStatus];
    }
    
    if (_crashManagerStatus != BITCrashManagerStatusDisabled) {
      _crashFiles = [[NSMutableArray alloc] init];
      NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
      _crashesDir = [[NSString stringWithFormat:@"%@", [[paths objectAtIndex:0] stringByAppendingPathComponent:@"/crashes/"]] retain];
			
      if (![self.fileManager fileExistsAtPath:_crashesDir]) {
        NSDictionary *attributes = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedLong: 0755] forKey: NSFilePosixPermissions];
        NSError *theError = NULL;
				
        [self.fileManager  createDirectoryAtPath:_crashesDir withIntermediateDirectories: YES attributes: attributes error: &theError];
      }
      
      PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
      NSError *error = NULL;
      
      // Check if we previously crashed
      if ([crashReporter hasPendingCrashReport]) {
        _didCrashInLastSession = YES;
        [self handleCrashReport];
      }
      
      // Enable the Crash Reporter
      if (![crashReporter enableCrashReporterAndReturnError: &error])
        NSLog(@"WARNING: Could not enable crash reporter: %@", error);
      
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startManager) name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
    }
    
    if (!BITHockeyBundle()) {
      NSLog(@"WARNING: %@.bundle is missing, will send reports automatically!", BITHOCKEYSDK_BUNDLE);
    }
  }
  return self;
}


- (void) dealloc {
  self.delegate = nil;
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
  
  [_appIdentifier release];
  _appIdentifier = nil;
  
  [_urlConnection cancel];
  [_urlConnection release]; 
  _urlConnection = nil;
  
  [_crashData release];
  
  [_crashesDir release];
  [_crashFiles release];
  
  [_fileManager release];
  _fileManager = nil;
  
  [super dealloc];
}


- (void)setCrashManagerStatus:(BITCrashManagerStatus)crashManagerStatus {
  _crashManagerStatus = crashManagerStatus;
  
  [[NSUserDefaults standardUserDefaults] setInteger:crashManagerStatus forKey:kBITCrashManagerStatus];
}


#pragma mark - private methods

// begin the startup process
- (void)startManager {
  if (!_sendingInProgress && [self hasPendingCrashReport]) {
    _sendingInProgress = YES;
    if (!BITHockeyBundle()) {
			NSLog(@"WARNING: HockeySDKResource.bundle is missing, sending reports automatically!");
      [self sendCrashReports];
    } else if (_crashManagerStatus != BITCrashManagerStatusAutoSend && [self hasNonApprovedCrashReports]) {
      
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillShowSubmitCrashReportAlert:)]) {
        [self.delegate crashManagerWillShowSubmitCrashReportAlert:self];
      }
      
      NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
      NSString *alertDescription = [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundAnonymousDescription"), appName];
      
      // the crash report is not anynomous any more if username or useremail are not nil
      NSString *username = nil;
      NSString *useremail = nil;

      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(userNameForCrashManager:)]) {
        username = [self.delegate userNameForCrashManager:self];
      }

      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(userEmailForCrashManager:)]) {
        useremail = [self.delegate userEmailForCrashManager:self];
      }

      if (username || useremail) {
        alertDescription = [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundDescription"), appName];
      }
      
      UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundTitle"), appName]
                                                          message:alertDescription
                                                         delegate:self
                                                cancelButtonTitle:BITHockeyLocalizedString(@"CrashDontSendReport")
                                                otherButtonTitles:BITHockeyLocalizedString(@"CrashSendReport"), nil];
      
      if ([self isShowingAlwaysButton]) {
        [alertView addButtonWithTitle:BITHockeyLocalizedString(@"CrashSendReportAlways")];
      }
      
      [alertView setTag: BITCrashAlertTypeSend];
      [alertView show];
      [alertView release];
    } else {
      [self sendCrashReports];
    }
  }
}


#pragma mark - PLCrashReporter

//
// Called to handle a pending crash report.
//
- (void) handleCrashReport {
  PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
  NSError *error = NULL;
	
  // check if the next call ran successfully the last time
  if (_analyzerStarted == 0) {
    // mark the start of the routine
    _analyzerStarted = 1;
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:_analyzerStarted] forKey:kBITCrashAnalyzerStarted];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Try loading the crash report
    _crashData = [[NSData alloc] initWithData:[crashReporter loadPendingCrashReportDataAndReturnError: &error]];
    
    NSString *cacheFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
    
    if (_crashData == nil) {
      NSLog(@"Could not load crash report: %@", error);
    } else {
      [_crashData writeToFile:[_crashesDir stringByAppendingPathComponent: cacheFilename] atomically:YES];
      
      // get the startup timestamp from the crash report, and the file timestamp to calculate the timeinterval when the crash happened after startup
      PLCrashReport *report = [[[PLCrashReport alloc] initWithData:_crashData error:&error] autorelease];
      
      if (report.systemInfo.timestamp && report.applicationInfo.applicationStartupTimestamp) {
        _timeintervalCrashInLastSessionOccured = [report.systemInfo.timestamp timeIntervalSinceDate:report.applicationInfo.applicationStartupTimestamp];
      }
    }
  }
	
  // Purge the report
  // mark the end of the routine
  _analyzerStarted = 0;
  [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:_analyzerStarted] forKey:kBITCrashAnalyzerStarted];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  [crashReporter purgePendingCrashReport];
  return;
}

- (BOOL)hasNonApprovedCrashReports {
  NSDictionary *approvedCrashReports = [[NSUserDefaults standardUserDefaults] dictionaryForKey: kBITCrashApprovedReports];
  
  if (!approvedCrashReports || [approvedCrashReports count] == 0) return YES;
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    NSString *filename = [_crashFiles objectAtIndex:i];
    
    if (![approvedCrashReports objectForKey:filename]) return YES;
  }
  
  return NO;
}

- (BOOL)hasPendingCrashReport {
  if (_crashManagerStatus != BITCrashManagerStatusDisabled) {
    if ([_crashFiles count] == 0 && [self.fileManager fileExistsAtPath:_crashesDir]) {
      NSString *file = nil;
      NSError *error = NULL;
      
      NSDirectoryEnumerator *dirEnum = [self.fileManager enumeratorAtPath: _crashesDir];
			
      while ((file = [dirEnum nextObject])) {
        NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:[_crashesDir stringByAppendingPathComponent:file] error:&error];
        if ([[fileAttributes objectForKey:NSFileSize] intValue] > 0) {
          [_crashFiles addObject:file];
        }
      }
    }
    
    if ([_crashFiles count] > 0) {
      BITHockeyLog(@"Pending crash reports found.");
      return YES;
    } else
      return NO;
  } else
    return NO;
}


- (void) showCrashStatusMessage {
  UIAlertView *alertView = nil;
	
  if (_serverResult >= BITCrashStatusAssigned && 
    _crashIdenticalCurrentVersion &&
    BITHockeyBundle()) {
    // show some feedback to the user about the crash status
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    switch (_serverResult) {
      case BITCrashStatusAssigned:
        alertView = [[UIAlertView alloc] initWithTitle: [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashResponseTitle"), appName ]
                                               message: [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashResponseNextRelease"), appName]
                                              delegate: self
                                     cancelButtonTitle: BITHockeyLocalizedString(@"HockeyOK")
                                     otherButtonTitles: nil];
        break;
      case BITCrashStatusSubmitted:
        alertView = [[UIAlertView alloc] initWithTitle: [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashResponseTitle"), appName ]
                                               message: [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashResponseWaitingApple"), appName]
                                              delegate: self
                                     cancelButtonTitle: BITHockeyLocalizedString(@"HockeyOK")
                                     otherButtonTitles: nil];
        break;
      case BITCrashStatusAvailable:
        alertView = [[UIAlertView alloc] initWithTitle: [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashResponseTitle"), appName ]
                                               message: [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashResponseAvailable"), appName]
                                              delegate: self
                                     cancelButtonTitle: BITHockeyLocalizedString(@"HockeyOK")
                                     otherButtonTitles: nil];
        break;
      default:
        alertView = nil;
        break;
    }
		
    if (alertView) {
      [alertView setTag: BITCrashAlertTypeFeedback];
      [alertView show];
      [alertView release];
    }
  }
}


#pragma mark -
#pragma mark UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
  if ([alertView tag] == BITCrashAlertTypeSend) {
    switch (buttonIndex) {
      case 0:
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillCancelSendingCrashReport:)]) {
          [self.delegate crashManagerWillCancelSendingCrashReport:self];
        }
        
        _sendingInProgress = NO;
        [self cleanCrashReports];
        break;
      case 1:
        [self sendCrashReports];
        break;
      case 2: {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBITCrashAutomaticallySendReports];
        [[NSUserDefaults standardUserDefaults] synchronize];
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillSendCrashReportsAlways:)]) {
          [self.delegate crashManagerWillSendCrashReportsAlways:self];
        }
        
        [self sendCrashReports];
        break;
      }
      default:
        _sendingInProgress = NO;
        [self cleanCrashReports];
        break;
    }
  }
}


#pragma mark - Private


- (NSString *) extractAppUUIDs:(PLCrashReport *)report {  
  NSMutableString *uuidString = [NSMutableString string];
  NSArray *uuidArray = [BITCrashReportTextFormatter arrayOfAppUUIDsForCrashReport:report];
  
  for (NSDictionary *element in uuidArray) {
    if ([element objectForKey:kBITBinaryImageKeyUUID] && [element objectForKey:kBITBinaryImageKeyArch] && [element objectForKey:kBITBinaryImageKeyUUID]) {
      [uuidString appendFormat:@"<uuid type=\"%@\" arch=\"%@\">%@</uuid>",
       [element objectForKey:kBITBinaryImageKeyType],
       [element objectForKey:kBITBinaryImageKeyArch],
       [element objectForKey:kBITBinaryImageKeyUUID]
       ];
    }
  }
  
  return uuidString;
}


- (NSString *)getDevicePlatform {
  size_t size = 0;
  sysctlbyname("hw.machine", NULL, &size, NULL, 0);
  char *answer = (char*)malloc(size);
  sysctlbyname("hw.machine", answer, &size, NULL, 0);
  NSString *platform = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
  free(answer);
  return platform;
}


- (void)performSendingCrashReports {
  NSMutableDictionary *approvedCrashReports = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey: kBITCrashApprovedReports]];
  
  NSError *error = NULL;
	
  NSString *username = @"";
  NSString *useremail = @"";
  NSString *applicationLog = @"";
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(userNameForCrashManager:)]) {
    username = [self.delegate userNameForCrashManager:self] ?: @"";
  }
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(userEmailForCrashManager:)]) {
    useremail = [self.delegate userEmailForCrashManager:self] ?: @"";
  }

  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(applicationLogForCrashManager:)]) {
    applicationLog = [self.delegate applicationLogForCrashManager:self] ?: @"";
  }
	
  NSMutableString *crashes = nil;
  _crashIdenticalCurrentVersion = NO;
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    NSString *filename = [_crashesDir stringByAppendingPathComponent:[_crashFiles objectAtIndex:i]];
    NSData *crashData = [NSData dataWithContentsOfFile:filename];
		
    if ([crashData length] > 0) {
      PLCrashReport *report = [[[PLCrashReport alloc] initWithData:crashData error:&error] autorelease];
			
      if (report == nil) {
        NSLog(@"Could not parse crash report");
        // we cannot do anything with this report, so delete it
        [self.fileManager removeItemAtPath:filename error:&error];
        continue;
      }
      
      NSString *crashUUID = report.reportInfo.reportGUID ?: @"";
      NSString *crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report];
      
      if ([report.applicationInfo.applicationVersion compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
        _crashIdenticalCurrentVersion = YES;
      }
			
      if (crashes == nil) {
        crashes = [NSMutableString string];
      }
      
      [crashes appendFormat:@"<crash><applicationname>%s</applicationname><uuids>%@</uuids><bundleidentifier>%@</bundleidentifier><systemversion>%@</systemversion><platform>%@</platform><senderversion>%@</senderversion><version>%@</version><uuid>%@</uuid><log><![CDATA[%@]]></log><userid>%@</userid><contact>%@</contact><description><![CDATA[%@]]></description></crash>",
       [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"] UTF8String],
       [self extractAppUUIDs:report],
       report.applicationInfo.applicationIdentifier,
       report.systemInfo.operatingSystemVersion,
       [self getDevicePlatform],
       [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
       report.applicationInfo.applicationVersion,
       crashUUID,
       [crashLogString stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,crashLogString.length)],
       username,
       useremail,
       [applicationLog stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,applicationLog.length)]];
      
      
      // store this crash report as user approved, so if it fails it will retry automatically
      [approvedCrashReports setObject:[NSNumber numberWithBool:YES] forKey:[_crashFiles objectAtIndex:i]];
    } else {
      // we cannot do anything with this report, so delete it
      [self.fileManager removeItemAtPath:filename error:&error];
    }
  }
	
  [[NSUserDefaults standardUserDefaults] setObject:approvedCrashReports forKey:kBITCrashApprovedReports];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  if (crashes != nil) {
    BITHockeyLog(@"Sending crash reports:\n%@", crashes);
    [self postXML:[NSString stringWithFormat:@"<crashes>%@</crashes>", crashes]
             toURL:[NSURL URLWithString:BITHOCKEYSDK_URL]];
    
  }
}

- (void)cleanCrashReports {
  NSError *error = NULL;
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {		
    [self.fileManager removeItemAtPath:[_crashesDir stringByAppendingPathComponent:[_crashFiles objectAtIndex:i]] error:&error];
  }
  [_crashFiles removeAllObjects];
  
  [[NSUserDefaults standardUserDefaults] setObject:nil forKey:kBITCrashApprovedReports];
  [[NSUserDefaults standardUserDefaults] synchronize];    
}

- (void)sendCrashReports {
  // send it to the next runloop
  [self performSelector:@selector(performSendingCrashReports) withObject:nil afterDelay:0.0f];
}

- (void)checkForFeedbackStatus {
  NSMutableURLRequest *request = nil;
  
  request = [NSMutableURLRequest requestWithURL:
    [NSURL URLWithString:[NSString stringWithFormat:@"%@api/2/apps/%@/crashes/%@",
                          BITHOCKEYSDK_URL,
                          [_appIdentifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                          _feedbackRequestID
                          ]
     ]];
  
  [request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
  [request setValue:@"Quincy/iOS" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  [request setTimeoutInterval: 15];
  [request setHTTPMethod:@"GET"];
  
  _serverResult = BITCrashStatusUnknown;
  _statusCode = 200;
	
  // Release when done in the delegate method
  _responseData = [[NSMutableData alloc] init];
	
  _urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];    
  
  if (!_urlConnection) {
    BITHockeyLog(@"Requesting feedback status could not start!");
  } else {
    BITHockeyLog(@"Requesting feedback status.");
  }
}

- (void)postXML:(NSString*)xml toURL:(NSURL*)url {
  NSMutableURLRequest *request = nil;
  NSString *boundary = @"----FOO";
  
  NSString *feedbackEnabled = @"&feedbackEnabled=no";
  
  if ([self isFeedbackActivated]) {
    feedbackEnabled = @"&feedbackEnabled=yes";
  }
  
  request = [NSMutableURLRequest requestWithURL:
             [NSURL URLWithString:[NSString stringWithFormat:@"%@api/2/apps/%@/crashes?sdk=%@&sdk_version=%@%@",
                                   BITHOCKEYSDK_URL,
                                   [_appIdentifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                                   BITHOCKEYSDK_NAME,
                                   BITHOCKEYSDK_VERSION,
                                   feedbackEnabled
                                   ]
              ]];
  
  [request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
  [request setValue:@"Quincy/iOS" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  [request setTimeoutInterval: 15];
  [request setHTTPMethod:@"POST"];
  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
  [request setValue:contentType forHTTPHeaderField:@"Content-type"];
	
  NSMutableData *postBody =  [NSMutableData data];
  [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[@"Content-Disposition: form-data; name=\"xml\"; filename=\"crash.xml\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"Content-Type: text/xml\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  
  [request setHTTPBody:postBody];
	
  _serverResult = BITCrashStatusUnknown;
  _statusCode = 200;
	
  //Release when done in the delegate method
  _responseData = [[NSMutableData alloc] init];
	
  _urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
  
  if (!_urlConnection) {
    BITHockeyLog(@"Sending crash reports could not start!");
    _sendingInProgress = NO;
  } else {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillSendCrashReport:)]) {
      [self.delegate crashManagerWillSendCrashReport:self];
    }
    
    BITHockeyLog(@"Sending crash reports started.");
  }
}

#pragma mark - NSURLConnection Delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
    _statusCode = [(NSHTTPURLResponse *)response statusCode];
  }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  [_responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManager:didFailWithError:)]) {
    [self.delegate crashManager:self didFailWithError:error];
  }
  
  BITHockeyLog(@"ERROR: %@", [error localizedDescription]);
  
  _sendingInProgress = NO;
	
  [_responseData release];
  _responseData = nil;	
  [_urlConnection release];
  _urlConnection = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  NSError *error = nil;
  
  if (_statusCode >= 200 && _statusCode < 400 && _responseData != nil && [_responseData length] > 0) {
    [self cleanCrashReports];
    
    _feedbackRequestID = nil;
    // HockeyApp uses PList XML format
    NSMutableDictionary *response = [NSPropertyListSerialization propertyListFromData:_responseData
                                                                     mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                                               format:nil
                                                                     errorDescription:NULL];
    BITHockeyLog(@"Received API response: %@", response);
    
    _serverResult = (BITCrashStatus)[[response objectForKey:@"status"] intValue];
    if ([response objectForKey:@"id"]) {
      _feedbackRequestID = [[NSString alloc] initWithString:[response objectForKey:@"id"]];
      _feedbackDelayInterval = [[response objectForKey:@"delay"] floatValue];
      if (_feedbackDelayInterval > 0)
        _feedbackDelayInterval *= 0.01;
    }
    
    if ([self isFeedbackActivated]) {
      // only proceed if the server did not report any problem
      if (_serverResult == BITCrashStatusQueued) {
        // the report is still in the queue
        if (_feedbackRequestID) {
          [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkForFeedbackStatus) object:nil];
          [self performSelector:@selector(checkForFeedbackStatus) withObject:nil afterDelay:_feedbackDelayInterval];
        }
      } else {
        [self showCrashStatusMessage];
      }
      
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerDidFinishSendingCrashReport:)]) {
        [self.delegate crashManagerDidFinishSendingCrashReport:self];
      }
    }
  } else if (_statusCode == 400) {
    [self cleanCrashReports];
    
    error = [NSError errorWithDomain:kBITCrashErrorDomain
                                code:BITCrashAPIAppVersionRejected
                            userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The server rejected receiving crash reports for this app version!", NSLocalizedDescriptionKey, nil]];
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManager:didFailWithError:)]) {
      [self.delegate crashManager:self didFailWithError:error];
    }
    
    BITHockeyLog(@"ERROR: %@", [error localizedDescription]);
  } else {
    if (_responseData == nil || [_responseData length] == 0) {
      error = [NSError errorWithDomain:kBITCrashErrorDomain
                                  code:BITCrashAPIReceivedEmptyResponse
                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Sending failed with an empty response!", NSLocalizedDescriptionKey, nil]];
    } else {
      error = [NSError errorWithDomain:kBITCrashErrorDomain
                                  code:BITCrashAPIErrorWithStatusCode
                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Sending failed with status code: %i", _statusCode], NSLocalizedDescriptionKey, nil]];
    }

    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManager:didFailWithError:)]) {
      [self.delegate crashManager:self didFailWithError:error];
    }

    BITHockeyLog(@"ERROR: %@", [error localizedDescription]);
  }
  
  _sendingInProgress = NO;
	
  [_responseData release];
  _responseData = nil;	
  [_urlConnection release];
  _urlConnection = nil;
}


@end
