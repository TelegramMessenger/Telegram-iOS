import Foundation
import UIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import MtProtoKit
import TelegramUIPreferences
import LegacyComponents
import TelegramNotices
import LegacyDataImportImpl

@objc(TGPresentationState) private final class TGPresentationState: NSObject, NSCoding {
    let pallete: Int32
    let userInfo: Int32
    let fontSize: Int32
    
    init?(coder aDecoder: NSCoder) {
        self.pallete = aDecoder.decodeInt32(forKey: "p")
        self.userInfo = aDecoder.decodeInt32(forKey: "u")
        self.fontSize = aDecoder.decodeInt32(forKey: "f")
    }
    
    func encode(with aCoder: NSCoder) {
        assertionFailure()
    }
}

private enum PreferencesProvider {
    case dict([String: Any])
    case standard(UserDefaults)
    
    subscript(_ key: String) -> Any? {
        get {
            switch self {
                case let .dict(dict):
                    return dict[key]
                case let .standard(standard):
                    return standard.object(forKey: key)
            }
        }
    }
}

private func loadLegacyCustomProperyData(database: SqliteInterface, key: String) -> Data? {
    var result: Data?
    database.select("SELECT value FROM service_v29 WHERE key=\(HashFunctions.murMurHash32(key))", { cursor in
        result = cursor.getData(at: 0)
        return false
    })
    return result
}

private func convertLegacyProxyPort(_ value: Int) -> Int32 {
    if value < 0 {
        return Int32(UInt16(bitPattern: Int16(clamping: value)))
    } else {
        return Int32(clamping: value)
    }
}

