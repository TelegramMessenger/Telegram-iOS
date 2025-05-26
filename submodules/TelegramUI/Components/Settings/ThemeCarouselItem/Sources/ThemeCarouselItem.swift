import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import MergeLists
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import WallpaperResources
import AccountContext
import AppBundle
import ContextUI
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ShimmerEffect
import StickerResources
import ListItemComponentAdaptor
import HexColor

private struct ThemeCarouselThemeEntry: Comparable, Identifiable {
    let index: Int
    let emojiFile: TelegramMediaFile?
    let themeReference: PresentationThemeReference?
    let nightMode: Bool
    let channelMode: Bool
    let themeSpecificAccentColors: [Int64: PresentationThemeAccentColor]
    let themeSpecificChatWallpapers: [Int64: TelegramWallpaper]
    var selected: Bool
    let theme: PresentationTheme
    let strings: PresentationStrings
    let wallpaper: TelegramWallpaper?
    
    var stableId: Int {
        return index
    }
    
    static func ==(lhs: ThemeCarouselThemeEntry, rhs: ThemeCarouselThemeEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.emojiFile?.fileId != rhs.emojiFile?.fileId {
            return false
        }
        if lhs.themeReference?.index != rhs.themeReference?.index {
            return false
        }
        if lhs.nightMode != rhs.nightMode {
            return false
        }
        if lhs.channelMode != rhs.channelMode {
            return false
        }
        if lhs.themeSpecificAccentColors != rhs.themeSpecificAccentColors {
            return false
        }
        if lhs.themeSpecificChatWallpapers != rhs.themeSpecificChatWallpapers {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.wallpaper != rhs.wallpaper {
            return false
        }
        return true
    }
    
    static func <(lhs: ThemeCarouselThemeEntry, rhs: ThemeCarouselThemeEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, action: @escaping (PresentationThemeReference?) -> Void, contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?) -> ListViewItem {
        return ThemeCarouselThemeIconItem(context: context, emojiFile: self.emojiFile, themeReference: self.themeReference, nightMode: self.nightMode, channelMode: self.channelMode, themeSpecificAccentColors: self.themeSpecificAccentColors, themeSpecificChatWallpapers: self.themeSpecificChatWallpapers, selected: self.selected, theme: self.theme, strings: self.strings, wallpaper: self.wallpaper, action: action, contextAction: contextAction)
    }
}


public class ThemeCarouselThemeIconItem: ListViewItem {
    public let context: AccountContext
    public let emojiFile: TelegramMediaFile?
    public let themeReference: PresentationThemeReference?
    public let nightMode: Bool
    public let channelMode: Bool
    public let themeSpecificAccentColors: [Int64: PresentationThemeAccentColor]
    public let themeSpecificChatWallpapers: [Int64: TelegramWallpaper]
    public let selected: Bool
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let wallpaper: TelegramWallpaper?
    public let action: (PresentationThemeReference?) -> Void
    public let contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?
    
    public init(context: AccountContext, emojiFile: TelegramMediaFile?, themeReference: PresentationThemeReference?, nightMode: Bool, channelMode: Bool, themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], themeSpecificChatWallpapers: [Int64: TelegramWallpaper], selected: Bool, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper?, action: @escaping (PresentationThemeReference?) -> Void, contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?) {
        self.context = context
        self.emojiFile = emojiFile
        self.themeReference = themeReference
        self.nightMode = nightMode
        self.channelMode = channelMode
        self.themeSpecificAccentColors = themeSpecificAccentColors
        self.themeSpecificChatWallpapers = themeSpecificChatWallpapers
        self.selected = selected
        self.theme = theme
        self.strings = strings
        self.wallpaper = wallpaper
        self.action = action
        self.contextAction = contextAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeCarouselThemeItemIconNode()
            let (nodeLayout, apply) = node.asyncLayout()(self, params)
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply(false)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ThemeCarouselThemeItemIconNode)
            if let nodeValue = node() as? ThemeCarouselThemeItemIconNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable = true
    public func selected(listView: ListView) {
        self.action(self.themeReference)
    }
}

private let textFont = Font.regular(12.0)
private let selectedTextFont = Font.bold(12.0)

