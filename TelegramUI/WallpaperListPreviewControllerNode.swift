import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Photos
import LegacyComponents

enum WallpaperEntry: Equatable {
    case wallpaper(TelegramWallpaper)
    case asset(PHAsset, UIImage?)
    case contextResult(ChatContextResult)
    
    public static func ==(lhs: WallpaperEntry, rhs: WallpaperEntry) -> Bool {
        switch lhs {
            case let .wallpaper(wallpaper):
                if case .wallpaper(wallpaper) = rhs {
                    return true
                } else {
                    return false
                }
            case let .asset(lhsAsset, _):
                if case let .asset(rhsAsset, _) = rhs, lhsAsset.localIdentifier == rhsAsset.localIdentifier {
                    return true
                } else {
                    return false
                }
            case let .contextResult(lhsResult):
                if case let .contextResult(rhsResult) = rhs, lhsResult.id == rhsResult.id {
                    return true
                } else {
                    return false
                }
        }
    }
}

private final class WallpaperBackgroundNode: ASDisplayNode {
    let wallpaper: WallpaperEntry
    private var fetchDisposable: Disposable?
    private var statusDisposable: Disposable?
    let wrapperNode: ASDisplayNode
    let imageNode: TransformImageNode
    let cropNode: WallpaperCropNode
    private var contentSize: CGSize?
    
    private let statusNode: RadialStatusNode
    private let blurredNode: BlurredImageNode
    
    let controlsColor = Promise<UIColor>(.white)
    let status = Promise<MediaResourceStatus>(.Local)
    
    init(account: Account, wallpaper: WallpaperEntry) {
        self.wallpaper = wallpaper
        self.wrapperNode = ASDisplayNode()
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = .subsequentUpdates
        
        self.cropNode = WallpaperCropNode()
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        let progressDiameter: CGFloat = 50.0
        self.statusNode.frame = CGRect(x: 0.0, y: 0.0, width: progressDiameter, height: progressDiameter)
        self.statusNode.isUserInteractionEnabled = false
        
        self.blurredNode = BlurredImageNode()
        
        super.init()
        
        self.clipsToBounds = true
        self.backgroundColor = .black
        
        let signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
        let fetchSignal: Signal<FetchResourceSourceType, FetchResourceError>
        let statusSignal: Signal<MediaResourceStatus, NoError>
        let displaySize: CGSize
        let contentSize: CGSize
        switch wallpaper {
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
        
        self.addSubnode(self.wrapperNode)
        if self.cropNode.supernode == nil {
            self.imageNode.contentMode = .scaleAspectFill
            self.wrapperNode.addSubnode(self.imageNode)
        }
        self.wrapperNode.addSubnode(self.statusNode)
        
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
        self.fetchDisposable = fetchSignal.start()
        
        let statusForegroundColor = UIColor.white
        self.statusDisposable = (statusSignal
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
        })
        
        let controlsColorSignal: Signal<UIColor, NoError>
        if case let .wallpaper(wallpaper) = wallpaper {
            controlsColorSignal = chatBackgroundContrastColor(wallpaper: wallpaper, postbox: account.postbox)
        } else {
            controlsColorSignal = backgroundContrastColor(for: imagePromise.get())
        }
        self.controlsColor.set(.single(.white) |> then(controlsColorSignal))
        self.status.set(statusSignal)
    }
    
    deinit {
        self.fetchDisposable?.dispose()
        self.statusDisposable?.dispose()
    }
    
    var cropRect: CGRect? {
        switch self.wallpaper {
            case .asset, .contextResult:
                return self.cropNode.cropRect
            default:
                return nil
        }
    }
    
    func setParallaxEnabled(_ enabled: Bool) {
        if enabled {
            let amount = 16.0
            
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
    
    func updateLayout(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
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
                self.cropNode.scrollNode.view.zoom(to: CGRect(x: (contentSize.width - fittedSize.width) / 2.0, y: (contentSize.height - fittedSize.height) / 2.0, width: fittedSize.width, height: fittedSize.height), animated: false)
            }
            self.blurredNode.frame = self.imageNode.bounds
        }
        
        let progressDiameter: CGFloat = 50.0
        self.statusNode.frame = CGRect(x: layout.safeInsets.left + floorToScreenPixels((layout.size.width - layout.safeInsets.left - layout.safeInsets.right - progressDiameter) / 2.0), y: floorToScreenPixels((layout.size.height - progressDiameter) / 2.0), width: progressDiameter, height: progressDiameter)
    }
}

