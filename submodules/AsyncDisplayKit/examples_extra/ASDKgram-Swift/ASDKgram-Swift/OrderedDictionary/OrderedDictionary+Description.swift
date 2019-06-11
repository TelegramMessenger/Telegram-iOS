//
//  OrderedDictionary+Description.swift
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

extension OrderedDictionary: CustomStringConvertible {
    
    /// A textual representation of the ordered dictionary.
    public var description: String {
        return makeDescription(debug: false)
    }
    
}

extension OrderedDictionary: CustomDebugStringConvertible {
    
    /// A textual representation of the ordered dictionary, suitable for debugging.
    public var debugDescription: String {
        return makeDescription(debug: true)
    }
    
}

extension OrderedDictionary {
    
    fileprivate func makeDescription(debug: Bool) -> String {
        // The implementation of the description is inspired by zwaldowski's implementation of the
        // ordered dictionary. See http://bit.ly/2iqGhrb
        
        if isEmpty { return "[:]" }
        
        let printFunction: (Any, inout String) -> () = {
            if debug {
                return { debugPrint($0, separator: "", terminator: "", to: &$1) }
            } else {
                return { print($0, separator: "", terminator: "", to: &$1) }
            }
        }()
        
        let descriptionForItem: (Any) -> String = { item in
            var description = ""
            printFunction(item, &description)
            return description
        }
        
        let bodyComponents = map { element in
            return descriptionForItem(element.key) + ": " + descriptionForItem(element.value)
        }
        
        let body = bodyComponents.joined(separator: ", ")
        
        return "[\(body)]"
    }
    
}
