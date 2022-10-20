//
//  Bundle+Resources.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/23/19.
//

import Foundation

#if !CrowdinSDKSPM

extension Bundle {
    static var module: Bundle { Bundle(for: SettingsView.self) }
}

#endif
