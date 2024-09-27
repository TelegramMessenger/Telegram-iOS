import Foundation
import UIKit
import AsyncDisplayKit
import AVFoundation
import Display
import SwiftSignalKit
import TelegramCore
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import StickerResources
import AccountContext
import MediaEditor
import UniversalMediaPlayer
import TelegramPresentationData
import TelegramUniversalVideoContent
import DustEffect
import DynamicCornerRadiusView

private class BlurView: UIVisualEffectView {
    private func setup() {
        for subview in self.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }
        
        if let sublayer = self.layer.sublayers?[0], let filters = sublayer.filters {
            sublayer.backgroundColor = nil
            sublayer.isOpaque = false
            let allowedKeys: [String] = [
                "gaussianBlur"
            ]
            sublayer.filters = filters.filter { filter in
                guard let filter = filter as? NSObject else {
                    return true
                }
                let filterName = String(describing: filter)
                if !allowedKeys.contains(filterName) {
                    return false
                }
                return true
            }
        }
    }
    
    override var effect: UIVisualEffect? {
        get {
            return super.effect
        }
        set {
            super.effect = newValue
            self.setup()
        }
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        self.setup()
    }
}

public class DrawingStickerEntityView: DrawingEntityView {
    var stickerEntity: DrawingStickerEntity {
        return self.entity as! DrawingStickerEntity
    }
    
    let imageNode: TransformImageNode
    var animationNode: DefaultAnimatedStickerNodeImpl?
    var videoNode: UniversalVideoNode?
    var videoMaskView: DynamicCornerRadiusView?
    var animatedImageView: UIImageView?
    var overlayImageView: UIImageView?
    var cameraPreviewView: UIView?
    
    let progressDisposable = MetaDisposable()
    let progressLayer = CAShapeLayer()
    
    var didSetUpAnimationNode = false
    private let stickerFetchedDisposable = MetaDisposable()
    private let cachedDisposable = MetaDisposable()
    
    private var isVisible = true
    var isPlaying = false
    var started: ((Double) -> Void)?
    
    var currentSize: CGSize?
    public var updated: () -> Void = {}
    
    public var duration: Double? {
        if let animationNode = self.animationNode, animationNode.currentFrameCount > 1 {
            return Double(animationNode.currentFrameCount) / Double(animationNode.currentFrameRate)
        } else if let videoNode = self.videoNode {
            return videoNode.duration
        } else {
            return nil
        }
    }
    
    init(context: AccountContext, entity: DrawingStickerEntity) {
        self.imageNode = TransformImageNode()
        
        super.init(context: context, entity: entity)
        
        self.addSubview(self.imageNode.view)
                
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
        self.cachedDisposable.dispose()
        self.progressDisposable.dispose()
    }
    
    private var file: TelegramMediaFile? {
        if case let .file(file, _) = self.stickerEntity.content {
            return file.media
        } else {
            return nil
        }
    }
    
    private var image: UIImage? {
        if case let .image(image, _) = self.stickerEntity.content {
            return image
        } else {
            return nil
        }
    }
    
