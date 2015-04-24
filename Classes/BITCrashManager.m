/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_CRASH_REPORTER

#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIKit.h>

#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"
#import "BITHockeyAppClient.h"

#import "BITCrashAttachment.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITCrashManagerPrivate.h"
#import "BITCrashReportTextFormatter.h"
#import "BITCrashDetailsPrivate.h"

#include <sys/sysctl.h>

// stores the set of crashreports that have been approved but aren't sent yet
#define kBITCrashApprovedReports @"HockeySDKCrashApprovedReports"

// keys for meta information associated to each crash
#define kBITCrashMetaUserName @"BITCrashMetaUserName"
#define kBITCrashMetaUserEmail @"BITCrashMetaUserEmail"
#define kBITCrashMetaUserID @"BITCrashMetaUserID"
#define kBITCrashMetaApplicationLog @"BITCrashMetaApplicationLog"
#define kBITCrashMetaAttachment @"BITCrashMetaAttachment"

// internal keys
NSString *const KBITAttachmentDictIndex = @"index";
NSString *const KBITAttachmentDictAttachment = @"attachment";

NSString *const kBITCrashManagerStatus = @"BITCrashManagerStatus";

NSString *const kBITAppWentIntoBackgroundSafely = @"BITAppWentIntoBackgroundSafely";
NSString *const kBITAppDidReceiveLowMemoryNotification = @"BITAppDidReceiveLowMemoryNotification";
NSString *const kBITAppVersion = @"BITAppVersion";
NSString *const kBITAppOSVersion = @"BITAppOSVersion";
NSString *const kBITAppOSBuild = @"BITAppOSBuild";
NSString *const kBITAppUUIDs = @"BITAppUUIDs";

NSString *const kBITFakeCrashUUID = @"BITFakeCrashUUID";
NSString *const kBITFakeCrashAppVersion = @"BITFakeCrashAppVersion";
NSString *const kBITFakeCrashAppBundleIdentifier = @"BITFakeCrashAppBundleIdentifier";
NSString *const kBITFakeCrashOSVersion = @"BITFakeCrashOSVersion";
NSString *const kBITFakeCrashDeviceModel = @"BITFakeCrashDeviceModel";
NSString *const kBITFakeCrashAppBinaryUUID = @"BITFakeCrashAppBinaryUUID";
NSString *const kBITFakeCrashReport = @"BITFakeCrashAppString";


static BITCrashManagerCallbacks bitCrashCallbacks = {
  .context = NULL,
  .handleSignal = NULL
};

// proxy implementation for PLCrashReporter to keep our interface stable while this can change
static void plcr_post_crash_callback (siginfo_t *info, ucontext_t *uap, void *context) {
  if (bitCrashCallbacks.handleSignal != NULL)
    bitCrashCallbacks.handleSignal(context);
}

static PLCrashReporterCallbacks plCrashCallbacks = {
  .version = 0,
  .context = NULL,
  .handleSignal = plcr_post_crash_callback
};


@implementation BITCrashManager {
  NSMutableDictionary *_approvedCrashReports;
  
  NSMutableArray *_crashFiles;
  NSString       *_lastCrashFilename;
  NSString       *_settingsFile;
  NSString       *_analyzerInProgressFile;
  NSFileManager  *_fileManager;
    
  PLCrashReporterCallbacks *_crashCallBacks;
  
  BOOL _crashIdenticalCurrentVersion;
  
  BOOL _sendingInProgress;
  BOOL _isSetup;
  
  BOOL _didLogLowMemoryWarning;
  
  id _appDidBecomeActiveObserver;
  id _appWillTerminateObserver;
  id _appDidEnterBackgroundObserver;
  id _appWillEnterForegroundObserver;
  id _appDidReceiveLowMemoryWarningObserver;
  id _networkDidBecomeReachableObserver;
}


- (instancetype)init {
  if ((self = [super init])) {
    _delegate = nil;
    _showAlwaysButton = YES;
    _isSetup = NO;
    
    _plCrashReporter = nil;
    _exceptionHandler = nil;
    _crashCallBacks = nil;
    
    _crashIdenticalCurrentVersion = YES;
    
    _didCrashInLastSession = NO;
    _timeIntervalCrashInLastSessionOccurred = -1;
    _didLogLowMemoryWarning = NO;
    
    _approvedCrashReports = [[NSMutableDictionary alloc] init];
    _alertViewHandler = nil;

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
    
    _crashesDir = bit_settingsDir();
    _settingsFile = [_crashesDir stringByAppendingPathComponent:BITHOCKEY_CRASH_SETTINGS];
    _analyzerInProgressFile = [_crashesDir stringByAppendingPathComponent:BITHOCKEY_CRASH_ANALYZER];

    if ([_fileManager fileExistsAtPath:_analyzerInProgressFile]) {
      NSError *error = nil;
      [_fileManager removeItemAtPath:_analyzerInProgressFile error:&error];
    }
    
    if (!BITHockeyBundle() && !bit_isRunningInAppExtension()) {
      NSLog(@"[HockeySDK] WARNING: %@ is missing, will send reports automatically!", BITHOCKEYSDK_BUNDLE);
    }
  }
  return self;
}


- (void) dealloc {
  [self unregisterObservers];
}


- (void)setCrashManagerStatus:(BITCrashManagerStatus)crashManagerStatus {
  _crashManagerStatus = crashManagerStatus;
  
  [[NSUserDefaults standardUserDefaults] setInteger:crashManagerStatus forKey:kBITCrashManagerStatus];
}


#pragma mark - Private

/**
 * Save all settings
 *
 * This saves the list of approved crash reports
 */
- (void)saveSettings {
  NSError *error = nil;
  
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity:2];
  if (_approvedCrashReports && [_approvedCrashReports count] > 0) {
    [rootObj setObject:_approvedCrashReports forKey:kBITCrashApprovedReports];
  }

  NSData *plist = [NSPropertyListSerialization dataWithPropertyList:(id)rootObj format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
  
  if (plist) {
    [plist writeToFile:_settingsFile atomically:YES];
  } else {
    BITHockeyLog(@"ERROR: Writing settings. %@", [error description]);
  }
}

/**
 * Load all settings
 *
 * This contains the list of approved crash reports
 */
- (void)loadSettings {
  NSError *error = nil;
  NSPropertyListFormat format;
  
  if (![_fileManager fileExistsAtPath:_settingsFile])
    return;
  
  NSData *plist = [NSData dataWithContentsOfFile:_settingsFile];
  if (plist) {
    NSDictionary *rootObj = (NSDictionary *)[NSPropertyListSerialization
                                             propertyListWithData:plist
                                             options:NSPropertyListMutableContainersAndLeaves
                                             format:&format
                                             error:&error];
    
    if ([rootObj objectForKey:kBITCrashApprovedReports])
      [_approvedCrashReports setDictionary:[rootObj objectForKey:kBITCrashApprovedReports]];
  } else {
    BITHockeyLog(@"ERROR: Reading crash manager settings.");
  }
}


