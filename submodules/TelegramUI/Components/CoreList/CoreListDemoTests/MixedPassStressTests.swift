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

    /// The same grammar with every pass anchored by a mode drawn from its own generator
    /// (`MixedPassScenario.nextAnchorMode`), so the preserve modes meet every structural, geometry,
    /// scroll and attachment change under the same invariants.
    func testSeededMixedPassesPreserveGeneralInvariantsUnderEveryAnchorMode() {
        for seed in seeds {
            run(seed: seed, passCount: 32, includesAnchorModes: true)
        }
    }

    /// Non-vacuity guard for the run above: the seeds reach a centred pass, a `.preserveItem` pass on a
    /// row the old window loaded and one that falls back, each without a `scrollTo`, which would win.
    func testTheGrammarActuallyExercisesTheAnchorModes() {
        var sawCentred = false
        var sawLoadedItem = false
        var sawFallback = false

        for seed in seeds {
            var scenario = MixedPassScenario(seed: seed,
                                             itemCount: 120,
                                             includesAttachments: true,
                                             includesAnchorModes: true)
            let fixture = VirtualListFixture(
                viewport: CGSize(width: 390, height: 800),
                items: scenario.makeInitialItems(),
                preloadMargin: 160
            )
            for _ in 0..<32 {
                let step = scenario.nextStep()
                if step.scrollTo == nil {
                    switch step.anchorMode {
                    case .preserveCentredContent:
                        sawCentred = true
                    case let .preserveItem(identity):
                        let isLoaded = fixture.activeWindow.items.contains {
                            fixture.listView.items[$0.index].identity == identity
                        }
                        if isLoaded, step.items.contains(where: { $0.identity == identity }) {
                            sawLoadedItem = true
                        } else {
                            sawFallback = true
                        }
                    case .automatic, .preserveVisibleContent:
                        break
                    }
                }
                fixture.listView.frame.size = step.size
                fixture.listView.applyChanges(
                    items: step.items.map { $0 as CoreListItem },
                    newSize: step.size,
                    newInsets: step.insets,
                    scrollTo: step.scrollTo,
                    anchorMode: step.anchorMode,
                    transition: step.transition
                )
                fixture.flushScheduler()
            }
        }

        XCTAssertTrue(sawCentred, "no seed produced a centred pass")
        XCTAssertTrue(sawLoadedItem, "no seed preserved a loaded row")
        XCTAssertTrue(sawFallback, "no seed fell back from `.preserveItem`")
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

    private func run(seed: UInt64, passCount: Int, includesAnchorModes: Bool = false) {
        var scenario = MixedPassScenario(seed: seed,
                                         itemCount: 120,
                                         includesAttachments: true,
                                         includesAnchorModes: includesAnchorModes)
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
                anchorMode: step.anchorMode,
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
