import XCTest
import UIKit
import TelegramCore
import TelegramPresentationData
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30):** rich text pasted from another app keeps its TEXT COLOUR and its
/// HIGHLIGHT in the engine composer: RTF `"red"` in red on a yellow background shows red on yellow, and
/// still does after a theme change to dark (the theme's text colour never reaches it). The model cannot
/// carry a colour, so the message sent is plain — the composer shows the user something that is not sent.
/// Legacy control: the legacy composer's storage takes the theme's colour and no background. The engine's
/// own presentation verifier does not see it (`presentationDrift` is clean), so the fuzz never did.
///
/// **How it was seen:** p20 external-paste sweep, reading the engine storage's attributes after the paste.
///
/// **Suspected:** `IDInlineTextStyleResolver importAttributedString:` keeps every attribute it does not
/// map (`result = attributes.mutableCopy`, only fonts and the four traits are rebuilt), so
/// `NSForegroundColorAttributeName` and `NSBackgroundColorAttributeName` survive; the host's presentation
/// re-derivation (`normalisePresentation`, `rerenderPresentation`) does not reset a colour it did not set.
/// Fix-agnostic: the pasted runs must end up with the theme's text colour and no background.
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessPastedForeignColourTests: XCTestCase {
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        self.driver.host.updatePresentationInterfaceState { $0.updatedTheme(defaultPresentationTheme) }
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    static func coloured() -> Data {
        let text = NSMutableAttributedString(string: "plain ")
        text.append(NSAttributedString(string: "red", attributes: [.foregroundColor: UIColor.red, .backgroundColor: UIColor.yellow]))
        text.append(NSAttributedString(string: " tail"))
        return try! text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    private func attributes(of word: String) -> [NSAttributedString.Key: Any]? {
        for block in self.driver.editor.engine.attributedBlocks {
            let range = (block.string as NSString).range(of: word)
            if range.location != NSNotFound {
                return block.attributes(at: range.location, effectiveRange: nil)
            }
        }
        return nil
    }

    private func pasteColoured() {
        self.driver.arrange(ChatInputContent())
        UIPasteboard.general.items = [["public.rtf": Self.coloured()]]
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.5)
    }

    private func assertThemeColoured(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let red = self.attributes(of: "red"), let plain = self.attributes(of: "plain") else {
            XCTFail("precondition: the paste landed: \(fuzzEscaped(self.driver.viewText()))", file: file, line: line)
            return
        }
        let redColour = red[.foregroundColor] as? UIColor
        let plainColour = plain[.foregroundColor] as? UIColor
        XCTAssertEqual(redColour, plainColour, "\(label): the pasted word keeps its foreign text colour \(String(describing: redColour)) (the theme's is \(String(describing: plainColour)))", file: file, line: line)
        XCTAssertNil(red[.backgroundColor], "\(label): the pasted word keeps its foreign highlight \(String(describing: red[.backgroundColor]))", file: file, line: line)
    }

    func testPastedTextTakesTheThemesColour() {
        self.pasteColoured()
        self.assertThemeColoured("after the paste")
    }

    func testPastedTextFollowsAThemeChange() {
        self.pasteColoured()
        self.driver.host.updatePresentationInterfaceState { $0.updatedTheme(defaultDarkPresentationTheme) }
        self.driver.root.view.setNeedsLayout()
        self.driver.settle(0.3)
        self.assertThemeColoured("after the change to dark")
    }

    /// Control: the model — what is sent — has no colour to carry; it holds the plain text only.
    func testControlTheModelIsPlain() {
        self.pasteColoured()
        XCTAssertEqual(FuzzModel.describe(FuzzModel.normalized(self.driver.model())), "[p body \"plain red tail\"]")
    }

    /// Control: the legacy composer's storage takes the theme's colour and no highlight.
    func testControlLegacyTakesTheThemesColour() throws {
        _ = self.driver.node.resignInputFirstResponder()
        let arranged = try HarnessLegacy.arrange(HarnessContent.plainText(""))
        defer { HarnessLegacy.restore(arranged) }
        UIPasteboard.general.items = [["public.rtf": Self.coloured()]]
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = arranged.textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(arranged.root, seconds: 0.5)
        let text = arranged.textView.attributedText!
        let range = (text.string as NSString).range(of: "red")
        XCTAssertNotEqual(range.location, NSNotFound, "precondition: the paste landed: \(fuzzEscaped(text.string))")
        guard range.location != NSNotFound else { return }
        let attributes = text.attributes(at: range.location, effectiveRange: nil)
        XCTAssertNotEqual(attributes[.foregroundColor] as? UIColor, UIColor.red)
        XCTAssertNil(attributes[.backgroundColor])
    }
}
