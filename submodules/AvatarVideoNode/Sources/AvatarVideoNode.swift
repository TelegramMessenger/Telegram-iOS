import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import UniversalMediaPlayer
import TelegramUniversalVideoContent
import Postbox
import TelegramCore
import AccountContext
import ComponentFlow
import GradientBackground
import AnimationCache
import MultiAnimationRenderer
import EntityKeyboard

private let maxVideoLoopCount = 3

public final class AvatarVideoNode: ASDisplayNode {
    private let context: AccountContext
    
    private var backgroundNode: ASImageNode
    
    private var emojiMarkup: TelegramMediaImage.EmojiMarkup?
    
    private var fileDisposable: Disposable?
    private var animationFile: TelegramMediaFile?
    private var itemLayer: EmojiPagerContentComponent.View.ItemLayer?
    
    private var videoNode: UniversalVideoNode?
    private var videoContent: NativeVideoContent?
    private let playbackStartDisposable = MetaDisposable()
    private var videoLoopCount = 0
    
    private var size = CGSize(width: 60.0, height: 60.0)
    
    public init(context: AccountContext) {
        self.context = context
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.backgroundNode)
    }
    
    deinit {
        self.fileDisposable?.dispose()
        self.playbackStartDisposable.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .circular
        }
    }
    
    private func setupAnimation() {
        guard let animationFile = self.animationFile else {
            return
        }
        
        let itemNativeFitSize = CGSize(width: 128.0, height: 128.0)
        
        let size = CGSize(width: self.size.width * 0.67, height: self.size.height * 0.67)
        let itemFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((self.size.width - size.width) / 2.0), y: floorToScreenPixels((self.size.height - size.height) / 2.0)), size: size)
        
        let animationData = EntityKeyboardAnimationData(file: animationFile)
        let itemLayer = EmojiPagerContentComponent.View.ItemLayer(
            item: EmojiPagerContentComponent.Item(
                animationData: animationData,
                content: .animation(animationData),
                itemFile: animationFile,
                subgroupId: nil,
                icon: .none,
                tintMode: animationData.isTemplate ? .primary : .none
            ),
            context: context,
            attemptSynchronousLoad: false,
            content: .animation(animationData),
            cache: context.animationCache,
            renderer: context.animationRenderer,
            placeholderColor: .clear,
            blurredBadgeColor: .clear,
            accentIconColor: .white,
            pointSize: itemNativeFitSize,
            onUpdateDisplayPlaceholder: { displayPlaceholder, _ in
                if !displayPlaceholder {
                    print()
                }
//                guard let strongSelf = self else {
//                    return
//                }
//                if displayPlaceholder {
//                    if let itemLayer = strongSelf.visibleItemLayers[itemId] {
//                        let placeholderView: EmojiPagerContentComponent.View.ItemPlaceholderView
//                        if let current = strongSelf.visibleItemPlaceholderViews[itemId] {
//                            placeholderView = current
//                        } else {
//                            placeholderView = EmojiPagerContentComponent.View.ItemPlaceholderView(
//                                context: context,
//                                dimensions: item.file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0),
//                                immediateThumbnailData: item.file.immediateThumbnailData,
//                                shimmerView: nil,//strongSelf.shimmerHostView,
//                                color: theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.08),
//                                size: itemNativeFitSize
//                            )
//                            strongSelf.visibleItemPlaceholderViews[itemId] = placeholderView
//                            strongSelf.view.insertSubview(placeholderView, at: 0)
//                        }
//                        placeholderView.frame = itemLayer.frame
//                        placeholderView.update(size: placeholderView.bounds.size)
//
//                        strongSelf.updateShimmerIfNeeded()
//                    }
//                } else {
//                    if let placeholderView = strongSelf.visibleItemPlaceholderViews[itemId] {
//                        strongSelf.visibleItemPlaceholderViews.removeValue(forKey: itemId)
//
//                        if duration > 0.0 {
//                            placeholderView.layer.opacity = 0.0
//                            placeholderView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, completion: { [weak self, weak placeholderView] _ in
//                                guard let strongSelf = self else {
//                                    return
//                                }
//                                placeholderView?.removeFromSuperview()
//                                strongSelf.updateShimmerIfNeeded()
//                            })
//                        } else {
//                            placeholderView.removeFromSuperview()
//                            strongSelf.updateShimmerIfNeeded()
//                        }
//                    }
//                }
            }
        )
        itemLayer.onContentsUpdate = { [weak self] in
            self?.backgroundNode.isHidden = false
        }
        itemLayer.layerTintColor = UIColor.white.cgColor
        itemLayer.frame = itemFrame
        itemLayer.isVisibleForAnimations = true
        self.itemLayer = itemLayer
        self.backgroundNode.layer.addSublayer(itemLayer)
    }
    
    public func update(peer: EnginePeer, photo: TelegramMediaImage, size: CGSize) {
        self.size = size
        if let markup = photo.emojiMarkup {
            if markup != self.emojiMarkup {
                self.emojiMarkup = markup
                
                let colors = markup.backgroundColors.map { UInt32(bitPattern: $0) }
                let backgroundImage: UIImage
                if colors.count == 1 {
                    backgroundImage = generateSingleColorImage(size: size, color: UIColor(rgb: colors.first!))!
                } else if colors.count == 2 {
                    backgroundImage = generateGradientImage(size: size, colors: colors.map { UIColor(rgb: $0) }, locations: [0.0, 1.0])!
                } else {
                    backgroundImage = GradientBackgroundNode.generatePreview(size: size, colors: colors.map { UIColor(rgb: $0) })
                }
                self.backgroundNode.image = backgroundImage
                self.backgroundNode.isHidden = true
                
                switch markup.content {
                case let .emoji(fileId):
                    self.fileDisposable = (self.context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                    |> deliverOnMainQueue).start(next: { [weak self] files in
                        if let strongSelf = self, let file = files.values.first {
                            strongSelf.animationFile = file
                            strongSelf.setupAnimation()
                        }
                    })
                case let .sticker(packReference, fileId):
                    self.fileDisposable = (self.context.engine.stickers.loadedStickerPack(reference: packReference, forceActualized: false)
                    |> map { pack -> TelegramMediaFile? in
                        if case let .result(_, items, _) = pack, let item = items.first(where: { $0.file.fileId.id == fileId }) {
                            return item.file
                        }
                        return nil
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] file in
                        if let strongSelf = self, let file {
                            strongSelf.animationFile = file
                            strongSelf.setupAnimation()
                        }
                    })
                }
            }
        } else if let video = smallestVideoRepresentation(photo.videoRepresentations), let peerReference = PeerReference(peer._asPeer()) {
            self.backgroundNode.image = nil
            
            let videoId = photo.id?.id ?? peer.id.id._internalGetInt64Value()
            let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: photo.representations, videoThumbnails: [], immediateThumbnailData: photo.immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.dimensions, flags: [])]))
            let videoContent = NativeVideoContent(id: .profileVideo(videoId, nil), userLocation: .other, fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true, startTimestamp: video.startTimestamp, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear, captureProtected: false, storeAfterDownload: nil)
            if videoContent.id != self.videoContent?.id {
                self.videoNode?.removeFromSupernode()
                self.videoContent = videoContent
            }
        }
    }
    
    public func updateVisibility(_ isVisible: Bool) {
        if isVisible, let videoContent = self.videoContent, self.videoLoopCount != maxVideoLoopCount {
            if self.videoNode == nil {
                let context = self.context
                let mediaManager = context.sharedContext.mediaManager
                let videoNode = UniversalVideoNode(postbox: context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: VideoDecoration(), content: videoContent, priority: .embedded)
                videoNode.clipsToBounds = true
                videoNode.isUserInteractionEnabled = false
                videoNode.isHidden = true
                videoNode.playbackCompleted = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.videoLoopCount += 1
                        if strongSelf.videoLoopCount == maxVideoLoopCount {
                            if let videoNode = strongSelf.videoNode {
                                strongSelf.videoNode = nil
                                videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak videoNode] _ in
                                    videoNode?.removeFromSupernode()
                                })
                            }
                        }
                    }
                }
                
                if let _ = videoContent.startTimestamp {
                    self.playbackStartDisposable.set((videoNode.status
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
                            Queue.mainQueue().after(0.15) {
                                strongSelf.videoNode?.isHidden = false
                            }
                        }
                    }))
                } else {
                    self.playbackStartDisposable.set(nil)
                    videoNode.isHidden = false
                }
                videoNode.canAttachContent = true
                videoNode.play()
                
                self.addSubnode(videoNode)
                self.videoNode = videoNode
            }
        } else if let videoNode = self.videoNode {
            self.videoNode = nil
            videoNode.removeFromSupernode()
        }
    }
    
    public func updateLayout(size: CGSize, cornerRadius: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layer.cornerRadius = cornerRadius
        
        self.backgroundNode.frame = CGRect(origin: .zero, size: size)
        
        if let videoNode = self.videoNode {
            videoNode.frame = CGRect(origin: .zero, size: size)
            videoNode.updateLayout(size: size, transition: transition)
        }
    }
    
    public func resetPlayback() {
        self.videoLoopCount = 0
    }
}

