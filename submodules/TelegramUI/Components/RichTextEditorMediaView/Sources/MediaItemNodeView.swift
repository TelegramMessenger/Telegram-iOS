import Foundation
import UIKit
import ComponentFlow
import Display
import AppBundle
import AccountContext
import TelegramCore
import InstantPageUI
import RichTextEditorUIKit
import RichTextEditorCore
import MosaicLayout
import GlassBackgroundComponent

/// Adapts the rich-text editor's `RichTextMediaItemView` seam to concrete media renderers, by kind:
/// audio (music/voice `.file`) → `StandaloneInstantPageAudioView` (a playable row); location (`.geo`)
/// → `StandaloneInstantPageImageView` (map snapshot + pin); photo/video (ANY count, including 1) → a
/// UNIFIED cell pool of `RichTextMediaContentComponent`s hosted in `ComponentHostView`s.
///
/// **Unified pool (no single↔mosaic mode boundary):** photo/video always renders from `mosaicCells`.
/// count==1 is a single full-bounds cell (the mosaic engine `chatMessageBubbleMosaicLayout` has NO 1-item
/// case, so it is bypassed for count<=1 → the one cell fills `size`); count>=2 uses the album mosaic engine.
/// Removing the mode switch lets `MosaicCellDiff` reuse surviving cells across 1↔2↔3… transitions, so an
/// add-more / delete-one via `updateResolvedItems(_:)` preserves each survivor's bound fetch (no re-flash).
/// Audio/location stay on their `StandaloneInstantPage*` views (always single, never mutate).
///
/// The editor owns/positions/sizes the hosted view via `update(size:)`. `cornerRadius > 0` rounds the
/// container's corners for photo/video/location (audio stays square).
@available(iOS 13.0, *)
public final class MediaItemNodeView: UIView, RichTextMediaItemView, UIScrollViewDelegate {
    private let imageView: StandaloneInstantPageImageView?   // location (.geo) only
    private let audioView: StandaloneInstantPageAudioView?   // audio (music/voice) only
    private let documentView: StandaloneInstantPageDocumentView?   // document (generic file) only
    // Photo/video → a mosaic cell pool. count==1 is a single full-bounds cell (mosaic engine has no 1-item case).
    private var mosaicItems: [(media: EngineMedia, naturalSize: CGSize, isSpoiler: Bool, kind: MediaKind)] = []
    private var mosaicCells: [MosaicCellDiff.PooledKey: (host: ComponentHostView<Empty>, component: RichTextMediaContentComponent)] = [:]
    private var mosaicOccurrenceCounter: [EngineMedia.Id: Int] = [:]
    private let mosaicContext: AccountContext?   // set for photo/video; nil for audio/location
    private let showsControls: Bool   // forwarded to each photo/video cell's glass "more" button
    private var displayMode: MediaDisplayMode = .mosaic

    // Slideshow (swipeable carousel) chrome — lazily built, reused across mode toggles.
    private var slideshowScrollView: HorizontalPagingScrollView?
    private var slideshowPageControl: PageControlNode?

    // A dedicated "+" add button (article editor, photo/video containers only). Glass chrome mirroring the
    // per-cell ⋯ button (`RichTextMediaContentComponent.View`'s `moreButton`/`moreButtonBackgroundContainer`/
    // `moreButtonBackground`); top-right corner. Fires `.add` (container-level, itemIndex nil).
    private var addButtonContainer: GlassBackgroundContainerView?
    private var addButton: HighlightTrackingButton?
    private var addButtonBackground: GlassBackgroundView?
    private var addButtonIconView: UIImageView?

    // The layout-toggle "mosaic ↔ slideshow" button (article editor + photo/video containers, >= 2 items).
    // Glass chrome mirroring the add button; sits immediately LEFT of the "+".
    private var layoutToggleContainer: GlassBackgroundContainerView?
    private var layoutToggleButton: HighlightTrackingButton?
    private var layoutToggleBackground: GlassBackgroundView?
    private var layoutToggleIconView: UIImageView?

