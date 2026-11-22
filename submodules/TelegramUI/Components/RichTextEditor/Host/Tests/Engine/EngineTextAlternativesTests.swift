import XCTest
import UIKit
import RichTextInputDecHost
import RichTextInputDecUpstream
import RichTextEditorCore
@testable import RichTextEngineEditor

/// `UITextView`'s text-alternatives surface — `insertText:alternatives:style:` and its family —
/// which the engine's view lacked. It is NOT how an accepted autocorrection reaches a text input on
/// iOS 26.5: the keyboard applies that as a plain `replaceRange:withText:` and draws its underline
/// itself, through the text-choice acceleration assistant (see `EngineSelectionRectBaselineTests`).
/// The family is what a client that inserts text WITH alternatives — dictation, a paste of annotated
/// text — uses, and it lives on the host's shim; these tests drive it the way such a client and the
/// tap do, and read the result the way a device dump does: the annotation the tap is answered from,
/// and the rendering attribute the canvas draws.
/// The members of the family UIKit sends under PRIVATE names. The engine adds them at run time
/// (`TGPrivateMethodAliases.h`) and no shipping header declares them, so the tests declare them here
/// and send them the way UIKit does.
@objc private protocol UIKitTextAlternativesCallbacks {
    @objc(rangeWithTextAlternatives:atPosition:)
    func range(withTextAlternatives alternatives: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
               at position: UITextPosition) -> UITextRange?
    @objc(replaceRange:withAnnotatedString:relativeReplacementRange:)
    func replace(_ range: UITextRange, withAnnotatedString annotatedString: NSAttributedString,
                 relativeReplacementRange: NSRange)
    @objc(removeAlternativesForCurrentWord)
    func removeAlternativesForCurrentWord()
}

private func uikitCallbacks(_ view: TGIDObservingBlockTextView) -> UIKitTextAlternativesCallbacks {
    unsafeBitCast(view, to: UIKitTextAlternativesCallbacks.self)
}

@available(iOS 18.4, *)
final class EngineTextAlternativesTests: XCTestCase {
    private var window: UIWindow!
    private var engine: TGIDObservingBlockTextView!

