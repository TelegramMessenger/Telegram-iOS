import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import ProgressNavigationButtonNode
import MediaResources
import AccountContext
import RadialStatusNode
import PhotoResources
import GalleryUI
import LocalMediaResources
import WallpaperResources
import AppBundle
import WallpaperBackgroundNode

struct WallpaperGalleryItemArguments {
    let colorPreview: Bool
    let isColorsList: Bool
    let patternEnabled: Bool
    
    init(colorPreview: Bool = false, isColorsList: Bool = false, patternEnabled: Bool = false) {
        self.colorPreview = colorPreview
        self.isColorsList = isColorsList
        self.patternEnabled = patternEnabled
    }
}

class WallpaperGalleryItem: GalleryItem {
    var id: AnyHashable {
        return self.index
    }
    
    let index: Int
    
    let context: AccountContext
    let entry: WallpaperGalleryEntry
    let arguments: WallpaperGalleryItemArguments
    let source: WallpaperListSource
    
    init(context: AccountContext, index: Int, entry: WallpaperGalleryEntry, arguments: WallpaperGalleryItemArguments, source: WallpaperListSource) {
        self.context = context
        self.index = index
        self.entry = entry
        self.arguments = arguments
        self.source = source
    }
    
    func node(synchronous: Bool) -> GalleryItemNode {
        let node = WallpaperGalleryItemNode(context: self.context)
        node.setEntry(self.entry, arguments: self.arguments, source: self.source)
        return node
    }
    
    func updateNode(node: GalleryItemNode, synchronous: Bool) {
        if let node = node as? WallpaperGalleryItemNode {
            node.setEntry(self.entry, arguments: self.arguments, source: self.source)
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        return nil
    }
}

private let progressDiameter: CGFloat = 50.0
private let motionAmount: CGFloat = 32.0

private func reference(for resource: MediaResource, media: Media, message: Message?, slug: String?) -> MediaResourceReference {
    if let message = message {
        return .media(media: .message(message: MessageReference(message), media: media), resource: resource)
    }
    return .wallpaper(wallpaper: slug.flatMap(WallpaperReference.slug), resource: resource)
}

final class WallpaperGalleryItemNode: GalleryItemNode {
    private let context: AccountContext
    private let presentationData: PresentationData
    
    var entry: WallpaperGalleryEntry?
    var source: WallpaperListSource?
    private var colorPreview: Bool = false
    private var contentSize: CGSize?
    private var arguments = WallpaperGalleryItemArguments()
    
    let wrapperNode: ASDisplayNode
    let imageNode: TransformImageNode
    let nativeNode: WallpaperBackgroundNode
    private let statusNode: RadialStatusNode
    private let blurredNode: BlurredImageNode
    let cropNode: WallpaperCropNode
    
    private var blurButtonNode: WallpaperOptionButtonNode
    private var motionButtonNode: WallpaperOptionButtonNode
    private var patternButtonNode: WallpaperOptionButtonNode
    private var colorsButtonNode: WallpaperOptionButtonNode
    private var playButtonNode: HighlightableButtonNode
    private let playButtonBackgroundNode: NavigationBackgroundNode
    
    private let messagesContainerNode: ASDisplayNode
    private var messageNodes: [ListViewItemNode]?
    private var validMessages: [String]?
    
    fileprivate let _ready = Promise<Void>()
    private let fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private let colorDisposable = MetaDisposable()
    
    let subtitle = Promise<String?>(nil)
    let status = Promise<MediaResourceStatus>(.Local)
    let actionButton = Promise<UIBarButtonItem?>(nil)
    var action: (() -> Void)?
    var requestPatternPanel: ((Bool, TelegramWallpaper) -> Void)?
    var toggleColorsPanel: (([UIColor]?) -> Void)?
    var requestRotateGradient: ((Int32) -> Void)?
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    private var validOffset: CGFloat?

    private var initialWallpaper: TelegramWallpaper?

    private let playButtonPlayImage: UIImage?
    private let playButtonRotateImage: UIImage?

    private var isReadyDisposable: Disposable?
    
    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.wrapperNode = ASDisplayNode()
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = .subsequentUpdates
        self.nativeNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        self.cropNode = WallpaperCropNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        self.statusNode.frame = CGRect(x: 0.0, y: 0.0, width: progressDiameter, height: progressDiameter)
        self.statusNode.isUserInteractionEnabled = false
        
        self.blurredNode = BlurredImageNode()
        
        self.messagesContainerNode = ASDisplayNode()
        self.messagesContainerNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        self.messagesContainerNode.isUserInteractionEnabled = false
        
        self.blurButtonNode = WallpaperOptionButtonNode(title: self.presentationData.strings.WallpaperPreview_Blurred, value: .check(false))
        self.blurButtonNode.setEnabled(false)
        self.motionButtonNode = WallpaperOptionButtonNode(title: self.presentationData.strings.WallpaperPreview_Motion, value: .check(false))
        self.motionButtonNode.setEnabled(false)
        self.patternButtonNode = WallpaperOptionButtonNode(title: self.presentationData.strings.WallpaperPreview_Pattern, value: .check(false))
        self.patternButtonNode.setEnabled(false)

        self.colorsButtonNode = WallpaperOptionButtonNode(title: self.presentationData.strings.WallpaperPreview_WallpaperColors, value: .colors(false, [.clear]))

