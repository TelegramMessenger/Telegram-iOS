import XCTest
@testable import CoreListDemo

final class MixedPassStressOracleTests: XCTestCase {
    func testOracleAcceptsOverlappingStructuralGeometryAndScrollPasses() {
        let initial = (0..<120).map {
            MixedPassItem(
                id: $0,
                height: MixedPassScenario.heights[$0 % MixedPassScenario.heights.count]
            )
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 800),
            items: initial.map { $0 as CoreListItem },
            preloadMargin: 160,
            emitsCA: true
        )
        let oracle = MixedPassStressOracle()
        let before = oracle.capture(fixture: fixture)

        var changed = initial
        changed[0] = MixedPassItem(id: changed[0].id, height: 128)
        let inserted = (200..<205).map {
            MixedPassItem(id: $0, height: 60)
        }
        changed.insert(contentsOf: inserted, at: 5)
        let step = MixedPassStep(
            items: changed,
            size: CGSize(width: 430, height: 874),
            insets: UIEdgeInsets(top: 120, left: 40, bottom: 40, right: 50),
            scrollTo: .init(index: 40, pointOffset: 20),
            transition: .easeInOut(duration: 0.5),
            advanceAfter: 0.05,
            actions: [
                .resize(index: 0, id: 0, from: 44, to: 128),
                .insert(index: 5, ids: Array(200..<205)),
                .scroll(index: 40, pointOffset: 20),
            ]
        )

        fixture.listView.frame.size = step.size
        fixture.listView.applyChanges(
            items: step.items.map { $0 as CoreListItem },
            newSize: step.size,
            newInsets: step.insets,
            scrollTo: step.scrollTo,
            transition: step.transition
        )
        let after = oracle.capture(fixture: fixture)

        oracle.assertBoundary(
            before: before,
            after: after,
            step: step,
            context: "focused"
        )
        oracle.assertWindow(fixture: fixture, context: "focused")
        oracle.assertInstalledAnimations(fixture: fixture, context: "focused")

        _ = fixture.runUntilSettled(max: 2)
        oracle.assertSettled(fixture: fixture, context: "focused")
    }

    func testOracleDetectsMissingInstalledAnimation() {
        let track = ListAnimationTrack(
            generation: 7,
            from: 20,
            to: 0,
            startTime: 1,
            duration: 0.5,
            curve: .linear
        )

        XCTAssertThrowsError(
            try MixedPassStressOracle.validateTrack(
                expected: track,
                animation: nil,
                property: .positionY
            )
        )
    }

    /// Non-vacuity for the clock branch of `validateTrack`. It is the suite's highest-volume model↔CA
    /// assertion, and it now reads metadata rather than `beginTime` — so something has to prove the
    /// branch can still fail, or a replacement could quietly become a tautology.
    func testOracleDetectsAWrongDeclaredTrackClock() throws {
        let track = ListAnimationTrack(generation: 7, from: 20, to: 0,
                                       startTime: 1, duration: 0.5, curve: .linear)
        let animation = CoreAnimationCompiler().animation(for: track, property: .positionY)
        animation.setValue(2.0, forKey: "CoreListAnimation.startTime")

        XCTAssertThrowsError(
            try MixedPassStressOracle.validateTrack(expected: track, animation: animation,
                                                    property: .positionY)
        ) { error in
            XCTAssertEqual(error as? MixedPassOracleError, .wrongClock)
        }
    }

    /// Non-vacuity for the origin-policy branch: an emission that claims `.explicit` must actually
    /// carry a stamp on the phase axis.
    func testOracleDetectsAnOriginThatContradictsItsPolicy() throws {
        let track = ListAnimationTrack(generation: 8, from: 20, to: 0,
                                       startTime: 1, duration: 0.5, curve: .linear)
        let compiler = CoreAnimationCompiler()

        let explicit = compiler.animation(for: track, property: .positionY,
                                          origin: .explicit(track.startTime))
        XCTAssertNoThrow(
            try MixedPassStressOracle.validateTrack(expected: track, animation: explicit,
                                                    property: .positionY)
        )
        explicit.beginTime = 0
        XCTAssertThrowsError(
            try MixedPassStressOracle.validateTrack(expected: track, animation: explicit,
                                                    property: .positionY)
        ) { error in
            XCTAssertEqual(error as? MixedPassOracleError, .wrongOrigin)
        }

        // The `.atCommit` half is deliberately unasserted at stress scale — `beginTime == 0` there is
        // a statement about Core Animation, not CoreList — so a stray stamp on an `.atCommit`
        // emission must NOT be reported by this oracle.
        let implicit = compiler.animation(for: track, property: .positionY)
        implicit.beginTime = 1
        XCTAssertNoThrow(
            try MixedPassStressOracle.validateTrack(expected: track, animation: implicit,
                                                    property: .positionY)
        )
    }

    func testSettlementCheckpointReapsTracksAlreadyPastTheirDeadline() {
        let initial = (0..<20).map {
            MixedPassItem(id: $0, height: 60)
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 800),
            items: initial.map { $0 as CoreListItem },
            emitsCA: true
        )
        fixture.listView.applyChanges(
            items: Array(initial.dropFirst()).map { $0 as CoreListItem },
            transition: .easeInOut(duration: 0.1)
        )
        fixture.clock.advance(by: 0.2)

        XCTAssertFalse(fixture.hasActiveAnimations)
        XCTAssertFalse(fixture.ghostBlocks.isEmpty)

        MixedPassStressOracle().settle(fixture: fixture, max: 1)

        XCTAssertTrue(fixture.ghostBlocks.isEmpty)
        XCTAssertTrue(fixture.crossingCarryIdentities.isEmpty)
    }

    /// A reserving run boundary puts a deliberate gap between consecutive rows. The oracle's
    /// contiguity assertion must account for it, or every stress seed that produces one fails for a
    /// reason that is not a defect.
    func testOracleAcceptsAReservationGap() {
        let items: [CoreListItem] = (0..<20).map { index in
            let group = index / 5
            return AttachedItem(id: index, height: 50,
                                attachedItems: ["date\(group)": FixedHeightAttachment(
                                    label: "g\(group)", height: 30,
                                    placement: .reservesSpace, edge: .top, isFloating: true)])
        }
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        // Precondition: the collection really does reserve, so this is not vacuous.
        XCTAssertTrue(fixture.activeWindow.items.contains { $0.reservedTop > 0 })

        let oracle = MixedPassStressOracle()
        oracle.assertWindow(fixture: fixture, context: "reservation gap")
    }

    func testOracleAssertsAttachmentInvariants() {
        let items: [CoreListItem] = (0..<20).map { index in
            let group = index / 5
            return AttachedItem(id: index, height: 50,
                                attachedItems: ["date\(group)": FixedHeightAttachment(
                                    label: "g\(group)", height: 30,
                                    placement: .overlay, edge: .top, isFloating: true)])
        }
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        let window = fixture.activeWindow
        XCTAssertFalse(window.attachments.isEmpty, "precondition: there must be attachments to check")
        XCTAssertEqual(Set(window.attachments.map(\.serial)).count, window.attachments.count)
        let loaded = window.startIndex..<(window.endIndex + 1)
        for attachment in window.attachments {
            XCTAssertTrue(loaded.contains(attachment.memberRange.lowerBound))
            XCTAssertTrue(loaded.contains(attachment.memberRange.upperBound - 1))
        }

        let oracle = MixedPassStressOracle()
        oracle.assertWindow(fixture: fixture, context: "attachment invariants")
    }
}
