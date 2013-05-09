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

#import <CrashReporter/CrashReporter.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIKit.h>
#import "HockeySDK.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"

#import "BITHockeyManagerPrivate.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITCrashManagerPrivate.h"
#import "BITCrashReportTextFormatter.h"

#include <sys/sysctl.h>

// stores the set of crashreports that have been approved but aren't sent yet
#define kBITCrashApprovedReports @"HockeySDKCrashApprovedReports"

// keys for meta information associated to each crash
#define kBITCrashMetaUserName @"BITCrashMetaUserName"
#define kBITCrashMetaUserEmail @"BITCrashMetaUserEmail"
#define kBITCrashMetaUserID @"BITCrashMetaUserID"
#define kBITCrashMetaApplicationLog @"BITCrashMetaApplicationLog"

NSString *const kBITCrashManagerStatus = @"BITCrashManagerStatus";


@interface BITCrashManager ()

@property (nonatomic, strong) NSFileManager *fileManager;

@end

@implementation BITCrashManager {
  NSMutableDictionary *_approvedCrashReports;
  
  NSMutableArray *_crashFiles;
  NSString       *_crashesDir;
  NSString       *_settingsFile;
  NSString       *_analyzerInProgressFile;
  NSFileManager  *_fileManager;
  
  BOOL _crashIdenticalCurrentVersion;
  
  NSMutableData *_responseData;
  NSInteger _statusCode;
  
  NSURLConnection *_urlConnection;
  
  BOOL _sendingInProgress;
  BOOL _isSetup;
  
  NSUncaughtExceptionHandler *_exceptionHandler;
}


- (id)init {
  if ((self = [super init])) {
    _delegate = nil;
    _showAlwaysButton = NO;
    _isSetup = NO;
    
    _exceptionHandler = nil;
    
    _crashIdenticalCurrentVersion = YES;
    _urlConnection = nil;
    _responseData = nil;
    _sendingInProgress = NO;
    
    _didCrashInLastSession = NO;
    _timeintervalCrashInLastSessionOccured = -1;
    
    _approvedCrashReports = [[NSMutableDictionary alloc] init];

    _fileManager = [[NSFileManager alloc] init];
    _crashFiles = [[NSMutableArray alloc] init];
    
    _crashManagerStatus = BITCrashManagerStatusAlwaysAsk;
    
    NSString *testValue = [[NSUserDefaults standardUserDefaults] stringForKey:kBITCrashManagerStatus];
    if (testValue) {
      _crashManagerStatus = (BITCrashManagerStatus) [[NSUserDefaults standardUserDefaults] integerForKey:kBITCrashManagerStatus];
    } else {
      // migrate previous setting if available
      if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BITCrashAutomaticallySendReports"]) {
        _crashManagerStatus = BITCrashManagerStatusAutoSend;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BITCrashAutomaticallySendReports"];
      }
      [[NSUserDefaults standardUserDefaults] setInteger:_crashManagerStatus forKey:kBITCrashManagerStatus];
    }
    
    // temporary directory for crashes grabbed from PLCrashReporter
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    _crashesDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:BITHOCKEY_IDENTIFIER];
    
    if (![self.fileManager fileExistsAtPath:_crashesDir]) {
      NSDictionary *attributes = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedLong: 0755] forKey: NSFilePosixPermissions];
      NSError *theError = NULL;
      
      [self.fileManager createDirectoryAtPath:_crashesDir withIntermediateDirectories: YES attributes: attributes error: &theError];
    }
    
    _settingsFile = [_crashesDir stringByAppendingPathComponent:BITHOCKEY_CRASH_SETTINGS];
    _analyzerInProgressFile = [_crashesDir stringByAppendingPathComponent:BITHOCKEY_CRASH_ANALYZER];

    if ([_fileManager fileExistsAtPath:_analyzerInProgressFile]) {
      NSError *error = nil;
      [_fileManager removeItemAtPath:_analyzerInProgressFile error:&error];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(invokeDelayedProcessing) name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
    
    if (!BITHockeyBundle()) {
      NSLog(@"[HockeySDK] WARNING: %@ is missing, will send reports automatically!", BITHOCKEYSDK_BUNDLE);
    }
  }
  return self;
}


