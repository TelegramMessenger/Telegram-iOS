import Foundation

import UIKit
import XCTest

import Postbox
@testable import Postbox

import SwiftSignalKit

func randomFilePath() -> String {
    return NSTemporaryDirectory() + "\(arc4random())\(arc4random())"
}

/*class RandomAccessResourceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        
        self.continueAfterFailure = false
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testCompleteAligned() {
        let path = randomFilePath()
        
        let size = 10 * 1024 * 1024
        //let size = 64 * 1024
        let sampleData = NSMutableData()
        sampleData.length = size
        arc4random_buf(sampleData.mutableBytes, size)
        
        var storeRange: (RandomAccessResourceStoreRange) -> Void = { _ in }
        
        let context = RandomAccessMediaResourceContext(path: path, size: size, fetchRange: { range in
            let subdata = sampleData.subdata(with: NSRange(location: range.lowerBound, length: range.count))
            storeRange(RandomAccessResourceStoreRange(offset: range.lowerBound, data: subdata))
            return EmptyDisposable
        })
        
        storeRange = { [weak context] range in
            context?.storeRanges([range])
        }
        
        var blocks: [Int] = []
        for i in 0 ..< context.blockCount {
            blocks.append(i)
        }
        
        var selectedRanges: [Range<Int>] = []
        
        while !blocks.isEmpty {
            let arrayOffset = Int(arc4random_uniform(UInt32(blocks.count)))
            var rangeEnd = blocks[arrayOffset]
            var arrayOffsetEnd = arrayOffset
            for i in arrayOffset + 1 ..< blocks.count {
                if blocks[i] == rangeEnd + 1 {
                    rangeEnd = blocks[i]
                    arrayOffsetEnd = i
                } else {
                    break
                }
            }
            
            let arrayOffsetCount = arrayOffsetEnd + 1 - arrayOffset
            let selectedArrayOffsetCount = Int(arc4random_uniform(UInt32(arrayOffsetCount + 1)))
            let selectedArrayOffsetEnd = arrayOffset + max(0, selectedArrayOffsetCount - 1)
            
            let range = (blocks[arrayOffset] * context.blockSize) ..< ((blocks[selectedArrayOffsetEnd] + 1) * context.blockSize)
            blocks.removeSubrange(arrayOffset ..< (selectedArrayOffsetEnd + 1))
            
            selectedRanges.append(Range(range))
        }
        
        selectedRanges.removeAll()
        
        selectedRanges.append(10092544..<10354688); selectedRanges.append(1310720..<7274496); selectedRanges.append(7340032..<7798784); selectedRanges.append(1179648..<1310720); selectedRanges.append(524288..<851968); selectedRanges.append(8060928..<9895936); selectedRanges.append(1114112..<1179648); selectedRanges.append(7929856..<8060928); selectedRanges.append(196608..<524288); selectedRanges.append(131072..<196608); selectedRanges.append(7798784..<7864320); selectedRanges.append(917504..<1114112); selectedRanges.append(65536..<131072); selectedRanges.append(7274496..<7340032); selectedRanges.append(0..<65536); selectedRanges.append(7864320..<7929856); selectedRanges.append(851968..<917504); selectedRanges.append(9961472..<10027008); selectedRanges.append(10354688..<10420224); selectedRanges.append(10027008..<10092544); selectedRanges.append(10420224..<10485760); selectedRanges.append(9895936..<9961472)
        
        print("\(selectedRanges)")
        
        let testData = NSMutableData()
        testData.length = size
        for range in selectedRanges {
            var invocationCount = 0
            let _ = context.addListenerForData(in: Range(range), mode: .Complete, updated: { subdata in
                XCTAssert(subdata.count == range.count, "\(subdata.count) != \(range.count)")
                invocationCount += 1
                subdata.withUnsafeBytes { (bytes: UnsafePointer<Void>) -> Void in
                    memcpy(testData.mutableBytes.advanced(by: range.lowerBound), bytes, range.count)
                }
            })
            let _ = context.addListenerForFetchedData(in: Range(range))
            XCTAssert(invocationCount == 1, "invocationCount != 1")
        }
        
        XCTAssert(memcmp(testData.bytes, sampleData.bytes, size) == 0)
    }
    
    func testCompleteUnaligned() {
        let path = randomFilePath()
        
        let size = 10 * 1024 * 1024 + 123
        let sampleData = NSMutableData()
        sampleData.length = size
        arc4random_buf(sampleData.mutableBytes, size)
        
        var storeRange: (RandomAccessResourceStoreRange) -> Void = { _ in }
        
        let context = RandomAccessMediaResourceContext(path: path, size: size, fetchRange: { range in
            let subdata = sampleData.subdata(with: NSRange(location: range.lowerBound, length: range.count))
            storeRange(RandomAccessResourceStoreRange(offset: range.lowerBound, data: subdata))
            return EmptyDisposable
        })
        
        storeRange = { [weak context] range in
            context?.storeRanges([range])
        }
        
        var blocks: [Int] = []
        for i in 0 ..< context.blockCount {
            blocks.append(i)
        }
        
        var selectedRanges: [Range<Int>] = []
        
        var dataOffset = 0
        while dataOffset < size {
            let partSize = min(size - dataOffset, Int(arc4random_uniform(1024 * 1024)))
            selectedRanges.append(dataOffset ..< (dataOffset + partSize))
            dataOffset += partSize
        }
        
        print("\(selectedRanges)")
        
        let testData = NSMutableData()
        testData.length = size
        for range in selectedRanges {
            let _ = context.addListenerForData(in: Range(range), mode: .Complete, updated: { subdata in
                if range.count != subdata.count {
                    print("\(subdata.count)")
                }
                XCTAssert(subdata.count == range.count)
                subdata.withUnsafeBytes { (bytes: UnsafePointer<Void>) -> Void in
                    memcpy(testData.mutableBytes.advanced(by: range.lowerBound), bytes, subdata.count)
                }
            })
            let _ = context.addListenerForFetchedData(in: Range(range))
        }
        
        XCTAssert(memcmp(testData.bytes, sampleData.bytes, size) == 0)
    }
    
    /*func testIncrementalStoreCompleteSubscriptionAligned() {
        let path = randomFilePath()
        
        let size = 10 * 1024 * 1024
        //let size = 64 * 1024
        let sampleData = NSMutableData()
        sampleData.length = size
        arc4random_buf(sampleData.mutableBytes, size)
        
        var storeRange: (RandomAccessResourceStoreRange) -> Void = { _ in }
        
        let context = RandomAccessMediaResourceContext(path: path, size: size, fetchRange: { range in
            var offset = range.lowerBound
            while offset < range.upperBound {
                let subdata = sampleData.subdata(with: NSRange(location: offset, length: min(range.upperBound - offset, 64 * 1024)))
                storeRange(RandomAccessResourceStoreRange(offset: range.lowerBound, data: subdata))
                
                offset += 64 * 1024
            }
            return EmptyDisposable
        })
        
        storeRange = { [weak context] range in
            context?.storeRanges([range])
        }
        
        var blocks: [Int] = []
        for i in 0 ..< context.blockCount {
            blocks.append(i)
        }
        
        var selectedRanges: [Range<Int>] = []
        
        while !blocks.isEmpty {
            let arrayOffset = Int(arc4random_uniform(UInt32(blocks.count)))
            var rangeEnd = blocks[arrayOffset]
            var arrayOffsetEnd = arrayOffset
            for i in arrayOffset + 1 ..< blocks.count {
                if blocks[i] == rangeEnd + 1 {
                    rangeEnd = blocks[i]
                    arrayOffsetEnd = i
                } else {
                    break
                }
            }
            
            let arrayOffsetCount = arrayOffsetEnd + 1 - arrayOffset
            let selectedArrayOffsetCount = Int(arc4random_uniform(UInt32(arrayOffsetCount + 1)))
            let selectedArrayOffsetEnd = arrayOffset + max(0, selectedArrayOffsetCount - 1)
            
            let range = (blocks[arrayOffset] * context.blockSize) ..< ((blocks[selectedArrayOffsetEnd] + 1) * context.blockSize)
            blocks.removeSubrange(arrayOffset ..< (selectedArrayOffsetEnd + 1))
            
            selectedRanges.append(Range(range))
        }
        
        print("\(selectedRanges)")
        
        let testData = NSMutableData()
        testData.length = size
        for range in selectedRanges {
            var invocations = 0
            let _ = context.addListenerForData(in: Range(range), mode: .Complete, updated: { subdata in
                XCTAssert(subdata.count == range.count)
                subdata.withUnsafeBytes { (bytes: UnsafePointer<Void>) -> Void in
                    memcpy(testData.mutableBytes.advanced(by: range.lowerBound), bytes, range.count)
                }
                invocations += 1
            })
            let _ = context.addListenerForFetchedData(in: Range(range))
            //XCTAssert(invocations == 1)
        }
        
        XCTAssert(memcmp(testData.bytes, sampleData.bytes, size) == 0)
    }*/
    
    func testIncrementalStoreCompleteSubscriptionUnaligned() {
        let path = randomFilePath()
        
        let size = 10 * 1024 * 1024 + 123
        let sampleData = NSMutableData()
        sampleData.length = size
        arc4random_buf(sampleData.mutableBytes, size)
        
        var storeRange: (RandomAccessResourceStoreRange) -> Void = { _ in }
        
        let context = RandomAccessMediaResourceContext(path: path, size: size, fetchRange: { range in
            var offset = range.lowerBound
            while offset < range.upperBound {
                let subdata = sampleData.subdata(with: NSRange(location: offset, length: min(range.upperBound - offset, 64 * 1024)))
                storeRange(RandomAccessResourceStoreRange(offset: offset, data: subdata))
                
                offset += 64 * 1024
            }
            return EmptyDisposable
        })
        
        storeRange = { [weak context] range in
            context?.storeRanges([range])
        }
        
        var selectedRanges: [Range<Int>] = []
        
        var dataOffset = 0
        while dataOffset < size {
            let partSize = min(size - dataOffset, Int(arc4random_uniform(1024 * 1024)))
            selectedRanges.append(dataOffset ..< (dataOffset + partSize))
            dataOffset += partSize
        }
        
        print("\(selectedRanges)")
        
        let testData = NSMutableData()
        testData.length = size
        for range in selectedRanges {
            var invocations = 0
            let _ = context.addListenerForData(in: Range(range), mode: .Complete, updated: { subdata in
                XCTAssert(subdata.count == range.count)
                subdata.withUnsafeBytes { (bytes: UnsafePointer<Void>) -> Void in
                    memcpy(testData.mutableBytes.advanced(by: range.lowerBound), bytes, subdata.count)
                }
                invocations += 1
            })
            let _ = context.addListenerForFetchedData(in: Range(range))
            XCTAssert(invocations == 1)
        }
        
        XCTAssert(memcmp(testData.bytes, sampleData.bytes, size) == 0)
    }
    
    func testIncrementalStoreIncrementalSubscriptionAligned() {
        let path = randomFilePath()
        
        let size = 10 * 1024 * 1024
        let sampleData = NSMutableData()
        sampleData.length = size
        arc4random_buf(sampleData.mutableBytes, size)
        
        var storeRange: (RandomAccessResourceStoreRange) -> Void = { _ in }
        
        let context = RandomAccessMediaResourceContext(path: path, size: size, fetchRange: { range in
            var offset = range.lowerBound
            while offset < range.upperBound {
                let subdata = sampleData.subdata(with: NSRange(location: offset, length: min(range.upperBound - offset, 64 * 1024)))
                storeRange(RandomAccessResourceStoreRange(offset: offset, data: subdata))
                
                offset += 64 * 1024
            }
            return EmptyDisposable
        })
        
        storeRange = { [weak context] range in
            context?.storeRanges([range])
        }
        
        var blocks: [Int] = []
        for i in 0 ..< context.blockCount {
            blocks.append(i)
        }
        
        var selectedRanges: [Range<Int>] = []
        
        while !blocks.isEmpty {
            let arrayOffset = Int(arc4random_uniform(UInt32(blocks.count)))
            var rangeEnd = blocks[arrayOffset]
            var arrayOffsetEnd = arrayOffset
            for i in arrayOffset + 1 ..< blocks.count {
                if blocks[i] == rangeEnd + 1 {
                    rangeEnd = blocks[i]
                    arrayOffsetEnd = i
                } else {
                    break
                }
            }
            
            let arrayOffsetCount = arrayOffsetEnd + 1 - arrayOffset
            let selectedArrayOffsetCount = Int(arc4random_uniform(UInt32(arrayOffsetCount + 1)))
            let selectedArrayOffsetEnd = arrayOffset + max(0, selectedArrayOffsetCount - 1)
            
            let range = (blocks[arrayOffset] * context.blockSize) ..< ((blocks[selectedArrayOffsetEnd] + 1) * context.blockSize)
            blocks.removeSubrange(arrayOffset ..< (selectedArrayOffsetEnd + 1))
            
            selectedRanges.append(Range(range))
        }
        
        print("\(selectedRanges)")
        
        let testData = NSMutableData()
        testData.length = size
        for range in selectedRanges {
            var offset = 0
            let _ = context.addListenerForData(in: Range(range), mode: .Incremental, updated: { subdata in
                subdata.withUnsafeBytes { (bytes: UnsafePointer<Void>) -> Void in
                    memcpy(testData.mutableBytes.advanced(by: range.lowerBound + offset), bytes, subdata.count)
                }
                offset += subdata.count
            })
            let _ = context.addListenerForFetchedData(in: Range(range))
            XCTAssert(offset == range.count)
        }
        
        XCTAssert(memcmp(testData.bytes, sampleData.bytes, size) == 0)
    }
    
    func testIncrementalStoreIncrementalSubscriptionUnaligned() {
        let path = randomFilePath()
        
        let size = 10 * 1024 * 1024 + 123
        let sampleData = NSMutableData()
        sampleData.length = size
        arc4random_buf(sampleData.mutableBytes, size)
        
        var storeRange: (RandomAccessResourceStoreRange) -> Void = { _ in }
        
        let context = RandomAccessMediaResourceContext(path: path, size: size, fetchRange: { range in
            var offset = range.lowerBound
            while offset < range.upperBound {
                let subdata = sampleData.subdata(with: NSRange(location: offset, length: min(range.upperBound - offset, 64 * 1024)))
                storeRange(RandomAccessResourceStoreRange(offset: offset, data: subdata))
                
                offset += 64 * 1024
            }
            return EmptyDisposable
        })
        
        storeRange = { [weak context] range in
            context?.storeRanges([range])
        }
        
        var selectedRanges: [Range<Int>] = []
        
        selectedRanges = [0..<615697, 615697..<1040801]
        
        var dataOffset = 1040801
        while dataOffset < size {
            let partSize = min(size - dataOffset, Int(arc4random_uniform(1024 * 1024)))
            selectedRanges.append(dataOffset ..< (dataOffset + partSize))
            dataOffset += partSize
        }
        
        print("\(selectedRanges)")
        
        let testData = NSMutableData()
        testData.length = size
        for range in selectedRanges {
            var offset = 0
            let _ = context.addListenerForData(in: Range(range), mode: .Incremental, updated: { subdata in
                subdata.withUnsafeBytes { (bytes: UnsafePointer<Void>) -> Void in
                    memcpy(testData.mutableBytes.advanced(by: range.lowerBound + offset), bytes, subdata.count)
                }
                offset += subdata.count
            })
            let _ = context.addListenerForFetchedData(in: Range(range))
            XCTAssert(offset == range.count)
        }
        
        XCTAssert(memcmp(testData.bytes, sampleData.bytes, size) == 0)
    }
}
*/
