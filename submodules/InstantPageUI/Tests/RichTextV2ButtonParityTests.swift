import XCTest
import UIKit
import TelegramCore
import RichTextEditorCore
@testable import InstantPageUI
@testable import RichTextEditorUIKit
import RichTextButtonIcons
import RichTextEditorMessageConversion

/// The editor cannot import `InstantPageUI` — that edge is a dependency cycle, since this very test
/// target imports `RichTextEditorUIKit`. So the editor's pill geometry is a host-supplied contract
/// (`RichTextButtonMetrics`) plus a transcription, and THIS test is what keeps the two from drifting.
/// Exactly the role `RichTextV2MetricsParityTests` plays for the line formulas.
@available(iOS 13.0, *)
final class RichTextV2ButtonParityTests: XCTestCase {
    func testDefaultButtonMetricsMatchTheRendererConstants() {
        let m = RichTextButtonMetrics.default
        XCTAssertEqual(m.inlineFontSize, instantPageInlineButtonFontSize)
        XCTAssertEqual(m.blockFontSize, instantPageBlockButtonFontSize)
        XCTAssertEqual(m.inlineHorizontalPadding, instantPageInlineButtonHorizontalPadding)
        XCTAssertEqual(m.blockHorizontalPadding, instantPageBlockButtonHorizontalPadding)
        XCTAssertEqual(m.blockMinimumHorizontalPadding, instantPageBlockButtonMinimumHorizontalPadding)
        XCTAssertEqual(m.verticalPadding, instantPageInlineButtonVerticalPadding)
        XCTAssertEqual(m.adjacentSpacing, instantPageInlineButtonAdjacentSpacing)
        XCTAssertEqual(m.blockRowHeight, instantPageBlockButtonHeight)
        XCTAssertEqual(m.maximumButtonsPerRow, instantPageBlockButtonsPerRow)
        XCTAssertEqual(m.blockSpacing, instantPageBlockButtonSpacing)
        XCTAssertEqual(m.blockIconReserve, richTextBlockButtonIconReserve)
        XCTAssertEqual(m.inlineIconReserve, richTextInlineButtonIconReserve)
        XCTAssertEqual(m.blockIconInset, richTextBlockButtonIconInset)
    }

    /// The article editor sources its metrics from the renderer's constants via the theme adapter, so
    /// that path must agree with the pinned default the composer uses.
    func testAdapterMetricsMatchTheDefault() {
        XCTAssertEqual(InstantPageTheme.chatMessageRenderMetrics().button, RichTextButtonMetrics.default)
    }

    /// The chat composer cannot import `InstantPageUI` either, so it assigns
    /// `RichTextRenderMetrics.default`. That default must carry the same pill geometry the article
    /// editor gets from the theme adapter, or the two hosts render pills differently.
    func testRenderMetricsDefaultCarriesTheDefaultButtonMetrics() {
        XCTAssertEqual(RichTextRenderMetrics.default.button, RichTextButtonMetrics.default)
    }

    // MARK: - Row packing

    private func rendererEntries(
        labels: [String], alignment: InstantPageButtonRowAlignment, width: CGFloat, rtl: Bool,
        isLink: Bool = false
    ) -> (frames: [CGRect], totalHeight: CGFloat) {
        // The renderer's `.buttonRow` arm builds this via the file-private `setupStyleStack` — not
        // reachable from a test — but only the FONT affects the measured width, and for the non-serif
        // chat-message theme that stack resolves to exactly this semibold system font. If that ever
        // stops being true, the width assertions below fail rather than silently drifting.
        let labelFont = UIFont.systemFont(ofSize: instantPageBlockButtonFontSize, weight: .semibold)
        let labelled = labels.map { label -> (button: InstantPageButton, labelString: NSAttributedString) in
            let button = InstantPageButton(text: .plain(label), action: .disabled, color: nil, isLink: isLink)
            return (button, NSAttributedString(string: label, attributes: [.font: labelFont]))
        }
        let (entries, height) = instantPageV2LayoutButtonRow(
            labelledButtons: labelled, alignment: alignment, boundingWidth: width,
            horizontalInset: 0.0, rtl: rtl, metrics: InstantPageMetrics.unscaled)
        return (entries.map { $0.frame }, height)
    }

