//
//  CrowdinSDKConfig+RealtimeUpdates.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/1/19.
//

import Foundation

extension CrowdinSDKConfig {
    private static var realtimeUpdatesEnabled: Bool = false
    
    /// Realtime updates feature status
    var realtimeUpdatesEnabled: Bool {
        get {
            return CrowdinSDKConfig.realtimeUpdatesEnabled
        }
        set {
            CrowdinSDKConfig.realtimeUpdatesEnabled = newValue
        }
    }
    
    /// Method for enabling/disabling real-time updates feature through the config.
    /// - Parameter realtimeUpdatesEnabled: A boolean value which indicate real-time updates status.
    public func with(realtimeUpdatesEnabled: Bool) -> Self {
        self.realtimeUpdatesEnabled = realtimeUpdatesEnabled
        return self
    }
}
