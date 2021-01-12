import Foundation
import NGLogging
import NGRequests

struct GlobalNGSettingsObj: Decodable {
    let gmod: Bool
    let youtube_pip: Bool
    let qr_login_camera: Bool
    let gmod2: Bool
    let gmod3: Bool
    let translate_rules: [TranslateRule]
}

public struct TranslateRule: Codable {
    public let name: String
    public let pattern: String
    public let data_check: String
    public let match_group: Int
}

fileprivate let LOGTAG = extractNameFromPath(#file)

public var VarGNGSettings = GNGSettings()

public class GNGSettings {
    let UD = UserDefaults(suiteName: "GlobalNGSettings")

    public init() {
        UD?.register(defaults:
            [
                "gmod": false,
                "youtube_pip": true,
                "qr_login_camera": false,
                "gmod2": false,
                "gmod3": false,
            ])
    }

    public var gmod: Bool {
        get {
            return UD?.bool(forKey: "gmod") ?? false
        }
        set {
            UD?.set(newValue, forKey: "gmod")
        }
    }

    public var youtube_pip: Bool {
        get {
            return UD?.bool(forKey: "youtube_pip") ?? true
        }
        set {
            UD?.set(newValue, forKey: "youtube_pip")
        }
    }

    public var qr_login_camera: Bool {
        get {
            return UD?.bool(forKey: "qr_login_camera") ?? false
        }
        set {
            UD?.set(newValue, forKey: "qr_login_camera")
        }
    }

    public var gmod2: Bool {
        get {
            return UD?.bool(forKey: "gmod2") ?? false
        }
        set {
            UD?.set(newValue, forKey: "gmod2")
        }
    }

    public var gmod3: Bool {
        get {
            return UD?.bool(forKey: "gmod3") ?? false
        }
        set {
            UD?.set(newValue, forKey: "gmod3")
        }
    }
    
    public var translate_rules: [TranslateRule] {
        get {
            if let savedTranslateRules = UD?.object(forKey: "TranslateRules") as? Data {
                let decoder = PropertyListDecoder()
                do {
                    let loadedTranslateRules = try decoder.decode(Array<TranslateRule>.self, from: savedTranslateRules)
                    return loadedTranslateRules
                } catch let error as NSError {
                    ngLog("Cant load TranslateRules from UD \(error.localizedDescription)", LOGTAG)
                }
            }
            
            return [
                TranslateRule(
                    name: "new_mobile",
                    pattern: "<div class=\"result-container\">([\\s\\S]+)</div><div class=",
                    data_check: "<div class=\"result-container\">",
                    match_group: 1
                ),
                TranslateRule(
                    name: "old_mobile",
                    pattern: "<div dir=\"(ltr|rtl)\" class=\"t0\">([\\s\\S]+)</div><form action=",
                    data_check: "class=\"t0\">",
                    match_group: 2
                )
            ]
        }
        set {
            let encoder = PropertyListEncoder()
            do {
                let encoded = try encoder.encode(newValue)
                UD?.set(encoded, forKey: "TranslateRules")
            } catch let error as NSError {
                ngLog("Cant set TranslateRules to UD \(error)", LOGTAG)
            }
        }
    }
}

func getGlobalSettingsUrl(_ build: String) -> String {
    return "https://raw.githubusercontent.com/nicegram/settings/\(build)/global.json"
}

func parseAndSetGlobalData(data: Data) -> Bool {
    do {
        try JSONDecoder().decode(GlobalNGSettingsObj.self, from: data)
    } catch let error as NSError {
        ngLog("Error: Couldn't decode data into globalsettings model \(error)", LOGTAG)
        return false
    }
    
    
    let parsedSettings = try! JSONDecoder().decode(GlobalNGSettingsObj.self, from: data)
    let currentSettings = VarGNGSettings
    currentSettings.gmod = parsedSettings.gmod
    currentSettings.youtube_pip = parsedSettings.youtube_pip
    currentSettings.qr_login_camera = parsedSettings.qr_login_camera
    currentSettings.gmod2 = parsedSettings.gmod2
    currentSettings.gmod3 = parsedSettings.gmod3
    currentSettings.translate_rules = parsedSettings.translate_rules

    ngLog("GlobalSettings updated \(parsedSettings)", LOGTAG)
    return true
}

public func updateGlobalNGSettings(_ build: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"]) as! String) {
    let url = getGlobalSettingsUrl(build)

    RequestsGet(url: URL(string: url)!).start(next: { data, _ in
        ngLog("Got global settings for \(build)", LOGTAG)
        let settingsResult = parseAndSetGlobalData(data: data)
        
        if !settingsResult && build != "master" {
            updateGlobalNGSettings("master")
        }

    }, error: { _ in
        ngLog("HTTP error \(build)", LOGTAG)
    })
}
