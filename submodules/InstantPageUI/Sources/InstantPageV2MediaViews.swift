import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import GalleryUI
import UniversalMediaPlayer
import TelegramUniversalVideoContent
import InvisibleInkDustNode

// Mutable weak box: lets a wrapper hand its `openMedia` closure a back-reference to itself,
// filled in after `super.init` (when `self` becomes usable). SwiftSignalKit's `Weak<T>` requires
// a non-optional value at init time, so it can't be used here.
private final class WrapperRef {
    weak var view: UIView?
}

// MARK: - Revealable spoiler dust cover

// Manages a revealable "dust" cover over a spoiler photo/video in a SENT/received rich message.
// Mirrors the message-side `ExtendedMediaOverlayNode` (ChatMessageInteractiveMediaNode): a
// `MediaDustNode` hosted inside a container node whose view is masked away during the reveal
// animation. The cover is purely visual (user interaction disabled), so taps fall through to the
// wrapped media node; the enclosing media view GATES its `openMedia` closure so that while the
// cover is `concealed` the first tap calls `reveal()` instead of opening the gallery. Once
// revealed (`concealed == false`) the cover is removed and taps open the gallery as normal.
final class MediaSpoilerDustOverlay {
    let containerNode: ASDisplayNode
    private let dustNode: MediaDustNode
    // The heavily-blurred cover (from `InstantPageImageNode.makeSpoilerBlurredNode()`), hosted BELOW the
    // dust in this container. Both sit ABOVE the always-sharp wrapped node, so the dust's reveal mask —
    // which masks its supernode (this container) away in an expanding circle from the tap — clears blur +
    // dust TOGETHER and exposes the sharp media beneath, exactly like `ExtendedMediaOverlayNode`.
    let blurredImageNode: TransformImageNode?
    // The media id the cover was built for; used so a positionally-reused view resets its reveal
    // state only when the underlying media actually changes (see `InstantPageV2MediaImageView`).
    let mediaId: EngineMedia.Id?
    private(set) var concealed: Bool = true

    init(enableAnimations: Bool, mediaId: EngineMedia.Id?, blurredImageNode: TransformImageNode?) {
        self.mediaId = mediaId
        self.dustNode = MediaDustNode(enableAnimations: enableAnimations)
        self.containerNode = ASDisplayNode()
        self.blurredImageNode = blurredImageNode
        // Purely visual: let taps reach the wrapped media node, whose gated openMedia drives reveal.
        self.containerNode.isUserInteractionEnabled = false
        self.dustNode.isUserInteractionEnabled = false
        self.dustNode.revealOnTap = false
        self.dustNode.isRevealed = false
        if let blurredImageNode {
            self.containerNode.addSubnode(blurredImageNode)   // blur below dust
        }
        self.containerNode.addSubnode(self.dustNode)
        self.dustNode.revealed = { [weak self] in
            guard let self else { return }
            self.concealed = false
            self.containerNode.view.removeFromSuperview()
        }
    }

    func updateLayout(size: CGSize) {
        self.containerNode.frame = CGRect(origin: .zero, size: size)
        self.blurredImageNode?.frame = CGRect(origin: .zero, size: size)
        self.dustNode.frame = CGRect(origin: .zero, size: size)
        self.dustNode.update(size: size, color: .white, transition: .immediate)
    }

    func reveal() {
        guard self.concealed else { return }
        self.concealed = false
        // Mirror ExtendedMediaOverlayNode.reveal(animated:): drive the dust node's own tap-reveal
        // animation, which masks the container (blur + dust) away over the sharp media and fires
        // `revealed` on completion.
        self.dustNode.revealOnTap = true
        self.dustNode.tap(at: CGPoint(x: self.dustNode.bounds.width / 2.0, y: self.dustNode.bounds.height / 2.0))
    }
}

// MARK: - Shared media node factory

