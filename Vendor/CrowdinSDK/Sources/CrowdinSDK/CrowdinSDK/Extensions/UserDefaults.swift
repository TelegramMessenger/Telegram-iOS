//
//  UserDefaults.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/31/19.
//

import Foundation

extension UserDefaults {
    
    /// Enum with simple key values which are used to save information in UserDefaults.
    ///
    /// - AppleLanguages: Key for saving localization languages array used by application.
    /// - mode: Key for saving SDK mode value.
    /// - customLocalization: Key for saving current localization language code.
	enum Keys: String {
		case AppleLanguages
        case mode = "CrowdinSDK.Localization.mode"
        case customLocalization = "CrowdinSDK.Localization.customLocalization"
	}
	
    /// Store custom languages priorities for in-app localization.
	var appleLanguages: [String]? {
		get {
			return UserDefaults.standard.array(forKey: Keys.AppleLanguages.rawValue) as? [String]
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Keys.AppleLanguages.rawValue)
			UserDefaults.standard.synchronize()
		}
	}
	
    /// Custom language in-app localization.
	var appleLanguage: String? {
		get {
			return self.appleLanguages?.first
		}
		set {
            if let value = newValue {
                self.appleLanguages = [value]
            } else {
                self.appleLanguages = nil
            }
            UserDefaults.standard.synchronize()
		}
	}
    
    /// Property for storing SDK mode.
    var mode: Int {
        get {
            return UserDefaults.standard.integer(forKey: Keys.mode.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.mode.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Store custom localization for crowdin provider.
    var customLocalization: String? {
        get {
            return UserDefaults.standard.string(forKey: Keys.customLocalization.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.customLocalization.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
	
    /// Clean custom priorities for in-app localizations.
	func cleanAppleLanguages() {
		self.appleLanguage = nil
	}
}
