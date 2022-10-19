//
//  CrowdinSDK+IntervalUpdate.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/1/19.
//

import Foundation

extension CrowdinSDK {
    public class func startIntervalUpdates(interval: TimeInterval) {
        IntervalUpdateFeature.shared = IntervalUpdateFeature(interval: interval)
        IntervalUpdateFeature.shared?.start()
    }
    
    public class func stopIntervalUpdates() {
        IntervalUpdateFeature.shared?.stop()
        IntervalUpdateFeature.shared = nil
    }
    
    class func initializeIntervalUpdateFeature() {
        guard let config = CrowdinSDK.config else { return }
        if config.intervalUpdatesEnabled {
            if let interval = config.localizationUpdatesInterval {
                IntervalUpdateFeature.shared = IntervalUpdateFeature(interval: interval)
            } else {
                IntervalUpdateFeature.shared = IntervalUpdateFeature()
            }
            IntervalUpdateFeature.shared?.start()
        }
    }
}
