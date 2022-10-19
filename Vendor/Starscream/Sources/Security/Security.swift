//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Security.swift
//  Starscream
//
//  Created by Dalton Cherry on 3/16/19.
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

public enum SecurityErrorCode: UInt16 {
    case acceptFailed = 1
    case pinningFailed = 2
}

public enum PinningState {
    case success
    case failed(CFError?)
}

// CertificatePinning protocol provides an interface for Transports to handle Certificate
// or Public Key Pinning.
public protocol CertificatePinning: class {
    func evaluateTrust(trust: SecTrust, domain: String?, completion: ((PinningState) -> ()))
}

// validates the "Sec-WebSocket-Accept" header as defined 1.3 of the RFC 6455
// https://tools.ietf.org/html/rfc6455#section-1.3
public protocol HeaderValidator: class {
    func validate(headers: [String: String], key: String) -> Error?
}