    func getRenderImage() -> UIImage? {
        if case let .file(_, type) = self.stickerEntity.content, case .reaction = type {
            let rect = self.bounds
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 2.0)
            self.drawHierarchy(in: rect, afterScreenUpdates: true)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image
        } else if case .message = self.stickerEntity.content {
            return self.animatedImageView?.image
        } else {
            return nil
        }
    }
    
    private var video: TelegramMediaFile? {
        if case let .video(file) = self.stickerEntity.content {
            return file
        } else {
            return nil
        }
    }
    
    private var dimensions: CGSize {
        switch self.stickerEntity.content {
        case let .file(file, _):
            return file.media.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
        case let .image(image, _):
            return image.size
        case let .animatedImage(_, thumbnailImage):
            return thumbnailImage.size
        case let .video(file):
            return file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
        case .dualVideoReference:
            return CGSize(width: 512.0, height: 512.0)
        case let .message(_, size, _, _, _):
            return size
        }
    }
    
    private func updateAnimationColor() {
        let color: UIColor?
        if case let .file(file, type) = self.stickerEntity.content, file.media.isCustomTemplateEmoji {
            if case let .reaction(_, style) = type {
                if case .white = style {
                    color = UIColor(rgb: 0x000000)
                } else {
                    color = UIColor(rgb: 0xffffff)
                }
            } else {
                color = UIColor(rgb: 0xffffff)
            }
        } else {
            color = nil
        }
        self.animationNode?.dynamicColor = color
    }
    
    func setup() {
        if let file = self.file {
            if let dimensions = file.dimensions {
                if file.isAnimatedSticker || file.isVideoSticker || file.mimeType == "video/webm" {
                    if self.animationNode == nil {
                        let animationNode = DefaultAnimatedStickerNodeImpl()
                        animationNode.clipsToBounds = true
                        animationNode.autoplay = false
                        self.animationNode = animationNode
                        animationNode.started = { [weak self, weak animationNode] in
                            self?.imageNode.isHidden = true
                                                        
                            if let animationNode = animationNode {
                                if animationNode.currentFrameCount == 1 {
                                    self?.stickerEntity.isExplicitlyStatic = true
                                }
                                let _ = (animationNode.status
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { [weak self] status in
                                    self?.started?(status.duration)
                                })
                            }
                        }
                        self.addSubnode(animationNode)
                        
                        self.updateAnimationColor()
                        
                        if !self.stickerEntity.isAnimated {
                            self.imageNode.isHidden = true
                        }
                    }
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: self.context.account.postbox, userLocation: .other, file: file, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 256.0, height: 256.0))))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: stickerPackFileReference(file), resource: file.resource).start())
                } else {
                    if let animationNode = self.animationNode {
                        animationNode.visibility = false
                        self.animationNode = nil
                        animationNode.removeFromSupernode()
                        self.imageNode.isHidden = false
                        self.didSetUpAnimationNode = false
                    }
                    self.imageNode.isHidden = false
                    self.imageNode.setSignal(chatMessageSticker(account: self.context.account, userLocation: .other, file: file, small: false, synchronousLoad: false))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: stickerPackFileReference(file), resource: chatMessageStickerResource(file: file, small: false)).start())
                }
                self.setNeedsLayout()
            }
        } else if let image = self.image {
            func drawImageWithOrientation(_ image: UIImage, size: CGSize, in context: CGContext) {
                let imageSize: CGSize
                
                switch image.imageOrientation {
                case .left, .leftMirrored, .right, .rightMirrored:
                    imageSize = CGSize(width: size.height, height: size.width)
                default:
                    imageSize = size
                }
                
                let imageRect = CGRect(origin: .zero, size: imageSize)
                                
                switch image.imageOrientation {
                case .down, .downMirrored:
                    context.translateBy(x: imageSize.width, y: imageSize.height)
                    context.rotate(by: CGFloat.pi)
                case .left, .leftMirrored:
                    context.translateBy(x: imageSize.width, y: 0)
                    context.rotate(by: CGFloat.pi / 2)
                case .right, .rightMirrored:
                    context.translateBy(x: 0, y: imageSize.height)
                    context.rotate(by: -CGFloat.pi / 2)
                default:
                    break
                }
                
                context.draw(image.cgImage!, in: imageRect)
            }
            
            var synchronous = false
            if case let .image(_, type) = self.stickerEntity.content {
                synchronous = type == .dualPhoto
            }
            self.imageNode.setSignal(.single({ arguments -> DrawingContext? in
                let context = DrawingContext(size: arguments.drawingSize, opaque: false, clear: true)
                context?.withFlippedContext({ ctx in
                    drawImageWithOrientation(image, size: arguments.drawingSize, in: ctx)
                })
                return context
            }), attemptSynchronously: synchronous)
            self.setNeedsLayout()
        } else if case let .video(file) = self.stickerEntity.content {
            self.setupWithVideo(file)
        } else if case let .animatedImage(data, thumbnailImage) = self.stickerEntity.content {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.image = thumbnailImage
            imageView.setDrawingAnimatedImage(data: data)
            self.animatedImageView = imageView
            self.addSubview(imageView)
            self.setNeedsLayout()
        } else if case let .message(_, _, file, mediaRect, _) = self.stickerEntity.content {
            if let image = self.stickerEntity.renderImage {
                self.setupWithImage(image, overlayImage: self.stickerEntity.overlayRenderImage)
            }
            if let file, let _ = mediaRect {
                self.setupWithVideo(file)
            }
        }
    }
    
    private func setupWithImage(_ image: UIImage, overlayImage: UIImage? = nil) {
        let imageView: UIImageView
        if let current = self.animatedImageView {
            imageView = current
        } else {
            imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            self.addSubview(imageView)
            self.animatedImageView = imageView
        }
        imageView.image = image
        
        if let overlayImage {
            let imageView: UIImageView
            if let current = self.overlayImageView {
                imageView = current
            } else {
                imageView = UIImageView()
                imageView.contentMode = .scaleAspectFit
                self.addSubview(imageView)
                self.overlayImageView = imageView
            }
            imageView.image = overlayImage
        }
        
        self.currentSize = nil
        self.setNeedsLayout()
    }
    
    private func setupWithVideo(_ file: TelegramMediaFile) {
        let videoNode = UniversalVideoNode(
            accountId: self.context.account.id,
            postbox: self.context.account.postbox,
            audioSession: self.context.sharedContext.mediaManager.audioSession,
            manager: self.context.sharedContext.mediaManager.universalVideoManager,
            decoration: StickerVideoDecoration(),
            content: NativeVideoContent(
                id: .contextResult(0, "\(UInt64.random(in: 0 ... UInt64.max))"),
                userLocation: .other,
                fileReference: .standalone(media: file),
                imageReference: nil,
                streamVideo: .story,
                loopVideo: true,
                enableSound: false,
                soundMuted: true,
                beginWithAmbientSound: false,
                mixWithOthers: true,
                useLargeThumbnail: false,
                autoFetchFullSizeThumbnail: false,
                tempFilePath: nil,
                captureProtected: false,
                hintDimensions: file.dimensions?.cgSize,
                storeAfterDownload: nil,
                displayImage: false,
                hasSentFramesToDisplay: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.videoNode?.isHidden = false
                }
            ),
            priority: .gallery
        )
        videoNode.canAttachContent = true
        videoNode.isUserInteractionEnabled = false
        videoNode.clipsToBounds = true
        self.addSubnode(videoNode)
        if let overlayImageView = self.overlayImageView {
            self.addSubview(overlayImageView)
        }
        self.videoNode = videoNode
        self.setNeedsLayout()
        videoNode.play()
    }
    
    public override func play() {
        self.isVisible = true
        self.applyVisibility()
        
        self.videoNode?.play()
    }
    
    public override func pause() {
        self.isVisible = false
        self.applyVisibility()
        
        self.videoNode?.pause()
    }
    
    public override func seek(to timestamp: Double) {
        self.isVisible = false
        self.isPlaying = false
        self.animationNode?.seekTo(.timestamp(timestamp))
        
        self.videoNode?.seek(timestamp)
    }
    
    override func resetToStart() {
        self.isVisible = false
        self.isPlaying = false
        self.animationNode?.seekTo(.timestamp(0.0))
    }
    
    override func updateVisibility(_ visibility: Bool) {
        self.isVisible = visibility
        self.applyVisibility()
    }
    
    public var isNightTheme = false {
        didSet {
            self.animatedImageView?.image = self.isNightTheme ? self.stickerEntity.secondaryRenderImage : self.stickerEntity.renderImage
        }
    }
    
    func applyVisibility() {
        let isPlaying = self.isVisible
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            
            if let file = self.file {
                if isPlaying && !self.didSetUpAnimationNode {
                    self.didSetUpAnimationNode = true
                    let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0))
                    let source = AnimatedStickerResourceSource(account: self.context.account, resource: file.resource, isVideo: file.isVideoSticker || file.mimeType == "video/webm")
                    let pathPrefix = self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                    let playbackMode: AnimatedStickerPlaybackMode = .loop
                    self.animationNode?.setup(source: source, width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: playbackMode, mode: .direct(cachePathPrefix: pathPrefix))
                    
                    self.cachedDisposable.set((source.cachedDataPath(width: 384, height: 384)
                    |> deliverOn(Queue.concurrentDefaultQueue())).start())
                }
            }
            self.animationNode?.visibility = isPlaying
            if isPlaying {
                self.animationNode?.play()
            }
        }
    }
    
    public func setupCameraPreviewView(_ cameraPreviewView: UIView, progress: Signal<Float, NoError>) {
        self.addSubview(cameraPreviewView)
        self.cameraPreviewView = cameraPreviewView
        
        self.progressLayer.opacity = 1.0
        self.progressLayer.transform = CATransform3DMakeRotation(-.pi / 2.0, 0.0, 0.0, 1.0)
        self.progressLayer.fillColor = UIColor.clear.cgColor
        self.progressLayer.strokeColor = UIColor(rgb: 0xffffff, alpha: 0.5).cgColor
        self.progressLayer.lineWidth = 3.0
        self.progressLayer.lineCap = .round
        self.progressLayer.strokeEnd = 0.0
        self.layer.addSublayer(self.progressLayer)
        
        self.setNeedsLayout()
        
        self.progressDisposable.set((progress
        |> deliverOnMainQueue).startStrict(next: { [weak self] progress in
            if let self {
                self.progressLayer.strokeEnd = CGFloat(progress)
            }
        }))
    }
    
    public func invalidateCameraPreviewView() {
        guard let cameraPreviewView = self.cameraPreviewView else {
            return
        }
        Queue.mainQueue().after(0.1, {
            self.cameraPreviewView = nil
            cameraPreviewView.removeFromSuperview()
            
            if let cameraSnapshotView = self.cameraSnapshotView {
                self.cameraSnapshotView = nil
                UIView.animate(withDuration: 0.25, animations: {
                    cameraSnapshotView.alpha = 0.0
                }, completion: { _ in
                    cameraSnapshotView.removeFromSuperview()
                })
            }
        })
        self.progressLayer.opacity = 0.0
        self.progressLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { _ in
            self.progressLayer.removeFromSuperlayer()
            self.progressLayer.path = nil
        })
        self.progressDisposable.set(nil)
    }
    
    public func snapshotCameraPreviewView() {
        guard let cameraPreviewView = self.cameraPreviewView else {
            return
        }
        if let snapshot = cameraPreviewView.snapshotView(afterScreenUpdates: false) {
            self.cameraSnapshotView = snapshot
            self.addSubview(snapshot)
        }
        self.layer.addSublayer(self.progressLayer)
    }
    
    private var cameraBlurView: BlurView?
    private var cameraSnapshotView: UIView?
    public func beginCameraSwitch() {
        guard let cameraPreviewView = self.cameraPreviewView, self.cameraBlurView == nil else {
            return
        }
        if let snapshot = cameraPreviewView.snapshotView(afterScreenUpdates: false) {
            self.cameraSnapshotView = snapshot
            self.addSubview(snapshot)
        }
        
        let blurView = BlurView(effect: nil)
        blurView.clipsToBounds = true
        blurView.frame = self.bounds
        blurView.layer.cornerRadius = self.bounds.width / 2.0
        self.addSubview(blurView)
        UIView.transition(with: self, duration: 0.4, options: [.transitionFlipFromLeft, .curveEaseOut], animations: {
            blurView.effect = UIBlurEffect(style: .dark)
        })
        self.cameraBlurView = blurView
    }
    
    public func commitCameraSwitch() {
        if let cameraBlurView = self.cameraBlurView {
            self.cameraBlurView = nil
            UIView.animate(withDuration: 0.4, animations: {
                cameraBlurView.effect = nil
            }, completion: { _ in
                cameraBlurView.removeFromSuperview()
            })
        }
        
        if let cameraSnapshotView = self.cameraSnapshotView {
            self.cameraSnapshotView = nil
            UIView.animate(withDuration: 0.25, animations: {
                cameraSnapshotView.alpha = 0.0
            }, completion: { _ in
                cameraSnapshotView.removeFromSuperview()
            })
        }
    }
    
    public func playDissolveAnimation(completion: @escaping () -> Void = {}) {
        guard let containerView = self.containerView, case let .image(image, _) = self.stickerEntity.content else {
            return
        }
            
        let scaledSize = image.size.aspectFitted(CGSize(width: 180.0, height: 180.0))
        guard let scaledImage = generateScaledImage(image: image, size: scaledSize) else {
            self.isHidden = true
            completion()
            return
        }
        
        let dustEffectLayer = DustEffectLayer()
        dustEffectLayer.position = self.center
        dustEffectLayer.bounds = CGRect(origin: CGPoint(), size: containerView.bounds.size)
        containerView.layer.insertSublayer(dustEffectLayer, below: self.layer)
        
        dustEffectLayer.animationSpeed = 2.2
        dustEffectLayer.becameEmpty = { [weak dustEffectLayer] in
            dustEffectLayer?.removeFromSuperlayer()
            completion()
        }

        let maxSize = CGSize(width: 512.0, height: 512.0)
        let itemSize = CGSize(width: self.bounds.width * self.entity.scale, height: self.bounds.height * self.entity.scale)
        let fittedSize = itemSize.aspectFittedOrSmaller(maxSize)
        let scale = itemSize.width / fittedSize.width
        
        dustEffectLayer.transform = CATransform3DScale(CATransform3DMakeRotation(self.stickerEntity.rotation, 0.0, 0.0, 1.0), scale, scale, 1.0)
        
        let itemFrame = CGRect(origin: CGPoint(x: (containerView.bounds.width - fittedSize.width) / 2.0, y: (containerView.bounds.height - fittedSize.height) / 2.0), size: fittedSize)
        dustEffectLayer.addItem(frame: itemFrame, image: scaledImage)
        
        self.isHidden = true
    }
    
    public func playCutoutAnimation() {
        let values = [self.entity.scale, self.entity.scale * 1.1, self.entity.scale]
        let keyTimes = [0.0, 0.67, 1.0]
        self.layer.animateKeyframes(values: values as [NSNumber], keyTimes: keyTimes as [NSNumber], duration: 0.35, keyPath: "transform.scale")
    }
        
    private var didApplyVisibility = false
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
                
        if size.width > 0 && self.currentSize != size {
            self.currentSize = size
            
            let sideSize: CGFloat = max(size.width, size.height)
            let boundingSize = self.innerLayoutSubview(boundingSize: CGSize(width: sideSize, height: sideSize))

            let imageSize = self.dimensions.aspectFitted(boundingSize)
            let imageFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (size.height - imageSize.height) / 2.0), size: imageSize)

            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            self.imageNode.frame = imageFrame
            if let animationNode = self.animationNode {
                if self.isReaction {
                    animationNode.cornerRadius = floor(imageSize.width * 0.1)
                }
                animationNode.frame = imageFrame
                animationNode.updateLayout(size: imageSize)
                
                if !self.didApplyVisibility {
                    self.didApplyVisibility = true
                    self.applyVisibility()
                }
            }
            
            if let videoNode = self.videoNode {
                if case let .message(_, size, _, rect, cornerRadius) = self.stickerEntity.content, let rect, let cornerRadius {
                    let baseSize = self.stickerEntity.baseSize
                    let scale = baseSize.width / size.width
                    let scaledRect = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
                    videoNode.frame = scaledRect
                    videoNode.updateLayout(size: scaledRect.size, transition: .immediate)
                    
                    if cornerRadius > 100.0 {
                        videoNode.cornerRadius = cornerRadius * scale
                    } else {
                        videoNode.cornerRadius = 0.0
                        
                        let hasRoundBottomCorners = scaledRect.maxY > baseSize.height - 6.0
                        if hasRoundBottomCorners {
                            let maskView: DynamicCornerRadiusView
                            if let current = self.videoMaskView {
                                maskView = current
                            } else {
                                maskView = DynamicCornerRadiusView()
                                self.videoMaskView = maskView
                                videoNode.view.mask = maskView
                            }
                            
                            let corners = DynamicCornerRadiusView.Corners(
                                minXMinY: 0.0,
                                maxXMinY: 0.0,
                                minXMaxY: cornerRadius * scale,
                                maxXMaxY: cornerRadius * scale
                            )
                            maskView.update(size: scaledRect.size, corners: corners, transition: .immediate)
                        } else {
                            videoNode.view.mask = nil
                        }
                    }
                } else {
                    videoNode.cornerRadius = floor(imageSize.width * 0.03)
                    videoNode.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) * 0.5), y: floor((size.height - imageSize.height) * 0.5)), size: imageSize)
                    videoNode.updateLayout(size: imageSize, transition: .immediate)
                }
            }
            
            if let animatedImageView = self.animatedImageView {
                animatedImageView.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) * 0.5), y: floor((size.height - imageSize.height) * 0.5)), size: imageSize)
            }
            if let overlayImageView = self.overlayImageView {
                overlayImageView.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) * 0.5), y: floor((size.height - imageSize.height) * 0.5)), size: imageSize)
            }
            
            if let cameraPreviewView = self.cameraPreviewView {
                cameraPreviewView.layer.cornerRadius = imageSize.width / 2.0
                cameraPreviewView.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) * 0.5), y: floor((size.height - imageSize.height) * 0.5)), size: imageSize)
                self.progressLayer.frame = cameraPreviewView.frame
                
                if self.progressLayer.path == nil {
                    self.progressLayer.path = CGPath(ellipseIn: cameraPreviewView.frame.insetBy(dx: 6.0, dy: 6.0), transform: nil)
                }
            }
            
            self.update(animated: false)
        }
    }
    
    var isReaction: Bool {
        return false
    }
    
    func onDeselection() {
        
    }
        
    func innerLayoutSubview(boundingSize: CGSize) -> CGSize {
        return boundingSize
    }
    
    public override func update(animated: Bool) {
        self.center = self.stickerEntity.position
        
        let size = self.stickerEntity.baseSize
        
        self.bounds = CGRect(origin: .zero, size: self.dimensions.aspectFitted(size))
        self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(self.stickerEntity.rotation), self.stickerEntity.scale, self.stickerEntity.scale)
    
        self.updateAnimationColor()

        if case .message = self.stickerEntity.content, self.animatedImageView == nil {
            let image = self.isNightTheme ? self.stickerEntity.secondaryRenderImage : self.stickerEntity.renderImage
            if let image {
                self.setupWithImage(image)
            }
        }
        
        self.updateMirroring(animated: animated)
        
        self.updated()
    
        super.update(animated: animated)
    }
    
    func updateMirroring(animated: Bool) {
        let staticTransform = CATransform3DMakeScale(self.stickerEntity.mirrored ? -1.0 : 1.0, 1.0, 1.0)
        if animated {
            let isCurrentlyMirrored = ((self.imageNode.layer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0) < 0.0
            var animationSourceTransform = CATransform3DIdentity
            var animationTargetTransform = CATransform3DIdentity
            if isCurrentlyMirrored {
                animationSourceTransform = CATransform3DRotate(animationSourceTransform, .pi, 0.0, 1.0, 0.0)
                animationSourceTransform.m34 = -1.0 / self.imageNode.frame.width
            }
            if self.stickerEntity.mirrored {
                animationTargetTransform = CATransform3DRotate(animationTargetTransform, .pi, 0.0, 1.0, 0.0)
                animationTargetTransform.m34 = -1.0 / self.imageNode.frame.width
            }

            self.imageNode.transform = animationSourceTransform
            self.animationNode?.transform = animationSourceTransform
            self.videoNode?.transform = animationSourceTransform
            self.animatedImageView?.layer.transform = animationSourceTransform
            
            UIView.animate(withDuration: 0.25, animations: {
                self.imageNode.transform = animationTargetTransform
                self.animationNode?.transform = animationTargetTransform
                self.videoNode?.transform = animationTargetTransform
                self.animatedImageView?.layer.transform = animationTargetTransform
            }, completion: { finished in
                self.imageNode.transform = staticTransform
                self.animationNode?.transform = staticTransform
                self.videoNode?.transform = staticTransform
                self.animatedImageView?.layer.transform = staticTransform
            })
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.imageNode.transform = staticTransform
            self.animationNode?.transform = staticTransform
            self.videoNode?.transform = staticTransform
            self.animatedImageView?.layer.transform = staticTransform
            CATransaction.commit()
        }
    }
    
    override func updateSelectionView() {
        guard let selectionView = self.selectionView as? DrawingStickerEntitySelectionView else {
            return
        }
        self.pushIdentityTransformForMeasurement()
     
        selectionView.transform = .identity
        let maxSide = max(self.selectionBounds.width, self.selectionBounds.height)
        let center = self.selectionBounds.center
                
        let scale = self.superview?.superview?.layer.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0
        
        selectionView.center = self.convert(center, to: selectionView.superview)
        
        selectionView.bounds = CGRect(origin: .zero, size: CGSize(width: (maxSide * self.stickerEntity.scale) * scale + selectionView.selectionInset * 2.0, height: (maxSide * self.stickerEntity.scale) * scale + selectionView.selectionInset * 2.0))
        selectionView.transform = CGAffineTransformMakeRotation(self.stickerEntity.rotation)
        
        self.popIdentityTransformForMeasurement()
    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingStickerEntitySelectionView()
        selectionView.entityView = self
        return selectionView
    }
    
    func getRenderSubEntities() -> [DrawingEntity] {
        if case let .message(_, _, file, _, cornerRadius) = self.stickerEntity.content {
            if let file, let cornerRadius, let videoNode = self.videoNode {
                let _ = cornerRadius
                let stickerSize = self.bounds.size
                let stickerPosition = self.stickerEntity.position
                let videoSize = videoNode.frame.size
                let scale = self.stickerEntity.scale
                let rotation = self.stickerEntity.rotation
                
                let videoPosition = videoNode.position.offsetBy(dx: -stickerSize.width / 2.0, dy: -stickerSize.height / 2.0)
                let videoScale = videoSize.width / stickerSize.width
                
                let videoEntity = DrawingStickerEntity(content: .video(file))
                videoEntity.referenceDrawingSize = self.stickerEntity.referenceDrawingSize
                videoEntity.position = stickerPosition.offsetBy(
                    dx: (videoPosition.x * cos(rotation) - videoPosition.y * sin(rotation)) * scale,
                    dy: (videoPosition.y * cos(rotation) + videoPosition.x * sin(rotation)) * scale
                )
                videoEntity.scale = scale * videoScale
                videoEntity.rotation = rotation
                
                var entities: [DrawingEntity] = []
                entities.append(videoEntity)
                
                if let overlayImage = self.stickerEntity.overlayRenderImage {
                    let overlayEntity = DrawingStickerEntity(content: .image(overlayImage, .sticker))
                    overlayEntity.referenceDrawingSize = self.stickerEntity.referenceDrawingSize
                    overlayEntity.position = self.stickerEntity.position
                    overlayEntity.scale = self.stickerEntity.scale
                    overlayEntity.rotation = self.stickerEntity.rotation
                    entities.append(overlayEntity)
                }
                
                return entities
            }
        }
        return []
    }
}

