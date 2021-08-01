import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import TelegramPresentationData
import PhotoResources

final class ThemeGridSearchItem: GridItem {
    let account: Account
    let theme: PresentationTheme
    let result: ChatContextResult
    let interaction: ThemeGridSearchInteraction
    
    let section: GridSection? = nil
    
    init(account: Account, theme: PresentationTheme, result: ChatContextResult, interaction: ThemeGridSearchInteraction) {
        self.account = account
        self.theme = theme
        self.result = result
        self.interaction = interaction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ThemeGridSearchItemNode()
        node.setup(item: self)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ThemeGridSearchItemNode else {
            assertionFailure()
            return
        }
        node.setup(item: self)
    }
}

final class ThemeGridSearchItemNode: GridItemNode {
    private let imageNode: TransformImageNode
    
    private(set) var item: ThemeGridSearchItem?
    private var currentDimensions: CGSize?
    
    override init() {
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setup(item: ThemeGridSearchItem) {
        if self.item !== item {
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            
            var thumbnailDimensions: CGSize?
            var thumbnailResource: TelegramMediaResource?
            var imageResource: TelegramMediaResource?
            var imageDimensions: CGSize?
            var immediateThumbnailData: Data?
            switch item.result {
            case let .externalReference(externalReference):
                if let content = externalReference.content, externalReference.type != "gif" {
                    imageResource = content.resource
                } else if let thumbnail = externalReference.thumbnail {
                    imageResource = thumbnail.resource
                }
                imageDimensions = externalReference.content?.dimensions?.cgSize
            case let .internalReference(internalReference):
                if let image = internalReference.image {
                    immediateThumbnailData = image.immediateThumbnailData
                    if let representation = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 321, height: 321)) {
                        imageResource = representation.resource
                        imageDimensions = representation.dimensions.cgSize
                    }
                    if let file = internalReference.file {
                        if let thumbnailRepresentation = smallestImageRepresentation(file.previewRepresentations) {
                            thumbnailDimensions = thumbnailRepresentation.dimensions.cgSize
                            thumbnailResource = thumbnailRepresentation.resource
                        }
                    } else {
                        if let thumbnailRepresentation = smallestImageRepresentation(image.representations) {
                            thumbnailDimensions = thumbnailRepresentation.dimensions.cgSize
                            thumbnailResource = thumbnailRepresentation.resource
                        }
                    }
                } else if let file = internalReference.file {
                    immediateThumbnailData = file.immediateThumbnailData
                    if let dimensions = file.dimensions {
                        imageDimensions = dimensions.cgSize
                    } else if let largestRepresentation = largestImageRepresentation(file.previewRepresentations) {
                        imageDimensions = largestRepresentation.dimensions.cgSize
                    }
                    imageResource = smallestImageRepresentation(file.previewRepresentations)?.resource
                }
            }
            
            var representations: [TelegramMediaImageRepresentation] = []
            if let thumbnailResource = thumbnailResource, let thumbnailDimensions = thumbnailDimensions {
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailDimensions), resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil))
            }
            if let imageResource = imageResource, let imageDimensions = imageDimensions {
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(imageDimensions), resource: imageResource, progressiveSizes: [], immediateThumbnailData: nil))
            }
            if !representations.isEmpty {
                let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, immediateThumbnailData: immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                updateImageSignal =  mediaGridMessagePhoto(account: item.account, photoReference: .standalone(media: tmpImage), fullRepresentationSize: CGSize(width: 512, height: 512))
            } else {
                updateImageSignal = .complete()
            }
            
            if let updateImageSignal = updateImageSignal {
                self.imageNode.setSignal(updateImageSignal)
            }
            
            self.currentDimensions = imageDimensions
            if let _ = imageDimensions {
                self.setNeedsLayout()
            }
        }
        
        self.item = item
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
                item.interaction.openResult(item.result)
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        self.imageNode.frame = bounds
        
        if let item = self.item, let dimensions = self.currentDimensions {
            let imageSize = dimensions.aspectFilled(bounds.size)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: bounds.size, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor))()
        }
    }
}
