//
//  CrowdinSDKConfig+Debug.swift
//  BaseAPI
//
//  Created by Nazar Yavornytskyy on 2/15/21.
//

import Foundation

extension CrowdinSDKConfig {
    private static var debugEnabled: Bool = false
    
    /// Debug mode status
    var debugEnabled: Bool {
        get {
            return CrowdinSDKConfig.debugEnabled
        }
        set {
            CrowdinSDKConfig.debugEnabled = newValue
        }
    }
    
    /// Method for enabling/disabling debug mode through the config.
    /// - Parameter debugEnabled: A boolean value which indicate debug mode enabling status.
    public func with(debugEnabled: Bool) -> Self {
        self.debugEnabled = debugEnabled
        return self
    }
}
