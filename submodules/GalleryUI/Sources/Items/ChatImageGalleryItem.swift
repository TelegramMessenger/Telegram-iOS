import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import PhotoResources
import AppBundle
import StickerPackPreviewUI
import OverlayStatusController
import PresentationDataUtils

enum ChatMediaGalleryThumbnail: Equatable {
    case image(ImageMediaReference)
    case video(FileMediaReference)
    
    static func ==(lhs: ChatMediaGalleryThumbnail, rhs: ChatMediaGalleryThumbnail) -> Bool {
        switch lhs {
            case let .image(lhsImage):
                if case let .image(rhsImage) = rhs, lhsImage.media.isEqual(to: rhsImage.media) {
                    return true
                } else {
                    return false
                }
            case let .video(lhsVideo):
                if case let .video(rhsVideo) = rhs, lhsVideo.media.isEqual(to: rhsVideo.media) {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class ChatMediaGalleryThumbnailItem: GalleryThumbnailItem {
    private let account: Account
    private let thumbnail: ChatMediaGalleryThumbnail
    
    init?(account: Account, mediaReference: AnyMediaReference) {
        self.account = account
        if let imageReference = mediaReference.concrete(TelegramMediaImage.self) {
            self.thumbnail = .image(imageReference)
        } else if let fileReference = mediaReference.concrete(TelegramMediaFile.self), fileReference.media.isVideo {
            self.thumbnail = .video(fileReference)
        } else {
            return nil
        }
    }
    
    func isEqual(to: GalleryThumbnailItem) -> Bool {
        if let to = to as? ChatMediaGalleryThumbnailItem {
            return self.thumbnail == to.thumbnail
        } else {
            return false
        }
    }
    
    var image: (Signal<(TransformImageArguments) -> DrawingContext?, NoError>, CGSize) {
        switch self.thumbnail {
            case let .image(imageReference):
                if let representation = largestImageRepresentation(imageReference.media.representations) {
                    return (mediaGridMessagePhoto(account: self.account, photoReference: imageReference), representation.dimensions.cgSize)
                } else {
                    return (.single({ _ in return nil }), CGSize(width: 128.0, height: 128.0))
                }
            case let .video(fileReference):
                if let representation = largestImageRepresentation(fileReference.media.previewRepresentations) {
                    return (mediaGridMessageVideo(postbox: self.account.postbox, videoReference: fileReference), representation.dimensions.cgSize)
                } else {
                    return (.single({ _ in return nil }), CGSize(width: 128.0, height: 128.0))
                }
        }
    }
}

class ChatImageGalleryItem: GalleryItem {
    let context: AccountContext
    let presentationData: PresentationData
    let message: Message
    let location: MessageHistoryEntryLocation?
    let performAction: (GalleryControllerInteractionTapAction) -> Void
    let openActionOptions: (GalleryControllerInteractionTapAction) -> Void
    
    init(context: AccountContext, presentationData: PresentationData, message: Message, location: MessageHistoryEntryLocation?, performAction: @escaping (GalleryControllerInteractionTapAction) -> Void, openActionOptions: @escaping (GalleryControllerInteractionTapAction) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.message = message
        self.location = location
        self.performAction = performAction
        self.openActionOptions = openActionOptions
    }
    
    func node() -> GalleryItemNode {
        let node = ChatImageGalleryItemNode(context: self.context, presentationData: self.presentationData, performAction: self.performAction, openActionOptions: self.openActionOptions)
        
        for media in self.message.media {
            if let image = media as? TelegramMediaImage {
                node.setImage(imageReference: .message(message: MessageReference(self.message), media: image))
                break
            } else if let file = media as? TelegramMediaFile, file.mimeType.hasPrefix("image/") {
                node.setFile(context: self.context, fileReference: .message(message: MessageReference(self.message), media: file))
                break
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if let image = content.image {
                    node.setImage(imageReference: .message(message: MessageReference(self.message), media: image))
                    break
                } else if let file = content.file, file.mimeType.hasPrefix("image/") {
                    node.setFile(context: self.context, fileReference: .message(message: MessageReference(self.message), media: file))
                    break
                }
            }
        }
        
        if let location = self.location {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(location.index + 1)", "\(location.count)").0))
        }
        
        node.setMessage(self.message)
        
        return node
    }
    
    func updateNode(node: GalleryItemNode) {
        if let node = node as? ChatImageGalleryItemNode, let location = self.location {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(location.index + 1)", "\(location.count)").0))
            
            node.setMessage(self.message)
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        if let id = self.message.groupInfo?.stableId {
            var mediaReference: AnyMediaReference?
            for m in self.message.media {
                if let m = m as? TelegramMediaImage {
                    mediaReference = .message(message: MessageReference(self.message), media: m)
                } else if let m = m as? TelegramMediaFile, m.isVideo {
                    mediaReference = .message(message: MessageReference(self.message), media: m)
                }
            }
            if let mediaReference = mediaReference {
                if let item = ChatMediaGalleryThumbnailItem(account: self.context.account, mediaReference: mediaReference) {
                    return (Int64(id), item)
                }
            }
        }
        return nil
    }
}

final class ChatImageGalleryItemNode: ZoomableContentGalleryItemNode {
    private let context: AccountContext
    private var message: Message?
    
    private let imageNode: TransformImageNode
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    fileprivate let _rightBarButtonItem = Promise<UIBarButtonItem?>()
    private let statusNodeContainer: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    private let footerContentNode: ChatItemGalleryFooterContentNode
    
    private var contextAndMedia: (AccountContext, AnyMediaReference)?
    
    private var fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private var status: MediaResourceStatus?
    
    init(context: AccountContext, presentationData: PresentationData, performAction: @escaping (GalleryControllerInteractionTapAction) -> Void, openActionOptions: @escaping (GalleryControllerInteractionTapAction) -> Void) {
        self.context = context
        
        self.imageNode = TransformImageNode()
        self.footerContentNode = ChatItemGalleryFooterContentNode(context: context, presentationData: presentationData)
        self.footerContentNode.performAction = performAction
        self.footerContentNode.openActionOptions = openActionOptions
        
        self.statusNodeContainer = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        self.statusNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 50.0, height: 50.0))
        self.statusNode.isHidden = true
        
        super.init()
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self.imageNode.view.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        
        self.statusNodeContainer.addSubnode(self.statusNode)
        self.addSubnode(self.statusNodeContainer)
        
        self.statusNodeContainer.addTarget(self, action: #selector(self.statusPressed), forControlEvents: .touchUpInside)
        
        self.statusNodeContainer.isUserInteractionEnabled = false
    }
    
    deinit {
        //self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
    }
    
    override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let statusSize = CGSize(width: 50.0, height: 50.0)
        transition.updateFrame(node: self.statusNodeContainer, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - statusSize.width) / 2.0), y: floor((layout.size.height - statusSize.height) / 2.0)), size: statusSize))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(), size: statusSize))
    }
    
    fileprivate func setMessage(_ message: Message) {
        self.footerContentNode.setMessage(message)
    }
    
    fileprivate func setImage(imageReference: ImageMediaReference) {
        if self.contextAndMedia == nil || !self.contextAndMedia!.1.media.isEqual(to: imageReference.media) {
            if let largestSize = largestRepresentationForPhoto(imageReference.media) {
                let displaySize = largestSize.dimensions.cgSize.fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.setSignal(chatMessagePhoto(postbox: context.account.postbox, photoReference: imageReference), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize.dimensions.cgSize, self.imageNode)
                
                self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, reference: imageReference.resourceReference(largestSize.resource)).start())
                self.setupStatus(resource: largestSize.resource)
            } else {
                self._ready.set(.single(Void()))
            }
            if imageReference.media.flags.contains(.hasStickers) {
                let rightBarButtonItem = UIBarButtonItem(image: UIImage(bundleImageName: "Media Gallery/Stickers"), style: .plain, target: self, action: #selector(self.openStickersButtonPressed))
                self._rightBarButtonItem.set(.single(rightBarButtonItem))
            }
        }
        self.contextAndMedia = (self.context, imageReference.abstract)
    }
    
    @objc func openStickersButtonPressed() {
        guard let (context, media) = self.contextAndMedia else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            guard let strongSelf = self else {
                return EmptyDisposable
            }
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
            (strongSelf.baseNavigationController()?.topViewController as? ViewController)?.present(controller, in: .window(.root), with: nil)
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.15, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()
        
        let signal = stickerPacksAttachedToMedia(account: context.account, media: media)
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        let _ = (signal
        |> deliverOnMainQueue).start(next: { [weak self] packs in
            guard let strongSelf = self, !packs.isEmpty else {
                return
            }
            let baseNavigationController = strongSelf.baseNavigationController()
            baseNavigationController?.view.endEditing(true)
            let controller = StickerPackScreen(context: context, mainStickerPack: packs[0], stickerPacks: packs, sendSticker: nil)
            (baseNavigationController?.topViewController as? ViewController)?.present(controller, in: .window(.root), with: nil)
        })
    }
    
    func setFile(context: AccountContext, fileReference: FileMediaReference) {
        if self.contextAndMedia == nil || !self.contextAndMedia!.1.media.isEqual(to: fileReference.media) {
            if var largestSize = fileReference.media.dimensions {
                var displaySize = largestSize.cgSize.dividedByScreenScale()
                if let previewDimensions = largestImageRepresentation(fileReference.media.previewRepresentations)?.dimensions {
                    let previewAspect = CGFloat(previewDimensions.width) / CGFloat(previewDimensions.height)
                    let aspect = displaySize.width / displaySize.height
                    if abs(previewAspect - 1.0 / aspect) < 0.1 {
                        displaySize = CGSize(width: displaySize.height, height: displaySize.width)
                        largestSize = PixelDimensions(width: largestSize.height, height: largestSize.width)
                    }
                }
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.setSignal(chatMessageImageFile(account: context.account, fileReference: fileReference, thumbnail: false), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize.cgSize, self.imageNode)
                self.setupStatus(resource: fileReference.media.resource)
            } else {
                self._ready.set(.single(Void()))
            }
        }
        self.contextAndMedia = (context, fileReference.abstract)
    }
    
    private func setupStatus(resource: MediaResource) {
        self.statusDisposable.set((self.context.account.postbox.mediaBox.resourceStatus(resource)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                let previousStatus = strongSelf.status
                strongSelf.status = status
                switch status {
                    case .Remote:
                        strongSelf.statusNode.isHidden = false
                        strongSelf.statusNode.alpha = 1.0
                        strongSelf.statusNodeContainer.isUserInteractionEnabled = true
                        strongSelf.statusNode.transitionToState(.download(.white), completion: {})
                    case let .Fetching(isActive, progress):
                        strongSelf.statusNode.isHidden = false
                        strongSelf.statusNode.alpha = 1.0
                        strongSelf.statusNodeContainer.isUserInteractionEnabled = true
                        let adjustedProgress = max(progress, 0.027)
                        strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true), completion: {})
                    case .Local:
                        if let previousStatus = previousStatus, case .Fetching = previousStatus {
                            strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: 1.0, cancelEnabled: true), completion: {
                                if let strongSelf = self {
                                    strongSelf.statusNode.alpha = 0.0
                                    strongSelf.statusNodeContainer.isUserInteractionEnabled = false
                                    strongSelf.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { _ in
                                        if let strongSelf = self {
                                            strongSelf.statusNode.transitionToState(.none, animated: false, completion: {})
                                        }
                                    })
                                }
                            })
                        } else if !strongSelf.statusNode.isHidden && !strongSelf.statusNode.alpha.isZero {
                            strongSelf.statusNode.alpha = 0.0
                            strongSelf.statusNodeContainer.isUserInteractionEnabled = false
                            strongSelf.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { _ in
                                if let strongSelf = self {
                                    strongSelf.statusNode.transitionToState(.none, animated: false, completion: {})
                                }
                            })
                        }
                }
            }
        }))
    }
    
    override func animateIn(from node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        
        /*let projectedScale = CGPoint(x: self.imageNode.view.bounds.width / node.1.width, y: self.imageNode.view.bounds.height / node.1.height)
        let scaledLocalImageViewBounds = CGRect(x: -node.1.minX * projectedScale.x, y: -node.1.minY * projectedScale.y, width: node.0.bounds.width * projectedScale.x, height: node.0.bounds.height * projectedScale.y)*/
        
        let scaledLocalImageViewBounds = self.imageNode.view.bounds
        
        let transformedCopyViewFinalFrame = self.imageNode.view.convert(scaledLocalImageViewBounds, to: self.view)
        
        let (maybeSurfaceCopyView, _) = node.2()
        let (maybeCopyView, copyViewBackgrond) = node.2()
        copyViewBackgrond?.alpha = 0.0
        let surfaceCopyView = maybeSurfaceCopyView!
        let copyView = maybeCopyView!
        
        addToTransitionSurface(surfaceCopyView)
        
        var transformedSurfaceFrame: CGRect?
        var transformedSurfaceFinalFrame: CGRect?
        if let contentSurface = surfaceCopyView.superview {
            transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
            transformedSurfaceFinalFrame = self.imageNode.view.convert(scaledLocalImageViewBounds, to: contentSurface)
        }
        
        if let transformedSurfaceFrame = transformedSurfaceFrame {
            surfaceCopyView.frame = transformedSurfaceFrame
        }
        
        self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
        copyView.frame = transformedSelfFrame
        
        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        surfaceCopyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        let positionDuration: Double = 0.21
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), to: CGPoint(x: transformedCopyViewFinalFrame.midX, y: transformedCopyViewFinalFrame.midY), duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak copyView] _ in
            copyView?.removeFromSuperview()
        })
        let scale = CGSize(width: transformedCopyViewFinalFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewFinalFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        
        if let transformedSurfaceFrame = transformedSurfaceFrame, let transformedSurfaceFinalFrame = transformedSurfaceFinalFrame {
            surfaceCopyView.layer.animatePosition(from: CGPoint(x: transformedSurfaceFrame.midX, y: transformedSurfaceFrame.midY), to: CGPoint(x: transformedCopyViewFinalFrame.midX, y: transformedCopyViewFinalFrame.midY), duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak surfaceCopyView] _ in
                surfaceCopyView?.removeFromSuperview()
            })
            let scale = CGSize(width: transformedSurfaceFinalFrame.size.width / transformedSurfaceFrame.size.width, height: transformedSurfaceFinalFrame.size.height / transformedSurfaceFrame.size.height)
            surfaceCopyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        }
        
        self.imageNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.imageNode.layer.position, duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring)
        self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        
        transformedFrame.origin = CGPoint()
        self.imageNode.layer.animateBounds(from: transformedFrame, to: self.imageNode.layer.bounds, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        
        self.statusNodeContainer.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.statusNodeContainer.position, duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateScale(from: 0.5, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    override func animateOut(to node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        self.fetchDisposable.set(nil)
        
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let (maybeSurfaceCopyView, _) = node.2()
        let (maybeCopyView, copyViewBackgrond) = node.2()
        copyViewBackgrond?.alpha = 0.0
        let surfaceCopyView = maybeSurfaceCopyView!
        let copyView = maybeCopyView!
        
        addToTransitionSurface(surfaceCopyView)
        
        var transformedSurfaceFrame: CGRect?
        var transformedSurfaceCopyViewInitialFrame: CGRect?
        if let contentSurface = surfaceCopyView.superview {
            transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
            transformedSurfaceCopyViewInitialFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: contentSurface)
        }
        
        self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
        copyView.frame = transformedSelfFrame
        
        let intermediateCompletion = { [weak copyView, weak surfaceCopyView] in
            if positionCompleted && boundsCompleted && copyCompleted {
                copyView?.removeFromSuperview()
                surfaceCopyView?.removeFromSuperview()
                completion()
            }
        }
        
        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08, removeOnCompletion: false)
        surfaceCopyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.025, removeOnCompletion: false)
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            copyCompleted = true
            intermediateCompletion()
        })
        
        if let transformedSurfaceFrame = transformedSurfaceFrame, let transformedCopyViewInitialFrame = transformedSurfaceCopyViewInitialFrame {
            surfaceCopyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSurfaceFrame.midX, y: transformedSurfaceFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSurfaceFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSurfaceFrame.size.height)
            surfaceCopyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        }
        
        self.imageNode.layer.animatePosition(from: self.imageNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        self.imageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        self.imageNode.layer.animateBounds(from: self.imageNode.layer.bounds, to: transformedFrame, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        self.statusNodeContainer.layer.animatePosition(from: self.statusNodeContainer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.statusNodeContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false)
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
        
        if let (context, mediaReference) = self.contextAndMedia, let fileReference = mediaReference.concrete(TelegramMediaFile.self) {
            if isVisible {
            } else {
                self.fetchDisposable.set(nil)
            }
        }
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    override func rightBarButtonItem() -> Signal<UIBarButtonItem?, NoError> {
        return self._rightBarButtonItem.get()
    }
    
    override func footerContent() -> Signal<GalleryFooterContentNode?, NoError> {
        return .single(self.footerContentNode)
    }
    
    @objc func statusPressed() {
        if let (_, mediaReference) = self.contextAndMedia, let status = self.status {
            var resource: MediaResourceReference?
            var statsCategory: MediaResourceStatsCategory?
            if let fileReference = mediaReference.concrete(TelegramMediaFile.self) {
                resource = fileReference.resourceReference(fileReference.media.resource)
                statsCategory = statsCategoryForFileWithAttributes(fileReference.media.attributes)
            } else if let imageReference = mediaReference.concrete(TelegramMediaImage.self ) {
                resource = (largestImageRepresentation(imageReference.media.representations)?.resource).flatMap(imageReference.resourceReference)
                statsCategory = .image
            }
            if let resource = resource {
                switch status {
                    case .Fetching:
                        self.context.account.postbox.mediaBox.cancelInteractiveResourceFetch(resource.resource)
                    case .Remote:
                        self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, reference: resource, statsCategory: statsCategory ?? .generic).start())
                    default:
                        break
                }
            }
        }
    }
}
