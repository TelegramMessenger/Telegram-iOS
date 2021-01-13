import Foundation

@propertyWrapper
public struct NGStorage<T: Codable> {
    private let key: String
    private let defaultValue: T

    public init(key: String, defaultValue: T) {
        self.key = "ng:" + key
        self.defaultValue = defaultValue
    }

    public var wrappedValue: T {
        get {
            // Read value from UserDefaults
            guard let data = UserDefaults.standard.object(forKey: key) as? Data else {
                // Return defaultValue when no data in UserDefaults
                return defaultValue
            }

            // Convert data to the desire data type
            let value = try? JSONDecoder().decode(T.self, from: data)
            return value ?? defaultValue
        }
        set {
            // Convert newValue to data
            let data = try? JSONEncoder().encode(newValue)
            
            // Set value to UserDefaults
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

public struct NGSettings {
    // MARK: Premium
    @NGStorage(key: "premium", defaultValue: false)
    public static var premium: Bool
    
    @NGStorage(key: "oneTapTr", defaultValue: true)
    public static var oneTapTr: Bool
    
    @NGStorage(key: "oneTapTrButtonLowPowerMode", defaultValue: false)
    public static var oneTapTrButtonLowPowerMode: Bool
    
    @NGStorage(key: "ignoreTranslate", defaultValue: [])
    public static var ignoreTranslate: [String]
    
    @NGStorage(key: "rememberFolderOnExit", defaultValue: false)
    public static var rememberFolderOnExit: Bool
    
    @NGStorage(key: "lastFolder", defaultValue: nil)
    public static var lastFolder: Int32?
    
    // MARK: App Settings
    @NGStorage(key: "showContactsTab", defaultValue: true)
    public static var showContactsTab: Bool
    
    @NGStorage(key: "sendWithEnter", defaultValue: false)
    public static var sendWithEnter: Bool
    
    @NGStorage(key: "hidePhoneSettings", defaultValue: false)
    public static var hidePhoneSettings: Bool
    
    @NGStorage(key: "useRearCamTelescopy", defaultValue: false)
    public static var useRearCamTelescopy: Bool
    
    @NGStorage(key: "hideNotifyAccount", defaultValue: false)
    public static var hideNotifyAccount: Bool
    
    @NGStorage(key: "fixNotifications", defaultValue: false)
    public static var fixNotifications: Bool
    
    @NGStorage(key: "showTabNames", defaultValue: true)
    public static var showTabNames: Bool
    
    @NGStorage(key: "classicProfileUI", defaultValue: false)
    public static var classicProfileUI: Bool
    
    @NGStorage(key: "showGmodIcon", defaultValue: true)
    public static var showGmodIcon: Bool
    
    @NGStorage(key: "showProfileId", defaultValue: true)
    public static var showProfileId: Bool
    
    @NGStorage(key: "showRegDate", defaultValue: true)
    public static var showRegDate: Bool
}

public struct NGWebSettings {
    // MARK: Remote Settings
    @NGStorage(key: "syncPins", defaultValue: false)
    static var syncPins: Bool
    
    @NGStorage(key: "restricted", defaultValue: [])
    static var resticted: [Int64]
    
    @NGStorage(key: "RR", defaultValue: [])
    static var RR: [String]
    
    @NGStorage(key: "allowed", defaultValue: [])
    static var allowed: [Int64]
      
}


public struct NGSharedSettings {
    let UD = UserDefaults(suiteName: "group.\(Bundle.main.bundleIdentifier!)")

    public init() {
        UD?.register(defaults: ["hideNotifyAccountName": false])
    }

    public var hideNotifyAccountName: Bool {
        get {
            return UD?.bool(forKey: "hideNotifyAccountName") ?? false
        }
        set {
            UD?.set(newValue, forKey: "hideNotifyAccountName")
        }
    }
}

public var VarNGSharedSettings = NGSharedSettings()


public func isPremium() -> Bool {    
    let bb = (Bundle.main.infoDictionary?[kCFBundleVersionKey as String] ?? "") as! String
    if bb.last != "1" {
        return false
    }
    let premium = NGSettings.premium
    if !premium {
        if  #available(iOS 13, *) {
        } else {
            return UserDefaults.standard.bool(forKey: "ng:premiumLegacy")
        }
    }
    return premium
}

public func usetrButton() -> [(Bool, [String])] {
    if isPremium() {
        var ignoredLangs = NGSettings.ignoreTranslate
        if !NGSettings.ignoreTranslate.isEmpty && ProcessInfo.processInfo.isLowPowerModeEnabled && !NGSettings.oneTapTrButtonLowPowerMode {
            ignoredLangs = []
        }
        return [(NGSettings.oneTapTr, ignoredLangs)]
    }
    return [(false, [])]
}
