import UIKit
import XCTest

import Postbox

class TestParent: PostboxCoding, Equatable {
    var parentInt32: Int32
    
    required init(decoder: PostboxDecoder) {
        self.parentInt32 = decoder.decodeInt32ForKey("parentInt32", orElse: 0)
    }
    
    init(parentInt32: Int32) {
        self.parentInt32 = parentInt32
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.parentInt32, forKey: "parentInt32")
    }
}

class TestObject: TestParent {
    var int32: Int32
    var int64: Int64
    var double: Double
    var string: String
    var int32Array: [Int32]
    var int64Array: [Int64]
    
    required init(decoder: PostboxDecoder) {
        self.int32 = decoder.decodeInt32ForKey("int32", orElse: 0)
        self.int64 = decoder.decodeInt64ForKey("int64", orElse: 0)
        self.double = decoder.decodeDoubleForKey("double", orElse: 0.0)
        self.string = decoder.decodeStringForKey("string", orElse: "")
        self.int32Array = decoder.decodeInt32ArrayForKey("int32Array")
        self.int64Array = decoder.decodeInt64ArrayForKey("int64Array")
        super.init(decoder: decoder)
    }
    
    init(parentInt32: Int32, int32: Int32, int64: Int64, double: Double, string: String, int32Array: [Int32], int64Array: [Int64]) {
        self.int32 = int32
        self.int64 = int64
        self.double = double
        self.string = string
        self.int32Array = int32Array
        self.int64Array = int64Array
        super.init(parentInt32: parentInt32)
    }
    
    override func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.int32, forKey: "int32")
        encoder.encodeInt64(self.int64, forKey: "int64")
        encoder.encodeDouble(self.double, forKey: "double")
        encoder.encodeString(self.string, forKey: "string")
        encoder.encodeInt32Array(self.int32Array, forKey: "int32Array")
        encoder.encodeInt64Array(self.int64Array, forKey: "int64Array")
        super.encode(encoder)
    }
}

class TestKey: PostboxCoding, Hashable {
    let value: Int
    required init(decoder: PostboxDecoder) {
        self.value = Int(decoder.decodeInt32ForKey("value", orElse: 0))
    }
    
    init(value: Int) {
        self.value = value
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.value), forKey: "value")
    }
    
    var hashValue: Int {
        get {
            return self.value
        }
    }
}

func ==(lhs: TestObject, rhs: TestObject) -> Bool {
    return lhs.int32 == rhs.int32 &&
        lhs.int64 == rhs.int64 &&
        lhs.double == rhs.double &&
        lhs.string == rhs.string &&
        lhs.int32Array == rhs.int32Array &&
        lhs.int64Array == rhs.int64Array &&
        lhs.parentInt32 == rhs.parentInt32
}

func ==(lhs: TestParent, rhs: TestParent) -> Bool {
    return lhs.parentInt32 == rhs.parentInt32
}

func ==(lhs: TestKey, rhs: TestKey) -> Bool {
    return lhs.value == rhs.value
}

class EmptyState: PostboxCoding {
    required init(decoder: PostboxDecoder) {
    }
    
    func encode(_ encoder: PostboxEncoder) {
    }
}

class SerializationTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testExample() {
        declareEncodable(TestParent.self, f: { TestParent(decoder: $0) })
        declareEncodable(TestObject.self, f: { TestObject(decoder: $0) })
        declareEncodable(TestKey.self, f: { TestKey(decoder: $0) })
        
        let encoder = PostboxEncoder()
        encoder.encodeInt32(12345, forKey: "a")
        encoder.encodeInt64(Int64(12345), forKey: "b")
        encoder.encodeBool(true, forKey: "c")
        encoder.encodeString("test", forKey: "d")
        
        let before = TestObject(parentInt32: 100, int32: 12345, int64: 67890, double: 1.23456, string: "test", int32Array: [1, 2, 3, 4, 5], int64Array: [6, 7, 8, 9, 0])
        encoder.encodeObject(before, forKey: "e")
        
        encoder.encodeInt32Array([1, 2, 3, 4], forKey: "f")
        encoder.encodeInt64Array([1, 2, 3, 4], forKey: "g")
        
