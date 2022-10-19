//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FoundationHTTPHandler.swift
//  Starscream
//
//  Created by Dalton Cherry on 1/25/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation
#if os(watchOS)
public typealias FoundationHTTPHandler = StringHTTPHandler
#else
public class FoundationHTTPHandler: HTTPHandler {

    var buffer = Data()
    weak var delegate: HTTPHandlerDelegate?
    
    public init() {
        
    }
    
    public func convert(request: URLRequest) -> Data {
        let msg = CFHTTPMessageCreateRequest(kCFAllocatorDefault, request.httpMethod! as CFString,
                                             request.url! as CFURL, kCFHTTPVersion1_1).takeRetainedValue()
        if let headers = request.allHTTPHeaderFields {
            for (aKey, aValue) in headers {
                CFHTTPMessageSetHeaderFieldValue(msg, aKey as CFString, aValue as CFString)
            }
        }
        if let body = request.httpBody {
            CFHTTPMessageSetBody(msg, body as CFData)
        }
        guard let data = CFHTTPMessageCopySerializedMessage(msg) else {
            return Data()
        }
        return data.takeRetainedValue() as Data
    }
    
    public func parse(data: Data) -> Int {
        let offset = findEndOfHTTP(data: data)
        if offset > 0 {
            buffer.append(data.subdata(in: 0..<offset))
        } else {
            buffer.append(data)
        }
        if parseContent(data: buffer) {
            buffer = Data()
        }
        return offset
    }
    
    //returns true when the buffer should be cleared
    func parseContent(data: Data) -> Bool {
        var pointer = [UInt8]()
        data.withUnsafeBytes { pointer.append(contentsOf: $0) }

        let response = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false).takeRetainedValue()
        if !CFHTTPMessageAppendBytes(response, pointer, data.count) {
            return false //not enough data, wait for more
        }
        if !CFHTTPMessageIsHeaderComplete(response) {
            return false //not enough data, wait for more
        }
        
        let code = CFHTTPMessageGetResponseStatusCode(response)
        if code != HTTPWSHeader.switchProtocolCode {
            delegate?.didReceiveHTTP(event: .failure(HTTPUpgradeError.notAnUpgrade(code)))
            return true
        }
        
        if let cfHeaders = CFHTTPMessageCopyAllHeaderFields(response) {
            let nsHeaders = cfHeaders.takeRetainedValue() as NSDictionary
            var headers = [String: String]()
            for (key, value) in nsHeaders {
                if let key = key as? String, let value = value as? String {
                    headers[key] = value
                }
            }
            delegate?.didReceiveHTTP(event: .success(headers))
            return true
        }
        
        delegate?.didReceiveHTTP(event: .failure(HTTPUpgradeError.invalidData))
        return true
    }
    
    public func register(delegate: HTTPHandlerDelegate) {
        self.delegate = delegate
    }
    
    private func findEndOfHTTP(data: Data) -> Int {
        let endBytes = [UInt8(ascii: "\r"), UInt8(ascii: "\n"), UInt8(ascii: "\r"), UInt8(ascii: "\n")]
        var pointer = [UInt8]()
        data.withUnsafeBytes { pointer.append(contentsOf: $0) }
        var k = 0
        for i in 0..<data.count {
            if pointer[i] == endBytes[k] {
                k += 1
                if k == 4 {
                    return i + 1
                }
            } else {
                k = 0
            }
        }
        return -1
    }
}
#endif