    private func editorFrames(
        labels: [String], alignment: ButtonRowAlignment, width: CGFloat, rtl: Bool,
        isLink: Bool = false
    ) -> (frames: [CGRect], totalHeight: CGFloat) {
        let mapper = AttributedStringMapper()
        let buttons = labels.map { ButtonRef(label: [TextRun(text: $0)], action: .disabled, isLink: isLink) }
        let packed = richTextPackButtonRow(
            buttons: buttons, alignment: alignment, availableWidth: width,
            metrics: .default, isRTL: rtl,
            hasIcon: { mapper.buttonHasIcon($0.action) },
            measure: { mapper.buttonAttachment(button: $0, isBlockPill: true, maxWidth: $1, horizontalPadding: $2) })
        return (packed.frames, packed.totalHeight)
    }

    /// The rendered label of each pill, in model order — the thing the inset fallback is FOR. Frames
    /// alone cannot catch a padding divergence in the justified path, where every frame is the column
    /// width no matter how much of the label survived.
    private func rendererLabels(labels: [String], alignment: InstantPageButtonRowAlignment, width: CGFloat,
                                action: ReplyMarkupButtonAction) -> [String] {
        let labelFont = UIFont.systemFont(ofSize: instantPageBlockButtonFontSize, weight: .semibold)
        let labelled = labels.map { label -> (button: InstantPageButton, labelString: NSAttributedString) in
            (InstantPageButton(text: .plain(label), action: action, color: nil, isLink: false),
             NSAttributedString(string: label, attributes: [.font: labelFont]))
        }
        let (entries, _) = instantPageV2LayoutButtonRow(
            labelledButtons: labelled, alignment: alignment, boundingWidth: width,
            horizontalInset: 0.0, rtl: false, metrics: InstantPageMetrics.unscaled)
        return entries.map { $0.attachment.labelString.string }
    }

    private func editorLabels(labels: [String], alignment: ButtonRowAlignment, width: CGFloat,
                              action: ButtonAction) -> [String] {
        let mapper = AttributedStringMapper()
        let buttons = labels.map { ButtonRef(label: [TextRun(text: $0)], action: action) }
        let packed = richTextPackButtonRow(
            buttons: buttons, alignment: alignment, availableWidth: width, metrics: .default, isRTL: false,
            hasIcon: { mapper.buttonHasIcon($0.action) },
            measure: { mapper.buttonAttachment(button: $0, isBlockPill: true, maxWidth: $1, horizontalPadding: $2) })
        return packed.attachments.map { $0.labelString.string }
    }

    /// The editor transcribes `instantPageV2LayoutButtonRow`. This pins the transcription against the
    /// renderer's real output for every alignment, both reading directions, and a wrapping row.
    func testRowPackingMatchesTheRenderer() {
        let cases: [[String]] = [
            ["A", "Longer label", "Mid", "X"],
            ["Only one"],
            ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"],   // wraps past the 8-per-row cap
        ]
        let alignments: [(InstantPageButtonRowAlignment, ButtonRowAlignment)] =
            [(.justify, .justify), (.left, .left), (.center, .center), (.right, .right)]

        for labels in cases {
            for (rendererAlignment, editorAlignment) in alignments {
                for rtl in [false, true] {
                    let expected = rendererEntries(labels: labels, alignment: rendererAlignment, width: 320.0, rtl: rtl)
                    let actual = editorFrames(labels: labels, alignment: editorAlignment, width: 320.0, rtl: rtl)
                    let context = "\(labels.count) buttons, \(rendererAlignment), rtl=\(rtl)"

                    XCTAssertEqual(actual.totalHeight, expected.totalHeight, accuracy: 0.01, "height — \(context)")
                    XCTAssertEqual(actual.frames.count, expected.frames.count, "count — \(context)")
                    guard actual.frames.count == expected.frames.count else { continue }
                    for index in 0 ..< expected.frames.count {
                        XCTAssertEqual(actual.frames[index].minX, expected.frames[index].minX, accuracy: 0.5, "x[\(index)] — \(context)")
                        XCTAssertEqual(actual.frames[index].minY, expected.frames[index].minY, accuracy: 0.5, "y[\(index)] — \(context)")
                        XCTAssertEqual(actual.frames[index].width, expected.frames[index].width, accuracy: 0.5, "w[\(index)] — \(context)")
                        XCTAssertEqual(actual.frames[index].height, expected.frames[index].height, accuracy: 0.01, "h[\(index)] — \(context)")
                    }
                }
            }
        }
    }

