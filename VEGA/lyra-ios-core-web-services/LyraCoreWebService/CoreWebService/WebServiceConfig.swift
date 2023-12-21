//
//  WebServiceConfig.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit
import CoreTelephony

/// Web configurations necessary for building the url request
public struct WebServiceConfig {
        
    var accessToken: String?
    var headers = [String:String]()
    var environment: WebEnvironment = .development
    
    public init(environment: WebEnvironment, headers: [String:String] = [:], accessToken: String? = nil) {
        self.headers = headers
        self.accessToken = accessToken
        self.environment = environment
    }
    
    mutating func addHeader(value: String, for key: String) {
        self.headers[key] = value
    }
    
    mutating func addHeaders(_ headers: [String:String]) {
        headers.forEach {
            self.headers[$0.0] = $0.1
        }
    }
    
}