// Hosts a V1 `InstantPageImageNode` inside a V2 UIView wrapper. The caller sizes its own
// frame from `item.frame` and adds the returned node's view as a subview.
func makeMediaWrapper(
    frame: CGRect,
    media: InstantPageMedia,
    webPage: TelegramMediaWebpage,
    attributes: [InstantPageImageAttribute],
    renderContext: InstantPageV2RenderContext,
    theme: InstantPageTheme,
    openMedia: @escaping (InstantPageMedia) -> Void,
    longPressMedia: @escaping (InstantPageMedia) -> Void,
    emptyColor: UIColor? = nil,
    fit: Bool = false
) -> InstantPageImageNode {
    let imageNode = InstantPageImageNode(
        context: renderContext.context,
        sourceLocation: renderContext.sourceLocation,
        theme: theme,
        webPage: webPage,
        media: media,
        attributes: attributes,
        interactive: true,
        roundCorners: false,
        fit: fit,
        openMedia: openMedia,
        longPressMedia: longPressMedia,
        activatePinchPreview: nil,
        pinchPreviewFinished: nil,
        imageReferenceForMedia: renderContext.imageReference,
        fileReferenceForMedia: renderContext.fileReference,
        autoDownloadImage: renderContext.shouldAutoDownloadImage,
        autoDownloadFile: renderContext.shouldAutoDownloadFile,
        emptyColor: emptyColor,
        getPreloadedResource: { _ in nil }
    )
    imageNode.captureProtected = renderContext.captureProtected
    imageNode.frame = CGRect(origin: .zero, size: frame.size)
    return imageNode
}

// Walks up the superview chain from `start` to find the nearest enclosing `InstantPageV2View`.
private func findEnclosingV2View(from start: UIView?) -> InstantPageV2View? {
    var view: UIView? = start
    while view != nil {
        if let v2 = view as? InstantPageV2View {
            return v2
        }
        view = view?.superview
    }
    return nil
}

// Registers `wrapper` in the root V2View's `mediaRegistry` under `mediaIndex`. The root is
// reached by walking up the superview chain to the nearest `InstantPageV2View`, then walking
// its `rootMediaRegistryHost` chain transitively (nested details blocks can leave an inner
// body's host pointing at an intermediate body — see `trueRegistryRoot`). No-op if the wrapper
// isn't yet attached to a V2View ancestor.
func registerInRootRegistry(wrapper: UIView, mediaIndex: Int) {
    guard let v2 = findEnclosingV2View(from: wrapper.superview) else { return }
    v2.trueRegistryRoot.mediaRegistry[mediaIndex] = Weak(wrapper)
}

// Routes a tap on `tapped` through `openInstantPageMedia`, sourcing sibling medias from the
// root V2View's `currentLayout`. No-op if the wrapper isn't currently in a V2View tree.
func handleOpenMediaTap(
    tapped: InstantPageMedia,
    wrapper: UIView,
    renderContext: InstantPageV2RenderContext
) {
    guard let v2 = findEnclosingV2View(from: wrapper.superview) else { return }
    let root = v2.trueRegistryRoot
    guard let layout = root.currentLayout else { return }
    openInstantPageMedia(
        media: tapped,
        allMedias: layout.allMedias(),
        webPage: renderContext.webpage,
        context: renderContext.context,
        userLocation: renderContext.sourceLocation.userLocation,
        captureProtected: renderContext.captureProtected,
        present: renderContext.present,
        push: renderContext.push,
        openUrl: renderContext.openUrl,
        baseNavigationController: renderContext.baseNavigationController,
        transitionArgsForMedia: { [weak root] tappedSibling -> GalleryTransitionArguments? in
            guard let root else { return nil }
            return root.transitionArgsFor(tappedSibling, addToTransitionSurface: { [weak root] view in
                root?.superview?.addSubview(view)
            })
        },
        hiddenMediaCallback: { [weak root] hidden in
            root?.applyHiddenMedia(hidden)
        }
    )
}

// MARK: - Concrete wrapper classes

