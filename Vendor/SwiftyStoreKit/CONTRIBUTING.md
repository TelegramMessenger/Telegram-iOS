# Contributing to SwiftyStoreKit

### All contributions to SwiftyStoreKit are welcome. 😎

This project is becoming widely adopted and its growth is now limited by the time the main maintainer can allocate.

Going forward, the aim is to **transfer some of the maintainance and development effort to the community**.

If you want to help developing SwiftyStoreKit, please look for issues marked with a blue **contributions welcome** label. See [this issue](https://github.com/bizz84/SwiftyStoreKit/issues/192) for an example.

The maintainer will use this label initially for simple tasks that are appropriate for beginners and first time contributors.

As the project and its community grows:

* intermediate and advanced tasks will be opened up to contributors
* most experienced contributors will be able to gain **admin** rights to review and merge pull requests

**Note**: While the maintainer(s) try to regularly keep the project alive and healthy, issues and pull requests are not always reviewed in a timely manner. 🕰

## Scope

SwiftyStoreKit aims to be a lightweight wrapper on top of [StoreKit](https://developer.apple.com/reference/storekit).

While SwiftyStoreKit offers access to the [local receipt data](https://developer.apple.com/reference/foundation/bundle/1407276-appstorereceipturl), it is a non-goal to add support for persisting IAP data locally. It is up to clients to do this with a storage solution of choice (i.e. NSUserDefaults, CoreData, Keychain).

**Swift Version**: SwiftyStoreKit includes [Swift 2.3](https://github.com/bizz84/SwiftyStoreKit/tree/swift-2.3) and [Swift 2.2](https://github.com/bizz84/SwiftyStoreKit/tree/swift-2.2) branches. These legacy versions are no longer maintained and all active development happens on [master](https://github.com/bizz84/SwiftyStoreKit) and [develop](https://github.com/bizz84/SwiftyStoreKit/tree/develop), which support Swift 3.x and Swift 4.x.

**Objective-C**: Currently, SwiftyStoreKit cannot be used in Objective-C projects. The main limitation is that most classes and types in the library are Swift-only. See [related issue](https://github.com/bizz84/SwiftyStoreKit/issues/123).

## Pull requests

The project uses [gitflow](http://nvie.com/posts/a-successful-git-branching-model/) as a branching model.

In short:

* All pull requests for **new features** and **bug fixes** should be made into the `develop` branch.
* Pull requests for **hot fixes** can be done into both `master` and `develop`.
* The maintainer(s) will merge `develop` into `master` and create a release tag as new features are added.
* All releases [can be found here](https://github.com/bizz84/SwiftyStoreKit/releases).

## Open Features / Enhancement Requests

These are intermediate / advanced tasks that will hopefully be implemented in the future:

### Local Receipt validation

SwiftyStoreKit offers a reference implementation for [receipt validation with Apple](https://github.com/bizz84/SwiftyStoreKit/blob/master/SwiftyStoreKit/AppleReceiptValidator.swift).

This could be extended by implementing local receipt validation as recommended by Apple. See [related issue](https://github.com/bizz84/SwiftyStoreKit/issues/101).

### Support for content hosted by Apple for non-consumable products

See [related issue](https://github.com/bizz84/SwiftyStoreKit/issues/128).

### Increase unit test coverage

The payment flows are unit tested fairly extensively. Additional unit test coverage is welcome:

- [ ] Dependency injection for SwiftyStoreKit dependencies
- [ ] Unit tests on main [SwiftyStoreKit class](https://github.com/bizz84/SwiftyStoreKit/blob/master/SwiftyStoreKit/SwiftyStoreKit.swift).
- [ ] Unit tests for receipt verification code.

See [related issue](https://github.com/bizz84/SwiftyStoreKit/issues/38).


## Issues

If SwiftyStoreKit doesn't work as you expect, please review [any open issues](https://github.com/bizz84/SwiftyStoreKit/issues) before opening a new one.

