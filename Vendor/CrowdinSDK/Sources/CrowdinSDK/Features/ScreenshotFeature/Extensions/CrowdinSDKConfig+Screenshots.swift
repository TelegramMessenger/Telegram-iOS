//
//  CrowdinSDKConfig+Screenshots.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/1/19.
//

import Foundation

extension CrowdinSDKConfig {
    // Screenshot feature config
    private static var screenshotsEnabled: Bool = false
    
    var screenshotsEnabled: Bool {
        get {
            return CrowdinSDKConfig.screenshotsEnabled
        }
        set {
            CrowdinSDKConfig.screenshotsEnabled = newValue
        }
    }
    
    public func with(screenshotsEnabled: Bool) -> Self {
        self.screenshotsEnabled = screenshotsEnabled
        return self
    }
}
