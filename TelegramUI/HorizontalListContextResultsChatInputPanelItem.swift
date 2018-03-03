import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox

final class HorizontalListContextResultsChatInputPanelItem: ListViewItem {
    let account: Account
    let result: ChatContextResult
    let resultSelected: (ChatContextResult) -> Void
    
    let selectable: Bool = true
    
    public init(account: Account, result: ChatContextResult, resultSelected: @escaping (ChatContextResult) -> Void) {
        self.account = account
        self.result = result
        self.resultSelected = resultSelected
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = HorizontalListContextResultsChatInputPanelItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (previousItem != nil, nextItem != nil)
            let (layout, apply) = nodeLayout(self, params, top, bottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply(.None) })
            })
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? HorizontalListContextResultsChatInputPanelItemNode {
            Queue.mainQueue().async {
                let nodeLayout = node.asyncLayout()
                
                async {
                    let (top, bottom) = (previousItem != nil, nextItem != nil)
                    
                    let (layout, apply) = nodeLayout(self, params, top, bottom)
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply(animation)
                        })
                    }
                }
            }
        } else {
            assertionFailure()
        }
    }
    
    func selected(listView: ListView) {
        self.resultSelected(self.result)
    }
}

private let titleFont = Font.medium(16.0)
private let textFont = Font.regular(15.0)
private let iconFont = Font.medium(25.0)
private let iconTextBackgroundImage = generateStretchableFilledCircleImage(radius: 2.0, color: UIColor(rgb: 0xdfdfdf))

final class HorizontalListContextResultsChatInputPanelItemNode: ListViewItemNode {
    private let imageNodeBackground: ASDisplayNode
    private let imageNode: TransformImageNode
    private var videoLayer: (SoftwareVideoThumbnailLayer, SoftwareVideoLayerFrameManager, SampleBufferLayer)?
    private var currentImageResource: TelegramMediaResource?
    private var currentVideoFile: TelegramMediaFile?
    
    private(set) var item: HorizontalListContextResultsChatInputPanelItem?
    
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
                    displayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
                    if #available(iOS 10.0, *) {
                        displayLink.preferredFramesPerSecond = 25
                    } else {
                        displayLink.frameInterval = 2
                    }
                    displayLink.isPaused = false
                    CMTimebaseSetRate(self.timebase, 1.0)
                } else if let displayLink = self.displayLink {
                    self.displayLink = nil
                    displayLink.isPaused = true
                    displayLink.invalidate()
                    CMTimebaseSetRate(self.timebase, 0.0)
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
        self.imageNodeBackground.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.isLayerBacked = true
        self.imageNode.displaysAsynchronously = false
        
        var timebase: CMTimebase?
        CMTimebaseCreateWithMasterClock(nil, CMClockGetHostTimeClock(), &timebase)
        CMTimebaseSetRate(timebase!, 0.0)
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
        
        return { [weak self] item, params, mergedTop, mergedBottom in
            let height = params.width
            
            let sideInset: CGFloat = 4.0
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            
            var imageResource: TelegramMediaResource?
            var videoFile: TelegramMediaFile?
            var imageDimensions: CGSize?
            switch item.result {
                case let .externalReference(_, type, title, _, url, content, thumbnail, _):
                    if let content = content {
                        imageResource = content.resource
                    } else if let thumbnail = thumbnail {
                        imageResource = thumbnail.resource
                    }
                    imageDimensions = content?.dimensions
                    if type == "gif", let thumbnailResource = imageResource, let content = content, let dimensions = content.dimensions {
                        videoFile = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), resource: content.resource, previewRepresentations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnailResource)], mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: dimensions, flags: [])])
                        imageResource = nil
                    }
                case let .internalReference(_, _, title, _, image, file, _):
                    if let image = image {
                        if let largestRepresentation = largestImageRepresentation(image.representations) {
                            imageDimensions = largestRepresentation.dimensions
                        }
                        imageResource = imageRepresentationLargerThan(image.representations, size: CGSize(width: 200.0, height: 100.0))?.resource
                    } else if let file = file {
                        if let dimensions = file.dimensions {
                            imageDimensions = dimensions
                        } else if let largestRepresentation = largestImageRepresentation(file.previewRepresentations) {
                            imageDimensions = largestRepresentation.dimensions
                        }
                        imageResource = smallestImageRepresentation(file.previewRepresentations)?.resource
                    }
                
                    if let file = file {
                        if file.isVideo && file.isAnimated {
                            videoFile = file
                            imageResource = nil
                        }
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
                if !currentVideoFile.isEqual(videoFile) {
                    updatedVideoFile = true
                }
            } else if (currentVideoFile != nil) != (videoFile != nil) {
                updatedVideoFile = true
            }
            
            if updatedImageResource {
                if let imageResource = imageResource {
                    let tmpRepresentation = TelegramMediaImageRepresentation(dimensions: CGSize(width: fittedImageDimensions.width * 2.0, height: fittedImageDimensions.height * 2.0), resource: imageResource)
                    let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [tmpRepresentation], reference: nil)
                    //updateImageSignal = chatWebpageSnippetPhoto(account: item.account, photo: tmpImage)
                    updateImageSignal = chatMessagePhoto(postbox: item.account.postbox, photo: tmpImage)
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
                            let thumbnailLayer = SoftwareVideoThumbnailLayer(account: item.account, file: videoFile)
                            thumbnailLayer.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                            strongSelf.layer.addSublayer(thumbnailLayer)
                            let layerHolder = takeSampleBufferLayer()
                            layerHolder.layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                            layerHolder.layer.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                            strongSelf.layer.addSublayer(layerHolder.layer)
                            let manager = SoftwareVideoLayerFrameManager(account: item.account, resource: videoFile.resource, layerHolder: layerHolder)
                            strongSelf.videoLayer = (thumbnailLayer, manager, layerHolder)
                            thumbnailLayer.ready = { [weak thumbnailLayer, weak manager] in
                                if let strongSelf = self, let thumbnailLayer = thumbnailLayer, let manager = manager {
                                    if strongSelf.videoLayer?.0 === thumbnailLayer && strongSelf.videoLayer?.1 === manager {
                                        manager.start()
                                    }
                                }
                            }
                            
                            /*if let applicationContext = item.account.applicationContext as? TelegramApplicationContext {
                                strongSelf.videoNode.acquireContext(account: item.account, mediaManager: applicationContext.mediaManager, id: ChatContextResultManagedMediaId(result: item.result), resource: videoResource, priority: 1)
                            }*/
                        }
                    }
                    
                    if let (thumbnailLayer, _, layer) = strongSelf.videoLayer {
                        thumbnailLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
                        thumbnailLayer.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                        layer.layer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
                        layer.layer.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                    }
                }
            })
        }
    }
}
