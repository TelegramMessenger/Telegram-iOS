import UIKit
import XCTest
@testable import CoreListDemo

/// A row that records every `(width, transition)` it is measured with, so a test can assert what
/// `measureTransition(forItemAt:view:)` decided rather than infer it from geometry.
private final class MeasureRecordingItemView: UIView, CoreListItemView {
    private(set) var measurements: [(width: CGFloat, transition: CoreListTransition)] = []
    var onContentDidChange: ((Bool) -> Void)?

    var lastTransition: CoreListTransition? { measurements.last?.transition }

    override init(frame: CGRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }

    nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        measurements.append((width, transition))
        return 50
    }
}

private final class MeasureRecordingItem: CoreListItem {
    let id: Int
    /// Bumped to make `isEqual` false, i.e. to reconcile this row's CONTENT in a pass.
    let revision: Int
    var identity: AnyHashable { id }

    init(id: Int, revision: Int = 0) {
        self.id = id
        self.revision = revision
    }

    func view() -> UIView & CoreListItemView { MeasureRecordingItemView() }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? MeasureRecordingItem else { return false }
        return id == other.id && revision == other.revision
    }
}

/// `measureTransition` decides whether a row animates its own internals. It has to say yes in two
/// distinct cases, and the second one was missing: a pass that changes `contentWidth` re-measures
/// every loaded row at a new width, and the row reflows internally — but reconciles nothing, so the
/// content-only predicate returned `.immediate` and every row snapped while its frame animated.
final class MeasureTransitionTests: XCTestCase {
    private func makeFixture(count: Int = 8) -> (VirtualListFixture, [MeasureRecordingItem]) {
        let items = (0..<count).map { MeasureRecordingItem(id: $0) }
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 400), items: items)
        return (fixture, items)
    }

    private func loadedViews(_ fixture: VirtualListFixture) -> [MeasureRecordingItemView] {
        fixture.listView.loadedItemViews.compactMap { $0 as? MeasureRecordingItemView }
    }

    // MARK: - The regression

    func testHorizontalInsetChangeMeasuresRowsWithThePassTransition() {
        let (fixture, _) = makeFixture()
        let views = loadedViews(fixture)
        XCTAssertFalse(views.isEmpty, "precondition: rows are loaded")

        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0),
                                      transition: .linear(duration: 0.3))

        for view in loadedViews(fixture) {
            XCTAssertEqual(view.lastTransition?.animation, .curve(duration: 0.3, curve: .linear),
                           "a row re-measured at a new width must animate its internals on the pass")
        }
    }

    func testViewportWidthChangeMeasuresRowsWithThePassTransition() {
        // The same rule for a size change rather than an inset one — rotation, split view.
        let (fixture, _) = makeFixture()

        fixture.listView.applyChanges(newSize: CGSize(width: 320, height: 400),
                                      transition: .linear(duration: 0.25))

        for view in loadedViews(fixture) {
            XCTAssertEqual(view.lastTransition?.animation, .curve(duration: 0.25, curve: .linear))
        }
    }

    // MARK: - Controls: the cases that must STAY immediate

    func testVerticalInsetChangeLeavesRowsImmediate() {
        // The original reasoning holds here and must keep holding: a vertical inset does not touch
        // `contentWidth`, so nothing re-lays-out and the move is pure outer geometry, which
        // ListAnimationModel owns.
        let (fixture, _) = makeFixture()

        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 120, left: 0, bottom: 0, right: 0),
                                      transition: .linear(duration: 0.3))

        for view in loadedViews(fixture) {
            XCTAssertEqual(view.lastTransition?.isImmediate, true,
                           "a vertical-only inset change must not animate row internals")
        }
    }

    func testUnchangedPassLeavesRowsImmediate() {
        let (fixture, items) = makeFixture()

        fixture.listView.applyChanges(items: items, transition: .linear(duration: 0.3))

        for view in loadedViews(fixture) {
            XCTAssertEqual(view.lastTransition?.isImmediate, true,
                           "a pass that changes neither content nor width must not animate internals")
        }
    }

    func testFreshViewInAWidthChangingPassIsStillImmediate() {
        // A view created during the pass has no prior layout to animate its internals from. It must
        // stay immediate even though the pass changes the width — the exclusion the item contract has
        // always promised, and the one the width case could most easily have broken.
        let (fixture, items) = makeFixture()
        let before = Set(loadedViews(fixture).map(ObjectIdentifier.init))

        var inserted = items
        inserted.insert(MeasureRecordingItem(id: 999), at: 0)
        fixture.listView.applyChanges(items: inserted,
                                      newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0),
                                      transition: .linear(duration: 0.3))

        let fresh = loadedViews(fixture).filter { !before.contains(ObjectIdentifier($0)) }
        XCTAssertFalse(fresh.isEmpty, "precondition: the insert produced at least one new view")
        for view in fresh {
            XCTAssertEqual(view.lastTransition?.isImmediate, true,
                           "a view created in this pass has nothing to animate from")
        }
    }

    // MARK: - The case that already worked

    func testContentReconciliationStillMeasuresWithThePassTransition() {
        let (fixture, items) = makeFixture()

        let bumped = items.map { MeasureRecordingItem(id: $0.id, revision: $0.id == 0 ? 1 : 0) }
        fixture.listView.applyChanges(items: bumped, transition: .linear(duration: 0.3))

        let reconciled = loadedViews(fixture).first
        XCTAssertEqual(reconciled?.lastTransition?.animation, .curve(duration: 0.3, curve: .linear),
                       "a reconciled row still measures with the pass transition")
    }
}
