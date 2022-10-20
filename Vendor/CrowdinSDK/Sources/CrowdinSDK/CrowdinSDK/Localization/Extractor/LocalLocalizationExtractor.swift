//
//  LocalLocalizationExtractor.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/24/19.
//

import Foundation

final class LocalLocalizationExtractor {
    enum Strings: String {
        case LocalPlurals
        case LocalizableStringsdict = "Localizable.stringsdict"
    }
    
    static var allLocalizations: [String] { Bundle.main.inBundleLocalizations }
    
    var allKeys: [String] { localizationDict.keys.map({ String($0) }) }
    var allValues: [String] { localizationDict.values.map({ String($0) }) }
    
    var localizationDict: [String: String] = [:]
	var localizationPluralsDict: [AnyHashable: Any] = [:]
    
    var pluralsFolder: FolderProtocol
    var pluralsBundle: DictionaryBundleProtocol?
    
    var localization: String {
        didSet {
            extract()
        }
    }
    
    var isEmpty: Bool { localizationDict.isEmpty && self.localizationPluralsDict.isEmpty }
    
    var stringsFiles: [String] {
        guard let filePath = Bundle.main.path(forResource: localization, ofType: FileType.lproj.rawValue) else { return [] }
        guard var files = try? FileManager.default.contentsOfDirectory(atPath: filePath) else { return [] }
        files = files.map({ filePath + String.pathDelimiter + $0 })
        return files
    }
    
    var stringsdictFiles: [String] {
        guard let filePath = Bundle.main.path(forResource: localization, ofType: FileType.lproj.extension) else { return [] }
        let folder = Folder(path: filePath)
        let files = folder.files.filter({ $0.type == FileType.stringsdict.rawValue })
        return files.map({ $0.path })
    }
    
    init(localization: String) {
        self.localization = localization
        pluralsFolder = Folder(path: CrowdinFolder.shared.path + String.pathDelimiter + Strings.LocalPlurals.rawValue)
        extract()
    }
    
    func setLocalization(_ localization: String) {
        self.localization = localization
        extract()
    }
    
    func extract() {
        localizationDict = [:]
        stringsFiles.forEach { (file) in
            guard let dict = NSDictionary(contentsOfFile: file) else { return }
            self.localizationDict.merge(with: dict as? [String: String] ?? [:])
        }
        
        localizationPluralsDict = [:]
        stringsdictFiles.forEach { (file) in
            guard let dict = NSMutableDictionary (contentsOfFile: file) else { return }
			guard let strings = dict as? [AnyHashable: Any] else { return }
			self.localizationPluralsDict = self.localizationPluralsDict + strings
        }
        setupPluralsBundle()
    }
	
	static func extractLocalizationJSONFile(to path: String) {
		let json = self.extractLocalizationJSON()
		guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else { return }
		try? data.write(to: URL(fileURLWithPath: path))
	}
	
	static func extractLocalizationJSON() -> [String: Any] {
		var result = [String: Any]()
		self.allLocalizations.forEach { (localization) in
			let extractor = LocalLocalizationExtractor(localization: localization)
			var dict = [String: Any]()
			if !extractor.localizationDict.isEmpty {
				dict[Keys.strings.rawValue] = extractor.localizationDict
			}
			if !extractor.localizationPluralsDict.isEmpty {
				dict[Keys.plurals.rawValue] = extractor.localizationPluralsDict
			}
			result[localization] = dict
		}
		return result
	}
    
    func extractLocalizationStrings(to path: String) -> StringsFile {
        let file = StringsFile(path: path + String.pathDelimiter + localization + FileType.strings.extension)
        file.file = self.localizationDict
        try? file.save()
        return file
    }
    
    static func extractAllLocalizationStrings(to path: String) {
        self.allLocalizations.forEach { (localization) in
            let ectractor = LocalLocalizationExtractor(localization: localization)
            _ = ectractor.extractLocalizationStrings(to: path)
        }
    }
    
    func extractLocalizationPlurals(to path: String) -> DictionaryFile {
        let file = DictionaryFile(path: path + String.pathDelimiter + localization + FileType.stringsdict.extension)
        file.file = self.localizationPluralsDict
        try? file.save()
        return file
    }
    
    static func extractAllLocalizationPlurals(to path: String) {
        self.allLocalizations.forEach { (localization) in
            let ectractor = LocalLocalizationExtractor(localization: localization)
            _ = ectractor.extractLocalizationPlurals(to: path)
        }
    }
    
    func setupPluralsBundle() {
        pluralsBundle?.remove()
        pluralsFolder.directories.forEach{ try? $0.remove() }
        let localizationFolderName = localization + String.minus + UUID().uuidString
        pluralsBundle = DictionaryBundle(path: pluralsFolder.path + String.pathDelimiter + localizationFolderName, fileName: Strings.LocalizableStringsdict.rawValue, dictionary: self.localizationPluralsDict)
    }
    
    // Localization methods
    func localizedString(for key: String) -> String? {
        var string = self.localizationDict[key]
        if string == nil {
            string = self.pluralsBundle?.bundle.swizzled_LocalizedString(forKey: key, value: nil, table: nil)
            // Plurals localization works as default bundle localization. In case localized string for key is missing the key string will be returned. To prevent issues with localization where key equals value(for example for english language) we need to set nil here.
            if string == key {
                string = nil
            }
        }
        return string
    }
}
