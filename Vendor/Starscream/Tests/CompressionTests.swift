//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  CompressionTests.swift
//
//  Created by Joseph Ross on 7/16/14.
//  Copyright © 2017 Joseph Ross.
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

import XCTest
@testable import Starscream

class CompressionTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testBasic() {
        let compressor = Compressor(windowBits: 15)!
        let decompressor = Decompressor(windowBits: 15)!
        
        let rawData = "Hello, World! Hello, World! Hello, World! Hello, World! Hello, World!".data(using: .utf8)!
        
        let compressed = try! compressor.compress(rawData)
        let uncompressed = try! decompressor.decompress(compressed, finish: true)
        
        XCTAssert(rawData == uncompressed)
    }
    
    func testHugeData() {
        let compressor = Compressor(windowBits: 15)!
        let decompressor = Decompressor(windowBits: 15)!
        
        // 2 Gigs!
//        var rawData = Data(repeating: 0, count: 0x80000000)
        var rawData = Data(repeating: 0, count: 0x80000)
        let rawDataLen = rawData.count
        rawData.withUnsafeMutableBytes { (ptr: UnsafeMutablePointer<UInt8>) -> Void in
            arc4random_buf(ptr, rawDataLen)
        }
        
        let compressed = try! compressor.compress(rawData)
        let uncompressed = try! decompressor.decompress(compressed, finish: true)
        
        XCTAssert(rawData == uncompressed)
    }
    
}
