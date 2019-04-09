import Foundation

import XCTest

import Postbox
@testable import Postbox

import SwiftSignalKit

func binaryIndexOrLower<T: Comparable>(_ inputArr: [T], _ searchItem: T) -> Int {
    var lo = 0
    var hi = inputArr.count - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        if inputArr[mid] < searchItem {
            lo = mid + 1
        } else if searchItem < inputArr[mid] {
            hi = mid - 1
        } else {
            return mid
        }
    }
    return hi
}

func check(xs: [[Int]], anchor: Int, limit: Int) {
    var previousAnchorIndices: [Int: Int] = [:]
    var nextAnchorIndices: [Int: Int] = [:]
    for i in 0 ..< xs.count {
        let index = binaryIndexOrLower(xs[i], anchor)
        previousAnchorIndices[i] = index
        nextAnchorIndices[i] = index + 1
    }
    
    var result: [Int] = []
    
    while true {
        var minId = -1
        for (i, value) in previousAnchorIndices {
            if value != -1 {
                if minId == -1 {
                    minId = i
                } else {
                    if xs[i][value] > xs[minId][previousAnchorIndices[minId]!] {
                        minId = i
                    }
                }
            }
        }
        if minId != -1 {
            result.insert(xs[minId][previousAnchorIndices[minId]!], at: 0)
            previousAnchorIndices[minId]! -= 1
            if result.count == limit {
                break
            }
        }
        
        var maxId = -1
        for (i, value) in nextAnchorIndices {
            if value != xs[i].count {
                if maxId == -1 {
                    maxId = i
                } else {
                    if xs[i][value] < xs[maxId][nextAnchorIndices[maxId]!] {
                        maxId = i
                    }
                }
            }
        }
        if maxId != -1 {
            result.append(xs[maxId][nextAnchorIndices[maxId]!])
            nextAnchorIndices[maxId]! += 1
            if result.count == limit {
                break
            }
        }
        
        if minId == -1 && maxId == -1 {
            break
        }
    }
    print(result)
    assert(result.sorted() == result)
}

class MessageHistoryViewTests: XCTestCase {
    func testRangeCollectionSimple() {
        let xs: [[Int]] = [
            [10, 20, 30, 40, 50, 60, 70, 80],
            [9, 21, 29, 41, 49, 61, 69, 81]
        ]
        check(xs: xs, anchor: -1, limit: 2)
    }
    
    func testRangeCollectionRandom() {
        for step in 0 ..< 10 {
            print("step \(step)")
            var xs: [[Int]] = []
            for i in 0 ..< 2 {
                if xs.count <= i {
                    xs.append([])
                }
                for _ in 0 ..< 1000 {
                    xs[i].append(Int(arc4random_uniform(10001)))
                }
                xs[i].sort()
            }
            for i in -1 ... 1001 {
                check(xs: xs, anchor: i, limit: 10000)
            }
        }
    }
}