func importLegacyPreferences(accountManager: AccountManager, account: TemporaryAccount, documentsPath: String, database: SqliteInterface) -> Signal<Never, NoError> {
    return deferred { () -> Signal<Never, NoError> in
        var presentationState: TGPresentationState?
        if let value = NSKeyedUnarchiver.unarchiveObject(withFile: documentsPath + "/presentation.dat") as? TGPresentationState {
            presentationState = value
        }
        
        var autoNightPreferences: TGPresentationAutoNightPreferences?
        if let value = NSKeyedUnarchiver.unarchiveObject(withFile: documentsPath + "/autonight.dat") as? TGPresentationAutoNightPreferences {
            autoNightPreferences = value
        }
                
        let autoDownloadPreferences: TGAutoDownloadPreferences? = NSKeyedUnarchiver.unarchiveObject(withFile: documentsPath + "/autoDownload.pref") as? TGAutoDownloadPreferences
        
        let preferencesProvider: PreferencesProvider
        let defaultsPath = documentsPath + "/standard.defaults"
        
        let standardPreferences = PreferencesProvider.standard(UserDefaults.standard)
        if let data = try? Data(contentsOf: URL(fileURLWithPath: defaultsPath)), let dict = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: Any] {
            preferencesProvider = .dict(dict)
        } else {
            preferencesProvider = standardPreferences
        }
        
        var showCallsTab: Bool?
        if let data = try? Data(contentsOf: URL(fileURLWithPath: documentsPath + "/enablecalls.tab")), !data.isEmpty {
            showCallsTab = data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Bool in
                return bytes.pointee != 0
            }
        }
        
        let parsedAutoplayGifs: Bool? = preferencesProvider["autoPlayAnimations"] as? Bool
        let soundEnabled: Bool? = preferencesProvider["soundEnabled"] as? Bool
        let vibrationEnabled: Bool? = preferencesProvider["vibrationEnabled"] as? Bool
        let bannerEnabled: Bool? = preferencesProvider["bannerEnabled"] as? Bool
        let callsDataUsageMode: Int? = preferencesProvider["callsDataUsageMode"] as? Int
        let callsDisableCallKit: Bool? = preferencesProvider["callsDisableCallKit"] as? Bool
        let callsUseProxy: Bool? = preferencesProvider["callsUseProxy"] as? Bool
        let contactsInhibitSync: Bool? = preferencesProvider["contactsInhibitSync"] as? Bool
        let stickersSuggestMode: Int? = preferencesProvider["stickersSuggestMode"] as? Int
        
        let allowSecretWebpages: Bool? = preferencesProvider["allowSecretWebpages"] as? Bool
        let allowSecretWebpagesInitialized: Bool? = preferencesProvider["allowSecretWebpagesInitialized"] as? Bool
        let secretInlineBotsInitialized: Bool? = preferencesProvider["secretInlineBotsInitialized"] as? Bool
        
        let musicPlayerOrderType: Int? = standardPreferences["musicPlayerOrderType_v1"] as? Int
        let musicPlayerRepeatType: Int? = standardPreferences["musicPlayerRepeatType_v1"] as? Int
        
        let instantPageFontSize: Float? = standardPreferences["instantPage_fontMultiplier_v0"] as? Float
        let instantPageFontSerif: Int? = standardPreferences["instantPage_fontSerif_v0"] as? Int
        let instantPageTheme: Int? = standardPreferences["instantPage_theme_v0"] as? Int
        let instantPageAutoNightMode: Int? = standardPreferences["instantPage_autoNightTheme_v0"] as? Int
        
        let proxyList = NSKeyedUnarchiver.unarchiveObject(withFile: documentsPath + "/proxies.data") as? [TGProxyItem]
        var selectedProxy: (ProxyServerSettings, Bool)?
        if let data = loadLegacyCustomProperyData(database: database, key: "socksProxyData"), let dict = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: Any], let host = dict["ip"] as? String, let port = dict["port"] as? Int {
            let inactive = (dict["inactive"] as? Bool) ?? true
            var connection: ProxyServerConnection?
            if let secretString = dict["secret"] as? String {
                let secret = MTProxySecret.parse(secretString)
                if let secret = secret {
                    connection = .mtp(secret: secret.serialize())
                }
            } else {
                connection = .socks5(username: (dict["username"] as? String) ?? "", password: (dict["password"] as? String) ?? "")
            }
            if let connection = connection {
                selectedProxy = (ProxyServerSettings(host: host, port: convertLegacyProxyPort(port), connection: connection), !inactive)
            }
        }
        
        var passcodeChallenge: PostboxAccessChallengeData?
        if let data = try? Data(contentsOf: URL(fileURLWithPath: documentsPath + "/x.y")) {
            let reader = LegacyBufferReader(LegacyBuffer(data: data))
            if let mode = reader.readBytesAsInt32(1), let length = reader.readInt32(), let passwordData = reader.readBuffer(Int(length))?.makeData(), let passwordText = String(data: passwordData, encoding: .utf8) {
                var lockTimeout: Int32?
                if let value = UserDefaults.standard.object(forKey: "Passcode_lockTimeout") as? Int {
                    if value == 0 {
                        lockTimeout = nil
                    } else {
                        lockTimeout = max(60, Int32(clamping: value))
                    }
                } else {
                    lockTimeout = 1 * 60 * 60
                }
                
                if mode == 3 {
                    passcodeChallenge = .numericalPassword(value: passwordText)
                } else if mode == 4 {
                    passcodeChallenge = PostboxAccessChallengeData.plaintextPassword(value: passwordText)
                }
            }
        }
        
        var passcodeEnableBiometrics: Bool = true
        if let value = UserDefaults.standard.object(forKey: "Passcode_useTouchId") as? Bool {
            passcodeEnableBiometrics = value
        }
        
        var localization: TGLocalization?
        if let nativeDocumentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            localization = NSKeyedUnarchiver.unarchiveObject(withFile: nativeDocumentsPath + "/localization") as? TGLocalization
        }
        
        return accountManager.transaction { transaction -> Signal<Void, NoError> in
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings, { current in
                var settings = (current as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
                if let presentationState = presentationState {
                    switch presentationState.pallete {
                        case 1:
                            settings.theme = .builtin(.day)
                           
                            if presentationState.userInfo != 0 {
                                //themeSpecificAccentColors: current.themeSpecificAccentColors
                                //settings.themeAccentColor = presentationState.userInfo
                            }
                            settings.themeSpecificChatWallpapers[settings.theme.index] = .color(0xffffff)
                        case 2:
                            settings.theme = .builtin(.night)
                            settings.themeSpecificChatWallpapers[settings.theme.index] = .color(0x000000)
                        case 3:
                            settings.theme = .builtin(.nightAccent)
                            settings.themeSpecificChatWallpapers[settings.theme.index] = .color(0x18222d)
                        default:
                            settings.theme = .builtin(.dayClassic)
                            settings.themeSpecificChatWallpapers[settings.theme.index] = .builtin(WallpaperSettings())
                    }
                    let fontSizeMap: [Int32: PresentationFontSize] = [
                        14: .extraSmall,
                        15: .small,
                        16: .medium,
                        17: .regular,
                        19: .large,
                        23: .extraLarge,
                        26: .extraLargeX2
                    ]
                    settings.fontSize = fontSizeMap[presentationState.fontSize] ?? .regular
                    
                    if presentationState.userInfo != 0 {
                        //themeSpecificAccentColors: current.themeSpecificAccentColors
                        //settings.themeAccentColor = presentationState.userInfo
                    }
                }
                
                if let autoNightPreferences = autoNightPreferences {
                    let nightTheme: PresentationBuiltinThemeReference
                    switch autoNightPreferences.preferredPalette {
                        case 1:
                            nightTheme = .night
                        default:
                            nightTheme = .nightAccent
                    }
                    switch autoNightPreferences.mode {
                        case TGPresentationAutoNightModeSunsetSunrise:
                            settings.automaticThemeSwitchSetting = AutomaticThemeSwitchSetting(trigger: .timeBased(setting: .automatic(latitude: Double(autoNightPreferences.latitude), longitude: Double(autoNightPreferences.longitude), localizedName: autoNightPreferences.cachedLocationName)), theme: .builtin(nightTheme))
                        case TGPresentationAutoNightModeScheduled:
                            settings.automaticThemeSwitchSetting = AutomaticThemeSwitchSetting(trigger: .timeBased(setting: .manual(fromSeconds: autoNightPreferences.scheduleStart, toSeconds: autoNightPreferences.scheduleEnd)), theme: .builtin(nightTheme))
                        case TGPresentationAutoNightModeBrightness:
                            settings.automaticThemeSwitchSetting = AutomaticThemeSwitchSetting(trigger: .brightness(threshold: Double(autoNightPreferences.brightnessThreshold)), theme: .builtin(nightTheme))
                        default:
                            break
                    }
                }
                
                return settings
            })
            
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, { current in
                var settings: MediaAutoDownloadSettings = current as? MediaAutoDownloadSettings ?? .defaultSettings

                if let preferences = autoDownloadPreferences, !preferences.isDefaultPreferences() {
                    settings.cellular.enabled = !preferences.disabled
                    settings.wifi.enabled = !preferences.disabled
                }
                
                if let parsedAutoplayGifs = parsedAutoplayGifs {
                    settings.autoplayGifs = parsedAutoplayGifs
                }
                
                return settings
            })
            
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.inAppNotificationSettings, { current in
                var settings: InAppNotificationSettings = current as? InAppNotificationSettings ?? .defaultSettings
                if let soundEnabled = soundEnabled {
                    settings.playSounds = soundEnabled
                }
                if let vibrationEnabled = vibrationEnabled {
                    settings.vibrate = vibrationEnabled
                }
                if let bannerEnabled = bannerEnabled {
                    settings.displayPreviews = bannerEnabled
                }
                return settings
            })
            
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.voiceCallSettings, { current in
                var settings: VoiceCallSettings = current as? VoiceCallSettings ?? .defaultSettings
                if let callsDataUsageMode = callsDataUsageMode {
                    switch callsDataUsageMode {
                        case 1:
                            settings.dataSaving = .cellular
                        case 2:
                            settings.dataSaving = .always
                        default:
                            settings.dataSaving = .never
                    }
                }
                if let callsDisableCallKit = callsDisableCallKit, callsDisableCallKit {
                    settings.enableSystemIntegration = false
                }
                return settings
            })
            
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.callListSettings, { current in
                var settings: CallListSettings = current as? CallListSettings ?? .defaultSettings
                if let showCallsTab = showCallsTab {
                    settings.showTab = showCallsTab
                }
                return settings
            })
            
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationPasscodeSettings, { current in
                var settings: PresentationPasscodeSettings = current as? PresentationPasscodeSettings ?? .defaultSettings
                if let passcodeChallenge = passcodeChallenge {
                    transaction.setAccessChallengeData(passcodeChallenge)
                    settings.enableBiometrics = passcodeEnableBiometrics
                }
                return settings
            })
            
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.stickerSettings, { current in
                var settings: StickerSettings = current as? StickerSettings ?? .defaultSettings
                if let stickersSuggestMode = stickersSuggestMode {
                    switch stickersSuggestMode {
                        case 1:
                            settings.emojiStickerSuggestionMode = .installed
                        case 2:
                            settings.emojiStickerSuggestionMode = .none
                        default:
                            settings.emojiStickerSuggestionMode = .all
                    }
                }
                return settings
            })
            
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings, { current in
                var settings: MusicPlaybackSettings = current as? MusicPlaybackSettings ?? .defaultSettings
                if let musicPlayerOrderType = musicPlayerOrderType {
                    switch musicPlayerOrderType {
                    case 1:
                        settings.order = .reversed
                    case 2:
                        settings.order = .random
                    default:
                        settings.order = .regular
                    }
                }
                if let musicPlayerRepeatType = musicPlayerRepeatType {
                    switch musicPlayerRepeatType {
                    case 1:
                        settings.looping = .all
                    case 2:
                        settings.looping = .item
                    default:
                        settings.looping = .none
                    }
                }
                return settings
            })
            
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.instantPagePresentationSettings, { current in
                let settings: InstantPagePresentationSettings = current as? InstantPagePresentationSettings ?? .defaultSettings
                if let instantPageFontSize = instantPageFontSize {
                    switch instantPageFontSize {
                        case 0.85:
                            settings.fontSize = .small
                        case 1.15:
                            settings.fontSize = .large
                        case 1.30:
                            settings.fontSize = .xlarge
                        case 1.50:
                            settings.fontSize = .xxlarge
                        default:
                            settings.fontSize = .standard
                    }
                }
                if let instantPageFontSerif = instantPageFontSerif {
                    settings.forceSerif = instantPageFontSerif == 1
                }
                if let instantPageTheme = instantPageTheme {
                    switch instantPageTheme {
                    case 1:
                        settings.themeType = .sepia
                    case 2:
                        settings.themeType = .gray
                    case 3:
                        settings.themeType = .dark
                    default:
                        settings.themeType = .light
                    }
                }
                if let instantPageAutoNightMode = instantPageAutoNightMode {
                    settings.autoNightMode = instantPageAutoNightMode == 1
                }
                return settings
            })
            
            if let localization = localization {
                transaction.updateSharedData(SharedDataKeys.localizationSettings, { _ in
                    var entries: [LocalizationEntry] = []
                    for (key, value) in localization.dict() {
                        entries.append(LocalizationEntry.string(key: key, value: value))
                    }
                    return LocalizationSettings(primaryComponent: LocalizationComponent(languageCode: localization.code, localizedName: "", localization: Localization(version: 0, entries: entries), customPluralizationCode: nil), secondaryComponent: nil)
                })
            }
            
            transaction.updateSharedData(SharedDataKeys.proxySettings, { current in
                var settings: ProxySettings = current as? ProxySettings ?? .defaultSettings
                if let callsUseProxy = callsUseProxy {
                    settings.useForCalls = callsUseProxy
                }
                
                if let proxyList = proxyList {
                    for item in proxyList {
                        let connection: ProxyServerConnection?
                        if item.isMTProxy, let secret = item.secret {
                            let parsedSecret = MTProxySecret.parse(secret)
                            if let parsedSecret = parsedSecret {
                                connection = .mtp(secret: parsedSecret.serialize())
                            } else {
                                connection = nil
                            }
                        } else if !item.isMTProxy {
                            connection = .socks5(username: item.username ?? "", password: item.password ?? "")
                        } else {
                            connection = nil
                        }
                        if let connection = connection {
                            settings.servers.append(ProxyServerSettings(host: item.server, port: convertLegacyProxyPort(Int(item.port)), connection: connection))
                        }
                    }
                }
                
                if let (server, active) = selectedProxy {
                    if !settings.servers.contains(server) {
                        settings.servers.insert(server, at: 0)
                    }
                    settings.activeServer = server
                    settings.enabled = active
                }
                
                return settings
            })
            
            if let secretInlineBotsInitialized = secretInlineBotsInitialized, secretInlineBotsInitialized {
                ApplicationSpecificNotice.setSecretChatInlineBotUsage(transaction: transaction)
            }
            
            if let allowSecretWebpagesInitialized = allowSecretWebpagesInitialized, allowSecretWebpagesInitialized, let allowSecretWebpages = allowSecretWebpages {
                ApplicationSpecificNotice.setSecretChatLinkPreviews(transaction: transaction, value: allowSecretWebpages)
            }
            
            return account.postbox.transaction { transaction -> Void in
                transaction.updatePreferencesEntry(key: PreferencesKeys.contactsSettings, { current in
                    var settings = current as? ContactsSettings ?? ContactsSettings.defaultSettings
                    if let contactsInhibitSync = contactsInhibitSync, contactsInhibitSync {
                        settings.synchronizeContacts = false
                    }
                    return settings
                })
            }
        }
        |> switchToLatest
        |> ignoreValues
    }
}
