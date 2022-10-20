# Changelog

## Version 4.5.2

Releasedate: 2021-10-24

```ruby
pod 'DeviceKit', '~> 4.5'
```

### Fixes

- Fix iPad mini (6th generation) screen size and aspect ratio again. ([#300](https://github.com/devicekit/DeviceKit/pull/300))
- Add missing device support URLs and images. ([#300](https://github.com/devicekit/DeviceKit/pull/300))

## Version 4.5.1

Releasedate: 2021-10-15

```ruby
pod 'DeviceKit', '~> 4.5'
```

### Fixes

- Fix iPad mini (6th generation) screen size and aspect ratio. ([#294](https://github.com/devicekit/DeviceKit/pull/294))

## Version 4.5.0

Releasedate: 2021-09-16

```ruby
pod 'DeviceKit', '~> 4.5'
```

### New September 2021 devices

This version adds support for the devices announced at the September 2021 Apple Event: ([#286](https://github.com/devicekit/DeviceKit/pull/286))

| Device | Case value |
| --- | --- |
| iPhone 13 | `Device.iPhone13` |
| iPhone 13 mini | `Device.iPhone13Mini` |
| iPhone 13 Pro | `Device.iPhone13Pro` |
| iPhone 13 Pro Max | `Device.iPhone13ProMax` |
| iPad (9th generation) | `Device.iPad9` |
| iPad mini (6th generation) | `Device.iPadMini6` |

### Changes

- Switched from Travis CI to GitHub Actions.

## Version 4.4.0

Releasedate: 2021-04-29

```ruby
pod 'DeviceKit', '~> 4.4'
```

This version adds support for the devices announced at the April 2021 Apple Event: ([#279](https://github.com/devicekit/DeviceKit/pull/279))

- iPad Pro (11-inch) (3rd generation) `Device.iPadPro11Inch3`
- iPad Pro (12.9-inch) (5th generation) `Device.iPadPro12Inch5`
- Apple TV 4K (2nd generation) `Device.appleTV4K2`

## Version 4.3.0

Releasedate: 2021-02-12

```ruby
pod 'DeviceKit', '~> 4.3'
```

This version adds support for the Simulator running on Apple Silicon and fixes documentation:

- Support for running in Simulator on Apple Silicon. ([#273](https://github.com/devicekit/DeviceKit/pull/273))
- Fix tech specs link and images for iPhone 12 models and iPad Air (4th generation). ([#272](https://github.com/devicekit/DeviceKit/pull/272))

## Version 4.2.1

Releasedate: 2020-10-22

```ruby
pod 'DeviceKit', '~> 4.2'
```

This version fixes a couple of bugs introduced in the v4.2.0 release:

- `Device.allDevicesWithALidarSensor` didn't include iPhone 12 Pro and iPhone 12 Pro Max. ([#268](https://github.com/devicekit/DeviceKit/pull/268) [#266](https://github.com/devicekit/DeviceKit/issues/266))
- `Device.iPadAir4.screenRatio` returned an invalid screen ratio. ([#268](https://github.com/devicekit/DeviceKit/pull/268) [#267](https://github.com/devicekit/DeviceKit/issues/267))

## Version 4.2.0

Releasedate: 2020-10-21

```ruby
pod 'DeviceKit', '~> 4.2'
```

This release will add support for the October 2020 devices. ([#262](https://github.com/devicekit/DeviceKit/pull/262))

- iPad Air (4th generation)
- iPhone 12
- iPhone 12 mini
- iPhone 12 Pro
- iPhone 12 Pro Max
```swift
Device.iPadAir4

Device.iPhone12
Device.iPhone12Mini

Device.iPhone12Pro
Device.iPhone12ProMax
```

## Version 4.1.0

Releasedate: 2020-09-21

```ruby
pod 'DeviceKit', '~> 4.1'
```

This release will add support for the September 2020 devices, which will be released on the 18th of September: ([#256](https://github.com/devicekit/DeviceKit/pull/256))
- iPad (8th generation)
- Apple Watch Series 6
- Apple Watch SE
```swift
Device.iPad8

Device.appleWatchSeries6_40mm
Device.appleWatchSeries6_44mm

Device.appleWatchSE_40mm
Device.appleWatchSE_44mm
```

Support for iPad Air (4th generation) will be added in a later version since it will be a long time before we know its device identifiers.

## Version 4.0.0

Releasedate: 2020-09-04

```ruby
pod 'DeviceKit', '~> 4.0'
```

This is a v4.0.0 release because of the possibly breaking change of no longer supporting iOS 9. This decision was made because of Xcode 12 no longer supporting iOS 8.

- Dropped support for iOS 8. Lowest supported version is now iOS 9. ([#249](https://github.com/devicekit/DeviceKit/pull/249))
- Updated project settings for Xcode 12. ([#248](https://github.com/devicekit/DeviceKit/pull/248))

## Version 3.2.0

Releasedate: 2020-04-29

```ruby
pod 'DeviceKit', '~> 3.2'
```

### iPhone SE (2nd generation)
- Added support for the iPhone SE (2nd generation). ([#238](https://github.com/devicekit/DeviceKit/pull/238))
```swift
Device.iPhoneSE2
```

## Version 3.1.0

Releasedate: 2020-03-29

```ruby
pod 'DeviceKit', '~> 3.1'
```

### 2020 iPad Pro
- Added support for the new 2020 iPad Pro. ([#235](https://github.com/devicekit/DeviceKit/pull/235))
```swift
Device.iPadPro11Inch2 // iPad Pro (11-inch) (2nd generation)
Device.iPadPro12inch4 // iPad Pro (12.9-inch) (4th generation)
```

### New features
- Added new functions for detecting LiDAR support.
  - `Device.allDevicesWithALidarSensor` and `Device.current.hasLidarSensor`

## Version 3.0.0

Releasedate: 2020-01-19

```ruby
pod 'DeviceKit', '~> 3.0'
```

### Breaking changes
- The enum for the Apple TV HD has been renamed from `.appleTV4` to `.appleTVHD`. ([#211](https://github.com/devicekit/DeviceKit/pull/211))
- `.allSimulatorXSeriesDevices` has been deprecated and replaced by `.allSimulatorDevicesWithSensorHousing`. ([#212](https://github.com/devicekit/DeviceKit/pull/212))
- `.allXSeriesDevices` has been deprecated and replaced by `.allDevicesWithSensorHousing`. ([#212](https://github.com/devicekit/DeviceKit/pull/212))

#### Camera
- `CameraTypes` has been renamed to `CameraType`. ([#212](https://github.com/devicekit/DeviceKit/pull/212))
- `CameraType.normal` has been deprecated and replaced by `CameraType.wide`. ([#212](https://github.com/devicekit/DeviceKit/pull/212))
- `.allDevicesWithNormalCamera` has been deprecated and replaced by `.allDevicesWithWideCamera`. ([#212](https://github.com/devicekit/DeviceKit/pull/212))
- `.hasNormalCamera` has been deprecated and replaced by `.hasWideCamera`. ([#212](https://github.com/devicekit/DeviceKit/pull/212))

### New features
- You can now check which devices support wireless charging through the following variables: `Device.allDevicesWithWirelessChargingSupport` and `Device.current.supportsWirelessCharging` ([#209](https://github.com/devicekit/DeviceKit/pull/209))
- New `.safeDescription` variable that will provide you with a safe version of the `.description` variable. ([#212](https://github.com/devicekit/DeviceKit/pull/212))
  - Example: "iPhone Xʀ" vs "iPhone XR"

### Bugfixes
- `.allDevicesWith3dTouchSupport` contained `.iPhoneSE` which was incorrect. ([#226](https://github.com/devicekit/DeviceKit/pull/226))
- Some variables would return incorrect values when running on the simulator. ([#227](https://github.com/devicekit/DeviceKit/pull/227))

## Version 2.3.0

Releasedate: 2019-10-02

```ruby
pod 'DeviceKit', '~> 2.3'
```

### New devices
- Added support for the new september 2019 devices:
  - iPad (7th generation)

## Version 2.2.0

Releasedate: 2019-09-24

```ruby
pod 'DeviceKit', '~> 2.2'
```

### New devices
- Added support for the new september 2019 devices:
  - iPhone 11
  - iPhone 11 Pro
  - iPhone 11 Pro Max
  - Apple Watch Series 5

### New features
- `Device.current.cameras` now has the `.ultraWide` camera type added for devices with that camera.

## Version 2.1.0

Releasedate: 2019-09-01

```ruby
pod 'DeviceKit', '~> 2.1'
```

### New features
- Add support for the new iPod touch (7th generation) ([#189](https://github.com/devicekit/DeviceKit/pull/189))
- Added `Device.allApplePencilCapableDevices` and `Device.current.applePencilSupport` variables for checking Apple Pencil support. ([#179](https://github.com/devicekit/DeviceKit/pull/179))
  - `.applePencilSupport` returns `ApplePencilSupport.firstGeneration` or `ApplePencilSupport.secondGeneration` for checking which Apple Pencil is supported.
- Added 3D Touch (iOS) and Force Touch (watchOS) support variables: ([#183](https://github.com/devicekit/DeviceKit/pull/183))
  - iOS
    - `Device.allDevicesWith3dTouchSupport`
    - `Device.current.has3dTouchSupport`
  - watchOS
    - `Device.allWatchesWithForceTouchSupport`
    - `Device.current.hasForceTouchSupport`
- Added variable to check for the camera's a device has. ([#188](https://github.com/devicekit/DeviceKit/pull/188))
  - Example: `Device.iPhoneXS.cameras` should return `CameraTypes.normal` and `CameraTypes.telephoto`.

### Fixes
- Rename iPod touch 5 and 6 to iPod touch (5th generation) and iPod touch (6th generation) respectively. ([#189](https://github.com/devicekit/DeviceKit/pull/189))
- Rename Apple TV (4th generation) to Apple TV HD to comply with Apple's rename of the device. ([#196](https://github.com/devicekit/DeviceKit/pull/196))
- Improve support for Swift Package Manager. ([#193](https://github.com/devicekit/DeviceKit/pull/193))
- Fixed the `Device.current.isZoomed` variable. ([#59 comment](https://github.com/devicekit/DeviceKit/issues/59#issuecomment-519457674) and [#198](https://github.com/devicekit/DeviceKit/pull/198))


## Version 2.0.0

Releasedate: 2019-04-10

```ruby
pod 'DeviceKit', '~> 2.0'
```

### Breaking changes
- The original `Device()` constructor has been made private in favour of using `Device.current` to match `UIDevice.current`.
- The enum values for the iPhone Xs, iPhone Xs Max and iPhone Xʀ have been renamed to be `.iPhoneXS`, `.iPhoneXSMax` and `.iPhoneXR` to match proper formatting.
- `.description` for the iPhone Xs, iPhone Xs Max and iPhone Xʀ have been changed to contain small caps formatting for the s and the ʀ part.
- `.description` for the iPad 5 and iPad 6 have been changed to the proper names; iPad (5<sup>th</sup> generation) and iPad (6<sup>th</sup> generation).
- `.name`, `.systemName`, `.systemVersion`, `.model`, `.localizedModel`, `.batteryState` and `.batteryLevel` will now all return nil when you try to get its value when the device you are getting it from isn't the current one. (eg. `Device.iPad6.name` while running on iPad 5)

### New features
- Updated to Swift 5!
- New `.allDevicesWithRoundedDisplayCorners` and `.hasRoundedDisplayCorners` values to check if a device has rounded display corners. (eg. iPhone Xs and iPad Pro (3<sup>rd</sup> generation))
- new `.allDevicesWithSensorHousing` and `.hasSensorHousing` values to check if a device has a screen cutout for the sensor housing. (eg. iPhone Xs)

### Bugfixes
- `.isPad` and `.isPhone` are now giving correct outputs again.

## Version 1.13.0 (Last Swift 4.2 release)

Releasedate: 2019-03-29

```ruby
pod 'DeviceKit', '~> 1.13'
```

### New iPads
Added new iPad Mini (5th generation) and iPad Air (3rd generation)
```swift
Device.iPadMini5 // iPad Mini (5th generation)
Device.iPadAir3 // iPad Air (3rd generation)
```
