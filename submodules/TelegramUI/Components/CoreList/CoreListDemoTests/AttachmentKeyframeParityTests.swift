import XCTest
@testable import CoreListDemo

final class AttachmentKeyframeParityTests: XCTestCase {
    /// Driven through `TestScrollEngine` rather than `PhysicsScrollEngine`: the production engine's
    /// `core` and `handlePan` are private, so no test can launch a real flight on it, and every
    /// existing flight-level test uses this harness for the same reason. It runs the REAL
    /// `KeyframeFlight` and mirrors the production launch/rebake/settle points exactly.
    private func flyingEngine(clock: SyntheticClock) -> TestScrollEngine {
        let engine = TestScrollEngine(clock: clock, viewport: CGSize(width: 390, height: 800))
        engine.decelerationMode = .keyframe
        engine.setEdges(min: 0, max: 10_000)
        engine.setOffset(500)
        return engine
    }

    func testAKeyframeFlightPublishesItsTrajectory() {
        let clock = SyntheticClock()
        let engine = flyingEngine(clock: clock)
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        engine.simulateFlick(offsetVelocity: 2_000)

        let flight = published.compactMap { $0 }.first
        XCTAssertNotNil(flight, "a launched flight must publish")
        XCTAssertGreaterThan(flight!.trajectory.duration, 0)
        XCTAssertGreaterThanOrEqual(flight!.trajectory.samples.count, 2)
    }

    func testSteppedDecelerationPublishesNoFlight() {
        let clock = SyntheticClock()
        let engine = TestScrollEngine(clock: clock, viewport: CGSize(width: 390, height: 800))
        engine.decelerationMode = .stepped
        engine.setEdges(min: 0, max: 10_000)
        engine.setOffset(500)
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        engine.simulateFlick(offsetVelocity: 2_000)

        XCTAssertTrue(published.compactMap { $0 }.isEmpty,
                      "stepped deceleration advances on the main thread — nothing to compose against")
    }

    func testASettledFlightPublishesNil() {
        let clock = SyntheticClock()
        let engine = flyingEngine(clock: clock)
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        engine.simulateFlick(offsetVelocity: 2_000)
        XCTAssertNotNil(published.last ?? nil)

        // Run past the flight's end.
        for _ in 0..<600 {
            clock.advance(by: 1.0 / 60)
            engine.tick(dt: 1.0 / 60)
            if !engine.isDecelerating { break }
        }
        XCTAssertFalse(engine.isDecelerating, "precondition: the flight must have settled")
        XCTAssertNil(published.last ?? ScrollFlight(trajectory: Trajectory(samples: []), beginTime: 0),
                     "a settled flight must publish nil so consumers tear their tracks down")
    }

    fileprivate func groupedItems(count: Int = 60, groupSize: Int = 5) -> [CoreListItem] {
        (0..<count).map { index in
            let group = index / groupSize
            return AttachedItem(id: index, height: 50,
                                attachedItems: ["date\(group)": FixedHeightAttachment(
                                    label: "group\(group)", height: 30,
                                    placement: .overlay, edge: .top, isFloating: true)])
        }
    }

    fileprivate func rampTrajectory(from: CGFloat, to: CGFloat,
                                    duration: TimeInterval = 0.5,
                                    steps: Int = 50) -> Trajectory {
        Trajectory(samples: (0...steps).map { i in
            let phase = CGFloat(i) / CGFloat(steps)
            return .init(t: duration * Double(phase),
                         offset: from + (to - from) * phase,
                         velocity: 0)
        })
    }

    /// While a flight plays, the attachment's SETTLED frame is its destination — exactly as
    /// `contentHost.bounds.origin.y` is parked at `trajectory.finalOffset` — and the additive keyframe
    /// supplies the displacement. Solving at the live offset here would double the header's travel.
    func testAttachmentsAreParkedAtTheFlightsFinalOffset() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let window = fixture.activeWindow
        let attachment = window.attachments.first!

        let liveOffset = fixture.listView.engine.offset
        let finalOffset = liveOffset + 400
        fixture.listView.activeScrollFlight = ScrollFlight(
            trajectory: rampTrajectory(from: liveOffset, to: finalOffset), beginTime: 0)
        fixture.listView.renderAttachments()

        let parked = fixture.listView.attachmentMap(attachment, window: window)
            .y(atOffset: finalOffset) - window.minY
        XCTAssertEqual(attachment.view.frame.minY, parked, accuracy: 0.001,
                       "the settled frame must be the flight's destination, not the live offset")

