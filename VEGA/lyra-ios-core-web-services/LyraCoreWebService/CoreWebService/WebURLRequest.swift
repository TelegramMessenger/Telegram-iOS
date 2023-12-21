//
//  WebURLRequest.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit

/**
 An object for building URLRequest.
 */
struct WebURLRequest {
    
    private(set) var request: URLRequest?
    private let config: WebServiceConfig
    private let urlProvider: URLProvider
    
    init(config: WebServiceConfig, urlProvider: URLProvider) {
        self.config = config
        self.urlProvider = urlProvider
    }
    
    /**
     Utility method for creating `GET` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated `URLRequest`.*/
    mutating func getRequest(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, withAccessToken: Bool = true) -> URLRequest {
        return self.createRequest(pathComponents: pathComponents ?? [],
                                  method: .get,
                                  urlParameters: urlParameters ?? [:],
                                  withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `POST` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - body: Key-valued type to be added as `Data` in `URLRequest`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func postRequest(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, body: [String: Any]?, withAccessToken: Bool = true) -> URLRequest {
        return self.createRequest(pathComponents: pathComponents ?? [],
                                  method: .post,
                                  urlParameters: urlParameters ?? [:],
                                  body: body,
                                  withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `POST` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - body: Array  of Key-valued type to be added as `Data` in `URLRequest`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createPostRequest(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, body: [[String: Any]]?, withAccessToken: Bool = true) -> URLRequest {
        return self.createRequest(pathComponents: pathComponents ?? [],
                                  method: .post,
                                  urlParameters: urlParameters ?? [:],
                                  body: body,
                                  withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `POST` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - body: An object that conforms to `Encodable` to be added as `Data` in `URLRequest`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createPostRequest<Body: Encodable>(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, body: Body?, withAccessToken: Bool = true) -> URLRequest {
        return self.createRequest(pathComponents: pathComponents ?? [],
                                  method: .post,
                                  urlParameters: urlParameters ?? [:],
                                  body: body,
                                  withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `POST` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createPostRequest(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, withAccessToken: Bool = true) -> URLRequest {
        return createRequest(pathComponents: pathComponents ?? [],
                             method: .post,
                             urlParameters: urlParameters ?? [:],
                             bodyData: nil,
                             withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `PUT` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - body: Array  of Key-valued type to be added as `Data` in `URLRequest`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createPutRequest(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, body: [String: Any]?, withAccessToken: Bool = true) -> URLRequest {
        return self.createRequest(pathComponents: pathComponents ?? [],
                                  method: .put,
                                  urlParameters: urlParameters ?? [:],
                                  body: body,
                                  withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `PUT` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - body: An object that conforms to `Encodable` to be added as `Data` in `URLRequest`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createPutRequest<Body: Encodable>(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, body: Body?, withAccessToken: Bool = true) -> URLRequest {
        return self.createRequest(pathComponents: pathComponents ?? [],
                                  method: .put,
                                  urlParameters: urlParameters ?? [:],
                                  body: body,
                                  withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `PUT` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createPutRequest(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, withAccessToken: Bool = true) -> URLRequest {
        return createRequest(pathComponents: pathComponents ?? [],
                             method: .put,
                             urlParameters: urlParameters ?? [:],
                             bodyData: nil,
                             withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `PATCH` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - body: Array  of Key-valued type to be added as `Data` in `URLRequest`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createPatchRequest(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, body: [String: Any]?, withAccessToken: Bool = true) -> URLRequest {
        return self.createRequest(pathComponents: pathComponents ?? [],
                                  method: .patch,
                                  urlParameters: urlParameters ?? [:],
                                  body: body,
                                  withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `PATCH` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - body: An object that conforms to `Encodable` to be added as `Data` in `URLRequest`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createPatchRequest<Body: Encodable>(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, body: Body?, withAccessToken: Bool = true) -> URLRequest {
        return self.createRequest(pathComponents: pathComponents ?? [],
                                  method: .patch,
                                  urlParameters: urlParameters ?? [:],
                                  body: body,
                                  withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `DELETE` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - body: Array  of Key-valued type to be added as `Data` in `URLRequest`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createDeleteRequest(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, body: [String: Any]?, withAccessToken: Bool = true) -> URLRequest {
        return self.createRequest(pathComponents: pathComponents ?? [],
                                  method: .delete,
                                  urlParameters: urlParameters ?? [:],
                                  body: body,
                                  withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `DELETE` request
     
     - Parameters:
       - pathComponents: Array of string to append on url's API. Eg. ["component1","component"] will be appended as "/component1/component2"
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - body: An object that conforms to `Encodable` to be added as `Data` in `URLRequest`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createDeleteRequest<Body: Encodable>(pathComponents: [String]? = nil, urlParameters: [String: String]? = nil, body: Body?, withAccessToken: Bool = true) -> URLRequest {
        return self.createRequest(pathComponents: pathComponents ?? [],
                                  method: .delete,
                                  urlParameters: urlParameters ?? [:],
                                  body: body,
                                  withAccessToken: withAccessToken)
    }
    
    /**
     Utility method for creating `GET` request  provided with full url path
     
     - Parameters:
       - fullPath: Full path of url string
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createGetRequest(fullPath: String, withAccessToken: Bool) -> URLRequest? {
        
        guard let url = urlProvider.url(forFullPath: fullPath) else {
            return nil
        }
                
        request = URLRequest(url: url)
        setMethod(.get)
        setDefautHeaders(withAccessToken: withAccessToken)
        setConfigHeaders()
        return request
    }
    
    /**
     Utility method for creating `GET` request  provided with custom url
     
     - Parameters:
       - customUrl: Custom url string
       - urlParameters: Key value pair to be mapped as `URLQueryItem`
       - withAccessToken: Indicator if the request will use bearer token. Default is `true`

     - Returns: A  generated URLRequest.*/
    mutating func createGetRequest(customUrl: String, urlParameters: [String: String]? = nil, withAccessToken: Bool) -> URLRequest? {
        
        guard let url = urlProvider.url(forCustomUrl: customUrl, urlParameters: urlParameters ?? [:]) else {
            return nil
        }
        
        request = URLRequest(url: url)
        setMethod(.get)
        setDefautHeaders(withAccessToken: withAccessToken)
        setConfigHeaders()
        return request
    }
    
    /**
     Generate the URLRequest
     */
    mutating func createRequest(pathComponents: [String], method: HttpMethod, urlParameters: [String: String], bodyData: Data?, withAccessToken: Bool) -> URLRequest {
        request = URLRequest(url: urlProvider.url(for: pathComponents, urlParameters: urlParameters))
        setMethod(method)
        setDefautHeaders(withAccessToken: withAccessToken)
        setBody(bodyData)
        setConfigHeaders()
        return request ?? URLRequest(url: urlProvider.url(for: pathComponents, urlParameters: urlParameters))
    }
    
    /**
     Generate a URLRequest with body as `Dictionary`
     */
    mutating func createRequest(pathComponents: [String], method: HttpMethod, urlParameters: [String: String], body: [String: Any]? = nil, withAccessToken: Bool) -> URLRequest {
        let data = body != nil ? try? JSONSerialization.data(withJSONObject: body!, options: .prettyPrinted) : nil
        return createRequest(pathComponents: pathComponents, method: method, urlParameters: urlParameters, bodyData: data, withAccessToken: withAccessToken)
    }
    
    /**
     Generate a URLRequest with body as `Array` of `Dictionary`
     */
    mutating func createRequest(pathComponents: [String], method: HttpMethod, urlParameters: [String: String], body: [[String: Any]]?, withAccessToken: Bool) -> URLRequest {
        let data = body != nil ? try? JSONSerialization.data(withJSONObject: body!, options: .prettyPrinted) : nil
        return createRequest(pathComponents: pathComponents, method: method, urlParameters: urlParameters, bodyData: data, withAccessToken: withAccessToken)
    }
    
    /**
     Generate a URLRequest with body as `Encodable` object
     */
    mutating func createRequest<Body: Encodable>(pathComponents: [String], method: HttpMethod, urlParameters: [String: String], body: Body?, withAccessToken: Bool) -> URLRequest {
        let data = body != nil ? try? JSONEncoder().encode(body!) : nil
        return createRequest(pathComponents: pathComponents, method: method, urlParameters: urlParameters, bodyData: data, withAccessToken: withAccessToken)
    }
    
    /**
     Mutate `WebURLRequest` by setting the body data
     */
    public mutating func setBody(_ body: [String: Any]?) {
        guard let b = body else { return }
        setBody(try? JSONSerialization.data(withJSONObject: b, options: .prettyPrinted))
    }
    
    /**
     Attach the httpBody to `URLRequest`
     */
    public mutating func setBody(_ body: Data?) {
        request?.httpBody = body
    }
    
    /**
     Set the HTTPMethod of `URLRequest`
     */
    public mutating func setMethod(_ method: HttpMethod) {
        request?.httpMethod = method.rawValue
    }
    
    /**
     Set a header value to `URLRequest`
     */
    public mutating func setHeader(field: String, value: String?) {
        request?.allHTTPHeaderFields?[field] = value
    }
    
    /**
     Set default headers of `URLRequest`
     */
    public mutating func setDefautHeaders(withAccessToken: Bool) {
        if request?.allHTTPHeaderFields == nil {
            request?.allHTTPHeaderFields = [:]
        }
        
        guard withAccessToken else {
            return
        }
        
        setAuthorizationHeader()
    }
    
    /**
     Set Authorization header of `URLRequest`
     */
    public mutating func setAuthorizationHeader() {
        guard let token = config.accessToken, !token.isEmpty else { return }
        setHeader(field: "Authorization", value: "Bearer \(token)")
    }
    
    /**
     Set config headers
     */
    
    public mutating func setConfigHeaders() {
        
        config.headers.forEach {
            setHeader(field: $0.0, value: $0.1)
        }
        
    }
}

