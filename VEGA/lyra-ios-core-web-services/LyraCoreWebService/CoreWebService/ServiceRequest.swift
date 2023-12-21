//
//  ServiceRequest.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit
import Combine

/**
 Object for  creation and handling of the API requests
 */
@available(iOS 13.0, *)
public protocol APIServiceRequest {
    associatedtype Provider
    
    // A URL Provider that generates the URLRequest
    var urlProvider: Provider { get set }
    
    // Configurations for customizing the URLRequest
    var config: WebServiceConfig { get set }
    
    // Web service to be used for calling the API request
    var webService: WebService { get set }
    
    // Set config values
    mutating func setAccessToken(_ accessToken: String?)
    mutating func setHeaders(_ headers: [String:String])
    mutating func addHeader(value: String, for key: String)
    mutating func addHeaders(_ headers: [String:String])
    
}

@available(iOS 13.0, *)
extension APIServiceRequest {
    
    public mutating func setAccessToken(_ accessToken: String?) {
        self.config.accessToken = accessToken
    }
    
    public mutating func setHeaders(_ headers: [String:String]) {
        self.config.headers = headers
    }
    
    public mutating func addHeader(value: String, for key: String) {
        self.config.addHeader(value: value, for: key)
    }
    
    public mutating func addHeaders(_ headers: [String:String]) {
        self.config.addHeaders(headers)
    }
    
}



