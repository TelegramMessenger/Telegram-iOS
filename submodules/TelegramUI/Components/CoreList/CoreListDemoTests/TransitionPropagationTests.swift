import XCTest
@testable import CoreListDemo

/// A row that records the transition of every `update`/`apply` call it receives, so the propagation
/// rule — a non-immediate transition reaches a row only when that row's content changed in the pass —
/// is directly observable.
private final class RecordingRowView: UIView, CoreListItemView {
    enum Call: Equatable {
        case update(isImmediate: Bool, duration: TimeInterval)
        case apply(isImmediate: Bool, duration: TimeInterval)
    }

    var calls: [Call] = []
    var height: CGFloat = 40
    var onContentDidChange: ((Bool) -> Void)?

    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        calls.append(.update(isImmediate: transition.isImmediate, duration: transition.duration))
        return height
    }

    func noteApply(_ transition: CoreListTransition) {
        calls.append(.apply(isImmediate: transition.isImmediate, duration: transition.duration))
    }
}

private final class RecordingRow: CoreListItem {
    let id: Int
    let version: Int
    private let sharedView: RecordingRowView

    init(id: Int, version: Int, sharedView: RecordingRowView) {
        self.id = id
        self.version = version
        self.sharedView = sharedView
    }

    var identity: AnyHashable { AnyHashable(id) }
    func view() -> UIView & CoreListItemView { sharedView }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? RecordingRow else { return false }
        return other.id == id && other.version == version
    }

    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? RecordingRowView)?.noteApply(transition)
    }
}

final class TransitionPropagationTests: XCTestCase {
    /// `VirtualListFixture` takes its items at init and builds a window immediately, so every test
    /// clears the recorded calls after construction. The fixture pins `durationFactor: { 1 }`, so
    /// recorded durations are the logical ones.
    private func makeFixture(_ view: RecordingRowView) -> VirtualListFixture {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: [RecordingRow(id: 1, version: 0, sharedView: view)])
        view.calls.removeAll()
        return fixture
    }

    private func updates(_ view: RecordingRowView) -> [(isImmediate: Bool, duration: TimeInterval)] {
        view.calls.compactMap { call in
            if case let .update(isImmediate, duration) = call {
                return (isImmediate: isImmediate, duration: duration)
            }
            return nil
        }
    }

    private func sawApply(_ view: RecordingRowView) -> Bool {
        view.calls.contains { if case .apply = $0 { return true } else { return false } }
    }

    func testFreshViewMeasuresImmediately() {
        let view = RecordingRowView()
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: [])
        view.calls.removeAll()

        fixture.listView.applyChanges(items: [RecordingRow(id: 1, version: 0, sharedView: view)],
                                      transition: .easeInOut(duration: 0.5))

        let measured = updates(view)
        XCTAssertFalse(measured.isEmpty, "the fresh row must be measured")
        XCTAssertTrue(measured.allSatisfy(\.isImmediate),
                      "a newly created view has nothing to animate from")
        XCTAssertFalse(sawApply(view), "apply is only for reused survivors")
    }

    func testReconciledSurvivorReceivesThePassTransition() {
        let view = RecordingRowView()
        let fixture = makeFixture(view)

        fixture.listView.applyChanges(items: [RecordingRow(id: 1, version: 1, sharedView: view)],
                                      transition: .easeInOut(duration: 0.5))

        XCTAssertEqual(view.calls.first, .apply(isImmediate: false, duration: 0.5))
        let measured = updates(view)
        XCTAssertFalse(measured.isEmpty, "the reconciled row must be remeasured")
        XCTAssertTrue(measured.allSatisfy { !$0.isImmediate && abs($0.duration - 0.5) < 1e-9 },
                      "a reconciled survivor measures with the pass transition")
    }

    func testUnchangedSurvivorMeasuresImmediately() {
        let view = RecordingRowView()
        let fixture = makeFixture(view)

        // Same identity AND same version: isEqual is true, so no reconcile. The second row gives the
        // pass a real structural change, so it cannot short-circuit before measuring.
        fixture.listView.applyChanges(items: [RecordingRow(id: 1, version: 0, sharedView: view),
                                              RecordingRow(id: 2, version: 0,
                                                           sharedView: RecordingRowView())],
                                      transition: .easeInOut(duration: 0.5))

        XCTAssertFalse(sawApply(view))
        XCTAssertTrue(updates(view).allSatisfy(\.isImmediate),
                      "an unchanged survivor's content did not change; only its geometry, "
                      + "which ListAnimationModel owns")
    }

    func testDirtyFlushUsesTheFlushTransition() {
        let view = RecordingRowView()
        let fixture = makeFixture(view)

        view.height = 90
        view.onContentDidChange?(true)
        fixture.flushScheduler()

        let expected = fixture.listView.defaultDirtyDuration
        XCTAssertTrue(updates(view).contains { !$0.isImmediate && abs($0.duration - expected) < 1e-9 },
                      "an animated self-update must measure with the flush transition")
    }

    func testDirtyFlushWithoutAnimationMeasuresImmediately() {
        let view = RecordingRowView()
        let fixture = makeFixture(view)

        view.height = 90
        view.onContentDidChange?(false)
        fixture.flushScheduler()

        XCTAssertTrue(updates(view).allSatisfy(\.isImmediate))
    }
}
