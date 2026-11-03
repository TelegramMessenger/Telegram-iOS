#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

// Controller-run LIVE integration probe: does the real private UITextCheckingController,
// hosted with a real DocumentCanvasView as its client, get DRIVEN and flag a misspelling
// through the perform-bridged UITextRange path? (This is the one thing unit tests + the
// standalone spike couldn't confirm: the canvas-as-client bridging under real driving.)
final class NativeTextCheckingLiveTests: XCTestCase {
    private func spin(_ s: TimeInterval) {
        let e = Date().addingTimeInterval(s)
        while Date() < e { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02)) }
    }

    func test_liveController_flagsMisspellingViaCanvasClient() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"),
            runs: [TextRun(text: "helllo wrold today")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()

        v.installNativeCheckingIfNeeded()
        XCTAssertNotNil(v.nativeChecker, "NativeTextChecker did not install (private class missing?)")
        spin(2.5)                                   // async textChecker load
        v.setCaret(global: 1)                       // caret at the start ("helllo")
        v.setCaret(global: 8)                       // move past "helllo" (0..6 region-local → global 1..7) → checks it
        spin(1.0)
        let ranges = Set((v.spellResults[BlockID("p")]?.ranges ?? []).map { $0.range })
        XCTAssertTrue(ranges.contains(NSRange(location: 0, length: 6)),
            "leaving 'helllo' must flag it via the selection-driven driver")
    }
}
#endif
