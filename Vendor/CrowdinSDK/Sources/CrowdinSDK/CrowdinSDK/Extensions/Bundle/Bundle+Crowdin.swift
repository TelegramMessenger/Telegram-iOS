//
//  Bundle+Crowdin.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 3/19/19.
//

import Foundation

// MARK: - Extension for reading Crowdin SDK configuration values from Info.plist.
extension Bundle {
    /// Crowdin CDN hash value.
    var crowdinDistributionHash: String? {
        return infoDictionary?["CrowdinDistributionHash"] as? String
    }
    
    /// Source language for current project on crowdin server.
    var crowdinSourceLanguage: String? {
        return infoDictionary?["CrowdinSourceLanguage"] as? String
    }
}
