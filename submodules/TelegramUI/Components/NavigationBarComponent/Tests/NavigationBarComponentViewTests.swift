import XCTest
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import GlassBackgroundComponent
@testable import NavigationBarComponent

/// A title whose view, like any plain UIView, would answer hitTest for its whole row-sized frame.
private final class RowFillingTitleComponent: Component {
    typealias EnvironmentType = NavigationBarTitleEnvironment

    static func ==(lhs: RowFillingTitleComponent, rhs: RowFillingTitleComponent) -> Bool {
        return true
    }

    final class View: UIView {
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationBarTitleEnvironment>, transition: ComponentTransition) -> CGSize {
        return availableSize
    }
}

/// A 44pt button content that needs no bundle resources (bundle images and the "…" Lottie animation do not
/// load in a hostless test process).
private final class FixedButtonContentComponent: Component {
    typealias EnvironmentType = NavigationButtonEnvironment

    static func ==(lhs: FixedButtonContentComponent, rhs: FixedButtonContentComponent) -> Bool {
        return true
    }

    final class View: UIView {
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonEnvironment>, transition: ComponentTransition) -> CGSize {
        return CGSize(width: 44.0, height: availableSize.height)
    }
}

private final class HostedNode: ASDisplayNode {
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 30.0, height: 30.0)
    }
}

/// Counts the times it left the window (an animation it ran would have stopped each time).
private final class WindowTrackingNode: ASDisplayNode {
    var windowExits = 0

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 30.0, height: 30.0)
    }

    override func didExitHierarchy() {
        super.didExitHierarchy()
        self.windowExits += 1
    }
}

/// One window for the whole process: a test process traps after the suite if a window it made is freed.
private let testWindow = UIWindow(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0))

final class NavigationBarComponentViewTests: XCTestCase {
    private func makeTheme() -> NavigationBarTheme {
        return NavigationBarTheme(overallDarkAppearance: false, buttonColor: .black, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .gray, accentForegroundColor: .white)
    }

    private func makeTintedTheme(_ color: UIColor, glassStyle: NavigationBar.GlassStyle = .default) -> NavigationBarTheme {
        return NavigationBarTheme(overallDarkAppearance: false, buttonColor: .white, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .gray, accentForegroundColor: .white, glassStyle: glassStyle, glassTintColor: color)
    }

    private func updateBar(_ bar: ComponentView<Empty>, theme: NavigationBarTheme, right: [NavigationBarComponent.Button], transition: ComponentTransition) -> NavigationBarComponent.View {
        let content = NavigationBarComponent.Content(title: .text("Profile"), back: .back, leftButton: nil, rightButtons: right, backPressed: {})
        let size = bar.update(
            transition: transition,
            component: AnyComponent(NavigationBarComponent(theme: theme, strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, primaryContent: content, secondaryContent: nil, secondaryTransition: 0.0)),
            environment: {},
            containerSize: CGSize(width: 390.0, height: 44.0)
        )
        let view = bar.view as! NavigationBarComponent.View
        view.frame = CGRect(origin: CGPoint(), size: size)
        return view
    }

    // A theme's glass tint (the profile over a cover colour) is the glass of capsules that ask for no tint; accent
    // capsules keep the accent; without a tint generic capsules are the panel glass.
    func test_glassTintColor_isTheGenericCapsulesGlass() {
        XCTAssertEqual(navigationBarGlassTintColor(.generic, theme: self.makeTheme()), GlassBackgroundView.TintColor(kind: .panel))
        let tinted = self.makeTintedTheme(.orange)
        XCTAssertEqual(navigationBarGlassTintColor(.generic, theme: tinted), GlassBackgroundView.TintColor(kind: .custom(style: .default, color: .orange)))
        XCTAssertEqual(navigationBarGlassTintColor(.accent, theme: tinted), GlassBackgroundView.TintColor(kind: .custom(style: .default, color: .blue)))
        XCTAssertEqual(navigationBarGlassTintColor(.generic, theme: self.makeTintedTheme(.orange, glassStyle: .clear)), GlassBackgroundView.TintColor(kind: .custom(style: .clear, color: .orange)))
    }

