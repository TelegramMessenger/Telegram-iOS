import XCTest
import UIKit
import ObjectiveC
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, merely tapping into the composer (or tapping the caret /
/// a selected word to bring up the edit menu) made iOS show its "“App” would like to paste from
/// “…”" privacy alert whenever the clipboard held another app's content. The user never chose
/// Paste. Whichever button they pressed, the alert also took first responder away, so the
/// keyboard they had tapped for went straight back down.
///
/// **Why.** UIKit polls `canPerformAction(paste:)` whenever it builds the edit menu or the
/// keyboard's paste affordances. The engine view's override asked the host
/// (`tgid_canPasteMediaHandler` → `RichTextEngineEditorView.canPasteMedia` →
/// `ChatTextInputPanelNode.handlePastedMedia(perform: false)`), which READ the clipboard
/// (`data(forPasteboardType:)` for gif/mp4/heics, then `items`). Reading another app's content
/// without a paste gesture is exactly what raises the alert. The legacy backend never asks there.
///
/// **How it was seen.** Driving the harness on K1 (2026-09-22), five times across all three
/// scenarios; setting Settings ▸ Apps ▸ ComposerHarness ▸ Paste from Other Apps to Deny made it
/// stop. A Tier-2 reproduction was written first and could not be made to fail cleanly: while the
/// consent prompt is pending the app's main thread is blocked in the read, so XCUITest cannot
/// snapshot the app at all and the run ends in Bazel's test timeout.
///
/// **Tier 1**, reduced from that Tier-2 reproduction: the defect is the READ, and a read can be
/// counted in-process. The spy swaps UIPasteboard's content accessors for counting forwarders for
/// the length of one `canPerformAction` call; the permission-free queries (`hasStrings`,
/// `hasImages`, `contains(pasteboardTypes:)`) are deliberately not spied on, because answering
/// with them is the fix.
final class HarnessPastePromptTests: XCTestCase {
    private func root() throws -> HarnessRootViewController {
        let value = try XCTUnwrap(AppDelegate.harnessRootViewController)
        value.loadViewIfNeeded()
        value.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0)
        let deadline = Date().addingTimeInterval(30.0)
        while value.panelHost == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        value.view.layoutIfNeeded()
        return value
    }

    private func engineView(in view: UIView) -> UIView? {
        if NSStringFromClass(type(of: view)) == "TGIDObservingBlockTextView" {
            return view
        }
        for subview in view.subviews {
            if let found = self.engineView(in: subview) {
                return found
            }
        }
        return nil
    }

    /// Asking whether Paste is available must not read the clipboard's contents.
    func testAskingWhetherPasteIsAvailableDoesNotReadTheClipboard() throws {
        let value = try self.root()
        let host = try XCTUnwrap(value.panelHost)
        XCTAssertEqual(host.liveBackend, .engine, "precondition: the engine backend is not live")
        let editor = try XCTUnwrap(self.engineView(in: value.view), "precondition: no engine text view in the hierarchy")

        UIPasteboard.general.string = "clipboard text"
        XCTAssertEqual(HarnessPasteboardReadSpy.count { _ = UIPasteboard.general.string }, ["string"],
                       "precondition: the spy does not see a deliberate read")

        let reads = HarnessPasteboardReadSpy.count {
            _ = editor.canPerformAction(#selector(UIResponderStandardEditActions.paste(_:)), withSender: nil)
        }
        XCTAssertEqual(reads, [], "canPerformAction(paste:) read the clipboard, which raises the system paste prompt")
    }
}

/// Counts reads of the clipboard's CONTENTS for the duration of one closure.
final class HarnessPasteboardReadSpy: NSObject {
    private static var reads: [String] = []

    private static let selectors: [(original: Selector, spy: Selector)] = [
        (NSSelectorFromString("dataForPasteboardType:"), #selector(UIPasteboard.harnessSpy_data(forPasteboardType:))),
        (NSSelectorFromString("valueForPasteboardType:"), #selector(UIPasteboard.harnessSpy_value(forPasteboardType:))),
        (NSSelectorFromString("items"), #selector(getter: UIPasteboard.harnessSpy_items)),
        (NSSelectorFromString("string"), #selector(getter: UIPasteboard.harnessSpy_string)),
        (NSSelectorFromString("image"), #selector(getter: UIPasteboard.harnessSpy_image)),
        (NSSelectorFromString("images"), #selector(getter: UIPasteboard.harnessSpy_images)),
    ]

    static func record(_ name: String) {
        self.reads.append(name)
    }

    static func count(_ body: () -> Void) -> [String] {
        self.reads = []
        self.exchange()
        body()
        self.exchange()
        return self.reads
    }

    /// `UIPasteboard.general` is a private concrete subclass that overrides the accessors, so the
    /// exchange happens on THAT class. Both selectors are first copied onto it (a no-op where it
    /// already has its own), so the exchange never rewrites `UIPasteboard`'s own table.
    private static func exchange() {
        let cls: AnyClass = type(of: UIPasteboard.general)
        for (original, spy) in self.selectors {
            guard let a = class_getInstanceMethod(cls, original), let b = class_getInstanceMethod(cls, spy) else {
                XCTFail("could not spy on \(cls).\(original)")
                continue
            }
            class_addMethod(cls, original, method_getImplementation(a), method_getTypeEncoding(a))
            class_addMethod(cls, spy, method_getImplementation(b), method_getTypeEncoding(b))
            guard let ownA = class_getInstanceMethod(cls, original), let ownB = class_getInstanceMethod(cls, spy) else {
                continue
            }
            method_exchangeImplementations(ownA, ownB)
        }
    }
}

extension UIPasteboard {
    // After the exchange, each spy's own selector names the ORIGINAL implementation, so the
    // apparent self-call forwards to the real accessor.
    @objc dynamic func harnessSpy_data(forPasteboardType type: String) -> Data? {
        HarnessPasteboardReadSpy.record("data(\(type))")
        return self.harnessSpy_data(forPasteboardType: type)
    }

    @objc dynamic func harnessSpy_value(forPasteboardType type: String) -> Any? {
        HarnessPasteboardReadSpy.record("value(\(type))")
        return self.harnessSpy_value(forPasteboardType: type)
    }

    @objc dynamic var harnessSpy_items: [[String: Any]] {
        HarnessPasteboardReadSpy.record("items")
        return self.harnessSpy_items
    }

    @objc dynamic var harnessSpy_string: String? {
        HarnessPasteboardReadSpy.record("string")
        return self.harnessSpy_string
    }

    @objc dynamic var harnessSpy_image: UIImage? {
        HarnessPasteboardReadSpy.record("image")
        return self.harnessSpy_image
    }

    @objc dynamic var harnessSpy_images: [UIImage]? {
        HarnessPasteboardReadSpy.record("images")
        return self.harnessSpy_images
    }
}
