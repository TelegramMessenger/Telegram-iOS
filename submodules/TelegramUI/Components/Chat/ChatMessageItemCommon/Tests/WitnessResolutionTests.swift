import XCTest
import Display

// Mirrors the real arrangement:
//   ListViewItem            declares `neighborDescriptor` + a temporary default
//   ItemListItem            supplies a specialized one via `extension ... where Self: ListViewItem`
//   a concrete settings row conforms to both
//
// If the base protocol's default won instead, ~110 ItemListItems would silently publish an
// ObjectIdentifier — conservative, so nothing renders wrong, but every one of them would force a
// neighbor relayout on every transaction and the whole optimization would be dead. This pins the
// language behavior the arrangement depends on.

private protocol BaseItem: AnyObject {
    var descriptor: AnyEquatable { get }
}

private extension BaseItem {
    var descriptor: AnyEquatable {
        return AnyEquatable("base-default")
    }
}

private protocol RefiningItem {
    var tag: String { get }
}

private extension RefiningItem where Self: BaseItem {
    var descriptor: AnyEquatable {
        return AnyEquatable("specialized:" + self.tag)
    }
}

private final class ItemConformingToBoth: BaseItem, RefiningItem {
    let tag = "x"
}

private final class ItemConformingToBaseOnly: BaseItem {
}

private final class ItemWithOwnDescriptor: BaseItem, RefiningItem {
    let tag = "y"
    var descriptor: AnyEquatable {
        return AnyEquatable("concrete")
    }
}

final class WitnessResolutionTests: XCTestCase {
    func testSpecializedExtensionWinsOverBaseDefault() {
        let item: BaseItem = ItemConformingToBoth()
        XCTAssertEqual(item.descriptor, AnyEquatable("specialized:x"),
                       "the constrained extension must supply the witness, not the base default")
    }

    func testBaseDefaultAppliesWhenNotRefined() {
        let item: BaseItem = ItemConformingToBaseOnly()
        XCTAssertEqual(item.descriptor, AnyEquatable("base-default"))
    }

    func testConcreteDeclarationShadowsBoth() {
        let item: BaseItem = ItemWithOwnDescriptor()
        XCTAssertEqual(item.descriptor, AnyEquatable("concrete"),
                       "items needing extra facets must be able to override the shared extension")
    }
}
