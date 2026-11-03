import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// A container's own lines are not its children, and `ContainerContents` is where that lives.
///
/// A quote's span ENDS with its author line and a details' span BEGINS with its title, so "the
/// span's first role" and "the span's last role" are not the first and last CHILD. Rules written
/// against that assumption broke six times across two rungs — an empty code block counted as an
/// empty child, a quote judged covered because its only child's atom was, a caret landing on the
/// span's first primary which was a table CELL, a quote's author line taken for the block after a
/// table, and settle destroying a folded details because its title read as an orphan.
///
/// These pin the model's answers rather than any one rule's, so the next rule cannot re-derive them.
@available(iOS 18.4, *)
final class EngineContainerContentsTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func quote(_ id: String, _ children: [Block], author: String = "") -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children,
                               author: author.isEmpty ? [] : [TextRun(text: author)]))
    }
    private func details(_ id: String, title: String, _ children: [Block], expanded: Bool = true) -> Block {
        .details(DetailsBlock(id: BlockID(id), title: title.isEmpty ? [] : [TextRun(text: title)],
                              children: children, expanded: expanded))
    }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    /// The role index of the container's own line of `kind`, which is where these tests start.
    private func roleIndex(ofKind kind: SecondaryRegionKind) -> Int {
        let found = editor.currentRoles.firstIndex { $0.secondaryKind == kind }
        XCTAssertNotNil(found, "no \(kind) role among \(editor.currentRoles.count) roles")
        return found ?? 0
    }

    // MARK: - The span's edges are the container's own lines, not its children

    func test_aQuotesSpanEndsWithItsAuthorLineNotItsLastChild() {
        load([quote("q", [para("a", "one"), para("b", "two")], author: "Someone")])
        let author = roleIndex(ofKind: .blockQuoteAuthor)
        let contents = editor.contents(of: BlockID("q"), around: author)

        XCTAssertEqual(contents.span.upperBound, author, "the span ends with the author line")
        XCTAssertEqual(contents.trailingOwnedLine, author)
        XCTAssertNil(contents.leadingOwnedLine, "a quote owns no line above its children")
        XCTAssertEqual(contents.ownedLines, [author])
        XCTAssertEqual(contents.units.count, 2, "two children, and the author is not one of them")
        XCTAssertEqual(contents.lastChildRole, author - 1, "the last CHILD is the role before the line")
        XCTAssertNotEqual(contents.lastChildRole, contents.span.upperBound,
                          "the distinction this whole type exists for")
    }

    func test_aDetailsSpanBeginsWithItsTitleNotItsFirstChild() {
        load([details("d", title: "Notes", [para("a", "one"), para("b", "two")])])
        let title = roleIndex(ofKind: .detailsTitle)
        let contents = editor.contents(of: BlockID("d"), around: title)

        XCTAssertEqual(contents.span.lowerBound, title, "the span begins with the title")
        XCTAssertEqual(contents.leadingOwnedLine, title)
        XCTAssertNil(contents.trailingOwnedLine, "a details owns no line below its body")
        XCTAssertEqual(contents.ownedLines, [title])
        XCTAssertEqual(contents.units.count, 2, "two children, and the title is not one of them")
        XCTAssertEqual(contents.firstChildRole, title + 1)
        XCTAssertNotEqual(contents.firstChildRole, contents.span.lowerBound,
                          "the mirror of the quote case, at the other end")
    }

    /// The contrast that proves the accessors read the document rather than returning a constant: a
    /// quote owning NO line has its first child at the span's start and its last child at its end.
    ///
    /// Getting such a quote takes an EMPTY one. Author-line presence is keyed on content, not on the
    /// author text — "any PRIMARY engine block within the quote is non-empty" — so a quote with a
    /// non-empty child carries an author-line ROLE whether or not anybody typed an attribution.
    func test_aQuoteThatOwnsNoLineHasItsChildrenAtBothEndsOfItsSpan() {
        load([quote("q", [para("a", "")])])
        let child = editor.currentRoles.firstIndex { $0.containerDepth == 1 }!
        let contents = editor.contents(of: BlockID("q"), around: child)
        XCTAssertTrue(contents.ownedLines.isEmpty, "an empty quote has no author line to own")
        XCTAssertEqual(contents.firstChildRole, contents.span.lowerBound)
        XCTAssertEqual(contents.lastChildRole, contents.span.upperBound)
        XCTAssertNil(contents.leadingOwnedLine)
        XCTAssertNil(contents.trailingOwnedLine)
    }

    /// …and the same quote with non-empty content DOES own a line, which is the other half of the
    /// contrast: the accessors track the document, not the container kind.
    func test_aQuoteWithContentOwnsAnAuthorLineEvenWithNoAttributionTyped() {
        load([quote("q", [para("a", "one")])])
        let author = roleIndex(ofKind: .blockQuoteAuthor)
        let contents = editor.contents(of: BlockID("q"), around: author)
        XCTAssertEqual(contents.ownedLines, [author])
        XCTAssertEqual(contents.trailingOwnedLine, author)
        XCTAssertNotEqual(contents.lastChildRole, contents.span.upperBound)
    }

    // MARK: - A folded details is a container with NO primary

    /// Its body lives in the shape, off the engine's axis, so its span is exactly one role — its own
    /// title. Three rules read that as damage before it was spelled here: settle rewrote the title to
    /// a paragraph and dropped the ONLY copy of the body, coverage reported it never covered, and the
    /// boundary Backspace removed a details' last empty child.
    func test_aFoldedDetailsHoldsNothingButItsOwnTitle() {
        load([details("d", title: "Notes", [para("a", "one")], expanded: false)])
        let title = roleIndex(ofKind: .detailsTitle)
        let contents = editor.contents(of: BlockID("d"), around: title)

        XCTAssertEqual(contents.span, title...title, "one role, and it is the title")
        XCTAssertTrue(contents.units.isEmpty, "no children on the engine's axis")
        XCTAssertEqual(contents.ownedLines, [title])
        XCTAssertEqual(contents.leadingOwnedLine, title)
        XCTAssertEqual(contents.trailingOwnedLine, title, "with no children it is both")
        XCTAssertTrue(contents.holdsContent, "the title is authored content, and it is all there is")
    }

    // MARK: - The two emptiness questions are the contents', not a caller's

    func test_aDetailsWithATypedTitleIsNotEmptyHoweverEmptyItsBody() {
        load([details("d", title: "Notes", [para("a", "")])])
        let title = roleIndex(ofKind: .detailsTitle)
        let contents = editor.contents(of: BlockID("d"), around: title)
        XCTAssertTrue(contents.isEmpty, "its one child IS an empty bare paragraph")
        XCTAssertFalse(contents.ownedLinesAreEmpty, "but the title is content the user typed")
    }

    func test_aDetailsWithAnEmptyTitleAndAnEmptyBodyIsEmptyBothWays() {
        load([details("d", title: "", [para("a", "")])])
        let title = roleIndex(ofKind: .detailsTitle)
        let contents = editor.contents(of: BlockID("d"), around: title)
        XCTAssertTrue(contents.isEmpty)
        XCTAssertTrue(contents.ownedLinesAreEmpty)
    }

    /// A quote's AUTHOR is a field, not content: legacy un-quotes over one without asking, so a
    /// typed author must NOT keep an otherwise-empty quote alive.
    func test_aQuotesAuthorLineNeverKeepsItAlive() {
        load([quote("q", [para("a", "")], author: "Someone")])
        let author = roleIndex(ofKind: .blockQuoteAuthor)
        let contents = editor.contents(of: BlockID("q"), around: author)
        XCTAssertTrue(contents.isEmpty)
        XCTAssertTrue(contents.ownedLinesAreEmpty, "an attribution is metadata, not content")
    }

    // MARK: - Ownership is keyed on the container, never on the kind

    /// A CHILD's own second line — a code block's language, a media caption — belongs to that child's
    /// unit, not to the container around it. Keying on `secondaryKind != nil` alone would take it.
    func test_aChildsOwnSecondLineIsNotTheContainersOwnedLine() {
        load([quote("q", [.code(CodeBlock(id: BlockID("c"), language: "swift",
                                          runs: [TextRun(text: "let x = 1")]))], author: "Someone")])
        let author = roleIndex(ofKind: .blockQuoteAuthor)
        let contents = editor.contents(of: BlockID("q"), around: author)
        XCTAssertEqual(contents.ownedLines, [author], "only the author line — not the code's language line")
        XCTAssertEqual(contents.units.count, 1, "the code block and its language line are ONE child")
        XCTAssertTrue(contents.units.first?.contains(roleIndex(ofKind: .codeLanguage)) ?? false,
                      "the language line sits inside its child's unit")
    }
}
