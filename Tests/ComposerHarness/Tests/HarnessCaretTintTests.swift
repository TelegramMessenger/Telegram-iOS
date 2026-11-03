import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend the caret, the selection highlight and the selection handles
/// are always the system blue, whatever the chat theme's accent colour is. Legacy tints them with the
/// theme's accent (`theme.list.itemAccentColor`, which the panel passes as `inputTintColor`). With the
/// default dark theme (white accent) legacy draws a white caret, white handles and a grey highlight;
/// the engine draws blue ones, and inside a dark quote the blue highlight is the low-contrast band
/// the third roam noticed. Any custom accent (orange, green…) is likewise ignored.
///
/// **How it was seen.** K1, 2026-09-23, fifth roam, `-harness-theme dark`: screenshots of a caret and
/// of a selection inside a quote on both backends, twice each; lldb `tintColor` on the engine text view
/// is `systemBlueColor` while legacy's `ChatInputTextView` reports `UIExtendedSRGBColorSpace 1 1 1 1`
/// (the dark accent).
///
/// **Suspected cause.** `RichTextEditorChatInputNode` (`ChatRichTextEditorComposer`) stores
/// `inputTintColor` and `inputCaretColor` without applying them (`didChangeInputTintColor()` is empty),
/// so the panel's `richTextInputNode.inputTintColor = tintColor` (`ChatTextInputPanelNode.swift`
/// ~1297 and ~2070) never reaches the engine view.
///
/// Light theme (the hosted default): legacy tint `(0, 0.533, 1)` = the day accent; engine `systemBlue`.
///
/// **Tier 1**: the tint UIKit draws the caret and selection with is the text view's `tintColor`,
/// readable in-process. Legacy is the control, in the same process and theme.
final class HarnessCaretTintTests: XCTestCase {
    /// Resolved in a DARK trait collection on purpose. The hosted tests run the light default theme,
    /// whose accent (0, 136, 255) is the same value iOS 26 resolves light `systemBlue` to, so a light
    /// comparison would pass while the engine still ignores the accent. The accent is a static colour
    /// and resolves the same in any traits; `systemBlue` does not.
    private func rgba(_ color: UIColor, _ traits: UITraitCollection) -> [CGFloat] {
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
        let dark = UITraitCollection(traitsFrom: [traits, UITraitCollection(userInterfaceStyle: .dark)])
        color.resolvedColor(with: dark).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { ($0 * 255.0).rounded() }
    }

    private func find<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        if let view = view as? T {
            return view
        }
        for subview in view.subviews {
            if let found = self.find(type, in: subview) {
                return found
            }
        }
        return nil
    }

    func testTheEngineCaretUsesTheThemeAccentLikeLegacy() throws {
        let root = try HarnessEngine.root()
        defer { root.setBackend(.engine) }

        // Control: legacy's text view carries the theme accent.
        root.setBackend(.legacy)
        HarnessEngine.settle(root)
        let legacyHost = try XCTUnwrap(root.panelHost)
        let accent = legacyHost.interfaceState.theme.list.itemAccentColor
        let legacyView = try XCTUnwrap(self.find(ChatInputTextView.self, in: root.view), "precondition: no legacy text view")
        XCTAssertEqual(self.rgba(legacyView.tintColor, legacyView.traitCollection), self.rgba(accent, legacyView.traitCollection),
                       "control: legacy no longer tints its caret with the theme accent")

        root.setBackend(.engine)
        HarnessEngine.settle(root)
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let engineView = try HarnessEngine.textView(in: root)
        let engineAccent = host.interfaceState.theme.list.itemAccentColor
        XCTAssertEqual(self.rgba(engineView.tintColor, engineView.traitCollection), self.rgba(engineAccent, engineView.traitCollection),
                       "the engine's caret/selection tint is \(String(describing: engineView.tintColor)), not the theme accent \(engineAccent)")
        _ = node.resignInputFirstResponder()
    }
}
