import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Display
import Postbox

enum UniversalVideoGalleryItemContentInfo {
    case message(Message)
    case webPage(TelegramMediaWebpage, TelegramMediaFile)
}

class UniversalVideoGalleryItem: GalleryItem {
    let account: Account
    let presentationData: PresentationData
    let content: UniversalVideoContent
    let originData: GalleryItemOriginData?
    let indexData: GalleryItemIndexData?
    let contentInfo: UniversalVideoGalleryItemContentInfo?
    let caption: String
    let hideControls: Bool
    let playbackCompleted: () -> Void
    
    init(account: Account, presentationData: PresentationData, content: UniversalVideoContent, originData: GalleryItemOriginData?, indexData: GalleryItemIndexData?, contentInfo: UniversalVideoGalleryItemContentInfo?, caption: String, hideControls: Bool = false, playbackCompleted: @escaping () -> Void = {}) {
        self.account = account
        self.presentationData = presentationData
        self.content = content
        self.originData = originData
        self.indexData = indexData
        self.contentInfo = contentInfo
        self.caption = caption
        self.hideControls = hideControls
        self.playbackCompleted = playbackCompleted
    }
    
    func node() -> GalleryItemNode {
        let node = UniversalVideoGalleryItemNode(account: self.account, presentationData: self.presentationData)
        
        if let indexData = self.indexData {
            node._title.set(.single("\(indexData.position + 1) \(self.presentationData.strings.Common_of) \(indexData.totalCount)"))
        }
        
        node.setupItem(self)
        
        return node
    }
    
    func updateNode(node: GalleryItemNode) {
        if let node = node as? UniversalVideoGalleryItemNode {
            if let indexData = self.indexData {
                node._title.set(.single("\(indexData.position + 1) \(self.presentationData.strings.Common_of) \(indexData.totalCount)"))
            }
            
            node.setupItem(self)
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        guard let contentInfo = self.contentInfo else {
            return nil
        }
        if case let .message(message) = contentInfo {
            if let id = message.groupInfo?.stableId {
                var mediaReference: AnyMediaReference?
                for m in message.media {
                    if let m = m as? TelegramMediaImage {
                        mediaReference = .message(message: MessageReference(message), media: m)
                    } else if let m = m as? TelegramMediaFile, m.isVideo {
                        mediaReference = .message(message: MessageReference(message), media: m)
                    }
                }
                if let mediaReference = mediaReference {
                    if let item = ChatMediaGalleryThumbnailItem(account: self.account, mediaReference: mediaReference) {
                        return (Int64(id), item)
                    }
                }
            }
        } else if case let .webPage(webPage, file) = contentInfo {
            if let item = ChatMediaGalleryThumbnailItem(account: self.account, mediaReference: .webPage(webPage: WebpageReference(webPage), media: file)) {
                return (0, item)
            }
        }
        return nil
    }
}

private let pictureInPictureImage = UIImage(bundleImageName: "Media Gallery/PictureInPictureIcon")?.precomposed()
private let pictureInPictureButtonImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/PictureInPictureButton"), color: .white)
private let placeholderFont = Font.regular(16.0)

private final class UniversalVideoGalleryItemPictureInPictureNode: ASDisplayNode {
    private let iconNode: ASImageNode
    private let textNode: ASTextNode
    
    init(strings: PresentationStrings) {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = pictureInPictureImage
        
        self.textNode = ASTextNode()
        self.textNode.isLayerBacked = true
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: strings.Embed_PlayingInPIP, font: placeholderFont, textColor: UIColor(rgb: 0x8e8e93))
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
    }
    
    func updateLayout(_ size: CGSize, transition: ContainedViewLayoutTransition) {
        let iconSize = self.iconNode.image?.size ?? CGSize()
        let textSize = self.textNode.measure(CGSize(width: size.width - 20.0, height: CGFloat.greatestFiniteMagnitude))
        let spacing: CGFloat = 10.0
        let contentHeight = iconSize.height + spacing + textSize.height
        let contentVerticalOrigin = floor((size.height - contentHeight) / 2.0)
        transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: contentVerticalOrigin), size: iconSize))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: contentVerticalOrigin + iconSize.height + spacing), size: textSize))
    }
}

final class UniversalVideoGalleryItemNode: ZoomableContentGalleryItemNode {
    private let account: Account
    private let strings: PresentationStrings
    
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    fileprivate let _titleView = Promise<UIView?>()
    fileprivate let _rightBarButtonItem = Promise<UIBarButtonItem?>()
    