private var cachedBorderImages: [String: UIImage] = [:]
private func generateBorderImage(theme: PresentationTheme, bordered: Bool, selected: Bool) -> UIImage? {
    let key = "\(theme.list.itemBlocksBackgroundColor.hexString)_\(selected ? "s" + theme.list.itemAccentColor.hexString : theme.list.disclosureArrowColor.hexString)"
    if let image = cachedBorderImages[key] {
        return image
    } else {
        let image = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)

            let lineWidth: CGFloat
            if selected {
                lineWidth = 2.0
                context.setLineWidth(lineWidth)
                context.setStrokeColor(theme.list.itemBlocksBackgroundColor.cgColor)
                
                context.strokeEllipse(in: bounds.insetBy(dx: 3.0 + lineWidth / 2.0, dy: 3.0 + lineWidth / 2.0))
                
                var accentColor = theme.list.itemAccentColor
                if accentColor.rgb == 0xffffff {
                    accentColor = UIColor(rgb: 0x999999)
                }
                context.setStrokeColor(accentColor.cgColor)
            } else {
                context.setStrokeColor(theme.list.disclosureArrowColor.withAlphaComponent(0.4).cgColor)
                lineWidth = 1.0
            }

            if bordered || selected {
                context.setLineWidth(lineWidth)
                context.strokeEllipse(in: bounds.insetBy(dx: 1.0 + lineWidth / 2.0, dy: 1.0 + lineWidth / 2.0))
            }
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 16)
        cachedBorderImages[key] = image
        return image
    }
}


private final class ThemeCarouselThemeItemIconNode: ListViewItemNode {
    private let containerNode: ASDisplayNode
    private let emojiContainerNode: ASDisplayNode
    private let imageNode: TransformImageNode
    private let overlayNode: ASImageNode
    private let textNode: TextNode
    private let emojiNode: TextNode
    private let emojiImageNode: TransformImageNode
    private var animatedStickerNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode
    var snapshotView: UIView?
    
    private let activateAreaNode: AccessibilityAreaNode
    
