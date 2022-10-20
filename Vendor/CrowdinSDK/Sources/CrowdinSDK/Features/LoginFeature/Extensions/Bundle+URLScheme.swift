//
//  NSBundle+.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 8/19/19.
//

import Foundation

extension Bundle {
    enum Keys: String {
        case CFBundleURLTypes
        case CFBundleURLSchemes
    }
    /// URL types supported by application.
    var urlTypes: [[String: Any]]? {
        return infoDictionary?[Keys.CFBundleURLTypes.rawValue] as? [[String: Any]]
    }
    
    /// Array of URL schemes supported by application.
    var urlSchemes: [String]? {
        var schemes = [String]()
        urlTypes?.forEach({ (dict) in
            guard var values = dict[Keys.CFBundleURLSchemes.rawValue] as? [String] else { return }
            values = values.map({ $0 + "://" })
            schemes.append(contentsOf: values)
        })
        return schemes
    }
}
