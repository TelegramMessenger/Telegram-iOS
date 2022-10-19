//: Playground - noun: a place where people can play
// To use this playground, build DeviceKit.framework for any simulator first.

import DeviceKit
import UIKit

let device = Device()

print(device)     // prints, for example, "iPhone 6 Plus"

/// Get the Device You're Running On
if device == .iPhone6Plus {
    // Do something
} else {
    // Do something else
}

/// Get the Device Family
if device.isPod {
    // iPods (real or simulator)
} else if device.isPhone {
    // iPhone (real or simulator)
} else if device.isPad {
    // iPad (real or simulator)
}

/// Check If Running on Simulator
if device.isSimulator {
    // Running on one of the simulators(iPod/iPhone/iPad)
    // Skip doing something irrelevant for Simulator
}

/// Get the Simulator Device
switch device {
case .simulator(.iPhone6s): break // You're running on the iPhone 6s simulator
case .simulator(.iPadAir2): break // You're running on the iPad Air 2 simulator
default: break
}

/// Make Sure the Device Is Contained in a Preconfigured Group
let groupOfAllowedDevices: [Device] = [.iPhone6,
                                       .iPhone6Plus,
                                       .iPhone6s,
                                       .iPhone6sPlus,
                                       .simulator(.iPhone6),
                                       .simulator(.iPhone6Plus),
                                       .simulator(.iPhone6s),
                                       .simulator(.iPhone6sPlus)]

if device.isOneOf(groupOfAllowedDevices) {
    // Do your action
}

/// Get the Current Battery State
if device.batteryState == .full || device.batteryState >= .charging(75) {
    print("Your battery is happy! 😊")
}

/// Get the Current Battery Level
if device.batteryLevel >= 50 {
    // install_iOS()
} else {
    // showError()
}

/// Get Low Power mode status
if device.batteryState.lowPowerMode {
    print("Low Power mode is enabled! 🔋")
} else {
    print("Low Power mode is disabled! 😊")
}

/// Check if a Guided Access session is currently active
if device.isGuidedAccessSessionActive {
    print("Guided Access session is currently active")
} else {
    print("No Guided Access session is currently active")
}

/// Get Screen Brightness
if device.screenBrightness > 50 {
    print("Take care of your eyes!")
}

/// Get Available Disk Space
if Device.volumeAvailableCapacityForOpportunisticUsage ?? 0 > Int64(1_000_000) {
    // download that nice-to-have huge file
}

if Device.volumeAvailableCapacityForImportantUsage ?? 0 > Int64(1_000) {
    // download that file you really need
}

// Get the underlying device
let simulator = Device.simulator(.iPhone8Plus)
let realDevice = Device.iPhone8Plus
simulator.realDevice == realDevice // true
realDevice.realDevice == realDevice // true
