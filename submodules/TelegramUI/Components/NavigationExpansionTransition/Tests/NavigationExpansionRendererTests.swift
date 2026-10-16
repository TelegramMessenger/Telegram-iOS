import XCTest
import UIKit
import Display
import GlassBackgroundComponent
@testable import NavigationExpansionTransition

/// Plain views standing in for the chat's pill content and avatar, recording what was lent and returned.
private final class FakeSource: NavigationExpansionSourceProviding {
    let screen: UIView
    let titleView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 96.0, height: 20.0))
    let statusView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 80.0, height: 14.0))
    let avatarView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 38.0, height: 38.0))
    let home = UIView()
    var lends = 0
    var returns = 0

    init(screen: UIView) {
        self.screen = screen
        for view in [self.titleView, self.statusView, self.avatarView] {
            self.home.addSubview(view)
        }
        screen.addSubview(self.home)
    }

    let expansionBarExclusions = NavigationBarTransitionExclusions.none

    func lendExpansionSource(in screenView: UIView) -> NavigationExpansionSourceLoan? {
        self.lends += 1
        let g = makeExpansionGeometry()
        return NavigationExpansionSourceLoan(origin: g.origin, originTint: .init(kind: .panel), isDark: false, companion: g.companion, companionPhotoDiameter: 38.0, companionView: self.avatarView, labels: [
            NavigationExpansionLabel(view: self.titleView, textCenter: CGPoint(x: 48.0, y: 10.0), textSize: CGSize(width: 96.0, height: 20.0), screenCenter: g.labels[0].sourceCenter, coloring: .recolor(.black)),
            NavigationExpansionLabel(view: self.statusView, textCenter: CGPoint(x: 40.0, y: 7.0), textSize: CGSize(width: 80.0, height: 14.0), screenCenter: g.labels[1].sourceCenter, coloring: .recolor(.gray))
        ], press: .none)
    }

    func returnExpansionSource() {
        self.returns += 1
        for view in [self.titleView, self.statusView, self.avatarView] {
            self.home.addSubview(view)
        }
    }
}

private final class FakeDestination: NavigationExpansionDestinationProviding {
    let titleView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 158.0, height: 34.0))
    let statusView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 130.0, height: 20.0))
    let avatarView = UIView()
    let buttons = (0 ..< 4).map { _ in UIView() }
    /// Each button's platter, drawn elsewhere (the profile's are shapes in a blur's mask).
    let platters = (0 ..< 4).map { _ in UIView() }
    let background = UIView()
    let list = UIView()
    let home = UIView()
    /// Content that lies on the photo (the profile's header content on the photo path).
    var overlays: [UIView] = []
    var path: ExpansionPath = .origin
    var lends = 0
    var returns = 0
    private(set) weak var top: UIView?

    init(top: UIView) {
        self.top = top
        let g = makeExpansionGeometry()
        self.avatarView.frame = g.avatar!
        for (view, frame) in zip(self.buttons, g.appearing) {
            view.frame = frame
            top.addSubview(view)
        }
        top.addSubview(self.avatarView)
        top.addSubview(self.background)
        top.addSubview(self.list)
        self.home.addSubview(self.titleView)
        self.home.addSubview(self.statusView)
        top.addSubview(self.home)
    }

    var expansionPath: ExpansionPath {
        return self.path
    }

    func lendExpansionDestination(in screenView: UIView) -> NavigationExpansionDestinationLoan? {
        self.lends += 1
        let g = makeExpansionGeometry()
        return NavigationExpansionDestinationLoan(avatar: g.avatar, photo: g.photo, avatarView: self.avatarView, avatarRestFrame: g.avatar!, labels: [
            NavigationExpansionLabel(view: self.titleView, textCenter: CGPoint(x: 79.0, y: 17.0), textSize: CGSize(width: 158.0, height: 34.0), screenCenter: g.labels[0].destinationCenter, coloring: .multiply([self.titleView.layer], .white)),
            NavigationExpansionLabel(view: self.statusView, textCenter: CGPoint(x: 65.0, y: 10.0), textSize: CGSize(width: 130.0, height: 20.0), screenCenter: g.labels[1].destinationCenter, coloring: .multiply([self.statusView.layer], .white))
        ], labelColors: [.white, .white], carriedEdge: g.carriedEdge, appearingViews: self.buttons, appearingCompanions: self.platters.map { [$0] }, overlayViews: self.overlays, backgroundViews: [self.background], listViews: [self.list], patternViews: [], glassTint: .purple, screenCornerRadius: g.screenCornerRadius, backButtonFrame: CGRect(x: 16.0, y: 64.0, width: 44.0, height: 44.0))
    }

    func returnExpansionDestination() {
        self.returns += 1
        self.home.addSubview(self.titleView)
        self.home.addSubview(self.statusView)
        for overlay in self.overlays {
            self.top?.addSubview(overlay)
        }
        // The renderer takes the avatar out; its provider puts it back at rest, as the profile's does.
        self.top?.addSubview(self.avatarView)
        self.avatarView.frame = makeExpansionGeometry().avatar!
    }
}