        fixture.listView.activeScrollFlight = nil
        fixture.listView.renderAttachments()
        let live = fixture.listView.attachmentMap(attachment, window: window)
            .y(atOffset: liveOffset) - window.minY
        XCTAssertEqual(attachment.view.frame.minY, live, accuracy: 0.001,
                       "with no flight it returns to solving at the live offset")
    }

    /// `renderAttachments` parks the FRAME at the flight's destination and delivers the DISTANCE at
    /// the live offset. Both are needed: the frame must not move under the additive animation, and
    /// the distance must track what the user sees, since nothing animates it on the render server.
    func testRenderAttachmentsDeliversTheDistanceAtTheLiveOffset() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let window = fixture.activeWindow
        let live = fixture.listView.engine.offset
        let settled = live + 2_000
        fixture.listView.activeScrollFlight = ScrollFlight(
            trajectory: rampTrajectory(from: live, to: settled), beginTime: 0)
        fixture.listView.renderAttachments()

        XCTAssertFalse(window.attachments.isEmpty,
                       "precondition: the fixture must produce attachment runs")
        var sawADifference = false
        for attachment in window.attachments {
            let map = fixture.listView.attachmentMap(attachment, window: window)
            let view = attachment.view as! FixedHeightAttachmentView
            XCTAssertEqual(view.lastStickDistance ?? .nan,
                           map.stickDistance(atOffset: live),
                           accuracy: 0.001,
                           "delivered distance must solve at the live offset")
            if abs(map.stickDistance(atOffset: live) - map.stickDistance(atOffset: settled)) > 1.0 {
                sawADifference = true
            }
        }
        // Non-vacuity: if every run reported the same distance at both offsets, the assertion above
        // would hold no matter which offset the implementation used.
        XCTAssertTrue(sawADifference,
                      "the flight must move at least one run between regimes for this to prove anything")
    }

    private func map(edge: CoreListAttachmentEdge = .top,
                     bandTop: CGFloat = 100, bandBottom: CGFloat = 400,
                     height: CGFloat = 30, anchor: CGFloat = 0,
                     contentBase: CGFloat = 0) -> AttachmentOffsetMap {
        AttachmentOffsetMap(bandTop: bandTop, bandBottom: bandBottom, height: height,
                            anchor: anchor, contentBase: contentBase,
                            edge: edge, isFloating: true)
    }

    /// THE parity assertion: every emitted vertex equals the map evaluated at that vertex's offset,
    /// expressed additively against the destination. If the sticky math is ever written a second time
    /// for the baked path, this fails.
    func testComposedKeyframeMatchesTheMapAtEveryVertex() {
        let m = map()
        // Sweeps the whole piecewise range: below lo, through the parked segment, past hi.
        let trajectory = rampTrajectory(from: 0, to: 500)
        let composed = m.composedKeyframe(trajectory: trajectory)

        XCTAssertEqual(composed.values.count, trajectory.samples.count)
        XCTAssertEqual(composed.keyTimes.count, trajectory.samples.count)
        let settled = m.y(atOffset: trajectory.finalOffset)
        for (index, sample) in trajectory.samples.enumerated() {
            XCTAssertEqual(composed.values[index],
                           m.y(atOffset: sample.offset) - settled,
                           accuracy: 1e-9,
                           "vertex \(index) at offset \(sample.offset)")
        }
    }

    /// The distance is solved at the LIVE offset while the frame is parked at the flight's
    /// destination. That is only sound because the two describe the same rendered position: the
    /// baked track is `y(atOffset:)` sampled along the trajectory, so evaluating the same map at the
    /// same offset reproduces what CA draws. If either path is ever re-derived, this fails.
    func testStickDistanceDescribesTheRenderedPositionAtEveryVertex() {
        let m = map()
        let trajectory = rampTrajectory(from: 0, to: 500)
        let composed = m.composedKeyframe(trajectory: trajectory)
        let settledY = m.y(atOffset: trajectory.finalOffset)

        for (index, sample) in trajectory.samples.enumerated() {
            // What the render server actually shows at this vertex: the parked model frame plus the
            // additive value.
            let renderedY = settledY + composed.values[index]
            XCTAssertEqual(m.stickDistance(atOffset: sample.offset),
                           renderedY - m.lo,
                           accuracy: 1e-9,
                           "vertex \(index) at offset \(sample.offset)")
        }
    }

    func testComposedKeyframeResolvesToZero() {
        let composed = map().composedKeyframe(trajectory: rampTrajectory(from: 0, to: 500))
        XCTAssertEqual(composed.values.last!, 0, accuracy: 1e-9,
                       "an additive track must resolve onto the settled endpoint")
        XCTAssertEqual(composed.keyTimes.first!, 0, accuracy: 1e-9)
        XCTAssertEqual(composed.keyTimes.last!, 1, accuracy: 1e-9)
    }

    /// A non-floating attachment does not move relative to content, so it needs no track at all.
    func testANonFloatingAttachmentComposesToNothing() {
        let m = AttachmentOffsetMap(bandTop: 100, bandBottom: 400, height: 30,
                                    anchor: 0, contentBase: 0, edge: .top, isFloating: false)
        let composed = m.composedKeyframe(trajectory: rampTrajectory(from: 0, to: 500))
        XCTAssertTrue(composed.values.allSatisfy { abs($0) < 1e-9 },
                      "a rigid attachment rides the content translation; its own track is flat")
    }

    /// An attachment gets a track exactly when the flight makes it move RELATIVE to the content — i.e.
    /// when its solve is not constant across the trajectory. A run far enough below the viewport that
    /// the display anchor never reaches its band stays pinned to its band top for the whole flight, so
    /// it rides the content translation and needs no track of its own. Asserting "every attachment
    /// gets one" would be asserting a pessimisation.
    func testAFlightInstallsAnAdditiveKeyframeOnEveryMovingAttachment() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems(), emitsCA: true)
        let live = fixture.listView.engine.offset
        let trajectory = rampTrajectory(from: live, to: live + 400)
        fixture.listView.activeScrollFlight = ScrollFlight(trajectory: trajectory, beginTime: 0)
        fixture.listView.renderAttachments()

        let window = fixture.activeWindow
        var moving = 0
        var stationary = 0
        for attachment in window.attachments {
            let composed = fixture.listView.attachmentMap(attachment, window: window)
                .composedKeyframe(trajectory: trajectory)
            let movesRelativeToContent = composed.values.contains { abs($0) > 1e-9 }
            let animation = attachment.view.layer
                .animation(forKey: CoreVirtualListView.attachmentFlightKey)

            if movesRelativeToContent {
                moving += 1
                let keyframe = animation as? CAKeyframeAnimation
                XCTAssertNotNil(keyframe, "a moving attachment must ride the flight")
                XCTAssertEqual(keyframe?.keyPath, "position.y")
                XCTAssertTrue(keyframe?.isAdditive ?? false)
                XCTAssertEqual(keyframe?.calculationMode, .linear)
                XCTAssertEqual(keyframe?.duration ?? 0, trajectory.duration, accuracy: 1e-9)
            } else {
                stationary += 1
                XCTAssertNil(animation,
                             "an attachment that does not move relative to content needs no track")
            }
        }
        XCTAssertGreaterThan(moving, 0, "precondition: this flight must move at least one attachment")
        XCTAssertGreaterThan(stationary, 0,
                             "precondition: a run out of the anchor's reach must stay stationary")
    }

    /// A flight's trajectory is baked ONCE, in the coordinate base of that moment. Window rebalancing
    /// re-bases the container mid-flight (`applyShift` → `KeyframeFlight.noteShift`), so everything
    /// composed against the trajectory must add the accrued shift. Measured drifting to 1330pt stale
    /// over a single fling before this was fixed: attachments parked where the flight WOULD have
    /// landed, and jumped on every rebalance.
    func testTheSolveTracksTheFlightsShiftedRestingPlace() {
        let items: [CoreListItem] = (0..<400).map { index in
            let group = index / 6
            return AttachedItem(id: index, height: 95,
                                attachedItems: ["date\(group)": FixedHeightAttachment(
                                    label: "g\(group)", height: 34,
                                    placement: .overlay, edge: .top, isFloating: true)])
        }
        let clock = SyntheticClock()
        let fixture = PhysicsListFixture(viewport: CGSize(width: 393, height: 852),
                                         items: items,
                                         decelerationMode: .keyframe,
                                         clock: clock)
        fixture.listView.applyChanges(scrollTo: .init(index: 150, pointOffset: 0),
                                      transition: .immediate)
        fixture.simulateFlick(offsetVelocity: 3500)

        var sawShift = false
        for _ in 0..<24 {
            clock.advance(by: 1.0 / 60)
            fixture.tick(dt: 1.0 / 60)
            guard let settled = fixture.engine.keyframeSettledOffset,
                  let flight = fixture.listView.activeScrollFlight else { break }
            if abs(settled - flight.trajectory.finalOffset) > 1 { sawShift = true }
            XCTAssertEqual(fixture.listView.attachmentSolveOffset, settled, accuracy: 0.5,
                           "attachments must park at the flight's SHIFTED resting place")
        }
        XCTAssertTrue(sawShift,
                      "precondition: rebalancing must have re-based the flight, or this test cannot "
                        + "observe the stale-base defect")
    }

    func testEndingTheFlightRemovesTheTracks() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems(), emitsCA: true)
        let live = fixture.listView.engine.offset
        fixture.listView.activeScrollFlight = ScrollFlight(
            trajectory: rampTrajectory(from: live, to: live + 400), beginTime: 0)
        fixture.listView.renderAttachments()
        let view = fixture.activeWindow.attachments.first!.view
        XCTAssertNotNil(view.layer.animation(forKey: CoreVirtualListView.attachmentFlightKey))

        fixture.listView.activeScrollFlight = nil
        fixture.listView.renderAttachments()
        XCTAssertNil(view.layer.animation(forKey: CoreVirtualListView.attachmentFlightKey),
                     "a finished or caught flight must leave no track behind")
    }
}