private final class VideoDecoration: UniversalVideoDecoration {
    public let backgroundNode: ASDisplayNode? = nil
    public let contentContainerNode: ASDisplayNode
    public let foregroundNode: ASDisplayNode? = nil
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    
    private var validLayoutSize: CGSize?
    
    public init() {
        self.contentContainerNode = ASDisplayNode()
    }
    
    public func updateContentNode(_ contentNode: (UniversalVideoContentNode & ASDisplayNode)?) {
        if self.contentNode !== contentNode {
            let previous = self.contentNode
            self.contentNode = contentNode
            
            if let previous = previous {
                if previous.supernode === self.contentContainerNode {
                    previous.removeFromSupernode()
                }
            }
            
            if let contentNode = contentNode {
                if contentNode.supernode !== self.contentContainerNode {
                    self.contentContainerNode.addSubnode(contentNode)
                    if let validLayoutSize = self.validLayoutSize {
                        contentNode.frame = CGRect(origin: CGPoint(), size: validLayoutSize)
                        contentNode.updateLayout(size: validLayoutSize, transition: .immediate)
                    }
                }
            }
        }
    }
    
    public func updateCorners(_ corners: ImageCorners) {
        self.contentContainerNode.clipsToBounds = true
        if isRoundEqualCorners(corners) {
            self.contentContainerNode.cornerRadius = corners.topLeft.radius
        } else {
            let boundingSize: CGSize = CGSize(width: max(corners.topLeft.radius, corners.bottomLeft.radius) + max(corners.topRight.radius, corners.bottomRight.radius), height: max(corners.topLeft.radius, corners.topRight.radius) + max(corners.bottomLeft.radius, corners.bottomRight.radius))
            let size: CGSize = CGSize(width: boundingSize.width + corners.extendedEdges.left + corners.extendedEdges.right, height: boundingSize.height + corners.extendedEdges.top + corners.extendedEdges.bottom)
            let arguments = TransformImageArguments(corners: corners, imageSize: size, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets())
            guard let context = DrawingContext(size: size, clear: true) else {
                return
            }
            context.withContext { ctx in
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fill(arguments.drawingRect)
            }
            addCorners(context, arguments: arguments)
            
            if let maskImage = context.generateImage() {
                let mask = CALayer()
                mask.contents = maskImage.cgImage
                mask.contentsScale = maskImage.scale
                mask.contentsCenter = CGRect(x: max(corners.topLeft.radius, corners.bottomLeft.radius) / maskImage.size.width, y: max(corners.topLeft.radius, corners.topRight.radius) / maskImage.size.height, width: (maskImage.size.width - max(corners.topLeft.radius, corners.bottomLeft.radius) - max(corners.topRight.radius, corners.bottomRight.radius)) / maskImage.size.width, height: (maskImage.size.height - max(corners.topLeft.radius, corners.topRight.radius) - max(corners.bottomLeft.radius, corners.bottomRight.radius)) / maskImage.size.height)
                
                self.contentContainerNode.layer.mask = mask
                self.contentContainerNode.layer.mask?.frame = self.contentContainerNode.bounds
            }
        }
    }
    
