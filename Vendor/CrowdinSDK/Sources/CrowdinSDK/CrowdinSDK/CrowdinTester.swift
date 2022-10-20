//
//  CrowdinTester.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 3/24/19.
//

import Foundation

/// Class for SDK testing.
public class CrowdinTester {
    /// Concrete localization code for testing.
    var localization: String
    /// Localization file presentation with all downloaded localizations from crowdin server(strings and plurals).
    /// This file is in dictionary format.
    let localizationFile: DictionaryFile
    
    /// Initialization method.
    ///
    /// - Parameter localization: Localization code for testing.
    public init(localization: String) {
        self.localization = localization
        let path = CrowdinFolder.shared.path + String.pathDelimiter + Strings.Crowdin.rawValue + String.pathDelimiter + localization + FileType.plist.extension
        self.localizationFile = DictionaryFile(path: path)
    }
    
    /// List of all downloaded localizations.
    public class var downloadedLocalizations: [String] {
        return CrowdinFolder.shared.files.map({ $0.name })
    }
    
    /// All localization strins keys for current localization.
    public var inSDKStringsKeys: [String] {
        guard let strings = localizationFile.file?[Keys.strings.rawValue] as? [String: String] else { return [] }
        return strings.keys.map({ $0 })
    }
    
    /// All localization plurals keys for current localization.
    public var inSDKPluralsKeys: [String] {
        guard let plurals = localizationFile.file?[Keys.plurals.rawValue] as? [AnyHashable: Any] else { return [] }
        return plurals.keys.compactMap({ $0 as? String })
    }
}
