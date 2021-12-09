import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import ShareController
import PhotoResources
import GalleryUI
import TelegramUniversalVideoContent
import UndoUI

private struct PeerAvatarImageGalleryThumbnailItem: GalleryThumbnailItem {
    let account: Account
    let peer: Peer
    let content: [ImageRepresentationWithReference]
    
    init(account: Account, peer: Peer, content: [ImageRepresentationWithReference]) {
        self.account = account
        self.peer = peer
        self.content = content
    }
    
    func image(synchronous: Bool) -> (Signal<(TransformImageArguments) -> DrawingContext?, NoError>, CGSize) {
        if let representation = largestImageRepresentation(self.content.map({ $0.representation })) {
            return (avatarGalleryThumbnailPhoto(account: self.account, representations: self.content, synchronousLoad: synchronous), representation.dimensions.cgSize)
        } else {
            return (.single({ _ in return nil }), CGSize(width: 128.0, height: 128.0))
        }
    }
    
    func isEqual(to: GalleryThumbnailItem) -> Bool {
        if let to = to as? PeerAvatarImageGalleryThumbnailItem {
            return self.content == to.content
        } else {
            return false
        }
    }
}

class PeerAvatarImageGalleryItem: GalleryItem {
    var id: AnyHashable {
        return self.entry.id
    }
    
    let context: AccountContext
    let peer: Peer
    let presentationData: PresentationData
    let entry: AvatarGalleryEntry
    let sourceCorners: AvatarGalleryController.SourceCorners
    let delete: (() -> Void)?
    let setMain: (() -> Void)?
    let edit: (() -> Void)?
    
    init(context: AccountContext, peer: Peer, presentationData: PresentationData, entry: AvatarGalleryEntry, sourceCorners: AvatarGalleryController.SourceCorners, delete: (() -> Void)?, setMain: (() -> Void)?, edit: (() -> Void)?) {
        self.context = context
        self.peer = peer
        self.presentationData = presentationData
        self.entry = entry
        self.sourceCorners = sourceCorners
        self.delete = delete
        self.setMain = setMain
        self.edit = edit
    }
        
    func node(synchronous: Bool) -> GalleryItemNode {
        let node = PeerAvatarImageGalleryItemNode(context: self.context, presentationData: self.presentationData, peer: self.peer, sourceCorners: self.sourceCorners)
        
        if let indexData = self.entry.indexData {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(indexData.position + 1)", "\(indexData.totalCount)").string))
        }
        
        node.setEntry(self.entry, synchronous: synchronous)
        node.footerContentNode.delete = self.delete
        node.footerContentNode.setMain = self.setMain
        node.edit = self.edit
        
        return node
    }
    
    func updateNode(node: GalleryItemNode, synchronous: Bool) {
        if let node = node as? PeerAvatarImageGalleryItemNode {
            if let indexData = self.entry.indexData {
                node._title.set(.single(self.presentationData.strings.Items_NOfM("\(indexData.position + 1)", "\(indexData.totalCount)").string))
            }
            let previousContentAnimations = node.imageNode.contentAnimations
            if synchronous {
                node.imageNode.contentAnimations = []
            }
            node.setEntry(self.entry, synchronous: synchronous)
            if synchronous {
                 node.imageNode.contentAnimations = previousContentAnimations
            }
            node.footerContentNode.delete = self.delete
            node.footerContentNode.setMain = self.setMain
            node.edit = self.edit
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        let content: [ImageRepresentationWithReference]
        switch self.entry {
            case let .topImage(representations, _, _, _, _, _):
                content = representations
            case let .image(_, _, representations, _, _, _, _, _, _, _):
                content = representations
        }
        
        return (0, PeerAvatarImageGalleryThumbnailItem(account: self.context.account, peer: self.peer, content: content))
    }
}

private class PeerAvatarImageGalleryContentNode: ASDisplayNode {
    override func layout() {
        super.layout()
        
        if let subnodes = self.subnodes {
            for node in subnodes {
                node.frame = self.bounds
            }
        }
    }
}

final class PeerAvatarImageGalleryItemNode: ZoomableContentGalleryItemNode {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let peer: Peer
    private let sourceCorners: AvatarGalleryController.SourceCorners
    
    private var entry: AvatarGalleryEntry?
    
    private let contentNode: PeerAvatarImageGalleryContentNode
    fileprivate let imageNode: TransformImageNode
    private var videoNode: UniversalVideoNode?
    private var videoContent: NativeVideoContent?
    private var videoStartTimestamp: Double?
    
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    fileprivate let _rightBarButtonItems = Promise<[UIBarButtonItem]?>()
    