- (void) dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
  
  [_urlConnection cancel];
}


- (void)setCrashManagerStatus:(BITCrashManagerStatus)crashManagerStatus {
  _crashManagerStatus = crashManagerStatus;
  
  [[NSUserDefaults standardUserDefaults] setInteger:crashManagerStatus forKey:kBITCrashManagerStatus];
}


#pragma mark - Private

- (void)saveSettings {
  NSString *errorString = nil;
  
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity:2];
  if (_approvedCrashReports && [_approvedCrashReports count] > 0)
    [rootObj setObject:_approvedCrashReports forKey:kBITCrashApprovedReports];
  
  NSData *plist = [NSPropertyListSerialization dataFromPropertyList:(id)rootObj
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                   errorDescription:&errorString];
  if (plist) {
    [plist writeToFile:_settingsFile atomically:YES];
  } else {
    BITHockeyLog(@"ERROR: Writing settings. %@", errorString);
  }
}

- (void)loadSettings {
  NSString *errorString = nil;
  NSPropertyListFormat format;
  
  if (![_fileManager fileExistsAtPath:_settingsFile])
    return;
  
  NSData *plist = [NSData dataWithContentsOfFile:_settingsFile];
  if (plist) {
    NSDictionary *rootObj = (NSDictionary *)[NSPropertyListSerialization
                                             propertyListFromData:plist
                                             mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                             format:&format
                                             errorDescription:&errorString];
    
    if ([rootObj objectForKey:kBITCrashApprovedReports])
      [_approvedCrashReports setDictionary:[rootObj objectForKey:kBITCrashApprovedReports]];
  } else {
    BITHockeyLog(@"ERROR: Reading crash manager settings.");
  }
}

