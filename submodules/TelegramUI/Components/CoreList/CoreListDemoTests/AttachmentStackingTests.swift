import XCTest
@testable import CoreListDemo

/// Stacking: an attachment that yields to a group of others resolves its own position against
/// theirs, INSIDE `AttachmentOffsetMap.y(atOffset:)`. Why it can live nowhere else, and the two
/// deliberate divergences from ListViewImpl, are under "Topic headers" in
/// `docs/chat/corelist-chat-history-backend.md`.
///
/// The one-level-only rule is enforced by an `assert` in `y(atOffset:)` rather than a test: a Swift
/// assertion traps the process, which XCTest cannot catch.
final class AttachmentStackingTests: XCTestCase {
    /// A non-floating `.top` map sits at its band top at every offset — the simplest way to place a
    /// partner at an exact, known y without threading anchors through the test.
    private func partner(at y: CGFloat, height: CGFloat = 30) -> AttachmentOffsetMap {
        AttachmentOffsetMap(bandTop: y, bandBottom: y + height, height: height,
                            anchor: 0, contentBase: 0, edge: .top, isFloating: false)
    }

    /// Floating `.top`, anchor 0, contentBase 0: own y is exactly `clamp(offset, lo, hi)`, so a test
    /// names the attachment's natural position by choosing the offset it evaluates at.
    private func yielding(to partners: [AttachmentOffsetMap],
                          gap: CGFloat = 27,
                          bandTop: CGFloat = 0,
                          bandBottom: CGFloat = 1000,
                          height: CGFloat = 30) -> AttachmentOffsetMap {
        AttachmentOffsetMap(bandTop: bandTop, bandBottom: bandBottom, height: height,
                            anchor: 0, contentBase: 0, edge: .top, isFloating: true,
                            yield: (partners: partners, gap: gap))
    }

    /// Non-vacuity for everything below: the same geometry with no yield declared stays put, so any
    /// movement these tests observe is the composition and not the underlying map.
    func testWithoutAYieldTheMapIsUnchanged() {
        let m = AttachmentOffsetMap(bandTop: 0, bandBottom: 1000, height: 30,
                                    anchor: 0, contentBase: 0, edge: .top, isFloating: true)
        XCTAssertEqual(m.y(atOffset: 110), 110, accuracy: 1e-9)
        XCTAssertEqual(yielding(to: []).y(atOffset: 110), 110, accuracy: 1e-9,
                       "an empty partner set is the same no-op")
    }

    /// A partner far above must NOT drag the yielding attachment up: only an OVERLAPPING partner
    /// participates. Without the overlap test, `partnerY - gap` wins the min unconditionally and the
    /// header flies to the top of the band.
    func testFarAbovePartnerDoesNotPull() {
        let m = yielding(to: [partner(at: 0)])
        XCTAssertEqual(m.y(atOffset: 500), 500, accuracy: 1e-9,
                       "partner rect [0, 30] does not meet own rect [500, 530]")
    }

    /// The nudge engages on overlap and lands exactly `gap` clear of the partner's top.
    func testOverlappingPartnerPushesByGap() {
        // Partner rect [100, 130]; own natural rect [110, 140]. 110 - 27 above 100 -> 73.
        let m = yielding(to: [partner(at: 100)])
        XCTAssertEqual(m.y(atOffset: 110), 73, accuracy: 1e-9)
    }

    /// Never above the band top: the clamp survives the nudge.
    func testNudgeClampsAtBandTop() {
        let m = yielding(to: [partner(at: 100)], bandTop: 90)
        // The unclamped answer is 73, which is above the band.
        XCTAssertEqual(m.y(atOffset: 110), 90, accuracy: 1e-9)
    }

    /// Deterministic among several overlapping partners: taking the min over ALL of them needs no
    /// tie-break, so the result cannot depend on the order partners are supplied in. `ListViewImpl`
    /// picks one partner by an order-dependent comparison (ListView.swift:4064-4070) and iterates a
    /// Dictionary; we implement its evident intent instead, and this is where the two may diverge —
    /// only on inputs where its own answer is arbitrary.
    func testTopmostPartnerWinsRegardlessOfOrder() {
        // 100 overlaps own natural rect [110, 140]; 60 comes into reach only after that push;
        // 200 never participates at all.
        let ys: [CGFloat] = [100, 60, 200]
        for permutation in permutations(of: ys) {
            let m = yielding(to: permutation.map { partner(at: $0) })
            XCTAssertEqual(m.y(atOffset: 110), 33, accuracy: 1e-9,
                           "order \(permutation) must not change the answer")
        }
    }