final class WallpaperListPreviewControllerNode: ViewControllerTracingNode {
    private let account: Account
    private var presentationData: PresentationData
    private let source: WallpaperListPreviewSource
    private let dismiss: () -> Void
    private let apply: (WallpaperEntry, PresentationWallpaperMode, CGRect?) -> Void
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let toolbarBackground: ASDisplayNode
    private let toolbarSeparator: ASDisplayNode
    private let toolbarVerticalSeparator: ASDisplayNode
    private let toolbarButtonCancel: HighlightTrackingButtonNode
    private let toolbarButtonCancelBackground: ASDisplayNode
    private let toolbarButtonApply: HighlightTrackingButtonNode
    private let toolbarButtonApplyBackground: ASDisplayNode
    
    private let segmentedControl: UISegmentedControl
    private var segmentedControlColor = Promise<UIColor>(.white)
    private var segmentedControlColorDisposable: Disposable?
    
    private var status = Promise<MediaResourceStatus>(.Local)
    private var statusDisposable: Disposable?
    
    private var wallpapersDisposable: Disposable?
    private var wallpapers: [WallpaperEntry]?
    let ready = ValuePromise<Bool>(false)
    
    private var messageNodes: [ListViewItemNode]?
    
    private var visibleBackgroundNodes: [WallpaperBackgroundNode] = []
    private var centralWallpaper: WallpaperEntry?
    
    private let currentWallpaperPromise = Promise<WallpaperEntry>()
    var currentWallpaper: Signal<WallpaperEntry, NoError> {
        return self.currentWallpaperPromise.get()
    }
    private var visibleBackgroundNodesOffset: CGFloat = 0.0
    