- (void)cleanCrashReports {
  NSError *error = NULL;
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    [_fileManager removeItemAtPath:[_crashFiles objectAtIndex:i] error:&error];
    [_fileManager removeItemAtPath:[[_crashFiles objectAtIndex:i] stringByAppendingString:@".meta"] error:&error];
    [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", [_crashFiles objectAtIndex:i], kBITCrashMetaUserName]];
    [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", [_crashFiles objectAtIndex:i], kBITCrashMetaUserEmail]];
    [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", [_crashFiles objectAtIndex:i], kBITCrashMetaUserID]];
  }
  [_crashFiles removeAllObjects];
  [_approvedCrashReports removeAllObjects];
  
  [self saveSettings];
}

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

- (NSString *)userIDForCrashReport {
  NSString *userID = @"";
  
  if ([BITHockeyManager sharedHockeyManager].delegate &&
      [[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(userIDForHockeyManager:componentManager:)]) {
    userID = [[BITHockeyManager sharedHockeyManager].delegate
                userIDForHockeyManager:[BITHockeyManager sharedHockeyManager]
                componentManager:self] ?: @"";
  }
  
  return userID;
}

- (NSString *)userNameForCrashReport {
  NSString *username = @"";
  
  if (self.delegate && [self.delegate respondsToSelector:@selector(userNameForCrashManager:)]) {
    if (!self.isAppStoreEnvironment)
      NSLog(@"[HockeySDK] DEPRECATED: Please use BITHockeyManagerDelegate's userNameForHockeyManager:componentManager: or userIDForHockeyManager:componentManager: instead.");
    username = [self.delegate userNameForCrashManager:self] ?: @"";
  }
  if ([BITHockeyManager sharedHockeyManager].delegate &&
      [[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(userNameForHockeyManager:componentManager:)]) {
    username = [[BITHockeyManager sharedHockeyManager].delegate
                userNameForHockeyManager:[BITHockeyManager sharedHockeyManager]
                componentManager:self] ?: @"";
  }
  
  return username;
}

- (NSString *)userEmailForCrashReport {
  NSString *useremail = @"";

  if (self.delegate && [self.delegate respondsToSelector:@selector(userEmailForCrashManager:)]) {
    if (!self.isAppStoreEnvironment)
      NSLog(@"[HockeySDK] DEPRECATED: Please use BITHockeyManagerDelegate's userEmailForHockeyManager:componentManager: instead.");
    useremail = [self.delegate userEmailForCrashManager:self] ?: @"";
  }
  if ([BITHockeyManager sharedHockeyManager].delegate &&
      [[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(userEmailForHockeyManager:componentManager:)]) {
    useremail = [[BITHockeyManager sharedHockeyManager].delegate
                 userEmailForHockeyManager:[BITHockeyManager sharedHockeyManager]
                 componentManager:self] ?: @"";
  }
  
  return useremail;
}

#pragma mark - PLCrashReporter

// Called to handle a pending crash report.
- (void) handleCrashReport {
  PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
  NSError *error = NULL;
	
  [self loadSettings];
  
  // check if the next call ran successfully the last time
  if (![_fileManager fileExistsAtPath:_analyzerInProgressFile]) {
    // mark the start of the routine
    [_fileManager createFileAtPath:_analyzerInProgressFile contents:nil attributes:nil];
    
    [self saveSettings];
    
    // Try loading the crash report
    NSData *crashData = [[NSData alloc] initWithData:[crashReporter loadPendingCrashReportDataAndReturnError: &error]];
    
    NSString *cacheFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
    
    if (crashData == nil) {
      BITHockeyLog(@"ERROR: Could not load crash report: %@", error);
    } else {
      // get the startup timestamp from the crash report, and the file timestamp to calculate the timeinterval when the crash happened after startup
      PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
      
      if ([report.applicationInfo respondsToSelector:@selector(applicationStartupTimestamp)]) {
        if (report.systemInfo.timestamp && report.applicationInfo.applicationStartupTimestamp) {
          _timeintervalCrashInLastSessionOccured = [report.systemInfo.timestamp timeIntervalSinceDate:report.applicationInfo.applicationStartupTimestamp];
        }
      }

      [crashData writeToFile:[_crashesDir stringByAppendingPathComponent: cacheFilename] atomically:YES];
      
      // write the meta file
      NSMutableDictionary *metaDict = [NSMutableDictionary dictionaryWithCapacity:4];
      NSString *applicationLog = @"";
      NSString *errorString = nil;
      
      [self addStringValueToKeychain:[self userNameForCrashReport] forKey:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserName]];
      [self addStringValueToKeychain:[self userEmailForCrashReport] forKey:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserEmail]];
      [self addStringValueToKeychain:[self userIDForCrashReport] forKey:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserID]];
      
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(applicationLogForCrashManager:)]) {
        applicationLog = [self.delegate applicationLogForCrashManager:self] ?: @"";
      }
      [metaDict setObject:applicationLog forKey:kBITCrashMetaApplicationLog];
      
      NSData *plist = [NSPropertyListSerialization dataFromPropertyList:(id)metaDict
                                                                 format:NSPropertyListBinaryFormat_v1_0
                                                       errorDescription:&errorString];
      if (plist) {
        [plist writeToFile:[NSString stringWithFormat:@"%@.meta", [_crashesDir stringByAppendingPathComponent: cacheFilename]] atomically:YES];
      } else {
        BITHockeyLog(@"ERROR: Writing crash meta data failed. %@", error);
      }
    }
  }
	
  // Purge the report
  // mark the end of the routine
  if ([_fileManager fileExistsAtPath:_analyzerInProgressFile]) {
    [_fileManager removeItemAtPath:_analyzerInProgressFile error:&error];
  }

  [self saveSettings];
  
  [crashReporter purgePendingCrashReport];
}

- (BOOL)hasNonApprovedCrashReports {
  if (!_approvedCrashReports || [_approvedCrashReports count] == 0) return YES;
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    NSString *filename = [_crashFiles objectAtIndex:i];
    
    if (![_approvedCrashReports objectForKey:filename]) return YES;
  }
  
  return NO;
}

