import XCTest
import UIKit
@testable import Display

/// Folding iPhone Duo switches the navigation root from split to flat; the chat list highlighted the
/// chat the detail pane showed and nothing cleared it, so the row stayed highlighted.
final class SplitSelectionTests: XCTestCase {
    private final class RecordingMaster: ViewController {
        var received: [(data: Any?, progress: CGFloat)] = []
        var reveals: [Bool] = []

        init() {
            super.init(navigationBarPresentationData: nil)
        }

        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func updateNavigationCustomData(_ data: Any?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
            self.received.append((data, progress))
        }

        override func narrowMasterRevealUpdated(_ isRevealed: Bool) {
            self.reveals.append(isRevealed)
        }
    }

    private final class DetailChat: ViewController {
        init() {
            super.init(navigationBarPresentationData: nil)
        }

        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var customData: Any? {
            return "chat-1"
        }
    }

    private func makeSplitContainer() -> NavigationSplitContainer {
        let navigationBar = NavigationBarTheme(overallDarkAppearance: false, buttonColor: .blue, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .gray, accentForegroundColor: .white)
        return NavigationSplitContainer(theme: NavigationControllerTheme(statusBar: .black, navigationBar: navigationBar, emptyAreaColor: .white, separatorColor: .gray, opaqueBackgroundColor: .white), controllerRemoved: { _ in })
    }

