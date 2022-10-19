//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Data+Extensions.swift
//  Starscream
//
//  Created by Dalton Cherry on 3/27/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//
//  Fix for deprecation warnings
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

internal extension Data {
    struct ByteError: Swift.Error {}
    
    #if swift(>=5.0)
    func withUnsafeBytes<ResultType, ContentType>(_ completion: (UnsafePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
        return try withUnsafeBytes {
            if let baseAddress = $0.baseAddress, $0.count > 0 {
                return try completion(baseAddress.assumingMemoryBound(to: ContentType.self))
            } else {
                throw ByteError()
            }
        }
    }
    #endif
    
    #if swift(>=5.0)
    mutating func withUnsafeMutableBytes<ResultType, ContentType>(_ completion: (UnsafeMutablePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
        return try withUnsafeMutableBytes {
            if let baseAddress = $0.baseAddress, $0.count > 0 {
                return try completion(baseAddress.assumingMemoryBound(to: ContentType.self))
            } else {
                throw ByteError()
            }
        }
    }
    #endif
}
