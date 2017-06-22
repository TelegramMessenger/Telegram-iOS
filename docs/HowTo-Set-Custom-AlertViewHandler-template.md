## Introduction

HockeySDK lets the user decide wether to send a crash report or lets the developer send crash reports automatically without user interaction. In addition it is possible to attach more data like logs, a binary, or the users name, email or a user ID if this is already known.

Starting with HockeySDK version 3.6 it is possible to customize this even further and implement your own flow to e.g. ask the user for more details about what happened or his name and email address if your app doesn't know that yet.

The following example shows how this could be implemented. We'll present a custom UIAlertView asking the user for more details and attaching that to the crash report.

## HowTo

1. Setup the SDK
2. Configure HockeySDK to use your custom alertview handler using the `[[BITHockeyManager sharedHockeyManager].crashManager setAlertViewHandler:(BITCustomAlertViewHandler)alertViewHandler;` method in your AppDelegate.
3. Implement your handler in a way that it calls `[[BITHockeyManager sharedHockeyManager].crashManagerhandleUserInput:(BITCrashManagerUserInput)userInput withUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData]` with the input provided by the user.
4. Dismiss your custom view.

## Example

	@interface BITAppDelegate () <UIAlertViewDelegate>
	@end
	
	
	@implementation BITAppDelegate
	
	- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	  [self.window makeKeyAndVisible];
	
	  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<>"
	                                                         delegate:nil];
	  
	  // optionally enable logging to get more information about states.
	  [BITHockeyManager sharedHockeyManager].debugLogEnabled = YES;

	  [[BITHockeyManager sharedHockeyManager].crashManager setAlertViewHandler:^(){
        NSString *exceptionReason = [[BITHockeyManager sharedHockeyManager].crashManager lastSessionCrashDetails].exceptionReason;
        UIAlertView *customAlertView = [[UIAlertView alloc] initWithTitle: @"Oh no! The App crashed"
                                                                  message: nil
                                                                 delegate: self
                                                        cancelButtonTitle: @"Don't send"
                                                        otherButtonTitles: @"Send", @"Always send", nil];
        if (exceptionReason) {
            customAlertView.message = @"We would like to send a crash report to the developers. Please enter a short description of what happened:";
            customAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
        } else {
            customAlertView.message = @"We would like to send a crash report to the developers";
        }
        
        [customAlertView show];
      }];

      [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];

	  return YES;
	}
	
	- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	    BITCrashMetaData *crashMetaData = [BITCrashMetaData new];
	    if (alertView.alertViewStyle != UIAlertViewStyleDefault) {
	        crashMetaData.userDescription = [alertView textFieldAtIndex:0].text;
	    }
	    switch (buttonIndex) {
	        case 0:
	            [[BITHockeyManager sharedHockeyManager].crashManager handleUserInput:BITCrashManagerUserInputDontSend withUserProvidedMetaData:nil];
	            break;
	        case 1:
	            [[BITHockeyManager sharedHockeyManager].crashManager handleUserInput:BITCrashManagerUserInputSend withUserProvidedMetaData:crashMetaData];
	            break;
	        case 2:
	            [[BITHockeyManager sharedHockeyManager].crashManager handleUserInput:BITCrashManagerUserInputAlwaysSend withUserProvidedMetaData:crashMetaData];
	            break;
	    }
	}

	@end
