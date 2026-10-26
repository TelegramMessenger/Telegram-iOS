#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Hosting for INLINE `textButton` pills. A block row's pills are subviews of its own
/// `ButtonRowBackingView`; an inline pill sits in the text flow, so it is hosted here at its
/// attachment's rect — a direct mirror of `syncEmojiViews`, which does the same for inline emoji.
///
/// The pill is a VIEW rather than a rasterised attachment image because its label may contain a custom
/// emoji, which needs a live host view. `ButtonTextAttachment` therefore carries only a clear spacer and
/// reserves the box; everything visible is drawn by the hosted `ButtonPillView`.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    struct HostedButtonPill {
        let view: ButtonPillView
        var canvasFrame: CGRect
    }

    /// Re-hosts every inline pill. Pooled by the pill's GLOBAL POSITION — an inline button has no stable
    /// identity of its own (`ButtonRef` is a pure value), so an edit that shifts it re-hosts it. Pills are
    /// cheap to rebuild; the emoji INSIDE a pill are pooled by `instanceID` in the pill view itself, so a
    /// running animation survives as long as the pill keeps its position.
    func syncButtonPillViews() {
        var wanted = Set<Int>()

        for region in allLeafRegions() {
            let attr = region.layout.attributedString
            let full = NSRange(location: 0, length: attr.length)
            attr.enumerateAttribute(.attachment, in: full, options: []) { value, range, _ in
                guard let attachment = value as? ButtonTextAttachment,
                      let box = region.layout.attachmentBox(at: range.location)
                else { return }
                let key = region.globalStart + range.location
                wanted.insert(key)
                let canvasRect = box.offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y)

                let hosted: HostedButtonPill
                if let existing = buttonPillViews[key] {
                    hosted = existing
                } else {
                    let view = ButtonPillView()
                    hosted = HostedButtonPill(view: view, canvasFrame: canvasRect)
                    buttonPillViews[key] = hosted
                }
                hosted.view.configure(attachment: attachment, metrics: self.mapper.styleSheet.metrics.button)
                buttonPillViews[key]?.canvasFrame = canvasRect
                placeButtonPill(hosted, canvasRect: canvasRect, regionStart: region.globalStart)
                hosted.view.syncEmoji(provider: self.emojiViewProvider,
                                      dynamicColor: attachment.colors.label)
            }
        }

        for (key, hosted) in buttonPillViews where !wanted.contains(key) {
            hosted.view.removeFromSuperview()
            buttonPillViews[key] = nil
        }
        cullButtonPillViews()
    }

    /// Parents + frames one hosted pill. Table-cell pills go into the table's scrolling content view so
    /// they ride the horizontal scroll; everything else goes into the canvas-level `emojiOverlay`.
    /// Identical rule to `placeEmoji` — an inline pill is an inline atom exactly as an emoji is.
    private func placeButtonPill(_ hosted: HostedButtonPill, canvasRect: CGRect, regionStart: Int) {
        if let table = tableBox(containingGlobal: regionStart),
           let tv = blockViews[table.id] as? TableBackingView {
            let contentFrame = canvasRect.offsetBy(dx: -table.frame.minX, dy: -table.frame.minY)
            tv.hostEmoji(hosted.view, at: contentFrame)
        } else {
            if hosted.view.superview !== emojiOverlay { emojiOverlay.addSubview(hosted.view) }
            hosted.view.frame = canvasRect
        }
    }

    /// Mirrors `cullEmojiViews`, including its table exemption: a table-cell pill's `canvasFrame` is the
    /// UNSCROLLED rect, which would mis-score a horizontally-scrolled cell, so the table clips instead.
    func cullButtonPillViews() {
        let visible: CGRect
        if let sv = superview as? UIScrollView {
            visible = CGRect(origin: sv.contentOffset, size: sv.bounds.size)
        } else {
            visible = bounds
        }
        let expanded = visible.insetBy(dx: -emojiCullMargin, dy: -emojiCullMargin)
        for (_, hosted) in buttonPillViews {
            if hosted.view.superview is TableContentView {
                hosted.view.isHidden = false
                continue
            }
            hosted.view.isHidden = !expanded.intersects(hosted.canvasFrame)
        }
    }

    /// Test accessor: how many inline pills are currently hosted.
    var hostedButtonPillCountForTesting: Int { buttonPillViews.count }
}
#endif
