//
//  InAppReceiptVerificatorTests.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 17/05/2017.
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

import XCTest
@testable import SwiftyStoreKit

class TestReceiptValidator: ReceiptValidator {
    var validateCalled = false
    func validate(receiptData: Data, completion: @escaping (VerifyReceiptResult) -> Void) {
        validateCalled = true
        completion(.success(receipt: [:]))
    }
}

class TestInAppReceiptRefreshRequest: InAppReceiptRefreshRequest {
    
    override func start() {
        // do nothing
    }
}

extension VerifyReceiptResult: Equatable {
    
    static public func == (lhs: VerifyReceiptResult, rhs: VerifyReceiptResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success): return true
        case (.error(let lhsError), .error(let rhsError)): return lhsError == rhsError
        default: return false
        }
    }
}

extension ReceiptError: Equatable {
    
    static public func == (lhs: ReceiptError, rhs: ReceiptError) -> Bool {
        switch (lhs, rhs) {
        case (.noReceiptData, .noReceiptData): return true
        case (.noRemoteData, .noRemoteData): return true
        case (.requestBodyEncodeError, .requestBodyEncodeError): return true
        case (.networkError, .networkError): return true
        case (.jsonDecodeError, .jsonDecodeError): return true
        case (.receiptInvalid, .receiptInvalid): return true
        default: return false
        }
    }
}

class InAppReceiptVerificatorTests: XCTestCase {
    
    // MARK: refresh tests (no receipt url or no receipt data)
    func testVerifyReceipt_when_appStoreReceiptURLIsNil_then_callsRefresh() {
        
        let validator = TestReceiptValidator()
        let verificator = InAppReceiptVerificator(appStoreReceiptURL: nil)
        
        var refreshCalled = false
        let request = verificator.verifyReceipt(using: validator, forceRefresh: false, refresh: { (properties, callback) -> InAppReceiptRefreshRequest in
            
            refreshCalled = true
            return TestInAppReceiptRefreshRequest(receiptProperties: properties, callback: callback)
            
        }, completion: { _ in
            
        })
        XCTAssertNotNil(request)
        XCTAssertTrue(refreshCalled)
    }

    func testVerifyReceipt_when_appStoreReceiptURLIsNotNil_noReceiptData_then_callsRefresh() {
        
        let testReceiptURL = makeReceiptURL()
        
        let validator = TestReceiptValidator()
        let verificator = InAppReceiptVerificator(appStoreReceiptURL: testReceiptURL)
        
        var refreshCalled = false
        let request = verificator.verifyReceipt(using: validator, forceRefresh: false, refresh: { (properties, callback) -> InAppReceiptRefreshRequest in
            
            refreshCalled = true
            return TestInAppReceiptRefreshRequest(receiptProperties: properties, callback: callback)
            
        }, completion: { _ in
            
        })
        XCTAssertNotNil(request)
        XCTAssertTrue(refreshCalled)
    }
    
    func testVerifyReceipt_when_appStoreReceiptURLIsNotNil_hasReceiptData_forceRefreshIsTrue_then_callsRefresh() {
        
        let testReceiptURL = makeReceiptURL()
        writeReceiptData(to: testReceiptURL)
        
        let validator = TestReceiptValidator()
        let verificator = InAppReceiptVerificator(appStoreReceiptURL: testReceiptURL)
        
        var refreshCalled = false
        let request = verificator.verifyReceipt(using: validator, forceRefresh: true, refresh: { (properties, callback) -> InAppReceiptRefreshRequest in
            
            refreshCalled = true
            return TestInAppReceiptRefreshRequest(receiptProperties: properties, callback: callback)
            
        }, completion: { _ in
            
        })
        XCTAssertNotNil(request)
        XCTAssertTrue(refreshCalled)
    }

    func testVerifyReceipt_when_appStoreReceiptURLIsNil_refreshCallbackError_then_errorNetworkError() {
        
        let validator = TestReceiptValidator()
        let verificator = InAppReceiptVerificator(appStoreReceiptURL: nil)
        let refreshError = NSError(domain: "", code: 0, userInfo: nil)
        
        let request = verificator.verifyReceipt(using: validator, forceRefresh: false, refresh: { (properties, callback) -> InAppReceiptRefreshRequest in
            
            callback(.error(e: refreshError))
            return TestInAppReceiptRefreshRequest(receiptProperties: properties, callback: callback)
            
        }, completion: { result in
            
            XCTAssertEqual(result, VerifyReceiptResult.error(error: ReceiptError.networkError(error: refreshError)))
        })
        XCTAssertNotNil(request)
    }

