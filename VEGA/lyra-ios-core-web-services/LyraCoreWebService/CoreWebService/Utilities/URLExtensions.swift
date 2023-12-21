//
//  URLExtensions.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit

extension URL {
    public init?(baseUrl: String, parameters: [String: String]) {
        
        let percentEncodedUrl = baseUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        
        var components = URLComponents(string: percentEncodedUrl ?? baseUrl)
        components?.queryItems = parameters.map {
            return URLQueryItem(name: $0.key, value: $0.value)
        }
        
        guard let created = components?.url else { return nil }
        
        self = created
    }
    
    public static func createUrl(fullPath: String, parameters: [String: String]) -> URL? {
        return URL(baseUrl: fullPath, parameters: parameters)
    }
}
