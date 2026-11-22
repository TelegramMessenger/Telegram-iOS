#if canImport(UIKit)
import XCTest
import UIKit
import RichTextInputDecUpstream

/// R9-inline Task 1 (GATING). Everything the custom-emoji work does rests on one fact: an inline
/// atom occupies EXACTLY ONE position on the engine's canonical UTF-16 axis.
///
/// The legacy editor's whole custom-emoji design depends on the equivalent property — a single
/// `U+FFFC` carrying its ref in `CharacterAttributes`, so that `DocumentTree`, `PositionResolver`,
/// the editing engine and the tokenizer need no changes at all. On the engine side the composer's
/// flat-offset mapping (`composerSelectedRange`) is the load-bearing consumer: `ChatTextInputPanelNode`
/// drives every programmatic insert, replace and caret move off it. An attachment that measured as
/// anything other than 1 would put that mapping out of step with the panel's own arithmetic — and it
/// would do so silently, since both sides would still produce plausible offsets.
///
/// Hence a gating test rather than an assumption noted in a comment.
@available(iOS 18.4, *)
final class EngineAttachmentPositionTests: XCTestCase {

    private func makeDocument(_ text: String) -> IDBlockDocument {
        IDBlockDocument(
            attributedBlocks: [NSAttributedString(string: text)],
            defaultAttributes: [.font: UIFont.systemFont(ofSize: 17.0)]
        )
    }

    /// THE CONTROL, and it is not ceremony. This package's own verification-traps list is mostly
    /// instruments that returned a clean-looking number while measuring nothing. A delta of 1 for
    /// the attachment case only means something once the same measurement is shown to move for a
    /// known-1-unit input on the same axis.
    func test_control_aPlainCharacterIsOneCanonicalPosition() {
        let document = makeDocument("ab")
        let before = document.canonicalLength

        _ = document.replaceCanonicalRange(NSRange(location: 1, length: 0),
                                           with: NSAttributedString(string: "x"))

        XCTAssertEqual(document.canonicalLength - before, 1,
                       "A single plain character must advance the canonical axis by exactly 1. If "
                       + "this fails the axis is not what the composer mapping assumes and NOTHING "
                       + "below is interpretable.")
    }

    func test_anAttachmentIsExactlyOneCanonicalPosition() {
        let document = makeDocument("ab")
        let before = document.canonicalLength

        let attachment = NSTextAttachment()
        attachment.bounds = CGRect(x: 0.0, y: 0.0, width: 18.0, height: 18.0)
        _ = document.replaceCanonicalRange(NSRange(location: 1, length: 0),
                                           with: NSAttributedString(attachment: attachment))

        XCTAssertEqual(document.canonicalLength - before, 1,
                       "An inline attachment must occupy exactly one canonical position, like the "
                       + "legacy editor's single U+FFFC. A different width silently desynchronises "
                       + "composerSelectedRange from the panel's own offset arithmetic.")
    }

    /// The attachment must also be ADDRESSABLE as one unit: a length-1 replacement over it removes
    /// it entirely, leaving no orphaned half. This is the engine-side analogue of the surrogate-pair
    /// "service character" class of bug the legacy editor had to grow grapheme-expansion to fix.
    func test_anAttachmentIsRemovedByALengthOneReplacement() {
        let document = makeDocument("ab")
        let attachment = NSTextAttachment()
        attachment.bounds = CGRect(x: 0.0, y: 0.0, width: 18.0, height: 18.0)
        _ = document.replaceCanonicalRange(NSRange(location: 1, length: 0),
                                           with: NSAttributedString(attachment: attachment))
        let withAttachment = document.canonicalLength

        _ = document.replaceCanonicalRange(NSRange(location: 1, length: 1),
                                           with: NSAttributedString(string: ""))

        XCTAssertEqual(withAttachment - document.canonicalLength, 1,
                       "Deleting one canonical position over an attachment must remove the whole "
                       + "atom, not leave a fragment behind.")
    }
}
#endif
