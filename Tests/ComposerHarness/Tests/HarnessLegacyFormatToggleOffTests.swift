import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, a Format command cannot be toggled OFF over a selection
/// that already carries it everywhere but also carries some OTHER format on part of it. The command
/// re-applies instead, so the text stays formatted and the user has no way to remove it short of
/// reselecting piece by piece:
///
///     "The quick brown fox…" → select "quick brown" → Bold → select "brown" → Italic
///     → select "quick brown" → Bold
///       legacy:   [b] "quick " [b,i] "brown"      ← nothing changed
///       engine:   "quick " [i] "brown"            (bold removed, italic kept)
///
/// The same for Spoiler over a spoilered range with Bold inside it, and for every inline format:
/// a link, a date or another inline format inside the range splits the attribute runs the same way.
///
/// **How it was seen.** K1, 2026-09-23, seventh roam (legacy as the subject): the panel's own
/// `formatAttributesBold:` / `formatAttributesSpoiler:` sent through lldb, selections set on the
/// `ChatInputTextView`, the model read from the readout. Bold ×1, Spoiler ×1; engine oracle correct.
///
/// **Suspected cause.** `chatTextInputAddFormattingAttribute` (`ChatPresentationInterfaceState/
/// Sources/ChatTextFormat.swift`) decides "remove" only when an enumerated run of the attribute
/// EQUALS the whole selection (`nsRange == range`). `enumerateAttributes` splits runs wherever ANY
/// attribute changes, so a selection that is bold throughout but partly italic enumerates as two
/// runs, neither equal to the selection, and the attribute is added again. It should ask whether the
/// attribute covers the whole selection (e.g. `enumerateAttribute(attribute, …)` with no gaps).
/// Shared upstream code, not a branch regression as far as this roam checked.
///
/// **Tier 1**: the command is the panel's own `formatAttributes…` action (what the Format menu calls);
/// the loss is in the input state the chat sends from.
final class HarnessLegacyFormatToggleOffTests: XCTestCase {
    func testBoldTogglesOffOverAPartlyItalicSelection() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText("The quick brown fox jumps over the lazy dog."))
        arranged = value

        HarnessLegacy.select(value, NSRange(location: 4, length: 11))
        value.host.panel.formatAttributesBold(self)
        HarnessEngine.settle(value.root)
        HarnessLegacy.select(value, NSRange(location: 10, length: 5))
        value.host.panel.formatAttributesItalic(self)
        HarnessEngine.settle(value.root)
        XCTAssertEqual(HarnessLegacy.text(in: HarnessLegacy.content(value), where: { $0.bold }), "quick brown",
                       "precondition: bold was not applied")

        HarnessLegacy.select(value, NSRange(location: 4, length: 11))
        value.host.panel.formatAttributesBold(self)
        HarnessEngine.settle(value.root)

        let content = HarnessLegacy.content(value)
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.bold }), "",
                       "Bold over a fully bold, partly italic selection did not toggle off: \(content.blocks)")
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.italic }), "brown",
                       "toggling Bold off must keep the italic: \(content.blocks)")
    }

    func testSpoilerTogglesOffOverAPartlyBoldSelection() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText("The quick brown fox jumps over the lazy dog."))
        arranged = value

        HarnessLegacy.select(value, NSRange(location: 4, length: 15))
        value.host.panel.formatAttributesSpoiler(self)
        HarnessEngine.settle(value.root)
        HarnessLegacy.select(value, NSRange(location: 10, length: 5))
        value.host.panel.formatAttributesBold(self)
        HarnessEngine.settle(value.root)
        XCTAssertEqual(HarnessLegacy.text(in: HarnessLegacy.content(value), where: { $0.spoiler }), "quick brown fox",
                       "precondition: the spoiler was not applied")

        HarnessLegacy.select(value, NSRange(location: 4, length: 15))
        value.host.panel.formatAttributesSpoiler(self)
        HarnessEngine.settle(value.root)

        let content = HarnessLegacy.content(value)
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.spoiler }), "",
                       "Spoiler over a fully spoilered, partly bold selection did not toggle off: \(content.blocks)")
    }

    /// Control: a selection carrying nothing but the one format toggles off.
    func testBoldTogglesOffOverAUniformSelection() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText("The quick brown fox jumps over the lazy dog."))
        arranged = value

        HarnessLegacy.select(value, NSRange(location: 4, length: 11))
        value.host.panel.formatAttributesBold(self)
        HarnessEngine.settle(value.root)
        HarnessLegacy.select(value, NSRange(location: 4, length: 11))
        value.host.panel.formatAttributesBold(self)
        HarnessEngine.settle(value.root)

        XCTAssertEqual(HarnessLegacy.text(in: HarnessLegacy.content(value), where: { $0.bold }), "")
    }
}