    private let scrubberView: ChatVideoGalleryItemScrubberView
    private let footerContentNode: ChatItemGalleryFooterContentNode
    
    private var videoNode: UniversalVideoNode?
    private var pictureInPictureNode: UniversalVideoGalleryItemPictureInPictureNode?
    private let statusButtonNode: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    
    private var isCentral = false
    private var validLayout: (ContainerViewLayout, CGFloat)?
    private var didPause = false
    private var isPaused = true
    
    private var item: UniversalVideoGalleryItem?
    
    private let statusDisposable = MetaDisposable()
    
    var playbackCompleted: (() -> Void)?
    
    init(account: Account, presentationData: PresentationData) {
        self.account = account
        self.strings = presentationData.strings
        self.scrubberView = ChatVideoGalleryItemScrubberView()
        
        self.footerContentNode = ChatItemGalleryFooterContentNode(account: account, presentationData: presentationData)
        self.footerContentNode.scrubberView = self.scrubberView
        
        self.statusButtonNode = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        
        self._title.set(.single(""))
        self._titleView.set(.single(nil))
        
        super.init()
        
        self.scrubberView.seek = { [weak self] timestamp in
            self?.videoNode?.seek(timestamp)
        }
        
        self.statusButtonNode.addSubnode(self.statusNode)
        self.statusButtonNode.addTarget(self, action: #selector(statusButtonPressed), forControlEvents: .touchUpInside)
        
        self.addSubnode(self.statusButtonNode)
        
        self.footerContentNode.playbackControl = { [weak self] in
            if let strongSelf = self {
                if !strongSelf.isPaused {
                    strongSelf.didPause = true
                }
                strongSelf.videoNode?.togglePlayPause()
            }
        }
        self.footerContentNode.seekBackward = { [weak self] in
            if let strongSelf = self, let videoNode = strongSelf.videoNode {
                let _ = (videoNode.status |> take(1)).start(next: { [weak videoNode] status in
                    if let strongVideoNode = videoNode, let timestamp = status?.timestamp {
                        strongVideoNode.seek(max(0.0, timestamp - 15.0))
                    }
                })
            }
        }
        self.footerContentNode.seekForward = { [weak self] in
            if let strongSelf = self, let videoNode = strongSelf.videoNode {
                let _ = (videoNode.status |> take(1)).start(next: { [weak videoNode] status in
                    if let strongVideoNode = videoNode, let timestamp = status?.timestamp, let duration = status?.duration {
                        strongVideoNode.seek(min(duration, timestamp + 15.0))
                    }
                })
            }
        }
    }
    
    deinit {
        self.statusDisposable.dispose()
    }
    
    override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        self.validLayout = (layout, navigationBarHeight)
        
        let statusDiameter: CGFloat = 50.0
        let statusFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusDiameter) / 2.0), y: floor((layout.size.height - statusDiameter) / 2.0)), size: CGSize(width: statusDiameter, height: statusDiameter))
        transition.updateFrame(node: self.statusButtonNode, frame: statusFrame)
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(), size: statusFrame.size))
        
        if let pictureInPictureNode = self.pictureInPictureNode {
            if let item = self.item {
                let placeholderSize = item.content.dimensions.fitted(layout.size)
                transition.updateFrame(node: pictureInPictureNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - placeholderSize.width) / 2.0), y: floor((layout.size.height - placeholderSize.height) / 2.0)), size: placeholderSize))
                pictureInPictureNode.updateLayout(placeholderSize, transition: transition)
            }
        }
    }
    
    func setupItem(_ item: UniversalVideoGalleryItem) {
        if self.item?.content.id != item.content.id {
            if item.hideControls {
                self.statusButtonNode.isHidden = true
            }
            
            var disablePlayerControls = false
            var isAnimated = false
            if let content = item.content as? NativeVideoContent {
                isAnimated = content.fileReference.media.isAnimated
            } else if let _ = item.content as? SystemVideoContent {
                self._title.set(.single(item.presentationData.strings.Message_Video))
            } else if let content = item.content as? WebEmbedVideoContent, case .iframe = webEmbedType(content: content.webpageContent) {
                disablePlayerControls = true
            }
            
            if let videoNode = self.videoNode {
                videoNode.canAttachContent = false
                videoNode.removeFromSupernode()
            }
            
            if isAnimated || disablePlayerControls {
                self.footerContentNode.scrubberView = nil
            }
            
            guard let mediaManager = item.account.telegramApplicationContext.mediaManager else {
                preconditionFailure()
            }
            
            let videoNode = UniversalVideoNode(postbox: item.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: item.content, priority: .gallery)
            let videoSize = CGSize(width: item.content.dimensions.width * 2.0, height: item.content.dimensions.height * 2.0)
            videoNode.updateLayout(size: videoSize, transition: .immediate)
            videoNode.ownsContentNodeUpdated = { [weak self] value in
                if let strongSelf = self {
                    strongSelf.updateDisplayPlaceholder(!value)
                }
            }
            self.videoNode = videoNode
            videoNode.isUserInteractionEnabled = disablePlayerControls
            videoNode.backgroundColor = videoNode.ownsContentNode ? UIColor.black : UIColor(rgb: 0x333335)
            videoNode.canAttachContent = true
            self.updateDisplayPlaceholder(!videoNode.ownsContentNode)
            
            self.scrubberView.setStatusSignal(videoNode.status |> map { value -> MediaPlayerStatus in
                if let value = value, !value.duration.isZero {
                    return value
                } else {
                    return MediaPlayerStatus(generationTimestamp: 0.0, duration: max(Double(item.content.duration), 0.01), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused)
                }
            })
            
            self.scrubberView.setBufferingStatusSignal(videoNode.bufferingStatus)
            
            self.statusDisposable.set((videoNode.status |> deliverOnMainQueue).start(next: { [weak self] value in
                if let strongSelf = self {
                    var initialBuffering = false
                    var buffering = false
                    var isPaused = true
                    var seekable = false
                    var hasStarted = false
                    if let value = value {
                        hasStarted = value.timestamp > 0
                        
                        if let zoomableContent = strongSelf.zoomableContent, !value.dimensions.width.isZero && !value.dimensions.height.isZero {
                            let videoSize = CGSize(width: value.dimensions.width * 2.0, height: value.dimensions.height * 2.0)
                            if !zoomableContent.0.equalTo(videoSize) {
                                strongSelf.zoomableContent = (videoSize, zoomableContent.1)
                                strongSelf.videoNode?.updateLayout(size: videoSize, transition: .immediate)
                            }
                        }
                        switch value.status {
                            case .playing:
                                isPaused = false
                            case let .buffering(_, whilePlaying):
                                initialBuffering = true
                                buffering = true
                                isPaused = !whilePlaying
                                if let content = item.content as? NativeVideoContent, !content.streamVideo {
                                    initialBuffering = false
                                    if !content.enableSound {
                                        isPaused = false
                                    }
                                }
                            default:
                                if let content = item.content as? NativeVideoContent, !content.streamVideo {
                                    if !content.enableSound {
                                        isPaused = false
                                    }
                                }
                        }
                        seekable = value.duration >= 45.0
                    }
                    
                    if initialBuffering {
                        strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: nil, cancelEnabled: false), animated: false, completion: {})
                    } else {
                        strongSelf.statusNode.transitionToState(.play(.white), animated: false, completion: {})
                    }
                    
                    strongSelf.isPaused = isPaused
                    
                    if !item.hideControls {
                        strongSelf.statusButtonNode.isHidden = !initialBuffering && (strongSelf.didPause || !isPaused || value == nil)
                    }
                    
                    if isAnimated || disablePlayerControls {
                        strongSelf.footerContentNode.content = .info
                    }
                    else if isPaused {
                        if hasStarted || strongSelf.didPause || buffering {
                            strongSelf.footerContentNode.content = .playback(paused: true, seekable: seekable)
                        } else {
                            strongSelf.footerContentNode.content = .info
                        }
                    } else {
                        strongSelf.footerContentNode.content = .playback(paused: false, seekable: seekable)
                    }
                }
            }))
            
            self.zoomableContent = (videoSize, videoNode)
            
            if !isAnimated && !disablePlayerControls {
                let rightBarButtonItem = UIBarButtonItem(image: pictureInPictureButtonImage, style: .plain, target: self, action: #selector(self.pictureInPictureButtonPressed))
                self._rightBarButtonItem.set(.single(rightBarButtonItem))
            }
            
            videoNode.playbackCompleted = { [weak videoNode] in
                Queue.mainQueue().async {
                    item.playbackCompleted()
                    if !isAnimated {
                        videoNode?.seek(0.0)
                    }
                }
            }
            
            self._ready.set(videoNode.ready)
        }
        
        self.item = item
        
        if let contentInfo = item.contentInfo {
            switch contentInfo {
                case let .message(message):
                    self.footerContentNode.setMessage(message)
                case .webPage:
                    break
            }
        }
        self.footerContentNode.setup(origin: item.originData, caption: item.caption)
    }
    
    private func updateDisplayPlaceholder(_ displayPlaceholder: Bool) {
        if displayPlaceholder {
            if self.pictureInPictureNode == nil {
                let pictureInPictureNode = UniversalVideoGalleryItemPictureInPictureNode(strings: self.strings)
                pictureInPictureNode.isUserInteractionEnabled = false
                self.pictureInPictureNode = pictureInPictureNode
                self.insertSubnode(pictureInPictureNode, aboveSubnode: self.scrollNode)
                if let validLayout = self.validLayout {
                    if let item = self.item {
                        let placeholderSize = item.content.dimensions.fitted(validLayout.0.size)
                        pictureInPictureNode.frame = CGRect(origin: CGPoint(x: floor((validLayout.0.size.width - placeholderSize.width) / 2.0), y: floor((validLayout.0.size.height - placeholderSize.height) / 2.0)), size: placeholderSize)
                        pictureInPictureNode.updateLayout(placeholderSize, transition: .immediate)
                    }
                }
                self.videoNode?.backgroundColor = UIColor(rgb: 0x333335)
            }
        } else if let pictureInPictureNode = self.pictureInPictureNode {
            self.pictureInPictureNode = nil
            pictureInPictureNode.removeFromSupernode()
            self.videoNode?.backgroundColor = .black
        }
    }
    
    override func centralityUpdated(isCentral: Bool) {
        super.centralityUpdated(isCentral: isCentral)
        
        if self.isCentral != isCentral {
            self.isCentral = isCentral
            
            if let videoNode = self.videoNode {
                if isCentral {
                    //videoNode.canAttachContent = true
                } else if videoNode.ownsContentNode {
                    videoNode.pause()
                }
            }
        }
    }
    
    override func activateAsInitial() {
        if self.isCentral {
            self.videoNode?.play()
        }
    }
    
    override func animateIn(from node: (ASDisplayNode, () -> UIView?), addToTransitionSurface: (UIView) -> Void) {
        guard let videoNode = self.videoNode else {
            return
        }
        
        if let node = node.0 as? OverlayMediaItemNode {
            var transformedFrame = node.view.convert(node.view.bounds, to: videoNode.view)
            let transformedSuperFrame = node.view.convert(node.view.bounds, to: videoNode.view.superview)
            
            videoNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: videoNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            
            transformedFrame.origin = CGPoint()
            
            let transform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
            videoNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: videoNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
            
            self.account.telegramApplicationContext.mediaManager?.setOverlayVideoNode(nil)
        } else {
            var transformedFrame = node.0.view.convert(node.0.view.bounds, to: videoNode.view)
            let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: videoNode.view.superview)
            let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
            let transformedCopyViewFinalFrame = videoNode.view.convert(videoNode.view.bounds, to: self.view)
            
            let surfaceCopyView = node.1()!
            let copyView = node.1()!
            
            addToTransitionSurface(surfaceCopyView)
            
            var transformedSurfaceFrame: CGRect?
            var transformedSurfaceFinalFrame: CGRect?
            if let contentSurface = surfaceCopyView.superview {
                transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
                transformedSurfaceFinalFrame = videoNode.view.convert(videoNode.view.bounds, to: contentSurface)
            }
            
            if let transformedSurfaceFrame = transformedSurfaceFrame {
                surfaceCopyView.frame = transformedSurfaceFrame
            }
            
            self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
            copyView.frame = transformedSelfFrame
            
            copyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, removeOnCompletion: false)
            
            surfaceCopyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            
            copyView.layer.animatePosition(from: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), to: CGPoint(x: transformedCopyViewFinalFrame.midX, y: transformedCopyViewFinalFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak copyView] _ in
                copyView?.removeFromSuperview()
            })
            let scale = CGSize(width: transformedCopyViewFinalFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewFinalFrame.size.height / transformedSelfFrame.size.height)
            copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
            
            if let transformedSurfaceFrame = transformedSurfaceFrame, let transformedSurfaceFinalFrame = transformedSurfaceFinalFrame {
                surfaceCopyView.layer.animatePosition(from: CGPoint(x: transformedSurfaceFrame.midX, y: transformedSurfaceFrame.midY), to: CGPoint(x: transformedCopyViewFinalFrame.midX, y: transformedCopyViewFinalFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak surfaceCopyView] _ in
                    surfaceCopyView?.removeFromSuperview()
                })
                let scale = CGSize(width: transformedSurfaceFinalFrame.size.width / transformedSurfaceFrame.size.width, height: transformedSurfaceFinalFrame.size.height / transformedSurfaceFrame.size.height)
                surfaceCopyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
            }
            
            videoNode.allowsGroupOpacity = true
            videoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, completion: { [weak videoNode] _ in
                videoNode?.allowsGroupOpacity = false
            })
            videoNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: videoNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            
            transformedFrame.origin = CGPoint()
            
            let transform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
            videoNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: videoNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
            
            if let pictureInPictureNode = self.pictureInPictureNode {
                let transformedPlaceholderFrame = node.0.view.convert(node.0.view.bounds, to: pictureInPictureNode.view)
                let transform = CATransform3DScale(pictureInPictureNode.layer.transform, transformedPlaceholderFrame.size.width / pictureInPictureNode.layer.bounds.size.width, transformedPlaceholderFrame.size.height / pictureInPictureNode.layer.bounds.size.height, 1.0)
                pictureInPictureNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: pictureInPictureNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
                
                pictureInPictureNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                pictureInPictureNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: pictureInPictureNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            }
            
            self.statusButtonNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.statusButtonNode.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            self.statusButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            self.statusButtonNode.layer.animateScale(from: 0.5, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    override func animateOut(to node: (ASDisplayNode, () -> UIView?), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        guard let videoNode = self.videoNode else {
            completion()
            return
        }
        
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: videoNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: videoNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = videoNode.view.convert(videoNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let copyView = node.1()!
        let surfaceCopyView = node.1()!
        
        addToTransitionSurface(surfaceCopyView)
        
        var transformedSurfaceFrame: CGRect?
        var transformedSurfaceCopyViewInitialFrame: CGRect?
        if let contentSurface = surfaceCopyView.superview {
            transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
            transformedSurfaceCopyViewInitialFrame = videoNode.view.convert(videoNode.view.bounds, to: contentSurface)
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
        
        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false)
        surfaceCopyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, removeOnCompletion: false)
        
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
        
        videoNode.layer.animatePosition(from: videoNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        videoNode.allowsGroupOpacity = true
        videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak videoNode] _ in
            videoNode?.allowsGroupOpacity = false
        })
        
        self.statusButtonNode.layer.animatePosition(from: self.statusButtonNode.layer.position, to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            //positionCompleted = true
            //intermediateCompletion()
        })
        self.statusButtonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.statusButtonNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.25, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
        videoNode.layer.animate(from: NSValue(caTransform3D: videoNode.layer.transform), to: NSValue(caTransform3D: transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        if let pictureInPictureNode = self.pictureInPictureNode {
            let transformedPlaceholderFrame = node.0.view.convert(node.0.view.bounds, to: pictureInPictureNode.view)
            let pictureInPictureTransform = CATransform3DScale(pictureInPictureNode.layer.transform, transformedPlaceholderFrame.size.width / pictureInPictureNode.layer.bounds.size.width, transformedPlaceholderFrame.size.height / pictureInPictureNode.layer.bounds.size.height, 1.0)
            pictureInPictureNode.layer.animate(from: NSValue(caTransform3D: pictureInPictureNode.layer.transform), to: NSValue(caTransform3D: pictureInPictureTransform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            })
            
            pictureInPictureNode.layer.animatePosition(from: pictureInPictureNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                positionCompleted = true
                intermediateCompletion()
            })
            pictureInPictureNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    func animateOut(toOverlay node: ASDisplayNode, completion: @escaping () -> Void) {
        guard let videoNode = self.videoNode else {
            completion()
            return
        }
        
        var transformedFrame = node.view.convert(node.view.bounds, to: videoNode.view)
        let transformedSuperFrame = node.view.convert(node.view.bounds, to: videoNode.view.superview)
        let transformedSelfFrame = node.view.convert(node.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = videoNode.view.convert(videoNode.view.bounds, to: self.view)
        let transformedSelfTargetSuperFrame = videoNode.view.convert(videoNode.view.bounds, to: node.view.superview)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        var nodeCompleted = false
        
        let copyView = node.view.snapshotContentTree()!
        
        videoNode.isHidden = true
        copyView.frame = transformedSelfFrame
        
        let intermediateCompletion = { [weak copyView] in
            if positionCompleted && boundsCompleted && copyCompleted && nodeCompleted {
                copyView?.removeFromSuperview()
                completion()
            }
        }
        
        copyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, removeOnCompletion: false)
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            copyCompleted = true
            intermediateCompletion()
        })
        
        videoNode.layer.animatePosition(from: videoNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        self.statusButtonNode.layer.animatePosition(from: self.statusButtonNode.layer.position, to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            //positionCompleted = true
            //intermediateCompletion()
        })
        self.statusButtonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.statusButtonNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.25, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        
        let videoTransform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
        videoNode.layer.animate(from: NSValue(caTransform3D: videoNode.layer.transform), to: NSValue(caTransform3D: videoTransform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        if let pictureInPictureNode = self.pictureInPictureNode {
            pictureInPictureNode.isHidden = true
        }
        
        let nodeTransform = CATransform3DScale(node.layer.transform, videoNode.layer.bounds.size.width / transformedFrame.size.width, videoNode.layer.bounds.size.height / transformedFrame.size.height, 1.0)
        node.layer.animatePosition(from: CGPoint(x: transformedSelfTargetSuperFrame.midX, y: transformedSelfTargetSuperFrame.midY), to: node.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        node.layer.animate(from: NSValue(caTransform3D: nodeTransform), to: NSValue(caTransform3D: node.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            nodeCompleted = true
            intermediateCompletion()
        })
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    override func titleView() -> Signal<UIView?, NoError> {
        return self._titleView.get()
    }
    
    override func rightBarButtonItem() -> Signal<UIBarButtonItem?, NoError> {
        return self._rightBarButtonItem.get()
    }
    
    @objc func statusButtonPressed() {
        if let videoNode = self.videoNode {
            videoNode.togglePlayPause()
        }
    }
    
    @objc func pictureInPictureButtonPressed() {
        if let item = self.item, let _ = self.videoNode {
            let account = self.account
            let baseNavigationController = self.baseNavigationController()
            let mediaManager = self.account.telegramApplicationContext.mediaManager!
            var expandImpl: (() -> Void)?
            let overlayNode = OverlayUniversalVideoNode(account: self.account, audioSession: self.account.telegramApplicationContext.mediaManager!.audioSession, manager: self.account.telegramApplicationContext.mediaManager!.universalVideoManager, content: item.content, expand: {
                expandImpl?()
            }, close: { [weak mediaManager] in
                mediaManager?.setOverlayVideoNode(nil)
            })
            expandImpl = { [weak overlayNode] in
                guard let contentInfo = item.contentInfo else {
                    return
                }
                
                switch contentInfo {
                    case let .message(message):
                        let gallery = GalleryController(account: account, source: .peerMessagesAtId(message.id), replaceRootController: { controller, ready in
                            if let baseNavigationController = baseNavigationController {
                                baseNavigationController.replaceTopController(controller, animated: false, ready: ready)
                            }
                        }, baseNavigationController: baseNavigationController)
                        gallery.temporaryDoNotWaitForReady = true
                        
                        baseNavigationController?.view.endEditing(true)
                        
                        (baseNavigationController?.topViewController as? ViewController)?.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(transitionArguments: { _, _ in
                            if let overlayNode = overlayNode, let overlaySupernode = overlayNode.supernode {
                                return GalleryTransitionArguments(transitionNode: (overlayNode, { [weak overlayNode] in
                                    return overlayNode?.view.snapshotContentTree()
                                }), addToTransitionSurface: { [weak overlaySupernode, weak overlayNode] view in
                                    overlaySupernode?.view.addSubview(view)
                                    overlayNode?.canAttachContent = false
                                })
                            }
                            return nil
                        }))
                    case .webPage:
                        break
                }
            }
            account.telegramApplicationContext.mediaManager?.setOverlayVideoNode(overlayNode)
            if overlayNode.supernode != nil {
                self.beginCustomDismiss()
                self.animateOut(toOverlay: overlayNode, completion: { [weak self] in
                    self?.completeCustomDismiss()
                })
            }
        }
    }
    
    override func footerContent() -> Signal<GalleryFooterContentNode?, NoError> {
        return .single(self.footerContentNode)
    }
}
