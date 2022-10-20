//
//  URL + addQuery.swift
//  SubscriptionAnalytics
//
//  Created by Vadim Suhodolskiy on 8/7/20.
//

import Foundation

extension URL {
    func addQuery(_ parameters: [String: String?]) -> URL? {
        var components =  URLComponents(string: self.absoluteString)
        var items = [URLQueryItem]()
        
        for (key,value) in parameters {
            let item = URLQueryItem(name: key, value: value)
            items.append(item)
        }
        
        components?.queryItems = items
        
        return components?.url
    }
}
