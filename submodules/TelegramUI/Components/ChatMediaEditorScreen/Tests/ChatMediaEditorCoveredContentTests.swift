import Foundation
import UIKit
import XCTest
@testable import ChatMediaEditorScreen

final class ChatMediaEditorCoveredContentTests: XCTestCase {
    func testHidesOnlyWhileRestingFullScreen() {
        XCTAssertTrue(chatMediaEditorHidesCoveredContent(hasFinishedTransitionIn: true, isVisible: true, isDismissing: false, isSwipingDown: false, isInvalidated: false))
        XCTAssertFalse(chatMediaEditorHidesCoveredContent(hasFinishedTransitionIn: false, isVisible: true, isDismissing: false, isSwipingDown: false, isInvalidated: false))
        XCTAssertFalse(chatMediaEditorHidesCoveredContent(hasFinishedTransitionIn: true, isVisible: false, isDismissing: false, isSwipingDown: false, isInvalidated: false))
        XCTAssertFalse(chatMediaEditorHidesCoveredContent(hasFinishedTransitionIn: true, isVisible: true, isDismissing: true, isSwipingDown: false, isInvalidated: false))
        XCTAssertFalse(chatMediaEditorHidesCoveredContent(hasFinishedTransitionIn: true, isVisible: true, isDismissing: false, isSwipingDown: true, isInvalidated: false))
        XCTAssertFalse(chatMediaEditorHidesCoveredContent(hasFinishedTransitionIn: true, isVisible: true, isDismissing: false, isSwipingDown: false, isInvalidated: true))
    }

    private final class Hierarchy {
        let windowLike = UIView()
        let systemSibling = UIView()
        let rootViewControllerView = UIView()
        let rootSibling = UIView()
        let navigation = UIView()
        let chat = UIView()
        let sheet = UIView()
        let alreadyHidden = UIView()
        let container = UIView()
        let editor = UIView()
        let editorChild = UIView()
        let overlayAbove = UIView()
        let otherContainer = UIView()

        init() {
            self.alreadyHidden.isHidden = true
            self.windowLike.addSubview(self.systemSibling)
            self.windowLike.addSubview(self.rootViewControllerView)
            self.rootViewControllerView.addSubview(self.rootSibling)
            self.rootViewControllerView.addSubview(self.navigation)
            self.navigation.addSubview(self.chat)
            self.navigation.addSubview(self.alreadyHidden)
            self.navigation.addSubview(self.sheet)
            self.navigation.addSubview(self.container)
            self.navigation.addSubview(self.overlayAbove)
            self.navigation.addSubview(self.otherContainer)
            self.container.addSubview(self.editor)
            self.editor.addSubview(self.editorChild)
        }

        var everythingElse: [UIView] {
            return [self.windowLike, self.systemSibling, self.rootViewControllerView, self.navigation, self.container, self.editor, self.editorChild, self.overlayAbove, self.otherContainer]
        }

        func makeContent() -> ChatMediaEditorCoveredContent {
            let content = ChatMediaEditorCoveredContent()
            let boundary = self.rootViewControllerView
            content.boundary = { _ in
                return boundary
            }
            content.setCoveringView(self.editor)
            return content
        }
    }

    private func assertHidden(_ h: Hierarchy, _ hidden: Bool, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(h.chat.isHidden, hidden, file: file, line: line)
        XCTAssertEqual(h.sheet.isHidden, hidden, file: file, line: line)
        XCTAssertEqual(h.rootSibling.isHidden, hidden, file: file, line: line)
        XCTAssertTrue(h.alreadyHidden.isHidden, file: file, line: line)
        for view in h.everythingElse {
            XCTAssertFalse(view.isHidden, file: file, line: line)
        }
    }

    func testWalkStopsAtTheRootViewControllerView() {
        let h = Hierarchy()
        let covered = chatMediaEditorCoveredViews(below: h.editor, boundary: h.rootViewControllerView)
        XCTAssertEqual(covered.count, 3)
        XCTAssertTrue(covered.contains(where: { $0 === h.chat }))
        XCTAssertTrue(covered.contains(where: { $0 === h.sheet }))
        XCTAssertTrue(covered.contains(where: { $0 === h.rootSibling }))
        XCTAssertFalse(covered.contains(where: { $0 === h.systemSibling }))
    }

    func testWalkNeedsABoundaryAboveTheEditor() {
        let h = Hierarchy()
        XCTAssertTrue(chatMediaEditorCoveredViews(below: h.editor, boundary: nil).isEmpty)
        XCTAssertTrue(chatMediaEditorCoveredViews(below: h.editor, boundary: UIView()).isEmpty)
        XCTAssertTrue(chatMediaEditorCoveredViews(below: h.editor, boundary: h.editor).isEmpty)
    }

    func testHidesAfterTransitionInAndRestoresOnDismiss() {
        let h = Hierarchy()
        let content = h.makeContent()
        content.setIsVisible(true)
        self.assertHidden(h, false)
        content.transitionInFinished()
        XCTAssertTrue(content.isHiding)
        self.assertHidden(h, true)
        content.apply()
        self.assertHidden(h, true)
        content.dismissBegan()
        XCTAssertFalse(content.isHiding)
        self.assertHidden(h, false)
        content.apply()
        self.assertHidden(h, false)
    }

    func testCancelledSwipeRestoresThenHidesAgain() {
        let h = Hierarchy()
        let content = h.makeContent()
        content.setIsVisible(true)
        content.transitionInFinished()
        content.setIsSwipingDown(true)
        self.assertHidden(h, false)
        content.setIsSwipingDown(false)
        self.assertHidden(h, true)
    }

    func testDisappearRestoresAndReappearHides() {
        let h = Hierarchy()
        let content = h.makeContent()
        content.setIsVisible(true)
        content.transitionInFinished()
        content.setIsVisible(false)
        self.assertHidden(h, false)
        content.setIsVisible(true)
        self.assertHidden(h, true)
    }

    func testInvalidateRestoresForGood() {
        let h = Hierarchy()
        let content = h.makeContent()
        content.setIsVisible(true)
        content.transitionInFinished()
        content.invalidate()
        self.assertHidden(h, false)
        content.setIsVisible(true)
        self.assertHidden(h, false)
    }

    func testReparentedEditorIsNeverLeftInsideAHiddenView() {
        let h = Hierarchy()
        let content = h.makeContent()
        content.setIsVisible(true)
        content.transitionInFinished()
        self.assertHidden(h, true)

        h.chat.addSubview(h.container)
        content.apply()
        XCTAssertTrue(content.isHiding)
        XCTAssertFalse(h.chat.isHidden)
        XCTAssertFalse(h.container.isHidden)
        XCTAssertFalse(h.editor.isHidden)
        XCTAssertFalse(h.sheet.isHidden)
        XCTAssertTrue(h.rootSibling.isHidden)

        content.dismissBegan()
        XCTAssertFalse(h.rootSibling.isHidden)
        XCTAssertFalse(h.chat.isHidden)
    }

    func testNothingToHideOutsideTheBoundary() {
        let container = UIView()
        let below = UIView()
        let editor = UIView()
        container.addSubview(below)
        container.addSubview(editor)
        let content = ChatMediaEditorCoveredContent()
        content.setCoveringView(editor)
        content.setIsVisible(true)
        content.transitionInFinished()
        XCTAssertFalse(content.isHiding)
        XCTAssertFalse(below.isHidden)
    }
}
