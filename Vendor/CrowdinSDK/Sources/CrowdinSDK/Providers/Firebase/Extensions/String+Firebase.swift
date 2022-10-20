//
//  String.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 2/25/19.
//

import Foundation

extension String {
    static let symbolsMap = [
        ".": "'U+002E'",
        "/": "'U+002F'",
        "#": "'U+0023'",
        "$": "'U+0024'",
        "[": "'U+005B'",
        "]": "'U+005D'",
        ]
    
    var encodedFirebaseKey: String {
        var result = self
        for (key, value) in String.symbolsMap {
            result = result.replacingOccurrences(of: key, with: value)
        }
        return result
    }
    
    var decodedFirebaseKey: String {
        var result = self
        for (key, value) in String.symbolsMap {
            result = result.replacingOccurrences(of: value, with: key)
        }
        return result
    }
}
