#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A transcription of `instantPageV2LayoutButtonRow`
/// (`InstantPageUI/Sources/InstantPageV2ButtonRowLayout.swift`). The editor cannot import
/// `InstantPageUI` — that edge is a dependency cycle, since `InstantPageUITests` imports this module —
/// so this is a copy, pinned against the original by `RichTextV2ButtonParityTests`. The same
/// arrangement `richTextSpacingBetweenBlocks` is already in.
///
/// The STRUCTURE deliberately mirrors the original rather than being reorganised:
/// - `justify` splits the available width into equal columns, chunked at `maximumButtonsPerRow`.
/// - `left` / `center` / `right` hug the label and wrap greedily, still capped per row.
/// - EACH WRAPPED ROW is aligned on its own width, so a short last row re-aligns on itself.
/// - One RTL rule covers all four modes: a row lays out in the page's READING direction, so `left`
///   means leading (the right edge when `isRTL`) and the first pill sits at the reading start. This
///   deliberately differs from V2 table cells, which apply `.left`/`.right` literally.

/// Whether the renderer would draw a type badge for this action, which costs horizontal room a centred
/// label must keep clear of.
///
/// The COARSE FALLBACK, used only when no host icon provider is registered — see
/// `AttributedStringMapper.buttonHasIcon`. Core can name just three actions, so `.unsupported` — every
/// action Core cannot name — is treated as badge-bearing, which is true for 7 of the 11 it covers but
/// wrong for `callback`. A configured editor asks the provider instead and gets the exact answer.
@available(iOS 13.0, *)
func richTextButtonHasBadge(_ action: ButtonAction) -> Bool {
    switch action {
    case .url, .copyText:
        return true
    case .disabled:
        return false
    case .unsupported:
        return true
    }
}

/// Per-side inner padding for a row pill, and the tighter value it falls back to when its label does
/// not fit there. A link button is chrome-less at 0 in both cases; `min` guarantees the fallback can
/// never hand a button MORE room than it started with.
/// Mirrors `instantPageBlockButtonPadding(for:)` / `instantPageBlockButtonMinimumPadding(for:)`.
@available(iOS 13.0, *)
private func rowButtonPadding(_ button: ButtonRef, metrics: RichTextButtonMetrics) -> CGFloat {
    return button.isLink ? 0.0 : metrics.blockHorizontalPadding
}

@available(iOS 13.0, *)
private func rowButtonMinimumPadding(_ button: ButtonRef, metrics: RichTextButtonMetrics) -> CGFloat {
    return min(rowButtonPadding(button, metrics: metrics), metrics.blockMinimumHorizontalPadding)
}

/// Room a badge-bearing pill keeps clear on EACH side BEYOND `padding`. The attachment builder already
/// subtracts `padding` per side from the cap it is handed, so only the difference is taken off on top
/// of it — making the total clearance `max(padding, reserve)`, never their sum.
///
/// At the comfortable padding (19) this is 0: the padding alone already exceeds the badge reserve (18).
/// It arms only in the tight fallback, where the badge becomes the binding constraint.
@available(iOS 13.0, *)
private func rowButtonExtraSideInset(_ button: ButtonRef, padding: CGFloat, metrics: RichTextButtonMetrics,
                                     hasIcon: (ButtonRef) -> Bool) -> CGFloat {
    guard hasIcon(button) else {
        return 0.0
    }
    return max(0.0, metrics.blockIconReserve - padding)
}

