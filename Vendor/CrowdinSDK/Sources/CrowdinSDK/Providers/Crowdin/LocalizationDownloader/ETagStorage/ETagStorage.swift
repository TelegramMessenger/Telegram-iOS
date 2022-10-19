//
//  ETagStorage.swift
//  BaseAPI
//
//  Created by Serhii Londar on 29.03.2020.
//

import Foundation

class ETagStorage {
    let defaults = UserDefaults.standard
    let localization: String
    
    init(localization: String) {
        self.localization = localization
    }
    
    fileprivate enum Strings: String {
        case CrowdinETagsKey
    }
    
    var etags: [String: String] {
        get {
            let map = UserDefaults.standard.object(forKey: Strings.CrowdinETagsKey.rawValue) as? [String: [String: String]] ?? [String: [String: String]]()
            return map[localization] ?? [:]
        }
        set {
            var map = UserDefaults.standard.object(forKey: Strings.CrowdinETagsKey.rawValue) as? [String: [String: String]] ?? [String: [String: String]]()
            map[localization] = newValue
            UserDefaults.standard.set(map, forKey: Strings.CrowdinETagsKey.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    class func clear() {
        UserDefaults.standard.removeObject(forKey: Strings.CrowdinETagsKey.rawValue)
        UserDefaults.standard.synchronize()
    }
    
    class func clear(for localization: String) {
        var map = UserDefaults.standard.object(forKey: Strings.CrowdinETagsKey.rawValue) as? [String: [String: String]] ?? [String: [String: String]]()
        map[localization] = nil
        UserDefaults.standard.set(map, forKey: Strings.CrowdinETagsKey.rawValue)
        UserDefaults.standard.synchronize()
    }
}
