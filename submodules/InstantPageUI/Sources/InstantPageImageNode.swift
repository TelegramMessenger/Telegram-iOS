import Foundation
import UIKit
import ImageIO
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import PhotoResources
import MediaResources
import LocationResources
import LiveLocationPositionNode
import AppBundle
import TelegramUIPreferences
import ContextUI
import Tuples
import UIKitRuntimeUtils

private struct FetchControls {
    let fetch: (Bool) -> Void
    let cancel: () -> Void
}

private enum ExternalImageLoadState {
    case loading
    case ready
    case failed
}

private func externalImagePixelDimensions(data: Data) -> PixelDimensions? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
        return nil
    }
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
        return nil
    }
    guard let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.int32Value,
          let pixelHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.int32Value,
          pixelWidth > 0, pixelHeight > 0 else {
        return nil
    }
    
    let orientation = imageOrientationFromSource(source)
    switch orientation {
    case .left, .right, .leftMirrored, .rightMirrored:
        return PixelDimensions(width: pixelHeight, height: pixelWidth)
    default:
        return PixelDimensions(width: pixelWidth, height: pixelHeight)
    }
}

final class InstantPageImageNode: ASDisplayNode, InstantPageNode, InstantPageExternalMediaDimensionsNode {
    private let context: AccountContext
    private let webPage: TelegramMediaWebpage
    private var theme: InstantPageTheme
    private(set) var media: InstantPageMedia
    let attributes: [InstantPageImageAttribute]
    private let interactive: Bool
    private let roundCorners: Bool
    /// When true, the media is aspect-FITTED (letterboxed) within the node's bounds — with a blurred,
    /// scaled-up copy of the media filling the letterbox/pillarbox gap (`resizeMode: .blurBackground`) —
    /// instead of the default aspect-FILL (cover + crop). Mirrors the RichText editor's
    /// `RichTextMediaContentComponent` (`usesAspectFit`), so a sent rich message matches its authoring
    /// preview. Used by single media (whose frame height is capped at `min(1000, boundingWidth)`, so a
    /// tall portrait shows whole + blurred rather than cropped) and by every slideshow page (whose shared
    /// block frame is the tallest page). A landscape image that fills its slot shows no blur
    /// (`aspectFitted == boundingSize`). Honored in `layout()` for image/file media.
    private let fit: Bool
    /// When set, overrides the per-media-type placeholder/letterbox `emptyColor` (e.g. the slideshow uses
    /// black instead of the panel/placeholder color). nil = keep the per-type default.
    private let emptyColorOverride: UIColor?
    private let openMedia: (InstantPageMedia) -> Void
    private let longPressMedia: (InstantPageMedia) -> Void
    private let getPreloadedResource: (String) -> Data?
    
    private var fetchControls: FetchControls?
    private var externalImageLoadState: ExternalImageLoadState?
    var updateExternalMediaDimensions: ((EngineMedia.Id, PixelDimensions) -> Void)?
    private var externalMediaDimensions: PixelDimensions?
    private var didReportExternalMediaDimensions = false

    private let pinchContainerNode: PinchSourceContainerNode
    private let imageNode: TransformImageNode
    private let statusNode: RadialStatusNode
    private let linkIconNode: ASImageNode
    private let pinNode: ChatMessageLiveLocationPositionNode
    
    private var currentSize: CGSize?
    
    private var fetchStatus: EngineMediaResource.FetchStatus?
    private var fetchedDisposable = MetaDisposable()
    private var statusDisposable = MetaDisposable()
    
    private var themeUpdated: Bool = false
    private var externalMediaDimensionsUpdated: Bool = false

    // Spoiler support: a separate heavily-blurred (`.blurBackground`) overlay node that occludes the sharp
    // `imageNode` while concealed. A distinct node is required — `TransformImageArguments.==` ignores
    // `resizeMode`, so flipping the main node's resizeMode alone would early-out and never re-render; and a
    // separate node also gives an instant reveal (remove it → the always-sharp `imageNode` shows). The
    // enclosing V2 media view drives the dust cover + reveal timing. Default off (no effect on web IV).
    private var contentBlurredSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?

