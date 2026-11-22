import XCTest
import UIKit
@testable import CoreListDemo

/// A pass must start every row from where it is DRAWN, even when something earlier in the same runloop
/// turn has already re-based the row.
///
/// `presentation()` shows the last Core Animation commit. A pass or a rebalance whose window grows or
/// shrinks at its top rewrites every surviving row's container-local base in `render()`
/// (`frame.minY − window.minY`) and commits nothing, so a later pass in the same turn that differences
/// the presentation against the model reads that rebase as motion. News ran its widening pass and its
/// morph pass in one turn, and every row that moved started its track as far above itself as the window
/// had grown, across its neighbours.
///
/// These need a scene-attached window like every resume suite: a windowless fixture resolves no
/// presentation layer, so the resume path never reads the screen and the defect cannot show.
final class SameTransactionResumeTests: XCTestCase {
    /// A window on the test host's scene, so its layers enter the render tree and resolve a
    /// presentation layer at all (a scene-less `UIWindow` never does — see
    /// `PresentationResumeSamplingTests.testFixtureLayersHaveNoPresentationLayer`).
    private func makeRenderingWindow() throws -> UIWindow {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "no UIWindowScene in the test host; this test needs a rendering window")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
        window.makeKeyAndVisible()
        return window
    }

    private func settle() {
        CATransaction.flush()
        let deadline = Date().addingTimeInterval(0.1)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func rows(_ ids: [UUID], height: CGFloat) -> [CoreListItem] {
        ids.map { ContentResizableItem(id: $0, contentHeight: height) }
    }

    /// Eighty 100 pt rows scrolled to index 40 and committed: the loaded window starts far from index 0,
    /// so a wider band or a scroll up loads rows above every loaded one.
    private func scrolledFixture(window: UIWindow,
                                 ids: [UUID],
                                 emitsCA: Bool = false) -> VirtualListFixture {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 400),
                                         items: rows(ids, height: 100),
                                         preloadMargin: 100,
                                         emitsCA: emitsCA)
        window.addSubview(fixture.listView)
        window.layoutIfNeeded()
        fixture.listView.applyChanges(scrollTo: CoreListScrollTarget(index: 40, pointOffset: 0),
                                      transition: .immediate)
        settle()
        return fixture
    }

    private func screenYs(_ fixture: VirtualListFixture) -> [Int: CGFloat] {
        var result: [Int: CGFloat] = [:]
        for index in fixture.loadedIndices {
            result[index] = fixture.screenY(forIndex: index)
        }
        return result
    }

    /// Whether the pass just applied gave any of `indices` a position track, so a continuity check over
    /// them is not vacuous.
    private func movesAny(_ indices: [Int], in fixture: VirtualListFixture) -> Bool {
        indices.contains { fixture.positionTrack(identity: fixture.listView.items[$0].identity) != nil }
    }

    /// News's mode switch in miniature: a widening pass (rows prepended above, every loaded row
    /// re-based) and, in the same transaction, the pass that moves them. Without the committed-base
    /// record it fails by exactly the widening's rebase.
    func testAPassAfterAnUncommittedWideningStartsEveryRowWhereItIsDrawn() throws {
        let window = try makeRenderingWindow()
        defer { window.isHidden = true }
        let ids = (0..<80).map { _ in UUID() }
        let fixture = scrolledFixture(window: window, ids: ids)
        XCTAssertGreaterThan(try XCTUnwrap(fixture.loadedIndices.first), 0,
                             "precondition: the window does not start at index 0")
        let before = screenYs(fixture)
        let probe = try XCTUnwrap(fixture.view(identity: AnyHashable(ids[42]))).layer
        let baseBefore = probe.position.y

        fixture.listView.preloadMargin = 1600
        fixture.listView.applyChanges(items: rows(ids, height: 100), transition: .immediate)
        XCTAssertGreaterThan(probe.position.y - baseBefore, 100,
                             "precondition: the widening re-bases the loaded rows")
        XCTAssertEqual(try XCTUnwrap(probe.presentation()).position.y, baseBefore, accuracy: 0.5,
                       "precondition: the render tree still holds the old base")

        fixture.listView.applyChanges(items: rows(ids, height: 40),
                                      anchorMode: .preserveVisibleContent,
                                      transition: .linear(duration: 0.5))
        XCTAssertTrue(movesAny(Array(before.keys), in: fixture),
                      "precondition: the pass moves rows that were drawn before it")
        for (index, y) in before {
            guard let now = fixture.screenY(forIndex: index) else { continue }
            XCTAssertEqual(now, y, accuracy: 1e-6, "row \(index) starts away from where it is drawn")
        }
    }

    /// The same defect with a scroll in place of the widening: a rebalance that loads rows above the
    /// window re-bases the rows it keeps, and a pass later in the transaction must not read that as
    /// motion either.
    func testARebalanceEarlierInTheTransactionDoesNotPoisonAPass() throws {
        let window = try makeRenderingWindow()
        defer { window.isHidden = true }
        let ids = (0..<80).map { _ in UUID() }
        let fixture = scrolledFixture(window: window, ids: ids)
        let firstLoaded = try XCTUnwrap(fixture.loadedIndices.first)
        let probe = try XCTUnwrap(fixture.view(identity: AnyHashable(ids[41]))).layer
        let baseBefore = probe.position.y

        fixture.scroll(to: fixture.driver.engine.offset - 300)
        XCTAssertLessThan(try XCTUnwrap(fixture.loadedIndices.first), firstLoaded,
                          "precondition: the scroll loads rows above the window")
        XCTAssertGreaterThan(probe.position.y - baseBefore, 100,
                             "precondition: the rebalance re-bases the rows it keeps")
        XCTAssertEqual(try XCTUnwrap(probe.presentation()).position.y, baseBefore, accuracy: 0.5,
                       "precondition: the render tree still holds the old base")
        let before = screenYs(fixture)

        fixture.listView.applyChanges(items: rows(ids, height: 40), transition: .linear(duration: 0.5))
        XCTAssertTrue(movesAny(Array(before.keys), in: fixture),
                      "precondition: the pass moves rows that were drawn before it")
        for (index, y) in before {
            guard let now = fixture.screenY(forIndex: index) else { continue }
            XCTAssertEqual(now, y, accuracy: 1e-6, "row \(index) starts away from where it is drawn")
        }
    }

    /// The precise half: a row still IN FLIGHT when the turn's first pass re-bases it resumes from the
    /// position the render server draws, measured against the base that was committed. The model's
    /// clock is moved half way along the track while the render server has run it for 0.15 s, so the
    /// analytic answer is far from the drawn one and only the committed-base sample lands within a
    /// point. Sampled against the model instead, it is off by the widening's rebase.
    func testAnInFlightRowResumesFromWhereItIsDrawnAcrossAnUncommittedRebase() throws {
        let window = try makeRenderingWindow()
        defer { window.isHidden = true }
        let ids = (0..<80).map { _ in UUID() }
        let fixture = scrolledFixture(window: window, ids: ids, emitsCA: true)
        fixture.listView.applyChanges(items: rows(ids, height: 60), transition: .linear(duration: 0.6))
        CATransaction.flush()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))

        let identity = AnyHashable(ids[42])
        let layer = try XCTUnwrap(fixture.view(identity: identity)).layer
        let passA = try XCTUnwrap(fixture.positionTrack(identity: identity),
                                  "precondition: the row is moving")
        let committedBase = layer.position.y
        fixture.advance(by: 0.3)

        fixture.listView.preloadMargin = 1600
        fixture.listView.applyChanges(items: rows(ids, height: 60), transition: .immediate)
        XCTAssertEqual(fixture.positionTrack(identity: identity)?.generation, passA.generation,
                       "precondition: the widening leaves the row's track alone")
        XCTAssertGreaterThan(layer.position.y - committedBase, 100,
                             "precondition: the widening re-bases the row")
        let drawnOffset = try XCTUnwrap(layer.presentation()).position.y - committedBase
        XCTAssertGreaterThan(abs(drawnOffset), 1,
                             "precondition: the row is drawn away from its settled place")
        let drawnY = try XCTUnwrap(fixture.settledScreenY(identity: identity)) + drawnOffset
        XCTAssertGreaterThan(abs(try XCTUnwrap(fixture.screenY(identity: identity)) - drawnY), 10,
                             "precondition: the analytic answer is not where the row is drawn")

        fixture.listView.applyChanges(items: rows(ids, height: 30), transition: .linear(duration: 0.6))
        let passB = try XCTUnwrap(fixture.positionTrack(identity: identity))
        XCTAssertNotEqual(passB.generation, passA.generation, "precondition: the pass re-tracks the row")
        let settledY = try XCTUnwrap(fixture.settledScreenY(identity: identity))
        XCTAssertEqual(passB.from, drawnY - settledY, accuracy: 1,
                       "the row's new track must start where the render server draws it")
    }

    /// The same, with a scroll's rebalance as the turn's first write: the rebalance records the
    /// committed bases before `render()` re-bases the rows it keeps, so a pass after it in the same turn
    /// still measures against them.
    func testAnInFlightRowResumesFromWhereItIsDrawnAcrossAnUncommittedRebalance() throws {
        let window = try makeRenderingWindow()
        defer { window.isHidden = true }
        let ids = (0..<80).map { _ in UUID() }
        let fixture = scrolledFixture(window: window, ids: ids, emitsCA: true)
        fixture.listView.applyChanges(items: rows(ids, height: 60), transition: .linear(duration: 0.6))
        CATransaction.flush()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))

        let identity = AnyHashable(ids[42])
        let layer = try XCTUnwrap(fixture.view(identity: identity)).layer
        let passA = try XCTUnwrap(fixture.positionTrack(identity: identity),
                                  "precondition: the row is moving")
        let committedBase = layer.position.y
        let firstLoaded = try XCTUnwrap(fixture.loadedIndices.first)
        fixture.advance(by: 0.3)

        fixture.scroll(to: fixture.driver.engine.offset - 300)
        XCTAssertLessThan(try XCTUnwrap(fixture.loadedIndices.first), firstLoaded,
                          "precondition: the scroll loads rows above the window")
        XCTAssertEqual(fixture.positionTrack(identity: identity)?.generation, passA.generation,
                       "precondition: the scroll leaves the row's track alone")
        XCTAssertGreaterThan(layer.position.y - committedBase, 100,
                             "precondition: the rebalance re-bases the row")
        let drawnOffset = try XCTUnwrap(layer.presentation()).position.y - committedBase
        XCTAssertGreaterThan(abs(drawnOffset), 1,
                             "precondition: the row is drawn away from its settled place")
        let drawnY = try XCTUnwrap(fixture.settledScreenY(identity: identity)) + drawnOffset
        XCTAssertGreaterThan(abs(try XCTUnwrap(fixture.screenY(identity: identity)) - drawnY), 10,
                             "precondition: the analytic answer is not where the row is drawn")

        fixture.listView.applyChanges(items: rows(ids, height: 30), transition: .linear(duration: 0.6))
        let passB = try XCTUnwrap(fixture.positionTrack(identity: identity))
        XCTAssertNotEqual(passB.generation, passA.generation, "precondition: the pass re-tracks the row")
        let settledY = try XCTUnwrap(fixture.settledScreenY(identity: identity))
        XCTAssertEqual(passB.from, drawnY - settledY, accuracy: 1,
                       "the row's new track must start where the render server draws it")
    }

    /// A row the turn has already RE-TRACKED resumes from that new track, not from the screen: the
    /// screen still shows the committed base, which the new track's start has moved away from by the
    /// first pass's displacement. The model's clock moves between the two passes, so the second must
    /// start from the first's value at its own clock.
    func testARowReTrackedEarlierInTheTransactionResumesFromItsNewTrack() throws {
        let window = try makeRenderingWindow()
        defer { window.isHidden = true }
        let ids = (0..<80).map { _ in UUID() }
        let fixture = scrolledFixture(window: window, ids: ids)
        // In flight when the next turn's first pass runs, so that turn records their committed bases.
        fixture.listView.applyChanges(items: rows(ids, height: 70), transition: .linear(duration: 0.5))
        settle()
        var inFlight: [AnyHashable: UInt64] = [:]
        for index in fixture.loadedIndices {
            let identity = fixture.listView.items[index].identity
            if let track = fixture.positionTrack(identity: identity) {
                inFlight[identity] = track.generation
            }
        }
        XCTAssertFalse(inFlight.isEmpty, "precondition: rows are in flight when the turn begins")

        fixture.listView.applyChanges(items: rows(ids, height: 50), transition: .linear(duration: 0.5))
        fixture.advance(by: 0.1)
        var before: [Int: CGFloat] = [:]
        for index in fixture.loadedIndices {
            let identity = fixture.listView.items[index].identity
            guard let generation = inFlight[identity],
                  let track = fixture.positionTrack(identity: identity),
                  track.generation != generation
            else { continue }
            before[index] = fixture.screenY(forIndex: index)
        }
        XCTAssertFalse(before.isEmpty, "precondition: the first pass re-tracks rows that were in flight")

        fixture.listView.applyChanges(items: rows(ids, height: 40), transition: .linear(duration: 0.5))
        var compared = 0
        for (index, y) in before {
            guard let now = fixture.screenY(forIndex: index) else { continue }
            compared += 1
            XCTAssertEqual(now, y, accuracy: 1e-6,
                           "row \(index) must resume from its first track, not from the committed screen")
        }
        XCTAssertGreaterThan(compared, 0, "precondition: the re-tracked rows stay loaded")
    }
}
