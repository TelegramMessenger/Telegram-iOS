## Introduction

To catch and send crashes that occur while the app is starting up, the app has to get adjusted a little bit to make this work.

The challenges in this scenario are:

- Sending crash reports needs to be asynchronous, otherwise it would block the main thread or bad network conditions could make it even worse
- If the startup takes too long or the main thread is blocking too long, the watchdog process will kill the app
- The app might crash again before the crash report could have been send


## HowTo

1. Setup the SDK
2. Check if the app crashed in the last session by checking `[BITCrashManager didCrashInLastSession]`
3. Check if `[BITCrashManager timeintervalCrashInLastSessionOccured]` is below a treshhold that you define. E.g. say your app usually requires 2 seconds for startup, and giving sending a crash report some time, you mighe choose `5` seconds as the treshhold
4. If the crash happened in that timeframe, delay your app initialization and show an intermediate screen
5. Implement the `BITCrashManagerDelegate` protocol methods `- (void)crashManagerWillCancelSendingCrashReport:(BITCrashManager *)crashManager`,  `- (void)crashManager:(BITCrashManager *)crashManager didFailWithError:(NSError *)error;` and `- (void)crashManagerDidFinishSendingCrashReport:(BITCrashManager *)crashManager;` and continue app initialization

## Example

	@interface BITAppDelegate () <BITCrashManagerDelegate> {}
	@end
	
	
	@implementation BITAppDelegate
	
	- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	  [self.window makeKeyAndVisible];
	
	  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<>"
	                                                         delegate:nil];
	  
	  // optionally enable logging to get more information about states.
	  [BITHockeyManager sharedHockeyManager].debugLogEnabled = YES;
	
	  [[BITHockeyManager sharedHockeyManager] startManager];
	  
	  if ([self didCrashInLastSessionOnStartup]) {
	  	// show intermediate UI
	  } else {
	  	[self setupApplication];
	  }
	  
	  return YES;
	}
	
	- (BOOL)didCrashInLastSessionOnStartup {
	  return ([[BITHockeyManager sharedHockeyManager].crashManager didCrashInLastSession] &&
	  	[[BITHockeyManager sharedHockeyManager].crashManager timeintervalCrashInLastSessionOccured] < 5);
	}
	
	- (void)setupApplication {
	  // setup your app specific code
	}
	
	#pragma mark - BITCrashManagerDelegate
	
	- (void)crashManagerWillCancelSendingCrashReport:(BITCrashManager *)crashManager {
	  if ([self didCrashInLastSessionOnStartup]) {
	    [self setupApplication];
	  }
	}

	- (void)crashManager:(BITCrashManager *)crashManager didFailWithError:(NSError *)error {
	  if ([self didCrashInLastSessionOnStartup]) {
	    [self setupApplication];
	  }
	}
	
	- (void)crashManagerDidFinishSendingCrashReport:(BITCrashManager *)crashManager {
	  if ([self didCrashInLastSessionOnStartup]) {
	    [self setupApplication];
	  }
	}
	
	@end