    public func updateClippingFrame(_ frame: CGRect, completion: (() -> Void)?) {
        self.contentContainerNode.layer.animate(from: NSValue(cgRect: self.contentContainerNode.bounds), to: NSValue(cgRect: frame), keyPath: "bounds", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
        })

        if let maskLayer = self.contentContainerNode.layer.mask {
            maskLayer.animate(from: NSValue(cgRect: self.contentContainerNode.bounds), to: NSValue(cgRect: frame), keyPath: "bounds", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            })
            
            maskLayer.animate(from: NSValue(cgPoint: maskLayer.position), to: NSValue(cgPoint: frame.center), keyPath: "position", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            })
        }
        
        if let contentNode = self.contentNode {
            contentNode.layer.animate(from: NSValue(cgPoint: contentNode.layer.position), to: NSValue(cgPoint: frame.center), keyPath: "position", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
                completion?()
            })
        }
    }
    
    public func updateContentNodeSnapshot(_ snapshot: UIView?) {
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayoutSize = size
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        if let backgroundNode = self.backgroundNode {
            transition.updateFrame(node: backgroundNode, frame: bounds)
        }
        if let foregroundNode = self.foregroundNode {
            transition.updateFrame(node: foregroundNode, frame: bounds)
        }
        transition.updateFrame(node: self.contentContainerNode, frame: bounds)
        if let maskLayer = self.contentContainerNode.layer.mask {
            transition.updateFrame(layer: maskLayer, frame: bounds)
        }
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(), size: size))
            contentNode.updateLayout(size: size, transition: transition)
        }
    }
    
    public func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
    }
    
    public func tap() {
    }
}
