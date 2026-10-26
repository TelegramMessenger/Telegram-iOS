import XCTest
import Display

private protocol SizeFacet {
    var size: Int { get }
}

private struct FacetedPayload: Equatable, SizeFacet {
    let size: Int
    let name: String
}

private struct OtherPayload: Equatable {
    let size: Int
}

final class AnyEquatableTests: XCTestCase {
    func testEqualWhenSameTypeAndValue() {
        XCTAssertEqual(AnyEquatable(FacetedPayload(size: 1, name: "a")),
                       AnyEquatable(FacetedPayload(size: 1, name: "a")))
    }

    func testNotEqualWhenSameTypeDifferentValue() {
        XCTAssertNotEqual(AnyEquatable(FacetedPayload(size: 1, name: "a")),
                          AnyEquatable(FacetedPayload(size: 2, name: "a")))
    }

    func testNotEqualAcrossTypesEvenWithMatchingFields() {
        XCTAssertNotEqual(AnyEquatable(FacetedPayload(size: 1, name: "a")),
                          AnyEquatable(OtherPayload(size: 1)))
    }

    func testEqualityIsSymmetricAcrossTypes() {
        let a = AnyEquatable(FacetedPayload(size: 1, name: "a"))
        let b = AnyEquatable(OtherPayload(size: 1))
        XCTAssertEqual(a == b, b == a)
    }

    func testBaseRecoversConcreteType() {
        let boxed = AnyEquatable(FacetedPayload(size: 3, name: "x"))
        XCTAssertEqual(boxed.base(FacetedPayload.self)?.name, "x")
        XCTAssertNil(boxed.base(OtherPayload.self))
    }

    func testBaseRecoversProtocolFacet() {
        let boxed = AnyEquatable(FacetedPayload(size: 3, name: "x"))
        XCTAssertEqual(boxed.base(SizeFacet.self)?.size, 3)
        XCTAssertNil(AnyEquatable(OtherPayload(size: 3)).base(SizeFacet.self))
    }

    func testNoNeighborInfluenceIsEqualToItself() {
        XCTAssertEqual(AnyEquatable.noNeighborInfluence, AnyEquatable.noNeighborInfluence)
        XCTAssertNil(AnyEquatable.noNeighborInfluence.base(SizeFacet.self))
    }

    func testNeighborsEquality() {
        let a = ListViewItemNeighbors(previous: AnyEquatable(OtherPayload(size: 1)), next: nil)
        let b = ListViewItemNeighbors(previous: AnyEquatable(OtherPayload(size: 1)), next: nil)
        let c = ListViewItemNeighbors(previous: nil, next: AnyEquatable(OtherPayload(size: 1)))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(ListViewItemNeighbors.none, ListViewItemNeighbors(previous: nil, next: nil))
    }
}
