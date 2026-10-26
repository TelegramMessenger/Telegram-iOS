import XCTest
import UIKit
import AsyncDisplayKit
import Display
@testable import NavigationBarComponent
@testable import NavigationBarNode

private final class ActionCounter: NSObject {
    var count = 0

    @objc func fire() {
        self.count += 1
    }
}

private final class ReplacementContentNode: NavigationBarContentNode {
    override var nominalHeight: CGFloat {
        return 44.0
    }

    override var mode: NavigationBarContentMode {
        return .replacement
    }
}

private final class ExpansionContentNode: NavigationBarContentNode {
    override var nominalHeight: CGFloat {
        return 50.0
    }

    override var mode: NavigationBarContentMode {
        return .expansion
    }
}

/// A title on a glass pill, as the chat header draws one.
private final class PillTitleView: UIView, NavigationBarGlassPillTitleView {
    var requestUpdate: ((ContainedViewLayoutTransition) -> Void)?
    /// What it has lent, until its pill is attached again.
    private(set) var lentContent: UIView?
    var isGlassPillDetached = false {
        didSet {
            if !self.isGlassPillDetached {
                self.lentContent = nil
            }
        }
    }
    let pillFrame = CGRect(x: 10.0, y: 6.0, width: 120.0, height: 44.0)
    var glassPillFrame: CGRect? {
        return self.pillFrame
    }
    func lendGlassPillContent() -> UIView? {
        if let lentContent = self.lentContent {
            return lentContent
        }
        let view = UIView()
        self.lentContent = view
        return view
    }
    func animateLayoutTransition() {
    }
    func updateLayout(availableSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        return CGSize(width: 140.0, height: 56.0)
    }
}

private final class FakeComponentSource: NavigationBarComponentTransitionSource {
    var componentTransitionState: NavigationBarComponentTransitionState?
    var transitionContentFrameUpdated: ((CGRect) -> Void)?
    func takeView() -> NavigationBarTransitionTakeViewInfo? { return nil }
    func putBack() {}
    func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition) {}
    /// What the renderer last told it, nil before it said anything.
    var keepsOwnBackdrop: Bool?
    func updateKeepsOwnBackdrop(_ keepsOwnBackdrop: Bool) {
        self.keepsOwnBackdrop = keepsOwnBackdrop
    }

    init(backdropHeight: CGFloat, backdropAlpha: CGFloat, tintAlpha: CGFloat, edgeLength: CGFloat, keepsLoneBackdrop: Bool = false) {
        let theme = NavigationBarTheme(overallDarkAppearance: false, buttonColor: .black, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .lightGray, accentForegroundColor: .white)
        self.componentTransitionState = NavigationBarComponentTransitionState(content: NavigationBarComponent.Content(title: .text("A"), back: nil, leftButton: nil, rightButtons: [], backPressed: {}), theme: theme, strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), rowFrame: CGRect(x: 0.0, y: 57.0, width: 390.0, height: 44.0), rowAlpha: 1.0, leftInset: 16.0, rightInset: 16.0, trailingButtonsInset: 0.0, sideColumnFrame: nil, hidesSideColumnButtons: false, backdropHeight: backdropHeight, backdropColor: .white, backdropAlpha: backdropAlpha, backdropExtension: 0.0, backdropTintAlpha: tintAlpha, backdropEdgeLength: edgeLength, keepsLoneBackdrop: keepsLoneBackdrop)
    }
}

final class NavigationBarNodeTests: XCTestCase {
    private let time = ManualAnimationTime()

    override func setUp() {
        super.setUp()
        self.time.attach()
    }

    override func tearDown() {
        self.time.detach()
        super.tearDown()
    }

    private func makeNode() -> NavigationBarNode {
        let theme = NavigationBarTheme(overallDarkAppearance: false, buttonColor: .black, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .lightGray, accentForegroundColor: .white)
        return NavigationBarNode(presentationData: NavigationBarPresentationData(theme: theme, strings: NavigationBarStrings(back: "Back", close: "Close", more: "More")))
    }

