## Identify and authenticate users of iOS Ad-Hoc or Enterprise builds

HockeySDK 3.5 for iOS includes a new class called `BITAuthenticator` which serves 2 purposes:

1. Identifying who is running your Ad-Hoc or Enterprise builds. The authenticator provides an identifier for the rest of HockeySDK to work with, e.g. in-app update checks and crash reports.

2. Optional regular checking if an identified user is still allowed to run this application. The authenticator can be configured to make sure only users who are testers of your app are allowed to run it.

Previous versions of HockeySDK for iOS used the response of the method `UIDevice#uniqueIdentifier` (aka the UDID) to identify which user was testing an app and which versions are installable on the user's device. `UIDevice#uniqueIdentifier` was deprecated with iOS 5 and we expect Apple to remove it from future versions of iOS.

`BITAuthenticator` offers five strategies for authentication:

* **BITAuthenticatorIdentificationTypeAnonymous** (_Default_)

    An anonymous ID will be generated.

* **BITAuthenticatorIdentificationTypeDevice**

    The app opens Safari to request the UDID from the HockeyApp web clip.

* **BITAuthenticatorIdentificationTypeHockeyAppUser**

    The user needs to enter the email address of his HockeyApp account.

* **BITAuthenticatorIdentificationTypeHockeyAppEmail**

    The user needs to enter the email address and password of his HockeyApp account.
    
* **BITAuthenticatorIdentificationTypeWebAuth**

    The app opens Safari and asks the user to log in to his HockeyApp account.

The strategies **BITAuthenticatorIdentificationTypeDevice** and **BITAuthenticatorIdentificationTypeWebAuth** also allow for automatic authentication as explained [here](http://hockeyapp.net/blog/2014/01/31/automatic-authentication-ios.html).

After setting up one of those strategies, you need to trigger the authentication process by calling  

    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];

in your code. This will show a UI asking for identification details unless you set the strategy `BITAuthenticatorIdentificationTypeAnonymous` (then no UI is shown, but you still need to call this method). A [custom workflow](#custom-workflow) is explained at the end of this document.

**IMPORTANT**: If your app shows a modal view on startup, make sure to call `authenticateInstallation` either once your modal view is fully presented (e.g. its `viewDidLoad:` method is processed) or once your modal view is dismissed.

The following sections explain the different strategies and their advantages / disadvantages.

<a name="no-authentication"></a>
## No Authentication

Initialize HockeySDK with the following code:

    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<#APP_ID#>" delegate:self];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];

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
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];

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
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];

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
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];

Replace APP_ID with the your App ID (can be found on the app page). 

The SDK will ask the user to identify himself with the email address and password of his HockeyApp account, then validate if this user is a tester, member, or developer of your app.

Advantages:

* HockeyApp can show which user has installed your app and how long he used it.
* The SDK only offers installable builds, i.e. with the UDID in the provisioning profile (if all devices of this user are in the provisioning profile).
* If you remove a user from your app, he will not be able to use it anymore (see documentation for `restrictApplicationUsage`)

Disadvantages:

* Users need to be a tester, member, or developer of your app
* Users need to set a password on HockeyApp (even if they use Facebook Connect)

## Authentication using Login via Safari

Initialize HockeySDK with the following code:

    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_ID" delegate:self];
    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeWebAuth];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];

Replace APP_ID with the your App ID (can be found on the app page). 

The SDK will ask the user to identify himself by opening Safari. Safari then opens your app again via an URL scheme. You need to add the URL scheme to your Info.plist and handle it in your application delegate:

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
* The SDK only offers installable builds, i.e. with the UDID in the provisioning profile (if all devices of this user are in the provisioning profile).
* If you remove a user from your app, he will not be able to use it anymore (see documentation for `restrictApplicationUsage`)
* Works with any type of user accounts (even if they use Facebook Connect)

Disadvantages:

* Users need to be a tester, member, or developer of your app

## Custom Workflow

As an alternative, you can implement your own workflow with following two methods:

1. Start the process to identify a new user with one of the above strategies. This method will show a modal view only if the user was not identified before:

        - (void) identifyWithCompletion:(void(^)(BOOL identified, NSError *error)) completion;

2. Validate that the user is still a tester, member, or developer of your app. This will show an alert and a modal view only if the user could not be validated. Otherwise, the process will succeed without showing a message or view:

        - (void) validateWithCompletion:(void(^)(BOOL validated, NSError *error)) completion;