- (BOOL)hasPendingCrashReport {
  if (_crashManagerStatus == BITCrashManagerStatusDisabled) return NO;
    
  if ([self.fileManager fileExistsAtPath:_crashesDir]) {
    NSString *file = nil;
    NSError *error = NULL;
    
    NSDirectoryEnumerator *dirEnum = [self.fileManager enumeratorAtPath: _crashesDir];
    
    while ((file = [dirEnum nextObject])) {
      NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:[_crashesDir stringByAppendingPathComponent:file] error:&error];
      if ([[fileAttributes objectForKey:NSFileSize] intValue] > 0 &&
          ![file hasSuffix:@".analyzer"] &&
          ![file hasSuffix:@".plist"] &&
          ![file hasSuffix:@".meta"]) {
        [_crashFiles addObject:[_crashesDir stringByAppendingPathComponent: file]];
      }
    }
  }
  
  if ([_crashFiles count] > 0) {
    BITHockeyLog(@"INFO: %i pending crash reports found.", [_crashFiles count]);
    return YES;
  } else {
    if (_didCrashInLastSession) {
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillCancelSendingCrashReport:)]) {
        [self.delegate crashManagerWillCancelSendingCrashReport:self];
      }

      _didCrashInLastSession = NO;
    }
    
    return NO;
  }
}


#pragma mark - Crash Report Processing

// slightly delayed startup processing, so we don't keep the first runloop on startup busy for too long
- (void)invokeDelayedProcessing {
  BITHockeyLog(@"INFO: Start delayed CrashManager processing");
  
  // was our own exception handler successfully added?
  if (_exceptionHandler) {
    // get the current top level error handler
    NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
  
    // If the top level error handler differs from our own, then at least another one was added.
    // This could cause exception crashes not to be reported to HockeyApp. See log message for details.
    if (_exceptionHandler != currentHandler) {
      BITHockeyLog(@"[HockeySDK] WARNING: Another exception handler was added. If this invokes any kind exit() after processing the exception, which causes any subsequent error handler not to be invoked, these crashes will NOT be reported to HockeyApp!");
    }
  }
  
  if (!_sendingInProgress && [self hasPendingCrashReport]) {
    _sendingInProgress = YES;
    if (!BITHockeyBundle()) {
      [self sendCrashReports];
    } else if (_crashManagerStatus != BITCrashManagerStatusAutoSend && [self hasNonApprovedCrashReports]) {
      
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillShowSubmitCrashReportAlert:)]) {
        [self.delegate crashManagerWillShowSubmitCrashReportAlert:self];
      }
      
      NSString *appName = bit_appName(BITHockeyLocalizedString(@"HockeyAppNamePlaceholder"));
      NSString *alertDescription = [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundAnonymousDescription"), appName];
      
      // the crash report is not anynomous any more if username or useremail are not nil
      NSString *userid = [self userIDForCrashReport];
      NSString *username = [self userNameForCrashReport];
      NSString *useremail = [self userEmailForCrashReport];
            
      if ((userid && [userid length] > 0) ||
          (username && [username length] > 0) ||
          (useremail && [useremail length] > 0)) {
        alertDescription = [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundDescription"), appName];
      }
      
      UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundTitle"), appName]
                                                          message:alertDescription
                                                         delegate:self
                                                cancelButtonTitle:BITHockeyLocalizedString(@"CrashDontSendReport")
                                                otherButtonTitles:BITHockeyLocalizedString(@"CrashSendReport"), nil];
      
      if (self.shouldShowAlwaysButton) {
        [alertView addButtonWithTitle:BITHockeyLocalizedString(@"CrashSendReportAlways")];
      }
      
      [alertView show];
    } else {
      [self sendCrashReports];
    }
  }
}

