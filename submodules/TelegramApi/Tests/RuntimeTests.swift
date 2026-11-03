import Foundation
import ObjectiveC
import XCTest
import TelegramApiObjC
import TLRuntimeFixture

private func describe(_ object: TLObject) -> [String] {
    var out: [String] = []
    withUnsafeMutablePointer(to: &out) { pointer in
        TLObjectDescribe(object, pointer) { context, field, scalar, value in
            let out = context!.assumingMemoryBound(to: [String].self)
            let name = String(cString: field.pointee.name)
            if let scalar = scalar {
                switch field.pointee.kind {
                case .int32: out.pointee.append("\(name)=\(scalar.load(as: Int32.self))")
                case .int64: out.pointee.append("\(name)=\(scalar.load(as: Int64.self))")
                default: out.pointee.append("\(name)=?")
                }
            } else if let value = value {
                if let text = value as? String {
                    out.pointee.append("\(name)=\(text)")
                } else if let array = value as? [TLObject] {
                    out.pointee.append("\(name)=count=\(array.count)")
                } else if let object = value as? TLObject {
                    out.pointee.append("\(name)=\(String(cString: object.tl_constructorInfo.pointee.name))")
                } else {
                    out.pointee.append("\(name)=?")
                }
            } else {
                out.pointee.append("\(name)=nil")
            }
        }
    }
    return out
}

private func leaf() -> TLObject {
    return TLFixtureCreate(1, 0, "leaf", nil, nil, 0)
}

private func root() -> TLObject {
    return TLFixtureCreate(2, 5, "root", leaf(), [leaf(), TLFixtureEmptySingleton()], 1)
}

private func assertBalanced(_ name: String, file: StaticString = #filePath, line: UInt = #line, _ body: () -> Void) {
    let before = TLObjectLiveCount()
    body()
    XCTAssertEqual(TLObjectLiveCount(), before, "\(name) leaked", file: file, line: line)
}

final class RuntimeTests: XCTestCase {
    func testCreateAndDestroyReleasesEverything() {
        assertBalanced("tree") {
            let before = TLObjectLiveCount()
            let object = root()
            XCTAssertEqual(TLObjectLiveCount() - before, 3)
            XCTAssertEqual(TLFixtureNumber(object), 2)
        }
    }

    func testSingletonIsImmortalAndShared() {
        assertBalanced("singleton") {
            let first = TLFixtureEmptySingleton()
            for _ in 0 ..< 1000 {
                XCTAssertTrue(TLFixtureEmptySingleton() === first)
            }
            XCTAssertEqual(String(cString: first.tl_constructorInfo.pointee.name), "fixtureEmpty")
            XCTAssertEqual(first.tl_caseIndex, 1)
        }
    }

    func testDescribeReportsPresenceAndValues() {
        XCTAssertEqual(describe(root()), ["number=2", "optionalNumber=5", "text=root", "child=fixture", "children=count=2"])
        XCTAssertEqual(describe(leaf()), ["number=1", "optionalNumber=nil", "text=leaf", "child=nil", "children=nil"])
    }

    func testWeakReferenceClearsOnDealloc() {
        assertBalanced("weak") {
            var strong: TLObject? = leaf()
            weak let weakRef = strong
            XCTAssertNotNil(weakRef)
            strong = nil
            XCTAssertNil(weakRef)
        }
    }

    func testAutoreleasePoolAndCollections() {
        assertBalanced("autorelease + collections") {
            autoreleasepool {
                let object = root()
                _ = Unmanaged.passRetained(object).autorelease()
                let array = NSMutableArray()
                array.add(object)
                let set = NSMutableSet()
                set.add(object)
                let dictionary = NSMutableDictionary()
                dictionary["key"] = object
                XCTAssertTrue(set.contains(object))
                XCTAssertFalse(array.description.isEmpty)
                XCTAssertTrue((object as AnyObject) is TLObject)
            }
        }
    }

    func testConcurrentRetainReleaseIsBalanced() {
        assertBalanced("concurrent") {
            let object = root()
            DispatchQueue.concurrentPerform(iterations: 8) { _ in
                for _ in 0 ..< 20_000 {
                    let copy = object
                    XCTAssertEqual(TLFixtureNumber(copy), 2)
                }
            }
        }
    }
}
