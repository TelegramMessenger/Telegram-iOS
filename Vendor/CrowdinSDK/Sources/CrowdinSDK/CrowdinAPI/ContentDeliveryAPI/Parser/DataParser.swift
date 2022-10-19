//
//  DataParser.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 4/8/19.
//

import Foundation

protocol DataParser {
    associatedtype `Type`
    
    static func parse(data: Data) -> Type?
}

class PropertyListDataParser: DataParser {
    typealias `Type` = [AnyHashable: Any]
    
    static func parse(data: Data) -> [AnyHashable: Any]? {
        var propertyListForamat = PropertyListSerialization.PropertyListFormat.xml
        if let dictionary = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: &propertyListForamat) as? [AnyHashable: Any] {
            return dictionary
        }
        return nil
    }
}

class XLIFFDataParser: DataParser {
    typealias `Type` = [AnyHashable: Any]
    
    static func parse(data: Data) -> [AnyHashable: Any]? {
        if let dictionary = SwiftXMLParser().makeDic(data: data) {
            return dictionary
        }
        return nil
    }
}
