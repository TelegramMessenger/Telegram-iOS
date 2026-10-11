#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The PUBLIC surface over this module's internal button machinery, for the InputDec engine editor.
///
/// It exists because `richTextPackButtonRow`, `ButtonPillView` and `ButtonRowMenuPillView` are
/// internal AND live under `Canvas/`, which the engine branch does not modify. This file sits
/// outside `Canvas/`, in the same module, so it can see all three and republish them without a
/// single edit in there — and, decisively, without duplicating the packer, which is pinned to the
/// InstantPage V2 renderer by `RichTextV2ButtonParityTests`. A second copy of that arithmetic would
/// be a second thing to keep in step with the renderer, and only one of the two would be tested.
///
/// The legacy canvas does NOT use this: it has `ButtonRowBox` + `ButtonRowBackingView`, which are
/// bound to `CanvasBlock` and `BlockBackingView` and cannot be reused from outside. The two paths
/// share the packer and the pill view, which is the part that must not diverge.

/// The trailing "…" control's geometry. Editor-only chrome — a sent message has no such control —
/// so it is placed outside the packing, exactly as `ButtonRowBox` places it.
@available(iOS 13.0, *)
public enum RichTextButtonRowChrome {
    public static let menuButtonSide: CGFloat = 28.0
    public static let menuButtonGap: CGFloat = 6.0
    /// Width a row holds back so the control always fits on the last visual line.
    public static var menuButtonReserve: CGFloat { menuButtonSide + menuButtonGap }
}

/// The packed height of a row at `width`. Pure — it packs without building any view.
///
/// Mirrors `ButtonRowBox.measuredHeight(forWidth:)` including its floor: an EMPTY row still
/// occupies one pill's height, so it stays selectable and deletable rather than collapsing to
/// nothing.
@available(iOS 13.0, *)
public func richTextButtonRowHeight(buttons: [ButtonRef],
                                    alignment: ButtonRowAlignment,
                                    width: CGFloat,
                                    mapper: AttributedStringMapper,
                                    showsMenuAffordance: Bool) -> CGFloat {
    let metrics = mapper.styleSheet.metrics.button
    let packed = richTextPackButtonRow(
        buttons: buttons,
        alignment: alignment,
        availableWidth: max(0.0, width - (showsMenuAffordance ? RichTextButtonRowChrome.menuButtonReserve : 0.0)),
        metrics: metrics,
        isRTL: mapper.baseWritingDirection == .rightToLeft,
        hasIcon: { mapper.buttonHasIcon($0.action) },
        measure: { button, maxWidth, padding in
            mapper.buttonAttachment(button: button, isBlockPill: true, maxWidth: maxWidth,
                                    horizontalPadding: padding)
        }
    )
    return max(packed.totalHeight, metrics.blockRowHeight)
}

/// One rendered pill. Wraps the internal `ButtonPillView` rather than exposing it, so the module's
/// canvas types stay unpublished.
@available(iOS 13.0, *)
public final class RichTextButtonPillView: UIView {
    private let pill = ButtonPillView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        // Passthrough, like the canvas's own pill: taps are resolved geometrically by the host, which
        // keeps the editor's sole-`UITextInput` invariant intact.
        isUserInteractionEnabled = false
        addSubview(pill)
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    public func update(attachment: ButtonTextAttachment,
                       metrics: RichTextButtonMetrics,
                       emojiProvider: ((_ id: String, _ size: CGSize) -> (UIView & RichTextEmojiView)?)?) {
        pill.configure(attachment: attachment, metrics: metrics)
        if let emojiProvider {
            pill.syncEmoji(provider: emojiProvider, dynamicColor: attachment.colors.label)
        }
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        pill.frame = bounds
    }
}

/// A whole `pageBlockButtonRow`, packed and hosted.
///
/// The pills FILL their packed slots — a block pill's height is the fixed 40pt touch target and not
/// the label's ink box, which is an inline pill's height. Shrinking it to the ink box makes block
/// rows read as inline pills even when the packing allocated the right space, because the capsule
/// radius is `bounds.height / 2` and shrinks with it. `ButtonRowBackingView` learned this the hard
/// way; the comment travels with the behaviour.
@available(iOS 13.0, *)
public final class RichTextButtonRowView: UIView {
    private var pillViews: [RichTextButtonPillView] = []
    private let menuPillView = ButtonRowMenuPillView()
    private var frames: [CGRect] = []