final class NavigationExpansionRendererTests: XCTestCase {
    private func make(opening: Bool = true, configure: (FakeDestination) -> Void = { _ in }) -> (NavigationExpansionRendererImpl, container: UIView, top: UIView, source: FakeSource, destination: FakeDestination) {
        let size = makeExpansionGeometry().screenSize
        let container = UIView(frame: CGRect(origin: CGPoint(), size: size))
        let bottom = UIView(frame: container.bounds)
        let top = UIView(frame: container.bounds)
        container.addSubview(bottom)
        container.addSubview(top)
        let source = FakeSource(screen: bottom)
        let destination = FakeDestination(top: top)
        configure(destination)
        let renderer = NavigationExpansionRendererImpl.make(source: source, destination: destination, operation: opening ? .push : .pop) as! NavigationExpansionRendererImpl
        container.insertSubview(renderer.underView, belowSubview: top)
        container.insertSubview(renderer.view, aboveSubview: top)
        renderer.begin(topView: top, bottomView: bottom, size: size, time: opening ? 0.0 : 1.0, isOpening: opening)
        return (renderer, container, top, source, destination)
    }

    // Begun at 0: the upper screen is shown through a card that is the pill; the labels stand where the pill has them;
    // the profile's are invisible; its buttons and list are not there yet.
    func test_begin_atZero_showsThePill() {
        let (renderer, _, top, _, destination) = self.make()
        let g = makeExpansionGeometry()
        guard let mask = top.layer.mask else {
            return XCTFail("no card mask")
        }
        XCTAssertEqual(mask.frame, g.origin)
        XCTAssertEqual(mask.cornerRadius, 22.0, accuracy: 1e-6)
        XCTAssertEqual(renderer.labelHostCentersForTesting.first ?? CGPoint(), g.labels[0].sourceCenter)
        XCTAssertEqual(renderer.destinationLabelAlphasForTesting, [0.0, 0.0])
        XCTAssertEqual(destination.buttons.map { $0.alpha }, [0.0, 0.0, 0.0, 0.0])
        XCTAssertEqual(destination.list.alpha, 0.0)
    }

