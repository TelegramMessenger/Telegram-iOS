import XCTest
import UIKit
import TelegramCore
import TextFormat
import AccountContext
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30; CORRUPTS WHAT IS SENT):** Format ▸ Spoiler over a formula that is ALONE
/// in its paragraph hides it in the composer and the model keeps it (`[p [sp,f="E=mc^2"]"E=mc^2"]` — a
/// spoiler stays model state on an inline atom, p13 decision), but the message is sent on the rich route
/// with the formula as a standalone `InstantPageBlock.formula(latex:)` (`instantPageBlocks`,
/// `standaloneFormulaLatex`, TelegramCore `ChatInputContentInstantPage.swift`), which has no room for any
/// inline attribute: the formula the user hid is sent VISIBLE, and editing the message shows it unspoilered.
/// The same spoilered formula next to text (a `RichText` concat: `.textSpoiler(.formula)`) is sent hidden
/// (control).
///
/// **How it was seen:** the p20 send-path oracle in the edited-content fuzz, seeds 28 (inside a quote) and 41.
///
/// **Suspected:** `standaloneFormulaLatex` treats a spoilered formula as standalone; either it must not
/// (send it as a paragraph `.textSpoiler(.formula)`), or the block needs a spoiler. Fix-agnostic: red until
/// what is sent, loaded back for editing, equals the model.
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessSendPathFormulaSpoilerTests: XCTestCase {
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        HarnessEdited.installFormulaRenderer(on: self.driver.host)
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        self.driver.host.panel.formulaRenderer = nil
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    private func spoiler(_ content: ChatInputContent, _ range: NSRange) -> ChatInputContent {
        self.driver.arrange(content)
        self.driver.setViewSelection(range)
        self.driver.settle(0.1)
        self.driver.format(.spoiler)
        self.driver.settle(0.2)
        return self.driver.model()
    }

    private func spoileredFormulaCount(_ content: ChatInputContent) -> Int {
        return content.blocks.reduce(0) { total, block in
            if case let .paragraph(p) = block {
                return total + p.runs.filter { $0.attributes.formula != nil && $0.attributes.spoiler }.count
            }
            return total
        }
    }

    /// `[p "Top line"] [p formula] [p "End line"]`: the formula is ONE attachment character at 9.
    func testASpoileredStandaloneFormulaIsSentHidden() {
        let start = ChatInputContent(blocks: [HarnessEdited.paragraph([HarnessEdited.run("Top line")]), HarnessEdited.paragraph([HarnessEdited.formula("E=mc^2")]), HarnessEdited.paragraph([HarnessEdited.run("End line")])])
        let model = self.spoiler(start, NSRange(location: 9, length: 1))
        XCTAssertEqual(self.spoileredFormulaCount(model), 1, "precondition: the model carries the spoiler: \(HarnessEdited.describe(model))")
        XCTAssertEqual(HarnessSendPath.send(model).route, .rich)
        if let divergence = HarnessSendPath.divergence(model) {
            XCTFail("the spoiler over the formula is not sent: \(divergence.description)")
        }
    }

    /// Control: a spoilered formula beside text is sent hidden.
    func testControlASpoileredInlineFormulaIsSentHidden() {
        let start = ChatInputContent(blocks: [HarnessEdited.paragraph([HarnessEdited.run("Sum "), HarnessEdited.formula("a^2"), HarnessEdited.run(" end")])])
        let model = self.spoiler(start, NSRange(location: 4, length: 1))
        XCTAssertEqual(self.spoileredFormulaCount(model), 1, "precondition: the model carries the spoiler: \(HarnessEdited.describe(model))")
        XCTAssertNil(HarnessSendPath.divergence(model).map(\.description))
    }
}