        let beforeArray: [TestParent] = [TestObject(parentInt32: 1000, int32: 12345, int64: 67890, double: 1.23456, string: "test", int32Array: [1, 2, 3, 4, 5], int64Array: [6, 7, 8, 9, 0]), TestParent(parentInt32: 2000)]
        
        encoder.encodeObjectArray(beforeArray, forKey: "h")
        
        let beforeDictionary: [TestKey : TestParent] = [
            TestKey(value: 1): TestObject(parentInt32: 1000, int32: 12345, int64: 67890, double: 1.23456, string: "test", int32Array: [1, 2, 3, 4, 5], int64Array: [6, 7, 8, 9, 0]),
            TestKey(value: 2): TestParent(parentInt32: 2000)
        ]
        
        encoder.encodeObjectDictionary(beforeDictionary, forKey: "i")
        
        let decoder = PostboxDecoder(buffer: encoder.makeReadBufferAndReset())
        
        let afterDictionary = decoder.decodeObjectDictionaryForKey("i") as [TestKey : TestParent]
        XCTAssert(afterDictionary == beforeDictionary, "object dictionary failed")
        
        let afterArray = decoder.decodeObjectArrayForKey("h") as [TestParent]
        XCTAssert(afterArray == beforeArray, "object array failed")
        
        XCTAssert(decoder.decodeInt64ArrayForKey("g") == [1, 2, 3, 4], "int64 array failed")
        XCTAssert(decoder.decodeInt32ArrayForKey("f") == [1, 2, 3, 4], "int32 array failed")
        
        if let after = decoder.decodeObjectForKey("e") as? TestObject {
            XCTAssert(after == before, "object failed")
        } else {
            XCTFail("object failed")
        }
        
        XCTAssert(decoder.decodeStringForKey("d", orElse: "") == "test", "string failed")
        XCTAssert(decoder.decodeBoolForKey("c", orElse: false), "bool failed")
        XCTAssert(decoder.decodeInt64ForKey("b", orElse: 0) == Int64(12345), "int64 failed")
        XCTAssert(decoder.decodeInt32ForKey("a", orElse: 0) == 12345, "int32 failed")
    }
    
    func testKeys() {
        let key1 = ValueBoxKey(length: 8)
        let key2 = ValueBoxKey(length: 8)
        
        key1.setInt32(0, value: 1)
        key1.setInt32(4, value: 2)
        
        key2.setInt32(0, value: 1)
        key2.setInt32(4, value: 3)
        
        let lowerBound = ValueBoxKey(length: 4)
        lowerBound.setInt32(0, value: 0)
        let upperBound = ValueBoxKey(length: 4)
        upperBound.setInt32(0, value: 2)
        
        XCTAssert(key1 > lowerBound, "key1 <= lowerBound")
        XCTAssert(key1 < upperBound, "key1 >= upperBound")
        XCTAssert(key2 > lowerBound, "key2 <= lowerBound")
        XCTAssert(key2 < upperBound, "key2 >= upperBound")
        
        XCTAssert(key1 < key2, "key1 >= key2")
        XCTAssert(key1.successor == key2, "key1.next != key2")
        XCTAssert(key2.predecessor == key1, "key2.previous != key1")
    }
    
    func testKeyValue() {
        /*let basePath = "/tmp/postboxtest"
        do {
            try NSFileManager.defaultManager().removeItemAtPath(basePath)
        } catch _ { }
        
        let box = SqliteValueBox(basePath: basePath)
        box.transaction { transaction in
            let key = ValueBoxKey(length: 4)
            let value = WriteBuffer()
            for i in 1 ... 100 {
                key.setInt32(0, value: Int32(i))
                transaction.set("test", key: key, value: value)
            }
        }
        
        do {
            box.transaction { transaction in
                let lowerBound = ValueBoxKey(length: 4)
                lowerBound.setInt32(0, value: 2)
                let upperBound = ValueBoxKey(length: 4)
                upperBound.setInt32(0, value: 99)
                transaction.range("test", start: upperBound, end: lowerBound, values: { key, value in
                    print("\(key.getInt32(0))")
                    return true
                }, limit: 10)
            }
        }*/
    }
}