    // The bake: the card's mask grows from the pill to the screen on keyframes.
    func test_animate_keyframesTheCardFromThePillToTheScreen() {
        let (renderer, _, top, _, _) = self.make()
        let g = makeExpansionGeometry()
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { CGFloat($0 / 0.5) }
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: true, poses: times.map { _ in .none }, animationTime: { 0.0 }, reinstallTiming: { nil }, schedule: { _, _ in }))
        guard let bounds = top.layer.mask?.animation(forKey: "navigationExpansion.bounds") as? CAKeyframeAnimation, let values = bounds.values as? [NSValue] else {
            return XCTFail("no mask keyframes")
        }
        XCTAssertEqual(values.first?.cgRectValue.size, g.origin.size)
        // At 1 while opening the knock leaves a trace under half a point (see the choreography's tests).
        XCTAssertEqual(values.last?.cgRectValue.width ?? 0.0, g.screenSize.width, accuracy: 0.5)
        XCTAssertEqual(values.last?.cgRectValue.height ?? 0.0, g.screenSize.height, accuracy: 0.5)
    }

    // Review Focus 1: on either ending every lent view leaves the renderer (back with its provider), no colour layer
    // still masks with it, the upper screen is unmasked and its views are whole.
    func test_lentViews_returnToTheirSuperviewsAndFrames_onEveryEnding() {
        for atTop in [true, false] {
            let (renderer, _, top, source, destination) = self.make()
            renderer.end(atTop: atTop)
            XCTAssertEqual(source.returns, 1)
            XCTAssertEqual(destination.returns, 1)
            XCTAssertTrue(source.titleView.superview === source.home)
            XCTAssertTrue(source.statusView.superview === source.home)
            XCTAssertTrue(source.avatarView.superview === source.home)
            XCTAssertEqual(source.avatarView.alpha, 1.0)
            XCTAssertTrue(destination.titleView.superview === destination.home)
            XCTAssertNil(top.layer.mask)
            XCTAssertEqual(top.transform, .identity)
            XCTAssertEqual(destination.buttons.map { $0.alpha }, [1.0, 1.0, 1.0, 1.0])
            XCTAssertEqual(destination.buttons.map { $0.transform }, [.identity, .identity, .identity, .identity])
            XCTAssertEqual(destination.list.alpha, 1.0)
            XCTAssertEqual(destination.background.alpha, 1.0)
            XCTAssertTrue(destination.avatarView.superview === top)
            XCTAssertEqual(destination.avatarView.frame, makeExpansionGeometry().avatar!)
            XCTAssertTrue(renderer.view.subviews.allSatisfy { $0.subviews.isEmpty })
        }
    }

    // The drops' tint follows the fill on the transition's clock, per frame: glass cannot keyframe it.
    func test_tint_followsTheFill() {
        let (renderer, _, _, _, _) = self.make()
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { CGFloat($0 / 0.5) }
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: true, poses: times.map { _ in .none }, animationTime: { 0.25 }, reinstallTiming: { nil }, schedule: { _, _ in }))
        renderer.applyTint(atAnimationTime: 0.25)
        XCTAssertEqual(renderer.appliedTintFillForTesting, 0.5, accuracy: 0.02)
        renderer.applyTint(atAnimationTime: 0.5)
        XCTAssertEqual(renderer.appliedTintFillForTesting, 1.0, accuracy: 0.02)
    }

    // A lent label's text centre is the point its host carries: at 0 both the chat's labels and the profile's stand on
    // the chat's centres, whatever their scale (the hosts scale about that point).
    func test_begin_labelTextCentresStandOnTheirPath() {
        let (_, container, _, source, destination) = self.make()
        let g = makeExpansionGeometry()
        let cases: [(UIView, CGPoint, CGPoint)] = [
            (source.titleView, CGPoint(x: 48.0, y: 10.0), g.labels[0].sourceCenter),
            (source.statusView, CGPoint(x: 40.0, y: 7.0), g.labels[1].sourceCenter),
            (destination.titleView, CGPoint(x: 79.0, y: 17.0), g.labels[0].sourceCenter),
            (destination.statusView, CGPoint(x: 65.0, y: 10.0), g.labels[1].sourceCenter)
        ]
        for (view, textCenter, expected) in cases {
            let point = view.convert(textCenter, to: container)
            XCTAssertEqual(point.x, expected.x, accuracy: 0.01)
            XCTAssertEqual(point.y, expected.y, accuracy: 0.01)
        }
    }

    // The drops' own bounds follow their shape: the glass is laid out from each drop's top-left, so a drop whose bounds
    // stayed at its final size while its centre moved drew its glass off the card (down and right in a close).
    func test_animate_keyframesTheDropsBoundsWithTheirShape() {
        let (renderer, _, _, _, _) = self.make()
        let g = makeExpansionGeometry()
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { CGFloat($0 / 0.5) }
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: true, poses: times.map { _ in .none }, animationTime: { 0.0 }, reinstallTiming: { nil }, schedule: { _, _ in }))
        let drops = renderer.dropLayersForTesting
        guard let origin = drops.origin.animation(forKey: "navigationExpansion.bounds") as? CAKeyframeAnimation, let originValues = origin.values as? [NSValue] else {
            return XCTFail("no bounds keyframes on the pill's drop")
        }
        XCTAssertEqual(originValues.first?.cgRectValue.size, g.origin.size)
        XCTAssertEqual(originValues.last?.cgRectValue.width ?? 0.0, g.screenSize.width, accuracy: 0.5)
        guard let companion = drops.companion.animation(forKey: "navigationExpansion.bounds") as? CAKeyframeAnimation, let companionValues = companion.values as? [NSValue] else {
            return XCTFail("no bounds keyframes on the avatar's drop")
        }
        XCTAssertEqual(companionValues.first?.cgRectValue.size, g.companion?.size)
    }

    // A button's platter is drawn elsewhere (in a blur's mask), so it appears with its button: same alpha, same
    // transform, frame by frame, and back at rest when the expansion ends.
    func test_platters_appearWithTheirButtons() {
        let (renderer, _, _, _, destination) = self.make()
        for (button, platter) in zip(destination.buttons, destination.platters) {
            XCTAssertEqual(button.alpha, 0.0)
            XCTAssertEqual(platter.alpha, button.alpha)
            XCTAssertTrue(CATransform3DEqualToTransform(platter.layer.transform, button.layer.transform))
        }
        renderer.end(atTop: true)
        for platter in destination.platters {
            XCTAssertEqual(platter.alpha, 1.0)
            XCTAssertTrue(CATransform3DIsIdentity(platter.layer.transform))
        }
    }

    // The labels lie on the photo, as in the prototype's stack (photo, then actions, info and titles,
    // ProfileMorph.swift:538-561): on the photo path the name ends on the expanded photo. The photo stays in the
    // renderer's view, above the card-cut upper screen, so the flying circle is not cut while the card is a pill.
    func test_photo_liesUnderTheLabels() {
        let (renderer, _, _, _, _) = self.make()
        XCTAssertTrue(renderer.photoIsBelowLabelsForTesting)
    }

    // Content that lies on the photo (the profile's header on the photo path: buttons, badges) is lifted above the photo
    // at its place on screen, cut by the card like the upper screen (the prototype's actions, ProfileMorph.swift:545-547),
    // and leaves the renderer when the expansion ends.
    func test_overlays_lieOnThePhoto_cutByTheCard() {
        let overlay = UIView(frame: CGRect(x: 20.0, y: 300.0, width: 360.0, height: 60.0))
        let (renderer, container, _, _, _) = self.make(configure: { destination in
            destination.overlays = [overlay]
            destination.top?.addSubview(overlay)
        })
        XCTAssertTrue(overlay.isDescendant(of: renderer.view))
        XCTAssertEqual(overlay.convert(overlay.bounds, to: container), CGRect(x: 20.0, y: 300.0, width: 360.0, height: 60.0))
        XCTAssertTrue(renderer.photoIsBelowLabelsForTesting)
        XCTAssertTrue(renderer.photoIsBelowOverlaysForTesting)
        XCTAssertEqual(renderer.overlayMaskFrameForTesting, makeExpansionGeometry().origin)
        renderer.end(atTop: true)
        XCTAssertFalse(overlay.isDescendant(of: renderer.view))
    }

    // The upper screen is a card around the touch (spec, swipe back) and the avatar is the profile's, so it rides the
    // card (the prototype's avatar circle is recomputed onto the swipe card, ProfileMorph.swift:482-483).
    func test_swipe_avatarRidesTheCard() {
        let (renderer, container, top, _, destination) = self.make()
        let g = makeExpansionGeometry()
        let pose = NavigationExpansionCardPose(dx: 120.0, dy: 10.0, anchor: CGPoint(x: 40.0, y: 520.0), weight: 1.0)
        renderer.update(time: 1.0, isOpening: false, pose: pose)
        let expected = g.avatar!.applying(pose.transform(width: g.screenSize.width))
        let actual = destination.avatarView.convert(destination.avatarView.bounds, to: container)
        XCTAssertEqual(actual.midX, expected.midX, accuracy: 0.5)
        XCTAssertEqual(actual.midY, expected.midY, accuracy: 0.5)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.5)
        // The card itself: the screen carried by the pose, the touch point under the finger.
        let card = top.convert(top.bounds, to: container)
        let expectedCard = CGRect(origin: CGPoint(), size: g.screenSize).applying(pose.transform(width: g.screenSize.width))
        XCTAssertEqual(card.minX, expectedCard.minX, accuracy: 0.5)
        XCTAssertEqual(card.minY, expectedCard.minY, accuracy: 0.5)
        XCTAssertEqual(card.width, expectedCard.width, accuracy: 0.5)
    }

    // Below iOS 26, or with the fake-glass setting, the drops are the custom glass (they overlap instead of merging):
    // the expansion runs the same way, its drops keyframed, and everything lent comes back.
    func test_fakeGlass_runsAndReturnsEverything() {
        let previous = GlassBackgroundView.useCustomGlassImpl
        GlassBackgroundView.useCustomGlassImpl = true
        defer { GlassBackgroundView.useCustomGlassImpl = previous }
        let (renderer, _, top, source, destination) = self.make()
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { CGFloat($0 / 0.5) }
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: true, poses: times.map { _ in .none }, animationTime: { 0.0 }, reinstallTiming: { nil }, schedule: { _, _ in }))
        XCTAssertNotNil(renderer.dropLayersForTesting.origin.animation(forKey: "navigationExpansion.bounds"))
        renderer.end(atTop: true)
        XCTAssertEqual(source.returns, 1)
        XCTAssertEqual(destination.returns, 1)
        XCTAssertTrue(source.titleView.superview === source.home)
        XCTAssertNil(top.layer.mask)
    }

    // The coordinator ends a transition a frame or two after its keyframes complete (the clock's completion comes back
    // from the render server), and Core Animation shows the model values in between: every keyframed layer's model must
    // be its last keyframe, after the per-frame tint as well (it re-applies the drops' shape). The close's pill was
    // square for two frames when the tint applied the drop view's own corner radius (0) to the glass.
    func test_models_areTheLastKeyframes_afterTheTint() {
        for isOpening in [true, false] {
            let (renderer, container, top, _, _) = self.make()
            let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
            let times = timing.sampleTimes.map { t -> CGFloat in
                let u = CGFloat(t / 0.5)
                return isOpening ? u : 1.0 - u
            }
            renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: isOpening, poses: times.map { _ in .none }, animationTime: { 0.5 }, reinstallTiming: { nil }, schedule: { _, _ in }))
            renderer.applyTint(atAnimationTime: 0.5)
            var checked = 0
            for root in [container.layer, renderer.view.layer, renderer.underView.layer, top.layer] {
                checked += assertModelsAreLastKeyframes(root)
            }
            XCTAssertGreaterThan(checked, 10)
        }
    }

    // The renderer can outlive the transition's clock (it stays while the bars' glass lingers over the chat): once the
    // tint has reached the timeline's end it stays there, though the stopped clock then reads 0 (the close's start, the
    // profile's colour: the pill went purple after the close).
    func test_tint_staysAtTheEnd_whenTheClockStops() {
        let (renderer, _, _, _, _) = self.make()
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { 1.0 - CGFloat($0 / 0.5) }
        var clock: Double = 0.0
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: false, poses: times.map { _ in .none }, animationTime: { clock }, reinstallTiming: { nil }, schedule: { _, _ in }))
        let start = renderer.appliedTintFillForTesting
        clock = 0.6
        renderer.applyTint()
        let end = renderer.appliedTintFillForTesting
        XCTAssertNotEqual(start, end, accuracy: 0.01)
        clock = 0.0
        renderer.applyTint()
        XCTAssertEqual(renderer.appliedTintFillForTesting, end, accuracy: 1e-6)
    }

    // A transition ended early (a size change, a new push: performCompletion) sets its last frame directly and stops
    // the clock; the tint stays with that frame, though the clock then reads 0 (the close's start, the profile's
    // colour). And a clock that goes back never takes the tint back.
    func test_tint_followsTheFrameSetDirectly_notTheStoppedClock() {
        let (renderer, _, _, _, _) = self.make()
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { 1.0 - CGFloat($0 / 0.5) }
        var clock: Double = 0.0
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: false, poses: times.map { _ in .none }, animationTime: { clock }, reinstallTiming: { nil }, schedule: { _, _ in }))
        let start = renderer.appliedTintFillForTesting
        clock = 0.2
        renderer.applyTint()
        let middle = renderer.appliedTintFillForTesting
        XCTAssertNotEqual(start, middle, accuracy: 0.01)
        clock = 0.1
        renderer.applyTint()
        XCTAssertEqual(renderer.appliedTintFillForTesting, middle, accuracy: 1e-6, "a clock going back does not take the tint back")
        renderer.update(time: 0.0, isOpening: false, pose: .none)
        let landed = renderer.appliedTintFillForTesting
        XCTAssertNotEqual(landed, start, accuracy: 0.01)
        clock = 0.0
        renderer.applyTint()
        XCTAssertEqual(renderer.appliedTintFillForTesting, landed, accuracy: 1e-6)
    }

    // A merging glass container draws nothing for its first frames on screen (~50 ms, three frames, filmed on the
    // simulator): on the open, whose drops show from its first frame, the pill's glass and the avatar's ring were
    // missing until then. So the open's drops start outside it — apart, as the chat's own pill and capsule are — and
    // join it once it is up, keeping their keyframes.
    func test_open_dropsJoinTheContainerOnceItIsUp() {
        let (renderer, _, _, _, _) = self.make()
        XCTAssertFalse(renderer.dropsInContainerForTesting)
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { CGFloat($0 / 0.5) }
        var scheduled: [(time: Double, action: () -> Void)] = []
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: true, poses: times.map { _ in .none }, animationTime: { 0.0 }, reinstallTiming: { nil }, schedule: { time, action in scheduled.append((time, action)) }))
        XCTAssertFalse(renderer.dropsInContainerForTesting)
        guard let join = scheduled.first else {
            return XCTFail("the drops never join the container")
        }
        XCTAssertEqual(join.time, NavigationExpansionRendererImpl.glassContainerWarmUp, accuracy: 0.02)
        join.action()
        XCTAssertTrue(renderer.dropsInContainerForTesting)
        XCTAssertNotNil(renderer.dropLayersForTesting.origin.animation(forKey: "navigationExpansion.bounds"), "the drop keeps its keyframes")
        XCTAssertNotNil(renderer.dropLayersForTesting.companion.animation(forKey: "navigationExpansion.position"))
    }

    // The close's drops start clear (their glass returns near the pill), so they are in the container from the start.
    func test_close_dropsAreInTheContainerFromTheStart() {
        let (renderer, _, _, _, _) = self.make(opening: false)
        XCTAssertTrue(renderer.dropsInContainerForTesting)
    }

    // A swipe released into the close: the whole profile carries the released pose, which lets go as t(2 − t), while
    // the card shrinks on the close's clock into the pill (the prototype's CardTransform over the morph). A card kept at
    // the screen while the pose had weight inflated back to the full screen as the pose let go.
    func test_swipeRelease_cardShrinksUnderThePose() {
        let (renderer, _, top, _, _) = self.make(opening: false)
        let g = makeExpansionGeometry()
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { 1.0 - CGFloat($0 / 0.5) }
        let released = NavigationExpansionCardPose(dx: 160.0, dy: 20.0, anchor: CGPoint(x: 40.0, y: 520.0), weight: 1.0)
        let poses = times.map { released.released(NavigationExpansionCardPose.releasedWeight(time: $0)) }
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: false, poses: poses, animationTime: { 0.0 }, reinstallTiming: { nil }, schedule: { _, _ in }))
        guard let bounds = top.layer.mask?.animation(forKey: "navigationExpansion.bounds") as? CAKeyframeAnimation, let values = (bounds.values as? [NSValue])?.map({ $0.cgRectValue.size }) else {
            return XCTFail("no card keyframes")
        }
        XCTAssertEqual(values.first?.width ?? 0.0, g.screenSize.width, accuracy: 0.5)
        XCTAssertLessThan(values[values.count / 2].width, g.screenSize.width * 0.9, "the card shrinks as the pose lets go")
        XCTAssertEqual(values.last?.width ?? 0.0, g.origin.width, accuracy: 0.5)
    }

    // While the finger is down the clock is at 1: the card is the screen, carried by the pose.
    func test_swipeDrag_cardIsTheScreen() {
        let (renderer, _, top, _, _) = self.make(opening: false)
        let g = makeExpansionGeometry()
        renderer.update(time: 1.0, isOpening: false, pose: NavigationExpansionCardPose(dx: 120.0, dy: 10.0, anchor: CGPoint(x: 40.0, y: 520.0), weight: 1.0))
        XCTAssertEqual(top.layer.mask?.frame ?? .zero, CGRect(origin: CGPoint(), size: g.screenSize))
        XCTAssertEqual(top.layer.mask?.cornerRadius ?? 0.0, g.screenCornerRadius, accuracy: 0.01)
    }

    // The drops are part of the card: they carry the pose too (the prototype's liquid is inside the transformed profile).
    func test_swipe_dropsRideTheCard() {
        let (renderer, container, top, _, _) = self.make(opening: false)
        let pose = NavigationExpansionCardPose(dx: 120.0, dy: 10.0, anchor: CGPoint(x: 40.0, y: 520.0), weight: 1.0)
        renderer.update(time: 1.0, isOpening: false, pose: pose)
        let drop = renderer.dropLayersForTesting.origin
        let dropRect = drop.convert(drop.bounds, to: container.layer)
        let card = top.convert(top.bounds, to: container)
        XCTAssertEqual(dropRect.midX, card.midX, accuracy: 0.5)
        XCTAssertEqual(dropRect.midY, card.midY, accuracy: 0.5)
        XCTAssertEqual(dropRect.width, card.width, accuracy: 0.5)
    }

    // A caught push: the card at the frozen clock (smaller than the screen), carried by the finger's pose.
    func test_frozenClock_cardCarriedByThePose() {
        let (renderer, container, top, _, _) = self.make()
        let g = makeExpansionGeometry()
        let pose = NavigationExpansionCardPose(dx: 80.0, dy: 10.0, anchor: CGPoint(x: 40.0, y: 520.0), weight: 1.0)
        renderer.update(time: 0.3, isOpening: true, pose: pose)
        guard let mask = top.layer.mask else {
            return XCTFail("no card")
        }
        XCTAssertLessThan(mask.frame.width, g.screenSize.width, "the card at 0.3, not the screen")
        let card = top.convert(mask.frame, to: container)
        let expected = mask.frame.applying(pose.transform(width: g.screenSize.width))
        XCTAssertEqual(card.midX, expected.midX, accuracy: 0.5)
        XCTAssertEqual(card.midY, expected.midY, accuracy: 0.5)
        XCTAssertEqual(card.width, expected.width, accuracy: 0.5)
    }
}

