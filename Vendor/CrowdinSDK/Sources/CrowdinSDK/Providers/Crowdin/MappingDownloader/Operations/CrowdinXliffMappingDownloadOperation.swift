//
//  CrowdinPluralsMappingDownloadOperation.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 05.12.2019.
//

import Foundation

class CrowdinXliffMappingDownloadOperation: CrowdinDownloadOperation {
    var completion: (([String: String]?, [AnyHashable: Any]?, Error?) -> Void)? = nil
    var strings: [String: String]?
    var plurals: [AnyHashable: Any]?
    var error: Error?
    
    init(filePath: String, contentDeliveryAPI: CrowdinContentDeliveryAPI, completion: (([String: String]?, [AnyHashable: Any]?, Error?) -> Void)?) {
        super.init(filePath: filePath, contentDeliveryAPI: contentDeliveryAPI)
        self.completion = completion
    }
    
    override init(filePath: String, contentDeliveryAPI: CrowdinContentDeliveryAPI) {
        super.init(filePath: filePath, contentDeliveryAPI: contentDeliveryAPI)
    }
    
    override func main() {
        self.contentDeliveryAPI.getXliffMapping(filePath: self.filePath, etag: nil, timestamp: nil) { [weak self] (xliffDict, error) in
            guard let self = self else { return }
            
            var strings = [String: String]()
            var plurals = [AnyHashable: Any]()
            if let xliff = xliffDict?["xliff"] as? [AnyHashable: Any], let files = xliff["file"] as? [[AnyHashable: Any]] {
                for file in files {
                    if let attributes = file["XMLParserAttributesKey"] as? [String: String], let original = attributes["original"] {
                        if original.isStrings { // Parse strings
                            if let body = file["body"] as? [AnyHashable: Any], let transUnits = body["trans-unit"] as? [[String: Any]] {
                                for transUnit in transUnits {
                                    if let attributes = transUnit["XMLParserAttributesKey"] as? [String: String], let id = attributes["id"], let target = transUnit["target"] as? String {
                                        strings[id] = target
                                    }
                                }
                            }
                        } else if original.isStringsDict { // Parse Plurals
                            if let body = file["body"] as? [AnyHashable: Any], let transUnits = body["trans-unit"] as? [[String: Any]] {
                                for transUnit in transUnits {
                                    if let attributes = transUnit["XMLParserAttributesKey"] as? [String: String], let id = attributes["id"], let target = transUnit["target"] as? String {
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
                                                currentDict[key] = target
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
            self.strings = strings
            self.plurals = plurals
            self.error = error
            self.completion?(self.strings, self.plurals, self.error)
            self.finish(with: error != nil)
        }
    }
}
