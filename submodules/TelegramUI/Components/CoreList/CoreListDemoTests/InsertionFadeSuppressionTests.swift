import XCTest
import UIKit
@testable import CoreListDemo

/// The send morph carries a newly sent message out of the input field itself, so CoreList must not
/// also fade that row in — see docs/superpowers/specs/2026-08-04-corelist-insertion-fade-design.md.
/// Sibling of `CarouselFadeSuppressionTests`, which pins the other opt-out on the same call.
final class InsertionFadeSuppressionTests: XCTestCase {
    private final class Item: CoreListItem {
        let id: Int

        var identity: AnyHashable { id }

        init(id: Int) {
            self.id = id
        }

        func view() -> UIView & CoreListItemView {
            FixedHeightItemView(height: 50)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? Item)?.id == id
        }
    }

    private func makeFixture(ids: Range<Int>) -> VirtualListFixture {
        VirtualListFixture(viewport: CGSize(width: 390, height: 300),
                           items: ids.map { Item(id: $0) },
                           preloadMargin: 100)
    }

    /// Prepends a new row, which is inside the loaded window at any preload margin.
    private func itemsWithNewRow(ids: Range<Int>) -> [CoreListItem] {
        [Item(id: 999)] + ids.map { Item(id: $0) }
    }

    /// Fires a closure from inside `update(width:transition:)`, i.e. while a pass is running, so a
    /// nested `applyChanges` hits the re-entrancy guard. A fresh view is always measured in the pass
    /// that inserts it, which makes the trigger deterministic.
    private final class TriggerItemView: UIView, CoreListItemView {
        var onContentDidChange: ((Bool) -> Void)?
        var onUpdate: (@MainActor () -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError()
        }

        /// `update` is nonisolated to satisfy `CoreListItemView`, but the pass calling it runs on the
        /// main thread — which is what makes reaching back into the list here legitimate.
        nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
            MainActor.assumeIsolated {
                onUpdate?()
            }
            return 50
        }
    }

    private final class TriggerItem: CoreListItem {
        let id: Int
        private let onUpdate: @MainActor () -> Void

        var identity: AnyHashable { id }

        init(id: Int, onUpdate: @escaping @MainActor () -> Void) {
            self.id = id
            self.onUpdate = onUpdate
        }

        func view() -> UIView & CoreListItemView {
            let view = TriggerItemView(frame: .zero)
            view.onUpdate = onUpdate
            return view
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? TriggerItem)?.id == id
        }
    }

    func testSuppressedInsertionDoesNotFade() throws {
        let fixture = makeFixture(ids: 0..<10)

        fixture.listView.applyChanges(items: itemsWithNewRow(ids: 0..<10),
                                      animatesInsertions: false,
                                      transition: .easeInOut(duration: 1))

        XCTAssertNil(fixture.opacityTrack(identity: AnyHashable(999)))
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: AnyHashable(999))), 1, accuracy: 1e-9)
    }

    /// The control. Without it, the suppression could pass by never fading anything.
    func testDefaultInsertionStillFades() throws {
        let fixture = makeFixture(ids: 0..<10)

        fixture.listView.applyChanges(items: itemsWithNewRow(ids: 0..<10),
                                      transition: .easeInOut(duration: 1))

        XCTAssertNotNil(fixture.opacityTrack(identity: AnyHashable(999)))
        XCTAssertLessThan(try XCTUnwrap(fixture.opacity(identity: AnyHashable(999))), 1)
    }

    /// A pass that lands inside another is re-dispatched through the scheduler with its arguments
    /// listed explicitly, so a new one is dropped silently unless it is added there too.
    func testSuppressionSurvivesTheReentrancyDeferral() throws {
        let fixture = makeFixture(ids: 0..<10)

        var nestedPass: (@MainActor () -> Void)?
        var didTrigger = false
        let trigger = TriggerItem(id: -1) {
            guard !didTrigger else { return }
            didTrigger = true
            nestedPass?()
        }

        let outerItems: [CoreListItem] = [trigger] + (0..<10).map { Item(id: $0) }
        let nestedItems: [CoreListItem] = [Item(id: 999), trigger] + (0..<10).map { Item(id: $0) }

        nestedPass = { [unowned fixture] in
            fixture.listView.applyChanges(items: nestedItems,
                                          animatesInsertions: false,
                                          transition: .easeInOut(duration: 1))
        }

        // Inserting `trigger` builds its view, whose `update` fires the nested pass mid-flight.
        fixture.listView.applyChanges(items: outerItems,
                                      transition: .easeInOut(duration: 1))

        // Occupancy probe: without this a green test could mean the nested pass never ran.
        XCTAssertTrue(didTrigger, "the nested pass never fired — the test proves nothing")

        fixture.flushScheduler()

        XCTAssertNil(fixture.opacityTrack(identity: AnyHashable(999)))
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: AnyHashable(999))), 1, accuracy: 1e-9)
    }
}
