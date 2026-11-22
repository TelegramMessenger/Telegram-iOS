import Darwin
import Foundation
import ObjectiveC
import XCTest
import TelegramApiObjC
@testable import TelegramApi

/// Every payload is a plain TLObject whose allocation covers its table storage size.
final class StorageLayoutTests: XCTestCase {
    func testEveryObjectIsAPlainTLObjectOfItsInstanceSize() {
        func check(_ info: UnsafePointer<TLConstructorInfo>) {
            let object = TLObjectAllocate(info)
            XCTAssertTrue(object_getClass(object) == TLObject.self, String(cString: info.pointee.name))
            XCTAssertGreaterThanOrEqual(malloc_size(Unmanaged.passUnretained(object).toOpaque()), Int(info.pointee.instanceSize), String(cString: info.pointee.name))
        }
        for i in 0 ..< TLApiConstructorCount {
            check(TLApiConstructorAt(i))
        }
        for i in 0 ..< TLApiFunctionCount {
            check(TLApiFunctionConstructorAt(i))
        }
    }
}
