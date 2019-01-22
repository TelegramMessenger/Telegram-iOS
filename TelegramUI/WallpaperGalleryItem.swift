import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents

private class WallpaperMotionEffect: UIInterpolatingMotionEffect {
    var previousValue: CGFloat?
    
    override func keyPathsAndRelativeValues(forViewerOffset viewerOffset: UIOffset) -> [String : Any]? {
        var motionAmplitude: CGFloat = 0.0
        switch self.type {
            case .tiltAlongHorizontalAxis:
                motionAmplitude = viewerOffset.horizontal
            case .tiltAlongVerticalAxis:
                motionAmplitude = viewerOffset.vertical
        }
        
        if (motionAmplitude > 0) {
            guard let max = (self.maximumRelativeValue as? CGFloat) else {
                return nil
            }
            let value = max * motionAmplitude
            return [self.keyPath: value]
        } else {
            guard let min = (self.minimumRelativeValue as? CGFloat) else {
                return nil
            }
            let value = -(min) * motionAmplitude
            return [self.keyPath: value]
        }
    }
}

class WallpaperGalleryItem: GalleryItem {
    let context: AccountContext
    let entry: WallpaperGalleryEntry
    
    init(context: AccountContext, entry: WallpaperGalleryEntry) {
        self.context = context
        self.entry = entry
    }
    