final class DrawingStickerEntitySelectionView: DrawingEntitySelectionView {
    private let border = SimpleShapeLayer()
    private let leftHandle = SimpleShapeLayer()
    private let rightHandle = SimpleShapeLayer()
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer?
    
    override init(frame: CGRect) {
        let handleBounds = CGRect(origin: .zero, size: entitySelectionViewHandleSize)
        let handles = [
            self.leftHandle,
            self.rightHandle
        ]
        
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.isOpaque = false
        
        self.border.lineCap = .round
        self.border.fillColor = UIColor.clear.cgColor
        self.border.strokeColor = UIColor(rgb: 0xffffff, alpha: 0.75).cgColor
        self.border.shadowColor = UIColor.black.cgColor
        self.border.shadowRadius = 1.0
        self.border.shadowOpacity = 0.5
        self.border.shadowOffset = CGSize()
        self.layer.addSublayer(self.border)
        
        for handle in handles {
            handle.bounds = handleBounds
            handle.fillColor = UIColor(rgb: 0x0a60ff).cgColor
            handle.strokeColor = UIColor(rgb: 0xffffff).cgColor
            handle.rasterizationScale = UIScreen.main.scale
            handle.shouldRasterize = true
            
            self.layer.addSublayer(handle)
        }
                
        self.snapTool.onSnapUpdated = { [weak self] type, snapped in
            if let self, let entityView = self.entityView {
                entityView.onSnapUpdated(type, snapped)
            }
        }
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPress(_:)))
        self.addGestureRecognizer(longPressGestureRecognizer)
        self.longPressGestureRecognizer = longPressGestureRecognizer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var scale: CGFloat = 1.0 {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    override var selectionInset: CGFloat {
        return 18.0
    }
    
    private let snapTool = DrawingEntitySnapTool()
    
    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if case .began = gestureRecognizer.state {
            self.longPressed()
        }
    }
    
    private var currentHandle: CALayer?
    override func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView as? DrawingStickerEntityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }
        let location = gestureRecognizer.location(in: self)
        
        switch gestureRecognizer.state {
        case .began:
            self.tapGestureRecognizer?.isEnabled = false
            self.tapGestureRecognizer?.isEnabled = true
            
            self.longPressGestureRecognizer?.isEnabled = false
            self.longPressGestureRecognizer?.isEnabled = true
            
            self.snapTool.maybeSkipFromStart(entityView: entityView, position: entity.position)
            
            entityView.onDeselection()
            
            if let sublayers = self.layer.sublayers {
                for layer in sublayers {
                    if layer.frame.contains(location) {
                        self.currentHandle = layer
                        self.snapTool.maybeSkipFromStart(entityView: entityView, rotation: entity.rotation)
                        entityView.onInteractionUpdated(true)
                        return
                    }
                }
            }
            self.currentHandle = self.layer
            entityView.onInteractionUpdated(true)
        case .changed:
            if self.currentHandle == nil {
                self.currentHandle = self.layer
            }

            let delta = gestureRecognizer.translation(in: entityView.superview)
            let parentLocation = gestureRecognizer.location(in: self.superview)
            let velocity = gestureRecognizer.velocity(in: entityView.superview)
                        
            var updatedPosition = entity.position
            var updatedScale = entity.scale
            var updatedRotation = entity.rotation
            
            if self.currentHandle === self.leftHandle || self.currentHandle === self.rightHandle {
                if gestureRecognizer.numberOfTouches > 1 {
                    return
                }
                var deltaX = gestureRecognizer.translation(in: self).x
                if self.currentHandle === self.leftHandle {
                    deltaX *= -1.0
                }
                let scaleDelta = (self.bounds.size.width + deltaX * 2.0) / self.bounds.size.width
                updatedScale *= scaleDelta
                
                let newAngle: CGFloat
                if self.currentHandle === self.leftHandle {
                    newAngle = atan2(self.center.y - parentLocation.y, self.center.x - parentLocation.x)
                } else {
                    newAngle = atan2(parentLocation.y - self.center.y, parentLocation.x - self.center.x)
                }
                var delta = newAngle - updatedRotation
                if delta < -.pi {
                    delta = 2.0 * .pi + delta
                }
                let velocityValue = sqrt(velocity.x * velocity.x + velocity.y * velocity.y) / 1000.0
                updatedRotation = self.snapTool.update(entityView: entityView, velocity: velocityValue, delta: delta, updatedRotation: newAngle, skipMultiplier: 1.0)
            } else if self.currentHandle === self.layer {
                updatedPosition.x += delta.x
                updatedPosition.y += delta.y
                
                updatedPosition = self.snapTool.update(entityView: entityView, velocity: velocity, delta: delta, updatedPosition: updatedPosition, size: entityView.frame.size)
            }
            
            entity.position = updatedPosition
            entity.scale = updatedScale
            entity.rotation = updatedRotation
            entityView.update(animated: false)
            
            gestureRecognizer.setTranslation(.zero, in: entityView)
        case .ended, .cancelled:
            self.snapTool.reset()
            if self.currentHandle != nil {
                self.snapTool.rotationReset()
            }
            entityView.onInteractionUpdated(false)
            
            entityView.onSelection()
        default:
            break
        }
        
        entityView.onPositionUpdated(entity.position)
    }
    
    override func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let entityView = self.entityView as? DrawingStickerEntityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }
        
        if self.currentHandle != nil && self.currentHandle !== self.layer {
            return
        }

        switch gestureRecognizer.state {
        case .began, .changed:
            entityView.onDeselection()
            
            if case .began = gestureRecognizer.state {
                entityView.onInteractionUpdated(true)
            }
            let scale = gestureRecognizer.scale
            entity.scale = entity.scale * scale
            entityView.update(animated: false)

            gestureRecognizer.scale = 1.0
        case .cancelled, .ended:
            entityView.onInteractionUpdated(false)
            
            entityView.onSelection()
        default:
            break
        }
    }
    
    override func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        guard let entityView = self.entityView as? DrawingStickerEntityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }
        
        if self.currentHandle != nil && self.currentHandle !== self.layer {
            return
        }
        
        let velocity = gestureRecognizer.velocity
        var updatedRotation = entity.rotation
        var rotation: CGFloat = 0.0
        
        switch gestureRecognizer.state {
        case .began:
            entityView.onDeselection()
            
            self.snapTool.maybeSkipFromStart(entityView: entityView, rotation: entity.rotation)
            entityView.onInteractionUpdated(true)
        case .changed:
            rotation = gestureRecognizer.rotation
            updatedRotation += rotation
        
            updatedRotation = self.snapTool.update(entityView: entityView, velocity: velocity, delta: rotation, updatedRotation: updatedRotation)
            entity.rotation = updatedRotation
            entityView.update(animated: false)
            
            gestureRecognizer.rotation = 0.0
        case .ended, .cancelled:
            self.snapTool.rotationReset()
            entityView.onInteractionUpdated(false)
            
            entityView.onSelection()
        default:
            break
        }
                
        entityView.onPositionUpdated(entity.position)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -22.0, dy: -22.0).contains(point)
    }
    
    override func layoutSubviews() {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }
        
        let inset = self.selectionInset - 10.0

        let bounds = CGRect(origin: .zero, size: CGSize(width: entitySelectionViewHandleSize.width / self.scale, height: entitySelectionViewHandleSize.height / self.scale))
        let handleSize = CGSize(width: 9.0 / self.scale, height: 9.0 / self.scale)
        let handlePath = CGPath(ellipseIn: CGRect(origin: CGPoint(x: (bounds.width - handleSize.width) / 2.0, y: (bounds.height - handleSize.height) / 2.0), size: handleSize), transform: nil)
        let lineWidth = (1.0 + UIScreenPixel) / self.scale
                
        let radius = (self.bounds.width - inset * 2.0) / 2.0
        let circumference: CGFloat = 2.0 * .pi * radius
        let relativeDashLength: CGFloat = 0.25
        
        self.border.lineWidth = 2.0 / self.scale
        
        let actualInset: CGFloat
        if entity.isRectangle {
            let aspectRatio = entity.baseSize.width / entity.baseSize.height
            
            let width: CGFloat
            var height: CGFloat
            
            if entity.baseSize.width > entity.baseSize.height {
                width = self.bounds.width - inset * 2.0
                height = self.bounds.height / aspectRatio - inset * 2.0
            } else {
                width = self.bounds.width * aspectRatio - inset * 2.0
                height = self.bounds.height - inset * 2.0
            }
            
            actualInset = floorToScreenPixels((self.bounds.width - width) / 2.0)
            
            var cornerRadius: CGFloat = 12.0 - self.scale
            var count = 12
            if case .message = entity.content {
                cornerRadius *= 2.1
                count = 24
            } else if case .image = entity.content {
                count = 24
            }
            
            let perimeter: CGFloat = 2.0 * (width + height - cornerRadius * (4.0 - .pi))

            let dashLength = perimeter / CGFloat(count)
            self.border.lineDashPattern = [dashLength * relativeDashLength, dashLength * relativeDashLength] as [NSNumber]
            
            self.border.path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: floorToScreenPixels((self.bounds.width - width) / 2.0), y: floorToScreenPixels((self.bounds.height - height) / 2.0)), size: CGSize(width: width, height: height)), cornerRadius: cornerRadius).cgPath
        } else {
            actualInset = inset
            
            let count = 10
            let dashLength = circumference / CGFloat(count)
            self.border.lineDashPattern = [dashLength * relativeDashLength, dashLength * relativeDashLength] as [NSNumber]
            
            self.border.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: inset, y: inset), size: CGSize(width: self.bounds.width - inset * 2.0, height: self.bounds.height - inset * 2.0))).cgPath
        }
        
        for handle in [self.leftHandle, self.rightHandle] {
            handle.path = handlePath
            handle.bounds = bounds
            handle.lineWidth = lineWidth
        }
        
        self.leftHandle.position = CGPoint(x: actualInset, y: self.bounds.midY)
        self.rightHandle.position = CGPoint(x: self.bounds.maxX - actualInset, y: self.bounds.midY)
    }
}