final class InstantPageV2MediaImageView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2MediaImageItem
    var itemFrame: CGRect { return self.item.frame }
    let wrappedNode: InstantPageImageNode
    // Revealable spoiler dust cover (nil unless `item.spoiler`); see `MediaSpoilerDustOverlay`.
    private var spoilerOverlay: MediaSpoilerDustOverlay?

    init(item: InstantPageV2MediaImageItem, renderContext: InstantPageV2RenderContext, theme: InstantPageTheme) {
        self.item = item

        // The tap closure can't capture `[weak self]` before `super.init`, so we route through
        // a `WrapperRef` box that gets filled in after `super.init`. The box's weak storage
        // breaks the wrapper → wrappedNode → closure → wrapper retain cycle that would otherwise
        // form (the wrapper owns wrappedNode, which owns the closure, which holds the wrapper).
        let wrapperRef = WrapperRef()
        let renderContextRef = renderContext
        let openMedia: (InstantPageMedia) -> Void = { tapped in
            guard let wrapper = wrapperRef.view as? InstantPageV2MediaImageView else { return }
            // While a spoiler cover is concealed, the first tap reveals it instead of opening
            // the gallery; once revealed, taps fall through to the normal open path.
            if let overlay = wrapper.spoilerOverlay, overlay.concealed {
                overlay.reveal()
                return
            }
            handleOpenMediaTap(tapped: tapped, wrapper: wrapper, renderContext: renderContextRef)
        }
        self.wrappedNode = makeMediaWrapper(
            frame: item.frame,
            media: item.media,
            webPage: item.webPage,
            attributes: item.attributes,
            renderContext: renderContext,
            theme: theme,
            openMedia: openMedia,
            longPressMedia: { _ in },
            fit: item.fit
        )

        super.init(frame: item.frame)
        self.backgroundColor = .clear            // structural
        self.addSubview(self.wrappedNode.view)   // structural
        wrapperRef.view = self                   // structural: back-reference for the openMedia closure
        self.update(item: item, theme: theme, renderContext: renderContext)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard self.window != nil else { return }
        registerInRootRegistry(wrapper: self, mediaIndex: self.item.media.index)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.wrappedNode.frame = self.bounds
        if let overlay = self.spoilerOverlay {
            overlay.updateLayout(size: self.bounds.size)
            if let blurNode = overlay.blurredImageNode {
                // Draw the blur (the overlay only sets its frame); reuses the wrapped node's dimension math.
                self.wrappedNode.layoutSpoilerBlurredNode(blurNode, size: self.bounds.size)
            }
        }
    }

    func update(item: InstantPageV2MediaImageItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext) {
        let previousMedia = self.item.media
        let previousMediaId = previousMedia.media.id
        self.item = item
        self.layer.cornerRadius = item.cornerRadius
        self.clipsToBounds = item.cornerRadius > 0.0
        let strings = renderContext.context.sharedContext.currentPresentationData.with { $0 }.strings
        self.wrappedNode.update(strings: strings, theme: theme)
        // Re-read on every apply: copy protection can be toggled peer-side while the message is on
        // screen, which does not rebuild this view (see `InstantPageV2RenderContext.captureProtected`).
        self.wrappedNode.captureProtected = renderContext.captureProtected
        // On the Local→Cloud send flip the media id changes but the view is reused (see the
        // rich-bubble "Send-time media continuity" doc). Re-point the wrapped node's interactive
        // bindings at the Cloud media so tap-to-open works without a rebuild; the image is not
        // reloaded (no blink).
        if item.media.media.id != previousMediaId {
            self.wrappedNode.updateInteractiveMediaBinding(sourceLocation: renderContext.sourceLocation, media: item.media, imageReferenceForMedia: renderContext.imageReference, fileReferenceForMedia: renderContext.fileReference)
        } else if item.media != previousMedia {
            // Same medium, DIFFERENT surrounding value — caption/credit/url, or a photo that
            // compares unequal under an unchanged id (a message edit, or the server round-trip
            // returning different representations). The id check above does not cover it, and the
            // node's `media` is the value a tap hands to the gallery's lookup, so letting it drift
            // silently kills tap-to-open. See `updateMediaValue`.
            self.wrappedNode.updateMediaValue(item.media)
        }
        self.updateSpoiler(renderContext: renderContext)
    }

    // Reconciles the spoiler dust cover with the current item. A reused view drops a stale cover
    // when `spoiler` turns off or the underlying media changes, and keeps its (possibly revealed)
    // cover when the same spoiler media is re-laid-out.
    private func updateSpoiler(renderContext: InstantPageV2RenderContext) {
        if self.item.spoiler {
            let mediaId = self.item.media.media.id
            if let overlay = self.spoilerOverlay, overlay.mediaId == mediaId {
                // Same spoiler medium — preserve the current reveal state.
            } else {
                self.spoilerOverlay?.containerNode.view.removeFromSuperview()
                let enableAnimations = renderContext.context.sharedContext.energyUsageSettings.fullTranslucency
                let overlay = MediaSpoilerDustOverlay(enableAnimations: enableAnimations, mediaId: mediaId, blurredImageNode: self.wrappedNode.makeSpoilerBlurredNode())
                self.spoilerOverlay = overlay
                self.addSubview(overlay.containerNode.view)
                self.setNeedsLayout()
            }
        } else if let overlay = self.spoilerOverlay {
            overlay.containerNode.view.removeFromSuperview()
            self.spoilerOverlay = nil
        }
    }

    func instantPageTransitionNode(for media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return self.wrappedNode.transitionNode(media: media)
    }

    func instantPageUpdateHiddenMedia(_ media: InstantPageMedia?) {
        self.wrappedNode.updateHiddenMedia(media: media)
    }
}

