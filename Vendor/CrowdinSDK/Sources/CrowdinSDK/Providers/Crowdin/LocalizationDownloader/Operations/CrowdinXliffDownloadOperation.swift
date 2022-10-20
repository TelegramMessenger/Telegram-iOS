//
//  CrowdinXliffDownloadOperation.swift
//  BaseAPI
//
//  Created by Serhii Londar on 12.04.2020.
//

import Foundation

typealias CrowdinXliffDownloadOperationCompletion = ([String: String]?, [AnyHashable: Any]?, Error?) -> Void

extension String {
    fileprivate var isXib: Bool { hasSuffix(".xib") }
    fileprivate var isStorybaord: Bool { hasSuffix(".storyboard") }
}

class XliffDictionaryParser {
    static func parse(xliffDict: [AnyHashable: Any]) -> ([String: String], [AnyHashable: Any]) {
        var strings = [String: String]()
        var plurals = [AnyHashable: Any]()
        if let xliff = xliffDict["xliff"] as? [AnyHashable: Any], let files = xliff["file"] as? [[AnyHashable: Any]] {
            for file in files {
                if let attributes = file["XMLParserAttributesKey"] as? [String: String], let original = attributes["original"] {
                    if original.isStrings || original.isXib || original.isStorybaord { // Parse strings
                        if let body = file["body"] as? [AnyHashable: Any], let transUnits = body["trans-unit"] as? [[String: Any]] {
                            for transUnit in transUnits {
                                if let attributes = transUnit["XMLParserAttributesKey"] as? [String: String], let id = attributes["id"], let target = transUnit["target"] as? [String: Any], let textKey = target["XMLParserTextKey"] as? String {
                                    strings[id] = textKey
                                }
                            }
                        }
                    } else if original.isStringsDict { // Parse Plurals
                        if let body = file["body"] as? [AnyHashable: Any], let transUnits = body["trans-unit"] as? [[String: Any]] {
                            for transUnit in transUnits {
                                if let attributes = transUnit["XMLParserAttributesKey"] as? [String: String], let id = attributes["id"], let target = transUnit["target"] as? [String: Any], let textKey = target["XMLParserTextKey"] as? String {
                                    var path = id.split(separator: "/").map({ String($0) }).map({ $0.split(separator: ":").map({ String($0) }) })
                                    if path.count > 1 {
                                        path.removeLast()
                                        path[path.count - 1][1] = "string"
                                    }
                                    var currentDict = [AnyHashable: Any]()
                                    for index in (0..<path.count).reversed() {
                                        let currentPath = path[index]
                                        if currentPath.count == 2, currentPath[1] == "dict" {
                                            let key = currentPath[0]
                                            currentDict = [key: currentDict]
                                            strings.removeValue(forKey: key)
                                        } else if currentPath.count == 2, currentPath[1] == "string" {
                                            let key = currentPath[0]
                                            currentDict[key] = textKey
                                            currentDict["NSStringFormatValueTypeKey"] = "u";
                                            currentDict["NSStringFormatSpecTypeKey"] = "NSStringPluralRuleType";
                                        }
                                    }
                                    plurals.mergeRecursively(with: currentDict)
                                }
                            }
                        }
                    }
                }
            }
        }
        return (strings, plurals)
    }
}

class CrowdinXliffDownloadOperation: CrowdinDownloadOperation {
    var completion: CrowdinXliffDownloadOperationCompletion? = nil
    var strings: [String: String]?
    var plurals: [AnyHashable: Any]?
    var timestamp: TimeInterval?
    var eTagStorage: ETagStorage
    
    init(filePath: String, localization: String, timestamp: TimeInterval?, contentDeliveryAPI: CrowdinContentDeliveryAPI, completion: CrowdinXliffDownloadOperationCompletion?) {
        self.timestamp = timestamp
        self.eTagStorage = ETagStorage(localization: localization)
        super.init(filePath: filePath, contentDeliveryAPI: contentDeliveryAPI)
        self.completion = completion
    }
    
    required init(filePath: String, localization: String, timestamp: TimeInterval?, contentDeliveryAPI: CrowdinContentDeliveryAPI) {
        self.timestamp = timestamp
        self.eTagStorage = ETagStorage(localization: localization)
        super.init(filePath: filePath, contentDeliveryAPI: contentDeliveryAPI)
    }
    
    override func main() {
        let etag = eTagStorage.etags[self.filePath]
        contentDeliveryAPI.getXliff(filePath: filePath, etag: etag, timestamp: timestamp) { [weak self] (xliffDict, etag, error) in
            guard let self = self else { return }
            if let xliffDict = xliffDict {
                let parseResult = XliffDictionaryParser.parse(xliffDict: xliffDict)
                self.strings = parseResult.0
                self.plurals = parseResult.1
            }
            self.eTagStorage.etags[self.filePath] = etag
            self.completion?(self.strings, self.plurals, error)
            self.finish(with: error != nil)
        }
    }
}
