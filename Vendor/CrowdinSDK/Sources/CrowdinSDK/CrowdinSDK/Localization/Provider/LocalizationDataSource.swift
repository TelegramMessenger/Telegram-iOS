//
//  LocalizationDataSource.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 3/10/19.
//

import Foundation

protocol LocalizationDataSourceProtocol {
    func findKey(for string: String) -> String?
    func findValues(for string: String, with format: String) -> [Any]?
}

class StringsLocalizationDataSource: LocalizationDataSourceProtocol {
    
    var strings: [String: String]
    
    init(strings: [String: String]) {
        self.strings = strings
    }
    
    func findKey(for string: String) -> String? {
        // Simple strings
        for (key, value) in strings {
            if string == value { return key }
        }
        // Formated strings
        for (key, value) in strings {
            if String.findMatch(for: value, with: string) {
                if let values = String.findValues(for: string, with: value) {
                    // Check if localized strign is equal to text.
                    // swiftlint:disable force_cast
                    if key.cw_localized(with: values as! [CVarArg]) == string {
                        return key
                    }
                }
            }
        }
        return nil
    }
    
    func findValues(for string: String, with format: String) -> [Any]? {
        return String.findValues(for: string, with: format)
    }
}

class PluralsLocalizationDataSource: LocalizationDataSourceProtocol {
    private enum Keys: String {
        case NSStringLocalizedFormatKey
        case NSStringFormatSpecTypeKey
        case NSStringFormatValueTypeKey
    }
    
    private enum Rules: String {
        case zero
        case one
        case two
        case few
        case many
        case other
    }
    
    var plurals: [AnyHashable: Any]
    
    init(plurals: [AnyHashable: Any]) {
        self.plurals = plurals
    }
    func findKey(for string: String) -> String? {
        return findKeyAndValues(for: plurals, for: string).key
    }
    
    func findValues(for string: String, with format: String) -> [Any]? {
        return findKeyAndValues(for: plurals, for: string).values
    }
    
    func findKeyAndValues(for plurals: [AnyHashable: Any], for text: String) -> (key: String?, values: [Any]?) {
        guard let plurals = plurals as? [String: Any] else { return (nil, nil) }
        for (key, plural) in plurals {
            guard let plural = plural as? [AnyHashable: Any] else { continue }
            for(pluralKey, value) in plural {
                guard let strinKey = pluralKey as? String else { continue }
                if strinKey == Keys.NSStringLocalizedFormatKey.rawValue { continue }
                guard let value = value as? [String: String] else { continue }
                for (rule, formatedString) in value {
                    guard rule != Keys.NSStringFormatSpecTypeKey.rawValue else { continue }
                    guard rule != Keys.NSStringFormatValueTypeKey.rawValue else { continue }
                    // As plurals can be simple string then check whether it is equal to text. If not do the same as for formated string.
                    if formatedString == text {
                        if let rules = Rules(rawValue: rule) {
                            return (key, [valueForRule(rules)])
                        } else {
                            return (key, [])
                        }
                    }
                    if String.findMatch(for: formatedString, with: text), let values = String.findValues(for: text, with: formatedString) {
                        // Check if localized string is equal to text.
                        // swiftlint:disable force_cast
                        if key.cw_localized(with: values as! [CVarArg]) == text {
                            return (key, values)
                        }
                    }
                }
            }
        }
        return (nil, nil)
    }
    
    private func valueForRule(_ rule: Rules) -> UInt {
        switch rule {
        case .zero:
            return 0
        case .one:
            return 1
        case .two:
            return 2
        case .few:
            return 3
        case .many:
            return 11
        case .other:
            return 1000000
        }
    }
}
