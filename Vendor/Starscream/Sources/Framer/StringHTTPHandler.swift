//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  StringHTTPHandler.swift
//  Starscream
//
//  Created by Dalton Cherry on 8/25/19.
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

public class StringHTTPHandler: HTTPHandler {
    
    var buffer = Data()
    weak var delegate: HTTPHandlerDelegate?
    
    public init() {
        
    }
    
    public func convert(request: URLRequest) -> Data {
        guard let url = request.url else {
            return Data()
        }
        
        var path = url.absoluteString
        let offset = (url.scheme?.count ?? 2) + 3
        path = String(path[path.index(path.startIndex, offsetBy: offset)..<path.endIndex])
        if let range = path.range(of: "/") {
            path = String(path[range.lowerBound..<path.endIndex])
        } else {
            path = "/"
            if let query = url.query {
                path += "?" + query
            }
        }
        
        var httpBody = "\(request.httpMethod ?? "GET") \(path) HTTP/1.1\r\n"
        if let headers = request.allHTTPHeaderFields {
            for (key, val) in headers {
                httpBody += "\(key): \(val)\r\n"
            }
        }
        httpBody += "\r\n"
        
        guard var data = httpBody.data(using: .utf8) else {
            return Data()
        }
        
        if let body = request.httpBody {
            data.append(body)
        }
        
        return data
    }
    
    public func parse(data: Data) -> Int {
        let offset = findEndOfHTTP(data: data)
        if offset > 0 {
            buffer.append(data.subdata(in: 0..<offset))
            if parseContent(data: buffer) {
                buffer = Data()
            }
        } else {
            buffer.append(data)
        }
        return offset
    }
    
    //returns true when the buffer should be cleared
    func parseContent(data: Data) -> Bool {
        guard let str = String(data: data, encoding: .utf8) else {
            delegate?.didReceiveHTTP(event: .failure(HTTPUpgradeError.invalidData))
            return true
        }
        let splitArr = str.components(separatedBy: "\r\n")
        var code = -1
        var i = 0
        var headers = [String: String]()
        for str in splitArr {
            if i == 0 {
                let responseSplit = str.components(separatedBy: .whitespaces)
                guard responseSplit.count > 1 else {
                    delegate?.didReceiveHTTP(event: .failure(HTTPUpgradeError.invalidData))
                    return true
                }
                if let c = Int(responseSplit[1]) {
                    code = c
                }
            } else {
                guard let separatorIndex = str.firstIndex(of: ":") else { break }
                let key = str.prefix(upTo: separatorIndex).trimmingCharacters(in: .whitespaces)
                let val = str.suffix(from: str.index(after: separatorIndex)).trimmingCharacters(in: .whitespaces)
                headers[key.lowercased()] = val
            }
            i += 1
        }
        
        if code != HTTPWSHeader.switchProtocolCode {
            delegate?.didReceiveHTTP(event: .failure(HTTPUpgradeError.notAnUpgrade(code)))
            return true
        }
        
        delegate?.didReceiveHTTP(event: .success(headers))
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

