//
//  CrowdinSDK+ReatimeUpdates.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/1/19.
//

import Foundation

extension CrowdinSDK {
    class func initializeRealtimeUpdatesFeature() {
        guard let config = CrowdinSDK.config else { return }
        let crowdinProviderConfig = config.crowdinProviderConfig ?? CrowdinProviderConfig()
        if config.realtimeUpdatesEnabled {
            RealtimeUpdateFeature.shared = RealtimeUpdateFeature(hash: crowdinProviderConfig.hashString, sourceLanguage: crowdinProviderConfig.sourceLanguage, organizationName: config.loginConfig?.organizationName)
            swizzleControlMethods()
        }
    }
    
    public class func startRealtimeUpdates(success: (() -> Void)?, error: ((Error) -> Void)?) {
        guard var realtimeUpdateFeature = RealtimeUpdateFeature.shared else { return }
        realtimeUpdateFeature.success = success
        realtimeUpdateFeature.error = error
        realtimeUpdateFeature.start()
    }
    
    public class func stopRealtimeUpdates() {
        guard let realtimeUpdateFeature = RealtimeUpdateFeature.shared else { return }
        realtimeUpdateFeature.stop()
    }
    
    /// Reload localization for all UI controls(UILabel, UIButton). Works only if realtime update feature is enabled.
    public class func reloadUI() {
        DispatchQueue.main.async { RealtimeUpdateFeature.shared?.refreshAllControls() }
    }
}