    init(account: Account, presentationData: PresentationData, source: WallpaperListPreviewSource, dismiss: @escaping () -> Void, apply: @escaping (WallpaperEntry, PresentationWallpaperMode, CGRect?) -> Void) {
        self.account = account
        self.presentationData = presentationData
        self.source = source
        self.dismiss = dismiss
        self.apply = apply
        
        self.toolbarBackground = ASDisplayNode()
        self.toolbarBackground.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        
        self.toolbarSeparator = ASDisplayNode()
        self.toolbarSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.toolbarVerticalSeparator = ASDisplayNode()
        self.toolbarVerticalSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.toolbarButtonCancelBackground = ASDisplayNode()
        self.toolbarButtonCancelBackground.alpha = 0.0
        self.toolbarButtonCancelBackground.backgroundColor = self.presentationData.theme.list.itemHighlightedBackgroundColor
        self.toolbarButtonCancelBackground.isUserInteractionEnabled = false
        
        self.toolbarButtonCancel = HighlightTrackingButtonNode()
        self.toolbarButtonCancel.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Common_Cancel, font: Font.regular(17.0), textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor), for: [])
        
        self.toolbarButtonApplyBackground = ASDisplayNode()
        self.toolbarButtonApplyBackground.alpha = 0.0
        self.toolbarButtonApplyBackground.backgroundColor = self.presentationData.theme.list.itemHighlightedBackgroundColor
        self.toolbarButtonApplyBackground.isUserInteractionEnabled = false
        
        self.toolbarButtonApply = HighlightTrackingButtonNode()
        self.toolbarButtonApply.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Wallpaper_Set, font: Font.regular(17.0), textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor), for: [])
        
        self.segmentedControl = UISegmentedControl(items: [self.presentationData.strings.WallpaperPreview_Still, self.presentationData.strings.WallpaperPreview_Perspective, self.presentationData.strings.WallpaperPreview_Blurred])
        self.segmentedControl.selectedSegmentIndex = 0
        self.segmentedControl.tintColor = .white
        
        super.init()
        
        self.backgroundColor = .black
        
        self.addSubnode(self.toolbarBackground)
        self.addSubnode(self.toolbarSeparator)
        self.addSubnode(self.toolbarVerticalSeparator)
        self.addSubnode(self.toolbarButtonCancel)
        self.addSubnode(self.toolbarButtonApply)
        
        self.view.addSubview(self.segmentedControl)
        
        self.toolbarButtonCancel.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.toolbarButtonApply.addTarget(self, action: #selector(self.applyPressed), forControlEvents: .touchUpInside)
        
        self.toolbarButtonCancel.highligthedChanged = { [weak self] value in
            if let strongSelf = self {
                if value {
                    if strongSelf.toolbarButtonCancelBackground.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.toolbarButtonCancelBackground, aboveSubnode: strongSelf.toolbarVerticalSeparator)
                    }
                    strongSelf.toolbarButtonCancelBackground.layer.removeAnimation(forKey: "opacity")
                    strongSelf.toolbarButtonCancelBackground.alpha = 1.0
                } else if !strongSelf.toolbarButtonCancelBackground.alpha.isZero {
                    strongSelf.toolbarButtonCancelBackground.alpha = 0.0
                    strongSelf.toolbarButtonCancelBackground.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                }
            }
        }
        
        self.toolbarButtonApply.highligthedChanged = { [weak self] value in
            if let strongSelf = self {
                if value {
                    if strongSelf.toolbarButtonApplyBackground.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.toolbarButtonApplyBackground, aboveSubnode: strongSelf.toolbarVerticalSeparator)
                    }
                    strongSelf.toolbarButtonApplyBackground.layer.removeAnimation(forKey: "opacity")
                    strongSelf.toolbarButtonApplyBackground.alpha = 1.0
                } else if !strongSelf.toolbarButtonApplyBackground.alpha.isZero {
                    strongSelf.toolbarButtonApplyBackground.alpha = 0.0
                    strongSelf.toolbarButtonApplyBackground.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                }
            }
        }
        
        self.segmentedControl.addTarget(self, action: #selector(self.indexChanged), for: .valueChanged)
        self.segmentedControlColorDisposable = (self.segmentedControlColor.get()
        |> deliverOnMainQueue).start(next: { [weak self] color in
            if let strongSelf = self {
                strongSelf.segmentedControl.tintColor = color
            }
        })
        
        self.statusDisposable = (self.status.get()
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                switch status {
                    case .Local:
                        strongSelf.toolbarButtonApply.isEnabled = true
                        strongSelf.toolbarButtonApply.alpha = 1.0
                    default:
                        strongSelf.toolbarButtonApply.isEnabled = false
                        strongSelf.toolbarButtonApply.alpha = 0.3
                }
            }
        })
        
        switch source {
            case let .list(wallpapers, central, type):
                self.wallpapers = wallpapers.map { .wallpaper($0) }
                self.centralWallpaper = WallpaperEntry.wallpaper(central)
                self.ready.set(true)
            
                if case let .wallpapers(wallpaperMode) = type, let mode = wallpaperMode {
                    self.segmentedControl.selectedSegmentIndex = Int(clamping: mode.rawValue)
                }
            case let .slug(slug, file):
                if let file = file {
                    let entry = WallpaperEntry.wallpaper(.file(id: 0, accessHash: 0, isCreator: false, slug: slug, file: file, color: nil))
                    self.wallpapers = [entry]
                    self.centralWallpaper = entry
                }
                self.ready.set(true)
            case let .wallpaper(wallpaper):
                let entry = WallpaperEntry.wallpaper(wallpaper)
                self.wallpapers = [entry]
                self.centralWallpaper = entry
                self.ready.set(true)
            case let .asset(asset, thumbnailImage):
                let entry = WallpaperEntry.asset(asset, thumbnailImage)
                self.wallpapers = [entry]
                self.centralWallpaper = entry
                self.ready.set(true)
            case let .contextResult(result):
                let entry = WallpaperEntry.contextResult(result)
                self.wallpapers = [entry]
                self.centralWallpaper = entry
                self.ready.set(true)
            case .customColor:
                self.ready.set(true)
        }
        if let (layout, navigationHeight) = self.validLayout {
            self.updateVisibleBackgroundNodes(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
        if let wallpaper = self.centralWallpaper {
            self.currentWallpaperPromise.set(.single(wallpaper))
        }
    }
    
    deinit {
        self.wallpapersDisposable?.dispose()
        self.segmentedControlColorDisposable?.dispose()
        self.statusDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.toolbarBackground.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.toolbarSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.toolbarVerticalSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.toolbarButtonCancel.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Common_Cancel, font: Font.regular(17.0), textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor), for: [])
        self.toolbarButtonApply.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Wallpaper_Set, font: Font.regular(17.0), textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor), for: [])
        self.toolbarButtonCancelBackground.backgroundColor = self.presentationData.theme.list.itemHighlightedBackgroundColor
        self.toolbarButtonApplyBackground.backgroundColor = self.presentationData.theme.list.itemHighlightedBackgroundColor
        
        self.backgroundColor = .black
        if let (layout, navigationHeight) = self.validLayout {
            self.updateVisibleBackgroundNodes(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                break
            case .cancelled, .ended:
                break
            default:
                break
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self] _ in
            if let strongSelf = self, strongSelf.segmentedControl.selectedSegmentIndex == 2 {
                strongSelf.centralNode()?.setBlurEnabled(true, animated: true)
            }
        })
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var items: [ChatMessageItem] = []
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 1)
        let otherPeerId = self.account.peerId
        var peers = SimpleDictionary<PeerId, Peer>()
        let messages = SimpleDictionary<MessageId, Message>()
        peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_PreviewReplyAuthor, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        peers[otherPeerId] = TelegramUser(id: otherPeerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_PreviewReplyAuthor, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let controllerInteraction = ChatControllerInteraction(openMessage: { _, _ in
            return false }, openPeer: { _, _, _ in }, openPeerMention: { _ in }, openMessageContextMenu: { _, _, _, _ in }, navigateToMessage: { _, _ in }, clickThroughMessage: { }, toggleMessagesSelection: { _, _ in }, sendMessage: { _ in }, sendSticker: { _, _ in }, sendGif: { _ in }, requestMessageActionCallback: { _, _, _ in }, activateSwitchInline: { _, _ in }, openUrl: { _, _, _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _ in  }, openWallpaper: { _ in  }, openHashtag: { _, _ in }, updateInputState: { _ in }, updateInputMode: { _ in }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in }, navigationController: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _ in }, longTap: { _ in }, openCheckoutOrReceipt: { _ in }, openSearch: { }, setupReply: { _ in
        }, canSetupReply: { _ in
            return false
        }, navigateToFirstDateMessage: { _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _ in
        }, requestSelectMessagePollOption: { _, _ in
        }, openAppStorePage: {
        }, requestMessageUpdate: { _ in
        }, cancelInteractiveKeyboardGestures: {
        }, automaticMediaDownloadSettings: AutomaticMediaDownloadSettings.defaultSettings,
           pollActionState: ChatInterfacePollActionState())
        
        let chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: self.presentationData.theme, wallpaper: self.presentationData.chatWallpaper), fontSize: self.presentationData.fontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: false)
        
        let topMessageText: String = ""
        let bottomMessageText: String = ""
