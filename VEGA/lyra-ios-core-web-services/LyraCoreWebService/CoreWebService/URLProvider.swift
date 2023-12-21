//
//  URLProvider.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit

/**
 A protocol for creation of URLProvider object
 
 URLProvider object will be injected into the `APIServiceRequest` for generation of URLRequest
 The main responsibilty of the URLProvider is to map the following properties and generate a URLRequest
 - path: The main API path of the request to be appended to the base URL
 - apiVersion: API version
 - environment: Determine which API base url to be used.
 - baseURL: The base URL string to be used.
 */
public protocol URLProvider {
    var path: String? { get set }
    var apiVersion: ApiVersion? { get set }
    var environment: WebEnvironment { get set }
    var baseUrl: String { get }
}

extension URLProvider {
                
    /// Build a URLProvider with path and api version
    private mutating func configure(environment: WebEnvironment, path: String, apiVersion: ApiVersion?) -> URLProvider {
        self.path = path
        self.apiVersion = apiVersion
        self.environment = environment
        return self
    }
    
    /// Build a URL with path components and url parameters
    func url(for pathComponents: [String], urlParameters: [String: String]) -> URL {
        let baseUrl = self.composeAPIUrl(pathComponents: pathComponents)
        if urlParameters.isEmpty {
            
            guard let baseUrl = baseUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return URL(string: baseUrl)!
            }
            
            return URL(string: baseUrl)!
            
        } else {
            return URL(baseUrl: baseUrl, parameters: urlParameters)!
        }
    }
    
    /// Build URL with full path url
    func url(forFullPath fullPath: String) -> URL? {
        
        guard let percentEncodedUrl = fullPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
         
        guard let url = URL(string: percentEncodedUrl) else {
            return nil
        }
        
        return url
        
    }
    
    /// Build URL with custom url and url parameters
    func url(forCustomUrl customUrl: String, urlParameters: [String: String]) -> URL? {
        
        guard let percentEncodedUrl = customUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
         
        if urlParameters.isEmpty {
            
            return URL(string: customUrl)
            
        } else {
            return URL(baseUrl: percentEncodedUrl, parameters: urlParameters)
        }
        
    }
    
    /// Build the API URL string
    private func composeAPIUrl(pathComponents: [String]) -> String {
        
        guard let path = self.path else {
            return "\(baseUrl)"
        }
        
        guard let apiVersion = self.apiVersion else {
            return "\(baseUrl)\(path)"
        }
        
        let components = ([path] + pathComponents).joined(separator: "/")
        return "\(baseUrl)\(apiVersion.path)\(components)"
    }
}

// MARK: Utility Methods

extension URLProvider {
    
    /**
     Generate  a `GET` `URLRequest` using `WebURLRequest`
     */
    public mutating func getRequest(config: WebServiceConfig,
                                    apiVersion: ApiVersion?,
                                    path: String,
                                    pathComponents: [String]? = nil,
                                    urlParameters: [String: String]? = nil,
                                    withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.getRequest(pathComponents: pathComponents, urlParameters: urlParameters, withAccessToken: withAccessToken)
    }
    
    /**
     Generate  a `POST` `URLRequest` using `WebURLRequest`
     */
    public mutating func postRequest(config: WebServiceConfig,
                                     apiVersion: ApiVersion?,
                                     path: String,
                                     pathComponents: [String]? = nil,
                                     urlParameters: [String: String]? = nil,
                                     body: [String: Any]?,
                                     withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.postRequest(pathComponents: pathComponents,
                                      urlParameters: urlParameters,
                                      body: body,
                                      withAccessToken: withAccessToken)
    }
    
    /**
     Generate  a `POST` `URLRequest` using `WebURLRequest`
     */
    public mutating func createPostRequest(config: WebServiceConfig,
                                           apiVersion: ApiVersion?,
                                           path: String,
                                           pathComponents: [String]? = nil,
                                           urlParameters: [String: String]? = nil,
                                           body: [[String: Any]]?,
                                           withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.createPostRequest(pathComponents: pathComponents,
                                            urlParameters: urlParameters,
                                            body: body,
                                            withAccessToken: withAccessToken)
    }
    
    /**
     Generate  a `POST` `URLRequest` using `WebURLRequest`
     */
    public mutating func createPostRequest<Body: Encodable>(config: WebServiceConfig,
                                                            apiVersion: ApiVersion?,
                                                            path: String,
                                                            pathComponents: [String]? = nil,
                                                            urlParameters: [String: String]? = nil,
                                                            body: Body?,
                                                            withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.createPostRequest(pathComponents: pathComponents,
                                            urlParameters: urlParameters,
                                            body: body,
                                            withAccessToken: withAccessToken)
    }
    
    /**
     Generate  a `POST` `URLRequest` using `WebURLRequest`
     */
    public mutating func createPostRequest(config: WebServiceConfig,
                                           apiVersion: ApiVersion?,
                                           path: String,
                                           pathComponents: [String]? = nil,
                                           urlParameters: [String: String]? = nil,
                                           withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.createPostRequest(pathComponents: pathComponents,
                                            urlParameters: urlParameters,
                                            withAccessToken: withAccessToken)
        
    }
    
