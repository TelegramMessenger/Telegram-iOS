import XCTest
@testable import RichTextEditorCore

/// `isInlineMergeable` used to accept EVERY heading level, so a fragment whose first (or only) block
/// is a heading was folded into a split half of the host paragraph — and the fold keeps the HOST's
/// style. Pasting a copied rich message into the (body) chat composer therefore retyped its heading as
/// body text: the reported "headings are not pasted".
///
/// The rule now distinguishes the two directions, which are not symmetric:
///   - a plain BODY fragment paragraph carries no block structure, so folding it loses nothing and it
///     must keep folding (pasting text into a heading has to stay a heading);
///   - a HEADING fragment paragraph loses its style when folded, so it only folds into a host that is
///     already that same style, and otherwise stands as its own block.
final class DocumentFragmentHeadingPasteTests: XCTestCase {
    private func para(_ id: String, _ text: String, style: ParagraphStyleName = .body) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: style, runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    private func styles(_ document: Document) -> [ParagraphStyleName?] {
        document.blocks.map { block in
            if case .paragraph(let p) = block { return p.style } else { return nil }
        }
    }

    private func texts(_ document: Document) -> [String] {
        document.blocks.map { block in
            if case .paragraph(let p) = block { return p.text } else { return "?" }
        }
    }

    /// THE reported case: the empty composer, pasting a copied rich message that opens with a heading.
    func test_headingOnlyFragment_pastedIntoAnEmptyBodyParagraph_staysAHeading() throws {
        let host = Document(blocks: [self.para("host", "")])
        let fragment = Document(blocks: [self.para("f", "Title", style: .heading1)])

        let result = try XCTUnwrap(host.insertingFragment(fragment, atGlobal: 1))
        XCTAssertEqual(self.styles(result.document), [.heading1], "the pasted heading must not be retyped as body")
        XCTAssertEqual(self.texts(result.document), ["Title"])
    }

    /// The same, multi-block: heading first, then body — the shape a copied rich message actually has.
    func test_fragmentStartingWithAHeading_keepsIt() throws {
        let host = Document(blocks: [self.para("host", "")])
        let fragment = Document(blocks: [
            self.para("f0", "Title", style: .heading1),
            self.para("f1", "Body text")
        ])

        let result = try XCTUnwrap(host.insertingFragment(fragment, atGlobal: 1))
        XCTAssertEqual(self.styles(result.document), [.heading1, .body])
        XCTAssertEqual(self.texts(result.document), ["Title", "Body text"])
    }

    /// A heading at the END of the fragment is the mirror case — it used to fold into the host's tail.
    func test_fragmentEndingWithAHeading_keepsIt() throws {
        let host = Document(blocks: [self.para("host", "")])
        let fragment = Document(blocks: [
            self.para("f0", "Body text"),
            self.para("f1", "Trailing title", style: .heading2)
        ])

        let result = try XCTUnwrap(host.insertingFragment(fragment, atGlobal: 1))
        XCTAssertEqual(self.styles(result.document), [.body, .heading2])
        XCTAssertEqual(self.texts(result.document), ["Body text", "Trailing title"])
    }

    /// Pasted mid-paragraph, a heading splits the host rather than dissolving into it. Both halves keep
    /// the host's style; nothing is lost either way.
    func test_headingPastedMidParagraph_splitsTheHost() throws {
        let host = Document(blocks: [self.para("host", "abcdef")])
        let fragment = Document(blocks: [self.para("f", "Title", style: .heading3)])

        // Text starts at global 1, so global 4 is between "abc" and "def".
        let result = try XCTUnwrap(host.insertingFragment(fragment, atGlobal: 4))
        XCTAssertEqual(self.styles(result.document), [.body, .heading3, .body])
        XCTAssertEqual(self.texts(result.document), ["abc", "Title", "def"])
    }

    /// The OTHER direction must not change: plain text pasted into a heading stays in the heading.
    /// A body fragment carries no structure of its own, so folding it is lossless.
    func test_bodyFragmentPastedIntoAHeading_staysInTheHeading() throws {
        let host = Document(blocks: [self.para("host", "Title", style: .heading1)])
        let fragment = Document(blocks: [self.para("f", " more")])

        let result = try XCTUnwrap(host.insertingFragment(fragment, atGlobal: 6))
        XCTAssertEqual(self.styles(result.document), [.heading1], "one block still — the paste folded in")
        XCTAssertEqual(self.texts(result.document), ["Title more"])
    }

    /// A heading folded into a host of the SAME style is lossless, so it still folds — pasting an H1 in
    /// the middle of an H1 must not shatter it into three blocks.
    func test_headingPastedIntoTheSameHeadingStyle_stillFolds() throws {
        let host = Document(blocks: [self.para("host", "abcdef", style: .heading1)])
        let fragment = Document(blocks: [self.para("f", "XY", style: .heading1)])

        let result = try XCTUnwrap(host.insertingFragment(fragment, atGlobal: 4))
        XCTAssertEqual(self.styles(result.document), [.heading1])
        XCTAssertEqual(self.texts(result.document), ["abcXYdef"])
    }

    /// Plain body → body is the overwhelmingly common paste and must be byte-unchanged.
    func test_bodyIntoBody_stillFolds() throws {
        let host = Document(blocks: [self.para("host", "abcdef")])
        let fragment = Document(blocks: [self.para("f", "XY")])

        let result = try XCTUnwrap(host.insertingFragment(fragment, atGlobal: 4))
        XCTAssertEqual(self.styles(result.document), [.body])
        XCTAssertEqual(self.texts(result.document), ["abcXYdef"])
        XCTAssertEqual(result.caret, 6, "caret lands after the inserted text")
    }
}
