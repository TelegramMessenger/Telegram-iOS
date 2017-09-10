## Crash Reporting is not working

This is a checklist to help find the issue if crashes do not appear in HockeyApp or the dialog asking if crashes should be send doesn't appear:


1. Check if the `BETA_IDENTIFIER` or `LIVE_IDENTIFIER` matches the App ID in HockeyApp.

2. Check if CFBundleIdentifier in your Info.plist matches the Bundle Identifier of the app in HockeyApp. HockeyApp accepts crashes only if both the App ID and the Bundle Identifier equal their corresponding values in your plist and source code.

3. Unless you have set `[BITCrashManager setCrashManagerStatus:]` to `BITCrashManagerStatusAutoSend`: If your app crashes and you start it again, is the alert shown which asks the user to send the crash report? If not, please crash your app again, then connect the debugger and set a break point in `BITCrashManager.m`, method `startManager` to see why the alert is not shown.

4. Enable the debug logging option and check the output if the Crash Manager gets `Setup`, `Started`, returns no error message and sending the crash report to the server results in no error:

        [[BITHockeyManager shareHockeyManager] setDebugLogEnabled: YES];
    

5. Make sure Xcode debugger is not attached while causing the app to crash

6. Are you trying to catch "out of memory crashes"? This is _NOT_ possible! Out of memory crashes are actually kills by the watchdog process. Whenever you kill a process, there is no crash happening. The crash reports for those that you see on iTunes Connect, are arbitrary reports written by the watchdog process that did the kill. So they only system that can provide information about these, is iOS itself.

7. If you are using `#ifdef (CONFIGURATION_something)`, make sure that the `something` string matches the exact name of your Xcode build configuration. Spaces are not allowed!

8. Remove or at least disable any other exception handler or crash reporting framework.

9. If it still does not work, please [contact us](http://support.hockeyapp.net/discussion/new).