final class InstantPageV2MediaVideoView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2MediaVideoItem
    var itemFrame: CGRect { return self.item.frame }
    let wrappedNode: InstantPageImageNode
    // Revealable spoiler dust cover (nil unless `item.spoiler`); see `MediaSpoilerDustOverlay`.
    private var spoilerOverlay: MediaSpoilerDustOverlay?
    // Inline autoplay player, present only when `shouldAutoplayVideo` is true for the current file
    // and (if spoilered) the cover has been revealed. Layered ABOVE the poster `wrappedNode`.
    private var videoNode: UniversalVideoNode?
    // The media id the current `videoNode` was built for; drives teardown/rebuild on positional reuse.
    private var videoNodeMediaId: EngineMedia.Id?
    // `captureProtected` baked into the current `videoNode`'s content. `NativeVideoContent` takes it
    // at construction, so a peer-side copy-protection toggle has to rebuild the player.
    private var videoNodeCaptureProtected = false
    // Whether the view currently intersects the visibility rect; gates `canAttachContent`.
    private var localIsVisible = false
    // One-shot auto-download fetch (download even when not autoplaying), keyed by media id.
    private let videoFetchDisposable = MetaDisposable()
    private var videoFetchMediaId: EngineMedia.Id?

    deinit {
        self.videoFetchDisposable.dispose()
    }

    init(item: InstantPageV2MediaVideoItem, renderContext: InstantPageV2RenderContext, theme: InstantPageTheme) {
        self.item = item

        let wrapperRef = WrapperRef()
        let renderContextRef = renderContext
        let openMedia: (InstantPageMedia) -> Void = { tapped in
            guard let wrapper = wrapperRef.view as? InstantPageV2MediaVideoView else { return }
            // While a spoiler cover is concealed, the first tap reveals it instead of opening
            // the gallery; once revealed, taps fall through to the normal open path.
            if let overlay = wrapper.spoilerOverlay, overlay.concealed {
                overlay.reveal()
                wrapper.updateInlineVideo(renderContext: renderContextRef)
                return
            }
            handleOpenMediaTap(tapped: tapped, wrapper: wrapper, renderContext: renderContextRef)
        }
        self.wrappedNode = makeMediaWrapper(
            frame: item.frame,
            media: item.media,
            webPage: item.webPage,
            attributes: item.attributes,
            renderContext: renderContext,
            theme: theme,
            openMedia: openMedia,
            longPressMedia: { _ in },
            fit: item.fit
        )

        super.init(frame: item.frame)
        self.backgroundColor = .clear            // structural
        self.addSubview(self.wrappedNode.view)   // structural
        wrapperRef.view = self                   // structural: back-reference for the openMedia closure
        self.update(item: item, theme: theme, renderContext: renderContext)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard self.window != nil else { return }
        registerInRootRegistry(wrapper: self, mediaIndex: self.item.media.index)
    }

    /// The rect the inline player should occupy.
    ///
    /// The poster (`wrappedNode`) renders aspect-FIT over a blurred backdrop whenever `item.fit` is set,
    /// which single media does: `instantPageV2MediaFrame` caps a portrait item's height at its display
    /// width, so the box deliberately stops matching the media aspect. The player is layered ABOVE that
    /// poster, so sizing it to the full bounds both squashes the video into the capped box and hides the
    /// blurred backdrop — which is why video appeared square and stretched while images did not.
    ///
    /// Collage cells construct the item WITHOUT `fit`, so they keep filling their bounds (crop-to-fill,
    /// matching image cells and the 1pt-bleed clipping note at the construction site).
    private func inlineVideoFrame(in bounds: CGRect) -> CGRect {
        guard self.item.fit,
              case let .file(file) = self.item.media.media,
              let dimensions = file.dimensions,
              dimensions.width > 0, dimensions.height > 0 else {
            return bounds
        }
        let fitted = dimensions.cgSize.aspectFitted(bounds.size)
        return CGRect(
            x: floorToScreenPixels((bounds.width - fitted.width) / 2.0),
            y: floorToScreenPixels((bounds.height - fitted.height) / 2.0),
            width: fitted.width,
            height: fitted.height
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.wrappedNode.frame = self.bounds
        let videoFrame = self.inlineVideoFrame(in: self.bounds)
        self.videoNode?.frame = videoFrame
        self.videoNode?.updateLayout(size: videoFrame.size, transition: .immediate)
        if let overlay = self.spoilerOverlay {
            overlay.updateLayout(size: self.bounds.size)
            if let blurNode = overlay.blurredImageNode {
                // Draw the blur (the overlay only sets its frame); reuses the wrapped node's dimension math.
                self.wrappedNode.layoutSpoilerBlurredNode(blurNode, size: self.bounds.size)
            }
        }
    }

    func update(item: InstantPageV2MediaVideoItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext) {
        let previousMedia = self.item.media
        let previousMediaId = previousMedia.media.id
        self.item = item
        self.layer.cornerRadius = item.cornerRadius
        self.clipsToBounds = item.cornerRadius > 0.0
        let strings = renderContext.context.sharedContext.currentPresentationData.with { $0 }.strings
        self.wrappedNode.update(strings: strings, theme: theme)
        self.wrappedNode.captureProtected = renderContext.captureProtected
        // See the image view: refresh the poster node's `self.media` identity on the Local→Cloud
        // send flip so the gallery centralIndex match (and transitionNode) use the Cloud media. The
        // inline video node is rebuilt separately below (keyed by media id).
        if item.media.media.id != previousMediaId {
            self.wrappedNode.updateInteractiveMediaBinding(sourceLocation: renderContext.sourceLocation, media: item.media, imageReferenceForMedia: renderContext.imageReference, fileReferenceForMedia: renderContext.fileReference)
        } else if item.media != previousMedia {
            // See the image view: same medium, drifted value. A video's tap is ungated by fetch
            // status, so this lookup is the ONLY thing standing between the tap and the gallery.
            self.wrappedNode.updateMediaValue(item.media)
        }
        self.updateSpoiler(renderContext: renderContext)
        self.updateInlineVideo(renderContext: renderContext)
    }

    // Reconciles the spoiler dust cover with the current item. A reused view drops a stale cover
    // when `spoiler` turns off or the underlying media changes, and keeps its (possibly revealed)
    // cover when the same spoiler media is re-laid-out.
    private func updateSpoiler(renderContext: InstantPageV2RenderContext) {
        if self.item.spoiler {
            let mediaId = self.item.media.media.id
            if let overlay = self.spoilerOverlay, overlay.mediaId == mediaId {
                // Same spoiler medium — preserve the current reveal state.
            } else {
                self.spoilerOverlay?.containerNode.view.removeFromSuperview()
                let enableAnimations = renderContext.context.sharedContext.energyUsageSettings.fullTranslucency
                let overlay = MediaSpoilerDustOverlay(enableAnimations: enableAnimations, mediaId: mediaId, blurredImageNode: self.wrappedNode.makeSpoilerBlurredNode())
                self.spoilerOverlay = overlay
                self.addSubview(overlay.containerNode.view)
                self.setNeedsLayout()
            }
        } else if let overlay = self.spoilerOverlay {
            overlay.containerNode.view.removeFromSuperview()
            self.spoilerOverlay = nil
        }
    }

    // Reconciles the inline autoplay player + one-shot auto-download with the current item/policy.
    private func updateInlineVideo(renderContext: InstantPageV2RenderContext) {
        guard case let .file(file) = self.item.media.media, let messageId = renderContext.message?.id else {
            self.tearDownVideoNode()
            return
        }
        let mediaId = self.item.media.media.id

        // Auto-download the video bytes per settings, once per media id, regardless of autoplay.
        if renderContext.shouldAutoDownloadFile(file), self.videoFetchMediaId != mediaId {
            self.videoFetchMediaId = mediaId
            let fileReference = renderContext.fileReference(file)
            self.videoFetchDisposable.set(freeMediaFileInteractiveFetched(account: renderContext.context.account, userLocation: renderContext.sourceLocation.userLocation, fileReference: fileReference).start())
        }

        // Autoplay only when enabled AND no concealed spoiler cover is hiding the media.
        let spoilerBlocks = (self.spoilerOverlay?.concealed ?? false)
        let wantAutoplay = renderContext.shouldAutoplayVideo(file) && !spoilerBlocks

        if wantAutoplay {
            if self.videoNode != nil, self.videoNodeMediaId == mediaId, self.videoNodeCaptureProtected == renderContext.captureProtected {
                return
            }
            self.tearDownVideoNode()

            var streamVideo = false
            if isMediaStreamable(media: file) {
                streamVideo = true
            }
            var imageReference: ImageMediaReference?
            if let presentation = smallestImageRepresentation(file.previewRepresentations) {
                let image = TelegramMediaImage(imageId: EngineMedia.Id(namespace: 0, id: 0), representations: [presentation], immediateThumbnailData: file.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                imageReference = renderContext.imageReference(image)
            }
            let content = NativeVideoContent(
                id: .message(UInt32(bitPattern: messageId.id), file.fileId),
                userLocation: renderContext.sourceLocation.userLocation,
                fileReference: renderContext.fileReference(file),
                imageReference: imageReference,
                streamVideo: streamVideo ? .conservative : .none,
                loopVideo: file.isAnimated,
                enableSound: false,
                fetchAutomatically: true,
                placeholderColor: .clear,
                captureProtected: renderContext.captureProtected,
                storeAfterDownload: nil
            )
            let videoNode = UniversalVideoNode(
                context: renderContext.context,
                postbox: renderContext.context.account.postbox,
                audioSession: renderContext.context.sharedContext.mediaManager.audioSession,
                manager: renderContext.context.sharedContext.mediaManager.universalVideoManager,
                decoration: GalleryVideoDecoration(),
                content: content,
                priority: .embedded,
                autoplay: true
            )
            videoNode.isUserInteractionEnabled = false
            // Confine the player to the cell. `NativeVideoContentNode.updateLayout` deliberately
            // inflates its `playerNode` to `bounds.insetBy(dx: -1, dy: -1)` (a seam hack so no hairline
            // of backdrop shows at the video's edge), and nothing below us clips it: this path builds a
            // `GalleryVideoDecoration`, whose `contentContainerNode.clipsToBounds` is only set inside
            // `updateCorners`, which no one calls here. Unclipped, an autoplaying video paints 1pt past
            // its item frame on every side — which in a `.collage` mosaic is exactly the 1pt gutter
            // between cells, so a video cell visibly bleeds over its neighbours (image cells don't:
            // they draw into `boundingSize == bounds.size`). Clipping here rather than on `self` keeps
            // the wrapper's own `clipsToBounds` tied to `cornerRadius`, as the image view's is.
            videoNode.clipsToBounds = true
            videoNode.frame = self.inlineVideoFrame(in: self.bounds)
            self.addSubview(videoNode.view)
            self.videoNode = videoNode
            self.videoNodeMediaId = mediaId
            self.videoNodeCaptureProtected = renderContext.captureProtected
            videoNode.canAttachContent = self.localIsVisible
            self.setNeedsLayout()
        } else {
            self.tearDownVideoNode()
        }
    }

    private func tearDownVideoNode() {
        if let videoNode = self.videoNode {
            videoNode.canAttachContent = false
            videoNode.view.removeFromSuperview()
            self.videoNode = nil
            self.videoNodeMediaId = nil
            self.videoNodeCaptureProtected = false
        }
    }

    func instantPageTransitionNode(for media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return self.wrappedNode.transitionNode(media: media)
    }

    func instantPageUpdateHiddenMedia(_ media: InstantPageMedia?) {
        self.wrappedNode.updateHiddenMedia(media: media)
        self.videoNode?.isHidden = (media == self.item.media)
    }

    func instantPageUpdateIsVisible(_ isVisible: Bool) {
        if self.localIsVisible != isVisible {
            self.localIsVisible = isVisible
            self.videoNode?.canAttachContent = isVisible
        }
    }
}

final class InstantPageV2MediaMapView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2MediaMapItem
    var itemFrame: CGRect { return self.item.frame }
    let wrappedNode: InstantPageImageNode

    init(item: InstantPageV2MediaMapItem, renderContext: InstantPageV2RenderContext, theme: InstantPageTheme) {
        self.item = item

        let wrapperRef = WrapperRef()
        let renderContextRef = renderContext
        let openMedia: (InstantPageMedia) -> Void = { tapped in
            guard let wrapper = wrapperRef.view else { return }
            handleOpenMediaTap(tapped: tapped, wrapper: wrapper, renderContext: renderContextRef)
        }
        self.wrappedNode = makeMediaWrapper(
            frame: item.frame,
            media: item.media,
            webPage: item.webPage,
            attributes: item.attributes,
            renderContext: renderContext,
            theme: theme,
            openMedia: openMedia,
            longPressMedia: { _ in }
        )

        super.init(frame: item.frame)
        self.backgroundColor = .clear            // structural
        self.addSubview(self.wrappedNode.view)   // structural
        wrapperRef.view = self                   // structural: back-reference for the openMedia closure
        self.update(item: item, theme: theme, renderContext: renderContext)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard self.window != nil else { return }
        registerInRootRegistry(wrapper: self, mediaIndex: self.item.media.index)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.wrappedNode.frame = self.bounds
    }

    func update(item: InstantPageV2MediaMapItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext) {
        let previousMedia = self.item.media
        self.item = item
        self.layer.cornerRadius = item.cornerRadius
        self.clipsToBounds = item.cornerRadius > 0.0
        let strings = renderContext.context.sharedContext.currentPresentationData.with { $0 }.strings
        self.wrappedNode.update(strings: strings, theme: theme)
        self.wrappedNode.captureProtected = renderContext.captureProtected
        // A map tap opens LocationViewController straight from the tapped value, so it does not go
        // through the gallery's lookup — but `transitionNode` / `updateHiddenMedia` still match
        // against the node's `media`, so keep it in step. There is no id-flip branch here: a map has
        // no uploadable resource, so its media id never changes under a reused view.
        if item.media != previousMedia {
            self.wrappedNode.updateMediaValue(item.media)
        }
    }

    func instantPageTransitionNode(for media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return self.wrappedNode.transitionNode(media: media)
    }

    func instantPageUpdateHiddenMedia(_ media: InstantPageMedia?) {
        self.wrappedNode.updateHiddenMedia(media: media)
    }
}