    /// Telegram albums cap at 10 media; the "+" add button is hidden once the container is full.
    private static let maxContainerItemCount = 10

    /// Shown iff the add button is (article editor + photo/video container) AND this is a togglable album (>= 2).
    /// Deliberately NOT gated on `canAddMoreItems` — the layout toggle stays available on a full (10-item) album.
    private var showsLayoutToggle: Bool { self.showsAddButton && self.mosaicItems.count >= 2 }

    /// True when this view should show the add button: article editor (`showsControls`) + a photo/video
    /// container (`mosaicContext != nil` — never audio/location).
    private var showsAddButton: Bool { self.showsControls && self.mosaicContext != nil }

    /// The add button is offered only while the container can still grow (fewer than the max).
    private var canAddMoreItems: Bool { self.mosaicItems.count < MediaItemNodeView.maxContainerItemCount }

    /// The "+" add button is actually on-screen: an article-editor photo/video container that can still grow.
    /// When false but `showsLayoutToggle` is true (a full album), the toggle button slides into the "+" slot.
    private var addButtonVisible: Bool { self.showsAddButton && self.canAddMoreItems }

    public init(context: AccountContext,
                items: [(media: EngineMedia, naturalSize: CGSize, isSpoiler: Bool, kind: MediaKind)],
                audioColorOverride: InstantPageAudioColorOverride? = nil,
                documentColorOverride: InstantPageDocumentColorOverride? = nil,
                cornerRadius: CGFloat = 0,
                showsControls: Bool = true,
                displayMode: MediaDisplayMode = .mosaic) {
        self.showsControls = showsControls
        self.displayMode = displayMode
        if items.count == 1, items[0].kind == .document, case let .file(file) = items[0].media {
            // Dispatch on the EDITOR's kind, not by sniffing the media: an image-mime file picked from
            // the Files tab is a document row, and sniffing would send it to the photo pool below.
            self.documentView = StandaloneInstantPageDocumentView(context: context, file: file, colorOverride: documentColorOverride)
            self.audioView = nil
            self.imageView = nil
            self.mosaicContext = nil
            super.init(frame: .zero)
            self.addSubview(self.documentView!)
        } else if items.count == 1, case let .file(file) = items[0].media, file.isMusic || file.isVoice {
            self.documentView = nil
            self.audioView = StandaloneInstantPageAudioView(context: context, file: file, colorOverride: audioColorOverride)
            self.imageView = nil
            self.mosaicContext = nil
            super.init(frame: .zero)
            self.addSubview(self.audioView!)
        } else if items.count == 1, case .geo = items[0].media {
            let attributes: [InstantPageImageAttribute] = [InstantPageMapAttribute(zoom: 15, dimensions: CGSize(width: 600.0, height: 300.0))]
            self.documentView = nil
            self.imageView = StandaloneInstantPageImageView(context: context, media: items[0].media, attributes: attributes)
            self.audioView = nil
            self.mosaicContext = nil
            super.init(frame: .zero)
            self.addSubview(self.imageView!)
        } else {
            // Photo/video (any count) — the mosaic cell pool. count==1 fills bounds.
            self.documentView = nil
            self.imageView = nil
            self.audioView = nil
            self.mosaicContext = context
            super.init(frame: .zero)
            self.mosaicItems = items
        }
        // Round photo/video/location corners on request; audio and document rows stay square.
        if cornerRadius > 0, self.audioView == nil, self.documentView == nil {
            self.layer.cornerRadius = cornerRadius
            self.layer.masksToBounds = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Editor-set control-tap hook `(kind, itemIndex, anchorView, sourceRect)`. For a single-item container the
    /// cell reports `itemIndex == nil` (whole block — byte-identical to pre-container behavior); a ≥2 mosaic
    /// reports the touched cell's index. Audio/location are non-interactive (no cells wire it).
    public var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?

    /// Re-render with a NEW resolved item list (add-more / delete-one), reusing surviving cells via
    /// `MosaicCellDiff` so their bound fetch is preserved (no re-flash). No-op for audio/location.
    public func updateResolvedItems(_ items: [(media: EngineMedia, naturalSize: CGSize, isSpoiler: Bool, kind: MediaKind)],
                                    displayMode: MediaDisplayMode = .mosaic) {
        guard self.mosaicContext != nil else { return }
        self.mosaicItems = items
        self.displayMode = displayMode
        self.updatePhotoVideoLayout(size: self.bounds.size)
    }

    public func update(size: CGSize) {
        self.imageView?.frame = CGRect(origin: .zero, size: size)
        self.imageView?.update(size: size)
        self.audioView?.frame = CGRect(origin: .zero, size: size)
        self.audioView?.update(size: size)
        self.documentView?.frame = CGRect(origin: .zero, size: size)
        self.documentView?.update(size: size)
        if self.mosaicContext != nil {
            self.updatePhotoVideoLayout(size: size)
        }
        self.layoutAddButton(size: size)
        self.layoutToggleButtonLayout(size: size)
    }

    /// Chooses the mosaic grid or the slideshow carousel for the current mode (slideshow only for >= 2 items).
    private func updatePhotoVideoLayout(size: CGSize) {
        guard self.mosaicContext != nil else { return }
        if self.displayMode == .slideshow && self.mosaicItems.count >= 2 {
            self.updateSlideshow(size: size)
        } else {
            self.teardownSlideshowChrome()
            self.updateMosaic(size: size)
        }
    }

    /// Builds the add button's glass chrome on first use (article-editor photo/video containers only).
    /// Mirrors `RichTextMediaContentComponent.View`'s more-button setup exactly: background inside the
    /// button, button inside the container's `contentView`, container added last (above everything else).
    private func ensureAddButton() {
        guard self.addButtonContainer == nil else { return }
        let container = GlassBackgroundContainerView()
        let background = GlassBackgroundView()
        let button = HighlightTrackingButton()
        background.isUserInteractionEnabled = false
        button.addSubview(background)
        container.contentView.addSubview(button)
        self.addSubview(container)
        let iconView = UIImageView(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: .white))
        iconView.contentMode = .center
        button.addSubview(iconView)
        button.addTarget(self, action: #selector(self.addButtonPressed), for: .touchUpInside)
        button.highligthedChanged = { [weak button] highlighted in
            guard let button else { return }
            let transition: ComponentTransition = highlighted ? .immediate : .easeInOut(duration: 0.25)
            transition.setAlpha(view: button, alpha: highlighted ? 0.6 : 1.0)
        }
        self.addButtonContainer = container
        self.addButton = button
        self.addButtonBackground = background
        self.addButtonIconView = iconView
    }

    @objc private func addButtonPressed() {
        guard let container = self.addButtonContainer else { return }
        self.onControlTapped?(.add, nil, container, container.bounds)
    }

    /// Positions the add button top-right and shows/hides it (`showsAddButton`). Brought above the mosaic
    /// cells every pass since cell hosts are inserted after it may have been created.
    private func layoutAddButton(size: CGSize) {
        guard self.addButtonVisible else {
            self.addButtonContainer?.isHidden = true
            return
        }
        self.ensureAddButton()
        guard let container = self.addButtonContainer, let button = self.addButton,
              let background = self.addButtonBackground, let iconView = self.addButtonIconView else { return }
        container.isHidden = false
        let buttonSize = CGSize(width: 36.0, height: 36.0)
        let inset: CGFloat = 8.0
        let frame = CGRect(x: size.width - inset - buttonSize.width, y: inset, width: buttonSize.width, height: buttonSize.height)   // top-right
        container.frame = frame
        container.update(size: buttonSize, isDark: true, transition: .immediate)
        background.frame = CGRect(origin: .zero, size: buttonSize)
        background.update(size: buttonSize, cornerRadius: buttonSize.height * 0.5, isDark: true, tintColor: .init(kind: .panel), transition: .immediate)
        button.frame = CGRect(origin: .zero, size: buttonSize)
        iconView.frame = CGRect(origin: .zero, size: buttonSize)
        self.bringSubviewToFront(container)   // above the mosaic cells
    }

    /// Lays out photo/video cells, reusing an existing cell wherever `MosaicCellDiff` finds a matching pooled
    /// occurrence for the incoming media ids (bound fetch preserved). count==1 fills `size`; count>=2 uses the
    /// album mosaic engine.
    ///
    /// `EngineMedia.id` is `EngineMedia.Id?` on the general enum (some kinds carry no stable identity); the
    /// pool only ever holds photo/video (`.image`/`.file`), whose `.id` is non-nil in practice, so the
    /// `compactMap` below is a defensive guard. An id-less item is skipped entirely (no cell rendered) rather
    /// than force-unwrapped or given a synthetic key — there is no stable identity to pool/reuse it by.
    private func updateMosaic(size: CGSize) {
        guard self.mosaicContext != nil else { return }
        let frames: [CGRect]
        if self.mosaicItems.count <= 1 {
            frames = [CGRect(origin: .zero, size: size)]
        } else {
            // Same cap the box reserves (MediaBlockBox.mosaicSize): pack within width × min(1000,width),
            // then scale-to-fit + center when the width-driven pack still exceeds the cap.
            let cap = min(1000.0, size.width)
            let (rawFrames, naturalSize) = chatMessageBubbleMosaicLayout(
                maxSize: CGSize(width: size.width, height: cap),
                itemSizes: self.mosaicItems.map { $0.naturalSize })
            let scale: CGFloat = naturalSize.height > cap ? cap / naturalSize.height : 1.0
            let xOffset = floor((size.width - naturalSize.width * scale) / 2.0)
            frames = rawFrames.map { frame, _ in
                CGRect(x: xOffset + frame.minX * scale, y: frame.minY * scale,
                       width: frame.width * scale, height: frame.height * scale)
            }
        }
        self.applyCells(into: self, frames: frames, size: size,
                        usesAspectFit: self.mosaicItems.count == 1, reportNilIndex: self.mosaicItems.count == 1)
    }

    /// Builds/reuses/positions the photo-video cells at `frames` inside `container`, diffed by media identity
    /// (`MosaicCellDiff`) so survivors keep their bound fetch. `usesAspectFit` and `reportNilIndex` match the
    /// current mode. Shared by the mosaic grid and the slideshow carousel. Cells beyond `frames.count` fall
    /// back to `size`-filling frames.
    ///
    /// `EngineMedia.id` is `EngineMedia.Id?` on the general enum (some kinds carry no stable identity); the
    /// pool only ever holds photo/video (`.image`/`.file`), whose `.id` is non-nil in practice, so the
    /// `compactMap` below is a defensive guard. An id-less item is skipped entirely (no cell rendered).
    private func applyCells(into container: UIView, frames: [CGRect], size: CGSize,
                            usesAspectFit: Bool, reportNilIndex: Bool) {
        guard let context = self.mosaicContext else { return }
        // Diff by media identity so surviving cells are reused (fetch bound once), not rebuilt.
        let incomingIds: [EngineMedia.Id] = self.mosaicItems.compactMap { $0.media.id }
        let plan = MosaicCellDiff.plan(poolKeys: Array(self.mosaicCells.keys), incoming: incomingIds)
        // Tear down removed cells (their spoiler blur/dust are inside the cell's component, torn down with it).
        for key in plan.removed {
            self.mosaicCells[key]?.host.removeFromSuperview()
            self.mosaicCells[key] = nil
        }
        // `reuseIndex` walks `plan.reuse` in lockstep with `incomingIds` — both were built by iterating
        // `mosaicItems` in order and skipping id-less items identically, so the two stay aligned.
        var reuseIndex = 0
        for (index, item) in self.mosaicItems.enumerated() {
            guard let mediaId = item.media.id else { continue }
            let frame = index < frames.count ? frames[index] : CGRect(origin: .zero, size: size)
            let host: ComponentHostView<Empty>
            let cellKey: MosaicCellDiff.PooledKey
            if let reusedKey = plan.reuse[reuseIndex], let existingHost = self.mosaicCells[reusedKey]?.host {
                host = existingHost   // reuse the fetch-bound host (the cell's poster stays bound once)
                cellKey = reusedKey
            } else {
                // Fresh cell: unique occurrence key so duplicate media get distinct pool slots.
                let occurrence = self.mosaicOccurrenceCounter[mediaId, default: 0]
                self.mosaicOccurrenceCounter[mediaId] = occurrence + 1
                cellKey = MosaicCellDiff.PooledKey(id: mediaId, occurrence: occurrence)
                let newHost = ComponentHostView<Empty>()
                host = newHost
            }
            reuseIndex += 1
            // Re-parent a pooled cell into `container` (mosaic `self` ↔ the slideshow scroll view) WITHOUT
            // tearing it down, so the bound fetch survives a mode toggle (no re-flash).
            if host.superview !== container { container.addSubview(host) }
            let reportedIndex: Int? = reportNilIndex ? nil : index
            // A FRESH component each pass (reusing only the fetch-bound host): `ComponentHostView` skips
            // `update` when the component compares equal at an unchanged size, so mutating a reused
            // instance's `isSpoiler` in place would be a no-op on a same-size spoiler toggle. Passing a new
            // component whose `isSpoiler` (part of `==`) reflects the current state is what makes the toggle
            // re-render. `usesAspectFit` rides a size change (1↔mosaic), so it needn't be in `==`.
            let component = RichTextMediaContentComponent(context: context, media: item.media, showsMoreButton: self.showsControls, usesAspectFit: usesAspectFit, isSpoiler: item.isSpoiler)
            component.onControlTapped = { [weak self] kind, anchorView, rect in
                self?.onControlTapped?(kind, reportedIndex, anchorView, rect)
            }
            self.mosaicCells[cellKey] = (host, component)
            host.frame = frame
            _ = host.update(transition: .immediate, component: AnyComponent(component),
                            environment: {}, containerSize: frame.size)
        }
    }

    /// Renders/reuses the swipeable carousel: a horizontal-only paging scroll view with one full-size page
    /// per item and a bottom page control. Reused across mode toggles; the cells are re-parented into the
    /// scroll view by `applyCells` (fetch preserved).
    private func updateSlideshow(size: CGSize) {
        guard self.mosaicContext != nil else { return }
        let scroll: HorizontalPagingScrollView
        if let existing = self.slideshowScrollView {
            scroll = existing
        } else {
            scroll = HorizontalPagingScrollView()
            scroll.isPagingEnabled = true
            scroll.showsHorizontalScrollIndicator = false
            scroll.showsVerticalScrollIndicator = false
            scroll.scrollsToTop = false
            scroll.contentInsetAdjustmentBehavior = .never   // always available (class is @available iOS 13)
            scroll.delegate = self
            self.addSubview(scroll)
            self.slideshowScrollView = scroll
        }
        scroll.frame = CGRect(origin: .zero, size: size)

        let count = self.mosaicItems.count
        let pageFrames = (0..<count).map { CGRect(x: CGFloat($0) * size.width, y: 0, width: size.width, height: size.height) }
        self.applyCells(into: scroll, frames: pageFrames, size: size, usesAspectFit: true, reportNilIndex: false)
        scroll.contentSize = CGSize(width: CGFloat(count) * size.width, height: size.height)

        let pageControl: PageControlNode
        if let existing = self.slideshowPageControl {
            pageControl = existing
        } else {
            pageControl = PageControlNode(dotColor: .white, inactiveDotColor: UIColor(white: 1.0, alpha: 0.5))
            pageControl.isUserInteractionEnabled = false
            self.addSubview(pageControl.view)
            self.slideshowPageControl = pageControl
        }
        pageControl.pagesCount = count
        let page = size.width > 0 ? Int((scroll.contentOffset.x + size.width / 2) / size.width) : 0
        pageControl.setPage(CGFloat(max(0, min(count - 1, page))))
        pageControl.layer.transform = CATransform3DIdentity
        pageControl.frame = CGRect(x: 0, y: size.height - 20, width: size.width, height: 20)
        let maxWidth = size.width - 36
        let pcSize = pageControl.calculateSizeThatFits(size)
        if pcSize.width > maxWidth, pcSize.width > 0 {
            pageControl.layer.transform = CATransform3DMakeScale(maxWidth / pcSize.width, maxWidth / pcSize.width, 1)
        }
        self.bringSubviewToFront(pageControl.view)
    }

    /// Re-parents any slideshow cells back into `self` and removes the carousel chrome (called when switching
    /// to mosaic). The cells themselves are preserved in `mosaicCells` (re-parented by `applyCells` next pass).
    private func teardownSlideshowChrome() {
        guard self.slideshowScrollView != nil || self.slideshowPageControl != nil else { return }
        for (_, cell) in self.mosaicCells where cell.host.superview === self.slideshowScrollView {
            self.addSubview(cell.host)
        }
        self.slideshowScrollView?.removeFromSuperview()
        self.slideshowScrollView = nil
        self.slideshowPageControl?.view.removeFromSuperview()
        self.slideshowPageControl = nil
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === self.slideshowScrollView, let pageControl = self.slideshowPageControl else { return }
        let width = self.bounds.size.width
        guard width > 0, !self.mosaicItems.isEmpty else { return }
        let page = Int((scrollView.contentOffset.x + width / 2) / width)
        pageControl.setPage(CGFloat(max(0, min(self.mosaicItems.count - 1, page))))
    }

    /// Builds the layout-toggle button's glass chrome on first use. Mirrors `ensureAddButton`.
    private func ensureLayoutToggleButton() {
        guard self.layoutToggleContainer == nil else { return }
        let container = GlassBackgroundContainerView()
        let background = GlassBackgroundView()
        let button = HighlightTrackingButton()
        background.isUserInteractionEnabled = false
        button.addSubview(background)
        container.contentView.addSubview(button)
        self.addSubview(container)
        let iconView = UIImageView()
        iconView.contentMode = .center
        button.addSubview(iconView)
        button.addTarget(self, action: #selector(self.layoutTogglePressed), for: .touchUpInside)
        button.highligthedChanged = { [weak button] highlighted in
            guard let button else { return }
            let transition: ComponentTransition = highlighted ? .immediate : .easeInOut(duration: 0.25)
            transition.setAlpha(view: button, alpha: highlighted ? 0.6 : 1.0)
        }
        self.layoutToggleContainer = container
        self.layoutToggleButton = button
        self.layoutToggleBackground = background
        self.layoutToggleIconView = iconView
    }

    @objc private func layoutTogglePressed() {
        guard let container = self.layoutToggleContainer else { return }
        self.onControlTapped?(.toggleLayout, nil, container, container.bounds)
    }

    /// Positions the toggle button IMMEDIATELY LEFT of the add button and shows/hides it. Icon depicts the
    /// layout you'll switch TO: a carousel glyph while currently mosaic, a grid glyph while currently slideshow.
    private func layoutToggleButtonLayout(size: CGSize) {
        guard self.showsLayoutToggle else {
            self.layoutToggleContainer?.isHidden = true
            return
        }
        self.ensureLayoutToggleButton()
        guard let container = self.layoutToggleContainer, let button = self.layoutToggleButton,
              let background = self.layoutToggleBackground, let iconView = self.layoutToggleIconView else { return }
        container.isHidden = false
        let buttonSize = CGSize(width: 36.0, height: 36.0)
        let inset: CGFloat = 8.0
        let spacing: CGFloat = 6.0
        // Normally sits left of the add button (which is at x = width - inset - 36); when the add button is
        // hidden (a full album), slide right into its top-right slot so the corner isn't left empty.
        let rightmostX = size.width - inset - buttonSize.width
        let originX = self.addButtonVisible ? (rightmostX - spacing - buttonSize.width) : rightmostX
        let frame = CGRect(x: originX, y: inset, width: buttonSize.width, height: buttonSize.height)
        container.frame = frame
        container.update(size: buttonSize, isDark: true, transition: .immediate)
        background.frame = CGRect(origin: .zero, size: buttonSize)
        background.update(size: buttonSize, cornerRadius: buttonSize.height * 0.5, isDark: true, tintColor: .init(kind: .panel), transition: .immediate)
        button.frame = CGRect(origin: .zero, size: buttonSize)
        let imageName = self.displayMode == .slideshow ? "RichText/ToolCollage" : "RichText/ToolSlideshow"
        iconView.image = UIImage(bundleImageName: imageName)?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = .white
        iconView.frame = CGRect(origin: .zero, size: buttonSize)
        self.bringSubviewToFront(container)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.frame = self.bounds
        self.audioView?.frame = self.bounds
        self.documentView?.frame = self.bounds
        if self.mosaicContext != nil {
            self.updatePhotoVideoLayout(size: self.bounds.size)
        }
        self.layoutAddButton(size: self.bounds.size)
        self.layoutToggleButtonLayout(size: self.bounds.size)
    }

    /// The editor treats media as non-interactive EXCEPT for the interactive controls the photo/video
    /// renderer exposes (the per-cell more button, and — article editor only — this container's own add
    /// button). Only a hit that resolves to such a control claims the touch; everything else — the poster
    /// area, and the audio/location branches entirely — returns nil so the touch falls through to the
    /// editor's own tap handling. Guarded by the standard visibility/point-inside checks so a culled
    /// (hidden) media view never claims a touch. The add button is checked FIRST since it visually sits
    /// above the mosaic cells in the top-right corner.
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !self.isHidden, self.isUserInteractionEnabled, self.alpha > 0.01,
              self.point(inside: point, with: event) else {
            return nil
        }
        if self.addButtonVisible, let container = self.addButtonContainer, !container.isHidden {
            let inContainer = container.convert(point, from: self)
            if let hit = container.hitTest(inContainer, with: event) {
                return hit
            }
        }
        if self.showsLayoutToggle, let container = self.layoutToggleContainer, !container.isHidden {
            let inContainer = container.convert(point, from: self)
            if let hit = container.hitTest(inContainer, with: event) { return hit }
        }
        if self.mosaicContext != nil {
            if let scroll = self.slideshowScrollView, !scroll.isHidden {
                // Per-cell controls (e.g. the more button) still win — they live inside the scroll's cells.
                for (_, cell) in self.mosaicCells {
                    let inHost = cell.host.convert(point, from: self)
                    if cell.host.point(inside: inHost, with: event),
                       let hit = cell.host.hitTest(inHost, with: event), hit !== cell.host {
                        return hit
                    }
                }
                let inScroll = scroll.convert(point, from: self)
                if scroll.point(inside: inScroll, with: event) { return scroll }
            }
            for (_, cell) in self.mosaicCells {
                let inHost = cell.host.convert(point, from: self)
                if cell.host.point(inside: inHost, with: event),
                   let hit = cell.host.hitTest(inHost, with: event), hit !== cell.host {
                    return hit
                }
            }
            return nil
        }
        return nil   // audio / location / document — non-interactive
    }
}

/// A paging scroll view that begins its pan ONLY for a predominantly-horizontal drag, so a vertical drag
/// falls through to the editor's own scroll (mirrors the repo's `GripYieldingScrollView` yield pattern).
@available(iOS 13.0, *)
final class HorizontalPagingScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.panGestureRecognizer {
            let t = self.panGestureRecognizer.translation(in: self)
            if abs(t.y) > abs(t.x) { return false }   // vertical → let the editor scroll
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}