/**
 * Remove a cached crash report
 *
 *  @param filename The base filename of the crash report
 */
- (void)cleanCrashReportWithFilename:(NSString *)filename {
  if (!filename) return;
  
  NSError *error = NULL;
  
  [_fileManager removeItemAtPath:filename error:&error];
  [_fileManager removeItemAtPath:[filename stringByAppendingString:@".data"] error:&error];
  [_fileManager removeItemAtPath:[filename stringByAppendingString:@".meta"] error:&error];
  [_fileManager removeItemAtPath:[filename stringByAppendingString:@".desc"] error:&error];
  
  NSString *cacheFilename = [filename lastPathComponent];
  [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserName]];
  [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserEmail]];
  [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserID]];
  
  [_crashFiles removeObject:filename];
  [_approvedCrashReports removeObjectForKey:filename];
  
  [self saveSettings];
}

/**
 *	 Remove all crash reports and stored meta data for each from the file system and keychain
 *
 * This is currently only used as a helper method for tests
 */
- (void)cleanCrashReports {
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    [self cleanCrashReportWithFilename:[_crashFiles objectAtIndex:i]];
  }
}

- (void)persistAttachment:(BITHockeyAttachment *)attachment withFilename:(NSString *)filename {
  NSString *attachmentFilename = [filename stringByAppendingString:@".data"];
  NSMutableData *data = [[NSMutableData alloc] init];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
  
  [archiver encodeObject:attachment forKey:kBITCrashMetaAttachment];
  
  [archiver finishEncoding];
  
  [data writeToFile:attachmentFilename atomically:YES];
}

- (void)persistUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData {
  if (!userProvidedMetaData) return;
  
  if (userProvidedMetaData.userDescription && [userProvidedMetaData.userDescription length] > 0) {
    NSError *error;
    [userProvidedMetaData.userDescription writeToFile:[NSString stringWithFormat:@"%@.desc", [_crashesDir stringByAppendingPathComponent: _lastCrashFilename]] atomically:YES encoding:NSUTF8StringEncoding error:&error];
  }
  
  if (userProvidedMetaData.userName && [userProvidedMetaData.userName length] > 0) {
    [self addStringValueToKeychain:userProvidedMetaData.userName forKey:[NSString stringWithFormat:@"%@.%@", _lastCrashFilename, kBITCrashMetaUserName]];

  }

  if (userProvidedMetaData.userEmail && [userProvidedMetaData.userEmail length] > 0) {
    [self addStringValueToKeychain:userProvidedMetaData.userEmail forKey:[NSString stringWithFormat:@"%@.%@", _lastCrashFilename, kBITCrashMetaUserEmail]];
  }

  if (userProvidedMetaData.userID && [userProvidedMetaData.userID length] > 0) {
    [self addStringValueToKeychain:userProvidedMetaData.userID forKey:[NSString stringWithFormat:@"%@.%@", _lastCrashFilename, kBITCrashMetaUserID]];
    
  }
}

/**
 *  Read the attachment data from the stored file
 *
 *  @param filename The crash report file path
 *
 *  @return an BITHockeyAttachment instance or nil
 */
- (BITHockeyAttachment *)attachmentForCrashReport:(NSString *)filename {
  NSString *attachmentFilename = [filename stringByAppendingString:@".data"];
  
  if (![_fileManager fileExistsAtPath:attachmentFilename])
    return nil;
  
    
  NSData *codedData = [[NSData alloc] initWithContentsOfFile:attachmentFilename];
  if (!codedData)
    return nil;
  
  NSKeyedUnarchiver *unarchiver = nil;
      
  @try {
    unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:codedData];
  }
  @catch (NSException *exception) {
    return nil;
  }
  
  if ([unarchiver containsValueForKey:kBITCrashMetaAttachment]) {
    BITHockeyAttachment *attachment = [unarchiver decodeObjectForKey:kBITCrashMetaAttachment];
    return attachment;
  }
  
  return nil;
}

/**
 *	 Extract all app specific UUIDs from the crash reports
 *
 * This allows us to send the UUIDs in the XML construct to the server, so the server does not need to parse the crash report for this data.
 * The app specific UUIDs help to identify which dSYMs are needed to symbolicate this crash report.
 *
 *	@param	report The crash report from PLCrashReporter
 *
 *	@return XML structure with the app specific UUIDs
 */
- (NSString *) extractAppUUIDs:(BITPLCrashReport *)report {
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

- (void) registerObservers {
  __weak typeof(self) weakSelf = self;
  
  if(nil == _appDidBecomeActiveObserver) {
    _appDidBecomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                                    object:nil
                                                                                     queue:NSOperationQueue.mainQueue
                                                                                usingBlock:^(NSNotification *note) {
                                                                                  typeof(self) strongSelf = weakSelf;
                                                                                  [strongSelf triggerDelayedProcessing];
                                                                                }];
  }
  
  if(nil == _networkDidBecomeReachableObserver) {
    _networkDidBecomeReachableObserver = [[NSNotificationCenter defaultCenter] addObserverForName:BITHockeyNetworkDidBecomeReachableNotification
                                                                                           object:nil
                                                                                            queue:NSOperationQueue.mainQueue
                                                                                       usingBlock:^(NSNotification *note) {
                                                                                         typeof(self) strongSelf = weakSelf;
                                                                                         [strongSelf triggerDelayedProcessing];
                                                                                       }];
  }
  
  if (nil ==  _appWillTerminateObserver) {
    _appWillTerminateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                                                  object:nil
                                                                                   queue:NSOperationQueue.mainQueue
                                                                              usingBlock:^(NSNotification *note) {
                                                                                typeof(self) strongSelf = weakSelf;
                                                                                [strongSelf leavingAppSafely];
                                                                              }];
  }
  
  if (nil ==  _appDidEnterBackgroundObserver) {
    _appDidEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                                                       object:nil
                                                                                        queue:NSOperationQueue.mainQueue
                                                                                   usingBlock:^(NSNotification *note) {
                                                                                     typeof(self) strongSelf = weakSelf;
                                                                                     [strongSelf leavingAppSafely];
                                                                                   }];
  }
  
  if (nil == _appWillEnterForegroundObserver) {
    _appWillEnterForegroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                                                        object:nil
                                                                                         queue:NSOperationQueue.mainQueue
                                                                                    usingBlock:^(NSNotification *note) {
                                                                                      typeof(self) strongSelf = weakSelf;
                                                                                      [strongSelf appEnteredForeground];
                                                                                    }];
  }

  if (nil == _appDidReceiveLowMemoryWarningObserver) {
    _appDidReceiveLowMemoryWarningObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                                                               object:nil
                                                                                                queue:NSOperationQueue.mainQueue
                                                                                           usingBlock:^(NSNotification *note) {
                                                                                             // we only need to log this once
                                                                                             if (!_didLogLowMemoryWarning) {
                                                                                               [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBITAppDidReceiveLowMemoryNotification];
                                                                                               [[NSUserDefaults standardUserDefaults] synchronize];
                                                                                               _didLogLowMemoryWarning = YES;
                                                                                             }
                                                                                           }];
  }
}

