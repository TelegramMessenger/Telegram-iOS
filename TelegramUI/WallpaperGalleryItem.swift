import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents

class WallpaperGalleryItem: GalleryItem {
    let account: Account
    let entry: WallpaperGalleryEntry
    
    init(account: Account, entry: WallpaperGalleryEntry) {
        self.account = account
        self.entry = entry
    }
    
    func node() -> GalleryItemNode {
        let node = WallpaperGalleryItemNode(account: self.account)
        node.setEntry(self.entry)
        return node
    }
    
    func updateNode(node: GalleryItemNode) {
        if let node = node as? WallpaperGalleryItemNode {
            node.setEntry(self.entry)
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        return nil
    }
}

let progressDiameter: CGFloat = 50.0

final class WallpaperGalleryItemNode: GalleryItemNode {
    private let account: Account
    private var entry: WallpaperGalleryEntry?
    private var contentSize: CGSize?
    
    let wrapperNode: ASDisplayNode
    let imageNode: TransformImageNode
    private let statusNode: RadialStatusNode
    private let blurredNode: BlurredImageNode
    let cropNode: WallpaperCropNode
    
    fileprivate let _ready = Promise<Void>()
    private let fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    
    let controlsColor = Promise<UIColor>(.white)
    let status = Promise<MediaResourceStatus>(.Local)
    
    init(account: Account) {
        self.account = account
        
        self.wrapperNode = ASDisplayNode()
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = .subsequentUpdates
        self.cropNode = WallpaperCropNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        self.statusNode.frame = CGRect(x: 0.0, y: 0.0, width: progressDiameter, height: progressDiameter)
        self.statusNode.isUserInteractionEnabled = false
        
        self.blurredNode = BlurredImageNode()
        
        super.init()
        
        self.clipsToBounds = true
        self.backgroundColor = .black
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self.imageNode.view.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        
        self.addSubnode(self.wrapperNode)
        self.addSubnode(self.statusNode)
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
    }
    
    var cropRect: CGRect? {
        guard let entry = self.entry else {
            return nil
        }
        switch entry {
            case .asset, .contextResult:
                return self.cropNode.cropRect
            default:
                return nil
        }
    }
    
