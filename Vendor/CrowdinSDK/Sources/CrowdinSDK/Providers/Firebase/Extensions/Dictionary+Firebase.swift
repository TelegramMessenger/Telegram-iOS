//
//  Dictionary+Firebase.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 2/25/19.
//

import Foundation

extension Dictionary where Key == String {
    func encodeFirebase() -> Dictionary {
        var result = Dictionary()
        for (key, value) in self {
            if let value = value as? Dictionary {
                result[key.encodedFirebaseKey] = value.encodeFirebase() as? Value
            } else {
                result[key.encodedFirebaseKey] = value
            }
        }
        return result
    }
    
    func decodeFirebase() -> Dictionary {
        var result = Dictionary()
        for (key, value) in self {
            if let value = value as? Dictionary {
                result[key.decodedFirebaseKey] = value.decodeFirebase() as? Value
            } else {
                result[key.decodedFirebaseKey] = value
            }
        }
        return result
    }
}
