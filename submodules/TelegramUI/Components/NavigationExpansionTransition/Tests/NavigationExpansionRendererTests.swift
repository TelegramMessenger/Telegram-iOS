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
    /// The title's text layer (a `SplitTintTextView`'s tint layer), and how the title is coloured.
    let titleTintLayer = CALayer()
    var titleColoring: NavigationExpansionLabel.Coloring = .recolor(.black)
    /// The title pill, where the geometry's is not wanted.
    var origin: CGRect?
    /// A view whose frame is the title pill, measured in the space it is lent in (as the chat's pill is).
    var originView: UIView?
    /// False as in a forum, whose bar has its menu button where a chat has its avatar.
    var hasCompanion = true
    /// False as in a channel whose title shows no status line (the profile's does).
    var hasStatus = true

    init(screen: UIView) {
        self.titleView.layer.addSublayer(self.titleTintLayer)
        // The chat's avatar where the flying circle starts: its photo, centred on the capsule.
        if let companion = makeExpansionGeometry().companion {
            self.avatarView.frame = CGRect(x: companion.midX - 19.0, y: companion.midY - 19.0, width: 38.0, height: 38.0)
        }
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
        let measuredOrigin = self.originView.map { $0.convert($0.bounds, to: screenView) }
        var labels = [NavigationExpansionLabel(view: self.titleView, textCenter: CGPoint(x: 48.0, y: 10.0), textSize: CGSize(width: 96.0, height: 20.0), screenCenter: g.labels[0].sourceCenter, coloring: self.titleColoring)]
        if self.hasStatus {
            labels.append(NavigationExpansionLabel(view: self.statusView, textCenter: CGPoint(x: 40.0, y: 7.0), textSize: CGSize(width: 80.0, height: 14.0), screenCenter: g.labels[1].sourceCenter, coloring: .recolor(.gray)))
        }
        return NavigationExpansionSourceLoan(origin: measuredOrigin ?? self.origin ?? g.origin, originTint: .init(kind: .panel), isDark: false, companion: self.hasCompanion ? g.companion : nil, companionPhotoDiameter: 38.0, companionView: self.hasCompanion ? self.avatarView : nil, labels: labels, press: .none)
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
    /// Views around the status that keep their place beside it (the profile's level, username, balance).
    var statusFollowers: [UIView] = []
    /// The page below the header, which rides the status (the profile's list and music strip).
    var pageViews: [UIView] = []
    /// Views clipping at the page's top edge (the profile's cover).
    var pageEdgeViews: [UIView] = []
    /// The rest of the background, landing with the page (the profile's gifts around its avatar).
    var landingViews: [UIView] = []
    var path: ExpansionPath = .origin
    var screenCornerRadii = makeExpansionGeometry().screenCornerRadii
    /// The avatar's corner radius over its side (a forum's is a rounded square).
    var avatarCornerFraction: CGFloat = 0.5
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
        // On the photo path its avatar view is the expanded photo, as the profile's is.
        return NavigationExpansionDestinationLoan(avatar: g.avatar, photo: g.photo, avatarView: self.avatarView, avatarRestFrame: self.path == .photo ? g.photo! : g.avatar!, labels: [
            NavigationExpansionLabel(view: self.titleView, textCenter: CGPoint(x: 79.0, y: 17.0), textSize: CGSize(width: 158.0, height: 34.0), screenCenter: g.labels[0].destinationCenter, coloring: .multiply([self.titleView.layer], .white)),
            NavigationExpansionLabel(view: self.statusView, textCenter: CGPoint(x: 65.0, y: 10.0), textSize: CGSize(width: 130.0, height: 20.0), screenCenter: g.labels[1].destinationCenter, coloring: .multiply([self.statusView.layer], .white), followers: self.statusFollowers)
        ], labelColors: [.white, .white], carriedEdge: g.carriedEdge, appearingViews: self.buttons, appearingCompanions: self.platters.map { [$0] }, overlayViews: self.overlays, backgroundViews: [self.background], listViews: [self.list], pageViews: self.pageViews, pageEdgeViews: self.pageEdgeViews, landingViews: self.landingViews, patternViews: [], glassTint: .purple, screenCornerRadii: self.screenCornerRadii, backButtonFrame: CGRect(x: 16.0, y: 64.0, width: 44.0, height: 44.0), avatarCornerFraction: self.avatarCornerFraction)
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
    private func make(opening: Bool = true, configureContainer: (UIView) -> Void = { _ in }, configureSource: (FakeSource) -> Void = { _ in }, configure: (FakeDestination) -> Void = { _ in }) -> (NavigationExpansionRendererImpl, container: UIView, top: UIView, source: FakeSource, destination: FakeDestination) {
        let size = makeExpansionGeometry().screenSize
        let container = UIView(frame: CGRect(origin: CGPoint(), size: size))
        configureContainer(container)
        let bottom = UIView(frame: container.bounds)
        let top = UIView(frame: container.bounds)
        container.addSubview(bottom)
        container.addSubview(top)
        let source = FakeSource(screen: bottom)
        configureSource(source)
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

    // A modal's root container is shifted by its sublayer transform (scaled about its centre, moved down), and a pop
    // that also removes the modal begins before the shift is animated away. The renderer draws inside that container,
    // so the shift reaches its views anyway: the card starts on the chat's pill as laid out, not as shifted, and rides
    // the shift as it goes.
    func test_begin_underAModalsShift_measuresThePillAsLaidOut() {
        let g = makeExpansionGeometry()
        let pill = UIView(frame: g.origin)
        let (_, _, top, _, _) = self.make(configureContainer: { container in
            container.layer.sublayerTransform = CATransform3DScale(CATransform3DMakeTranslation(0.0, 27.0, 0.0), 0.92, 0.92, 1.0)
        }, configureSource: { source in
            source.home.addSubview(pill)
            source.originView = pill
        })
        guard let mask = top.layer.mask else {
            return XCTFail("no card mask")
        }
        // The conversion passes through the transform and its inverse: equal up to rounding.
        XCTAssertEqual(mask.frame.minX, g.origin.minX, accuracy: 1e-6)
        XCTAssertEqual(mask.frame.minY, g.origin.minY, accuracy: 1e-6)
        XCTAssertEqual(mask.frame.width, g.origin.width, accuracy: 1e-6)
        XCTAssertEqual(mask.frame.height, g.origin.height, accuracy: 1e-6)
    }

    // The drops' container merges them no sooner than the chat's pill and capsule stand apart at rest, so they do not
    // join in a neck as the close lands (or as the open starts) where the pill reaches close to the capsule.
    func test_dropsContainer_mergesNoCloserThanThePillAndCapsuleRest() {
        let g = makeExpansionGeometry()
        let roomy = self.make(opening: false)
        XCTAssertEqual(roomy.0.glassContainerSpacingForTesting, 30.0, accuracy: 1e-9)
        let pill = CGRect(x: g.companion!.minX - 10.0 - 250.0, y: g.origin.minY, width: 250.0, height: 44.0)
        let tight = self.make(opening: false, configureSource: { $0.origin = pill })
        XCTAssertLessThanOrEqual(tight.0.glassContainerSpacingForTesting, 10.0)
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

    // On the photo path the photo's view is the expanded photo (402 × 500), scaled on each axis apart into the frame's
    // photo, down to the flying circle. Its mask's corners are round on screen, so it lands as the chat's avatar's
    // circle. Corners drawn round in the photo's own points came out 19 pt across and 15 pt down at the circle, its
    // sides straight for 7 pt, which cut the chat's avatar at the sides until the transition ended.
    func test_photoPath_maskCornersAreRoundOnScreen() {
        let (renderer, container, _, _, _) = self.make(opening: false, configure: { $0.path = .photo })
        let choreography = ExpansionChoreography(geometry: makeExpansionGeometry(), path: .photo, duration: renderer.openSpring.response)
        for time: CGFloat in [0.0, 0.3, 0.6, 0.9] {
            renderer.update(time: time, isOpening: false, pose: .none)
            let frame = choreography.frame(ExpansionClock(time: time, isOpening: false), press: .none)
            guard let photo = frame.photo, let path = renderer.photoMaskForTesting.path else {
                return XCTFail("no photo at \(time)")
            }
            let wrapper = renderer.photoMaskForTesting.wrapper
            // The left corners, top and bottom: around each one's centre, just inside its radius and just outside.
            let corners: [(center: CGPoint, radius: CGFloat, down: CGFloat)] = [
                (CGPoint(x: photo.minX + frame.photoCornerRadii.topLeft, y: photo.minY + frame.photoCornerRadii.topLeft), frame.photoCornerRadii.topLeft, -1.0),
                (CGPoint(x: photo.minX + frame.photoCornerRadii.bottomLeft, y: photo.maxY - frame.photoCornerRadii.bottomLeft), frame.photoCornerRadii.bottomLeft, 1.0)
            ]
            for corner in corners where corner.radius > 2.0 {
                for degrees in stride(from: 5.0, through: 85.0, by: 10.0) {
                    let angle = CGFloat(degrees) * .pi / 180.0
                    func point(_ distance: CGFloat) -> CGPoint {
                        return wrapper.convert(CGPoint(x: corner.center.x - cos(angle) * distance, y: corner.center.y + corner.down * sin(angle) * distance), from: container.layer)
                    }
                    XCTAssertTrue(path.contains(point(corner.radius - 0.5)), "t=\(time) r=\(corner.radius) at \(degrees)°: inside")
                    XCTAssertFalse(path.contains(point(corner.radius + 0.5)), "t=\(time) r=\(corner.radius) at \(degrees)°: outside")
                }
            }
        }
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
        for (isOpening, screenCornerRadii) in [(true, CornerRadii(uniform: 62.0)), (false, CornerRadii(uniform: 62.0)), (true, duoCoverScreenCornerRadii), (false, duoCoverScreenCornerRadii)] {
            let (renderer, container, top, _, _) = self.make(configure: { $0.screenCornerRadii = screenCornerRadii })
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
        XCTAssertEqual(top.layer.mask?.cornerRadius ?? 0.0, g.screenCornerRadii.topLeft, accuracy: 0.01)
    }

    // A screen whose corners differ (iPhone Duo's cover screen): the card's mask takes four radii, the pill's capsule at 0
    // and the screen's own at 1, and keyframes them from the one to the other; it keeps no single radius.
    func test_differingScreenCorners_cardMaskTakesTheScreensCorners() {
        let (renderer, _, top, _, _) = self.make(configure: { $0.screenCornerRadii = duoCoverScreenCornerRadii })
        guard let mask = top.layer.mask else {
            return XCTFail("no card mask")
        }
        XCTAssertEqual(mask.cornerRadii, CornerRadii(uniform: 22.0))
        renderer.update(time: 1.0, isOpening: true, pose: .none)
        XCTAssertEqual(mask.cornerRadii, duoCoverScreenCornerRadii)
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { CGFloat($0 / 0.5) }
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: true, poses: times.map { _ in .none }, animationTime: { 0.0 }, reinstallTiming: { nil }, schedule: { _, _ in }))
        guard let animation = mask.animation(forKey: "navigationExpansion." + mask.cornerRadiiKeyPath) as? CAKeyframeAnimation, let values = animation.values as? [NSValue] else {
            return XCTFail("no corner radii keyframes")
        }
        XCTAssertEqual(values.first.flatMap { CornerRadii(boxedValue: $0) }, CornerRadii(uniform: 22.0))
        XCTAssertEqual(values.last.flatMap { CornerRadii(boxedValue: $0) }, duoCoverScreenCornerRadii)
        XCTAssertNil(mask.animation(forKey: "navigationExpansion.cornerRadius"))
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

    // A chat title tinted through its text layer (a `SplitTintTextView`: emoji in a layer of their own): the layer's
    // multiply colour runs from the chat's colour to the profile's on the render server, with no recolour group over the
    // title (which painted its emoji in the text colour), and is the chat's own again at the end.
    func test_multiplySource_tintsItsTextLayer_emojiUntouched() {
        let (renderer, _, _, source, _) = self.make(configureSource: { $0.titleColoring = .multiply([$0.titleTintLayer], .black) })
        XCTAssertFalse((source.titleView.superview?.layer.sublayers ?? []).contains(where: { ($0.compositingFilter as? String) == "sourceAtop" }), "no recolour group")
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { CGFloat($0 / 0.5) }
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: true, poses: times.map { _ in .none }, animationTime: { 0.0 }, reinstallTiming: { nil }, schedule: { _, _ in }))
        guard let animation = source.titleTintLayer.animation(forKey: "navigationExpansion.contentsMultiplyColor") as? CAKeyframeAnimation, let values = animation.values, let first = values.first, let last = values.last else {
            return XCTFail("no tint keyframes on the title's text layer")
        }
        func brightness(_ color: Any?) -> CGFloat {
            guard let color else {
                return -1.0
            }
            var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
            UIColor(cgColor: color as! CGColor).getRed(&r, green: &g, blue: &b, alpha: &a)
            return max(r, g, b)
        }
        XCTAssertEqual(brightness(first), 0.0, accuracy: 0.01, "from the chat's black")
        XCTAssertEqual(brightness(last), 1.0, accuracy: 0.01, "to the profile's white")
        renderer.end(atTop: true)
        XCTAssertEqual(brightness(source.titleTintLayer.layerTintColor), 0.0, accuracy: 0.01, "the chat's colour again")
    }

    private func timeline(from: CGFloat, to: CGFloat, opening: Bool) -> NavigationExpansionTimeline {
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { from + (to - from) * CGFloat($0 / 0.5) }
        return NavigationExpansionTimeline(timing: timing, times: times, isOpening: opening, poses: times.map { _ in .none }, animationTime: { 0.0 }, reinstallTiming: { nil }, schedule: { _, _ in })
    }

    // Without a companion (a forum's bar has its menu button where a chat has its avatar) the profile's avatar is drawn
    // all the way: a point above the chat's title at the start, growing above the title mid-way under an unmasked
    // circle, at its place at rest. It used to be lent and never placed, so it showed only once the profile had it back.
    func test_noCompanion_avatarIsDrawnAllTheWay() {
        let (renderer, container, _, _, destination) = self.make(configureSource: { $0.hasCompanion = false })
        let g = makeExpansionGeometry()
        for time: CGFloat in [0.0, 0.5, 1.0] {
            renderer.update(time: time, isOpening: true, pose: .none)
            XCTAssertNotNil(renderer.photoMaskForTesting.path, "t=\(time): the avatar is not masked out")
            let frame = destination.avatarView.convert(destination.avatarView.bounds, to: container)
            guard let title = renderer.labelHostCentersForTesting.first else {
                return XCTFail("no title host")
            }
            switch time {
            case 0.0:
                XCTAssertLessThan(frame.width, 1.0, "a point")
                XCTAssertLessThan(frame.midY, g.labels[0].sourceCenter.y, "above the title")
            case 0.5:
                XCTAssertGreaterThan(frame.width, 1.0)
                XCTAssertLessThan(frame.width, g.avatar!.width)
                XCTAssertLessThan(frame.maxY, title.y, "above the title")
            default:
                XCTAssertEqual(frame.minX, g.avatar!.minX, accuracy: 0.5)
                XCTAssertEqual(frame.minY, g.avatar!.minY, accuracy: 0.5)
                XCTAssertEqual(frame.width, g.avatar!.width, accuracy: 0.5)
            }
        }
    }

    // A forum's avatar is a rounded square, and so is the photo's mask while it flies: a point 10 pt in from the corner of
    // the 100 pt avatar is inside a quarter-side rounding and outside a circle. It used to fly as a circle.
    func test_roundedSquareAvatar_flyingMaskKeepsItsCorners() {
        let (renderer, _, _, _, _) = self.make(configureSource: { $0.hasCompanion = false }, configure: { $0.avatarCornerFraction = 0.25 })
        renderer.update(time: 1.0, isOpening: true, pose: .none)
        guard let path = renderer.photoMaskForTesting.path else {
            return XCTFail("no mask")
        }
        XCTAssertTrue(path.contains(CGPoint(x: 10.0, y: 10.0)), "a rounded square, not a circle")
        XCTAssertFalse(path.contains(CGPoint(x: 3.0, y: 3.0)), "still rounded")
    }

    // A status the chat's title does not show (a channel's), but the profile's does, comes from where it would stand under
    // the chat's title, at the title's scale, and fades in as the labels cross. It had no place, so it was taken from the
    // profile and shown only once the profile had it back.
    func test_missingStatus_comesFromUnderTheTitle() {
        let (renderer, _, _, _, _) = self.make(configureSource: { $0.hasStatus = false })
        let g = makeExpansionGeometry()
        XCTAssertEqual(renderer.destinationLabelHostsForTesting.count, 2, "the profile's status has a host")
        renderer.update(time: 0.0, isOpening: true, pose: .none)
        var hosts = renderer.destinationLabelHostsForTesting
        XCTAssertEqual(hosts[1].alpha, 0.0, accuracy: 1e-6)
        XCTAssertEqual(hosts[1].layer.position.x, g.labels[0].sourceCenter.x, accuracy: 1e-6)
        XCTAssertGreaterThan(hosts[1].layer.position.y, g.labels[0].sourceCenter.y, "under the chat's title")
        renderer.update(time: 0.5, isOpening: true, pose: .none)
        hosts = renderer.destinationLabelHostsForTesting
        XCTAssertGreaterThan(hosts[1].layer.position.y, hosts[0].layer.position.y, "under the title as it crosses")
        renderer.update(time: 1.0, isOpening: true, pose: .none)
        hosts = renderer.destinationLabelHostsForTesting
        XCTAssertEqual(hosts[1].alpha, 1.0, accuracy: 1e-6)
        XCTAssertEqual(hosts[1].layer.position.x, g.labels[1].destinationCenter.x, accuracy: 0.1)
        XCTAssertEqual(hosts[1].layer.position.y, g.labels[1].destinationCenter.y, accuracy: 0.1)
    }

    // The chat's avatar (live, animated avatars included) rides the flying circle above the profile's: at the open's
    // start it is exactly where it was, so nothing jumps when the circle takes over.
    func test_companion_ridesTheCircle_fromItsOwnPlace() {
        let (_, container, _, source, _) = self.make()
        let home = CGRect(x: makeExpansionGeometry().companion!.midX - 19.0, y: makeExpansionGeometry().companion!.midY - 19.0, width: 38.0, height: 38.0)
        XCTAssertFalse(source.avatarView.superview === source.home, "lent to the circle")
        let onScreen = source.avatarView.convert(source.avatarView.bounds, to: container)
        XCTAssertEqual(onScreen.midX, home.midX, accuracy: 0.5)
        XCTAssertEqual(onScreen.midY, home.midY, accuracy: 0.5)
        XCTAssertEqual(onScreen.width, home.width, accuracy: 0.5)
        XCTAssertEqual(source.avatarView.alpha, 1.0, accuracy: 0.001)
    }

    // The two avatars cross-fade on the clock: the chat's fades out over the open's first part and in over the close's
    // last part.
    func test_companion_crossfadesOnTheClock() {
        let (opening, _, _, openingSource, _) = self.make()
        opening.animate(timeline: self.timeline(from: 0.0, to: 1.0, opening: true))
        guard let fadeOut = openingSource.avatarView.layer.animation(forKey: "navigationExpansion.opacity") as? CAKeyframeAnimation, let outValues = fadeOut.values as? [NSNumber] else {
            return XCTFail("no fade on the open")
        }
        XCTAssertEqual(outValues.first?.doubleValue ?? 0.0, 1.0, accuracy: 0.001)
        XCTAssertEqual(outValues.last?.doubleValue ?? 1.0, 0.0, accuracy: 0.001)

        let (closing, _, _, closingSource, _) = self.make(opening: false)
        XCTAssertEqual(closingSource.avatarView.alpha, 0.0, accuracy: 0.001, "the profile's avatar shows at the close's start")
        closing.animate(timeline: self.timeline(from: 1.0, to: 0.0, opening: false))
        guard let fadeIn = closingSource.avatarView.layer.animation(forKey: "navigationExpansion.opacity") as? CAKeyframeAnimation, let inValues = fadeIn.values as? [NSNumber] else {
            return XCTFail("no fade on the close")
        }
        XCTAssertEqual(inValues.first?.doubleValue ?? 1.0, 0.0, accuracy: 0.001)
        XCTAssertEqual(inValues.last?.doubleValue ?? 0.0, 1.0, accuracy: 0.001)
    }

    // At the end the chat's avatar is home: its superview, frame and transform, shown.
    /// The followers of the status: one straight in the upper screen with a transform of its own, one in a container
    /// that scales it (the profile's subtitle container), both laid out beside the status's resting place.
    private func makeFollowers(_ destination: FakeDestination) -> (plain: UIView, scaled: UIView, container: UIView) {
        let top = destination.top!
        let plain = UIView(frame: CGRect(x: 40.0, y: 300.0, width: 60.0, height: 20.0))
        plain.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        top.addSubview(plain)
        let container = UIView(frame: CGRect(x: 100.0, y: 340.0, width: 200.0, height: 40.0))
        container.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        top.addSubview(container)
        let scaled = UIView(frame: CGRect(x: 20.0, y: 10.0, width: 80.0, height: 20.0))
        container.addSubview(scaled)
        destination.statusFollowers = [plain, scaled]
        return (plain, scaled, container)
    }

    // The status's followers move and scale with it as if they were part of it, in their own superviews: wherever the
    // status is, each stands where it stood beside the status's resting place, in the status's own (moving, scaling)
    // coordinates. Without that they stayed put while the status flew in and bounced.
    func test_followers_rideTheirLabel_inPlace() {
        var followers: (plain: UIView, scaled: UIView, container: UIView)?
        var rest: [CGRect] = []
        let (renderer, container, top, _, _) = self.make(configure: { destination in
            followers = self.makeFollowers(destination)
            let r = makeExpansionGeometry().labels[1].destinationCenter
            rest = [followers!.plain, followers!.scaled].map { $0.convert($0.bounds, to: destination.top!.superview!).offsetBy(dx: -r.x, dy: -r.y) }
        })
        guard let followers else {
            return XCTFail()
        }
        for time: CGFloat in [0.0, 0.3, 0.6, 1.03] {
            renderer.update(time: time, isOpening: true, pose: .none)
            guard let host = renderer.destinationLabelHostsForTesting.last else {
                return XCTFail("no status host")
            }
            for (view, restRect) in zip([followers.plain, followers.scaled], rest) {
                let inHost = view.layer.convert(view.bounds, to: host.layer)
                XCTAssertEqual(inHost.midX, restRect.midX, accuracy: 0.01, "t=\(time)")
                XCTAssertEqual(inHost.midY, restRect.midY, accuracy: 0.01, "t=\(time)")
                XCTAssertEqual(inHost.width, restRect.width, accuracy: 0.01, "t=\(time)")
                XCTAssertEqual(inHost.height, restRect.height, accuracy: 0.01, "t=\(time)")
            }
            if time == 0.3 {
                let onScreen = followers.plain.convert(followers.plain.bounds, to: container)
                let r = makeExpansionGeometry().labels[1].destinationCenter
                XCTAssertGreaterThan(abs(onScreen.midY - (rest[0].midY + r.y)), 5.0, "mid-flight the follower is away from its resting place")
            }
        }
        // They stay where they are in the tree.
        XCTAssertTrue(followers.plain.superview === top)
        XCTAssertTrue(followers.scaled.superview === followers.container)
    }

    // On keyframes too: each follower gets one transform keyframe per sample, ending where it rests.
    func test_followers_keyframed() {
        var followers: (plain: UIView, scaled: UIView, container: UIView)?
        let (renderer, _, _, _, _) = self.make(configure: { followers = self.makeFollowers($0) })
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
        let times = timing.sampleTimes.map { CGFloat($0 / 0.5) }
        renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: true, poses: times.map { _ in .none }, animationTime: { 0.0 }, reinstallTiming: { nil }, schedule: { _, _ in }))
        for (view, restTransform) in [(followers!.plain, CATransform3DMakeScale(0.8, 0.8, 1.0)), (followers!.scaled, CATransform3DIdentity)] {
            guard let animation = view.layer.animation(forKey: "navigationExpansion.transform") as? CAKeyframeAnimation, let values = animation.values as? [NSValue] else {
                return XCTFail("no follower keyframes")
            }
            XCTAssertEqual(values.count, timing.sampleTimes.count)
            XCTAssertFalse(CATransform3DEqualToTransform(values[0].caTransform3DValue, restTransform), "it starts away from its resting place")
            let last = values[values.count - 1].caTransform3DValue
            XCTAssertEqual(last.m11, restTransform.m11, accuracy: 0.01)
            XCTAssertEqual(last.m41, 0.0, accuracy: 0.5)
            XCTAssertEqual(last.m42, 0.0, accuracy: 0.5)
        }
    }

    // On every ending the followers keep their own transforms again, with no keyframes left.
    func test_followers_restoredOnEveryEnding() {
        for atTop in [true, false] {
            var followers: (plain: UIView, scaled: UIView, container: UIView)?
            let (renderer, _, _, _, _) = self.make(configure: { followers = self.makeFollowers($0) })
            let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.5, factor: 1.0)
            let times = timing.sampleTimes.map { CGFloat($0 / 0.5) }
            renderer.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: true, poses: times.map { _ in .none }, animationTime: { 0.0 }, reinstallTiming: { nil }, schedule: { _, _ in }))
            renderer.update(time: 0.4, isOpening: true, pose: .none)
            renderer.end(atTop: atTop)
            XCTAssertEqual(followers!.plain.transform, CGAffineTransform(scaleX: 0.8, y: 0.8))
            XCTAssertEqual(followers!.scaled.transform, .identity)
            XCTAssertNil(followers!.plain.layer.animation(forKey: "navigationExpansion.transform"))
            XCTAssertNil(followers!.scaled.layer.animation(forKey: "navigationExpansion.transform"))
        }
    }

    /// The page: one view straight in the upper screen with a transform of its own (the list), one in a container that
    /// scales it, and one holding the buttons (the profile's buttons' container, which also carries their platters'
    /// blur).
    private func makePage(_ destination: FakeDestination) -> (plain: UIView, scaled: UIView, holder: UIView) {
        let top = destination.top!
        let plain = UIView(frame: CGRect(x: 0.0, y: 360.0, width: 402.0, height: 514.0))
        plain.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        top.addSubview(plain)
        let container = UIView(frame: CGRect(x: 0.0, y: 300.0, width: 402.0, height: 60.0))
        container.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        top.addSubview(container)
        let scaled = UIView(frame: CGRect(x: 20.0, y: 10.0, width: 300.0, height: 24.0))
        container.addSubview(scaled)
        let holder = UIView(frame: top.bounds)
        top.addSubview(holder)
        for button in destination.buttons {
            holder.addSubview(button)
        }
        destination.pageViews = [plain, scaled, holder]
        return (plain, scaled, holder)
    }

    // The page below the header rides the status as one piece: wherever the status's host stands, the page views and
    // the buttons they hold stand as far from their resting places, overshoot included, each keeping its own transform.
    // Without it the avatar and the name bounced over a page that held still.
    func test_page_ridesTheStatus() {
        var page: (plain: UIView, scaled: UIView, holder: UIView)?
        var rest: [CGRect] = []
        let (renderer, container, _, _, destination) = self.make(configure: { destination in
            page = self.makePage(destination)
            rest = ([page!.plain, page!.scaled] + destination.buttons).map { $0.convert($0.bounds, to: destination.top!.superview!) }
        })
        guard let page else {
            return XCTFail()
        }
        let statusRest = makeExpansionGeometry().labels[1].destinationCenter.y
        var overshoot: CGFloat = 0.0
        for time: CGFloat in [0.6, 1.0, 1.04] {
            renderer.update(time: time, isOpening: true, pose: .none)
            guard let host = renderer.destinationLabelHostsForTesting.last else {
                return XCTFail("no status host")
            }
            let delta = host.layer.position.y - statusRest
            // The buttons only once they have appeared (their own rise and growth are over).
            let views = [page.plain, page.scaled] + (time >= 1.0 ? destination.buttons : [])
            for (view, restRect) in zip(views, rest) {
                let now = view.convert(view.bounds, to: container)
                XCTAssertEqual(now.midY - restRect.midY, delta, accuracy: 0.01, "t=\(time)")
                XCTAssertEqual(now.midX, restRect.midX, accuracy: 0.01, "t=\(time)")
                XCTAssertEqual(now.height, restRect.height, accuracy: 0.01, "t=\(time): its own transform is kept")
            }
            if time == 0.6 {
                XCTAssertLessThan(delta, -20.0, "mid-flight the page is still above its place")
            }
            if time == 1.04 {
                overshoot = delta
            }
        }
        XCTAssertGreaterThan(overshoot, 2.0, "the page goes past its place with the status")
    }

    // A button never takes the page itself: the view holding it carries it, so a button that took it too would move
    // twice (and a platter moved on its own is clipped by the profile's blur, which stays where it is).
    func test_page_buttonsTakeOnlyTheirOwnRise() {
        let (renderer, _, _, _, destination) = self.make(configure: { _ = self.makePage($0) })
        renderer.update(time: 0.6, isOpening: true, pose: .none)
        for (button, platter) in zip(destination.buttons, destination.platters) {
            XCTAssertLessThanOrEqual(button.layer.transform.m42, 14.0 + 1e-6)
            XCTAssertGreaterThanOrEqual(button.layer.transform.m42, 0.0)
            XCTAssertTrue(CATransform3DEqualToTransform(platter.layer.transform, button.layer.transform))
        }
        renderer.animate(timeline: self.timeline(from: 0.0, to: 1.0, opening: true))
        guard let animation = destination.buttons[0].layer.animation(forKey: "navigationExpansion.transform") as? CAKeyframeAnimation, let values = animation.values as? [NSValue] else {
            return XCTFail("no button keyframes")
        }
        XCTAssertEqual(values[0].caTransform3DValue.m42, 14.0, accuracy: 1e-6, "it starts 14 pt below its place, nothing more")
    }

    // On keyframes too, ending where the page rests; and the followers keep theirs beside it.
    func test_page_keyframed() {
        var page: (plain: UIView, scaled: UIView, holder: UIView)?
        var followers: (plain: UIView, scaled: UIView, container: UIView)?
        let (renderer, _, _, _, _) = self.make(configure: { destination in
            page = self.makePage(destination)
            followers = self.makeFollowers(destination)
        })
        let timeline = self.timeline(from: 0.0, to: 1.0, opening: true)
        renderer.animate(timeline: timeline)
        for (view, restTransform) in [(page!.plain, CATransform3DMakeScale(0.9, 0.9, 1.0)), (page!.scaled, CATransform3DIdentity), (page!.holder, CATransform3DIdentity)] {
            guard let animation = view.layer.animation(forKey: "navigationExpansion.transform") as? CAKeyframeAnimation, let values = animation.values as? [NSValue] else {
                return XCTFail("no page keyframes")
            }
            XCTAssertEqual(values.count, timeline.timing.sampleTimes.count)
            XCTAssertLessThan(values[0].caTransform3DValue.m42, -20.0, "it starts above its place, under the chat's status")
            let last = values[values.count - 1].caTransform3DValue
            XCTAssertEqual(last.m11, restTransform.m11, accuracy: 0.01)
            XCTAssertEqual(last.m42, 0.0, accuracy: 1.0)
        }
        for follower in [followers!.plain, followers!.scaled] {
            XCTAssertNotNil(follower.layer.animation(forKey: "navigationExpansion.transform"), "the followers still ride their label")
        }
    }

    // On every ending the page views keep their own transforms again, with no keyframes left.
    func test_page_restoredOnEveryEnding() {
        for atTop in [true, false] {
            var page: (plain: UIView, scaled: UIView, holder: UIView)?
            let (renderer, _, _, _, _) = self.make(configure: { page = self.makePage($0) })
            renderer.animate(timeline: self.timeline(from: 0.0, to: 1.0, opening: true))
            renderer.update(time: 0.7, isOpening: true, pose: .none)
            renderer.end(atTop: atTop)
            XCTAssertEqual(page!.plain.transform, CGAffineTransform(scaleX: 0.9, y: 0.9))
            XCTAssertEqual(page!.scaled.transform, .identity)
            XCTAssertEqual(page!.holder.transform, .identity)
            for view in [page!.plain, page!.scaled, page!.holder] {
                XCTAssertNil(view.layer.animation(forKey: "navigationExpansion.transform"))
            }
        }
    }

    // And the cover's edge keeps its own transform and sublayer transform again, with no keyframes left.
    func test_pageEdge_restoredOnEveryEnding() {
        for atTop in [true, false] {
            var cover: (edge: UIView, content: UIView)?
            let (renderer, _, _, _, _) = self.make(configure: { destination in
                cover = self.makePageEdge(destination)
                cover!.edge.layer.sublayerTransform = CATransform3DMakeTranslation(0.0, 2.0, 0.0)
            })
            renderer.animate(timeline: self.timeline(from: 0.0, to: 1.0, opening: true))
            renderer.update(time: 0.7, isOpening: true, pose: .none)
            renderer.end(atTop: atTop)
            XCTAssertTrue(CATransform3DIsIdentity(cover!.edge.layer.transform))
            XCTAssertTrue(CATransform3DEqualToTransform(cover!.edge.layer.sublayerTransform, CATransform3DMakeTranslation(0.0, 2.0, 0.0)))
            XCTAssertNil(cover!.edge.layer.animation(forKey: "navigationExpansion.transform"))
            XCTAssertNil(cover!.edge.layer.animation(forKey: "navigationExpansion.sublayerTransform"))
        }
    }

    /// The cover: a view clipping at its bottom edge, the page's top, tall above the screen as the profile's is, with its
    /// content (the gradient) at its bottom; it has a transform of its own.
    private func makePageEdge(_ destination: FakeDestination) -> (edge: UIView, content: UIView) {
        let top = destination.top!
        let edge = UIView(frame: CGRect(x: -3.0, y: 360.0 - 2000.0, width: 408.0, height: 2000.0))
        edge.clipsToBounds = true
        top.addSubview(edge)
        let content = UIView(frame: CGRect(x: 0.0, y: 2000.0 - 363.0, width: 408.0, height: 363.0))
        edge.addSubview(content)
        destination.pageEdgeViews = [edge]
        return (edge, content)
    }

    // The cover's bottom edge rides the page; its content holds still while the page comes in from above and lands with it
    // past its place: wherever the status's host stands, the edge stands as far from its place as the page does, and the
    // gradient as far as the page's overshoot. Riding in from above, the page's music strip (the cover's bottom band)
    // otherwise left a strip of the cover below it, 40 pt at first; held still through the overshoot, the gradient and
    // its pattern stood still while the avatar, the name and the page bounced over them.
    func test_pageEdge_ridesThePage_contentLandsWithIt() {
        var cover: (edge: UIView, content: UIView)?
        var rest: (edge: CGRect, content: CGRect)?
        let (renderer, container, _, _, _) = self.make(configure: { destination in
            cover = self.makePageEdge(destination)
            let screen = destination.top!.superview!
            rest = (cover!.edge.convert(cover!.edge.bounds, to: screen), cover!.content.convert(cover!.content.bounds, to: screen))
        })
        guard let cover, let rest else {
            return XCTFail()
        }
        let statusRest = makeExpansionGeometry().labels[1].destinationCenter.y
        for time: CGFloat in [0.6, 1.0, 1.04] {
            renderer.update(time: time, isOpening: true, pose: .none)
            guard let host = renderer.destinationLabelHostsForTesting.last else {
                return XCTFail("no status host")
            }
            let delta = host.layer.position.y - statusRest
            let edge = cover.edge.convert(cover.edge.bounds, to: container)
            XCTAssertEqual(edge.maxY - rest.edge.maxY, delta, accuracy: 0.01, "t=\(time)")
            XCTAssertEqual(edge.height, rest.edge.height, accuracy: 0.01, "t=\(time)")
            let content = cover.content.convert(cover.content.bounds, to: container)
            XCTAssertEqual(content.minY - rest.content.minY, max(delta, 0.0), accuracy: 0.01, "t=\(time): the gradient holds still until the page passes its place")
            XCTAssertEqual(content.height, rest.content.height, accuracy: 0.01, "t=\(time)")
            if time == 0.6 {
                XCTAssertLessThan(delta, -20.0, "mid-flight the edge is still above its place")
            }
            if time == 1.04 {
                XCTAssertGreaterThan(delta, 2.0, "the page goes past its place")
            }
        }
    }

    // On keyframes too: the edge's transform and its content's sublayer transform cancel while the edge is above its
    // place, and leave the content the page's overshoot past it.
    func test_pageEdge_keyframed() {
        var cover: (edge: UIView, content: UIView)?
        let (renderer, _, _, _, _) = self.make(configure: { cover = self.makePageEdge($0) })
        let timeline = self.timeline(from: 0.0, to: 1.04, opening: true)
        renderer.animate(timeline: timeline)
        guard let edge = cover?.edge, let transform = edge.layer.animation(forKey: "navigationExpansion.transform") as? CAKeyframeAnimation, let transforms = transform.values as? [NSValue], let sublayer = edge.layer.animation(forKey: "navigationExpansion.sublayerTransform") as? CAKeyframeAnimation, let sublayers = sublayer.values as? [NSValue] else {
            return XCTFail("no edge keyframes")
        }
        XCTAssertEqual(transforms.count, timeline.timing.sampleTimes.count)
        XCTAssertEqual(sublayers.count, transforms.count)
        XCTAssertLessThan(transforms[0].caTransform3DValue.m42, -20.0, "it starts above its place")
        var landed: CGFloat = 0.0
        for (edgeValue, contentValue) in zip(transforms, sublayers) {
            let edge = edgeValue.caTransform3DValue.m42
            let content = edge + contentValue.caTransform3DValue.m42
            XCTAssertEqual(content, max(edge, 0.0), accuracy: 1e-6)
            landed = max(landed, content)
        }
        XCTAssertGreaterThan(landed, 2.0, "the content lands with the overshoot")
    }

    // The rest of the background (the profile's gifts around its avatar) holds still while the page comes in and lands
    // with it past its place, as the cover's gradient does, keeping its own transform; it is restored on every ending.
    func test_landing_takesOnlyThePagesOvershoot() {
        for atTop in [true, false] {
            var landing: UIView?
            var rest: CGRect?
            let (renderer, container, _, _, _) = self.make(configure: { destination in
                let view = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 402.0, height: 360.0))
                view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                destination.top!.addSubview(view)
                destination.landingViews = [view]
                landing = view
                rest = view.convert(view.bounds, to: destination.top!.superview!)
            })
            guard let landing, let rest else {
                return XCTFail()
            }
            let statusRest = makeExpansionGeometry().labels[1].destinationCenter.y
            for time: CGFloat in [0.6, 1.0, 1.04] {
                renderer.update(time: time, isOpening: true, pose: .none)
                guard let host = renderer.destinationLabelHostsForTesting.last else {
                    return XCTFail("no status host")
                }
                let delta = host.layer.position.y - statusRest
                let now = landing.convert(landing.bounds, to: container)
                XCTAssertEqual(now.minY - rest.minY, max(delta, 0.0), accuracy: 0.01, "t=\(time)")
                XCTAssertEqual(now.height, rest.height, accuracy: 0.01, "t=\(time): its own transform is kept")
                if time == 1.04 {
                    XCTAssertGreaterThan(delta, 2.0, "the page goes past its place")
                }
            }
            renderer.animate(timeline: self.timeline(from: 0.0, to: 1.0, opening: true))
            renderer.end(atTop: atTop)
            XCTAssertEqual(landing.transform, CGAffineTransform(scaleX: 0.9, y: 0.9))
            XCTAssertNil(landing.layer.animation(forKey: "navigationExpansion.transform"))
        }
    }

    func test_companion_goesHome() {
        let (renderer, _, _, source, _) = self.make(opening: false)
        let home = CGRect(x: makeExpansionGeometry().companion!.midX - 19.0, y: makeExpansionGeometry().companion!.midY - 19.0, width: 38.0, height: 38.0)
        renderer.end(atTop: false)
        XCTAssertTrue(source.avatarView.superview === source.home)
        XCTAssertEqual(source.avatarView.frame, home)
        XCTAssertTrue(source.avatarView.transform.isIdentity)
        XCTAssertEqual(source.avatarView.alpha, 1.0)
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
            case current.cornerRadiiKeyPath:
                XCTAssertEqual(current.cornerRadii, CornerRadii(boxedValue: last as! NSValue), name, file: file, line: line)
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
