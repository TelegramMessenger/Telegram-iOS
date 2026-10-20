import XCTest
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
@testable import NavigationBarComponent

/// A 44pt button content that needs no bundle resources.
private final class PlatterTestButtonComponent: Component {
    typealias EnvironmentType = NavigationButtonEnvironment

    let width: CGFloat
    let color: UIColor?

    init(width: CGFloat, color: UIColor? = nil) {
        self.width = width
        self.color = color
    }

    static func ==(lhs: PlatterTestButtonComponent, rhs: PlatterTestButtonComponent) -> Bool {
        return lhs.width == rhs.width && lhs.color == rhs.color
    }

    final class View: UIView {
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonEnvironment>, transition: ComponentTransition) -> CGSize {
        view.backgroundColor = self.color
        return CGSize(width: self.width, height: availableSize.height)
    }
}

/// One window for the whole file: a test process traps after the suite if a window it made is freed.
private let platterTestWindow = UIWindow(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0))

/// Hears what Core Animation tells a layer about entering and leaving the visible layer tree, as an animated emoji layer
/// does to start and stop playing.
private final class OrderProbeLayer: CALayer {
    private(set) var isOrderedIn = false

    override func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.isOrderedIn = true
        } else if event == kCAOnOrderOut {
            self.isOrderedIn = false
        }
        return nil
    }
}

/// The capsules of a navigation transition as iOS 27 animates them (SwiftUI GlassContainer under the bar's v2 platter
/// container; docs/superpowers/specs/2026-10-13-native-navigation-glass-platters-ios27-re.md).
final class NavigationBarPlatterTransitionViewTests: XCTestCase {
    private let time = ManualAnimationTime()

    override func setUp() {
        super.setUp()
        self.time.attach()
    }

    override func tearDown() {
        self.time.detach()
        super.tearDown()
    }

    private func advance(_ view: NavigationBarPlatterTransitionView, by seconds: Double) {
        self.time.advance(by: seconds)
    }

    private func makeTheme() -> NavigationBarTheme {
        return NavigationBarTheme(overallDarkAppearance: false, buttonColor: .black, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .gray, accentForegroundColor: .white)
    }

    private func button(_ id: String, width: CGFloat = 44.0, tint: NavigationBarComponent.Button.Tint = .generic, color: UIColor? = nil) -> NavigationBarComponent.Button {
        return NavigationBarComponent.Button(id: id, content: .custom(AnyComponent(PlatterTestButtonComponent(width: width, color: color))), tint: tint, action: { _ in })
    }

