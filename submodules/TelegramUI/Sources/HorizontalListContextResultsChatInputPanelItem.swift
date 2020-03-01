import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import AVFoundation
import RadialStatusNode
import StickerResources
import PhotoResources
import AnimatedStickerNode
import TelegramAnimatedStickerNode

final class HorizontalListContextResultsChatInputPanelItem: ListViewItem {
    let account: Account
    let result: ChatContextResult
    let resultSelected: (ChatContextResult, ASDisplayNode, CGRect) -> Bool
    
    let selectable: Bool = true
    
    public init(account: Account, result: ChatContextResult, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool) {
        self.account = account
        self.result = result
        self.resultSelected = resultSelected
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = HorizontalListContextResultsChatInputPanelItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (previousItem != nil, nextItem != nil)
            let (layout, apply) = nodeLayout(self, params, top, bottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? HorizontalListContextResultsChatInputPanelItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (top, bottom) = (previousItem != nil, nextItem != nil)
                    
                    let (layout, apply) = nodeLayout(self, params, top, bottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
}

private let titleFont = Font.medium(16.0)
private let textFont = Font.regular(15.0)
private let iconFont = Font.medium(25.0)
private let iconTextBackgroundImage = generateStretchableFilledCircleImage(radius: 2.0, color: UIColor(rgb: 0xdfdfdf))

final class HorizontalListContextResultsChatInputPanelItemNode: ListViewItemNode {
    private let imageNodeBackground: ASDisplayNode
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    private var videoLayer: (SoftwareVideoThumbnailLayer, SoftwareVideoLayerFrameManager, SampleBufferLayer)?
    private var currentImageResource: TelegramMediaResource?
    private var currentVideoFile: TelegramMediaFile?
    private var currentAnimatedStickerFile: TelegramMediaFile?
    private var resourceStatus: MediaResourceStatus?
    private(set) var item: HorizontalListContextResultsChatInputPanelItem?
    private var statusDisposable = MetaDisposable()
    private let statusNode: RadialStatusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))

    override var visibility: ListViewItemNodeVisibility {
        didSet {
            switch visibility {
                case .visible:
                    self.ticking = true
                default:
                    self.ticking = false
            }
        }
    }
    
    private let timebase: CMTimebase
    
    private var displayLink: CADisplayLink?
    private var ticking: Bool = false {
        didSet {
            if self.ticking != oldValue {
                if self.ticking {
                    class DisplayLinkProxy: NSObject {
                        weak var target: HorizontalListContextResultsChatInputPanelItemNode?
                        init(target: HorizontalListContextResultsChatInputPanelItemNode) {
                            self.target = target
                        }
                        
                        @objc func displayLinkEvent() {
                            self.target?.displayLinkEvent()
                        }
                    }
                    
                    let displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
                    self.displayLink = displayLink
                    displayLink.add(to: RunLoop.main, forMode: .common)
                    if #available(iOS 10.0, *) {
                        displayLink.preferredFramesPerSecond = 25
                    } else {
                        displayLink.frameInterval = 2
                    }
                    displayLink.isPaused = false
                    CMTimebaseSetRate(self.timebase, rate: 1.0)
                } else if let displayLink = self.displayLink {
                    self.displayLink = nil
                    displayLink.isPaused = true
                    displayLink.invalidate()
                    CMTimebaseSetRate(self.timebase, rate: 0.0)
                }
            }
        }
    }
    
    private func displayLinkEvent() {
        let timestamp = CMTimebaseGetTime(self.timebase).seconds
        self.videoLayer?.1.tick(timestamp: timestamp)
    }
    
