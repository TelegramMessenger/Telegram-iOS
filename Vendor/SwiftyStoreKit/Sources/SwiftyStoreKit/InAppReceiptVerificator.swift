//
//  InAppReceiptVerificator.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 16/05/2017.
// Copyright (c) 2017 Andrea Bizzotto (bizz84@gmail.com)
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

import Foundation

class InAppReceiptVerificator: NSObject {

    let appStoreReceiptURL: URL?
    init(appStoreReceiptURL: URL? = Bundle.main.appStoreReceiptURL) {
        self.appStoreReceiptURL = appStoreReceiptURL
    }

    var appStoreReceiptData: Data? {
        guard let receiptDataURL = appStoreReceiptURL,
            let data = try? Data(contentsOf: receiptDataURL) else {
            return nil
        }
        return data
    }

    private var receiptRefreshRequest: InAppReceiptRefreshRequest?

    /**
     *  Verify application receipt.
     *  - Parameter validator: Validator to check the encrypted receipt and return the receipt in readable format
     *  - Parameter forceRefresh: If true, refreshes the receipt even if one already exists.
     *  - Parameter refresh: closure to perform receipt refresh (this is made explicit for testability)
     *  - Parameter completion: handler for result
     */
    @discardableResult
    public func verifyReceipt(using validator: ReceiptValidator,
                              forceRefresh: Bool,
                              refresh: InAppReceiptRefreshRequest.ReceiptRefresh = InAppReceiptRefreshRequest.refresh,
                              completion: @escaping (VerifyReceiptResult) -> Void) -> InAppRequest? {
        
        return fetchReceipt(forceRefresh: forceRefresh, refresh: refresh) { result in
            switch result {
            case .success(let receiptData):
                self.verify(receiptData: receiptData, using: validator, completion: completion)
            case .error(let error):
                completion(.error(error: error))
            }
        }
    }
    
    /**
     *  Fetch application receipt. This method does two things:
     *  * If the receipt is missing, refresh it
     *  * If the receipt is available or is refreshed, validate it
     *  - Parameter forceRefresh: If true, refreshes the receipt even if one already exists.
     *  - Parameter refresh: closure to perform receipt refresh (this is made explicit for testability)
     *  - Parameter completion: handler for result
     */
    @discardableResult
    public func fetchReceipt(forceRefresh: Bool,
                             refresh: InAppReceiptRefreshRequest.ReceiptRefresh = InAppReceiptRefreshRequest.refresh,
                             completion: @escaping (FetchReceiptResult) -> Void) -> InAppRequest? {

        if let receiptData = appStoreReceiptData, forceRefresh == false {
            completion(.success(receiptData: receiptData))
            return nil
        } else {
            
            receiptRefreshRequest = refresh(nil) { result in
                
                self.receiptRefreshRequest = nil
                
                switch result {
                case .success:
                    if let receiptData = self.appStoreReceiptData {
                        completion(.success(receiptData: receiptData))
                    } else {
                        completion(.error(error: .noReceiptData))
                    }
                case .error(let e):
                    completion(.error(error: .networkError(error: e)))
                }
            }
            return receiptRefreshRequest
        }
    }
    
    /**
     *  - Parameter receiptData: encrypted receipt data
     *  - Parameter validator: Validator to check the encrypted receipt and return the receipt in readable format
     *  - Parameter completion: handler for result
     */
    private func verify(receiptData: Data, using validator: ReceiptValidator, completion: @escaping (VerifyReceiptResult) -> Void) {
     
        validator.validate(receiptData: receiptData) { result in
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
