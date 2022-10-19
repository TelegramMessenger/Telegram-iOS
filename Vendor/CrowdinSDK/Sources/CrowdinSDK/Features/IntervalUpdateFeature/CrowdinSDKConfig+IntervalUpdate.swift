//
//  CrowdinSDKConfig+IntervalUpdate.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/1/19.
//

import Foundation

extension CrowdinSDKConfig {
    private static var intervalUpdatesEnabled: Bool = false
    private static var intervalUpdatesInterval: TimeInterval? = nil
    
    /// Time inteval for localization updates. Minimum value is 15 minutes.
    var localizationUpdatesInterval: TimeInterval? {
        get {
            return CrowdinSDKConfig.intervalUpdatesInterval
        }
        set {
            CrowdinSDKConfig.intervalUpdatesInterval = newValue
        }
    }
    
    /// Interval updates feature status.
    var intervalUpdatesEnabled: Bool {
        get {
            return CrowdinSDKConfig.intervalUpdatesEnabled
        }
        set {
            CrowdinSDKConfig.intervalUpdatesEnabled = newValue
        }
    }
    
    public func with(intervalUpdatesEnabled: Bool, interval: TimeInterval?) -> Self {
        self.intervalUpdatesEnabled = intervalUpdatesEnabled
        self.localizationUpdatesInterval = interval
        return self
    }
}