    var item: ThemeCarouselThemeIconItem?
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.visibilityStatus = self.visibility != .none
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                self.animatedStickerNode?.visibility = self.visibilityStatus
            }
        }
    }
    
    private let stickerFetchedDisposable = MetaDisposable()

    init() {
        self.containerNode = ASDisplayNode()
        self.emojiContainerNode = ASDisplayNode()

        self.imageNode = TransformImageNode()
        self.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 82.0, height: 108.0))
        self.imageNode.isLayerBacked = true
        self.imageNode.cornerRadius = 14.0
        self.imageNode.clipsToBounds = true
        self.imageNode.contentAnimations = [.subsequentUpdates]
        
        self.overlayNode = ASImageNode()
        self.overlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 84.0, height: 110.0))
        self.overlayNode.isLayerBacked = true

        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.emojiNode = TextNode()
        self.emojiNode.isUserInteractionEnabled = false
        self.emojiNode.displaysAsynchronously = false
        
        self.emojiImageNode = TransformImageNode()
        
        self.placeholderNode = StickerShimmerEffectNode()
        
        self.activateAreaNode = AccessibilityAreaNode()

        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.overlayNode)
        self.containerNode.addSubnode(self.textNode)
        
        self.addSubnode(self.emojiContainerNode)
        self.emojiContainerNode.addSubnode(self.emojiNode)
        self.emojiContainerNode.addSubnode(self.emojiImageNode)
        self.emojiContainerNode.addSubnode(self.placeholderNode)
        
        var firstTime = true
        self.emojiImageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                strongSelf.removePlaceholder(animated: !firstTime)
                if firstTime {
                    strongSelf.emojiImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            firstTime = false
        }
        
        self.addSubnode(self.activateAreaNode)
    }

    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOS 13.0, *) {
            self.imageNode.layer.cornerCurve = .continuous
        }
    }
    
    private func removePlaceholder(animated: Bool) {
        if !animated {
            self.placeholderNode.removeFromSupernode()
        } else {
            self.placeholderNode.alpha = 0.0
            self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.placeholderNode.removeFromSupernode()
            })
        }
    }
    
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        let emojiFrame = CGRect(origin: CGPoint(x: 33.0, y: 79.0), size: CGSize(width: 24.0, height: 24.0))
        self.placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + emojiFrame.minX, y: rect.minY + emojiFrame.minY), size: emojiFrame.size), within: containerSize)
    }
    
    override func selected() {
        let wasSelected = self.item?.selected ?? false
        super.selected()
        
        if let animatedStickerNode = self.animatedStickerNode {
            Queue.mainQueue().after(0.1) {
                if !wasSelected {
                    animatedStickerNode.seekTo(.frameIndex(0))
                    animatedStickerNode.play(firstFrame: false, fromIndex: nil)
                    
                    let scale: CGFloat = 2.6
                    animatedStickerNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
                    animatedStickerNode.layer.animateSpring(from: 1.0 as NSNumber, to: scale as NSNumber, keyPath: "transform.scale", duration: 0.45)
                    
                    animatedStickerNode.completed = { [weak animatedStickerNode, weak self] _ in
                        guard let item = self?.item, item.selected else {
                            return
                        }
                        animatedStickerNode?.transform = CATransform3DIdentity
                        animatedStickerNode?.layer.animateSpring(from: scale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)
                    }
                }
            }
        }
        
    }
    
    func asyncLayout() -> (ThemeCarouselThemeIconItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeEmojiLayout = TextNode.asyncLayout(self.emojiNode)
        let makeImageLayout = self.imageNode.asyncLayout()
        
        let currentItem = self.item

        return { [weak self] item, params in
            var updatedThemeReference = false
            var updatedTheme = false
            var updatedNightMode = false
            var updatedChannelMode = false
            var updatedWallpaper = false
            var updatedSelected = false
            
            if currentItem?.themeReference != item.themeReference {
                updatedThemeReference = true
            }
            if currentItem?.nightMode != item.nightMode {
                updatedNightMode = true
            }
            if currentItem?.channelMode != item.channelMode {
                updatedChannelMode = true
            }
            if currentItem?.wallpaper != item.wallpaper {
                updatedWallpaper = true
            }
            if currentItem?.theme !== item.theme {
                updatedTheme = true
            }
            if currentItem?.selected != item.selected {
                updatedSelected = true
            }
            
            let text = NSAttributedString(string: item.strings.Wallpaper_NoWallpaper, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor)
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))

            var string: String?
            if item.themeReference == nil {
                string = "❌"
                self?.imageNode.backgroundColor = item.theme.list.mediaPlaceholderColor
            } else if let _ = item.themeReference?.emoticon {
            } else {
                string = item.channelMode ? "" : "🎨" 
            }
            
            let emojiTitle = NSAttributedString(string: string ?? "", font: Font.regular(20.0), textColor: .black)
            let (_, emojiApply) = makeEmojiLayout(TextNodeLayoutArguments(attributedString: emojiTitle, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 120.0, height: 90.0), insets: UIEdgeInsets())
            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                        
                    if updatedThemeReference || updatedWallpaper || updatedNightMode || updatedChannelMode {
                        if var themeReference = item.themeReference {
                            if case .builtin = themeReference, item.nightMode {
                                themeReference = .builtin(.night)
                            }
                            
                            let color = item.themeSpecificAccentColors[themeReference.index]
                            let wallpaper = item.themeSpecificChatWallpapers[themeReference.index]
                            
                            strongSelf.imageNode.setSignal(themeIconImage(account: item.context.account, accountManager: item.context.sharedContext.accountManager, theme: themeReference, color: color, wallpaper: wallpaper ?? item.wallpaper, nightMode: item.nightMode, channelMode: item.channelMode, emoticon: true))
                            strongSelf.imageNode.backgroundColor = nil
                        } else {
                            
                        }
                    }
                    
                    if updatedTheme || updatedSelected {
                        strongSelf.overlayNode.image = generateBorderImage(theme: item.theme, bordered: false, selected: item.selected)
                    }
                    
                    if !item.selected && currentItem?.selected == true, let animatedStickerNode = strongSelf.animatedStickerNode {
                        animatedStickerNode.transform = CATransform3DIdentity
                        
                        let initialScale: CGFloat = CGFloat((animatedStickerNode.value(forKeyPath: "layer.presentationLayer.transform.scale.x") as? NSNumber)?.floatValue ?? 1.0)
                        animatedStickerNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)
                    }
                                        
                    strongSelf.containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(x: 15.0, y: -15.0), size: CGSize(width: 90.0, height: 120.0))
                    
                    strongSelf.emojiContainerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                    strongSelf.emojiContainerNode.frame = CGRect(origin: CGPoint(x: 15.0, y: -15.0), size: CGSize(width: 90.0, height: 120.0))
                    
                    let _ = emojiApply()

                    let imageSize = CGSize(width: 82.0, height: 108.0)
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: 4.0, y: 6.0), size: imageSize)
                    let applyLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: .clear))
                    applyLayout()
                    
                    strongSelf.overlayNode.frame = strongSelf.imageNode.frame.insetBy(dx: -1.0, dy: -1.0)
                    strongSelf.emojiNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 78.0), size: CGSize(width: 90.0, height: 30.0))
                    strongSelf.emojiNode.isHidden = string == nil
                    
                    let _ = textApply()
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((90.0 - textLayout.size.width) / 2.0), y: 24.0), size: textLayout.size)
                    strongSelf.textNode.isHidden = item.themeReference != nil
                    
                    let emojiFrame = CGRect(origin: CGPoint(x: 33.0, y: 79.0), size: CGSize(width: 24.0, height: 24.0))
                    if let file = item.emojiFile, currentItem?.emojiFile == nil {
                        let imageApply = strongSelf.emojiImageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: emojiFrame.size, boundingSize: emojiFrame.size, intrinsicInsets: UIEdgeInsets()))
                        imageApply()
                        strongSelf.emojiImageNode.setSignal(chatMessageStickerPackThumbnail(postbox: item.context.account.postbox, resource: file.resource, animated: true, nilIfEmpty: true))
                        strongSelf.emojiImageNode.frame = emojiFrame
                        
                        let animatedStickerNode: AnimatedStickerNode
                        if let current = strongSelf.animatedStickerNode {
                            animatedStickerNode = current
                        } else {
                            animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                            animatedStickerNode.started = { [weak self] in
                                self?.emojiImageNode.isHidden = true
                            }
                            strongSelf.animatedStickerNode = animatedStickerNode
                            strongSelf.emojiContainerNode.insertSubnode(animatedStickerNode, belowSubnode: strongSelf.placeholderNode)
                            let pathPrefix = item.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                            animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: item.context.account, resource: file.resource), width: 128, height: 128, playbackMode: .still(.start), mode: .direct(cachePathPrefix: pathPrefix))
                            
                            animatedStickerNode.anchorPoint = CGPoint(x: 0.5, y: 1.0)
                        }
                        animatedStickerNode.autoplay = true
                        animatedStickerNode.visibility = strongSelf.visibilityStatus
                        
                        strongSelf.stickerFetchedDisposable.set(fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: MediaResourceReference.media(media: .standalone(media: file), resource: file.resource)).start())
                        
                        let thumbnailDimensions = PixelDimensions(width: 512, height: 512)
                        strongSelf.placeholderNode.update(backgroundColor: nil, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.2), shimmeringColor: UIColor(rgb: 0xffffff, alpha: 0.3), data: file.immediateThumbnailData, size: emojiFrame.size, enableEffect: item.context.sharedContext.energyUsageSettings.fullTranslucency, imageSize: thumbnailDimensions.cgSize)
                        strongSelf.placeholderNode.frame = emojiFrame
                    }
                    
                    if let animatedStickerNode = strongSelf.animatedStickerNode {
                        animatedStickerNode.frame = emojiFrame
                        animatedStickerNode.updateLayout(size: emojiFrame.size)
                    }
                    
                    let presentationData = item.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.activateAreaNode.accessibilityLabel = item.themeReference?.emoticon.flatMap { presentationData.strings.Appearance_VoiceOver_Theme($0).string }
                    if item.selected {
                        strongSelf.activateAreaNode.accessibilityTraits = [.button, .selected]
                    } else {
                        strongSelf.activateAreaNode.accessibilityTraits = [.button]
                    }
                    
                    strongSelf.activateAreaNode.frame = CGRect(origin: .zero, size: itemLayout.size)
                }
            })
        }
    }
    
    func prepareCrossfadeTransition() {
        guard self.snapshotView == nil else {
            return
        }
        
        if let snapshotView = self.containerNode.view.snapshotView(afterScreenUpdates: false) {
            snapshotView.transform = self.containerNode.view.transform
            snapshotView.frame = self.containerNode.view.frame
            self.view.insertSubview(snapshotView, aboveSubview: self.containerNode.view)
            self.snapshotView = snapshotView
        }
    }
    
    func animateCrossfadeTransition() {
        guard self.snapshotView?.layer.animationKeys()?.isEmpty ?? true else {
            return
        }
        
        self.snapshotView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak self] _ in
            self?.snapshotView?.removeFromSuperview()
            self?.snapshotView = nil
        })
    }
        
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        super.animateInsertion(currentTimestamp, duration: duration, options: options)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}

