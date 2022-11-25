import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import AVFoundation
import RadialStatusNode
import StickerResources
import PhotoResources
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import TelegramPresentationData
import AccountContext
import ShimmerEffect
import SoftwareVideo

final class HorizontalListContextResultsChatInputPanelItem: ListViewItem {
    let account: Account
    let theme: PresentationTheme
    let result: ChatContextResult
    let resultSelected: (ChatContextResult, ASDisplayNode, CGRect) -> Bool
    
    let selectable: Bool = true
    
    public init(account: Account, theme: PresentationTheme,  result: ChatContextResult, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool) {
        self.account = account
        self.theme = theme
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
                    return (nil, { _ in apply(synchronousLoads, .None) })
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
                            apply(false, animation)
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
    private var placeholderNode: StickerShimmerEffectNode?
    private var videoLayer: (SoftwareVideoThumbnailNode, SoftwareVideoLayerFrameManager, SampleBufferLayer)?
    private var currentImageResource: TelegramMediaResource?
    private var currentVideoFile: TelegramMediaFile?
    private var currentAnimatedStickerFile: TelegramMediaFile?
    private var resourceStatus: MediaResourceStatus?
    private(set) var item: HorizontalListContextResultsChatInputPanelItem?
    private var statusDisposable = MetaDisposable()
    private let statusNode: RadialStatusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
    
    private let fetchDisposable = MetaDisposable()

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
        
        self.placeholderNode = StickerShimmerEffectNode()
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.isLayerBacked = !smartInvertColorsEnabled()
        self.imageNode.displaysAsynchronously = false
        
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        CMTimebaseSetRate(timebase!, rate: 0.0)
        self.timebase = timebase!
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.imageNodeBackground)
        
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
        self.addSubnode(self.imageNode)
        
