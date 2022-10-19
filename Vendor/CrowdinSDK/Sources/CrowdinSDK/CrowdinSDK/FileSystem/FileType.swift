//
//  FileType.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/24/19.
//

import Foundation

enum FileType: String {
    case plist
    case png
    case lproj
    case strings
    case stringsdict
    case json
    
    var `extension`: String {
        return ".\(self.rawValue)"
    }
}
