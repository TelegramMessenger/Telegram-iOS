//
//  URLSessionMock.swift
//  CrowdinSDK-Unit-CrowdinAPI_Tests
//
//  Created by Serhii Londar on 29.10.2019.
//

import Foundation

class URLSessionMock: URLSession {
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void

    var data: Data?
    var error: Error?

    override func dataTask(with request: URLRequest, completionHandler: @escaping CompletionHandler
    ) -> URLSessionDataTask {
        let data = self.data
        let error = self.error

        return URLSessionDataTaskMock {
            completionHandler(data, nil, error)
        }
    }
}

class URLSessionDataTaskMock: URLSessionDataTask {
    private let closure: () -> Void

    init(closure: @escaping () -> Void) {
        self.closure = closure
    }
    
    override func resume() {
        closure()
    }
}