- (void) unregisterObservers {
  [self unregisterObserver:_appDidBecomeActiveObserver];
  [self unregisterObserver:_appWillTerminateObserver];
  [self unregisterObserver:_appDidEnterBackgroundObserver];
  [self unregisterObserver:_appWillEnterForegroundObserver];
  [self unregisterObserver:_appDidReceiveLowMemoryWarningObserver];
  
  [self unregisterObserver:_networkDidBecomeReachableObserver];
}

- (void) unregisterObserver:(id)observer {
  if (observer) {
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    observer = nil;
  }
}

- (void)leavingAppSafely {
  if (self.isAppNotTerminatingCleanlyDetectionEnabled)
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBITAppWentIntoBackgroundSafely];
}

- (void)appEnteredForeground {
  // we disable kill detection while the debugger is running, since we'd get only false positives if the app is terminated by the user using the debugger
  if (self.isDebuggerAttached) {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBITAppWentIntoBackgroundSafely];
  } else if (self.isAppNotTerminatingCleanlyDetectionEnabled) {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kBITAppWentIntoBackgroundSafely];
    
    static dispatch_once_t predAppData;
      
    dispatch_once(&predAppData, ^{
      id bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
      if (bundleVersion && [bundleVersion isKindOfClass:[NSString class]])
        [[NSUserDefaults standardUserDefaults] setObject:bundleVersion forKey:kBITAppVersion];
      [[NSUserDefaults standardUserDefaults] setObject:[[UIDevice currentDevice] systemVersion] forKey:kBITAppOSVersion];
      [[NSUserDefaults standardUserDefaults] setObject:[self osBuild] forKey:kBITAppOSBuild];
      
      NSString *uuidString =[NSString stringWithFormat:@"<uuid type=\"app\" arch=\"%@\">%@</uuid>",
                             [self deviceArchitecture],
                             [self executableUUID]
                             ];

      [[NSUserDefaults standardUserDefaults] setObject:uuidString forKey:kBITAppUUIDs];
    });
  }
}

- (NSString *)deviceArchitecture {
  NSString *archName = @"???";
  
  size_t size;
  cpu_type_t type;
  cpu_subtype_t subtype;
  size = sizeof(type);
  if (sysctlbyname("hw.cputype", &type, &size, NULL, 0))
    return archName;

  size = sizeof(subtype);
  if (sysctlbyname("hw.cpusubtype", &subtype, &size, NULL, 0))
    return archName;

  archName = [BITCrashReportTextFormatter bit_archNameFromCPUType:type subType:subtype] ?: @"???";
  
  return archName;
}

- (NSString *)osBuild {
  size_t size;
  sysctlbyname("kern.osversion", NULL, &size, NULL, 0);
  char *answer = (char*)malloc(size);
  if (answer == NULL)
    return nil;
  sysctlbyname("kern.osversion", answer, &size, NULL, 0);
  NSString *osBuild = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
  free(answer);
  return osBuild;
}

/**
 *	 Get the userID from the delegate which should be stored with the crash report
 *
 *	@return The userID value
 */
- (NSString *)userIDForCrashReport {
  // first check the global keychain storage
  NSString *userID = [self stringValueFromKeychainForKey:kBITHockeyMetaUserID] ?: @"";
  
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  // if we have an identification from BITAuthenticator, use this as a default.
  if ((
       self.installationIdentificationType == BITAuthenticatorIdentificationTypeAnonymous ||
       self.installationIdentificationType == BITAuthenticatorIdentificationTypeDevice
       ) &&
      self.installationIdentification) {
    userID = self.installationIdentification;
  }
#endif
  
  if ([BITHockeyManager sharedHockeyManager].delegate &&
      [[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(userIDForHockeyManager:componentManager:)]) {
    userID = [[BITHockeyManager sharedHockeyManager].delegate
                userIDForHockeyManager:[BITHockeyManager sharedHockeyManager]
                componentManager:self] ?: @"";
  }
  
  return userID;
}

/**
 *	 Get the userName from the delegate which should be stored with the crash report
 *
 *	@return The userName value
 */
- (NSString *)userNameForCrashReport {
  // first check the global keychain storage
  NSString *username = [self stringValueFromKeychainForKey:kBITHockeyMetaUserName] ?: @"";
  
  if (self.delegate && [self.delegate respondsToSelector:@selector(userNameForCrashManager:)]) {
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

/**
 *	 Get the userEmail from the delegate which should be stored with the crash report
 *
 *	@return The userEmail value
 */
- (NSString *)userEmailForCrashReport {
  // first check the global keychain storage
  NSString *useremail = [self stringValueFromKeychainForKey:kBITHockeyMetaUserEmail] ?: @"";
  
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  // if we have an identification from BITAuthenticator, use this as a default.
  if ((
       self.installationIdentificationType == BITAuthenticatorIdentificationTypeHockeyAppEmail ||
       self.installationIdentificationType == BITAuthenticatorIdentificationTypeHockeyAppUser ||
       self.installationIdentificationType == BITAuthenticatorIdentificationTypeWebAuth
       ) &&
      self.installationIdentification) {
    useremail = self.installationIdentification;
  }
#endif
  
  if (self.delegate && [self.delegate respondsToSelector:@selector(userEmailForCrashManager:)]) {
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


#pragma mark - Public


/**
 *  Set the callback for PLCrashReporter
 *
 *  @param callbacks BITCrashManagerCallbacks instance
 */
- (void)setCrashCallbacks: (BITCrashManagerCallbacks *) callbacks {
  if (!callbacks) return;
  
  // set our proxy callback struct
  bitCrashCallbacks.context = callbacks->context;
  bitCrashCallbacks.handleSignal = callbacks->handleSignal;
  
  // set the PLCrashReporterCallbacks struct
  plCrashCallbacks.context = callbacks->context;
  
  _crashCallBacks = &plCrashCallbacks;
}


- (void)setAlertViewHandler:(BITCustomAlertViewHandler)alertViewHandler{
  _alertViewHandler = alertViewHandler;
}

/**
 * Check if the debugger is attached
 *
 * Taken from https://github.com/plausiblelabs/plcrashreporter/blob/2dd862ce049e6f43feb355308dfc710f3af54c4d/Source/Crash%20Demo/main.m#L96
 *
 * @return `YES` if the debugger is attached to the current process, `NO` otherwise
 */
- (BOOL)isDebuggerAttached {
  static BOOL debuggerIsAttached = NO;
  
  static dispatch_once_t debuggerPredicate;
  dispatch_once(&debuggerPredicate, ^{
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    int name[4];
    
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
      NSLog(@"[HockeySDK] ERROR: Checking for a running debugger via sysctl() failed: %s", strerror(errno));
      debuggerIsAttached = false;
    }
    
    if (!debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0)
      debuggerIsAttached = true;
  });
  
  return debuggerIsAttached;
}


- (void)generateTestCrash {
  if (![self isAppStoreEnvironment]) {
    
    if ([self isDebuggerAttached]) {
      NSLog(@"[HockeySDK] WARNING: The debugger is attached. The following crash cannot be detected by the SDK!");
    }
    
    __builtin_trap();
  }
}

/**
 *  Write a meta file for a new crash report
 *
 *  @param filename the crash reports temp filename
 */
- (void)storeMetaDataForCrashReportFilename:(NSString *)filename {
  NSError *error = NULL;
  NSMutableDictionary *metaDict = [NSMutableDictionary dictionaryWithCapacity:4];
  NSString *applicationLog = @"";
  
  [self addStringValueToKeychain:[self userNameForCrashReport] forKey:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserName]];
  [self addStringValueToKeychain:[self userEmailForCrashReport] forKey:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserEmail]];
  [self addStringValueToKeychain:[self userIDForCrashReport] forKey:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserID]];
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(applicationLogForCrashManager:)]) {
    applicationLog = [self.delegate applicationLogForCrashManager:self] ?: @"";
  }
  [metaDict setObject:applicationLog forKey:kBITCrashMetaApplicationLog];
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(attachmentForCrashManager:)]) {
    BITHockeyAttachment *attachment = [self.delegate attachmentForCrashManager:self];
    
    if (attachment && attachment.hockeyAttachmentData) {
      [self persistAttachment:attachment withFilename:[_crashesDir stringByAppendingPathComponent: filename]];
    }
  }
  
  NSData *plist = [NSPropertyListSerialization dataWithPropertyList:(id)metaDict
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                            options:0
                                                              error:&error];
  if (plist) {
    [plist writeToFile:[_crashesDir stringByAppendingPathComponent: [filename stringByAppendingPathExtension:@"meta"]] atomically:YES];
  } else {
    BITHockeyLog(@"ERROR: Writing crash meta data failed. %@", error);
  }
}