final class InstantPageV2MediaCoverImageView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2MediaCoverImageItem
    var itemFrame: CGRect { return self.item.frame }
    let wrappedNode: InstantPageImageNode

    init(item: InstantPageV2MediaCoverImageItem, renderContext: InstantPageV2RenderContext, theme: InstantPageTheme) {
        self.item = item

        let wrapperRef = WrapperRef()
        let renderContextRef = renderContext
        let openMedia: (InstantPageMedia) -> Void = { tapped in
            guard let wrapper = wrapperRef.view else { return }
            handleOpenMediaTap(tapped: tapped, wrapper: wrapper, renderContext: renderContextRef)
        }
        self.wrappedNode = makeMediaWrapper(
            frame: item.frame,
            media: item.media,
            webPage: item.webPage,
            attributes: item.attributes,
            renderContext: renderContext,
            theme: theme,
            openMedia: openMedia,
            longPressMedia: { _ in }
        )

        super.init(frame: item.frame)
        self.backgroundColor = .clear            // structural
        self.addSubview(self.wrappedNode.view)   // structural
        wrapperRef.view = self                   // structural: back-reference for the openMedia closure
        self.update(item: item, theme: theme, renderContext: renderContext)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard self.window != nil else { return }
        registerInRootRegistry(wrapper: self, mediaIndex: self.item.media.index)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.wrappedNode.frame = self.bounds
    }

    func update(item: InstantPageV2MediaCoverImageItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext) {
        let previousMedia = self.item.media
        let previousMediaId = previousMedia.media.id
        self.item = item
        self.layer.cornerRadius = item.cornerRadius
        self.clipsToBounds = item.cornerRadius > 0.0
        let strings = renderContext.context.sharedContext.currentPresentationData.with { $0 }.strings
        self.wrappedNode.update(strings: strings, theme: theme)
        self.wrappedNode.captureProtected = renderContext.captureProtected
        // See the image view: refresh interactive bindings on the Local→Cloud send media-id flip.
        if item.media.media.id != previousMediaId {
            self.wrappedNode.updateInteractiveMediaBinding(sourceLocation: renderContext.sourceLocation, media: item.media, imageReferenceForMedia: renderContext.imageReference, fileReferenceForMedia: renderContext.fileReference)
        } else if item.media != previousMedia {
            // See the image view: same medium, drifted value.
            self.wrappedNode.updateMediaValue(item.media)
        }
    }

    func instantPageTransitionNode(for media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return self.wrappedNode.transitionNode(media: media)
    }

    func instantPageUpdateHiddenMedia(_ media: InstantPageMedia?) {
        self.wrappedNode.updateHiddenMedia(media: media)
    }
}

