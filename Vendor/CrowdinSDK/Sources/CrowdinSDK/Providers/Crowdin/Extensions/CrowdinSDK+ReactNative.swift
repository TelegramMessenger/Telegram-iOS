//
//  CrowdinSDK+ReactNative.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 21.07.2020.
//

import Foundation

extension CrowdinSDK {
    /// Association object for storing localization keys for different states.
    private static let localizationProviderObjectAssociation = ObjectAssociation<LocalizationProvider>()
    
    /// Dictionary with localization keys for different states.
    static var localizationProvider: LocalizationProvider? {
        get { return CrowdinSDK.localizationProviderObjectAssociation[self] }
        set { CrowdinSDK.localizationProviderObjectAssociation[self] = newValue }
    }
    
    /// Get localization dictionary for current localizatiion in json format. Example:
    /// {
    /// "localization": "en",
    /// "strings": [
    ///     ...
    /// ],
    /// "plurals": [
    ///     ...
    /// ]
    /// }
    /// - Returns: Localization dictionary for current localizatiion in json format.
    public class func localizationDictionary() -> [AnyHashable: Any] {
        return localizationDictionary(for: Localization.current.provider.localStorage.localization)
    }
    
    /// Get localization dictionary for specific localizatiion in json format. Example:
    /// {
    /// "localization": "en",
    /// "strings": [
    ///     ...
    /// ],
    /// "plurals": [
    ///     ...
    /// ]
    /// }
    /// - Parameter localization: Localization code to get localizatiion in json format.
    /// - Returns: Localization dictionary for specific localizatiion in json format.
    public class func localizationDictionary(for localization: String) -> [AnyHashable: Any] {
        let localLocalizationStorage = LocalLocalizationStorage(localization: localization)
        localLocalizationStorage.fetchData()
        if localLocalizationStorage.strings.count == 0 {
            
        }
        return [
            "localization": localLocalizationStorage.localization,
            "strings": localLocalizationStorage.strings,
            "plurals": localLocalizationStorage.plurals
        ]
    }
    
    /// Get localization dictionary for specific localizatiion in json format. Download localization from server and store it locally.
    /// {
    /// "localization": "en",
    /// "strings": [
    ///     ...
    /// ],
    /// "plurals": [
    ///     ...
    /// ]
    /// }
    /// - Parameters:
    ///   - localization: Localization code.
    ///   - hashString: Crowdin project hash string.
    ///   - completion: Completion handler.
    ///   - errorHandler: Error handler.
    public class func localizationDictionary(for localization: String, hashString: String, completion: @escaping ([AnyHashable: Any]) -> Void, errorHandler: @escaping (Error) -> Void) {
        let localLocalizationStorage = LocalLocalizationStorage(localization: localization)
        let remoteLocalizationStorage = CrowdinRemoteLocalizationStorage(localization: localization, config: CrowdinProviderConfig(hashString: hashString, sourceLanguage: .empty))
        remoteLocalizationStorage.prepare {
            localizationProvider = LocalizationProvider(localization: localization, localStorage: localLocalizationStorage, remoteStorage: remoteLocalizationStorage)
            localizationProvider?.completion = { [weak localizationProvider] in
                guard let localizationProvider = localizationProvider else { return }
                localizationProvider.loadLocalLocalization()
                let result: [String: Any] = [
                    "localization": localizationProvider.localStorage.localization,
                    "strings": localizationProvider.localStorage.strings,
                    "plurals": localizationProvider.localStorage.plurals
                ]
                completion(result)
                CrowdinSDK.localizationProvider = nil
            }
            localizationProvider?.errorHandler = { error in
                errorHandler(error)
                CrowdinSDK.localizationProvider = nil
            }
            localizationProvider?.refreshLocalization()
        }
    }
}