    // MARK: - The tight-padding fallback

    /// A pill whose label does not fit gives its inner padding back to the label, so BOTH sides must
    /// pick the same padding or the editor shows a different amount of text than the sent message.
    /// Asserted on the rendered labels, not the frames: in the justified path every frame is the
    /// column width regardless of how much of the label survived.
    func testTightPaddingFallbackMatchesTheRenderer() {
        // Four columns of ~76pt each: comfortable padding leaves ~38pt of ink, which these labels
        // exceed, so every one of them takes the fallback.
        let labels = ["Subscribe now", "Open the website", "Read more", "Contact us"]
        for (rendererAlignment, editorAlignment) in [(InstantPageButtonRowAlignment.justify, ButtonRowAlignment.justify),
                                                     (.left, .left)] {
            // `.disabled` carries no badge, so the padding is the ONLY constraint and the fallback's
            // full 22pt per side shows up in the label.
            XCTAssertEqual(
                editorLabels(labels: labels, alignment: editorAlignment, width: 320.0, action: .disabled),
                rendererLabels(labels: labels, alignment: rendererAlignment, width: 320.0, action: .disabled),
                "no badge, \(rendererAlignment)")
            // `.url` DOES carry one, so the badge reserve binds once the padding drops below it. The
            // two sides must agree on that interaction too, not just on the padding.
            XCTAssertEqual(
                editorLabels(labels: labels, alignment: editorAlignment, width: 320.0, action: .url("https://telegram.org")),
                rendererLabels(labels: labels, alignment: rendererAlignment, width: 320.0, action: .url("https://telegram.org")),
                "badge, \(rendererAlignment)")
        }
    }

    /// The fallback only arms where it is needed: a label that fits keeps the comfortable padding, so
    /// a row of short labels is untouched by any of this.
    func testAPillWhoseLabelFitsKeepsTheComfortablePadding() {
        let button = InstantPageButton(text: .plain("Go"), action: .disabled, color: nil, isLink: false)
        let label = NSAttributedString(string: "Go", attributes: [
            .font: UIFont.systemFont(ofSize: instantPageBlockButtonFontSize, weight: .semibold)])
        let (entries, _) = instantPageV2LayoutButtonRow(
            labelledButtons: [(button, label)], alignment: .justify, boundingWidth: 320.0,
            horizontalInset: 0.0, rtl: false, metrics: InstantPageMetrics.unscaled)
        XCTAssertEqual(entries.first?.attachment.horizontalPadding, instantPageBlockButtonHorizontalPadding)
        XCTAssertEqual(entries.first?.attachment.isTruncated, false)
    }

    /// A link button is chrome-less at 0 padding already, so the fallback must not hand it MORE room
    /// than it started with — `min`, not the constant.
    func testTheFallbackNeverWidensALinkButtonsPadding() {
        let button = InstantPageButton(text: .plain(String(repeating: "long ", count: 40)), action: .disabled,
                                       color: nil, isLink: true)
        let label = NSAttributedString(string: String(repeating: "long ", count: 40), attributes: [
            .font: UIFont.systemFont(ofSize: instantPageBlockButtonFontSize, weight: .semibold)])
        let (entries, _) = instantPageV2LayoutButtonRow(
            labelledButtons: [(button, label)], alignment: .justify, boundingWidth: 320.0,
            horizontalInset: 0.0, rtl: false, metrics: InstantPageMetrics.unscaled)
        XCTAssertEqual(entries.first?.attachment.isTruncated, true, "the label is far too long to fit")
        XCTAssertEqual(entries.first?.attachment.horizontalPadding, 0.0)
    }

