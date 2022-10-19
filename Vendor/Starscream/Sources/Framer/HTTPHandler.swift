//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPHandler.swift
//  Starscream
//
//  Created by Dalton Cherry on 1/24/19.
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

public enum HTTPUpgradeError: Error {
    case notAnUpgrade(Int)
    case invalidData
}

public struct HTTPWSHeader {
    static let upgradeName        = "Upgrade"
    static let upgradeValue       = "websocket"
    static let hostName           = "Host"
    static let connectionName     = "Connection"
    static let connectionValue    = "Upgrade"
    static let protocolName       = "Sec-WebSocket-Protocol"
    static let versionName        = "Sec-WebSocket-Version"
    static let versionValue       = "13"
    static let extensionName      = "Sec-WebSocket-Extensions"
    static let keyName            = "Sec-WebSocket-Key"
    static let originName         = "Origin"
    static let acceptName         = "Sec-WebSocket-Accept"
    static let switchProtocolCode = 101
    static let defaultSSLSchemes  = ["wss", "https"]
    
    /// Creates a new URLRequest based off the source URLRequest.
    /// - Parameter request: the request to "upgrade" the WebSocket request by adding headers.
    /// - Parameter supportsCompression: set if the client support text compression.
    /// - Parameter secKeyName: the security key to use in the WebSocket request. https://tools.ietf.org/html/rfc6455#section-1.3
    /// - returns: A URLRequest request to be converted to data and sent to the server.
    public static func createUpgrade(request: URLRequest, supportsCompression: Bool, secKeyValue: String) -> URLRequest {
        guard let url = request.url, let parts = url.getParts() else {
            return request
        }
        
        var req = request
        if request.value(forHTTPHeaderField: HTTPWSHeader.originName) == nil {
            var origin = url.absoluteString
            if let hostUrl = URL (string: "/", relativeTo: url) {
                origin = hostUrl.absoluteString
                origin.remove(at: origin.index(before: origin.endIndex))
            }
            req.setValue(origin, forHTTPHeaderField: HTTPWSHeader.originName)
        }
        req.setValue(HTTPWSHeader.upgradeValue, forHTTPHeaderField: HTTPWSHeader.upgradeName)
        req.setValue(HTTPWSHeader.connectionValue, forHTTPHeaderField: HTTPWSHeader.connectionName)
        req.setValue(HTTPWSHeader.versionValue, forHTTPHeaderField: HTTPWSHeader.versionName)
        req.setValue(secKeyValue, forHTTPHeaderField: HTTPWSHeader.keyName)
        
        if let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty {
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, val) in headers {
                req.setValue(val, forHTTPHeaderField: key)
            }
        }
        
        if supportsCompression {
            let val = "permessage-deflate; client_max_window_bits; server_max_window_bits=15"
            req.setValue(val, forHTTPHeaderField: HTTPWSHeader.extensionName)
        }
        let hostValue = req.allHTTPHeaderFields?[HTTPWSHeader.hostName] ?? "\(parts.host):\(parts.port)"
        req.setValue(hostValue, forHTTPHeaderField: HTTPWSHeader.hostName)
        return req
    }
    
    // generateWebSocketKey 16 random characters between a-z and return them as a base64 string
    public static func generateWebSocketKey() -> String {
        return Data((0..<16).map{ _ in UInt8.random(in: 97...122) }).base64EncodedString()
    }
}

public enum HTTPEvent {
    case success([String: String])
    case failure(Error)
}

public protocol HTTPHandlerDelegate: class {
    func didReceiveHTTP(event: HTTPEvent)
}

public protocol HTTPHandler {
    func register(delegate: HTTPHandlerDelegate)
    func convert(request: URLRequest) -> Data
    func parse(data: Data) -> Int
}

public protocol HTTPServerDelegate: class {
    func didReceive(event: HTTPEvent)
}

public protocol HTTPServerHandler {
    func register(delegate: HTTPServerDelegate)
    func parse(data: Data)
    func createResponse(headers: [String: String]) -> Data
}

public struct URLParts {
    let port: Int
    let host: String
    let isTLS: Bool
}

public extension URL {
    /// isTLSScheme returns true if the scheme is https or wss
    var isTLSScheme: Bool {
        guard let scheme = self.scheme else {
            return false
        }
        return HTTPWSHeader.defaultSSLSchemes.contains(scheme)
    }
    
    /// getParts pulls host and port from the url.
    func getParts() -> URLParts? {
        guard let host = self.host else {
            return nil // no host, this isn't a valid url
        }
        let isTLS = isTLSScheme
        var port = self.port ?? 0
        if self.port == nil {
            if isTLS {
                port = 443
            } else {
                port = 80
            }
        }
        return URLParts(port: port, host: host, isTLS: isTLS)
    }
}
