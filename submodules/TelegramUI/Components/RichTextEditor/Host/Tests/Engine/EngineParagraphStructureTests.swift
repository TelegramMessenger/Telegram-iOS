import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

final class EngineParagraphStructureTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "alpha")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "beta")])),
        ])
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
        XCTAssertTrue(editor.becomeFirstResponder())
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func firstParagraph() -> ParagraphBlock {
        guard case let .paragraph(p) = editor.document.blocks[0] else {
            fatalError("expected a paragraph")
        }
        return p
    }

    func test_settingAHeadingStyleReachesTheDocument() {
        editor.composerSelectedRange = NSRange(location: 0, length: 0)
        editor.setParagraphStyle(.heading1)
        XCTAssertEqual(firstParagraph().style, .heading1)
    }

    func test_theStyleChangeIsReportedBack() {
        editor.composerSelectedRange = NSRange(location: 0, length: 0)
        editor.setParagraphStyle(.heading1)
        XCTAssertEqual(editor.currentParagraphStyle(), .heading1)
    }

    func test_settingAListMarkerReachesTheDocument() {
        editor.composerSelectedRange = NSRange(location: 0, length: 0)
        editor.setList(.bullet)
        XCTAssertNotNil(firstParagraph().list)
    }

    func test_indentIncreasesListNestingAndOutdentClampsAtZero() {
        editor.composerSelectedRange = NSRange(location: 0, length: 0)
        editor.setList(.bullet)
        editor.indent()
        let indented = firstParagraph().list?.level ?? 0
        XCTAssertGreaterThan(indented, 0)
        editor.outdent(); editor.outdent()
        XCTAssertEqual(firstParagraph().list?.level ?? 0, 0, "outdent did not clamp at zero")
    }

    /// A whole-document re-application must not lose the caret — the user is mid-edit.
    func test_theSelectionSurvivesAStyleChange() {
        editor.composerSelectedRange = NSRange(location: 3, length: 0)
        editor.setParagraphStyle(.heading1)
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 3, length: 0),
                       "the style change collapsed the caret")
    }

    func test_onlyTheSelectedParagraphChangesStyle() {
        editor.composerSelectedRange = NSRange(location: 0, length: 0)
        editor.setParagraphStyle(.heading1)
        guard case let .paragraph(second) = editor.document.blocks[1] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertNotEqual(second.style, .heading1, "the style leaked into the unselected paragraph")
    }
}
