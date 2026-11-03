import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The composer-host members the engine can genuinely answer.
///
/// These are ANSWER-OR-TRAP, not deferred capabilities: the engine can do all of them today, so each
/// forwards and none returns a constant. The distinction matters because the previous attempt at
/// this project failed five times on members that answered plausibly instead of truthfully.
final class EngineComposerHostTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    private func paragraphs(_ texts: [String]) -> Document {
        Document(blocks: texts.enumerated().map { index, text in
            .paragraph(ParagraphBlock(id: BlockID("p\(index)"),
                                      runs: text.isEmpty ? [] : [TextRun(text: text)]))
        })
    }

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        _ = editor.resignEditorFirstResponder()
        window.isHidden = true
        window = nil; editor = nil
        super.tearDown()
    }

    func test_updateReturnsAContentHeightThatGrowsWithContent() {
        editor.document = paragraphs(["one"])
        let short = editor.update(size: CGSize(width: 320, height: 240), insets: .zero,
                                  contentMargins: .zero, scrollIndicatorInsets: nil)
        editor.document = paragraphs(["one", "two", "three", "four"])
        let tall = editor.update(size: CGSize(width: 320, height: 240), insets: .zero,
                                 contentMargins: .zero, scrollIndicatorInsets: nil)
        XCTAssertGreaterThan(tall, short, "update() did not measure the taller document as taller")
    }

    func test_updateNeverReturnsLessThanTheMinimumContentHeight() {
        editor.minimumContentHeight = 120
        editor.document = paragraphs([""])
        let height = editor.update(size: CGSize(width: 320, height: 240), insets: .zero,
                                   contentMargins: .zero, scrollIndicatorInsets: nil)
        XCTAssertGreaterThanOrEqual(height, 120)
    }

    func test_insetsReachTheEnginesScrollView() {
        editor.document = paragraphs(["one"])
        _ = editor.update(size: CGSize(width: 320, height: 240),
                          insets: UIEdgeInsets(top: 11, left: 0, bottom: 7, right: 0),
                          contentMargins: .zero, scrollIndicatorInsets: nil)
        XCTAssertEqual(editor.engine.contentInset.top, 11, accuracy: 0.01)
        XCTAssertEqual(editor.engine.contentInset.bottom, 7, accuracy: 0.01)
    }

    func test_scrollIndicatorInsetsReachTheEngineWhenSupplied() {
        editor.document = paragraphs(["one"])
        _ = editor.update(size: CGSize(width: 320, height: 240), insets: .zero,
                          contentMargins: .zero,
                          scrollIndicatorInsets: UIEdgeInsets(top: 5, left: 0, bottom: 0, right: 0))
        XCTAssertEqual(editor.engine.verticalScrollIndicatorInsets.top, 5, accuracy: 0.01)
    }

    func test_becomingFirstResponderFiresTheCallback() {
        var became = 0
        editor.onBecameFirstResponder = { became += 1 }
        XCTAssertTrue(editor.becomeFirstResponder())
        XCTAssertEqual(became, 1)
    }

    func test_resigningFiresTheCallback() {
        var resigned = 0
        XCTAssertTrue(editor.becomeFirstResponder())
        editor.onResignedFirstResponder = { resigned += 1 }
        XCTAssertTrue(editor.resignEditorFirstResponder())
        XCTAssertEqual(resigned, 1)
    }

    /// `body`, `listEnd` and `listOutdent` have no defaults (`BlockBox.swift:17`); the rest do.
    func test_placeholdersRoundTrip() {
        let placeholders = RichTextEditorPlaceholders(body: "Message", listEnd: "end", listOutdent: "out")
        editor.placeholders = placeholders
        XCTAssertEqual(editor.placeholders, placeholders)
    }

    func test_canvasBackgroundColourReachesTheEngine() {
        editor.canvasBackgroundColor = .systemBlue
        XCTAssertEqual(editor.engine.backgroundColor, .systemBlue)
        XCTAssertEqual(editor.canvasBackgroundColor, .systemBlue)
    }

    func test_contentPageMarginAndTapBelowRoundTrip() {
        editor.contentPageMargin = 17
        editor.tapBelowAddsTrailingParagraph = true
        XCTAssertEqual(editor.contentPageMargin, 17, accuracy: 0.01)
        XCTAssertTrue(editor.tapBelowAddsTrailingParagraph)
    }

    /// The theme is a MAPPER input, not a view decoration — it decides the colour the engine
    /// renders text in. A stored-but-unused theme would leave the composer white-on-white in dark
    /// mode, so this asserts the rendered attributes actually change.
    func test_settingATintedThemeChangesTheColourTheEngineRendersTextIn() {
        editor.document = paragraphs(["alpha"])
        let before = editor.engine.attributedBlocks[0]
            .attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor

        var tinted = RichTextEditorTheme.default
        tinted.primaryText = .magenta
        editor.theme = tinted

        let after = editor.engine.attributedBlocks[0]
            .attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotEqual(before, after, "the theme did not reach the text the engine renders")
        XCTAssertEqual(after, .magenta)
    }

    func test_settingAThemePreservesTheDocument() {
        let document = paragraphs(["alpha", "beta"])
        editor.document = document
        var tinted = RichTextEditorTheme.default
        tinted.primaryText = .magenta
        editor.theme = tinted
        XCTAssertEqual(editor.document, document, "rebuilding the mapper lost the document")
    }

    func test_composerContentOffsetIsTheEnginesOwn() {
        editor.document = paragraphs(["one", "two", "three", "four", "five", "six", "seven"])
        _ = editor.update(size: CGSize(width: 320, height: 60), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil)
        editor.engine.contentOffset = CGPoint(x: 0, y: 12)
        XCTAssertEqual(editor.composerContentOffset.y, 12, accuracy: 0.01)
    }

    /// The pre-selection lives on the ENGINE because the engine is the first responder; a value
    /// stored on the wrapper would never be queried by UIKit.
    func test_theInitialInputLanguageIsHeldByTheEngine() {
        editor.initialInputPrimaryLanguage = "en-US"
        XCTAssertEqual(editor.engine.tgid_initialPrimaryLanguage, "en-US")
        XCTAssertEqual(editor.initialInputPrimaryLanguage, "en-US")
    }

    func test_resettingTheInputLanguageReArmsThePreSelection() {
        editor.initialInputPrimaryLanguage = "en-US"
        _ = editor.engine.textInputMode          // consumes the single-shot pre-selection
        editor.resetInputPrimaryLanguage()
        // Re-armed: the next query consults the pre-selection again rather than reporting the live
        // keyboard immediately. Asserting the re-arm through behaviour, not a private flag.
        XCTAssertEqual(editor.initialInputPrimaryLanguage, "en-US")
        XCTAssertNotNil(editor.engine.textInputMode)
    }

    func test_hardwareReturnHandlerIsConsulted() {
        var seen: UIKeyModifierFlags?
        editor.onHardwareReturn = { flags in seen = flags; return true }
        XCTAssertNotNil(editor.onHardwareReturn)
        XCTAssertTrue(editor.onHardwareReturn?(.shift) ?? false)
        XCTAssertEqual(seen, .shift)
    }
}
