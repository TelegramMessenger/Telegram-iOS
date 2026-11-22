#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A hosted checklist checkbox view + its current canvas frame (mirrors `HostedEmoji`).
@available(iOS 13.0, *)
final class HostedChecklistMarker {
    let view: UIView & RichTextChecklistMarkerView
    var canvasFrame: CGRect
    init(view: UIView & RichTextChecklistMarkerView, canvasFrame: CGRect) {
        self.view = view; self.canvasFrame = canvasFrame
    }
}

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Creates/reuses/positions one checkbox view per top-level `.checklist` box and culls the rest.
    /// Mirrors `syncEmojiViews()`. No-op when no provider is set (glyph fallback).
    func syncChecklistMarkerViews() {
        guard let provider = checklistMarkerViewProvider else {
            for (_, h) in checklistMarkerViews { h.view.removeFromSuperview() }
            checklistMarkerViews.removeAll()
            return
        }
        var present = Set<BlockID>()
        for case let p as BlockBox in allBoxesRecursive() {   // top level AND nested in a details / quote body
            guard p.listMembership?.marker == .checklist, let rect = p.checklistMarkerCanvasRect() else { continue }
            present.insert(p.id)
            let checked = p.listMembership?.checked ?? false
            let hosted: HostedChecklistMarker
            if let h = checklistMarkerViews[p.id] {
                hosted = h
                hosted.view.setChecked(checked, animated: false)
            } else if let v = provider(checked, rect.size) {
                v.isUserInteractionEnabled = false   // the canvas owns taps; it hit-tests the rect
                hosted = HostedChecklistMarker(view: v, canvasFrame: rect)
                checklistMarkerViews[p.id] = hosted
            } else {
                continue
            }
            hosted.canvasFrame = rect
            if hosted.view.superview !== emojiOverlay { emojiOverlay.addSubview(hosted.view) }
            hosted.view.frame = rect
        }
        for (id, h) in checklistMarkerViews where !present.contains(id) {
            h.view.removeFromSuperview()
            checklistMarkerViews[id] = nil
        }
    }
}
#endif