- (BOOL)handleUserInput:(BITCrashManagerUserInput)userInput withUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData {
  switch (userInput) {
    case BITCrashManagerUserInputDontSend:
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillCancelSendingCrashReport:)]) {
        [self.delegate crashManagerWillCancelSendingCrashReport:self];
      }
      
      if (_lastCrashFilename)
        [self cleanCrashReportWithFilename:[_crashesDir stringByAppendingPathComponent: _lastCrashFilename]];
      
      return YES;
      
    case BITCrashManagerUserInputSend:
      if (userProvidedMetaData)
        [self persistUserProvidedMetaData:userProvidedMetaData];
      
      [self sendNextCrashReport];
      return YES;
      
    case BITCrashManagerUserInputAlwaysSend:
      _crashManagerStatus = BITCrashManagerStatusAutoSend;
      [[NSUserDefaults standardUserDefaults] setInteger:_crashManagerStatus forKey:kBITCrashManagerStatus];
      [[NSUserDefaults standardUserDefaults] synchronize];
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillSendCrashReportsAlways:)]) {
        [self.delegate crashManagerWillSendCrashReportsAlways:self];
      }
      
      if (userProvidedMetaData)
        [self persistUserProvidedMetaData:userProvidedMetaData];
      
      [self sendNextCrashReport];
      return YES;
      
    default:
      return NO;
  }
  
}

#pragma mark - PLCrashReporter

/**
 *	 Process new crash reports provided by PLCrashReporter
 *
 * Parse the new crash report and gather additional meta data from the app which will be stored along the crash report
 */
- (void) handleCrashReport {
  NSError *error = NULL;
	
  if (!self.plCrashReporter) return;
  
  // check if the next call ran successfully the last time
  if (![_fileManager fileExistsAtPath:_analyzerInProgressFile]) {
    // mark the start of the routine
    [_fileManager createFileAtPath:_analyzerInProgressFile contents:nil attributes:nil];
    
    [self saveSettings];
    
    // Try loading the crash report
    NSData *crashData = [[NSData alloc] initWithData:[self.plCrashReporter loadPendingCrashReportDataAndReturnError: &error]];
    
    NSString *cacheFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
    _lastCrashFilename = cacheFilename;
    
    if (crashData == nil) {
      BITHockeyLog(@"ERROR: Could not load crash report: %@", error);
    } else {
      // get the startup timestamp from the crash report, and the file timestamp to calculate the timeinterval when the crash happened after startup
      BITPLCrashReport *report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
      
      if (report == nil) {
        BITHockeyLog(@"WARNING: Could not parse crash report");
      } else {
        NSDate *appStartTime = nil;
        NSDate *appCrashTime = nil;
        if ([report.processInfo respondsToSelector:@selector(processStartTime)]) {
          if (report.systemInfo.timestamp && report.processInfo.processStartTime) {
            appStartTime = report.processInfo.processStartTime;
            appCrashTime =report.systemInfo.timestamp;
            _timeIntervalCrashInLastSessionOccurred = [report.systemInfo.timestamp timeIntervalSinceDate:report.processInfo.processStartTime];
          }
        }
        
        [crashData writeToFile:[_crashesDir stringByAppendingPathComponent: cacheFilename] atomically:YES];
        
        NSString *incidentIdentifier = @"???";
        if (report.uuidRef != NULL) {
          incidentIdentifier = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
        }
        
        NSString *reporterKey = bit_appAnonID() ?: @"";

        _lastSessionCrashDetails = [[BITCrashDetails alloc] initWithIncidentIdentifier:incidentIdentifier
                                                                           reporterKey:reporterKey
                                                                                signal:report.signalInfo.name
                                                                         exceptionName:report.exceptionInfo.exceptionName
                                                                       exceptionReason:report.exceptionInfo.exceptionReason
                                                                          appStartTime:appStartTime
                                                                             crashTime:appCrashTime
                                                                             osVersion:report.systemInfo.operatingSystemVersion
                                                                               osBuild:report.systemInfo.operatingSystemBuild
                                                                              appBuild:report.applicationInfo.applicationVersion
                                    ];

        // fetch and store the meta data after setting _lastSessionCrashDetails, so the property can be used in the protocol methods
        [self storeMetaDataForCrashReportFilename:cacheFilename];
      }
    }
  }
	
  // Purge the report
  // mark the end of the routine
  if ([_fileManager fileExistsAtPath:_analyzerInProgressFile]) {
    [_fileManager removeItemAtPath:_analyzerInProgressFile error:&error];
  }

  [self saveSettings];
  
  [self.plCrashReporter purgePendingCrashReport];
}