    /// The case `ListViewImpl` needed a second pass for (`for _ in 0 ..< 2`, ListView.swift:4054):
    /// pushing clear of one partner creates a NEW overlap with a partner that was clear before.
    func testPushCreatingNewOverlapConvergesToFixedPoint() {
        let far = partner(at: 60)
        let near = partner(at: 100)
        // Precondition: at the natural position only `near` overlaps.
        let single = yielding(to: [far])
        XCTAssertEqual(single.y(atOffset: 110), 110, accuracy: 1e-9,
                       "precondition: [60, 90] must not meet [110, 140]")

        // Clearing `near` lands at 73, whose rect [73, 103] now meets [60, 90] — so the fixed point
        // is 60 - 27 = 33, not 73.
        let m = yielding(to: [near, far])
        XCTAssertEqual(m.y(atOffset: 110), 33, accuracy: 1e-9)
    }

    /// The nudge is a function of offset like everything else on this type: it engages and releases
    /// as the scroll carries the partner past.
    func testTheNudgeReleasesWhenTheOverlapEnds() {
        let m = yielding(to: [partner(at: 100)])
        XCTAssertEqual(m.y(atOffset: 40), 40, accuracy: 1e-9, "own rect [40, 70] is clear above")
        XCTAssertEqual(m.y(atOffset: 110), 73, accuracy: 1e-9, "overlapping: pushed clear")
        XCTAssertEqual(m.y(atOffset: 400), 400, accuracy: 1e-9, "own rect [400, 430] is clear below")
    }

    // MARK: - Baking

    private func rampTrajectory(from: CGFloat, to: CGFloat,
                                duration: TimeInterval = 0.5,
                                steps: Int = 50) -> Trajectory {
        Trajectory(samples: (0...steps).map { i in
            let phase = CGFloat(i) / CGFloat(steps)
            return .init(t: duration * Double(phase),
                         offset: from + (to - from) * phase,
                         velocity: 0)
        })
    }

    /// THE reason the yield lives in the solve. `composedKeyframe` bakes the CA track a momentum
    /// flight rides by SAMPLING `y(atOffset:)` (AttachmentSolve.swift), so a yield resolved anywhere
    /// else would be absent from the flight: the attachment would ride un-nudged for the whole
    /// deceleration and snap into place at the end. This is the test that would have caught that
    /// design.
    ///
    /// Asserted against INDEPENDENTLY computed positions rather than against `y(atOffset:)` alone,
    /// which would hold vacuously for a map that never nudges at all.
    func testComposedKeyframeCarriesTheNudge() {
        let m = yielding(to: [partner(at: 100)])
        // Own natural y is the offset itself. Partner rect [100, 130] meets own rect [y, y + 30] for
        // y in (70, 130), where the solve takes `min(y, 100 - 27)` — so the overlapping stretch
        // BELOW 73 is untouched: the nudge only ever moves an attachment up.
        func expected(atOffset offset: CGFloat) -> CGFloat {
            (offset > 70 && offset < 130) ? min(offset, 73) : offset
        }
        // The ramp sweeps in below the partner, through the overlap, and out the far side.
        let trajectory = rampTrajectory(from: 0, to: 400)
        let composed = m.composedKeyframe(trajectory: trajectory)
        let settled = expected(atOffset: trajectory.finalOffset)

        var nudgedVertices = 0
        for (index, sample) in trajectory.samples.enumerated() {
            if expected(atOffset: sample.offset) != sample.offset {
                nudgedVertices += 1
            }
            XCTAssertEqual(composed.values[index],
                           expected(atOffset: sample.offset) - settled,
                           accuracy: 1e-9,
                           "vertex \(index) at offset \(sample.offset)")
        }
        XCTAssertGreaterThan(nudgedVertices, 0,
                             "precondition: the trajectory must cross the overlap, or the baked "
                                + "track would be identical with or without the yield")
    }

