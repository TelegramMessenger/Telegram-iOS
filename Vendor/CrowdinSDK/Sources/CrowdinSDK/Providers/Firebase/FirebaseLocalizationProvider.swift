//
//  FirebaseProvider.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 2/2/19.
//

import Foundation

@objcMembers public class FirebaseLocalizationProvider: BaseLocalizationProvider {
    public init(path: String) {
        let localization = Bundle.main.preferredLanguage
        let localStorage = FirebaseLocalLocalizationStorage(localization: localization)
        let remoteStorage = FirebaseRemoteLocalizationStorage(localization: localization, path: path)
        super.init(localization: localization, localStorage: localStorage, remoteStorage: remoteStorage)
    }
    
    public init() {
        let localization = Bundle.main.preferredLanguage
        let localStorage = FirebaseLocalLocalizationStorage(localization: localization)
        let remoteStorage = FirebaseRemoteLocalizationStorage(localization: localization)
        super.init(localization: localization, localStorage: localStorage, remoteStorage: remoteStorage)
    }
    
    public required init(localization: String, localStorage: LocalLocalizationStorage, remoteStorage: RemoteLocalizationStorage) {
        let localStorage = FirebaseLocalLocalizationStorage(localization: localization)
        let remoteStorage = FirebaseRemoteLocalizationStorage(localization: localization)
        super.init(localization: localization, localStorage: localStorage, remoteStorage: remoteStorage)
    }
    
    public init(path: String, localization: String, localStorage: LocalLocalizationStorage, remoteStorage: RemoteLocalizationStorage) {
        let localStorage = FirebaseLocalLocalizationStorage(localization: localization)
        let remoteStorage = FirebaseRemoteLocalizationStorage(localization: localization, path: path)
        super.init(localization: localization, localStorage: localStorage, remoteStorage: remoteStorage)
    }
}
