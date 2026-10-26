import XCTest
@testable import CoreListDemo

final class CoreVirtualListCoreTests: XCTestCase {
    private func items(_ ids: [Int], height: CGFloat = 50) -> [CoreListItem] {
        ids.map {
            IdentifiableFixedHeightItem(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))!,
                height: height
            )
        }
    }

    private func settledScreenY(_ listView: CoreVirtualListView, index: Int) -> CGFloat? {
        guard let item = listView.activeWindow.items.first(where: { $0.index == index }) else {
            return nil
        }
        return listView.containerOriginY
            + item.frame.minY - listView.activeWindow.minY
            - listView.engine.offset
    }

    private func viewByIdentity(_ listView: CoreVirtualListView) -> [AnyHashable: UIView] {
        Dictionary(uniqueKeysWithValues: listView.activeWindow.items.map {
            (listView.items[$0.index].identity, $0.view)
        })
    }

    func test_initialWindowFill_buildsSettledContiguousWindow() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: items(Array(0..<20)),
            preloadMargin: 0
        )

        XCTAssertEqual(fixture.activeWindow.items.map(\.index), [0, 1, 2, 3])
        XCTAssertEqual(fixture.listView.engine.offset, 0, accuracy: 0.001)
        for index in 0..<4 {
            XCTAssertEqual(settledScreenY(fixture.listView, index: index)!, CGFloat(index * 50), accuracy: 0.001)
        }
        XCTAssertEqual(Set(viewByIdentity(fixture.listView).keys).count, 4)
    }

    func test_duplicateIdentityValidation_findsThePairUsedByThePrecondition() throws {
        let id = UUID()
        let duplicate: [CoreListItem] = [
            IdentifiableFixedHeightItem(id: id, height: 50),
            IdentifiableFixedHeightItem(id: id, height: 80),
        ]

        let pair = try XCTUnwrap(CoreVirtualListView.firstDuplicatePair(in: duplicate))
        XCTAssertEqual(pair.first, 0)
        XCTAssertEqual(pair.second, 1)
        XCTAssertNil(CoreVirtualListView.firstDuplicatePair(in: items([0, 1])))
    }

    func test_noChangeIdentityDiff_preservesWindowViewsOffsetAndFrames() {
        let source = items(Array(0..<20))
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: source,
            preloadMargin: 0
        )
        let beforeViews = viewByIdentity(fixture.listView)
        let beforeFrames = fixture.activeWindow.items.map(\.frame)
        let beforeOffset = fixture.listView.engine.offset

        let diff = CoreVirtualListView.computeDiff(old: source, new: source)
        fixture.listView.applyChanges(items: source, transition: .easeInOut(duration: 0))

        XCTAssertEqual(diff.survivorMap.count, source.count)
        XCTAssertTrue(diff.deletes.isEmpty)
        XCTAssertTrue(diff.inserts.isEmpty)
        XCTAssertTrue(diff.moves.isEmpty)
        XCTAssertEqual(fixture.listView.engine.offset, beforeOffset, accuracy: 0.001)
        XCTAssertEqual(fixture.activeWindow.items.map(\.frame), beforeFrames)
        for (identity, view) in beforeViews {
            XCTAssertTrue(viewByIdentity(fixture.listView)[identity] === view)
        }
    }

    func test_middleInsertAndDelete_settleFinalFramesAndReuseSurvivors() {
        let source = items(Array(0..<20))
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: source,
            preloadMargin: 0
        )
        let oldViews = viewByIdentity(fixture.listView)
        let oldOffset = fixture.listView.engine.offset

        var inserted = source
        inserted.insert(items([999])[0], at: 3)
        fixture.listView.applyChanges(items: inserted, transition: .easeInOut(duration: 0))

        XCTAssertEqual(fixture.listView.engine.offset, oldOffset, accuracy: 0.001)
        XCTAssertEqual(settledScreenY(fixture.listView, index: 3)!, 150, accuracy: 0.001)
        XCTAssertEqual(settledScreenY(fixture.listView, index: 4)!, 200, accuracy: 0.001)
        XCTAssertTrue(viewByIdentity(fixture.listView)[source[3].identity] === oldViews[source[3].identity])

        inserted.remove(at: 3)
        fixture.listView.applyChanges(items: inserted, transition: .easeInOut(duration: 0))

        XCTAssertEqual(fixture.listView.engine.offset, oldOffset, accuracy: 0.001)
        XCTAssertEqual(settledScreenY(fixture.listView, index: 3)!, 150, accuracy: 0.001)
        XCTAssertTrue(viewByIdentity(fixture.listView)[source[3].identity] === oldViews[source[3].identity])
    }

    func test_LISMovePairing_reusesMovedViewAtSettledSlot() {
        let source = items(Array(0..<10))
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 500),
            items: source,
            preloadMargin: 0
        )
        let movedIdentity = source[2].identity
        let movedView = viewByIdentity(fixture.listView)[movedIdentity]

        var reordered = source
        let moved = reordered.remove(at: 2)
        reordered.insert(moved, at: 5)
        let diff = CoreVirtualListView.computeDiff(old: source, new: reordered)
        fixture.listView.applyChanges(items: reordered, transition: .easeInOut(duration: 0))

        XCTAssertEqual(diff.moves.count, 1)
        XCTAssertEqual(diff.moves.first?.old, 2)
        XCTAssertEqual(diff.moves.first?.new, 5)
        XCTAssertTrue(viewByIdentity(fixture.listView)[movedIdentity] === movedView)
        XCTAssertEqual(settledScreenY(fixture.listView, index: 5)!, 250, accuracy: 0.001)
        XCTAssertEqual(fixture.listView.engine.offset, 0, accuracy: 0.001)
    }

    func test_scrollToAnchor_settlesAtRequestedPosition() {
        let fixture = VirtualListFixture(items: items(Array(0..<200)))
        let oldViews = viewByIdentity(fixture.listView)

        fixture.listView.applyChanges(
            scrollTo: .init(index: 100, pointOffset: 200),
            transition: .easeInOut(duration: 0)
        )

        XCTAssertTrue(fixture.activeWindow.contains(index: 100))
        XCTAssertEqual(settledScreenY(fixture.listView, index: 100)!, 200, accuracy: 0.001)
        XCTAssertTrue(fixture.listView.engine.offset.isFinite)
        for (identity, view) in oldViews where viewByIdentity(fixture.listView)[identity] != nil {
            XCTAssertTrue(viewByIdentity(fixture.listView)[identity] === view)
        }
    }

    func test_loadedTopAndBottomEdges_clampAfterImmediateDeletes() {
        let source = items(Array(0..<50))
        let top = VirtualListFixture(items: source)
        var withoutFirst = source
        withoutFirst.removeFirst()
        top.listView.applyChanges(items: withoutFirst, transition: .easeInOut(duration: 0))

        XCTAssertEqual(top.activeWindow.startIndex, 0)
        XCTAssertEqual(top.listView.engine.offset, 0, accuracy: 0.001)
        XCTAssertEqual(settledScreenY(top.listView, index: 0)!, 0, accuracy: 0.001)

        let bottom = VirtualListFixture(items: source)
        bottom.listView.applyChanges(
            scrollTo: .init(index: 49, pointOffset: 750),
            transition: .easeInOut(duration: 0)
        )
        let lastIdentity = source[48].identity
        let lastView = viewByIdentity(bottom.listView)[lastIdentity]
        var withoutLast = source
        withoutLast.removeLast()
        bottom.listView.applyChanges(items: withoutLast, transition: .easeInOut(duration: 0))

        XCTAssertEqual(bottom.activeWindow.endIndex, 48)
        XCTAssertEqual(settledScreenY(bottom.listView, index: 48)! + 50, 800, accuracy: 0.001)
        XCTAssertTrue(viewByIdentity(bottom.listView)[lastIdentity] === lastView)
        XCTAssertTrue(bottom.listView.engine.offset.isFinite)
    }

    func test_widthDependentRemeasure_preservesAnchorAndViewIdentity() {
        let ids = (0..<30).map { _ in UUID() }
        let source: [CoreListItem] = ids.map {
            IdentifiableWidthDependentItem(id: $0, baseHeight: 50, baseWidth: 390)
        }
        let fixture = VirtualListFixture(items: source)
        let firstIdentity = source[0].identity
        let firstView = viewByIdentity(fixture.listView)[firstIdentity]
        let oldOffset = fixture.listView.engine.offset

        fixture.listView.applyChanges(
            newSize: CGSize(width: 195, height: 800),
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(fixture.activeWindow.localFrame(for: 0)!.height, 100, accuracy: 0.001)
        XCTAssertEqual(settledScreenY(fixture.listView, index: 0)!, 0, accuracy: 0.001)
        XCTAssertEqual(fixture.listView.engine.offset, oldOffset, accuracy: 0.001)
        XCTAssertTrue(viewByIdentity(fixture.listView)[firstIdentity] === firstView)
    }

    func test_contentReconciliation_reusesTheSameViewAndSettlesNewHeight() {
        let ids = (0..<8).map { _ in UUID() }
        var source: [CoreListItem] = ids.map { ContentResizableItem(id: $0, contentHeight: 50) }
        let fixture = VirtualListFixture(items: source)
        let identity = source[2].identity
        let view = viewByIdentity(fixture.listView)[identity] as! ContentResizableItemView
        view.addBonus(30)
        let oldOffset = fixture.listView.engine.offset

        source[2] = ContentResizableItem(id: ids[2], contentHeight: 90)
        fixture.listView.applyChanges(items: source, transition: .easeInOut(duration: 0))

        XCTAssertTrue(viewByIdentity(fixture.listView)[identity] === view)
        XCTAssertEqual(view.applyCount, 2)
        XCTAssertEqual(fixture.activeWindow.localFrame(for: 2)!.height, 120, accuracy: 0.001)
        XCTAssertEqual(settledScreenY(fixture.listView, index: 3)!, 220, accuracy: 0.001)
        XCTAssertEqual(fixture.listView.engine.offset, oldOffset, accuracy: 0.001)
    }

    func test_dirtyUpdates_coalesceAndSettleBothFrames() {
        let ids = (0..<2).map { _ in UUID() }
        let source: [CoreListItem] = ids.map { SelfUpdatingItem(id: $0, initialHeight: 50) }
            + items(Array(2..<30))
        let fixture = VirtualListFixture(items: source)
        let beforeViews = viewByIdentity(fixture.listView)
        let oldOffset = fixture.listView.engine.offset
        let first = fixture.activeWindow.items[0].view as! SelfUpdatingItemView
        let second = fixture.activeWindow.items[1].view as! SelfUpdatingItemView

        first.simulateContentChange(newHeight: 70, animated: false)
        second.simulateContentChange(newHeight: 80, animated: false)

        XCTAssertEqual(fixture.scheduler.pending.count, 1)
        fixture.flushScheduler()
        XCTAssertEqual(fixture.scheduler.pending.count, 0)
        XCTAssertEqual(fixture.activeWindow.localFrame(for: 0)!.height, 70, accuracy: 0.001)
        XCTAssertEqual(fixture.activeWindow.localFrame(for: 1)!.height, 80, accuracy: 0.001)
        XCTAssertEqual(settledScreenY(fixture.listView, index: 2)!, 150, accuracy: 0.001)
        XCTAssertEqual(fixture.listView.engine.offset, oldOffset, accuracy: 0.001)
        XCTAssertTrue(viewByIdentity(fixture.listView)[source[0].identity] === beforeViews[source[0].identity])
    }

    func test_userScroll_rebalancesWindowAndPreservesOverlappingViews() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: items(Array(0..<100)),
            preloadMargin: 0
        )
        let before = viewByIdentity(fixture.listView)
        let beforeRange = fixture.activeWindow.startIndex...fixture.activeWindow.endIndex

        fixture.scrollView.bounds.origin.y = 150
        fixture.fireScroll()

        XCTAssertNotEqual(fixture.activeWindow.startIndex...fixture.activeWindow.endIndex, beforeRange)
        XCTAssertEqual(fixture.listView.engine.offset, fixture.scrollView.bounds.origin.y, accuracy: 0.001)
        XCTAssertTrue(fixture.activeWindow.items.allSatisfy { settledScreenY(fixture.listView, index: $0.index) != nil })
        for (identity, view) in before where viewByIdentity(fixture.listView)[identity] != nil {
            XCTAssertTrue(viewByIdentity(fixture.listView)[identity] === view)
        }
    }

    func test_applyDrivenReload_rebindsRemainingControllerTrack() {
        let source = items(Array(0..<100))
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: source,
            preloadMargin: 0,
            emitsCA: true
        )
        let identity = source[0].identity
        let oldView = fixture.activeWindow.items.first(where: { $0.index == 0 })!.view
        fixture.animationController.transitionPosition(
            identity: identity,
            layer: oldView.layer,
            oldSettledY: 0,
            newSettledY: 100,
            transition: .easeInOut(duration: 1)
        )

        fixture.listView.applyChanges(
            scrollTo: .init(index: 50, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        fixture.advance(by: 0.25)
        fixture.listView.applyChanges(
            scrollTo: .init(index: 0, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )

        let reboundView = fixture.activeWindow.items.first(where: { $0.index == 0 })!.view
        XCTAssertFalse(reboundView === oldView)
        XCTAssertNotNil(reboundView.layer.animation(forKey: "CoreListAnimation.positionY"))
        XCTAssertNotNil(fixture.animationController.positionOffset(identity: identity,
                                                                    at: fixture.clock.now))
    }

    func test_noChangeApply_doesNotReinstallExistingControllerTrack() throws {
        let source = items(Array(0..<20))
        let fixture = VirtualListFixture(items: source, emitsCA: true)
        let identity = source[0].identity
        let view = fixture.activeWindow.items.first(where: { $0.index == 0 })!.view
        fixture.animationController.transitionPosition(
            identity: identity,
            layer: view.layer,
            oldSettledY: 0,
            newSettledY: 100,
            transition: .easeInOut(duration: 1)
        )
        let key = "CoreListAnimation.positionY"
        let installed = try XCTUnwrap(view.layer.animation(forKey: key))
        installed.setValue("preserve-existing-install", forKey: "Task4.installSentinel")
        view.layer.add(installed, forKey: key)

        fixture.listView.applyChanges(items: source, transition: .easeInOut(duration: 0))

        XCTAssertEqual(view.layer.animation(forKey: key)?.value(forKey: "Task4.installSentinel") as? String,
                       "preserve-existing-install")
    }

    func test_UIKitAndPhysicsEngines_settleToMatchingFinalFrames() {
        let source = items(Array(0..<100))
        let uikit = VirtualListFixture(items: source)
        let physics = PhysicsListFixture(items: source)
        let uikitViews = viewByIdentity(uikit.listView)
        let physicsViews = viewByIdentity(physics.listView)

        uikit.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 125), transition: .easeInOut(duration: 0))
        physics.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 125), transition: .easeInOut(duration: 0))
        var changed = source
        changed.insert(items([999])[0], at: 43)
        changed.remove(at: 38)
        uikit.listView.applyChanges(items: changed, transition: .easeInOut(duration: 0))
        physics.listView.applyChanges(items: changed, transition: .easeInOut(duration: 0))

        XCTAssertEqual(uikit.activeWindow.startIndex, physics.activeWindow.startIndex)
        XCTAssertEqual(uikit.activeWindow.endIndex, physics.activeWindow.endIndex)
        XCTAssertTrue(uikit.listView.engine.offset.isFinite)
        XCTAssertTrue(physics.listView.engine.offset.isFinite)
        for index in uikit.loadedIndices {
            XCTAssertEqual(
                settledScreenY(uikit.listView, index: index)!,
                settledScreenY(physics.listView, index: index)!,
                accuracy: 0.001
            )
        }
        for (identity, view) in uikitViews where viewByIdentity(uikit.listView)[identity] != nil {
            XCTAssertTrue(viewByIdentity(uikit.listView)[identity] === view)
        }
        for (identity, view) in physicsViews where viewByIdentity(physics.listView)[identity] != nil {
            XCTAssertTrue(viewByIdentity(physics.listView)[identity] === view)
        }
    }
}
