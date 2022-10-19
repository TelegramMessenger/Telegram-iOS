//
//  RULocalLocalizationProvider.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 09.02.2020.
//

import Foundation

class RULocalLocalizationStorage: LocalLocalizationStorage {
    override init(localization: String) {
        super.init(localization: localization)
        // swiftlint:disable force_try
        self.localizationFolder = try! CrowdinFolder.shared.createFolder(with: "RealtimeUpdates")
    }
}