    private func layout(_ node: NavigationBarNode) {
        node.frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0)
        node.updateLayout(size: CGSize(width: 390.0, height: 107.0), defaultHeight: 60.0, additionalTopHeight: 47.0, additionalContentHeight: 0.0, additionalBackgroundHeight: 0.0, leftInset: 0.0, rightInset: 0.0, appearsHidden: false, transition: .immediate)
    }

    func test_titleChanges_reachTheRow() {
        let node = self.makeNode()
        let item = UINavigationItem(title: "A")
        node.item = item
        self.layout(node)
        XCTAssertEqual(node.currentContent?.title, .text("A"))
        item.title = "B"
        node.layout()
        XCTAssertEqual(node.currentContent?.title, .text("B"))
    }

    func test_executeBack_runsTheBackAction() {
        let node = self.makeNode()
        var pressed = 0
        node.backPressed = {
            pressed += 1
        }
        node.item = UINavigationItem(title: "Sheet")
        node.previousItem = .close
        let _ = node.executeBack()
        XCTAssertEqual(pressed, 1)
    }

    func test_emptyRowSpace_fallsThrough() {
        let node = self.makeNode()
        node.item = UINavigationItem(title: "Settings")
        self.layout(node)
        XCTAssertNil(node.hitTest(CGPoint(x: 195.0, y: 80.0), with: nil))
    }

    func test_titleView_isHostedAboveTheRow() {
        let node = self.makeNode()
        let item = UINavigationItem(title: "")
        let titleView = UIView()
        item.titleView = titleView
        node.item = item
        node.passthroughTouches = false
        self.layout(node)
        XCTAssertTrue(node.titleView === titleView)
        XCTAssertFalse(titleView.frame.isEmpty)
        XCTAssertTrue(node.hitTest(CGPoint(x: titleView.frame.midX, y: titleView.frame.midY), with: nil) === titleView)
    }

    func test_expansionContentNode_addsItsHeight() {
        let node = self.makeNode()
        node.setContentNode(ExpansionContentNode(), animated: false)
        XCTAssertEqual(node.contentHeight(defaultHeight: 60.0), 110.0)
    }

    func test_backInColumn_onlyWithAPlacement() {
        let node = self.makeNode()
        node.item = UINavigationItem(title: "Chat")
        node.previousItem = .item(UINavigationItem())
        self.layout(node)
        XCTAssertFalse(node.isBackInSideColumn)
    }

    // ComposePoll, ComposeTodo and the article editor put their own top buttons over the bar.
    func test_overBackgroundControl_takesTouchesUnderTheRow() {
        let node = self.makeNode()
        let item = UINavigationItem(title: "Poll")
        item.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        node.item = item
        node.previousItem = .close
        let control = UIButton(frame: CGRect(x: 16.0, y: 60.0, width: 60.0, height: 36.0))
        node.customOverBackgroundContentView.addSubview(control)
        self.layout(node)
        XCTAssertTrue(node.hitTest(CGPoint(x: control.frame.midX, y: control.frame.midY), with: nil) === control)
    }

    // An empty left item hides the back button (editing modes); Escape must not pop the screen through it.
    func test_executeBack_withAnEmptyLeftItem_doesNotGoBack() {
        let node = self.makeNode()
        var pressed = 0
        node.backPressed = {
            pressed += 1
        }
        let item = UINavigationItem(title: "Edit")
        item.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        node.item = item
        node.previousItem = .item(UINavigationItem())
        let _ = node.executeBack()
        XCTAssertEqual(pressed, 0)
    }

    func test_executeBack_runsTheLeftItemsAction() {
        let node = self.makeNode()
        var pressed = 0
        node.backPressed = {
            pressed += 1
        }
        let target = ActionCounter()
        let item = UINavigationItem(title: "Edit")
        item.leftBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: target, action: #selector(ActionCounter.fire))
        node.item = item
        node.previousItem = .item(UINavigationItem())
        let _ = node.executeBack()
        XCTAssertEqual(target.count, 1)
        XCTAssertEqual(pressed, 0)
    }

    // An active search (a replacement content node) hides the iPhone Duo column's buttons with the row.
    func test_replacementContentNode_hidesTheSideColumnButtons() {
        let node = self.makeNode()
        node.item = UINavigationItem(title: "Log")
        self.layout(node)
        XCTAssertFalse(node.currentHidesSideColumnButtons)
        node.setContentNode(ReplacementContentNode(), animated: false)
        XCTAssertTrue(node.currentHidesSideColumnButtons)
        node.setContentNode(nil, animated: false)
        node.layout()
        XCTAssertFalse(node.currentHidesSideColumnButtons)
    }

    // iPhone Duo, folded portrait (SideColumnRegionTests' cover portrait): the strip is on the right, below a 170pt block.
    private func duoLayout(formSheet: Bool = false) -> ContainerViewLayout {
        return ContainerViewLayout(size: CGSize(width: 466.0, height: 678.0), metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil), division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: formSheet)
    }

    private func duoItem() -> UINavigationItem {
        let item = UINavigationItem(title: "Chat")
        item.rightBarButtonItem = UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)
        return item
    }

    func test_sideColumnExtent_isTheColumnsShapesInTheScreen() {
        let node = self.makeNode()
        node.item = self.duoItem()
        node.previousItem = .item(UINavigationItem())
        let extent = node.sideColumnExtent(placement: NavigationBarSideColumnPlacement(layout: self.duoLayout(), reservedBelow: nil))
        XCTAssertEqual(extent?.edge, .right)
        // The region starts 8pt below the corner block (SideColumnRegionTests: x 396, y 178).
        XCTAssertEqual(extent?.frame.minX, 396.0)
        XCTAssertEqual(extent?.frame.minY, 178.0)
        XCTAssertEqual(extent?.frame.width, 48.0)
        let content = node.currentContentForTesting()
        let columnFrame = NavigationBarComponent.sideColumnContentFrame(content: content, columnLength: 478.0)
        XCTAssertEqual(extent?.frame, columnFrame?.offsetBy(dx: 396.0, dy: 178.0))
    }

    func test_sideColumnExtent_isNilInAFormSheet() {
        let node = self.makeNode()
        node.item = self.duoItem()
        node.previousItem = .item(UINavigationItem())
        XCTAssertNil(node.sideColumnExtent(placement: NavigationBarSideColumnPlacement(layout: self.duoLayout(formSheet: true), reservedBelow: nil)))
    }

    // An item change outside a layout pass that moves the column asks the screen to lay out again; a layout pass does not.
    func test_itemChange_reportsAMovedColumn() {
        let node = self.makeNode()
        let item = UINavigationItem(title: "Chat")
        node.item = item
        node.previousItem = .item(UINavigationItem())
        var reports = 0
        node.sideColumnExtentUpdated = { _ in
            reports += 1
        }
        node.sideColumnPlacement = NavigationBarSideColumnPlacement(layout: self.duoLayout(), reservedBelow: nil)
        node.frame = CGRect(x: 0.0, y: 0.0, width: 466.0, height: 60.0)
        node.updateLayout(size: CGSize(width: 466.0, height: 60.0), defaultHeight: 60.0, additionalTopHeight: 0.0, additionalContentHeight: 0.0, additionalBackgroundHeight: 0.0, leftInset: 0.0, rightInset: 84.0, appearsHidden: false, transition: .immediate)
        XCTAssertEqual(reports, 0)
        item.setRightBarButton(UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil), animated: false)
        node.layout()
        XCTAssertEqual(reports, 1)
        node.updateLayout(size: CGSize(width: 466.0, height: 60.0), defaultHeight: 60.0, additionalTopHeight: 0.0, additionalContentHeight: 0.0, additionalBackgroundHeight: 0.0, leftInset: 0.0, rightInset: 84.0, appearsHidden: false, transition: .immediate)
        XCTAssertEqual(reports, 1)
    }

    func test_setBackdropAlpha_fadesTheEdgeEffect() {
        let node = self.makeNode()
        node.item = UINavigationItem(title: "Languages")
        self.layout(node)
        XCTAssertTrue(node.isBackdropVisible)
        node.setBackdropAlpha(0.0, transition: .immediate)
        XCTAssertFalse(node.isBackdropVisible)
        XCTAssertEqual(node.edgeEffectViewImpl.alpha, 0.0)
        node.setBackdropAlpha(1.5, transition: .immediate)
        XCTAssertTrue(node.isBackdropVisible)
        XCTAssertEqual(node.edgeEffectViewImpl.alpha, 1.0)
    }

    func test_takeView_handsOverTheContent_andAgainNotWhileLifted() {
        let node = self.makeNode()
        node.item = UINavigationItem(title: "Settings")
        self.layout(node)
        let info = node.takeView()
        XCTAssertTrue(info?.containingView === node.view)
        XCTAssertTrue(info?.contentView === node.contentView)
        XCTAssertNil(node.takeView())
        node.putBack()
        XCTAssertTrue(node.contentView.superview === node.view)
    }

    func test_optedOutBar_takesNoPart() {
        let node = self.makeNode()
        node.intrinsicCanTransitionInline = false
        XCTAssertNil(node.takeView())
    }

    // In a role the renderer draws the glass (capsules, column) and the backdrop above both screens. The bar keeps
    // everything else, its title included, at full opacity with no drift: the lifted content rides its screen (UIKit's
    // matching views).
    func test_role_detachesTheGlass_andKeepsTheContent() {
        let node = self.makeNode()
        let item = UINavigationItem(title: "Settings")
        let titleView = UIView()
        item.titleView = titleView
        item.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)
        node.item = item
        node.previousItem = .item(UINavigationItem())
        self.layout(node)
        let _ = node.takeView()
        node.updateTransition(role: .bottom, fraction: 0.5, transition: .immediate)
        XCTAssertEqual(node.transitionBackdropHostAlpha, 0.0)
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, true)
        XCTAssertEqual(node.transitionRowHostAlpha, 1.0)
        XCTAssertEqual(node.transitionExtrasAlpha, 1.0)
        XCTAssertEqual(titleView.superview?.bounds.minX ?? -1.0, 0.0)
        node.updateTransition(role: nil, fraction: 0.0, transition: .immediate)
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, false)
        XCTAssertEqual(node.transitionBackdropHostAlpha, 1.0)
        node.putBack()
    }

    // After a transition whose glass is still animating above the bar, the bar keeps its own capsules out through
    // putting the content back, until the glass hands over.
    func test_heldGlass_keepsTheCapsulesOutUntilHandedOver() {
        let node = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        let _ = node.takeView()
        node.updateTransition(role: .top, fraction: 1.0, transition: .immediate)
        XCTAssertTrue(node.holdGlass(true, interrupted: nil))
        node.putBack()
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, true)
        XCTAssertEqual(node.transitionBackdropHostAlpha, 1.0)
        let _ = node.holdGlass(false, interrupted: nil)
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, false)
    }

    // A touch on the bar, or its content changing, makes the glass hand over at once; a layout that changes nothing
    // does not.
    func test_heldGlass_handsOverOnATouchOrAChange() {
        let node = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        var interruptions = 0
        let _ = node.holdGlass(true, interrupted: {
            interruptions += 1
        })
        self.layout(node)
        XCTAssertEqual(interruptions, 0)
        let _ = node.hitTest(CGPoint(x: 360.0, y: 70.0), with: nil)
        let _ = node.hitTest(CGPoint(x: 360.0, y: 70.0), with: nil)
        XCTAssertEqual(interruptions, 1, "once per hold")
        let _ = node.holdGlass(true, interrupted: {
            interruptions += 1
        })
        node.item?.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: nil, action: nil)
        self.layout(node)
        XCTAssertEqual(interruptions, 2)
    }

    // A touch elsewhere on the screen (scrolling the list the swipe landed on) leaves the glass to finish: on iOS touching
    // content does not cut the capsules' settle. UIKit asks the bar first about every touch on the screen, since it is
    // the screen's topmost subnode, so the bar checks the point itself (code review, 2026-10-14).
    func test_heldGlass_aTouchOutsideTheBarDoesNotHandOver() {
        let node = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        var interruptions = 0
        let _ = node.holdGlass(true, interrupted: {
            interruptions += 1
        })
        XCTAssertNil(node.hitTest(CGPoint(x: 200.0, y: 500.0), with: nil))
        XCTAssertEqual(interruptions, 0)
        let _ = node.hitTest(CGPoint(x: 360.0, y: 70.0), with: nil)
        XCTAssertEqual(interruptions, 1)
    }

    // While the transition's glass lingers above the bar it draws the iPhone Duo column's capsules too, so the bar's own
    // column stays hidden until the hold ends, as its row capsules do.
    func test_heldGlass_keepsTheColumnHidden() {
        let node = self.makeLaidOutNode(title: "Info")
        node.updateTransition(role: .top, fraction: 1.0, transition: .immediate)
        let _ = node.holdGlass(true, interrupted: {})
        node.updateTransition(role: nil, fraction: 0.0, transition: .immediate)
        XCTAssertEqual(node.columnHostAlphaForTesting, 0.0)
        let _ = node.holdGlass(false, interrupted: nil)
        XCTAssertEqual(node.columnHostAlphaForTesting, 1.0)
    }

    // A hold whose transition went away without releasing it (its navigation container replaced mid-linger, e.g. on an
    // iPad resize across the compact/regular boundary) must not leave the bar without its capsules: the bar releases it
    // itself on a touch, and in any case after a cap (code review, 2026-10-14).
    func test_heldGlass_aHoldNobodyReleases_endsOnATouch() {
        let node = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        let _ = node.holdGlass(true, interrupted: {})
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, true)
        let _ = node.hitTest(CGPoint(x: 360.0, y: 70.0), with: nil)
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, false)
    }

    // The glass runs on stretched time under Slow Animations, so the hold's cap stretches with it.
    func test_heldGlass_capFollowsSlowAnimations() {
        let node = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        node.glassHoldDurationFactor = { 0.5 }
        let _ = node.holdGlass(true, interrupted: {})
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, false, "1.6 s × 0.5")
    }

    func test_heldGlass_aHoldNobodyReleases_endsAfterTheCap() {
        let node = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        let _ = node.holdGlass(true, interrupted: {})
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, true, "the transition's own cap (1.5 s) comes first")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, false)
    }

    // The bar leaving the screen without a stack change (another tab selected while the glass lingers above the chat
    // list) hands over, or the glass would go on drawing the old tab's capsules over the new tab's bar.
    func test_heldGlass_leavingTheWindow_handsOver() {
        // What ASDK's hierarchy callbacks call is called directly: ASDK forbids calling them, and any UIWindow in this test
        // process creates a window scene whose invalidation later traps.
        let node = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        var interruptions = 0
        let _ = node.holdGlass(true, interrupted: { [weak node] in
            interruptions += 1
            let _ = node?.holdGlass(false, interrupted: nil)
        })
        node.leftHierarchy()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(interruptions, 1)
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, false)
    }

    // Leaving and re-entering in the same turn (a finished swipe re-adds the screen beneath) is not leaving.
    func test_heldGlass_reenteringTheWindowAtOnce_keepsTheHold() {
        let node = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        var interruptions = 0
        let _ = node.holdGlass(true, interrupted: {
            interruptions += 1
        })
        node.leftHierarchy()
        node.enteredHierarchy()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(interruptions, 0)
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, true)
        let _ = node.holdGlass(false, interrupted: nil)
    }

    // The renderer's glass reports that it is still animating after a push begins, and that it settled.
    func test_renderer_reportsItsGlassAnimatingAndSettled() {
        let bottom = self.makeLaidOutNode(title: "Chats")
        let top = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return
        }
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: 0.0, bottomFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), topFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), transition: .immediate)
        renderer.beginTransition(isInteractive: false, toTop: true)
        XCTAssertTrue(renderer.isGlassAnimating)
        var settled = 0
        renderer.glassSettled = {
            settled += 1
        }
        for _ in 0 ..< 480 {
            self.time.advance(by: 1.0 / 120.0)
        }
        XCTAssertFalse(renderer.isGlassAnimating)
        XCTAssertEqual(settled, 1)
    }

    func test_layoutWhileLifted_reportsTheFrame_andPutBackRestores() {
        let node = self.makeNode()
        node.item = UINavigationItem(title: "Chat")
        self.layout(node)
        let _ = node.takeView()
        var reported: CGRect?
        node.transitionContentFrameUpdated = { frame in
            reported = frame
        }
        node.frame = CGRect(x: 0.0, y: 0.0, width: 844.0, height: 80.0)
        node.updateLayout(size: CGSize(width: 844.0, height: 80.0), defaultHeight: 44.0, additionalTopHeight: 0.0, additionalContentHeight: 0.0, additionalBackgroundHeight: 0.0, leftInset: 0.0, rightInset: 0.0, appearsHidden: false, transition: .immediate)
        XCTAssertEqual(reported, CGRect(x: 0.0, y: 0.0, width: 844.0, height: 80.0))
        node.putBack()
        XCTAssertEqual(node.contentView.frame, CGRect(x: 0.0, y: 0.0, width: 844.0, height: 80.0))
    }

    func test_componentTransitionState_describesTheBar() {
        let node = self.makeNode()
        let item = UINavigationItem(title: "Settings")
        node.item = item
        node.previousItem = .item(UINavigationItem())
        self.layout(node)
        let state = node.componentTransitionState
        XCTAssertEqual(state?.content.title, .text("Settings"))
        XCTAssertEqual(state?.content.back, .back)
        XCTAssertEqual(state?.backdropHeight, 107.0)
        XCTAssertEqual(state?.rowFrame.height, 44.0)
    }

    // A regular screen whose right items are the Done checkmark beside another item gives the checkmark a pill of its own
    // (UIKit gives the prominent item its own section). The items [Done, Edit] are drawn Done leftmost, so Edit is the
    // outermost pill and Done the one inside it.
    func test_doneBesideAnotherItem_isAPillOfItsOwn() {
        let node = self.makeNode()
        let item = UINavigationItem(title: "Info")
        item.rightBarButtonItems = [UIBarButtonItem(title: "___done", style: .done, target: nil, action: nil), UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)]
        node.item = item
        node.previousItem = .item(UINavigationItem())
        self.layout(node)
        XCTAssertNotNil(node.rowViewForTesting?.rightPillBackgroundContainer(at: 1))
        XCTAssertEqual(node.rowViewForTesting?.rightPillBackgroundContainer(at: 1)?.frame.width, 44.0)
    }

    // ItemListController's right items are [secondary, primary] (search, Edit): the bar draws them as two pills, Edit
    // outermost, as UIKit does.
    func test_itemListPair_searchAndEdit_areTwoPills() {
        let node = self.makeNode()
        let item = UINavigationItem(title: "Administrators")
        item.rightBarButtonItems = [UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil), UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)]
        node.item = item
        node.previousItem = .item(UINavigationItem())
        self.layout(node)
        guard let rowView = node.rowViewForTesting, let edit = rowView.rightPillBackgroundContainer(at: 0), let search = rowView.rightPillBackgroundContainer(at: 1) else {
            XCTFail("not two pills")
            return
        }
        XCTAssertGreaterThan(edit.frame.minX, search.frame.maxX)
        XCTAssertEqual(edit.frame.minX - search.frame.maxX, 12.0)
    }

    private func makeLaidOutNode(title: String, rightItem: UIBarButtonItem? = nil) -> NavigationBarNode {
        let node = self.makeNode()
        let item = UINavigationItem(title: title)
        item.rightBarButtonItem = rightItem
        node.item = item
        node.previousItem = .item(UINavigationItem())
        self.layout(node)
        return node
    }

    // The shared edge effect is laid out once at the taller bar's height and only moved, so that its bottom edge is
    // where it was at every sample; its colour and alpha are keyframes too.
    func test_renderer_bakesTheEdgeEffect_atTheTallerHeight() {
        let bottom = self.makeLaidOutNode(title: "Chats")
        let top = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        top.frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 167.0)
        top.updateLayout(size: CGSize(width: 390.0, height: 167.0), defaultHeight: 60.0, additionalTopHeight: 47.0, additionalContentHeight: 0.0, additionalBackgroundHeight: 0.0, leftInset: 0.0, rightInset: 0.0, appearsHidden: false, transition: .immediate)
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return
        }
        let timing = NavigationKeyframeTiming(origin: .atCommit, duration: 0.2, factor: 1.0)
        let timeline = NavigationTransitionTimeline(timing: timing, fractions: timing.sampleTimes.map { CGFloat($0 / 0.2) }, topFrames: timing.sampleTimes.map { _ in CGRect() }, bottomFrames: timing.sampleTimes.map { _ in CGRect() }, animationTime: { 0.0 }, reinstallTiming: { timing }, schedule: { _, _ in })
        renderer.animate(size: CGSize(width: 390.0, height: 844.0), timeline: timeline, bottomFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), topFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 167.0))
        let edge = renderer.edgeEffectViewForTesting
        guard let position = edge.layer.animation(forKey: "navigationBarTransition.position") as? CAKeyframeAnimation else {
            XCTFail("no edge keyframes")
            return
        }
        XCTAssertEqual(edge.bounds.height, 20.0 + max(bottom.componentTransitionState?.backdropHeight ?? 0.0, top.componentTransitionState?.backdropHeight ?? 0.0) + 24.0, accuracy: 0.5)
        XCTAssertEqual(position.values?.count, timing.sampleTimes.count)
        // Its bottom edge is where today's per-fraction frame puts it, at the first and the last sample.
        guard let bottomState = bottom.componentTransitionState, let topState = top.componentTransitionState else {
            XCTFail("no states")
            return
        }
        for (index, fraction) in [(0, CGFloat(0.0)), (timing.sampleTimes.count - 1, CGFloat(1.0))] {
            let today = navigationBarTransitionBackdropFrame(fraction: fraction, bottomTop: 0.0, topTop: 0.0, bottomHeight: bottomState.backdropHeight, topHeight: topState.backdropHeight, bottomExtension: bottomState.backdropExtension, topExtension: topState.backdropExtension, width: 390.0, layoutHeight: bottomState.backdropHeight * (1.0 - fraction) + topState.backdropHeight * fraction)
            let center = (position.values?[index] as? NSValue)?.cgPointValue ?? CGPoint()
            XCTAssertEqual(center.y + edge.bounds.height * 0.5, today.maxY, accuracy: 0.01)
        }
    }

    // The header's tint (0.85) and the chat bar's (0.75) meet along the progress, per frame and baked.
    func test_renderer_interpolatesTheBackdropTint() {
        let bottom = FakeComponentSource(backdropHeight: 200.0, backdropAlpha: 1.0, tintAlpha: 0.85, edgeLength: 54.0)
        let top = FakeComponentSource(backdropHeight: 107.0, backdropAlpha: 1.0, tintAlpha: 0.75, edgeLength: 64.0)
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return
        }
        let barFrame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0)
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: 0.5, bottomFrame: barFrame, topFrame: barFrame, transition: .immediate)
        XCTAssertEqual(CGFloat(renderer.edgeEffectViewForTesting.colorLayer.opacity), 0.8, accuracy: 1e-4)
        let timing = NavigationKeyframeTiming(origin: .atCommit, duration: 0.2, factor: 1.0)
        let fractions = timing.sampleTimes.map { CGFloat($0 / 0.2) }
        let timeline = NavigationTransitionTimeline(timing: timing, fractions: fractions, topFrames: fractions.map { _ in barFrame }, bottomFrames: fractions.map { _ in barFrame }, animationTime: { 0.0 }, reinstallTiming: { timing }, schedule: { _, _ in })
        renderer.animate(size: CGSize(width: 390.0, height: 844.0), timeline: timeline, bottomFrame: barFrame, topFrame: barFrame)
        guard let tint = renderer.edgeEffectViewForTesting.colorLayer.animation(forKey: "navigationBarTransition.tintOpacity") as? CAKeyframeAnimation else {
            XCTFail("no tint keyframes")
            return
        }
        let values = tint.values?.compactMap { ($0 as? NSNumber)?.floatValue } ?? []
        XCTAssertEqual(values.first ?? 0.0, 0.85, accuracy: 1e-4)
        XCTAssertEqual(values.last ?? 0.0, 0.75, accuracy: 1e-4)
    }

    // The edge's length is a mask image, which can only switch: one length for the whole transition, the one of the
    // backdrop that shows more (the header's, over a chat whose backdrop is transparent); a tie takes the taller one's.
    func test_backdropEdgeLength_comesFromTheBackdropThatShowsMore() {
        let header = FakeComponentSource(backdropHeight: 200.0, backdropAlpha: 1.0, tintAlpha: 0.85, edgeLength: 54.0)
        let transparentChat = FakeComponentSource(backdropHeight: 107.0, backdropAlpha: 0.0, tintAlpha: 0.75, edgeLength: 64.0)
        let opaqueBar = FakeComponentSource(backdropHeight: 107.0, backdropAlpha: 1.0, tintAlpha: 0.75, edgeLength: 64.0)
        func length(_ bottom: FakeComponentSource, _ top: FakeComponentSource) -> CGFloat {
            return navigationBarTransitionBackdropEdgeLength(bottom: bottom.componentTransitionState!, top: top.componentTransitionState!)
        }
        XCTAssertEqual(length(header, transparentChat), 54.0)
        XCTAssertEqual(length(transparentChat, header), 54.0)
        XCTAssertEqual(length(header, opaqueBar), 54.0)
        XCTAssertEqual(length(opaqueBar, header), 54.0)
    }

    func test_renderer_interpolatesTheBackdrop() {
        let bottom = self.makeLaidOutNode(title: "Settings")
        let top = self.makeLaidOutNode(title: "Privacy")
        top.frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 167.0)
        top.updateLayout(size: CGSize(width: 390.0, height: 167.0), defaultHeight: 60.0, additionalTopHeight: 47.0, additionalContentHeight: 0.0, additionalBackgroundHeight: 0.0, leftInset: 0.0, rightInset: 0.0, appearsHidden: false, transition: .immediate)
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return
        }
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: 0.5, bottomFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), topFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 167.0), transition: .immediate)
        XCTAssertEqual(renderer.currentBackdropHeight, 137.0, accuracy: 0.001)
        XCTAssertEqual(renderer.currentFraction, 0.5)
    }

    private func rendererBackdropAlpha(bottom: NavigationBarNode, top: NavigationBarNode, fraction: CGFloat) -> CGFloat? {
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return nil
        }
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: fraction, bottomFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), topFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), transition: .immediate)
        return renderer.currentBackdropAlpha
    }

    // When one bar's backdrop is transparent and the other's is not, UIKit fades it in a keyframe rather than along the
    // whole transition: going transparent during the first 0.3 of the progress, going opaque during the last 0.3
    // (`_UIBarsTwoPartCrossfadeTransitionProgress`, bar RE §6). In fraction terms the fade sits next to the opaque bar
    // whichever way the transition runs, so a push and a pop (and a scrubbed pop) agree.
    func test_renderer_fadesATransparencyChangeNextToTheOpaqueBar() {
        let opaque = self.makeLaidOutNode(title: "Settings")
        let transparent = self.makeLaidOutNode(title: "Profile")
        transparent.setBackdropAlpha(0.0, transition: .immediate)

        // Opaque below, transparent on top: the backdrop is gone by 0.3.
        XCTAssertEqual(self.rendererBackdropAlpha(bottom: opaque, top: transparent, fraction: 0.0) ?? -1.0, 1.0, accuracy: 0.001)
        XCTAssertEqual(self.rendererBackdropAlpha(bottom: opaque, top: transparent, fraction: 0.15) ?? -1.0, 0.5, accuracy: 0.001)
        XCTAssertEqual(self.rendererBackdropAlpha(bottom: opaque, top: transparent, fraction: 0.3) ?? -1.0, 0.0, accuracy: 0.001)
        XCTAssertEqual(self.rendererBackdropAlpha(bottom: opaque, top: transparent, fraction: 0.7) ?? -1.0, 0.0, accuracy: 0.001)

        // Transparent below, opaque on top: the backdrop comes in from 0.7.
        XCTAssertEqual(self.rendererBackdropAlpha(bottom: transparent, top: opaque, fraction: 0.5) ?? -1.0, 0.0, accuracy: 0.001)
        XCTAssertEqual(self.rendererBackdropAlpha(bottom: transparent, top: opaque, fraction: 0.7) ?? -1.0, 0.0, accuracy: 0.001)
        XCTAssertEqual(self.rendererBackdropAlpha(bottom: transparent, top: opaque, fraction: 0.85) ?? -1.0, 0.5, accuracy: 0.001)
        XCTAssertEqual(self.rendererBackdropAlpha(bottom: transparent, top: opaque, fraction: 1.0) ?? -1.0, 1.0, accuracy: 0.001)
    }

    // Two backdrops on the same side of UIKit's 0.3 threshold cross-fade along the whole transition.
    func test_renderer_crossFadesBackdropsOfTheSameKindAlongTheTransition() {
        let full = self.makeLaidOutNode(title: "Settings")
        let half = self.makeLaidOutNode(title: "Privacy")
        half.setBackdropAlpha(0.5, transition: .immediate)
        XCTAssertEqual(self.rendererBackdropAlpha(bottom: full, top: half, fraction: 0.5) ?? -1.0, 0.75, accuracy: 0.001)

        let clear = self.makeLaidOutNode(title: "Profile")
        clear.setBackdropAlpha(0.0, transition: .immediate)
        let faint = self.makeLaidOutNode(title: "Media")
        faint.setBackdropAlpha(0.2, transition: .immediate)
        XCTAssertEqual(self.rendererBackdropAlpha(bottom: clear, top: faint, fraction: 0.5) ?? -1.0, 0.1, accuracy: 0.001)
    }

    private func rendererBackdrop(bottom: FakeComponentSource, top: FakeComponentSource, fraction: CGFloat) -> (alpha: CGFloat, height: CGFloat)? {
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return nil
        }
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: fraction, bottomFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 200.0), topFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), transition: .immediate)
        return (renderer.currentBackdropAlpha, renderer.currentBackdropHeight)
    }

    // The user's correction (2026-10-15): the chat-list header's edge effect stays while it pushes to or pops from a
    // chat (whose bar shows no backdrop). The header keeps it on its own screen, riding it under the arriving chat, and
    // the transition draws none of it, where UIKit's rule would fade it out next to the chat.
    func test_aBackdropOnlyTheHeaderShows_staysOnItsScreen() {
        for fraction: CGFloat in [0.0, 0.15, 0.5, 1.0] {
            let header = FakeComponentSource(backdropHeight: 200.0, backdropAlpha: 1.0, tintAlpha: 0.85, edgeLength: 54.0, keepsLoneBackdrop: true)
            let chat = FakeComponentSource(backdropHeight: 107.0, backdropAlpha: 0.0, tintAlpha: 0.75, edgeLength: 64.0)
            XCTAssertEqual(self.rendererBackdrop(bottom: header, top: chat, fraction: fraction)?.alpha ?? -1.0, 0.0, accuracy: 0.001, "push at \(fraction)")
            XCTAssertEqual(header.keepsOwnBackdrop, true)
            XCTAssertEqual(chat.keepsOwnBackdrop, false)
            XCTAssertEqual(self.rendererBackdrop(bottom: chat, top: header, fraction: fraction)?.alpha ?? -1.0, 0.0, accuracy: 0.001, "pop at \(fraction)")
        }
    }

    // With the header's backdrop left to it, the transition draws only the other bar's: a faint one fades in at its own
    // height rather than moving from the header's.
    func test_aBackdropTheHeaderKeeps_leavesTheTransitionTheOtherBars() {
        let header = FakeComponentSource(backdropHeight: 200.0, backdropAlpha: 1.0, tintAlpha: 0.85, edgeLength: 54.0, keepsLoneBackdrop: true)
        let faint = FakeComponentSource(backdropHeight: 107.0, backdropAlpha: 0.2, tintAlpha: 0.75, edgeLength: 64.0)
        let backdrop = self.rendererBackdrop(bottom: header, top: faint, fraction: 0.5)
        XCTAssertEqual(backdrop?.alpha ?? -1.0, 0.1, accuracy: 0.001)
        XCTAssertEqual(backdrop?.height ?? -1.0, 107.0, accuracy: 0.001)
    }

    // Where the other bar shows a backdrop too (Chats -> Archived), the transition draws one between them as before.
    func test_aBackdropBothBarsShow_isDrawnByTheTransition() {
        let header = FakeComponentSource(backdropHeight: 200.0, backdropAlpha: 1.0, tintAlpha: 0.85, edgeLength: 54.0, keepsLoneBackdrop: true)
        let archived = FakeComponentSource(backdropHeight: 150.0, backdropAlpha: 1.0, tintAlpha: 0.85, edgeLength: 54.0, keepsLoneBackdrop: true)
        let backdrop = self.rendererBackdrop(bottom: header, top: archived, fraction: 0.5)
        XCTAssertEqual(backdrop?.alpha ?? -1.0, 1.0, accuracy: 0.001)
        XCTAssertEqual(backdrop?.height ?? -1.0, 175.0, accuracy: 0.001)
        XCTAssertEqual(header.keepsOwnBackdrop, false)
        XCTAssertEqual(archived.keepsOwnBackdrop, false)
    }

    func test_renderer_needsTwoComponentSources() {
        final class Other: NavigationBarTransitionSource {
            var transitionContentFrameUpdated: ((CGRect) -> Void)?
            func takeView() -> NavigationBarTransitionTakeViewInfo? { return nil }
            func putBack() {}
            func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition) {}
        }
        XCTAssertNil(makeNavigationBarTransitionRenderer(bottom: self.makeLaidOutNode(title: "A"), top: Other()))
    }

    // An active search (a replacement content node) hides the bar's row, so its capsules are not on screen: the bar
    // contributes none, and the other bar's capsules materialize in place on a push (and dematerialize in place on a
    // pop), as UIKit's capsules without a counterpart do. The capsules are never faded as a whole: their view is the
    // glass's ancestor, and pushing a chat from Chats' search with that view starting transparent, the chat's glass was
    // not drawn through the push and the linger after it, while on the pop its capsules flew up to the hidden row.
    private func hiddenRowRenderer() -> (renderer: NavigationBarTransitionRendererImpl, size: CGSize, frame: CGRect)? {
        let bottom = self.makeLaidOutNode(title: "Contacts", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        bottom.setContentNode(ReplacementContentNode(), animated: false)
        let top = self.makeLaidOutNode(title: "Chat", rightItem: UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil))
        XCTAssertEqual(bottom.componentTransitionState?.rowAlpha, 0.0)
        XCTAssertEqual(top.componentTransitionState?.rowAlpha, 1.0)
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return nil
        }
        let size = CGSize(width: 390.0, height: 844.0)
        let frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0)
        renderer.update(size: size, fraction: 0.0, bottomFrame: frame, topFrame: frame, transition: .immediate)
        return (renderer, size, frame)
    }

    func test_renderer_aBarWhoseRowIsHidden_contributesNoCapsules_push() {
        guard let (renderer, _, _) = self.hiddenRowRenderer(), let platterView = renderer.platterViewForTesting else {
            return XCTFail("no platter view")
        }
        XCTAssertEqual(platterView.layer.opacity, 1.0)
        renderer.beginTransition(isInteractive: false, toTop: true)
        for role in [NavigationBarPlatterTransitionView.Role.leading, .trailing(0)] {
            let state = platterView.platterStateForTesting(role)
            XCTAssertEqual(state?.opacity ?? 1.0, 0.0, accuracy: 0.001, "\(role) materializes")
            XCTAssertGreaterThan(state?.scale.height ?? 0.0, 1.0, "\(role) materializes in place")
        }
        self.time.advance(by: 1.5)
        XCTAssertEqual(platterView.platterStateForTesting(.leading)?.opacity ?? 0.0, 1.0, accuracy: 0.001)
        XCTAssertEqual(platterView.layer.opacity, 1.0)
    }

    func test_renderer_aBarWhoseRowIsHidden_contributesNoCapsules_pop() {
        guard let (renderer, size, frame) = self.hiddenRowRenderer(), let platterView = renderer.platterViewForTesting else {
            return XCTFail("no platter view")
        }
        renderer.update(size: size, fraction: 1.0, bottomFrame: frame, topFrame: frame, transition: .immediate)
        XCTAssertEqual(platterView.layer.opacity, 1.0)
        renderer.beginTransition(isInteractive: false, toTop: false)
        let start = platterView.platterStateForTesting(.leading)?.frame
        XCTAssertNotNil(start)
        self.time.advance(by: 0.2)
        // In place: the chat's back capsule does not move toward the hidden bar's row, it leaves where it is.
        XCTAssertEqual(platterView.platterStateForTesting(.leading)?.frame, start)
        XCTAssertLessThan(platterView.platterStateForTesting(.leading)?.opacity ?? 1.0, 1.0)
        XCTAssertEqual(platterView.layer.opacity, 1.0)
    }

    private func makePillNode(rightItems: [UIBarButtonItem]) -> (NavigationBarNode, PillTitleView) {
        let node = self.makeNode()
        let item = UINavigationItem(title: "")
        let titleView = PillTitleView()
        item.titleView = titleView
        item.rightBarButtonItems = rightItems
        node.item = item
        node.previousItem = .item(UINavigationItem())
        self.layout(node)
        return (node, titleView)
    }

    // A title on a glass pill (the chat header) is reported as the bar's second right platter, and hidden while a
    // transition, or the glass lingering after one, draws it (asked 2026-10-15).
    func test_glassPillTitle_isReported_andHiddenWhileTheTransitionDrawsIt() {
        let (node, titleView) = self.makePillNode(rightItems: [UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)])
        let pill = node.componentTransitionState?.titlePill
        XCTAssertEqual(pill?.frame, titleView.pillFrame.offsetBy(dx: titleView.frame.minX, dy: titleView.frame.minY))
        XCTAssertFalse(titleView.isGlassPillDetached)
        node.updateTransition(role: .top, fraction: 0.0, transition: .immediate)
        XCTAssertTrue(titleView.isGlassPillDetached)
        node.updateTransition(role: nil, fraction: 0.0, transition: .immediate)
        XCTAssertFalse(titleView.isGlassPillDetached)
        let _ = node.holdGlass(true, interrupted: nil)
        XCTAssertTrue(titleView.isGlassPillDetached)
        let _ = node.holdGlass(false, interrupted: nil)
        XCTAssertFalse(titleView.isGlassPillDetached)
    }

    // The pill's contents are the title view's own, lent live while the transition draws the pill (a still copy froze the
    // chat title's animated emoji status), the same view throughout, and given back when the transition ends.
    func test_glassPillTitle_contentsAreLentLive() {
        let (node, titleView) = self.makePillNode(rightItems: [UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)])
        node.updateTransition(role: .top, fraction: 0.0, transition: .immediate)
        let pill = node.componentTransitionState?.titlePill
        let content = pill?.lendContent()
        XCTAssertNotNil(titleView.lentContent)
        XCTAssertTrue(content === titleView.lentContent)
        XCTAssertTrue(pill?.lendContent() === content)
        node.updateTransition(role: nil, fraction: 0.0, transition: .immediate)
        XCTAssertFalse(titleView.isGlassPillDetached)
        XCTAssertNil(titleView.lentContent)
    }

    // With two right platters already (an accent circle and a capsule) the pill has no slot: not reported, never hidden.
    func test_glassPillTitle_besideTwoRightPlatters_isNotReported() {
        let (node, titleView) = self.makePillNode(rightItems: [UIBarButtonItem(title: "___done", style: .done, target: nil, action: nil), UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)])
        XCTAssertNil(node.componentTransitionState?.titlePill)
        node.updateTransition(role: .top, fraction: 0.0, transition: .immediate)
        XCTAssertFalse(titleView.isGlassPillDetached)
    }

    // The renderer hands the pill to the capsules: pushing from a bar with one right capsule, the pill is the arriving
    // bar's second right platter.
    func test_renderer_passesTheTitlePillToTheCapsules() {
        let bottom = self.makeLaidOutNode(title: "List", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        let (top, titleView) = self.makePillNode(rightItems: [UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)])
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            return XCTFail("no renderer")
        }
        let frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0)
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: 0.0, bottomFrame: frame, topFrame: frame, transition: .immediate)
        renderer.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: 1.5)
        XCTAssertEqual(renderer.platterViewForTesting?.platterStateForTesting(.trailing(1))?.frame, titleView.pillFrame.offsetBy(dx: titleView.frame.minX, dy: titleView.frame.minY))
    }

    // The bar reports a layout while lifted only once it has finished it, so the renderer reads the new row, not the
    // previous one.
    func test_layoutWhileLifted_reportsAfterTheBarIsLaidOut() {
        let node = self.makeNode()
        node.item = UINavigationItem(title: "Chat")
        self.layout(node)
        let _ = node.takeView()
        var reportedRowWidth: CGFloat?
        node.transitionContentFrameUpdated = { [unowned node] _ in
            reportedRowWidth = node.componentTransitionState?.rowFrame.width
        }
        node.frame = CGRect(x: 0.0, y: 0.0, width: 844.0, height: 80.0)
        node.updateLayout(size: CGSize(width: 844.0, height: 80.0), defaultHeight: 44.0, additionalTopHeight: 0.0, additionalContentHeight: 0.0, additionalBackgroundHeight: 0.0, leftInset: 0.0, rightInset: 0.0, appearsHidden: false, transition: .immediate)
        XCTAssertEqual(reportedRowWidth, 844.0)
        node.putBack()
    }

    // A bar its screen faded out (a full-screen mini app) would come back at full opacity once lifted: it slides.
    func test_fadedOutBar_takesNoPart() {
        let node = self.makeLaidOutNode(title: "Mini App")
        node.alpha = 0.0
        XCTAssertNil(node.takeView())
    }

    // The morph row lays a screen's node out exactly as the bar does (at least 44pt, centred), so nothing jumps when
    // the bar takes over at the end.
    func test_nodeButton_snapshotLaysOutLikeTheNode() {
        let avatar = AvatarLikeNode()
        let bottom = self.makeLaidOutNode(title: "Chat", rightItem: UIBarButtonItem(customDisplayNode: avatar))
        let top = self.makeLaidOutNode(title: "Info")
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return
        }
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: 0.0, bottomFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), topFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), transition: .immediate)
        renderer.beginTransition(isInteractive: false, toTop: true)
        XCTAssertEqual(bottom.rowViewForTesting?.primaryRightButtonsWidth ?? 0.0, 44.0)
        XCTAssertEqual(renderer.platterViewForTesting?.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, bottom.rowViewForTesting?.primaryRightButtonsWidth ?? -1.0)
    }

    // A tap on Back pops while UIKit is still drawing the back capsule's press: the transition's capsule starts at that
    // press and releases it, rather than the press vanishing when the bar hands its capsules over.
    func test_poppingFromAPressedBack_carriesThePressIntoTheTransition() {
        let bottom = self.makeLaidOutNode(title: "Chats")
        let top = self.makeLaidOutNode(title: "Info")
        guard let capsule = top.rowViewForTesting?.leftButtonsBackgroundContainer, let glass = { () -> UIView? in
            var current: UIView? = capsule.contentView.superview
            while let view = current, view !== capsule, !(view is UIVisualEffectView) {
                current = view.superview
            }
            return current as? UIVisualEffectView
        }() else {
            XCTFail("no back capsule")
            return
        }
        glass.transform = CGAffineTransform(scaleX: 60.0 / 44.0, y: 60.0 / 44.0)
        let pressGlow = CALayer()
        pressGlow.name = "_UIFlexInteraction.BigGlow"
        pressGlow.opacity = 0.8
        glass.layer.addSublayer(pressGlow)
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return
        }
        bottom.updateTransition(role: .bottom, fraction: 1.0, transition: .immediate)
        top.updateTransition(role: .top, fraction: 1.0, transition: .immediate)
        XCTAssertEqual(top.componentTransitionState?.leadingPressScale ?? 0.0, 60.0 / 44.0, accuracy: 0.001)
        XCTAssertEqual((top.componentTransitionState.map { $0.trailingPressScales.first ?? 1.0 } ?? 0.0), 1.0, accuracy: 0.001)
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: 1.0, bottomFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), topFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), transition: .immediate)
        renderer.beginTransition(isInteractive: false, toTop: false)
        XCTAssertEqual(renderer.platterViewForTesting?.platterStateForTesting(.leading)?.press ?? 0.0, 60.0 / 44.0, accuracy: 0.001)
        XCTAssertEqual(top.componentTransitionState?.leadingPressGlow ?? 0.0, 0.8, accuracy: 0.001)
        XCTAssertEqual(renderer.platterViewForTesting?.platterStateForTesting(.leading)?.glow ?? 0.0, 0.8, accuracy: 0.001)
    }

    // A finger dragging a swipe back does not move the capsules (measured on native, 2026-10-14): they stay the top
    // bar's while the screens follow the finger, and switch to the bar the swipe ends on when it is let go.
    func test_swipe_dragDoesNotMoveTheCapsules() {
        let bottom = self.makeLaidOutNode(title: "Chats", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        let top = self.makeLaidOutNode(title: "Info", rightItem: UIBarButtonItem(title: "Select Messages", style: .plain, target: nil, action: nil))
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return
        }
        let size = CGSize(width: 390.0, height: 844.0)
        let barFrame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0)
        bottom.updateTransition(role: .bottom, fraction: 1.0, transition: .immediate)
        top.updateTransition(role: .top, fraction: 1.0, transition: .immediate)
        renderer.update(size: size, fraction: 1.0, bottomFrame: barFrame, topFrame: barFrame, transition: .immediate)
        renderer.beginTransition(isInteractive: true, toTop: false)
        guard let platterView = renderer.platterViewForTesting, let start = platterView.platterStateForTesting(.trailing(0))?.frame else {
            XCTFail("no trailing capsule")
            return
        }
        let bottomWidth = bottom.rowViewForTesting?.primaryRightButtonsWidth ?? 0.0
        XCTAssertGreaterThan(start.width, bottomWidth + 20.0)
        var fraction: CGFloat = 1.0
        while fraction > 0.3 {
            fraction -= 0.05
            renderer.update(size: size, fraction: fraction, bottomFrame: barFrame, topFrame: barFrame, transition: .immediate)
            self.time.advance(by: 1.0 / 30.0)
            XCTAssertEqual(platterView.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, start.width, accuracy: 0.001)
        }
        renderer.endInteraction(towardTop: false)
        for _ in 0 ..< 240 {
            self.time.advance(by: 1.0 / 120.0)
        }
        XCTAssertEqual(platterView.platterStateForTesting(.trailing(0))?.frame.width ?? 0.0, bottomWidth, accuracy: 0.01)
    }

    /// A push from a bar without a right button to one whose right button is a screen's node, begun as the coordinator
    /// begins it.
    private func beginNodeTransition(_ avatar: ASDisplayNode) -> (renderer: NavigationBarTransitionRendererImpl, top: NavigationBarNode)? {
        let bottom = self.makeLaidOutNode(title: "Appearance")
        let top = self.makeLaidOutNode(title: "Chat Themes", rightItem: UIBarButtonItem(customDisplayNode: avatar))
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            return nil
        }
        let barFrame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0)
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: 0.0, bottomFrame: barFrame, topFrame: barFrame, transition: .immediate)
        renderer.beginTransition(isInteractive: false, toTop: true)
        return (renderer, top)
    }

    // The capsules show the screen's own node, not a picture of it: a node that draws only once it is on screen (Chat
    // Themes' animated switch) drew nothing in a snapshot taken while its bar hid its capsules.
    func test_transitionCapsule_hostsTheScreensOwnNode() {
        let avatar = AvatarLikeNode()
        guard let (renderer, top) = self.beginNodeTransition(avatar) else {
            XCTFail("no renderer")
            return
        }
        XCTAssertTrue(avatar.view.isDescendant(of: renderer.rowView))
        XCTAssertFalse(avatar.view.isDescendant(of: top.view))
    }

    // A screen that sets its button again mid-transition (a list screen applies its state) rebuilds the bar's button
    // for the node; the node stays lent to the capsule.
    func test_transitionCapsule_keepsTheNode_whenTheBarRebuildsItsButton() {
        let avatar = AvatarLikeNode()
        guard let (renderer, top) = self.beginNodeTransition(avatar) else {
            XCTFail("no renderer")
            return
        }
        top.item?.rightBarButtonItem = UIBarButtonItem(customDisplayNode: avatar)
        self.layout(top)
        // Before the renderer hears of the change: the bar's new button must not have taken the node.
        XCTAssertTrue(avatar.view.isDescendant(of: renderer.rowView))
        XCTAssertFalse(avatar.view.isDescendant(of: top.view))
        let barFrame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0)
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: 0.5, bottomFrame: barFrame, topFrame: barFrame, transition: .immediate)
        XCTAssertTrue(avatar.view.isDescendant(of: renderer.rowView))
        XCTAssertFalse(avatar.view.isDescendant(of: top.view))
    }

    // When the transition's glass is gone, the node goes back into its bar, where the bar laid it out.
    func test_transitionEnd_returnsTheNodeToItsBar() {
        let avatar = AvatarLikeNode()
        let reference = AvatarLikeNode()
        let referenceBar = self.makeLaidOutNode(title: "Chat Themes", rightItem: UIBarButtonItem(customDisplayNode: reference))
        let frameInBar = reference.frame
        XCTAssertTrue(reference.view.isDescendant(of: referenceBar.view))
        guard let (renderer, top) = self.beginNodeTransition(avatar) else {
            XCTFail("no renderer")
            return
        }
        renderer.end()
        XCTAssertTrue(avatar.view.isDescendant(of: top.view))
        XCTAssertFalse(avatar.view.isDescendant(of: renderer.rowView))
        XCTAssertEqual(avatar.frame, frameInBar)
    }

    // A renderer dropped without being ended (its transition went away) still gives the node back.
    func test_releasedRenderer_returnsTheNodeToItsBar() {
        let avatar = AvatarLikeNode()
        var top: NavigationBarNode?
        weak var weakRenderer: NavigationBarTransitionRendererImpl?
        autoreleasepool {
            guard let (renderer, transitionTop) = self.beginNodeTransition(avatar) else {
                return
            }
            XCTAssertTrue(avatar.view.isDescendant(of: renderer.rowView))
            weakRenderer = renderer
            top = transitionTop
        }
        XCTAssertNil(weakRenderer)
        XCTAssertTrue(top.map { avatar.view.isDescendant(of: $0.view) } ?? false)
    }

    // The glass row draws no titles: each bar's own title rides its screen, as in UIKit.
    func test_renderer_drawsNoTitles() {
        let bottom = self.makeLaidOutNode(title: "Settings")
        let top = self.makeLaidOutNode(title: "Privacy")
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            XCTFail("no renderer")
            return
        }
        renderer.update(size: CGSize(width: 390.0, height: 844.0), fraction: 0.5, bottomFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), topFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0), transition: .immediate)
        renderer.beginTransition(isInteractive: false, toTop: true)
        XCTAssertNotNil(renderer.platterViewForTesting)
        func texts(in view: UIView) -> [String] {
            var result: [String] = []
            if let textView = view as? ImmediateTextView, let text = textView.attributedText?.string, !text.isEmpty, !view.isHidden {
                result.append(text)
            }
            for subview in view.subviews {
                result.append(contentsOf: texts(in: subview))
            }
            return result
        }
        XCTAssertEqual(texts(in: renderer.rowView), [])
    }

    // An animated in-place change of a capsule's items (Edit -> Done) runs iOS 27's capsule animation (morph, item
    // swap, scale pulse, tint cross-fade) on the bar's own capsule, which stays in the hierarchy throughout.
    func test_animatedItemChange_runsTheNativeCapsuleAnimation() {
        let item = UINavigationItem(title: "Text Replacement")
        item.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)
        let node = self.makeNode()
        node.item = item
        node.previousItem = .item(UINavigationItem())
        self.layout(node)
        XCTAssertNil(node.rowViewForTesting?.inPlaceStateForTesting(isLeft: false))
        let capsule = node.rowViewForTesting?.rightPillBackgroundContainer(at: 0)

        item.setRightBarButton(UIBarButtonItem(title: "Done", style: .done, target: nil, action: nil), animated: true)
        node.layout()
        guard let rowView = node.rowViewForTesting, rowView.inPlaceStateForTesting(isLeft: false) != nil else {
            XCTFail("no in-place animation")
            return
        }
        XCTAssertFalse(rowView.plattersDetached)
        XCTAssertTrue(rowView.rightPillBackgroundContainer(at: 0) === capsule)
        XCTAssertTrue(capsule?.superview === rowView)
        rowView.inPlaceTickForTesting(dt: 0.05)
        XCTAssertGreaterThan(rowView.inPlaceStateForTesting(isLeft: false)?.pulse.height ?? 1.0, 1.0)
        for _ in 0 ..< 240 {
            rowView.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
        XCTAssertNil(rowView.inPlaceStateForTesting(isLeft: false))
    }

    // The profile puts its search in the row's place. A row its screen hides stays hidden through the controller's
    // layouts (each calls `setHidden(!displayNavigationBar)`), its Duo column with it, and the bar still takes part
    // in a transition, handing it no capsules.
    func test_rowHiddenByScreen_survivesTheControllersSetHidden() {
        let node = self.makeLaidOutNode(title: "Profile", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        node.setRowHiddenByScreen(true, transition: .immediate)
        node.setHidden(false, animated: false)
        self.layout(node)
        XCTAssertEqual(node.componentTransitionState?.rowAlpha, 0.0)
        XCTAssertEqual(node.columnHostAlphaForTesting, 0.0)
        XCTAssertNotNil(node.takeView())
        node.putBack()
        node.setRowHiddenByScreen(false, transition: .immediate)
        XCTAssertEqual(node.componentTransitionState?.rowAlpha, 1.0)
        XCTAssertEqual(node.columnHostAlphaForTesting, 1.0)
    }

    // A capsule's native glass ignores its ancestors' alpha below the glass container (seen on the profile: a hidden
    // row left its tinted glass on screen under the search field), so a row its screen hides fades the glass
    // container, as a replacement content node does.
    func test_rowHiddenByScreen_hidesTheGlass() {
        let node = self.makeLaidOutNode(title: "Profile", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        node.setRowHiddenByScreen(true, transition: .immediate)
        XCTAssertEqual(node.glassContainerAlphaForTesting, 0.0)
        node.setRowHiddenByScreen(false, transition: .immediate)
        XCTAssertEqual(node.glassContainerAlphaForTesting, 1.0)
    }

    private func glassTheme(_ tint: UIColor?, buttonColor: UIColor = .black) -> NavigationBarPresentationData {
        let theme = NavigationBarTheme(overallDarkAppearance: false, buttonColor: buttonColor, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .lightGray, accentForegroundColor: .white, glassTintColor: tint)
        return NavigationBarPresentationData(theme: theme, strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"))
    }

    // UIKit's glass keeps how it adapted to the backdrop when it joined the bar's container: the profile's Edit, back
    // while the bar was plain over its white header, stayed light over the cover once the bar turned tinted. A change of
    // the bar's glass makes the glass adapt again once its transition is over.
    func test_glassChange_readaptsTheGlass_onceAfterItsTransition() {
        let node = self.makeLaidOutNode(title: "Profile", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        node.updatePresentationData(self.glassTheme(.purple, buttonColor: .white), transition: .animated(duration: 0.2, curve: .easeInOut))
        XCTAssertEqual(node.glassReadaptationCountForTesting, 0)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
        XCTAssertEqual(node.glassReadaptationCountForTesting, 1)
    }

    // The row's request to adapt the glass again (a capsule that appeared in place has settled) reaches the glass.
    func test_rowRequest_readaptsTheGlass() {
        let node = self.makeLaidOutNode(title: "Profile", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        node.rowViewForTesting?.glassNeedsReadaptation?()
        XCTAssertEqual(node.glassReadaptationCountForTesting, 1)
    }

    // A new theme that keeps the glass (a colour of the buttons) leaves the glass as it adapted.
    func test_themeChangeKeepingTheGlass_doesNotReadapt() {
        let node = self.makeLaidOutNode(title: "Profile", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        node.updatePresentationData(self.glassTheme(nil, buttonColor: .blue), transition: .immediate)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        XCTAssertEqual(node.glassReadaptationCountForTesting, 0)
    }

    // Plain and tinted in quick succession (a finger resting at the profile's threshold) adapt once, after the last.
    func test_quickGlassChanges_readaptOnce() {
        let node = self.makeLaidOutNode(title: "Profile", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        node.updatePresentationData(self.glassTheme(.purple, buttonColor: .white), transition: .animated(duration: 0.2, curve: .easeInOut))
        node.updatePresentationData(self.glassTheme(nil), transition: .animated(duration: 0.2, curve: .easeInOut))
        node.updatePresentationData(self.glassTheme(.purple, buttonColor: .white), transition: .animated(duration: 0.2, curve: .easeInOut))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
        XCTAssertEqual(node.glassReadaptationCountForTesting, 1)
    }

    // A replacement content node leaving while the screen still hides the row does not bring the glass back.
    func test_rowHiddenByScreen_outlastsAReplacementContentNode() {
        let node = self.makeLaidOutNode(title: "Profile", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        node.setRowHiddenByScreen(true, transition: .immediate)
        node.setContentNode(ReplacementContentNode(), animated: false)
        node.setContentNode(nil, animated: false)
        XCTAssertEqual(node.glassContainerAlphaForTesting, 0.0)
        node.setRowHiddenByScreen(false, transition: .immediate)
        XCTAssertEqual(node.glassContainerAlphaForTesting, 1.0)
    }

    // The controller hides the bar while a replacement content node holds the row's place: the row is still hidden
    // when the node leaves. The node fades the glass container and `setHidden` the row, so neither overrides the other.
    func test_setHidden_duringAReplacementContentNode_holdsWhenItLeaves() {
        let node = self.makeLaidOutNode(title: "Profile", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        node.setContentNode(ReplacementContentNode(), animated: false)
        node.setHidden(true, animated: false)
        node.setContentNode(nil, animated: false)
        XCTAssertEqual(node.componentTransitionState?.rowAlpha, 0.0)
        node.setHidden(false, animated: false)
        XCTAssertEqual(node.componentTransitionState?.rowAlpha, 1.0)
    }

    // Hidden before the bar has made its row (a profile laid out with its search already open): the row comes up hidden.
    func test_rowHiddenByScreen_beforeTheFirstLayout() {
        let node = self.makeNode()
        let item = UINavigationItem(title: "Profile")
        item.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)
        node.item = item
        node.setRowHiddenByScreen(true, transition: .immediate)
        self.layout(node)
        XCTAssertEqual(node.componentTransitionState?.rowAlpha, 0.0)
    }

    // The controller's own hiding still works, and showing the bar again does not show a row its screen hides.
    func test_setHidden_andRowHiddenByScreen_combine() {
        let node = self.makeLaidOutNode(title: "Profile", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        node.setHidden(true, animated: false)
        XCTAssertEqual(node.componentTransitionState?.rowAlpha, 0.0)
        node.setRowHiddenByScreen(true, transition: .immediate)
        node.setHidden(false, animated: false)
        XCTAssertEqual(node.componentTransitionState?.rowAlpha, 0.0)
        node.setRowHiddenByScreen(false, transition: .immediate)
        XCTAssertEqual(node.componentTransitionState?.rowAlpha, 1.0)
    }

    // A screen finds the view of a bar item it set: the anchor for its tooltip or its camera transition.
    func test_rightButtonView_isTheItemsButton() {
        let edit = UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)
        let node = self.makeLaidOutNode(title: "Profile", rightItem: edit)
        guard let view = node.rightButtonView(for: edit), let capsule = node.rowViewForTesting?.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no button view")
            return
        }
        XCTAssertTrue(view.isDescendant(of: capsule))
        XCTAssertNil(node.rightButtonView(for: UIBarButtonItem(title: "Other", style: .plain, target: nil, action: nil)))
    }

    // The profile's glass over a cover colour reaches the bar's capsules.
    func test_themeGlassTint_reachesTheCapsules() {
        let theme = NavigationBarTheme(overallDarkAppearance: false, buttonColor: .white, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .lightGray, accentForegroundColor: .white, glassTintColor: .orange)
        let node = NavigationBarNode(presentationData: NavigationBarPresentationData(theme: theme, strings: NavigationBarStrings(back: "Back", close: "Close", more: "More")))
        let item = UINavigationItem(title: "Profile")
        item.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)
        node.item = item
        self.layout(node)
        XCTAssertEqual(node.rowViewForTesting?.rightPillBackgroundContainer(at: 0)?.glassTintColor, navigationBarGlassTintColor(.generic, theme: theme))
        let plain = NavigationBarTheme(overallDarkAppearance: false, buttonColor: .white, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .lightGray, accentForegroundColor: .white)
        XCTAssertNotEqual(navigationBarGlassTintColor(.generic, theme: theme), navigationBarGlassTintColor(.generic, theme: plain))
    }

    // A change made without animation is applied as is.
    func test_unanimatedItemChange_isImmediate() {
        let item = UINavigationItem(title: "Text Replacement")
        item.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)
        let node = self.makeNode()
        node.item = item
        self.layout(node)
        item.setRightBarButton(UIBarButtonItem(title: "Done", style: .done, target: nil, action: nil), animated: false)
        node.layout()
        XCTAssertNil(node.rowViewForTesting?.inPlaceStateForTesting(isLeft: false))
        XCTAssertEqual(node.rowViewForTesting?.plattersDetached, false)
    }

    // An expansion takes the chat's pill and avatar: the bar morph draws neither for the lower bar, so the upper bar's
    // Edit has no counterpart and materializes in place (without the exclusion it morphs out of the avatar capsule).
    func test_transitionRenderer_exclusions_dropThePillAndTheNode() {
        let avatarNode = ASDisplayNode()
        let (bottom, _) = self.makePillNode(rightItems: [UIBarButtonItem(customDisplayNode: avatarNode)!])
        let top = self.makeLaidOutNode(title: "Profile", rightItem: UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil))
        guard let renderer = makeNavigationBarTransitionRenderer(bottom: bottom, top: top) as? NavigationBarTransitionRendererImpl else {
            return XCTFail("no renderer")
        }
        renderer.updateExclusions(bottom: NavigationBarTransitionExclusions(titlePill: true, nodes: [avatarNode]))
        let size = CGSize(width: 390.0, height: 844.0)
        let frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 107.0)
        renderer.update(size: size, fraction: 0.0, bottomFrame: frame, topFrame: frame, transition: .immediate)
        guard let platterView = renderer.platterViewForTesting else {
            return XCTFail("no platter view")
        }
        renderer.beginTransition(isInteractive: false, toTop: true)
        let edit = platterView.platterStateForTesting(.trailing(0))
        XCTAssertEqual(edit?.opacity ?? 1.0, 0.0, accuracy: 0.001, "Edit materializes")
        XCTAssertGreaterThan(edit?.scale.height ?? 0.0, 1.0, "in place")
        XCTAssertNil(platterView.platterStateForTesting(.trailing(1)), "no pill platter")
    }
}

/// A screen's node that sizes itself like the chat's avatar (37pt, narrower than a button).
private final class AvatarLikeNode: ASDisplayNode {
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 37.0, height: 37.0)
    }
}
