//
//  UILabel+RealtimeUpdates.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/5/19.
//

import UIKit

extension UILabel {
    /// Subscribe UILabel for realtime updates if it has localization key and realtime updates feature enabled.
    @objc func subscribeForRealtimeUpdates() {
        if self.localizationKey != nil {
            RealtimeUpdateFeature.shared?.subscribe(control: self)
        }
    }
    
    /// Unsubscribe UILabel for realtime updates.
    @objc func unsubscribeForRealtimeUpdates() {
        RealtimeUpdateFeature.shared?.unsubscribe(control: self)
    }
}