/**
 Get the filename of the first not approved crash report
 
 @return NSString Filename of the first found not approved crash report
 */
- (NSString *)firstNotApprovedCrashReport {
  if ((!_approvedCrashReports || [_approvedCrashReports count] == 0) && [_crashFiles count] > 0) {
    return [_crashFiles objectAtIndex:0];
  }
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    NSString *filename = [_crashFiles objectAtIndex:i];
    
    if (![_approvedCrashReports objectForKey:filename]) return filename;
  }
  
  return nil;
}

/**
 *	Check if there are any new crash reports that are not yet processed
 *
 *	@return	`YES` if there is at least one new crash report found, `NO` otherwise
 */
- (BOOL)hasPendingCrashReport {
  if (_crashManagerStatus == BITCrashManagerStatusDisabled) return NO;
    
  if ([self.fileManager fileExistsAtPath:_crashesDir]) {
    NSError *error = NULL;
    
    NSArray *dirArray = [self.fileManager contentsOfDirectoryAtPath:_crashesDir error:&error];
    
    for (NSString *file in dirArray) {
      NSString *filePath = [_crashesDir stringByAppendingPathComponent:file];

      NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:filePath error:&error];
      if ([[fileAttributes objectForKey:NSFileType] isEqualToString:NSFileTypeRegular] &&
          [[fileAttributes objectForKey:NSFileSize] intValue] > 0 &&
          ![file hasSuffix:@".DS_Store"] &&
          ![file hasSuffix:@".analyzer"] &&
          ![file hasSuffix:@".plist"] &&
          ![file hasSuffix:@".data"] &&
          ![file hasSuffix:@".meta"] &&
          ![file hasSuffix:@".desc"]) {
        [_crashFiles addObject:filePath];
      }
    }
  }
  
  if ([_crashFiles count] > 0) {
    BITHockeyLog(@"INFO: %lu pending crash reports found.", (unsigned long)[_crashFiles count]);
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

- (void)triggerDelayedProcessing {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invokeDelayedProcessing) object:nil];
  [self performSelector:@selector(invokeDelayedProcessing) withObject:nil afterDelay:0.5];
}

/**
 * Delayed startup processing for everything that does not to be done in the app startup runloop
 *
 * - Checks if there is another exception handler installed that may block ours
 * - Present UI if the user has to approve new crash reports
 * - Send pending approved crash reports
 */
- (void)invokeDelayedProcessing {
  if (!bit_isRunningInAppExtension() &&
      [[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
    return;
  }
  
  BITHockeyLog(@"INFO: Start delayed CrashManager processing");
  
  // was our own exception handler successfully added?
  if (self.exceptionHandler) {
    // get the current top level error handler
    NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
  
    // If the top level error handler differs from our own, then at least another one was added.
    // This could cause exception crashes not to be reported to HockeyApp. See log message for details.
    if (self.exceptionHandler != currentHandler) {
      BITHockeyLog(@"[HockeySDK] WARNING: Another exception handler was added. If this invokes any kind exit() after processing the exception, which causes any subsequent error handler not to be invoked, these crashes will NOT be reported to HockeyApp!");
    }
  }
  
  if (!_sendingInProgress && [self hasPendingCrashReport]) {
    _sendingInProgress = YES;
    
    NSString *notApprovedReportFilename = [self firstNotApprovedCrashReport];

    // this can happen in case there is a non approved crash report but it didn't happen in the previous app session
    if (notApprovedReportFilename && !_lastCrashFilename) {
      _lastCrashFilename = [notApprovedReportFilename lastPathComponent];
    }

    if (!BITHockeyBundle() || bit_isRunningInAppExtension()) {
      [self sendNextCrashReport];
    } else if (_crashManagerStatus != BITCrashManagerStatusAutoSend && notApprovedReportFilename) {
      
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillShowSubmitCrashReportAlert:)]) {
        [self.delegate crashManagerWillShowSubmitCrashReportAlert:self];
      }
      
      NSString *appName = bit_appName(BITHockeyLocalizedString(@"HockeyAppNamePlaceholder"));
      NSString *alertDescription = [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundAnonymousDescription"), appName];
      
      // the crash report is not anonymous any more if username or useremail are not nil
      NSString *userid = [self userIDForCrashReport];
      NSString *username = [self userNameForCrashReport];
      NSString *useremail = [self userEmailForCrashReport];
            
      if ((userid && [userid length] > 0) ||
          (username && [username length] > 0) ||
          (useremail && [useremail length] > 0)) {
        alertDescription = [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundDescription"), appName];
      }
      
      if (_alertViewHandler) {
        _alertViewHandler();
      } else {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundTitle"), appName]
                                                            message:alertDescription
                                                           delegate:self
                                                  cancelButtonTitle:BITHockeyLocalizedString(@"CrashDontSendReport")
                                                  otherButtonTitles:BITHockeyLocalizedString(@"CrashSendReport"), nil];
        
        if (self.shouldShowAlwaysButton) {
          [alertView addButtonWithTitle:BITHockeyLocalizedString(@"CrashSendReportAlways")];
        }
        
        [alertView show];
      }
    } else {
      [self sendNextCrashReport];
    }
  }
}

/**
 *	 Main startup sequence initializing PLCrashReporter if it wasn't disabled
 */