        self.playButtonBackgroundNode = NavigationBackgroundNode(color: UIColor(white: 0.0, alpha: 0.3))
        self.playButtonNode = HighlightableButtonNode()
        self.playButtonNode.insertSubnode(self.playButtonBackgroundNode, at: 0)

        self.playButtonPlayImage = generateImage(CGSize(width: 48.0, height: 48.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor.white.cgColor)

            let diameter = size.width

            let factor = diameter / 50.0

            let size = CGSize(width: 15.0, height: 18.0)
            context.translateBy(x: (diameter - size.width) / 2.0 + 1.5, y: (diameter - size.height) / 2.0)
            if (diameter < 40.0) {
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: factor, y: factor)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            }
            let _ = try? drawSvgPath(context, path: "M1.71891969,0.209353049 C0.769586558,-0.350676705 0,0.0908839327 0,1.18800046 L0,16.8564753 C0,17.9569971 0.750549162,18.357187 1.67393713,17.7519379 L14.1073836,9.60224049 C15.0318735,8.99626906 15.0094718,8.04970371 14.062401,7.49100858 L1.71891969,0.209353049 ")
            context.fillPath()
            if (diameter < 40.0) {
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            }
            context.translateBy(x: -(diameter - size.width) / 2.0 - 1.5, y: -(diameter - size.height) / 2.0)
        })

        self.playButtonRotateImage = generateTintedImage(image: UIImage(bundleImageName: "Settings/ThemeColorRotateIcon"), color: .white)

        self.playButtonNode.setImage(self.playButtonPlayImage, for: [])
        
        super.init()
        
        self.clipsToBounds = true
        self.backgroundColor = .black
        
        self.imageNode.imageUpdated = { [weak self] image in
            if image != nil {
                self?._ready.set(.single(Void()))
            }
        }
        self.isReadyDisposable = (self.nativeNode.isReady
        |> filter { $0 }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            self?._ready.set(.single(Void()))
        })
        
        self.imageNode.view.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        
        self.addSubnode(self.wrapperNode)
        //self.addSubnode(self.statusNode)
        self.addSubnode(self.messagesContainerNode)
        
        self.addSubnode(self.blurButtonNode)
        self.addSubnode(self.motionButtonNode)
        self.addSubnode(self.patternButtonNode)
        self.addSubnode(self.colorsButtonNode)
        self.addSubnode(self.playButtonNode)
        
        self.blurButtonNode.addTarget(self, action: #selector(self.toggleBlur), forControlEvents: .touchUpInside)
        self.motionButtonNode.addTarget(self, action: #selector(self.toggleMotion), forControlEvents: .touchUpInside)
        self.patternButtonNode.addTarget(self, action: #selector(self.togglePattern), forControlEvents: .touchUpInside)
        self.colorsButtonNode.addTarget(self, action: #selector(self.toggleColors), forControlEvents: .touchUpInside)
        self.playButtonNode.addTarget(self, action: #selector(self.togglePlay), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
        self.colorDisposable.dispose()
        self.isReadyDisposable?.dispose()
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
    
    func setEntry(_ entry: WallpaperGalleryEntry, arguments: WallpaperGalleryItemArguments, source: WallpaperListSource) {
        let previousArguments = self.arguments
        self.arguments = arguments
        self.source = source
        
        if self.arguments.colorPreview != previousArguments.colorPreview {
            if self.arguments.colorPreview {
                self.imageNode.contentAnimations = []
            } else {
                self.imageNode.contentAnimations = .subsequentUpdates
            }
        }
        
        if self.entry != entry || self.arguments.colorPreview != previousArguments.colorPreview {
            let previousEntry = self.entry
            self.entry = entry
            if previousEntry != entry {
                self.preparePatternEditing()
            }

            self.colorsButtonNode.colors = self.calculateGradientColors() ?? defaultBuiltinWallpaperGradientColors
            
            let imagePromise = Promise<UIImage?>()
            
            let signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
            let fetchSignal: Signal<FetchResourceSourceType, FetchResourceError>
            let statusSignal: Signal<MediaResourceStatus, NoError>
            let subtitleSignal: Signal<String?, NoError>
            var actionSignal: Signal<UIBarButtonItem?, NoError> = .single(nil)
            var colorSignal: Signal<UIColor, NoError> = serviceColor(from: imagePromise.get())
            var patternArguments: PatternWallpaperArguments?
            
            let displaySize: CGSize
            let contentSize: CGSize
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let defaultAction = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: presentationData.theme.rootController.navigationBar.accentTextColor), style: .plain, target: self, action: #selector(self.actionPressed))
            let progressAction = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: presentationData.theme.rootController.navigationBar.accentTextColor))
            
            var isBlurrable = true

            self.nativeNode.updateBubbleTheme(bubbleTheme: presentationData.theme, bubbleCorners: presentationData.chatBubbleCorners)

            switch entry {
            case let .wallpaper(wallpaper, _):
                self.nativeNode.update(wallpaper: wallpaper)

                if case let .file(file) = wallpaper, file.isPattern {
                    self.nativeNode.isHidden = false
                    self.patternButtonNode.isSelected = file.isPattern

                    if file.isPattern && file.settings.colors.count >= 3 {
                        self.playButtonNode.setImage(self.playButtonPlayImage, for: [])
                    } else {
                        self.playButtonNode.setImage(self.playButtonRotateImage, for: [])
                    }
                } else if case let .gradient(gradient) = wallpaper {
                    self.nativeNode.isHidden = false
                    self.nativeNode.update(wallpaper: wallpaper)
                    self.patternButtonNode.isSelected = false

                    if gradient.colors.count >= 3 {
                        self.playButtonNode.setImage(self.playButtonPlayImage, for: [])
                    } else {
                        self.playButtonNode.setImage(self.playButtonRotateImage, for: [])
                    }
                } else if case .color = wallpaper {
                    self.nativeNode.isHidden = false
                    self.nativeNode.update(wallpaper: wallpaper)
                    self.patternButtonNode.isSelected = false
                } else {
                    self.nativeNode.isHidden = true
                    self.patternButtonNode.isSelected = false
                    self.playButtonNode.setImage(self.playButtonRotateImage, for: [])
                }
            case .asset:
                self.nativeNode._internalUpdateIsSettingUpWallpaper()
                self.nativeNode.isHidden = true
                self.patternButtonNode.isSelected = false
                self.playButtonNode.setImage(self.playButtonRotateImage, for: [])
            default:
                self.nativeNode.isHidden = true
                self.patternButtonNode.isSelected = false
                self.playButtonNode.setImage(self.playButtonRotateImage, for: [])
            }
            
            switch entry {
                case let .wallpaper(wallpaper, message):
                    self.initialWallpaper = wallpaper

                    switch wallpaper {
                        case .builtin:
                            displaySize = CGSize(width: 1308.0, height: 2688.0).fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                            contentSize = displaySize
                            signal = settingsBuiltinWallpaperImage(account: self.context.account)
                            fetchSignal = .complete()
                            statusSignal = .single(.Local)
                            subtitleSignal = .single(nil)
                            colorSignal = chatServiceBackgroundColor(wallpaper: wallpaper, mediaBox: self.context.account.postbox.mediaBox)
                            isBlurrable = false
                        case .color:
                            displaySize = CGSize(width: 1.0, height: 1.0)
                            contentSize = displaySize
                            signal = .single({ _ in nil })
                            fetchSignal = .complete()
                            statusSignal = .single(.Local)
                            subtitleSignal = .single(nil)
                            actionSignal = .single(defaultAction)
                            colorSignal = chatServiceBackgroundColor(wallpaper: wallpaper, mediaBox: self.context.account.postbox.mediaBox)
                            isBlurrable = false
                        case .gradient:
                            displaySize = CGSize(width: 1.0, height: 1.0)
                            contentSize = displaySize
                            signal = .single({ _ in nil })
                            fetchSignal = .complete()
                            statusSignal = .single(.Local)
                            subtitleSignal = .single(nil)
                            actionSignal = .single(defaultAction)
                            colorSignal = chatServiceBackgroundColor(wallpaper: wallpaper, mediaBox: self.context.account.postbox.mediaBox)
                            isBlurrable = false
                        case let .file(file):
                            let dimensions = file.file.dimensions ?? PixelDimensions(width: 2000, height: 4000)
                            contentSize = dimensions.cgSize
                            displaySize = dimensions.cgSize.dividedByScreenScale().integralFloor
                            
                            var convertedRepresentations: [ImageRepresentationWithReference] = []
                            for representation in file.file.previewRepresentations {
                                convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: reference(for: representation.resource, media: file.file, message: message, slug: file.slug)))
                            }
                            convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource, progressiveSizes: [], immediateThumbnailData: nil), reference: reference(for: file.file.resource, media: file.file, message: message, slug: file.slug)))
                            
                            if wallpaper.isPattern {
                                var patternColors: [UIColor] = []
                                var patternColor = UIColor(rgb: 0xd6e2ee, alpha: 0.5)
                                var patternIntensity: CGFloat = 0.5
                                
                                if !file.settings.colors.isEmpty {
                                    if let intensity = file.settings.intensity {
                                        patternIntensity = CGFloat(intensity) / 100.0
                                    }
                                    patternColor = UIColor(rgb: file.settings.colors[0], alpha: patternIntensity)
                                    patternColors.append(patternColor)
                                    
                                    if file.settings.colors.count >= 2 {
                                        patternColors.append(UIColor(rgb: file.settings.colors[1], alpha: patternIntensity))
                                    }
                                }
       
                                patternArguments = PatternWallpaperArguments(colors: patternColors, rotation: file.settings.rotation, preview: self.arguments.colorPreview)
                                
                                self.backgroundColor = patternColor.withAlphaComponent(1.0)
                                
                                self.colorPreview = self.arguments.colorPreview

                                signal = .single({ _ in nil })

                                colorSignal = chatServiceBackgroundColor(wallpaper: wallpaper, mediaBox: self.context.account.postbox.mediaBox)
                                
                                isBlurrable = false
                            } else {
                                let fileReference: FileMediaReference
                                if let message = message {
                                    fileReference = .message(message: MessageReference(message), media: file.file)
                                } else {
                                    fileReference = .standalone(media: file.file)
                                }
                                signal = wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, fileReference: fileReference, representations: convertedRepresentations, alwaysShowThumbnailFirst: true, autoFetchFullSize: false)
                            }
                            fetchSignal = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: convertedRepresentations[convertedRepresentations.count - 1].reference)
                            let account = self.context.account
                            statusSignal = self.context.sharedContext.accountManager.mediaBox.resourceStatus(file.file.resource)
                            |> take(1)
                            |> mapToSignal { status -> Signal<MediaResourceStatus, NoError> in
                                if case .Local = status {
                                    return .single(status)
                                } else {
                                    return account.postbox.mediaBox.resourceStatus(file.file.resource)
                                }
                            }
                            if let fileSize = file.file.size {
                                subtitleSignal = .single(dataSizeString(fileSize, formatting: DataSizeStringFormatting(presentationData: self.presentationData)))
                            } else {
                                subtitleSignal = .single(nil)
                            }
                            if file.slug.isEmpty {
                                actionSignal = .single(nil)
                            } else {
                                actionSignal = .single(defaultAction)
                            }
                        case let .image(representations, _):
                            if let largestSize = largestImageRepresentation(representations) {
                                contentSize = largestSize.dimensions.cgSize
                                displaySize = largestSize.dimensions.cgSize.dividedByScreenScale().integralFloor
                                
                                let convertedRepresentations: [ImageRepresentationWithReference] = representations.map({ ImageRepresentationWithReference(representation: $0, reference: .wallpaper(wallpaper: nil, resource: $0.resource)) })
                                signal = wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, alwaysShowThumbnailFirst: true, autoFetchFullSize: false)
                                
                                if let largestIndex = convertedRepresentations.firstIndex(where: { $0.representation == largestSize }) {
                                    fetchSignal = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: convertedRepresentations[largestIndex].reference)
                                } else {
                                    fetchSignal = .complete()
                                }
                                let account = context.account
                                statusSignal = context.sharedContext.accountManager.mediaBox.resourceStatus(largestSize.resource)
                                |> take(1)
                                |> mapToSignal { status -> Signal<MediaResourceStatus, NoError> in
                                    if case .Local = status {
                                        return .single(status)
                                    } else {
                                        return account.postbox.mediaBox.resourceStatus(largestSize.resource)
                                    }
                                }
                                if let fileSize = largestSize.resource.size {
                                    subtitleSignal = .single(dataSizeString(fileSize, formatting: DataSizeStringFormatting(presentationData: self.presentationData)))
                                } else {
                                    subtitleSignal = .single(nil)
                                }
                                
                                actionSignal = self.context.wallpaperUploadManager!.stateSignal()
                                |> filter { state in
                                    return state.wallpaper == wallpaper
                                }
                                |> map { state in
                                    switch state {
                                        case .uploading:
                                            return progressAction
                                        case .uploaded:
                                            return defaultAction
                                        default:
                                            return nil
                                    }
                                }
                            } else {
                                displaySize = CGSize(width: 1.0, height: 1.0)
                                contentSize = displaySize
                                signal = .never()
                                fetchSignal = .complete()
                                statusSignal = .single(.Local)
                                subtitleSignal = .single(nil)
                            }
                    }
                    self.cropNode.removeFromSupernode()
                case let .asset(asset):
                    let dimensions = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                    contentSize = dimensions
                    displaySize = dimensions.dividedByScreenScale().integralFloor
                    signal = photoWallpaper(postbox: context.account.postbox, photoLibraryResource: PhotoLibraryMediaResource(localIdentifier: asset.localIdentifier, uniqueId: Int64.random(in: Int64.min ... Int64.max)))
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
                    case let .externalReference(externalReference):
                        if let content = externalReference.content {
                            imageResource = content.resource
                        }
                        if let thumbnail = externalReference.thumbnail {
                            thumbnailResource = thumbnail.resource
                            thumbnailDimensions = thumbnail.dimensions?.cgSize
                        }
                        if let dimensions = externalReference.content?.dimensions {
                            imageDimensions = dimensions.cgSize
                        }
                    case let .internalReference(internalReference):
                        if let image = internalReference.image {
                            if let imageRepresentation = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 1000, height: 800)) {
                                imageDimensions = imageRepresentation.dimensions.cgSize
                                imageResource = imageRepresentation.resource
                            }
                            if let thumbnailRepresentation = smallestImageRepresentation(image.representations) {
                                thumbnailDimensions = thumbnailRepresentation.dimensions.cgSize
                                thumbnailResource = thumbnailRepresentation.resource
                            }
                        }
                    }
                    
                    if let imageResource = imageResource, let imageDimensions = imageDimensions {
                        contentSize = imageDimensions
                        displaySize = imageDimensions.dividedByScreenScale().integralFloor
                        
                        var representations: [TelegramMediaImageRepresentation] = []
                        if let thumbnailResource = thumbnailResource, let thumbnailDimensions = thumbnailDimensions {
                            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailDimensions), resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil))
                        }
                        representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(imageDimensions), resource: imageResource, progressiveSizes: [], immediateThumbnailData: nil))
                        let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        
                        signal = chatMessagePhoto(postbox: context.account.postbox, photoReference: .standalone(media: tmpImage))
                        fetchSignal = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .media(media: .standalone(media: tmpImage), resource: imageResource))
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
                self.wrapperNode.addSubnode(self.nativeNode)
            } else {
                self.imageNode.contentMode = .scaleToFill
            }
            
            self.imageNode.setSignal(signal, dispatchOnDisplayLink: false)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets(), custom: patternArguments))()
            self.imageNode.imageUpdated = { [weak self] image in
                if let strongSelf = self {
                    if image != nil {
                        strongSelf._ready.set(.single(Void()))
                    }
                    var image = isBlurrable ? image : nil
                    if let imageToScale = image {
                        let actualSize = CGSize(width: imageToScale.size.width * imageToScale.scale, height: imageToScale.size.height * imageToScale.scale)
                        if actualSize.width > 1280.0 || actualSize.height > 1280.0 {
                            image = TGScaleImageToPixelSize(image, actualSize.fitted(CGSize(width: 1280.0, height: 1280.0)))
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
                    var local = false
                    switch status {
                        case let .Fetching(_, progress):
                            let adjustedProgress = max(progress, 0.027)
                            state = .progress(color: statusForegroundColor, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: false, animateRotation: true)
                        case .Local:
                            state = .none
                            local = true
                        case .Remote, .Paused:
                            state = .progress(color: statusForegroundColor, lineWidth: nil, value: 0.027, cancelEnabled: false, animateRotation: true)
                    }
                    strongSelf.statusNode.transitionToState(state, completion: {})
                    
                    strongSelf.blurButtonNode.setEnabled(local)
                    strongSelf.motionButtonNode.setEnabled(local)
                    strongSelf.patternButtonNode.setEnabled(local)
                }
            }))
            
            self.subtitle.set(subtitleSignal |> deliverOnMainQueue)
            self.status.set(statusSignal |> deliverOnMainQueue)
            self.actionButton.set(actionSignal |> deliverOnMainQueue)
            
            self.colorDisposable.set((colorSignal
            |> deliverOnMainQueue).start(next: { [weak self] color in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.statusNode.backgroundNodeColor = color
                strongSelf.patternButtonNode.buttonColor = color
                strongSelf.blurButtonNode.buttonColor = color
                strongSelf.motionButtonNode.buttonColor = color
                strongSelf.colorsButtonNode.buttonColor = color

                strongSelf.playButtonBackgroundNode.updateColor(color: color, transition: .immediate)
            }))
        } else if self.arguments.patternEnabled != previousArguments.patternEnabled {
            self.patternButtonNode.isSelected = self.arguments.patternEnabled
        }

        if let (layout, _) = self.validLayout {
            self.updateButtonsLayout(layout: layout, offset: CGPoint(), transition: .immediate)
            self.updateMessagesLayout(layout: layout, offset: CGPoint(), transition: .immediate)
        }
    }
    
    override func screenFrameUpdated(_ frame: CGRect) {
        let offset = -frame.minX
        guard self.validOffset != offset else {
            return
        }
        self.validOffset = offset
        if let (layout, _) = self.validLayout {
            self.updateWrapperLayout(layout: layout, offset: offset, transition: .immediate)
            self.updateButtonsLayout(layout: layout, offset: CGPoint(x: offset, y: 0.0), transition: .immediate)
            self.updateMessagesLayout(layout: layout, offset: CGPoint(x: offset, y: 0.0), transition:.immediate)
        }
    }
    
    func updateDismissTransition(_ value: CGFloat) {
        if let (layout, _) = self.validLayout {
            self.updateButtonsLayout(layout: layout, offset: CGPoint(x: 0.0, y: value), transition: .immediate)
            self.updateMessagesLayout(layout: layout, offset: CGPoint(x: 0.0, y: value), transition: .immediate)
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

            if let (layout, _) = self.validLayout {
                self.updateButtonsLayout(layout: layout, offset: CGPoint(), transition: .immediate)
            }
        }
    }

    var colors: [UInt32]? {
        return self.calculateGradientColors()?.map({ $0.rgb })
    }

    func updateIsColorsPanelActive(_ value: Bool, animated: Bool) {
        self.colorsButtonNode.setSelected(value, animated: false)
    }
    
    @objc func toggleBlur() {
        let value = !self.blurButtonNode.isSelected
        self.blurButtonNode.setSelected(value, animated: true)
        self.setBlurEnabled(value, animated: true)
    }
    
    func setBlurEnabled(_ enabled: Bool, animated: Bool) {
        let blurRadius: CGFloat = 45.0
        
        var animated = animated
        if animated, let (layout, _) = self.validLayout {
            animated = min(layout.size.width, layout.size.height) > 321.0
        } else {
            animated = false
        }
        
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
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIView.AnimationOptions(rawValue: 7 << 16), animations: {
                    self.blurredNode.blurView.blurRadius = blurRadius
                }, completion: nil)
            } else {
                self.blurredNode.blurView.blurRadius = blurRadius
            }
        } else {
            if self.blurredNode.supernode != nil {
                if animated {
                    UIView.animate(withDuration: 0.3, delay: 0.0, options: UIView.AnimationOptions(rawValue: 7 << 16), animations: {
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
    
    @objc private func toggleMotion() {
        let value = !self.motionButtonNode.isSelected
        self.motionButtonNode.setSelected(value, animated: true)
        self.setMotionEnabled(value, animated: true)

        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    var isPatternEnabled: Bool {
        return self.patternButtonNode.isSelected
    }
    
    @objc private func togglePattern() {
        guard let initialWallpaper = self.initialWallpaper else {
            return
        }

        let value = !self.patternButtonNode.isSelected
        self.patternButtonNode.setSelected(value, animated: false)
        
        self.requestPatternPanel?(value, initialWallpaper)
    }

    func calculateGradientColors() -> [UIColor]? {
        guard let entry = self.entry else {
            return nil
        }
        switch entry {
        case let .wallpaper(wallpaper, _):
            switch wallpaper {
            case let .file(file):
                if file.isPattern {
                    if file.settings.colors.isEmpty {
                        return nil
                    } else {
                        return file.settings.colors.map(UIColor.init(rgb:))
                    }
                } else {
                    return nil
                }
            case let .gradient(gradient):
                return gradient.colors.map(UIColor.init(rgb:))
            case let .color(color):
                return [UIColor(rgb: color)]
            default:
                return nil
            }
        default:
            return nil
        }
    }

    @objc private func toggleColors() {
        guard let currentGradientColors = self.calculateGradientColors() else {
            return
        }
        self.toggleColorsPanel?(currentGradientColors)
    }

    @objc private func togglePlay() {
        guard let entry = self.entry, case let .wallpaper(wallpaper, _) = entry else {
            return
        }
        switch wallpaper {
        case let .gradient(gradient):
            if gradient.colors.count >= 3 {
                self.nativeNode.animateEvent(transition: .animated(duration: 0.5, curve: .spring), extendAnimation: false)
            } else {
                let rotation = gradient.settings.rotation ?? 0
                self.requestRotateGradient?((rotation + 90) % 360)
            }
        case let .file(file):
            if file.isPattern {
                if file.settings.colors.count >= 3 {
                    self.nativeNode.animateEvent(transition: .animated(duration: 0.5, curve: .spring), extendAnimation: false)
                } else {
                    let rotation = file.settings.rotation ?? 0
                    self.requestRotateGradient?((rotation + 90) % 360)
                }
            }
        default:
            break
        }
    }
    
    private func preparePatternEditing() {
    }
    
    func setMotionEnabled(_ enabled: Bool, animated: Bool) {
        if enabled {
            let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
            horizontal.minimumRelativeValue = motionAmount
            horizontal.maximumRelativeValue = -motionAmount
            
            let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
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
    
    func updateWrapperLayout(layout: ContainerViewLayout, offset: CGFloat, transition: ContainedViewLayoutTransition) {
        var appliedOffset: CGFloat = 0.0
        if self.arguments.isColorsList {
            appliedOffset = offset
        }
        transition.updatePosition(node: self.wrapperNode, position: CGPoint(x: layout.size.width / 2.0 + appliedOffset, y: layout.size.height / 2.0))
    }
    
    func updateButtonsLayout(layout: ContainerViewLayout, offset: CGPoint, transition: ContainedViewLayoutTransition) {
        let patternButtonSize = self.patternButtonNode.measure(layout.size)
        let blurButtonSize = self.blurButtonNode.measure(layout.size)
        let motionButtonSize = self.motionButtonNode.measure(layout.size)
        let colorsButtonSize = self.colorsButtonNode.measure(layout.size)
        let playButtonSize = CGSize(width: 48.0, height: 48.0)
        
        let maxButtonWidth = max(patternButtonSize.width, max(blurButtonSize.width, motionButtonSize.width))
        let buttonSize = CGSize(width: maxButtonWidth, height: 30.0)
        let alpha = 1.0 - min(1.0, max(0.0, abs(offset.y) / 50.0))
        
        let additionalYOffset: CGFloat = 0.0
        /*if self.patternButtonNode.isSelected {
            additionalYOffset = -235.0
        } else if self.colorsButtonNode.isSelected {
            additionalYOffset = -235.0
        }*/

        let buttonSpacing: CGFloat = 18.0
        
        let leftButtonFrame = CGRect(origin: CGPoint(x: floor(layout.size.width / 2.0 - buttonSize.width - buttonSpacing) + offset.x, y: layout.size.height - 49.0 - layout.intrinsicInsets.bottom - 54.0 + offset.y + additionalYOffset), size: buttonSize)
        let centerButtonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonSize.width) / 2.0) + offset.x, y: layout.size.height - 49.0 - layout.intrinsicInsets.bottom - 54.0 + offset.y + additionalYOffset), size: buttonSize)
        let rightButtonFrame = CGRect(origin: CGPoint(x: ceil(layout.size.width / 2.0 + buttonSpacing) + offset.x, y: layout.size.height - 49.0 - layout.intrinsicInsets.bottom - 54.0 + offset.y + additionalYOffset), size: buttonSize)
        
        var patternAlpha: CGFloat = 0.0
        var patternFrame = centerButtonFrame
        
        var blurAlpha: CGFloat = 0.0
        var blurFrame = centerButtonFrame
        
        var motionFrame = centerButtonFrame
        var motionAlpha: CGFloat = 0.0

        var colorsFrame = CGRect(origin: CGPoint(x: rightButtonFrame.maxX - colorsButtonSize.width, y: rightButtonFrame.minY), size: colorsButtonSize)
        var colorsAlpha: CGFloat = 0.0

        let playFrame = CGRect(origin: CGPoint(x: centerButtonFrame.midX - playButtonSize.width / 2.0, y: centerButtonFrame.midY - playButtonSize.height / 2.0), size: playButtonSize)
        var playAlpha: CGFloat = 0.0

        let centerOffset: CGFloat = 32.0
        
        if let entry = self.entry {
            switch entry {
                case .asset:
                    blurAlpha = 1.0
                    blurFrame = leftButtonFrame
                    motionAlpha = 1.0
                    motionFrame = rightButtonFrame
                case .contextResult:
                    blurAlpha = 1.0
                    blurFrame = leftButtonFrame
                    motionAlpha = 1.0
                    motionFrame = rightButtonFrame
                case let .wallpaper(wallpaper, _):
                    switch wallpaper {
                        case .builtin:
                            motionAlpha = 1.0
                            motionFrame = centerButtonFrame
                        case .color:
                            motionAlpha = 0.0
                            patternAlpha = 1.0

                            patternFrame = leftButtonFrame
                            playAlpha = 0.0

                            colorsAlpha = 1.0
                        case .image:
                            blurAlpha = 1.0
                            blurFrame = leftButtonFrame
                            motionAlpha = 1.0
                            motionFrame = rightButtonFrame
                        case let .gradient(gradient):
                            motionAlpha = 0.0
                            patternAlpha = 1.0

                            if gradient.colors.count >= 2 {
                                playAlpha = 1.0
                                patternFrame = leftButtonFrame.offsetBy(dx: -centerOffset, dy: 0.0)
                                colorsFrame = colorsFrame.offsetBy(dx: centerOffset, dy: 0.0)
                            } else {
                                playAlpha = 0.0
                                patternFrame = leftButtonFrame
                            }

                            colorsAlpha = 1.0
                        case let .file(file):
                            if file.isPattern {
                                motionAlpha = 0.0
                                patternAlpha = 1.0

                                if file.settings.colors.count >= 2 {
                                    playAlpha = 1.0
                                    patternFrame = leftButtonFrame.offsetBy(dx: -centerOffset, dy: 0.0)
                                    colorsFrame = colorsFrame.offsetBy(dx: centerOffset, dy: 0.0)
                                } else {
                                    playAlpha = 0.0
                                    patternFrame = leftButtonFrame
                                }

                                colorsAlpha = 1.0
                            } else {
                                if wallpaper.isPattern {
                                    motionAlpha = 1.0
                                    if self.arguments.isColorsList {
                                        patternAlpha = 1.0
                                        if self.patternButtonNode.isSelected {
                                            patternFrame = leftButtonFrame
                                        }
                                        motionFrame = rightButtonFrame
                                    }
                                } else {
                                    blurAlpha = 1.0
                                    blurFrame = leftButtonFrame
                                    motionAlpha = 1.0
                                    motionFrame = rightButtonFrame
                                }
                            }
                    }
            }
        }
        
        transition.updateFrame(node: self.patternButtonNode, frame: patternFrame)
        transition.updateAlpha(node: self.patternButtonNode, alpha: patternAlpha * alpha)
        
        transition.updateFrame(node: self.blurButtonNode, frame: blurFrame)
        transition.updateAlpha(node: self.blurButtonNode, alpha: blurAlpha * alpha)
        
        transition.updateFrame(node: self.motionButtonNode, frame: motionFrame)
        transition.updateAlpha(node: self.motionButtonNode, alpha: motionAlpha * alpha)

        transition.updateFrame(node: self.colorsButtonNode, frame: colorsFrame)
        transition.updateAlpha(node: self.colorsButtonNode, alpha: colorsAlpha * alpha)

        transition.updateFrame(node: self.playButtonNode, frame: playFrame)
        transition.updateFrame(node: self.playButtonBackgroundNode, frame: CGRect(origin: CGPoint(), size: playFrame.size))
        self.playButtonBackgroundNode.update(size: playFrame.size, cornerRadius: playFrame.size.height / 2.0, transition: transition)
        transition.updateAlpha(node: self.playButtonNode, alpha: playAlpha * alpha)
        transition.updateSublayerTransformScale(node: self.playButtonNode, scale: max(0.1, playAlpha))
    }
    
    private func updateMessagesLayout(layout: ContainerViewLayout, offset: CGPoint, transition: ContainedViewLayoutTransition) {
        let bottomInset: CGFloat = 115.0

        if self.patternButtonNode.isSelected || self.colorsButtonNode.isSelected {
            //bottomInset = 350.0
        }
        
        var items: [ListViewItem] = []
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
        let otherPeerId = self.context.account.peerId
        var peers = SimpleDictionary<PeerId, Peer>()
        let messages = SimpleDictionary<MessageId, Message>()
        peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_PreviewReplyAuthor, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        peers[otherPeerId] = TelegramUser(id: otherPeerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_PreviewReplyAuthor, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        var topMessageText = ""
        var bottomMessageText = ""
        var currentWallpaper: TelegramWallpaper = self.presentationData.chatWallpaper
        if let entry = self.entry, case let .wallpaper(wallpaper, _) = entry {
            currentWallpaper = wallpaper
        }
        
        if let source = self.source {
            switch source {
                case .slug, .wallpaper:
                    topMessageText = presentationData.strings.WallpaperPreview_PreviewTopText
                    bottomMessageText = presentationData.strings.WallpaperPreview_PreviewBottomText

                    var hasAnimatableGradient = false
                    switch currentWallpaper {
                    case let .file(file) where file.isPattern:
                        if file.settings.colors.count >= 3 {
                            hasAnimatableGradient = true
                        }
                    case let .gradient(gradient):
                        if gradient.colors.count >= 3 {
                            hasAnimatableGradient = true
                        }
                    default:
                        break
                    }
                    if hasAnimatableGradient {
                        bottomMessageText = presentationData.strings.WallpaperPreview_PreviewBottomTextAnimatable
                    }
                case let .list(_, _, type):
                    switch type {
                        case .wallpapers:
                            topMessageText = presentationData.strings.WallpaperPreview_SwipeTopText
                            bottomMessageText = presentationData.strings.WallpaperPreview_SwipeBottomText

                            var hasAnimatableGradient = false
                            switch currentWallpaper {
                            case let .file(file) where file.isPattern:
                                if file.settings.colors.count >= 3 {
                                    hasAnimatableGradient = true
                                }
                            case let .gradient(gradient):
                                if gradient.colors.count >= 3 {
                                    hasAnimatableGradient = true
                                }
                            default:
                                break
                            }
                            if hasAnimatableGradient {
                                bottomMessageText = presentationData.strings.WallpaperPreview_PreviewBottomTextAnimatable
                            }
                        case .colors:
                            topMessageText = presentationData.strings.WallpaperPreview_SwipeColorsTopText
                            bottomMessageText = presentationData.strings.WallpaperPreview_SwipeColorsBottomText
                }
                case .asset, .contextResult:
                    topMessageText = presentationData.strings.WallpaperPreview_CropTopText
                    bottomMessageText = presentationData.strings.WallpaperPreview_CropBottomText
                case .customColor:
                    topMessageText = presentationData.strings.WallpaperPreview_CustomColorTopText
                    bottomMessageText = presentationData.strings.WallpaperPreview_CustomColorBottomText
            }
        }
        
        let theme = self.presentationData.theme.withUpdated(preview: true)
                   
        let message1 = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 2), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66001, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: bottomMessageText, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: [message1], theme: theme, strings: self.presentationData.strings, wallpaper: currentWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.nativeNode, availableReactions: nil, isCentered: false))
        
        let message2 = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: topMessageText, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: [message2], theme: theme, strings: self.presentationData.strings, wallpaper: currentWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.nativeNode, availableReactions: nil, isCentered: false))
        
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, availableHeight: layout.size.height)
        if let messageNodes = self.messageNodes {
            if self.validMessages != [topMessageText, bottomMessageText] {
                self.validMessages = [topMessageText, bottomMessageText]
                for i in 0 ..< items.count {
                    items[i].updateNode(async: { f in f() }, node: { return messageNodes[i] }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None) { layout, apply in
                        let nodeFrame = CGRect(origin: messageNodes[i].frame.origin, size: CGSize(width: layout.size.width, height: layout.size.height))

                        messageNodes[i].contentSize = layout.contentSize
                        messageNodes[i].insets = layout.insets
                        messageNodes[i].frame = nodeFrame

                        apply(ListViewItemApply(isOnScreen: true))
                    }
                }
            }
        } else {
            self.validMessages = [topMessageText, bottomMessageText]
            var messageNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                var itemNode: ListViewItemNode?
                items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                itemNode!.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                itemNode!.isUserInteractionEnabled = false
                messageNodes.append(itemNode!)
                self.messagesContainerNode.addSubnode(itemNode!)
            }
            self.messageNodes = messageNodes
        }
        
        let alpha = 1.0 - min(1.0, max(0.0, abs(offset.y) / 50.0))
        
        if let messageNodes = self.messageNodes {
            var bottomOffset: CGFloat = 9.0 + bottomInset + layout.intrinsicInsets.bottom
            for itemNode in messageNodes {
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: offset.x, y: bottomOffset - offset.y), size: itemNode.frame.size))
                bottomOffset += itemNode.frame.height
                itemNode.updateFrame(itemNode.frame, within: layout.size)
                transition.updateAlpha(node: itemNode, alpha: alpha)
            }
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        var offset: CGFloat = 0.0
        if let validOffset = self.validOffset {
            offset = validOffset
        }
        
        self.wrapperNode.bounds = CGRect(origin: CGPoint(), size: layout.size)
        self.updateWrapperLayout(layout: layout, offset: offset, transition: transition)
        self.messagesContainerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        if self.cropNode.supernode == nil {
            self.imageNode.frame = self.wrapperNode.bounds
            self.nativeNode.frame = self.wrapperNode.bounds
            self.nativeNode.updateLayout(size: self.nativeNode.bounds.size, transition: .immediate)
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
        
        let additionalYOffset: CGFloat = 0.0
        
        self.statusNode.frame = CGRect(x: layout.safeInsets.left + floorToScreenPixels((layout.size.width - layout.safeInsets.left - layout.safeInsets.right - progressDiameter) / 2.0), y: floorToScreenPixels((layout.size.height + additionalYOffset - progressDiameter) / 2.0), width: progressDiameter, height: progressDiameter)
        
        self.updateButtonsLayout(layout: layout, offset: CGPoint(x: offset, y: 0.0), transition: transition)
        self.updateMessagesLayout(layout: layout, offset: CGPoint(x: offset, y: 0.0), transition: transition)
        
        self.validLayout = (layout, navigationBarHeight)
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
    }

    func animateWallpaperAppeared() {
        self.nativeNode.animateEvent(transition: .animated(duration: 2.0, curve: .spring), extendAnimation: true)
    }
}
