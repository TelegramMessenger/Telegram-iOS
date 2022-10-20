//
//  CrowdinSDKConfig+Screenshots.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/1/19.
//

import Foundation

extension CrowdinSDKConfig {
    // Settings view enabled
    static var settingsEnabled: Bool = false
    
    var settingsEnabled: Bool {
        get {
            return CrowdinSDKConfig.settingsEnabled
        }
        set {
            CrowdinSDKConfig.settingsEnabled = newValue
        }
    }
    
    public func with(settingsEnabled: Bool) -> Self {
        self.settingsEnabled = settingsEnabled
        return self
    }
}