    func testVerifyReceipt_when_appStoreReceiptURLIsNil_refreshCallbackSuccess_receiptDataNotWritten_then_errorNoReceiptData_validateNotCalled() {
        
        let validator = TestReceiptValidator()
        let verificator = InAppReceiptVerificator(appStoreReceiptURL: nil)
        
        let request = verificator.verifyReceipt(using: validator, forceRefresh: false, refresh: { (properties, callback) -> InAppReceiptRefreshRequest in
            
            callback(.success)
            return TestInAppReceiptRefreshRequest(receiptProperties: properties, callback: callback)

        }, completion: { result in

            XCTAssertEqual(result, VerifyReceiptResult.error(error: ReceiptError.noReceiptData))
        })
        XCTAssertNotNil(request)
        XCTAssertFalse(validator.validateCalled)
    }

    func testVerifyReceipt_when_appStoreReceiptURLIsNil_noReceiptData_refreshCallbackSuccess_receiptDataWritten_then_errorNoReceiptData_validateNotCalled() {
        
        let testReceiptURL = makeReceiptURL()
        
        let validator = TestReceiptValidator()
        let verificator = InAppReceiptVerificator(appStoreReceiptURL: nil)
        
        let request = verificator.verifyReceipt(using: validator, forceRefresh: false, refresh: { (properties, callback) -> InAppReceiptRefreshRequest in
            
            writeReceiptData(to: testReceiptURL)
            callback(.success)
            return TestInAppReceiptRefreshRequest(receiptProperties: properties, callback: callback)
            
        }, completion: { result in
            
            XCTAssertEqual(result, VerifyReceiptResult.error(error: ReceiptError.noReceiptData))
        })
        XCTAssertNotNil(request)
        XCTAssertFalse(validator.validateCalled)
        removeReceiptData(at: testReceiptURL)
    }
    
    func testVerifyReceipt_when_appStoreReceiptURLIsNotNil_noReceiptData_refreshCallbackSuccess_receiptDataWritten_then_validateIsCalled() {
        
        let testReceiptURL = makeReceiptURL()
        
        let validator = TestReceiptValidator()
        let verificator = InAppReceiptVerificator(appStoreReceiptURL: testReceiptURL)
        
        let request = verificator.verifyReceipt(using: validator, forceRefresh: false, refresh: { (properties, callback) -> InAppReceiptRefreshRequest in
            
            writeReceiptData(to: testReceiptURL)
            callback(.success)
            return TestInAppReceiptRefreshRequest(receiptProperties: properties, callback: callback)
            
        }, completion: { _ in
            
        })
        XCTAssertNil(request)
        XCTAssertTrue(validator.validateCalled)
        removeReceiptData(at: testReceiptURL)
    }
    
    // MARK: non-refresh tests (receipt url and data are set)
    func testVerifyReceipt_when_appStoreReceiptURLIsNotNil_hasReceiptData_forceRefreshIsFalse_then_refreshNotCalled_validateIsCalled() {
        
        let testReceiptURL = makeReceiptURL()
        writeReceiptData(to: testReceiptURL)

        let validator = TestReceiptValidator()
        let verificator = InAppReceiptVerificator(appStoreReceiptURL: testReceiptURL)
        
        let request = verificator.verifyReceipt(using: validator, forceRefresh: false, refresh: { (properties, callback) -> InAppReceiptRefreshRequest in
            
            XCTFail("refresh should not be called if we already have a receipt")
            return TestInAppReceiptRefreshRequest(receiptProperties: properties, callback: callback)
            
        }, completion: { _ in
            
        })
        XCTAssertNil(request)
        XCTAssertTrue(validator.validateCalled)
        removeReceiptData(at: testReceiptURL)
    }
    
    // MARK: Helpers
    func makeReceiptURL() -> URL {
        
        guard let testFolderURL = try? FileManager.default.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: false) else {
            fatalError("Invalid test folder")
        }
        return testFolderURL.appendingPathComponent("receipt.data")
    }
    
    func writeReceiptData(to url: URL) {
        
        guard let testReceiptData = NSData(base64Encoded: "encrypted-receipt", options: .ignoreUnknownCharacters) else {
            fatalError("Invalid receipt data")
        }
        try? testReceiptData.write(to: url)
    }
    
    func removeReceiptData(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

}
