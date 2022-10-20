//
//  InAppReceiptRefreshRequest.swift
//  SwiftyStoreKit
//
//  Created by phimage on 23/12/15.
// Copyright (c) 2015 Andrea Bizzotto (bizz84@gmail.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import StoreKit
import Foundation

class InAppReceiptRefreshRequest: NSObject, SKRequestDelegate, InAppRequest {

    enum ResultType {
        case success
        case error(e: Error)
    }

    typealias RequestCallback = (ResultType) -> Void
    typealias ReceiptRefresh = (_ receiptProperties: [String: Any]?, _ callback: @escaping RequestCallback) -> InAppReceiptRefreshRequest

    class func refresh(_ receiptProperties: [String: Any]? = nil, callback: @escaping RequestCallback) -> InAppReceiptRefreshRequest {
        let request = InAppReceiptRefreshRequest(receiptProperties: receiptProperties, callback: callback)
        request.start()
        return request
    }

    let refreshReceiptRequest: SKReceiptRefreshRequest
    let callback: RequestCallback

    deinit {
        refreshReceiptRequest.delegate = nil
    }

    init(receiptProperties: [String: Any]? = nil, callback: @escaping RequestCallback) {
        self.callback = callback
        self.refreshReceiptRequest = SKReceiptRefreshRequest(receiptProperties: receiptProperties)
        super.init()
        self.refreshReceiptRequest.delegate = self
    }

    func start() {
        self.refreshReceiptRequest.start()
    }

    func cancel() {
        self.refreshReceiptRequest.cancel()
    }
    
    func requestDidFinish(_ request: SKRequest) {
        /*if let resoreRequest = request as? SKReceiptRefreshRequest {
         let receiptProperties = resoreRequest.receiptProperties ?? [:]
         for (k, v) in receiptProperties {
         print("\(k): \(v)")
         }
         }*/
        performCallback(.success)
    }
    func request(_ request: SKRequest, didFailWithError error: Error) {
        // XXX could here check domain and error code to return typed exception
        performCallback(.error(e: error))
    }
    private func performCallback(_ result: ResultType) {
        DispatchQueue.main.async {
            self.callback(result)
        }
    }
}
