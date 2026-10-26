import XCTest
@testable import CoreListDemo

final class DemoInteractionTests: XCTestCase {
    private func descendants(of view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap(descendants(of:))
    }

    private func makeLoadedController() throws
        -> (
            controller: ViewController,
            list: CoreVirtualListView,
            views: [UIView],
            responseScheduler: ManualAutoLoadResponseScheduler
        ) {
        let scheduler = ManualAutoLoadResponseScheduler()
        let controller = ViewController(autoLoadResponseScheduler: scheduler)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()
        let views = descendants(of: controller.view)
        let list = try XCTUnwrap(views.compactMap { $0 as? CoreVirtualListView }.first)
        return (controller, list, views, scheduler)
    }

    private func makeTallLoadedController() throws
        -> (
            controller: ViewController,
            list: CoreVirtualListView,
            views: [UIView],
            responseScheduler: ManualAutoLoadResponseScheduler
        ) {
        let scheduler = ManualAutoLoadResponseScheduler()
        let controller = ViewController(autoLoadResponseScheduler: scheduler)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 2_000)
        controller.view.layoutIfNeeded()
        let views = descendants(of: controller.view)
        let list = try XCTUnwrap(views.compactMap { $0 as? CoreVirtualListView }.first)
        return (controller, list, views, scheduler)
    }

    private func button(titled title: String, in views: [UIView]) throws -> UIButton {
        try XCTUnwrap(views.compactMap { $0 as? UIButton }
            .first(where: { $0.title(for: .normal) == title }))
    }

    private func topBar(in controller: ViewController) throws -> UIStackView {
        try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIStackView }.first)
    }

    private func expectedChromeInsets(for controller: ViewController) throws -> UIEdgeInsets {
        UIEdgeInsets(top: try topBar(in: controller).frame.maxY + 12,
                     left: 0,
                     bottom: controller.view.safeAreaInsets.bottom,
                     right: 0)
    }

    private func settledY(for index: Int, in list: CoreVirtualListView) throws -> CGFloat {
        let item = try XCTUnwrap(list.activeWindow.items.first { $0.index == index })
        return list.containerOriginY + item.frame.minY
            - list.activeWindow.minY - list.engine.offset
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }

    private func formAutoLoadRequest(
        _ scheduler: ManualAutoLoadResponseScheduler
    ) {
        drainMainQueue()
        XCTAssertEqual(scheduler.pendingCount, 1)
    }

    private func deliverAutoLoadResponse(
        _ scheduler: ManualAutoLoadResponseScheduler
    ) {
        formAutoLoadRequest(scheduler)
        scheduler.advance(by: 0.2)
    }

    func testVirtualListDefaultsToPhysicsKeyframeEngine() throws {
        let controller = ViewController()
        controller.loadViewIfNeeded()

        let views = descendants(of: controller.view)
        let list = try XCTUnwrap(views.compactMap { $0 as? CoreVirtualListView }.first)
        let control = try XCTUnwrap(views.compactMap { $0 as? UISegmentedControl }.first)
        XCTAssertEqual(control.selectedSegmentIndex, 2)
        let engine = try XCTUnwrap(list.engine as? PhysicsScrollEngine)
        guard case .keyframe = engine.decelerationMode else {
            return XCTFail("Virtual List must default to keyframe deceleration")
        }
    }

    /// The immediate Del/Add affordance replaces one row while preserving the rest of the list.
    func test_delAddButton_replacesOnlyItsTargetRow() throws {
        let controller = ViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()

        let views = descendants(of: controller.view)
        let list = try XCTUnwrap(views.compactMap { $0 as? CoreVirtualListView }.first)
        let button = try XCTUnwrap(views.compactMap { $0 as? UIButton }
            .first(where: { $0.title(for: .normal) == "Del/Add" }))
        let idsBefore = list.items.compactMap { ($0 as? DemoListItem)?.id }

        button.sendActions(for: .touchUpInside)

        let idsAfter = list.items.compactMap { ($0 as? DemoListItem)?.id }
        XCTAssertEqual(idsAfter.count, idsBefore.count, "replacement must preserve the item count")
        XCTAssertNotEqual(idsAfter[5], idsBefore[5], "the row at the Del/Add slot must get a fresh identity")
        for index in idsBefore.indices where index != 5 {
            XCTAssertEqual(idsAfter[index], idsBefore[index], "Del/Add changed unrelated row \(index)")
        }
    }

    func test_addTopButton_insertsFreshItemAtFirstIndex() throws {
        let controller = ViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()

        let views = descendants(of: controller.view)
        let list = try XCTUnwrap(views.compactMap { $0 as? CoreVirtualListView }.first)
        let button = try XCTUnwrap(views.compactMap { $0 as? UIButton }
            .first(where: { $0.title(for: .normal) == "+top" }))
        let idsBefore = list.items.compactMap { ($0 as? DemoListItem)?.id }

        button.sendActions(for: .touchUpInside)

        let idsAfter = list.items.compactMap { ($0 as? DemoListItem)?.id }
        XCTAssertEqual(idsAfter.count, idsBefore.count + 1)
        XCTAssertFalse(idsBefore.contains(idsAfter[0]), "the top row must have a fresh identity")
        XCTAssertEqual(Array(idsAfter.dropFirst()), idsBefore, "existing rows must retain their order")
    }

    func testMixedVerticalInsetJumpTogglesInsetAndScrollsInOnePass() throws {
        let fixture = try makeLoadedController()
        let baseline = try expectedChromeInsets(for: fixture.controller)
        let mixedButton = try button(titled: "V+300 + Jump40", in: fixture.views)
        let insetButton = try button(titled: "Inset +300", in: fixture.views)

        mixedButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(fixture.list.viewportGeometry.insets.top, baseline.top + 300)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.bottom, baseline.bottom)
        XCTAssertEqual(try settledY(for: 40, in: fixture.list),
                       baseline.top + 300, accuracy: 1e-6)
        XCTAssertEqual(mixedButton.title(for: .normal), "V-300 + Jump40")
        XCTAssertEqual(insetButton.title(for: .normal), "Inset -300")
        let firstTrack = try XCTUnwrap(
            fixture.list.animationController.model.track(
                for: .viewport, property: .viewportOffset
            )
        )
        XCTAssertEqual(firstTrack.duration,
                       0.5 * UIView.animationDurationFactor,
                       accuracy: 1e-9)
        XCTAssertEqual(firstTrack.curve, .easeInOut)

        mixedButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(fixture.list.viewportGeometry.insets, baseline)
        XCTAssertEqual(try settledY(for: 40, in: fixture.list),
                       baseline.top, accuracy: 1e-6)
        XCTAssertEqual(mixedButton.title(for: .normal), "V+300 + Jump40")
        XCTAssertEqual(insetButton.title(for: .normal), "Inset +300")
    }

    func testMixedHorizontalInsetDelAddTogglesGeometryAndReplacesOneIdentity() throws {
        let fixture = try makeLoadedController()
        let baseline = try expectedChromeInsets(for: fixture.controller)
        let button = try button(titled: "H+40/50 + Del/Add", in: fixture.views)
        let overlay = try XCTUnwrap(fixture.views.first {
            $0.accessibilityIdentifier == "InsetRectOverlay"
        })
        let before = fixture.list.items.map(\.identity)

        button.sendActions(for: .touchUpInside)

        let afterAdd = fixture.list.items.map(\.identity)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.left, 40)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.right, 50)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.top, baseline.top)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.bottom, baseline.bottom)
        XCTAssertEqual(overlay.frame,
                       fixture.controller.view.bounds.inset(
                           by: fixture.list.viewportGeometry.insets
                       ))
        XCTAssertEqual(afterAdd.count, before.count)
        XCTAssertNotEqual(afterAdd[5], before[5])
        for index in before.indices where index != 5 {
            XCTAssertEqual(afterAdd[index], before[index])
        }
        XCTAssertEqual(button.title(for: .normal), "H-40/50 + Del/Add")

        button.sendActions(for: .touchUpInside)

        XCTAssertEqual(fixture.list.viewportGeometry.insets.left, 0)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.right, 0)
        XCTAssertEqual(fixture.list.viewportGeometry.insets, baseline)
        XCTAssertEqual(overlay.frame,
                       fixture.controller.view.bounds.inset(by: baseline))
        XCTAssertNotEqual(fixture.list.items[5].identity, afterAdd[5])
        XCTAssertEqual(button.title(for: .normal), "H+40/50 + Del/Add")
    }

    func testMixedFirstSizeSwapTogglesHeightAndIdentityMove() throws {
        let fixture = try makeLoadedController()
        let button = try button(titled: "Size200 + Swap", in: fixture.views)
        let before = fixture.list.items.compactMap { $0 as? DemoListItem }

        button.sendActions(for: .touchUpInside)

        let afterAdd = fixture.list.items.compactMap { $0 as? DemoListItem }
        XCTAssertEqual(afterAdd[0].id, before[0].id)
        XCTAssertEqual(afterAdd[0].minHeight, 200)
        XCTAssertEqual(afterAdd[1].id, before[4].id)
        XCTAssertEqual(afterAdd[4].id, before[1].id)
        XCTAssertEqual(button.title(for: .normal), "Size0 + Swap")

        button.sendActions(for: .touchUpInside)

        let restored = fixture.list.items.compactMap { $0 as? DemoListItem }
        XCTAssertEqual(restored.map(\.id), before.map(\.id))
        XCTAssertEqual(restored[0].minHeight, 0)
        XCTAssertEqual(button.title(for: .normal), "Size200 + Swap")
    }

    func testMixedHorizontalSizeFiveAlternatesExactInsertedIdentities() throws {
        let fixture = try makeLoadedController()
        let baseline = try expectedChromeInsets(for: fixture.controller)
        let button = try button(titled: "H+Size+5", in: fixture.views)
        let before = fixture.list.items.compactMap { $0 as? DemoListItem }
        let beforeIDs = Set(before.map(\.id))

        button.sendActions(for: .touchUpInside)

        let afterAdd = fixture.list.items.compactMap { $0 as? DemoListItem }
        let inserted = Set(afterAdd.map(\.id)).subtracting(beforeIDs)
        XCTAssertEqual(inserted.count, 5)
        XCTAssertEqual(afterAdd.count, before.count + 5)
        XCTAssertEqual(afterAdd[0].id, before[0].id)
        XCTAssertEqual(afterAdd[0].minHeight, 200)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.left, 40)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.right, 50)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.top, baseline.top)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.bottom, baseline.bottom)
        XCTAssertEqual(button.title(for: .normal), "H-Size-5")

        button.sendActions(for: .touchUpInside)

        let restored = fixture.list.items.compactMap { $0 as? DemoListItem }
        XCTAssertEqual(restored.map(\.id), before.map(\.id))
        XCTAssertEqual(restored[0].minHeight, 0)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.left, 0)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.right, 0)
        XCTAssertEqual(fixture.list.viewportGeometry.insets, baseline)
        XCTAssertEqual(button.title(for: .normal), "H+Size+5")
    }

    func testMixedFiveRemovalIgnoresTrackedIdentityAlreadyDeletedElsewhere() throws {
        let fixture = try makeLoadedController()
        let mixed = try button(titled: "H+Size+5", in: fixture.views)
        let minusOne = try button(titled: "-1", in: fixture.views)
        let before = fixture.list.items.map(\.identity)

        mixed.sendActions(for: .touchUpInside)
        minusOne.sendActions(for: .touchUpInside)
        mixed.sendActions(for: .touchUpInside)

        XCTAssertEqual(fixture.list.items.map(\.identity), before)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.left, 0)
        XCTAssertEqual(fixture.list.viewportGeometry.insets.right, 0)
        XCTAssertEqual(try XCTUnwrap(fixture.list.items[0] as? DemoListItem).minHeight, 0)
    }

    func testInsetButtonTogglesTopInsetAndRestoresIt() throws {
        let controller = ViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()

        let views = descendants(of: controller.view)
        let list = try XCTUnwrap(views.compactMap { $0 as? CoreVirtualListView }.first)
        let baseline = try expectedChromeInsets(for: controller)
        let button = try XCTUnwrap(views.compactMap { $0 as? UIButton }
            .first(where: { $0.title(for: .normal) == "Inset +300" }))

        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(list.viewportGeometry.insets.top, baseline.top + 300)
        XCTAssertEqual(list.viewportGeometry.insets.bottom, baseline.bottom)
        XCTAssertEqual(button.title(for: .normal), "Inset -300")

        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(list.viewportGeometry.insets, baseline)
        XCTAssertEqual(button.title(for: .normal), "Inset +300")
    }

    func testInsetRectOverlayTracksAllReceivedInsets() throws {
        let controller = ViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()

        let views = descendants(of: controller.view)
        let list = try XCTUnwrap(views.compactMap { $0 as? CoreVirtualListView }.first)
        let overlay = try XCTUnwrap(views.first {
            $0.accessibilityIdentifier == "InsetRectOverlay"
        })
        let button = try XCTUnwrap(views.compactMap { $0 as? UIButton }
            .first(where: { $0.title(for: .normal) == "Inset +300" }))

        XCTAssertEqual(overlay.frame,
                       controller.view.bounds.inset(by: list.viewportGeometry.insets))
        XCTAssertFalse(overlay.isUserInteractionEnabled)
        XCTAssertGreaterThan(
            try XCTUnwrap(controller.view.subviews.firstIndex { $0 === overlay }),
            try XCTUnwrap(controller.view.subviews.firstIndex { $0 === list })
        )

        button.sendActions(for: .touchUpInside)
        controller.view.layoutIfNeeded()

        XCTAssertEqual(overlay.frame,
                       controller.view.bounds.inset(by: list.viewportGeometry.insets))
    }

    func testListOuterBoundsOverlayTracksReceivedListFrame() throws {
        let fixture = try makeLoadedController()
        let chrome = try expectedChromeInsets(for: fixture.controller)
        let overlay = try XCTUnwrap(fixture.views.first {
            $0.accessibilityIdentifier == "ListOuterBoundsOverlay"
        })
        let insetOverlay = try XCTUnwrap(fixture.views.first {
            $0.accessibilityIdentifier == "InsetRectOverlay"
        })

        XCTAssertEqual(fixture.list.frame, fixture.controller.view.bounds)
        XCTAssertEqual(overlay.frame, fixture.controller.view.bounds)
        XCTAssertEqual(fixture.list.viewportGeometry.insets, chrome)
        XCTAssertEqual(overlay.backgroundColor, .clear)
        XCTAssertFalse(overlay.isUserInteractionEnabled)
        XCTAssertEqual(overlay.layer.borderWidth, 2)
        XCTAssertEqual(overlay.layer.borderColor, UIColor.systemBlue.cgColor)
        XCTAssertGreaterThan(
            try XCTUnwrap(fixture.controller.view.subviews.firstIndex { $0 === overlay }),
            try XCTUnwrap(fixture.controller.view.subviews.firstIndex { $0 === fixture.list })
        )
        XCTAssertGreaterThan(
            try XCTUnwrap(fixture.controller.view.subviews.firstIndex { $0 === insetOverlay }),
            try XCTUnwrap(fixture.controller.view.subviews.firstIndex { $0 === overlay })
        )

        fixture.controller.view.frame.size.height = 780
        fixture.controller.view.setNeedsLayout()
        fixture.controller.view.layoutIfNeeded()

        let resizedChrome = try expectedChromeInsets(for: fixture.controller)
        XCTAssertEqual(fixture.list.frame, fixture.controller.view.bounds)
        XCTAssertEqual(overlay.frame, fixture.controller.view.bounds)
        XCTAssertEqual(fixture.list.viewportGeometry.insets, resizedChrome)
    }

    func testStandaloneTopAndJumpTargetEffectiveTopInset() throws {
        let fixture = try makeLoadedController()
        let jump = try button(titled: "Jump to 40", in: fixture.views)
        let top = try button(titled: "Top", in: fixture.views)
        let targetY = fixture.list.viewportGeometry.insets.top

        jump.sendActions(for: .touchUpInside)
        XCTAssertEqual(try settledY(for: 40, in: fixture.list), targetY, accuracy: 1e-6)

        top.sendActions(for: .touchUpInside)
        XCTAssertEqual(try settledY(for: 0, in: fixture.list), targetY, accuracy: 1e-6)
    }

    func testEngineRebuildPreservesFullScreenGeometryAndInsets() throws {
        let fixture = try makeLoadedController()
        let control = try XCTUnwrap(
            fixture.views.compactMap { $0 as? UISegmentedControl }.first
        )
        let expectedInsets = fixture.list.viewportGeometry.insets

        control.selectedSegmentIndex = 0
        control.sendActions(for: .valueChanged)
        fixture.controller.view.layoutIfNeeded()

        let replacement = try XCTUnwrap(
            descendants(of: fixture.controller.view)
                .compactMap { $0 as? CoreVirtualListView }.first
        )
        XCTAssertEqual(replacement.frame, fixture.controller.view.bounds)
        XCTAssertEqual(replacement.viewportGeometry.insets, expectedInsets)
    }

    func testLoadButtonsPrependAndRemoveFiveWhilePreservingSettledAnchor() throws {
        let fixture = try makeLoadedController()
        fixture.list.applyChanges(
            scrollTo: .init(index: 40, pointOffset: -20),
            transition: .easeInOut(duration: 0)
        )
        let witness = fixture.list.items[40].identity
        let oldY = try settledY(for: 40, in: fixture.list)
        let load = try button(titled: "Load +5", in: fixture.views)
        let unload = try button(titled: "Load -5", in: fixture.views)
        let before = fixture.list.items.map(\.identity)

        load.sendActions(for: .touchUpInside)

        XCTAssertEqual(fixture.list.items.count, before.count + 5)
        XCTAssertEqual(Array(fixture.list.items.dropFirst(5).map(\.identity)), before)
        let loadedWitnessIndex = try XCTUnwrap(
            fixture.list.items.firstIndex { $0.identity == witness }
        )
        XCTAssertEqual(
            try settledY(for: loadedWitnessIndex, in: fixture.list),
            oldY,
            accuracy: 1e-6
        )

        unload.sendActions(for: .touchUpInside)

        XCTAssertEqual(fixture.list.items.map(\.identity), before)
        let restoredWitnessIndex = try XCTUnwrap(
            fixture.list.items.firstIndex { $0.identity == witness }
        )
        XCTAssertEqual(
            try settledY(for: restoredWitnessIndex, in: fixture.list),
            oldY,
            accuracy: 1e-6
        )
    }

    func testAutoLoadDefaultsOffAndEnablingAtLaunchPrependsFiveWithoutAnimation() throws {
        let fixture = try makeLoadedController()
        let button = try button(titled: "Auto Load", in: fixture.views)
        let before = fixture.list.items.map(\.identity)
        let witness = before[0]
        let oldY = try settledY(for: 0, in: fixture.list)

        XCTAssertNil(fixture.list.animationController.model.track(
            for: .viewport, property: .viewportOffset
        ))

        button.sendActions(for: .touchUpInside)
        drainMainQueue()
        XCTAssertEqual(fixture.responseScheduler.pendingCount, 1)
        XCTAssertEqual(fixture.list.items.map(\.identity), before)

        fixture.responseScheduler.advance(by: 0.199)
        XCTAssertEqual(fixture.list.items.map(\.identity), before)

        fixture.responseScheduler.advance(by: 0.001)

        XCTAssertEqual(button.title(for: .normal), "Stop Load")
        XCTAssertEqual(fixture.list.items.count, before.count + 5)
        XCTAssertEqual(Array(fixture.list.items.dropFirst(5).map(\.identity)), before)
        let witnessIndex = try XCTUnwrap(
            fixture.list.items.firstIndex { $0.identity == witness }
        )
        XCTAssertEqual(
            try settledY(for: witnessIndex, in: fixture.list),
            oldY,
            accuracy: 1e-6
        )
        XCTAssertFalse(fixture.list.animationController.hasActiveAnimations(
            at: fixture.list.animationController.now()
        ))
    }

    func testAutoLoadAppendsFiveAtBottom() throws {
        let fixture = try makeLoadedController()
        let button = try button(titled: "Auto Load", in: fixture.views)
        button.sendActions(for: .touchUpInside)
        deliverAutoLoadResponse(fixture.responseScheduler)
        let before = fixture.list.items.map(\.identity)

        fixture.list.applyChanges(
            scrollTo: .init(index: fixture.list.items.count - 1, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        deliverAutoLoadResponse(fixture.responseScheduler)

        XCTAssertEqual(fixture.list.items.count, before.count + 5)
        XCTAssertEqual(
            Array(fixture.list.items.prefix(before.count).map(\.identity)),
            before
        )
    }

    func testDisablingAutoLoadSuppressesQueuedAndFutureLoads() throws {
        let fixture = try makeLoadedController()
        let button = try button(titled: "Auto Load", in: fixture.views)
        let beforeCount = fixture.list.items.count
        button.sendActions(for: .touchUpInside)
        formAutoLoadRequest(fixture.responseScheduler)
        button.sendActions(for: .touchUpInside)
        fixture.responseScheduler.advance(by: 0.2)

        fixture.list.applyChanges(
            scrollTo: .init(index: fixture.list.items.count - 1, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        drainMainQueue()

        XCTAssertEqual(button.title(for: .normal), "Auto Load")
        XCTAssertEqual(fixture.responseScheduler.pendingCount, 0)
        XCTAssertEqual(fixture.list.items.count, beforeCount)
    }

    func testAutoLoadAtBothEdgesAddsFiveOnEachSide() throws {
        let fixture = try makeLoadedController()
        fixture.list.items = Array(fixture.list.items.prefix(1))
        let original = try XCTUnwrap(fixture.list.items.first?.identity)
        let button = try button(titled: "Auto Load", in: fixture.views)

        button.sendActions(for: .touchUpInside)
        deliverAutoLoadResponse(fixture.responseScheduler)

        XCTAssertEqual(fixture.list.items.count, 11)
        XCTAssertEqual(fixture.list.items[5].identity, original)
    }

    func testAutoLoadContinuesUntilBothEdgesClear() throws {
        let fixture = try makeTallLoadedController()
        fixture.list.items = Array(fixture.list.items.prefix(1))
        let button = try button(titled: "Auto Load", in: fixture.views)

        button.sendActions(for: .touchUpInside)
        deliverAutoLoadResponse(fixture.responseScheduler)

        XCTAssertEqual(fixture.list.items.count, 11)
        XCTAssertEqual(fixture.list.reachedLoadedEdges, [.top, .bottom])

        var turns = 0
        while !fixture.list.reachedLoadedEdges.isEmpty, turns < 10 {
            deliverAutoLoadResponse(fixture.responseScheduler)
            turns += 1
        }

        XCTAssertGreaterThan(fixture.list.items.count, 11)
        XCTAssertTrue(fixture.list.reachedLoadedEdges.isEmpty)
        XCTAssertLessThan(turns, 10)
    }

    func testDisablingAutoLoadCancelsRemainingContinuation() throws {
        let fixture = try makeTallLoadedController()
        fixture.list.items = Array(fixture.list.items.prefix(1))
        let button = try button(titled: "Auto Load", in: fixture.views)

        button.sendActions(for: .touchUpInside)
        deliverAutoLoadResponse(fixture.responseScheduler)
        let countAfterFirstBatch = fixture.list.items.count
        XCTAssertEqual(countAfterFirstBatch, 11)
        XCTAssertFalse(fixture.list.reachedLoadedEdges.isEmpty)

        button.sendActions(for: .touchUpInside)
        drainMainQueue()
        drainMainQueue()

        XCTAssertEqual(button.title(for: .normal), "Auto Load")
        XCTAssertEqual(fixture.list.items.count, countAfterFirstBatch)
    }

    func testEngineSwitchKeepsAutoLoadEnabledAndReevaluatesTop() throws {
        let fixture = try makeLoadedController()
        let button = try button(titled: "Auto Load", in: fixture.views)
        button.sendActions(for: .touchUpInside)
        formAutoLoadRequest(fixture.responseScheduler)
        let control = try XCTUnwrap(
            descendants(of: fixture.controller.view)
                .compactMap { $0 as? UISegmentedControl }.first
        )

        control.selectedSegmentIndex = 0
        control.sendActions(for: .valueChanged)
        drainMainQueue()
        XCTAssertEqual(fixture.responseScheduler.pendingCount, 1)

        let views = descendants(of: fixture.controller.view)
        let replacement = try XCTUnwrap(
            views.compactMap { $0 as? CoreVirtualListView }.first
        )
        fixture.responseScheduler.advance(by: 0.2)
        XCTAssertEqual(button.title(for: .normal), "Stop Load")
        XCTAssertEqual(replacement.items.count, DemoListItem.makeItems().count + 5)
    }

    func testAutoLoadDeduplicatesRepeatedTopArrivalWhileResponseIsInFlight() throws {
        let fixture = try makeLoadedController()
        let button = try button(titled: "Auto Load", in: fixture.views)
        let beforeCount = fixture.list.items.count

        button.sendActions(for: .touchUpInside)
        formAutoLoadRequest(fixture.responseScheduler)

        fixture.list.applyChanges(
            scrollTo: .init(index: 20, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        fixture.list.applyChanges(
            scrollTo: .init(index: 0, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        drainMainQueue()

        XCTAssertEqual(fixture.responseScheduler.pendingCount, 1)
        fixture.responseScheduler.advance(by: 0.2)
        XCTAssertEqual(fixture.list.items.count, beforeCount + 5)
        XCTAssertEqual(fixture.responseScheduler.pendingCount, 0)
    }

    func testAcceptedAutoLoadResponseAppliesAfterLeavingEdge() throws {
        let fixture = try makeLoadedController()
        let button = try button(titled: "Auto Load", in: fixture.views)
        let before = fixture.list.items.map(\.identity)

        button.sendActions(for: .touchUpInside)
        formAutoLoadRequest(fixture.responseScheduler)
        fixture.list.applyChanges(
            scrollTo: .init(index: 20, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )

        fixture.responseScheduler.advance(by: 0.2)

        XCTAssertEqual(
            Array(fixture.list.items.dropFirst(5).map(\.identity)),
            before
        )
    }

    func testLoadMinusFiveKeepsCollectionNonempty() throws {
        let fixture = try makeLoadedController()
        let unload = try button(titled: "Load -5", in: fixture.views)
        fixture.list.applyChanges(
            items: Array(fixture.list.items.prefix(4)),
            transition: .easeInOut(duration: 0)
        )

        unload.sendActions(for: .touchUpInside)
        unload.sendActions(for: .touchUpInside)

        XCTAssertEqual(fixture.list.items.count, 1)
    }
}
