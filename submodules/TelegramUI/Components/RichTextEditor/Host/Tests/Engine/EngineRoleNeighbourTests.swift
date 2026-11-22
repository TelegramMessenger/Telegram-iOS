import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// `currentRoles[i ± 1]` answers what is STORED next to a role. Every navigation rule wants what is
/// next to it in the document's STRUCTURE, and the two differ at exactly one place — a container
/// edge — which is where all six defects in this class were found.
///
/// This is the one place the five cases are pinned. Every migrated rule relies on it rather than
/// re-deriving the distinction, which is the whole point of having a type.
@available(iOS 18.4, *)
final class EngineRoleNeighbourTests: XCTestCase {
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
    private func details(_ id: String, title: String, _ children: [Block]) -> Block {
        .details(DetailsBlock(id: BlockID(id), title: [TextRun(text: title)], children: children, expanded: true))
    }
    private func table(_ id: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                          rows: [Row(id: BlockID("\(id)r"),
                                     cells: [Cell(id: BlockID("\(id)c0"), blocks: [para("\(id)p0", "aa")]),
                                             Cell(id: BlockID("\(id)c1"), blocks: [para("\(id)p1", "bb")])])]))
    }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    /// A readable name for a case, so a failure says which case came back rather than printing an
    /// associated value nobody can match against the expectation by eye.
    private func name(_ neighbour: RoleNeighbour) -> String {
        switch neighbour {
        case let .sameLeafContainer(index): return "sameLeafContainer(\(index))"
        case let .sibling(index): return "sibling(\(index))"
        case let .ownLineOfEnclosingContainer(index): return "ownLineOfEnclosingContainer(\(index))"
        case let .outsideContainer(container, beyond):
            return "outsideContainer(\(container.id.rawValue), \(beyond.map(String.init) ?? "nil"))"
        case .documentEdge: return "documentEdge"
        }
    }
    private func firstCell() -> Int { editor.currentRoles.firstIndex { $0.owningTable != nil } ?? -1 }
    private func lastCell() -> Int { editor.currentRoles.lastIndex { $0.owningTable != nil } ?? -1 }

    // MARK: - sameLeafContainer

    func test_theNextCellOfTheSameTableIsTheSameLeafContainer() {
        load([table("t")])
        XCTAssertEqual(name(editor.neighbour(after: firstCell())), "sameLeafContainer(\(firstCell() + 1))")
    }

    func test_aCodeBlocksBodyAfterItsLanguageLineIsTheSameLeafContainer() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")]))])
        guard let language = editor.currentRoles.firstIndex(where: { $0.secondaryKind == .codeLanguage }) else {
            return XCTFail("no language line")
        }
        XCTAssertEqual(name(editor.neighbour(after: language)), "sameLeafContainer(\(language + 1))")
    }

    // MARK: - sibling

    func test_twoTopLevelParagraphsAreSiblings() {
        load([para("a", "one"), para("b", "two")])
        XCTAssertEqual(name(editor.neighbour(after: 0)), "sibling(1)")
        XCTAssertEqual(name(editor.neighbour(before: 1)), "sibling(0)")
    }

    func test_twoChildrenOfTheSameQuoteAreSiblings() {
        load([quote("q", [para("a", "one"), para("b", "two")])])
        XCTAssertEqual(name(editor.neighbour(after: 0)), "sibling(1)")
    }

    /// A TOP-LEVEL table has no enclosing container, so the block after it is a sibling — which is
    /// why today's top-level behaviour falls out of the type instead of needing an exception.
    func test_theBlockAfterATopLevelTableIsASibling() {
        load([table("t"), para("after", "z")])
        let last = lastCell()
        XCTAssertEqual(name(editor.neighbour(after: last)), "sibling(\(last + 1))")
    }

    // MARK: - ownLineOfEnclosingContainer

    func test_aQuotesAuthorLineIsTheContainersOwnLine() {
        load([quote("q", [para("a", "one")], author: "Someone")])
        XCTAssertEqual(name(editor.neighbour(after: 0)), "ownLineOfEnclosingContainer(1)")
    }

    func test_aDetailsTitleAboveItsFirstBodyChildIsTheContainersOwnLine() {
        load([details("d", title: "T", [para("a", "one")])])
        XCTAssertEqual(name(editor.neighbour(before: 1)), "ownLineOfEnclosingContainer(0)")
    }

    // MARK: - outsideContainer

    /// The shape of the reported defect: the role after a table that is a details' last body item is
    /// the block FOLLOWING the details.
    func test_theBlockAfterADetailsIsOutsideItFromItsLastCell() {
        load([details("d", title: "T", [para("a", "one"), table("t")]), para("after", "z")])
        let last = lastCell()
        XCTAssertEqual(name(editor.neighbour(after: last)), "outsideContainer(d, \(last + 1))")
    }

    /// With nothing after the container, `beyond` is nil but the case is still `outsideContainer` —
    /// a rule minting a sibling needs to know WHICH container it is minting into, and that is the
    /// information `documentEdge` would throw away.
    func test_aContainerThatEndsAtTheDocumentsEndStillReportsItsContainer() {
        load([details("d", title: "T", [para("a", "one"), table("t")])])
        XCTAssertEqual(name(editor.neighbour(after: lastCell())), "outsideContainer(d, nil)")
    }

    // MARK: - documentEdge

    /// Only a TOP-LEVEL role reaches this: with no enclosing container there is nothing to report.
    func test_onlyATopLevelRoleReachesTheDocumentEdge() {
        load([para("a", "one")])
        XCTAssertEqual(name(editor.neighbour(after: 0)), "documentEdge")
        XCTAssertEqual(name(editor.neighbour(before: 0)), "documentEdge")
    }

    // MARK: - Neuter

    /// The classifier must be able to be wrong, or this whole table is decoration.
    /// `sameLeafContainer` and `sibling` are the pair most easily confused — the leaf container is
    /// the role's own `containerID` (its table, its code block); a sibling shares an ANCESTOR — so
    /// the neuter targets exactly that distinction rather than something no plausible mistake makes.
    func test_theTableDistinguishesSameLeafContainerFromSibling() {
        load([table("t")])
        let cellToCell = name(editor.neighbour(after: firstCell()))
        load([para("a", "one"), para("b", "two")])
        let paraToPara = name(editor.neighbour(after: 0))
        XCTAssertNotEqual(cellToCell.prefix(6), paraToPara.prefix(6),
                          "two cells of one table and two paragraphs must not classify alike")
    }
}