- (void)startManager {
  if (_crashManagerStatus == BITCrashManagerStatusDisabled) return;
  
  [self registerObservers];
  
  [self loadSettings];
  
  if (!_isSetup) {
    static dispatch_once_t plcrPredicate;
    dispatch_once(&plcrPredicate, ^{
      /* Configure our reporter */
        
      PLCrashReporterSignalHandlerType signalHandlerType = PLCrashReporterSignalHandlerTypeBSD;
      if (self.isMachExceptionHandlerEnabled) {
        signalHandlerType = PLCrashReporterSignalHandlerTypeMach;
      }
      
      PLCrashReporterSymbolicationStrategy symbolicationStrategy = PLCrashReporterSymbolicationStrategyNone;
      if (self.isOnDeviceSymbolicationEnabled) {
        symbolicationStrategy = PLCrashReporterSymbolicationStrategyAll;
      }
      
      BITPLCrashReporterConfig *config = [[BITPLCrashReporterConfig alloc] initWithSignalHandlerType: signalHandlerType
                                                                               symbolicationStrategy: symbolicationStrategy];
      self.plCrashReporter = [[BITPLCrashReporter alloc] initWithConfiguration: config];
      
      // Check if we previously crashed
      if ([self.plCrashReporter hasPendingCrashReport]) {
        _didCrashInLastSession = YES;
        [self handleCrashReport];
      }
      
      // The actual signal and mach handlers are only registered when invoking `enableCrashReporterAndReturnError`
      // So it is safe enough to only disable the following part when a debugger is attached no matter which
      // signal handler type is set
      // We only check for this if we are not in the App Store environment
      
      BOOL debuggerIsAttached = NO;
      if (![self isAppStoreEnvironment]) {
        if ([self isDebuggerAttached]) {
          debuggerIsAttached = YES;
          NSLog(@"[HockeySDK] WARNING: Detecting crashes is NOT enabled due to running the app with a debugger attached.");
        }
      }
      
      if (!debuggerIsAttached) {
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
        
        // PLCrashReporter may only be initialized once. So make sure the developer
        // can't break this
        NSError *error = NULL;
        
        // set any user defined callbacks, hopefully the users knows what they do
        if (_crashCallBacks) {
          [self.plCrashReporter setCrashCallbacks:_crashCallBacks];
        }
        
        // Enable the Crash Reporter
        if (![self.plCrashReporter enableCrashReporterAndReturnError: &error])
          NSLog(@"[HockeySDK] WARNING: Could not enable crash reporter: %@", [error localizedDescription]);
        
        // get the new current top level error handler, which should now be the one from PLCrashReporter
        NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
        
        // do we have a new top level error handler? then we were successful
        if (currentHandler && currentHandler != initialHandler) {
          self.exceptionHandler = currentHandler;
          
          BITHockeyLog(@"INFO: Exception handler successfully initialized.");
        } else {
          // this should never happen, theoretically only if NSSetUncaugtExceptionHandler() has some internal issues
          NSLog(@"[HockeySDK] ERROR: Exception handler could not be set. Make sure there is no other exception handler set up!");
        }
      }
      _isSetup = YES;
    });
  }

  if ([[NSUserDefaults standardUserDefaults] valueForKey:kBITAppDidReceiveLowMemoryNotification])
    _didReceiveMemoryWarningInLastSession = [[NSUserDefaults standardUserDefaults] boolForKey:kBITAppDidReceiveLowMemoryNotification];

  if (!_didCrashInLastSession && self.isAppNotTerminatingCleanlyDetectionEnabled) {
    BOOL didAppSwitchToBackgroundSafely = YES;
    
    if ([[NSUserDefaults standardUserDefaults] valueForKey:kBITAppWentIntoBackgroundSafely])
      didAppSwitchToBackgroundSafely = [[NSUserDefaults standardUserDefaults] boolForKey:kBITAppWentIntoBackgroundSafely];

    if (!didAppSwitchToBackgroundSafely) {
      BOOL considerReport = YES;
      
      if (self.delegate &&
          [self.delegate respondsToSelector:@selector(considerAppNotTerminatedCleanlyReportForCrashManager:)]) {
        considerReport = [self.delegate considerAppNotTerminatedCleanlyReportForCrashManager:self];
      }
      
      if (considerReport) {
        [self createCrashReportForAppKill];
      
        _didCrashInLastSession = YES;
      }
    }
  }
  
  if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
    [self appEnteredForeground];
  }
  
  [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kBITAppDidReceiveLowMemoryNotification];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  [self triggerDelayedProcessing];
}

/**
 *  Creates a fake crash report because the app was killed while being in foreground
 */