    /// Two adjacent rows sum both paddings — `InstantPageLayoutSpacings.swift`. The rule must sit
    /// BEFORE the `.list` checks, matching the renderer's order.
    func testButtonRowSpacingMatchesTheRenderer() {
        let m = RichTextRenderMetrics.default
        XCTAssertEqual(
            richTextSpacingBetweenBlocks(upper: .buttonRow, lower: .buttonRow, kind: .topLevel, metrics: m),
            m.blockVerticalPadding * 2.0
        )
    }

    /// A LINK-styled row button draws no background and takes NO inner horizontal padding, so its pill
    /// is narrower than a filled one. Both sides must agree on that or the editor's preview stops
    /// matching the sent message — this pins the new geometry across the seam.
    func testLinkStyledRowPackingMatchesTheRenderer() {
        let labels = ["A", "Longer label", "Mid"]
        for (rendererAlignment, editorAlignment) in [(InstantPageButtonRowAlignment.left, ButtonRowAlignment.left),
                                                     (.center, .center),
                                                     (.justify, .justify)] {
            let expected = rendererEntries(labels: labels, alignment: rendererAlignment, width: 320.0, rtl: false, isLink: true)
            let actual = editorFrames(labels: labels, alignment: editorAlignment, width: 320.0, rtl: false, isLink: true)
            let context = "link, \(rendererAlignment)"

            XCTAssertEqual(actual.totalHeight, expected.totalHeight, accuracy: 0.01, "height — \(context)")
            XCTAssertEqual(actual.frames.count, expected.frames.count, "count — \(context)")
            guard actual.frames.count == expected.frames.count else { continue }
            for index in 0 ..< expected.frames.count {
                XCTAssertEqual(actual.frames[index].minX, expected.frames[index].minX, accuracy: 0.5, "x[\(index)] — \(context)")
                XCTAssertEqual(actual.frames[index].width, expected.frames[index].width, accuracy: 0.5, "w[\(index)] — \(context)")
            }
        }
    }

    /// The padding rule itself, on the renderer side.
    func testLinkStyledRowButtonTakesNoInnerPadding() {
        let link = InstantPageButton(text: .plain("Go"), action: .disabled, color: nil, isLink: true)
        let filled = InstantPageButton(text: .plain("Go"), action: .disabled, color: nil, isLink: false)
        XCTAssertEqual(instantPageBlockButtonPadding(for: link), 0.0)
        XCTAssertEqual(instantPageBlockButtonPadding(for: filled), instantPageBlockButtonHorizontalPadding)
    }

    /// And that it draws no fill, in both the renderer and the editor.
    func testLinkStyledButtonHasNoFill() {
        let rendererColors = instantPageButtonColors(nil, theme: InstantPageTheme.chatMessageGeometryTheme(),
                                                     isInline: false, isDisabled: false, isLink: true)
        XCTAssertEqual(rendererColors.fill, .clear)

        let editorColors = RichTextEditorTheme.default.resolvedButtonColors(color: nil, isDisabled: false, isLink: true)
        XCTAssertEqual(editorColors.fill, .clear)
    }

    // MARK: - The inline type icon

    /// An inline pill's icon reserve is UNCONDITIONAL width, unlike the block badge's side inset, so a
    /// disagreement here moves the line break of every paragraph holding a button — the composer would
    /// wrap differently from the message it sends.
    private func rendererInlineWidth(action: ReplyMarkupButtonAction) -> CGFloat {
        // See `rendererEntries`: the `.textButton` arm's style stack resolves to exactly this face.
        let font = UIFont.systemFont(ofSize: instantPageInlineButtonFontSize, weight: .semibold)
        return instantPageInlineButtonAttachment(
            button: InstantPageButton(text: .plain("Open"), action: action, color: nil),
            labelString: NSAttributedString(string: "Open", attributes: [.font: font])
        ).size.width
    }

