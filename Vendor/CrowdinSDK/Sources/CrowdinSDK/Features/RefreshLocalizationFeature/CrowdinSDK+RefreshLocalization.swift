//
//  CrowdinSDK+RefreshLocalization.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/5/19.
//

import Foundation

extension CrowdinSDK {
    public class func forceRefreshLocalization() {
        RefreshLocalizationFeature.refreshLocalization()
    }
}