    // The profile's header steps its glass colour while its buttons stay: the kept capsule takes the new glass, and a
    // colour change alone is not an item change (no in-place animation, no pulse).
    func test_glassTintChange_retintsTheKeptCapsule_withoutAnInPlaceChange() {
        let bar = ComponentView<Empty>()
        let edit = NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in })
        let before = self.updateBar(bar, theme: self.makeTheme(), right: [edit], transition: .immediate)
        guard let capsule = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no capsule")
            return
        }
        let tinted = self.makeTintedTheme(.orange)
        let view = self.updateBar(bar, theme: tinted, right: [edit], transition: .easeInOut(duration: 0.2))
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 0) === capsule)
        XCTAssertNil(view.inPlaceStateForTesting(isLeft: false))
        XCTAssertEqual(capsule.glassTintColor, GlassBackgroundView.TintColor(kind: .custom(style: .default, color: .orange)))
    }

    private func makeBar(content: NavigationBarComponent.Content) -> NavigationBarComponent.View {
        let bar = ComponentView<Empty>()
        let size = bar.update(
            transition: .immediate,
            component: AnyComponent(NavigationBarComponent(
                theme: self.makeTheme(),
                strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"),
                leftInset: 16.0,
                rightInset: 16.0,
                trailingButtonsInset: 0.0,
                primaryContent: content,
                secondaryContent: nil,
                secondaryTransition: 0.0,
                sideColumnLength: nil,
                openSideColumnOverflow: nil
            )),
            environment: {},
            containerSize: CGSize(width: 390.0, height: 44.0)
        )
        let view = bar.view as! NavigationBarComponent.View
        view.frame = CGRect(origin: CGPoint(), size: size)
        return view
    }

    func test_customTitleContainer_doesNotSwallowRowTouches() {
        let view = self.makeBar(content: NavigationBarComponent.Content(title: .custom(AnyComponent(RowFillingTitleComponent())), back: nil, leftButton: nil, rightButtons: [], backPressed: {}))
        XCTAssertTrue(view.primaryTitleView is RowFillingTitleComponent.View)
        let result = view.hitTest(CGPoint(x: 195.0, y: 22.0), with: nil)
        XCTAssertFalse(result is RowFillingTitleComponent.View)
    }

    func test_titleBand_clearsTheButtons() {
        let view = self.makeBar(content: NavigationBarComponent.Content(title: .text("Chats"), back: .back, leftButton: nil, rightButtons: [NavigationBarComponent.Button(id: "a", content: .custom(AnyComponent(FixedButtonContentComponent())), action: { _ in })], backPressed: {}))
        // Back is 44pt wide, the right button 44pt: each extent is 16 + 44.
        XCTAssertEqual(view.primaryCenterContentInsets.left, 64.0)
        XCTAssertEqual(view.primaryCenterContentInsets.right, 64.0)
        XCTAssertEqual(view.centeredContentFrame, CGRect(x: 0.0, y: 0.0, width: 390.0, height: 44.0))
        XCTAssertNotNil(view.rightButtonViews["a"])
    }

    // The title band and the regular bar's title view clear the whole right side: the capsule, UIKit's 12 pt gap and the
    // circle.
    func test_accentCircle_widensTheRightExtent() {
        let view = self.makeBar(content: NavigationBarComponent.Content(title: .text("Chats"), back: nil, leftButton: nil, rightButtons: [self.fixedButton("compose", tint: .accent), self.fixedButton("story"), self.fixedButton("proxy")], backPressed: {}))
        XCTAssertEqual(view.primaryRightButtonsWidth, 88.0 + 12.0 + 44.0)
        XCTAssertEqual(view.primaryCenterContentInsets.right, 16.0 + 88.0 + 12.0 + 44.0 + 4.0)
        XCTAssertEqual(view.primaryContentView?.rightPillWidths.first, 44.0)
        XCTAssertTrue(view.rightButtonViews["compose"]?.isDescendant(of: view.primaryContentView!.rightPillContainer(at: 0)) ?? false)
    }

    private func makeBar(content: NavigationBarComponent.Content, sideColumnLength: CGFloat?, hidesSideColumnButtons: Bool = false) -> NavigationBarComponent.View {
        let bar = ComponentView<Empty>()
        let size = bar.update(
            transition: .immediate,
            component: AnyComponent(NavigationBarComponent(
                theme: self.makeTheme(),
                strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"),
                leftInset: 16.0,
                rightInset: 16.0,
                trailingButtonsInset: 0.0,
                primaryContent: content,
                secondaryContent: nil,
                secondaryTransition: 0.0,
                sideColumnLength: sideColumnLength,
                hidesSideColumnButtons: hidesSideColumnButtons,
                openSideColumnOverflow: nil
            )),
            environment: {},
            containerSize: CGSize(width: 390.0, height: 44.0)
        )
        let view = bar.view as! NavigationBarComponent.View
        view.frame = CGRect(origin: CGPoint(), size: size)
        return view
    }

    func test_doneButton_takesTheColumnsTrailingCircle() {
        let done = NavigationBarComponent.Button(id: "done", content: .custom(AnyComponent(FixedButtonContentComponent())), tint: .accent, action: { _ in })
        let view = self.makeBar(content: NavigationBarComponent.Content(title: .text("Edit"), back: .back, leftButton: nil, rightButtons: [done], backPressed: {}), sideColumnLength: 400.0)
        XCTAssertNotNil(view.columnTrailingBackgroundContainer)
        XCTAssertEqual(view.primaryRightButtonsWidth, 0.0)
        XCTAssertTrue(view.isBackInSideColumn)
    }

    // iPhone Duo's side column: the chat's avatar (a node, generic tint) is the column capsule's only item, so its glass
    // is a 48 pt circle around the 44 pt button. An expansion asks for it, and for the press UIKit drew on it, before the
    // bar detaches its platters: the press comes from the sampler (UIKit takes a tap's off before the action runs).
    // Measured 2026-10-18: the expansion took the 44 pt button for the circle and lost the lifted circle's press.
    func test_rightButtonCapsule_columnItem_isTheColumnsCapsule_withTheSampledPress() {
        let node = HostedNode()
        let content = NavigationBarComponent.Content(title: .text("Chat"), back: .back, leftButton: nil, rightButtons: [NavigationBarComponent.Button(id: "avatar", content: .node(node), action: { _ in })], backPressed: {})
        let view = self.makeBar(content: content, sideColumnLength: 400.0)
        guard let capsule = view.columnButtonsBackgroundContainer, let glass = navigationBarTestGlassEffectView(content: capsule.contentView, container: capsule), let button = view.rightButtonViews["avatar"] else {
            XCTFail("no column capsule")
            return
        }
        XCTAssertNil(view.columnTrailingBackgroundContainer)
        XCTAssertEqual(capsule.bounds.size, CGSize(width: 48.0, height: 48.0))
        XCTAssertTrue(view.rightButtonCapsule(containing: button)?.container === capsule)
        XCTAssertEqual(view.rightButtonCapsule(containing: button)?.pressScale ?? 0.0, 1.0, accuracy: 0.001)

        var now = 100.0
        view.pressSamplerClock = {
            return now
        }
        let restBounds = glass.bounds
        let center = glass.center
        // The column hangs outside the bar: its host hit-tests it through the bar.
        XCTAssertNotNil(view.sideColumnHitTest(capsule.convert(CGPoint(x: capsule.bounds.midX, y: capsule.bounds.midY), to: view.sideColumnView), with: nil))
        for frame in 1 ... 10 {
            now = 100.0 + Double(frame) / 60.0
            let size = 48.0 + 16.0 * Double(frame) / 10.0
            glass.bounds = CGRect(x: 0.0, y: 0.0, width: size, height: size)
            glass.center = center
            view.tickPressSampler()
        }
        // Held: the live press.
        XCTAssertEqual(view.rightButtonCapsule(containing: button)?.pressScale ?? 1.0, 64.0 / 48.0, accuracy: 0.001)
        // The touch ends: UIKit takes the press off, then the action starts the expansion, which asks at once.
        now += 1.0 / 120.0
        glass.bounds = restBounds
        glass.center = center
        XCTAssertEqual(view.rightButtonCapsule(containing: button)?.pressScale ?? 1.0, 64.0 / 48.0, accuracy: 0.001)
        // Long after: no press.
        now += 1.0
        XCTAssertEqual(view.rightButtonCapsule(containing: button)?.pressScale ?? 0.0, 1.0, accuracy: 0.001)
    }

    // The row's circle is its own capsule: 44 pt, with the press UIKit draws on it.
    func test_rightButtonCapsule_rowCircle_isItsPill_withTheLivePress() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: nil, right: self.chatsButtons(), transition: .immediate)
        guard let circle = view.rightPillBackgroundContainer(at: 0), let glass = navigationBarTestGlassEffectView(content: circle.contentView, container: circle), let compose = view.rightButtonViews["compose"] else {
            XCTFail("no circle")
            return
        }
        XCTAssertTrue(view.rightButtonCapsule(containing: compose)?.container === circle)
        XCTAssertEqual(circle.bounds.height, 44.0)
        let center = glass.center
        glass.bounds = CGRect(x: 0.0, y: 0.0, width: 60.0, height: 60.0)
        glass.center = center
        XCTAssertEqual(view.rightButtonCapsule(containing: compose)?.pressScale ?? 1.0, 60.0 / 44.0, accuracy: 0.001)
    }

    func test_withoutColumn_backIsInTheRow() {
        let view = self.makeBar(content: NavigationBarComponent.Content(title: .text("Edit"), back: .back, leftButton: nil, rightButtons: [], backPressed: {}), sideColumnLength: nil)
        XCTAssertFalse(view.isBackInSideColumn)
        XCTAssertEqual(view.primaryLeftButtonsWidth, 44.0)
    }

    func test_textTitle_isAnAccessibilityHeader() {
        let view = self.makeBar(content: NavigationBarComponent.Content(title: .text("Settings"), back: nil, leftButton: nil, rightButtons: [], backPressed: {}), sideColumnLength: nil)
        let title = view.titleAccessibilityElement
        XCTAssertEqual(title?.accessibilityLabel, "Settings")
        XCTAssertTrue(title?.accessibilityTraits.contains(.header) ?? false)
    }

    func test_accessibilityOrder_backThenTitleThenRight() {
        let right = NavigationBarComponent.Button(id: "a", content: .custom(AnyComponent(FixedButtonContentComponent())), overflow: NavigationBarComponent.OverflowInfo(title: "Search", iconName: nil, priority: 0), action: { _ in })
        let view = self.makeBar(content: NavigationBarComponent.Content(title: .text("Chats"), back: .back, leftButton: nil, rightButtons: [right], backPressed: {}), sideColumnLength: nil)
        XCTAssertEqual(view.leadingAccessibilityElements.map(\.accessibilityLabel), ["Back"])
        XCTAssertEqual(view.trailingAccessibilityElements.map(\.accessibilityLabel), ["Search"])
    }

    // The old bar measured a text button against the bar's width; a long localized title is not truncated.
    func test_longTextButton_isNotCappedAtTheChatListsWidth() {
        let button = NavigationBarComponent.Button(id: "a", content: .text(title: "Mark all messages as read", isBold: false), action: { _ in })
        let view = self.makeBar(content: NavigationBarComponent.Content(title: .text(""), back: nil, leftButton: nil, rightButtons: [button], backPressed: {}), sideColumnLength: nil)
        XCTAssertGreaterThan(view.primaryRightButtonsWidth, 150.0)
    }

    // An active search hides the column's capsule and Done circle with the row; the back circle stays.
    func test_hidesSideColumnButtons_keepsOnlyTheBackCircle() {
        let search = NavigationBarComponent.Button(id: "search", content: .custom(AnyComponent(FixedButtonContentComponent())), action: { _ in })
        let done = NavigationBarComponent.Button(id: "done", content: .custom(AnyComponent(FixedButtonContentComponent())), tint: .accent, action: { _ in })
        let content = NavigationBarComponent.Content(title: .text("Log"), back: .back, leftButton: nil, rightButtons: [done, search], backPressed: {})
        let shown = self.makeBar(content: content, sideColumnLength: 400.0)
        XCTAssertEqual(shown.columnButtonsBackgroundContainer?.alpha, 1.0)
        XCTAssertEqual(shown.columnTrailingBackgroundContainer?.alpha, 1.0)

        let hidden = self.makeBar(content: content, sideColumnLength: 400.0, hidesSideColumnButtons: true)
        XCTAssertTrue(hidden.isBackInSideColumn)
        XCTAssertEqual(hidden.columnButtonsBackgroundContainer?.alpha ?? 0.0, 0.0)
        XCTAssertFalse(hidden.columnButtonsBackgroundContainer?.isUserInteractionEnabled ?? false)
        XCTAssertEqual(hidden.columnTrailingBackgroundContainer?.alpha ?? 0.0, 0.0)
        XCTAssertFalse(hidden.columnTrailingBackgroundContainer?.isUserInteractionEnabled ?? false)
    }

    // A screen that hands the bar a new item for the same node (a list screen applying its state, the Chat Themes
    // switch on a theme preview) gets a new button view; the node goes into it without leaving the window, or an
    // animation it runs stops there (Lottie pauses a view that leaves its window: the switch froze at its first frame).
    func test_rebuiltButton_takesItsNode_withoutLeavingTheWindow() {
        let node = WindowTrackingNode()
        let bar = ComponentView<Empty>()
        func update(_ id: AnyHashable) -> UIView? {
            let content = NavigationBarComponent.Content(title: .text("Chat Themes"), back: .back, leftButton: nil, rightButtons: [NavigationBarComponent.Button(id: id, content: .node(node), action: { _ in })], backPressed: {})
            let size = bar.update(transition: .immediate, component: AnyComponent(NavigationBarComponent(theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, trailingButtonsInset: 0.0, primaryContent: content, secondaryContent: nil, secondaryTransition: 0.0, sideColumnLength: nil, openSideColumnOverflow: nil)), environment: {}, containerSize: CGSize(width: 390.0, height: 44.0))
            bar.view?.frame = CGRect(origin: CGPoint(), size: size)
            return bar.view
        }
        guard let barView = update("first") else {
            XCTFail("no bar")
            return
        }
        testWindow.addSubview(barView)
        defer {
            barView.removeFromSuperview()
        }
        XCTAssertNotNil(node.view.window)
        let exitsBefore = node.windowExits
        let _ = update("second")
        XCTAssertNotNil(node.view.window)
        XCTAssertEqual(node.windowExits, exitsBefore)
    }

    // A screen's node rides in its button's view, which moves between the row and the column.
    func test_hostedNode_movesBetweenRowAndColumn() {
        let node = HostedNode()
        let content = NavigationBarComponent.Content(title: .text("Chat"), back: .back, leftButton: nil, rightButtons: [NavigationBarComponent.Button(id: "avatar", content: .node(node), action: { _ in })], backPressed: {})
        let bar = ComponentView<Empty>()
        func update(_ sideColumnLength: CGFloat?) -> NavigationBarComponent.View {
            let size = bar.update(transition: .immediate, component: AnyComponent(NavigationBarComponent(theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, trailingButtonsInset: 0.0, primaryContent: content, secondaryContent: nil, secondaryTransition: 0.0, sideColumnLength: sideColumnLength, openSideColumnOverflow: nil)), environment: {}, containerSize: CGSize(width: 390.0, height: 44.0))
            let view = bar.view as! NavigationBarComponent.View
            view.frame = CGRect(origin: CGPoint(), size: size)
            return view
        }
        let rowView = update(nil)
        XCTAssertTrue(node.view.isDescendant(of: rowView))
        XCTAssertFalse(node.view.isDescendant(of: rowView.sideColumnView))
        let columnView = update(400.0)
        XCTAssertTrue(node.view.isDescendant(of: columnView.sideColumnView))
        let backInRowView = update(nil)
        XCTAssertFalse(node.view.isDescendant(of: backInRowView.sideColumnView))
        XCTAssertTrue(node.view.isDescendant(of: backInRowView))
    }

    // The column's back circle is too narrow to widen for an unread badge: the badge sits on its corner.
    func test_backBadge_inTheColumn_sitsOnTheCircle() {
        let content = NavigationBarComponent.Content(title: .text("Chat"), back: .back, leftButton: nil, rightButtons: [], backPressed: {}, badge: "3")
        let view = self.makeBar(content: content, sideColumnLength: 400.0)
        XCTAssertEqual(view.columnBadgeNode?.text, "3")
        let backFrame = view.columnBackBackgroundContainer?.frame ?? CGRect()
        XCTAssertGreaterThan(view.columnBadgeNode?.frame.maxX ?? 0.0, backFrame.maxX)
        XCTAssertLessThan(view.columnBadgeNode?.frame.minY ?? 0.0, backFrame.minY)
        let rowView = self.makeBar(content: content, sideColumnLength: nil)
        XCTAssertNil(rowView.columnBadgeNode)
    }

    // What a screen insets its content by must be what the bar lays out.
    func test_sideColumnContentFrame_isWhatTheViewLaysOut() {
        let search = NavigationBarComponent.Button(id: "search", content: .custom(AnyComponent(FixedButtonContentComponent())), action: { _ in })
        let done = NavigationBarComponent.Button(id: "done", content: .custom(AnyComponent(FixedButtonContentComponent())), tint: .accent, action: { _ in })
        let content = NavigationBarComponent.Content(title: .text("Edit"), back: .back, leftButton: nil, rightButtons: [done, search], backPressed: {})
        let view = self.makeBar(content: content, sideColumnLength: 400.0)
        let shapes = [view.columnBackBackgroundContainer?.frame, view.columnButtonsBackgroundContainer?.frame, view.columnTrailingBackgroundContainer?.frame].compactMap { $0 }
        XCTAssertEqual(shapes.count, 3)
        let expected = shapes.dropFirst().reduce(shapes[0]) { $0.union($1) }
        XCTAssertEqual(NavigationBarComponent.sideColumnContentFrame(content: content, columnLength: 400.0), expected)
    }

    func test_sideColumnContentFrame_isNilWithNothingInTheColumn() {
        let content = NavigationBarComponent.Content(title: .text("Edit"), back: nil, leftButton: nil, rightButtons: [NavigationBarComponent.Button(id: "save", content: .text(title: "Save", isBold: true), action: { _ in })], backPressed: {})
        XCTAssertNil(NavigationBarComponent.sideColumnContentFrame(content: content, columnLength: 400.0))
    }

    private func fixedButton(_ id: String, tint: NavigationBarComponent.Button.Tint = .generic) -> NavigationBarComponent.Button {
        return NavigationBarComponent.Button(id: id, content: .custom(AnyComponent(FixedButtonContentComponent())), tint: tint, action: { _ in })
    }

    // While a navigation transition draws the glass above both screens, the bar's capsules leave the hierarchy (alpha
    // does not hide native glass) and its title stays where it was, riding with the bar's screen.
    func test_detachedPlatters_leaveTheHierarchy_andTheTitleStays() {
        let bar = ComponentView<Empty>()
        func update(rightButtons: [NavigationBarComponent.Button]) -> NavigationBarComponent.View {
            let content = NavigationBarComponent.Content(title: .text("Title"), back: .back, leftButton: nil, rightButtons: rightButtons, backPressed: {})
            let size = bar.update(
                transition: .immediate,
                component: AnyComponent(NavigationBarComponent(theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, primaryContent: content, secondaryContent: nil, secondaryTransition: 0.0)),
                environment: {},
                containerSize: CGSize(width: 390.0, height: 44.0)
            )
            let view = bar.view as! NavigationBarComponent.View
            view.frame = CGRect(origin: CGPoint(), size: size)
            return view
        }
        let view = update(rightButtons: [self.fixedButton("x")])
        guard let title = view.primaryContentView?.titleOffsetContainer else {
            XCTFail("no title")
            return
        }
        let titleFrame = title.convert(title.bounds, to: view)
        view.plattersDetached = true
        XCTAssertNil(view.leftButtonsBackgroundContainer?.superview)
        XCTAssertNil(view.rightPillBackgroundContainer(at: 0)?.superview)
        XCTAssertTrue(title.isDescendant(of: view))
        XCTAssertEqual(title.convert(title.bounds, to: view), titleFrame)
        // A layout while detached keeps them out.
        let _ = update(rightButtons: [self.fixedButton("x"), self.fixedButton("y")])
        XCTAssertNil(view.rightPillBackgroundContainer(at: 0)?.superview)
        view.plattersDetached = false
        XCTAssertTrue(view.leftButtonsBackgroundContainer?.superview === view)
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 0)?.superview === view)
    }

    private func updateBar(_ bar: ComponentView<Empty>, back: NavigationBarComponent.Back?, right: [NavigationBarComponent.Button], transition: ComponentTransition) -> NavigationBarComponent.View {
        let content = NavigationBarComponent.Content(title: .text("Private Chats"), back: back, leftButton: nil, rightButtons: right, backPressed: {})
        let size = bar.update(
            transition: transition,
            component: AnyComponent(NavigationBarComponent(theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, primaryContent: content, secondaryContent: nil, secondaryTransition: 0.0)),
            environment: {},
            containerSize: CGSize(width: 390.0, height: 44.0)
        )
        let view = bar.view as! NavigationBarComponent.View
        view.frame = CGRect(origin: CGPoint(), size: size)
        return view
    }

    // An animated change of a capsule's items (Edit -> Done) animates as iOS 27's glass does on the bar's own capsule:
    // the same capsule (so its press carries on), morphing from the old frame, pulsing, with the new items
    // materializing; at rest it is at its new frame with no transform left.
    func test_inPlaceItemChange_keepsTheCapsule_andAnimatesNatively() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in })], transition: .immediate)
        guard let capsule = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no capsule")
            return
        }
        let oldFrame = capsule.frame
        let view = self.updateBar(bar, back: nil, right: [self.fixedButton("done", tint: .accent)], transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 0) === capsule)
        guard let start = view.inPlaceStateForTesting(isLeft: false) else {
            XCTFail("no in-place animation")
            return
        }
        XCTAssertEqual(start.frame, oldFrame)
        XCTAssertEqual(start.itemsAlpha ?? -1.0, 0.0)
        view.inPlaceTickForTesting(dt: 0.08)
        XCTAssertGreaterThan(view.inPlaceStateForTesting(isLeft: false)?.pulse.height ?? 1.0, 1.0)
        for _ in 0 ..< 240 {
            view.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
        XCTAssertNil(view.inPlaceStateForTesting(isLeft: false))
        XCTAssertEqual(capsule.frame, CGRect(x: 390.0 - 16.0 - 44.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertTrue(CATransform3DIsIdentity(capsule.layer.transform))
        XCTAssertEqual(view.rightPill(at: 0).itemsContainer.alpha, 1.0)
    }

    /// A one-pill bar [Edit] with UIKit's press on Edit faked by growing its effect view, and that effect view.
    private func pressedEdit(_ bar: ComponentView<Empty>) -> (edit: GlassContextExtractableContainer, glass: UIView)? {
        let before = self.updateBar(bar, back: .back, right: [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in })], transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0), let glass = navigationBarTestGlassEffectView(content: edit.contentView, container: edit) else {
            return nil
        }
        let center = glass.center
        glass.bounds = CGRect(x: 0.0, y: 0.0, width: edit.bounds.width * 1.1, height: 44.0 * 1.1)
        glass.center = center
        return (edit, glass)
    }

    // A glass UIKit is pressing comes up white when its effect changes: tapped Edit -> Done on a one-pill bar
    // (Subscribers) left Done white with a blue edge. Before the retint the pill gets a new effect view, and the press's
    // scale goes on as the bar's own.
    func test_inPlaceItemChange_pressedPill_retintsOnANewEffectView() {
        let bar = ComponentView<Empty>()
        guard let (edit, pressed) = self.pressedEdit(bar) else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: [self.fixedButton("done", tint: .accent)], transition: .easeInOut(duration: 0.3))
        XCTAssertFalse(navigationBarTestGlassEffectView(content: edit.contentView, container: edit) === pressed)
        XCTAssertNil(pressed.superview)
        XCTAssertEqual(view.inPlaceStateForTesting(isLeft: false)?.press ?? 1.0, 1.1, accuracy: 0.01)
    }

    // A change that keeps the tint changes no effect, so UIKit's press stays on its glass.
    func test_inPlaceItemChange_pressedPill_sameTint_keepsItsEffectView() {
        let bar = ComponentView<Empty>()
        guard let (edit, pressed) = self.pressedEdit(bar) else {
            XCTFail("no pill")
            return
        }
        _ = self.updateBar(bar, back: .back, right: [NavigationBarComponent.Button(id: "cancel", content: .text(title: "Cancel", isBold: false), action: { _ in })], transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(navigationBarTestGlassEffectView(content: edit.contentView, container: edit) === pressed)
    }

    // Unpressed, a retint keeps the effect view (UIKit cross-fades its tint).
    func test_inPlaceItemChange_unpressedPill_keepsItsEffectView() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in })], transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0), let glass = navigationBarTestGlassEffectView(content: edit.contentView, container: edit) else {
            XCTFail("no pill")
            return
        }
        _ = self.updateBar(bar, back: .back, right: [self.fixedButton("done", tint: .accent)], transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(navigationBarTestGlassEffectView(content: edit.contentView, container: edit) === glass)
    }

    // The new items take taps while the change animates (Edit -> Done, then Done tapped at once). The content view hit
    // tests its row buttons by converting the point to them, so the capsule holding them must stay in the hierarchy:
    // with it detached (the old overlay) the conversion has no common ancestor and every tap missed until it settled.
    // When a transition takes the bar's capsules, the bar measures the press UIKit is drawing on each (a scale on the
    // glass the capsule's content sits in), so the transition can carry it on.
    func test_detachingPlatters_measuresThePress() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in })], transition: .immediate)
        guard let capsule = view.leftButtonsBackgroundContainer, let glass = navigationBarTestGlassEffectView(content: capsule.contentView, container: capsule) else {
            XCTFail("no back capsule")
            return
        }
        // UIKit's press as it draws it on a short tap (measured in the app): the glass grows its bounds around the
        // content, which keeps its own size.
        let center = glass.center
        glass.bounds = CGRect(x: 0.0, y: 0.0, width: 60.0, height: 60.0)
        glass.center = center
        view.plattersDetached = true
        XCTAssertEqual(view.detachedLeftPressScale, 60.0 / 44.0, accuracy: 0.001)
        XCTAssertEqual((view.detachedRightPressScales.first ?? 1.0), 1.0, accuracy: 0.001)
        view.plattersDetached = false
        XCTAssertEqual(view.detachedLeftPressScale, 1.0)
    }

    // UIKit draws a short tap's press only as a running animation on the glass, and takes it off when the touch ends,
    // before the button's action runs (measured in the app, 2026-10-14: at the hand-over the glass read 44 pt in its
    // presentation too, with no animation left). So the bar samples the press while a touch is in a capsule, and the
    // hand-over takes the last sample.
    func test_detachingPlatters_takesThePressSampledDuringTheTouch() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in })], transition: .immediate)
        guard let capsule = view.leftButtonsBackgroundContainer, let glass = navigationBarTestGlassEffectView(content: capsule.contentView, container: capsule) else {
            XCTFail("no back capsule")
            return
        }
        let restBounds = glass.bounds
        let center = glass.center
        glass.bounds = CGRect(x: 0.0, y: 0.0, width: 60.0, height: 60.0)
        glass.center = center
        // The touch arrives in the back capsule.
        let _ = view.hitTest(capsule.convert(CGPoint(x: capsule.bounds.midX, y: capsule.bounds.midY), to: view), with: nil)
        // The touch ends: UIKit takes the press off, then the action starts a transition.
        glass.bounds = restBounds
        glass.center = center
        view.plattersDetached = true
        XCTAssertEqual(view.detachedLeftPressScale, 60.0 / 44.0, accuracy: 0.001)
        XCTAssertEqual((view.detachedRightPressScales.first ?? 1.0), 1.0, accuracy: 0.001)
    }

    // A press held longer than the sampler's first window (filmed in the app, 2026-10-14: Back held ~1.6 s snapped
    // 60 -> 44 pt at the release, the sampler having stopped 1.5 s after touch-down) is still sampled until it ends.
    func test_detachingPlatters_takesThePressSampledAtTheEndOfALongHold() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: [], transition: .immediate)
        guard let capsule = view.leftButtonsBackgroundContainer, let glass = navigationBarTestGlassEffectView(content: capsule.contentView, container: capsule) else {
            XCTFail("no back capsule")
            return
        }
        var now = 100.0
        view.pressSamplerClock = {
            return now
        }
        let restBounds = glass.bounds
        let center = glass.center
        let _ = view.hitTest(capsule.convert(CGPoint(x: capsule.bounds.midX, y: capsule.bounds.midY), to: view), with: nil)
        // UIKit's press grows and is held for 3 s, sampled every frame.
        for frame in 1 ... 180 {
            now = 100.0 + Double(frame) / 60.0
            let size = 44.0 + 16.0 * min(1.0, Double(frame) / 10.0)
            glass.bounds = CGRect(x: 0.0, y: 0.0, width: size, height: size)
            glass.center = center
            view.tickPressSampler()
        }
        // The touch ends: UIKit takes the press off, then the action starts a transition.
        now += 1.0 / 120.0
        glass.bounds = restBounds
        glass.center = center
        view.plattersDetached = true
        XCTAssertEqual(view.detachedLeftPressScale, 60.0 / 44.0, accuracy: 0.001)
    }

    // UIKit's press glow on a capsule when the bar hands it to a transition: the opacity of its BigGlow layer
    // (`_UIFlexInteraction`); a press with no glow layer found reads as full glow, no press as none.
    func test_detachingPlatters_measuresThePressGlow() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in })], transition: .immediate)
        guard let back = view.leftButtonsBackgroundContainer, let backGlass = navigationBarTestGlassEffectView(content: back.contentView, container: back), let edit = view.rightPillBackgroundContainer(at: 0), let editGlass = navigationBarTestGlassEffectView(content: edit.contentView, container: edit) else {
            XCTFail("no capsules")
            return
        }
        let glow = CALayer()
        glow.name = "_UIFlexInteraction.BigGlow"
        glow.opacity = 0.7
        backGlass.layer.addSublayer(glow)
        backGlass.transform = CGAffineTransform(scaleX: 60.0 / 44.0, y: 60.0 / 44.0)
        editGlass.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        view.plattersDetached = true
        XCTAssertEqual(view.detachedLeftPressGlow, 0.7, accuracy: 0.001)
        XCTAssertEqual((view.detachedRightPressGlows.first ?? 0.0), 1.0, accuracy: 0.001)
        view.plattersDetached = false
        XCTAssertEqual(view.detachedLeftPressGlow, 0.0)
        glow.removeFromSuperlayer()
        backGlass.transform = .identity
        editGlass.transform = .identity
        view.plattersDetached = true
        XCTAssertEqual(view.detachedLeftPressGlow, 0.0)
        XCTAssertEqual((view.detachedRightPressGlows.first ?? 0.0), 0.0)
    }

    // Under Reduce Motion an in-place change does not pulse and its shape does not bounce (glass RE §2.2, §3.2).
    func test_inPlaceItemChange_underReduceMotion_noPulseAndNoBounce() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: nil, right: [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in })], transition: .immediate)
        before.inPlaceReduceMotion = { true }
        let view = self.updateBar(bar, back: nil, right: [self.fixedButton("done", tint: .accent)], transition: .easeInOut(duration: 0.3))
        var maxPulse: CGFloat = 1.0
        var minWidth: CGFloat = 1000.0
        for _ in 0 ..< 240 {
            view.inPlaceTickForTesting(dt: 1.0 / 240.0)
            if let state = view.inPlaceStateForTesting(isLeft: false) {
                maxPulse = max(maxPulse, state.pulse.height)
                minWidth = min(minWidth, state.frame.width)
            }
        }
        XCTAssertEqual(maxPulse, 1.0)
        XCTAssertGreaterThanOrEqual(minWidth, 44.0 - 0.01)
    }

    // An in-place change starts where it is: its first frame advances nothing, however late it comes.
    func test_inPlaceItemChange_firstFrame_advancesNothing() {
        let bar = ComponentView<Empty>()
        let _ = self.updateBar(bar, back: nil, right: [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in })], transition: .immediate)
        let start = CACurrentMediaTime()
        let view = self.updateBar(bar, back: nil, right: [self.fixedButton("done", tint: .accent)], transition: .easeInOut(duration: 0.3))
        view.inPlaceDurationFactor = { 1.0 }
        view.inPlaceDisplayLinkFrame(at: start + 0.05)
        XCTAssertEqual(view.inPlaceStateForTesting(isLeft: false)?.itemsAlpha ?? -1.0, 0.0)
        view.inPlaceDisplayLinkFrame(at: start + 0.05 + 1.0 / 60.0)
        XCTAssertGreaterThan(view.inPlaceStateForTesting(isLeft: false)?.itemsAlpha ?? 0.0, 0.0)
    }

    func test_inPlaceItemChange_newItemsTakeTapsMidAnimation() {
        let bar = ComponentView<Empty>()
        let _ = self.updateBar(bar, back: nil, right: [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in })], transition: .immediate)
        let view = self.updateBar(bar, back: nil, right: [self.fixedButton("done", tint: .accent)], transition: .easeInOut(duration: 0.3))
        // Below the status bar, as in the app: a view outside the bar's hierarchy would no longer share its coordinates.
        let host = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 200.0))
        host.addSubview(view)
        view.frame = CGRect(x: 0.0, y: 100.0, width: 390.0, height: 44.0)
        view.inPlaceTickForTesting(dt: 0.05)
        XCTAssertNotNil(view.inPlaceStateForTesting(isLeft: false))
        guard let done = view.rightButtonViews["done"] else {
            XCTFail("no Done button")
            return
        }
        let point = CGPoint(x: 390.0 - 16.0 - 22.0, y: 22.0)
        let result = view.hitTest(point, with: nil)
        XCTAssertTrue(result?.isDescendant(of: done) ?? false, "\(String(describing: result))")
    }

    // The items an in-place change replaces leave as themselves: the old button's own view, handed over by the content
    // view (never a snapshot, which freezes what animates).
    func test_inPlaceItemChange_oldItemsLeaveLive() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: nil, right: [self.fixedButton("edit")], transition: .immediate)
        guard let edit = before.rightButtonViews["edit"] else {
            XCTFail("no Edit button")
            return
        }
        let view = self.updateBar(bar, back: nil, right: [self.fixedButton("search")], transition: .easeInOut(duration: 0.3))
        let leaving = view.inPlaceLeavingViewsForTesting(slot: .right(0))
        XCTAssertEqual(leaving.count, 1)
        XCTAssertTrue(leaving.first.map { edit.isDescendant(of: $0) } ?? false, "\(leaving)")
        XCTAssertFalse(view.rightButtonViews["search"]?.isDescendant(of: leaving.first ?? UIView()) ?? true)
    }

    // A node kept across an in-place change stays in the button the bar shows it in. The profile's more/search slot is
    // one node: [search, more] -> [more] (a swipe from its Chats tab to Media) hands the old pill's "more" button to
    // the leaving items and lays out a new one, which takes the node. The leaving button, put on screen with the
    // leaving items, took the node back and took it away when it left: the pill stayed empty.
    func test_inPlaceItemChange_keptNode_staysInTheShownButton() {
        let node = HostedNode()
        let bar = ComponentView<Empty>()
        let more = NavigationBarComponent.Button(id: "more", content: .node(node), action: { _ in })
        let before = self.updateBar(bar, back: .back, right: [self.fixedButton("search"), more], transition: .immediate)
        testWindow.addSubview(before)
        defer {
            before.removeFromSuperview()
        }
        XCTAssertNotNil(node.view.window)

        let view = self.updateBar(bar, back: .back, right: [more], transition: .easeInOut(duration: 0.3))
        XCTAssertNotNil(view.inPlaceStateForTesting(isLeft: false))
        XCTAssertFalse(view.inPlaceLeavingViewsForTesting(slot: .right(0)).isEmpty)
        guard let shown = view.rightButtonViews["more"] else {
            XCTFail("no more button")
            return
        }
        XCTAssertTrue(node.view.isDescendant(of: shown))

        for _ in 0 ..< 240 {
            view.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
        XCTAssertNil(view.inPlaceStateForTesting(isLeft: false))
        XCTAssertTrue(view.rightButtonViews["more"] === shown)
        XCTAssertTrue(node.view.isDescendant(of: shown))
        XCTAssertNotNil(node.view.window)
    }

    // Work that must not cut a capsule's change short (the bar's glass adapting again) waits until every capsule has
    // settled, and runs at once when none animates.
    func test_afterInPlaceAnimations_waitsForTheCapsulesToSettle() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: nil, right: [self.fixedButton("edit")], transition: .immediate)
        var runs = 0
        before.afterInPlaceAnimations {
            runs += 1
        }
        XCTAssertEqual(runs, 1)

        let view = self.updateBar(bar, back: nil, right: [self.fixedButton("done", tint: .accent)], transition: .easeInOut(duration: 0.3))
        XCTAssertNotNil(view.inPlaceStateForTesting(isLeft: false))
        view.afterInPlaceAnimations {
            runs += 1
        }
        XCTAssertEqual(runs, 1)
        for _ in 0 ..< 240 {
            view.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
        XCTAssertNil(view.inPlaceStateForTesting(isLeft: false))
        XCTAssertEqual(runs, 2)
    }

    // A capsule that appears in place (the profile's "…" coming with its Media tab) is glass UIKit only half takes in:
    // a context menu morphing out of it left its glass behind the menu. Once the change has settled the bar asks its
    // host to make the glass adapt again, once; a change that adds no capsule does not ask.
    func test_capsuleAppearingInPlace_asksForReadaptation_onceSettled() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: [], transition: .immediate)
        var requests = 0
        before.glassNeedsReadaptation = {
            requests += 1
        }
        let view = self.updateBar(bar, back: .back, right: [self.fixedButton("more")], transition: .easeInOut(duration: 0.3))
        XCTAssertNotNil(view.inPlaceStateForTesting(isLeft: false))
        XCTAssertEqual(requests, 0)
        for _ in 0 ..< 240 {
            view.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
        XCTAssertNil(view.inPlaceStateForTesting(isLeft: false))
        XCTAssertEqual(requests, 1)

        let _ = self.updateBar(bar, back: .back, right: [self.fixedButton("done", tint: .accent)], transition: .easeInOut(duration: 0.3))
        XCTAssertNotNil(view.inPlaceStateForTesting(isLeft: false))
        for _ in 0 ..< 240 {
            view.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
        XCTAssertEqual(requests, 1)
    }

    // A capsule the change removes (the back button entering edit mode) dematerializes, then leaves.
    func test_inPlaceCapsuleRemoval_dematerializes() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: [self.fixedButton("edit")], transition: .immediate)
        guard let backCapsule = before.leftButtonsBackgroundContainer else {
            XCTFail("no back capsule")
            return
        }
        let view = self.updateBar(bar, back: nil, right: [self.fixedButton("edit")], transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(backCapsule.superview === view)
        view.inPlaceTickForTesting(dt: 0.1)
        XCTAssertGreaterThan(backCapsule.layer.transform.m11, 1.0)
        for _ in 0 ..< 240 {
            view.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
        XCTAssertNil(backCapsule.superview)
    }

    private func chatsButtons() -> [NavigationBarComponent.Button] {
        return [self.fixedButton("compose", tint: .accent), self.fixedButton("story"), self.fixedButton("proxy")]
    }

    // UIKit's geometry (spec, measured on iOS 27): the circle 44 x 44 at the right inset, the capsule ending 12 pt before
    // it. The circle's glass holds the accent button.
    func test_accentCircle_isOutermost_twelvePointsAfterTheCapsule() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: nil, right: self.chatsButtons(), transition: .immediate)
        XCTAssertEqual(view.rightPillBackgroundContainer(at: 0)?.frame, CGRect(x: 390.0 - 16.0 - 44.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertEqual(view.rightPillBackgroundContainer(at: 1)?.frame, CGRect(x: 390.0 - 16.0 - 44.0 - 12.0 - 88.0, y: 0.0, width: 88.0, height: 44.0))
        guard let circle = view.rightPillBackgroundContainer(at: 0), let compose = view.rightButtonViews["compose"] else {
            XCTFail("no circle")
            return
        }
        XCTAssertTrue(compose.isDescendant(of: circle))
        XCTAssertTrue(view.navigationButtonContextContainer(sourceView: compose) === circle)
    }

    // A transition takes the circle with the other platters and gives it back.
    func test_accentCircle_leavesWithThePlatters_andComesBack() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: nil, right: self.chatsButtons(), transition: .immediate)
        view.plattersDetached = true
        XCTAssertNotNil(view.rightPillBackgroundContainer(at: 0))
        XCTAssertNil(view.rightPillBackgroundContainer(at: 0)?.superview)
        view.plattersDetached = false
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 0)?.superview === view)
    }

    // Chats entering Edit mode takes its right buttons away in place: the circle and the capsule each dematerialize
    // where they are (UIKit, sampled: +16 pt and x1.2), then leave.
    func test_editMode_circleAndCapsuleDematerializeInPlace() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: nil, right: self.chatsButtons(), transition: .immediate)
        guard let circle = before.rightPillBackgroundContainer(at: 0), let capsule = before.rightPillBackgroundContainer(at: 1) else {
            XCTFail("no right platters")
            return
        }
        let view = self.updateBar(bar, back: nil, right: [], transition: .easeInOut(duration: 0.3))
        XCTAssertNotNil(view.inPlaceStateForTesting(slot: .right(0)))
        XCTAssertNotNil(view.inPlaceStateForTesting(slot: .right(1)))
        view.inPlaceTickForTesting(dt: 0.1)
        XCTAssertGreaterThan(circle.layer.transform.m11, 1.0)
        XCTAssertGreaterThan(capsule.layer.transform.m11, 1.0)
        for _ in 0 ..< 240 {
            view.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
        XCTAssertNil(circle.superview)
        XCTAssertNil(capsule.superview)
    }

    // Edit mode left again before the removal settled: a new circle materializes while the old one finishes leaving, and
    // nothing of the old one stays.
    func test_editModeToggledBack_newCircleMaterializes_oldOneLeaves() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: nil, right: self.chatsButtons(), transition: .immediate)
        guard let oldCircle = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no circle")
            return
        }
        let _ = self.updateBar(bar, back: nil, right: [], transition: .easeInOut(duration: 0.3))
        before.inPlaceTickForTesting(dt: 0.05)
        let view = self.updateBar(bar, back: nil, right: self.chatsButtons(), transition: .easeInOut(duration: 0.3))
        guard let newCircle = view.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no new circle")
            return
        }
        XCTAssertFalse(newCircle === oldCircle)
        for _ in 0 ..< 240 {
            view.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
        XCTAssertNil(oldCircle.superview)
        XCTAssertEqual(newCircle.frame, CGRect(x: 390.0 - 16.0 - 44.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertTrue(CATransform3DIsIdentity(newCircle.layer.transform))
    }

    // A transition carries on the press UIKit draws on the circle as the trailing platter's, and the capsule's beside it
    // as the inner one's.
    func test_detachingPlatters_measuresTheCircleAndTheCapsuleBesideIt() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: nil, right: self.chatsButtons(), transition: .immediate)
        guard let circle = view.rightPillBackgroundContainer(at: 0), let circleGlass = navigationBarTestGlassEffectView(content: circle.contentView, container: circle), let capsule = view.rightPillBackgroundContainer(at: 1), let capsuleGlass = navigationBarTestGlassEffectView(content: capsule.contentView, container: capsule) else {
            XCTFail("no right platters")
            return
        }
        let circleCenter = circleGlass.center
        circleGlass.bounds = CGRect(x: 0.0, y: 0.0, width: 60.0, height: 60.0)
        circleGlass.center = circleCenter
        let capsuleCenter = capsuleGlass.center
        capsuleGlass.bounds = CGRect(x: 0.0, y: 0.0, width: 110.0, height: 55.0)
        capsuleGlass.center = capsuleCenter
        view.plattersDetached = true
        XCTAssertEqual((view.detachedRightPressScales.first ?? 1.0), 60.0 / 44.0, accuracy: 0.001)
        XCTAssertEqual((view.detachedRightPressScales.count > 1 ? view.detachedRightPressScales[1] : 1.0), 55.0 / 44.0, accuracy: 0.001)
        // Detached, the circle's button finds its capsule with the press handed to the transition.
        if let compose = view.rightButtonViews["compose"] {
            XCTAssertTrue(view.rightButtonCapsule(containing: compose)?.container === circle)
            XCTAssertEqual(view.rightButtonCapsule(containing: compose)?.pressScale ?? 1.0, 60.0 / 44.0, accuracy: 0.001)
        } else {
            XCTFail("no compose button")
        }
        view.plattersDetached = false
        XCTAssertEqual((view.detachedRightPressScales.count > 1 ? view.detachedRightPressScales[1] : 1.0), 1.0)
    }

    // The inline forum slides in over Chats: the circle narrows with Chats' right side and the capsule follows it, so
    // the right side moves continuously (here halfway: the circle 22 pt, the capsule 28 pt in from the edge).
    func test_secondaryContentSlide_circleNarrows_capsuleFollows() {
        let bar = ComponentView<Empty>()
        let primary = NavigationBarComponent.Content(title: .text("Chats"), back: nil, leftButton: nil, rightButtons: self.chatsButtons(), backPressed: {})
        let secondary = NavigationBarComponent.Content(title: .text("Forum"), back: .back, leftButton: nil, rightButtons: [self.fixedButton("more")], backPressed: {})
        func update(_ secondaryContent: NavigationBarComponent.Content?, _ fraction: CGFloat) -> NavigationBarComponent.View {
            let size = bar.update(
                transition: .immediate,
                component: AnyComponent(NavigationBarComponent(theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, primaryContent: primary, secondaryContent: secondaryContent, secondaryTransition: fraction)),
                environment: {},
                containerSize: CGSize(width: 390.0, height: 44.0)
            )
            let view = bar.view as! NavigationBarComponent.View
            view.frame = CGRect(origin: CGPoint(), size: size)
            return view
        }
        let _ = update(nil, 0.0)
        let view = update(secondary, 0.5)
        // Circle: 44 -> 0 is 22; extent: 56 -> 0 is 28. Capsule: 88 -> 44 is 66 wide, ending 28 pt from the edge.
        XCTAssertEqual(view.rightPillBackgroundContainer(at: 0)?.frame, CGRect(x: 390.0 - 16.0 - 22.0, y: 0.0, width: 22.0, height: 44.0))
        XCTAssertEqual(view.rightPillBackgroundContainer(at: 1)?.frame, CGRect(x: 390.0 - 16.0 - 28.0 - 66.0, y: 0.0, width: 66.0, height: 44.0))
    }

    // The circle keeps the tint of the content it belongs to: sliding to a forum (which has no circle), Chats' compose
    // circle narrows on its accent glass. It took the forum's generic tint for the whole slide, a grey circle under the
    // white compose glyph, and turned blue only once the slide ended.
    func test_secondaryContentSlide_circleKeepsItsOwnersTint() {
        let bar = ComponentView<Empty>()
        let primary = NavigationBarComponent.Content(title: .text("Chats"), back: nil, leftButton: nil, rightButtons: self.chatsButtons(), backPressed: {})
        let secondary = NavigationBarComponent.Content(title: .text("Forum"), back: .back, leftButton: nil, rightButtons: [self.fixedButton("more")], backPressed: {})
        func update(_ secondaryContent: NavigationBarComponent.Content?, _ fraction: CGFloat) -> NavigationBarComponent.View {
            let size = bar.update(
                transition: .immediate,
                component: AnyComponent(NavigationBarComponent(theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, primaryContent: primary, secondaryContent: secondaryContent, secondaryTransition: fraction)),
                environment: {},
                containerSize: CGSize(width: 390.0, height: 44.0)
            )
            let view = bar.view as! NavigationBarComponent.View
            view.frame = CGRect(origin: CGPoint(), size: size)
            return view
        }
        XCTAssertEqual(update(nil, 0.0).appliedRightPillTint(at: 0), .accent)
        XCTAssertEqual(update(secondary, 0.2).appliedRightPillTint(at: 0), .accent)
        XCTAssertEqual(update(secondary, 0.9).appliedRightPillTint(at: 0), .accent)
    }

    // A change made without animation is applied as is.
    func test_immediateItemChange_isNotAnimated() {
        let bar = ComponentView<Empty>()
        let _ = self.updateBar(bar, back: .back, right: [self.fixedButton("edit")], transition: .immediate)
        let view = self.updateBar(bar, back: nil, right: [self.fixedButton("done", tint: .accent)], transition: .immediate)
        XCTAssertNil(view.inPlaceStateForTesting(isLeft: false))
        XCTAssertNil(view.inPlaceStateForTesting(isLeft: true))
    }

    // A transition carries on the press UIKit draws on every right pill, by index from the edge.
    func test_detachingPlatters_measuresEveryRightPill() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: nil, right: [self.fixedButton("a", tint: .accent), self.fixedButton("b", tint: .accent), self.fixedButton("c")], transition: .immediate)
        guard let third = view.rightPillBackgroundContainer(at: 2), let glass = navigationBarTestGlassEffectView(content: third.contentView, container: third) else {
            XCTFail("no third pill")
            return
        }
        let center = glass.center
        glass.bounds = CGRect(x: 0.0, y: 0.0, width: 55.0, height: 55.0)
        glass.center = center
        view.plattersDetached = true
        XCTAssertEqual(view.detachedRightPressScales.count, 3)
        XCTAssertEqual(view.detachedRightPressScales.count > 2 ? view.detachedRightPressScales[2] : 1.0, 55.0 / 44.0, accuracy: 0.001)
    }

    private func doneOnly() -> [NavigationBarComponent.Button] {
        return [self.fixedButton("done", tint: .accent)]
    }

    private func settle(_ view: NavigationBarComponent.View) {
        for _ in 0 ..< 360 {
            view.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
    }

    // Edit -> Done: the search pill is sucked into Done (its nearest remaining pill), its glass merged with Done's in one
    // container while it collapses, then gone; Done's glass is its own again.
    func test_inPlaceMerge_leavingPill_collapsesIntoTheNearestPill() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let search = before.rightPillBackgroundContainer(at: 1), let edit = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("not two pills")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        guard let start = view.inPlaceStateForTesting(slot: .right(1)) else {
            XCTFail("no merge")
            return
        }
        XCTAssertTrue(start.isMatched)
        XCTAssertTrue(search.isGlassLent)
        XCTAssertTrue(edit.isGlassLent)
        view.inPlaceTickForTesting(dt: 0.3)
        guard let mid = view.inPlaceStateForTesting(slot: .right(1)) else {
            XCTFail("merge ended early")
            return
        }
        XCTAssertGreaterThan(mid.frame.midX, start.frame.midX)
        self.settle(view)
        XCTAssertNil(search.superview)
        XCTAssertFalse(edit.isGlassLent)
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 0) === edit)
    }

    // While two pills merge, their glass is laid out by its frame and size, untransformed, as push/pop lays out merged
    // platters (the glass container fuses shapes by their geometry).
    func test_inPlaceMerge_lentGlass_isLaidOutByFrame_untransformed() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.08)
        guard let partner = view.inPlaceStateForTesting(slot: .right(0)), let leaving = view.inPlaceStateForTesting(slot: .right(1)) else {
            XCTFail("no merge")
            return
        }
        XCTAssertGreaterThan(partner.pulse.width, 1.0)
        XCTAssertFalse(partner.isGlassTransformed)
        XCTAssertFalse(leaving.isGlassTransformed)
        // The partner's glass is drawn at its swollen size.
        XCTAssertGreaterThan(partner.glassFrame?.width ?? 0.0, partner.frame.width)
    }

    // The pair pulses about SwiftUI's transition anchor (`transitionAnchor`, shared with push/pop): a right pill's
    // trailing edge, so the partner swells toward the leaving pill.
    func test_inPlaceMerge_partnerPulse_isAnchoredAtTheTrailingEdge() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        guard let partner = view.inPlaceStateForTesting(slot: .right(0)) else {
            XCTFail("no partner")
            return
        }
        XCTAssertEqual(partner.pulseAnchor.x, 1.0)
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(1))?.pulseAnchor.x, 1.0)
    }

    // Native (the Administrators film): the leaving search pill takes Done's accent tint as it goes into it.
    func test_inPlaceMerge_movingPill_takesItsPartnersTint() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        guard let leaving = view.inPlaceStateForTesting(slot: .right(1)), let partner = view.inPlaceStateForTesting(slot: .right(0)) else {
            XCTFail("no merge")
            return
        }
        XCTAssertEqual(leaving.tintColor, partner.tintColor)
    }

    // Done -> Edit: search grows out of the Edit pill (its nearest previous pill) and separates to its own frame.
    func test_inPlaceMerge_arrivingPill_growsOutOfItsPartner() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let done = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no pill")
            return
        }
        let doneFrame = done.frame
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        guard let start = view.inPlaceStateForTesting(slot: .right(1)), let search = view.rightPillBackgroundContainer(at: 1) else {
            XCTFail("no eject")
            return
        }
        XCTAssertTrue(start.isMatched)
        XCTAssertEqual(start.frame.midX, doneFrame.midX, accuracy: 0.5)
        self.settle(view)
        XCTAssertFalse(search.isGlassLent)
        XCTAssertEqual(search.frame.maxX, (view.rightPillBackgroundContainer(at: 0)?.frame.minX ?? 0.0) - 12.0)
    }

    // Edit -> Done -> Edit before the merge ends: the search pill that was leaving is the one that comes back.
    func test_inPlaceMerge_pillComingBack_isReused() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let search = before.rightPillBackgroundContainer(at: 1) else {
            XCTFail("no pill")
            return
        }
        let _ = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        before.inPlaceTickForTesting(dt: 0.1)
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 1) === search)
        self.settle(view)
        XCTAssertTrue(search.superview === view)
        XCTAssertFalse(search.isGlassLent)
    }

    // Without native glass merging the leaving pill keeps its own container and fades with it.
    func test_inPlaceMerge_withoutNativeMerging_fadesInItsOwnContainer() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { false }
        guard let search = before.rightPillBackgroundContainer(at: 1) else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertFalse(search.isGlassLent)
        self.settle(view)
        XCTAssertNil(search.superview)
    }

    // Reduce Motion: the leaving pill dematerializes where it is, no merge.
    func test_inPlaceMerge_underReduceMotion_dematerializesInPlace() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        before.inPlaceReduceMotion = { true }
        guard let search = before.rightPillBackgroundContainer(at: 1) else {
            XCTFail("no pill")
            return
        }
        let frame = search.frame
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(1))?.isMatched, false)
        view.inPlaceTickForTesting(dt: 0.2)
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(1))?.frame ?? .zero, frame)
        XCTAssertFalse(search.isGlassLent)
    }

    // Review focus 5: the arriving search pill takes a tap at once, while its glass is lent.
    func test_inPlaceMerge_arrivingPill_takesTapsAtOnce() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .immediate)
        before.glassMergesShapes = { true }
        testWindow.addSubview(before)
        defer {
            before.removeFromSuperview()
        }
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.05)
        guard let search = view.rightPillBackgroundContainer(at: 1), let searchButton = view.rightButtonViews["search"] else {
            XCTFail("no pill")
            return
        }
        XCTAssertTrue(search.isGlassLent)
        let point = searchButton.convert(CGPoint(x: searchButton.bounds.midX, y: searchButton.bounds.midY), to: view)
        XCTAssertTrue(view.hitTest(point, with: nil)?.isDescendant(of: searchButton) ?? false)
    }

    // Review focus 1: a transition taking the platters mid-merge gets every glass back in its pill and no merging
    // container left in the bar.
    func test_inPlaceMerge_platterDetachMidMerge_reclaimsTheGlass() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.05)
        view.plattersDetached = true
        XCTAssertFalse(edit.isGlassLent)
        XCTAssertFalse(view.subviews.contains(where: { $0 is GlassBackgroundContainerView }))
    }

    // Review focus 2: a long press on the partner mid-merge finishes the merge before the menu extracts its container.
    func test_inPlaceMerge_contextMenuMidMerge_reclaimsTheGlass() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.05)
        guard let doneButton = view.rightButtonViews["done"], let container = view.navigationButtonContextContainer(sourceView: doneButton) as? GlassContextExtractableContainer else {
            XCTFail("no context container")
            return
        }
        XCTAssertFalse(container.isGlassLent)
        XCTAssertNil(view.inPlaceStateForTesting(slot: .right(1)))
    }

    // Review focus 3: a relayout mid-merge (a wider bar) settles every pill at its new frame with its glass reclaimed.
    func test_inPlaceMerge_relayoutMidMerge_settlesAtTheNewFrames() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let _ = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        before.inPlaceTickForTesting(dt: 0.05)
        let content = NavigationBarComponent.Content(title: .text("Private Chats"), back: .back, leftButton: nil, rightButtons: self.doneOnly(), backPressed: {})
        let _ = bar.update(transition: .easeInOut(duration: 0.3), component: AnyComponent(NavigationBarComponent(theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, primaryContent: content, secondaryContent: nil, secondaryTransition: 0.0)), environment: {}, containerSize: CGSize(width: 430.0, height: 44.0))
        let view = bar.view as! NavigationBarComponent.View
        self.settle(view)
        guard let done = view.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no pill")
            return
        }
        XCTAssertEqual(done.frame, CGRect(x: 430.0 - 16.0 - 44.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertFalse(done.isGlassLent)
    }

    // A relayout while search is sucked into Done: search heads for Done's new frame, not where Done was, and the merging
    // container spans the new bar.
    func test_inPlaceMerge_relayoutMidMerge_leavingPillFollowsItsPartner() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let _ = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        before.inPlaceTickForTesting(dt: 0.05)
        let content = NavigationBarComponent.Content(title: .text("Private Chats"), back: .back, leftButton: nil, rightButtons: self.doneOnly(), backPressed: {})
        let _ = bar.update(transition: .easeInOut(duration: 0.3), component: AnyComponent(NavigationBarComponent(theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, primaryContent: content, secondaryContent: nil, secondaryTransition: 0.0)), environment: {}, containerSize: CGSize(width: 430.0, height: 44.0))
        let view = bar.view as! NavigationBarComponent.View
        view.frame = CGRect(x: 0.0, y: 0.0, width: 430.0, height: 44.0)
        XCTAssertEqual(view.inPlaceMergeContainer?.frame.width ?? 430.0, 430.0)
        view.inPlaceTickForTesting(dt: 0.3)
        guard let leaving = view.inPlaceStateForTesting(slot: .right(1)) else {
            XCTFail("the leaving pill settled early")
            return
        }
        // Done was centred at 352 in the 390 pt bar and is at 392 in the 430 pt one.
        XCTAssertGreaterThan(leaving.frame.midX, 372.0)
    }

    // An item change on a pill still lent to a merge (the pill count unchanged) is cross-faded by the bar too: UIKit's
    // animated effect change would band the merged shape.
    func test_inPlaceMerge_itemChangeOnALentPill_crossFadesFrameByFrame() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.05)
        guard let done = view.rightPillBackgroundContainer(at: 0), done.isGlassLent, let from = done.glassTintColor else {
            XCTFail("Done is not merging")
            return
        }
        let _ = self.updateBar(bar, back: .back, right: [self.fixedButton("save")], transition: .easeInOut(duration: 0.3))
        XCTAssertEqual(done.glassTintColor, from)
        self.settle(view)
        XCTAssertEqual(done.glassTintColor, navigationBarGlassTintColor(.generic, theme: self.makeTheme()))
    }

    // A press UIKit was drawing on the partner when its glass was lent goes on as the animator's own release.
    func test_inPlaceMerge_partnerPress_continuesAsASpring() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0), let glass = navigationBarTestGlassEffectView(content: edit.contentView, container: edit) else {
            XCTFail("no pill")
            return
        }
        let center = glass.center
        glass.bounds = CGRect(x: 0.0, y: 0.0, width: edit.bounds.width * 1.1, height: 44.0 * 1.1)
        glass.center = center
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(0))?.press ?? 1.0, 1.1, accuracy: 0.01)
        self.settle(view)
        XCTAssertNil(view.inPlaceStateForTesting(slot: .right(0)))
    }

    /// The bar before Edit -> Done, with UIKit's press on Edit faked by growing its effect view (as `_UIFlexInteraction`
    /// does), and that effect view.
    private func pressedEditAndSearch(_ bar: ComponentView<Empty>) -> (edit: GlassContextExtractableContainer, glass: UIView)? {
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0), let glass = navigationBarTestGlassEffectView(content: edit.contentView, container: edit) else {
            return nil
        }
        let center = glass.center
        glass.bounds = CGRect(x: 0.0, y: 0.0, width: edit.bounds.width * 1.1, height: 44.0 * 1.1)
        glass.center = center
        return (edit, glass)
    }

    // A glass UIKit is pressing is not fused with its neighbours in a glass container: it keeps its own edge inside the
    // merged shape (a darker band where search joins Done, a darker disc where it was absorbed: probed on iOS 27, and only
    // a new effect view was clean). So the pressed partner merges on a new effect view holding the same content.
    func test_inPlaceMerge_pressedPartner_mergesOnANewEffectView() {
        let bar = ComponentView<Empty>()
        guard let (edit, pressedGlass) = self.pressedEditAndSearch(bar) else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        guard let glass = navigationBarTestGlassEffectView(content: edit.contentView, container: edit) else {
            XCTFail("the content is not in a glass")
            return
        }
        XCTAssertFalse(glass === pressedGlass)
        XCTAssertNil(pressedGlass.superview)
        XCTAssertTrue(edit.isGlassLent)
        // The press goes on as the bar's own release.
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(0))?.press ?? 1.0, 1.1, accuracy: 0.01)
    }

    // A pill going into its partner carries its items with it (iOS 27's search glyph stays inside the moving shape until
    // it fades), where an in-place change leaves them where they rest while the shape morphs around them.
    func test_inPlaceMerge_leavingPill_carriesItsItems() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.15)
        guard let offset = view.inPlaceStateForTesting(slot: .right(1))?.leavingItemsOffsetInGlass else {
            XCTFail("no leaving items in the lent glass")
            return
        }
        XCTAssertEqual(offset.x, 0.0, accuracy: 0.5)
        XCTAssertEqual(offset.y, 0.0, accuracy: 0.5)
    }

    // UIKit's animated change of a glass effect draws a dark band where two merging shapes meet (probed on iOS 27: an
    // effect set every frame does not), so a merging pill's tint cross-fades frame by frame, from where it was.
    func test_inPlaceMerge_partnerTint_crossFadesFrameByFrame() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0), let from = edit.glassTintColor else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertEqual(edit.glassTintColor, from)
        view.inPlaceTickForTesting(dt: 0.03)
        guard case let .custom(_, color)? = edit.glassTintColor?.kind else {
            XCTFail("not cross-fading: \(String(describing: edit.glassTintColor))")
            return
        }
        var alpha: CGFloat = 0.0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(alpha, 0.15)
        XCTAssertLessThan(alpha, 0.95)
        self.settle(view)
        XCTAssertEqual(edit.glassTintColor, navigationBarGlassTintColor(.accent, theme: self.makeTheme()))
    }

    /// How far a merging pill's tint has gone from `from` to `to`, read from the glass's tint alpha (the blend mixes it).
    private func tintFraction(_ container: GlassContextExtractableContainer?, from: CGFloat, to: CGFloat) -> CGFloat? {
        guard case let .custom(_, color)? = container?.glassTintColor?.kind else {
            return nil
        }
        var alpha: CGFloat = 0.0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        return (alpha - from) / (to - from)
    }

    // Native's tint fades as its shapes move, on the glass transition spring (measured 2026-10-16, four reference films,
    // tapped and not: white <-> accent takes ~0.25 s, about half way at 0.1 s), not at once.
    func test_inPlaceMerge_partnerTint_fadesOnTheTransitionSpring() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let edit = before.rightPillBackgroundContainer(at: 0)
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        for _ in 0 ..< 12 {
            view.inPlaceTickForTesting(dt: 0.1 / 12.0)
        }
        // The panel tint's alpha is 0.1, the accent's 1.
        guard let fraction = self.tintFraction(edit, from: 0.1, to: 1.0) else {
            XCTFail("not cross-fading: \(String(describing: edit?.glassTintColor))")
            return
        }
        XCTAssertGreaterThan(fraction, 0.4)
        XCTAssertLessThan(fraction, 0.7)
    }

    // Done -> Edit: search, growing out of Done, fades from Done's accent to the plain glass on the same spring.
    func test_inPlaceMerge_arrivingPillTint_fadesOnTheTransitionSpring() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        for _ in 0 ..< 12 {
            view.inPlaceTickForTesting(dt: 0.1 / 12.0)
        }
        guard let fraction = self.tintFraction(view.rightPillBackgroundContainer(at: 1), from: 1.0, to: 0.1) else {
            XCTFail("not cross-fading: \(String(describing: view.rightPillBackgroundContainer(at: 1)?.glassTintColor))")
            return
        }
        XCTAssertGreaterThan(fraction, 0.4)
        XCTAssertLessThan(fraction, 0.7)
    }

    // A pill growing out of its partner starts in the partner's tint and cross-fades to its own, frame by frame too.
    func test_inPlaceMerge_arrivingPill_crossFadesFromItsPartnersTint() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        guard let search = view.rightPillBackgroundContainer(at: 1) else {
            XCTFail("no eject")
            return
        }
        XCTAssertEqual(search.glassTintColor, navigationBarGlassTintColor(.accent, theme: self.makeTheme()))
        view.inPlaceTickForTesting(dt: 0.03)
        guard case let .custom(_, color)? = search.glassTintColor?.kind else {
            XCTFail("not cross-fading: \(String(describing: search.glassTintColor))")
            return
        }
        var alpha: CGFloat = 0.0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(alpha, 0.15)
        XCTAssertLessThan(alpha, 0.95)
        self.settle(view)
        XCTAssertEqual(search.glassTintColor, navigationBarGlassTintColor(.generic, theme: self.makeTheme()))
    }

    // A change while pills still merge reads no press from the merge's own scaling (the pulse grows the lent glass), so it
    // keeps the glass and continues nothing.
    func test_inPlaceMerge_changeMidMerge_readsNoPressFromItsOwnScaling() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.05)
        XCTAssertGreaterThan(view.inPlaceStateForTesting(slot: .right(0))?.pulse.width ?? 1.0, 1.0)
        guard let glass = navigationBarTestGlassEffectView(content: edit.contentView, container: edit) else {
            XCTFail("no glass")
            return
        }
        _ = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(navigationBarTestGlassEffectView(content: edit.contentView, container: edit) === glass)
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(0))?.press ?? 0.0, 1.0, accuracy: 0.001)
    }

    // A tap on a pill whose glass is still lent to a merge (the previous change's springs have not settled): its press goes
    // on as the bar's own, as for a pill lent afresh, rather than snapping off with the renewed glass.
    func test_inPlaceMerge_pressOnALentGlass_continues() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.05)
        guard let pressed = navigationBarTestGlassEffectView(content: edit.contentView, container: edit), let shape = pressed.superview?.bounds.size else {
            XCTFail("no glass")
            return
        }
        XCTAssertTrue(edit.isGlassLent)
        let center = pressed.center
        pressed.bounds = CGRect(x: 0.0, y: 0.0, width: shape.width * 1.1, height: shape.height * 1.1)
        pressed.center = center
        _ = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        XCTAssertFalse(navigationBarTestGlassEffectView(content: edit.contentView, container: edit) === pressed)
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(0))?.press ?? 1.0, 1.1, accuracy: 0.01)
    }

    // Two pills going into the same partner lend its glass twice in one layout; its press is carried on once.
    func test_inPlaceMerge_partnerOfTwo_carriesItsPressOnce() {
        let bar = ComponentView<Empty>()
        let texts = ["Edit", "Select", "Sort"].map { (title: String) in NavigationBarComponent.Button(id: title, content: .text(title: title, isBold: false), action: { _ in }) }
        let before = self.updateBar(bar, back: .back, right: texts, transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0), before.rightPillBackgroundContainer(at: 2) != nil, let glass = navigationBarTestGlassEffectView(content: edit.contentView, container: edit) else {
            XCTFail("not three pills")
            return
        }
        let center = glass.center
        glass.bounds = CGRect(x: 0.0, y: 0.0, width: edit.bounds.width * 1.1, height: 44.0 * 1.1)
        glass.center = center
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertNotNil(view.inPlaceStateForTesting(slot: .right(2)))
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(0))?.press ?? 1.0, 1.1, accuracy: 0.01)
    }

    private func textButtons(_ titles: [String]) -> [NavigationBarComponent.Button] {
        return titles.map { title in NavigationBarComponent.Button(id: title, content: .text(title: title, isBold: false), action: { _ in }) }
    }

    // Three pills, [Edit][Sort] -> [Done][Sort][Select]: Sort keeps its items but moves (Done is narrower than Edit), and
    // Select grows out of it. Sort springs from where it was to its new place and settles there.
    func test_inPlaceMerge_movingPartnerOfAnArrivingPill_springsToItsNewFrame() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.textButtons(["Edit", "Sort"]), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let sort = before.rightPillBackgroundContainer(at: 1) else {
            XCTFail("not two pills")
            return
        }
        let oldFrame = sort.frame
        let view = self.updateBar(bar, back: .back, right: [self.fixedButton("done", tint: .accent)] + self.textButtons(["Sort", "Select"]), transition: .easeInOut(duration: 0.3))
        guard view.inPlaceStateForTesting(slot: .right(2))?.isMatched == true, let start = view.inPlaceStateForTesting(slot: .right(1)) else {
            XCTFail("Select does not grow out of Sort")
            return
        }
        XCTAssertEqual(start.frame, oldFrame)
        // Its items go with it.
        view.inPlaceTickForTesting(dt: 0.05)
        guard let moving = view.inPlaceStateForTesting(slot: .right(1)), let sortButton = view.rightButtonViews["Sort"] else {
            XCTFail("Sort settled early")
            return
        }
        XCTAssertGreaterThan(moving.frame.minX, oldFrame.minX + 1.0)
        // Centred in its glass (the pair's pulse moves the glass's centre off the frame's).
        XCTAssertEqual(sortButton.convert(CGPoint(x: sortButton.bounds.midX, y: sortButton.bounds.midY), to: view).x, moving.glassFrame?.midX ?? moving.frame.midX, accuracy: 0.5)
        self.settle(view)
        guard let done = view.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no Done")
            return
        }
        XCTAssertEqual(sort.frame.maxX, done.frame.minX - 12.0)
        XCTAssertEqual(sort.frame.width, oldFrame.width)
    }

    // [Done][Sort][Select] -> [Edit][Sort]: Sort moves (Edit is wider than Done) and Select goes into it. Sort springs from
    // where it was rather than jumping to its new place.
    func test_inPlaceMerge_movingPartnerOfALeavingPill_springsFromWhereItWas() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: [self.fixedButton("done", tint: .accent)] + self.textButtons(["Sort", "Select"]), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let sort = before.rightPillBackgroundContainer(at: 1) else {
            XCTFail("not three pills")
            return
        }
        let oldFrame = sort.frame
        let view = self.updateBar(bar, back: .back, right: self.textButtons(["Edit", "Sort"]), transition: .easeInOut(duration: 0.3))
        guard view.inPlaceStateForTesting(slot: .right(2))?.isMatched == true, let start = view.inPlaceStateForTesting(slot: .right(1)) else {
            XCTFail("Select does not go into Sort")
            return
        }
        XCTAssertEqual(start.frame, oldFrame)
        self.settle(view)
        guard let edit = view.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no Edit")
            return
        }
        XCTAssertEqual(sort.frame.maxX, edit.frame.minX - 12.0)
    }

    /// The bar mid-merge: [Edit][search] -> [Done], 0.05 s in, Done's and search's glass lent.
    private func midMerge(_ bar: ComponentView<Empty>) -> (view: NavigationBarComponent.View, done: GlassContextExtractableContainer)? {
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.05)
        guard let done = view.rightPillBackgroundContainer(at: 0), done.isGlassLent else {
            return nil
        }
        return (view, done)
    }

    // A layout without animation that takes away a pill whose glass is lent to a merge ends that merge at once: nothing of
    // it stays in the merging container while its springs would have settled.
    func test_inPlaceMerge_immediateRemovalOfALentPill_endsItsMerge() {
        let bar = ComponentView<Empty>()
        guard let (view, done) = self.midMerge(bar) else {
            XCTFail("Done is not merging")
            return
        }
        let _ = self.updateBar(bar, back: .back, right: [], transition: .immediate)
        XCTAssertFalse(done.isGlassLent)
        XCTAssertNil(done.superview)
        XCTAssertNil(view.inPlaceStateForTesting(slot: .right(0)))
        XCTAssertNil(view.inPlaceStateForTesting(slot: .right(1)))
        XCTAssertNil(view.inPlaceMergeContainer)
    }

    // UIKit's press is read (a scale and a walk of the glass's layers) only by a layout that changes items in place, not
    // by every layout: a secondary content sliding over the bar lays it out every frame.
    func test_layoutWithoutAnInPlaceChange_readsNoPress() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        var reads = 0
        view.inPlacePressReader = { container in
            reads += 1
            return navigationBarCapsulePress(container)
        }
        let primary = NavigationBarComponent.Content(title: .text("Private Chats"), back: .back, leftButton: nil, rightButtons: self.editAndSearch(), backPressed: {})
        let secondary = NavigationBarComponent.Content(title: .text("Forum"), back: .back, leftButton: nil, rightButtons: [self.fixedButton("more")], backPressed: {})
        for fraction: CGFloat in [0.0, 0.3, 0.6] {
            let _ = bar.update(transition: .immediate, component: AnyComponent(NavigationBarComponent(theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, primaryContent: primary, secondaryContent: secondary, secondaryTransition: fraction)), environment: {}, containerSize: CGSize(width: 390.0, height: 44.0))
        }
        let _ = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        XCTAssertEqual(reads, 0)
        // An in-place change still reads it.
        let _ = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertGreaterThan(reads, 0)
    }

    // A context menu extracting a pill's container takes its glass back itself (a backstop: the bar ends a merge before it
    // hands a container to a menu). The merge then lays the glass out as the container's own, not as lent.
    func test_inPlaceMerge_containerTakingItsGlassBack_endsTheLoan() {
        let bar = ComponentView<Empty>()
        guard let (view, done) = self.midMerge(bar) else {
            XCTFail("Done is not merging")
            return
        }
        done.updateState(state: .extracted(size: CGSize(width: 200.0, height: 100.0), cornerRadius: 20.0, state: .animatedIn), transition: .transition(.immediate), completion: nil)
        view.inPlaceTickForTesting(dt: 1.0 / 60.0)
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(0))?.isGlassLent, false)
        var glass: UIView? = done.contentView.superview
        while let current = glass, !(current is GlassBackgroundView) {
            glass = current.superview
        }
        XCTAssertTrue(glass?.isDescendant(of: done) ?? false)
        XCTAssertLessThan(abs(glass?.frame.minX ?? 1000.0), 1.0)
    }

    // A transition taking the bar mid-merge carries on the press the bar is continuing on a renewed glass (UIKit's was ended
    // with the old glass, so the glass reads none), with no glow: the merge draws none, so a glow would flash in.
    func test_inPlaceMerge_detachingMidMerge_carriesTheBarsPress() {
        let bar = ComponentView<Empty>()
        guard self.pressedEditAndSearch(bar) != nil else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.02)
        let press = view.inPlaceStateForTesting(slot: .right(0))?.press ?? 1.0
        XCTAssertGreaterThan(press, 1.01)
        view.plattersDetached = true
        XCTAssertEqual(view.detachedRightPressScales.first ?? 1.0, press, accuracy: 0.001)
        XCTAssertEqual(view.detachedRightPressGlows.first ?? -1.0, 0.0, accuracy: 0.001)
    }

    // A press the sampler caught during the touch (UIKit's, on the glass the merge then renewed) and the bar's continuation
    // of that same press are one press: a transition right after the change gets it once, with no glow.
    func test_inPlaceMerge_detachingRightAfterASampledPress_carriesThePressOnce() {
        let bar = ComponentView<Empty>()
        guard let (edit, glass) = self.pressedEditAndSearch(bar), let editButton = (bar.view as? NavigationBarComponent.View)?.rightButtonViews["edit"] else {
            XCTFail("no pill")
            return
        }
        let before = bar.view as! NavigationBarComponent.View
        testWindow.addSubview(before)
        defer {
            before.removeFromSuperview()
        }
        let now = 100.0
        before.pressSamplerClock = {
            return now
        }
        // The touch on Edit, sampled while UIKit's press is on its glass.
        XCTAssertTrue(before.hitTest(editButton.convert(CGPoint(x: editButton.bounds.midX, y: editButton.bounds.midY), to: before), with: nil)?.isDescendant(of: editButton) ?? false)
        XCTAssertTrue(glass.superview != nil)
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(edit.isGlassLent)
        view.inPlaceTickForTesting(dt: 1.0 / 60.0)
        // The sampler's next frame reads the renewed glass.
        view.tickPressSampler()
        let press = view.inPlaceStateForTesting(slot: .right(0))?.press ?? 1.0
        XCTAssertGreaterThan(press, 1.05)
        view.plattersDetached = true
        XCTAssertEqual(view.detachedRightPressScales.first ?? 1.0, press, accuracy: 0.001)
        XCTAssertEqual(view.detachedRightPressGlows.first ?? -1.0, 0.0, accuracy: 0.001)
    }

    // A touch on a pill whose glass is lent to a merge is sampled like any other, so a transition it starts carries its
    // press.
    func test_inPlaceMerge_touchOnALentGlass_samplesThePress() {
        let bar = ComponentView<Empty>()
        guard let (view, done) = self.midMerge(bar), let doneButton = view.rightButtonViews["done"], let pressed = navigationBarTestGlassEffectView(content: done.contentView, container: done), let shape = pressed.superview?.bounds.size else {
            XCTFail("Done is not merging")
            return
        }
        testWindow.addSubview(view)
        defer {
            view.removeFromSuperview()
        }
        let center = pressed.center
        let rest = pressed.bounds
        pressed.bounds = CGRect(x: 0.0, y: 0.0, width: shape.width * 1.1, height: shape.height * 1.1)
        pressed.center = center
        let point = doneButton.convert(CGPoint(x: doneButton.bounds.midX, y: doneButton.bounds.midY), to: view)
        XCTAssertTrue(view.hitTest(point, with: nil)?.isDescendant(of: doneButton) ?? false)
        // The touch ends: UIKit takes the press off, then the action starts a transition.
        pressed.bounds = rest
        pressed.center = center
        view.plattersDetached = true
        XCTAssertEqual(view.detachedRightPressScales.first ?? 1.0, 1.1, accuracy: 0.01)
    }

    // A change to the dark appearance mid-merge reaches the merging container, which draws the merged glass.
    func test_inPlaceMerge_appearanceChangeMidMerge_reachesTheMergingContainer() {
        let bar = ComponentView<Empty>()
        guard let (view, _) = self.midMerge(bar) else {
            XCTFail("Done is not merging")
            return
        }
        let dark = NavigationBarTheme(overallDarkAppearance: true, buttonColor: .white, disabledButtonColor: .gray, primaryTextColor: .white, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .gray, accentForegroundColor: .white)
        let content = NavigationBarComponent.Content(title: .text("Private Chats"), back: .back, leftButton: nil, rightButtons: self.doneOnly(), backPressed: {})
        let _ = bar.update(transition: .easeInOut(duration: 0.3), component: AnyComponent(NavigationBarComponent(theme: dark, strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, primaryContent: content, secondaryContent: nil, secondaryTransition: 0.0)), environment: {}, containerSize: CGSize(width: 390.0, height: 44.0))
        var effectView: UIView? = view.inPlaceMergeContainer?.contentView
        while let current = effectView, !(current is UIVisualEffectView) {
            effectView = current.superview
        }
        XCTAssertEqual(effectView?.overrideUserInterfaceStyle, .dark)
    }

    // A merge with no press on the partner keeps its effect view (renewing it would cut a tint change short).
    func test_inPlaceMerge_unpressedPartner_keepsItsEffectView() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0), let glass = navigationBarTestGlassEffectView(content: edit.contentView, container: edit) else {
            XCTFail("no pill")
            return
        }
        _ = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(navigationBarTestGlassEffectView(content: edit.contentView, container: edit) === glass)
    }

    // The merge draws no press glow of its own over the new effect view: push/pop's glow, drawn over a tinted glass, turns
    // an accent pill cyan (measured: 99eefc, 3bd8fa), where iOS 27's pressed Done fades from white to accent through pale
    // blues (c3def7, 8ccafc, 52b9fc). The press's scale goes on.
    func test_inPlaceMerge_pressedPartner_drawsNoGlow() {
        let bar = ComponentView<Empty>()
        guard let (edit, _) = self.pressedEditAndSearch(bar) else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertFalse(edit.contentView.superview?.subviews.contains(where: { $0 is NavigationBarPressGlowView }) ?? true)
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(0))?.press ?? 1.0, 1.1, accuracy: 0.01)
    }

    private func editAndSearch() -> [NavigationBarComponent.Button] {
        return [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in }), self.fixedButton("search")]
    }

    // Channel Administrators: Edit and search are two pills, Edit outermost at the right inset and search 12 pt before it.
    func test_rightPills_editAndSearch_areTwoPillsTwelvePointsApart() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        guard let edit = view.rightPillBackgroundContainer(at: 0), let search = view.rightPillBackgroundContainer(at: 1), let editButton = view.rightButtonViews["edit"], let searchButton = view.rightButtonViews["search"] else {
            XCTFail("not two pills")
            return
        }
        XCTAssertEqual(edit.frame.maxX, 390.0 - 16.0)
        XCTAssertEqual(search.frame, CGRect(x: edit.frame.minX - 12.0 - 44.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertTrue(editButton.isDescendant(of: edit))
        XCTAssertTrue(searchButton.isDescendant(of: search))
        // Each pill holds one button, so each morphs into its button's context menu.
        XCTAssertTrue(edit.morphsIntoContextMenu)
        XCTAssertTrue(search.morphsIntoContextMenu)
        XCTAssertTrue(view.navigationButtonContextContainer(sourceView: searchButton) === search)
    }

    // Saved Messages' [search, …]: two buttons in one pill. A menu from either morphs the whole pill, its other button
    // with it, and closes back into it, as UIKit's does with a section of several items (measured on iOS 27).
    func test_twoButtonPill_morphsWholeIntoEitherButtonsMenu() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: [self.fixedButton("more"), self.fixedButton("search")], transition: .immediate)
        guard let pill = view.rightPillBackgroundContainer(at: 0), let more = view.rightButtonViews["more"], let search = view.rightButtonViews["search"] else {
            XCTFail("not one pill")
            return
        }
        XCTAssertNil(view.rightPillBackgroundContainer(at: 1))
        XCTAssertTrue(pill.morphsIntoContextMenu)
        XCTAssertTrue(view.navigationButtonContextContainer(sourceView: more) === pill)
        XCTAssertTrue(view.navigationButtonContextContainer(sourceView: search) === pill)
    }

    // The title clears both pills and the gap between them.
    func test_rightPills_titleBand_clearsEveryPill() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        guard let edit = view.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no pill")
            return
        }
        XCTAssertEqual(view.primaryRightButtonsWidth, edit.frame.width + 12.0 + 44.0)
        XCTAssertFalse(view.primaryHasRoomForTitlePill)
    }

    // Review focus 4 (guard): Done toggling enabled keeps the same two pills, only retinting.
    func test_rightPills_doneEnabledToggle_keepsThePills() {
        let bar = ComponentView<Empty>()
        let enabled = self.updateBar(bar, back: .back, right: [self.fixedButton("done", tint: .accent), self.fixedButton("search")], transition: .immediate)
        guard let done = enabled.rightPillBackgroundContainer(at: 0), let search = enabled.rightPillBackgroundContainer(at: 1) else {
            XCTFail("not two pills")
            return
        }
        let view = self.updateBar(bar, back: .back, right: [self.fixedButton("done", tint: .accentDisabled), self.fixedButton("search")], transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 0) === done)
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 1) === search)
        XCTAssertNil(view.inPlaceStateForTesting(slot: .right(0)))
        XCTAssertNil(view.inPlaceStateForTesting(slot: .right(1)))
        XCTAssertEqual(view.appliedRightPillTint(at: 0), .accentDisabled)
    }

    // A transition takes every pill and gives them back.
    func test_rightPills_leaveWithThePlatters_andComeBack() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        view.plattersDetached = true
        XCTAssertNil(view.rightPillBackgroundContainer(at: 0)?.superview)
        XCTAssertNil(view.rightPillBackgroundContainer(at: 1)?.superview)
        view.plattersDetached = false
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 1)?.superview === view)
    }
}

/// The glass effect view a capsule's content sits in: what UIKit's press grows.
func navigationBarTestGlassEffectView(content: UIView, container: UIView) -> UIView? {
    var current: UIView? = content.superview
    while let view = current, view !== container {
        if view is UIVisualEffectView {
            return view
        }
        current = view.superview
    }
    return nil
}