// Sets up shared-media playback for an audio tap. Mirrors V1's
// `InstantPageControllerNode.openMedia(_:)` audio branch: collect the page's voice/music
// medias from the root V2View's current layout, build an `InstantPageMediaPlaylist` keyed by
// `playlistId`, and start playback. No-op if the wrapper isn't currently in a V2View tree.
func handleOpenAudioTap(
    tapped: InstantPageMedia,
    wrapper: UIView,
    renderContext: InstantPageV2RenderContext,
    playlistId: InstantPageMediaPlaylistId
) {
    guard case let .file(tappedFile) = tapped.media, tappedFile.isVoice || tappedFile.isMusic else { return }
    guard let v2 = findEnclosingV2View(from: wrapper.superview) else { return }
    let root = v2.trueRegistryRoot
    guard let layout = root.currentLayout else { return }

    var audioMedias: [InstantPageMedia] = []
    var initialIndex = 0
    for media in layout.allMedias() {
        if case let .file(file) = media.media, (file.isVoice || file.isMusic) {
            if media.index == tapped.index {
                initialIndex = audioMedias.count
            }
            audioMedias.append(media)
        }
    }

    let playlist = InstantPageMediaPlaylist(
        playlistId: playlistId,
        webPage: renderContext.webpage,
        messageReference: renderContext.message,
        items: audioMedias,
        initialItemIndex: initialIndex
    )
    renderContext.context.sharedContext.mediaManager.setPlaylist(
        (renderContext.context, playlist),
        type: tappedFile.isVoice ? .voice : .music,
        control: .playback(.play)
    )
}