private final class StickerVideoDecoration: UniversalVideoDecoration {
    public let backgroundNode: ASDisplayNode? = nil
    public let contentContainerNode: ASDisplayNode
    public let foregroundNode: ASDisplayNode? = nil
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    
    private var validLayout: (size: CGSize, actualSize: CGSize)?
    
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
                    if let validLayout = self.validLayout {
                        contentNode.frame = CGRect(origin: CGPoint(), size: validLayout.size)
                        contentNode.updateLayout(size: validLayout.size, actualSize: validLayout.actualSize, transition: .immediate)
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
    
    public func updateLayout(size: CGSize, actualSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, actualSize)
        
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
            contentNode.updateLayout(size: size, actualSize: actualSize, transition: transition)
        }
    }
    
    public func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
    }
    
    public func tap() {
    }
}

private extension UIBezierPath {
    static func smoothCurve(
        through points: [CGPoint],
        length: CGFloat
    ) -> UIBezierPath {
        let angle = (CGFloat.pi * 2) / CGFloat(points.count)
        let smoothness: CGFloat = ((4 / 3) * tan(angle / 4)) / sin(angle / 2) / 2
        
        var smoothPoints = [SmoothPoint]()
        for index in (0 ..< points.count) {
            let prevIndex = index - 1
            let prev = points[prevIndex >= 0 ? prevIndex : points.count + prevIndex]
            let curr = points[index]
            let next = points[(index + 1) % points.count]
            
            let angle: CGFloat = {
                let dx = next.x - prev.x
                let dy = -next.y + prev.y
                let angle = atan2(dy, dx)
                if angle < 0 {
                    return abs(angle)
                } else {
                    return 2 * .pi - angle
                }
            }()
            
            smoothPoints.append(
                SmoothPoint(
                    point: curr,
                    inAngle: angle + .pi,
                    inLength: smoothness * distance(from: curr, to: prev),
                    outAngle: angle,
                    outLength: smoothness * distance(from: curr, to: next)
                )
            )
        }
        
        let resultPath = UIBezierPath()
        resultPath.move(to: smoothPoints[0].point)
        for index in (0 ..< smoothPoints.count) {
            let curr = smoothPoints[index]
            let next = smoothPoints[(index + 1) % points.count]
            let currSmoothOut = curr.smoothOut()
            let nextSmoothIn = next.smoothIn()
            resultPath.addCurve(to: next.point, controlPoint1: currSmoothOut, controlPoint2: nextSmoothIn)
        }
        resultPath.close()
        return resultPath
    }
    