    private let statusNodeContainer: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    fileprivate let footerContentNode: AvatarGalleryItemFooterContentNode
    
    private let fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private var status: MediaResourceStatus?
    private let playbackStatusDisposable = MetaDisposable()
    
    fileprivate var edit: (() -> Void)?
    
    init(context: AccountContext, presentationData: PresentationData, peer: Peer, sourceCorners: AvatarGalleryController.SourceCorners) {
        self.context = context
        self.presentationData = presentationData
        self.peer = peer
        self.sourceCorners = sourceCorners
        
        self.contentNode = PeerAvatarImageGalleryContentNode()
        self.imageNode = TransformImageNode()
        self.footerContentNode = AvatarGalleryItemFooterContentNode(context: context, presentationData: presentationData)
        
        self.statusNodeContainer = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        self.statusNode.isHidden = true
        
        super.init()
        
        self.contentNode.addSubnode(self.imageNode)
                
        self.imageNode.contentAnimations = .subsequentUpdates
        self.imageNode.view.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        
        self.statusNodeContainer.addSubnode(self.statusNode)
        self.addSubnode(self.statusNodeContainer)
        
        self.statusNodeContainer.addTarget(self, action: #selector(self.statusPressed), forControlEvents: .touchUpInside)
        self.statusNodeContainer.isUserInteractionEnabled = false
        
        self.footerContentNode.share = { [weak self] interaction in
            if let strongSelf = self, let entry = strongSelf.entry, !entry.representations.isEmpty {
                let subject: ShareControllerSubject
                var actionCompletionText: String?
                if let video = entry.videoRepresentations.last, let peerReference = PeerReference(peer) {
                    let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.representation.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.representation.dimensions, flags: [])]))
                    subject = .media(videoFileReference.abstract)
                    actionCompletionText = strongSelf.presentationData.strings.Gallery_VideoSaved
                } else {
                    subject = .image(entry.representations)
                    actionCompletionText = strongSelf.presentationData.strings.Gallery_ImageSaved
                }
                let shareController = ShareController(context: strongSelf.context, subject: subject, preferredAction: .saveToCameraRoll)
                shareController.actionCompleted = { [weak self] in
                    if let strongSelf = self, let actionCompletionText = actionCompletionText {
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        interaction.presentController(UndoOverlayController(presentationData: presentationData, content: .mediaSaved(text: actionCompletionText), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return true }), nil)
                    }
                }
                interaction.presentController(shareController, nil)
            }
        }
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
        self.playbackStatusDisposable.dispose()
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
    
    fileprivate func setEntry(_ entry: AvatarGalleryEntry, synchronous: Bool) {
        let previousRepresentations = self.entry?.representations
        let previousVideoRepresentations = self.entry?.videoRepresentations
        if self.entry != entry {
            self.entry = entry
            
            var barButtonItems: [UIBarButtonItem] = []
            let footerContent: AvatarGalleryItemFooterContent = .info
            if self.peer.id == self.context.account.peerId {
                let rightBarButtonItem =  UIBarButtonItem(title: entry.videoRepresentations.isEmpty ? self.presentationData.strings.Settings_EditPhoto : self.presentationData.strings.Settings_EditVideo, style: .plain, target: self, action: #selector(self.editPressed))
                barButtonItems.append(rightBarButtonItem)
            }
            self._rightBarButtonItems.set(.single(barButtonItems))
                        
            self.footerContentNode.setEntry(entry, content: footerContent)
            
            if let largestSize = largestImageRepresentation(entry.representations.map({ $0.representation })) {
                let displaySize = largestSize.dimensions.cgSize.fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                let representations = entry.representations
                if representations.last != previousRepresentations?.last {
                    self.imageNode.setSignal(chatAvatarGalleryPhoto(account: self.context.account, representations: representations, immediateThumbnailData: entry.immediateThumbnailData, attemptSynchronously: synchronous), attemptSynchronously: synchronous, dispatchOnDisplayLink: false)
                    if entry.videoRepresentations.isEmpty {
                        self.imageNode.imageUpdated = { [weak self] _ in
                            self?._ready.set(.single(Void()))
                        }
                    }
                }
                
                self.zoomableContent = (largestSize.dimensions.cgSize, self.contentNode)

                if let largestIndex = representations.firstIndex(where: { $0.representation == largestSize }) {
                    self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, reference: representations[largestIndex].reference).start())
                }
                
                var id: Int64
                var category: String?
                if case let .image(mediaId, _, _, _, _, _, _, _, _, categoryValue) = entry {
                    id = mediaId.id
                    category = categoryValue
                } else {
                    id = Int64(entry.peer?.id.id._internalGetInt64Value() ?? 0)
                    if let resource = entry.videoRepresentations.first?.representation.resource as? CloudPhotoSizeMediaResource {
                        id = id &+ resource.photoId
                    }
                }
                if let video = entry.videoRepresentations.last, let peerReference = PeerReference(self.peer) {
                    if video != previousVideoRepresentations?.last {
                        let mediaManager = self.context.sharedContext.mediaManager
                        let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.representation.resource, previewRepresentations: representations.map { $0.representation }, videoThumbnails: [], immediateThumbnailData: entry.immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.representation.dimensions, flags: [])]))
                        let videoContent = NativeVideoContent(id: .profileVideo(id, category), fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.representation.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: true, useLargeThumbnail: true, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear)
                        let videoNode = UniversalVideoNode(postbox: self.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: videoContent, priority: .overlay)
                        videoNode.isUserInteractionEnabled = false
                        videoNode.isHidden = true
                        self.videoStartTimestamp = video.representation.startTimestamp
                                            
                        self.videoContent = videoContent
                        self.videoNode = videoNode
                        
                        self.playVideoIfCentral()
                        videoNode.updateLayout(size: largestSize.dimensions.cgSize, transition: .immediate)
                        
                        self.contentNode.addSubnode(videoNode)
                        
                        self._ready.set(videoNode.ready)
                    }
                } else if let videoNode = self.videoNode {
                    self.videoContent = nil
                    self.videoNode = nil
                    
                    Queue.mainQueue().after(0.1) {
                        videoNode.removeFromSupernode()
                    }
                }
                
                self.imageNode.frame = self.contentNode.bounds
                self.videoNode?.frame = self.contentNode.bounds
            } else {
                self._ready.set(.single(Void()))
            }
        }
    }
    
    private func playVideoIfCentral() {
        guard let videoNode = self.videoNode, self.isCentral else {
            return
        }
        if let _ = self.videoStartTimestamp {
            videoNode.isHidden = true
            self.playbackStatusDisposable.set((videoNode.status
                |> map { status -> Bool in
                    if let status = status, case .playing = status.status {
                        return true
                    } else {
                        return false
                    }
                }
                |> filter { playing in
                    return playing
                }
                |> take(1)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    if let strongSelf = self {
                        Queue.mainQueue().after(0.1) {
                            strongSelf.videoNode?.isHidden = false
                        }
                    }
                }))
        } else {
            self.playbackStatusDisposable.set(nil)
            videoNode.isHidden = false
        }
    
        let hadAttachedContent = videoNode.hasAttachedContext
        videoNode.canAttachContent = true
        if videoNode.hasAttachedContext {
            if let startTimestamp = self.videoStartTimestamp, !hadAttachedContent {
                videoNode.seek(startTimestamp)
            }
            videoNode.play()
        }
    }
    
    var isCentral = false
    override func centralityUpdated(isCentral: Bool) {
        super.centralityUpdated(isCentral: isCentral)
        
        if self.isCentral != isCentral {
            self.isCentral = isCentral
            
            if isCentral {
                self.playVideoIfCentral()
            } else if let videoNode = self.videoNode {
                videoNode.pause()
                if let startTimestamp = self.videoStartTimestamp {
                    videoNode.seek(startTimestamp)
                } else {
                    videoNode.seek(0.0)
                }
                videoNode.isHidden = true
            }
        }
    }
    
    override func animateIn(from node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.contentNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.contentNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewFinalFrame = self.contentNode.view.convert(self.contentNode.view.bounds, to: self.view)
        let scaledLocalImageViewBounds = self.contentNode.view.bounds
        
        let copyViewContents = node.2().0!
        let copyView = UIView()
        copyView.addSubview(copyViewContents)
        copyViewContents.frame = CGRect(origin: CGPoint(x: (transformedSelfFrame.width - copyViewContents.frame.width) / 2.0, y: (transformedSelfFrame.height - copyViewContents.frame.height) / 2.0), size: copyViewContents.frame.size)
        copyView.layer.sublayerTransform = CATransform3DMakeScale(transformedSelfFrame.width / copyViewContents.frame.width, transformedSelfFrame.height / copyViewContents.frame.height, 1.0)
        
        let surfaceCopyViewContents = node.2().0!
        let surfaceCopyView = UIView()
        surfaceCopyView.addSubview(surfaceCopyViewContents)
        
        addToTransitionSurface(surfaceCopyView)
        
        var transformedSurfaceFrame: CGRect?
        var transformedSurfaceFinalFrame: CGRect?
        if let contentSurface = surfaceCopyView.superview {
            transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
            transformedSurfaceFinalFrame = self.contentNode.view.convert(scaledLocalImageViewBounds, to: contentSurface)
        }
        
        if let transformedSurfaceFrame = transformedSurfaceFrame, let transformedSurfaceFinalFrame = transformedSurfaceFinalFrame {
            surfaceCopyViewContents.frame = CGRect(origin: CGPoint(x: (transformedSurfaceFrame.width - surfaceCopyViewContents.frame.width) / 2.0, y: (transformedSurfaceFrame.height - surfaceCopyViewContents.frame.height) / 2.0), size: surfaceCopyViewContents.frame.size)
            surfaceCopyView.layer.sublayerTransform = CATransform3DMakeScale(transformedSurfaceFrame.width / surfaceCopyViewContents.frame.width, transformedSurfaceFrame.height / surfaceCopyViewContents.frame.height, 1.0)
            surfaceCopyView.frame = transformedSurfaceFrame
            
            surfaceCopyView.layer.animatePosition(from: CGPoint(x: transformedSurfaceFrame.midX, y: transformedSurfaceFrame.midY), to: CGPoint(x: transformedSurfaceFinalFrame.midX, y: transformedSurfaceFinalFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            let scale = CGSize(width: transformedSurfaceFinalFrame.size.width / transformedSurfaceFrame.size.width, height: transformedSurfaceFrame.size.height / transformedSelfFrame.size.height)
            surfaceCopyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
            
            surfaceCopyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak surfaceCopyView] _ in
                surfaceCopyView?.removeFromSuperview()
            })
        }
        
        if case .round = self.sourceCorners {
            self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
        }
        copyView.frame = transformedSelfFrame
        
        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak copyView] _ in
            copyView?.removeFromSuperview()
        })
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), to: CGPoint(x: transformedCopyViewFinalFrame.midX, y: transformedCopyViewFinalFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewFinalFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewFinalFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        
        self.contentNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.contentNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            completion()
        })
        
        if let _ = self.videoNode {
            self.contentNode.view.superview?.bringSubviewToFront(self.contentNode.view)
        } else {
            self.contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.07)
        }
        
        transformedFrame.origin = CGPoint()
        //self.imageNode.layer.animateBounds(from: transformedFrame, to: self.imageNode.layer.bounds, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        
        let transform = CATransform3DScale(self.contentNode.layer.transform, transformedFrame.size.width / self.contentNode.layer.bounds.size.width, transformedFrame.size.height / self.contentNode.layer.bounds.size.height, 1.0)
        self.contentNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: self.contentNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
        
        self.contentNode.clipsToBounds = true
        if case .round = self.sourceCorners {
            self.contentNode.layer.animate(from: (self.contentNode.frame.width / 2.0) as NSNumber, to: 0.0 as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.default.rawValue, duration: 0.18, removeOnCompletion: false, completion: { [weak self] value in
                if value {
                    self?.contentNode.clipsToBounds = false
                }
            })
        } else if case let .roundRect(cornerRadius) = self.sourceCorners {
            let scale = scaledLocalImageViewBounds.width / transformedCopyViewFinalFrame.width
            let selfScale = transformedCopyViewFinalFrame.width / transformedSelfFrame.width
            self.contentNode.layer.animate(from: (cornerRadius * scale * selfScale) as NSNumber, to: 0.0 as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.default.rawValue, duration: 0.18, removeOnCompletion: false, completion: { [weak self] value in
                if value {
                    self?.contentNode.clipsToBounds = false
                }
            })
        } else {
            self.contentNode.clipsToBounds = false
        }
        
        self.statusNodeContainer.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.statusNodeContainer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateScale(from: 0.5, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    override func animateOut(to node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.contentNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.contentNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.contentNode.view.convert(self.contentNode.view.bounds, to: self.view)
        let scaledLocalImageViewBounds = self.contentNode.view.bounds
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let (maybeCopyView, copyViewBackground) = node.2()
        copyViewBackground?.alpha = 1.0
        
        let copyView = maybeCopyView!
        
        var sourceHasRoundCorners = false
        if case .none = self.sourceCorners {
        } else {
            sourceHasRoundCorners = true
        }
        
        if sourceHasRoundCorners {
            self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
        }
        copyView.frame = transformedSelfFrame
        
        let surfaceCopyView = node.2().0!
        if !sourceHasRoundCorners {
            addToTransitionSurface(surfaceCopyView)
        }
        
        var transformedSurfaceFrame: CGRect?
        var transformedSurfaceCopyViewInitialFrame: CGRect?
        if let contentSurface = surfaceCopyView.superview {
            transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
            transformedSurfaceCopyViewInitialFrame = self.contentNode.view.convert(self.contentNode.view.bounds, to: contentSurface)
        }
        
        let durationFactor = 1.0
        
        let intermediateCompletion = { [weak copyView, weak surfaceCopyView] in
            if positionCompleted && boundsCompleted && copyCompleted {
                copyView?.removeFromSuperview()
                surfaceCopyView?.removeFromSuperview()
                completion()
            }
        }
        
        if let transformedSurfaceFrame = transformedSurfaceFrame, let transformedSurfaceCopyViewInitialFrame = transformedSurfaceCopyViewInitialFrame {
            surfaceCopyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1 * durationFactor, removeOnCompletion: false)
            
            surfaceCopyView.layer.animatePosition(from: CGPoint(x: transformedSurfaceCopyViewInitialFrame.midX, y: transformedSurfaceCopyViewInitialFrame.midY), to: CGPoint(x: transformedSurfaceFrame.midX, y: transformedSurfaceFrame.midY), duration: 0.25 * durationFactor, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            let scale = CGSize(width: transformedSurfaceCopyViewInitialFrame.size.width / transformedSurfaceFrame.size.width, height: transformedSurfaceCopyViewInitialFrame.size.height / transformedSurfaceFrame.size.height)
            surfaceCopyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25 * durationFactor, removeOnCompletion: false, completion: { _ in
                intermediateCompletion()
            })
        }
        
        copyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1 * durationFactor, removeOnCompletion: false)
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25 * durationFactor, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25 * durationFactor, removeOnCompletion: false, completion: { _ in
            copyCompleted = true
            intermediateCompletion()
        })
        
        if let _ = self.videoNode {
            self.contentNode.view.superview?.bringSubviewToFront(self.contentNode.view)
        } else {
            self.contentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25 * durationFactor, removeOnCompletion: false)
        }
        
        self.contentNode.layer.animatePosition(from: self.contentNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25 * durationFactor, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(self.contentNode.layer.transform, transformedFrame.size.width / self.contentNode.layer.bounds.size.width, transformedFrame.size.height / self.contentNode.layer.bounds.size.height, 1.0)
        self.contentNode.layer.animate(from: NSValue(caTransform3D: self.contentNode.layer.transform), to: NSValue(caTransform3D: transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25 * durationFactor, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        self.contentNode.clipsToBounds = true
        if case .round = self.sourceCorners {
            self.contentNode.layer.animate(from: 0.0 as NSNumber, to: (self.contentNode.frame.width / 2.0) as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.default.rawValue, duration: 0.18 * durationFactor, removeOnCompletion: false)
        } else if case let .roundRect(cornerRadius) = self.sourceCorners {
            let scale = scaledLocalImageViewBounds.width / transformedCopyViewInitialFrame.width
            let selfScale = transformedCopyViewInitialFrame.width / transformedSelfFrame.width
            self.contentNode.layer.animate(from: 0.0 as NSNumber, to: (cornerRadius * scale * selfScale) as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.default.rawValue, duration: 0.18 * durationFactor, removeOnCompletion: false)
        }
        
        self.statusNodeContainer.layer.animatePosition(from: self.statusNodeContainer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.statusNodeContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false)
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    override func rightBarButtonItems() -> Signal<[UIBarButtonItem]?, NoError> {
        return self._rightBarButtonItems.get()
    }
    
    @objc func statusPressed() {
        if let entry = self.entry, let largestSize = largestImageRepresentation(entry.representations.map({ $0.representation })), let status = self.status {
            switch status {
                case .Fetching:
                    self.context.account.postbox.mediaBox.cancelInteractiveResourceFetch(largestSize.resource)
                case .Remote:
                    let representations: [ImageRepresentationWithReference]
                    switch entry {
                        case let .topImage(topRepresentations, _, _, _, _, _):
                            representations = topRepresentations
                        case let .image(_, _, imageRepresentations, _, _, _, _, _, _, _):
                            representations = imageRepresentations
                    }
                    
                    if let largestIndex = representations.firstIndex(where: { $0.representation == largestSize }) {
                        self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, reference: representations[largestIndex].reference).start())
                    }
                default:
                    break
            }
        }
    }
    
    @objc private func editPressed() {
        self.edit?()
    }
    
    override func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((self.footerContentNode, nil))
    }
}
