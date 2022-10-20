<img src="/DeviceKit.svg" height="128">

[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/devicekit/DeviceKit/master/LICENSE)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/DeviceKit.svg)](https://cocoapods.org/pods/DeviceKit)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![codecov](https://codecov.io/gh/devicekit/DeviceKit/branch/master/graph/badge.svg)](https://codecov.io/gh/devicekit/DeviceKit)
[![CocoaPods](https://img.shields.io/cocoapods/dt/DeviceKit.svg)](https://cocoapods.org/pods/DeviceKit)
[![Maintainability](https://api.codeclimate.com/v1/badges/844e23a17bde71ff6be1/maintainability)](https://codeclimate.com/github/devicekit/DeviceKit/maintainability)
[![Platform](https://img.shields.io/cocoapods/p/DeviceKit.svg?style=flat)](http://cocoadocs.org/docsets/DeviceKit)


| Branch | Build Status | Versions |
|:---------|:--------------:|:----------:|
| **master** |[![Build Status](https://travis-ci.org/devicekit/DeviceKit.svg?branch=master)](https://travis-ci.org/devicekit/DeviceKit)| ≥ 2.0 |
| **Swift 4 - 4.2** |[![Build Status](https://travis-ci.org/devicekit/DeviceKit.svg?branch=swift-4)](https://travis-ci.org/devicekit/DeviceKit)| ≥ 1.3 < 1.13 |
| **Swift 3** |[![Build Status](https://travis-ci.org/devicekit/DeviceKit.svg?branch=swift-3)](https://travis-ci.org/devicekit/DeviceKit)| ≥ 1.0 < 1.3 |
| **Swift 2.3** |[![Build Status](https://travis-ci.org/devicekit/DeviceKit.svg?branch=swift-2.3-unsupported)](https://travis-ci.org/devicekit/DeviceKit)| < 1.0 |

`DeviceKit` is a value-type replacement of [`UIDevice`](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIDevice_Class/).

## Current version 4.5.2
See our detailed [changelog](CHANGELOG.md) for the latest features, improvements and bug fixes.

## Features

- [x] Equatable
- [x] Device identification
- [x] Device family detection
- [x] Device group detection
- [x] Simulator detection
- [x] Battery state
- [x] Battery level
- [x] Various device metrics (e.g. screen size, screen ratio, PPI)
- [x] Low Power Mode detection
- [x] Guided Access Session detection
- [x] Screen brightness
- [x] Display Zoom detection
- [x] Detect available sensors (Touch ID, Face ID)
- [x] Detect available disk space
- [x] Apple Pencil support detection

## Requirements

- iOS 9.0+ (linking against iOS 9.3 required)
- tvOS 9.0+ (linking against tvOS 9.2 required)
- watchOS 2.0+

## Installation
DeviceKit can be installed in various ways.

### CocoaPods

#### Swift 5
```ruby
pod 'DeviceKit', '~> 4.0'
```
#### iOS 8.0 support
```ruby
pod 'DeviceKit', '3.2'
```
#### Swift 4.0 - Swift 4.2
```ruby
pod 'DeviceKit', '~> 1.3'
```
#### Swift 3
```ruby
pod 'DeviceKit', '~> 1.2.3'
```
#### Swift 2.3 (Unsupported)
```ruby
pod 'DeviceKit', :git => 'https://github.com/devicekit/DeviceKit.git', :branch => 'swift-2.3-unsupported'
```

### Swift Package Manager

#### Swift 5
```swift
dependencies: [
    .package(url: "https://github.com/devicekit/DeviceKit.git", from: "4.0.0"),
    /// ...
]
```
#### iOS 8.0 support
```swift
dependencies: [
    .package(url: "https://github.com/devicekit/DeviceKit.git", from: "3.2.0"),
    /// ...
]
```

### Carthage

#### Swift 5
```ogdl
github "devicekit/DeviceKit" ~> 4.0
```
#### iOS 8.0 support
```ogdl
github "devicekit/DeviceKit" ~> 3.2
```
#### Swift 4.0 - Swift 4.2
```ogdl
github "devicekit/DeviceKit" ~> 1.3
```
#### Swift 3
```ogdl
github "devicekit/DeviceKit" ~> 1.2.3
```
#### Swift 2.3 (Unsupported)
```ogdl
github "devicekit/DeviceKit" "swift-2.3-unsupported"
```

### Manually
To install it manually, drag the `DeviceKit` project into your app project in Xcode. Or add it as a git submodule by running:
```bash
$ git submodule add https://github.com/devicekit/DeviceKit.git
```

## Usage
First make sure to import the framework:
```swift
import DeviceKit
```

Here are some usage examples. All devices are also available as simulators:
```swift
.iPhone6 => .simulator(.iPhone6)
.iPhone6s => .simulator(.iPhone6s)
```

You can try these examples in Playground.

**Note:**

> To try DeviceKit in the playground, open the `DeviceKit.xcworkspace` and build DeviceKit.framework for any simulator first by selecting "DeviceKit" as your current scheme.

### Get the Device You're Running On
```swift
let device = Device.current

print(device)     // prints, for example, "iPhone 6 Plus"

if device == .iPhone6Plus {
  // Do something
} else {
  // Do something else
}
```

### Get the Device Family
```swift
let device = Device.current
if device.isPod {
  // iPods (real or simulator)
} else if device.isPhone {
  // iPhone (real or simulator)
} else if device.isPad {
  // iPad (real or simulator)
}
```

### Check If Running on Simulator
```swift
let device = Device.current
if device.isSimulator {
  // Running on one of the simulators(iPod/iPhone/iPad)
  // Skip doing something irrelevant for Simulator
} 
```

### Get the Simulator Device
```swift
let device = Device.current
switch device {
case .simulator(.iPhone6s): break // You're running on the iPhone 6s simulator
case .simulator(.iPadAir2): break // You're running on the iPad Air 2 simulator
default: break
}
```
 
### Make Sure the Device Is Contained in a Preconfigured Group
```swift
let groupOfAllowedDevices: [Device] = [.iPhone6, .iPhone6Plus, .iPhone6s, .iPhone6sPlus, .simulator(.iPhone6), .simulator(.iPhone6Plus),.simulator(.iPhone6s),.simulator(.iPhone6sPlus).simulator(.iPhone8),.simulator(.iPhone8Plus),.simulator(.iPhoneX),.simulator(.iPhoneXS),.simulator(.iPhoneXSMax),.simulator(.iPhoneXR)]

let device = Device.current
 
if device.isOneOf(groupOfAllowedDevices) {
  // Do your action
}
```

### Get the Current Battery State
**Note:**

> To get the current battery state we need to set `UIDevice.current.isBatteryMonitoringEnabled` to `true`. To avoid any issues with your code, we read the current setting and reset it to what it was before when we're done.

```swift
if device.batteryState == .full || device.batteryState >= .charging(75) {
  print("Your battery is happy! 😊")
}
```

### Get the Current Battery Level
```swift
if device.batteryLevel >= 50 {
  install_iOS()
} else {
  showError()
}
```

### Get Low Power mode status
```swift
if device.batteryState.lowPowerMode {
  print("Low Power mode is enabled! 🔋")
} else {
  print("Low Power mode is disabled! 😊")
}
```

### Check if a Guided Access session is currently active
```swift
if device.isGuidedAccessSessionActive {
  print("Guided Access session is currently active")
} else {
  print("No Guided Access session is currently active")
}
```

### Get Screen Brightness
```swift
if device.screenBrightness > 50 {
  print("Take care of your eyes!")
}
```

### Get Available Disk Space
```swift
if Device.volumeAvailableCapacityForOpportunisticUsage ?? 0 > Int64(1_000_000) {
  // download that nice-to-have huge file
}

if Device.volumeAvailableCapacityForImportantUsage ?? 0 > Int64(1_000) {
  // download that file you really need
}
```

## Source of Information
All model identifiers are taken from the following website: https://www.theiphonewiki.com/wiki/Models or extracted from the simulator app bundled with Xcode.

## Contributing
If you have the need for a specific feature that you want implemented or if you experienced a bug, please open an issue.
If you extended the functionality of DeviceKit yourself and want others to use it too, please submit a pull request.

## Contributors
The complete list of people who contributed to this project is available [here](https://github.com/devicekit/DeviceKit/graphs/contributors). DeviceKit wouldn't be what it is without you! Thank you very much! 🙏
