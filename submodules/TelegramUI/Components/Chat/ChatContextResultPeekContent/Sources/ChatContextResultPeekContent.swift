import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AVFoundation
import PhotoResources
import AppBundle
import ContextUI
import SoftwareVideo
import BatchVideoRendering
import GifVideoLayer
import AccountContext

public final class ChatContextResultPeekContent: PeekControllerContent {
    public let context: AccountContext
    public let contextResult: ChatContextResult
    public let menu: [ContextMenuItem]
    public let batchVideoContext: BatchVideoRenderingContext
    
    public init(context: AccountContext, contextResult: ChatContextResult, menu: [ContextMenuItem], batchVideoContext: BatchVideoRenderingContext) {
        self.context = context
        self.contextResult = contextResult
        self.menu = menu
        self.batchVideoContext = batchVideoContext
    }
    
    public func presentation() -> PeekControllerContentPresentation {
        return .contained
    }
    
    public func menuActivation() -> PeerControllerMenuActivation {
        return .drag
    }
    
    public func menuItems() -> [ContextMenuItem] {
        return self.menu
    }
    
    public func node() -> PeekControllerContentNode & ASDisplayNode {
        return ChatContextResultPeekNode(context: self.context, contextResult: self.contextResult, batchVideoContext: self.batchVideoContext)
    }
    
    public func topAccessoryNode() -> ASDisplayNode? {
        let arrowNode = ASImageNode()
        if let image = UIImage(bundleImageName: "Peek/Arrow") {
            arrowNode.image = image
            arrowNode.frame = CGRect(origin: CGPoint(), size: image.size)
        }
        return arrowNode
    }
    
    public func fullScreenAccessoryNode(blurView: UIVisualEffectView) -> (PeekControllerAccessoryNode & ASDisplayNode)? {
        return nil
    }
    
    public func isEqual(to: PeekControllerContent) -> Bool {
        if let to = to as? ChatContextResultPeekContent {
            return self.contextResult == to.contextResult
        } else {
            return false
        }
    }
}

private final class ChatContextResultPeekNode: ASDisplayNode, PeekControllerContentNode {
    private let context: AccountContext
    private let contextResult: ChatContextResult
    private let batchVideoContext: BatchVideoRenderingContext
    
    private let imageNodeBackground: ASDisplayNode
    private let imageNode: TransformImageNode
    private var videoLayer: GifVideoLayer?
    
    private var currentImageResource: TelegramMediaResource?
    private var currentVideoFile: TelegramMediaFile?
    
    private var ticking: Bool = false {
        didSet {
            if self.ticking != oldValue {
                self.videoLayer?.shouldBeAnimating = self.ticking
            }
        }
    }
    
    init(context: AccountContext, contextResult: ChatContextResult, batchVideoContext: BatchVideoRenderingContext) {
        self.context = context
        self.contextResult = contextResult
        self.batchVideoContext = batchVideoContext
        
        self.imageNodeBackground = ASDisplayNode()
        self.imageNodeBackground.isLayerBacked = true
        self.imageNodeBackground.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.isLayerBacked = !smartInvertColorsEnabled()
        self.imageNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.imageNodeBackground)
        
        self.imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
        self.addSubnode(self.imageNode)
    }
    
    deinit {
    }
    
    func ready() -> Signal<Bool, NoError> {
        return .single(true)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let imageLayout = self.imageNode.asyncLayout()
        let currentImageResource = self.currentImageResource
        let currentVideoFile = self.currentVideoFile
        
        var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        
        var imageResource: TelegramMediaResource?
        var videoFileReference: FileMediaReference?
        var imageDimensions: CGSize?
        switch self.contextResult {
            case let .externalReference(externalReference):
                if let content = externalReference.content {
                    imageResource = content.resource
                } else if let thumbnail = externalReference.thumbnail {
                    imageResource = thumbnail.resource
                }
                imageDimensions = externalReference.content?.dimensions?.cgSize
                if let content = externalReference.content, externalReference.type == "gif", let thumbnailResource = imageResource
                    , let dimensions = content.dimensions {
                    videoFileReference = .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: content.resource, previewRepresentations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: dimensions, flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: []))
                    imageResource = nil
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
                    imageResource = smallestImageRepresentation(file.previewRepresentations)?.resource
                }
                
                if let file = internalReference.file {
                    if file.isVideo && file.isAnimated {
                        videoFileReference = .standalone(media: file)
                        imageResource = nil
                    }
                }
        }
        
        let fittedImageDimensions: CGSize
        let croppedImageDimensions: CGSize
        if let imageDimensions = imageDimensions {
            fittedImageDimensions = imageDimensions.fitted(CGSize(width: size.width, height: size.height))
        } else {
            fittedImageDimensions = CGSize(width: min(size.width, size.height), height: min(size.width, size.height))
        }
        croppedImageDimensions = fittedImageDimensions
        
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
        if let currentVideoFile = currentVideoFile, let videoFileReference = videoFileReference {
            if !currentVideoFile.isEqual(to: videoFileReference.media) {
                updatedVideoFile = true
            }
        } else if (currentVideoFile != nil) != (videoFileReference != nil) {
            updatedVideoFile = true
        }
        
        if updatedImageResource {
            if let imageResource = imageResource {
                let tmpRepresentation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: Int32(fittedImageDimensions.width * 2.0), height: Int32(fittedImageDimensions.height * 2.0)), resource: imageResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
                let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [tmpRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                updateImageSignal = chatMessagePhoto(postbox: self.context.account.postbox, userLocation: .other, photoReference: .standalone(media: tmpImage))
            } else {
                updateImageSignal = .complete()
            }
        }
        
        self.currentImageResource = imageResource
        self.currentVideoFile = videoFileReference?.media
        
        if let imageApply = imageApply {
            if let updateImageSignal = updateImageSignal {
                self.imageNode.setSignal(updateImageSignal)
            }
            
            self.imageNode.frame = CGRect(origin: CGPoint(), size: croppedImageDimensions)
            self.imageNodeBackground.frame = CGRect(origin: CGPoint(), size: croppedImageDimensions)
            imageApply()
        }
        
        if updatedVideoFile {
            if let videoLayer = self.videoLayer {
                self.videoLayer = nil
                videoLayer.removeFromSuperlayer()
            }
            
            if let videoFileReference {
                let videoLayer = GifVideoLayer(
                    context: self.context,
                    batchVideoContext: self.batchVideoContext,
                    userLocation: .other,
                    file: videoFileReference,
                    synchronousLoad: false
                )
                self.videoLayer = videoLayer
                self.layer.addSublayer(videoLayer)
            }
        }
        
        if let videoLayer = self.videoLayer {
            videoLayer.frame = CGRect(origin: CGPoint(), size: CGSize(width: croppedImageDimensions.width, height: croppedImageDimensions.height))
        }
        
        if !self.ticking {
            self.ticking = true
        }
    
        return croppedImageDimensions
    }
}
