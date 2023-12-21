//
//  WebService.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit
import Combine

/**
 Protocol for web service provider
 */
@available(iOS 13.0, *)
public protocol WebService {
    
    /// Send a request with URLRequest and return a Future publisher with decodable data or Error if there are some
    func sendRequest<T,E>(request: URLRequest) -> Future<T, E> where T : Decodable, E : WebServiceError, E : Error
}
