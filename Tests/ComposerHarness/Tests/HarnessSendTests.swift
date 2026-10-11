import XCTest
import TelegramCore
@testable import ComposerHarnessLib

final class HarnessSendTests: XCTestCase {
    private func root() throws -> HarnessRootViewController {
        let value = try XCTUnwrap(AppDelegate.harnessRootViewController)
        value.loadViewIfNeeded()
        value.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0)
        let deadline = Date().addingTimeInterval(30.0)
        while value.panelHost == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        value.view.layoutIfNeeded()
        return value
    }

    func testSendAppendsAReceiptAndClearsTheField() throws {
        let value = try self.root()
        let host = try XCTUnwrap(value.panelHost)
        let before = value.historyView.entries.count

        host.setInputContent(HarnessContent.plainText("hello"))
        value.view.layoutIfNeeded()
        XCTAssertFalse(host.panel.inputTextState.content.plainText.isEmpty)

        value.simulateSend()
        value.view.layoutIfNeeded()

        XCTAssertEqual(value.historyView.entries.count, before + 1)
        XCTAssertEqual(value.historyView.entries.last?.content.plainText, "hello")
        XCTAssertTrue(host.panel.inputTextState.content.plainText.isEmpty,
                      "the field was not cleared")
    }

    func testSendingAnEmptyComposerAppendsNothing() throws {
        let value = try self.root()
        let host = try XCTUnwrap(value.panelHost)
        host.setInputContent(ChatInputContent())
        value.view.layoutIfNeeded()

        let before = value.historyView.entries.count
        value.simulateSend()
        XCTAssertEqual(value.historyView.entries.count, before)
    }

    /// The panel's own Send button routes through the same hook. If this diverges from
    /// `simulateSend`, a Tier-2 test tapping Send would exercise a path no Tier-1 test covers.
    func testTheRealSendHookIsWiredToTheSamePath() throws {
        let value = try self.root()
        let host = try XCTUnwrap(value.panelHost)
        host.setInputContent(HarnessContent.plainText("via hook"))
        value.view.layoutIfNeeded()

        let before = value.historyView.entries.count
        host.panel.sendMessage()
        value.view.layoutIfNeeded()

        XCTAssertEqual(value.historyView.entries.count, before + 1)
        XCTAssertEqual(value.historyView.entries.last?.content.plainText, "via hook")
    }
}
