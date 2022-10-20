//
//  UILabel.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/23/19.
//

import Foundation
import UIKit

// MARK: - Extension for Bundle method swizzling.
extension Bundle {
    // swiftlint:disable implicitly_unwrapped_optional
    /// Original localizedString(forKey:value:table:) method.
    static var original: Method!
    /// Swizzled localizedString(forKey:value:table:) method.
    static var swizzled: Method!
    
    static var isSwizzled: Bool {
        return original != nil && swizzled != nil
    }
    
    /// Swizzled implementation for localizedString(forKey:value:table:) method.
    ///
    /// - Parameters:
    ///   - key: The key for a string in the table identified by tableName.
    ///   - value: The value to return if key is nil or if a localized string for key can’t be found in the table.
    ///   - tableName: The receiver’s string table to search. If tableName is nil or is an empty string, the method attempts to use the table in Localizable.strings.
    /// - Returns: Localization value for localization key provided by crowdin. If there are no string for provided localization key, localization string from bundle will be returned.
    @objc func swizzled_LocalizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        var translation = Localization.current.localizedString(for: key)
        if translation == nil {
            translation = swizzled_LocalizedString(forKey: key, value: value, table: tableName)
        }
        return translation ?? key
    }

    /// Method for swizzling implementation for localizedString(forKey:value:table:) method.
    class func swizzle() {
        // swiftlint:disable force_unwrapping
        original = class_getInstanceMethod(self, #selector(Bundle.localizedString(forKey:value:table:)))!
        swizzled = class_getInstanceMethod(self, #selector(Bundle.swizzled_LocalizedString(forKey:value:table:)))!
        method_exchangeImplementations(original, swizzled)
    }
    
    /// Method for swizzling implementation back for localizedString(forKey:value:table:) method.
    class func unswizzle() {
        guard original != nil && swizzled != nil else { return }
        method_exchangeImplementations(swizzled, original)
        swizzled = nil
        original = nil
    }
}