    /// Excludes the rendered media from screenshots and screen recordings, matching what
    /// `ChatMessageInteractiveMediaNode` does for a copy-protected regular media message. Driven by
    /// the enclosing V2 media view from `InstantPageV2RenderContext.captureProtected`; default off,
    /// so web IV and V1 Instant View are unaffected.
    ///
    /// The spoiler blur node is a sibling the caller owns (see `makeSpoilerBlurredNode`), so it is
    /// tracked weakly here and kept in sync — a concealed spoiler must be protected too, otherwise
    /// a screenshot of a blurred-but-unprotected cover still reveals the shape of the media.
    var captureProtected: Bool = false {
        didSet {
            if self.captureProtected != oldValue {
                self.imageNode.captureProtected = self.captureProtected
                self.spoilerBlurredNode?.captureProtected = self.captureProtected
            }
        }
    }
    private weak var spoilerBlurredNode: TransformImageNode?

    init(context: AccountContext, sourceLocation: InstantPageSourceLocation, theme: InstantPageTheme, webPage: TelegramMediaWebpage, media: InstantPageMedia, attributes: [InstantPageImageAttribute], interactive: Bool, roundCorners: Bool, fit: Bool, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, imageReferenceForMedia: ((TelegramMediaImage) -> ImageMediaReference)? = nil, fileReferenceForMedia: ((TelegramMediaFile) -> FileMediaReference)? = nil, autoDownloadImage: ((TelegramMediaImage) -> Bool)? = nil, autoDownloadFile: ((TelegramMediaFile) -> Bool)? = nil, emptyColor: UIColor? = nil, getPreloadedResource: @escaping (String) -> Data?) {
        self.context = context
        self.theme = theme
        self.webPage = webPage
        self.media = media
        self.attributes = attributes
        self.interactive = interactive
        self.roundCorners = roundCorners
        self.fit = fit
        self.emptyColorOverride = emptyColor
        self.openMedia = openMedia
        self.longPressMedia = longPressMedia
        self.getPreloadedResource = getPreloadedResource

        self.pinchContainerNode = PinchSourceContainerNode()
        self.imageNode = TransformImageNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        self.linkIconNode = ASImageNode()
        self.pinNode = ChatMessageLiveLocationPositionNode()
        
        super.init()

        self.pinchContainerNode.contentNode.addSubnode(self.imageNode)
        self.addSubnode(self.pinchContainerNode)
        
        if interactive, media.url != nil {
            self.linkIconNode.image = UIImage(bundleImageName: "Instant View/ImageLink")
            self.pinchContainerNode.contentNode.addSubnode(self.linkIconNode)
        }
        
        if case let .image(image) = media.media, let largest = largestImageRepresentation(image.representations) {
            if let externalResource = largest.resource as? InstantPageExternalMediaResource {
                self.loadExternalImage(resourceUrl: externalResource.url)
            } else {
                let imageReference = imageReferenceForMedia?(image) ?? ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
                self.imageNode.setSignal(chatMessagePhoto(postbox: context.account.postbox, userLocation: sourceLocation.userLocation, photoReference: imageReference))
                self.contentBlurredSignal = chatSecretPhoto(account: context.account, userLocation: sourceLocation.userLocation, photoReference: imageReference, ignoreFullSize: true)

                let autoDownload = autoDownloadImage?(image) ?? shouldDownloadMediaAutomatically(settings: context.sharedContext.currentAutomaticMediaDownloadSettings, peerType: sourceLocation.peerType, networkType: MediaAutoDownloadNetworkType(context.account.immediateNetworkType), authorPeerId: nil, contactsPeerIds: Set(), media: image)
                if !interactive || autoDownload {
                    self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(context: context, userLocation: sourceLocation.userLocation, photoReference: imageReference, displayAtSize: nil, storeToDownloadsPeerId: nil).start())
                }
                
                self.fetchControls = FetchControls(fetch: { [weak self] manual in
                    if let strongSelf = self {
                        strongSelf.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(context: context, userLocation: sourceLocation.userLocation, photoReference: imageReference, displayAtSize: nil, storeToDownloadsPeerId: nil).start())
                    }
                }, cancel: {
                    chatMessagePhotoCancelInteractiveFetch(account: context.account, photoReference: imageReference)
                })
                
                if interactive {
                    self.statusDisposable.set((context.engine.resources.status(resource: EngineMediaResource(largest.resource)) |> deliverOnMainQueue).start(next: { [weak self] status in
                        displayLinkDispatcher.dispatch {
                            if let strongSelf = self {
                                strongSelf.fetchStatus = status
                                strongSelf.updateFetchStatus()
                            }
                        }
                    }))

                    self.pinchContainerNode.contentNode.addSubnode(self.statusNode)
                }
            }
        } else if case let .file(file) = media.media {
            if let externalResource = file.resource as? InstantPageExternalMediaResource {
                self.loadExternalImage(resourceUrl: externalResource.url)
            } else {
                let fileReference = fileReferenceForMedia?(file) ?? FileMediaReference.webPage(webPage: WebpageReference(webPage), media: file)
                if file.mimeType.hasPrefix("image/") {
                    let autoDownload = autoDownloadFile?(file) ?? shouldDownloadMediaAutomatically(settings: context.sharedContext.currentAutomaticMediaDownloadSettings, peerType: sourceLocation.peerType, networkType: MediaAutoDownloadNetworkType(context.account.immediateNetworkType), authorPeerId: nil, contactsPeerIds: Set(), media: file)
                    if !interactive || autoDownload {
                        _ = freeMediaFileInteractiveFetched(account: context.account, userLocation: sourceLocation.userLocation, fileReference: fileReference).start()
                    }
                    self.imageNode.setSignal(instantPageImageFile(account: context.account, userLocation: sourceLocation.userLocation, fileReference: fileReference, fetched: true))
                } else {
                    self.imageNode.setSignal(chatMessageVideo(postbox: context.account.postbox, userLocation: sourceLocation.userLocation, videoReference: fileReference))
                }
                self.contentBlurredSignal = chatSecretMessageVideo(account: context.account, userLocation: sourceLocation.userLocation, videoReference: fileReference)
                if file.isVideo {
                    self.statusNode.transitionToState(.play(.white), animated: false, completion: {})
                    self.pinchContainerNode.contentNode.addSubnode(self.statusNode)
                }
            }
        } else if case let .geo(map) = media.media {
            self.addSubnode(self.pinNode)

            var dimensions = CGSize(width: 200.0, height: 100.0)
            for attribute in self.attributes {
                if let mapAttribute = attribute as? InstantPageMapAttribute {
                    dimensions = mapAttribute.dimensions
                    break
                }
            }
            let resource = MapSnapshotMediaResource(latitude: map.latitude, longitude: map.longitude, width: Int32(dimensions.width), height: Int32(dimensions.height))
            self.imageNode.setSignal(chatMapSnapshotImage(engine: context.engine, resource: resource))
        } else if case let .webpage(webPage) = media.media, case let .Loaded(content) = webPage.content, let image = content.image {
            let imageReference = imageReferenceForMedia?(image) ?? ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
            self.imageNode.setSignal(chatMessagePhoto(postbox: context.account.postbox, userLocation: sourceLocation.userLocation, photoReference: imageReference))
            self.contentBlurredSignal = chatSecretPhoto(account: context.account, userLocation: sourceLocation.userLocation, photoReference: imageReference, ignoreFullSize: true)
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(context: context, userLocation: sourceLocation.userLocation, photoReference: imageReference, displayAtSize: nil, storeToDownloadsPeerId: nil).start())
            self.statusNode.transitionToState(.play(.white), animated: false, completion: {})
            self.pinchContainerNode.contentNode.addSubnode(self.statusNode)
        }

        if let activatePinchPreview = activatePinchPreview {
            self.pinchContainerNode.activate = { sourceNode in
                activatePinchPreview(sourceNode)
            }
            self.pinchContainerNode.animatedOut = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                pinchPreviewFinished?(strongSelf)
            }
        }
    }
    
    deinit {
        self.fetchedDisposable.dispose()
        self.statusDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if self.interactive {
            let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            recognizer.delaysTouchesBegan = false
            self.view.addGestureRecognizer(recognizer)
        } else {
            self.view.isUserInteractionEnabled = false
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }

    /// Builds a heavily-blurred (`blurred: true` secret-media signal) `TransformImageNode` for a spoiler
    /// cover. The caller (the V2 media view's `MediaSpoilerDustOverlay`) HOSTS it above this node so the
    /// dust's reveal mask clears both blur + dust together, exposing the always-sharp `imageNode` — matching
    /// `ExtendedMediaOverlayNode`. Layout is via `layoutSpoilerBlurredNode(_:size:)`. Nil for media with no
    /// image signal (e.g. maps). The sharp `imageNode` itself is never blurred.
    func makeSpoilerBlurredNode() -> TransformImageNode? {
        guard let contentBlurredSignal = self.contentBlurredSignal else {
            return nil
        }
        let node = TransformImageNode()
        node.contentAnimations = []
        node.captureProtected = self.captureProtected
        node.setSignal(contentBlurredSignal)
        self.spoilerBlurredNode = node
        return node
    }

    /// Lays out a node from `makeSpoilerBlurredNode()` to fill `size` (same aspect-fill + corner-radius math
    /// as the sharp `imageNode`); `.blurBackground` + the `blurred: true` signal draw a full blur with no
    /// sharp foreground. Idempotent (a `TransformImageNode` no-ops on unchanged args).
    func layoutSpoilerBlurredNode(_ node: TransformImageNode, size: CGSize) {
        node.frame = CGRect(origin: CGPoint(), size: size)
        guard let dimensions = self.effectiveMediaDimensions() else {
            return
        }
        let imageSize = dimensions.cgSize.aspectFilled(size)
        let radius: CGFloat = self.roundCorners ? floor(min(imageSize.width, imageSize.height) / 2.0) : 0.0
        let apply = node.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: size, intrinsicInsets: UIEdgeInsets(), resizeMode: .blurBackground, emptyColor: .clear))
        apply()
    }

    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        if self.theme.imageTintColor != theme.imageTintColor {
            self.theme = theme
            self.themeUpdated = true
            self.setNeedsLayout()
        }
    }

    /// Re-point interactive bindings — `self.media` identity, the fetch-status subscription, and
    /// `fetchControls` — at a new media reference WITHOUT resetting the displayed image signal.
    ///
    /// Used when a rich message's media transitions Local→Cloud on send: `ApplyUpdateMessage` moved
    /// the bytes onto the new (cloud) resource id, so the already-decoded pixels stay valid — no
    /// reload, no blink. But the node's `media` (matched against the fresh gallery entries in
    /// `openInstantPageMedia`'s `centralIndex` lookup, and by `transitionNode`) and its fetch-status
    /// (which gates tap-to-open for images) still point at the stale local resource; without this
    /// refresh, tap-to-open silently fails until the bubble is rebuilt on the next scroll-recycle.
    /// The image signal is deliberately NOT re-set (that is what preserves the pixels / avoids the
    /// flash); the poster stays the moved-bytes image, which is identical to the cloud image.
    func updateInteractiveMediaBinding(sourceLocation: InstantPageSourceLocation, media: InstantPageMedia, imageReferenceForMedia: ((TelegramMediaImage) -> ImageMediaReference)?, fileReferenceForMedia: ((TelegramMediaFile) -> FileMediaReference)?) {
        self.media = media
        guard self.interactive else {
            return
        }
        let context = self.context
        if case let .image(image) = media.media, let largest = largestImageRepresentation(image.representations) {
            if largest.resource is InstantPageExternalMediaResource {
                return
            }
            let imageReference = imageReferenceForMedia?(image) ?? ImageMediaReference.webPage(webPage: WebpageReference(self.webPage), media: image)
            self.fetchControls = FetchControls(fetch: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(context: context, userLocation: sourceLocation.userLocation, photoReference: imageReference, displayAtSize: nil, storeToDownloadsPeerId: nil).start())
                }
            }, cancel: {
                chatMessagePhotoCancelInteractiveFetch(account: context.account, photoReference: imageReference)
            })
            self.statusDisposable.set((context.engine.resources.status(resource: EngineMediaResource(largest.resource)) |> deliverOnMainQueue).start(next: { [weak self] status in
                displayLinkDispatcher.dispatch {
                    if let strongSelf = self {
                        strongSelf.fetchStatus = status
                        strongSelf.updateFetchStatus()
                    }
                }
            }))
        }
        // The file/video branch installs no status/fetchControls (video tap is ungated and uses
        // `self.media`, refreshed above), so no further work is needed for it.
    }

    /// Re-points ONLY the `media` value — no reference, fetch-status or image-signal work.
    ///
    /// For a re-layout that keeps the same media id but changes the surrounding `InstantPageMedia`
    /// (caption, credit, url, or a photo/file that compares unequal under the same id — a message
    /// edit, or a server round-trip returning different representations). `self.media` is the value
    /// the tap hands to `openInstantPageMedia`, which matches it against the CURRENT layout's
    /// medias, and it is what `transitionNode` / `updateHiddenMedia` are matched against; letting it
    /// drift means those lookups stop resolving and the gallery never opens.
    ///
    /// Distinct from `updateInteractiveMediaBinding`, which is for the Local→Cloud id flip and
    /// additionally re-subscribes the fetch status — deliberately NOT done here, since re-arming
    /// that subscription for an unchanged resource would flicker the status back through `.Remote`.
    func updateMediaValue(_ media: InstantPageMedia) {
        self.media = media
    }
    
    private func loadExternalImage(resourceUrl: String) {
        self.externalImageLoadState = .loading
        self.updateExternalImageLoadState()
        
        var requestUrl = resourceUrl
        if !requestUrl.hasPrefix("http") && !requestUrl.hasPrefix("https") && requestUrl.hasPrefix("//") {
            requestUrl = "https:\(requestUrl)"
        }
        
        let photoData: Signal<Tuple4<Data?, Data?, ChatMessagePhotoQuality, Bool>, NoError>
        if let preloadedData = self.getPreloadedResource(resourceUrl) {
            photoData = .single(Tuple4(nil, preloadedData, .full, true))
        } else {
            photoData = self.context.engine.resources.httpData(url: requestUrl, preserveExactUrl: true)
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Data?, NoError> in
                return .single(nil)
            }
            |> map { data in
                if let data {
                    return Tuple4(nil, data, .full, true)
                } else {
                    return Tuple4(nil, nil, .full, false)
                }
            }
        }
        
        let stateAwarePhotoData = photoData
        |> deliverOnMainQueue
        |> afterNext { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if let data = value._1 ?? value._0, UIImage(data: data) != nil {
                if let dimensions = externalImagePixelDimensions(data: data) {
                    strongSelf.externalMediaDimensions = dimensions
                    strongSelf.externalMediaDimensionsUpdated = true
                    strongSelf.maybeUpdateExternalMediaDimensions(dimensions)
                }
                strongSelf.externalImageLoadState = .ready
                strongSelf.setNeedsLayout()
            } else {
                strongSelf.externalImageLoadState = .failed
            }
            strongSelf.updateExternalImageLoadState()
        }
        
        self.imageNode.setSignal(chatMessagePhotoInternal(photoData: stateAwarePhotoData)
        |> map { _, _, generate in
            return generate
        })
        
        self.fetchControls = FetchControls(fetch: { [weak self] _ in
            self?.loadExternalImage(resourceUrl: resourceUrl)
        }, cancel: {})
    }
    
    private func currentMediaDimensions() -> PixelDimensions? {
        if case let .image(image) = self.media.media, let largest = largestImageRepresentation(image.representations) {
            return largest.dimensions
        } else if case let .file(file) = self.media.media {
            return file.dimensions
        } else {
            return nil
        }
    }
    
    private func effectiveMediaDimensions() -> PixelDimensions? {
        return self.externalMediaDimensions ?? self.currentMediaDimensions()
    }
    
    private func maybeUpdateExternalMediaDimensions(_ dimensions: PixelDimensions) {
        guard !self.didReportExternalMediaDimensions, let mediaId = self.media.media.id else {
            return
        }
        if let currentDimensions = self.currentMediaDimensions(), currentDimensions == dimensions {
            return
        }
        self.didReportExternalMediaDimensions = true
        self.updateExternalMediaDimensions?(mediaId, dimensions)
    }
    
    private func updateExternalImageLoadState() {
        guard let externalImageLoadState = self.externalImageLoadState else {
            return
        }
        
        if self.statusNode.supernode == nil {
            self.pinchContainerNode.contentNode.addSubnode(self.statusNode)
        }
        
        let state: RadialStatusNodeState
        switch externalImageLoadState {
        case .loading:
            state = .progress(color: .white, lineWidth: nil, value: nil, cancelEnabled: false, animateRotation: true)
        case .ready:
            state = .none
        case .failed:
            state = .none
        }
        
        self.statusNode.transitionToState(state, completion: { [weak statusNode] in
            if state == .none {
                statusNode?.removeFromSupernode()
            }
        })
    }
    
    private func updateFetchStatus() {
        var state: RadialStatusNodeState = .none
        if let fetchStatus = self.fetchStatus {
            switch fetchStatus {
                case let .Fetching(_, progress):
                    let adjustedProgress = max(progress, 0.027)
                    state = .progress(color: .white, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true, animateRotation: true)
                case .Remote:
                    state = .download(.white)
                default:
                    break
            }
        }
        // Re-attach before showing anything: the `.none` transition below detaches the node, so a
        // status that goes back to `.Remote`/`.Fetching` — which happens when
        // `updateInteractiveMediaBinding` re-points the subscription at a Cloud resource whose bytes
        // are not local yet — would otherwise render its download/progress ring on a node that is no
        // longer in the hierarchy. The tap then takes the `.Remote` branch (fetch instead of open)
        // with NO visible indicator, reading as "tapping the image does nothing".
        // Mirrors `updateExternalImageLoadState`.
        if state != .none, self.statusNode.supernode == nil {
            self.pinchContainerNode.contentNode.addSubnode(self.statusNode)
        }
        self.statusNode.transitionToState(state, completion: { [weak statusNode] in
            if state == .none {
                statusNode?.removeFromSupernode()
            }
        })
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        if self.currentSize != size || self.themeUpdated || self.externalMediaDimensionsUpdated {
            self.currentSize = size
            self.themeUpdated = false
            self.externalMediaDimensionsUpdated = false

            self.pinchContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.pinchContainerNode.update(size: size, transition: .immediate)
            self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
            
            let radialStatusSize: CGFloat = max(18.0, min(50.0, floor(min(size.width, size.height) * 0.7)))
            self.statusNode.frame = CGRect(x: floorToScreenPixels((size.width - radialStatusSize) / 2.0), y: floorToScreenPixels((size.height - radialStatusSize) / 2.0), width: radialStatusSize, height: radialStatusSize)
            
            if case .image = self.media.media, let dimensions = self.effectiveMediaDimensions() {
                let imageSize = self.fit ? dimensions.cgSize.aspectFitted(size) : dimensions.cgSize.aspectFilled(size)
                let boundingSize = size
                let resizeMode: TransformImageResizeMode = self.fit ? .blurBackground : .fill(.black)
                let radius: CGFloat = self.roundCorners ? floor(min(imageSize.width, imageSize.height) / 2.0) : 0.0
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), resizeMode: resizeMode, emptyColor: self.emptyColorOverride ?? self.theme.panelBackgroundColor))
                apply()

                self.linkIconNode.frame = CGRect(x: size.width - 38.0, y: 14.0, width: 24.0, height: 24.0)
            } else if case let .file(file) = self.media.media, let dimensions = self.effectiveMediaDimensions() {
                let emptyColor = file.mimeType.hasPrefix("image/") ? self.theme.imageTintColor : nil

                let imageSize = self.fit ? dimensions.cgSize.aspectFitted(size) : dimensions.cgSize.aspectFilled(size)
                let boundingSize = size
                let resizeMode: TransformImageResizeMode = self.fit ? .blurBackground : .fill(.black)
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), resizeMode: resizeMode, emptyColor: self.emptyColorOverride ?? emptyColor))
                apply()
            } else if case .geo = self.media.media {
                let presentationTheme = self.context.sharedContext.currentPresentationData.with { $0 }.theme
                for attribute in self.attributes {
                    if let mapAttribute = attribute as? InstantPageMapAttribute {
                        let imageSize = mapAttribute.dimensions.aspectFilled(size)
                        let boundingSize = size
                        let radius: CGFloat = self.roundCorners ? floor(min(imageSize.width, imageSize.height) / 2.0) : 0.0
                        let makeLayout = self.imageNode.asyncLayout()
                        let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), emptyColor: presentationTheme.list.mediaPlaceholderColor))
                        apply()
                        break
                    }
                }

                let makePinLayout = self.pinNode.asyncLayout()
                let (pinSize, pinApply) = makePinLayout(self.context, presentationTheme, .location(nil))
                self.pinNode.frame = CGRect(origin: CGPoint(x: floor((size.width - pinSize.width) / 2.0), y: floor(size.height * 0.5 - 10.0 - pinSize.height / 2.0)), size: pinSize)
                pinApply()
            } else if case let .webpage(webPage) = media.media, case let .Loaded(content) = webPage.content, let image = content.image, let largest = largestImageRepresentation(image.representations) {
                let imageSize = largest.dimensions.cgSize.aspectFilled(size)
                let boundingSize = size
                let radius: CGFloat = self.roundCorners ? floor(min(imageSize.width, imageSize.height) / 2.0) : 0.0
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), emptyColor: self.theme.pageBackgroundColor))
                apply()
            }
        }
    }

    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if instantPageMediaMatchesNodeIdentity(media, self.media) {
            let imageNode = self.imageNode
            return (self.imageNode, self.imageNode.bounds, { [weak imageNode] in
                guard let imageNode else {
                    return (nil, nil)
                }
                guard imageNode.captureProtected else {
                    return (imageNode.view.snapshotContentTree(unhide: true), nil)
                }
                // A capture-protected layer is excluded from snapshots too, so snapshotting it
                // directly yields an empty view and the gallery open/close animation flies a blank
                // rect. Mirror `ChatMessageInteractiveMediaNode.transitionNode(adjustRect:)`: stand an
                // UNPROTECTED copy of the image in front of the protected node, snapshot that, then
                // protect the resulting snapshot so the transition itself stays uncapturable.
                let standInView = UIImageView()
                standInView.contentMode = .scaleToFill
                standInView.image = imageNode.image
                standInView.frame = imageNode.bounds
                if standInView.layer.contents == nil {
                    standInView.layer.contents = standInView.image?.cgImage
                }
                imageNode.view.addSubview(standInView)
                let view = imageNode.view.snapshotContentTree(unhide: true)
                standInView.removeFromSuperview()
                if let view {
                    setLayerDisableScreenshots(view.layer, true)
                }
                return (view, nil)
            })
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        if let media {
            self.imageNode.isHidden = instantPageMediaMatchesNodeIdentity(self.media, media)
        } else {
            self.imageNode.isHidden = false
        }
        self.statusNode.isHidden = self.imageNode.isHidden
        self.linkIconNode.isHidden = self.imageNode.isHidden
    }
    
    @objc private func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                    if let externalImageLoadState = self.externalImageLoadState {
                        switch externalImageLoadState {
                        case .loading:
                            return
                        case .failed:
                            if case .tap = gesture {
                                self.fetchControls?.fetch(true)
                            }
                            return
                        case .ready:
                            break
                        }
                    }
                    if let fetchStatus = self.fetchStatus {
                        switch fetchStatus {
                            case .Local:
                                switch gesture {
                                    case .tap:
                                    if case .image = self.media.media, self.media.index == -1 {
                                            return
                                        }
                                        self.openMedia(self.media)
                                    case .longTap:
                                        self.longPressMedia(self.media)
                                    default:
                                        break
                                }
                            case .Remote, .Paused:
                                if case .tap = gesture {
                                    self.fetchControls?.fetch(true)
                                }
                            case .Fetching:
                                if case .tap = gesture {
                                    self.fetchControls?.cancel()
                                }
                        }
                    } else {
                        switch gesture {
                            case .tap:
                                if case .image = self.media.media, self.media.index == -1 {
                                    return
                                }
                                self.openMedia(self.media)
                            case .longTap:
                                self.longPressMedia(self.media)
                            default:
                                break
                        }
                    }
                }
            default:
                break
        }
    }
}