/// Compares every keyframe animation in `layer`'s tree with the model value it lands on; returns how many it checked.
private func assertModelsAreLastKeyframes(_ layer: CALayer, file: StaticString = #filePath, line: UInt = #line) -> Int {
    var checked = 0
    var layers: [CALayer] = [layer]
    if let mask = layer.mask {
        layers.append(mask)
    }
    for current in layers {
        for key in current.animationKeys() ?? [] {
            guard let animation = current.animation(forKey: key) as? CAKeyframeAnimation, let keyPath = animation.keyPath, let last = animation.values?.last else {
                continue
            }
            checked += 1
            let name = "\(type(of: current)) \(key)"
            switch keyPath {
            case "position":
                let p = (last as! NSValue).cgPointValue
                XCTAssertEqual(current.position.x, p.x, accuracy: 0.01, name, file: file, line: line)
                XCTAssertEqual(current.position.y, p.y, accuracy: 0.01, name, file: file, line: line)
            case "bounds":
                let r = (last as! NSValue).cgRectValue
                XCTAssertEqual(current.bounds.width, r.width, accuracy: 0.01, name, file: file, line: line)
                XCTAssertEqual(current.bounds.height, r.height, accuracy: 0.01, name, file: file, line: line)
            case "cornerRadius":
                XCTAssertEqual(current.cornerRadius, CGFloat((last as! NSNumber).doubleValue), accuracy: 0.01, name, file: file, line: line)
            case "opacity":
                XCTAssertEqual(Double(current.opacity), (last as! NSNumber).doubleValue, accuracy: 0.001, name, file: file, line: line)
            case "transform":
                XCTAssertTrue(CATransform3DEqualToTransform(current.transform, (last as! NSValue).caTransform3DValue), name, file: file, line: line)
            default:
                checked -= 1
            }
        }
    }
    for sublayer in layer.sublayers ?? [] {
        checked += assertModelsAreLastKeyframes(sublayer, file: file, line: line)
    }
    if let mask = layer.mask {
        for sublayer in mask.sublayers ?? [] {
            checked += assertModelsAreLastKeyframes(sublayer, file: file, line: line)
        }
    }
    return checked
}
