//
//  NativeWebService.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit
import Combine

/**
 Concrete class for native webs service provider using URLSession
 */
@available(iOS 13.0, *)
public struct NativeWebService: WebService {
    
    public init() { }
    
    @discardableResult
    public func sendRequest<T,E>(request: URLRequest) -> Future<T, E> where T : Decodable, E : WebServiceError, E : Error {
        
        return Future { promise in
            let requestId = UUID().uuidString
            self.logRequest(request: request, requestId: requestId)
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                                
                let (valid, errorData, error) = self.validateResponse(requestId: requestId, data: data, response: response as? HTTPURLResponse, error: error)
                
                let statusCode: Int?
                if let response = response as? HTTPURLResponse {
                    statusCode = response.statusCode
                } else {
                    statusCode = nil
                }

                guard valid else {
                    promise(.failure(E.init(data: errorData, error: error, statusCode: statusCode)))
                    return
                }

                // Additional checker but it's already sure that data is not null here
                guard let data = data else {
                    promise(.failure(E.init(data: nil, error: error, statusCode: statusCode)))
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    let objects = try decoder.decode(T.self, from: data)
                    promise(.success(objects))
                } catch {
                    promise(.failure(E.init(data: nil, error: error, statusCode: statusCode)))
                    print("Failed to decode", error)
                }
            }
            task.resume()
        }
    }
    
    /// Helper method for logging the request data
    // TODO: Improve the logging using log levels and/or os_log
    private func logRequest(request: URLRequest, requestId: String = UUID().uuidString) {
        print("[REQUEST] -\(requestId)")
        print("[METHOD] \(request.httpMethod ?? "")")
        print("[URL]: \(request.url?.absoluteString ?? "")")
        
        var headerToPrint = request.allHTTPHeaderFields
        headerToPrint?["Authorization"] = ""

        if let headerData = try? JSONEncoder().encode(headerToPrint),
           let headerJsonString = headerData.prettyPrintedJSONString {
            print("[HEADERS]:")
            print(headerJsonString)
        }

        if let httpBody = request.httpBody {
            if let bodyString = httpBody.prettyPrintedJSONString {
                print("[BODY]:")
                print(bodyString)

            } else if let bodyString = String(data: httpBody as Data, encoding: .utf8) {
                print("[BODY]:")
                print(bodyString)
            }
        }
    }
        
    /// Handle and validate the response
    private func validateResponse<T: Any>(requestId: String,
                                          data: T?,
                                          response: HTTPURLResponse?,
                                          error: Error?) -> (Bool, Data?, Error?)  {
        
        // TODO: Improve the logging using log levels and/or os_log
        print("")
        print("[RESPONSE] -\(requestId)")

        if let error = error {
            print("Failed to fetch \(T.self): ", error)
            return (false, data as? Data, error)
        }

        guard let response = response else {
            return (false, data as? Data, HTTPError.runtimeError("Invalid Response"))
        }

        print("[STATUS CODE]: \(response.statusCode)")
        print("Successfully fetched \(T.self)")
        
        if let jsonString = (data as? Data)?.prettyPrintedJSONString {
            print(jsonString)
        }
        
        
        guard (200...299).contains(response.statusCode) else {
            return (false, data as? Data, nil)
        }
        
        return (true, nil, nil)
    }
}