//        switch self.source {
//            case .wallpaper, .slug:
//                topMessageText = presentationData.strings.WallpaperPreview_PreviewTopText
//                bottomMessageText = presentationData.strings.WallpaperPreview_PreviewBottomText
//            case let .list(_, _, type):
//                switch type {
//                    case .wallpapers:
//                        topMessageText = presentationData.strings.WallpaperPreview_SwipeTopText
//                        bottomMessageText = presentationData.strings.WallpaperPreview_SwipeBottomText
//                    case .colors:
//                        topMessageText = presentationData.strings.WallpaperPreview_SwipeColorsTopText
//                        bottomMessageText = presentationData.strings.WallpaperPreview_SwipeColorsBottomText
//                }
//            case .asset, .contextResult:
//                topMessageText = presentationData.strings.WallpaperPreview_CropTopText
//                bottomMessageText = presentationData.strings.WallpaperPreview_CropBottomText
//            case .customColor:
//                topMessageText = presentationData.strings.WallpaperPreview_CustomColorTopText
//                bottomMessageText = presentationData.strings.WallpaperPreview_CustomColorBottomText
//        }
        
        items.append(ChatMessageItem(presentationData: chatPresentationData, account: self.account, chatLocation: .peer(peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false), controllerInteraction: controllerInteraction, content: .message(message: Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 2), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66001, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: topMessageText, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), read: true, selection: .none, isAdmin: false), disableDate: true))
        
        items.append(ChatMessageItem(presentationData: chatPresentationData, account: self.account, chatLocation: .peer(peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false), controllerInteraction: controllerInteraction, content: .message(message: Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: bottomMessageText, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), read: true, selection: .none, isAdmin: false), disableDate: true))
        
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right)
        if let messageNodes = self.messageNodes {
            for i in 0 ..< items.count {
                let itemNode = messageNodes[i]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: layout.size.width, height: layout.size.height))
                    
                    itemNode.contentSize = layout.contentSize
                    itemNode.insets = layout.insets
                    itemNode.frame = nodeFrame
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            }
        } else {
            var messageNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                var itemNode: ListViewItemNode?
                items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                itemNode!.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
                messageNodes.append(itemNode!)
                self.addSubnode(itemNode!)
            }
            self.messageNodes = messageNodes
        }
        
        let bottomInset = layout.intrinsicInsets.bottom + 49.0
        transition.updateFrame(node: self.toolbarBackground, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset), size: CGSize(width: layout.size.width, height: bottomInset)))
        transition.updateFrame(node: self.toolbarSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.toolbarVerticalSeparator, frame: CGRect(origin: CGPoint(x: floor(layout.size.width / 2.0), y: layout.size.height - bottomInset), size: CGSize(width: UIScreenPixel, height: bottomInset)))
        
        let cancelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset), size: CGSize(width: floor(layout.size.width / 2.0), height: 49.0))
        transition.updateFrame(node: self.toolbarButtonCancel, frame: cancelFrame)
        transition.updateFrame(node: self.toolbarButtonCancelBackground, frame: cancelFrame)
        
        let applyFrame = CGRect(origin: CGPoint(x: floor(layout.size.width / 2.0), y: layout.size.height - bottomInset), size: CGSize(width: ceil(layout.size.width / 2.0), height: 49.0))
        transition.updateFrame(node: self.toolbarButtonApply, frame: applyFrame)
        transition.updateFrame(node: self.toolbarButtonApplyBackground, frame: applyFrame)
        
        var optionsAvailable = true
        if let centralWallpaper = centralWallpaper {
            switch centralWallpaper {
                case let .wallpaper(wallpaper):
                    switch wallpaper {
                        case .color:
                            optionsAvailable = false
                        default:
                            break
                    }
                default:
                    break
            }
        }
        
        var segmentedControlSize = self.segmentedControl.sizeThatFits(layout.size)
        segmentedControlSize.width = max(270.0, segmentedControlSize.width)
        
        self.segmentedControl.isUserInteractionEnabled = optionsAvailable
        transition.updateAlpha(layer: self.segmentedControl.layer, alpha: optionsAvailable ? 1.0 : 0.0)
        transition.updateFrame(view: self.segmentedControl, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layout.size.width - layout.safeInsets.left - layout.safeInsets.right - segmentedControlSize.width) / 2.0), y: layout.size.height - bottomInset - segmentedControlSize.height - 24.0), size: segmentedControlSize))
        
        if let messageNodes = self.messageNodes {
            var bottomOffset: CGFloat = layout.size.height - bottomInset - 9.0
            if optionsAvailable {
                bottomOffset -= segmentedControlSize.height + 37.0
            }
            for itemNode in messageNodes {
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: bottomOffset - itemNode.frame.height), size: itemNode.frame.size))
                bottomOffset -= itemNode.frame.height
            }
        }
        
        self.updateVisibleBackgroundNodes(layout: layout, navigationBarHeight: navigationBarHeight, transition: transition)
    }
    
    private func updateVisibleBackgroundNodes(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var visibleBackgroundNodes: [WallpaperBackgroundNode] = []
        if let wallpapers = self.wallpapers, let centralWallpaper = self.centralWallpaper {
            outer: for i in 0 ..< wallpapers.count {
                if wallpapers[i] == centralWallpaper {
                    for j in max(0, i - 1) ... min(i + 1, wallpapers.count - 1) {
                        let itemPostition = j - i
                        let itemFrame = CGRect(origin: CGPoint(x: CGFloat(itemPostition) * layout.size.width, y: 0.0), size: layout.size)
                        var currentItemNode: WallpaperBackgroundNode?
                        inner: for current in self.visibleBackgroundNodes {
                            if current.wallpaper == wallpapers[j] {
                                currentItemNode = current
                                break inner
                            }
                        }
                        let itemNode = currentItemNode ?? WallpaperBackgroundNode(account: self.account, wallpaper: wallpapers[j])
                        visibleBackgroundNodes.append(itemNode)
                        let itemNodeTransition: ContainedViewLayoutTransition
                        if itemNode.supernode == nil {
                            self.insertSubnode(itemNode, at: 0)
                            itemNodeTransition = .immediate
                        } else {
                            itemNodeTransition = transition
                        }
                        
                        if j == i {
                            self.segmentedControlColor.set(itemNode.controlsColor.get())
                            self.status.set(itemNode.status.get())
                        }
                        
                        itemNodeTransition.updateFrame(node: itemNode, frame: itemFrame)
                        itemNode.updateLayout(layout, navigationHeight: navigationBarHeight, transition: itemNodeTransition)
                        visibleBackgroundNodes.append(itemNode)
                    }
                    break outer
                }
            }
        }
        
        for itemNode in self.visibleBackgroundNodes {
            var found = false
            inner: for updatedItemNode in visibleBackgroundNodes {
                if itemNode === updatedItemNode {
                    found = true
                    break
                }
            }
            if !found {
                itemNode.removeFromSupernode()
            }
        }
        self.visibleBackgroundNodes = visibleBackgroundNodes
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let (layout, _) = self.validLayout {
            let additionalButtonHeight = layout.intrinsicInsets.bottom
            
            if self.toolbarButtonCancel.isEnabled {
                var buttonFrame = self.toolbarButtonCancel.frame
                buttonFrame.size.height += additionalButtonHeight
                if buttonFrame.contains(point) {
                    return self.toolbarButtonCancel.view
                }
            }
            if self.toolbarButtonApply.isEnabled {
                var buttonFrame = self.toolbarButtonApply.frame
                buttonFrame.size.height += additionalButtonHeight
                if buttonFrame.contains(point) {
                    return self.toolbarButtonApply.view
                }
            }
        }
        return super.hitTest(point, with: event)
    }
    
    private func centralNode() -> WallpaperBackgroundNode? {
        for node in self.visibleBackgroundNodes {
            if node.wallpaper == self.centralWallpaper {
                return node
            }
        }
        return nil
    }
    
    @objc private func indexChanged() {
        guard let mode = PresentationWallpaperMode(rawValue: Int32(self.segmentedControl.selectedSegmentIndex)) else {
            return
        }
        
        if let node = self.centralNode() {
            if mode == .perspective {
                node.setParallaxEnabled(true)
                node.setBlurEnabled(false, animated: true)
            } else if mode == .blurred {
                node.setParallaxEnabled(false)
                node.setBlurEnabled(true, animated: true)
            } else {
                node.setParallaxEnabled(false)
                node.setBlurEnabled(false, animated: true)
            }
        }
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func applyPressed() {
        if let wallpaper = self.centralWallpaper {
            let mode: PresentationWallpaperMode
            switch self.segmentedControl.selectedSegmentIndex {
                case 1:
                    mode = .perspective
                case 2:
                    mode = .blurred
                default:
                    mode = .still
            }
            self.apply(wallpaper, mode, self.centralNode()?.cropRect)
        }
    }
}
