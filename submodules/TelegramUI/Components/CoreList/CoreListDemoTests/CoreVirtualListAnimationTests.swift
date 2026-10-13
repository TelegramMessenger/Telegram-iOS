import XCTest
import UIKit
@testable import CoreListDemo

final class CoreVirtualListAnimationTests: XCTestCase {
    func testImmediateInsetsSetTopOffsetAndHorizontalFrames() throws {
        let fixture = VirtualListFixture(itemCount: 20, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(
            newSize: CGSize(width: 390, height: 400),
            newInsets: UIEdgeInsets(top: 100, left: 20, bottom: 30, right: 40),
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(fixture.listView.viewportGeometry.insets.top, 100)
        XCTAssertEqual(fixture.boundsOriginY, -100, accuracy: 1e-6)
        let identity = fixture.listView.items[0].identity
        let frame = try XCTUnwrap(fixture.frame(identity: identity))
        XCTAssertEqual(frame.minX, 20, accuracy: 1e-6)
        XCTAssertEqual(frame.width, 330, accuracy: 1e-6)
        XCTAssertEqual(fixture.listView.engine.contentHost.frame,
                       fixture.listView.bounds)
    }

    func testInsetChangeDuringViewportMotionRetargetsContinuously() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(
            scrollTo: .init(index: 5, pointOffset: 100),
            transition: .easeInOut(duration: 4)
        )
        let identity = fixture.listView.items[5].identity
        fixture.advance(by: 1)
        let boundary = try XCTUnwrap(fixture.renderedY(identity: identity))
        let oldEndpoint = try settledEndpointY(fixture, identity: identity)

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 2)
        )

        XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                       boundary, accuracy: 1e-6)
        XCTAssertEqual(try settledEndpointY(fixture, identity: identity),
                       oldEndpoint + 300, accuracy: 1e-6)
        XCTAssertNil(fixture.positionTrack(identity: identity))
        let replacement = try XCTUnwrap(fixture.viewportTrack)
        XCTAssertEqual(replacement.curve, .easeInOut)
        XCTAssertEqual(replacement.duration, 2, accuracy: 1e-9)
    }

    func testTopOverscrollRemainsPresentationOnlyAcrossInsetExpansion() {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.scroll(to: -30)

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(fixture.boundsOriginY, -330, accuracy: 1e-6,
                       "the settled -300 edge and -30 presentation overscroll must compose once")
    }

    func testTopInsetExpansionBuildsOnlyFinalProjectedBand() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 560),
            items: idItems(Array(0..<100), height: 75),
            preloadMargin: 200
        )
        let rowZero = fixture.listView.items[0].identity
        let initial = try settledEndpointY(fixture, identity: rowZero)

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 4)
        )

        XCTAssertEqual(fixture.loadedIndices, Array(0...6))
        XCTAssertEqual(Set(fixture.crossingCarryIdentities), Set(7...10))
        XCTAssertEqual(try settledEndpointY(fixture, identity: rowZero),
                       initial + 300, accuracy: 1e-6)
        XCTAssertNil(fixture.positionTrack(identity: rowZero))
        XCTAssertNotNil(fixture.viewportTrack)
    }

    func testInsetCollapseFromTrueMinimumAnimatesOnlyForcedClamp() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400),
                                         emitsCA: true)
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .linear(duration: 0)
        )
        fixture.scroll(to: -300)
        let identity = fixture.listView.items[0].identity
        let renderedBefore = try XCTUnwrap(fixture.renderedY(identity: identity))

        fixture.listView.applyChanges(newInsets: .zero,
                                      transition: .linear(duration: 4))

        XCTAssertEqual(fixture.boundsOriginY, 0, accuracy: 1e-6)
        XCTAssertEqual(fixture.loadedIndices, Array(0...11))
        XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                       renderedBefore, accuracy: 1e-6)
        XCTAssertNil(fixture.positionTrack(identity: identity))
        let track = try XCTUnwrap(fixture.viewportTrack)
        XCTAssertEqual(track.from, -300, accuracy: 1e-6)
        XCTAssertEqual(track.to, 0, accuracy: 1e-6)
        XCTAssertEqual(track.duration, 4, accuracy: 1e-9)
        XCTAssertEqual(track.curve, .linear)

        let key = fixture.animationController.compiler.animationKey(for: .viewportOffset)
        let animation = try XCTUnwrap(
            fixture.listView.engine.contentHost.layer.animation(forKey: key)
                as? CABasicAnimation
        )
        XCTAssertEqual(animation.keyPath, "bounds.origin.y")
        XCTAssertTrue(animation.isAdditive)
        XCTAssertEqual(animation.duration, track.duration, accuracy: 1e-9)
        let values = try keyframeValues(animation).map { NSNumber(value: Double($0)) }
        XCTAssertEqual(try XCTUnwrap(values.first).doubleValue,
                       Double(track.from), accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(values.last).doubleValue,
                       Double(track.to), accuracy: 1e-6)
    }

    func testBottomOverscrollRemainsPresentationOnlyAcrossInsetCollapse() {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )
        fixture.listView.applyChanges(
            scrollTo: .init(index: 99, pointOffset: 50),
            transition: .easeInOut(duration: 0)
        )
        let settledBottom = fixture.boundsOriginY
        fixture.scroll(to: settledBottom + 30)

        fixture.listView.applyChanges(newInsets: .zero,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(fixture.boundsOriginY, settledBottom + 30, accuracy: 1e-6,
                       "the settled bottom edge and +30 presentation overscroll must compose once")
    }

    func testRemovingTopInsetAtLoadedBottomClampsInsteadOfOverscrolling() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )
        fixture.listView.applyChanges(
            scrollTo: .init(index: 99, pointOffset: 50),
            transition: .easeInOut(duration: 0)
        )
        let identity = fixture.listView.items[99].identity
        let endpointBefore = try settledEndpointY(fixture, identity: identity)
        let renderedBefore = try XCTUnwrap(fixture.renderedY(identity: identity))

        fixture.listView.applyChanges(newInsets: .zero,
                                      transition: .easeInOut(duration: 4))

        XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                       renderedBefore, accuracy: 1e-6)
        XCTAssertEqual(try settledEndpointY(fixture, identity: identity),
                       endpointBefore, accuracy: 1e-6)
        XCTAssertNil(fixture.positionTrack(identity: identity))
        XCTAssertNil(fixture.viewportTrack)
    }

    func testUnderfilledCollectionKeepsTopPrecedenceAcrossInsetChange() throws {
        let fixture = VirtualListFixture(itemCount: 3, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400),
                                         preloadMargin: 160)

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 100, left: 0, bottom: 100, right: 0),
            transition: .easeInOut(duration: 0)
        )

        let first = fixture.listView.items[0].identity
        let last = fixture.listView.items[2].identity
        XCTAssertEqual(try settledEndpointY(fixture, identity: first), 100, accuracy: 1e-6)
        XCTAssertEqual(try settledEndpointY(fixture, identity: last), 200, accuracy: 1e-6)
        XCTAssertEqual(fixture.loadedIndices, Array(0...2))
    }

    func testBottomInsetAndHeightDoNotTranslateUnclampedMiddleAnchor() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.scroll(to: 500)
        let identity = fixture.listView.items[12].identity
        let endpoint = try settledEndpointY(fixture, identity: identity)

        fixture.listView.applyChanges(
            newSize: CGSize(width: 390, height: 500),
            newInsets: UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0),
            transition: .easeInOut(duration: 2)
        )

        XCTAssertEqual(try settledEndpointY(fixture, identity: identity),
                       endpoint, accuracy: 1e-6)
        XCTAssertNil(fixture.viewportTrack)
        XCTAssertNil(fixture.positionTrack(identity: identity))
    }

    func testScrollToUsesNewTopInsetInSamePass() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        let identity = fixture.listView.items[20].identity

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            scrollTo: .init(index: 20, pointOffset: 40),
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(try settledEndpointY(fixture, identity: identity), 340, accuracy: 1e-6)
    }

    func testNonTopInsetToggleMovesEverySharedRowExactlyOnceAndReturns() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400),
                                         preloadMargin: 160)
        fixture.scroll(to: 500)
        let oldIdentities = fixture.activeWindow.items.map {
            fixture.listView.items[$0.index].identity
        }
        let originalEndpoints = try Dictionary(uniqueKeysWithValues: oldIdentities.map {
            ($0, try settledEndpointY(fixture, identity: $0))
        })
        let originalRendered = try Dictionary(uniqueKeysWithValues: oldIdentities.map {
            ($0, try XCTUnwrap(fixture.renderedY(identity: $0)))
        })

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .linear(duration: 4)
        )

        let sharedAfterExpansion = Set(oldIdentities).intersection(
            fixture.activeWindow.items.map { fixture.listView.items[$0.index].identity }
        )
        for identity in sharedAfterExpansion {
            XCTAssertEqual(try settledEndpointY(fixture, identity: identity),
                           try XCTUnwrap(originalEndpoints[identity]) + 300, accuracy: 1e-6)
            XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                           try XCTUnwrap(originalRendered[identity]), accuracy: 1e-6)
            XCTAssertNil(fixture.positionTrack(identity: identity))
        }
        XCTAssertEqual(fixture.viewportTrack?.curve, .linear)

        fixture.advance(by: 4)
        for identity in sharedAfterExpansion {
            XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                           try XCTUnwrap(originalRendered[identity]) + 300, accuracy: 1e-6)
        }

        fixture.listView.applyChanges(newInsets: .zero,
                                      transition: .linear(duration: 2))

        for identity in sharedAfterExpansion {
            XCTAssertEqual(try settledEndpointY(fixture, identity: identity),
                           try XCTUnwrap(originalEndpoints[identity]), accuracy: 1e-6)
            XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                           try XCTUnwrap(originalRendered[identity]) + 300, accuracy: 1e-6)
            XCTAssertNil(fixture.positionTrack(identity: identity))
        }
        XCTAssertEqual(fixture.viewportTrack?.curve, .linear)

        fixture.advance(by: 2)
        for identity in sharedAfterExpansion {
            XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                           try XCTUnwrap(originalRendered[identity]), accuracy: 1e-6)
        }
    }

    private func settledEndpointY(_ fixture: VirtualListFixture,
                                  identity: AnyHashable) throws -> CGFloat {
        try XCTUnwrap(fixture.settledContentY(identity: identity))
            - fixture.boundsOriginY
    }

    func testHorizontalInsetsStartFromCurrentXAndWidth() throws {
        let fixture = VirtualListFixture(itemCount: 20, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        let identity = fixture.listView.items[0].identity
        let oldFrame = try XCTUnwrap(fixture.frame(identity: identity))

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 50),
            transition: .linear(duration: 4)
        )

        let newFrame = try XCTUnwrap(fixture.frame(identity: identity))
        let xOffset = try XCTUnwrap(fixture.animationController.positionOffsetX(
            identity: identity, at: fixture.animationController.now()
        ))
        let visualWidth = try XCTUnwrap(fixture.animationController.width(
            identity: identity, at: fixture.animationController.now()
        ))
        XCTAssertEqual(newFrame.minX + xOffset, oldFrame.minX, accuracy: 1e-6)
        XCTAssertEqual(visualWidth, oldFrame.width, accuracy: 1e-6)
        XCTAssertEqual(fixture.animationController.model.track(
            for: .live(identity), property: .positionX
        )?.curve, .linear)
        XCTAssertEqual(fixture.animationController.model.track(
            for: .live(identity), property: .width
        )?.curve, .linear)
    }

    func testHorizontalReplacementUsesCompleteInsertedGeometryForOutgoingGhost() throws {
        let fixture = VirtualListFixture(itemCount: 20, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        var firstPass = fixture.listView.items
        let firstInserted = IdentifiableFixedHeightItem(id: UUID(), height: 50)
        firstPass[5] = firstInserted
        fixture.listView.applyChanges(items: firstPass,
                                      transition: .easeInOut(duration: 0))
        let departingView = try XCTUnwrap(fixture.view(identity: firstInserted.identity))

        var secondPass = fixture.listView.items
        let incoming = IdentifiableFixedHeightItem(id: UUID(), height: 50)
        secondPass[5] = incoming
        fixture.listView.applyChanges(
            items: secondPass,
            newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 50),
            transition: .easeInOut(duration: 4)
        )

        let ghost = try XCTUnwrap(
            fixture.listView.ghostMemberHorizontalSnapshots.first {
                $0.view === departingView
            }
        )
        let ghostWidth = try XCTUnwrap(fixture.animationController.model.track(
            for: ghost.owner, property: .width
        ))
        XCTAssertEqual(ghostWidth.from, 390, accuracy: 1e-6)
        XCTAssertEqual(ghostWidth.to, 300, accuracy: 1e-6)

        let incomingOwner = ListAnimationOwner.live(incoming.identity)
        XCTAssertEqual(fixture.animationController.model.value(
            for: incomingOwner, property: .width,
            at: fixture.animationController.now()
        ), 300)
        XCTAssertNil(fixture.animationController.model.track(
            for: incomingOwner, property: .positionX
        ))
        XCTAssertNil(fixture.animationController.model.track(
            for: incomingOwner, property: .width
        ))
        XCTAssertNotNil(fixture.animationController.model.track(
            for: incomingOwner, property: .opacity
        ))
    }

    func testDeletedGhostComposesWithHorizontalInsetGeometry() throws {
        let fixture = VirtualListFixture(itemCount: 20, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        let removedIdentity = fixture.listView.items[0].identity
        let removedView = try XCTUnwrap(fixture.view(identity: removedIdentity))
        let remaining = Array(fixture.listView.items.dropFirst())

        fixture.listView.applyChanges(
            items: remaining,
            newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 50),
            transition: .linear(duration: 4)
        )

        let snapshot = try XCTUnwrap(
            fixture.listView.ghostMemberHorizontalSnapshots.first {
                $0.view === removedView
            }
        )
        let now = fixture.animationController.now()
        let xOffset = try XCTUnwrap(fixture.animationController.model.value(
            for: snapshot.owner, property: .positionX, at: now
        ))
        let visualWidth = try XCTUnwrap(fixture.animationController.model.value(
            for: snapshot.owner, property: .width, at: now
        ))
        XCTAssertEqual(snapshot.settledX + xOffset, 0, accuracy: 1e-6)
        XCTAssertEqual(visualWidth, 390, accuracy: 1e-6)
        XCTAssertEqual(fixture.animationController.model.track(
            for: snapshot.owner, property: .positionX
        )?.curve, .linear)
        XCTAssertEqual(fixture.animationController.model.track(
            for: snapshot.owner, property: .width
        )?.curve, .linear)
    }

    func testMixedGeometryRetargetsEveryPropertyAtOneBoundary() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.scroll(to: 500)
        let identity = fixture.listView.items[12].identity

        fixture.listView.applyChanges(
            newSize: CGSize(width: 430, height: 700),
            newInsets: UIEdgeInsets(top: 300, left: 20, bottom: 40, right: 30),
            transition: .easeInOut(duration: 4)
        )
        fixture.advance(by: 1)
        let yBoundary = try XCTUnwrap(fixture.renderedY(identity: identity))
        let firstFrame = try XCTUnwrap(fixture.frame(identity: identity))
        let xBoundary = firstFrame.minX + (fixture.animationController.positionOffsetX(
            identity: identity, at: fixture.animationController.now()
        ) ?? 0)
        let widthBoundary = try XCTUnwrap(fixture.animationController.width(
            identity: identity, at: fixture.animationController.now()
        ))

        fixture.listView.applyChanges(
            newSize: CGSize(width: 360, height: 500),
            newInsets: UIEdgeInsets(top: 80, left: 0, bottom: 120, right: 0),
            transition: .easeInOut(duration: 2)
        )

        let secondFrame = try XCTUnwrap(fixture.frame(identity: identity))
        let retargetedX = secondFrame.minX + (fixture.animationController.positionOffsetX(
            identity: identity, at: fixture.animationController.now()
        ) ?? 0)
        let retargetedWidth = try XCTUnwrap(fixture.animationController.width(
            identity: identity, at: fixture.animationController.now()
        ))
        XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                       yBoundary, accuracy: 1e-6)
        XCTAssertEqual(retargetedX, xBoundary, accuracy: 1e-6)
        XCTAssertEqual(retargetedWidth, widthBoundary, accuracy: 1e-6)
        XCTAssertEqual(fixture.viewportTrack?.curve, .easeInOut)
        XCTAssertEqual(fixture.animationController.model.track(
            for: .live(identity), property: .positionX
        )?.curve, .easeInOut)
        XCTAssertEqual(fixture.animationController.model.track(
            for: .live(identity), property: .width
        )?.curve, .easeInOut)
    }

    func testUnclampedInsetViewportTrackMatchesEmittedAnimation() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400),
                                         emitsCA: true)
        fixture.scroll(to: 500)

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 2)
        )

        let track = try XCTUnwrap(fixture.viewportTrack)
        XCTAssertEqual(track.from, 300, accuracy: 1e-6)
        XCTAssertEqual(track.to, 0, accuracy: 1e-6)
        XCTAssertEqual(track.duration, 2, accuracy: 1e-9)
        XCTAssertEqual(track.curve, .easeInOut)

        let key = fixture.animationController.compiler.animationKey(for: .viewportOffset)
        let animation = try XCTUnwrap(
            fixture.listView.engine.contentHost.layer.animation(forKey: key)
                as? CABasicAnimation
        )
        XCTAssertEqual(animation.keyPath, "bounds.origin.y")
        XCTAssertTrue(animation.isAdditive)
        XCTAssertEqual(animation.duration, track.duration, accuracy: 1e-9)
        let values = try keyframeValues(animation).map { NSNumber(value: Double($0)) }
        XCTAssertEqual(try XCTUnwrap(values.first).doubleValue,
                       Double(track.from), accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(values.last).doubleValue,
                       Double(track.to), accuracy: 1e-6)
    }
    private final class MeasurementCounter {
        var created: [Int: Int] = [:]
        var measured: [Int: Int] = [:]
    }

    private final class MeasuredIDItem: CoreListItem {
        let id: Int
        let height: CGFloat
        let counter: MeasurementCounter
        var identity: AnyHashable { id }

        init(id: Int, height: CGFloat, counter: MeasurementCounter) {
            self.id = id
            self.height = height
            self.counter = counter
        }

        func view() -> UIView & CoreListItemView {
            counter.created[id, default: 0] += 1
            return MeasuredFixedHeightView(id: id, height: height, counter: counter)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? MeasuredIDItem)?.id == id
        }
    }

    private final class MeasuredFixedHeightView: UIView, CoreListItemView {
        let id: Int
        let height: CGFloat
        let counter: MeasurementCounter
        var onContentDidChange: ((Bool) -> Void)?

        init(id: Int, height: CGFloat, counter: MeasurementCounter) {
            self.id = id
            self.height = height
            self.counter = counter
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
            counter.measured[id, default: 0] += 1
            return height
        }
    }

    private func loadedMeasuredIDs(_ listView: CoreVirtualListView) -> [Int] {
        listView.activeWindow.items.map {
            listView.items[$0.index].identity.base as! Int
        }
    }

    func testRemovingLargeTopInsetBuildsCompleteProjectedWindowWithoutExtraMeasurement() {
        let counter = MeasurementCounter()
        let items: [CoreListItem] = (0..<100).map {
            MeasuredIDItem(id: $0, height: 75, counter: counter)
        }
        let driver = PhysicsListDriver(
            viewport: CGSize(width: 390, height: 560),
            items: items,
            preloadMargin: 200,
            decelerationMode: .keyframe
        )

        driver.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0.5)
        )
        XCTAssertEqual(loadedMeasuredIDs(driver.listView), Array(0...6))

        counter.created.removeAll()
        counter.measured.removeAll()
        driver.listView.applyChanges(newInsets: .zero,
                                     transition: .easeInOut(duration: 0.5))

        XCTAssertEqual(loadedMeasuredIDs(driver.listView), Array(0...10))
        XCTAssertTrue(counter.created.isEmpty,
                      "rows returning from the crossing band must reuse their views")
        XCTAssertEqual(Set(counter.measured.keys), Set(0...10))
        XCTAssertTrue(counter.measured.values.allSatisfy { $0 == 1 })
        XCTAssertFalse(counter.measured.keys.contains(11))
    }

    func testLargeTopInsetCarriesOnlyRowsLeavingProjectedMembership() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 560),
            items: idItems(Array(0..<100), height: 75),
            preloadMargin: 200
        )

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 4)
        )

        XCTAssertEqual(fixture.loadedIndices, Array(0...6))
        XCTAssertEqual(Set(fixture.crossingCarryIdentities), Set(7...10))
    }

    func testLargeTopInsetCarriesReleaseWithViewportGeneration() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 560),
            items: idItems(Array(0..<100), height: 75),
            preloadMargin: 200
        )
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 4)
        )
        let generation = try XCTUnwrap(fixture.viewportTrack).generation
        XCTAssertFalse(fixture.crossingCarryIdentities.isEmpty)

        fixture.advance(by: 3.9)
        XCTAssertFalse(fixture.crossingCarryIdentities.isEmpty,
                       "carries must remain until viewport generation \(generation) completes")
        fixture.advance(by: 0.1)
        XCTAssertTrue(fixture.crossingCarryIdentities.isEmpty)
    }

    func testRemovingLargeTopInsetPromotesCrossingRowsWithoutScroll() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 560),
            items: idItems(Array(0..<100), height: 75),
            preloadMargin: 200
        )
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 4)
        )
        fixture.advance(by: 1)
        let carriedViews = Dictionary(uniqueKeysWithValues:
            fixture.crossingCarryIdentities.compactMap { identity in
                fixture.crossingCarryView(identity: identity).map { (identity, $0) }
            })

        fixture.listView.applyChanges(newInsets: .zero,
                                      transition: .easeInOut(duration: 2))

        XCTAssertEqual(fixture.loadedIndices, Array(0...10))
        XCTAssertTrue(fixture.crossingCarryIdentities.isEmpty)
        for identity in 7...10 {
            XCTAssertTrue(fixture.view(identity: identity) === carriedViews[identity])
        }
    }

    // Int-id content item: identity is `id`; `isEqual` is value equality over id + height, so a
    // same-id row whose height changes is NOT equal and reconciles (design 2026-05-31).
    private final class HeightReconcileItem: CoreListItem {
        let id: Int
        let height: CGFloat

        var identity: AnyHashable { id }

        init(id: Int, height: CGFloat) {
            self.id = id
            self.height = height
        }

        func view() -> UIView & CoreListItemView {
            let view = ContentResizableItemView()
            apply(to: view, transition: .immediate)
            return view
        }

        func isEqual(to other: CoreListItem) -> Bool {
            guard let other = other as? HeightReconcileItem else { return false }
            return id == other.id && height == other.height
        }

        func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
            (view as? ContentResizableItemView)?.applyContent(height)
        }
    }

    private final class ClampingScrollEngine: ScrollEngine {
        let contentHost = UIView()
        var onScroll: ((CGFloat) -> Void)?
        /// Never fires: this stub writes offsets directly, with no baked trajectory to compose against.
        var onFlightChanged: ((ScrollFlight?) -> Void)?
        var onWillBeginDragging: (() -> Void)?
        var onDidEndDragging: (() -> Void)?
        // Never consulted: this engine has no drag and therefore no release.
        var shouldStopScrollingOnRelease: ((CGFloat) -> Bool)?
        private(set) var offset: CGFloat = 0

        func setOffset(_ y: CGFloat) {
            offset = min(max(y, 0), 100)
            contentHost.bounds.origin.y = offset
        }

        func reanchorDragToCurrentPosition() {}


        func haltMotionInPlace() {
            // Nothing to halt: this engine has no momentum. `setOffset` re-clamps, which is the correct
            // no-motion behaviour and mirrors UIKitScrollEngine.
            setOffset(offset)
        }

        func syncToPresentedPosition() {
            // Its offset is already the presented value — nothing animates behind it.
        }

        func applyShift(_ dy: CGFloat) {
            setOffset(offset + dy)
        }

        func setEdges(min: CGFloat?, max: CGFloat?) {}

        func containerOrigin(windowHeight: CGFloat,
                             topLoaded: Bool,
                             bottomLoaded: Bool) -> CGFloat {
            0
        }
    }

    private final class IDItem: CoreListItem {
        let id: Int
        let height: CGFloat

        var identity: AnyHashable { id }

        init(id: Int, height: CGFloat) {
            self.id = id
            self.height = height
        }

        func view() -> UIView & CoreListItemView {
            FixedHeightItemView(height: height)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            guard let other = other as? IDItem else { return false }
            return id == other.id
        }
    }

    private func idItems(_ ids: [Int], height: CGFloat = 50) -> [CoreListItem] {
        ids.map { IDItem(id: $0, height: height) }
    }

    func testLargeInsertCarriesEveryOldOnlyLoadedSurvivorOut() throws {
        let original = Array(0..<30)
        let inserted = Array(100..<105)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: idItems(original, height: 75),
            preloadMargin: 200
        )
        let oldOnly = Array(6...10)
        let oldViews = Dictionary(uniqueKeysWithValues: oldOnly.map {
            ($0, fixture.view(identity: $0)!)
        })
        let oldY = Dictionary(uniqueKeysWithValues: oldOnly.map {
            ($0, fixture.screenY(identity: $0)!)
        })

        fixture.apply(
            idItems(Array(0..<5) + inserted + Array(5..<30), height: 75),
            duration: 8
        )

        XCTAssertEqual(Set(fixture.crossingCarryIdentities), Set(oldOnly.map(AnyHashable.init)))
        XCTAssertEqual(fixture.loadedIndices, Array(0...10),
                       "the settled window must not be enlarged")
        for identity in oldOnly {
            XCTAssertTrue(fixture.crossingCarryView(identity: identity) === oldViews[identity])
            XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                           oldY[identity]!, accuracy: 1e-9)
            XCTAssertEqual(try XCTUnwrap(fixture.positionTrack(identity: identity)).from,
                           -375, accuracy: 1e-9)
        }

        fixture.advance(by: 4)
        for identity in oldOnly {
            XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                           oldY[identity]! + 187.5, accuracy: 1e-9)
        }

        fixture.advance(by: 4)
        XCTAssertTrue(fixture.crossingCarryIdentities.isEmpty)
    }

    func testUnwitnessedMixedPassCarriesCrossingRunRigidly() throws {
        let ids = (0..<30).map { _ in UUID() }
        let insertedIDs = (0..<5).map { _ in UUID() }
        func items(firstHeight: CGFloat, inserted: Bool) -> [CoreListItem] {
            let original: [CoreListItem] = ids.enumerated().map {
                ContentResizableItem(id: $0.element,
                                     contentHeight: $0.offset == 0 ? firstHeight : 75)
            }
            guard inserted else { return original }
            let block: [CoreListItem] = insertedIDs.map {
                ContentResizableItem(id: $0, contentHeight: 75)
            }
            return Array(original[0..<5]) + block + Array(original[5...])
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 402, height: 874),
            items: items(firstHeight: 75, inserted: false),
            preloadMargin: 200
        )
        let chromeInsets = UIEdgeInsets(top: 307, left: 0, bottom: 83, right: 0)
        fixture.listView.applyChanges(newInsets: chromeInsets,
                                      transition: .easeInOut(duration: 0))
        let crossingIDs = Array(ids[5...10])

        fixture.listView.applyChanges(
            items: items(firstHeight: 200, inserted: true),
            newInsets: UIEdgeInsets(top: 307, left: 40, bottom: 83, right: 50),
            transition: .easeInOut(duration: 8)
        )

        let snapshots = Dictionary(uniqueKeysWithValues:
            fixture.listView.crossingCarrySnapshots.map { ($0.identity, $0) })
        let settled = try crossingIDs.map {
            try XCTUnwrap(snapshots[AnyHashable($0)]?.settledContentY)
        }
        let lastLoadedIndex = try XCTUnwrap(fixture.loadedIndices.last)
        let lastLoadedIdentity = fixture.listView.items[lastLoadedIndex].identity
        let occupiedMaxY = try XCTUnwrap(
            fixture.settledContentY(identity: lastLoadedIdentity)
        ) + fixture.activeWindow.items.last!.frame.height
        XCTAssertGreaterThanOrEqual(settled[0], occupiedMaxY)
        let offsets = try crossingIDs.map {
            try XCTUnwrap(fixture.positionTrack(identity: $0)?.from)
        }
        XCTAssertEqual(zip(settled.dropFirst(), settled).map { $0 - $1 },
                       Array(repeating: 75, count: crossingIDs.count - 1))
        XCTAssertTrue(offsets.dropFirst().allSatisfy {
            abs($0 - offsets[0]) < 1e-9
        })
        let loadedInsertedIDs = insertedIDs.filter { fixture.view(identity: $0) != nil }
        XCTAssertFalse(loadedInsertedIDs.isEmpty)
        for identity in loadedInsertedIDs {
            XCTAssertNil(fixture.positionTrack(identity: identity))
            XCTAssertNotNil(fixture.opacityTrack(identity: identity))
        }

        fixture.advance(by: 8)
        fixture.listView.applyChanges(items: items(firstHeight: 75, inserted: false),
                                      newInsets: chromeInsets,
                                      transition: .easeInOut(duration: 8))

        let incomingOffsets = try crossingIDs.map {
            try XCTUnwrap(fixture.positionTrack(identity: $0)?.from)
        }
        let incomingY = try crossingIDs.map {
            try XCTUnwrap(fixture.renderedY(identity: $0))
        }
        XCTAssertTrue(incomingOffsets.dropFirst().allSatisfy {
            abs($0 - incomingOffsets[0]) < 1e-9
        })
        XCTAssertEqual(zip(incomingY.dropFirst(), incomingY).map { $0 - $1 },
                       Array(repeating: 75, count: crossingIDs.count - 1))
    }

    func testLargeRemovalAnimatesEveryNewlyLoadedSurvivorIn() throws {
        let original = Array(0..<30)
        let inserted = Array(100..<105)
        let expanded = Array(0..<5) + inserted + Array(5..<30)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: idItems(expanded, height: 75),
            preloadMargin: 200
        )

        fixture.apply(idItems(original, height: 75), duration: 8)

        for identity in 6...10 {
            XCTAssertNotNil(fixture.view(identity: identity))
            XCTAssertNil(fixture.opacityTrack(identity: identity))
            XCTAssertEqual(try XCTUnwrap(fixture.positionTrack(identity: identity)).from,
                           375, accuracy: 1e-9)
            XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: identity)),
                           CGFloat(identity * 75 + 375), accuracy: 1e-9)
        }

        fixture.advance(by: 4)
        for identity in 6...10 {
            XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: identity)),
                           CGFloat(identity * 75) + 187.5, accuracy: 1e-9)
        }
    }

    func testInsertThenRemovePromotesSameCarryViewsContinuously() throws {
        let original = Array(0..<30)
        let inserted = Array(100..<105)
        let expanded = Array(0..<5) + inserted + Array(5..<30)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: idItems(original, height: 75),
            preloadMargin: 200
        )
        let identity = 8
        let originalView = try XCTUnwrap(fixture.view(identity: identity))

        fixture.apply(idItems(expanded, height: 75), duration: 8)
        fixture.advance(by: 1)
        let before = try XCTUnwrap(fixture.renderedY(identity: identity))

        fixture.apply(idItems(original, height: 75), duration: 8)

        XCTAssertTrue(fixture.view(identity: identity) === originalView)
        XCTAssertNil(fixture.crossingCarryView(identity: identity))
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: identity)),
                       before, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.positionTrack(identity: identity)).startTime,
                       1, accuracy: 1e-9)
    }

    func testUnrelatedPassPreservesOutgoingCarryTrackExactly() throws {
        let original = Array(0..<30)
        let expanded = Array(0..<5) + Array(100..<105) + Array(5..<30)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: idItems(original, height: 75), preloadMargin: 200
        )
        fixture.apply(idItems(expanded, height: 75), duration: 8)
        fixture.advance(by: 1)
        let before = try XCTUnwrap(fixture.positionTrack(identity: 8))

        fixture.listView.applyChanges(newSize: fixture.listView.logicalSize,
                                      transition: .easeInOut(duration: 1))

        XCTAssertEqual(fixture.positionTrack(identity: 8), before)
        XCTAssertNotNil(fixture.crossingCarryView(identity: 8))
    }

    func testRemovingOutgoingCarryConvertsCurrentPresentationToGhost() throws {
        let original = Array(0..<30)
        let expanded = Array(0..<5) + Array(100..<105) + Array(5..<30)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: idItems(original, height: 75), preloadMargin: 200
        )
        fixture.apply(idItems(expanded, height: 75), duration: 8)
        fixture.advance(by: 1)
        let view = try XCTUnwrap(fixture.crossingCarryView(identity: 8))
        let before = try XCTUnwrap(fixture.renderedY(identity: 8))
        let removed = expanded.filter { $0 != 8 }

        fixture.apply(idItems(removed, height: 75), duration: 4)

        XCTAssertNil(fixture.crossingCarryView(identity: 8))
        XCTAssertTrue(fixture.driver.isExitMember(view))
        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: view)),
                       before, accuracy: 1e-9)
    }

    func testZeroDurationLargeInsertReleasesOutgoingCarriesImmediately() {
        let original = Array(0..<30)
        let expanded = Array(0..<5) + Array(100..<105) + Array(5..<30)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: idItems(original, height: 75), preloadMargin: 200
        )

        fixture.apply(idItems(expanded, height: 75), duration: 0)

        XCTAssertTrue(fixture.crossingCarryIdentities.isEmpty)
    }

    func testCoordinateRebaseShiftsCarryBaseWithoutReplacingTrack() throws {
        let original = Array(0..<60)
        let expanded = Array(0..<5) + Array(100..<105) + Array(5..<60)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: idItems(original, height: 75), preloadMargin: 200
        )
        fixture.apply(idItems(expanded, height: 75), duration: 8)
        let beforeTrack = try XCTUnwrap(fixture.positionTrack(identity: 8))
        let beforeY = try XCTUnwrap(fixture.renderedY(identity: 8))

        fixture.scroll(to: 150)

        XCTAssertEqual(fixture.positionTrack(identity: 8), beforeTrack)
        XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: 8)),
                       beforeY - 150, accuracy: 1e-6)
    }

    func testUserScrollPromotesCrossingCarryOutOfRegistry() {
        let original = Array(0..<60)
        let expanded = Array(0..<5) + Array(100..<105) + Array(5..<60)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: idItems(original, height: 75), preloadMargin: 200
        )
        fixture.apply(idItems(expanded, height: 75), duration: 8)
        XCTAssertTrue(fixture.crossingCarryIdentities.contains(6))

        fixture.scroll(to: 300)

        let activeIdentities = Set(fixture.activeWindow.items.map {
            fixture.listView.items[$0.index].identity
        })
        XCTAssertTrue(activeIdentities.contains(6), "scroll must load the carried identity")
        XCTAssertTrue(
            activeIdentities.intersection(fixture.crossingCarryIdentities).isEmpty,
            "an identity promoted by scroll must no longer remain a crossing carry"
        )

        var nextIDs = expanded
        nextIDs.insert(999, at: fixture.activeWindow.startIndex)
        fixture.apply(idItems(nextIDs, height: 75), duration: 0.3)
        let nextActiveIdentities = Set(fixture.activeWindow.items.map {
            fixture.listView.items[$0.index].identity
        })
        XCTAssertTrue(nextActiveIdentities.intersection(fixture.crossingCarryIdentities).isEmpty)
    }

    func testLargeBlockCrossingNeverMeasuresOutsideOldNewWindowUnion() {
        let counter = MeasurementCounter()
        func items(_ ids: [Int]) -> [CoreListItem] {
            ids.map { MeasuredIDItem(id: $0, height: 75, counter: counter) }
        }
        let original = Array(0..<100)
        let inserted = Array(1000..<1100)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: items(original), preloadMargin: 200
        )
        let oldLoaded = Set(fixture.activeWindow.items.map { original[$0.index] })
        counter.created.removeAll()
        counter.measured.removeAll()

        fixture.apply(items(Array(0..<5) + inserted + Array(5..<100)), duration: 8)

        let newLoaded = Set(fixture.activeWindow.items.map {
            fixture.listView.items[$0.index].identity.base as! Int
        })
        let allowed = oldLoaded.union(newLoaded)
        XCTAssertTrue(Set(counter.created.keys).isSubset(of: allowed))
        XCTAssertTrue(Set(counter.measured.keys).isSubset(of: allowed))
        XCTAssertEqual(fixture.loadedIndices, Array(0...10),
                       "100 inserted rows must not expand the settled window")
    }

    func testVariableHeightBlockUsesOneLocalDisplacementForCrossingSurvivors() throws {
        let original: [CoreListItem] = (0..<30).map { IDItem(id: $0, height: 75) }
        let insertedHeights: [CGFloat] = [40, 60, 80, 100, 120]
        let inserted: [CoreListItem] = zip(100..<105, insertedHeights).map {
            IDItem(id: $0.0, height: $0.1)
        }
        let expanded = Array(original[0..<5]) + inserted + Array(original[5...])
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: original, preloadMargin: 200
        )
        let oldLoaded = Set(fixture.activeWindow.items.map {
            fixture.listView.items[$0.index].identity
        })

        fixture.apply(expanded, duration: 8)

        let expandedLoaded = Set(fixture.activeWindow.items.map {
            fixture.listView.items[$0.index].identity
        })
        let outgoing = oldLoaded.subtracting(expandedLoaded)
        XCTAssertFalse(outgoing.isEmpty)
        for identity in outgoing {
            XCTAssertEqual(try XCTUnwrap(fixture.positionTrack(identity: identity)).from,
                           -400, accuracy: 1e-9)
        }

        fixture.advance(by: 8)
        let beforeRemovalLoaded = Set(fixture.activeWindow.items.map {
            fixture.listView.items[$0.index].identity
        })
        fixture.apply(original, duration: 8)
        let afterRemovalLoaded = Set(fixture.activeWindow.items.map {
            fixture.listView.items[$0.index].identity
        })
        let incoming = afterRemovalLoaded.subtracting(beforeRemovalLoaded)
        XCTAssertFalse(incoming.isEmpty)
        for identity in incoming {
            XCTAssertEqual(try XCTUnwrap(fixture.positionTrack(identity: identity)).from,
                           400, accuracy: 1e-9)
        }
    }

    func testRepeatedLargeInsertRemoveLeavesNoCarryOrOwnerGrowth() {
        let original = idItems(Array(0..<40), height: 75)
        let expanded = idItems(Array(0..<5) + Array(100..<105) + Array(5..<40),
                               height: 75)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: original, preloadMargin: 200
        )

        for _ in 0..<10 {
            fixture.apply(expanded, duration: 1)
            fixture.advance(by: 1)
            fixture.apply(original, duration: 1)
            fixture.advance(by: 1)
            XCTAssertTrue(fixture.crossingCarryIdentities.isEmpty)
            XCTAssertTrue(fixture.ghostBlocks.isEmpty)
            XCTAssertLessThanOrEqual(
                fixture.animationController.model.ownerCount,
                fixture.activeWindow.items.count + 1
            )
        }
    }

    private func reconcileItems(_ ids: [Int],
                                firstHeight: CGFloat = 50) -> [CoreListItem] {
        ids.map {
            HeightReconcileItem(id: $0, height: $0 == ids.first ? firstHeight : 50)
        }
    }

    /// The animation's endpoints, as `[from, to]`.
    ///
    /// Named for the sampled keyframe array it used to read. CoreList now emits CAAnimationUtils-
    /// shaped `CABasicAnimation`s, so the endpoints are `fromValue`/`toValue`; every caller only ever
    /// looked at `.first` and `.last`, which is exactly what this still returns.
    private func keyframeValues(_ animation: CAAnimation) throws -> [CGFloat] {
        let basic = try XCTUnwrap(animation as? CABasicAnimation)
        let from = try XCTUnwrap(basic.fromValue as? NSNumber)
        let to = try XCTUnwrap(basic.toValue as? NSNumber)
        return [CGFloat(from.doubleValue), CGFloat(to.doubleValue)]
    }

    func testInsertIsFullHeightAtFinalPositionAndOnlyFades() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3]))

        fixture.apply(idItems([0, 9, 1, 2, 3]), duration: 2)

        XCTAssertEqual(try XCTUnwrap(fixture.frame(identity: 9)).height, 50)
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: 9)), 50, accuracy: 1e-9)
        XCTAssertNil(fixture.positionTrack(identity: 9))
        XCTAssertNil(fixture.heightTrack(identity: 9))
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 9)), 0, accuracy: 1e-9)
        fixture.advance(by: 1)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 9)), 0.5, accuracy: 1e-9)
    }

    func testInsertAtSettledTopPinsNewFirstRowBelowInset() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3]))

        fixture.apply(idItems([9, 0, 1, 2, 3]), duration: 8)

        XCTAssertEqual(try XCTUnwrap(fixture.settledContentY(identity: 9)), 0,
                       accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.settledContentY(identity: 0)), 50,
                       accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 9)), 0,
                       accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 0)), 0,
                       accuracy: 1e-9,
                       "the former first row must start continuously before moving down")
        XCTAssertEqual(try XCTUnwrap(fixture.positionTrack(identity: 0)).from, -50,
                       accuracy: 1e-9)
    }

    func testTopOverscrollUsesSettledEdgeForInsertionAnchor() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3]))
        fixture.scrollView.bounds.origin.y = -30
        fixture.fireScroll()

        fixture.apply(idItems([9, 0, 1, 2, 3]), duration: 8)

        XCTAssertEqual(try XCTUnwrap(fixture.settledContentY(identity: 9)), 0,
                       accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.settledContentY(identity: 0)), 50,
                       accuracy: 1e-9)
        XCTAssertEqual(fixture.boundsOriginY, -30, accuracy: 1e-9,
                       "presentation-only overscroll must remain owned by the bounce")
    }

    // The engine matches survivors by `identity` and reconciles a survivor iff `!isEqual` (content).
    // Content-equal survivors must be a no-op (no reconfigure, no reopened geometry); a real content
    // change must open the geometry gate. (Re-expressed from a former comparison-count assertion:
    // the diff no longer calls a user method — it compares `identity` — so counting isEqual calls is
    // both moot and nondeterministic.)
    func testContentEqualSurvivorsSkipGeometryGateWhileContentChangeOpensIt() throws {
        let allIDs = Array(0..<200)
        let survivingIDs = allIDs.filter { $0 != 1 }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: reconcileItems(allIDs)
        )
        fixture.apply(reconcileItems(survivingIDs), duration: 12)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)

        // Re-apply content-equal survivors: no survivor reconfigures, so the settled ghost block's
        // geometry track must stay closed.
        fixture.apply(reconcileItems(survivingIDs), duration: 1)
        XCTAssertNil(fixture.ghostBlockTrack(block.id),
                     "content-equal survivors must not reopen the geometry gate")

        // A real content change (first row 50 -> 100) shifts geometry and must reopen the gate.
        fixture.apply(reconcileItems(survivingIDs, firstHeight: 100), duration: 4)
        XCTAssertNotNil(fixture.ghostBlockTrack(block.id),
                        "a real survivor content change must open the geometry gate")
    }

    func testInsertDuringInsertDoesNotRestartFirstInsertFade() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2]))
        fixture.apply(idItems([0, 9, 1, 2]), duration: 4)
        fixture.advance(by: 1)
        let before = try XCTUnwrap(fixture.opacityTrack(identity: 9))

        fixture.apply(idItems([0, 9, 10, 1, 2]), duration: 4)

        XCTAssertEqual(fixture.opacityTrack(identity: 9), before)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 9)), 0.12916193104731982, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 10)), 0, accuracy: 1e-9)
    }

    func testOneApplyUsesOneCapturedTimeForEveryBornTrack() throws {
        var mediaTime: CFTimeInterval = 0
        let fixture = VirtualListFixture(
            items: idItems(Array(0..<20)),
            mediaTime: {
                mediaTime += 0.25
                return mediaTime
            }
        )

        fixture.apply(idItems([0, 99] + Array(1..<20)), duration: 4)

        let tracks = [
            try XCTUnwrap(fixture.opacityTrack(identity: 99)),
            try XCTUnwrap(fixture.positionTrack(identity: 1)),
            try XCTUnwrap(fixture.positionTrack(identity: 2)),
            try XCTUnwrap(fixture.positionTrack(identity: 3)),
        ]
        XCTAssertEqual(Set(tracks.map(\.startTime)).count, 1,
                       "one list transaction must not acquire per-row clock skew")
    }

    func testContiguousFiveRowInsertUsesFinalFullHeightFramesAndIndependentFades() throws {
        let fixture = VirtualListFixture(items: idItems(Array(0..<10)))
        let inserted = Array(20..<25)
        fixture.apply(idItems([0] + inserted + Array(1..<10)), duration: 3)

        for (ordinal, identity) in inserted.enumerated() {
            XCTAssertEqual(try XCTUnwrap(fixture.frame(identity: identity)).height, 50)
            XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)),
                           CGFloat((ordinal + 1) * 50), accuracy: 1e-9)
            XCTAssertNil(fixture.positionTrack(identity: identity))
            XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: identity)), 0, accuracy: 1e-9)
            XCTAssertNotNil(fixture.opacityTrack(identity: identity))
        }

        fixture.advance(by: 1.5)
        for identity in inserted {
            XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: identity)), 0.5, accuracy: 1e-9)
        }
    }

    func testInsertAboveAndBelowScrolledAnchorBothFadeAtFinalFrames() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: idItems(Array(0..<30)),
            preloadMargin: 200
        )
        fixture.listView.applyChanges(scrollTo: .init(index: 10, pointOffset: 100),
                                      transition: .easeInOut(duration: 0))
        var changed = Array(0..<30)
        changed.insert(90, at: 8)
        changed.insert(91, at: 14)

        fixture.apply(idItems(changed), duration: 2)

        XCTAssertEqual(try XCTUnwrap(fixture.frame(identity: 90)).height, 50)
        XCTAssertEqual(try XCTUnwrap(fixture.frame(identity: 91)).height, 50)
        XCTAssertNil(fixture.positionTrack(identity: 90))
        XCTAssertNil(fixture.positionTrack(identity: 91))
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 90)), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 91)), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 10)), 100, accuracy: 1e-9)
    }

    func testDeleteTopThenReplacementPreservesUntouchedMotionGeneration() throws {
        let fixture = VirtualListFixture(items: idItems(Array(0..<20)))
        fixture.apply(idItems(Array(1..<20)), duration: 4)
        fixture.advance(by: 1)
        let rowOneTrack = try XCTUnwrap(fixture.positionTrack(identity: 1))
        var replacement = Array(1..<20)
        replacement[4] = 99

        fixture.apply(idItems(replacement), duration: 4)

        XCTAssertEqual(fixture.positionTrack(identity: 1), rowOneTrack)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 1)), 43.541903447634006, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 99)), 0, accuracy: 1e-9)
        XCTAssertNotNil(fixture.opacityTrack(identity: 99))
    }

    func testScrollOffscreenAndRebindPreservesInsertionOriginalPhaseAndDeadline() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: idItems(Array(0..<20)),
            preloadMargin: 0,
            emitsCA: true
        )
        // Start the clock away from 0 so the rebind assertion below distinguishes the two origin
        // conventions: at clock 0 an implicit origin and the track's own clock are both 0. Every
        // other assertion here is clock-relative and unaffected.
        fixture.advance(by: 2)
        fixture.apply(idItems([0, 99] + Array(1..<20)), duration: 4)
        let original = try XCTUnwrap(fixture.opacityTrack(identity: 99))
        fixture.advance(by: 1)

        fixture.scroll(to: 150)
        XCTAssertNil(fixture.view(identity: 99))
        fixture.advance(by: 1)
        fixture.scroll(to: 0)

        XCTAssertEqual(fixture.opacityTrack(identity: 99), original)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 99)), 0.5, accuracy: 1e-9)
        let reboundView = try XCTUnwrap(fixture.view(identity: 99))
        let animation = try XCTUnwrap(
            reboundView.layer.animation(forKey: "CoreListAnimation.opacity")
        )
        // This fixture is never in a window, so Core Animation resolved nothing for the original and
        // `rebind` falls back to the model's clock — non-vacuous now that the clock started at 2.
        XCTAssertEqual(animation.beginTime, original.startTime)
        XCTAssertTrue(animation.coreListPreservesPhase)
        XCTAssertEqual(animation.duration, original.duration)
    }

    func testOffscreenContentHeightChangeSettlesStaleHeightAndPreservesPositionTrackOnRebind() throws {
        let ids = (0..<30).map { _ in UUID() }
        func items(includeFirst: Bool = true, rowHeight: CGFloat) -> [CoreListItem] {
            ids.enumerated().compactMap { index, id in
                guard includeFirst || index != 0 else { return nil }
                return ContentResizableItem(
                    id: id,
                    contentHeight: index == 1 ? rowHeight : 50
                )
            }
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: items(rowHeight: 50),
            preloadMargin: 0,
            emitsCA: true
        )
        let identity = ids[1]
        fixture.apply(items(includeFirst: false, rowHeight: 100), duration: 8)
        fixture.advance(by: 1)
        let positionBefore = try XCTUnwrap(fixture.positionTrack(identity: identity))
        XCTAssertNotNil(fixture.heightTrack(identity: identity))

        fixture.scroll(to: 300)
        XCTAssertNil(fixture.view(identity: identity))
        fixture.apply(items(includeFirst: false, rowHeight: 150), duration: 4)
        fixture.scroll(to: 0)

        let rebound = try XCTUnwrap(fixture.view(identity: identity))
        XCTAssertEqual(try XCTUnwrap(fixture.frame(identity: identity)).height,
                       150, accuracy: 1e-9)
        XCTAssertEqual(rebound.layer.bounds.height, 150, accuracy: 1e-9,
                       "freshly measured geometry must win over the retained height endpoint")
        XCTAssertNil(fixture.heightTrack(identity: identity))
        XCTAssertNil(rebound.layer.animation(forKey: "CoreListAnimation.height"))
        XCTAssertEqual(fixture.positionTrack(identity: identity), positionBefore,
                       "height reconciliation must preserve unrelated active position state")
    }

    func testSamePassReentryWithChangedOffscreenHeightSettlesBeforeRebind() throws {
        let ids = (0..<30).map { _ in UUID() }
        func items(includeFirst: Bool = true, rowHeight: CGFloat) -> [CoreListItem] {
            ids.enumerated().compactMap { index, id in
                guard includeFirst || index != 0 else { return nil }
                return ContentResizableItem(
                    id: id,
                    contentHeight: index == 1 ? rowHeight : 50
                )
            }
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: items(rowHeight: 50),
            preloadMargin: 0,
            emitsCA: true
        )
        let identity = ids[1]
        fixture.apply(items(includeFirst: false, rowHeight: 100), duration: 8)
        fixture.advance(by: 1)
        let positionBefore = try XCTUnwrap(fixture.positionTrack(identity: identity))
        fixture.scroll(to: 300)
        XCTAssertNil(fixture.view(identity: identity))

        fixture.listView.applyChanges(
            items: items(includeFirst: false, rowHeight: 150),
            scrollTo: .init(index: 0, pointOffset: 0),
            transition: .easeInOut(duration: 4)
        )

        let rebound = try XCTUnwrap(fixture.view(identity: identity))
        XCTAssertEqual(rebound.layer.bounds.height, 150, accuracy: 1e-9)
        XCTAssertNil(fixture.heightTrack(identity: identity))
        XCTAssertNil(rebound.layer.animation(forKey: "CoreListAnimation.height"))
        XCTAssertEqual(fixture.positionTrack(identity: identity), positionBefore)
    }

    func testOffscreenUnchangedHeightRebindPreservesOriginalHeightTrackAndCAMetadata() throws {
        let ids = (0..<30).map { _ in UUID() }
        func items(rowHeight: CGFloat) -> [CoreListItem] {
            ids.enumerated().map { index, id in
                ContentResizableItem(
                    id: id,
                    contentHeight: index == 0 ? rowHeight : 50
                )
            }
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: items(rowHeight: 50),
            preloadMargin: 0,
            emitsCA: true
        )
        let identity = ids[0]
        // See the sibling rebind test: a clock at 0 cannot distinguish an implicit origin from the
        // track's own clock. The closing assertion compares against `original.value(at: clock.now)`,
        // so it self-adjusts, and `bounds.height == 100` is settled geometry.
        fixture.advance(by: 2)
        fixture.apply(items(rowHeight: 100), duration: 8)
        let original = try XCTUnwrap(fixture.heightTrack(identity: identity))
        let originalAnimation = try XCTUnwrap(
            fixture.view(identity: identity)?.layer.animation(
                forKey: "CoreListAnimation.height"
            )
        )
        fixture.advance(by: 1)
        fixture.scroll(to: 300)
        fixture.advance(by: 1)

        fixture.scroll(to: 0)

        let rebound = try XCTUnwrap(fixture.view(identity: identity))
        let reboundAnimation = try XCTUnwrap(
            rebound.layer.animation(forKey: "CoreListAnimation.height")
        )
        XCTAssertEqual(fixture.heightTrack(identity: identity), original)
        XCTAssertEqual(rebound.layer.bounds.height, 100, accuracy: 1e-9)
        // The original install is commit-resolved and this fixture never commits, so it carries no
        // origin at all; the rebind, which must resume mid-phase, falls back to the model's clock.
        XCTAssertEqual(originalAnimation.beginTime, 0,
                       "the original install is commit-resolved")
        XCTAssertEqual(reboundAnimation.beginTime, original.startTime)
        XCTAssertTrue(reboundAnimation.coreListPreservesPhase)
        XCTAssertEqual(reboundAnimation.duration, originalAnimation.duration)
        XCTAssertEqual(
            (reboundAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            original.generation
        )
        XCTAssertEqual(try XCTUnwrap(fixture.visualHeight(identity: identity)),
                       original.value(at: fixture.clock.now), accuracy: 1e-9)
    }

    func testOffscreenChangedHeightReconcilesStoredHeightWithoutActiveHeightTrack() throws {
        let ids = (0..<30).map { _ in UUID() }
        func items(includeFirst: Bool = true, rowHeight: CGFloat) -> [CoreListItem] {
            ids.enumerated().compactMap { index, id in
                guard includeFirst || index != 0 else { return nil }
                return ContentResizableItem(
                    id: id,
                    contentHeight: index == 1 ? rowHeight : 50
                )
            }
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: items(rowHeight: 50),
            preloadMargin: 0,
            emitsCA: true
        )
        let identity = ids[1]
        fixture.apply(items(includeFirst: false, rowHeight: 50), duration: 8)
        fixture.advance(by: 1)
        let positionBefore = try XCTUnwrap(fixture.positionTrack(identity: identity))
        XCTAssertNil(fixture.heightTrack(identity: identity))
        fixture.scroll(to: 300)

        fixture.apply(items(includeFirst: false, rowHeight: 90), duration: 4)
        fixture.scroll(to: 0)

        let rebound = try XCTUnwrap(fixture.view(identity: identity))
        XCTAssertEqual(rebound.layer.bounds.height, 90, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.visualHeight(identity: identity)),
                       90, accuracy: 1e-9)
        XCTAssertNil(fixture.heightTrack(identity: identity))
        XCTAssertNil(rebound.layer.animation(forKey: "CoreListAnimation.height"))
        XCTAssertEqual(fixture.positionTrack(identity: identity), positionBefore)
    }

    func testOffscreenStructuralPredecessorChangeSafelySettlesOnlyPositionBeforeRebind() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: idItems(Array(0..<30)),
            preloadMargin: 0,
            emitsCA: true
        )
        fixture.apply(idItems([0, 99] + Array(1..<30)), duration: 8)
        fixture.apply(idItems([99] + Array(1..<30)), duration: 4)
        fixture.advance(by: 1)
        let opacityBefore = try XCTUnwrap(fixture.opacityTrack(identity: 99))
        XCTAssertNotNil(fixture.positionTrack(identity: 99))
        fixture.scroll(to: 250)
        XCTAssertNil(fixture.view(identity: 99))

        fixture.apply(idItems([100, 99] + Array(1..<30)), duration: 4)

        XCTAssertNil(fixture.positionTrack(identity: 99),
                     "an offscreen changed endpoint safely settles instead of rebinding stale correction")
        XCTAssertEqual(fixture.opacityTrack(identity: 99), opacityBefore,
                       "safe settlement is property-granular and cannot restart opacity")
        fixture.scroll(to: 0)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 99)),
                       try XCTUnwrap(fixture.settledScreenY(identity: 99)),
                       accuracy: 1e-9)
        XCTAssertEqual(fixture.opacityTrack(identity: 99), opacityBefore)
    }

    func testOffscreenPredecessorChangeSettlesBeforeSamePassReentry() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: idItems(Array(0..<30)),
            preloadMargin: 0,
            emitsCA: true
        )
        fixture.apply(idItems([0, 99] + Array(1..<30)), duration: 8)
        fixture.apply(idItems([99] + Array(1..<30)), duration: 4)
        fixture.advance(by: 1)
        let opacityBefore = try XCTUnwrap(fixture.opacityTrack(identity: 99))
        fixture.scroll(to: 250)
        XCTAssertNil(fixture.view(identity: 99))
        XCTAssertNotNil(fixture.positionTrack(identity: 99))

        fixture.listView.applyChanges(
            items: idItems([100, 99] + Array(1..<30)),
            scrollTo: .init(index: 1, pointOffset: 0),
            transition: .easeInOut(duration: 4)
        )

        XCTAssertNotNil(fixture.view(identity: 99))
        XCTAssertNil(fixture.positionTrack(identity: 99),
                     "safe settlement must precede same-pass rebind")
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 99)),
                       try XCTUnwrap(fixture.settledScreenY(identity: 99)),
                       accuracy: 1e-9)
        XCTAssertEqual(fixture.opacityTrack(identity: 99), opacityBefore,
                       "same-pass settlement cannot restart opacity")
    }

    func testOffscreenUnchangedPredecessorsKeepOriginalPositionAndOpacityDeadlines() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: idItems(Array(0..<30)),
            preloadMargin: 0,
            emitsCA: true
        )
        fixture.apply(idItems([0, 99] + Array(1..<30)), duration: 8)
        fixture.apply(idItems([99] + Array(1..<30)), duration: 4)
        fixture.advance(by: 1)
        let positionBefore = try XCTUnwrap(fixture.positionTrack(identity: 99))
        let opacityBefore = try XCTUnwrap(fixture.opacityTrack(identity: 99))
        fixture.scroll(to: 250)

        fixture.apply(idItems([99] + Array(1..<30) + [100]), duration: 4)

        XCTAssertEqual(fixture.positionTrack(identity: 99), positionBefore)
        XCTAssertEqual(fixture.opacityTrack(identity: 99), opacityBefore)
        fixture.scroll(to: 0)
        XCTAssertEqual(fixture.positionTrack(identity: 99), positionBefore)
        XCTAssertEqual(fixture.opacityTrack(identity: 99), opacityBefore)
    }

    func testScrollSeedsNeverSeenLiveOwnerWithoutCreatingTracks() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: idItems(Array(0..<20)),
            preloadMargin: 0
        )
        XCTAssertNil(fixture.animationController.opacity(owner: .live(5), at: fixture.clock.now))

        fixture.scroll(to: 200)

        XCTAssertNotNil(fixture.view(identity: 5))
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 5)), 1, accuracy: 1e-9)
        XCTAssertNil(fixture.positionTrack(identity: 5))
        XCTAssertNil(fixture.opacityTrack(identity: 5))
    }

    func testLongTraversalPrunesSettledUnboundOwnerState() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: idItems(Array(0..<100)),
            preloadMargin: 0
        )
        var visited = Set<Int>()

        for index in stride(from: 0, to: 100, by: 5) {
            fixture.listView.applyChanges(
                scrollTo: .init(index: index, pointOffset: 0),
                transition: .easeInOut(duration: 0)
            )
            for item in fixture.activeWindow.items {
                visited.insert(item.index)
            }
        }

        XCTAssertGreaterThanOrEqual(visited.count, 80)
        XCTAssertLessThan(fixture.animationController.model.ownerCount, 20,
                          "settled unbound owners must not grow with traversal history")
    }

    func testActiveOffscreenOwnerStateIsRetainedUntilItsTrackSettles() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 200),
            items: idItems(Array(0..<30)),
            preloadMargin: 0
        )
        fixture.apply(idItems(Array(1..<30)), duration: 4)
        fixture.advance(by: 1)
        XCTAssertNotNil(fixture.positionTrack(identity: 1))

        fixture.scroll(to: 250)

        XCTAssertNil(fixture.view(identity: 1))
        XCTAssertTrue(fixture.animationController.model.contains(.live(AnyHashable(1))))
        XCTAssertNotNil(fixture.positionTrack(identity: 1))
    }

    func testDeletionInducedSurvivorShiftStartsAtExactPrePassVisibleY() throws {
        let fixture = VirtualListFixture(items: idItems(Array(0..<20)))
        let before = try XCTUnwrap(fixture.screenY(identity: 1))

        fixture.apply(idItems(Array(1..<20)), duration: 4)

        XCTAssertEqual(before, 50, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: 1)), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 1)), before, accuracy: 1e-9)
        let track = try XCTUnwrap(fixture.positionTrack(identity: 1))
        XCTAssertEqual(track.from, 50, accuracy: 1e-9)
        XCTAssertEqual(track.to, 0, accuracy: 1e-9)
    }

    func testChangedTargetRetargetsFromExactAnalyticCurrentVisibleY() throws {
        let fixture = VirtualListFixture(items: idItems(Array(0..<20)))
        fixture.apply(idItems(Array(1..<20)), duration: 4)
        fixture.advance(by: 1)
        let before = try XCTUnwrap(fixture.screenY(identity: 2))

        fixture.apply(idItems([1, 99] + Array(2..<20)), duration: 4)

        XCTAssertEqual(before, 93.54190344763401, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: 2)), 100, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 2)), before, accuracy: 1e-9)
        let replacement = try XCTUnwrap(fixture.positionTrack(identity: 2))
        XCTAssertEqual(replacement.from, before - 100, accuracy: 1e-9)
        XCTAssertEqual(replacement.startTime, 1, accuracy: 1e-9)
        XCTAssertEqual(replacement.duration, 4, accuracy: 1e-9)
    }

    func testScrollToParkingRebaseRetargetsFromExactHalfwayVisibleY() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: idItems(Array(0..<40)),
            preloadMargin: 100
        )
        fixture.apply(idItems(Array(1..<40)), duration: 4)
        fixture.advance(by: 2)
        let before = try XCTUnwrap(fixture.screenY(identity: 2))

        fixture.listView.applyChanges(
            scrollTo: .init(index: 1, pointOffset: 100),
            transition: .easeInOut(duration: 4)
        )

        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 2)), before, accuracy: 1e-6)
        let replacement = try XCTUnwrap(fixture.positionTrack(identity: 2))
        XCTAssertLessThan(abs(replacement.from), fixture.listView.logicalSize.height)
    }

    func testStructuralParkingRebaseRetargetsFromExactHalfwayVisibleY() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: idItems(Array(0..<40)),
            preloadMargin: 100
        )
        fixture.listView.applyChanges(
            scrollTo: .init(index: 10, pointOffset: 100),
            transition: .easeInOut(duration: 0)
        )
        fixture.apply(idItems(Array(0..<10) + Array(11..<40)), duration: 4)
        fixture.advance(by: 2)
        let before = try XCTUnwrap(fixture.screenY(identity: 12))

        fixture.apply(idItems(Array(11..<40)), duration: 4)

        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 12)), before, accuracy: 1e-6)
        let replacement = try XCTUnwrap(fixture.positionTrack(identity: 12))
        XCTAssertLessThan(abs(replacement.from), fixture.listView.logicalSize.height)
    }

    func testUnchangedSettledTargetPreservesPositionTrackExactly() throws {
        let current = idItems(Array(1..<20))
        let fixture = VirtualListFixture(items: idItems(Array(0..<20)))
        fixture.apply(current, duration: 4)
        fixture.advance(by: 1)
        let before = try XCTUnwrap(fixture.positionTrack(identity: 1))

        fixture.apply(current, duration: 20)

        XCTAssertEqual(fixture.positionTrack(identity: 1), before)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 1)), 43.541903447634006, accuracy: 1e-9)
    }

    func testDelayedSwapTwoThroughFiveReusesViewsAndOnlyMovedRowsGetTracks() throws {
        let source = idItems(Array(0..<8))
        let fixture = VirtualListFixture(items: source)
        let oldViews = Dictionary(uniqueKeysWithValues: (0..<8).map {
            ($0, fixture.view(identity: $0)!)
        })
        var reordered = Array(0..<8)
        let moved = reordered.remove(at: 2)
        reordered.insert(moved, at: 5)

        fixture.apply(idItems(reordered), duration: 4)

        for identity in 0..<8 {
            XCTAssertTrue(fixture.view(identity: identity) === oldViews[identity])
            XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: identity)), 1, accuracy: 1e-9)
        }
        for identity in [2, 3, 4, 5] {
            XCTAssertNotNil(fixture.positionTrack(identity: identity))
            XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: identity)),
                           CGFloat(identity * 50), accuracy: 1e-9)
        }
        for identity in [0, 1, 6, 7] {
            XCTAssertNil(fixture.positionTrack(identity: identity))
        }
    }

    func testRepeatedSwapReplacesOnlyChangedPositionTracks() throws {
        let source = idItems(Array(0..<8))
        let fixture = VirtualListFixture(items: source)
        let oldViews = Dictionary(uniqueKeysWithValues: (0..<8).map {
            ($0, fixture.view(identity: $0)!)
        })
        var reordered = Array(0..<8)
        let moved = reordered.remove(at: 2)
        reordered.insert(moved, at: 5)
        fixture.apply(idItems(reordered), duration: 4)
        fixture.advance(by: 1)
        var firstTracks: [Int: ListAnimationTrack] = [:]
        for identity in [2, 3, 4, 5] {
            firstTracks[identity] = try XCTUnwrap(fixture.positionTrack(identity: identity))
        }

        fixture.apply(source, duration: 4)

        for identity in [2, 3, 4, 5] {
            let replacement = try XCTUnwrap(fixture.positionTrack(identity: identity))
            XCTAssertNotEqual(replacement.generation, firstTracks[identity]?.generation)
            XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: identity)), 1, accuracy: 1e-9)
            XCTAssertTrue(fixture.view(identity: identity) === oldViews[identity])
        }
        for identity in [0, 1, 6, 7] {
            XCTAssertNil(fixture.positionTrack(identity: identity))
        }
    }

    func testContentResizeRetargetsAffectedMoveTrackContinuously() throws {
        let ids = (0..<8).map { _ in UUID() }
        var reordered = ids
        let moved = reordered.remove(at: 2)
        reordered.insert(moved, at: 5)
        var items = reordered.map { ContentResizableItem(id: $0, contentHeight: 50) }
        let fixture = VirtualListFixture(
            items: ids.map { ContentResizableItem(id: $0, contentHeight: 50) }
        )
        fixture.apply(items, duration: 4)
        fixture.advance(by: 1)
        let before = try XCTUnwrap(fixture.positionTrack(identity: moved))
        let beforeY = try XCTUnwrap(fixture.screenY(identity: moved))
        items[0] = ContentResizableItem(id: items[0].id, contentHeight: 90)

        fixture.apply(items, duration: 3)

        XCTAssertEqual(try XCTUnwrap(fixture.frame(identity: items[0].id)).height, 90)
        let replacement = try XCTUnwrap(fixture.positionTrack(identity: moved))
        XCTAssertNotEqual(replacement.generation, before.generation)
        XCTAssertEqual(replacement.from, -170.62571034290204, accuracy: 1e-9)
        XCTAssertEqual(replacement.startTime, 1, accuracy: 1e-9)
        XCTAssertEqual(replacement.duration, 3, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: moved)), beforeY, accuracy: 1e-9)
    }

    func testEqualHeightSwapThenDelayedTopMovedRowGrowthComposesEveryChangedProperty() throws {
        let ids = (0..<8).map { _ in UUID() }
        func items(_ order: [Int], grownIdentity: Int? = nil) -> [CoreListItem] {
            order.map { index in
                ContentResizableItem(id: ids[index],
                                     contentHeight: index == grownIdentity ? 100 : 75)
            }
        }
        let reordered = [0, 4, 2, 3, 1, 5, 6, 7]
        let fixture = VirtualListFixture(items: items(Array(0..<8)), emitsCA: true)
        fixture.apply(items(reordered), duration: 4)
        fixture.advance(by: 1)

        XCTAssertNotNil(fixture.positionTrack(identity: ids[4]))
        XCTAssertNotNil(fixture.positionTrack(identity: ids[1]))
        XCTAssertNil(fixture.positionTrack(identity: ids[2]))
        XCTAssertNil(fixture.positionTrack(identity: ids[3]))
        let movedPosition = try XCTUnwrap(fixture.positionTrack(identity: ids[4]))
        let movedPositionAnimation = try XCTUnwrap(
            fixture.view(identity: ids[4])?.layer.animation(
                forKey: "CoreListAnimation.positionY"
            )
        )
        let beforeTwo = try XCTUnwrap(fixture.screenY(identity: ids[2]))
        let beforeThree = try XCTUnwrap(fixture.screenY(identity: ids[3]))

        fixture.apply(items(reordered, grownIdentity: 4), duration: 3)

        XCTAssertEqual(fixture.positionTrack(identity: ids[4]), movedPosition,
                       "an unchanged position target must remain an exact no-op")
        let preservedPositionAnimation = try XCTUnwrap(
            fixture.view(identity: ids[4])?.layer.animation(
                forKey: "CoreListAnimation.positionY"
            )
        )
        // `beginTime` no longer witnesses non-replacement (it is commit-resolved); the exact
        // generation equality below does.
        XCTAssertEqual(preservedPositionAnimation.duration, movedPositionAnimation.duration)
        XCTAssertEqual(
            (preservedPositionAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (movedPositionAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )

        XCTAssertEqual(try XCTUnwrap(fixture.frame(identity: ids[4])).height, 100)
        XCTAssertEqual(try XCTUnwrap(fixture.visualHeight(identity: ids[4])), 75,
                       accuracy: 1e-9)
        let height = try XCTUnwrap(fixture.heightTrack(identity: ids[4]))
        XCTAssertEqual(height.from, 75, accuracy: 1e-9)
        XCTAssertEqual(height.to, 100, accuracy: 1e-9)
        XCTAssertEqual(height.startTime, 1, accuracy: 1e-9)
        XCTAssertEqual(height.duration, 3, accuracy: 1e-9)

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: ids[2])),
                       175, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: ids[3])),
                       250, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: ids[2])),
                       beforeTwo, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: ids[3])),
                       beforeThree, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.positionTrack(identity: ids[2])).from,
                       -25, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.positionTrack(identity: ids[3])).from,
                       -25, accuracy: 1e-9)
        XCTAssertNotNil(fixture.positionTrack(identity: ids[5]),
                        "every loaded survivor shifted by the growth must animate")
    }

    func testSelfResizeAnimatesVisualHeightAndDoesNotClearUnrelatedMoveTrack() throws {
        let selfID = UUID()
        let source: [CoreListItem] = idItems(Array(1..<10))
            + [SelfUpdatingItem(id: selfID, initialHeight: 50)]
        let fixture = VirtualListFixture(items: source)
        let reordered: [CoreListItem] = idItems([1, 3, 4, 5, 2, 6, 7, 8, 9])
            + [SelfUpdatingItem(id: selfID, initialHeight: 50)]
        fixture.apply(reordered, duration: 4)
        fixture.advance(by: 1)
        let before = try XCTUnwrap(fixture.positionTrack(identity: 2))
        let beforeY = try XCTUnwrap(fixture.screenY(identity: 2))
        let view = try XCTUnwrap(fixture.view(identity: selfID) as? SelfUpdatingItemView)

        view.simulateContentChange(newHeight: 90, animated: true)
        fixture.flushScheduler()

        XCTAssertEqual(try XCTUnwrap(fixture.frame(identity: selfID)).height, 90)
        XCTAssertEqual(try XCTUnwrap(fixture.visualHeight(identity: selfID)), 50,
                       accuracy: 1e-9)
        let height = try XCTUnwrap(fixture.heightTrack(identity: selfID))
        XCTAssertEqual(height.from, 50, accuracy: 1e-9)
        XCTAssertEqual(height.to, 90, accuracy: 1e-9)
        XCTAssertEqual(height.duration, fixture.listView.defaultDirtyDuration, accuracy: 1e-9)
        XCTAssertEqual(fixture.positionTrack(identity: 2), before)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 2)), beforeY, accuracy: 1e-9)
    }

    func testNewSizeRetargetsAffectedMoveTrackContinuously() throws {
        let ids = (0..<10).map { _ in UUID() }
        let source: [CoreListItem] = ids.map {
            IdentifiableWidthDependentItem(id: $0, baseHeight: 50, baseWidth: 390)
        }
        var reorderedIDs = ids
        let moved = reorderedIDs.remove(at: 2)
        reorderedIDs.insert(moved, at: 5)
        let reordered: [CoreListItem] = reorderedIDs.map {
            IdentifiableWidthDependentItem(id: $0, baseHeight: 50, baseWidth: 390)
        }
        let fixture = VirtualListFixture(items: source)
        fixture.apply(reordered, duration: 4)
        fixture.advance(by: 1)
        let before = try XCTUnwrap(fixture.positionTrack(identity: moved))
        let beforeY = try XCTUnwrap(fixture.screenY(identity: moved))

        fixture.listView.applyChanges(newSize: CGSize(width: 195, height: 800),
                                      transition: .easeInOut(duration: 3))

        XCTAssertEqual(try XCTUnwrap(fixture.frame(identity: moved)).height, 100)
        let replacement = try XCTUnwrap(fixture.positionTrack(identity: moved))
        XCTAssertNotEqual(replacement.generation, before.generation)
        XCTAssertEqual(replacement.from, -380.62571034290204, accuracy: 1e-9)
        XCTAssertEqual(replacement.startTime, 1, accuracy: 1e-9)
        XCTAssertEqual(replacement.duration, 3, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: moved)), beforeY, accuracy: 1e-9)
    }

    func testDelayedUnequalHeightResizeRetargetsEveryChangedEndpointContinuously() throws {
        let ids = (1...8).map {
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))!
        }
        let heights: [CGFloat] = [40, 60, 80, 100, 70, 90, 110, 120]
        func items(_ order: [Int], heightsByID: [CGFloat] = heights) -> [CoreListItem] {
            order.map {
                ContentResizableItem(id: ids[$0], contentHeight: heightsByID[$0])
            }
        }

        let fixture = VirtualListFixture(items: items(Array(0..<8)), emitsCA: true)
        let reordered = [0, 4, 2, 3, 1, 5, 6, 7]
        fixture.apply(items(reordered), duration: 4)
        fixture.advance(by: 1)

        let sameTargetTrack = try XCTUnwrap(fixture.positionTrack(identity: ids[4]))
        let sameTargetAnimation = try XCTUnwrap(
            fixture.view(identity: ids[4])?.layer.animation(
                forKey: "CoreListAnimation.positionY"
            )
        )
        let before = [1, 2, 3].map { fixture.screenY(identity: ids[$0])! }
        XCTAssertEqual(before[0], 72.29048276182996, accuracy: 1e-9)
        XCTAssertEqual(before[1], 101.2916193104732, accuracy: 1e-9)
        XCTAssertEqual(before[2], 181.2916193104732, accuracy: 1e-9)

        var resizedHeights = heights
        resizedHeights[4] = 100
        resizedHeights[1] = 50
        fixture.apply(items(reordered, heightsByID: resizedHeights), duration: 3)

        XCTAssertEqual(fixture.positionTrack(identity: ids[4]), sameTargetTrack,
                       "an active owner whose settled target is unchanged is a strict no-op")
        let preservedAnimation = try XCTUnwrap(
            fixture.view(identity: ids[4])?.layer.animation(
                forKey: "CoreListAnimation.positionY"
            )
        )
        let grownHeight = try XCTUnwrap(fixture.heightTrack(identity: ids[4]))
        XCTAssertEqual(grownHeight.from, 70, accuracy: 1e-9)
        XCTAssertEqual(grownHeight.to, 100, accuracy: 1e-9)
        let shrunkHeight = try XCTUnwrap(fixture.heightTrack(identity: ids[1]))
        XCTAssertEqual(shrunkHeight.from, 60, accuracy: 1e-9)
        XCTAssertEqual(shrunkHeight.to, 50, accuracy: 1e-9)
        XCTAssertEqual(
            (preservedAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (sameTargetAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )

        let expectedSettled: [CGFloat] = [320, 140, 220]
        let expectedFrom: [CGFloat] = [-247.70951723817004, -38.70838068952679, -38.708380689526805]
        for (ordinal, identityIndex) in [1, 2, 3].enumerated() {
            let identity = ids[identityIndex]
            XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)),
                           expectedSettled[ordinal], accuracy: 1e-9)
            XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: identity)),
                           before[ordinal], accuracy: 1e-9,
                           "the analytic visible position must be C0-continuous")

            let replacement = try XCTUnwrap(fixture.positionTrack(identity: identity))
            XCTAssertEqual(replacement.from, expectedFrom[ordinal], accuracy: 1e-9)
            XCTAssertEqual(replacement.startTime, 1, accuracy: 1e-9)
            XCTAssertEqual(replacement.duration, 3, accuracy: 1e-9)

            let animation = try XCTUnwrap(
                fixture.view(identity: identity)?.layer.animation(
                    forKey: "CoreListAnimation.positionY"
                )
            )
            XCTAssertEqual(try XCTUnwrap(try keyframeValues(animation).first),
                           expectedFrom[ordinal], accuracy: 1e-9,
                           "the replacement CA correction must start at the analytic boundary")
            // The full-pipeline lock for the new convention: a track minted in this pass declares
            // the pass clock (1) and leaves its origin to the commit.
            XCTAssertEqual(animation.beginTime, 0, accuracy: 1e-9,
                           "a track minted in this pass leaves its origin to the commit")
            XCTAssertEqual(try XCTUnwrap(animation.coreListDeclaredStartTime), 1, accuracy: 1e-9)
            XCTAssertFalse(animation.coreListPreservesPhase)
            XCTAssertEqual(animation.duration, 3, accuracy: 1e-9)
        }

        let newlyAffected = try XCTUnwrap(fixture.positionTrack(identity: ids[5]))
        XCTAssertEqual(newlyAffected.from, -20, accuracy: 1e-9)
        XCTAssertEqual(newlyAffected.startTime, 1, accuracy: 1e-9)
        XCTAssertEqual(newlyAffected.duration, 3, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: ids[5])), 350, accuracy: 1e-9,
                       "a newly affected owner must remain C0-continuous")
    }

    func testContiguousDeparturesFormOneRigidGhostBlock() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3, 4]))
        let first = try XCTUnwrap(fixture.view(identity: 1))
        let second = try XCTUnwrap(fixture.view(identity: 2))
        let firstY = try XCTUnwrap(fixture.screenY(identity: 1))
        let secondY = try XCTUnwrap(fixture.screenY(identity: 2))

        fixture.apply(idItems([0, 3, 4]), duration: 8)

        XCTAssertEqual(fixture.ghostBlocks.count, 1)
        XCTAssertTrue(fixture.driver.isExitMember(first))
        XCTAssertTrue(fixture.driver.isExitMember(second))
        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: first)),
                       firstY, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: second)),
                       secondY, accuracy: 1e-9)
        XCTAssertEqual(second.frame.minY - first.frame.minY,
                       secondY - firstY, accuracy: 1e-9)
    }

    func testDisjointDeparturesFormSeparateBlocks() {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3, 4]))

        fixture.apply(idItems([0, 2, 4]), duration: 8)

        XCTAssertEqual(fixture.ghostBlocks.count, 2)
        XCTAssertEqual(fixture.driver.exitSubviews.count, 2)
    }

    func testDepartureAboveAnchorAttachesGhostMaxYToSuccessorMinY() throws {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 200),
                                         items: idItems([0, 1, 2, 3, 4]),
                                         preloadMargin: 100)
        fixture.scroll(to: 50)

        fixture.apply(idItems([1, 2, 3, 4]), duration: 8)

        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        let successorY = try XCTUnwrap(fixture.settledContentY(identity: 1))
        XCTAssertEqual(block.attachmentEdge, .maxY)
        XCTAssertEqual(block.witness, .liveMinY(AnyHashable(1)))
        XCTAssertEqual(block.settledRootY + block.localMaxY, successorY,
                       accuracy: 1e-9)
        XCTAssertNil(fixture.ghostBlockTrack(block.id),
                     "an already aligned ghost must not animate downward")
    }

    func testTailDepartureUsesLastLiveMaxY() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2]))

        fixture.apply(idItems([0, 1]), duration: 8)

        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        XCTAssertEqual(block.witness, .liveMaxY(AnyHashable(1)))
    }

    func testAmbiguousMovedOrdinalFormsWitnessTowardAnchorAbove() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3, 4, 5]))

        fixture.apply(idItems([0, 1, 5, 3, 4]), duration: 8)

        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        XCTAssertEqual(block.witness, .liveMaxY(AnyHashable(1)))
    }

    func testAmbiguousMovedOrdinalFormsWitnessTowardAnchorBelow() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 100),
            items: idItems([0, 1, 2, 3, 4, 5]),
            preloadMargin: 60
        )
        fixture.listView.applyChanges(
            scrollTo: .init(index: 3, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: 3)), 0, accuracy: 1e-9)
        XCTAssertNotNil(fixture.view(identity: 2))

        fixture.apply(idItems([0, 1, 5, 3, 4]), duration: 8)

        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        XCTAssertEqual(block.witness, .liveMinY(AnyHashable(3)))
    }

    func testOlderWitnessHandsToResolvedAmbiguousNewBlockAtExactSettledEdge() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3, 4, 5]))
        fixture.apply(idItems([0, 9, 2, 3, 4, 5]), duration: 30)
        let older = try XCTUnwrap(fixture.ghostBlocks.first)

        fixture.apply(idItems([0, 8, 9, 2, 3, 4, 5]), duration: 0)
        fixture.apply(idItems([0, 9, 2, 3, 4, 5]), duration: 12)
        fixture.advance(by: 1)
        XCTAssertNotNil(fixture.positionTrack(identity: 9))
        XCTAssertNotEqual(try XCTUnwrap(fixture.screenY(identity: 9)),
                          try XCTUnwrap(fixture.settledScreenY(identity: 9)),
                          accuracy: 1e-6,
                          "the departing carrier must have an active sampled correction")
        let existingBlockIDs = Set(fixture.ghostBlocks.map(\.id))

        fixture.apply(idItems([0, 5, 2, 3, 4]), duration: 4)

        let newer = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { !existingBlockIDs.contains($0.id) })
        )
        XCTAssertEqual(newer.witness, .liveMaxY(AnyHashable(0)))
        let updatedOlder = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == older.id })
        )
        XCTAssertEqual(updatedOlder.witness, .ghostMinY(newer.id))
        XCTAssertEqual(updatedOlder.settledRootY,
                       newer.settledRootY + newer.localMinY,
                       accuracy: 1e-9)
        let anchorMaxY = try XCTUnwrap(fixture.settledContentY(identity: 0))
            + (try XCTUnwrap(fixture.frame(identity: 0))).height
        XCTAssertEqual(updatedOlder.settledRootY,
                       anchorMaxY,
                       accuracy: 1e-9)
    }

    func testGhostRidesRetainedBoundaryWhenLaterChangeOccursAbove() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3]))
        let outgoing = try XCTUnwrap(fixture.view(identity: 1))
        fixture.apply(idItems([0, 9, 2, 3]), duration: 10)
        fixture.advance(by: 1)
        let boundary = try XCTUnwrap(fixture.ghostBlocks.first)
        let before = try XCTUnwrap(fixture.driver.exitScreenY(view: outgoing))

        fixture.apply(idItems([0, 8, 9, 2, 3]), duration: 2)

        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: outgoing)),
                       before, accuracy: 1e-9)
        fixture.advance(by: 2)
        XCTAssertEqual(try XCTUnwrap(fixture.driver.ghostBlockScreenY(boundary.id)),
                       try XCTUnwrap(fixture.settledScreenY(identity: 9)),
                       accuracy: 1e-6)
    }

    func testUnchangedGhostBoundaryPreservesExactTrack() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2]))
        fixture.apply(idItems([0, 9, 2]), duration: 12)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        fixture.apply(idItems([0, 8, 9, 2]), duration: 8)
        let original = try XCTUnwrap(fixture.ghostBlockTrack(block.id))

        fixture.listView.applyChanges(newSize: fixture.listView.logicalSize,
                                      transition: .easeInOut(duration: 1))

        XCTAssertEqual(fixture.ghostBlockTrack(block.id), original)
    }

    func testZeroDurationLaterBoundaryChangeSnapsGhost() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3]))
        fixture.apply(idItems([0, 9, 2, 3]), duration: 10)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)

        fixture.apply(idItems([0, 8, 9, 2, 3]), duration: 0)

        XCTAssertNil(fixture.ghostBlockTrack(block.id))
        XCTAssertEqual(try XCTUnwrap(fixture.driver.ghostBlockScreenY(block.id)),
                       try XCTUnwrap(fixture.settledScreenY(identity: 9)),
                       accuracy: 1e-6)
    }

    func testRetainedMaxYBoundaryFollowsWitnessHeightChange() throws {
        let ids = [UUID(), UUID(), UUID()]
        func items(_ included: [Int], middleHeight: CGFloat) -> [CoreListItem] {
            included.map { index in
                ContentResizableItem(id: ids[index],
                                     contentHeight: index == 1 ? middleHeight : 75)
            }
        }
        let fixture = VirtualListFixture(items: items([0, 1, 2], middleHeight: 75))
        fixture.apply(items([0, 1], middleHeight: 75), duration: 10)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)

        fixture.apply(items([0, 1], middleHeight: 100), duration: 2)
        fixture.advance(by: 2)

        let witnessTop = try XCTUnwrap(fixture.settledScreenY(identity: ids[1]))
        XCTAssertEqual(try XCTUnwrap(fixture.driver.ghostBlockScreenY(block.id)),
                       witnessTop + 100, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == block.id })
        ).witness, .liveMaxY(AnyHashable(ids[1])))
    }

    func testRemovedWitnessHandsOlderBlockToNewGhostAtExactBoundary() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3, 4]))
        fixture.apply(idItems([0, 3, 4]), duration: 12)
        fixture.advance(by: 1)
        let older = try XCTUnwrap(fixture.ghostBlocks.first)

        fixture.apply(idItems([0, 4]), duration: 4)

        let updatedOlder = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == older.id })
        )
        guard case let .ghostMinY(newerID) = updatedOlder.witness else {
            return XCTFail("expected exact-boundary ghost handoff")
        }
        XCTAssertNotEqual(newerID, older.id)
    }

    func testRemovedWitnessHandsOffExactlyAcrossStructuralRebase() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 100),
            items: idItems(Array(0..<30)),
            preloadMargin: 0
        )
        fixture.listView.applyChanges(
            scrollTo: .init(index: 10, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        fixture.apply(idItems(Array(0..<10) + Array(11..<30)), duration: 12)
        fixture.advance(by: 1)
        let older = try XCTUnwrap(fixture.ghostBlocks.first)
        let before = try XCTUnwrap(fixture.driver.ghostBlockScreenY(older.id))

        fixture.apply(idItems([9, 12]), duration: 4)

        XCTAssertEqual(fixture.boundsOriginY, 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.driver.ghostBlockScreenY(older.id)),
                       before, accuracy: 1e-6)
        let updatedOlder = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == older.id })
        )
        guard case let .ghostMinY(newerID) = updatedOlder.witness else {
            return XCTFail("expected exact-boundary ghost handoff after rebase")
        }
        XCTAssertNotEqual(newerID, older.id)
    }

    func testMovedWitnessMigratesTowardCurrentPassAnchor() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3, 4]))
        fixture.apply(idItems([0, 9, 2, 3, 4]), duration: 12)
        fixture.advance(by: 1)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)

        fixture.apply(idItems([0, 2, 3, 9, 4]), duration: 4)

        let migrated = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == block.id })
        )
        XCTAssertNotEqual(migrated.witness, .liveMinY(AnyHashable(9)))
        XCTAssertEqual(migrated.witness, .liveMaxY(AnyHashable(0)))
    }

    func testMovedWitnessUsesOppositeEdgeWhenCurrentPassAnchorIsBelowAcrossRebase() throws {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 200),
                                         items: idItems([0, 1, 2, 3, 4, 5]),
                                         preloadMargin: 160)
        fixture.scroll(to: 225)
        fixture.apply(idItems([0, 9, 2, 3, 4, 5]), duration: 12)
        fixture.advance(by: 1)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        let oldBoundsOriginY = fixture.boundsOriginY

        fixture.apply(idItems([0, 2, 3, 4, 9, 5]), duration: 4)

        let migrated = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == block.id })
        )
        XCTAssertNotEqual(fixture.boundsOriginY, oldBoundsOriginY, accuracy: 1e-9)
        XCTAssertEqual(migrated.witness, .liveMinY(AnyHashable(0)))
    }

    func testReferencedInvisibleBlockOutlivesMembersUntilDependentFinishes() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3, 4]))
        fixture.apply(idItems([0, 3, 4]), duration: 12)
        fixture.advance(by: 1)
        let older = try XCTUnwrap(fixture.ghostBlocks.first)
        fixture.apply(idItems([0, 4]), duration: 2)
        let newer = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id != older.id })
        )

        fixture.advance(by: 2)

        XCTAssertTrue(fixture.ghostBlocks.contains { $0.id == newer.id })
        XCTAssertEqual(try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == newer.id })
        ).visibleMemberCount, 0)

        fixture.advance(by: 9)
        XCTAssertTrue(fixture.ghostBlocks.isEmpty)
    }

    func testPureUserScrollMovesGhostAsParentWithoutReplacingBlockTrack() throws {
        let fixture = VirtualListFixture(itemCount: 20, itemHeight: 75)
        let outgoing = try XCTUnwrap(fixture.view(identity: fixture.listView.items[2].identity))
        var next = fixture.listView.items
        next.remove(at: 2)
        fixture.apply(next, duration: 10)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        let track = fixture.ghostBlockTrack(block.id)
        let before = try XCTUnwrap(fixture.driver.exitScreenY(view: outgoing))

        fixture.scroll(to: fixture.boundsOriginY + 30)

        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: outgoing)),
                       before - 30, accuracy: 1e-6)
        XCTAssertEqual(fixture.ghostBlockTrack(block.id), track)
    }

    func testCoordinateRebaseShiftsLedgerRootAndPreservesTrack() throws {
        let fixture = VirtualListFixture(itemCount: 40, itemHeight: 75,
                                         viewport: CGSize(width: 390, height: 300),
                                         preloadMargin: 0)
        let outgoing = try XCTUnwrap(fixture.view(identity: fixture.listView.items[1].identity))
        var next = fixture.listView.items
        next.remove(at: 1)
        fixture.apply(next, duration: 10)
        let before = try XCTUnwrap(fixture.ghostBlocks.first)
        let track = fixture.ghostBlockTrack(before.id)
        let screenY = try XCTUnwrap(fixture.driver.exitScreenY(view: outgoing))

        fixture.listView.setBoundsOriginY(fixture.boundsOriginY + 500)

        let after = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == before.id })
        )
        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: outgoing)),
                       screenY, accuracy: 1e-6)
        XCTAssertNotEqual(after.settledRootY, before.settledRootY)
        XCTAssertEqual(fixture.ghostBlockTrack(after.id), track)
    }

    func testPureProgrammaticScrollPreservesWitnessAndBlockTrack() throws {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 300),
                                         items: idItems([0, 1] + Array(10..<28)))
        fixture.apply(idItems([0, 9] + Array(10..<28)), duration: 12)
        fixture.apply(idItems([0, 8, 9] + Array(10..<28)), duration: 8)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        let witness = block.witness
        let track = try XCTUnwrap(fixture.ghostBlockTrack(block.id))

        fixture.listView.applyChanges(scrollTo: .init(index: 10, pointOffset: 100),
                                      transition: .easeInOut(duration: 4))

        let after = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == block.id })
        )
        XCTAssertEqual(after.witness, witness)
        XCTAssertEqual(fixture.ghostBlockTrack(block.id), track)
    }

    func testOffscreenWitnessPreservesExactTrackAcrossSemanticNoOps() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: idItems([0, 1] + Array(10..<28)),
            emitsCA: true
        )
        fixture.apply(idItems([0, 9] + Array(10..<28)), duration: 12)
        fixture.apply(idItems([0, 8, 9] + Array(10..<28)), duration: 8)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        fixture.listView.applyChanges(
            scrollTo: .init(index: 10, pointOffset: 100),
            transition: .easeInOut(duration: 4)
        )
        XCTAssertNil(fixture.view(identity: 9))

        let witness = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == block.id })
        ).witness
        let track = try XCTUnwrap(fixture.ghostBlockTrack(block.id))
        let render = try XCTUnwrap(fixture.listView.ghostRender(for: block.id))
        let key = fixture.animationController.compiler.animationKey(for: .positionY)
        let animation = try XCTUnwrap(render.wrapper.layer.animation(forKey: key))
        let generation = try XCTUnwrap(
            (animation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )

        fixture.listView.applyChanges(
            items: fixture.listView.items,
            transition: .easeInOut(duration: 1)
        )
        fixture.listView.applyChanges(
            newSize: fixture.listView.logicalSize,
            transition: .easeInOut(duration: 1)
        )

        let after = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == block.id })
        )
        XCTAssertEqual(after.witness, witness)
        XCTAssertEqual(fixture.ghostBlockTrack(block.id), track)
        let preserved = try XCTUnwrap(render.wrapper.layer.animation(forKey: key))
        // `beginTime` no longer witnesses non-replacement (it is commit-resolved); the exact
        // generation equality below does.
        XCTAssertEqual(preserved.duration, animation.duration, accuracy: 1e-9)
        XCTAssertEqual(
            (preserved.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            generation
        )
    }

    func testChangedLogicalSizeStillRetargetsExistingGhost() throws {
        let ids = (0..<6).map { _ in UUID() }
        func items(excluding removed: UUID? = nil) -> [CoreListItem] {
            ids.compactMap { id in
                guard id != removed else { return nil }
                return IdentifiableWidthDependentItem(
                    id: id,
                    baseHeight: 50,
                    baseWidth: 390
                )
            }
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items()
        )
        fixture.apply(items(excluding: ids[1]), duration: 12)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        XCTAssertNil(fixture.ghostBlockTrack(block.id))

        fixture.listView.applyChanges(
            newSize: CGSize(width: 195, height: 300),
            transition: .easeInOut(duration: 4)
        )

        let updated = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == block.id })
        )
        XCTAssertEqual(updated.witness, .liveMinY(AnyHashable(ids[2])))
        XCTAssertEqual(updated.settledRootY, 100, accuracy: 1e-9)
        let track = try XCTUnwrap(fixture.ghostBlockTrack(block.id))
        XCTAssertEqual(track.from, -50, accuracy: 1e-9)
        XCTAssertEqual(track.duration, 4, accuracy: 1e-9)
    }

    func testRealDirtyMeasurementStillRetargetsExistingGhost() throws {
        let selfID = UUID()
        let source: [CoreListItem] = [
            SelfUpdatingItem(id: selfID, initialHeight: 50),
            IDItem(id: 1, height: 50),
            IDItem(id: 2, height: 50),
            IDItem(id: 3, height: 50),
        ]
        let fixture = VirtualListFixture(items: source)
        let survivors: [CoreListItem] = [
            SelfUpdatingItem(id: selfID, initialHeight: 50),
            IDItem(id: 2, height: 50),
            IDItem(id: 3, height: 50),
        ]
        fixture.apply(survivors, duration: 12)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        XCTAssertNil(fixture.ghostBlockTrack(block.id))
        let view = try XCTUnwrap(
            fixture.view(identity: selfID) as? SelfUpdatingItemView
        )

        view.simulateContentChange(newHeight: 100, animated: true)
        fixture.flushScheduler()

        let updated = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == block.id })
        )
        XCTAssertEqual(updated.witness, .liveMinY(AnyHashable(2)))
        XCTAssertEqual(updated.settledRootY, 100, accuracy: 1e-9)
        let track = try XCTUnwrap(fixture.ghostBlockTrack(block.id))
        XCTAssertEqual(track.from, -50, accuracy: 1e-9)
        XCTAssertEqual(track.duration,
                       fixture.listView.defaultDirtyDuration,
                       accuracy: 1e-9)
    }

    func testMixedItemChangeAndScrollStillResolvesGhostOnce() throws {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 300),
                                         items: idItems([0, 1] + Array(10..<28)))
        fixture.apply(idItems([0, 9] + Array(10..<28)), duration: 12)
        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        let beforeGeneration = fixture.ghostBlockTrack(block.id)?.generation

        fixture.listView.applyChanges(
            items: idItems([0, 8, 9] + Array(10..<28)),
            scrollTo: .init(index: 2, pointOffset: 100),
            transition: .easeInOut(duration: 4)
        )

        let after = try XCTUnwrap(
            fixture.ghostBlocks.first(where: { $0.id == block.id })
        )
        XCTAssertEqual(after.witness, .liveMinY(AnyHashable(9)))
        XCTAssertNotEqual(fixture.ghostBlockTrack(block.id)?.generation,
                          beforeGeneration)
    }

    func testPopulatedToEmptyLeavesOneUnresolvedFrozenBlock() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1]))
        let first = try XCTUnwrap(fixture.view(identity: 0))
        let before = try XCTUnwrap(fixture.screenY(identity: 0))

        fixture.apply([], duration: 8)

        let block = try XCTUnwrap(fixture.ghostBlocks.first)
        XCTAssertEqual(fixture.ghostBlocks.count, 1)
        XCTAssertEqual(block.witness, .unresolved)
        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: first)),
                       before, accuracy: 1e-9)
        XCTAssertNil(fixture.ghostBlockTrack(block.id))
    }

    func testEmptyNoOpRebuildClearsViewportCarriesWhenNoGhostsRemain() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 300),
                                         items: idItems(Array(0..<100)),
                                         preloadMargin: 0)
        fixture.listView.applyChanges(scrollTo: .init(index: 80, pointOffset: 100),
                                      transition: .easeInOut(duration: 10))
        XCTAssertFalse(fixture.viewportCarryViews.isEmpty)

        fixture.apply([], duration: 0)
        XCTAssertTrue(fixture.activeWindow.isEmpty)
        XCTAssertTrue(fixture.ghostBlocks.isEmpty)
        XCTAssertFalse(fixture.viewportCarryViews.isEmpty)

        fixture.apply([], duration: 0)

        XCTAssertTrue(fixture.viewportCarryViews.isEmpty)
        XCTAssertFalse(fixture.hasActiveAnimations)
    }

    func testRemovedRowIsReparentedAtExactCurrentYAndOnlyFades() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3]), emitsCA: true)
        let removedView = try XCTUnwrap(fixture.view(identity: 1))
        let beforeY = try XCTUnwrap(fixture.screenY(identity: 1))

        fixture.apply(idItems([0, 2, 3]), duration: 2)

        XCTAssertTrue(fixture.driver.isExitMember(removedView))
        XCTAssertEqual(fixture.driver.exitOverlay.bounds.size,
                       fixture.listView.engine.contentHost.bounds.size)
        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: removedView)),
                       beforeY, accuracy: 1e-9)
        XCTAssertEqual(removedView.frame.size, CGSize(width: 390, height: 50))
        XCTAssertNil(fixture.driver.exitAnimation(view: removedView, property: .positionY))
        let fade = try XCTUnwrap(
            fixture.driver.exitAnimation(view: removedView, property: .opacity)
        )
        let values = try keyframeValues(fade)
        XCTAssertEqual(try XCTUnwrap(values.first), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(values.last), 0, accuracy: 1e-9)
    }

    func testExitRemainsContinuousAcrossTransactionContentRebase() throws {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: idItems(Array(0..<30)),
            preloadMargin: 100
        )
        let outgoing = try XCTUnwrap(fixture.view(identity: 1))
        let beforeY = try XCTUnwrap(fixture.screenY(identity: 1))
        let changed = idItems([0] + Array(2..<30))

        fixture.listView.applyChanges(
            items: changed,
            scrollTo: .init(index: 10, pointOffset: 100),
            transition: .easeInOut(duration: 4)
        )

        XCTAssertGreaterThan(fixture.boundsOriginY, 1_000_000)
        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: outgoing)),
                       beforeY, accuracy: 1e-9)
    }

    func testExitMirrorsActualClampedEngineShift() throws {
        let clock = SyntheticClock()
        let engine = ClampingScrollEngine()
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { clock.now },
            durationFactor: { 1 }
        )
        let viewport = CGSize(width: 390, height: 300)
        engine.contentHost.frame = CGRect(origin: .zero, size: viewport)
        let list = CoreVirtualListView(
            frame: CGRect(origin: .zero, size: viewport),
            engine: engine,
            animationController: controller,
            scheduler: TestScheduler()
        )
        list.items = idItems([0, 1, 2, 3])
        list.applyChanges(newSize: viewport, transition: .easeInOut(duration: 0))
        let outgoing = try XCTUnwrap(list.activeWindow.items.first { $0.index == 1 }?.view)
        list.applyChanges(items: idItems([0, 2, 3]), transition: .easeInOut(duration: 4))
        let blockID = try XCTUnwrap(list.ghostBlockID(containing: outgoing))
        let beforeRoot = try XCTUnwrap(
            list.ghostBlockSnapshots.first { $0.id == blockID }?.settledRootY
        )
        let before = beforeRoot + outgoing.frame.minY - engine.offset

        list.setBoundsOriginY(500)

        let afterRoot = try XCTUnwrap(
            list.ghostBlockSnapshots.first { $0.id == blockID }?.settledRootY
        )
        XCTAssertEqual(engine.offset, 100, accuracy: 1e-9)
        XCTAssertEqual(afterRoot + outgoing.frame.minY - engine.offset,
                       before, accuracy: 1e-9)
    }

    func testRemovalDuringInsertionStartsAtAnalyticOpacity() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2]), emitsCA: true)
        fixture.apply(idItems([0, 9, 1, 2]), duration: 4)
        fixture.advance(by: 1)
        let removedView = try XCTUnwrap(fixture.view(identity: 9))
        let analyticOpacity = try XCTUnwrap(fixture.opacity(identity: 9))
        let beforeY = try XCTUnwrap(fixture.screenY(identity: 9))

        fixture.apply(idItems([0, 1, 2]), duration: 4)

        XCTAssertEqual(analyticOpacity, 0.12916193104731982, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: removedView)),
                       beforeY, accuracy: 1e-9)
        let fade = try XCTUnwrap(
            fixture.driver.exitAnimation(view: removedView, property: .opacity)
        )
        XCTAssertEqual(try XCTUnwrap(try keyframeValues(fade).first),
                       analyticOpacity, accuracy: 1e-9)
    }

    func testRemovalDuringPositionMotionCapturesAnalyticCurrentY() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3]))
        fixture.apply(idItems([1, 2, 3]), duration: 4)
        fixture.advance(by: 1)
        let outgoing = try XCTUnwrap(fixture.view(identity: 2))
        let analyticY = try XCTUnwrap(fixture.screenY(identity: 2))

        fixture.apply(idItems([1, 3]), duration: 4)

        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: outgoing)),
                       analyticY, accuracy: 1e-9)
    }

    func testRemovalDuringHeightMotionFreezesAnalyticCurrentHeightAndOnlyFades() throws {
        let ids = (0..<3).map { _ in UUID() }
        func items(_ included: [Int], grown: Bool) -> [CoreListItem] {
            included.map { index in
                ContentResizableItem(id: ids[index],
                                     contentHeight: index == 1 && grown ? 100 : 75)
            }
        }
        let fixture = VirtualListFixture(items: items([0, 1, 2], grown: false), emitsCA: true)
        fixture.apply(items([0, 1, 2], grown: true), duration: 4)
        fixture.advance(by: 1)
        let outgoing = try XCTUnwrap(fixture.view(identity: ids[1]))
        let analyticHeight = try XCTUnwrap(fixture.visualHeight(identity: ids[1]))

        fixture.apply(items([0, 2], grown: true), duration: 4)

        XCTAssertEqual(analyticHeight, 78.229048276183, accuracy: 1e-9)
        XCTAssertEqual(outgoing.frame.height, analyticHeight, accuracy: 1e-9)
        XCTAssertNil(fixture.driver.exitAnimation(view: outgoing, property: .height))
        XCTAssertNotNil(fixture.driver.exitAnimation(view: outgoing, property: .opacity))
    }

    func testZeroDurationRemovalTearsDownSynchronously() {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2]))

        fixture.apply(idItems([0, 2]), duration: 0)

        XCTAssertTrue(fixture.driver.exitSubviews.isEmpty)
        XCTAssertFalse(fixture.hasActiveAnimations)
    }

    func testRealCACompletionTearsDownExitWithoutAnalyticReap() throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 300)
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let controller = ListAnimationController(durationFactor: { 1 })
        let list = CoreVirtualListView(
            frame: window.bounds,
            engine: UIKitScrollEngine(),
            animationController: controller,
            scheduler: TestScheduler()
        )
        root.view.addSubview(list)
        list.items = idItems([0, 1, 2])
        list.applyChanges(newSize: window.bounds.size, transition: .easeInOut(duration: 0))
        let outgoing = try XCTUnwrap(list.activeWindow.items.first { $0.index == 1 }?.view)

        list.applyChanges(items: idItems([0, 2]), transition: .easeInOut(duration: 0.05))
        XCTAssertNotNil(list.ghostBlockID(containing: outgoing))
        let deadline = Date(timeIntervalSinceNow: 1)
        while outgoing.superview != nil, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        XCTAssertNil(outgoing.superview,
                     "the Core Animation transaction completion must own exit teardown")
    }

    func testReplacementCrossfadesIndependentOutgoingAndIncomingOwners() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2]), emitsCA: true)
        let outgoing = try XCTUnwrap(fixture.view(identity: 1))
        // A pass clock of 0 makes the declared-clock equality below `0 == 0`; advance so the two
        // fades actually have to agree on something.
        fixture.advance(by: 2)

        fixture.apply(idItems([0, 9, 2]), duration: 3)

        let incoming = try XCTUnwrap(fixture.view(identity: 9))
        XCTAssertFalse(outgoing === incoming)
        XCTAssertTrue(fixture.driver.isExitMember(outgoing))
        XCTAssertTrue(incoming.superview === fixture.listView.container)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 9)), 0, accuracy: 1e-9)
        let outgoingFade = try XCTUnwrap(
            fixture.driver.exitAnimation(view: outgoing, property: .opacity)
        )
        let incomingFade = try XCTUnwrap(
            fixture.driver.exitAnimation(view: incoming, property: .opacity)
        )
        // The two fades belong to one pass, so they declare one phase axis — the claim `beginTime`
        // used to carry, now on the metadata that survives having no commit.
        XCTAssertEqual(try XCTUnwrap(outgoingFade.coreListDeclaredStartTime),
                       try XCTUnwrap(incomingFade.coreListDeclaredStartTime), accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(outgoingFade.coreListDeclaredStartTime),
                       fixture.clock.now, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(try keyframeValues(outgoingFade).first), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(try keyframeValues(outgoingFade).last), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(try keyframeValues(incomingFade).first), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(try keyframeValues(incomingFade).last), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.ghostBlocks.first).attachmentEdge, .minY)
    }

    func testDelayedReplacementPreservesOriginalBoundaryCarrier() throws {
        let fixture = VirtualListFixture(items: idItems(Array(0..<12)))
        fixture.apply(idItems(Array(0..<5) + Array(6..<12)), duration: 0.3)
        fixture.advance(by: 0.1)

        var inserted = fixture.listView.items
        inserted.insert(IDItem(id: 1000, height: 50), at: 5)
        fixture.apply(inserted, duration: 0.3)

        let ghost = try XCTUnwrap(fixture.ghostBlocks.first)
        XCTAssertEqual(ghost.attachmentEdge, .minY)
        XCTAssertEqual(ghost.witness, .liveMinY(AnyHashable(1000)))
        XCTAssertEqual(ghost.settledRootY, 250, accuracy: 1e-9)
    }

    func testReinsertedIdentityUsesDistinctViewAndOldExitCannotRemoveIt() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2]))
        let oldView = try XCTUnwrap(fixture.view(identity: 1))
        fixture.apply(idItems([0, 2]), duration: 4)
        fixture.advance(by: 1)

        fixture.apply(idItems([0, 1, 2]), duration: 4)

        let newView = try XCTUnwrap(fixture.view(identity: 1))
        XCTAssertFalse(oldView === newView)
        XCTAssertTrue(fixture.driver.isExitMember(oldView))
        XCTAssertTrue(newView.superview === fixture.listView.container)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 1)), 0, accuracy: 1e-9)

        _ = fixture.runUntilSettled(max: 6)
        XCTAssertTrue(fixture.driver.exitSubviews.isEmpty)
        XCTAssertTrue(newView.superview === fixture.listView.container)
        XCTAssertTrue(fixture.view(identity: 1) === newView)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 1)), 1, accuracy: 1e-9)
        XCTAssertFalse(fixture.hasActiveAnimations)
    }

    func testRepeatedDeleteAddLeavesNoExitSubviewsAfterSettlement() {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2]))

        for _ in 0..<4 {
            fixture.apply(idItems([0, 2]), duration: 2)
            fixture.advance(by: 0.25)
            fixture.apply(idItems([0, 1, 2]), duration: 2)
            fixture.advance(by: 0.25)
        }

        XCTAssertFalse(fixture.driver.exitSubviews.isEmpty)
        _ = fixture.runUntilSettled(max: 5)
        XCTAssertTrue(fixture.driver.exitSubviews.isEmpty)
        XCTAssertFalse(fixture.hasActiveAnimations)
    }

    func testPopulatedToEmptyAndEmptyToPopulatedUseExitAndInsertionRules() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1]))
        fixture.apply([], duration: 2)

        XCTAssertTrue(fixture.activeWindow.isEmpty)
        XCTAssertEqual(fixture.driver.exitSubviews.count, 2)
        XCTAssertTrue(fixture.hasActiveAnimations)
        _ = fixture.runUntilSettled(max: 3)
        XCTAssertTrue(fixture.driver.exitSubviews.isEmpty)

        fixture.apply(idItems([8, 9]), duration: 2)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 8)), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: 9)), 0, accuracy: 1e-9)
        XCTAssertNil(fixture.positionTrack(identity: 8))
        XCTAssertNil(fixture.positionTrack(identity: 9))
    }

    func testResizeWhileEmptyPreservesActiveExitOwners() {
        let fixture = VirtualListFixture(items: idItems([0, 1]))
        fixture.apply([], duration: 4)
        XCTAssertEqual(fixture.driver.exitSubviews.count, 2)

        fixture.listView.applyChanges(
            newSize: CGSize(width: 390, height: 700),
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(fixture.driver.exitSubviews.count, 2)
        XCTAssertTrue(fixture.hasActiveAnimations)
    }

    func testMixedPassIsContinuousGranularAndUsesOneExactTransactionTime() throws {
        var mediaTime: CFTimeInterval = 0
        var advancesMediaTime = true
        let fixture = VirtualListFixture(
            items: idItems([0, 1, 2, 3, 4, 5]),
            mediaTime: {
                if advancesMediaTime { mediaTime += 0.125 }
                return mediaTime
            },
            emitsCA: true
        )
        let outgoing = try XCTUnwrap(fixture.view(identity: 1))
        let before = Dictionary(uniqueKeysWithValues: [0, 1, 2, 3, 4, 5].map {
            ($0, fixture.screenY(identity: $0)!)
        })

        fixture.apply(idItems([0, 9, 2, 4, 3, 5]), duration: 4)

        let sharedStart = try XCTUnwrap(fixture.opacityTrack(identity: 9)).startTime
        advancesMediaTime = false
        mediaTime = sharedStart

        for identity in [0, 2, 3, 4, 5] {
            XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: identity)),
                           before[identity]!, accuracy: 1e-9)
        }
        XCTAssertEqual(try XCTUnwrap(fixture.driver.exitScreenY(view: outgoing)),
                       before[1]!, accuracy: 1e-9)
        XCTAssertNil(fixture.positionTrack(identity: 9))
        XCTAssertNil(fixture.positionTrack(identity: 0))
        XCTAssertNil(fixture.positionTrack(identity: 2))
        XCTAssertNotNil(fixture.positionTrack(identity: 3))
        XCTAssertNotNil(fixture.positionTrack(identity: 4))
        XCTAssertNil(fixture.positionTrack(identity: 5))

        let outgoingFade = try XCTUnwrap(
            fixture.driver.exitAnimation(view: outgoing, property: .opacity)
        )
        let incomingFade = try XCTUnwrap(
            fixture.driver.exitAnimation(
                view: try XCTUnwrap(fixture.view(identity: 9)), property: .opacity
            )
        )
        let trackStarts = [
            try XCTUnwrap(fixture.opacityTrack(identity: 9)).startTime,
            try XCTUnwrap(fixture.positionTrack(identity: 3)).startTime,
            try XCTUnwrap(fixture.positionTrack(identity: 4)).startTime,
            try XCTUnwrap(outgoingFade.coreListDeclaredStartTime),
            try XCTUnwrap(incomingFade.coreListDeclaredStartTime),
        ]
        XCTAssertEqual(Set(trackStarts).count, 1,
                       "exit, insertion, move, and survivor tracks must share one pass clock")
    }

    func testSecondMixedPassReplacesOnlyChangedProperties() throws {
        let fixture = VirtualListFixture(items: idItems([0, 1, 2, 3, 4, 5]))
        fixture.apply(idItems([0, 9, 2, 4, 3, 5]), duration: 4)
        fixture.advance(by: 1)
        let unchangedPosition = try XCTUnwrap(fixture.positionTrack(identity: 4))
        let changedPosition = try XCTUnwrap(fixture.positionTrack(identity: 3))
        let unchangedOpacity = try XCTUnwrap(fixture.opacityTrack(identity: 9))

        fixture.apply(idItems([0, 9, 10, 4, 5, 3]), duration: 4)

        XCTAssertEqual(fixture.positionTrack(identity: 4), unchangedPosition)
        XCTAssertEqual(fixture.opacityTrack(identity: 9), unchangedOpacity)
        XCTAssertNotEqual(fixture.positionTrack(identity: 3)?.generation,
                          changedPosition.generation)
        XCTAssertNotNil(fixture.positionTrack(identity: 5))
        XCTAssertNil(fixture.positionTrack(identity: 10))
        XCTAssertNotNil(fixture.opacityTrack(identity: 10))
        XCTAssertNil(fixture.positionTrack(identity: 0))
        XCTAssertEqual(fixture.driver.exitSubviews.count, 2)
    }
}