    override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    fileprivate func setEntry(_ entry: WallpaperGalleryEntry) {
        if self.entry != entry {
            self.entry = entry
            
            let signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
            let fetchSignal: Signal<FetchResourceSourceType, FetchResourceError>
            let statusSignal: Signal<MediaResourceStatus, NoError>
            let displaySize: CGSize
            let contentSize: CGSize
            
            switch entry {
                case let .wallpaper(wallpaper):
                    switch wallpaper {
                        case .builtin:
                            displaySize = CGSize(width: 640.0, height: 1136.0)
                            contentSize = displaySize
                            signal = settingsBuiltinWallpaperImage(account: account)
                            fetchSignal = .complete()
                            statusSignal = .single(.Local)
                        case let .color(color):
                            displaySize = CGSize(width: 1.0, height: 1.0)
                            contentSize = displaySize
                            signal = .never()
                            fetchSignal = .complete()
                            statusSignal = .single(.Local)
                            self.backgroundColor = UIColor(rgb: UInt32(bitPattern: color))
                        case let .file(file):
                            let dimensions = file.file.dimensions ?? CGSize(width: 100.0, height: 100.0)
                            contentSize = dimensions
                            displaySize = dimensions.dividedByScreenScale().integralFloor
                            
                            var convertedRepresentations: [ImageRepresentationWithReference] = []
                            for representation in file.file.previewRepresentations {
                                convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: .standalone(resource: representation.resource)))
                            }
                            convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource), reference: .standalone(resource: file.file.resource)))
                            signal = chatMessageImageFile(account: account, fileReference: .standalone(media: file.file), thumbnail: false)
                            fetchSignal = fetchedMediaResource(postbox: account.postbox, reference: convertedRepresentations[convertedRepresentations.count - 1].reference)
                            statusSignal = account.postbox.mediaBox.resourceStatus(file.file.resource)
                        case let .image(representations):
                            if let largestSize = largestImageRepresentation(representations) {
                                contentSize = largestSize.dimensions
                                displaySize = largestSize.dimensions.dividedByScreenScale().integralFloor
                                
                                let convertedRepresentations: [ImageRepresentationWithReference] = representations.map({ ImageRepresentationWithReference(representation: $0, reference: .wallpaper(resource: $0.resource)) })
                                signal = chatAvatarGalleryPhoto(account: account, representations: convertedRepresentations)
                                
                                if let largestIndex = convertedRepresentations.index(where: { $0.representation == largestSize }) {
                                    fetchSignal = fetchedMediaResource(postbox: account.postbox, reference: convertedRepresentations[largestIndex].reference)
                                } else {
                                    fetchSignal = .complete()
                                }
                                statusSignal = account.postbox.mediaBox.resourceStatus(largestSize.resource)
                            } else {
                                displaySize = CGSize(width: 1.0, height: 1.0)
                                contentSize = displaySize
                                signal = .never()
                                fetchSignal = .complete()
                                statusSignal = .single(.Local)
                            }
                    }
                    self.cropNode.removeFromSupernode()
                case let .asset(asset, _):
                    let dimensions = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                    contentSize = dimensions
                    displaySize = dimensions.dividedByScreenScale().integralFloor
                    signal = photoWallpaper(postbox: account.postbox, photoLibraryResource: PhotoLibraryMediaResource(localIdentifier: asset.localIdentifier, uniqueId: arc4random64()))
                    fetchSignal = .complete()
                    statusSignal = .single(.Local)
                    self.wrapperNode.addSubnode(self.cropNode)
                case let .contextResult(result):
                    var imageDimensions: CGSize?
                    var imageResource: TelegramMediaResource?
                    var thumbnailDimensions: CGSize?
                    var thumbnailResource: TelegramMediaResource?
                    switch result {
                    case let .externalReference(_, _, _, _, _, _, content, thumbnail, _):
                        if let content = content {
                            imageResource = content.resource
                        }
                        if let thumbnail = thumbnail {
                            thumbnailResource = thumbnail.resource
                            thumbnailDimensions = thumbnail.dimensions
                        }
                        if let dimensions = content?.dimensions {
                            imageDimensions = dimensions
                        }
                    case let .internalReference(_, _, _, _, _, image, _, _):
                        if let image = image {
                            if let imageRepresentation = imageRepresentationLargerThan(image.representations, size: CGSize(width: 1000.0, height: 800.0)) {
                                imageDimensions = imageRepresentation.dimensions
                                imageResource = imageRepresentation.resource
                            }
                            if let thumbnailRepresentation = imageRepresentationLargerThan(image.representations, size: CGSize(width: 200.0, height: 100.0)) {
                                thumbnailDimensions = thumbnailRepresentation.dimensions
                                thumbnailResource = thumbnailRepresentation.resource
                            }
                        }
                    }
                    
                    if let imageResource = imageResource, let imageDimensions = imageDimensions {
                        contentSize = imageDimensions
                        displaySize = imageDimensions.dividedByScreenScale().integralFloor
                        
                        var representations: [TelegramMediaImageRepresentation] = []
                        if let thumbnailResource = thumbnailResource, let thumbnailDimensions = thumbnailDimensions {
                            representations.append(TelegramMediaImageRepresentation(dimensions: thumbnailDimensions, resource: thumbnailResource))
                        }
                        representations.append(TelegramMediaImageRepresentation(dimensions: imageDimensions, resource: imageResource))
                        let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil)
                        
                        signal = chatMessagePhoto(postbox: account.postbox, photoReference: .standalone(media: tmpImage))
                        fetchSignal = fetchedMediaResource(postbox: account.postbox, reference: .media(media: .standalone(media: tmpImage), resource: imageResource))
                        statusSignal = account.postbox.mediaBox.resourceStatus(imageResource)
                    } else {
                        displaySize = CGSize(width: 1.0, height: 1.0)
                        contentSize = displaySize
                        signal = .never()
                        fetchSignal = .complete()
                        statusSignal = .single(.Local)
                    }
                    self.wrapperNode.addSubnode(self.cropNode)
            }
            self.contentSize = contentSize
            
            if self.cropNode.supernode == nil {
                self.imageNode.contentMode = .scaleAspectFill
                self.wrapperNode.addSubnode(self.imageNode)
            } else {
                self.imageNode.contentMode = .scaleToFill
            }
            
            let imagePromise = Promise<UIImage?>()
            self.imageNode.setSignal(signal, dispatchOnDisplayLink: false)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
            self.imageNode.imageUpdated = { [weak self] image in
                if let strongSelf = self {
                    var image = image
                    if let scaledImage = image {
                        if scaledImage.size.width > 2048.0 || scaledImage.size.height > 2048.0 {
                            image = TGScaleImageToPixelSize(image, scaledImage.size.fitted(CGSize(width: 2048.0, height: 2048.0)))
                        }
                    }
                    strongSelf.blurredNode.image = image
                    imagePromise.set(.single(image))
                }
            }
            self.fetchDisposable.set(fetchSignal.start())
            
            let statusForegroundColor = UIColor.white
            self.statusDisposable.set((statusSignal
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    let state: RadialStatusNodeState
                    switch status {
                    case let .Fetching(_, progress):
                        let adjustedProgress = max(progress, 0.027)
                        state = .progress(color: statusForegroundColor, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: false)
                    case .Local:
                        state = .none
                    case .Remote:
                        state = .progress(color: statusForegroundColor, lineWidth: nil, value: 0.027, cancelEnabled: false)
                    }
                    strongSelf.statusNode.transitionToState(state, completion: {})
                }
            }))
            
            let controlsColorSignal: Signal<UIColor, NoError>
            if case let .wallpaper(wallpaper) = entry {
                controlsColorSignal = chatBackgroundContrastColor(wallpaper: wallpaper, postbox: account.postbox)
            } else {
                controlsColorSignal = backgroundContrastColor(for: imagePromise.get())
            }
            self.controlsColor.set(.single(.white) |> then(controlsColorSignal))
            self.status.set(statusSignal)
        }
    }
    
    func setParallaxEnabled(_ enabled: Bool) {
        if enabled {
            let amount = 24.0
            
            let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
            horizontal.minimumRelativeValue = -amount
            horizontal.maximumRelativeValue = amount
            
            let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
            vertical.minimumRelativeValue = -amount
            vertical.maximumRelativeValue = amount
            
            let group = UIMotionEffectGroup()
            group.motionEffects = [horizontal, vertical]
            self.wrapperNode.view.addMotionEffect(group)
        } else {
            for effect in self.imageNode.view.motionEffects {
                self.wrapperNode.view.removeMotionEffect(effect)
            }
        }
    }
    
    func setBlurEnabled(_ enabled: Bool, animated: Bool) {
        let blurRadius: CGFloat = 45.0
        
        if enabled {
            if self.blurredNode.supernode == nil {
                if self.cropNode.supernode != nil {
                    self.blurredNode.frame = self.imageNode.bounds
                    self.imageNode.addSubnode(self.blurredNode)
                } else {
                    self.blurredNode.frame = self.imageNode.frame
                    self.addSubnode(self.blurredNode)
                }
            }
            
            if animated {
                self.blurredNode.blurView.blurRadius = 0.0
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions(rawValue: 7 << 16), animations: {
                    self.blurredNode.blurView.blurRadius = blurRadius
                }, completion: nil)
            } else {
                self.blurredNode.blurView.blurRadius = blurRadius
            }
        } else {
            if self.blurredNode.supernode != nil {
                if animated {
                    UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions(rawValue: 7 << 16), animations: {
                        self.blurredNode.blurView.blurRadius = 0.0
                    }, completion: { finished in
                        if finished {
                            self.blurredNode.removeFromSupernode()
                        }
                    })
                } else {
                    self.blurredNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        self.wrapperNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        if self.cropNode.supernode == nil {
            self.imageNode.frame = self.wrapperNode.bounds
            self.blurredNode.frame = self.imageNode.frame
        } else {
            self.cropNode.frame = self.wrapperNode.bounds
            self.cropNode.containerLayoutUpdated(layout, transition: transition)
            
            if self.cropNode.supernode != nil, let contentSize = self.contentSize, self.cropNode.zoomableContent == nil {
                let fittedSize = TGScaleToFit(self.cropNode.bounds.size, contentSize)
                self.cropNode.zoomableContent = (contentSize, self.imageNode)
                self.cropNode.zoom(to: CGRect(x: (contentSize.width - fittedSize.width) / 2.0, y: (contentSize.height - fittedSize.height) / 2.0, width: fittedSize.width, height: fittedSize.height))
            }
            self.blurredNode.frame = self.imageNode.bounds
        }
        
        self.statusNode.frame = CGRect(x: layout.safeInsets.left + floorToScreenPixels((layout.size.width - layout.safeInsets.left - layout.safeInsets.right - progressDiameter) / 2.0), y: floorToScreenPixels((layout.size.height - progressDiameter) / 2.0), width: progressDiameter, height: progressDiameter)
    }
}
