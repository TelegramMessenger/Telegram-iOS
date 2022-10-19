//
//  CrowdinSDK+ScreenshotFeature.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/1/19.
//

import Foundation
import CoreGraphics

extension CrowdinSDK {
    @objc class func initializeSettings() {
        guard let config = CrowdinSDK.config else { return }
        if config.settingsEnabled {
            self.showSettings()
        }
    }
    
    public class func showSettings() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let settingsView = SettingsView.shared {
                settingsView.settingsWindow.makeKeyAndVisible()
                settingsView.center = CGPoint(x: 100, y: 100)
                settingsView.settingsWindow.settingsView = settingsView
            }
        }
    }
}