/// Measures one row pill against the width its frame will occupy, choosing its padding: comfortable
/// when the label fits there, tight when it does not.
///
/// **A pill's inner padding is a preference, not a constraint.** Once a label has to be cut, the
/// padding is holding room the label needs more, so it gives it back — per button, so a row's short
/// labels are untouched. The two-try shape is deliberate over solving for the padding directly:
/// truncation is decided by the typesetter's cluster break, not by a width formula we could invert.
///
/// Returns the per-side `extraSideInset` the chosen padding implies alongside the attachment; the
/// hugging path adds it to the pill's frame width (the justified path's frame is the column, fixed).
/// Transcribes `instantPageBlockButtonMeasure`.
@available(iOS 13.0, *)
private func richTextMeasureRowButton(
    button: ButtonRef,
    pillWidth: CGFloat,
    metrics: RichTextButtonMetrics,
    hasIcon: (ButtonRef) -> Bool,
    measure: (ButtonRef, CGFloat?, CGFloat) -> ButtonTextAttachment
) -> (attachment: ButtonTextAttachment, extraSideInset: CGFloat) {
    func measured(padding: CGFloat) -> (attachment: ButtonTextAttachment, extraSideInset: CGFloat) {
        let extra = rowButtonExtraSideInset(button, padding: padding, metrics: metrics, hasIcon: hasIcon)
        return (measure(button, max(0.0, pillWidth - extra * 2.0), padding), extra)
    }
    let comfortable = rowButtonPadding(button, metrics: metrics)
    let minimum = rowButtonMinimumPadding(button, metrics: metrics)
    let result = measured(padding: comfortable)
    guard result.attachment.isTruncated, minimum < comfortable else {
        return result
    }
    return measured(padding: minimum)
}

/// Where a row's content starts within the available width, given its leftover space.
@available(iOS 13.0, *)
private func rowSlackOffset(alignment: ButtonRowAlignment, slack: CGFloat, isRTL: Bool) -> CGFloat {
    switch alignment {
    case .justify:
        return 0.0
    case .left:
        return isRTL ? slack : 0.0
    case .center:
        return slack / 2.0
    case .right:
        return isRTL ? 0.0 : slack
    }
}

/// Lays out one button row. Frames come back in MODEL order (frame *i* belongs to pill *i*); reading
/// direction lives in the frames themselves.
///
/// `measure` builds a pill attachment at a given cap AND per-side horizontal padding, and `hasIcon`
/// answers whether a pill keeps side room clear for its type badge — both supplied by the caller so
/// this file stays free of the mapper. It mirrors
/// `instantPageInlineButtonAttachment(button:labelString:maxWidth:horizontalPadding:)`.
@available(iOS 13.0, *)
func richTextPackButtonRow(
    buttons: [ButtonRef],
    alignment: ButtonRowAlignment,
    availableWidth: CGFloat,
    metrics: RichTextButtonMetrics,
    isRTL: Bool,
    hasIcon: (ButtonRef) -> Bool,
    measure: (ButtonRef, CGFloat?, CGFloat) -> ButtonTextAttachment
) -> (attachments: [ButtonTextAttachment], frames: [CGRect], totalHeight: CGFloat) {
    guard !buttons.isEmpty, availableWidth > 0.0 else {
        return ([], [], 0.0)
    }
    switch alignment {
    case .justify:
        return packJustified(buttons: buttons, availableWidth: availableWidth, metrics: metrics,
                             isRTL: isRTL, hasIcon: hasIcon, measure: measure)
    case .left, .center, .right:
        return packHugging(buttons: buttons, alignment: alignment, availableWidth: availableWidth,
                           metrics: metrics, isRTL: isRTL, hasIcon: hasIcon, measure: measure)
    }
}