    /**
     Generate  a `PUT` `URLRequest` using `WebURLRequest`
     */
    public mutating func createPutRequest(config: WebServiceConfig,
                                          apiVersion: ApiVersion?,
                                          path: String,
                                          pathComponents: [String]? = nil,
                                          urlParameters: [String: String]? = nil,
                                          body: [String: Any]?,
                                          withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.createPutRequest(pathComponents: pathComponents,
                                           urlParameters: urlParameters,
                                           body: body,
                                           withAccessToken: withAccessToken)
    }
    
    /**
     Generate  a `PUT` `URLRequest` using `WebURLRequest`
     */
    public mutating func createPutRequest<Body: Encodable>(config: WebServiceConfig,
                                                           apiVersion: ApiVersion?,
                                                           path: String,
                                                           pathComponents: [String]? = nil,
                                                           urlParameters: [String: String]? = nil,
                                                           body: Body?,
                                                           withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.createPutRequest(pathComponents: pathComponents,
                                           urlParameters: urlParameters,
                                           body: body,
                                           withAccessToken: withAccessToken)
    }
    
    /**
     Generate  a `PUT` `URLRequest` using `WebURLRequest`
     */
    public mutating func createPutRequest(config: WebServiceConfig,
                                          apiVersion: ApiVersion?,
                                          path: String,
                                          pathComponents: [String]? = nil,
                                          urlParameters: [String: String]? = nil,
                                          withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.createPutRequest(pathComponents: pathComponents,
                                           urlParameters: urlParameters,
                                           withAccessToken: withAccessToken)
    }
    
    /**
     Generate  a `PATCH` `URLRequest` using `WebURLRequest`
     */
    public mutating func createPatchRequest(config: WebServiceConfig,
                                            apiVersion: ApiVersion?,
                                            path: String,
                                            pathComponents: [String]? = nil,
                                            urlParameters: [String: String]? = nil,
                                            body: [String: Any]?,
                                            withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.createPatchRequest(pathComponents: pathComponents,
                                             urlParameters: urlParameters,
                                             body: body,
                                             withAccessToken: withAccessToken)
    }
    
    /**
     Generate  a `PATCH` `URLRequest` using `WebURLRequest`
     */
    public mutating func createPatchRequest<Body: Encodable>(config: WebServiceConfig,
                                                             apiVersion: ApiVersion?,
                                                             path: String,
                                                             pathComponents: [String]? = nil,
                                                             urlParameters: [String: String]? = nil,
                                                             body: Body?,
                                                             withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.createPatchRequest(pathComponents: pathComponents,
                                             urlParameters: urlParameters,
                                             body: body,
                                             withAccessToken: withAccessToken)
    }
    
    /**
     Generate  a `DELETE` `URLRequest` using `WebURLRequest`
     */
    public mutating func createDeleteRequest(config: WebServiceConfig,
                                             apiVersion: ApiVersion?,
                                             path: String,
                                             pathComponents: [String]? = nil,
                                             urlParameters: [String: String]? = nil,
                                             body: [String: Any]?,
                                             withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.createDeleteRequest(pathComponents: pathComponents,
                                              urlParameters: urlParameters,
                                              body: body,
                                              withAccessToken: withAccessToken)
    }
    
    /**
     Generate  a `DELETE` `URLRequest` using `WebURLRequest`
     */
    public mutating func createDeleteRequest<Body: Encodable>(config: WebServiceConfig,
                                                              apiVersion: ApiVersion?,
                                                              path: String,
                                                              pathComponents: [String]? = nil,
                                                              urlParameters: [String: String]? = nil,
                                                              body: Body?,
                                                              withAccessToken: Bool = true) -> URLRequest {
        let provider = self.configure(environment: config.environment, path: path, apiVersion: apiVersion)
        var webRequest = WebURLRequest(config: config, urlProvider: provider)
        return webRequest.createDeleteRequest(pathComponents: pathComponents,
                                              urlParameters: urlParameters,
                                              body: body,
                                              withAccessToken: withAccessToken)
    }
    
    public mutating func createGetRequest(fullPath: String,
                                          config: WebServiceConfig,
                                          withAccessToken: Bool = true) -> URLRequest? {
        
        var webRequest = WebURLRequest(config: config, urlProvider: self)
        return webRequest.createGetRequest(fullPath: fullPath, withAccessToken: withAccessToken)
        
    }
    
    public mutating func createGetRequest(customUrl: String,
                                          config: WebServiceConfig,
                                          urlParameters: [String: String]? = nil,
                                          withAccessToken: Bool = true) -> URLRequest? {
        
        var webRequest = WebURLRequest(config: config, urlProvider: self)
        return webRequest.createGetRequest(customUrl: customUrl, urlParameters: urlParameters, withAccessToken: withAccessToken)
        
    }

}