    private func editorInlineWidth(action: ButtonAction) -> CGFloat {
        var mapper = AttributedStringMapper()
        mapper.buttonIconProvider = richTextEditorButtonIcon
        return mapper.buttonAttachment(
            button: ButtonRef(label: [TextRun(text: "Open")], action: action),
            isBlockPill: false, maxWidth: nil
        ).size.width
    }

    func testInlinePillWidthMatchesTheRendererWithAndWithoutAnIcon() {
        XCTAssertEqual(self.editorInlineWidth(action: .url("https://telegram.org")),
                       self.rendererInlineWidth(action: .url("https://telegram.org")),
                       accuracy: 0.5, "icon-bearing")
        XCTAssertEqual(self.editorInlineWidth(action: .disabled),
                       self.rendererInlineWidth(action: .disabled),
                       accuracy: 0.5, "iconless")
    }

    /// And that the difference is the reserve itself on BOTH sides — two equal widths could also mean
    /// neither side reserved anything.
    func testBothSidesChargeTheIconReserveToTheSamePill() {
        XCTAssertEqual(self.rendererInlineWidth(action: .url("https://telegram.org"))
                        - self.rendererInlineWidth(action: .disabled),
                       richTextInlineButtonIconReserve, accuracy: 0.01)
        XCTAssertEqual(self.editorInlineWidth(action: .url("https://telegram.org"))
                        - self.editorInlineWidth(action: .disabled),
                       richTextInlineButtonIconReserve, accuracy: 0.01)
    }

    /// The BLOCK badge's side inset must be exact too, not "anything unsupported probably has one".
    /// `.callback` is iconless in the renderer, so it reserves nothing and keeps more of its label;
    /// a coarse editor rule takes 18pt per side off the same pill and ellipsises it earlier.
    ///
    /// Asserted on the rendered labels rather than the frames: in the justified path every frame is the
    /// column width no matter how much of the label survived.
    func testTheBlockBadgeReserveIsExactForAnActionTheEditorCannotName() {
        let labels = ["Subscribe now", "Open the website", "Read more", "Contact us"]
        let callbackAction = ReplyMarkupButtonAction.callback(requiresPassword: false,
                                                             data: EngineMemoryBuffer(data: Data([0x01, 0x02])))
        var mapper = AttributedStringMapper()
        mapper.buttonIconProvider = richTextEditorButtonIcon
        let buttons = labels.map { ButtonRef(label: [TextRun(text: $0)], action: buttonAction(from: callbackAction)) }
        let packed = richTextPackButtonRow(
            buttons: buttons, alignment: .justify, availableWidth: 320.0, metrics: .default, isRTL: false,
            hasIcon: { mapper.buttonHasIcon($0.action) },
            measure: { mapper.buttonAttachment(button: $0, isBlockPill: true, maxWidth: $1, horizontalPadding: $2) })

        XCTAssertEqual(packed.attachments.map { $0.labelString.string },
                       self.rendererLabels(labels: labels, alignment: .justify, width: 320.0, action: callbackAction))
    }

    /// An action the editor cannot NAME is still resolved to the renderer's icon decision, by decoding
    /// the opaque blob back through `ButtonActionCodec`. `.callback` is the case that matters: it is
    /// iconless in the renderer, and a coarse "unsupported means it has one" rule would reserve 14pt
    /// the sent message does not.
    func testAnUnsupportedCallbackActionReservesNothingOnEitherSide() {
        let callback = buttonAction(from: .callback(requiresPassword: false, data: EngineMemoryBuffer(data: Data([0x01, 0x02]))))
        guard case .unsupported = callback else {
            return XCTFail("a callback action should travel as .unsupported")
        }
        XCTAssertEqual(self.editorInlineWidth(action: callback),
                       self.rendererInlineWidth(action: .disabled), accuracy: 0.5)
    }
}
