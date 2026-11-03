import XCTest
@testable import CoreListDemo

final class MixedPassStressTests: XCTestCase {
    private let seeds: [UInt64] = [
        0x0001, 0x0042, 0x0517, 0xC0DE, 0xB10C, 0x5EED,
    ]

    func testSeededMixedPassesPreserveGeneralInvariants() {
        for seed in seeds {
            run(seed: seed, passCount: 32)
        }
    }

    /// Non-vacuity guard. Every assertion in the run above is conditional on the state the grammar
    /// happens to produce, so a grammar that stopped emitting attachments — or a resolver that
    /// stopped resolving them — would leave the suite green while covering nothing. This asserts the
    /// seeds actually reach the shapes attachments exist for.
    func testTheGrammarActuallyExercisesAttachments() {
        var sawReserving = false
        var sawOverlay = false
        var sawRegroup = false
        var sawDrop = false
        var maxAttachments = 0

        for seed in seeds {
            var scenario = MixedPassScenario(seed: seed, itemCount: 120, includesAttachments: true)
            let fixture = VirtualListFixture(
                viewport: CGSize(width: 390, height: 800),
                items: scenario.makeInitialItems(),
                preloadMargin: 160
            )
            for _ in 0..<32 {
                let step = scenario.nextStep()
                for action in step.actions {
                    if case .regroup = action { sawRegroup = true }
                    if case .dropAttachments = action { sawDrop = true }
                }
                fixture.listView.frame.size = step.size
                fixture.listView.applyChanges(
                    items: step.items.map { $0 as CoreListItem },
                    newSize: step.size,
                    newInsets: step.insets,
                    scrollTo: step.scrollTo,
                    transition: step.transition
                )
                fixture.flushScheduler()

                let attachments = fixture.activeWindow.attachments
                maxAttachments = max(maxAttachments, attachments.count)
                sawReserving = sawReserving || attachments.contains { $0.placement == .reservesSpace }
                sawOverlay = sawOverlay || attachments.contains { $0.placement == .overlay }
            }
        }

        XCTAssertGreaterThan(maxAttachments, 0, "the grammar never produced a resolved attachment")
        XCTAssertTrue(sawReserving, "no seed produced a space-reserving attachment")
        XCTAssertTrue(sawOverlay, "no seed produced an overlay attachment")
        XCTAssertTrue(sawRegroup, "no seed regrouped, so runs never split or merged")
        XCTAssertTrue(sawDrop, "no seed dropped attachments, so runs never gained a gap")
    }

    private func run(seed: UInt64, passCount: Int) {
        var scenario = MixedPassScenario(seed: seed, itemCount: 120, includesAttachments: true)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 800),
            items: scenario.makeInitialItems(),
            preloadMargin: 160,
            emitsCA: true
        )
        let oracle = MixedPassStressOracle()

        for pass in 0..<passCount {
            let before = oracle.capture(fixture: fixture)
            let step = scenario.nextStep()
            fixture.listView.frame.size = step.size
            fixture.listView.applyChanges(
                items: step.items.map { $0 as CoreListItem },
                newSize: step.size,
                newInsets: step.insets,
                scrollTo: step.scrollTo,
                transition: step.transition
            )
            fixture.flushScheduler()
            let after = oracle.capture(fixture: fixture)
            let context = failureContext(
                scenario: scenario,
                pass: pass,
                fixture: fixture
            )

            oracle.assertBoundary(
                before: before,
                after: after,
                step: step,
                context: context
            )
            oracle.assertWindow(fixture: fixture, context: context)
            oracle.assertInstalledAnimations(fixture: fixture, context: context)

            if step.advanceAfter > 0 {
                fixture.advance(by: step.advanceAfter)
                oracle.assertWindow(fixture: fixture, context: context)
                oracle.assertInstalledAnimations(fixture: fixture, context: context)
            }

            if (pass + 1).isMultiple(of: 8) {
                oracle.settle(fixture: fixture, max: 2)
                oracle.assertSettled(fixture: fixture, context: context)
            }
        }

        oracle.settle(fixture: fixture, max: 2)
        let context = failureContext(
            scenario: scenario,
            pass: passCount,
            fixture: fixture
        )
        oracle.assertSettled(fixture: fixture, context: context)

        let beforeNoOp = oracle.capture(fixture: fixture)
        fixture.listView.applyChanges(
            items: scenario.items.map { $0 as CoreListItem },
            newSize: scenario.size,
            newInsets: scenario.insets,
            transition: .easeInOut(duration: 0)
        )
        let afterNoOp = oracle.capture(fixture: fixture)
        XCTAssertEqual(beforeNoOp, afterNoOp, context)
        oracle.assertSettled(fixture: fixture, context: context)
    }

    private func failureContext(
        scenario: MixedPassScenario,
        pass: Int,
        fixture: VirtualListFixture
    ) -> String {
        scenario.failureContext(
            pass: pass,
            size: fixture.listView.logicalSize,
            insets: fixture.listView.viewportInsets,
            offset: fixture.boundsOriginY,
            loadedIndices: fixture.loadedIndices,
            crossingIdentities: fixture.listView.crossingCarrySnapshots.map {
                let track = fixture.positionTrack(identity: $0.identity)
                return AnyHashable(
                    "\($0.identity){release=\(String(describing: $0.releaseGeneration)),"
                        + "track=\(String(describing: track))}"
                )
            },
            ghostDescriptions: fixture.ghostBlocks.map {
                String(describing: $0)
            }
        )
    }
}