        var firstTime = true
        self.imageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                strongSelf.removePlaceholder(animated: !firstTime)
            }
            firstTime = false
        }
        
        if let placeholderNode = self.placeholderNode {
            placeholderNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
            self.addSubnode(placeholderNode)
        }
    }
    
    deinit {
        if let displayLink = self.displayLink {
            displayLink.isPaused = true
            displayLink.invalidate()
        }
        self.statusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    private func removePlaceholder(animated: Bool) {
        if let placeholderNode = self.placeholderNode {
            self.placeholderNode = nil
            if !animated {
                placeholderNode.removeFromSupernode()
            } else {
                placeholderNode.allowsGroupOpacity = true
                placeholderNode.alpha = 0.0
                placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak placeholderNode] _ in
                    placeholderNode?.removeFromSupernode()
                    placeholderNode?.allowsGroupOpacity = false
                })
            }
        }
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? HorizontalListContextResultsChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(false, .None)
        }
    }
    
    func asyncLayout() -> (_ item: HorizontalListContextResultsChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (Bool, ListViewItemUpdateAnimation) -> Void) {
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
                case let .externalReference(externalReference):
                    if let content = externalReference.content {
                        imageResource = content.resource
                    } else if let thumbnail = externalReference.thumbnail {
                        imageResource = thumbnail.resource
                    }
                    imageDimensions = externalReference.content?.dimensions?.cgSize
                    if externalReference.type == "gif", let thumbnailResource = externalReference.thumbnail?.resource, let content = externalReference.content, let dimensions = content.dimensions {
                        videoFile = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: thumbnailResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: dimensions, flags: [])])
                        imageResource = nil
                    }
                
                    if let file = videoFile {
                        updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(file.resource)
                    } else if let imageResource = imageResource {
                        updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(imageResource)
                    }
                case let .internalReference(internalReference):
                    if let image = internalReference.image {
                        if let largestRepresentation = largestImageRepresentation(image.representations) {
                            imageDimensions = largestRepresentation.dimensions.cgSize
                        }
                        imageResource = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 200, height: 100))?.resource
                    } else if let file = internalReference.file {
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
                
                    if let file = internalReference.file {
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
                        let tmpRepresentation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(CGSize(width: fittedImageDimensions.width * 2.0, height: fittedImageDimensions.height * 2.0)), resource: imageResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false)
                        let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [tmpRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        updateImageSignal = chatMessagePhoto(postbox: item.account.postbox, photoReference: .standalone(media: tmpImage), synchronousLoad: true)
                    }
                } else {
                    updateImageSignal = .complete()
                }
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: height, height: croppedImageDimensions.width + sideInset), insets: UIEdgeInsets())
            
            return (nodeLayout, { synchronousLoads, _ in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.currentImageResource = imageResource
                    strongSelf.currentVideoFile = videoFile
                    strongSelf.currentAnimatedStickerFile = currentAnimatedStickerFile
                    
                    if let imageApply = imageApply {
                        if let updateImageSignal = updateImageSignal {
                            strongSelf.imageNode.setSignal(updateImageSignal, attemptSynchronously: true)
                        }
                        
                        strongSelf.imageNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
                        strongSelf.imageNode.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                        
                        strongSelf.imageNodeBackground.frame = CGRect(origin: CGPoint(x: sideInset, y: sideInset), size: CGSize(width: croppedImageDimensions.height, height: croppedImageDimensions.width))
                        imageApply()
                    }
                        
                    if updatedVideoFile {
                        if let (thumbnailLayer, _, layer) = strongSelf.videoLayer {
                            strongSelf.videoLayer = nil
                            thumbnailLayer.removeFromSupernode()
                            layer.layer.removeFromSuperlayer()
                        }
                        
                        if let videoFile = videoFile {
                            let thumbnailLayer = SoftwareVideoThumbnailNode(account: item.account, fileReference: .standalone(media: videoFile), synchronousLoad: synchronousLoads)
                            thumbnailLayer.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                            strongSelf.addSubnode(thumbnailLayer)
                            let layerHolder = takeSampleBufferLayer()
                            layerHolder.layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                            layerHolder.layer.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                            strongSelf.layer.addSublayer(layerHolder.layer)
                            
                            let manager = SoftwareVideoLayerFrameManager(account: item.account, fileReference: .standalone(media: videoFile), layerHolder: layerHolder)
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
                                animationNode = DefaultAnimatedStickerNodeImpl()
                                animationNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                                animationNode.visibility = true
                                if let placeholderNode = strongSelf.placeholderNode {
                                    strongSelf.insertSubnode(animationNode, belowSubnode: placeholderNode)
                                } else {
                                    strongSelf.addSubnode(animationNode)
                                }
                                strongSelf.animationNode = animationNode
                            }
                            animationNode.started = { [weak self] in
                                self?.imageNode.alpha = 0.0
                            }
                            let dimensions = animatedStickerFile.dimensions ?? PixelDimensions(width: 512, height: 512)
                            let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))
                            strongSelf.fetchDisposable.set(freeMediaFileResourceInteractiveFetched(account: item.account, fileReference: stickerPackFileReference(animatedStickerFile), resource: animatedStickerFile.resource).start())
                            animationNode.setup(source: AnimatedStickerResourceSource(account: item.account, resource: animatedStickerFile.resource, isVideo: animatedStickerFile.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: .loop, mode: .cached)
                        }
                    }
                    
                    let progressSize = CGSize(width: 24.0, height: 24.0)
                    let progressFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((nodeLayout.contentSize.width - progressSize.width) / 2.0), y: floorToScreenPixels((nodeLayout.contentSize.height - progressSize.height) / 2.0)), size: progressSize)

                    strongSelf.statusNode.removeFromSupernode()
                    //strongSelf.addSubnode(strongSelf.statusNode)
                    
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
                                            state = .progress(color: statusForegroundColor, lineWidth: nil, value: CGFloat(max(progress, 0.2)), cancelEnabled: false, animateRotation: true)
                                        case .Remote, .Paused:
                                            //state = .download(statusForegroundColor)
                                            state = .none
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
                    
                    var immediateThumbnailData: Data?
                    if case let .internalReference(internalReference) = item.result, internalReference.file?.isSticker == true {
                        immediateThumbnailData = internalReference.file?.immediateThumbnailData
                    }
                    
                    if let placeholderNode = strongSelf.placeholderNode {
                        placeholderNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
                        placeholderNode.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                        
                        placeholderNode.update(backgroundColor: item.theme.list.plainBackgroundColor, foregroundColor: item.theme.list.mediaPlaceholderColor.mixedWith(item.theme.list.plainBackgroundColor, alpha: 0.4), shimmeringColor: item.theme.list.mediaPlaceholderColor.withAlphaComponent(0.3), data: immediateThumbnailData, size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
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