// begin the startup process
- (void)startManager {
  if (_crashManagerStatus == BITCrashManagerStatusDisabled) return;
  
  if (!_isSetup) {
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    NSError *error = NULL;
    
    // Make sure the correct version of PLCrashReporter is linked
    id plCrashReportReportInfoClass = NSClassFromString(@"PLCrashReportReportInfo");
    
    if (!plCrashReportReportInfoClass) {
      NSLog(@"[HockeySDK] ERROR: An old version of PLCrashReporter framework is linked! Please check the framework search path in the target build settings and remove references to folders that contain an older version of CrashReporter.framework and also delete these files.");
    }
    
    // Check if we previously crashed
    if ([crashReporter hasPendingCrashReport]) {
      _didCrashInLastSession = YES;
      [self handleCrashReport];
    }

    // PLCrashReporter is throwing an NSException if it is being enabled again
    // even though it already is enabled
    @try {
      // Multiple exception handlers can be set, but we can only query the top level error handler (uncaught exception handler).
      //
      // To check if PLCrashReporter's error handler is successfully added, we compare the top
      // level one that is set before and the one after PLCrashReporter sets up its own.
      //
      // With delayed processing we can then check if another error handler was set up afterwards
      // and can show a debug warning log message, that the dev has to make sure the "newer" error handler
      // doesn't exit the process itself, because then all subsequent handlers would never be invoked.
      // 
      // Note: ANY error handler setup BEFORE HockeySDK initialization will not be processed!
      
      // get the current top level error handler
      NSUncaughtExceptionHandler *initialHandler = NSGetUncaughtExceptionHandler();
      
      // Enable the Crash Reporter
      if (![crashReporter enableCrashReporterAndReturnError: &error])
        NSLog(@"[HockeySDK] WARNING: Could not enable crash reporter: %@", [error localizedDescription]);

      // get the new current top level error handler, which should now be the one from PLCrashReporter
      NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
      
      // do we have a new top level error handler? then we were successful
      if (currentHandler && currentHandler != initialHandler) {
        _exceptionHandler = currentHandler;
        
        BITHockeyLog(@"INFO: Exception handler successfully initialized.");
      } else {
        // this should never happen, theoretically only if NSSetUncaugtExceptionHandler() has some internal issues
        NSLog(@"[HockeySDK] ERROR: Exception handler could not be set. Make sure there is no other exception handler set up!");
      }
    }
    @catch (NSException * e) {
      NSLog(@"[HockeySDK] WARNING: %@", [e reason]);
    }

    _isSetup = YES;
  }

  [self performSelector:@selector(invokeDelayedProcessing) withObject:nil afterDelay:0.5];
}

- (void)sendCrashReports {
  // send it to the next runloop
  [self performSelector:@selector(performSendingCrashReports) withObject:nil afterDelay:1.0f];
}

