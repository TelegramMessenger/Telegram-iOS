## Introduction

For some types of crashes it is helpful to have more data available, than a crash report itself can provide, e.g. application specific log data.

Since the crash report can only be send on the next start, you need to store the log data into a log file. And to make that as fast as possible it should not block the main thread. We highly recommend using [CocoaLumberjack](https://github.com/robbiehanson/CocoaLumberjack/) or [NSLogger](https://github.com/fpillet/NSLogger) or even both in combination using the [NSLogger-CocoaLumberjack-connector](https://github.com/steipete/NSLogger-CocoaLumberjack-connector).

CocoaLumberjack can write log data to multiple destinations non blocking (!!), like the Xcode console or files, and NSLogger has the ability to stream log data over Bonjour to it's Mac application. We do *NOT* recommend to use `NSLog`!

**Important:** Make sure *NOT* to include personalized data into the log data because of privacy reasons! Also don't send too much data that you will never use. The crash report and the log data should be small in size, so they get send quickly even under bad mobile network conditions.


## HowTo

1. Setup the logging framework of choice
2. Implement `[BITCrashManagerDelegate applicationLogForCrashManager:]`
3. Return the log data

## Example

This example code is based on CocoaLumberjack logging into log files:

	@interface BITAppDelegate () <BITCrashManagerDelegate> {}
		@property (nonatomic) DDFileLogger *fileLogger;
	@end
	
	
	@implementation BITAppDelegate
	
	- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	  [self.window makeKeyAndVisible];

	  // initialize before HockeySDK, so the delegate can access the file logger!
	  _fileLogger = [[DDFileLogger alloc] init];
	  _fileLogger.maximumFileSize = (1024 * 64); // 64 KByte
	  _fileLogger.logFileManager.maximumNumberOfLogFiles = 1;
	  [_fileLogger rollLogFile];
	  [DDLog addLogger:_fileLogger];
	  
	  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<>"
                                                         delegate:nil];
	  
	  [[BITHockeyManager sharedHockeyManager] startManager];
	  
	  // add Xcode console logger if not running in the App Store
	  if (![[BITHockeyManager sharedHockeyManager] isAppStoreEnvironment]) {
    	PSDDFormatter *psLogger = [[[PSDDFormatter alloc] init] autorelease];
    	[[DDTTYLogger sharedInstance] setLogFormatter:psLogger];
    
    	[DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    	[DDLog addLogger:[DDNSLoggerLogger sharedInstance]];
      }
      
	  return YES;
	}
	
	// get the log content with a maximum byte size
	- (NSString *) getLogFilesContentWithMaxSize:(NSInteger)maxSize {
	  NSMutableString *description = [NSMutableString string];
	    
	  NSArray *sortedLogFileInfos = [[_fileLogger logFileManager] sortedLogFileInfos];
	  NSUInteger count = [sortedLogFileInfos count];
	  
	  // we start from the last one
	  for (NSUInteger index = count - 1; index >= 0; index--) {
	    DDLogFileInfo *logFileInfo = [sortedLogFileInfos objectAtIndex:index];
	    
	    NSData *logData = [[NSFileManager defaultManager] contentsAtPath:[logFileInfo filePath]];
	    if ([logData length] > 0) {
	      NSString *result = [[NSString alloc] initWithBytes:[logData bytes]
	                                                  length:[logData length]
	                                                encoding: NSUTF8StringEncoding];
	      
	      [description appendString:result];
	      [result release];
	    }
	  }
	  
	  if ([description length] > maxSize) {
	    description = (NSMutableString *)[description substringWithRange:NSMakeRange([description length]-maxSize-1, maxSize)]; 
	  }
	  
	  return description;
	}
	
	#pragma mark - BITCrashManagerDelegate
	
	- (NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager {
	  NSString *description = [self getLogFilesContentWithMaxSize:5000]; // 5000 bytes should be enough!
	  if ([description length] == 0) {
	    return nil;
	  } else {
	    return description;
	  }
	}
	
	@end