- (void)createCrashReportForAppKill {
  NSString *fakeReportUUID = bit_UUID();
  NSString *fakeReporterKey = bit_appAnonID() ?: @"???";
  
  NSString *fakeReportAppVersion = [[NSUserDefaults standardUserDefaults] objectForKey:kBITAppVersion];
  if (!fakeReportAppVersion)
    return;
  
  NSString *fakeReportOSVersion = [[NSUserDefaults standardUserDefaults] objectForKey:kBITAppOSVersion] ?: [[UIDevice currentDevice] systemVersion];
  NSString *fakeReportOSVersionString = fakeReportOSVersion;
  NSString *fakeReportOSBuild = [[NSUserDefaults standardUserDefaults] objectForKey:kBITAppOSBuild] ?: [self osBuild];
  if (fakeReportOSBuild) {
    fakeReportOSVersionString = [NSString stringWithFormat:@"%@ (%@)", fakeReportOSVersion, fakeReportOSBuild];
  }
  
  NSString *fakeReportAppBundleIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  NSString *fakeReportDeviceModel = [self getDevicePlatform] ?: @"Unknown";
  NSString *fakeReportAppUUIDs = [[NSUserDefaults standardUserDefaults] objectForKey:kBITAppUUIDs] ?: @"";
  
  NSString *fakeSignalName = kBITCrashKillSignal;
  
  NSMutableString *fakeReportString = [NSMutableString string];

  [fakeReportString appendFormat:@"Incident Identifier: %@\n", fakeReportUUID];
  [fakeReportString appendFormat:@"CrashReporter Key:   %@\n", fakeReporterKey];
  [fakeReportString appendFormat:@"Hardware Model:      %@\n", fakeReportDeviceModel];
  [fakeReportString appendFormat:@"Identifier:      %@\n", fakeReportAppBundleIdentifier];
  [fakeReportString appendFormat:@"Version:         %@\n", fakeReportAppVersion];
  [fakeReportString appendString:@"Code Type:       ARM\n"];
  [fakeReportString appendString:@"\n"];
  
  NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
  NSDateFormatter *rfc3339Formatter = [[NSDateFormatter alloc] init];
  [rfc3339Formatter setLocale:enUSPOSIXLocale];
  [rfc3339Formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
  [rfc3339Formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  NSString *fakeCrashTimestamp = [rfc3339Formatter stringFromDate:[NSDate date]];

  // we use the current date, since we don't know when the kill actually happened
  [fakeReportString appendFormat:@"Date/Time:       %@\n", fakeCrashTimestamp];
  [fakeReportString appendFormat:@"OS Version:      %@\n", fakeReportOSVersionString];
  [fakeReportString appendString:@"Report Version:  104\n"];
  [fakeReportString appendString:@"\n"];
  [fakeReportString appendFormat:@"Exception Type:  %@\n", fakeSignalName];
  [fakeReportString appendString:@"Exception Codes: 00000020 at 0x8badf00d\n"];
  [fakeReportString appendString:@"\n"];
  [fakeReportString appendString:@"Application Specific Information:\n"];
  [fakeReportString appendString:@"The application did not terminate cleanly but no crash occured."];
  if (self.didReceiveMemoryWarningInLastSession) {
    [fakeReportString appendString:@" The app received at least one Low Memory Warning."];
  }
  [fakeReportString appendString:@"\n\n"];
  
  NSString *fakeReportFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
  
  NSError *error = nil;
  
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity:2];
  [rootObj setObject:fakeReportUUID forKey:kBITFakeCrashUUID];
  [rootObj setObject:fakeReportAppVersion forKey:kBITFakeCrashAppVersion];
  [rootObj setObject:fakeReportAppBundleIdentifier forKey:kBITFakeCrashAppBundleIdentifier];
  [rootObj setObject:fakeReportOSVersion forKey:kBITFakeCrashOSVersion];
  [rootObj setObject:fakeReportDeviceModel forKey:kBITFakeCrashDeviceModel];
  [rootObj setObject:fakeReportAppUUIDs forKey:kBITFakeCrashAppBinaryUUID];
  [rootObj setObject:fakeReportString forKey:kBITFakeCrashReport];
  
  _lastSessionCrashDetails = [[BITCrashDetails alloc] initWithIncidentIdentifier:fakeReportUUID
                                                                     reporterKey:fakeReporterKey
                                                                          signal:fakeSignalName
                                                                   exceptionName:nil
                                                                 exceptionReason:nil
                                                                    appStartTime:nil
                                                                       crashTime:nil
                                                                       osVersion:fakeReportOSVersion
                                                                         osBuild:fakeReportOSBuild
                                                                        appBuild:fakeReportAppVersion
                              ];

  NSData *plist = [NSPropertyListSerialization dataWithPropertyList:(id)rootObj
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                            options:0
                                                              error:&error];
  if (plist) {
    if ([plist writeToFile:[_crashesDir stringByAppendingPathComponent:[fakeReportFilename stringByAppendingPathExtension:@"fake"]] atomically:YES]) {
      [self storeMetaDataForCrashReportFilename:fakeReportFilename];
    }
  } else {
    BITHockeyLog(@"ERROR: Writing fake crash report. %@", [error description]);
  }
}

/**
 *	 Send all approved crash reports
 *
 * Gathers all collected data and constructs the XML structure and starts the sending process
 */
- (void)sendNextCrashReport {
  NSError *error = NULL;
  
  _crashIdenticalCurrentVersion = NO;
  
  if ([_crashFiles count] == 0)
    return;
  
  NSString *crashXML = nil;
  BITHockeyAttachment *attachment = nil;
  
  NSString *filename = [_crashFiles objectAtIndex:0];
  NSString *cacheFilename = [filename lastPathComponent];
  NSData *crashData = [NSData dataWithContentsOfFile:filename];
  
  if ([crashData length] > 0) {
    BITPLCrashReport *report = nil;
    NSString *crashUUID = @"";
    NSString *installString = nil;
    NSString *crashLogString = nil;
    NSString *appBundleIdentifier = nil;
    NSString *appBundleVersion = nil;
    NSString *osVersion = nil;
    NSString *deviceModel = nil;
    NSString *appBinaryUUIDs = nil;
    NSString *metaFilename = nil;
    
    NSPropertyListFormat format;
    
    if ([[cacheFilename pathExtension] isEqualToString:@"fake"]) {
      NSDictionary *fakeReportDict = (NSDictionary *)[NSPropertyListSerialization
                                                      propertyListWithData:crashData
                                                      options:NSPropertyListMutableContainersAndLeaves
                                                      format:&format
                                                      error:&error];
      
      crashLogString = [fakeReportDict objectForKey:kBITFakeCrashReport];
      crashUUID = [fakeReportDict objectForKey:kBITFakeCrashUUID];
      appBundleIdentifier = [fakeReportDict objectForKey:kBITFakeCrashAppBundleIdentifier];
      appBundleVersion = [fakeReportDict objectForKey:kBITFakeCrashAppVersion];
      appBinaryUUIDs = [fakeReportDict objectForKey:kBITFakeCrashAppBinaryUUID];
      deviceModel = [fakeReportDict objectForKey:kBITFakeCrashDeviceModel];
      osVersion = [fakeReportDict objectForKey:kBITFakeCrashOSVersion];
      
      metaFilename = [cacheFilename stringByReplacingOccurrencesOfString:@".fake" withString:@".meta"];
      if ([appBundleVersion compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
        _crashIdenticalCurrentVersion = YES;
      }
      
    } else {
      report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
    }
    
    if (report == nil && crashLogString == nil) {
      BITHockeyLog(@"WARNING: Could not parse crash report");
      // we cannot do anything with this report, so delete it
      [self cleanCrashReportWithFilename:filename];
      // we don't continue with the next report here, even if there are to prevent calling sendCrashReports from itself again
      // the next crash will be automatically send on the next app start/becoming active event
      return;
    }
    
    installString = bit_appAnonID() ?: @"";
    
    if (report) {
      if (report.uuidRef != NULL) {
        crashUUID = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
      }
      metaFilename = [cacheFilename stringByAppendingPathExtension:@"meta"];
      crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:installString];
      appBundleIdentifier = report.applicationInfo.applicationIdentifier;
      appBundleVersion = report.applicationInfo.applicationVersion;
      osVersion = report.systemInfo.operatingSystemVersion;
      deviceModel = [self getDevicePlatform];
      appBinaryUUIDs = [self extractAppUUIDs:report];
      if ([report.applicationInfo.applicationVersion compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
        _crashIdenticalCurrentVersion = YES;
      }
    }
    
    if ([report.applicationInfo.applicationVersion compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
      _crashIdenticalCurrentVersion = YES;
    }
    
    NSString *username = @"";
    NSString *useremail = @"";
    NSString *userid = @"";
    NSString *applicationLog = @"";
    NSString *description = @"";
    
    NSData *plist = [NSData dataWithContentsOfFile:[_crashesDir stringByAppendingPathComponent:metaFilename]];
    if (plist) {
      NSDictionary *metaDict = (NSDictionary *)[NSPropertyListSerialization
                                                propertyListWithData:plist
                                                options:NSPropertyListMutableContainersAndLeaves
                                                format:&format
                                                error:&error];
      
      username = [self stringValueFromKeychainForKey:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserName]] ?: @"";
      useremail = [self stringValueFromKeychainForKey:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserEmail]] ?: @"";
      userid = [self stringValueFromKeychainForKey:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserID]] ?: @"";
      applicationLog = [metaDict objectForKey:kBITCrashMetaApplicationLog] ?: @"";
      description = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@.desc", [_crashesDir stringByAppendingPathComponent: cacheFilename]] encoding:NSUTF8StringEncoding error:&error];
      attachment = [self attachmentForCrashReport:filename];
    } else {
      BITHockeyLog(@"ERROR: Reading crash meta data. %@", error);
    }
    
    if ([applicationLog length] > 0) {
      if ([description length] > 0) {
        description = [NSString stringWithFormat:@"%@\n\nLog:\n%@", description, applicationLog];
      } else {
        description = [NSString stringWithFormat:@"Log:\n%@", applicationLog];
      }
    }
    
    crashXML = [NSString stringWithFormat:@"<crashes><crash><applicationname><![CDATA[%@]]></applicationname><uuids>%@</uuids><bundleidentifier>%@</bundleidentifier><systemversion>%@</systemversion><platform>%@</platform><senderversion>%@</senderversion><version>%@</version><uuid>%@</uuid><log><![CDATA[%@]]></log><userid>%@</userid><username>%@</username><contact>%@</contact><installstring>%@</installstring><description><![CDATA[%@]]></description></crash></crashes>",
                [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"],
                appBinaryUUIDs,
                appBundleIdentifier,
                osVersion,
                deviceModel,
                [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                appBundleVersion,
                crashUUID,
                [crashLogString stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,crashLogString.length)],
                userid,
                username,
                useremail,
                installString,
                [description stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,description.length)]];
    
    // store this crash report as user approved, so if it fails it will retry automatically
    [_approvedCrashReports setObject:[NSNumber numberWithBool:YES] forKey:filename];

    [self saveSettings];
    
    BITHockeyLog(@"INFO: Sending crash reports:\n%@", crashXML);
    [self sendCrashReportWithFilename:filename xml:crashXML attachment:attachment];
  } else {
    // we cannot do anything with this report, so delete it
    [self cleanCrashReportWithFilename:filename];
  }
}


