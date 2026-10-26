import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// Edit-menu support for the engine editor.
///
/// The engine avoids `UITextInteraction`, and the legacy canvas's own edit-menu file records what
/// that costs: "A custom UITextInput view that avoids UITextInteraction does NOT get Look Up / Share
/// / a Format submenu for free." The engine had NONE of that machinery — no `UIEditMenuInteraction`,
/// no presentation, and `contextMenuItemsProvider` stored but never read — so links and inline code
/// were implemented and unreachable.
///
/// Menu CONTENT is separated from menu PRESENTATION here for the same reason the legacy separates
/// them: a presented `UIEditMenuInteraction` cannot be driven or observed from a unit test, but the
/// content assembly can.
final class EngineEditMenuTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "alpha beta")]))])
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func selectAll() {
        let whole = editor.engine.textRange(from: editor.engine.beginningOfDocument,
                                            to: editor.engine.endOfDocument)!
        editor.engine.selectedTextRange = whole
    }

    private func collapseSelection() {
        let start = editor.engine.beginningOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: start, to: start)
    }

    private func titles(_ elements: [UIMenuElement]) -> [String] { elements.map(\.title) }

    private let systemSuggested: [UIMenuElement] = [UIAction(title: "Copy") { _ in }]

    /// The whole point of the rung: Telegram's Format items reach the menu.
    func test_theHostsFormatItemsReachTheMenuOverASelection() {
        editor.contextMenuItemsProvider = { defaults in
            defaults + [UIMenu(title: "Format", children: [UIAction(title: "Link") { _ in }])]
        }
        selectAll()

        let elements = editor.editMenuElements(suggestedActions: systemSuggested)

        XCTAssertTrue(titles(elements).contains("Format"),
                      "the composer's Format menu did not reach the engine editor's edit menu")
    }

    /// The system's own items must SURVIVE, not be replaced — the provider is handed the defaults and
    /// returns a superset. Losing Copy/Paste would be a worse regression than the missing Format menu.
    func test_theSystemsOwnItemsSurvive() {
        editor.contextMenuItemsProvider = { defaults in
            defaults + [UIAction(title: "Format") { _ in }]
        }
        selectAll()

        XCTAssertTrue(titles(editor.editMenuElements(suggestedActions: systemSuggested)).contains("Copy"),
                      "the system's suggested actions were dropped")
    }

    /// THE CONTROL. With no provider the menu must be exactly the system's — otherwise the test above
    /// could be passing on something this code invented rather than on the host's contribution.
    func test_control_withNoProviderTheMenuIsExactlyTheSystems() {
        selectAll()
        XCTAssertEqual(titles(editor.editMenuElements(suggestedActions: systemSuggested)), ["Copy"])
    }

    /// A collapsed caret is not a formatting target; the legacy canvas gates its custom items on
    /// `selFrom < selTo` for the same reason.
    func test_aCollapsedSelectionGetsNoHostItems() {
        editor.contextMenuItemsProvider = { defaults in
            defaults + [UIAction(title: "Format") { _ in }]
        }
        collapseSelection()

        XCTAssertFalse(titles(editor.editMenuElements(suggestedActions: systemSuggested)).contains("Format"),
                       "formatting was offered for a caret with nothing selected")
    }
}
