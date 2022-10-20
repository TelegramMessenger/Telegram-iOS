//
//  Localization.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/25/19.
//

import Foundation

/// Helper class for working with localization providers and extractors. Store all needed information such as: mode, current localization value, ect.
class Localization {
    var _provider: Atomic<LocalizationProviderProtocol>
    /// Current localization provider.
    var provider: LocalizationProviderProtocol {
        get {
            return _provider.value
        }
        set {
            _provider.mutate({ $0 = newValue })
        }
    }
    
    /// Localization extractor.
    var extractor: LocalLocalizationExtractor

    // swiftlint:disable implicitly_unwrapped_optional
    /// Instance of shared @Localization class instance.
    static var current: Localization! = nil
	
    /// Property for detecting and storing curent localization value depending on current SDK mode.
    static var currentLocalization: String? {
		set {
            self.customLocalization = newValue
            if let localization = newValue {
                Localization.current?.provider.localization = localization
                Localization.current?.extractor.localization = localization
            } else {
                Localization.current?.provider.localization = autoDetectedLocalization
                Localization.current?.extractor.localization = autoDetectedLocalization
            }
		}
		get {
            return customLocalization
		}
	}
    
    /// Auto detects localization. For detection uses localizations from the bundle and from the current provider. Return "en" if SDK isn't initialized or there are no languages ether on crowdin and bundle.
    private static var autoDetectedLocalization: String {
        if let avalaibleLocalizations = Localization.current?.avalaibleLocalizations {
            return Bundle.main.preferredLanguage(with: avalaibleLocalizations)
        }
        return defaultLocalization
    }
	
    /// Property for storing specific localization value in UserDefaults. This value used for custom in SDK localization.
    private static var customLocalization: String? {
        set {
            UserDefaults.standard.customLocalization = newValue
        }
        get {
            return UserDefaults.standard.customLocalization
        }
    }
	
    /// Initialize object with specific localization provider.
    ///
    /// - Parameter provider: Localization provider implementation.
	init(provider: LocalizationProviderProtocol) {
        let localization = provider.localization
        self.extractor = LocalLocalizationExtractor(localization: localization)
        self._provider = Atomic(provider)
        self.provider = provider
        self.provider.localization = localization
	}
	
	/// A list of all avalaible localization in SDK downloaded from current provider.
	var inProvider: [String] { provider.localizations }
    
    /// A list of all the localizations contained in the bundle.
    var inBundle: [String] { Bundle.main.inBundleLocalizations }
    
    var avalaibleLocalizations: [String] { Array(Set<String>(inProvider + inBundle)) }
    
    /// Find localization key for a given text.
    ///
    /// - Parameter text: Text to find key for.
    /// - Returns: Localization key for given text. If there are no such text in localization strings then method will return nil.
    func keyForString(_ text: String) -> String? {
        var key = provider.key(for: text)
        if key == nil {
            // TODO: Add proper method to extractor for getting keys.
            key = extractor.localizationDict.first(where: { $1 == text })?.key
        }
        return key
    }
    
    /// Find localization string for geiven key.
    ///
    /// - Parameter key: Key to find localization string for.
    /// - Returns: Localization key string value. If string woun't find method will return key value.
    func localizedString(for key: String) -> String? {
        var string = provider.localizedString(for: key)
        if string == nil {
            // Todo: Add proper method to extractor for getting localized string by key.
            string = extractor.localizedString(for: key)
        }
        return string
    }
	
    /// Method for detecting formated values in string by given format.
    ///
    /// - Parameters:
    ///   - string: Given localized string.
    ///   - format: String format.
    /// - Returns: Detected values. If values aren't detected than method will return nil.
	func findValues(for string: String, with format: String) -> [Any]? {
		return provider.values(for:string, with:format)
	}
}
