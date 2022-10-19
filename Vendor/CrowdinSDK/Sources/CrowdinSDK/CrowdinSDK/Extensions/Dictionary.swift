//
//  Dictionary.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/31/19.
//

import Foundation

extension Dictionary {
    mutating func mergeRecursively(with dict: [Key: Value]) {
        for (k, rv) in dict {
            // case of existing left value
            if let lv = self[k] {
                if var lv = lv as? Dictionary, let rv = rv as? Dictionary {
                    lv.mergeRecursively(with: rv)
                    self[k] = lv as? Value
                } else {
                    self[k] = rv
                }
            } else {
                self[k] = rv
            }
        }
    }
    
	mutating func merge(with dict: [Key: Value]) {
		for (k, v) in dict {
			updateValue(v, forKey: k)
		}
	}
	
	static func += (left: inout [Key: Value], right: [Key: Value]) {
		for (k, v) in right {
			left[k] = v
		}
	}
	
	static func + (left: inout [Key: Value], right: [Key: Value]) -> [Key: Value] {
		var result: [Key: Value] = [:]
		for (k, v) in right {
			result[k] = v
		}
		for (k, v) in left {
			result[k] = v
		}
		return result
	}
    
    mutating func trim(header key: Key, placeholder: Value) {
        updateValue(placeholder, forKey: key)
    }
}