    private func side(back: NavigationBarComponent.Back? = .back, left: NavigationBarComponent.Button? = nil, right: [NavigationBarComponent.Button]) -> NavigationBarPlatterTransitionView.Side {
        let content = NavigationBarComponent.Content(title: .text(""), back: back, leftButton: left, rightButtons: right, backPressed: {})
        return NavigationBarPlatterTransitionView.Side(content: content, theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, trailingButtonsInset: 0.0, rowFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 44.0))
    }

    private func makeView(bottom: NavigationBarPlatterTransitionView.Side, top: NavigationBarPlatterTransitionView.Side) -> NavigationBarPlatterTransitionView {
        let view = NavigationBarPlatterTransitionView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 88.0))
        view.setSides(bottom: bottom, top: top)
        return view
    }

    private func text(_ id: String) -> NavigationBarComponent.Button {
        return NavigationBarComponent.Button(id: id, content: .text(title: id, isBold: false), action: { _ in })
    }

    // UIKit pairs every section by index from the edge: a bar with three right pills morphs each into the other bar's
    // pill at the same index, the innermost one included.
    func test_threeRightPills_pairByIndex() {
        let view = self.makeView(bottom: self.side(right: [self.text("a"), self.text("b"), self.button("c")]), top: self.side(right: [self.text("x"), self.text("y"), self.button("z")]))
        view.beginTransition(isInteractive: false, toTop: true)
        let identity = view.platterIdentityForTesting(.trailing(2))
        XCTAssertNotNil(identity)
        self.time.advance(by: 1.5)
        XCTAssertEqual(view.platterIdentityForTesting(.trailing(2)), identity)
        XCTAssertEqual(view.platterStateForTesting(.trailing(2))?.opacity ?? 0.0, 1.0, accuracy: 0.001)
    }

    // A leftover pill merges into the other bar's nearest platter (SwiftUI's resolver), not always the outermost: the
    // third pill of three collapses into the second of two.
    func test_leftoverPill_collapsesIntoTheNearestPlatter() {
        let top = self.side(right: [self.text("x"), self.text("y")])
        let view = self.makeView(bottom: self.side(right: [self.text("a"), self.text("b"), self.button("c")]), top: top)
        view.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: 0.6)
        guard let leftover = view.platterStateForTesting(.trailing(2)), let inner = view.platterStateForTesting(.trailing(1)), let outer = view.platterStateForTesting(.trailing(0)) else {
            XCTFail("missing platters")
            return
        }
        XCTAssertLessThan(abs(leftover.frame.midX - inner.frame.midX), abs(leftover.frame.midX - outer.frame.midX))
    }

    // The pulse as curves: SwiftUI's formula on a rising curve and two falling ones that start after their delays, at
    // rest exactly at scale 1.
    func test_pulseCurve_isTheStepPulseOnExactDelays() {
        let size = CGSize(width: 80.0, height: 44.0)
        let curve = NavigationBarGlassPulseCurve(size: size, startTime: 0.0)
        var stepped = NavigationBarGlassPulse(size: size)
        for _ in 0 ..< 24 {
            stepped.step(1.0 / 120.0)
        }
        XCTAssertEqual(curve.scale(at: 0.2).height, stepped.scale.height, accuracy: 0.01)
        XCTAssertEqual(curve.scale(at: curve.restTime).width, 1.0, accuracy: 1e-9)
        XCTAssertEqual(curve.scale(at: curve.restTime).height, 1.0, accuracy: 1e-9)
        // Re-based onto a clock whose zero is its start, a pulse is the same motion.
        let later = NavigationBarGlassPulseCurve(size: size, startTime: 0.05)
        XCTAssertEqual(later.scale(at: 0.1).height, later.rebased(by: 0.05).scale(at: 0.05).height, accuracy: 1e-9)
        XCTAssertEqual(later.scale(at: 0.1).height, curve.scale(at: 0.05).height, accuracy: 1e-9)
    }


    private func chatsSide(innerPressScale: CGFloat = 1.0) -> NavigationBarPlatterTransitionView.Side {
        var side = self.side(back: nil, right: [self.button("compose", tint: .accent), self.button("story"), self.button("proxy")])
        side.trailingPressScales = [1.0, innerPressScale]
        return side
    }

    private func chatSide() -> NavigationBarPlatterTransitionView.Side {
        return self.side(right: [self.button("avatar")])
    }

    // UIKit pairs a bar's right platters by index from the edge (`SectionID(index, owner)`, one owner per bar): Chats'
    // accent compose circle and a chat's avatar platter are one shape, whose items swap and whose tint cross-fades; the
    // story/proxy capsule beside the circle is the inner platter.
    func test_outermostRightPlatters_areOneShape_acrossAnAccentCircle() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame, CGRect(x: 390.0 - 16.0 - 44.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, CGRect(x: 390.0 - 16.0 - 44.0 - 12.0 - 88.0, y: 0.0, width: 88.0, height: 44.0))
        let identity = view.platterIdentityForTesting(.trailing(0))
        self.time.advance(by: 0.05)
        XCTAssertNotNil(view.platterStateForTesting(.trailing(0))?.fadingTintAlpha)
        XCTAssertEqual(view.itemsStateForTesting(.trailing(0)).count, 2)
        self.time.advance(by: 1.0)
        XCTAssertEqual(view.platterIdentityForTesting(.trailing(0)), identity)
    }

    // Two bars without a circle pair their capsules as before: the capsule is the outermost platter, nothing is inner.
    func test_withoutACircle_theCapsuleIsTheOutermostPlatter() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit")]), top: self.side(right: [self.button("a"), self.button("b")]))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertNotNil(view.platterStateForTesting(.trailing(0)))
        XCTAssertNil(view.platterStateForTesting(.trailing(1)))
    }

    // The press UIKit was drawing on the capsule beside the circle carries on, on the inner platter.
    func test_innerCapsulePress_isCarriedOn() {
        let view = self.makeView(bottom: self.chatsSide(innerPressScale: 1.3), top: self.chatSide())
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.press ?? 0.0, 1.3, accuracy: 0.0001)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.press ?? 0.0, 1.0, accuracy: 0.0001)
    }

    // The kick: no motion before 0.05 s, out toward the target, taken back from 0.15 s, at rest at 0.
    func test_kickCurve_goesOutThenComesBack() {
        let kick = NavigationBarKickCurve(offset: CGSize(width: 13.0, height: 0.0), startTime: 1.0)
        XCTAssertEqual(kick.progress(at: 1.04), 0.0)
        let atReturn = kick.progress(at: 1.15)
        XCTAssertGreaterThan(atReturn, 0.6)
        XCTAssertLessThan(atReturn, 0.8)
        XCTAssertLessThan(kick.progress(at: 1.3), atReturn)
        XCTAssertEqual(kick.translation(at: kick.restTime).width, 0.0, accuracy: 0.01)
    }

    // The delay for the sampled geometry (spec): centres 84.67 pt apart on a 402 x 54 container is 0.152 s.
    func test_matchedDelay_isUIKitsFormula() {
        XCTAssertEqual(NavigationBarGlassSettings.matchedDelay(offset: CGSize(width: 84.67, height: 0.0), containerWidth: 402.0), 0.152, accuracy: 0.0005)
        XCTAssertEqual(NavigationBarGlassSettings.matchedDelay(offset: CGSize(width: 4000.0, height: 0.0), containerWidth: 402.0), 0.083 + 0.166, accuracy: 0.0001)
    }

    // Chats -> a chat: the story/proxy capsule has no partner and collapses into the chat's outermost (avatar) platter
    // after UIKit's minimum delay, shrinking toward the `.match` appearance as it goes. The distance term never applies
    // here: `Resolver.resolvedMinOffset` (SwiftUICore 27 0x1c6ea85b0) resolves a removed entry's offset to zero, so the
    // delay is `minDelay` (filmed on iOS 27: the capsule moves ~0.08 s after the circle starts changing).
    func test_leftoverInnerCapsule_collapsesIntoTheOutermostPlatter_afterTheDelay() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.beginTransition(isInteractive: false, toTop: true)
        let source = CGRect(x: 230.0, y: 0.0, width: 88.0, height: 44.0)
        let delay = NavigationBarGlassSettings.matchedMinDelay
        self.time.advance(by: delay - 0.01)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, source)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.opacity ?? 0.0, 1.0, accuracy: 0.001)
        self.time.advance(by: 0.04)
        XCTAssertGreaterThan(view.platterStateForTesting(.trailing(1))?.frame.midX ?? 0.0, source.midX)
        self.time.advance(by: 0.07)
        let moving = view.platterStateForTesting(.trailing(1))
        XCTAssertGreaterThan(moving?.frame.midX ?? 0.0, source.midX)
        XCTAssertLessThan(moving?.opacity ?? 1.0, 1.0)
        XCTAssertLessThan(moving?.scale.width ?? 1.0, 1.0)
        self.time.advance(by: 1.5)
        XCTAssertNil(view.platterStateForTesting(.trailing(1)))
    }

    // The pop: the capsule waits invisible on the avatar platter, then grows out of it into its place.
    func test_leftoverInnerCapsule_growsOutOfTheOutermostPlatter() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.beginTransition(isInteractive: false, toTop: false)
        let start = view.platterStateForTesting(.trailing(1))
        XCTAssertEqual(start?.frame, CGRect(x: 330.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertEqual(start?.opacity ?? 1.0, 0.0, accuracy: 0.001)
        self.time.advance(by: 1.5)
        let end = view.platterStateForTesting(.trailing(1))
        XCTAssertEqual(end?.frame, CGRect(x: 230.0, y: 0.0, width: 88.0, height: 44.0))
        XCTAssertEqual(end?.opacity ?? 0.0, 1.0, accuracy: 0.001)
    }

    // A swipe back released: the capsule grows out of the avatar on the release, not while the finger drags.
    func test_leftoverInnerCapsule_aReleasedSwipe_growsOnRelease() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.beginTransition(isInteractive: true, toTop: false)
        self.time.advance(by: 0.3)
        XCTAssertNil(view.platterStateForTesting(.trailing(1)))
        view.endInteraction(towardTop: false)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, CGRect(x: 330.0, y: 0.0, width: 44.0, height: 44.0))
    }

    private func assertRect(_ rect: CGRect?, _ expected: CGRect, accuracy: CGFloat = 0.01, file: StaticString = #filePath, line: UInt = #line) {
        guard let rect else {
            XCTFail("no rect", file: file, line: line)
            return
        }
        XCTAssertEqual(rect.minX, expected.minX, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(rect.minY, expected.minY, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(rect.width, expected.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(rect.height, expected.height, accuracy: accuracy, file: file, line: line)
    }

    // The collapsing capsule merges into the outermost platter as native glass does (measured on iOS 27): the bar's
    // platters are elements of one SDF layer at smoothness 12, and the capsule's element keeps opacity 1 and an identity
    // transform while its frame shrinks (72 x 35 at 0.25 s into the push). So both glass shapes share one container at
    // spacing 12, the capsule's glass keeps full opacity and draws its shrinking frame as its own size, and only its items
    // fade.
    func test_leftoverInnerCapsule_mergesIntoTheOutermostPlattersGlass_whileCollapsing() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.beginTransition(isInteractive: false, toTop: true)
        let container = view.glassContainerForTesting(.trailing(1))
        XCTAssertNotNil(container)
        XCTAssertTrue(container === view.glassContainerForTesting(.trailing(0)))
        XCTAssertEqual(container?.spacing, 12.0)
        // The glass view's own size is the end state, 0.2 x the 44 pt circle (a transform would leave it 44 x 44).
        XCTAssertEqual(view.glassViewForTesting(.trailing(1))?.bounds.width ?? 0.0, 8.8, accuracy: 0.01)
        XCTAssertEqual(view.glassViewForTesting(.trailing(1))?.bounds.height ?? 0.0, 8.8, accuracy: 0.01)
        self.time.advance(by: NavigationBarGlassSettings.matchedMinDelay + 0.1)
        let moving = view.platterStateForTesting(.trailing(1))
        XCTAssertLessThan(moving?.opacity ?? 1.0, 1.0)
        XCTAssertEqual(moving?.glassOpacity ?? 0.0, 1.0, accuracy: 0.001)
        XCTAssertLessThan(moving?.glassFrame.height ?? 44.0, 44.0)
    }

    // The pop: the capsule's glass waits merged inside the circle at 0.2 x, at full opacity, and grows out of it (its
    // element was 22 x 17 at the circle's left edge 0.12 s into the pop, opacity 1).
    func test_leftoverInnerCapsule_growsOutOfTheOutermostPlattersGlass() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.beginTransition(isInteractive: false, toTop: false)
        XCTAssertNotNil(view.glassContainerForTesting(.trailing(1)))
        XCTAssertTrue(view.glassContainerForTesting(.trailing(1)) === view.glassContainerForTesting(.trailing(0)))
        let start = view.platterStateForTesting(.trailing(1))
        XCTAssertEqual(start?.opacity ?? 1.0, 0.0, accuracy: 0.001)
        XCTAssertEqual(start?.glassOpacity ?? 0.0, 1.0, accuracy: 0.001)
        self.assertRect(start?.glassFrame, CGRect(x: 352.0 - 4.4, y: 22.0 - 4.4, width: 8.8, height: 8.8))
    }

    // The pop's capsule grows out of the circle at once: an inserted entry's offset resolves to nil
    // (`Resolver.resolvedMinOffset`), so it gets no delay (filmed on iOS 27: it pokes out of the circle as the circle
    // starts changing).
    func test_leftoverInnerCapsule_growsOutOfTheOutermostPlatter_withoutADelay() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.beginTransition(isInteractive: false, toTop: false)
        self.time.advance(by: 0.03)
        XCTAssertGreaterThan(view.platterStateForTesting(.trailing(1))?.glassFrame.width ?? 0.0, 8.8 + 1.0)
    }

    // The kick's offset is the platter's own centre minus its partner's (SwiftUICore 27: `partner.geometryResult(to:
    // entry)` from `source(target:)` at 0x1c6ea58fc, which is `to.mid - self.mid` at 0x1c717dcb0): a collapsing capsule
    // is kicked away from the circle it goes into, so it lags; a growing one is kicked further out.
    func test_leftoverInnerCapsule_isKickedAwayFromItsPartner() {
        let push = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        push.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: NavigationBarGlassSettings.matchedMinDelay + 0.15)
        XCTAssertLessThan(push.platterStateForTesting(.trailing(1))?.kick.width ?? 0.0, -1.0)
        let pop = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        pop.beginTransition(isInteractive: false, toTop: false)
        self.time.advance(by: 0.15)
        XCTAssertLessThan(pop.platterStateForTesting(.trailing(1))?.kick.width ?? 0.0, -1.0)
    }

    // SwiftUI pulses both shapes of a matched insertion or removal (`adjustMatchedEntry` writes a scale pulse to the
    // entry's state at 0x1c6ea2848 and to its partner's at 0x1c6ea3568), anchored at `GeometryResult.transitionAnchor`
    // (x = 1 for a partner in the right half). So the circle swells leftward with its right edge fixed, into the gap, and
    // the capsule keeps its right end toward the circle (filmed on iOS 27: on the pop the two stay joined by a neck until
    // ~0.28 s). The capsule's pulse starts with its morph, after the delay on a push.
    func test_matchedMorph_pulsesBothShapes_anchoredAtTheTrailingEdge() {
        func unpulsedMaxX(_ state: NavigationBarPlatterTransitionView.PlatterState) -> CGFloat {
            return state.frame.midX + state.frame.width * state.scale.width * state.press * 0.5
        }
        let pop = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        pop.beginTransition(isInteractive: false, toTop: false)
        self.time.advance(by: 0.1)
        let circle = pop.platterStateForTesting(.trailing(0))
        XCTAssertGreaterThan(circle?.pulse.width ?? 1.0, 1.01)
        XCTAssertEqual(circle?.glassFrame.maxX ?? 0.0, circle.map(unpulsedMaxX) ?? 1.0, accuracy: 0.01)
        let capsule = pop.platterStateForTesting(.trailing(1))
        XCTAssertGreaterThan(capsule?.pulse.width ?? 1.0, 1.01)
        XCTAssertEqual(capsule?.glassFrame.maxX ?? 0.0, capsule.map(unpulsedMaxX) ?? 1.0, accuracy: 0.01)

        let push = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        push.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: NavigationBarGlassSettings.matchedMinDelay - 0.01)
        XCTAssertEqual(push.platterStateForTesting(.trailing(1))?.pulse.width ?? 0.0, 1.0, accuracy: 0.0001)
        let pushCircle = push.platterStateForTesting(.trailing(0))
        XCTAssertGreaterThan(pushCircle?.pulse.width ?? 1.0, 1.01)
        XCTAssertEqual(pushCircle?.glassFrame.maxX ?? 0.0, pushCircle.map(unpulsedMaxX) ?? 1.0, accuracy: 0.01)
        self.time.advance(by: 0.08)
        XCTAssertGreaterThan(push.platterStateForTesting(.trailing(1))?.pulse.width ?? 1.0, 1.01)
    }

    // Without native glass (before iOS 26, or the custom glass setting) a container merges nothing, so the collapsing
    // capsule keeps a container of its own and fades with it, as it did before the merge.
    func test_leftoverInnerCapsule_withoutNativeGlass_fadesInAContainerOfItsOwn() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.glassMergesShapes = { false }
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertNotNil(view.glassContainerForTesting(.trailing(1)))
        XCTAssertFalse(view.glassContainerForTesting(.trailing(1)) === view.glassContainerForTesting(.trailing(0)))
        self.time.advance(by: NavigationBarGlassSettings.matchedMinDelay + 0.1)
        XCTAssertLessThan(view.platterStateForTesting(.trailing(1))?.glassOpacity ?? 1.0, 1.0)
    }

    // The chat header's glass pill is its bar's second right platter in a transition (asked 2026-10-15). Chats' story/proxy
    // capsule (index 1) morphs into it as one shape, its icons swapping for the title, instead of collapsing into the
    // avatar.
    private func titlePill(_ frame: CGRect, contents: UIView) -> NavigationBarTransitionTitlePill {
        return NavigationBarTransitionTitlePill(frame: frame, signature: ObjectIdentifier(contents), lendContent: { contents })
    }

    func test_titlePill_isTheSecondRightPlatter_theCapsuleMorphsIntoIt() {
        let pillFrame = CGRect(x: 110.0, y: 0.0, width: 170.0, height: 44.0)
        let contents = UIView()
        var chat = self.chatSide()
        chat.titlePill = self.titlePill(pillFrame, contents: contents)
        let view = self.makeView(bottom: self.chatsSide(), top: chat)
        view.beginTransition(isInteractive: false, toTop: true)
        let identity = view.platterIdentityForTesting(.trailing(1))
        XCTAssertNotNil(identity)
        XCTAssertEqual(view.itemsStateForTesting(.trailing(1)).count, 2)
        self.time.advance(by: 0.2)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.opacity ?? 0.0, 1.0, accuracy: 0.001)
        self.time.advance(by: 1.5)
        XCTAssertEqual(view.platterIdentityForTesting(.trailing(1)), identity)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, pillFrame)
        XCTAssertNotNil(contents.superview)
    }

    // Lent contents are told they are back on screen. An animated emoji layer (`InlineStickerItemLayer`) plays only
    // between Core Animation's `onOrderIn` and `onOrderOut`; lending moves the contents out of the window (`onOrderOut`),
    // so the platter must take them in where Core Animation asks for `onOrderIn`, which it skips while actions are
    // disabled. Otherwise the chat title's emoji status stood still for the whole transition.
    func test_titlePill_lentContents_hearTheyAreOnScreenAgain() {
        let probe = OrderProbeLayer()
        let contents = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 170.0, height: 44.0))
        contents.layer.addSublayer(probe)
        let title = UIView(frame: CGRect(x: 110.0, y: 0.0, width: 170.0, height: 44.0))
        title.addSubview(contents)
        platterTestWindow.addSubview(title)
        defer {
            title.removeFromSuperview()
        }
        XCTAssertTrue(probe.isOrderedIn, "precondition: the window orders layers in")
        let wrapper = UIView(frame: contents.frame)
        var chat = self.chatSide()
        chat.titlePill = NavigationBarTransitionTitlePill(frame: title.frame, signature: ObjectIdentifier(contents), lendContent: {
            wrapper.addSubview(contents)
            return wrapper
        })
        let view = self.makeView(bottom: self.chatsSide(), top: chat)
        platterTestWindow.addSubview(view)
        defer {
            view.removeFromSuperview()
        }
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertTrue(wrapper.window != nil, "the lent contents are in the transition")
        XCTAssertTrue(probe.isOrderedIn)
    }

    // Chat -> chat: pill to pill as one shape, the titles swapping inside it.
    func test_titlePill_toPill_isOneShape_itsContentsSwapping() {
        let toFrame = CGRect(x: 120.0, y: 0.0, width: 150.0, height: 44.0)
        var from = self.chatSide()
        from.titlePill = self.titlePill(CGRect(x: 110.0, y: 0.0, width: 170.0, height: 44.0), contents: UIView())
        var to = self.chatSide()
        to.titlePill = self.titlePill(toFrame, contents: UIView())
        let view = self.makeView(bottom: from, top: to)
        view.beginTransition(isInteractive: false, toTop: true)
        let identity = view.platterIdentityForTesting(.trailing(1))
        XCTAssertNotNil(identity)
        XCTAssertEqual(view.itemsStateForTesting(.trailing(1)).count, 2)
        self.time.advance(by: 1.5)
        XCTAssertEqual(view.platterIdentityForTesting(.trailing(1)), identity)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, toFrame)
        XCTAssertEqual(view.itemsStateForTesting(.trailing(1)).count, 1)
    }

    // The pop: the pill morphs back into Chats' capsule.
    func test_titlePill_popsIntoChatsCapsule() {
        let pillFrame = CGRect(x: 110.0, y: 0.0, width: 170.0, height: 44.0)
        var chat = self.chatSide()
        chat.titlePill = self.titlePill(pillFrame, contents: UIView())
        let view = self.makeView(bottom: self.chatsSide(), top: chat)
        view.beginTransition(isInteractive: false, toTop: false)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, pillFrame)
        self.time.advance(by: 1.5)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, CGRect(x: 230.0, y: 0.0, width: 88.0, height: 44.0))
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.opacity ?? 0.0, 1.0, accuracy: 0.001)
    }

    // Without a right button the pill is still the second right platter: Chats' compose circle (index 0) has no partner
    // and leaves in place, the capsule morphs into the pill.
    func test_titlePill_withoutARightButton_staysTheSecondRightPlatter() {
        let pillFrame = CGRect(x: 110.0, y: 0.0, width: 170.0, height: 44.0)
        var chat = self.side(right: [])
        chat.titlePill = self.titlePill(pillFrame, contents: UIView())
        let view = self.makeView(bottom: self.chatsSide(), top: chat)
        view.beginTransition(isInteractive: false, toTop: true)
        let circle = view.platterStateForTesting(.trailing(0))?.frame
        self.time.advance(by: 0.2)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame, circle)
        XCTAssertLessThan(view.platterStateForTesting(.trailing(0))?.opacity ?? 1.0, 1.0)
        self.time.advance(by: 1.5)
        XCTAssertNil(view.platterStateForTesting(.trailing(0)))
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, pillFrame)
    }

    // A bar with two right platters already (circle and capsule) has no slot for its pill: the capsule stays the second
    // right platter and the pill is left to its screen.
    func test_titlePill_besideTwoRightPlatters_isLeftToItsScreen() {
        var chats = self.chatsSide()
        chats.titlePill = self.titlePill(CGRect(x: 110.0, y: 0.0, width: 170.0, height: 44.0), contents: UIView())
        let view = self.makeView(bottom: chats, top: self.chatSide())
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, CGRect(x: 230.0, y: 0.0, width: 88.0, height: 44.0))
    }

    // Contacts -> a chat: Contacts has no platter in the pill's slot (only its "+"), so the pill has nothing to morph from
    // (asked 2026-10-18). It materializes in place instead of growing out of the "+", whose glass it does not merge with.
    func test_titlePill_withoutACounterpart_materializesInPlace() {
        let pillFrame = CGRect(x: 110.0, y: 0.0, width: 170.0, height: 44.0)
        var chat = self.chatSide()
        chat.titlePill = self.titlePill(pillFrame, contents: UIView())
        let view = self.makeView(bottom: self.side(back: nil, left: self.text("Sort"), right: [self.button("add")]), top: chat)
        view.beginTransition(isInteractive: false, toTop: true)
        let start = view.platterStateForTesting(.trailing(1))
        XCTAssertEqual(start?.frame, pillFrame)
        XCTAssertEqual(start?.opacity ?? 1.0, 0.0, accuracy: 0.001)
        XCTAssertEqual(start?.scale.width ?? 0.0, 186.0 / 170.0, accuracy: 0.0001)
        XCTAssertFalse(view.glassContainerForTesting(.trailing(1)) === view.glassContainerForTesting(.trailing(0)))
        self.time.advance(by: 0.1)
        let moving = view.platterStateForTesting(.trailing(1))
        XCTAssertEqual(moving?.frame, pillFrame)
        XCTAssertEqual(moving?.kick, CGSize())
        XCTAssertGreaterThan(moving?.opacity ?? 0.0, 0.0)
        self.time.advance(by: 1.5)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, pillFrame)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.opacity ?? 0.0, 1.0, accuracy: 0.001)
    }

    // The pop back to Contacts: the pill dematerializes where it is instead of collapsing into the "+".
    func test_titlePill_withoutACounterpart_dematerializesInPlace() {
        let pillFrame = CGRect(x: 110.0, y: 0.0, width: 170.0, height: 44.0)
        var chat = self.chatSide()
        chat.titlePill = self.titlePill(pillFrame, contents: UIView())
        let view = self.makeView(bottom: self.side(back: nil, left: self.text("Sort"), right: [self.button("add")]), top: chat)
        view.beginTransition(isInteractive: false, toTop: false)
        XCTAssertFalse(view.glassContainerForTesting(.trailing(1)) === view.glassContainerForTesting(.trailing(0)))
        self.time.advance(by: 0.1)
        let leaving = view.platterStateForTesting(.trailing(1))
        XCTAssertEqual(leaving?.frame, pillFrame)
        XCTAssertEqual(leaving?.kick, CGSize())
        XCTAssertLessThan(leaving?.opacity ?? 1.0, 1.0)
        XCTAssertLessThan(leaving?.glassOpacity ?? 1.0, 1.0)
        XCTAssertGreaterThan(leaving?.scale.width ?? 0.0, 1.0)
        self.time.advance(by: 1.5)
        XCTAssertNil(view.platterStateForTesting(.trailing(1)))
    }

    // Once it has collapsed, the capsule's glass leaves the container it merged in.
    func test_leftoverInnerCapsule_collapsed_leavesTheContainerItMergedIn() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.beginTransition(isInteractive: false, toTop: true)
        let glass = view.glassViewForTesting(.trailing(1))
        XCTAssertNotNil(glass?.superview)
        self.time.advance(by: 1.5)
        XCTAssertNil(view.platterStateForTesting(.trailing(1)))
        XCTAssertNil(glass?.superview)
    }

    // Platters that dematerialize in place keep glass containers of their own: a container's opacity is what fades glass
    // (a shape's own alpha does not).
    func test_innerCapsuleDematerializingInPlace_keepsAGlassContainerOfItsOwn() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.side(right: []))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertNotNil(view.glassContainerForTesting(.trailing(1)))
        XCTAssertFalse(view.glassContainerForTesting(.trailing(1)) === view.glassContainerForTesting(.trailing(0)))
        self.time.advance(by: 0.1)
        XCTAssertLessThan(view.platterStateForTesting(.trailing(1))?.glassOpacity ?? 1.0, 1.0)
    }

    // A pop to Chats from a bar with no right platter: there is no old platter for the capsule to grow out of (UIKit's
    // inserted entry matches only an old one), so it materializes in place, as the circle does.
    func test_innerCapsule_materializesInPlace_whenTheOtherBarHadNoRightPlatter() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.side(right: []))
        view.beginTransition(isInteractive: false, toTop: false)
        let start = view.platterStateForTesting(.trailing(1))
        XCTAssertEqual(start?.frame, CGRect(x: 230.0, y: 0.0, width: 88.0, height: 44.0))
        XCTAssertGreaterThan(start?.scale.width ?? 0.0, 1.0)
    }

    // Chats' buttons changing during the push (a bar applying its buttons a frame late): the collapsing capsule keeps its
    // delay and target, it does not start over.
    func test_leftoverInnerCapsule_keepsCollapsing_whenABarChangesMidTransition() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: 0.2)
        let before = view.platterStateForTesting(.trailing(1))?.frame
        view.setSides(bottom: self.chatsSide(), top: self.side(right: [self.button("avatar"), self.button("call")]))
        self.time.advance(by: 0.01)
        XCTAssertGreaterThan(view.platterStateForTesting(.trailing(1))?.frame.midX ?? 0.0, before?.midX ?? 0.0)
    }

    // With nothing on the other bar to go to it dematerializes in place, as before.
    func test_leftoverInnerCapsule_withNothingToGoTo_leavesInPlace() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.side(right: []))
        view.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: 0.1)
        let state = view.platterStateForTesting(.trailing(1))
        XCTAssertEqual(state?.frame, CGRect(x: 230.0, y: 0.0, width: 88.0, height: 44.0))
        XCTAssertGreaterThan(state?.scale.width ?? 0.0, 1.0)
    }

    // Under Reduce Motion UIKit's resolver does not match: in place, no delay.
    func test_leftoverInnerCapsule_underReduceMotion_leavesInPlace() {
        let view = self.makeView(bottom: self.chatsSide(), top: self.chatSide())
        view.isReduceMotionEnabled = { true }
        view.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: 0.1)
        XCTAssertEqual(view.platterStateForTesting(.trailing(1))?.frame, CGRect(x: 230.0, y: 0.0, width: 88.0, height: 44.0))
        XCTAssertLessThan(view.platterStateForTesting(.trailing(1))?.opacity ?? 1.0, 1.0)
    }

    // A capsule only the incoming screen has materializes in place: scale 1.2 (at most 16 pt larger), opacity 0 and blur
    // 10 at the start, to identity on the glass transition spring, Spring(0.416, bounce 0.25), so it undershoots its size
    // by ~0.6% (measured on iOS 27: a 62.33 pt Edit capsule appearing in a push reached 62.03 pt).
    func test_oneSidedCapsule_materializesInPlace() {
        let view = self.makeView(bottom: self.side(right: []), top: self.side(right: [self.button("edit")]))
        view.beginTransition(isInteractive: false, toTop: true)
        guard let start = view.platterStateForTesting(.trailing(0)) else {
            XCTFail("no trailing capsule")
            return
        }
        XCTAssertEqual(start.opacity, 0.0)
        XCTAssertEqual(start.scale.width, 1.2, accuracy: 0.0001)
        XCTAssertEqual(start.blur, 10.0)
        XCTAssertEqual(start.frame, CGRect(x: 390.0 - 16.0 - 44.0, y: 0.0, width: 44.0, height: 44.0))
        var minScale: CGFloat = 2.0
        for _ in 0 ..< 240 {
            self.time.advance(by: 1.0 / 120.0)
            minScale = min(minScale, view.platterStateForTesting(.trailing(0))?.scale.width ?? 2.0)
        }
        let end = view.platterStateForTesting(.trailing(0))
        XCTAssertEqual(end?.opacity ?? 0.0, 1.0, accuracy: 0.001)
        XCTAssertEqual(end?.scale.width ?? 0.0, 1.0, accuracy: 0.001)
        XCTAssertEqual(end?.blur ?? 10.0, 0.0, accuracy: 0.01)
        XCTAssertEqual(minScale, 1.0 - 0.0284 * 0.2, accuracy: 0.0005)
    }

    // The capsule's appearance runs on the glass transition spring, not the critically damped `.materialize` one (measured
    // on iOS 27 with the reference app's probe, 2026-10-14: a capsule appearing in a push reached 0.023, 0.092, 0.188 and
    // 0.409 of its way at 1, 2, 3 and 5 frames; one leaving in a pop 0.297, 0.516 and 0.938 at 4, 6 and 12 frames).
    // Spring(0.416, bounce 0.25) is 0.5185 of the way at 0.1 s and 0.9359 at 0.2 s; the critically damped one 0.4456 and
    // 0.8039, a ghost of the leaving capsule three times as strong at 0.2 s.
    func test_oneSidedCapsule_appearsAndLeavesOnTheTransitionSpring() {
        let appearing = self.makeView(bottom: self.side(right: []), top: self.side(right: [self.button("edit")]))
        appearing.beginTransition(isInteractive: false, toTop: true)
        let leaving = self.makeView(bottom: self.side(right: [self.button("edit")]), top: self.side(right: []))
        leaving.beginTransition(isInteractive: false, toTop: true)
        for _ in 0 ..< 12 {
            self.time.advance(by: 1.0 / 120.0)
        }
        XCTAssertEqual(appearing.platterStateForTesting(.trailing(0))?.opacity ?? 0.0, 0.5185, accuracy: 0.002)
        XCTAssertEqual(appearing.platterStateForTesting(.trailing(0))?.scale.width ?? 0.0, 1.0 + 0.2 * (1.0 - 0.5185), accuracy: 0.0005)
        XCTAssertEqual(leaving.platterStateForTesting(.trailing(0))?.opacity ?? 0.0, 1.0 - 0.5185, accuracy: 0.002)
        XCTAssertEqual(leaving.platterStateForTesting(.trailing(0))?.scale.width ?? 0.0, 1.0 + 0.2 * 0.5185, accuracy: 0.0005)
        for _ in 0 ..< 12 {
            self.time.advance(by: 1.0 / 120.0)
        }
        XCTAssertEqual(appearing.platterStateForTesting(.trailing(0))?.opacity ?? 0.0, 0.9359, accuracy: 0.002)
        XCTAssertEqual(leaving.platterStateForTesting(.trailing(0))?.opacity ?? 0.0, 1.0 - 0.9359, accuracy: 0.002)
    }

    // The scale is capped so the capsule grows by at most 16 pt per axis: a 100 pt capsule starts at 1.16 wide.
    func test_materializeScale_isCappedAtSixteenPoints() {
        let view = self.makeView(bottom: self.side(right: []), top: self.side(right: [self.button("wide", width: 100.0)]))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.scale.width ?? 0.0, 116.0 / 100.0, accuracy: 0.0001)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.scale.height ?? 0.0, 1.2, accuracy: 0.0001)
    }

    // A capsule only the outgoing screen has dematerializes in place and is gone at the end.
    func test_oneSidedCapsule_dematerializesInPlace() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit")]), top: self.side(right: []))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.opacity, 1.0)
        for _ in 0 ..< 240 {
            self.time.advance(by: 1.0 / 120.0)
        }
        XCTAssertNil(view.platterStateForTesting(.trailing(0)))
    }

    // A capsule both screens have is one glass shape: it morphs to its new frame on Spring(0.416, bounce 0.25), so a
    // shrinking capsule briefly undershoots its new width.
    func test_matchedCapsule_morphsOnTheBouncyTransitionSpring() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit", width: 80.0)]), top: self.side(right: [self.button("done", tint: .accent)]))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 80.0, accuracy: 0.001)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.opacity, 1.0)
        var minWidth: CGFloat = 1000.0
        for _ in 0 ..< 240 {
            self.time.advance(by: 1.0 / 120.0)
            minWidth = min(minWidth, view.platterStateForTesting(.trailing(0))?.frame.width ?? 1000.0)
        }
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 44.0, accuracy: 0.01)
        XCTAssertLessThan(minWidth, 43.5)
    }

    // The same capsule with the same items does not move (the back circle between two screens with back).
    func test_unchangedCapsule_staysPut() {
        let view = self.makeView(bottom: self.side(right: []), top: self.side(right: []))
        view.beginTransition(isInteractive: false, toTop: true)
        let frame = view.platterStateForTesting(.leading)?.frame
        XCTAssertNotNil(frame)
        self.time.advance(by: 0.05)
        XCTAssertEqual(view.platterStateForTesting(.leading)?.frame, frame)
        XCTAssertEqual(view.platterStateForTesting(.leading)?.opacity, 1.0)
        XCTAssertFalse(view.isAnimating)
    }

    // A swipe back shows the outgoing screen's capsules as they are while the finger drags (measured on native,
    // 2026-10-14: a "Select Messages" capsule kept its width over a whole drag toward a screen with "Edit"), and switches
    // them to the bar the swipe ends on when it is let go.
    func test_swipe_capsulesStayPutWhileDragging_andSwitchOnRelease() {
        let view = self.makeView(bottom: self.side(right: [self.button("search", width: 44.0)]), top: self.side(right: [self.button("edit", width: 80.0)]))
        // A pop: the top screen leaves.
        view.beginTransition(isInteractive: true, toTop: false)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 80.0, accuracy: 0.001)
        self.run(view, seconds: 2.0)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 80.0, accuracy: 0.001)
        view.endInteraction(towardTop: false)
        self.run(view, seconds: 2.0)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 44.0, accuracy: 0.01)
    }

    // A swipe back that takes a running push over does not touch the capsules either: they carry on to the top bar's,
    // where the push sent them, and switch only when the swipe is let go.
    func test_caughtPush_capsulesCarryOnUnaffected() {
        let view = self.makeView(bottom: self.side(right: [self.button("search", width: 44.0)]), top: self.side(right: [self.button("edit", width: 80.0)]))
        view.beginTransition(isInteractive: false, toTop: true)
        self.run(view, seconds: 0.1)
        view.beginInteraction()
        self.run(view, seconds: 2.0)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 80.0, accuracy: 0.01)
        view.endInteraction(towardTop: false)
        self.run(view, seconds: 2.0)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 44.0, accuracy: 0.01)
    }

    // A swipe let go toward the top bar ends there: a bar change after that heads the capsules for the top bar's new
    // ones, not back to the bottom bar's.
    func test_swipeLetGoTowardTheTop_laterBarChangesKeepTheTopBar() {
        let bottom = self.side(right: [self.button("search", width: 44.0)])
        let view = self.makeView(bottom: bottom, top: self.side(right: [self.button("edit", width: 80.0)]))
        view.beginTransition(isInteractive: true, toTop: false)
        view.endInteraction(towardTop: true)
        view.setSides(bottom: bottom, top: self.side(right: [self.button("edit", width: 100.0)]))
        self.run(view, seconds: 2.0)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 100.0, accuracy: 0.01)
    }

    private func run(_ view: NavigationBarPlatterTransitionView, seconds: CGFloat, step: CGFloat = 1.0 / 240.0, sample: (CGFloat) -> Void = { _ in }) {
        var time: CGFloat = 0.0
        while time < seconds - 1e-9 {
            self.time.advance(by: Double(step))
            time += step
            sample(time)
        }
    }

    // A kept capsule whose items change (Edit -> Done) pulses as iOS 27's does (measured on the native reference app:
    // height peaks at ~0.11 s at 1.2 for both a text capsule and the checkmark circle; width later). The peak is
    // min((L + 16) / L, 1.2) per axis.
    func test_itemChange_pulsesTheCapsule() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit", width: 64.0)]), top: self.side(right: [self.button("done", width: 76.0, tint: .accent)]))
        view.beginTransition(isInteractive: false, toTop: true)
        var maxPulseY: CGFloat = 1.0
        var maxPulseX: CGFloat = 1.0
        var timeOfMaxY: CGFloat = 0.0
        var timeOfMaxX: CGFloat = 0.0
        self.run(view, seconds: 1.0, sample: { time in
            guard let pulse = view.platterStateForTesting(.trailing(0))?.pulse else {
                return
            }
            if pulse.height > maxPulseY {
                maxPulseY = pulse.height
                timeOfMaxY = time
            }
            if pulse.width > maxPulseX {
                maxPulseX = pulse.width
                timeOfMaxX = time
            }
        })
        XCTAssertEqual(maxPulseY, 1.2, accuracy: 0.02)
        XCTAssertEqual(timeOfMaxY, 0.113, accuracy: 0.03)
        XCTAssertGreaterThan(timeOfMaxX, timeOfMaxY)
        // The width falls later (0.142 s), while the bouncy rise overshoots, so it peaks a little higher.
        XCTAssertGreaterThan(maxPulseX, 1.2)
        XCTAssertLessThan(maxPulseX, 1.25)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.pulse.width ?? 0.0, 1.0, accuracy: 0.001)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.pulse.height ?? 0.0, 1.0, accuracy: 0.001)
    }

    // The same capsule with the same items does not pulse.
    func test_unchangedItems_doNotPulse() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit")]), top: self.side(right: [self.button("edit")]))
        view.beginTransition(isInteractive: false, toTop: true)
        var maxPulse: CGFloat = 1.0
        self.run(view, seconds: 0.5, sample: { _ in
            maxPulse = max(maxPulse, view.platterStateForTesting(.trailing(0))?.pulse.height ?? 1.0)
        })
        XCTAssertEqual(maxPulse, 1.0)
    }

    // A replaced item enters with the materialize look (1.2, at most +16 pt; transparent; blur 10), not from 0.2.
    // Items swapped in a kept capsule are matched (`AppearanceSettings.match`, glass RE §2.3): the new ones grow from a
    // fifth of their size, transparent and blurred, while the old ones shrink to it, on the transition spring (measured on
    // iOS 27, Edit -> Select Messages in a push: the new label's scale went 0.200 -> 1.000 with an overshoot to 1.034, its
    // opacity 0.023, 0.092, 0.188, 0.296, 0.430 at 1-5 frames; the old one's opacity overshot to -0.024).
    func test_itemChange_newItemsEnterMaterialized() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit", width: 64.0)]), top: self.side(right: [self.button("done", width: 76.0, tint: .accent)]))
        view.beginTransition(isInteractive: false, toTop: true)
        guard let incoming = view.itemsStateForTesting(.trailing(0)).first(where: { $0.isTop }) else {
            XCTFail("no incoming items")
            return
        }
        XCTAssertEqual(incoming.opacity, 0.0)
        XCTAssertEqual(incoming.blur, 10.0)
        XCTAssertEqual(incoming.scale.width, 0.2, accuracy: 0.0001)
        XCTAssertEqual(incoming.scale.height, 0.2, accuracy: 0.0001)
        for _ in 0 ..< 12 {
            self.time.advance(by: 1.0 / 120.0)
        }
        guard let arrived = view.itemsStateForTesting(.trailing(0)).first(where: { $0.isTop }), let left = view.itemsStateForTesting(.trailing(0)).first(where: { !$0.isTop }) else {
            XCTFail("no items")
            return
        }
        // Spring(0.416, bounce 0.25) is 0.5185 of the way at 0.1 s.
        XCTAssertEqual(arrived.opacity, 0.5185, accuracy: 0.002)
        XCTAssertEqual(arrived.scale.width, 0.2 + 0.8 * 0.5185, accuracy: 0.001)
        XCTAssertEqual(left.opacity, 1.0 - 0.5185, accuracy: 0.002)
        XCTAssertEqual(left.scale.width, 1.0 - 0.8 * 0.5185, accuracy: 0.001)
    }

    // A tint change cross-fades on the one shape (measured: critically damped, ~0.3 s response): the old tint's glass
    // fades out above the new one and is gone at the end.
    func test_tintChange_crossFades() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit", width: 64.0)]), top: self.side(right: [self.button("done", width: 76.0, tint: .accent)]))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.fadingTintAlpha ?? 0.0, 1.0)
        self.run(view, seconds: 0.082)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.fadingTintAlpha ?? 0.0, 0.46, accuracy: 0.06)
        self.run(view, seconds: 1.0)
        XCTAssertNil(view.platterStateForTesting(.trailing(0))?.fadingTintAlpha)
    }

    // Edit -> the checkmark circle (44 pt): native peaks at 1.2 in height too (measured 45 -> 54.3 pt with the edge),
    // not (44 + 16) / 44.
    func test_itemChange_toACircle_peaksAtTheCap() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit", width: 64.0)]), top: self.side(right: [self.button("done", width: 44.0, tint: .accent)]))
        view.beginTransition(isInteractive: false, toTop: true)
        var maxPulseY: CGFloat = 1.0
        self.run(view, seconds: 0.6, sample: { _ in
            maxPulseY = max(maxPulseY, view.platterStateForTesting(.trailing(0))?.pulse.height ?? 1.0)
        })
        XCTAssertEqual(maxPulseY, 1.2, accuracy: 0.02)
    }

    // A list screen applies its bar buttons a few milliseconds after its push begins: a capsule that arrives in the
    // incoming bar mid-transition materializes then, instead of appearing only when the bar takes over at the end.
    func test_capsuleArrivingMidTransition_materializes() {
        let view = self.makeView(bottom: self.side(right: []), top: self.side(right: []))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertNil(view.platterStateForTesting(.trailing(0)))
        self.time.advance(by: 0.01)
        view.setSides(bottom: self.side(right: []), top: self.side(right: [self.button("edit")]))
        guard let start = view.platterStateForTesting(.trailing(0)) else {
            XCTFail("the arriving capsule is not shown")
            return
        }
        XCTAssertEqual(start.opacity, 0.0)
        self.run(view, seconds: 1.0)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.opacity ?? 0.0, 1.0, accuracy: 0.001)
    }

    // A list screen's buttons arrive just after its push begins (ItemListController applies its first state after the list
    // has made the screen ready), so at the start the incoming bar has no trailing capsule and Edit's starts to leave.
    // When Done arrives, Edit's capsule must turn into Done's, as SwiftUI's resolver reuses a removed entry that matches
    // an insertion (`Resolver.updateInsertion` -> `reuseEntry`), not vanish while a new one materializes.
    func test_capsuleArrivingMidTransition_takesOverTheLeavingCapsule() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit", width: 64.0)]), top: self.side(right: []))
        view.beginTransition(isInteractive: false, toTop: true)
        let leaving = view.platterIdentityForTesting(.trailing(0))
        XCTAssertNotNil(leaving)
        self.time.advance(by: 1.0 / 60.0)
        view.setSides(bottom: self.side(right: [self.button("edit", width: 64.0)]), top: self.side(right: [self.button("done", width: 44.0, tint: .accent)]))
        XCTAssertEqual(view.platterIdentityForTesting(.trailing(0)), leaving)
        // Still (almost) fully there: it barely began to leave.
        XCTAssertGreaterThan(view.platterStateForTesting(.trailing(0))?.opacity ?? 0.0, 0.9)
        // Edit's items leave and Done's arrive, and the tint cross-fades on the one shape.
        let items = view.itemsStateForTesting(.trailing(0))
        XCTAssertTrue(items.contains(where: { !$0.isTop && $0.opacity > 0.9 }), "\(items)")
        XCTAssertTrue(items.contains(where: { $0.isTop && $0.opacity < 0.1 }), "\(items)")
        XCTAssertNotNil(view.platterStateForTesting(.trailing(0))?.fadingTintAlpha)
        self.run(view, seconds: 1.0)
        XCTAssertEqual(view.platterIdentityForTesting(.trailing(0)), leaving)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.opacity ?? 0.0, 1.0, accuracy: 0.001)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame ?? CGRect(), CGRect(x: 390.0 - 16.0 - 44.0, y: 0.0, width: 44.0, height: 44.0))
    }

    // The same late arrival on the leading side: the incoming bar starts with a back button (the default), so the back
    // circle is kept, and then its close button arrives. The back chevron must leave and the close cross materialize,
    // not the cross replace the chevron in one frame.
    func test_itemsChangingMidTransition_crossFadeInTheKeptCapsule() {
        let view = self.makeView(bottom: self.side(right: []), top: self.side(right: []))
        view.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: 1.0 / 60.0)
        XCTAssertEqual(view.itemsStateForTesting(.leading).count, 1)
        view.setSides(bottom: self.side(right: []), top: self.side(back: nil, left: self.button("close"), right: []))
        let items = view.itemsStateForTesting(.leading)
        XCTAssertTrue(items.contains(where: { $0.opacity > 0.9 }), "\(items)")
        XCTAssertTrue(items.contains(where: { $0.isTop && $0.opacity < 0.1 }), "\(items)")
        // What has left is removed when the capsule comes to rest (here after its pulse, ~1.06 s).
        self.run(view, seconds: 1.5)
        let end = view.itemsStateForTesting(.leading)
        XCTAssertEqual(end.count, 1, "\(end)")
        XCTAssertEqual(end.first?.opacity ?? 0.0, 1.0, accuracy: 0.001)
    }

    // What leaves in that case is the items as they were, live: their own views, handed over by the content view before
    // it builds the new ones (never a still copy, which freezes what animates and, for items swapped in a frame earlier,
    // shows nothing at all).
    func test_itemsChangingMidTransition_leaveAsTheyWere_live() {
        let view = self.makeView(bottom: self.side(back: nil, left: self.button("first", color: .red), right: []), top: self.side(back: nil, left: self.button("first", color: .red), right: []))
        view.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: 1.0 / 60.0)
        view.setSides(bottom: self.side(back: nil, left: self.button("first", color: .red), right: []), top: self.side(back: nil, left: self.button("second", color: .blue), right: []))
        guard let leaving = view.leavingItemsViewsForTesting(.leading).first else {
            XCTFail("nothing leaves")
            return
        }
        XCTAssertFalse(leaving is UIImageView)
        func descendants(_ view: UIView) -> [UIView] {
            return view.subviews + view.subviews.flatMap(descendants)
        }
        XCTAssertTrue(descendants(leaving).contains(where: { $0.backgroundColor == .red }), "the old (red) button's own view leaves")
        XCTAssertFalse(descendants(leaving).contains(where: { $0.backgroundColor == .blue }))
    }

    // Under Reduce Motion SwiftUI's glass appears and disappears by opacity alone, with no scale or blur, for capsules and
    // for the items in them (glass RE §2.1, §3.3).
    func test_reduceMotion_materializesWithoutScaleOrBlur() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit", width: 64.0)]), top: self.side(back: nil, right: [self.button("done", width: 44.0, tint: .accent)]))
        view.isReduceMotionEnabled = { true }
        view.beginTransition(isInteractive: false, toTop: true)
        // The back circle only the bottom bar has dematerializes.
        self.run(view, seconds: 0.1)
        guard let leading = view.platterStateForTesting(.leading) else {
            XCTFail("no leaving back circle")
            return
        }
        XCTAssertLessThan(leading.opacity, 1.0)
        XCTAssertEqual(leading.scale.width, 1.0)
        XCTAssertEqual(leading.blur, 0.0)
        // Done's items arrive in Edit's capsule.
        guard let incoming = view.itemsStateForTesting(.trailing(0)).first(where: { $0.isTop }) else {
            XCTFail("no incoming items")
            return
        }
        XCTAssertGreaterThan(incoming.opacity, 0.0)
        XCTAssertLessThan(incoming.opacity, 1.0)
        XCTAssertEqual(incoming.scale.width, 1.0)
        XCTAssertEqual(incoming.blur, 0.0)
    }

    // Under Reduce Motion a capsule whose items change does not pulse, and the morph runs without its bounce (the
    // transition spring at the same response, critically damped: glass RE §2.2, §3.2).
    func test_reduceMotion_noPulseAndNoBounce() {
        let view = self.makeView(bottom: self.side(right: [self.button("edit", width: 80.0)]), top: self.side(right: [self.button("done", tint: .accent)]))
        view.isReduceMotionEnabled = { true }
        view.beginTransition(isInteractive: false, toTop: true)
        var maxPulse: CGFloat = 1.0
        var minWidth: CGFloat = 1000.0
        self.run(view, seconds: 1.0, sample: { _ in
            maxPulse = max(maxPulse, view.platterStateForTesting(.trailing(0))?.pulse.height ?? 1.0)
            minWidth = min(minWidth, view.platterStateForTesting(.trailing(0))?.frame.width ?? 1000.0)
        })
        XCTAssertEqual(maxPulse, 1.0)
        XCTAssertGreaterThanOrEqual(minWidth, 44.0 - 0.01)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 44.0, accuracy: 0.01)
    }

    // A push or pop started from a bar button: UIKit is still drawing the press on that capsule (at most 16 pt larger,
    // here a 44 pt circle at 60 pt). The transition's capsule takes it over and releases it on UIKit's own spring, damping
    // 0.375 and response 0.4 (read from `_UIFlexInteraction` at run time), instead of snapping to rest: a 0.28 undershoot
    // at ~0.22 s, then rest. Native's capsule is the same glass entry throughout, so its release simply goes on.
    func test_pressedCapsule_releasesOnUIKitsSpring() {
        var bottom = self.side(right: [])
        bottom.leadingPressScale = 60.0 / 44.0
        let view = self.makeView(bottom: self.side(right: []), top: self.side(right: []))
        view.setSides(bottom: self.side(right: []), top: { var top = self.side(right: []); top.leadingPressScale = 60.0 / 44.0; return top }())
        view.beginTransition(isInteractive: false, toTop: false)
        XCTAssertEqual(view.platterStateForTesting(.leading)?.press ?? 0.0, 60.0 / 44.0, accuracy: 1e-6)
        var minPress: CGFloat = 2.0
        var timeOfMin: CGFloat = 0.0
        self.run(view, seconds: 1.5, sample: { time in
            let press = view.platterStateForTesting(.leading)?.press ?? 1.0
            if press < minPress {
                minPress = press
                timeOfMin = time
            }
        })
        XCTAssertEqual(minPress, 1.0 - (60.0 / 44.0 - 1.0) * 0.28, accuracy: 0.01)
        XCTAssertEqual(timeOfMin, 0.216, accuracy: 0.02)
        XCTAssertEqual(view.platterStateForTesting(.leading)?.press ?? 0.0, 1.0, accuracy: 0.001)
        let _ = bottom
    }

    // UIKit's press glow on the capsule that started the transition goes on in the transition's capsule, fading as
    // UIKit's does after release: a critically damped spring with a 0.5 s response (fit to the native BigGlow's opacity
    // within ±0.005 per 60 Hz frame, 2026-10-14).
    func test_pressedCapsule_carriesUIKitsGlow_andFadesIt() {
        var top = self.side(right: [])
        top.leadingPressScale = 60.0 / 44.0
        top.leadingPressGlow = 1.0
        let view = self.makeView(bottom: self.side(right: []), top: top)
        view.beginTransition(isInteractive: false, toTop: false)
        XCTAssertEqual(view.platterStateForTesting(.leading)?.glow ?? 0.0, 1.0, accuracy: 1e-6)
        self.run(view, seconds: 0.15)
        let omegaT: CGFloat = 2.0 * .pi / 0.5 * 0.15
        XCTAssertEqual(view.platterStateForTesting(.leading)?.glow ?? 0.0, (1.0 + omegaT) * exp(-omegaT), accuracy: 0.002)
        self.run(view, seconds: 2.0)
        XCTAssertEqual(view.platterStateForTesting(.leading)?.glow ?? 1.0, 0.0, accuracy: 0.001)
        XCTAssertFalse(view.isAnimating)
    }

    // Slow Animations slows the capsules too: with a factor of 10, 0.5 s of real time is 0.05 s of animation.
    func test_capsules_respectTheAnimationDurationFactor() {
        self.time.factor = 10.0
        let view = self.makeView(bottom: self.side(right: []), top: self.side(right: [self.button("edit")]))
        view.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: 0.5)
        // Spring(0.416, bounce 0.25) is 0.1935 of the way at 0.05 s.
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.opacity ?? -1.0, 0.1935, accuracy: 0.002)
    }

    // The capsules play on the render server: a materializing capsule's scale and opacity are keyframes sampled from
    // its curves, beginning at the commit, and no display link runs.
    func test_materializingCapsule_isKeyframed() {
        let view = self.makeView(bottom: self.side(right: []), top: self.side(right: [self.button("edit", width: 80.0)]))
        view.beginTransition(isInteractive: false, toTop: true)
        guard let container = view.containerViewForTesting(.trailing(0)), let transform = container.layer.animation(forKey: "navigationGlass.transform") as? CAKeyframeAnimation, let opacity = container.layer.animation(forKey: "navigationGlass.opacity") as? CAKeyframeAnimation else {
            XCTFail("no keyframes")
            return
        }
        XCTAssertEqual(transform.beginTime, 0.0)
        let curve = NavigationSpringCurve(from: 1.0, target: 0.0, spring: NavigationTransitionSpring(duration: 0.416, bounce: 0.25), rest: .glass(0.001))
        XCTAssertEqual(CGFloat((opacity.values?[12] as? NSNumber)?.doubleValue ?? -1.0), 1.0 - curve.value(at: 0.1), accuracy: 0.002)
        XCTAssertEqual((transform.values?[12] as? NSValue)?.caTransform3DValue.m11 ?? 0.0, 1.0 + curve.value(at: 0.1) * 0.2, accuracy: 0.002)
        XCTAssertFalse(view.hasDisplayLinkForTesting)
    }

    // A bar changing mid-transition re-bakes from the state at now, explicitly at now, carrying the velocity.
    func test_barChangeMidTransition_rebakesFromNow() {
        let view = self.makeView(bottom: self.side(right: [self.button("a", width: 80.0)]), top: self.side(right: [self.button("a", width: 80.0)]))
        view.beginTransition(isInteractive: false, toTop: true)
        self.advance(view, by: 0.1)
        view.setSides(bottom: self.side(right: [self.button("a", width: 80.0)]), top: self.side(right: [self.button("a", width: 120.0)]))
        guard let container = view.containerViewForTesting(.trailing(0)), let position = container.layer.animation(forKey: "navigationGlass.position") as? CAKeyframeAnimation else {
            XCTFail("no keyframes")
            return
        }
        XCTAssertEqual(position.beginTime, container.layer.convertTime(self.time.now, from: nil), accuracy: 1e-9)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 80.0, accuracy: 0.01)
        self.advance(view, by: 1.0)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, 120.0, accuracy: 0.01)
    }

    // Rest is the clock's deadline: leaving capsules are removed and the view reports settled once.
    func test_settles_atTheDeadline() {
        let view = self.makeView(bottom: self.side(right: [self.button("a")]), top: self.side(right: []))
        var settled = 0
        view.onSettled = {
            settled += 1
        }
        view.beginTransition(isInteractive: false, toTop: true)
        self.advance(view, by: 0.3)
        XCTAssertTrue(view.isAnimating)
        XCTAssertEqual(settled, 0)
        self.advance(view, by: 1.5)
        XCTAssertFalse(view.isAnimating)
        XCTAssertNil(view.platterStateForTesting(.trailing(0)))
        XCTAssertEqual(settled, 1)
    }

    // Slow Animations: the keyframes run at speed 1/factor.
    func test_slowAnimations_keyframesRunAtSpeed() {
        self.time.factor = 10.0
        let view = self.makeView(bottom: self.side(right: []), top: self.side(right: [self.button("edit")]))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(view.containerViewForTesting(.trailing(0))?.layer.animation(forKey: "navigationGlass.opacity")?.speed ?? 0.0, 0.1, accuracy: 1e-6)
    }

    private func duoSide(back: NavigationBarComponent.Back? = .back, right: [NavigationBarComponent.Button], hidesColumnButtons: Bool = false) -> NavigationBarPlatterTransitionView.Side {
        var side = self.side(back: back, right: right)
        side.columnFrame = CGRect(x: 390.0 - 60.0, y: 120.0, width: 44.0, height: 478.0)
        side.hidesColumnButtons = hidesColumnButtons
        return side
    }

    /// A `.custom` button is a column item (`navigationBarIsColumnItem`), so the test buttons go to the column.
    private func iconButton(_ id: String, tint: NavigationBarComponent.Button.Tint = .generic) -> NavigationBarComponent.Button {
        return self.button(id, tint: tint)
    }

    // The column's back circle is a capsule like the row's: it morphs between bars, on the same spring.
    func test_columnBack_morphsBetweenBars() {
        let view = self.makeView(bottom: self.duoSide(right: []), top: self.duoSide(right: [self.iconButton("search")]))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertNotNil(view.platterStateForTesting(.column(0)))
        XCTAssertNil(view.platterStateForTesting(.leading), "the back is in the column")
    }

    // A column capsule only one bar has materializes in place, vertical: its corner radius is half its width.
    func test_columnButtons_materializeInPlace() {
        let view = self.makeView(bottom: self.duoSide(right: []), top: self.duoSide(right: [self.iconButton("search"), self.iconButton("more")]))
        view.beginTransition(isInteractive: false, toTop: true)
        guard let start = view.platterStateForTesting(.column(1)) else {
            XCTFail("no column capsule")
            return
        }
        XCTAssertEqual(start.opacity, 0.0, accuracy: 0.001)
        XCTAssertGreaterThan(start.frame.height, start.frame.width)
        self.time.advance(by: 1.0)
        XCTAssertEqual(view.platterStateForTesting(.column(1))?.opacity ?? 0.0, 1.0, accuracy: 0.001)
    }

    // A bar that hides its column buttons (an active search) has no column buttons or trailing capsule: only the back
    // circle takes a slot.
    func test_hiddenColumnButtons_haveNoCapsule() {
        let view = self.makeView(bottom: self.duoSide(right: [self.iconButton("search")], hidesColumnButtons: true), top: self.duoSide(right: [self.iconButton("search")], hidesColumnButtons: true))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertNotNil(view.platterStateForTesting(.column(0)))
        XCTAssertNil(view.platterStateForTesting(.column(1)))
        XCTAssertNil(view.platterStateForTesting(.column(2)))
    }

    // The same column items on both bars are no change of items: no pulse.
    func test_columnSignature_comesFromThePlacement() {
        let view = self.makeView(bottom: self.duoSide(right: [self.iconButton("search")]), top: self.duoSide(right: [self.iconButton("search")]))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(view.platterStateForTesting(.column(1))?.pulse.height ?? 0.0, 1.0, accuracy: 0.0001)
    }

    // Chats -> a chat on iPhone Duo: Chats' column is its story capsule over the compose circle, the chat's its back
    // circle over the avatar capsule, at the same two places. The shapes pair by index from the column's top, as the
    // row's right platters pair from the edge: each stays where it is and swaps its items (the compose circle's accent
    // cross-fading to the avatar's glass); none moves to the other's place, and none comes or goes in place.
    func test_column_pairsByIndexFromTheTop_chatsToChat() {
        let chats = self.duoSide(back: nil, right: [self.iconButton("compose", tint: .accent), self.iconButton("story")])
        let chat = self.duoSide(right: [self.iconButton("avatar")])
        let view = self.makeView(bottom: chats, top: chat)
        view.beginTransition(isInteractive: false, toTop: true)
        guard let storyStart = view.platterStateForTesting(.column(0)), let composeStart = view.platterStateForTesting(.column(1)) else {
            XCTFail("Chats' column has two shapes")
            return
        }
        XCTAssertNil(view.platterStateForTesting(.column(2)))
        for time in [0.05, 0.15, 0.3, 1.0] {
            self.time.advance(by: time)
            guard let first = view.platterStateForTesting(.column(0)), let second = view.platterStateForTesting(.column(1)) else {
                XCTFail("both shapes stay")
                return
            }
            XCTAssertEqual(first.opacity, 1.0, accuracy: 0.001, "the story capsule becomes the back circle, it does not dematerialize")
            XCTAssertEqual(second.opacity, 1.0, accuracy: 0.001, "the compose circle becomes the avatar capsule, it does not dematerialize")
            XCTAssertEqual(first.frame.midY, storyStart.frame.midY, accuracy: 0.5)
            XCTAssertEqual(second.frame.midY, composeStart.frame.midY, accuracy: 0.5)
        }
    }

    // The column back's unread badge rides with the circle's items.
    func test_columnBack_carriesTheBadge() {
        var side = self.duoSide(right: [])
        side.content = NavigationBarComponent.Content(title: .text(""), back: .back, leftButton: nil, rightButtons: [], backPressed: {}, badge: "3")
        let view = self.makeView(bottom: side, top: self.duoSide(right: []))
        view.beginTransition(isInteractive: false, toTop: true)
        guard let badge = view.badgeNodeForTesting(.column(0)) else {
            XCTFail("no badge")
            return
        }
        XCTAssertEqual(badge.text, "3")
        XCTAssertNotNil(badge.view.superview)
    }

    // A push started from a button that stays in the row beside an iPhone Duo column: only the row's trailing capsule
    // carries UIKit's press and glow; the bar measures none for the column's capsules.
    func test_rowPress_staysOnTheRowCapsule_besideAColumn() {
        let done = NavigationBarComponent.Button(id: "done", content: .text(title: "Done", isBold: true), action: { _ in })
        var bottom = self.duoSide(right: [done, self.iconButton("search")])
        bottom.trailingPressScales = [60.0 / 44.0]
        bottom.trailingPressGlows = [1.0]
        let view = self.makeView(bottom: bottom, top: self.duoSide(right: []))
        view.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.press ?? 0.0, 60.0 / 44.0, accuracy: 1e-6)
        XCTAssertEqual(view.platterStateForTesting(.trailing(0))?.glow ?? 0.0, 1.0, accuracy: 1e-6)
        XCTAssertEqual(view.platterStateForTesting(.column(1))?.press ?? 0.0, 1.0)
        XCTAssertEqual(view.platterStateForTesting(.column(1))?.glow ?? 1.0, 0.0)
        XCTAssertEqual(view.platterStateForTesting(.column(0))?.press ?? 0.0, 1.0)
        XCTAssertEqual(view.platterStateForTesting(.column(0))?.glow ?? 1.0, 0.0)
    }
}
