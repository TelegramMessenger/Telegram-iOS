import XCTest
@testable import ChatTextInputPanelNode

/// The panels above the input field (link preview, forward, reply, …) share one slot. A panel that appears is
/// shown over the one already there, and dismissing it brings back the one it covered (#37: a reply set while a
/// link preview was showing stayed hidden behind it, so nothing visibly changed).
final class ChatTextInputAccessoryPanelStackTests: XCTestCase {
    // Priority order, highest first, as `textInputAccessoryPanel` lists them.
    private let linkPreview: AnyHashable = "linkPreview"
    private let forward: AnyHashable = "forward"
    private let reply: AnyHashable = "reply"

    func testReplySetAfterLinkPreviewIsShown() {
        var stack = ChatTextInputAccessoryPanelStack()
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview]), self.linkPreview)
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview, self.reply]), self.reply)
        // Typing on with the same link changes nothing.
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview, self.reply]), self.reply)
    }

    func testCancellingTheReplyBringsBackTheLinkPreview() {
        var stack = ChatTextInputAccessoryPanelStack()
        _ = stack.update(availableKeys: [self.linkPreview])
        _ = stack.update(availableKeys: [self.linkPreview, self.reply])
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview]), self.linkPreview)
    }

    func testLinkPreviewAppearingAfterReplyIsShown() {
        var stack = ChatTextInputAccessoryPanelStack()
        XCTAssertEqual(stack.update(availableKeys: [self.reply]), self.reply)
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview, self.reply]), self.linkPreview)
        // Dismissing the link preview uncovers the reply.
        XCTAssertEqual(stack.update(availableKeys: [self.reply]), self.reply)
    }

    func testPanelsAppearingTogetherKeepThePriority() {
        var stack = ChatTextInputAccessoryPanelStack()
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview, self.forward, self.reply]), self.linkPreview)
        XCTAssertEqual(stack.update(availableKeys: [self.forward, self.reply]), self.forward)
        XCTAssertEqual(stack.update(availableKeys: [self.reply]), self.reply)
    }

    func testReplyingToAnotherMessageComesBackOnTop() {
        // The caller's key carries the subject, so a reply to another message is a new panel.
        let replyToA: AnyHashable = "reply-a"
        let replyToB: AnyHashable = "reply-b"
        var stack = ChatTextInputAccessoryPanelStack()
        _ = stack.update(availableKeys: [replyToA])
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview, replyToA]), self.linkPreview)
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview, replyToB]), replyToB)
    }

    func testANewPanelGoesOverTheWholeStack() {
        var stack = ChatTextInputAccessoryPanelStack()
        _ = stack.update(availableKeys: [self.reply])
        _ = stack.update(availableKeys: [self.linkPreview, self.reply])
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview, self.forward, self.reply]), self.forward)
        // Cancelling the forward uncovers the link preview, which was on top before it.
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview, self.reply]), self.linkPreview)
    }

    func testHidingTheSlotKeepsTheOrder() {
        // Search, selection and previewing hide the slot without unsetting anything: the reply set over the link
        // preview is still on top afterwards.
        var stack = ChatTextInputAccessoryPanelStack()
        _ = stack.update(availableKeys: [self.linkPreview])
        _ = stack.update(availableKeys: [self.linkPreview, self.reply])
        XCTAssertNil(stack.update(availableKeys: nil))
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview, self.reply]), self.reply)
    }

    func testNothingAvailableShowsNothing() {
        var stack = ChatTextInputAccessoryPanelStack()
        _ = stack.update(availableKeys: [self.reply])
        XCTAssertNil(stack.update(availableKeys: []))
        // A panel that went away and comes back is new again.
        _ = stack.update(availableKeys: [self.linkPreview])
        XCTAssertEqual(stack.update(availableKeys: [self.linkPreview, self.reply]), self.reply)
    }
}