    func node() -> GalleryItemNode {
        let node = WallpaperGalleryItemNode(context: self.context)
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

private let progressDiameter: CGFloat = 50.0
private let motionAmount: CGFloat = 32.0

final class WallpaperGalleryItemNode: GalleryItemNode {
    private let context: AccountContext
    var entry: WallpaperGalleryEntry?
    private var contentSize: CGSize?
    
    let wrapperNode: ASDisplayNode
    let imageNode: TransformImageNode
    private let statusNode: RadialStatusNode
    private let progressNode: ASTextNode
    private let blurredNode: BlurredImageNode
    let cropNode: WallpaperCropNode
    
    private var blurButtonNode: WallpaperOptionButtonNode
    private var motionButtonNode: WallpaperOptionButtonNode
    
    fileprivate let _ready = Promise<Void>()
    private let fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private let colorDisposable = MetaDisposable()
    
    let subtitle = Promise<String?>(nil)
    let status = Promise<MediaResourceStatus>(.Local)
    let actionButton = Promise<UIBarButtonItem?>(nil)
    let controlsColor = Promise<UIColor>(UIColor(rgb: 0x000000, alpha: 0.3))
    var action: (() -> Void)?
    
    private var validLayout: ContainerViewLayout?
    private var validOffset: CGFloat?
    
    init(context: AccountContext) {
        self.context = context
        
        self.wrapperNode = ASDisplayNode()
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = .subsequentUpdates
        self.cropNode = WallpaperCropNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        self.statusNode.frame = CGRect(x: 0.0, y: 0.0, width: progressDiameter, height: progressDiameter)
        self.statusNode.isUserInteractionEnabled = false
        self.progressNode = ASTextNode()
        
        self.blurredNode = BlurredImageNode()
        
        let presentationData = context.currentPresentationData.with { $0 }
        self.blurButtonNode = WallpaperOptionButtonNode(title: presentationData.strings.WallpaperPreview_Blurred)
        self.motionButtonNode = WallpaperOptionButtonNode(title: presentationData.strings.WallpaperPreview_Motion)
        
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
        self.addSubnode(self.progressNode)
        
        self.addSubnode(self.blurButtonNode)
        self.addSubnode(self.motionButtonNode)
        
        self.blurButtonNode.addTarget(self, action: #selector(self.toggleBlur), forControlEvents: .touchUpInside)
        self.motionButtonNode.addTarget(self, action: #selector(self.toggleMotion), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
        self.colorDisposable.dispose()
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
    
    @objc private func actionPressed() {
        self.action?()
    }
    
    fileprivate func setEntry(_ entry: WallpaperGalleryEntry) {
        if self.entry != entry {
            self.entry = entry
            
            let signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
            let fetchSignal: Signal<FetchResourceSourceType, FetchResourceError>
            let statusSignal: Signal<MediaResourceStatus, NoError>
            let subtitleSignal: Signal<String?, NoError>
            var actionSignal: Signal<UIBarButtonItem?, NoError> = .single(nil)
            let displaySize: CGSize
            let contentSize: CGSize
            
            let presentationData = self.context.currentPresentationData.with { $0 }
            let defaultAction = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: presentationData.theme.rootController.navigationBar.accentTextColor), style: .plain, target: self, action: #selector(self.actionPressed))
            
            switch entry {
                case let .wallpaper(wallpaper):
                    switch wallpaper {
                        case .builtin:
                            displaySize = CGSize(width: 1308.0, height: 2688.0).fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                            contentSize = displaySize
                            signal = settingsBuiltinWallpaperImage(account: context.account)
                            fetchSignal = .complete()
                            statusSignal = .single(.Local)
                            subtitleSignal = .single(nil)
                        case let .color(color):
                            displaySize = CGSize(width: 1.0, height: 1.0)
                            contentSize = displaySize
                            signal = .never()
                            fetchSignal = .complete()
                            statusSignal = .single(.Local)
                            subtitleSignal = .single(nil)
                            self.backgroundColor = UIColor(rgb: UInt32(bitPattern: color))
                            actionSignal = .single(defaultAction)
                        case let .file(file):
                            let dimensions = file.file.dimensions ?? CGSize(width: 100.0, height: 100.0)
                            contentSize = dimensions
                            displaySize = dimensions.dividedByScreenScale().integralFloor
                            
                            var convertedRepresentations: [ImageRepresentationWithReference] = []
                            for representation in file.file.previewRepresentations {
                                convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: .wallpaper(resource: representation.resource)))
                            }
                            convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource), reference: .wallpaper(resource: file.file.resource)))
                            signal = chatAvatarGalleryPhoto(account: context.account, fileReference: .standalone(media: file.file), representations: convertedRepresentations, alwaysShowThumbnailFirst: true, autoFetchFullSize: false)
                            fetchSignal = fetchedMediaResource(postbox: context.account.postbox, reference: convertedRepresentations[convertedRepresentations.count - 1].reference)
                            statusSignal = context.account.postbox.mediaBox.resourceStatus(file.file.resource)
                            if let fileSize = file.file.size {
                                subtitleSignal = .single(dataSizeString(fileSize))
                            } else {
                                subtitleSignal = .single(nil)
                            }
                            actionSignal = .single(defaultAction)
                        case let .image(representations):
                            if let largestSize = largestImageRepresentation(representations) {
                                contentSize = largestSize.dimensions
                                displaySize = largestSize.dimensions.dividedByScreenScale().integralFloor
                                
                                let convertedRepresentations: [ImageRepresentationWithReference] = representations.map({ ImageRepresentationWithReference(representation: $0, reference: .wallpaper(resource: $0.resource)) })
                                signal = chatAvatarGalleryPhoto(account: context.account, representations: convertedRepresentations)
                                
                                if let largestIndex = convertedRepresentations.index(where: { $0.representation == largestSize }) {
                                    fetchSignal = fetchedMediaResource(postbox: context.account.postbox, reference: convertedRepresentations[largestIndex].reference)
                                } else {
                                    fetchSignal = .complete()
                                }
                                statusSignal = context.account.postbox.mediaBox.resourceStatus(largestSize.resource)
                            } else {
                                displaySize = CGSize(width: 1.0, height: 1.0)
                                contentSize = displaySize
                                signal = .never()
                                fetchSignal = .complete()
                                statusSignal = .single(.Local)
                            }
                            subtitleSignal = .single(nil)
                    }
                    self.cropNode.removeFromSupernode()
                case let .asset(asset):
                    let dimensions = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                    contentSize = dimensions
                    displaySize = dimensions.dividedByScreenScale().integralFloor
                    signal = photoWallpaper(postbox: context.account.postbox, photoLibraryResource: PhotoLibraryMediaResource(localIdentifier: asset.localIdentifier, uniqueId: arc4random64()))
                    fetchSignal = .complete()
                    statusSignal = .single(.Local)
                    subtitleSignal = .single(nil)
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
                        
                        signal = chatMessagePhoto(postbox: context.account.postbox, photoReference: .standalone(media: tmpImage))
                        fetchSignal = fetchedMediaResource(postbox: context.account.postbox, reference: .media(media: .standalone(media: tmpImage), resource: imageResource))
                        statusSignal = context.account.postbox.mediaBox.resourceStatus(imageResource)
                    } else {
                        displaySize = CGSize(width: 1.0, height: 1.0)
                        contentSize = displaySize
                        signal = .never()
                        fetchSignal = .complete()
                        statusSignal = .single(.Local)
                    }
                    subtitleSignal = .single(nil)
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
                            strongSelf.progressNode.attributedText = NSAttributedString(string: "\(Int(progress * 100))%", font: Font.medium(13), textColor: .white, paragraphAlignment: .center)
                        case .Local:
                            state = .none
                            strongSelf.progressNode.attributedText = nil
                        case .Remote:
                            state = .progress(color: statusForegroundColor, lineWidth: nil, value: 0.027, cancelEnabled: false)
                            strongSelf.progressNode.attributedText = nil
                    }
                    strongSelf.statusNode.transitionToState(state, completion: {})
                }
            }))
            
            self.subtitle.set(subtitleSignal |> deliverOnMainQueue)
            self.status.set(statusSignal |> deliverOnMainQueue)
            self.actionButton.set(actionSignal |> deliverOnMainQueue)
            self.controlsColor.set(serviceColor(from: imagePromise.get()) |> deliverOnMainQueue)
            self.colorDisposable.set((serviceColor(from: imagePromise.get())
            |> deliverOnMainQueue).start(next: { [weak self] color in
                self?.blurButtonNode.color = color
                self?.motionButtonNode.color = color
            }))
        }
    }
    
    override func screenFrameUpdated(_ frame: CGRect) {
        let offset = -frame.minX
        self.validOffset = offset
        if let layout = self.validLayout {
            self.updateButtonsLayout(layout: layout, offset: CGPoint(x: offset, y: 0.0), transition: .immediate)
        }
    }
    
    func updateDismissTransition(_ value: CGFloat) {
        if let layout = self.validLayout {
            self.updateButtonsLayout(layout: layout, offset: CGPoint(x: 0.0, y: value), transition: .immediate)
        }
    }
    
    var options: WallpaperPresentationOptions {
        get {
            var options: WallpaperPresentationOptions = []
            if self.blurButtonNode.isSelected {
                options.insert(.blur)
            }
            if self.motionButtonNode.isSelected {
                options.insert(.motion)
            }
            return options
        }
        set {
            self.setBlurEnabled(newValue.contains(.blur), animated: false)
            self.blurButtonNode.isSelected = newValue.contains(.blur)
            
            self.setMotionEnabled(newValue.contains(.motion), animated: false)
            self.motionButtonNode.isSelected = newValue.contains(.motion)
        }
    }
    
    @objc func toggleBlur() {
        let value = !self.blurButtonNode.isSelected
        self.blurButtonNode.setSelected(value, animated: true)
        self.setBlurEnabled(value, animated: true)
    }
    
    func setBlurEnabled(_ enabled: Bool, animated: Bool) {
        let blurRadius: CGFloat = 45.0
        
        if enabled {
            if self.blurredNode.supernode == nil {
                if self.cropNode.supernode != nil {
                    self.blurredNode.frame = self.imageNode.bounds
                    self.imageNode.addSubnode(self.blurredNode)
                } else {
                    self.blurredNode.frame = self.imageNode.bounds
                    self.imageNode.addSubnode(self.blurredNode)
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
    
    @objc func toggleMotion() {
        let value = !self.motionButtonNode.isSelected
        self.motionButtonNode.setSelected(value, animated: true)
        self.setMotionEnabled(value, animated: true)
    }
    
    func setMotionEnabled(_ enabled: Bool, animated: Bool) {
        if enabled {
            let horizontal = WallpaperMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
            horizontal.minimumRelativeValue = motionAmount
            horizontal.maximumRelativeValue = -motionAmount
            
            let vertical = WallpaperMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
            vertical.minimumRelativeValue = motionAmount
            vertical.maximumRelativeValue = -motionAmount
            
            let group = UIMotionEffectGroup()
            group.motionEffects = [horizontal, vertical]
            self.wrapperNode.view.addMotionEffect(group)
            
            let scale = (self.frame.width + motionAmount * 2.0) / self.frame.width
            if animated {
                self.wrapperNode.layer.animateScale(from: 1.0, to: scale, duration: 0.2, removeOnCompletion: false)
            } else {
                self.wrapperNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
            }
        } else {
            let position = self.wrapperNode.layer.presentation()?.position
            
            for effect in self.wrapperNode.view.motionEffects {
                self.wrapperNode.view.removeMotionEffect(effect)
            }
            
            let scale = (self.frame.width + motionAmount * 2.0) / self.frame.width
            if animated {
                self.wrapperNode.layer.animateScale(from: scale, to: 1.0, duration: 0.2, removeOnCompletion: false)
                if let position = position {
                    self.wrapperNode.layer.animatePosition(from: position, to: self.wrapperNode.layer.position, duration: 0.2)
                }
            } else {
                self.wrapperNode.transform = CATransform3DIdentity
            }
        }
    }
    
    func updateButtonsLayout(layout: ContainerViewLayout, offset: CGPoint, transition: ContainedViewLayoutTransition) {
        let buttonSize = CGSize(width: 100.0, height: 30.0)
        let alpha = 1.0 - min(1.0, max(0.0, abs(offset.y) / 50.0))
        
        transition.updateFrame(node: self.blurButtonNode, frame: CGRect(origin: CGPoint(x: floor(layout.size.width / 2.0 - buttonSize.width - 10.0) + offset.x, y: layout.size.height - 49.0 - layout.intrinsicInsets.bottom - 54.0 + offset.y), size: buttonSize))
        transition.updateAlpha(node: self.blurButtonNode, alpha: alpha)
        
        transition.updateFrame(node: self.motionButtonNode, frame: CGRect(origin: CGPoint(x: ceil(layout.size.width / 2.0 + 10.0) + offset.x, y: layout.size.height - 49.0 - layout.intrinsicInsets.bottom - 54.0 + offset.y), size: buttonSize))
        transition.updateAlpha(node: self.motionButtonNode, alpha: alpha)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        self.wrapperNode.bounds = CGRect(origin: CGPoint(), size: layout.size)
        self.wrapperNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
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
        self.progressNode.frame = CGRect(x: layout.safeInsets.left + floorToScreenPixels((layout.size.width - layout.safeInsets.left - layout.safeInsets.right - progressDiameter) / 2.0), y: floorToScreenPixels((layout.size.height - 15.0) / 2.0), width: progressDiameter, height: progressDiameter)
        
        var offset: CGFloat = 0.0
        if let validOffset = self.validOffset {
            offset = validOffset
        }
        self.updateButtonsLayout(layout: layout, offset: CGPoint(x: offset, y: 0.0), transition: transition)
        
        self.validLayout = layout
    }
}