    /// The packed height, floored at one pill row. What the attachment reserves.
    public private(set) var contentHeight: CGFloat = 0.0
    /// The "…" control's rect in this view's own space; `.zero` when it is hidden, so
    /// `.contains` declines it and hit-testing needs no second condition.
    public private(set) var menuButtonRect: CGRect = .zero

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        addSubview(menuPillView)
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    public func update(buttons: [ButtonRef],
                       alignment: ButtonRowAlignment,
                       width: CGFloat,
                       mapper: AttributedStringMapper,
                       showsMenuAffordance: Bool,
                       emojiProvider: ((_ id: String, _ size: CGSize) -> (UIView & RichTextEmojiView)?)?) {
        let metrics = mapper.styleSheet.metrics.button
        // Pills pack into the width MINUS the reserve. Reserving beats letting the control wrap: the
        // default alignment is `justify`, where pills stretch to fill the width, so an unreserved
        // control never fits and EVERY row would be two lines tall. The cost is that a justified pill
        // is ~34pt narrower here than in the sent message — the smaller distortion.
        let packed = richTextPackButtonRow(
            buttons: buttons,
            alignment: alignment,
            availableWidth: max(0.0, width - (showsMenuAffordance ? RichTextButtonRowChrome.menuButtonReserve : 0.0)),
            metrics: metrics,
            isRTL: mapper.baseWritingDirection == .rightToLeft,
            hasIcon: { mapper.buttonHasIcon($0.action) },
            measure: { button, maxWidth, padding in
                mapper.buttonAttachment(button: button, isBlockPill: true, maxWidth: maxWidth,
                                        horizontalPadding: padding)
            }
        )
        frames = packed.frames
        contentHeight = max(packed.totalHeight, metrics.blockRowHeight)

        // Pooled POSITIONALLY (pill i reuses view i): the packing returns frames in model order and a
        // `ButtonRef` is a pure value with no identity of its own.
        while pillViews.count > packed.attachments.count { pillViews.removeLast().removeFromSuperview() }
        while pillViews.count < packed.attachments.count {
            let view = RichTextButtonPillView()
            insertSubview(view, belowSubview: menuPillView)
            pillViews.append(view)
        }
        for (index, attachment) in packed.attachments.enumerated() where frames.indices.contains(index) {
            pillViews[index].update(attachment: attachment, metrics: metrics, emojiProvider: emojiProvider)
            pillViews[index].frame = frames[index]
        }

        if showsMenuAffordance {
            let side = RichTextButtonRowChrome.menuButtonSide
            menuButtonRect = CGRect(x: max(0.0, width - side),
                                    y: (frames.last?.minY ?? 0.0) + (metrics.blockRowHeight - side) / 2.0,
                                    width: side, height: side)
        } else {
            menuButtonRect = .zero
        }
        menuPillView.tintColorOverride = mapper.theme.accent
        menuPillView.frame = menuButtonRect
        menuPillView.isHidden = !showsMenuAffordance
    }

    /// The pill under `point` (this view's space), or nil.
    public func pillIndex(at point: CGPoint) -> Int? {
        frames.firstIndex { $0.contains(point) }
    }

    /// The pill NEAREST `point`, never nil for a non-empty row — so a tap anywhere in the row's band
    /// lands on a pill rather than falling through.
    public func nearestPillIndex(to point: CGPoint) -> Int? {
        guard !frames.isEmpty else { return nil }
        if let hit = pillIndex(at: point) { return hit }
        var best = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, rect) in frames.enumerated() {
            let dx = max(rect.minX - point.x, 0.0, point.x - rect.maxX)
            let dy = max(rect.minY - point.y, 0.0, point.y - rect.maxY)
            let distance = dx * dx + dy * dy
            if distance < bestDistance { bestDistance = distance; best = index }
        }
        return best
    }

    public func pillRect(_ index: Int) -> CGRect? {
        frames.indices.contains(index) ? frames[index] : nil
    }
}
#endif
