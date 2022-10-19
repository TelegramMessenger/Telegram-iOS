//
//  ManifestManager.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 11.05.2020.
//

import Foundation

class ManifestManager {
    fileprivate static var shared: ManifestManager?
    
    var hash: String
    
    var files: [String]
    var timestamp: TimeInterval?
    var languages: [String]?
    var customLanguages: [CustomLangugage]?
    
    var contentDeliveryAPI: CrowdinContentDeliveryAPI
    
    init(hash: String) {
        self.hash = hash
        self.contentDeliveryAPI = CrowdinContentDeliveryAPI(hash: hash)
        let manifest = contentDeliveryAPI.getManifestSync()
        if let error = manifest.error {
            LocalizationUpdateObserver.shared.notifyError(with: [error])
        }
        self.files = manifest.response?.files ?? []
        self.timestamp = manifest.response?.timestamp
        self.languages = manifest.response?.languages
        self.customLanguages = manifest.response?.customLanguages
    }
    
    static func shared(for hash: String) -> ManifestManager {
        if let shared = shared, shared.hash == hash {
            return shared
        } else {
            let manifestManager = ManifestManager(hash: hash)
            shared = manifestManager
            return manifestManager
        }
    }
    
    var iOSLanguages: [String] {
        return self.languages?.compactMap({ self.iOSLanguageCode(for: $0) }) ?? []
    }
}
