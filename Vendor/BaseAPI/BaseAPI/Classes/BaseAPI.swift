//
//  BaseAPI.swift
//  BaseAPI
//
//  Created by Serhii Londar on 12/8/17.
//

import Foundation

#if swift(>=5.1) && os(Linux)
   import FoundationNetworking
#endif

public typealias BaseAPICompletion = (Data?, URLResponse?, Error?) -> Swift.Void
public typealias BaseAPIResult = SynchronousDataTaskResult

open class BaseAPI {
    var session: URLSession
    private let parsingQueue = DispatchQueue(label: "BaseAPI-parsing-queue")
    
    public init() {
        self.session = URLSession(configuration: URLSessionConfiguration.default)
    }
    
    public init(session: URLSession) {
        self.session = session
    }
    
    public func send(request: URLRequest, completion: @escaping BaseAPICompletion) {
        session.dataTask(with: request, completionHandler: completion).resume()
    }
    
    public func send(request: URLRequest) -> BaseAPIResult {
        return session.synchronousDataTask(request: request)
    }
    
    /// MARK - GET
    
    public func get(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, completion: @escaping BaseAPICompletion) {
        let request = Request(url: url, method: .GET, parameters: parameters, headers: headers, body: body)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            let task = session.dataTask(with: urlRequest) { (data, response, error) in
                callbackQueue.async { completion(data, response, error) }
            }
            task.resume()
        } else {
            callbackQueue.async { completion(nil, nil, buildRequest.error) }
        }
    }
    
    public func get(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil) -> BaseAPIResult {
        let request = Request(url: url, method: .GET, parameters: parameters, headers: headers, body: body)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            return session.synchronousDataTask(request: urlRequest)
        } else {
            return (nil, nil, buildRequest.error)
        }
    }
    
    public func ba_get<T: Decodable>(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, success: @escaping (T) -> Void, failure: @escaping (Error) -> Void) {
        self.get(url: url, parameters: parameters, headers: headers, callbackQueue: self.parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    
    public func ba_get(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        self.get(url: url, parameters: parameters, headers: headers, callbackQueue: self.parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    
    /// MARK - private
    
    private func handle<T: Decodable>(data: Data?, response: URLResponse?, error: Error?, callbackQueue: DispatchQueue = .main, success: @escaping (T) -> Void, failure: @escaping (Error) -> Void) {
        if let data = data {
            do {
                let model = try JSONDecoder().decode(T.self, from: data)
                callSuccess(with: model, success: success)
            } catch {
                callFailure(with: error, callbackQueue: callbackQueue, failure: failure)
            }
        } else if let error = error {
            callFailure(with: error, callbackQueue: callbackQueue, failure: failure)
        } else if let response = response {
            callFailure(with: NSError(domain: response.description, code: -9999, userInfo: ["response": response]), callbackQueue: callbackQueue, failure: failure)
        }
    }
    
    private func handle(data: Data?, response: URLResponse?, error: Error?, callbackQueue: DispatchQueue = .main, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        if let resp = response as? HTTPURLResponse, resp.statusCode == 200 {
            callbackQueue.async { success() }
        } else if let error = error {
            callFailure(with: error, callbackQueue: callbackQueue, failure: failure)
        } else if let response = response {
            callFailure(with: NSError(domain: response.description, code: -9999, userInfo: ["response": response]), callbackQueue: callbackQueue, failure: failure)
        }
    }
    
    private func callSuccess<T: Decodable>(with model: T, callbackQueue: DispatchQueue = .main, success: @escaping (T) -> Void) {
        callbackQueue.async { success(model) }
    }
    
    private func callFailure(with error: Error, callbackQueue: DispatchQueue = .main, failure: @escaping (Error) -> Void) {
        callbackQueue.async { failure(error) }
    }
    
    /// MARK - HEAD
    
    public func head(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, callbackQueue: DispatchQueue = .main, completion: @escaping BaseAPICompletion) {
        let request = Request(url: url, method: .HEAD, parameters: parameters, headers: headers, body: nil)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            let task = session.dataTask(with: urlRequest) { (data, response, error) in
                callbackQueue.async { completion(data, response, error) }
            }
            task.resume()
        } else {
            callbackQueue.async { completion(nil, nil, buildRequest.error) }
        }
    }
    
    public func head(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil) -> BaseAPIResult {
        let request = Request(url: url, method: .HEAD, parameters: parameters, headers: headers, body: nil)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            return session.synchronousDataTask(request: urlRequest)
        } else {
            return (nil, nil, buildRequest.error)
        }
    }
    
    public func ba_head<T: Decodable>(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, callbackQueue: DispatchQueue = .main, success: @escaping (T) -> Void, failure: @escaping (Error) -> Void) {
        self.head(url: url, parameters: parameters, headers: headers, callbackQueue: parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    
    /// MARK - POST
    
    public func post(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data?, callbackQueue: DispatchQueue = .main, completion: @escaping BaseAPICompletion) {
        let request = Request(url: url, method: .POST, parameters: parameters, headers: headers, body: body)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            let task = session.dataTask(with: urlRequest) { (data, response, error) in
                callbackQueue.async { completion(data, response, error) }
            }
            task.resume()
        } else {
            callbackQueue.async { completion(nil, nil, buildRequest.error) }
        }
    }
    
    public func post(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data?) -> BaseAPIResult {
        let request = Request(url: url, method: .POST, parameters: parameters, headers: headers, body: body)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            return session.synchronousDataTask(request: urlRequest)
        } else {
            return (nil, nil, buildRequest.error)
        }
    }
    
    public func ba_post<T: Decodable>(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, success: @escaping (T) -> Void, failure: @escaping (Error) -> Void) {
        self.post(url: url, parameters: parameters, headers: headers, body: body, callbackQueue: parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    
    public func ba_post(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        self.post(url: url, parameters: parameters, headers: headers, body: body, callbackQueue: parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    
    /// MARK - PATCH
    
    public func patch(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data?, callbackQueue: DispatchQueue = .main, completion: @escaping BaseAPICompletion) {
        let request = Request(url: url, method: .PATCH, parameters: parameters, headers: headers, body: body)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            let task = session.dataTask(with: urlRequest) { (data, response, error) in
                callbackQueue.async { completion(data, response, error) }
            }
            task.resume()
        } else {
            callbackQueue.async { completion(nil, nil, buildRequest.error) }
        }
    }
    
    public func patch(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data?) -> BaseAPIResult {
        let request = Request(url: url, method: .PATCH, parameters: parameters, headers: headers, body: body)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            return session.synchronousDataTask(request: urlRequest)
        } else {
            return (nil, nil, buildRequest.error)
        }
    }
    
    public func ba_patch<T: Decodable>(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, success: @escaping (T) -> Void, failure: @escaping (Error) -> Void) {
        self.patch(url: url, parameters: parameters, headers: headers, body: body, callbackQueue: parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    
    
    public func ba_patch(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        self.patch(url: url, parameters: parameters, headers: headers, body: body, callbackQueue: parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    /// MARK  - PUT
    
    public func put(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data?, callbackQueue: DispatchQueue = .main, completion: @escaping BaseAPICompletion) {
        let request = Request(url: url, method: .PUT, parameters: parameters, headers: headers, body: body)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            let task = session.dataTask(with: urlRequest) { (data, response, error) in
                callbackQueue.async { completion(data, response, error) }
            }
            task.resume()
        } else {
            callbackQueue.async { completion(nil, nil, buildRequest.error) }
        }
    }
    
    public func put(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data?) -> BaseAPIResult {
        let request = Request(url: url, method: .PUT, parameters: parameters, headers: headers, body: body)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            return session.synchronousDataTask(request: urlRequest)
        } else {
            return (nil, nil, buildRequest.error)
        }
    }
    
    public func ba_put<T: Decodable>(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, success: @escaping (T) -> Void, failure: @escaping (Error) -> Void) {
        self.patch(url: url, parameters: parameters, headers: headers, body: body, callbackQueue: parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    
    public func ba_put(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        self.patch(url: url, parameters: parameters, headers: headers, body: body, callbackQueue: parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    
    /// MARK - DELETE
    
    public func delete(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, completion: @escaping BaseAPICompletion) {
        let request = Request(url: url, method: .DELETE, parameters: parameters, headers: headers, body: body)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            let task = session.dataTask(with: urlRequest) { (data, response, error) in
                callbackQueue.async { completion(data, response, error) }
            }
            task.resume()
        } else {
            callbackQueue.async { completion(nil, nil, buildRequest.error) }
        }
    }
    
    public func delete(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil) -> BaseAPIResult {
        let request = Request(url: url, method: .DELETE, parameters: parameters, headers: headers, body: body)
        let buildRequest = request.request()
        if let urlRequest = buildRequest.request {
            return session.synchronousDataTask(request: urlRequest)
        } else {
            return (nil, nil, buildRequest.error)
        }
    }
    
    public func ba_delete<T: Decodable>(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, success: @escaping (T) -> Void, failure: @escaping (Error) -> Void) {
        self.delete(url: url, parameters: parameters, headers: headers, body: body, callbackQueue: parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    
    public func ba_delete(url: String, parameters: [String: String]? = nil, headers: [String: String]? = nil, body: Data? = nil, callbackQueue: DispatchQueue = .main, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        self.delete(url: url, parameters: parameters, headers: headers, body: body, callbackQueue: parsingQueue) { [weak self] (data, response, error) in
            guard let self = self else { return } // Handle error?
            self.handle(data: data, response: response, error: error, callbackQueue: callbackQueue, success: success, failure: failure)
        }
    }
    
}