    /// The shift path, which re-bases a once-baked trajectory into current list coordinates: it must
    /// go through the composed solve too, not around it.
    func testComposedKeyframeCarriesTheNudgeUnderACoordinateShift() {
        let m = yielding(to: [partner(at: 100)])
        let trajectory = rampTrajectory(from: -300, to: -200)
        let shift: CGFloat = 300
        let composed = m.composedKeyframe(trajectory: trajectory, coordinateShift: shift)
        let settled = m.y(atOffset: trajectory.finalOffset + shift)

        for (index, sample) in trajectory.samples.enumerated() {
            XCTAssertEqual(composed.values[index],
                           m.y(atOffset: sample.offset + shift) - settled,
                           accuracy: 1e-9,
                           "vertex \(index) at offset \(sample.offset)")
        }
        XCTAssertEqual(settled, 73, accuracy: 1e-9,
                       "precondition: the shifted destination must land inside the overlap")
    }

    // MARK: - Stick distance

    /// `ListViewImpl` measures a stacked header against `naturalOverlapLowerBound` — the partner's
    /// own natural origin less the gap (Display/Source/ListView.swift:4039-4052, :4084) — not against
    /// its own band edge. Otherwise a header that has merely been pushed clear reports a full gap of
    /// stick and fades out as though parked.
    func testStickDistanceMeasuresAgainstTheAdjustedBound() {
        // Both bands end at 1000, so the two runs share a natural origin exactly as a day's date pill
        // and that day's topic header do.
        let sharing = partner(at: 970)
        let m = AttachmentOffsetMap(bandTop: 0, bandBottom: 1000, height: 30,
                                    anchor: 0, contentBase: 0, edge: .bottom, isFloating: true,
                                    yield: (partners: [sharing], gap: 27))
        // Riding its run: natural y is 970, which the partner occupies, so the solve pushes to 943.
        XCTAssertEqual(m.y(atOffset: 970), 943, accuracy: 1e-9, "precondition: nudged off its edge")
        XCTAssertEqual(m.stickDistance(atOffset: 970), 0, accuracy: 1e-9,
                       "a riding header must report no stick even though the yield displaced it")
        // Parked 70pt clear of the natural edge, and out of the partner's reach.
        XCTAssertEqual(m.y(atOffset: 900), 900, accuracy: 1e-9, "precondition: not nudged here")
        XCTAssertEqual(m.stickDistance(atOffset: 900), 43, accuracy: 1e-9,
                       "ListViewImpl: (1000 - 27) - (900 + 30)")
    }

    /// The adjustment is keyed on a partner sharing the run boundary, as ListViewImpl's
    /// `otherNaturalOriginY == naturalY` is (ListView.swift:4046). A group member belonging to some
    /// other run may still push this attachment around, but it does not move the bound.
    func testStickDistanceIsUnadjustedWhenNoPartnerSharesTheNaturalOrigin() {
        let elsewhere = partner(at: 500)
        let m = AttachmentOffsetMap(bandTop: 0, bandBottom: 1000, height: 30,
                                    anchor: 0, contentBase: 0, edge: .bottom, isFloating: true,
                                    yield: (partners: [elsewhere], gap: 27))
        XCTAssertEqual(m.stickDistance(atOffset: 900), 70, accuracy: 1e-9)
    }

    // MARK: - Wiring

    /// Two coexisting header spaces, as a monoforum has them: a "date" run over every group of five
    /// rows tagged into a group, and a shorter "topic" run over the first three of each, yielding to
    /// it. Both float at the top edge, so parked they land on the same point and the yield is what
    /// separates them.
    private func stackedItems(count: Int = 60) -> [CoreListItem] {
        (0..<count).map { index in
            let group = index / 5
            var attachments: [AnyHashable: CoreListAttachedItem] = [
                "date\(group)": FixedHeightAttachment(label: "date\(group)", height: 30,
                                                      stackingGroup: "space2")
            ]
            if index % 5 < 3 {
                attachments["topic\(group)"] = FixedHeightAttachment(
                    label: "topic\(group)", height: 30,
                    stackingYield: (group: "space2", gap: 27))
            }
            return AttachedItem(id: index, height: 50, attachedItems: attachments)
        }
    }

    private func hasPrefix(_ key: AnyHashable, _ prefix: String) -> Bool {
        (key.base as? String)?.hasPrefix(prefix) ?? false
    }