public class ThemeCarouselThemeItem: ListViewItem, ItemListItem, ListItemComponentAdaptor.ItemGenerator {
    public var sectionId: ItemListSectionId

    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let themes: [PresentationThemeReference]
    public let hasNoTheme: Bool
    public let animatedEmojiStickers: [String: [StickerPackItem]]
    public let themeSpecificAccentColors: [Int64: PresentationThemeAccentColor]
    public let themeSpecificChatWallpapers: [Int64: TelegramWallpaper]
    public let nightMode: Bool
    public let channelMode: Bool
    public let selectedWallpaper: TelegramWallpaper?
    public let currentTheme: PresentationThemeReference?
    public let updatedTheme: (PresentationThemeReference?) -> Void
    public let contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?
    public let tag: ItemListItemTag?

    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, themes: [PresentationThemeReference], hasNoTheme: Bool, animatedEmojiStickers: [String: [StickerPackItem]], themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], themeSpecificChatWallpapers: [Int64: TelegramWallpaper], nightMode: Bool, channelMode: Bool = false, selectedWallpaper: TelegramWallpaper? = nil, currentTheme: PresentationThemeReference?, updatedTheme: @escaping (PresentationThemeReference?) -> Void, contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?, tag: ItemListItemTag? = nil) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.themes = themes
        self.hasNoTheme = hasNoTheme
        self.animatedEmojiStickers = animatedEmojiStickers
        self.themeSpecificAccentColors = themeSpecificAccentColors
        self.themeSpecificChatWallpapers = themeSpecificChatWallpapers
        self.nightMode = nightMode
        self.channelMode = channelMode
        self.selectedWallpaper = selectedWallpaper
        self.currentTheme = currentTheme
        self.updatedTheme = updatedTheme
        self.contextAction = contextAction
        self.tag = tag
        self.sectionId = sectionId
    }

    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeCarouselThemeItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ThemeCarouselThemeItemNode {
                let makeLayout = nodeValue.asyncLayout()

                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    public func item() -> ListViewItem {
        return self
    }
    
    public static func ==(lhs: ThemeCarouselThemeItem, rhs: ThemeCarouselThemeItem) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.themes != rhs.themes {
            return false
        }
        if lhs.animatedEmojiStickers != rhs.animatedEmojiStickers {
            return false
        }
        if lhs.themeSpecificAccentColors != rhs.themeSpecificAccentColors {
            return false
        }
        if lhs.themeSpecificChatWallpapers != rhs.themeSpecificChatWallpapers {
            return false
        }
        if lhs.nightMode != rhs.nightMode {
            return false
        }
        if lhs.channelMode != rhs.channelMode {
            return false
        }
        if lhs.currentTheme != rhs.currentTheme {
            return false
        }
        
        return true
    }
}

private struct ThemeCarouselThemeItemNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let crossfade: Bool
    let entries: [ThemeCarouselThemeEntry]
    let updatePosition: Bool
}

private func preparedTransition(context: AccountContext, action: @escaping (PresentationThemeReference?) -> Void, contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?, from fromEntries: [ThemeCarouselThemeEntry], to toEntries: [ThemeCarouselThemeEntry], crossfade: Bool, updatePosition: Bool) -> ThemeCarouselThemeItemNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, action: action, contextAction: contextAction), directionHint: .Down) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, action: action, contextAction: contextAction), directionHint: nil) }
    
    return ThemeCarouselThemeItemNodeTransition(deletions: deletions, insertions: insertions, updates: updates, crossfade: crossfade, entries: toEntries, updatePosition: false)
}

private func ensureThemeVisible(listNode: ListView, themeReference: PresentationThemeReference, animated: Bool) -> Bool {
    var resultNode: ThemeCarouselThemeItemIconNode?
    listNode.forEachItemNode { node in
        if resultNode == nil, let node = node as? ThemeCarouselThemeItemIconNode {
            if node.item?.themeReference?.index == themeReference.index {
                resultNode = node
            }
        }
    }
    if let resultNode = resultNode {
        listNode.ensureItemNodeVisible(resultNode, animated: animated, overflow: 57.0)
        return true
    } else {
        return false
    }
}