/// Equal columns filling the width, wrapping at the schema's cap.
@available(iOS 13.0, *)
private func packJustified(
    buttons: [ButtonRef],
    availableWidth: CGFloat,
    metrics: RichTextButtonMetrics,
    isRTL: Bool,
    hasIcon: (ButtonRef) -> Bool,
    measure: (ButtonRef, CGFloat?, CGFloat) -> ButtonTextAttachment
) -> (attachments: [ButtonTextAttachment], frames: [CGRect], totalHeight: CGFloat) {
    var attachments: [ButtonTextAttachment] = []
    var frames: [CGRect] = []
    var y: CGFloat = 0.0
    var index = 0
    while index < buttons.count {
        let upper = min(index + metrics.maximumButtonsPerRow, buttons.count)
        let rowButtons = Array(buttons[index ..< upper])
        let totalSpacing = metrics.blockSpacing * CGFloat(max(0, rowButtons.count - 1))
        let buttonWidth = max(0.0, (availableWidth - totalSpacing) / CGFloat(rowButtons.count))
        for (position, button) in rowButtons.enumerated() {
            // Cap the label at the column it will be stretched to. The pill centres its label, so the
            // clearance is kept on BOTH sides — otherwise a long centred label runs under the badge.
            attachments.append(richTextMeasureRowButton(button: button, pillWidth: buttonWidth,
                                                        metrics: metrics, hasIcon: hasIcon,
                                                        measure: measure).attachment)
            let column = isRTL ? (rowButtons.count - 1 - position) : position
            let x = CGFloat(column) * (buttonWidth + metrics.blockSpacing)
            frames.append(CGRect(x: x, y: y, width: buttonWidth, height: metrics.blockRowHeight))
        }
        y += metrics.blockRowHeight + metrics.blockSpacing
        index += metrics.maximumButtonsPerRow
    }
    return (attachments, frames, max(0.0, y - metrics.blockSpacing))
}

/// Left / centre / right: every pill hugs its label, rows fill greedily, each row placed at its own
/// origin (a short last row re-aligns on itself).
@available(iOS 13.0, *)
private func packHugging(
    buttons: [ButtonRef],
    alignment: ButtonRowAlignment,
    availableWidth: CGFloat,
    metrics: RichTextButtonMetrics,
    isRTL: Bool,
    hasIcon: (ButtonRef) -> Bool,
    measure: (ButtonRef, CGFloat?, CGFloat) -> ButtonTextAttachment
) -> (attachments: [ButtonTextAttachment], frames: [CGRect], totalHeight: CGFloat) {
    // Pass 1 — measure each pill at its natural width, capped so even the longest label fits
    // `availableWidth` on its own (the builder ellipsises past the cap, having first retried at the
    // tight padding). Pass 2 depends on that: a row can then never overflow, and an over-long single
    // label truncates instead.
    let measured: [(attachment: ButtonTextAttachment, width: CGFloat)] = buttons.map { button in
        let (attachment, extra) = richTextMeasureRowButton(button: button, pillWidth: availableWidth,
                                                           metrics: metrics, hasIcon: hasIcon,
                                                           measure: measure)
        return (attachment, min(availableWidth, attachment.size.width + extra * 2.0))
    }

    // Pass 2a — greedy packing, still capped at the schema's per-row maximum.
    var rows: [[Int]] = []
    var currentRow: [Int] = []
    var currentWidth: CGFloat = 0.0
    for index in 0 ..< measured.count {
        let width = measured[index].width
        if !currentRow.isEmpty {
            let projected = currentWidth + metrics.blockSpacing + width
            if projected > availableWidth || currentRow.count >= metrics.maximumButtonsPerRow {
                rows.append(currentRow)
                currentRow = []
                currentWidth = 0.0
            }
        }
        currentWidth = currentRow.isEmpty ? width : currentWidth + metrics.blockSpacing + width
        currentRow.append(index)
    }
    if !currentRow.isEmpty {
        rows.append(currentRow)
    }

    // Pass 2b — place each row at its own origin.
    var frames = [CGRect](repeating: .zero, count: measured.count)
    var y: CGFloat = 0.0
    for row in rows {
        let rowWidth = row.reduce(0.0) { $0 + measured[$1].width }
            + metrics.blockSpacing * CGFloat(max(0, row.count - 1))
        let slack = max(0.0, availableWidth - rowWidth)
        var x = rowSlackOffset(alignment: alignment, slack: slack, isRTL: isRTL)
        // The first button sits at the reading start, so on an RTL page the pills run right-to-left.
        let visualOrder = isRTL ? Array(row.reversed()) : row
        for index in visualOrder {
            frames[index] = CGRect(x: x, y: y, width: measured[index].width, height: metrics.blockRowHeight)
            x += measured[index].width + metrics.blockSpacing
        }
        y += metrics.blockRowHeight + metrics.blockSpacing
    }
    return (measured.map(\.attachment), frames, max(0.0, y - metrics.blockSpacing))
}
#endif
