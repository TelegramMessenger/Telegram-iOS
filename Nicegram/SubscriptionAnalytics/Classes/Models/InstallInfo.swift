//
//  InstallInfo.swift
//  Translator
//
//  Created by Vadim Suhodolskiy on 7/10/20.
//  Copyright © 2020 Boris Lysenko. All rights reserved.
//

import Foundation

public struct InstallInfo {
    public let provider: DeepLinkProvider?
    public let url: String?
    public let installDateTimestamp: time_t
    
    public init(provider: DeepLinkProvider? = nil, url: String? = nil, installDateTimestamp: time_t) {
        self.provider = provider
        self.url = url
        self.installDateTimestamp = installDateTimestamp
    }
    
    func toJSON() -> Data? {
        var dictionary: [String: Any] = [:]
        
        if let provider = provider {
            dictionary["provider"] = provider.rawValue
        }
        if let url = url {
            dictionary["source"] = url
        }
        
        dictionary["date_install"] = installDateTimestamp
     
        return try? JSONSerialization.data(withJSONObject: dictionary, options: [])
    }
}