public class ThemeCarouselThemeItemNode: ListViewItemNode, ItemListItemNode {
    private let containerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    private var snapshotView: UIView?
    
    private let listNode: ListView
    private var entries: [ThemeCarouselThemeEntry]?
    private var enqueuedTransitions: [ThemeCarouselThemeItemNodeTransition] = []
    private var initialized = false

    private var item: ThemeCarouselThemeItem?
    private var layoutParams: ListViewItemLayoutParams?

    private var tapping = false
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }

    public init() {
        self.containerNode = ASDisplayNode()
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true

        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true

        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true

        self.maskNode = ASImageNode()

        self.listNode = ListView()
        self.listNode.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)

        super.init(layerBacked: false, dynamicBounce: false)

        self.addSubnode(self.containerNode)
        self.addSubnode(self.listNode)
    }

    override public func didLoad() {
        super.didLoad()
        self.listNode.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    private func enqueueTransition(_ transition: ThemeCarouselThemeItemNodeTransition) {
        self.enqueuedTransitions.append(transition)
        
        if let _ = self.item {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        guard let item = self.item, let transition = self.enqueuedTransitions.first else {
            return
        }
        self.enqueuedTransitions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        if transition.crossfade {
            options.insert(.AnimateCrossfade)
        }
        options.insert(.Synchronous)
        
        var scrollToItem: ListViewScrollToItem?
        if !self.initialized || !self.tapping {
            if let index = transition.entries.firstIndex(where: { entry in
                return entry.themeReference?.index == item.currentTheme?.index
            }) {
                scrollToItem = ListViewScrollToItem(index: index, position: .bottom(-57.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Down)
                self.initialized = true
            }
        }
        
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
        })
    }

    public func asyncLayout() -> (_ item: ThemeCarouselThemeItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel

            contentSize = CGSize(width: params.width, height: 133.0)
            insets = itemListNeighborsGroupedInsets(neighbors, params)

            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size

            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params

                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.maskNode, at: 3)
                    }
                    
                    if params.isStandalone {
                        strongSelf.topStripeNode.isHidden = true
                        strongSelf.bottomStripeNode.isHidden = true
                        strongSelf.maskNode.isHidden = true
                        strongSelf.backgroundNode.isHidden = true
                    } else {
                        let hasCorners = itemListHasRoundedBlockLayout(params)
                        var hasTopCorners = false
                        var hasBottomCorners = false
                        switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            hasTopCorners = true
                            strongSelf.topStripeNode.isHidden = hasCorners
                        }
                        let bottomStripeInset: CGFloat
                        let bottomStripeOffset: CGFloat
                        switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = params.leftInset + 16.0
                            bottomStripeOffset = -separatorHeight
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                        }
                        
                        strongSelf.bottomStripeNode.isHidden = true
                        
                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        
                        strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }

                    strongSelf.containerNode.frame = CGRect(x: 0.0, y: 0.0, width: contentSize.width, height: contentSize.height)

                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)

                    var listInsets = UIEdgeInsets()
                    listInsets.top += params.leftInset + 12.0
                    listInsets.bottom += params.rightInset + 12.0
                    
                    strongSelf.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: contentSize.height, height: contentSize.width)
                    strongSelf.listNode.position = CGPoint(x: contentSize.width / 2.0, y: contentSize.height / 2.0 - 2.0)
                    strongSelf.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: contentSize.height, height: contentSize.width), insets: listInsets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                    
                    var entries: [ThemeCarouselThemeEntry] = []
                    var index: Int = 0
                    
                    var hasCurrentTheme = false
                    if item.hasNoTheme {
                        let selected = item.currentTheme == nil
                        if selected {
                            hasCurrentTheme = true
                        }
                        entries.append(ThemeCarouselThemeEntry(index: index, emojiFile: nil, themeReference: nil, nightMode: item.nightMode, channelMode: item.channelMode, themeSpecificAccentColors: item.themeSpecificAccentColors, themeSpecificChatWallpapers: item.themeSpecificChatWallpapers, selected: selected, theme: item.theme, strings: item.strings, wallpaper: nil))
                        index += 1
                    }
                    for theme in item.themes {
                        let selected = item.currentTheme?.index == theme.index
                        if selected {
                            hasCurrentTheme = true
                        }
                        let emojiFile = theme.emoticon.flatMap { item.animatedEmojiStickers[$0]?.first?.file }
                        entries.append(ThemeCarouselThemeEntry(index: index, emojiFile: emojiFile?._parse(), themeReference: theme, nightMode: item.nightMode, channelMode: item.channelMode, themeSpecificAccentColors: item.themeSpecificAccentColors, themeSpecificChatWallpapers: item.themeSpecificChatWallpapers, selected: selected, theme: item.theme, strings: item.strings, wallpaper: nil))
                        index += 1
                    }
                    
                    if !hasCurrentTheme {
                        entries.insert(ThemeCarouselThemeEntry(index: index, emojiFile: nil, themeReference: item.currentTheme, nightMode: false, channelMode: item.channelMode, themeSpecificAccentColors: item.themeSpecificAccentColors, themeSpecificChatWallpapers: item.themeSpecificChatWallpapers, selected: true, theme: item.theme, strings: item.strings, wallpaper: item.hasNoTheme ? item.selectedWallpaper : nil), at: item.hasNoTheme ? 1 : entries.count)
                    }
                    
                    let action: (PresentationThemeReference?) -> Void = { [weak self] themeReference in
                        if let strongSelf = self {
                            strongSelf.tapping = true
                            strongSelf.item?.updatedTheme(themeReference)
                            if let themeReference {
                                let _ = ensureThemeVisible(listNode: strongSelf.listNode, themeReference: themeReference, animated: true)
                            }
                            Queue.mainQueue().after(0.4) {
                                strongSelf.tapping = false
                            }
                        }
                    }
                    let previousEntries = strongSelf.entries ?? []
                    let crossfade = (previousEntries.count > 0 && previousEntries.count != entries.count) || (previousEntries.count > 0 && previousEntries.count < 3 && entries.count > 3)
                    let transition = preparedTransition(context: item.context, action: action, contextAction: item.contextAction, from: previousEntries, to: entries, crossfade: crossfade, updatePosition: false)
                    strongSelf.enqueueTransition(transition)
                    
                    strongSelf.entries = entries
                }
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }

    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    public func prepareCrossfadeTransition() {
        guard self.snapshotView == nil else {
            return
        }
        
        if let snapshotView = self.containerNode.view.snapshotView(afterScreenUpdates: false) {
            self.view.insertSubview(snapshotView, aboveSubview: self.containerNode.view)
            self.snapshotView = snapshotView
        }
        
        self.listNode.enumerateItemNodes { node in
            if let node = node as? ThemeCarouselThemeItemIconNode {
                node.prepareCrossfadeTransition()
            }
            return true
        }
    }
    
    public func animateCrossfadeTransition() {
        guard self.snapshotView?.layer.animationKeys()?.isEmpty ?? true else {
            return
        }

        var views: [UIView] = []
        if let snapshotView = self.snapshotView {
            views.append(snapshotView)
            self.snapshotView = nil
        }

        self.listNode.enumerateItemNodes { node in
            if let node = node as? ThemeCarouselThemeItemIconNode {
                if let snapshotView = node.snapshotView {
                    views.append(snapshotView)
                    node.snapshotView = nil
                }
            }
            return true
        }

        UIView.animate(withDuration: 0.3, animations: {
            for view in views {
                view.alpha = 0.0
            }
        }, completion: { _ in
            for view in views {
                view.removeFromSuperview()
            }
        })
    }
}