- (void)performSendingCrashReports {
  NSError *error = NULL;
	  
  NSMutableString *crashes = nil;
  _crashIdenticalCurrentVersion = NO;
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    NSString *filename = [_crashFiles objectAtIndex:i];
    NSData *crashData = [NSData dataWithContentsOfFile:filename];
		
    if ([crashData length] > 0) {
      PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
			
      if (report == nil) {
        BITHockeyLog(@"WARNING: Could not parse crash report");
        // we cannot do anything with this report, so delete it
        [_fileManager removeItemAtPath:filename error:&error];
        [_fileManager removeItemAtPath:[NSString stringWithFormat:@"%@.meta", filename] error:&error];

        [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserName]];
        [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserEmail]];
        [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserID]];
        continue;
      }
      
      NSString *crashUUID = @"";
      if ([report respondsToSelector:@selector(reportInfo)]) {
        crashUUID = report.reportInfo.reportGUID ?: @"";
      }
      NSString *installString = bit_appAnonID() ?: @"";
      NSString *crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:installString];
      
      if ([report.applicationInfo.applicationVersion compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
        _crashIdenticalCurrentVersion = YES;
      }
			
      if (crashes == nil) {
        crashes = [NSMutableString string];
      }
      
      NSString *username = @"";
      NSString *useremail = @"";
      NSString *userid = @"";
      NSString *applicationLog = @"";
      NSString *description = @"";
      
      NSString *errorString = nil;
      NSPropertyListFormat format;
      
      NSData *plist = [NSData dataWithContentsOfFile:[filename stringByAppendingString:@".meta"]];
      if (plist) {
        NSDictionary *metaDict = (NSDictionary *)[NSPropertyListSerialization
                                                  propertyListFromData:plist
                                                  mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                  format:&format
                                                  errorDescription:&errorString];
        
        username = [self stringValueFromKeychainForKey:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserName]] ?: @"";
        useremail = [self stringValueFromKeychainForKey:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserEmail]] ?: @"";
        userid = [self stringValueFromKeychainForKey:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserID]] ?: @"";
        applicationLog = [metaDict objectForKey:kBITCrashMetaApplicationLog] ?: @"";
      } else {
        BITHockeyLog(@"ERROR: Reading crash meta data. %@", error);
      }
      
      if ([applicationLog length] > 0) {
        description = [NSString stringWithFormat:@"%@", applicationLog];
      }
      
      [crashes appendFormat:@"<crash><applicationname>%s</applicationname><uuids>%@</uuids><bundleidentifier>%@</bundleidentifier><systemversion>%@</systemversion><platform>%@</platform><senderversion>%@</senderversion><version>%@</version><uuid>%@</uuid><log><![CDATA[%@]]></log><userid>%@</userid><username>%@</username><contact>%@</contact><installstring>%@</installstring><description><![CDATA[%@]]></description></crash>",
       [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"] UTF8String],
       [self extractAppUUIDs:report],
       report.applicationInfo.applicationIdentifier,
       report.systemInfo.operatingSystemVersion,
       [self getDevicePlatform],
       [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
       report.applicationInfo.applicationVersion,
       crashUUID,
       [crashLogString stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,crashLogString.length)],
       userid,
       username,
       useremail,
       installString,
       [description stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,description.length)]];
      
      
      // store this crash report as user approved, so if it fails it will retry automatically
      [_approvedCrashReports setObject:[NSNumber numberWithBool:YES] forKey:filename];
    } else {
      // we cannot do anything with this report, so delete it
      [_fileManager removeItemAtPath:filename error:&error];
      [_fileManager removeItemAtPath:[NSString stringWithFormat:@"%@.meta", filename] error:&error];
      
      [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserName]];
      [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserEmail]];
      [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserID]];
    }
  }
	
  [self saveSettings];
  
  if (crashes != nil) {
    BITHockeyLog(@"INFO: Sending crash reports:\n%@", crashes);
    [self postXML:[NSString stringWithFormat:@"<crashes>%@</crashes>", crashes]];
  }
}


#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
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
      _crashManagerStatus = BITCrashManagerStatusAutoSend;
      [[NSUserDefaults standardUserDefaults] setInteger:_crashManagerStatus forKey:kBITCrashManagerStatus];
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


#pragma mark - Networking

- (void)postXML:(NSString*)xml {
  NSMutableURLRequest *request = nil;
  NSString *boundary = @"----FOO";
  
  request = [NSMutableURLRequest requestWithURL:
             [NSURL URLWithString:[NSString stringWithFormat:@"%@api/2/apps/%@/crashes?sdk=%@&sdk_version=%@&feedbackEnabled=no",
                                   self.serverURL,
                                   [self encodedAppIdentifier],
                                   BITHOCKEY_NAME,
                                   BITHOCKEY_VERSION
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
	
  _statusCode = 200;
	
  //Release when done in the delegate method
  _responseData = [[NSMutableData alloc] init];
	
  _urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
  
  if (!_urlConnection) {
    BITHockeyLog(@"INFO: Sending crash reports could not start!");
    _sendingInProgress = NO;
  } else {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillSendCrashReport:)]) {
      [self.delegate crashManagerWillSendCrashReport:self];
    }
    
    BITHockeyLog(@"INFO: Sending crash reports started.");
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
	
  _responseData = nil;	
  _urlConnection = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  NSError *error = nil;
  
  if (_statusCode >= 200 && _statusCode < 400 && _responseData != nil && [_responseData length] > 0) {
    [self cleanCrashReports];
    
    // HockeyApp uses PList XML format
    NSMutableDictionary *response = [NSPropertyListSerialization propertyListFromData:_responseData
                                                                     mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                                               format:nil
                                                                     errorDescription:NULL];
    BITHockeyLog(@"INFO: Received API response: %@", response);
            
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerDidFinishSendingCrashReport:)]) {
      [self.delegate crashManagerDidFinishSendingCrashReport:self];
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
	
  _responseData = nil;	
  _urlConnection = nil;
}


@end
