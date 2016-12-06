import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox

final class HorizontalListContextResultsChatInputPanelItem: ListViewItem {
    fileprivate let account: Account
    fileprivate let result: ChatContextResult
    private let resultSelected: (ChatContextResult) -> Void
    
    let selectable: Bool = true
    
    public init(account: Account, result: ChatContextResult, resultSelected: @escaping (ChatContextResult) -> Void) {
        self.account = account
        self.result = result
        self.resultSelected = resultSelected
    }
    
    public func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        let configure = { () -> Void in
            let node = HorizontalListContextResultsChatInputPanelItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (previousItem != nil, nextItem != nil)
            let (layout, apply) = nodeLayout(self, width, top, bottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                apply(.None)
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? HorizontalListContextResultsChatInputPanelItemNode {
            Queue.mainQueue().async {
                let nodeLayout = node.asyncLayout()
                
                async {
                    let (top, bottom) = (previousItem != nil, nextItem != nil)
                    
                    let (layout, apply) = nodeLayout(self, width, top, bottom)
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
private let iconTextBackgroundImage = generateStretchableFilledCircleImage(radius: 2.0, color: UIColor(0xdfdfdf))

final class HorizontalListContextResultsChatInputPanelItemNode: ListViewItemNode {
    private let imageNodeBackground: ASDisplayNode
    private let imageNode: TransformImageNode
    private let videoNode: ManagedVideoNode
    private var currentImageResource: TelegramMediaResource?
    private var currentVideoResource: TelegramMediaResource?
    
    init() {
        self.imageNodeBackground = ASDisplayNode()
        self.imageNodeBackground.isLayerBacked = true
        self.imageNodeBackground.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        
        self.imageNode = TransformImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.displaysAsynchronously = false
        
        self.videoNode = ManagedVideoNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.backgroundColor = .white
        
        self.addSubnode(self.imageNodeBackground)
        
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat(M_PI / 2.0), 0.0, 0.0, 1.0)
        self.imageNode.alphaTransitionOnFirstUpdate = true
        self.addSubnode(self.imageNode)
        
        self.videoNode.transform = CATransform3DMakeRotation(CGFloat(M_PI / 2.0), 0.0, 0.0, 1.0)
        self.videoNode.clipsToBounds = true
        self.addSubnode(self.videoNode)
    }
    
    override public func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? HorizontalListContextResultsChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, width, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: HorizontalListContextResultsChatInputPanelItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let imageLayout = self.imageNode.asyncLayout()
        let currentImageResource = self.currentImageResource
        let currentVideoResource = self.currentVideoResource
        
        return { [weak self] item, height, mergedTop, mergedBottom in
            let sideInset: CGFloat = 4.0
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            
            var imageResource: TelegramMediaResource?
            var videoResource: TelegramMediaResource?
            var imageDimensions: CGSize?
            switch item.result {
                case let .externalReference(_, _, title, _, url, thumbnailUrl, contentUrl, _, dimensions, _, _):
                    if let contentUrl = contentUrl {
                        imageResource = HttpReferenceMediaResource(url: contentUrl, size: nil)
                    } else if let thumbnailUrl = thumbnailUrl {
                        imageResource = HttpReferenceMediaResource(url: thumbnailUrl, size: nil)
                    }
                    imageDimensions = dimensions
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
                            videoResource = file.resource
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
            var transformArguments: TransformImageArguments?
            if let imageResource = imageResource {
                let imageCorners = ImageCorners()
                let arguments = TransformImageArguments(corners: imageCorners, imageSize: fittedImageDimensions, boundingSize: croppedImageDimensions, intrinsicInsets: UIEdgeInsets())
                transformArguments = arguments
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
            
            var updatedVideoResource = false
            if let currentVideoResource = currentVideoResource, let videoResource = videoResource {
                if !currentVideoResource.isEqual(to: videoResource) {
                    updatedVideoResource = true
                }
            } else if (currentVideoResource != nil) != (videoResource != nil) {
                updatedVideoResource = true
            }
            
            if updatedImageResource {
                if let imageResource = imageResource {
                    let tmpRepresentation = TelegramMediaImageRepresentation(dimensions: CGSize(width: fittedImageDimensions.width * 2.0, height: fittedImageDimensions.height * 2.0), resource: imageResource)
                    let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [tmpRepresentation])
                    //updateImageSignal = chatWebpageSnippetPhoto(account: item.account, photo: tmpImage)
                    updateImageSignal = chatMessagePhoto(account: item.account, photo: tmpImage)
                } else {
                    updateImageSignal = .complete()
                }
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: height, height: croppedImageDimensions.width + sideInset), insets: UIEdgeInsets())
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.currentImageResource = imageResource
                    strongSelf.currentVideoResource = videoResource
                    
                    if let imageApply = imageApply {
                        if let updateImageSignal = updateImageSignal {
                            strongSelf.imageNode.setSignal(account: item.account, signal: updateImageSignal)
                        }
                        
                        strongSelf.imageNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
                        strongSelf.imageNode.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                        
                        strongSelf.videoNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
                        strongSelf.videoNode.position = CGPoint(x: height / 2.0, y: (nodeLayout.contentSize.height - sideInset) / 2.0 + sideInset)
                        
                        strongSelf.imageNodeBackground.frame = CGRect(origin: CGPoint(x: sideInset, y: sideInset), size: CGSize(width: croppedImageDimensions.height, height: croppedImageDimensions.width))
                        
                        if updatedVideoResource {
                            if let videoResource = videoResource {
                                if let applicationContext = item.account.applicationContext as? TelegramApplicationContext {
                                    strongSelf.videoNode.acquireContext(account: item.account, mediaManager: applicationContext.mediaManager, id: ChatContextResultManagedMediaId(result: item.result), resource: videoResource)
                                }
                            } else {
                                strongSelf.videoNode.clearContext()
                            }
                        }
                        
                        imageApply()
                        
                        strongSelf.videoNode.transformArguments = transformArguments
                    }
                }
            })
        }
    }
}
