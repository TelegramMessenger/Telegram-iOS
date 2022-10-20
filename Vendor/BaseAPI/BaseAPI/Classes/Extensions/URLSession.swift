//
//  URLSession.swift
//  BaseAPI
//
//  Created by Serhii Londar on 8/22/17.
//
//

import Foundation
import Dispatch

#if swift(>=5.1) && os(Linux)
   import FoundationNetworking
#endif

public typealias SynchronousDataTaskResult = (data: Data?, response: URLResponse?, error: Error?)

extension URLSession {
    public func synchronousDataTask(request: URLRequest) -> SynchronousDataTaskResult {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let dataTask = self.dataTask(with: request) { (rData, rResponse, eError) in
            data = rData
            response = rResponse
            error = eError
            semaphore.signal()
        }
        dataTask.resume()
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        return (data, response, error)
    }
    
    public func synchronousDataTask(url: URL) -> SynchronousDataTaskResult {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let dataTask = self.dataTask(with: url) {
            data = $0
            response = $1
            error = $2
            
            semaphore.signal()
        }
        dataTask.resume()
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        return (data, response, error)
    }
}
