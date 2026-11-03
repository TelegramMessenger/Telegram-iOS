import XCTest
import UIKit
@testable import CoreListDemo

/// `applyChanges(compensatesInsetChange:)` selects whether a top-inset change moves content.
///
/// The default `true` projects the resolved anchor by `newTopInset - oldTopInset`, preserving its
/// settled distance from the inset edge. `false` drops only that addend, so content holds its screen
/// position while the inset edge moves under it — the geometry `ListViewImpl` produces when it zeroes
/// `offsetFix` (`Display/Source/ListView.swift:3276`).
///
/// Its reason to exist: an inset change caused by the user's own in-progress drag. The chat's keyboard
/// is dismissed interactively by a window-level pan that recognizes SIMULTANEOUSLY with the history
/// list's scroll pan, so one downward drag reaches the list twice — as a scroll delta and as a smaller
/// bottom inset. Compensating the second on top of the first moves content by double the finger's
/// travel. Deciding that a pass is such a case is caller policy; `CoreVirtualListView` only offers the
/// switch.
///
/// Assertions are on settled/rendered screen Y rather than the engine offset: mid-collection with both
/// edges unloaded the engine sits on `UIKitScrollEngine`'s private 10,000,000-point canvas, so its raw
/// offset carries a meaningless base.
final class InsetCompensationSuppressionTests: XCTestCase {
    private let viewport = CGSize(width: 390, height: 400)
    private let grownInsets = UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0)

    /// A row inside the loaded window at the scrolled position these tests use.
    private func probeIdentity(_ fixture: VirtualListFixture) throws -> AnyHashable {
        let index = 12
        XCTAssertTrue(fixture.loadedIndices.contains(index), "probe row must be loaded")
        return fixture.listView.items[index].identity
    }

    private func scrolledFixture() -> VirtualListFixture {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        fixture.scroll(to: 500)
        return fixture
    }

    // MARK: - The switch

    /// Baseline: the default behavior this suppresses. Content follows the inset edge.
    func testCompensationMovesContentWithTheInsetEdgeByDefault() throws {
        let fixture = scrolledFixture()
        let identity = try probeIdentity(fixture)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: identity))

        fixture.listView.applyChanges(newInsets: grownInsets,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)),
                       before + 100, accuracy: 1e-6,
                       "the anchor must keep its distance from an inset edge that moved down 100")
    }

    func testSuppressedCompensationHoldsContentScreenPosition() throws {
        let fixture = scrolledFixture()
        let identity = try probeIdentity(fixture)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: identity))

        fixture.listView.applyChanges(newInsets: grownInsets,
                                      compensatesInsetChange: false,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)),
                       before, accuracy: 1e-6,
                       "content must stay put while the inset edge moves under it")
    }

    /// Suppression is symmetric — a SHRINKING inset (the keyboard going away, which is the real case)
    /// must not move content either.
    func testSuppressedCompensationHoldsContentAcrossAShrinkingInset() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        fixture.listView.applyChanges(newInsets: grownInsets, transition: .easeInOut(duration: 0))
        fixture.scroll(to: 500)
        let identity = try probeIdentity(fixture)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: identity))

        fixture.listView.applyChanges(newInsets: .zero,
                                      compensatesInsetChange: false,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)),
                       before, accuracy: 1e-6)
    }

    /// Nothing moves, so the shared viewport track must be an exact no-op rather than a zero-length
    /// animation — a suppressed pass has no displacement to own.
    func testSuppressedCompensationStartsNoViewportAnimation() throws {
        let fixture = scrolledFixture()

        fixture.listView.applyChanges(newInsets: grownInsets,
                                      compensatesInsetChange: false,
                                      transition: .linear(duration: 3))

        XCTAssertFalse(fixture.hasActiveAnimations,
                       "a pass that displaces nothing must not animate anything")
    }

    // MARK: - What suppression must NOT touch

    /// The load-bearing one. Suppression drops the compensation addend and nothing else: the new insets
    /// still take effect, so the loaded-top pin still puts index 0 on the inset edge. This is why the
    /// bottom of the chat keeps following the keyboard down even while the drag suppresses compensation
    /// — under the wrapper's π rotation the newest message IS the loaded top. `ListViewImpl` splits it
    /// the same way: `offsetFix` goes to zero, but `self.insets` is still assigned and `snapToBounds`
    /// still runs.
    func testSuppressionLeavesTheLoadedTopPinnedToTheNewInsetEdge() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        let identity = fixture.listView.items[0].identity
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)), 0, accuracy: 1e-6,
                       "precondition: sitting at the loaded top")

        fixture.listView.applyChanges(newInsets: grownInsets,
                                      compensatesInsetChange: false,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)), 100, accuracy: 1e-6,
                       "index 0 must ride the inset edge, suppression or not")
    }

    /// `additionalScrollDistance` is a caller-chosen displacement, not inset compensation, so
    /// suppression must leave it fully intact. `ListViewImpl` orders it the same way — the `+=` is after
    /// the tracking branch that zeroes `offsetFix`.
    func testSuppressionLeavesAdditionalScrollDistanceIntact() throws {
        let fixture = scrolledFixture()
        let identity = try probeIdentity(fixture)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: identity))

        fixture.listView.applyChanges(newInsets: grownInsets,
                                      additionalScrollDistance: -60,
                                      compensatesInsetChange: false,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)),
                       before - 60, accuracy: 1e-6,
                       "the 100pt compensation is suppressed; the 60pt displacement is not")
    }

    /// Suppression is about the inset addend only — a pass that also changes the collection must still
    /// anchor on its surviving witness exactly as it otherwise would.
    func testSuppressionDoesNotDisturbStructuralAnchoring() throws {
        func settledYAfterInsertAbove(compensates: Bool) throws -> CGFloat {
            let fixture = scrolledFixture()
            let identity = try probeIdentity(fixture)
            var items = fixture.listView.items
            items.insert(IdentifiableFixedHeightItem(id: UUID(), height: 50), at: 0)

            fixture.listView.applyChanges(items: items,
                                          newInsets: grownInsets,
                                          compensatesInsetChange: compensates,
                                          transition: .easeInOut(duration: 0))

            return try XCTUnwrap(fixture.settledScreenY(identity: identity))
        }

        // A row inserted above the anchor must not move the anchor on screen under either setting; the
        // two differ by exactly the compensation, nothing else.
        XCTAssertEqual(try settledYAfterInsertAbove(compensates: false) + 100,
                       try settledYAfterInsertAbove(compensates: true),
                       accuracy: 1e-6)
    }

    /// A pass with no inset change at all is unaffected either way — there is no addend to drop.
    func testSuppressionIsInertWithoutAnInsetChange() throws {
        let fixture = scrolledFixture()
        let identity = try probeIdentity(fixture)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: identity))

        fixture.listView.applyChanges(additionalScrollDistance: -60,
                                      compensatesInsetChange: false,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)),
                       before - 60, accuracy: 1e-6)
    }
}
