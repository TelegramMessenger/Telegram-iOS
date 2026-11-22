#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Reconciles pooled host media views against the laid-out document: reuse by owning `BlockID`,
    /// create via the provider for new blocks, size+position each at its media rect, tear down removed
    /// ones. Mirrors `syncEmojiViews`; media is simpler (one view per `MediaBlockBox`, positioned at the
    /// box's own canvas rect — no attachment-glyph scan). Called from `layoutSubviews` after blocks lay out.
    func syncMediaItemViews() {
        var present = Set<BlockID>()
        for box in allBoxesRecursive() {   // top level AND nested in a details / quote body
            guard let media = box as? MediaBlockBox else { continue }
            present.insert(media.id)
            let canvasRect = media.mediaRect()
            // Signature of the block's current media set — mediaID + kind + (rounded) natural size, in order.
            // A change (add / remove / reorder / natural-size change) invalidates the reused host view so the
            // provider rebuilds it for the new items (the seam is one-shot: a reused view can't be re-fed a
            // changed item list in place — that cross-mutation cell-reuse path is a deferred follow-up).
            let signature = media.displayMode.rawValue + "|" + media.items.map {
                "\($0.mediaID)#\($0.kind.rawValue)#\(Int($0.naturalSize.width.rounded()))x\(Int($0.naturalSize.height.rounded()))#s\($0.isSpoiler ? 1 : 0)"
            }.joined(separator: "|")
            let hosted: HostedMediaItem
            if let h = mediaItemViews[media.id], h.itemsSignature == signature {
                hosted = h
            } else {
                // Items changed (or first realization). Hand the existing view (if any) to the provider so
                // it can update IN PLACE — reusing surviving photo/video cells (fetch preserved, no re-flash)
                // — and return the SAME instance, or return a fresh one (recreate fallback), or nil = not ready.
                let existingView = mediaItemViews[media.id]?.view
                if let v = mediaViewProvider(media.items.map {
                    MediaProviderItem(mediaID: $0.mediaID, kind: $0.kind,
                                      naturalSize: CGSize(width: $0.naturalSize.width, height: $0.naturalSize.height),
                                      isSpoiler: $0.isSpoiler)
                }, media.id, media.displayMode, existingView) {
                    // Tear down a DIFFERENT prior instance (provider returned a fresh view, recreate fallback).
                    if let old = mediaItemViews[media.id], old.view !== v {
                        old.view.removeFromSuperview()
                    }
                    // Wire interaction + control routing. The wiring is refreshed every provider call so the
                    // captured `mediaID` (block primary) stays current across item removals (e.g. deletion of the
                    // first item shifts the primary to the old second item).
                    //
                    // Interaction-enabled so its `hitTest` is consulted, but the media view only claims a
                    // touch that lands on one of its interactive controls (the more button); the poster area
                    // returns nil and the touch falls through to the editor. See MediaPassthroughOverlayView.
                    v.isUserInteractionEnabled = true
                    // Route a control (more button) tap up through the account-free request path. Captures the
                    // occurrence BlockID (media.id) so delete targets THIS block even if mediaID repeats.
                    let blockID = media.id
                    let mediaID = media.mediaID
                    v.onControlTapped = { [weak self] kind, itemIndex, anchorView, rect in
                        self?.handleMediaControlTapped(blockID: blockID, mediaID: mediaID, itemIndex: itemIndex,
                                                       kind: kind, anchorView: anchorView, sourceRect: rect)
                    }
                    hosted = HostedMediaItem(view: v, canvasFrame: canvasRect, itemsSignature: signature)
                    mediaItemViews[media.id] = hosted
                } else {
                    continue   // provider not ready — keep any existing view, retry next layout pass
                }
            }
            hosted.canvasFrame = canvasRect
            if hosted.view.superview !== mediaOverlay { mediaOverlay.addSubview(hosted.view) }
            hosted.view.frame = canvasRect
            hosted.view.update(size: canvasRect.size)
        }
        for (id, h) in mediaItemViews where !present.contains(id) {
            h.view.removeFromSuperview()
            mediaItemViews[id] = nil
        }
        cullMediaItemViews()
    }

    /// Hides media views whose canvas frame is > `mediaCullMargin` outside the visible viewport.
    func cullMediaItemViews() {
        let visible: CGRect
        if let sv = superview as? UIScrollView {
            visible = CGRect(origin: sv.contentOffset, size: sv.bounds.size)
        } else {
            visible = bounds
        }
        let expanded = visible.insetBy(dx: -mediaCullMargin, dy: -mediaCullMargin)
        for (_, h) in mediaItemViews {
            h.view.isHidden = !expanded.intersects(h.canvasFrame)
        }
    }

    /// Builds the account-free `MediaControlRequest` for a tapped media control and fires
    /// `onRequestMediaControl`. `blockID` is the occurrence (stable across box re-instantiation); `mediaID`
    /// is the opaque host key the owner resolves the concrete media from. `delete` is bound to `blockID`, so
    /// it removes the exact occurrence even when `mediaID` is shared. `itemIndex` (nil = the whole block)
    /// routes `delete` to the per-item removal when the tap targeted one item of a container.
    func handleMediaControlTapped(blockID: BlockID, mediaID: String, itemIndex: Int?, kind: RichTextMediaControlKind,
                                  anchorView: UIView, sourceRect: CGRect) {
        // Current spoiler state for the tapped occurrence: the exact cell when `itemIndex` is in range, else
        // the block's first item (the ••• more menu targets the block; a per-cell delete targets one item).
        var isSpoiler = false
        if let box = boxes.first(where: { $0.id == blockID }) as? MediaBlockBox, case .media(let m) = box.currentBlock() {
            isSpoiler = itemIndex.flatMap { m.items.indices.contains($0) ? m.items[$0].isSpoiler : nil } ?? (m.items.first?.isSpoiler ?? false)
        }
        let request = MediaControlRequest(
            view: anchorView,
            sourceRect: sourceRect,
            control: kind,
            mediaID: mediaID,
            itemIndex: itemIndex,
            delete: { [weak self] in
                if let itemIndex { self?.deleteMediaItem(blockID: blockID, itemIndex: itemIndex) }
                else { self?.deleteMediaBlock(id: blockID) }
            },
            isSpoiler: isSpoiler,
            toggleSpoiler: { [weak self] in self?.toggleMediaSpoiler(blockID: blockID, itemIndex: itemIndex) },
            replace: nil,
            addMore: { [weak self] mediaID, naturalSize, kind in
                self?.addMediaItem(blockID: blockID, mediaID: mediaID,
                                   naturalSize: naturalSize, kind: kind)
            },
            toggleLayout: { [weak self] in self?.toggleMediaDisplayMode(blockID: blockID) }
        )
        onRequestMediaControl?(request)
    }

    /// Removes one item (by index) from a media container, leaving the rest. If only one item remains,
    /// removes the WHOLE block instead — routes to `deleteMediaBlock` (`+Editing.swift`), which already
    /// owns its own `editing { }` (one undo step) and REMOVES the block from its own stack, appending an
    /// empty paragraph only if that stack would otherwise be left with none. (Corrected Task 36c fix
    /// round: this said "turns the block into an empty paragraph via `deleteImageBoxOutcome`" — wrong
    /// about both the effect and the callee. `deleteImageBoxOutcome` has no callers at all; see its own
    /// doc comment, which is where that class of mis-attribution is described.) Otherwise rebuilds the
    /// box with the item removed, in place, mirroring the
    /// caption-split rebuild in `insertParagraphBreak` (`+Editing.swift` ~line 670): read the current
    /// `MediaBlock` off the box, mutate `items`, build a fresh `MediaBlockBox` reusing the old box's
    /// mapper/horizontalBleed/width, splice it into `boxes` in place, `recomputeSpans()` — all inside
    /// `editing { }` for one undo step. The mosaic is a single atom, so removing an item never changes the
    /// block's `nodeSize`/`textStart` and the caret (elsewhere in the document) is undisturbed by
    /// construction — no explicit anchor/head bookkeeping needed. Top-level media blocks only (mirrors
    /// `deleteMediaBlock`'s scope); no-op if `blockID` isn't found or `itemIndex` is out of range.
    func deleteMediaItem(blockID: BlockID, itemIndex: Int) {
        guard let (stack, index) = owningStack(ofBlockID: blockID), let mediaBox = stack.boxes[index] as? MediaBlockBox,
              case .media(let currentMedia) = mediaBox.currentBlock(), currentMedia.items.indices.contains(itemIndex) else { return }
        if currentMedia.items.count <= 1 {
            deleteMediaBlock(id: blockID)   // existing media-delete → empty paragraph; owns its own undo step
            return
        }
        editing {
            var newMedia = currentMedia
            newMedia.items.remove(at: itemIndex)
            // `effectiveWidth` is a placeholder — BlockStack.layout re-sets each box's width on the next pass,
            // so a nested box gets its (narrower) container width regardless.
            let newBox = MediaBlockBox(media: newMedia, mapper: mediaBox.mapper, width: effectiveWidth,
                                       horizontalBleed: mediaBox.horizontalBleed)
            stack.boxes[index] = newBox   // splice into the box's OWN stack (top-level or a container body)
            recomputeSpans()
            return .unchanged
        }
    }

    /// Appends a medium to the container owning `blockID` (add-more). Grows a single-media block into a
    /// mosaic. Same rebuild-in-place shape as `deleteMediaItem` above (mirrors `insertParagraphBreak`'s
    /// media-caption-split rebuild): read the current `MediaBlock`, append the new `MediaItem`, rebuild the
    /// box reusing the old mapper/horizontalBleed/width, splice into `boxes`, `recomputeSpans()`, inside
    /// `editing { }` for one undo step. `nodeSize` is caption-length-derived only, so appending an item
    /// never moves the caret. Top-level media blocks only; no-op if `blockID` isn't found.
    func addMediaItem(blockID: BlockID, mediaID: String, naturalSize: CGSize, kind: MediaKind) {
        guard let (stack, index) = owningStack(ofBlockID: blockID), let mediaBox = stack.boxes[index] as? MediaBlockBox,
              case .media(let currentMedia) = mediaBox.currentBlock() else { return }
        editing {
            var newMedia = currentMedia
            newMedia.items.append(MediaItem(mediaID: mediaID, kind: kind,
                                            naturalSize: Size2D(width: Double(naturalSize.width), height: Double(naturalSize.height))))
            let newBox = MediaBlockBox(media: newMedia, mapper: mediaBox.mapper, width: effectiveWidth,
                                       horizontalBleed: mediaBox.horizontalBleed)
            stack.boxes[index] = newBox   // splice into the box's OWN stack (top-level or a container body)
            recomputeSpans()
            return .unchanged
        }
    }

    /// Toggles the Telegram-style spoiler flag on a media block as ONE undo step. `itemIndex` non-nil and in
    /// range flips just that album cell; otherwise (single media, or `nil`) flips the WHOLE block, setting
    /// every item's `isSpoiler` to the negation of the first item's current value (so a mixed album unifies to
    /// a single toggled state). Same rebuild-in-place shape as `deleteMediaItem` / `addMediaItem` above (mirrors
    /// `insertParagraphBreak`'s media-caption-split rebuild): read the current `MediaBlock`, mutate `items`,
    /// rebuild the box reusing the old mapper/horizontalBleed/width, splice into `boxes`, `recomputeSpans()`,
    /// inside `editing { }` for one undo step. Spoiler is not a position-model concern (`nodeSize`/`textStart`
    /// are caption-derived only), so the caret is undisturbed. Top-level media blocks only; no-op if `blockID`
    /// isn't found.
    func toggleMediaSpoiler(blockID: BlockID, itemIndex: Int?) {
        guard let (stack, index) = owningStack(ofBlockID: blockID), let mediaBox = stack.boxes[index] as? MediaBlockBox,
              case .media(let currentMedia) = mediaBox.currentBlock() else { return }
        editing {
            var newMedia = currentMedia
            if let itemIndex, newMedia.items.indices.contains(itemIndex) {
                newMedia.items[itemIndex].isSpoiler.toggle()
            } else {
                let newValue = !(newMedia.items.first?.isSpoiler ?? false)
                for i in newMedia.items.indices { newMedia.items[i].isSpoiler = newValue }
            }
            let newBox = MediaBlockBox(media: newMedia, mapper: mediaBox.mapper, width: effectiveWidth,
                                       horizontalBleed: mediaBox.horizontalBleed)
            stack.boxes[index] = newBox   // splice into the box's OWN stack (top-level or a container body)
            recomputeSpans()
            return .unchanged
        }
    }

    /// Flips a multi-item media container's layout mode (mosaic ↔ slideshow) as ONE undo step. Same
    /// rebuild-in-place shape as `toggleMediaSpoiler` / `addMediaItem`: read the current `MediaBlock`, flip
    /// `displayMode`, rebuild the `MediaBlockBox` reusing the old mapper/horizontalBleed/width, splice into
    /// `boxes`, `recomputeSpans()`, inside `editing { }`. The mode is not a position-model concern
    /// (`nodeSize`/`textStart` are caption-derived only), so the caret is undisturbed. No-op if `blockID`
    /// isn't found or the block has fewer than 2 items (a single item has no album layout).
    func toggleMediaDisplayMode(blockID: BlockID) {
        guard let (stack, index) = owningStack(ofBlockID: blockID), let mediaBox = stack.boxes[index] as? MediaBlockBox,
              case .media(let currentMedia) = mediaBox.currentBlock(), currentMedia.items.count >= 2 else { return }
        editing {
            var newMedia = currentMedia
            newMedia.displayMode = (currentMedia.displayMode == .mosaic) ? .slideshow : .mosaic
            let newBox = MediaBlockBox(media: newMedia, mapper: mediaBox.mapper, width: effectiveWidth,
                                       horizontalBleed: mediaBox.horizontalBleed)
            stack.boxes[index] = newBox   // splice into the box's OWN stack (top-level or a container body)
            recomputeSpans()
            return .unchanged
        }
    }

    // MARK: Test accessors
    var hostedMediaCountForTesting: Int { mediaItemViews.count }
    func hostedMediaViewForTesting(_ id: BlockID) -> RichTextMediaItemView? { mediaItemViews[id]?.view }
    func hostedMediaItemSignatureForTesting(_ id: BlockID) -> String? { mediaItemViews[id]?.itemsSignature }
}

/// The `mediaOverlay` container. A full-bounds, visually-transparent pass-through: its `hitTest` returns
/// a hosted media view's subview ONLY when that media view claims the touch (i.e. the touch lands on an
/// interactive control such as the more button, per `MediaItemNodeView.hitTest`). Otherwise it returns
/// nil — NOT itself — so the canvas's own tap/caret/selection handling runs for taps on the media poster
/// and everywhere else. It must stay user-interaction-enabled or its `hitTest` (and the media views'
/// below it) would be skipped entirely.
@available(iOS 13.0, *)
final class MediaPassthroughOverlayView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }
}
#endif
