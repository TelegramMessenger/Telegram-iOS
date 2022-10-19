//
//  CrowdinProviderConfig.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 4/9/19.
//

import Foundation

@objcMembers public class CrowdinProviderConfig: NSObject {
    var hashString: String
    var sourceLanguage: String
    
    public init(hashString: String, sourceLanguage: String) {
        self.hashString = hashString
        self.sourceLanguage = sourceLanguage
    }
    
    @available(*, deprecated, renamed: "init(hashString:sourceLanguage:)")
    public init(hashString: String, localizations: [String], sourceLanguage: String) {
        self.hashString = hashString
        self.sourceLanguage = sourceLanguage
    }
    
    public override init() {
        guard let hashString = Bundle.main.crowdinDistributionHash else {
            fatalError("Please add CrowdinDistributionHash key to your Info.plist file")
        }
        self.hashString = hashString
        guard let crowdinSourceLanguage = Bundle.main.crowdinSourceLanguage else {
            fatalError("Please add CrowdinPluralsFileNames key to your Info.plist file")
        }
        self.sourceLanguage = crowdinSourceLanguage
    }
}