final class InstantPageV2MediaAudioView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2MediaAudioItem
    var itemFrame: CGRect { return self.item.frame }
    private let audioNode: InstantPageV2AudioContentNode

    init(item: InstantPageV2MediaAudioItem, renderContext: InstantPageV2RenderContext, theme: InstantPageTheme) {
        self.item = item

        // `.richMessage(messageId)` isolates playback state per chat message; the preview (no
        // message) falls back to the webpage-keyed id (only one preview is ever on screen).
        let playlistId: InstantPageMediaPlaylistId
        if let messageId = renderContext.message?.id {
            playlistId = .richMessage(messageId: messageId)
        } else {
            playlistId = .instantPage(webpageId: renderContext.webpage.webpageId)
        }

        let wrapperRef = WrapperRef()
        let renderContextRef = renderContext
        let itemMedia = item.media

        let presentationData = renderContext.context.sharedContext.currentPresentationData.with { $0 }
        let incoming = renderContext.message?.isIncoming == true
        let audioFile: TelegramMediaFile
        if case let .file(f) = item.media.media { audioFile = f } else { audioFile = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: EmptyMediaResource(), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/mpeg", size: nil, attributes: [], alternativeRepresentations: []) }
        self.audioNode = InstantPageV2AudioContentNode(context: renderContext.context, message: renderContext.message, file: audioFile, incoming: incoming, presentationData: presentationData)

        super.init(frame: item.frame)
        self.backgroundColor = .clear            // structural
        self.addSubview(self.audioNode.view)     // structural
        wrapperRef.view = self                   // structural: back-reference for the play closure

        self.audioNode.play = {
            guard let wrapper = wrapperRef.view else { return }
            handleOpenAudioTap(tapped: itemMedia, wrapper: wrapper, renderContext: renderContextRef, playlistId: playlistId)
        }

        let fetchContext = renderContext.context
        let fetchMessage = renderContext.message
        let fetchMedia = item.media
        self.audioNode.fetch = {
            guard case let .file(file) = fetchMedia.media, let message = fetchMessage, let messageId = message.id else { return }
            // Route through the fetch manager (not freeMediaFileInteractiveFetched) so the
            // messageMediaFileStatus signal — which keys progress off the fetch manager's
            // `hasEntry` — surfaces .Fetching, letting the overlay show the animated ring.
            let _ = messageMediaFileInteractiveFetched(fetchManager: fetchContext.fetchManager, messageId: messageId, messageReference: message, file: file, userInitiated: true, priority: .userInitiated).startStandalone()
        }

        let mediaForPlayback = item.media
        let playlistTypeForPlayback: MediaManagerPlayerType
        if case let .file(f) = mediaForPlayback.media, f.isVoice { playlistTypeForPlayback = .voice } else { playlistTypeForPlayback = .music }
        let contextForPlayback = renderContext.context

        self.audioNode.togglePlayPause = {
            contextForPlayback.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: playlistTypeForPlayback)
        }

        let stateSignal = contextForPlayback.sharedContext.mediaManager.filteredPlaylistState(accountId: contextForPlayback.account.id, playlistId: playlistId, itemId: InstantPageMediaPlaylistItemId(index: mediaForPlayback.index), type: playlistTypeForPlayback)
        self.audioNode.setPlaybackStatusSignal(stateSignal)

        self.update(item: item, theme: theme, renderContext: renderContext)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.audioNode.frame = self.bounds
        self.audioNode.updateLayout(width: self.bounds.width)
    }

    func update(item: InstantPageV2MediaAudioItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext) {
        self.item = item
        let presentationData = renderContext.context.sharedContext.currentPresentationData.with { $0 }
        let incoming = renderContext.message?.isIncoming == true
        self.audioNode.updatePresentationData(presentationData, incoming: incoming)
        self.audioNode.updateLayout(width: self.bounds.width)
    }

    // Audio is not a gallery item: explicit nil/no-op witnesses (per the existing pattern of
    // explicit per-class witnesses rather than a shared protocol-extension override).
    func instantPageTransitionNode(for media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }

    func instantPageUpdateHiddenMedia(_ media: InstantPageMedia?) {
    }
}