    /// The only coverage of the declaration → partner-map path: a group TAG on one attachment reaches
    /// the other's solve. Everything else in this file drives `AttachmentOffsetMap` directly.
    func testAYieldingRunResolvesAgainstItsGroupPartnersSolvedPosition() {
        let fixture = VirtualListFixture(items: stackedItems())
        let window = fixture.activeWindow
        guard let topic = window.attachments.first(where: { hasPrefix($0.key, "topic") }),
              let suffix = (topic.key.base as? String)?.dropFirst("topic".count),
              let date = window.attachments.first(where: { $0.key == AnyHashable("date" + suffix) })
        else {
            return XCTFail("fixture must load a topic run and its date partner")
        }
        let topicMap = fixture.listView.attachmentMap(topic, window: window)
        let dateMap = fixture.listView.attachmentMap(date, window: window)

        // Parked: the display anchor sits inside BOTH bands, so the two runs would otherwise land on
        // exactly the same point.
        let parked = (topicMap.lowBreakpoint! + topicMap.highBreakpoint!) / 2
        XCTAssertEqual(dateMap.y(atOffset: parked),
                       dateMap.anchorInFrameSpace(atOffset: parked), accuracy: 1e-9,
                       "precondition: the partner is parked at the display anchor and yields to nobody")
        XCTAssertEqual(topicMap.y(atOffset: parked),
                       dateMap.y(atOffset: parked) - 27, accuracy: 1e-9,
                       "the yielding run must sit a gap clear of its partner's SOLVED position")

        // Released: the topic run has been pushed out of the display area entirely while the date run
        // is still parked far below it, so nothing overlaps and the yield does not apply.
        let released = topicMap.highBreakpoint! + 100
        XCTAssertEqual(topicMap.y(atOffset: released), topicMap.hi, accuracy: 1e-9,
                       "with no overlap the yielding run sits at its own natural bound")
    }

    // MARK: - Z-order

    /// `ListViewImpl` puts a stacked header below every other header node
    /// (`insertItemBelowOtherHeaders`, ListView.swift:4167-4180). NOT free here: the attachment sort
    /// is `(memberRange.lowerBound, key description)`, and this makes the yield declaration an input
    /// to an ordering other behavior already depends on.
    func testYieldingAttachmentSortsBelowItsTargetGroup() {
        let runs = AttachmentRuns.pendingRuns(in: stackedItems(count: 10), loadedRange: 0..<10)
        let topic = runs.firstIndex { hasPrefix($0.key, "topic") }
        let date = runs.firstIndex { hasPrefix($0.key, "date") }
        XCTAssertNotNil(topic)
        XCTAssertNotNil(date)
        XCTAssertLessThan(topic!, date!,
                          "a yielding run must precede the group it defers to; the two share a "
                            + "member boundary, so the key tiebreak would otherwise decide it")
    }

    /// The sort is only half of it: sibling order is what actually decides z-order, and attachment
    /// views are long-lived — the two runs rarely enter the loaded window in the same pass, so a
    /// render that only appends new views leaves the order to the accident of creation.
    func testRenderRestoresTheZOrderOfALongLivedAttachmentView() {
        let fixture = VirtualListFixture(items: stackedItems())
        let window = fixture.activeWindow
        guard let topic = window.attachments.first(where: { hasPrefix($0.key, "topic") }),
              let date = window.attachments.first(where: { hasPrefix($0.key, "date") })
        else {
            return XCTFail("fixture must load both runs")
        }
        let container = fixture.listView.attachmentContainer
        XCTAssertLessThan(container.subviews.firstIndex(of: topic.view)!,
                          container.subviews.firstIndex(of: date.view)!)

        // Stand in for the run entering the window later: its view ends up on top.
        container.bringSubviewToFront(topic.view)
        XCTAssertGreaterThan(container.subviews.firstIndex(of: topic.view)!,
                             container.subviews.firstIndex(of: date.view)!,
                             "precondition: the order must actually be wrong before the render")

        fixture.listView.renderAttachments()
        XCTAssertLessThan(container.subviews.firstIndex(of: topic.view)!,
                          container.subviews.firstIndex(of: date.view)!,
                          "every render must re-assert the order, not just the pass that creates the view")
    }

    private func permutations<T>(of values: [T]) -> [[T]] {
        guard values.count > 1 else { return [values] }
        var result: [[T]] = []
        for (index, value) in values.enumerated() {
            var rest = values
            rest.remove(at: index)
            for tail in permutations(of: rest) {
                result.append([value] + tail)
            }
        }
        return result
    }
}
