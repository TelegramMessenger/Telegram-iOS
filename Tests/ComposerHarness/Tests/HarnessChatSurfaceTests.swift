import XCTest
import UIKit
import TelegramCore
import HarnessAppContext
import AccountContext
@testable import ComposerHarnessLib

/// Pins two places where the harness's synthetic chat has to behave like the real one, or a whole
/// class of findings becomes unreachable. Both were harness gaps found by the second roam:
///
/// - **The placeholder.** The panel picks it from `interfaceState.renderedPeer`; the harness had
///   no rendered peer, so the empty composer showed nothing on either backend.
/// - **Legacy formatting.** The legacy backend applies a Format-menu command by computing the new
///   input state and handing it UP through `updateTextInputStateAndMode`; `ChatControllerNode`
///   pushes it back down with `updateInputTextState`. The harness kept the state and never pushed
///   it, so every legacy Format command was a no-op and legacy could not be the control for
///   inline-formatting findings.
final class HarnessChatSurfaceTests: XCTestCase {
    func testTheEmptyComposerShowsTheMessagePlaceholder() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        host.setInputContent(ChatInputContent())
        HarnessEngine.settle(root)

        let expected = host.interfaceState.strings.Conversation_InputTextPlaceholder
        XCTAssertFalse(expected.isEmpty)
        XCTAssertEqual(host.panel.textPlaceholderNode.attributedText?.string, expected)
    }

    func testTheLegacyBoldCommandFormatsTheSelection() throws {
        let root = try HarnessEngine.root()
        root.setBackend(.legacy)
        defer { root.setBackend(.engine) }
        let host = try XCTUnwrap(root.panelHost)
        XCTAssertEqual(host.liveBackend, .legacy, "precondition: the legacy backend is not live")

        let content = HarnessContent.plainText("The quick brown fox")
        host.setInputContent(content)
        host.panel.updateInputTextState(
            ChatTextInputState(content: content, selectionRange: 4 ..< 9),
            keepSendButtonEnabled: false,
            extendedSearchLayout: false,
            accessoryItems: [],
            animated: false
        )
        HarnessEngine.settle(root)

        host.panel.formatAttributesBold(self)
        HarnessEngine.settle(root)

        let boldRuns = host.panel.inputTextState.content.blocks.flatMap { block -> [String] in
            guard case let .paragraph(paragraph) = block else {
                return []
            }
            return paragraph.runs.filter { $0.attributes.bold }.map { $0.text }
        }
        XCTAssertEqual(boldRuns, ["quick"], "the legacy Bold command did not reach the composer")
    }

    /// Format ▸ Link reached an empty `openLinkEditing`, so links could not be exercised at all.
    /// The prompt is the harness's; applying the answer is the chat's own code on each backend.
    private func assertLinkApplies(backend: HarnessBackend) throws {
        let root = try HarnessEngine.root()
        root.setBackend(backend)
        defer {
            root.linkPromptOverride = nil
            root.setBackend(.engine)
        }
        let host = try XCTUnwrap(root.panelHost)
        XCTAssertEqual(host.liveBackend, backend, "precondition: the \(backend) backend is not live")

        let content = HarnessContent.plainText("The quick brown fox")
        host.setInputContent(content)
        host.panel.updateInputTextState(
            ChatTextInputState(content: content, selectionRange: 4 ..< 9),
            keepSendButtonEnabled: false,
            extendedSearchLayout: false,
            accessoryItems: [],
            animated: false
        )
        HarnessEngine.settle(root)
        if backend == .engine {
            host.panel.richTextInputNode?.selectedRange = NSRange(location: 4, length: 5)
            HarnessEngine.settle(root)
        }

        var prompted: String?
        root.linkPromptOverride = { selectedText, _ in
            prompted = selectedText
            return "https://telegram.org"
        }
        host.panel.formatAttributesLink(self)
        HarnessEngine.settle(root)

        XCTAssertNotNil(prompted, "Format ▸ Link did not ask for a URL")
        let linked = host.panel.inputTextState.content.blocks.flatMap { block -> [String] in
            guard case let .paragraph(paragraph) = block else {
                return []
            }
            return paragraph.runs.filter { $0.attributes.entity == .url("https://telegram.org") }.map { $0.text }
        }
        XCTAssertEqual(linked, ["quick"], "\(backend): the link was not applied to the selection")
    }

    func testFormatLinkAppliesOnTheEngine() throws {
        try self.assertLinkApplies(backend: .engine)
    }

    func testFormatLinkAppliesOnLegacy() throws {
        try self.assertLinkApplies(backend: .legacy)
    }
}
