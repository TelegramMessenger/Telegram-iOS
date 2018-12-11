import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox

final class WebSearchItem: GridItem {
    var section: GridSection?
    
    let account: Account
    let theme: PresentationTheme
    let interfaceState: WebSearchInterfaceState
    let result: ChatContextResult
    let controllerInteraction: WebSearchControllerInteraction
    
    public init(account: Account, theme: PresentationTheme, interfaceState: WebSearchInterfaceState, result: ChatContextResult, controllerInteraction: WebSearchControllerInteraction) {
        self.account = account
        self.theme = theme
        self.result = result
        self.interfaceState = interfaceState
        self.controllerInteraction = controllerInteraction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = WebSearchItemNode()
        node.setup(item: self)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? WebSearchItemNode else {
            assertionFailure()
            return
        }
        node.setup(item: self)
    }
}

final class WebSearchItemNode: GridItemNode {
    private let imageNodeBackground: ASDisplayNode
    private let imageNode: TransformImageNode
    private var selectionNode: GridMessageSelectionNode?
    
    private var currentImageResource: TelegramMediaResource?
    private var currentVideoFile: TelegramMediaFile?
    private var currentDimensions: CGSize?
    
    private(set) var item: WebSearchItem?
    
    private let fetchStatusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private var resourceStatus: MediaResourceStatus?
    
    private let statusNode: RadialStatusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
    
    override init() {
        self.imageNodeBackground = ASDisplayNode()
        self.imageNodeBackground.isLayerBacked = true
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.imageNodeBackground)
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        self.fetchStatusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.imageNode.view.addGestureRecognizer(recognizer)
    }
    
    func setup(item: WebSearchItem) {
        if self.item !== item {
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
            
            var imageResource: TelegramMediaResource?
            var stickerFile: TelegramMediaFile?
            var videoFile: TelegramMediaFile?
            var imageDimensions: CGSize?
            switch item.result {
                case let .externalReference(_, _, type, title, _, url, content, thumbnail, _):
                    if let content = content {
                        imageResource = content.resource
                    } else if let thumbnail = thumbnail {
                        imageResource = thumbnail.resource
                    }
                    imageDimensions = content?.dimensions
                    if type == "gif", let thumbnailResource = imageResource, let content = content, let dimensions = content.dimensions {
                        videoFile = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: content.resource, previewRepresentations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnailResource)], mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: dimensions, flags: [])])
                        imageResource = nil
                    }
                    
                    if let file = videoFile {
                        updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(file.resource)
                    } else if let imageResource = imageResource {
                        updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(imageResource)
                    }
                case let .internalReference(_, _, _, title, _, image, file, _):
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
                
    //                if let file = file {
    //                    if file.isVideo && file.isAnimated {
    //                        videoFile = file
    //                        imageResource = nil
    //                        updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(file.resource)
    //                    } else if let imageResource = imageResource {
    //                        updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(imageResource)
    //                    }
    //                } else if let imageResource = imageResource {
    //                    updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(imageResource)
    //                }
            }
            
            if let imageResource = imageResource, let imageDimensions = imageDimensions {
                let tmpRepresentation = TelegramMediaImageRepresentation(dimensions: imageDimensions, resource: imageResource)
                let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [tmpRepresentation], reference: nil, partialReference: nil)
                updateImageSignal =  mediaGridMessagePhoto(account: item.account, photoReference: .standalone(media: tmpImage))
            } else {
                updateImageSignal = .complete()
            }
            
            if let updateImageSignal = updateImageSignal {
                self.imageNode.setSignal(updateImageSignal)
            }
            
            self.currentImageResource = imageResource
            self.currentVideoFile = videoFile
            self.currentDimensions = imageDimensions
            if let _ = imageDimensions {
                self.setNeedsLayout()
            }
        }
        
        self.item = item
        self.updateSelectionState(animated: false)
    }
    
    func updateSelectionState(animated: Bool) {
        if self.selectionNode == nil, let item = self.item {
            let selectionNode = GridMessageSelectionNode(theme: item.theme, toggle: { [weak self] value in
                if let strongSelf = self, let item = strongSelf.item {
                    item.controllerInteraction.toggleSelection([item.result.id], value)
                    strongSelf.updateSelectionState(animated: true)
                }
            })
            
            selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
            self.addSubnode(selectionNode)
            self.selectionNode = selectionNode
        }
        
        if let item = self.item {
            if let selectionState = item.controllerInteraction.selectionState {
                let selected = selectionState.selectedIds.contains(item.result.id)
                self.selectionNode?.updateSelected(selected, animated: animated)
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let imageFrame = self.bounds
        self.imageNode.frame = imageFrame
        
        if let item = self.item, let dimensions = self.currentDimensions {
            let imageSize = dimensions.aspectFilled(imageFrame.size)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor))()
        }
        
        self.selectionNode?.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        let progressDiameter: CGFloat = 40.0
        self.statusNode.frame = CGRect(origin: CGPoint(x: floor((imageFrame.size.width - progressDiameter) / 2.0), y: floor((imageFrame.size.height - progressDiameter) / 2.0)), size: CGSize(width: progressDiameter, height: progressDiameter))
        
        //self.videoAccessoryNode.frame = CGRect(origin: CGPoint(x: imageFrame.maxX - self.videoAccessoryNode.contentSize.width - 5, y: imageFrame.maxY - self.videoAccessoryNode.contentSize.height - 5), size: self.videoAccessoryNode.contentSize)
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
//        guard let controllerInteraction = self.controllerInteraction, let message = self.item?.message else {
//            return
//        }
//
//        switch recognizer.state {
//        case .ended:
//            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
//                switch gesture {
//                case .tap:
//                    if let (account, media, _) = self.currentState {
//                        if let file = media as? TelegramMediaFile {
//                            if let resourceStatus = self.resourceStatus {
//                                switch resourceStatus {
//                                case .Fetching:
//                                    messageMediaFileCancelInteractiveFetch(account: account, messageId: message.id, file: file)
//                                case .Local:
//                                    let _ = controllerInteraction.openMessage(message, .default)
//                                case .Remote:
//                                    self.fetchDisposable.set(messageMediaFileInteractiveFetched(account: account, message: message, file: file, userInitiated: true).start())
//                                }
//                            }
//                        } else {
//                            let _ = controllerInteraction.openMessage(message, .default)
//                        }
//                    }
//                case .longTap:
//                    controllerInteraction.openMessageContextMenu(message, false, self, self.bounds)
//                default:
//                    break
//                }
//            }
//        default:
//            break
//        }
    }
}

