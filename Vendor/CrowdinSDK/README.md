[<p align="center"><img src="https://support.crowdin.com/assets/logos/crowdin-dark-symbol.png" data-canonical-src="https://support.crowdin.com/assets/logos/crowdin-dark-symbol.png" width="200" height="200" align="center"/></p>](https://crowdin.com)

# Crowdin iOS SDK

Crowdin iOS SDK delivers all new translations from Crowdin project to the application immediately. So there is no need to update this application via App Store to get the new version with the localization.

The SDK provides:

* Over-The-Air Content Delivery – the localized content can be sent to the application from the project whenever needed.
* Real-Time Preview – all the translations that are done in the Editor can be shown in your version of the application in real-time. View the translations already made and the ones you're currently typing in.
* Screenshots – all the screenshots made in the application may be automatically sent to your Crowdin project with tagged source strings.

## Status

[![Cocoapods](https://img.shields.io/cocoapods/v/CrowdinSDK?logo=pods&cacheSeconds=3600)](https://cocoapods.org/pods/CrowdinSDK)
[![Cocoapods platforms](https://img.shields.io/cocoapods/p/CrowdinSDK?cacheSeconds=10000)](https://cocoapods.org/pods/CrowdinSDK)
[![GitHub Release Date](https://img.shields.io/github/release-date/crowdin/mobile-sdk-ios?cacheSeconds=10000)](https://github.com/crowdin/mobile-sdk-ios/releases/latest)
[![GitHub contributors](https://img.shields.io/github/contributors/crowdin/mobile-sdk-ios?cacheSeconds=3600)](https://github.com/crowdin/mobile-sdk-ios/graphs/contributors)
[![GitHub issues](https://img.shields.io/github/issues/crowdin/mobile-sdk-ios?cacheSeconds=3600)](https://github.com/crowdin/mobile-sdk-ios/issues)
[![GitHub License](https://img.shields.io/github/license/crowdin/mobile-sdk-ios?cacheSeconds=3600)](https://github.com/crowdin/mobile-sdk-ios/blob/master/LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-blue)](https://img.shields.io/badge/Swift_Package_Manager-compatible-red)


[![Azure DevOps builds (branch)](https://img.shields.io/azure-devops/build/crowdin/mobile-sdk-ios/14/master?logo=azure-pipelines&cacheSeconds=800)](https://dev.azure.com/crowdin/mobile-sdk-ios/_build/latest?definitionId=14&branchName=master)
[![codecov](https://codecov.io/gh/crowdin/mobile-sdk-ios/branch/master/graph/badge.svg)](https://codecov.io/gh/crowdin/mobile-sdk-ios)
[![Azure DevOps tests (branch)](https://img.shields.io/azure-devops/tests/crowdin/mobile-sdk-ios/14/master?cacheSeconds=800)](https://dev.azure.com/crowdin/mobile-sdk-ios/_build/latest?definitionId=14&branchName=master)

## Table of Contents
* [Requirements](#requirements)
* [Dependencies](#dependencies)
* [Installation](#installation)
* [Wiki](#wiki)
* [Setup](#setup)
* [Advanced Features](#advanced-features)
  * [Real-Time Preview](#real-time-preview)
  * [Screenshots](#screenshots)
* [Notes](#notes)
* [File Export Patterns](#file-export-patterns)
* [Contributing](#contributing)
* [Seeking Assistance](#seeking-assistance)
* [Security](#security)
* [Authors](#authors)
* [License](#license)

## Requirements

* Xcode 10.2
* Swift 4.2
* iOS 9.0

## Dependencies

* [Starscream](https://github.com/daltoniam/Starscream) - Websockets in swift for iOS and OSX.

## Installation

### Cocoapods

1. Cocoapods

   To install Crowdin iOS SDK via [cocoapods](https://cocoapods.org), make sure you have cocoapods installed locally. If not, install it with following command: ```sudo gem install cocoapods```.

   Detailed instruction can be found [here](https://guides.cocoapods.org/using/getting-started.html).

   Add the following line to your Podfile:

   ```swift
   pod 'CrowdinSDK'
   ```

2. Cocoapods spec repository

   ```swift
   target 'MyApp' do
     pod 'CrowdinSDK'
   end
   ```

3. Working with App Extensions

   Upon `pod install` result, you might experience some building issues in case your application embeds target extensions.

   Example error:

    > 'shared' (Swift) / 'sharedApplication' (Objective-C) is unavailable: not available on iOS (App Extension) - Use view controller based solutions where appropriate instead.

    In this scenario you'll need to add a `post_install` script to your Podfile

    ```swift
    post_install do |installer|

      extension_api_exclude_pods = ['CrowdinSDK']

      installer.pods_project.targets.each do |target|

          # the Pods contained into the `extension_api_exclude_pods` array
          # have to get the value (APPLICATION_EXTENSION_API_ONLY) set to NO
          # in order to work with service extensions

          if extension_api_exclude_pods.include? target.name
            target.build_configurations.each do |config|
              config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
            end
          end
        end
    end
    ```

    Then run `pod install` again to fix it.

After you've added *CrowdinSDK* to your Podfile, run ```pod install``` in your project directory, open `App.xcworkspace` and build it.

### Swift Package Manager

Once you have your Swift package set up, adding CrowdinSDK as a dependency is as easy as adding it to the dependencies value of your Package.swift.

**‼️Swift Package Manager support added in version 1.4.0‼️**

```swift
dependencies: [
    .package(url: "https://github.com/crowdin/mobile-sdk-ios.git", from:"1.4.0")
]
```

## Wiki

Visit the [Crowdin iOS SDK Wiki](https://github.com/crowdin/mobile-sdk-ios/wiki) to see additional project documentation. Here you can find information about the Example project, SDK Controls, and more.

## Setup

To configure iOS SDK integration you need to:

- Upload your *strings/stringsdict* localization files to Crowdin. If you have ready translations, you can also upload them.
- Set up Distribution in Crowdin.
- Set up SDK and enable Over-The-Air Content Delivery feature.

**Distribution** is a CDN vault that mirrors the translated content of your project and is required for integration with iOS app.

To manage distributions open the needed project and go to *Over-The-Air Content Delivery*. You can create as many distributions as you need and choose different files for each. You’ll need to click the *Release* button next to the necessary distribution every time you want to send new translations to the app.

1. Enable *Over-The-Air Content Delivery* in your Crowdin project so that application can pull translations from CDN vault.

2. In order to start using *CrowdinSDK* you need to initialize it in *AppDelegate* or in *Info.plist*

---

**Notes:**
- The CDN feature does not update the localization files. if you want to add new translations to the localization files you need to do it yourself.
- Once SDK receives the translations, it's stored on the device as application files for further sessions to minimize requests the next time the app starts. Storage time can be configured using `intervalUpdatesEnabled` option.
- CDN caches all the translation in release for up to 15 minutes and even when new translations are released in Crowdin, CDN may return it with a delay.

### Setup with AppDelegate

Open *AppDelegate.swift* file and add:

   ```swift
   import CrowdinSDK
   ```

In `application` method add:

```swift
let crowdinProviderConfig = CrowdinProviderConfig(hashString: "{your_distribution_hash}",
  sourceLanguage: "{source_language}")

CrowdinSDK.startWithConfig(crowdinSDKConfig, completion: {
    // SDK is ready to use, put code to change language, etc. here
})
```

| Config option              | Description                                                         | Example                                               |
|----------------------------|---------------------------------------------------------------------|-------------------------------------------------------|
| `hashString`               | Distribution Hash                                                   |`hashString: "7a0c1ee2622bc85a4030297uo3b"`
| `sourceLanguage`           | Source language code in your Crowdin project. [ISO 639-1](http://www.loc.gov/standards/iso639-2/php/English_list.php) | `sourceLanguage: "en"`

<details>
<summary>Objective-C</summary>

In *AppDelegate.m* add:

```objective-c
@import CrowdinSDK
```

or

```objective-c
#import<CrowdinSDK/CrowdinSDK.h>
```

In `application` method add:

```objective-c
CrowdinProviderConfig *crowdinProviderConfig = [[CrowdinProviderConfig alloc] initWithHashString:@"" sourceLanguage:@""];
CrowdinSDKConfig *config = [[[CrowdinSDKConfig config] withCrowdinProviderConfig:crowdinProviderConfig]];

[CrowdinSDK startWithConfig:config completion:^{
    // SDK is ready to use, put code to change language, etc. here
}];
```

If you have pure Objective-C project, then you will need to do some additional steps:

Add the following code to your Library Search Paths:

```objective-c
$(TOOLCHAIN_DIR)/usr/lib/swift/$(PLATFORM_NAME)
```

Add ```use_frameworks!``` to your Podfile.

</details>

### Setup with Info.plist

Open *Info.plist* file and add:

`CrowdinDistributionHash` - Crowdin CDN hash value for current project (String value).

`CrowdinSourceLanguage` - Source language code ([ISO 639-1](http://www.loc.gov/standards/iso639-2/php/English_list.php)) for current project on crowdin server (String value).

In AppDelegate you should call start method: `CrowdinSDK.start()` for Swift, and `[CrowdinSDK start]` for Objective-C.

**Note!** Using this setup method you will unable to set up additional *Screenshots* and *Real-Time Preview* project features.

## Advanced Features

### Real-Time Preview

All the translations that are done in the Editor can be shown in the application in real-time. View the translations already made and the ones you're currently typing in.

[<p align='center'><img src='https://github.com/crowdin/mobile-sdk-ios/blob/docs/sdk_preview.gif' width='500'/></p>](#)

Add the code below to your *Podfile*:

```swift
use_frameworks!
target 'your-app' do
  pod 'CrowdinSDK'
  pod 'CrowdinSDK/LoginFeature' // Required for Real-Time Preview
  pod 'CrowdinSDK/RealtimeUpdate' // Required for Real-Time Preview
  pod 'CrowdinSDK/Settings' // Optional. To add 'settings' floating button
end
```

Open *AppDelegate.swift* file and in `application` method add:

```swift
let crowdinProviderConfig = CrowdinProviderConfig(hashString: "{your_distribution_hash}",
    sourceLanguage: "{source_language}")

var loginConfig: CrowdinLoginConfig
do {
	loginConfig = try CrowdinLoginConfig(clientId: "{client_id}",
		clientSecret: "{client_secret}",
		scope: "project",
		redirectURI: "{redirectURI}",
		organizationName: "{organization_name}")
} catch {
	print(error)
	// CrowdinLoginConfig initialization error handling, typically for empty values and for wrong redirect URI value.
}

let crowdinSDKConfig = CrowdinSDKConfig.config().with(crowdinProviderConfig: crowdinProviderConfig)
    .with(loginConfig: loginConfig)
    .with(settingsEnabled: true)
    .with(realtimeUpdatesEnabled: true)

CrowdinSDK.startWithConfig(crowdinSDKConfig, completion: {
	// SDK is ready to use, put code to change language, etc. here
})
```

<details>
<summary>Objective-C</summary>

```objective-c
CrowdinProviderConfig *crowdinProviderConfig = [[CrowdinProviderConfig alloc] initWithHashString:@"" sourceLanguage:@""];

NSError *error;
CrowdinLoginConfig *loginConfig = [[CrowdinLoginConfig alloc] initWithClientId:@"{client_id}" clientSecret:@"{client_secter}" scope:@"project" organizationName:@"{organization_name}" error:&error];

if (!error) {
	CrowdinSDKConfig *config = [[[CrowdinSDKConfig config] withCrowdinProviderConfig:crowdinProviderConfig] withLoginConfig:loginConfig];

	[CrowdinSDK startWithConfig:config completion:^{
		// SDK is ready to use, put code to change language, etc. here
	}];
} else {
	NSLog(@"%@", error.localizedDescription);
	// CrowdinLoginConfig initialization error handling, typically for empty values and for wrong redirect URI value.
}
```
</details>


| Config option              | Description                                                         | Example                                               |
|----------------------------|---------------------------------------------------------------------|-------------------------------------------------------|
| `hashString`               | Distribution Hash                                                   |`hashString: "7a0c1ee2622bc85a4030297uo3b"`
| `sourceLanguage`           | Source language code in your Crowdin project. [ISO 639-1](http://www.loc.gov/standards/iso639-2/php/English_list.php) | `sourceLanguage: "en"`
| `clientId`, `clientSecret` | Crowdin OAuth Client ID and Client Secret | `clientId: "gpY2yTbCVGEelrcx3TYB"`, `clientSecret: "Xz95t0ASVgbvKaZbFB4SMHQzdUl1MSgSTabEDx9T"`
| `scope`                    | Define the access scope for personal tokens | `scope: "project"`
| `redirectURI`              | A custom URL for your app. Read more in the [article](https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app). It's an optional value. You should set it in case you want to use a specific URL scheme. In case you set a scheme which is not supported by your application init method will throw an exception.  | `redirectURI: "crowdintest://"`
| `organizationName`         | An Organization domain name (for Crowdin Enterprise users only) | `organizationName: "mycompany"`
| `settingsEnabled`          | Enable [floating widget](https://github.com/crowdin/mobile-sdk-ios/wiki/SDK-Controls) to easily access the features of SDK | `settingsEnabled: true`
| `realtimeUpdatesEnabled`   | Enable Real-Time Preview feature | `realtimeUpdatesEnabled: true`

The last step is to handle authorization callback in your application:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
	guard let url = URLContexts.first?.url else { return }
	CrowdinSDK.handle(url: url)
}
```

<details>
<summary>Objective-C</summary>

```objective-c
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    return [CrowdinSDK handleWithUrl:url];
}
```
</details>

If you are using **SceneDelegate**, you need to handle callback in the **SceneDelegate**  class implement method:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
	guard let url = URLContexts.first?.url else { return }
	CrowdinSDK.handle(url: url)
}
```

<details>
<summary>Objective-C</summary>

```objective-c
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    return [CrowdinSDK handleWithUrl:url];
}
```
</details>

### Screenshots

Enable if you want all the screenshots made in the application to be automatically sent to your Crowdin project with tagged strings. This will provide additional context for translators.

[<p align='center'><img src='https://github.com/crowdin/mobile-sdk-ios/blob/docs/sdk_screenshots.gif' width='500'/></p>](#)

Add the code below to your *Podfile*:

```swift
use_frameworks!
target 'your-app' do
  pod 'CrowdinSDK'
  pod 'CrowdinSDK/LoginFeature' // Required for Screenshots
  pod 'CrowdinSDK/Screenshots' // Required for Screenshots
  pod 'CrowdinSDK/Settings' // Optional. To add 'settings' button
end
```

Open *AppDelegate.swift* file and in `application` method add:

```swift
let crowdinProviderConfig = CrowdinProviderConfig(hashString: "{your_distribution_hash}",
    sourceLanguage: "{source_language}")

var loginConfig: CrowdinLoginConfig
do {
	loginConfig = try CrowdinLoginConfig(clientId: "{client_id}",
		clientSecret: "{client_secret}",
		scope: "project.screenshot",
		redirectURI: "{redirectURI}",
		organizationName: "{organization_name}")
} catch {
	print(error)
	// CrowdinLoginConfig initialization error handling, typically for empty values and for wrong redirect URI value.
}

let crowdinSDKConfig = CrowdinSDKConfig.config().with(crowdinProviderConfig: crowdinProviderConfig)
    .with(screenshotsEnabled: true)
    .with(loginConfig: loginConfig)
    .with(settingsEnabled: true)

CrowdinSDK.startWithConfig(crowdinSDKConfig, completion: {
	// SDK is ready to use, put code to change language, etc. here
})
```

<details>
<summary>Objective-C</summary>

```objective-c
CrowdinProviderConfig *crowdinProviderConfig = [[CrowdinProviderConfig alloc] initWithHashString:@"" sourceLanguage:@""];

NSError *error;
CrowdinLoginConfig *loginConfig = [[CrowdinLoginConfig alloc] initWithClientId:@"{client_id}" clientSecret:@"{client_secter}" scope:@"project.screenshot" organizationName:@"{organization_name}" error:&error];

if (!error) {
	CrowdinSDKConfig *config = [[[CrowdinSDKConfig config] withCrowdinProviderConfig:crowdinProviderConfig] withLoginConfig:loginConfig];

	[CrowdinSDK startWithConfig:config completion:^{
		// SDK is ready to use, put code to change language, etc. here
	}];
} else {
	NSLog(@"%@", error.localizedDescription);
	// CrowdinLoginConfig initialization error handling, typically for empty values and for wrong redirect URI value.
}
```
</details>


| Config option              | Description                                                         | Example                                               |
|----------------------------|---------------------------------------------------------------------|-------------------------------------------------------|
| `hashString`               | Distribution Hash                                                   |`hashString: "7a0c1ee2622bc85a4030297uo3b"`
| `sourceLanguage`           | Source language code in your Crowdin project. [ISO 639-1](http://www.loc.gov/standards/iso639-2/php/English_list.php) | `sourceLanguage: "en"`
| `clientId`, `clientSecret` | Crowdin OAuth Client ID and Client Secret | `clientId: "gpY2yTbCVGEelrcx3TYB"`, `clientSecret: "Xz95t0ASVgbvKaZbFB4SMHQzdUl1MSgSTabEDx9T"`
| `scope`                    | Define the access scope for personal tokens | `scope: "project.screenshot"`
| `redirectURI`              | A custom URL for your app. Read more in the [article](https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app). It's an optional value. You should set it in case you want to use a specific URL scheme. In case you set a scheme which is not supported by your application init method will throw an exception.  | `redirectURI: "crowdintest://"`
| `organizationName`         | An Organization domain name (for Crowdin Enterprise users only) | `organizationName: "mycompany"`
| `settingsEnabled`          | Enable [floating widget](https://github.com/crowdin/mobile-sdk-ios/wiki/SDK-Controls) to easily access the features of SDK | `settingsEnabled: true`
| `screenshotsEnabled`       | Enable Screenshots feature | `screenshotsEnabled: true`

The last step is to handle authorization callback in your application:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
	guard let url = URLContexts.first?.url else { return }
	CrowdinSDK.handle(url: url)
}
```

<details>
<summary>Objective-C</summary>

```objective-c
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    return [CrowdinSDK handleWithUrl:url];
}
```
</details>

If you are using **SceneDelegate**, you need to handle callback in the **SceneDelegate**  class implement method:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
	guard let url = URLContexts.first?.url else { return }
	CrowdinSDK.handle(url: url)
}
```

<details>
<summary>Objective-C</summary>

```objective-c

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    return [CrowdinSDK handleWithUrl:url];
}
```
</details>

You could also define (optional) your own handler to take a screenshot (for example, clicking on some button in your application):

```swift
let feature = ScreenshotFeature.shared {
	feature.captureScreenshot(name: String(Date().timeIntervalSince1970), success: {
	    CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .info, message: message))
	    self?.showToast(message)
	}, errorHandler: { (error) in
	    let message = "Error while capturing screenshot - \(error?.localizedDescription ?? "Unknown")"
	    CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .error, message: message))
	    self?.showToast(message)
	})
}
```

or even capture screenshots of a separate UIView.

## Notes

1. Configuring translation update interval

   By default SDK is looking for new translation once per application load every 15 minutes. You can update translations in application every defined time interval. To enable this feature add pod `CrowdinSDK/IntervalUpdate` to your pod file:

   ```swift
   pod 'CrowdinSDK/IntervalUpdate'
   ```

   Then enable this option in `CrowdinSDKConfig`:

   ```swift
   .with(intervalUpdatesEnabled: true, interval: {interval})
   ```

    `interval` - defines translations update time interval in seconds. Minimum allowed interval is 15 minutes.

2. R-Swift applications are also supported by Crowdin iOS SDK.

3. To change SDK target language on the fly regardless of device locale use the following method:

    ```swift
    CrowdinSDK.enableSDKLocalization(true, localization: “<language_code>”)
    ```
    
    `<language_code>` - target language code in [ISO 639-1](http://www.loc.gov/standards/iso639-2/php/English_list.php) format.

4. Currently, Language Mapping is not supported by iOS SDK.

5. Crowdin iOS SDK provides detailed debug mode - "Logs" tab in the Settings floating button module and logging into XCode console.
   To enable console logging, add the following option to your `CrowdinSDKConfig`
   
   ```swift
   .with(debugEnabled: true)
   ```
6. Log callback. Crowdin SDK collects log messages for all actions that made by SDK (login/logout, download languages, API calls). This callback returns Log text each time a new Log is created. To subscribe on receiving Log messages just add a new callback like this:

    ```swift
    CrowdinSDK.setOnLogCallback { logMessage in
       print("LOG MESSAGE - \(logMessage)")
    }
    ```

## File Export Patterns

You can set file export patterns and check existing ones using *File Settings*. The following placeholders are supported for iOS integration:

<table class="table table-bordered">
  <thead>
    <tr>
      <th>Name</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="vertical-align:middle">%language%</td>
      <td>Language name (e.g. Ukrainian)</td>
    </tr>
    <tr>
      <td style="vertical-align:middle">%locale%</td>
      <td>Locale (e.g. uk-UA)</td>
    </tr>
    <tr>
      <td style="vertical-align:middle">%two_letters_code%</td>
      <td>Language code ISO 639-1 (i.e. uk)</td>
    </tr>
    <tr>
      <td style="vertical-align:middle">%locale_with_underscore%</td>
      <td>Locale (e.g. uk_UA)</td>
    </tr>
      <tr>
      <td style="vertical-align:middle">%osx_code%</td>
      <td>OS X locale identifier used to name ".lproj" directories</td>
    </tr>
    <tr>
      <td style="vertical-align:middle">%osx_locale%</td>
      <td>OS X locale used to name translation resources (e.g. uk, zh-Hans, zh_HK)</td>
    </tr>
   </tbody>
</table>

## Contributing
If you want to contribute please read the [Contributing](/CONTRIBUTING.md) guidelines.

## Seeking Assistance
If you find any problems or would like to suggest a feature, please feel free to file an issue on Github at [Issues Page](https://github.com/crowdin/mobile-sdk-ios/issues).

Need help working with Crowdin iOS SDK or have any questions?
[Contact Customer Success Service](https://crowdin.com/contacts).

## Security

Crowdin iOS SDK CDN feature is built with security in mind, which means minimal access possible from the end-user is required. 
When you decide to use Crowdin iOS SDK, please make sure you’ve made the following information accessible to your end-users.

- We use the advantages of Amazon Web Services (AWS) for our computing infrastructure. AWS has ISO 27001 certification and has completed multiple SSAE 16 audits. All the translations are stored at AWS servers.
- When you use Crowdin iOS SDK CDN – translations are uploaded to Amazon CloudFront to be delivered to the app and speed up the download. Keep in mind that your users download translations without any additional authentication.
- We use encryption to keep your data private while in transit.
- We do not store any Personally Identifiable Information (PII) about the end-user, but you can decide to develop the opt-out option inside your application to make sure your users have full control.
- The Automatic Screenshots and Real-Time Preview features are supposed to be used by the development team and translators team. Those features should not be compiled to the production version of your app. Therefore, should not affect end-users privacy in any way. 

## Authors
- Serhii Londar, serhii.londar@gmail.com

## License
<pre>
The Crowdin iOS SDK is licensed under the MIT License. 
See the LICENSE file distributed with this work for additional 
information regarding copyright ownership.

Except as contained in the LICENSE file, the name(s) of the above copyright 
holders shall not be used in advertising or otherwise to promote the sale, 
use or other dealings in this Software without prior written authorization.
</pre>