    override func setUp() {
        super.setUp()
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17.0)]
        engine = TGIDObservingBlockTextView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 240),
            attributedBlocks: [NSAttributedString(string: "hello ", attributes: attributes)])
        engine.isEditable = true
        engine.isSelectable = true
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(engine); window.makeKeyAndVisible()
        XCTAssertTrue(engine.becomeFirstResponder())
        engine.selectedTextRange = engine.textRange(from: engine.endOfDocument, to: engine.endOfDocument)
        engine.layoutIfNeeded()
    }
    override func tearDown() {
        engine.resignFirstResponder()
        window.isHidden = true; window = nil; engine = nil
        super.tearDown()
    }

    private func position(_ offset: Int) -> UITextPosition {
        engine.position(from: engine.beginningOfDocument, offset: offset)!
    }
    private func canonical(_ range: UITextRange) -> NSRange {
        let start = engine.offset(from: engine.beginningOfDocument, to: range.start)
        return NSRange(location: start, length: engine.offset(from: range.start, to: range.end))
    }

    /// The display styles TextKit 2 will draw, read the way the device dump read them: the engine's
    /// block layouts through their layout managers' rendering attributes. Per block, block-local.
    private func renderedDisplayStyles() -> [String] {
        guard let stack = engine.value(forKey: "id_blockStack") as? NSObject,
              let layouts = stack.value(forKey: "blockLayouts") as? [NSObject] else { return ["<no layouts>"] }
        var result: [String] = []
        for (index, layout) in layouts.enumerated() {
            guard let manager = layout.value(forKey: "layoutManager") as? NSTextLayoutManager,
                  let content = manager.textContentManager else { continue }
            manager.enumerateRenderingAttributes(from: manager.documentRange.location, reverse: false) { manager, attributes, range in
                if let style = attributes[TGIDObservingBlockTextView.tgid_textAlternativesDisplayStyleKey()] {
                    let start = content.offset(from: manager.documentRange.location, to: range.location)
                    let end = content.offset(from: manager.documentRange.location, to: range.endLocation)
                    result.append("block\(index) \(start)..<\(end) style=\(style)")
                }
                return true
            }
        }
        return result
    }

    func test_anAcceptedCorrectionIsAnnotatedForTheTapAndRenderedAsACorrection() {
        engine.insertText("the", alternatives: ["teh"], style: .none)
        XCTAssertEqual(engine.attributedBlocks.first?.string, "hello the", "the text landed through the gate")
        var alternatives: AnyObject?
        let range = uikitCallbacks(engine).range(withTextAlternatives: &alternatives, at: position(7))
        XCTAssertNotNil(range, "the tap finds alternatives inside the word")
        XCTAssertEqual(range.map(canonical), NSRange(location: 6, length: 3))
        XCTAssertEqual((alternatives as? NSObject)?.value(forKey: "primaryString") as? String, "the")
        XCTAssertEqual((alternatives as? NSObject)?.value(forKey: "alternativeStrings") as? [String], ["teh"])
        XCTAssertEqual(renderedDisplayStyles(), ["block0 6..<9 style=0"],
                       "the controller's own style for a normal correction, mirrored as a rendering attribute")
    }

    func test_aCaretParkedRightAfterTheWordStillFindsIt() {
        engine.insertText("the", alternatives: ["teh"], style: .none)
        var alternatives: AnyObject?
        let range = uikitCallbacks(engine).range(withTextAlternatives: &alternatives, at: position(9))
        XCTAssertEqual(range.map(canonical), NSRange(location: 6, length: 3))
        XCTAssertNotNil(alternatives)
    }

    func test_aLowConfidenceCorrectionGetsTheOtherStyle() {
        engine.insertText("the", alternatives: ["teh"], style: .lowConfidence)
        XCTAssertEqual(renderedDisplayStyles(), ["block0 6..<9 style=1"])
    }

    func test_removingTheAnnotationClearsBothTheTapsAnswerAndTheUnderline() {
        engine.insertText("the", alternatives: ["teh"], style: .none)
        var alternatives: AnyObject?
        guard let range = uikitCallbacks(engine).range(withTextAlternatives: &alternatives, at: position(7)) else { return XCTFail("no range") }
        engine.removeAnnotation(TGIDObservingBlockTextView.tgid_textAlternativesKey(), for: range)
        engine.removeAnnotation(TGIDObservingBlockTextView.tgid_textAlternativesDisplayStyleKey(), for: range)
        XCTAssertNil(uikitCallbacks(engine).range(withTextAlternatives: &alternatives, at: position(7)))
        XCTAssertEqual(renderedDisplayStyles(), [])
    }

    func test_removeAlternativesForCurrentWordClearsTheWordUnderTheCaret() {
        engine.insertText("the", alternatives: ["teh"], style: .none)
        engine.selectedTextRange = engine.textRange(from: position(8), to: position(8))
        uikitCallbacks(engine).removeAlternativesForCurrentWord()
        var alternatives: AnyObject?
        XCTAssertNil(uikitCallbacks(engine).range(withTextAlternatives: &alternatives, at: position(7)))
        XCTAssertEqual(renderedDisplayStyles(), [])
    }

    func test_anAnnotatedReplacementCarriesItsAlternatives() {
        let attributes: [NSAttributedString.Key: Any] = [
            TGIDObservingBlockTextView.tgid_textAlternativesDisplayStyleKey(): 0,
        ]
        let whole = engine.textRange(from: position(0), to: position(5))!   // "hello"
        uikitCallbacks(engine).replace(whole, withAnnotatedString: NSAttributedString(string: "hallo", attributes: attributes),
                       relativeReplacementRange: NSRange(location: 0, length: 5))
        XCTAssertEqual(engine.attributedBlocks.first?.string, "hallo ")
        XCTAssertEqual(renderedDisplayStyles(), ["block0 0..<5 style=0"])
    }

    func test_aTextWithoutAlternativesAnswersNothing() {
        var alternatives: AnyObject?
        XCTAssertNil(uikitCallbacks(engine).range(withTextAlternatives: &alternatives, at: position(2)))
        XCTAssertEqual(renderedDisplayStyles(), [])
    }

    /// The whole editor: the correction lands in the model as plain text — the annotation is not a
    /// model attribute — and the gate saw it.
    func test_throughTheEditorTheModelHoldsThePlainWord() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window.addSubview(editor)
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello ")]))])
        editor.layoutIfNeeded()
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 6, length: 0)
        editor.engine.insertText("the", alternatives: ["teh"], style: .none)
        XCTAssertEqual(editor.document.blocks[0].asParagraph?.runs.map(\.text).joined(), "hello the")
        var alternatives: AnyObject?
        let at = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 7)!
        XCTAssertNotNil(uikitCallbacks(editor.engine).range(withTextAlternatives: &alternatives, at: at))
        editor.removeFromSuperview()
    }
}