    private var unfoldedLandscape: ContainerViewLayout {
        return ContainerViewLayout(size: CGSize(width: 951.0, height: 669.0), metrics: LayoutMetrics(widthClass: .regular, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    func test_detailChat_highlightsItInTheMaster() {
        let split = self.makeSplitContainer()
        let master = RecordingMaster()
        split.update(layout: self.unfoldedLandscape, masterControllers: [master], detailControllers: [DetailChat()], detailsPlaceholderNode: nil, transition: .immediate)
        XCTAssertEqual(master.received.last?.data as? String, "chat-1")
    }

    func test_clearingTheDetailSelection_removesTheHighlight() {
        let split = self.makeSplitContainer()
        let master = RecordingMaster()
        split.update(layout: self.unfoldedLandscape, masterControllers: [master], detailControllers: [DetailChat()], detailsPlaceholderNode: nil, transition: .immediate)
        split.clearDetailSelection()
        XCTAssertNil(master.received.last?.data)
        XCTAssertEqual(master.received.last?.progress, 0.0)
    }

    func test_masterWidthOverride_narrowsThePaneOnly() {
        let split = self.makeSplitContainer()
        let layout = self.unfoldedLandscape
        split.update(layout: layout, masterWidthOverride: 72.0, masterControllers: [RecordingMaster()], detailControllers: [DetailChat()], detailsPlaceholderNode: nil, transition: .immediate)
        let frames = split.scrollToTopProxyFrames(layout: layout)
        XCTAssertEqual(frames.master.width, 72.0)
        XCTAssertEqual(frames.detail.minX, 72.0)
        XCTAssertEqual(frames.detail.width, layout.size.width - 72.0)
    }

    func test_withoutAnOverride_theSplitWidthIsUnchanged() {
        let split = self.makeSplitContainer()
        let layout = self.unfoldedLandscape
        split.update(layout: layout, masterControllers: [RecordingMaster()], detailControllers: [DetailChat()], detailsPlaceholderNode: nil, transition: .immediate)
        XCTAssertEqual(split.scrollToTopProxyFrames(layout: layout).master.width, splitMasterWidth(containerSize: layout.size, division: nil))
    }

    func test_narrowMaster_givesTheDetailABackButton_andRotatingRestoresTheCross() {
        let split = self.makeSplitContainer()
        let master = RecordingMaster()
        let detail = DetailChat()
        split.update(layout: self.unfoldedLandscape, masterWidthOverride: 72.0, masterControllers: [master], detailControllers: [detail], detailsPlaceholderNode: nil, transition: .immediate)
        XCTAssertEqual(detail.previousItem, .item(master.navigationItem))
        split.update(layout: self.unfoldedLandscape, masterControllers: [master], detailControllers: [detail], detailsPlaceholderNode: nil, transition: .immediate)
        XCTAssertEqual(detail.previousItem, .close)
    }

    func test_ordinarySplit_keepsTheCross() {
        let split = self.makeSplitContainer()
        let detail = DetailChat()
        split.update(layout: self.unfoldedLandscape, masterControllers: [RecordingMaster()], detailControllers: [detail], detailsPlaceholderNode: nil, transition: .immediate)
        XCTAssertEqual(detail.previousItem, .close)
    }

    func test_onlyANarrowMasterLetsASwipeCloseTheChat() {
        let split = self.makeSplitContainer()
        let master = RecordingMaster()
        let detail = DetailChat()
        split.update(layout: self.unfoldedLandscape, masterWidthOverride: 72.0, masterControllers: [master], detailControllers: [detail], detailsPlaceholderNode: nil, transition: .immediate)
        XCTAssertTrue(split.detailSwipeIsAvailable)
        split.update(layout: self.unfoldedLandscape, masterControllers: [master], detailControllers: [detail], detailsPlaceholderNode: nil, transition: .immediate)
        XCTAssertFalse(split.detailSwipeIsAvailable)
    }

    func test_detailFollowsTheSwipe_andSettlesWhenReleasedEarly() {
        let split = self.makeSplitContainer()
        let layout = self.unfoldedLandscape
        split.frame = CGRect(origin: CGPoint(), size: layout.size)
        split.update(layout: layout, masterWidthOverride: 72.0, masterControllers: [RecordingMaster()], detailControllers: [DetailChat()], detailsPlaceholderNode: nil, transition: .immediate)
        split.detailSwipeUpdated(translation: 100.0, velocity: 0.0, state: .changed)
        XCTAssertEqual(split.detailSwipeOffset, 100.0)
        split.detailSwipeUpdated(translation: -30.0, velocity: 0.0, state: .changed)
        XCTAssertEqual(split.detailSwipeOffset, 0.0)
        split.detailSwipeUpdated(translation: 100.0, velocity: 0.0, state: .ended)
        XCTAssertEqual(split.detailSwipeOffset, 0.0)
    }

    func test_swipeRevealsTheFullMaster_andRestoresItWhenReleased() {
        let split = self.makeSplitContainer()
        let layout = self.unfoldedLandscape
        let master = RecordingMaster()
        split.frame = CGRect(origin: CGPoint(), size: layout.size)
        split.update(layout: layout, masterWidthOverride: 72.0, masterControllers: [master], detailControllers: [DetailChat()], detailsPlaceholderNode: nil, transition: .immediate)
        split.detailSwipeUpdated(translation: 5.0, velocity: 0.0, state: .began)
        split.detailSwipeUpdated(translation: 50.0, velocity: 0.0, state: .changed)
        XCTAssertEqual(master.reveals, [true])
        split.detailSwipeUpdated(translation: 50.0, velocity: 0.0, state: .ended)
        XCTAssertEqual(master.reveals, [true, false])
    }

    func test_narrowMasterKeepsItsContentAtFullWidth_soCompressingItRedrawsNothing() {
        let split = self.makeSplitContainer()
        let layout = self.unfoldedLandscape
        let master = RecordingMaster()
        split.prepareMasterFull(layout: layout, masterWidth: 72.0, masterControllers: [master])
        split.update(layout: layout, masterWidthOverride: 72.0, masterControllers: [master], detailControllers: [DetailChat()], detailsPlaceholderNode: nil, transition: .immediate)
        XCTAssertEqual(split.masterContentWidth, layout.size.width)
        XCTAssertEqual(split.scrollToTopProxyFrames(layout: layout).master.width, 72.0)
    }

    func test_swipeClosesPastAThirdOrOnAFlick() {
        XCTAssertFalse(narrowMasterSwipeCloses(offset: 100.0, velocity: 0.0, width: 318.0))
        XCTAssertTrue(narrowMasterSwipeCloses(offset: 110.0, velocity: 0.0, width: 318.0))
        XCTAssertTrue(narrowMasterSwipeCloses(offset: 20.0, velocity: 700.0, width: 318.0))
        XCTAssertFalse(narrowMasterSwipeCloses(offset: 200.0, velocity: -700.0, width: 318.0))
    }
}
