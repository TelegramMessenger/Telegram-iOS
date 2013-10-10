## Identify and authenticate users of iOS Ad-Hoc or Enterprise builds

HockeySDK 3.5 for iOS includes a new class called `BITAuthenticator` which serves 2 purposes:

1. Identifying who is running your Ad-Hoc or Enterprise builds. The authenticator provides an identifier for the rest of HockeySDK to work with, e.g. in-app update checks and crash reports.

2. Optional regular checking if an identified user is still allowed to run this application. The authenticator can be configured to make sure only users who are testers of your app are allowed to run it.

Previous versions of HockeySDK for iOS used the response of the method `UIDevice#uniqueIdentifier` (aka the UDID) to identify which user was testing an app and which versions are installable on the user's device. `UIDevice#uniqueIdentifier` was deprecated with iOS 5 and we expect Apple to remove it from future versions of iOS.

`BITAuthenticator` offers four strategies for authentication:

* **BITAuthenticatorIdentificationTypeAnonymous** (_Default_)

    An anonymous ID will be generated.

* **BITAuthenticatorIdentificationTypeDevice**

    The app opens Safari to request the UDID from the HockeyApp web clip.

* **BITAuthenticatorIdentificationTypeHockeyAppUser**

    The user needs to enter the email address of his HockeyApp account.

* **BITAuthenticatorIdentificationTypeHockeyAppEmail**

    The user needs to enter the email address and password of his HockeyApp account.

The `BITAuthenticator` class doesn't do anything on its own. In addition to setting up the behavior, you also need to trigger the process yourself.

If `automaticMode` is enabled (default), you simply need to place a call to `[[BITHockeyManager sharedHockeyManager] authenticateInstallation]` in your code. This will show a UI asking for identification details according to the chosen strategy.

**IMPORTANT**: If your app shows a modal view on startup, make sure to call `authenticateInstallation` either once your modal view is fully presented (e.g. its `viewDidLoad:` method is processed) or once your modal view is dismissed.

If `automaticMode` is disabled, you need to implement your own workflow by using

    - (void) identifyWithCompletion:(void(^)(BOOL identified, NSError *error)) completion;

to identify the current user depending on your strategy and 

    - (void) validateWithCompletion:(void(^)(BOOL validated, NSError *error)) completion;

to validate the user may still use the app if required.

The following sections explain the different strategies and their advantages / disadvantages.

<a name="no-authentication"></a>
## No Authentication

Initialize HockeySDK with the following code:

    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<#APP_ID#>" delegate:self];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager] authenticateInstallation];

Replace APP_ID with the your App ID (can be found on the app page). 

The SDK will use a generated unique ID to identify the installation.

Advantages:

* No additional steps for the user of your apps.
* Can be used with or without inviting users.

Disadvantages:

* You are not able to see who installed and used your app.
* The SDK can not detect if the device's UDID is included in the provisioning profile, so it might show un-installable versions (does not apply to Enterprise Provisioning Profiles).

## Authentication using UDID

Initialize HockeySDK with the following code:

    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<#APP_ID#>" delegate:self];
    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeDevice];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager] authenticateInstallation];

Replace APP_ID with the your App ID (can be found on the app page). 

The SDK will ask the user to identify his device by opening Safari. Safari reads the UDID out of the HockeyApp session and then opens your app again via an URL scheme. You need to add the URL scheme to your Info.plist and handle it in your application delegate:

1. Open your Info.plist.

2. Add a new key `CFBundleURLTypes`.

3. Change the key of the first child item to `URL Schemes` or `CFBundleURLSchemes`.

4. Enter `haAPP_ID` as the URL scheme with APP_ID being replaced by the App ID of your app.

5. Open your AppDelegate.m.

6. Add the following code:
 
        - (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
          if( [[BITHockeyManager sharedHockeyManager].authenticator handleOpenURL:url
                                                                sourceApplication:sourceApplication
                                                                       annotation:annotation]) {
            return YES;
          }

          /* Your own custom URL handlers */

          return NO;
        }

Advantages:

* HockeyApp can show which user has installed your app and how long he used it.
* The SDK only offers installable builds, i.e. with the UDID in the provisioning profile.
* Can be used with or without inviting users.

Disadvantages:

* Users need to install the HockeyApp web clip. They will be guided to do so if it isn't already installed.

## Authentication using Email Address

Initialize HockeySDK with the following code:

    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<#APP_ID#>" delegate:self];
    [[BITHockeyManager sharedHockeyManager].authenticator setAuthenticationSecret:@"<#SECRET#>"];
    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager] authenticateInstallation];

Replace APP_ID with the your App ID and SECRET with the Secret (both values can be found on the app page). 

The SDK will ask the user to identify himself with the email address of his HockeyApp account, then validate if this user is a tester, member, or developer of your app.

Advantages:

* HockeyApp can show which user has installed your app and how long he used it.
* The SDK only offers installable builds, i.e. with the UDID in the provisioning profile (if all devices of this user are in the provisioning profile).
* If you remove a user from your app, he will not be able to use it anymore (see documentation for `restrictApplicationUsage`)

Disadvantages:

* Users need to be a tester, member, or developer of your app
* Email addresses can be guessed by unauthorized users

## Authentication using Email Address and Password

Initialize HockeySDK with the following code:

    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_ID" delegate:self];
    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeHockeyAppUser];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager] authenticateInstallation];

Replace APP_ID with the your App ID (can be found on the app page). 

The SDK will ask the user to identify himself with the email address and password of his HockeyApp account, then validate if this user is a tester, member, or developer of your app.

Advantages:

* HockeyApp can show which user has installed your app and how long he used it.
* The SDK only offers installable builds, i.e. with the UDID in the provisioning profile (if all devices of this user are in the provisioning profile).
* If you remove a user from your app, he will not be able to use it anymore (see documentation for `restrictApplicationUsage`)

Disadvantages:

* Users need to be a tester, member, or developer of your app
* Users need to set a password on HockeyApp (even if they use Facebook Connect)