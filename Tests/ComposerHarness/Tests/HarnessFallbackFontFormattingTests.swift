import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, ITALIC never reaches the model for text the system font
/// cannot draw — Chinese, Arabic, emoji — and BOLD never reaches it for emoji. The text view carries
/// the marker (`IDInlineTextItalic = 1` on the run) and draws the substituted face, but the model,
/// which is what is sent, has the run plain:
///
///     "漢字 عربي 😀 The quick…" → select 0..<10 → Format ▸ Italic
///       engine: "漢字" [i] " " "عربي" [i] " " "😀"     ← only the two spaces are italic
///       legacy: [i] "漢字 عربي 😀"
///     Bold "quick", caret after "qu", type "😀漢字عربي"
///       engine: [b] "qu" "😀" [b] "漢字" [b] "عربي" [b] "ick"   ← the emoji is not bold
///     Italic "quick", same typing: [i] "qu" "😀" "漢" "ع" [i] "ick"   ← none of it italic
///     Markdown paste "*漢字 abc عربي* and **粗体 😀 bold**" → italic kept only on " abc ",
///     bold lost on the emoji
///
/// Spoiler, strikethrough, underline and monospace survive (control below): they are carried by
/// markers, not read back from the face.
///
/// **How it was seen.** K1, 2026-09-23, seventh roam (stress after the engine's text-storage
/// change): Format ▸ Italic/Bold through the edit-menu provider, `insertText:` on the engine text
/// view, markdown `paste:`, each through lldb; the model from the readout, the storage's attributes
/// from `textStorage`. Seen 4× (Format ▸ Italic, typing into italic, typing into bold, markdown
/// paste). Legacy control keeps both.
///
/// **Suspected cause.** The read-back derives italic from the RENDERED face:
/// `AttributedStringMapper.characterAttributes(from:)` sets `ca.italic = traits.contains(.traitItalic)`
/// (`RichTextEditorUIKit/Mapping/AttributedStringMapper.swift` ~388), and after TextKit's font fixing
/// the run's `.font` is the fallback (PingFang, SF Arabic, Apple Color Emoji), which has no italic
/// face — so the trait is gone although the marker is on the run. Bold reads `.rtBold` first, which
/// is why CJK/Arabic bold survives; the emoji's bold loss suggests the marker is missing on the
/// emoji's substituted run. Whether the sixth wave's attribute-fixing change
/// (`IDCanonicalTextStorageAdapter fixAttributesInRange:` / `id_adoptCanonicalAttributes:`) made the
/// read-back see fixed fonts where it used not to was not established.
///
/// **Tier 1**: `performFormatAction` is what the Format menu calls and `insertText(_:)` is the
/// keyboard's; the loss is in the model.
final class HarnessFallbackFontFormattingTests: XCTestCase {
    private func arrange(_ text: String) throws -> (HarnessRootViewController, ChatRichTextInputNode) {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(HarnessContent.plainText(text))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        return (root, node)
    }

    private func text(_ node: ChatRichTextInputNode, where predicate: (ChatInputInlineAttributes) -> Bool) -> String {
        var result = ""
        for block in node.currentInputContent().content.blocks {
            if case let .paragraph(paragraph) = block {
                for run in paragraph.runs where predicate(run.attributes) {
                    result += run.text
                }
            }
        }
        return result
    }

    private func format(_ action: ChatRichTextFormatAction, range: NSRange, of text: String,
                        where predicate: (ChatInputInlineAttributes) -> Bool) throws -> String {
        let (root, node) = try self.arrange(text)
        defer { _ = node.resignInputFirstResponder() }
        node.selectedRange = range
        HarnessEngine.settle(root)
        node.performFormatAction(action)
        HarnessEngine.settle(root)
        return self.text(node, where: predicate)
    }

    private func typeInto(_ action: ChatRichTextFormatAction, _ typed: String,
                          where predicate: (ChatInputInlineAttributes) -> Bool) throws -> String {
        let (root, node) = try self.arrange("The quick brown fox jumps over the lazy dog.")
        defer { _ = node.resignInputFirstResponder() }
        node.selectedRange = NSRange(location: 4, length: 5)
        HarnessEngine.settle(root)
        node.performFormatAction(action)
        HarnessEngine.settle(root)
        XCTAssertEqual(self.text(node, where: predicate), "quick", "precondition: \(action) was not applied")
        node.selectedRange = NSRange(location: 6, length: 0)
        HarnessEngine.settle(root)
        (try HarnessEngine.textView(in: root) as? UIKeyInput)?.insertText(typed)
        HarnessEngine.settle(root)
        return self.text(node, where: predicate)
    }

    func testItalicOnChineseArabicAndEmojiReachesTheModel() throws {
        let italic = try self.format(.italic, range: NSRange(location: 0, length: 10),
                                     of: "漢字 عربي 😀 The quick brown fox.", where: { $0.italic })
        XCTAssertEqual(italic, "漢字 عربي 😀", "Format ▸ Italic did not reach the model for fallback-font text")
    }

    func testTypingChineseArabicAndEmojiIntoItalicKeepsItalic() throws {
        let italic = try self.typeInto(.italic, "😀漢ع", where: { $0.italic })
        XCTAssertEqual(italic, "qu😀漢عick", "text typed into an italic run lost italic in the model")
    }

    func testTypingAnEmojiIntoBoldKeepsBold() throws {
        let bold = try self.typeInto(.bold, "😀漢字عربي", where: { $0.bold })
        XCTAssertEqual(bold, "qu😀漢字عربيick", "text typed into a bold run lost bold in the model")
    }

    /// Control: a marker-carried format survives the same typing.
    func testTypingIntoStrikethroughKeepsStrikethrough() throws {
        let struck = try self.typeInto(.strikethrough, "😀漢ع", where: { $0.strikethrough })
        XCTAssertEqual(struck, "qu😀漢عick")
    }
}
