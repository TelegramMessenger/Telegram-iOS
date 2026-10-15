import XCTest
import UIKit
@testable import Display

/// Folding iPhone Duo switches the navigation root from split to flat; the chat list highlighted the
/// chat the detail pane showed and nothing cleared it, so the row stayed highlighted.
final class SplitSelectionTests: XCTestCase {
    private final class RecordingMaster: ViewController {
        var received: [(data: Any?, progress: CGFloat)] = []

        init() {
            super.init(navigationBarPresentationData: nil)
        }

        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func updateNavigationCustomData(_ data: Any?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
            self.received.append((data, progress))
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
}
