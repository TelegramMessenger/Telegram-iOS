import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Settle keeps a media unit well-formed after any edit (spec §6): the caption's Return leaves a
/// body paragraph, a captioned atom always has its caption line, a caption-less one never does, and
/// an atom that a bypass path damaged is rescued.
@available(iOS 18.4, *)
final class EngineMediaSettleTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func item(_ id: String, kind: MediaKind = .image) -> MediaItem { MediaItem(mediaID: id, kind: kind, naturalSize: Size2D(width: 1000, height: 500)) }
    private func photo(_ id: String, _ caption: String = "") -> Block {
        .media(MediaBlock(id: BlockID(id), items: [item("m-\(id)")], caption: caption.isEmpty ? [] : [TextRun(text: caption)]))
    }
    private func audio(_ id: String) -> Block { .media(MediaBlock(id: BlockID(id), items: [item("m-\(id)", kind: .audio)])) }
    private func para(_ id: String, _ text: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)])) }
    private func strings() -> [String] { editor.engine.attributedBlocks.map { $0.string.replacingOccurrences(of: "\u{FFFC}", with: "▣") } }
    private func kinds() -> [String] {
        editor.currentRoles.map { role in
            if let kind = role.secondaryKind { return "secondary.\(kind)" }
            switch role.shape { case .media: return "media"; case .buttonRow: return "buttonRow"; case .code: return "code"; case .pullQuote: return "pullQuote"; case .collapsedQuote: return "collapsedQuote"; case .paragraph: return "std" }
        }
    }
    private func load(_ blocks: [Block]) { editor.document = Document(blocks: blocks); XCTAssertTrue(editor.engine.becomeFirstResponder()) }
    private func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    /// The BYPASS door: the controller edits without the gate seeing it (dictation, an IME commit).
    private func bypassInsert(_ text: String) {
        bypassInsertWithoutTurn(text)
        turn()
    }
    /// The same insert with no run-loop turn after it, for use INSIDE a `performHostStructuralEdit`
    /// block — settle runs once at that block's end, so a damaged state and the bypass insert that
    /// lands in it are seen together rather than repaired in between.
    private func bypassInsertWithoutTurn(_ text: String) {
        let controller = editor.engine.value(forKey: "id_behaviorInput") as AnyObject
        _ = controller.perform(#selector(UIKeyInput.insertText(_:)), with: text)
    }
    private func font(_ block: Int) -> UIFont? { editor.engine.attributedBlocks[block].attribute(.font, at: 0, effectiveRange: nil) as? UIFont }
    private func carriesAttachment(_ block: Int) -> Bool {
        let text = editor.engine.attributedBlocks[block]
        return (0..<text.length).contains { text.attribute(.attachment, at: $0, effectiveRange: nil) is MediaTextAttachment }
    }

    // MARK: - §6.3 the caption's Return

    func test_returnAtTheCaptionsEndOpensABodyParagraphBelowTheUnit() {
        load([photo("a", "cap"), para("p1", "after")])
        caret(5)
        editor.engine.insertText("\n")
        turn()
        XCTAssertEqual(strings(), ["▣", "cap", "", "after"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "std", "std"])
        // `font(_:)` reads the attribute at offset 0, so the fresh block has to hold a character
        // before its face can be read at all: the caret is already in it.
        editor.engine.insertText("z")
        turn()
        XCTAssertEqual(font(2)?.pointSize, font(3)?.pointSize, "body, not the caption's face")
    }

    func test_returnMidCaptionMovesTheTailBelow() {
        load([photo("a", "caption")])
        caret(5)   // "cap|tion"
        editor.engine.insertText("\n")
        turn()
        XCTAssertEqual(strings(), ["▣", "cap", "tion"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "std"])
    }

    func test_aPastedNewlineInTheCaptionSplitsLikeReturn() {
        load([photo("a", "cap")])
        caret(5)
        editor.engine.insertText("x\ny")
        turn()
        XCTAssertEqual(strings(), ["▣", "capx", "y"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "std"])
    }

    // MARK: - §6.2 caption-line presence

    func test_aCaptionedAtomWhoseLineVanishedGetsItBack() {
        load([photo("a", "cap"), para("p1", "after")])
        // A plan that forgets the line, as a bypass path might: the next settle restores it.
        var plan = editor.currentRoles
        plan.remove(at: 1)
        // A `replaceFlat` from a test is a keystroke to the gate, which would decide it and consume
        // the plan: framed as a host edit it passes untouched, and settle runs at its end.
        editor.performHostStructuralEdit {
            editor.replaceFlat(NSRange(location: 1, length: 4), with: "", adopting: plan)   // "\ncap" gone
        }
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "std"])
        XCTAssertEqual(strings(), ["▣", "", "after"], "an empty caption line, below the atom")
    }

    func test_aCaptionlessAtomNeverKeepsACaptionLine() {
        load([audio("a"), para("p1", "after")])
        XCTAssertEqual(kinds(), ["media", "std"])
        guard case let .standalone(.media(shape)) = editor.currentRoles[0].position else { return XCTFail() }
        var plan = editor.currentRoles
        plan.insert(.secondary(owner: .block(.media(shape)), line: shape.captionLineID, kind: .mediaCaption, within: []), at: 1)
        editor.performHostStructuralEdit {
            editor.replaceFlat(NSRange(location: 1, length: 0), with: "\n", adopting: plan)
        }
        XCTAssertEqual(kinds(), ["media", "std"])
        XCTAssertEqual(strings(), ["▣", "after"])
    }

    // MARK: - §6.2 atom integrity (bypass paths)

    func test_textDictatedAfterTheAtomMovesToTheCaptionsStart() {
        load([photo("a", "cap")])
        caret(1)
        bypassInsert("hi")
        XCTAssertEqual(strings(), ["▣", "hicap"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
    }

    func test_textDictatedBeforeTheAtomBecomesAParagraphAbove() {
        load([photo("a", "cap")])
        caret(0)
        bypassInsert("hi")
        XCTAssertEqual(strings(), ["hi", "▣", "cap"])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"])
    }

    func test_textDictatedAfterACaptionlessAtomBecomesAParagraphBelow() {
        load([audio("a")])
        caret(1)
        bypassInsert("hi")
        XCTAssertEqual(strings(), ["▣", "hi"])
        XCTAssertEqual(kinds(), ["media", "std"])
    }

    /// The two damaged states in which "does a caption line exist" and "is this kind captioned"
    /// disagree. Integrity dispatches on the KIND, so neither loses the text.
    ///
    /// The damage and the bypass insert are issued inside ONE `performHostStructuralEdit`: settle
    /// runs at its end, and a damaged state constructed in a block of its own would be repaired
    /// there, before the insert could land in it.

    func test_aStrayCaptionLineNeverSwallowsDictatedText() {
        load([audio("a")])                                   // "▣": the atom's trailing stop is 1
        guard case let .standalone(.media(shape)) = editor.currentRoles[0].position else { return XCTFail() }
        var plan = editor.currentRoles
        plan.insert(.secondary(owner: .block(.media(shape)), line: shape.captionLineID, kind: .mediaCaption, within: []), at: 1)
        editor.performHostStructuralEdit {
            editor.replaceFlat(NSRange(location: 1, length: 0), with: "\n", adopting: plan)   // the stray line
            caret(1)
            bypassInsertWithoutTurn("hi")                    // the atom block becomes "▣hi"
        }
        turn()
        // Copied into the stray line, the tail would go with it when presence deletes the line.
        XCTAssertEqual(strings(), ["▣", "hi"], "the tail is a paragraph below, and it survives")
        XCTAssertEqual(kinds(), ["media", "std"])
    }

    func test_aVanishedCaptionLineComesBackHoldingDictatedText() {
        load([photo("a", "cap")])                            // "▣\ncap"
        var plan = editor.currentRoles
        plan.remove(at: 1)
        editor.performHostStructuralEdit {
            editor.replaceFlat(NSRange(location: 1, length: 4), with: "", adopting: plan)      // "\ncap" gone
            caret(1)
            bypassInsertWithoutTurn("hi")                    // the atom block becomes "▣hi"
        }
        turn()
        // A paragraph below would leave the restored caption line empty ABOVE the text.
        XCTAssertEqual(strings(), ["▣", "hi"], "the line comes back holding the tail")
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
    }

    // MARK: - §6.3 a fresh block at either of the atom's stops

    /// A dictated MULTI-line insert at the trailing stop. `declareFreshBlocks` must rejoin the
    /// fresh block into the atom for a CAPTIONED kind — not declare it a body paragraph, which
    /// would put a paragraph between the atom and its caption and make
    /// `settleCaptionLinePresence` mint a SECOND caption line sharing one `captionLineID`.
    /// Integrity then moves the whole tail into the caption: spec §6.3's outcome, no new mechanism.
    func test_dictatedLinesAfterACaptionedAtomAllJoinTheCaption() {
        load([photo("a", "cap")])
        caret(1)
        bypassInsert("hi\nyo")
        XCTAssertEqual(strings(), ["▣", "hiyocap"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
    }

    /// The same insert at the LEADING stop. The controller's split leaves the atom's identity (and
    /// so its role) on the FIRST block while the attachment travels to the second, so the roles
    /// have to be swapped back before integrity looks at them — otherwise the role-holding block
    /// has no attachment, integrity reads the unit as destroyed, and the media is lost.
    func test_dictatedLinesBeforeTheAtomBecomeParagraphsAndTheAtomKeepsItsRole() {
        load([photo("a", "cap")])
        caret(0)
        bypassInsert("one\ntwo")
        XCTAssertEqual(strings(), ["one", "two", "▣", "cap"])
        XCTAssertEqual(kinds(), ["std", "std", "media", "secondary.mediaCaption"])
        XCTAssertTrue(carriesAttachment(2), "the atom kept the attachment and the media role together")
    }

    func test_anAtomWhoseAttachmentIsGoneBecomesAParagraphAndOrphansItsCaption() {
        load([photo("a", "cap")])
        // The attachment removed behind the gate's back: an attribute-only edit.
        editor.engine.id_setAttributes([.font: UIFont.systemFont(ofSize: 17)], inCanonicalRange: NSRange(location: 0, length: 1))
        editor.engine.tgid_mergeAttributes([:], removingKeys: [.attachment], inCanonicalRange: NSRange(location: 0, length: 1))
        editor.performHostStructuralChange { }
        XCTAssertEqual(kinds(), ["std", "std"])
    }

    func test_theGuardIsSilentOverAMediaDocument() {
        load([para("p0", "before"), photo("a", "cap"), audio("b"), para("p1", "after")])
        caret(6)
        editor.engine.insertText("!")
        caret(13)   // the caption's end, one past where it was before "before" grew
        editor.engine.insertText("!")
        turn()
        // The guard traps under XCTest on drift; reaching here with the expected text is the assertion.
        XCTAssertEqual(strings(), ["before!", "▣", "cap!", "▣", "after"])
    }
}
