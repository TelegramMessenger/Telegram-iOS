//
//  Bundle+Application.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/23/19.
//

import Foundation

// MARK: - Extension for working with Info.plist values.
extension Bundle {
    /// Application name stored in Info.plist.
    var appName: String {
        // swiftlint:disable force_cast
        return infoDictionary?["CFBundleName"] as! String
    }
    
    /// Application bundle id stored in Info.plist.
    var bundleId: String {
        // swiftlint:disable force_unwrapping
        return bundleIdentifier!
    }
    
    /// Application version stored in Info.plist.
    var versionNumber: String {
        // swiftlint:disable force_cast
        return infoDictionary?["CFBundleShortVersionString"] as! String
    }
    
    /// Application build number stored in Info.plist.
    var buildNumber: String {
        // swiftlint:disable force_cast
        return infoDictionary?["CFBundleVersion"] as! String
    }
    
    /// Application launch storyboard name (if it exist) stored in Info.plist.
    var launchStoryboardName: String? {
        return infoDictionary?["UILaunchStoryboardName"] as? String
    }
    
    /// Localization native development region.
    var developmentRegion: String? {
        return infoDictionary?["CFBundleDevelopmentRegion"] as? String
    }
}