#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
  switch (buttonIndex) {
    case 0:
      [self handleUserInput:BITCrashManagerUserInputDontSend withUserProvidedMetaData:nil];
      break;
    case 1:
      [self handleUserInput:BITCrashManagerUserInputSend withUserProvidedMetaData:nil];
      break;
    case 2:
      [self handleUserInput:BITCrashManagerUserInputAlwaysSend withUserProvidedMetaData:nil];
      break;
  }
}




#pragma mark - Networking

- (NSURLRequest *)requestWithXML:(NSString*)xml attachment:(BITHockeyAttachment *)attachment {
  NSString *postCrashPath = [NSString stringWithFormat:@"api/2/apps/%@/crashes", self.encodedAppIdentifier];
  
  NSMutableURLRequest *request = [self.hockeyAppClient requestWithMethod:@"POST"
                                                                    path:postCrashPath
                                                              parameters:nil];
  
  [request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
  [request setValue:@"HockeySDK/iOS" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];

  NSString *boundary = @"----FOO";
  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
  [request setValue:contentType forHTTPHeaderField:@"Content-type"];
	
  NSMutableData *postBody =  [NSMutableData data];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:BITHOCKEY_NAME
                                                      forKey:@"sdk"
                                                    boundary:boundary]];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:BITHOCKEY_VERSION
                                                      forKey:@"sdk_version"
                                                    boundary:boundary]];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:@"no"
                                                      forKey:@"feedbackEnabled"
                                                    boundary:boundary]];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:[xml dataUsingEncoding:NSUTF8StringEncoding]
                                                      forKey:@"xml"
                                                 contentType:@"text/xml"
                                                    boundary:boundary
                                                    filename:@"crash.xml"]];
  
  if (attachment && attachment.hockeyAttachmentData) {
    NSString *attachmentFilename = attachment.filename;
    if (!attachmentFilename) {
      attachmentFilename = @"Attachment_0";
    }
    [postBody appendData:[BITHockeyAppClient dataWithPostValue:attachment.hockeyAttachmentData
                                                        forKey:@"attachment0"
                                                   contentType:attachment.contentType
                                                      boundary:boundary
                                                      filename:attachmentFilename]];
  }
  
  [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  
  [request setHTTPBody:postBody];
  
  return request;
}

/**
 *	 Send the XML data to the server
 *
 * Wraps the XML structure into a POST body and starts sending the data asynchronously
 *
 *	@param	xml	The XML data that needs to be send to the server
 */
- (void)sendCrashReportWithFilename:(NSString *)filename xml:(NSString*)xml attachment:(BITHockeyAttachment *)attachment {
  
  NSURLRequest* request = [self requestWithXML:xml attachment:attachment];
  
  __weak typeof (self) weakSelf = self;
  BITHTTPOperation *operation = [self.hockeyAppClient
                                 operationWithURLRequest:request
                                 completion:^(BITHTTPOperation *operation, NSData* responseData, NSError *error) {
                                   typeof (self) strongSelf = weakSelf;
                                   
                                   _sendingInProgress = NO;
                                   
                                   NSInteger statusCode = [operation.response statusCode];

                                   if (nil == error) {
                                     if (nil == responseData || [responseData length] == 0) {
                                       error = [NSError errorWithDomain:kBITCrashErrorDomain
                                                                   code:BITCrashAPIReceivedEmptyResponse
                                                               userInfo:@{
                                                                          NSLocalizedDescriptionKey: @"Sending failed with an empty response!"
                                                                          }
                                                ];
                                     } else if (statusCode >= 200 && statusCode < 400) {
                                       [strongSelf cleanCrashReportWithFilename:filename];
                                       
                                       // HockeyApp uses PList XML format
                                       NSMutableDictionary *response = [NSPropertyListSerialization propertyListWithData:responseData
                                                                                                                 options:NSPropertyListMutableContainersAndLeaves
                                                                                                                  format:nil
                                                                                                                   error:&error];
                                       BITHockeyLog(@"INFO: Received API response: %@", response);
                                       
                                       if (strongSelf.delegate != nil &&
                                           [strongSelf.delegate respondsToSelector:@selector(crashManagerDidFinishSendingCrashReport:)]) {
                                         [strongSelf.delegate crashManagerDidFinishSendingCrashReport:self];
                                       }
                                       
                                       // only if sending the crash report went successfully, continue with the next one (if there are more)
                                       [strongSelf sendNextCrashReport];
                                     } else if (statusCode == 400) {
                                       [strongSelf cleanCrashReportWithFilename:filename];
                                       
                                       error = [NSError errorWithDomain:kBITCrashErrorDomain
                                                                   code:BITCrashAPIAppVersionRejected
                                                               userInfo:@{
                                                                          NSLocalizedDescriptionKey: @"The server rejected receiving crash reports for this app version!"
                                                                          }
                                                ];
                                     } else {
                                       error = [NSError errorWithDomain:kBITCrashErrorDomain
                                                                   code:BITCrashAPIErrorWithStatusCode
                                                               userInfo:@{
                                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Sending failed with status code: %li", (long)statusCode]
                                                                          }
                                                ];
                                     }
                                   }
                                   
                                   if (error) {
                                     if (strongSelf.delegate != nil &&
                                         [strongSelf.delegate respondsToSelector:@selector(crashManager:didFailWithError:)]) {
                                       [strongSelf.delegate crashManager:self didFailWithError:error];
                                     }
                                     
                                     BITHockeyLog(@"ERROR: %@", [error localizedDescription]);
                                   }
                                   
                                 }];
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillSendCrashReport:)]) {
    [self.delegate crashManagerWillSendCrashReport:self];
  }
  
  BITHockeyLog(@"INFO: Sending crash reports started.");

  [self.hockeyAppClient enqeueHTTPOperation:operation];
}

- (NSTimeInterval)timeintervalCrashInLastSessionOccured {
  return self.timeIntervalCrashInLastSessionOccurred;
}

@end

#endif /* HOCKEYSDK_FEATURE_CRASH_REPORTER */

