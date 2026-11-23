import XCTest
@testable import TelegramCore

final class SupportDraftsTests: XCTestCase {
    private func inputState(_ text: String, replyTo: EngineMessageReplySubject? = nil) -> SynchronizeableChatInputState {
        return SynchronizeableChatInputState(replySubject: replyTo, text: text, entities: [], timestamp: 1, textSelection: nil, messageEffectId: nil, suggestedPost: nil)
    }

    func testOnlyTheSupportMainThreadKeepsDraftsLocal() {
        XCTAssertTrue(supportKeepsDraftLocal(isSupportAccount: true, threadId: nil))
        XCTAssertFalse(supportKeepsDraftLocal(isSupportAccount: true, threadId: 5))
        XCTAssertFalse(supportKeepsDraftLocal(isSupportAccount: false, threadId: nil))
        XCTAssertFalse(supportKeepsDraftLocal(isSupportAccount: false, threadId: 5))
    }

    func testOccupationDraftTextAsTDesktopWritesIt() {
        XCTAssertTrue(isSupportOccupationDraftText("t:1762160000;u:3735928559;n:Agent"))
        XCTAssertTrue(isSupportOccupationDraftText("t:1762160000;u:1;n:"))
        XCTAssertTrue(isSupportOccupationDraftText("t:1762160000;u:1;n:Agent_Name with spaces"))
    }

    func testTextThatIsNotAnOccupationDraft() {
        XCTAssertFalse(isSupportOccupationDraftText("Hello"))
        XCTAssertFalse(isSupportOccupationDraftText("t:1762160000;u:1"))
        XCTAssertFalse(isSupportOccupationDraftText("t:soon;u:1;n:x"))
        XCTAssertFalse(isSupportOccupationDraftText("t:1;u:;n:x"))
        XCTAssertFalse(isSupportOccupationDraftText("t:1;u:1;n:a;b"))
        XCTAssertFalse(isSupportOccupationDraftText("t:1;u:1;n:a:b"))
        XCTAssertFalse(isSupportOccupationDraftText(" t:1;u:1;n:x"))
        XCTAssertFalse(isSupportOccupationDraftText("u:1;t:1;n:x"))
    }

    func testStoredDraftSweep() {
        XCTAssertEqual(supportStoredDraftSweep(hasOverride: true, inputState: self.inputState("t:1;u:2;n:x")), .clearOccupationText)
        XCTAssertEqual(supportStoredDraftSweep(hasOverride: false, inputState: self.inputState("t:1;u:2;n:x")), .clearOccupationText)
        XCTAssertEqual(supportStoredDraftSweep(hasOverride: true, inputState: self.inputState("my reply")), .dropOverride)
        XCTAssertEqual(supportStoredDraftSweep(hasOverride: true, inputState: nil), .dropOverride)
        XCTAssertEqual(supportStoredDraftSweep(hasOverride: false, inputState: self.inputState("my reply")), .keep)
        XCTAssertEqual(supportStoredDraftSweep(hasOverride: false, inputState: nil), .keep)
    }

    func testOccupationTextWithAReplyIsTheAgentsOwn() {
        let reply = EngineMessageReplySubject(messageId: EngineMessage.Id(peerId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1)), namespace: Namespaces.Message.Cloud, id: 1), quote: nil, innerSubject: nil)
        XCTAssertEqual(supportStoredDraftSweep(hasOverride: true, inputState: self.inputState("t:1;u:2;n:x", replyTo: reply)), .dropOverride)
    }
}
