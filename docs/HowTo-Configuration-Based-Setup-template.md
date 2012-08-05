## Introduction

It can be useful to use a different setup depending on your Xcode build configuration, e.g. disable Beta Update checks in Debug builds. 

To do that, we recommend to define a preprocessor macro for all configurations and use compiler directives to setup the SDK depending on the currently used build configuration.

**Note:** Beta Update checks is automatically disable when the SDK detects it is running in an App Store build. So you don't have to do anything in that scenario!

## HowTo

1. Select your project in the Project Navigator.
2. Select your target.
3. Select the tab "Build Settings".
4. Enter "preprocessor macros" into the search field.

    ![XcodeMacros1.png](XcodeMacros1_normal.png)

5. Select the top-most line and double-click the value field.
6. Click the + button.
7. Enter the following string into the input field and finish with "Done".<pre><code>CONFIGURATION_$(CONFIGURATION)</code></pre>

    ![XcodeMacros2.png](XcodeMacros2_normal.png)

Now you can use `#if defined (CONFIGURATION_ABCDEF)` directives in your code, where `ABCDEF` is the actual name of your build configuration.

**Note:** Make sure to use build configuration names without spaces!

## Example
	  
	  #if defined (CONFIGURATION_Debug)
	      [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<>"
	                                                             delegate:nil];
	      [[BITHockeyManager sharedHockeyManager] setDisableUpdateManager:YES];
	  #else
	      [[BITHockeyManager sharedHockeyManager] configureWithBetaIdentifier:@"<>"
	                                                           liveIdentifier:@"<>"
	                                                                 delegate:nil];
	  #endif
	  
	  [[BITHockeyManager sharedHockeyManager] startManager];
	  
