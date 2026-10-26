#if canImport(UIKit)
import UIKit

/// **No layout in this package may add a font's LEADING to a line.**
///
/// The V2 renderer advances a paragraph by a pitch derived from the paragraph's own font —
/// `lineAscent = floor(A + D)` raised only by an inline attachment, plus a `lineSpacing` computed
/// from the same number — and never consults the metrics of the face CoreText actually substituted
/// for a run (`InstantPageV2Layout.swift:4280,4560`). The editor must lay out on that same grid or
/// what you type stops matching what you send, which is the whole of the V2 parity contract.
///
/// **A pinned line box is not enough on its own, and the gap is narrow.** `StyleSheet` pins every
/// text line with `minimumLineHeight == maximumLineHeight`, and that pin does clamp a run's ascent
/// and descent — but a text system adds the font's leading ON TOP of the clamped box, where no
/// paragraph-style property can reach it. Latin never showed this because `.SFUI-Regular` reports
/// `leading == 0`. Measured at 17pt body against a 21pt box, one line:
///
/// | script | substituted face | font box | leading | line |
/// | --- | --- | --- | --- | --- |
/// | Latin | `.SFUI-Regular` | 20.29 | 0 | 21.0 |
/// | Hebrew | `.SFHebrew-Regular` | 20.29 | 0 | 21.0 |
/// | Devanagari | `.SFDevanagari-Regular` | 26.08 | 0 | 21.0 |
/// | Korean | `.AppleSDGothicNeoI-Regular` | — | 0.51 | 21.51 |
/// | Thai | `.ThonburiUI-Regular` | 22.27 | 1.1355 | 22.1355 |
/// | Arabic | `.SFArabic-Regular` | 21.12 | 1.1621 | 22.1621 |
///
/// **Devanagari is the control that names the mechanism.** It has the tallest font box of the six —
/// 5pt PAST the pin — and inflates the line by nothing at all, because the pin clamps exactly the
/// two metrics it is documented to clamp. Only leading escapes, and the three scripts that grow the
/// line are precisely the three whose face declares some. So this is one property, not a table of
/// scripts to keep up to date.
///
/// **In TextKit 2 — the engine's system — it compounds per line.** A two-line Arabic paragraph
/// measured 46.324 against the grid's 44.0 (one leading per line), where TextKit 1 added a single
/// one for the whole block; a five-line one sat 5.81 off. The reported symptom was a composer field
/// that grew by 2pt the moment Arabic was typed, and it got worse as the message got longer.
///
/// **Nothing is clipped by this.** Leading is the empty band a face asks for BETWEEN lines, never
/// ink — ascent and descent bound the glyphs, and those were already being clamped by the pin
/// before this rule existed (Devanagari, above, loses 5pt of font box today and always did). This
/// removes empty space, exactly as `EngineBlockSpacing.trailingLineBoxOverhang` does at the bottom
/// of a block.
///
/// **WHAT THIS RULE REACHES, AND WHAT IT DOES NOT.** The flag governs a line's own box: with it off
/// every fragment measures exactly the pinned box, in every script and both text systems. It does
/// NOT govern the advance to the next line, which is `box + max(lineSpacing, leading)` — the flag
/// cannot drive that below the leading, and no paragraph-style property reaches it either. So the
/// rule closes the gap completely only for a style with room to spare, and a style pinned with
/// `lineSpacing == 0` keeps spreading its lines by the leading.
///
/// That is exactly the difference between the two backends. `StyleSheet` pins
/// `minimumLineHeight == maximumLineHeight == pitch` with `lineSpacing == 0`, leaving nothing to
/// absorb with; the engine's `.safe` re-expression (`EngineDocumentBridge.v2BaselinePlacedStyle`)
/// sets the box to `ceil(fontBox)` and moves the remainder into `lineSpacing`, which is the room
/// this needs. Measured across every style at its own point size — worst leading of any script
/// against the spacing `.safe` leaves — heading1 1.4695/3, heading2 1.3359/4, heading3 1.2023/2,
/// heading4 1.1621/3, heading5 1.0688/2, heading6 1.0020/2, body 1.1621/2, caption 1.0020/2 are all
/// absorbed, and pullQuote 1.0020/1 leaks **0.001953125pt**, about 1/170 of a device pixel at 3×.
///
/// **So: the engine backend is closed by this rule; the legacy canvas is improved by it but not
/// closed**, and closing the legacy canvas means giving it the same re-expression rather than
/// finding a better flag. `ScriptLineHeightTests` asserts both halves, including the boundary, so
/// that a later change which closes it fails loudly instead of passing a stale case.
///
/// **Every construction site needs it, and a missed one is silent.** The three backends each build
/// their own layout — `BlockLayoutTK1`, `BlockLayout`, and the engine's `IDBlockLayout` (which sets
/// the same property directly, being Objective-C in a module below this one) — so a fix applied to
/// one is invisible to the others. `ScriptLineHeightTests` and `EngineScriptLineHeightTests` hold
/// all three to the same line grid for that reason.
public enum RichTextFontLeading {

    /// TextKit 1.
    public static func suppress(in manager: NSLayoutManager) {
        manager.usesFontLeading = false
    }

    /// TextKit 2.
    @available(iOS 15.0, *)
    public static func suppress(in manager: NSTextLayoutManager) {
        manager.usesFontLeading = false
    }

    /// The `NSStringDrawing` spelling of the same rule: the option set a measurement must NOT carry.
    ///
    /// `boundingRect(with:options:context:)` takes font leading as an opt-IN flag rather than a
    /// property, so a measuring site expresses the rule by leaving `.usesFontLeading` out of its
    /// options. Named here so the omission reads as the policy it is rather than as a forgotten
    /// flag.
    public static let drawingOptions: NSStringDrawingOptions = [.usesLineFragmentOrigin]
}
#endif
