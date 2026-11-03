// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Joannis Orlandos on 8/11/22.
//

import Foundation

public struct XMLDocumentType {
    public enum External: String {
        case `public` = "PUBLIC"
        case system = "SYSTEM"
    }
    
    public let rootElement: String
    public let external: External
    public let dtdName: String?
    public let dtdLocation: String
    
    internal init(
        rootElement: String,
        external: External,
        dtdName: String?,
        dtdLocation: String
    ) {
        self.rootElement = rootElement
        self.external = external
        self.dtdName = dtdName
        self.dtdLocation = dtdLocation
    }
    
    public static func `public`(rootElement: String, dtdName: String, dtdLocation: String) -> XMLDocumentType {
        XMLDocumentType(
            rootElement: rootElement,
            external: .public,
            dtdName: dtdName,
            dtdLocation: dtdLocation
        )
    }
    
    public static func system(rootElement: String, dtdLocation: String) -> XMLDocumentType {
        XMLDocumentType(
            rootElement: rootElement,
            external: .system,
            dtdName: nil,
            dtdLocation: dtdLocation
        )
    }
    
    func toXML() -> String {
        var string = "<!DOCTYPE \(rootElement) \(external.rawValue)"
        
        if let dtdName = dtdName {
            string += " \"\(dtdName)\""
        }
        
        string += " \"\(dtdLocation)\""
        
        string += ">\n"
        
        return string
    }
}