    init() {
        self.imageNodeBackground = ASDisplayNode()
        self.imageNodeBackground.isLayerBacked = true
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.isLayerBacked = !smartInvertColorsEnabled()
        self.imageNode.displaysAsynchronously = false
        
        var timebase: CMTimebase?
        CMTimebaseCreateWithMasterClock(allocator: nil, masterClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        CMTimebaseSetRate(timebase!, rate: 0.0)
        self.timebase = timebase!
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.imageNodeBackground)
        
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        if let displayLink = self.displayLink {
            displayLink.isPaused = true
            displayLink.invalidate()
        }
        self.statusDisposable.dispose()
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? HorizontalListContextResultsChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: HorizontalListContextResultsChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let imageLayout = self.imageNode.asyncLayout()
        let currentImageResource = self.currentImageResource
        let currentVideoFile = self.currentVideoFile
        let currentAnimatedStickerFile = self.currentAnimatedStickerFile
        
        return { [weak self] item, params, mergedTop, mergedBottom in
            let height = params.width
            
            let sideInset: CGFloat = 4.0
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?

            var imageResource: TelegramMediaResource?
            var stickerFile: TelegramMediaFile?
            var animatedStickerFile: TelegramMediaFile?
            var videoFile: TelegramMediaFile?
            var imageDimensions: CGSize?
            switch item.result {
                case let .externalReference(_, _, type, _, _, _, content, thumbnail, _):
                    if let content = content {
                        imageResource = content.resource
                    } else if let thumbnail = thumbnail {
                        imageResource = thumbnail.resource
                    }
                    imageDimensions = content?.dimensions?.cgSize
                    if type == "gif", let thumbnailResource = imageResource, let content = content, let dimensions = content.dimensions {
                        videoFile = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: content.resource, previewRepresentations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnailResource)], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: dimensions, flags: [])])
                        imageResource = nil
                    }
                
                    if let file = videoFile {
                        updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(file.resource)
                    } else if let imageResource = imageResource {
                        updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(imageResource)
                    }
                case let .internalReference(_, _, _, _, _, image, file, _):
                    if let image = image {
                        if let largestRepresentation = largestImageRepresentation(image.representations) {
                            imageDimensions = largestRepresentation.dimensions.cgSize
                        }
                        imageResource = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 200, height: 100))?.resource
                    } else if let file = file {
                        if let dimensions = file.dimensions {
                            imageDimensions = dimensions.cgSize
                        } else if let largestRepresentation = largestImageRepresentation(file.previewRepresentations) {
                            imageDimensions = largestRepresentation.dimensions.cgSize
                        }
                        if file.isAnimatedSticker {
                            animatedStickerFile = file
                            imageResource = smallestImageRepresentation(file.previewRepresentations)?.resource
                        } else if file.isSticker {
                            stickerFile = file
                            imageResource = file.resource
                        } else {
                            imageResource = smallestImageRepresentation(file.previewRepresentations)?.resource
                        }
                    }
                
                    if let file = file {
                        if file.isVideo && file.isAnimated {
                            videoFile = file
                            imageResource = nil
                            updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(file.resource)
                        } else if let imageResource = imageResource {
                            updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(imageResource)
                        }
                    } else if let imageResource = imageResource {
                        updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(imageResource)
                    }
            }
            
            let fittedImageDimensions: CGSize
            let croppedImageDimensions: CGSize
            if let imageDimensions = imageDimensions {
                fittedImageDimensions = imageDimensions.fitted(CGSize(width: 1000.0, height: height - sideInset - sideInset))
            } else {
                fittedImageDimensions = CGSize(width: height - sideInset - sideInset, height: height - sideInset - sideInset)
            }
            croppedImageDimensions = fittedImageDimensions.cropped(CGSize(width: floor(height * 4.0 / 3.0), height: 1000.0))
            
            var imageApply: (() -> Void)?
            if let _ = imageResource {
                let imageCorners = ImageCorners()
                let arguments = TransformImageArguments(corners: imageCorners, imageSize: fittedImageDimensions, boundingSize: croppedImageDimensions, intrinsicInsets: UIEdgeInsets())
                imageApply = imageLayout(arguments)
            }
            
            var updatedImageResource = false
            if let currentImageResource = currentImageResource, let imageResource = imageResource {
                if !currentImageResource.isEqual(to: imageResource) {
                    updatedImageResource = true
                }
            } else if (currentImageResource != nil) != (imageResource != nil) {
                updatedImageResource = true
            }
            
            var updatedVideoFile = false
            if let currentVideoFile = currentVideoFile, let videoFile = videoFile {
                if !currentVideoFile.isEqual(to: videoFile) {
                    updatedVideoFile = true
                }
            } else if (currentVideoFile != nil) != (videoFile != nil) {
                updatedVideoFile = true
            }
            
            var updatedAnimatedStickerFile = false
            if let currentAnimatedStickerFile = currentAnimatedStickerFile, let animatedStickerFile = animatedStickerFile {
                if !currentAnimatedStickerFile.isEqual(to: animatedStickerFile) {
                    updatedAnimatedStickerFile = true
                }
            } else if (currentAnimatedStickerFile != nil) != (animatedStickerFile != nil) {
                updatedAnimatedStickerFile = true
            }
            
            if updatedImageResource {
                if let imageResource = imageResource {
                    if let stickerFile = stickerFile {
                        updateImageSignal = chatMessageSticker(account: item.account, file: stickerFile, small: false, fetched: true)
                    } else {
                        let tmpRepresentation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(CGSize(width: fittedImageDimensions.width * 2.0, height: fittedImageDimensions.height * 2.0)), resource: imageResource)
                        let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [tmpRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        updateImageSignal = chatMessagePhoto(postbox: item.account.postbox, photoReference: .standalone(media: tmpImage))
                    }
                } else {
                    updateImageSignal = .complete()
                }
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: height, height: croppedImageDimensions.width + sideInset), insets: UIEdgeInsets())
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.currentImageResource = imageResource
                    strongSelf.currentVideoFile = videoFile
                    strongSelf.currentAnimatedStickerFile = currentAnimatedStickerFile
                    
                    if let imageApply = imageApply {
                        if let updateImageSignal = updateImageSignal {
                            strongSelf.imageNode.setSignal(updateImageSignal)
                        }
                        
                        strongSelf.imageNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
                        strongSelf.imageNode.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                        
                        strongSelf.imageNodeBackground.frame = CGRect(origin: CGPoint(x: sideInset, y: sideInset), size: CGSize(width: croppedImageDimensions.height, height: croppedImageDimensions.width))
                        imageApply()
                    }
                        
                    if updatedVideoFile {
                        if let (thumbnailLayer, _, layer) = strongSelf.videoLayer {
                            strongSelf.videoLayer = nil
                            thumbnailLayer.removeFromSuperlayer()
                            layer.layer.removeFromSuperlayer()
                        }
                        
                        if let videoFile = videoFile {
                            let thumbnailLayer = SoftwareVideoThumbnailLayer(account: item.account, fileReference: .standalone(media: videoFile))
                            thumbnailLayer.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                            strongSelf.layer.addSublayer(thumbnailLayer)
                            let layerHolder = takeSampleBufferLayer()
                            layerHolder.layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                            layerHolder.layer.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                            strongSelf.layer.addSublayer(layerHolder.layer)
                            let manager = SoftwareVideoLayerFrameManager(account: item.account, fileReference: .standalone(media: videoFile), resource: videoFile.resource, layerHolder: layerHolder)
                            strongSelf.videoLayer = (thumbnailLayer, manager, layerHolder)
                            thumbnailLayer.ready = { [weak thumbnailLayer, weak manager] in
                                if let strongSelf = self, let thumbnailLayer = thumbnailLayer, let manager = manager {
                                    if strongSelf.videoLayer?.0 === thumbnailLayer && strongSelf.videoLayer?.1 === manager {
                                        manager.start()
                                    }
                                }
                            }
                        }
                    }
                    
                    if updatedAnimatedStickerFile {
                        if let animationNode = strongSelf.animationNode {
                            strongSelf.animationNode = nil
                            animationNode.removeFromSupernode()
                        }
                        
                        if let animatedStickerFile = animatedStickerFile {
                            let animationNode: AnimatedStickerNode
                            if let currentAnimationNode = strongSelf.animationNode {
                                animationNode = currentAnimationNode
                            } else {
                                animationNode = AnimatedStickerNode()
                                animationNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                                animationNode.visibility = true
                                strongSelf.addSubnode(animationNode)
                                strongSelf.animationNode = animationNode
                            }
                            animationNode.started = { [weak self] in
                                self?.imageNode.alpha = 0.0
                            }
                            let dimensions = animatedStickerFile.dimensions ?? PixelDimensions(width: 512, height: 512)
                            let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))
                            animationNode.setup(source: AnimatedStickerResourceSource(account: item.account, resource: animatedStickerFile.resource), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), mode: .cached)
                        }
                    }
                    
                    let progressSize = CGSize(width: 24.0, height: 24.0)
                    let progressFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((nodeLayout.contentSize.width - progressSize.width) / 2.0), y: floorToScreenPixels((nodeLayout.contentSize.height - progressSize.height) / 2.0)), size: progressSize)

                    strongSelf.statusNode.removeFromSupernode()
                    strongSelf.addSubnode(strongSelf.statusNode)
                    
                    strongSelf.statusNode.frame = progressFrame

                    
                    if let updatedStatusSignal = updatedStatusSignal {
                        strongSelf.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                            displayLinkDispatcher.dispatch {
                                if let strongSelf = strongSelf {
                                    strongSelf.resourceStatus = status
                                    
                                    let state: RadialStatusNodeState
                                    let statusForegroundColor: UIColor = .white
                                    
                                    switch status {
                                        case let .Fetching(_, progress):
                                            state = .progress(color: statusForegroundColor, lineWidth: nil, value: CGFloat(max(progress, 0.2)), cancelEnabled: false)
                                        case .Remote:
                                            state = .download(statusForegroundColor)
                                        case .Local:
                                            state = .none
                                    }
                                    
                                    strongSelf.statusNode.transitionToState(state, completion: { })
                                }
                            }
                        }))
                    } else {
                        strongSelf.statusNode.transitionToState(.none, completion: { })
                    }
                    
                    if let (thumbnailLayer, _, layer) = strongSelf.videoLayer {
                        thumbnailLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
                        thumbnailLayer.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                        layer.layer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
                        layer.layer.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                    }
                    
                    if let animationNode = strongSelf.animationNode {
                        animationNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
                        animationNode.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                        animationNode.updateLayout(size: croppedImageDimensions)
                    }
                }
            })
        }
    }
    
    override func selected() {
        guard let item = self.item else {
            return
        }
        let _ = item.resultSelected(item.result, self, self.bounds)
    }
}
