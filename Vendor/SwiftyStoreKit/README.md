<img src="https://github.com/bizz84/SwiftyStoreKit/raw/master/SwiftyStoreKit-logo.png" width=100%>

[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://mit-license.org)
[![Platform](http://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg?style=flat)](https://developer.apple.com/resources/)
[![Language](https://img.shields.io/badge/swift-5.0-orange.svg)](https://developer.apple.com/swift)
[![Build](https://img.shields.io/travis/bizz84/SwiftyStoreKit.svg?style=flat)](https://travis-ci.org/bizz84/SwiftyStoreKit)
[![Issues](https://img.shields.io/github/issues/bizz84/SwiftyStoreKit.svg?style=flat)](https://github.com/bizz84/SwiftyStoreKit/issues)
[![Slack](https://img.shields.io/badge/Slack-Join-green.svg?style=flat)](https://join.slack.com/t/swiftystorekit/shared_invite/enQtODY3OTYxOTExMzE5LWVkNGY4MzcwY2VjNGM4MGU4NDFhMGE5YmUxMGM3ZTQ4NjVjNTRkNTJhNDAyMWZmY2M5OWE5MDE0ODc3OGJjMmM)

SwiftyStoreKit is a lightweight In App Purchases framework for iOS, tvOS, watchOS, macOS, and Mac Catalyst.

## Features
- Super easy-to-use block-based API
- Support for consumable and non-consumable in-app purchases
- Support for free, auto-renewable and non-renewing subscriptions
- Support for in-app purchases started in the App Store (iOS 11)
- Support for subscription discounts and offers
- Remote receipt verification
- Verify purchases, subscriptions, subscription groups
- Downloading content hosted with Apple
- iOS, tvOS, watchOS, macOS, and Catalyst compatible

## UPDATE: SwiftyStoreKit to RevenueCat Migration Guide
During WWDC21, Apple introduced [StoreKit 2](https://developer.apple.com/videos/play/wwdc2021/10114/), a brand new Swift API for in-app purchases and auto-renewable subscriptions. 

While it would be highly desirable to support StoreKit 2 in this project, [little progress](https://github.com/bizz84/SwiftyStoreKit/issues/550) has been made over the last year and most issues [remain unanswered](https://github.com/bizz84/SwiftyStoreKit/issues).

The good news is that [RevenueCat](https://www.revenuecat.com/) is a great alternative to SwiftyStoreKit, offering great APIs, support, and much more at a very [reasonable price](https://www.revenuecat.com/pricing).

If you've been using SwiftyStoreKit and want to migrate to RevenueCat, this guide covers everything you need:

- [SwiftyStoreKit Migration](https://docs.revenuecat.com/docs/swiftystorekit)

Or if you're just getting started, consider skipping SwiftyStoreKit altogether and signing up for [RevenueCat](https://www.revenuecat.com/).

Alternatively, you can also check out [Glassfy](https://glassfy.io/), which also makes it easy to handle in-app subscriptions and much more (here is their [pricing page](https://glassfy.io/pricing.html)).

## Contributions Wanted
SwiftyStoreKit makes it easy for an incredible number of developers to seemlessly integrate in-App Purchases. This project, however, is now **community-led**. We need help building out features and writing tests (see [issue #550](https://github.com/bizz84/SwiftyStoreKit/issues/550)).

### Maintainers Wanted
The author is no longer maintaining this project actively. If you'd like to become a maintainer, [join the Slack workspace](https://join.slack.com/t/swiftystorekit/shared_invite/enQtODY3OTYxOTExMzE5LWVkNGY4MzcwY2VjNGM4MGU4NDFhMGE5YmUxMGM3ZTQ4NjVjNTRkNTJhNDAyMWZmY2M5OWE5MDE0ODc3OGJjMmM) and enter the [#maintainers](https://app.slack.com/client/TL2JYQ458/CLG62K26A/details/) channel.
Going forward, SwiftyStoreKit should be made for the community, by the community. 

More info here: [The Future of SwiftyStoreKit: Maintainers Wanted](https://medium.com/@biz84/the-future-of-swiftystorekit-maintainers-needed-f60d01572c91).

## Requirements
If you've shipped an app in the last five years, you're probably good to go. Some features (like discounts) are only available on new OS versions, but most features are available as far back as:

| iOS | watchOS | tvOS | macOS | Mac Catalyst |
| --- | ------- | ---- | ----- | ------------ |
| 8.0 | 6.2     | 9.0  | 10.10 | 13.0         |

## Installation
There are a number of ways to install SwiftyStoreKit for your project. Swift Package Manager, CocoaPods, and Carthage integrations are the preferred and recommended approaches.

Regardless, make sure to import the project wherever you may use it:

```swift
import SwiftyStoreKit
```

### Swift Package Manager
The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into Xcode and the Swift compiler. **This is the recommended installation method.** Updates to SwiftyStoreKit will always be available immediately to projects with SPM. SPM is also integrated directly with Xcode.

If you are using Xcode 11 or later:
 1. Click `File`
 2. `Swift Packages`
 3. `Add Package Dependency...`
 4. Specify the git URL for SwiftyStoreKit.

```swift
https://github.com/bizz84/SwiftyStoreKit.git
```

### Carthage
To integrate SwiftyStoreKit into your Xcode project using [Carthage](https://github.com/Carthage/Carthage), specify it in your Cartfile:

```ogdl
github "bizz84/SwiftyStoreKit"
```

**NOTE**: Please ensure that you have the [latest](https://github.com/Carthage/Carthage/releases) Carthage installed.

### CocoaPods
SwiftyStoreKit can be installed as a [CocoaPod](https://cocoapods.org/) and builds as a Swift framework. To install, include this in your Podfile.

```ruby
use_frameworks!

pod 'SwiftyStoreKit'
```

## Contributing
Got issues / pull requests / want to contribute? [Read here](CONTRIBUTING.md).

# Documentation
Full documentation is available on the [SwiftyStoreKit Wiki](https://github.com/bizz84/SwiftyStoreKit/wiki). As SwiftyStoreKit (and Apple's StoreKit) gains features, platforms, and implementation approaches, new information will be added to the Wiki. Essential documentation is available here in the README and should be enough to get you up and running.

## App startup

### Complete Transactions

Apple recommends to register a transaction observer [as soon as the app starts](https://developer.apple.com/library/ios/technotes/tn2387/_index.html):
> Adding your app's observer at launch ensures that it will persist during all launches of your app, thus allowing your app to receive all the payment queue notifications.

SwiftyStoreKit supports this by calling `completeTransactions()` when the app starts:

```swift
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
	// see notes below for the meaning of Atomic / Non-Atomic
	SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
	    for purchase in purchases {
	        switch purchase.transaction.transactionState {
	        case .purchased, .restored:
	            if purchase.needsFinishTransaction {
	                // Deliver content from server, then:
	                SwiftyStoreKit.finishTransaction(purchase.transaction)
	            }
	            // Unlock content
	        case .failed, .purchasing, .deferred:
	            break // do nothing
	        }
	    }
	}
    return true
}
```

If there are any pending transactions at this point, these will be reported by the completion block so that the app state and UI can be updated.

If there are no pending transactions, the completion block will **not** be called.

Note that `completeTransactions()` **should only be called once** in your code, in `application(:didFinishLaunchingWithOptions:)`.

## Purchases

### Retrieve products info
```swift
SwiftyStoreKit.retrieveProductsInfo(["com.musevisions.SwiftyStoreKit.Purchase1"]) { result in
    if let product = result.retrievedProducts.first {
        let priceString = product.localizedPrice!
        print("Product: \(product.localizedDescription), price: \(priceString)")
    }
    else if let invalidProductId = result.invalidProductIDs.first {
        print("Invalid product identifier: \(invalidProductId)")
    }
    else {
        print("Error: \(result.error)")
    }
}
```

### Purchase a product (given a product id)

* **Atomic**: to be used when the content is delivered immediately.

```swift
SwiftyStoreKit.purchaseProduct("com.musevisions.SwiftyStoreKit.Purchase1", quantity: 1, atomically: true) { result in
    switch result {
    case .success(let purchase):
        print("Purchase Success: \(purchase.productId)")
    case .error(let error):
        switch error.code {
        case .unknown: print("Unknown error. Please contact support")
        case .clientInvalid: print("Not allowed to make the payment")
        case .paymentCancelled: break
        case .paymentInvalid: print("The purchase identifier was invalid")
        case .paymentNotAllowed: print("The device is not allowed to make the payment")
        case .storeProductNotAvailable: print("The product is not available in the current storefront")
        case .cloudServicePermissionDenied: print("Access to cloud service information is not allowed")
        case .cloudServiceNetworkConnectionFailed: print("Could not connect to the network")
        case .cloudServiceRevoked: print("User has revoked permission to use this cloud service")
        default: print((error as NSError).localizedDescription)
        }
    }
}
```

* **Non-Atomic**: to be used when the content is delivered by the server.

```swift
SwiftyStoreKit.purchaseProduct("com.musevisions.SwiftyStoreKit.Purchase1", quantity: 1, atomically: false) { result in
    switch result {
    case .success(let product):
        // fetch content from your server, then:
        if product.needsFinishTransaction {
            SwiftyStoreKit.finishTransaction(product.transaction)
        }
        print("Purchase Success: \(product.productId)")
    case .error(let error):
        switch error.code {
        case .unknown: print("Unknown error. Please contact support")
        case .clientInvalid: print("Not allowed to make the payment")
        case .paymentCancelled: break
        case .paymentInvalid: print("The purchase identifier was invalid")
        case .paymentNotAllowed: print("The device is not allowed to make the payment")
        case .storeProductNotAvailable: print("The product is not available in the current storefront")
        case .cloudServicePermissionDenied: print("Access to cloud service information is not allowed")
        case .cloudServiceNetworkConnectionFailed: print("Could not connect to the network")
        case .cloudServiceRevoked: print("User has revoked permission to use this cloud service")
        default: print((error as NSError).localizedDescription)
        }
    }
}
```

### Additional Purchase Documentation
These additional topics are available on the Wiki:
- [Purchase a product (given a SKProduct)](https://github.com/bizz84/SwiftyStoreKit/wiki/Purchasing#purchase-a-product-given-a-skproduct)
- [Handle purchases started on the App Store (iOS 11)](https://github.com/bizz84/SwiftyStoreKit/wiki/App-Store-Purchases)

### Restore Previous Purchases

According to [Apple - Restoring Purchased Products](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/StoreKitGuide/Chapters/Restoring.html#//apple_ref/doc/uid/TP40008267-CH8-SW9):

> In most cases, all your app needs to do is refresh its receipt and deliver the products in its receipt. The refreshed receipt contains a record of the user’s purchases in this app, on this device or any other device.
>
> Restoring completed transactions creates a new transaction for every completed transaction the user made, essentially replaying history for your transaction queue observer.

See the **Receipt Verification** section below for how to restore previous purchases using the receipt.

This section shows how to restore completed transactions with the `restorePurchases` method instead. When successful, the method returns all non-consumable purchases, as well as all auto-renewable subscription purchases, **regardless of whether they are expired or not**.

* **Atomic**: to be used when the content is delivered immediately.

```swift
SwiftyStoreKit.restorePurchases(atomically: true) { results in
    if results.restoreFailedPurchases.count > 0 {
        print("Restore Failed: \(results.restoreFailedPurchases)")
    }
    else if results.restoredPurchases.count > 0 {
        print("Restore Success: \(results.restoredPurchases)")
    }
    else {
        print("Nothing to Restore")
    }
}
```

* **Non-Atomic**: to be used when the content is delivered by the server.

```swift
SwiftyStoreKit.restorePurchases(atomically: false) { results in
    if results.restoreFailedPurchases.count > 0 {
        print("Restore Failed: \(results.restoreFailedPurchases)")
    }
    else if results.restoredPurchases.count > 0 {
        for purchase in results.restoredPurchases {
            // fetch content from your server, then:
            if purchase.needsFinishTransaction {
                SwiftyStoreKit.finishTransaction(purchase.transaction)
            }
        }
        print("Restore Success: \(results.restoredPurchases)")
    }
    else {
        print("Nothing to Restore")
    }
}
```

#### What does atomic / non-atomic mean?
For more information about atomic vs. non-atomic restorations, [view the Wiki page here](https://github.com/bizz84/SwiftyStoreKit/wiki/Restoring#what-does-atomic--non-atomic-mean).

### Downloading content hosted with Apple
More information about downloading hosted content is [available on the Wiki](https://github.com/bizz84/SwiftyStoreKit/wiki/Downloading-Content).

To start downloads (this can be done in `purchaseProduct()`, `completeTransactions()` or `restorePurchases()`):

```swift
SwiftyStoreKit.purchaseProduct("com.musevisions.SwiftyStoreKit.Purchase1", quantity: 1, atomically: false) { result in
    switch result {
    case .success(let product):
        let downloads = purchase.transaction.downloads
        if !downloads.isEmpty {
            SwiftyStoreKit.start(downloads)
        }
    case .error(let error):
        print("\(error)")
    }
}
```

To check the updated downloads, setup a `updatedDownloadsHandler` block in your AppDelegate:

```swift
SwiftyStoreKit.updatedDownloadsHandler = { downloads in
    // contentURL is not nil if downloadState == .finished
    let contentURLs = downloads.flatMap { $0.contentURL }
    if contentURLs.count == downloads.count {
        // process all downloaded files, then finish the transaction
        SwiftyStoreKit.finishTransaction(downloads[0].transaction)
    }
}
```

To control the state of the downloads, SwiftyStoreKit offers `start()`, `pause()`, `resume()`, `cancel()` methods.

## Receipt verification

This helper can be used to retrieve the (encrypted) local receipt data:

```swift
let receiptData = SwiftyStoreKit.localReceiptData
let receiptString = receiptData.base64EncodedString(options: [])
// do your receipt validation here
```

However, the receipt file may be missing or outdated. Use this method to get the updated receipt:

```swift
SwiftyStoreKit.fetchReceipt(forceRefresh: true) { result in
    switch result {
    case .success(let receiptData):
        let encryptedReceipt = receiptData.base64EncodedString(options: [])
        print("Fetch receipt success:\n\(encryptedReceipt)")
    case .error(let error):
        print("Fetch receipt failed: \(error)")
    }
}
```

Use this method to (optionally) refresh the receipt and perform validation in one step.

```swift
let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: "your-shared-secret")
SwiftyStoreKit.verifyReceipt(using: appleValidator, forceRefresh: false) { result in
    switch result {
    case .success(let receipt):
        print("Verify receipt success: \(receipt)")
    case .error(let error):
        print("Verify receipt failed: \(error)")
    }
}
```

Additional details about receipt verification are [available on the wiki](https://github.com/bizz84/SwiftyStoreKit/wiki/Verify-Receipt).

## Verifying purchases and subscriptions
Once you have retrieved the receipt using the `verifyReceipt` method, you can verify your purchases and subscriptions by product identifier.

### Verify Purchase

```swift
let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: "your-shared-secret")
SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
    switch result {
    case .success(let receipt):
        let productId = "com.musevisions.SwiftyStoreKit.Purchase1"
        // Verify the purchase of Consumable or NonConsumable
        let purchaseResult = SwiftyStoreKit.verifyPurchase(
            productId: productId,
            inReceipt: receipt)
            
        switch purchaseResult {
        case .purchased(let receiptItem):
            print("\(productId) is purchased: \(receiptItem)")
        case .notPurchased:
            print("The user has never purchased \(productId)")
        }
    case .error(let error):
        print("Receipt verification failed: \(error)")
    }
}
```

### Verify Subscription
This can be used to check if a subscription was previously purchased, and whether it is still active or if it's expired.

From [Apple - Working with Subscriptions](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/StoreKitGuide/Chapters/Subscriptions.html#//apple_ref/doc/uid/TP40008267-CH7-SW6):

> Keep a record of the date that each piece of content is published. Read the Original Purchase Date and Subscription Expiration Date field from each receipt entry to determine the start and end dates of the subscription.

When one or more subscriptions are found for a given product id, they are returned as a `ReceiptItem` array ordered by `expiryDate`, with the first one being the newest.

```swift
let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: "your-shared-secret")
SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
    switch result {
    case .success(let receipt):
        let productId = "com.musevisions.SwiftyStoreKit.Subscription"
        // Verify the purchase of a Subscription
        let purchaseResult = SwiftyStoreKit.verifySubscription(
            ofType: .autoRenewable, // or .nonRenewing (see below)
            productId: productId,
            inReceipt: receipt)
            
        switch purchaseResult {
        case .purchased(let expiryDate, let items):
            print("\(productId) is valid until \(expiryDate)\n\(items)\n")
        case .expired(let expiryDate, let items):
            print("\(productId) is expired since \(expiryDate)\n\(items)\n")
        case .notPurchased:
            print("The user has never purchased \(productId)")
        }

    case .error(let error):
        print("Receipt verification failed: \(error)")
    }
}
```

Further documentation on verifying subscriptions is [available on the wiki](https://github.com/bizz84/SwiftyStoreKit/wiki/Verify-Subscription).

### Subscription Groups

From [Apple Docs - Offering Subscriptions](https://developer.apple.com/app-store/subscriptions/):

> A subscription group is a set of in-app purchases that you can create to provide users with a range of content offerings, service levels, or durations to best meet their needs. Users can only buy one subscription within a subscription group at a time. If users would want to buy more that one type of subscription — for example, to subscribe to more than one channel in a streaming app — you can put these in-app purchases in different subscription groups.

You can verify all subscriptions within the same group with the `verifySubscriptions` method. [Learn more on the wiki](https://github.com/bizz84/SwiftyStoreKit/wiki/Subscription-Groups).


## Notes
The framework provides a simple block based API with robust error handling on top of the existing StoreKit framework. It does **NOT** persist in app purchases data locally. It is up to clients to do this with a storage solution of choice (i.e. NSUserDefaults, CoreData, Keychain).

## Change Log
See the [Releases Page](https://github.com/bizz84/SwiftyStoreKit/releases).

## Sample Code
The project includes demo apps [for iOS](https://github.com/bizz84/SwiftyStoreKit/blob/master/SwiftyStoreKit-iOS-Demo/ViewController.swift) [and macOS](https://github.com/bizz84/SwiftyStoreKit/blob/master/SwiftyStoreKit-macOS-Demo/ViewController.swift) showing how to use SwiftyStoreKit.
Note that the pre-registered in app purchases in the demo apps are for illustration purposes only and may not work as iTunes Connect may invalidate them.

## Essential Reading
* [Apple - WWDC16, Session 702: Using Store Kit for In-app Purchases with Swift 3](https://developer.apple.com/videos/play/wwdc2016/702/)
* [Apple - TN2387: In-App Purchase Best Practices](https://developer.apple.com/library/content/technotes/tn2387/_index.html)
* [Apple - TN2413: In-App Purchase FAQ](https://developer.apple.com/library/content/technotes/tn2413/_index.html) (also see [Cannot connect to iTunes Store](https://developer.apple.com/library/content/technotes/tn2413/_index.html#//apple_ref/doc/uid/DTS40016228-CH1-ERROR_MESSAGES-CANNOT_CONNECT_TO_ITUNES_STORE))
* [Apple - TN2259: Adding In-App Purchase to Your Applications](https://developer.apple.com/library/content/technotes/tn2259/_index.html)
* [iTunes Connect Developer Help - Workflow for configuring in-app purchases](https://help.apple.com/itunes-connect/developer/#/devb57be10e7)
* [Apple - About Receipt Validation](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Introduction.html)
* [Apple - Receipt Validation Programming Guide](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html#//apple_ref/doc/uid/TP40010573-CH106-SW1)
* [Apple - Validating Receipts Locally](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html)
* [Apple - Working with Subscriptions](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/StoreKitGuide/Chapters/Subscriptions.html#//apple_ref/doc/uid/TP40008267-CH7-SW6)
* [Apple - Offering Subscriptions](https://developer.apple.com/app-store/subscriptions/)
* [Apple - Restoring Purchased Products](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/StoreKitGuide/Chapters/Restoring.html#//apple_ref/doc/uid/TP40008267-CH8-SW9)
* [Apple - Testing In-App Purchase Products](https://developer.apple.com/library/content/documentation/LanguagesUtilities/Conceptual/iTunesConnectInAppPurchase_Guide/Chapters/TestingInAppPurchases.html): includes info on duration of subscriptions in sandbox mode
* [objc.io - Receipt Validation](https://www.objc.io/issues/17-security/receipt-validation/)

I have also written about building SwiftyStoreKit on Medium:

* [How I got 1000 ⭐️ on my GitHub Project](https://medium.com/ios-os-x-development/how-i-got-1000-%EF%B8%8F-on-my-github-project-654d3d394ca6#.1idp27olf)
* [Maintaining a Growing Open Source Project](https://medium.com/@biz84/maintaining-a-growing-open-source-project-1d385ca84c5#.4cv2g7tdc)

### Troubleshooting 
* [Apple TN 2413 - Why are my product identifiers being returned in the invalidProductIdentifiers array?](https://developer.apple.com/library/content/technotes/tn2413/_index.html#//apple_ref/doc/uid/DTS40016228-CH1-TROUBLESHOOTING-WHY_ARE_MY_PRODUCT_IDENTIFIERS_BEING_RETURNED_IN_THE_INVALIDPRODUCTIDENTIFIERS_ARRAY_)
* [Invalid Product IDs](http://troybrant.net/blog/2010/01/invalid-product-ids/): Checklist of common mistakes
* [Testing Auto-Renewable Subscriptions on iOS](http://davidbarnard.com/post/164337147440/testing-auto-renewable-subscriptions-on-ios)
* [Apple forums - iOS 11 beta sandbox - cannot connect to App Store](https://forums.developer.apple.com/message/261428#261428)

## Video Tutorials

#### Jared Davidson: In App Purchases! (Swift 3 in Xcode : Swifty Store Kit)

<a href="https://www.youtube.com/watch?v=dwPFtwDJ7tcb"><img src="https://raw.githubusercontent.com/bizz84/SwiftyStoreKit/master/Screenshots/VideoTutorial-JaredDavidson.jpg" width="50%" /></a>

#### [@rebeloper](https://github.com/rebeloper): Ultimate In-app Purchases Guide

<a href="https://www.youtube.com/watch?v=MP-U5gQylHc"><img src="https://user-images.githubusercontent.com/2488011/65576278-55cccc80-df7a-11e9-8db5-244e2afa3e46.png" width="50%" /></a>

## Written Tutorials

* [In App Purchase (IAP) made simple with SwiftyStoreKit](https://levelup.gitconnected.com/beginner-ios-dev-in-app-purchase-iap-made-simple-with-swiftystorekit-3add60e9065d)

## Credits
Many thanks to [phimage](https://github.com/phimage) for adding macOS support and receipt verification.

## Apps using SwiftyStoreKit

It would be great to showcase apps using SwiftyStoreKit here. Pull requests welcome :)

* [Every Plant, Ever](https://itunes.apple.com/us/app/every-plant-ever/id1433967019) - The sticker pack of every plant, ever.
* [Countdown](https://countdowns.download/ssk) - Countdown the days until your next vacation, deadline, or event
* [MDacne](https://itunes.apple.com/app/id1044050208) - Acne analysis and treatment
* [Pixel Picker](https://itunes.apple.com/app/id930804327) - Image Color Picker
* [KType](https://itunes.apple.com/app/id1037000234) - Space shooter game
* [iPic](https://itunes.apple.com/app/id1101244278) - Automatically upload images and save Markdown links
* [iHosts](https://itunes.apple.com/app/id1102004240) - Perfect for editing /etc/hosts
* [Arise](http://www.abnehm-app.de/) - Calorie counter
* [Truth Truth Lie](https://itunes.apple.com/app/id1130832864) - iMessage game, featured by Apple
* [Tactus Music Player](https://itunes.apple.com/app/id557446352) - Alternative music player app
* [Drops](https://itunes.apple.com/app/id939540371) - Language learning app
* [Fresh Snow](https://itunes.apple.com/app/id1063000470) - Colorado Ski Report
* [Zmeu Grand Canyon](http://grandcanyon.zmeu.guide/) - Interactive hiking map & planner
* [OB Monitor](https://itunes.apple.com/app/id1073398446) - The app for Texas Longhorns athletics fans
* [Talk Dim Sum](https://itunes.apple.com/us/app/talk-dim-sum/id953929066) - Your dim sum companion
* [Sluggard](https://itunes.apple.com/app/id1160131071) - Perform simple exercises to reduce the risks of sedentary lifestyle
* [Debts iOS](https://debts.ivanvorobei.by/ios) & [Debts macOS](https://debts.ivanvorobei.by/macos) - Track amounts owed
* [Botcher](https://itunes.apple.com/us/app/id1522337788) - Good for finding something to do
* [Hashr](https://apps.apple.com/app/id1166499829) - Generate unique password hashes based on website and master password
* [QRFi](https://apps.apple.com/app/id1535761355) - Create stylish QR Codes for WiFi

A full list of apps is published [on AppSight](https://www.appsight.io/sdk/574154).
