//
//  CrowdinMappingManager.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/6/19.
//

import Foundation

public protocol CrowdinMappingManagerProtocol {
    func stringLocalizationKey(for id: Int) -> String?
    func pluralLocalizationKey(for id: Int) -> String?
    
    func idFor(string: String) -> Int?
    func idFor(plural: String) -> Int?
    
    func id(for string: String) -> Int?
    func key(for id: Int) -> String?
}

public class CrowdinMappingManager: CrowdinMappingManagerProtocol {
    let downloader: CrowdinDownloaderProtocol
    var pluralsMapping: [String: String] = [:]
    var stringsMapping: [String: String] = [:]
    var plurals: [AnyHashable: Any] = [:]
    
    init(hash: String, sourceLanguage: String) {
        self.downloader = CrowdinMappingDownloader()
        self.downloader.download(with: hash, for: sourceLanguage) { (strings, plurals, _) in
            self.stringsMapping = strings ?? [:]
            self.plurals = plurals ?? [:]
            self.extractPluralsMapping()
        }
    }
    
    public func stringLocalizationKey(for id: Int) -> String? {
        return stringsMapping.first(where: { Int($0.value) == id })?.key
    }
    
    public func pluralLocalizationKey(for id: Int) -> String? {
        return pluralsMapping.first(where: { Int($0.value) == id })?.key
    }
    
    public func idFor(string: String) -> Int? {
        guard let stringId = stringsMapping.first(where: { $0.key == string })?.value else { return nil }
        return Int(stringId)
    }
    
    public func idFor(plural: String) -> Int? {
        guard let pluralId = pluralsMapping.first(where: { $0.key == plural })?.value else { return nil }
        return Int(pluralId)
    }
    
    public func key(for id: Int) -> String? {
        return self.stringLocalizationKey(for: id) ?? self.pluralLocalizationKey(for: id)
    }
    
    public func id(for key: String) -> Int? {
        return self.idFor(string: key) ?? self.idFor(plural: key)
    }
}

extension CrowdinMappingManager {
    enum Keys: String {
        case NSStringLocalizedFormatKey
    }
    
    func extractPluralsMapping() {
        pluralsMapping = [:]
        for (key, value) in plurals {
            guard let keyString = key as? String, let valueDict = value as? [AnyHashable: Any] else { continue }
            // Get main id for every key
            if let idString = valueDict[Keys.NSStringLocalizedFormatKey.rawValue] as? String {
                pluralsMapping[keyString] = idString
            }
            
            // Get id for every internal key if it exist.
            for (_, value) in valueDict {
                guard let valueDict = value as? [AnyHashable: Any] else { continue }
                if let idString = idFromDict(valueDict) {
                    pluralsMapping[keyString] = idString
                }
            }
        }
    }
    
    private enum PluralRules: String {
        case zero
        case one
        case two
        case few
        case many
        case other
        
        static var all: [PluralRules] {
            return [.zero, .one, .two, .few, .many, .other]
        }
    }
    
    func idFromDict(_ dict: [AnyHashable: Any]) -> String? {
        for pluralRule in PluralRules.all {
            if let id = dict[pluralRule.rawValue] as? String {
                return id
            }
        }
        return nil
    }
}