    static private func distance(from fromPoint: CGPoint, to toPoint: CGPoint) -> CGFloat {
        return sqrt((fromPoint.x - toPoint.x) * (fromPoint.x - toPoint.x) + (fromPoint.y - toPoint.y) * (fromPoint.y - toPoint.y))
    }
    
    struct SmoothPoint {
        let point: CGPoint
        
        let inAngle: CGFloat
        let inLength: CGFloat
        
        let outAngle: CGFloat
        let outLength: CGFloat
        
        func smoothIn() -> CGPoint {
            return smooth(angle: inAngle, length: inLength)
        }
        
        func smoothOut() -> CGPoint {
            return smooth(angle: outAngle, length: outLength)
        }
        
        private func smooth(angle: CGFloat, length: CGFloat) -> CGPoint {
            return CGPoint(
                x: point.x + length * cos(angle),
                y: point.y + length * sin(angle)
            )
        }
    }
}

extension UIImageView {
    func setDrawingAnimatedImage(data: Data) {
        DispatchQueue.global().async {
            if let animatedImage = UIImage.animatedImageFromData(data: data) {
                DispatchQueue.main.async {
                    self.setImage(with: animatedImage)
                    self.startAnimating()
                }
            }
        }
    }

    private func setImage(with animatedImage: DrawingAnimatedImage) {
        if let snapshotView = self.snapshotView(afterScreenUpdates: false) {
            self.addSubview(snapshotView)
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                snapshotView.removeFromSuperview()
            })
        }
        self.image = nil
        self.animationImages = animatedImage.images
        self.animationDuration = animatedImage.duration
        self.animationRepeatCount = 0
    }
}
