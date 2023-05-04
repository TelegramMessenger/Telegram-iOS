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
import TextFormat
import TooltipUI
import TelegramNotices

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
    let mode: WallpaperGalleryController.Mode
    let interaction: WallpaperGalleryInteraction
    
    init(context: AccountContext, index: Int, entry: WallpaperGalleryEntry, arguments: WallpaperGalleryItemArguments, source: WallpaperListSource, mode: WallpaperGalleryController.Mode, interaction: WallpaperGalleryInteraction) {
        self.context = context
        self.index = index
        self.entry = entry
        self.arguments = arguments
        self.source = source
        self.mode = mode
        self.interaction = interaction
    }
    
    func node(synchronous: Bool) -> GalleryItemNode {
        let node = WallpaperGalleryItemNode(context: self.context)
        node.setEntry(self.entry, arguments: self.arguments, source: self.source, mode: self.mode, interaction: self.interaction)
        return node
    }
    
    func updateNode(node: GalleryItemNode, synchronous: Bool) {
        if let node = node as? WallpaperGalleryItemNode {
            node.setEntry(self.entry, arguments: self.arguments, source: self.source, mode: self.mode, interaction: self.interaction)
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
    private var presentationData: PresentationData
    
    var entry: WallpaperGalleryEntry?
    var source: WallpaperListSource?
    var mode: WallpaperGalleryController.Mode?
    private var colorPreview: Bool = false
    private var contentSize: CGSize?
    private var arguments = WallpaperGalleryItemArguments()
    private var interaction: WallpaperGalleryInteraction?
    
    let wrapperNode: ASDisplayNode
    let imageNode: TransformImageNode
    private let temporaryImageNode: ASImageNode
    let nativeNode: WallpaperBackgroundNode
    let brightnessNode: ASDisplayNode
    private let statusNode: RadialStatusNode
    private let blurredNode: BlurredImageNode
    let cropNode: WallpaperCropNode
    
    private let cancelButtonNode: WallpaperNavigationButtonNode
    private let shareButtonNode: WallpaperNavigationButtonNode
    private let dayNightButtonNode: WallpaperNavigationButtonNode
    private let editButtonNode: WallpaperNavigationButtonNode
    
    private let buttonsContainerNode: SparseNode
    private let blurButtonNode: WallpaperOptionButtonNode
    private let motionButtonNode: WallpaperOptionButtonNode
    private let patternButtonNode: WallpaperOptionButtonNode
    private let colorsButtonNode: WallpaperOptionButtonNode
    private let playButtonNode: WallpaperNavigationButtonNode
    private let sliderNode: WallpaperSliderNode
    
    private let messagesContainerNode: ASDisplayNode
    private var messageNodes: [ListViewItemNode]?
    private var validMessages: [String]?
    
    private let serviceBackgroundNode: NavigationBackgroundNode
    
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
    
    private var isDarkAppearance: Bool = false
    private var didChangeAppearance: Bool = false
    private var darkAppearanceIntensity: CGFloat = 0.8
    
    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.isDarkAppearance = self.presentationData.theme.overallDarkAppearance
        
        self.wrapperNode = ASDisplayNode()
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = .subsequentUpdates
        self.temporaryImageNode = ASImageNode()
        self.temporaryImageNode.isUserInteractionEnabled = false
        self.nativeNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        self.cropNode = WallpaperCropNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        self.statusNode.frame = CGRect(x: 0.0, y: 0.0, width: progressDiameter, height: progressDiameter)
        self.statusNode.isUserInteractionEnabled = false
        
        self.blurredNode = BlurredImageNode()
        self.brightnessNode = ASDisplayNode()
        self.brightnessNode.alpha = 0.0
        
        self.messagesContainerNode = ASDisplayNode()
        self.messagesContainerNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        self.messagesContainerNode.isUserInteractionEnabled = false
        
        self.buttonsContainerNode = SparseNode()
        self.blurButtonNode = WallpaperOptionButtonNode(title: self.presentationData.strings.WallpaperPreview_Blurred, value: .check(false))
        self.blurButtonNode.setEnabled(false)
        self.motionButtonNode = WallpaperOptionButtonNode(title: self.presentationData.strings.WallpaperPreview_Motion, value: .check(false))
        self.motionButtonNode.setEnabled(false)
        self.patternButtonNode = WallpaperOptionButtonNode(title: self.presentationData.strings.WallpaperPreview_Pattern, value: .check(false))
        self.patternButtonNode.setEnabled(false)
        
        self.serviceBackgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0x333333, alpha: 0.35))
        
        var sliderValueChangedImpl: ((CGFloat) -> Void)?
        self.sliderNode = WallpaperSliderNode(minValue: 0.0, maxValue: 1.0, value: 0.7, valueChanged: { value, _ in
            sliderValueChangedImpl?(value)
        })

        self.colorsButtonNode = WallpaperOptionButtonNode(title: self.presentationData.strings.WallpaperPreview_WallpaperColors, value: .colors(false, [.clear]))

        self.cancelButtonNode = WallpaperNavigationButtonNode(content: .text(self.presentationData.strings.Common_Cancel), dark: true)
        self.cancelButtonNode.enableSaturation = true
        self.shareButtonNode = WallpaperNavigationButtonNode(content: .icon(image: UIImage(bundleImageName: "Chat/Links/Share"), size: CGSize(width: 28.0, height: 28.0)), dark: true)
        self.shareButtonNode.enableSaturation = true
        self.dayNightButtonNode = WallpaperNavigationButtonNode(content: .dayNight(isNight: self.isDarkAppearance), dark: true)
        self.dayNightButtonNode.enableSaturation = true
        self.editButtonNode = WallpaperNavigationButtonNode(content: .icon(image: UIImage(bundleImageName: "Settings/WallpaperAdjustments"), size: CGSize(width: 28.0, height: 28.0)), dark: true)
        self.editButtonNode.enableSaturation = true
        
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

        self.playButtonNode = WallpaperNavigationButtonNode(content: .icon(image: self.playButtonPlayImage, size: CGSize(width: 48.0, height: 48.0)), dark: true)
        
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
        self.addSubnode(self.temporaryImageNode)
        //self.addSubnode(self.statusNode)
        self.addSubnode(self.serviceBackgroundNode)
        self.addSubnode(self.messagesContainerNode)
        self.addSubnode(self.buttonsContainerNode)
        
        self.buttonsContainerNode.addSubnode(self.blurButtonNode)
        self.buttonsContainerNode.addSubnode(self.motionButtonNode)
        self.buttonsContainerNode.addSubnode(self.patternButtonNode)
        self.buttonsContainerNode.addSubnode(self.colorsButtonNode)
        self.buttonsContainerNode.addSubnode(self.playButtonNode)
        self.buttonsContainerNode.addSubnode(self.sliderNode)
        self.buttonsContainerNode.addSubnode(self.cancelButtonNode)
        self.buttonsContainerNode.addSubnode(self.shareButtonNode)
        self.buttonsContainerNode.addSubnode(self.dayNightButtonNode)
        self.buttonsContainerNode.addSubnode(self.editButtonNode)
        
        self.imageNode.addSubnode(self.brightnessNode)
        
        self.blurButtonNode.addTarget(self, action: #selector(self.toggleBlur), forControlEvents: .touchUpInside)
        self.motionButtonNode.addTarget(self, action: #selector(self.toggleMotion), forControlEvents: .touchUpInside)
        self.patternButtonNode.addTarget(self, action: #selector(self.togglePattern), forControlEvents: .touchUpInside)
        self.colorsButtonNode.addTarget(self, action: #selector(self.toggleColors), forControlEvents: .touchUpInside)
        self.playButtonNode.addTarget(self, action: #selector(self.togglePlay), forControlEvents: .touchUpInside)
        self.cancelButtonNode.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.shareButtonNode.addTarget(self, action: #selector(self.actionPressed), forControlEvents: .touchUpInside)
        self.dayNightButtonNode.addTarget(self, action: #selector(self.dayNightPressed), forControlEvents: .touchUpInside)
        self.editButtonNode.addTarget(self, action: #selector(self.editPressed), forControlEvents: .touchUpInside)
        
        sliderValueChangedImpl = { [weak self] value in
            if let self {
                self.updateIntensity(transition: .immediate)
            }
        }
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
    
    var editedCropRect: CGRect? {
        guard let cropRect = self.cropRect, let contentSize = self.contentSize else {
            return nil
        }
        if let editedFullSizeImage = self.editedFullSizeImage {
            let scale = editedFullSizeImage.size.height / contentSize.height
            return CGRect(origin: CGPoint(x: cropRect.minX * scale, y: cropRect.minY * scale), size: CGSize(width: cropRect.width * scale, height: cropRect.height * scale))
        } else {
            return cropRect
        }
    }
    
    var brightness: CGFloat? {
        guard let entry = self.entry else {
            return nil
        }
        switch entry {
        case .asset, .contextResult:
            return 1.0 - self.sliderNode.value
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
    
    private func switchTheme() {
        if let messageNodes = self.messageNodes {
            for messageNode in messageNodes.prefix(2) {
                if let snapshotView = messageNode.view.snapshotContentTree(keepPortals: true) {
                    messageNode.view.addSubview(snapshotView)
                    snapshotView.frame = messageNode.bounds
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
            }
        }
        let themeSettings = self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings])
        |> map { sharedData -> PresentationThemeSettings in
            let themeSettings: PresentationThemeSettings
            if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) {
                themeSettings = current
            } else {
                themeSettings = PresentationThemeSettings.defaultSettings
            }
            return themeSettings
        }
        
        let _ = (themeSettings
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] themeSettings in
            guard let strongSelf = self else {
                return
            }
            var presentationData = strongSelf.presentationData
            
            let lightTheme: PresentationTheme
            let lightWallpaper: TelegramWallpaper
            
            let darkTheme: PresentationTheme
            let darkWallpaper: TelegramWallpaper
            
            if !strongSelf.isDarkAppearance {
                darkTheme = presentationData.theme
                darkWallpaper = presentationData.chatWallpaper
                
                var currentColors = themeSettings.themeSpecificAccentColors[themeSettings.theme.index]
                if let colors = currentColors, colors.baseColor == .theme {
                    currentColors = nil
                }
                
                let themeSpecificWallpaper = (themeSettings.themeSpecificChatWallpapers[coloredThemeIndex(reference: themeSettings.theme, accentColor: currentColors)] ?? themeSettings.themeSpecificChatWallpapers[themeSettings.theme.index])
                
                if let themeSpecificWallpaper = themeSpecificWallpaper {
                    lightWallpaper = themeSpecificWallpaper
                } else {
                    let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeSettings.theme, accentColor: currentColors?.color, bubbleColors: currentColors?.customBubbleColors ?? [], wallpaper: currentColors?.wallpaper, baseColor: currentColors?.baseColor, preview: true) ?? defaultPresentationTheme
                    lightWallpaper = theme.chat.defaultWallpaper
                }
                
                var preferredBaseTheme: TelegramBaseTheme?
                if let baseTheme = themeSettings.themePreferredBaseTheme[themeSettings.theme.index], [.classic, .day].contains(baseTheme) {
                    preferredBaseTheme = baseTheme
                }
                
                lightTheme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeSettings.theme, baseTheme: preferredBaseTheme, accentColor: currentColors?.color, bubbleColors: currentColors?.customBubbleColors ?? [], wallpaper: currentColors?.wallpaper, baseColor: currentColors?.baseColor, serviceBackgroundColor: defaultServiceBackgroundColor) ?? defaultPresentationTheme
            } else {
                lightTheme = presentationData.theme
                lightWallpaper = presentationData.chatWallpaper
                
                let automaticTheme = themeSettings.automaticThemeSwitchSetting.theme
                let effectiveColors = themeSettings.themeSpecificAccentColors[automaticTheme.index]
                let themeSpecificWallpaper = (themeSettings.themeSpecificChatWallpapers[coloredThemeIndex(reference: automaticTheme, accentColor: effectiveColors)] ?? themeSettings.themeSpecificChatWallpapers[automaticTheme.index])
                
                var preferredBaseTheme: TelegramBaseTheme?
                if let baseTheme = themeSettings.themePreferredBaseTheme[automaticTheme.index], [.night, .tinted].contains(baseTheme) {
                    preferredBaseTheme = baseTheme
                } else {
                    preferredBaseTheme = .night
                }
                
                darkTheme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: automaticTheme, baseTheme: preferredBaseTheme, accentColor: effectiveColors?.color, bubbleColors: effectiveColors?.customBubbleColors ?? [], wallpaper: effectiveColors?.wallpaper, baseColor: effectiveColors?.baseColor, serviceBackgroundColor: defaultServiceBackgroundColor) ?? defaultPresentationTheme
                
                if let themeSpecificWallpaper = themeSpecificWallpaper {
                    darkWallpaper = themeSpecificWallpaper
                } else {
                    switch lightWallpaper {
                        case .builtin, .color, .gradient:
                            darkWallpaper = darkTheme.chat.defaultWallpaper
                        case .file:
                            if lightWallpaper.isPattern {
                                darkWallpaper = darkTheme.chat.defaultWallpaper
                            } else {
                                darkWallpaper = lightWallpaper
                            }
                        default:
                            darkWallpaper = lightWallpaper
                    }
                }
            }
            
            if strongSelf.isDarkAppearance {
                darkTheme.forceSync = true
                Queue.mainQueue().after(1.0, {
                    darkTheme.forceSync = false
                })
                presentationData = presentationData.withUpdated(theme: darkTheme).withUpdated(chatWallpaper: darkWallpaper)
            } else {
                lightTheme.forceSync = true
                Queue.mainQueue().after(1.0, {
                    lightTheme.forceSync = false
                })
                presentationData = presentationData.withUpdated(theme: lightTheme).withUpdated(chatWallpaper: lightWallpaper)
            }
            
            strongSelf.presentationData = presentationData
            
            if let (layout, _) = strongSelf.validLayout {
                strongSelf.updateMessagesLayout(layout: layout, offset: CGPoint(), transition: .animated(duration: 0.3, curve: .easeInOut))
            }
        })
    }
    
    @objc private func dayNightPressed() {
        self.isDarkAppearance = !self.isDarkAppearance
        self.dayNightButtonNode.setIsNight(self.isDarkAppearance)
                
        if let layout = self.validLayout?.0 {
            let offset = CGPoint(x: self.validOffset ?? 0.0, y: 0.0)
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
            self.updateButtonsLayout(layout: layout, offset: offset, transition: transition)
            self.updateMessagesLayout(layout: layout, offset: offset, transition: transition)
            
            if !self.didChangeAppearance {
                self.didChangeAppearance = true
                self.animateIntensityChange(delay: 0.15)
            } else {
                self.updateIntensity(transition: .animated(duration: 0.3, curve: .easeInOut))
            }
        }
        
        self.switchTheme()
    }
    
    @objc private func editPressed() {
        guard let image = self.imageNode.image, case let .asset(asset) = self.entry else {
            return
        }
        let originalImage = self.originalImage ?? image
        guard let cropRect = self.cropRect else {
            return
        }
        self.interaction?.editMedia(asset, originalImage, cropRect, self.currentAdjustments, self.cropNode.view, { [weak self] result, adjustments in
            guard let self else {
                return
            }
            self.originalImage = originalImage
            self.editedImage = result
            self.currentAdjustments = adjustments
            
            self.imageNode.setSignal(.single({ arguments in
                let context = DrawingContext(size: arguments.drawingSize, opaque: false)
                context?.withFlippedContext({ context in
                    let image = result ?? originalImage
                    if let cgImage = image.cgImage {
                        context.draw(cgImage, in: CGRect(origin: .zero, size: arguments.drawingSize))
                    }
                })
                return context
            }))

            Queue.mainQueue().after(0.1) {
                self.brightnessNode.isHidden = false
                self.temporaryImageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, delay: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
                    self?.temporaryImageNode.image = nil
                    self?.temporaryImageNode.layer.removeAllAnimations()
                })
            }
        }, { [weak self] image in
            guard let self else {
                return
            }
            self.editedFullSizeImage = image
            
            self.temporaryImageNode.frame = self.imageNode.view.convert(self.imageNode.bounds, to: self.view)
            self.temporaryImageNode.image = image ?? originalImage
            
            if self.cropNode.isHidden {
                self.temporaryImageNode.alpha = 0.0
            }
        })
        
        self.beginTransitionToEditor()
    }
    
    private var originalImage: UIImage?
    public private(set) var editedImage: UIImage?
    public private(set) var editedFullSizeImage: UIImage?
    private var currentAdjustments: TGMediaEditAdjustments?
    
    func beginTransitionToEditor() {
        self.cropNode.isHidden = true
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)
        transition.updateAlpha(node: self.messagesContainerNode, alpha: 0.0)
        transition.updateAlpha(node: self.buttonsContainerNode, alpha: 0.0)
        transition.updateAlpha(node: self.serviceBackgroundNode, alpha: 0.0)
        
        self.interaction?.beginTransitionToEditor()
    }
    
    func beginTransitionFromEditor(saving: Bool) {
        if saving {
            self.brightnessNode.isHidden = true
        }
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)
        transition.updateAlpha(node: self.messagesContainerNode, alpha: 1.0)
        transition.updateAlpha(node: self.buttonsContainerNode, alpha: 1.0)
        transition.updateAlpha(node: self.serviceBackgroundNode, alpha: 1.0)
    }
    
    func finishTransitionFromEditor() {
        self.cropNode.isHidden = false
        self.temporaryImageNode.alpha = 1.0
    }
    
    private func animateIntensityChange(delay: Double) {
        let targetValue: CGFloat = self.sliderNode.value
        self.sliderNode.internalUpdateLayout(size: self.sliderNode.frame.size, value: 1.0)
        self.sliderNode.ignoreUpdates = true
        Queue.mainQueue().after(delay, {
            self.brightnessNode.backgroundColor = UIColor(rgb: 0x000000)
            
            self.sliderNode.ignoreUpdates = false
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .easeInOut)
            self.sliderNode.animateValue(from: 1.0, to: targetValue, transition: transition)
            self.updateIntensity(transition: transition)
        })
    }
    
    private func updateIntensity(transition: ContainedViewLayoutTransition) {
        let value = self.isDarkAppearance ? self.sliderNode.value : 1.0
        if value < 1.0 {
            self.brightnessNode.backgroundColor = UIColor(rgb: 0x000000)
            transition.updateAlpha(node: self.brightnessNode, alpha: 1.0 - value)
        } else {
            transition.updateAlpha(node: self.brightnessNode, alpha: 0.0)
        }
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    func setEntry(_ entry: WallpaperGalleryEntry, arguments: WallpaperGalleryItemArguments, source: WallpaperListSource, mode: WallpaperGalleryController.Mode, interaction: WallpaperGalleryInteraction) {
        let previousArguments = self.arguments
        self.arguments = arguments
        self.source = source
        self.mode = mode
        self.interaction = interaction
        
        if self.arguments.colorPreview != previousArguments.colorPreview {
            if self.arguments.colorPreview {
                self.imageNode.contentAnimations = []
            } else {
                self.imageNode.contentAnimations = .subsequentUpdates
            }
        }
        
        var showPreviewTooltip = false
        
        if self.entry != entry || self.arguments.colorPreview != previousArguments.colorPreview {
            self.entry = entry

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

            var isColor = false
            switch entry {
            case let .wallpaper(wallpaper, _):
                Queue.mainQueue().justDispatch {
                    self.nativeNode.update(wallpaper: wallpaper)
                }

                if case let .file(file) = wallpaper, file.isPattern {
                    self.nativeNode.isHidden = false
                    self.patternButtonNode.isSelected = file.isPattern

                    if file.settings.colors.count >= 3 {
                        self.playButtonNode.setIcon(self.playButtonPlayImage)
                    } else {
                        self.playButtonNode.setIcon(self.playButtonRotateImage)
                    }
                    isColor = true
                } else if case let .gradient(gradient) = wallpaper {
                    self.nativeNode.isHidden = false
                    self.nativeNode.update(wallpaper: wallpaper)
                    self.patternButtonNode.isSelected = false

                    if gradient.colors.count >= 3 {
                        self.playButtonNode.setIcon(self.playButtonPlayImage)
                    } else {
                        self.playButtonNode.setIcon(self.playButtonRotateImage)
                    }
                    isColor = true
                } else if case .color = wallpaper {
                    self.nativeNode.isHidden = false
                    self.nativeNode.update(wallpaper: wallpaper)
                    self.patternButtonNode.isSelected = false
                    isColor = true
                } else {
                    self.nativeNode._internalUpdateIsSettingUpWallpaper()
                    self.nativeNode.isHidden = true
                    self.patternButtonNode.isSelected = false
                    self.playButtonNode.setIcon(self.playButtonRotateImage)
                }
                
                if let settings = wallpaper.settings {
                    if settings.blur {
                        self.blurButtonNode.setSelected(true, animated: false)
                        self.setBlurEnabled(true, animated: false)
                    }
                    if settings.motion {
                        self.motionButtonNode.setSelected(true, animated: false)
                        self.setMotionEnabled(true, animated: false)
                    }
                    if case let .file(file) = wallpaper, !file.isPattern, let intensity = file.settings.intensity {
                        self.sliderNode.value = (1.0 - CGFloat(intensity) / 100.0)
                        self.updateIntensity(transition: .immediate)
                    }
                }
            case .asset:
                self.nativeNode._internalUpdateIsSettingUpWallpaper()
                self.nativeNode.isHidden = true
                self.patternButtonNode.isSelected = false
                self.playButtonNode.setIcon(self.playButtonRotateImage)
            default:
                self.nativeNode.isHidden = true
                self.patternButtonNode.isSelected = false
                self.playButtonNode.setIcon(self.playButtonRotateImage)
            }
            
            self.cancelButtonNode.enableSaturation = isColor
            self.dayNightButtonNode.enableSaturation = isColor
            self.editButtonNode.enableSaturation = isColor
            self.shareButtonNode.enableSaturation = isColor
            self.patternButtonNode.backgroundNode.enableSaturation = isColor
            self.blurButtonNode.backgroundNode.enableSaturation = isColor
            self.motionButtonNode.backgroundNode.enableSaturation = isColor
            self.colorsButtonNode.backgroundNode.enableSaturation = isColor
            self.playButtonNode.enableSaturation = isColor
                        
            var canShare = false
            var canSwitchTheme = false
            var canEdit = false
            
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
                            canShare = true
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
                            canShare = true
                        case let .file(file):
                            let dimensions = file.file.dimensions ?? PixelDimensions(width: 2000, height: 4000)
                            contentSize = dimensions.cgSize
                            displaySize = dimensions.cgSize.dividedByScreenScale().integralFloor
                            var convertedRepresentations: [ImageRepresentationWithReference] = []
                            for representation in file.file.previewRepresentations {
                                convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: reference(for: representation.resource, media: file.file, message: message, slug: file.slug)))
                            }
                            convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false), reference: reference(for: file.file.resource, media: file.file, message: message, slug: file.slug)))
                            
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
                            fetchSignal = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: convertedRepresentations[convertedRepresentations.count - 1].reference)
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
                                canShare = true
                            }
                            colorSignal = .single(UIColor(rgb: 0x000000, alpha: 0.3))
                        case let .image(representations, _):
                            if let largestSize = largestImageRepresentation(representations) {
                                contentSize = largestSize.dimensions.cgSize
                                displaySize = largestSize.dimensions.cgSize.dividedByScreenScale().integralFloor
                                
                                let convertedRepresentations: [ImageRepresentationWithReference] = representations.map({ ImageRepresentationWithReference(representation: $0, reference: .wallpaper(wallpaper: nil, resource: $0.resource)) })
                                signal = wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, alwaysShowThumbnailFirst: true, autoFetchFullSize: false)
                                
                                if let largestIndex = convertedRepresentations.firstIndex(where: { $0.representation == largestSize }) {
                                    fetchSignal = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: convertedRepresentations[largestIndex].reference)
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
                            colorSignal = .single(UIColor(rgb: 0x000000, alpha: 0.3))
                    }
                    self.cropNode.removeFromSupernode()
                case let .asset(asset):
                    let dimensions = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                    contentSize = dimensions
                    displaySize = dimensions.aspectFittedOrSmaller(CGSize(width: 2048.0, height: 2048.0))
                    signal = photoWallpaper(postbox: context.account.postbox, photoLibraryResource: PhotoLibraryMediaResource(localIdentifier: asset.localIdentifier, uniqueId: Int64.random(in: Int64.min ... Int64.max)))
                    fetchSignal = .complete()
                    statusSignal = .single(.Local)
                    subtitleSignal = .single(nil)
                    colorSignal = .single(UIColor(rgb: 0x000000, alpha: 0.3))
                    self.wrapperNode.addSubnode(self.cropNode)
                    showPreviewTooltip = true
                    canSwitchTheme = true
                    canEdit = true
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
                        displaySize = imageDimensions.aspectFittedOrSmaller(CGSize(width: 2048.0, height: 2048.0))
                        
                        var representations: [TelegramMediaImageRepresentation] = []
                        if let thumbnailResource = thumbnailResource, let thumbnailDimensions = thumbnailDimensions {
                            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailDimensions), resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                        }
                        representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(imageDimensions), resource: imageResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                        let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        
                        signal = chatMessagePhoto(postbox: context.account.postbox, userLocation: .other, photoReference: .standalone(media: tmpImage))
                        fetchSignal = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: .media(media: .standalone(media: tmpImage), resource: imageResource))
                        statusSignal = context.account.postbox.mediaBox.resourceStatus(imageResource)
                    } else {
                        displaySize = CGSize(width: 1.0, height: 1.0)
                        contentSize = displaySize
                        signal = .never()
                        fetchSignal = .complete()
                        statusSignal = .single(.Local)
                    }
                    colorSignal = .single(UIColor(rgb: 0x000000, alpha: 0.3))
                    subtitleSignal = .single(nil)
                    self.wrapperNode.addSubnode(self.cropNode)
                    showPreviewTooltip = true
                    canSwitchTheme = true
            }
            self.contentSize = contentSize
            
            if case .wallpaper = source {
                canSwitchTheme = true
            } else if case let .list(_, _, type) = source, case .colors = type {
                canSwitchTheme = true
            }
            
            if canSwitchTheme {
                self.dayNightButtonNode.isHidden = false
                self.shareButtonNode.isHidden = true
            } else {
                self.dayNightButtonNode.isHidden = true
                self.shareButtonNode.isHidden = !canShare
            }
            self.editButtonNode.isHidden = !canEdit
            
            if self.cropNode.supernode == nil {
                self.imageNode.contentMode = .scaleAspectFill
                self.wrapperNode.addSubnode(self.imageNode)
                self.wrapperNode.addSubnode(self.nativeNode)
            } else {
                self.wrapperNode.insertSubnode(self.nativeNode, at: 0)
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
                        if actualSize.width > 960.0 || actualSize.height > 960.0 {
                            image = TGScaleImageToPixelSize(image, actualSize.fitted(CGSize(width: 960.0, height: 960.0)))
                        }
                    }
                    strongSelf.blurredNode.image = image
                    imagePromise.set(.single(image))
                    
                    if case .asset = entry, let image, let data = image.jpegData(compressionQuality: 0.5) {
                        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                        strongSelf.context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                        
                        let wallpaper: TelegramWallpaper = .image([TelegramMediaImageRepresentation(dimensions: PixelDimensions(image.size), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)], WallpaperSettings())
                        strongSelf.nativeNode.update(wallpaper: wallpaper)
                    }
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
            }))
        } else if self.arguments.patternEnabled != previousArguments.patternEnabled {
            self.patternButtonNode.isSelected = self.arguments.patternEnabled
        }

        if let (layout, _) = self.validLayout {
            self.updateButtonsLayout(layout: layout, offset: CGPoint(), transition: .immediate)
            self.updateMessagesLayout(layout: layout, offset: CGPoint(), transition: .immediate)
        }
        
        if showPreviewTooltip {
            Queue.mainQueue().after(0.35) {
                self.maybePresentPreviewTooltip()
            }
            if self.isDarkAppearance && !self.didChangeAppearance {
                Queue.mainQueue().justDispatch {
                    self.didChangeAppearance = true
                    self.animateIntensityChange(delay: 0.35)
                }
            }
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
        guard !self.animatingBlur else {
            return
        }
        let value = !self.blurButtonNode.isSelected
        self.blurButtonNode.setSelected(value, animated: true)
        self.setBlurEnabled(value, animated: true)
    }
    
    private var animatingBlur = false
    func setBlurEnabled(_ enabled: Bool, animated: Bool) {
        let blurRadius: CGFloat = 30.0
        
        var animated = animated
        if animated, let (layout, _) = self.validLayout {
            animated = min(layout.size.width, layout.size.height) > 321.0
        } else {
            animated = false
        }
        
        if enabled {
            if self.blurredNode.supernode == nil {
                self.blurredNode.frame = self.imageNode.bounds
                self.imageNode.insertSubnode(self.blurredNode, at: 0)
            }
            
            if animated {
                self.animatingBlur = true
                self.blurredNode.blurView.blurRadius = 0.0
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIView.AnimationOptions(rawValue: 7 << 16), animations: {
                    self.blurredNode.blurView.blurRadius = blurRadius
                }, completion: { _ in
                    self.animatingBlur = false
                })
            } else {
                self.blurredNode.blurView.blurRadius = blurRadius
            }
        } else {
            if self.blurredNode.supernode != nil {
                if animated {
                    self.animatingBlur = true
                    UIView.animate(withDuration: 0.3, delay: 0.0, options: UIView.AnimationOptions(rawValue: 7 << 16), animations: {
                        self.blurredNode.blurView.blurRadius = 0.0
                    }, completion: { finished in
                        self.animatingBlur = false
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
        
        var additionalYOffset: CGFloat = 0.0
        var canEditIntensity = false
        if let source = self.source {
            switch source {
            case .asset, .contextResult:
                canEditIntensity = true
            case let .wallpaper(wallpaper, _, _, _, _, _):
                if case let .file(file) = wallpaper, !file.isPattern {
                    canEditIntensity = true
                }
            default:
                break
            }
        }
        if canEditIntensity && self.isDarkAppearance {
            additionalYOffset -= 44.0
        }

        let buttonSpacing: CGFloat = 18.0
        
        let toolbarHeight: CGFloat = 66.0
        
        let leftButtonFrame = CGRect(origin: CGPoint(x: floor(layout.size.width / 2.0 - buttonSize.width - buttonSpacing) + offset.x, y: layout.size.height - toolbarHeight - layout.intrinsicInsets.bottom - 54.0 + offset.y + additionalYOffset), size: buttonSize)
        let centerButtonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonSize.width) / 2.0) + offset.x, y: layout.size.height - toolbarHeight - layout.intrinsicInsets.bottom - 54.0 + offset.y + additionalYOffset), size: buttonSize)
        let rightButtonFrame = CGRect(origin: CGPoint(x: ceil(layout.size.width / 2.0 + buttonSpacing) + offset.x, y: layout.size.height - toolbarHeight - layout.intrinsicInsets.bottom - 54.0 + offset.y + additionalYOffset), size: buttonSize)
        
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
        
        let sliderSize = CGSize(width: 268.0, height: 30.0)
        var sliderFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - sliderSize.width) / 2.0) + offset.x, y: layout.size.height - toolbarHeight - layout.intrinsicInsets.bottom - 52.0 + offset.y), size: sliderSize)
        var sliderAlpha: CGFloat = 0.0
        var sliderScale: CGFloat = 0.2
        if !additionalYOffset.isZero {
            sliderAlpha = 1.0
            sliderScale = 1.0
        } else {
            sliderFrame = sliderFrame.offsetBy(dx: 0.0, dy: 22.0)
        }
                
        let cancelSize = self.cancelButtonNode.measure(layout.size)
        let cancelFrame = CGRect(origin: CGPoint(x: 16.0 + offset.x, y: 16.0), size: cancelSize)
        let shareFrame = CGRect(origin: CGPoint(x: layout.size.width - 16.0 - 28.0 + offset.x, y: 16.0), size: CGSize(width: 28.0, height: 28.0))
        let editFrame = CGRect(origin: CGPoint(x: layout.size.width - 16.0 - 28.0 + offset.x - 46.0, y: 16.0), size: CGSize(width: 28.0, height: 28.0))
        
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
        transition.updateAlpha(node: self.playButtonNode, alpha: playAlpha * alpha)
        transition.updateSublayerTransformScale(node: self.playButtonNode, scale: max(0.1, playAlpha))
        
        transition.updateFrameAsPositionAndBounds(node: self.sliderNode, frame: sliderFrame)
        transition.updateAlpha(node: self.sliderNode, alpha: sliderAlpha * alpha)
        transition.updateTransformScale(node: self.sliderNode, scale: sliderScale)
        self.sliderNode.updateLayout(size: sliderFrame.size)
        
        transition.updateFrame(node: self.cancelButtonNode, frame: cancelFrame)
        transition.updateFrame(node: self.shareButtonNode, frame: shareFrame)
        transition.updateFrame(node: self.dayNightButtonNode, frame: shareFrame)
        transition.updateFrame(node: self.editButtonNode, frame: editFrame)
    }
    
    private func updateMessagesLayout(layout: ContainerViewLayout, offset: CGPoint, transition: ContainedViewLayoutTransition) {
        self.nativeNode.updateBubbleTheme(bubbleTheme: self.presentationData.theme, bubbleCorners: self.presentationData.chatBubbleCorners)
        
        var bottomInset: CGFloat = 132.0

        var items: [ListViewItem] = []
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
        let otherPeerId = self.context.account.peerId
        var peers = SimpleDictionary<PeerId, Peer>()
        let messages = SimpleDictionary<MessageId, Message>()
        peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_PreviewReplyAuthor, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [])
        peers[otherPeerId] = TelegramUser(id: otherPeerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_PreviewReplyAuthor, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [])
        
        var topMessageText = ""
        var bottomMessageText = ""
        var serviceMessageText: String?
        var currentWallpaper: TelegramWallpaper = self.presentationData.chatWallpaper
        if let entry = self.entry, case let .wallpaper(wallpaper, _) = entry {
            currentWallpaper = wallpaper
        }
        
        var canEditIntensity = false
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
                
                    if case let .wallpaper(wallpaper, _, _, _, _, _) = source, case let .file(file) = wallpaper, !file.isPattern {
                        canEditIntensity = true
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
                    canEditIntensity = true
                case .customColor:
                    topMessageText = presentationData.strings.WallpaperPreview_CustomColorTopText
                    bottomMessageText = presentationData.strings.WallpaperPreview_CustomColorBottomText
            }
        }
        
        if let mode = self.mode, case let .peer(peer, existing) = mode {
            topMessageText = presentationData.strings.WallpaperPreview_ChatTopText
            bottomMessageText = presentationData.strings.WallpaperPreview_ChatBottomText
            if !existing {
                serviceMessageText = presentationData.strings.WallpaperPreview_NotAppliedInfo(peer.compactDisplayTitle).string
            }
        }

        if canEditIntensity && self.isDarkAppearance {
            bottomInset += 44.0
        }
        
        let theme = self.presentationData.theme
                   
        let message1 = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 2), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66001, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: bottomMessageText, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil)
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: [message1], theme: theme, strings: self.presentationData.strings, wallpaper: currentWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.nativeNode, availableReactions: nil, isCentered: false))
        
        let message2 = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: topMessageText, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil)
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: [message2], theme: theme, strings: self.presentationData.strings, wallpaper: currentWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.nativeNode, availableReactions: nil, isCentered: false))
        
        if let serviceMessageText {
            let attributedText = convertMarkdownToAttributes(NSAttributedString(string: serviceMessageText))
            let entities = generateChatInputTextEntities(attributedText)
            
            let message3 = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66002, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [TelegramMediaAction(action: .customText(text: attributedText.string, entities: entities))], peers: peers, associatedMessages: messages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil)
            items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: [message3], theme: theme, strings: self.presentationData.strings, wallpaper: currentWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.nativeNode, availableReactions: nil, isCentered: false))
        }
        
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, availableHeight: layout.size.height)
        if let messageNodes = self.messageNodes {
            for i in 0 ..< items.count {
                items[i].updateNode(async: { f in f() }, node: { return messageNodes[i] }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None) { layout, apply in
                    let nodeFrame = CGRect(origin: messageNodes[i].frame.origin, size: CGSize(width: layout.size.width, height: layout.size.height))

                    messageNodes[i].contentSize = layout.contentSize
                    messageNodes[i].insets = layout.insets
                    messageNodes[i].frame = nodeFrame

                    apply(ListViewItemApply(isOnScreen: true))
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
        
        if let _ = serviceMessageText, let messageNodes = self.messageNodes, let node = messageNodes.last {
            if let backgroundNode = node.subnodes?.first?.subnodes?.first?.subnodes?.first?.subnodes?.first, let backdropNode = node.subnodes?.first?.subnodes?.first?.subnodes?.first?.subnodes?.last?.subnodes?.last?.subnodes?.first {
                backdropNode.isHidden = true
                let serviceBackgroundFrame = backgroundNode.view.convert(backgroundNode.bounds, to: self.view).offsetBy(dx: 0.0, dy: -1.0).insetBy(dx: 0.0, dy: -1.0)
                transition.updateFrame(node: self.serviceBackgroundNode, frame: serviceBackgroundFrame)
                self.serviceBackgroundNode.update(size: serviceBackgroundFrame.size, cornerRadius: serviceBackgroundFrame.height / 2.0, transition: transition)
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
        self.buttonsContainerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        if self.cropNode.supernode == nil {
            self.imageNode.frame = self.wrapperNode.bounds
            self.nativeNode.frame = self.wrapperNode.bounds
            
            let displayMode: WallpaperDisplayMode
            if case .regular = layout.metrics.widthClass {
                displayMode = .aspectFit
            } else {
                displayMode = .aspectFill
            }
            
            self.nativeNode.updateLayout(size: self.nativeNode.bounds.size, displayMode: displayMode, transition: .immediate)
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
            
            let displayMode: WallpaperDisplayMode
            if case .regular = layout.metrics.widthClass {
                displayMode = .aspectFit
            } else {
                displayMode = .aspectFill
            }
            
            self.nativeNode.frame = self.wrapperNode.bounds
            self.nativeNode.updateLayout(size: self.nativeNode.bounds.size, displayMode: displayMode, transition: .immediate)
        }
        self.brightnessNode.frame = self.imageNode.bounds
        
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
    
    private var displayedPreviewTooltip = false
    private func maybePresentPreviewTooltip() {
        guard !self.displayedPreviewTooltip else {
            return
        }
        
        let frame = self.dayNightButtonNode.view.convert(self.dayNightButtonNode.bounds, to: self.view)
        let currentTimestamp = Int32(Date().timeIntervalSince1970)
        
        let isDark = self.isDarkAppearance
        
        let signal: Signal<(Int32, Int32), NoError>
        if isDark {
            signal = ApplicationSpecificNotice.getChatWallpaperLightPreviewTip(accountManager: self.context.sharedContext.accountManager)
        } else {
            signal = ApplicationSpecificNotice.getChatWallpaperDarkPreviewTip(accountManager: self.context.sharedContext.accountManager)
        }
        
        let _ = (signal
        |> deliverOnMainQueue).start(next: { [weak self] count, timestamp in
            if let strongSelf = self, (count < 2 && currentTimestamp > timestamp + 24 * 60 * 60) {
                strongSelf.displayedPreviewTooltip = true
                
                let controller = TooltipScreen(account: strongSelf.context.account, sharedContext: strongSelf.context.sharedContext, text: isDark ? strongSelf.presentationData.strings.WallpaperPreview_PreviewInDayMode : strongSelf.presentationData.strings.WallpaperPreview_PreviewInNightMode, style: .customBlur(UIColor(rgb: 0x333333, alpha: 0.35)), icon: nil, location: .point(frame.offsetBy(dx: 1.0, dy: 6.0), .bottom), displayDuration: .custom(3.0), inset: 3.0, shouldDismissOnTouch: { _ in
                    return .dismiss(consume: false)
                })
                strongSelf.galleryController()?.present(controller, in: .current)

                if isDark {
                    let _ = ApplicationSpecificNotice.incrementChatWallpaperLightPreviewTip(accountManager: strongSelf.context.sharedContext.accountManager, timestamp: currentTimestamp).start()
                } else {
                    let _ = ApplicationSpecificNotice.incrementChatWallpaperDarkPreviewTip(accountManager: strongSelf.context.sharedContext.accountManager, timestamp: currentTimestamp).start()
                }
            }
        })
    }
}
