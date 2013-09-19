## Authenticating Users on iOS

Previous versions of HockeySDK for iOS used the response of the method `UIDevice#uniqueIdentifier` (aka the UDID) to identify which user was testing an app and which versions are installable on the user's device. `UIDevice#uniqueIdentifier` was deprecated with iOS 5 and we expect Apple to remove it from future versions of iOS.

HockeySDK 3.5 for iOS includes a new class called `BITAuthenticator` which offers three strategies for authentication:

* **BITAuthenticatorAuthTypeUDIDProvider** (_Default_)

    The app opens Safari to request the UDID from the HockeyApp web clip.

* **BITAuthenticatorAuthTypeEmail**

    The user needs to enter the email address of his HockeyApp account.

* **BITAuthenticatorAuthTypeEmailAndPassword**

    The user needs to enter the email address and password of his HockeyApp account.

The time when one of those strategies is enabled in the app's lifecycle is determined by the validation type:

* **BITAuthenticatorValidationTypeNever** (_Default_)

    Authentication is never executed (see [below](#no-authentication))

* **BITAuthenticatorValidationTypeOptional**

    Authentication is shown at the first start, but can be skipped by the user.

* **BITAuthenticatorValidationTypeOnFirstLaunch**

    Authentication is shown at the first start and validated with a new version.

* **BITAuthenticatorValidationTypeOnAppActive**

    Authentication is shown at the first start and validated at each start of the app.

The following sections explain the different strategies and their advantages / disadvantages.

<a name="no-authentication"></a>
## No Authentication

Initialize HockeySDK with the following code:

    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<#APP_ID#>" delegate:self];
    [[BITHockeyManager sharedHockeyManager] startManager];

Replace APP_ID with the your App ID (can be found on the app page). 

The SDK will use `UIDevice#identifierForVendor` on iOS 6 or newer or a generated unique ID on iOS 5.

Advantages:

* No additional steps for the user of your apps.
* Can be used with or without inviting users.

Disadvantages:

* You are not able to see who installed and used your app.
* The SDK can not detect if the device's UDID is included in the provisioning profile, so it might show un-installable versions (does not apply to Enterprise Provisioning Profiles).

## Authentication using UDID

Initialize HockeySDK with the following code:

    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<#APP_ID#>" delegate:self];
    [[BITHockeyManager sharedHockeyManager].authenticator setAuthenticationType:BITAuthenticatorAuthTypeUDIDProvider];
    [[BITHockeyManager sharedHockeyManager].authenticator setValidationType:BITAuthenticatorValidationTypeOptional];
    [[BITHockeyManager sharedHockeyManager] startManager];

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
    [[BITHockeyManager sharedHockeyManager].authenticator setAuthenticationType:BITAuthenticatorAuthTypeEmail];
    [[BITHockeyManager sharedHockeyManager].authenticator setValidationType:BITAuthenticatorValidationTypeOptional];
    [[BITHockeyManager sharedHockeyManager] startManager];

Replace APP_ID with the your App ID and SECRET with the Secret (both values can be found on the app page). 

The SDK will ask the user to identify himself with the email address of his HockeyApp account, then validate if this user is a tester, member, or developer of your app.

Advantages:

* HockeyApp can show which user has installed your app and how long he used it.
* The SDK only offers installable builds, i.e. with the UDID in the provisioning profile (if all devices of this user are in the provisioning profile).
* If you remove a user from your app, he will not be able to use it anymore (depending on validationType)

Disadvantages:

* Users need to be a tester, member, or developer of your app
* Email addresses can be guessed by unauthorized users

## Authentication using Email Address and Password

Initialize HockeySDK with the following code:

    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_ID" delegate:self];
    [[BITHockeyManager sharedHockeyManager].authenticator setAuthenticationType:BITAuthenticatorAuthTypeEmailAndPassword];
    [[BITHockeyManager sharedHockeyManager].authenticator setValidationType:BITAuthenticatorValidationTypeOptional];
    [[BITHockeyManager sharedHockeyManager] startManager];

Replace APP_ID with the your App ID (can be found on the app page). 

The SDK will ask the user to identify himself with the email address and password of his HockeyApp account, then validate if this user is a tester, member, or developer of your app.

Advantages:

* HockeyApp can show which user has installed your app and how long he used it.
* The SDK only offers installable builds, i.e. with the UDID in the provisioning profile (if all devices of this user are in the provisioning profile).
* If you remove a user from your app, he will not be able to use it anymore (depending on validationType)

Disadvantages:

* Users need to be a tester, member, or developer of your app
* Users need to set a password on HockeyApp (even if they use Facebook Connect)