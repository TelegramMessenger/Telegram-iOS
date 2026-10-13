import Foundation
import LottieSettings
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import ComponentDisplayAdapters
import ViewControllerComponent
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TelegramNotices
import PresentationDataUtils
import MergeLists
import MediaResources
import StickerResources
import WallpaperResources
import TooltipUI
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ShimmerEffect
import AttachmentUI
import AvatarNode
import AlertComponent
import SheetComponent
import ButtonComponent
import GlassBarButtonComponent
import BundleIconComponent
import LottieComponent
import MultilineTextComponent

private struct ThemeSettingsThemeEntry: Comparable, Identifiable {
    let index: Int
    let chatTheme: ChatTheme?
    let emojiFile: TelegramMediaFile?
    let themeReference: PresentationThemeReference?
    let peer: EnginePeer?
    let nightMode: Bool
    var selected: Bool
    let theme: PresentationTheme
    let strings: PresentationStrings
    let wallpaper: TelegramWallpaper?
    
    var stableId: String {
        return self.chatTheme?.id ?? "\(self.index)"
    }
    
    static func ==(lhs: ThemeSettingsThemeEntry, rhs: ThemeSettingsThemeEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.chatTheme != rhs.chatTheme {
            return false
        }
        if lhs.themeReference?.index != rhs.themeReference?.index {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.nightMode != rhs.nightMode {
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
    
    static func <(lhs: ThemeSettingsThemeEntry, rhs: ThemeSettingsThemeEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, action: @escaping (ChatTheme?) -> Void) -> ListViewItem {
        return ThemeSettingsThemeIconItem(context: context, chatTheme: self.chatTheme, emojiFile: self.emojiFile, themeReference: self.themeReference, peer: self.peer, nightMode: self.nightMode, selected: self.selected, theme: self.theme, strings: self.strings, wallpaper: self.wallpaper, action: action)
    }
}

private class ThemeSettingsThemeIconItem: ListViewItem {
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    let context: AccountContext
    let chatTheme: ChatTheme?
    let emojiFile: TelegramMediaFile?
    let themeReference: PresentationThemeReference?
    let peer: EnginePeer?
    let nightMode: Bool
    let selected: Bool
    let theme: PresentationTheme
    let strings: PresentationStrings
    let wallpaper: TelegramWallpaper?
    let action: (ChatTheme?) -> Void
    
    public init(
        context: AccountContext,
        chatTheme: ChatTheme?,
        emojiFile: TelegramMediaFile?,
        themeReference: PresentationThemeReference?,
        peer: EnginePeer?,
        nightMode: Bool,
        selected: Bool,
        theme: PresentationTheme,
        strings: PresentationStrings,
        wallpaper: TelegramWallpaper?,
        action: @escaping (ChatTheme?) -> Void
    ) {
        self.context = context
        self.chatTheme = chatTheme
        self.emojiFile = emojiFile
        self.themeReference = themeReference
        self.peer = peer
        self.nightMode = nightMode
        self.selected = selected
        self.theme = theme
        self.strings = strings
        self.wallpaper = wallpaper
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsThemeItemIconNode()
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ThemeSettingsThemeItemIconNode)
            if let nodeValue = node() as? ThemeSettingsThemeItemIconNode {
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
        self.action(self.chatTheme)
    }
}

private struct ThemeSettingsThemeItemNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let crossfade: Bool
    let entries: [ThemeSettingsThemeEntry]
}

private func ensureThemeVisible(listNode: ListView, themeId: String?, animated: Bool) -> Bool {
    var resultNode: ThemeSettingsThemeItemIconNode?
    var previousNode: ThemeSettingsThemeItemIconNode?
    var nextNode: ThemeSettingsThemeItemIconNode?
    listNode.forEachItemNode { node in
        guard let node = node as? ThemeSettingsThemeItemIconNode else {
            return
        }
        if resultNode == nil {
            if node.item?.chatTheme?.id == themeId {
                resultNode = node
            } else {
                previousNode = node
            }
        } else if nextNode == nil {
            nextNode = node
        }
    }
    if let resultNode = resultNode {
        var nodeToEnsure = resultNode
        if case let .visible(resultVisibility, _) = resultNode.visibility, resultVisibility == 1.0 {
            if let previousNode = previousNode, case let .visible(previousVisibility, _) = previousNode.visibility, previousVisibility < 0.5 {
                nodeToEnsure = previousNode
            } else if let nextNode = nextNode, case let .visible(nextVisibility, _) = nextNode.visibility, nextVisibility < 0.5 {
                nodeToEnsure = nextNode
            }
        }
        listNode.ensureItemNodeVisible(nodeToEnsure, animated: animated, overflow: 57.0)
        return true
    } else {
        return false
    }
}

private func preparedTransition(context: AccountContext, action: @escaping (ChatTheme?) -> Void, from fromEntries: [ThemeSettingsThemeEntry], to toEntries: [ThemeSettingsThemeEntry], crossfade: Bool) -> ThemeSettingsThemeItemNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, action: action), directionHint: .Down) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, action: action), directionHint: nil) }
    
    return ThemeSettingsThemeItemNodeTransition(deletions: deletions, insertions: insertions, updates: updates, crossfade: crossfade, entries: toEntries)
}

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

private final class ThemeSettingsThemeItemIconNode : ListViewItemNode {
    private let containerNode: ASDisplayNode
    private let emojiContainerNode: ASDisplayNode
    private let imageNode: TransformImageNode
    private let overlayNode: ASImageNode
    private let textNode: TextNode
    private let emojiNode: TextNode
    private let emojiImageNode: TransformImageNode
    private var animatedStickerNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode
    private var bubbleNode: ASImageNode?
    private var avatarNode: AvatarNode?
    private var replaceNode: ASImageNode?
    var snapshotView: UIView?
    
    var item: ThemeSettingsThemeIconItem?
    
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
        self.imageNode.cornerRadius = 16.0
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

        super.init(layerBacked: false, rotated: false, seeThrough: false)
        
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
    }

    deinit {
        self.stickerFetchedDisposable.dispose()
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
            Queue.mainQueue().after(0.1) { [animatedStickerNode, weak self] in
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
    
    func asyncLayout() -> (ThemeSettingsThemeIconItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeEmojiLayout = TextNode.asyncLayout(self.emojiNode)
        let makeImageLayout = self.imageNode.asyncLayout()
        
        let currentItem = self.item

        return { [weak self] item, params in
            var updatedEmoticon = false
            var updatedThemeReference = false
            var updatedTheme = false
            var updatedWallpaper = false
            var updatedSelected = false
            var updatedNightMode = false
            
            if currentItem?.chatTheme?.id != item.chatTheme?.id {
                updatedEmoticon = true
            }
            if currentItem?.themeReference != item.themeReference {
                updatedThemeReference = true
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
            if currentItem?.nightMode != item.nightMode {
                updatedNightMode = true
            }
            
            let text = NSAttributedString(string: item.strings.Conversation_Theme_NoTheme, font: Font.semibold(15.0), textColor: item.theme.actionSheet.controlAccentColor)
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let emoticon: String
            if let _ = item.chatTheme {
                emoticon = ""
            } else {
                emoticon = "❌"
            }
            let title = NSAttributedString(string: emoticon, font: Font.regular(22.0), textColor: .black)
            let (_, emojiApply) = makeEmojiLayout(TextNodeLayoutArguments(attributedString: title, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 120.0, height: 90.0), insets: UIEdgeInsets())
            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                        
                    if updatedThemeReference || updatedWallpaper || updatedNightMode {
                        if let themeReference = item.themeReference {
                            strongSelf.imageNode.setSignal(themeIconImage(account: item.context.account, accountManager: item.context.sharedContext.accountManager, theme: themeReference, color: nil, wallpaper: item.wallpaper, nightMode: item.nightMode, emoticon: true))
                            strongSelf.imageNode.backgroundColor = nil
                        }
                    }
                    if item.themeReference == nil {
                        if item.theme.overallDarkAppearance {
                            strongSelf.imageNode.backgroundColor = item.theme.list.plainBackgroundColor
                        } else {
                            strongSelf.imageNode.backgroundColor = item.theme.rootController.navigationBar.segmentedForegroundColor
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
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((90.0 - textLayout.size.width) / 2.0), y: 24.0), size: textLayout.size)
                    strongSelf.textNode.isHidden = emoticon.isEmpty
                    
                    strongSelf.containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(x: 15.0, y: -15.0), size: CGSize(width: 90.0, height: 120.0))
                    
                    strongSelf.emojiContainerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                    strongSelf.emojiContainerNode.frame = CGRect(origin: CGPoint(x: 15.0, y: -15.0), size: CGSize(width: 90.0, height: 120.0))
                    
                    let _ = textApply()
                    let _ = emojiApply()

                    let imageSize = CGSize(width: 82.0, height: 108.0)
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: 4.0, y: 6.0), size: imageSize)
                    let applyLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: .clear))
                    applyLayout()
                    
                    strongSelf.overlayNode.frame = strongSelf.imageNode.frame.insetBy(dx: -1.0, dy: -1.0)
                    strongSelf.emojiNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 79.0), size: CGSize(width: 90.0, height: 30.0))
                    
                    let emojiFrame = CGRect(origin: CGPoint(x: 33.0, y: 79.0), size: CGSize(width: 24.0, height: 24.0))
                    if let file = item.emojiFile, updatedEmoticon {
                        let imageApply = strongSelf.emojiImageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: emojiFrame.size, boundingSize: emojiFrame.size, intrinsicInsets: UIEdgeInsets()))
                        imageApply()
                        strongSelf.emojiImageNode.setSignal(chatMessageStickerPackThumbnail(postbox: item.context.account.postbox, resource: file.resource, animated: true, nilIfEmpty: true))
                        strongSelf.emojiImageNode.frame = emojiFrame
                        
                        let animatedStickerNode: AnimatedStickerNode
                        if let current = strongSelf.animatedStickerNode {
                            animatedStickerNode = current
                        } else {
                            animatedStickerNode = DefaultAnimatedStickerNodeImpl(lottieSettings: item.context.lottieRenderingSettings)
                            animatedStickerNode.started = { [weak self] in
                                self?.emojiImageNode.isHidden = true
                            }
                            strongSelf.animatedStickerNode = animatedStickerNode
                            strongSelf.emojiContainerNode.insertSubnode(animatedStickerNode, belowSubnode: strongSelf.placeholderNode)
                            let pathPrefix = item.context.engine.resources.shortLivedResourceCachePathPrefix(id: EngineMediaResource.Id(file.resource.id))
                            animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: item.context.account, resource: file.resource), width: 128, height: 128, playbackMode: .still(.start), mode: .direct(cachePathPrefix: pathPrefix))
                            
                            animatedStickerNode.anchorPoint = CGPoint(x: 0.5, y: 1.0)
                        }
                        animatedStickerNode.autoplay = true
                        animatedStickerNode.visibility = strongSelf.visibilityStatus
                        
                        strongSelf.stickerFetchedDisposable.set(item.context.engine.resources.fetch(reference: MediaResourceReference.media(media: .standalone(media: file), resource: file.resource), userLocation: .other, userContentType: .sticker).startStrict())
                        
                        let thumbnailDimensions = PixelDimensions(width: 512, height: 512)
                        strongSelf.placeholderNode.update(backgroundColor: nil, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.2), shimmeringColor: UIColor(rgb: 0xffffff, alpha: 0.3), data: file.immediateThumbnailData, size: emojiFrame.size, enableEffect: item.context.sharedContext.energyUsageSettings.fullTranslucency, imageSize: thumbnailDimensions.cgSize)
                        strongSelf.placeholderNode.frame = emojiFrame
                    }
                    
                    if let animatedStickerNode = strongSelf.animatedStickerNode {
                        animatedStickerNode.frame = emojiFrame
                        animatedStickerNode.updateLayout(size: emojiFrame.size)
                    }
                    
                    if let _ = item.peer {
                        let bubbleNode: ASImageNode
                        if let current = strongSelf.bubbleNode {
                            bubbleNode = current
                        } else {
                            bubbleNode = ASImageNode()
                            strongSelf.insertSubnode(bubbleNode, belowSubnode: strongSelf.emojiContainerNode)
                            strongSelf.bubbleNode = bubbleNode
                            
                            var bubbleColor: UIColor?
                            if let theme = item.chatTheme, case let .gift(_, themeSettings) = theme {
                                if item.nightMode {
                                    if let theme = themeSettings.first(where: { $0.baseTheme == .night || $0.baseTheme == .tinted }) {
                                        let color = theme.wallpaper?.settings?.colors.first ?? theme.accentColor
                                        bubbleColor = UIColor(rgb: UInt32(bitPattern: color))
                                    }
                                } else {
                                    if let theme = themeSettings.first(where: { $0.baseTheme == .classic || $0.baseTheme == .day }) {
                                        let color = theme.wallpaper?.settings?.colors.first ?? theme.accentColor
                                        bubbleColor = UIColor(rgb: UInt32(bitPattern: color))
                                    }
                                }
                            }
                            if let bubbleColor {
                                bubbleNode.image = generateFilledRoundedRectImage(size: CGSize(width: 24.0, height: 48.0), cornerRadius: 12.0, color: bubbleColor)
                            }
                        }
                        bubbleNode.frame = CGRect(origin: CGPoint(x: 50.0, y: 12.0), size: CGSize(width: 24.0, height: 48.0))
                    } else if let bubbleNode = strongSelf.bubbleNode {
                        strongSelf.bubbleNode = nil
                        bubbleNode.removeFromSupernode()
                    }
                    
                    if let peer = item.peer {
                        let avatarNode: AvatarNode
                        if let current = strongSelf.avatarNode {
                            avatarNode = current
                        } else {
                            avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 8.0))
                            strongSelf.insertSubnode(avatarNode, belowSubnode: strongSelf.emojiContainerNode)
                            strongSelf.avatarNode = avatarNode
                            avatarNode.setPeer(context: item.context, theme: item.theme, peer: peer, displayDimensions: CGSize(width: 20.0, height: 20.0))
                        }
                        avatarNode.transform = CATransform3DMakeRotation(.pi / 2.0, 0.0, 0.0, 1.0)
                        avatarNode.frame = CGRect(origin: CGPoint(x: 52.0, y: 14.0), size: CGSize(width: 20.0, height: 20.0))
                    } else if let avatarNode = strongSelf.avatarNode {
                        strongSelf.avatarNode = nil
                        avatarNode.removeFromSupernode()
                    }
                    
                    if let _ = item.peer {
                        let replaceNode: ASImageNode
                        if let current = strongSelf.replaceNode {
                            replaceNode = current
                        } else {
                            replaceNode = ASImageNode()
                            strongSelf.insertSubnode(replaceNode, belowSubnode: strongSelf.emojiContainerNode)
                            strongSelf.replaceNode = replaceNode
                            replaceNode.image = generateTintedImage(image: UIImage(bundleImageName: "Settings/Refresh"), color: .white)
                        }
                        replaceNode.transform = CATransform3DMakeRotation(.pi / 2.0, 0.0, 0.0, 1.0)
                        if let image = replaceNode.image {
                            replaceNode.frame = CGRect(origin: CGPoint(x: 53.0, y: 37.0), size: image.size)
                        }
                    } else if let replaceNode = strongSelf.replaceNode {
                        strongSelf.replaceNode = nil
                        replaceNode.removeFromSupernode()
                    }
                }
            })
        }
    }
    
    func crossfade() {
        if let snapshotView = self.containerNode.view.snapshotView(afterScreenUpdates: false) {
            snapshotView.transform = self.containerNode.view.transform
            snapshotView.frame = self.containerNode.view.frame
            self.view.insertSubview(snapshotView, aboveSubview: self.containerNode.view)
            
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: ChatThemeScreen.themeCrossfadeDuration, delay: ChatThemeScreen.themeCrossfadeDelay, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
        }
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

public final class ChatThemeScreen: ViewController {
    public static let themeCrossfadeDuration: Double = 0.3
    public static let themeCrossfadeDelay: Double = 0.25
    
    private var controllerNode: ChatThemeSheetScreenNode {
        return self.displayNode as! ChatThemeSheetScreenNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let animatedEmojiStickers: [String: [StickerPackItem]]
    private let initiallySelectedTheme: ChatTheme?
    private let peerName: String
    fileprivate let canResetWallpaper: Bool
    private let previewTheme: (ChatTheme?, Bool?) -> Void
    fileprivate let changeWallpaper: () -> Void
    fileprivate let resetWallpaper: () -> Void
    private let completion: (ChatTheme?) -> Void
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    public var dismissed: (() -> Void)?
    
    public var passthroughHitTestImpl: ((CGPoint) -> UIView?)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.passthroughHitTestImpl = self.passthroughHitTestImpl
            }
        }
    }
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
        animatedEmojiStickers: [String: [StickerPackItem]],
        initiallySelectedTheme: ChatTheme?,
        peerName: String,
        canResetWallpaper: Bool,
        previewTheme: @escaping (ChatTheme?, Bool?) -> Void,
        changeWallpaper: @escaping () -> Void,
        resetWallpaper: @escaping () -> Void,
        completion: @escaping (ChatTheme?) -> Void
    ) {
        self.context = context
        self.presentationData = updatedPresentationData.initial
        self.animatedEmojiStickers = animatedEmojiStickers
        self.initiallySelectedTheme = initiallySelectedTheme
        self.peerName = peerName
        self.canResetWallpaper = canResetWallpaper
        self.previewTheme = previewTheme
        self.changeWallpaper = changeWallpaper
        self.resetWallpaper = resetWallpaper
        self.completion = completion
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = (updatedPresentationData.signal
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatThemeSheetScreenNode(context: self.context, presentationData: self.presentationData, controller: self, animatedEmojiStickers: self.animatedEmojiStickers, initiallySelectedTheme: self.initiallySelectedTheme, peerName: self.peerName)
        self.controllerNode.passthroughHitTestImpl = self.passthroughHitTestImpl
        self.controllerNode.previewTheme = { [weak self] chatTheme, dark in
            guard let strongSelf = self else {
                return
            }
            strongSelf.previewTheme((chatTheme ?? .emoticon("")), dark)
        }
        self.controllerNode.present = { [weak self] c in
            self?.present(c, in: .current)
        }
        self.controllerNode.completion = { [weak self] chatTheme in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dismiss(animated: true)
            if strongSelf.initiallySelectedTheme == nil && chatTheme == nil {
            } else {
                strongSelf.completion(chatTheme)
            }
        }
        self.controllerNode.dismiss = { [weak self] in
            self?.dismiss(animated: false)
        }
        self.controllerNode.cancel = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dismiss(animated: true)
            strongSelf.previewTheme(nil, nil)
        }
    }
    
    override public func loadView() {
        super.loadView()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        })
        
        if flag {
            self.controllerNode.animateOut(completion: {
                super.dismiss(animated: flag, completion: completion)
                completion?()
            })
        } else {
            super.dismiss(animated: flag, completion: completion)
        }
        
        self.dismissed?()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    public func dimTapped() {
        self.controllerNode.dimTapped()
    }
}

private func iconColors(theme: PresentationTheme) -> [String: UIColor] {
    let accentColor = theme.actionSheet.controlAccentColor
    var colors: [String: UIColor] = [:]
    colors["Sunny.Path 14.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 15.Path.Stroke 1"] = accentColor
    colors["Path.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 39.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 24.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 25.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 18.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 41.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 43.Path.Stroke 1"] = accentColor
    colors["Path 10.Path.Fill 1"] = accentColor
    colors["Path 11.Path.Fill 1"] = accentColor
    return colors
}

private func interpolateColors(from: [String: UIColor], to: [String: UIColor], fraction: CGFloat) -> [String: UIColor] {
    var colors: [String: UIColor] = [:]
    for (key, fromValue) in from {
        if let toValue = to[key] {
            colors[key] = fromValue.interpolateTo(toValue, fraction: fraction)
        }
    }
    return colors
}

private final class ChatThemeScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let presentationData: PresentationData
    let animatedEmojiStickers: [String: [StickerPackItem]]
    let initiallySelectedTheme: ChatTheme?
    let peerName: String
    let canResetWallpaper: Bool
    let present: (ViewController) -> Void
    let presentInRoot: (ViewController) -> Void
    let previewTheme: (ChatTheme?, Bool?) -> Void
    let changeWallpaper: () -> Void
    let resetWallpaper: () -> Void
    let completion: (ChatTheme?) -> Void
    let cancel: () -> Void
    
    init(
        context: AccountContext,
        presentationData: PresentationData,
        animatedEmojiStickers: [String: [StickerPackItem]],
        initiallySelectedTheme: ChatTheme?,
        peerName: String,
        canResetWallpaper: Bool,
        present: @escaping (ViewController) -> Void,
        presentInRoot: @escaping (ViewController) -> Void,
        previewTheme: @escaping (ChatTheme?, Bool?) -> Void,
        changeWallpaper: @escaping () -> Void,
        resetWallpaper: @escaping () -> Void,
        completion: @escaping (ChatTheme?) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.context = context
        self.presentationData = presentationData
        self.animatedEmojiStickers = animatedEmojiStickers
        self.initiallySelectedTheme = initiallySelectedTheme
        self.peerName = peerName
        self.canResetWallpaper = canResetWallpaper
        self.present = present
        self.presentInRoot = presentInRoot
        self.previewTheme = previewTheme
        self.changeWallpaper = changeWallpaper
        self.resetWallpaper = resetWallpaper
        self.completion = completion
        self.cancel = cancel
    }
    
    static func ==(lhs: ChatThemeScreenComponent, rhs: ChatThemeScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.presentationData.theme !== rhs.presentationData.theme {
            return false
        }
        if lhs.presentationData.strings !== rhs.presentationData.strings {
            return false
        }
        if lhs.initiallySelectedTheme != rhs.initiallySelectedTheme {
            return false
        }
        if lhs.peerName != rhs.peerName {
            return false
        }
        if lhs.canResetWallpaper != rhs.canResetWallpaper {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var component: ChatThemeScreenComponent?
        private var environment: ViewControllerComponentContainer.Environment?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ChatThemeScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environmentValue = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environmentValue
            
            let sheetEnvironment = SheetComponentEnvironment(
                metrics: environmentValue.metrics,
                deviceMetrics: environmentValue.deviceMetrics,
                isDisplaying: environmentValue.isVisible,
                isCentered: false,
                hasInputHeight: !environmentValue.inputHeight.isZero,
                regularMetricsSize: nil,
                dismiss: { _ in
                    component.cancel()
                }
            )
            
            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent(
                    content: AnyComponent(ChatThemeSheetContentComponent(
                        context: component.context,
                        presentationData: component.presentationData,
                        animatedEmojiStickers: component.animatedEmojiStickers,
                        initiallySelectedTheme: component.initiallySelectedTheme,
                        peerName: component.peerName,
                        canResetWallpaper: component.canResetWallpaper,
                        present: component.present,
                        presentInRoot: component.presentInRoot,
                        previewTheme: component.previewTheme,
                        changeWallpaper: component.changeWallpaper,
                        resetWallpaper: component.resetWallpaper,
                        completion: component.completion,
                        cancel: component.cancel
                    )),
                    style: .glass,
                    backgroundColor: .color(environmentValue.theme.actionSheet.opaqueItemBackgroundColor),
                    clipsContent: true,
                    isScrollEnabled: false,
                    hasDimView: false,
                    animateOut: self.sheetAnimateOut
                )),
                environment: {
                    environmentValue
                    sheetEnvironment
                },
                containerSize: availableSize
            )
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: CGPoint(), size: sheetSize))
            }
            
            return availableSize
        }
        
        private func contentView() -> ChatThemeSheetContentComponent.View? {
            guard let sheetView = self.sheet.view else {
                return nil
            }
            return findTaggedComponentViewImpl(view: sheetView, tag: ChatThemeSheetContentComponent.Tag()) as? ChatThemeSheetContentComponent.View
        }
        
        func containsContent(point: CGPoint) -> Bool {
            guard let contentView = self.contentView() else {
                return false
            }
            return contentView.bounds.contains(self.convert(point, to: contentView))
        }
        
        func dimTapped() {
            self.contentView()?.dimTapped()
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.contentView()?.setAnimatedOut()
            self.sheetAnimateOut.invoke(Action { _ in
                completion()
            })
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ChatThemeSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    final class Tag {
    }
    
    let context: AccountContext
    let presentationData: PresentationData
    let animatedEmojiStickers: [String: [StickerPackItem]]
    let initiallySelectedTheme: ChatTheme?
    let peerName: String
    let canResetWallpaper: Bool
    let present: (ViewController) -> Void
    let presentInRoot: (ViewController) -> Void
    let previewTheme: (ChatTheme?, Bool?) -> Void
    let changeWallpaper: () -> Void
    let resetWallpaper: () -> Void
    let completion: (ChatTheme?) -> Void
    let cancel: () -> Void
    
    init(
        context: AccountContext,
        presentationData: PresentationData,
        animatedEmojiStickers: [String: [StickerPackItem]],
        initiallySelectedTheme: ChatTheme?,
        peerName: String,
        canResetWallpaper: Bool,
        present: @escaping (ViewController) -> Void,
        presentInRoot: @escaping (ViewController) -> Void,
        previewTheme: @escaping (ChatTheme?, Bool?) -> Void,
        changeWallpaper: @escaping () -> Void,
        resetWallpaper: @escaping () -> Void,
        completion: @escaping (ChatTheme?) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.context = context
        self.presentationData = presentationData
        self.animatedEmojiStickers = animatedEmojiStickers
        self.initiallySelectedTheme = initiallySelectedTheme
        self.peerName = peerName
        self.canResetWallpaper = canResetWallpaper
        self.present = present
        self.presentInRoot = presentInRoot
        self.previewTheme = previewTheme
        self.changeWallpaper = changeWallpaper
        self.resetWallpaper = resetWallpaper
        self.completion = completion
        self.cancel = cancel
    }
    
    static func ==(lhs: ChatThemeSheetContentComponent, rhs: ChatThemeSheetContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.presentationData.theme !== rhs.presentationData.theme {
            return false
        }
        if lhs.presentationData.strings !== rhs.presentationData.strings {
            return false
        }
        if lhs.initiallySelectedTheme != rhs.initiallySelectedTheme {
            return false
        }
        if lhs.peerName != rhs.peerName {
            return false
        }
        if lhs.canResetWallpaper != rhs.canResetWallpaper {
            return false
        }
        return true
    }
    
    final class View: UIView, ComponentTaggedView {
        private enum PrimaryAction: Equatable {
            case chooseWallpaper
            case resetTheme
            case apply
        }
        
        func matches(tag: Any) -> Bool {
            return tag is Tag
        }
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let leftButton = ComponentView<Empty>()
        private let switchThemeButton = ComponentView<Empty>()
        private let primaryButton = ComponentView<Empty>()
        private var resetWallpaperButton: ComponentView<Empty>?
        private let switchThemePlayOnce = ActionSlot<Void>()
        
        private let listNode: ListView
        private var entries: [ThemeSettingsThemeEntry]?
        private var enqueuedTransitions: [ThemeSettingsThemeItemNodeTransition] = []
        private var initialized = false
        
        private var component: ChatThemeSheetContentComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var selectedTheme: ChatTheme?
        private var isDarkAppearance: Bool = false
        private var isSwitchThemeEnabled = true
        private var isCompleting = false
        
        private var themes: [TelegramTheme] = []
        private var uniqueGiftChatThemesContext: UniqueGiftChatThemesContext?
        private var currentUniqueGiftChatThemesState: UniqueGiftChatThemesContext.State?
        private var uniqueGiftPeers: [EnginePeer.Id: EnginePeer] = [:]
        private let disposable = MetaDisposable()
        
        private var themeSelectionsCount = 0
        private var displayedPreviewTooltip = false
        private var animatedOut = false
        
        override init(frame: CGRect) {
            self.listNode = ListViewImpl()
            self.listNode.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
            
            super.init(frame: frame)
            
            self.addSubview(self.listNode.view)
            self.listNode.view.disablesInteractiveTransitionGestureRecognizer = true
            
            self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
                guard let self, let state = self.currentUniqueGiftChatThemesState, case .ready(true) = state.dataState else {
                    return
                }
                if case let .known(value) = offset, value < 100.0 {
                    self.uniqueGiftChatThemesContext?.loadMore()
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.disposable.dispose()
        }
        
        func setAnimatedOut() {
            self.animatedOut = true
        }
        
        private func setupIfNeeded(component: ChatThemeSheetContentComponent) {
            guard self.uniqueGiftChatThemesContext == nil else {
                return
            }
            
            self.selectedTheme = component.initiallySelectedTheme
            self.isDarkAppearance = component.presentationData.theme.overallDarkAppearance
            
            let uniqueGiftChatThemesContext = UniqueGiftChatThemesContext(account: component.context.account)
            self.uniqueGiftChatThemesContext = uniqueGiftChatThemesContext
            
            let context = component.context
            self.disposable.set(combineLatest(
                queue: Queue.mainQueue(),
                context.engine.themes.getChatThemes(accountManager: context.sharedContext.accountManager),
                uniqueGiftChatThemesContext.state
                |> mapToSignal { state -> Signal<(UniqueGiftChatThemesContext.State, [EnginePeer.Id: EnginePeer]), NoError> in
                    var peerIds: [EnginePeer.Id] = []
                    for theme in state.themes {
                        if case let .gift(gift, _) = theme, case let .unique(uniqueGift) = gift, let themePeerId = uniqueGift.themePeerId {
                            peerIds.append(themePeerId)
                        }
                    }
                    return combineLatest(
                        .single(state),
                        context.engine.data.get(
                            EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init))
                        )
                        |> map { peers in
                            var result: [EnginePeer.Id: EnginePeer] = [:]
                            for peerId in peerIds {
                                if let maybePeer = peers[peerId], let peer = maybePeer {
                                    result[peerId] = peer
                                }
                            }
                            return result
                        }
                    )
                }
            ).startStrict(next: { [weak self] themes, uniqueGiftChatThemesStateAndPeers in
                guard let self else {
                    return
                }
                self.themes = themes
                self.currentUniqueGiftChatThemesState = uniqueGiftChatThemesStateAndPeers.0
                self.uniqueGiftPeers = uniqueGiftChatThemesStateAndPeers.1
                self.rebuildEntries(crossfade: false)
            }))
        }
        
        private func hasChanges() -> Bool {
            return self.selectedTheme?.id != self.component?.initiallySelectedTheme?.id
        }
        
        private func primaryAction() -> PrimaryAction {
            if self.selectedTheme?.id == self.component?.initiallySelectedTheme?.id {
                return .chooseWallpaper
            } else if self.selectedTheme == nil && self.component?.initiallySelectedTheme != nil {
                return .resetTheme
            } else {
                return .apply
            }
        }
        
        private func primaryButtonTitle(strings: PresentationStrings) -> String {
            switch self.primaryAction() {
            case .chooseWallpaper:
                if self.component?.canResetWallpaper == true {
                    return strings.Conversation_Theme_SetNewPhotoWallpaper
                } else {
                    return strings.Conversation_Theme_SetPhotoWallpaper
                }
            case .resetTheme:
                return strings.Conversation_Theme_Reset
            case .apply:
                return strings.Conversation_Theme_Apply
            }
        }
        
        private func rebuildEntries(crossfade: Bool) {
            guard let component = self.component else {
                return
            }
            
            let presentationData = component.presentationData
            let selectedTheme = self.selectedTheme
            let isDarkAppearance = self.isDarkAppearance
            
            var entries: [ThemeSettingsThemeEntry] = []
            entries.append(ThemeSettingsThemeEntry(
                index: 0,
                chatTheme: nil,
                emojiFile: nil,
                themeReference: nil,
                peer: nil,
                nightMode: false,
                selected: selectedTheme == nil,
                theme: presentationData.theme,
                strings: presentationData.strings,
                wallpaper: nil
            ))
            
            var giftThemes = self.currentUniqueGiftChatThemesState?.themes ?? []
            var existingIds = Set<String>()
            if let initiallySelectedTheme = component.initiallySelectedTheme, case .gift = initiallySelectedTheme {
                let initialThemeIndex = giftThemes.firstIndex(where: { $0.id == initiallySelectedTheme.id })
                if initialThemeIndex == nil || initialThemeIndex! > 50 {
                    giftThemes.insert(initiallySelectedTheme, at: 0)
                }
            }
            
            for theme in giftThemes {
                guard case let .gift(gift, themeSettings) = theme, !existingIds.contains(theme.id) else {
                    continue
                }
                var emojiFile: TelegramMediaFile?
                var peer: EnginePeer?
                if case let .unique(uniqueGift) = gift {
                    for attribute in uniqueGift.attributes {
                        if case let .model(_, file, _, _) = attribute {
                            emojiFile = file
                        }
                    }
                    if let themePeerId = uniqueGift.themePeerId, theme.id != component.initiallySelectedTheme?.id {
                        peer = self.uniqueGiftPeers[themePeerId]
                    }
                }
                let themeReference: PresentationThemeReference
                let wallpaper: TelegramWallpaper?
                if isDarkAppearance {
                    wallpaper = themeSettings.first(where: { $0.baseTheme == .night || $0.baseTheme == .tinted })?.wallpaper
                    themeReference = .builtin(.night)
                } else {
                    wallpaper = themeSettings.first(where: { $0.baseTheme == .classic || $0.baseTheme == .day })?.wallpaper
                    themeReference = .builtin(.dayClassic)
                }
                entries.append(ThemeSettingsThemeEntry(
                    index: entries.count,
                    chatTheme: theme,
                    emojiFile: emojiFile,
                    themeReference: themeReference,
                    peer: peer,
                    nightMode: isDarkAppearance,
                    selected: selectedTheme?.id == theme.id,
                    theme: presentationData.theme,
                    strings: presentationData.strings,
                    wallpaper: wallpaper
                ))
                existingIds.insert(theme.id)
            }
            
            let uniqueGiftThemesState = self.currentUniqueGiftChatThemesState
            if uniqueGiftThemesState?.themes.count == 0 || uniqueGiftThemesState?.dataState == .ready(canLoadMore: false) {
                for theme in self.themes {
                    guard let emoticon = theme.emoticon else {
                        continue
                    }
                    entries.append(ThemeSettingsThemeEntry(
                        index: entries.count,
                        chatTheme: .emoticon(emoticon),
                        emojiFile: component.animatedEmojiStickers[emoticon]?.first?.file._parse(),
                        themeReference: .cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: nil, creatorAccountId: nil)),
                        peer: nil,
                        nightMode: isDarkAppearance,
                        selected: selectedTheme?.id == ChatTheme.emoticon(emoticon).id,
                        theme: presentationData.theme,
                        strings: presentationData.strings,
                        wallpaper: nil
                    ))
                }
            }
            
            let action: (ChatTheme?) -> Void = { [weak self] chatTheme in
                guard let self, self.selectedTheme != chatTheme else {
                    return
                }
                self.setChatTheme(chatTheme)
            }
            let previousEntries = self.entries ?? []
            let transition = preparedTransition(context: component.context, action: action, from: previousEntries, to: entries, crossfade: crossfade)
            self.enqueueTransition(transition)
            
            let isFirstTime = self.entries == nil
            self.entries = entries
            
            if isFirstTime {
                self.preloadWallpaperResources(themes: self.themes, context: component.context)
            }
        }
        
        private func preloadWallpaperResources(themes: [TelegramTheme], context: AccountContext) {
            for theme in themes {
                if let wallpaper = theme.settings?.first?.wallpaper, case let .file(file) = wallpaper {
                    let account = context.account
                    let accountManager = context.sharedContext.accountManager
                    let path = accountManager.mediaBox.cachedRepresentationCompletePath(file.file.resource.id, representation: CachedPreparedPatternWallpaperRepresentation())
                    if !FileManager.default.fileExists(atPath: path) {
                        let accountFullSizeData = Signal<(Data?, Bool), NoError> { subscriber in
                            let accountResource = account.postbox.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedPreparedPatternWallpaperRepresentation(), complete: false, fetch: true)
                            
                            let fetchedFullSize = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .other, userContentType: MediaResourceUserContentType(file: file.file), reference: .media(media: .standalone(media: file.file), resource: file.file.resource))
                            let fetchedFullSizeDisposable = fetchedFullSize.start()
                            let fullSizeDisposable = accountResource.start(next: { next in
                                subscriber.putNext((next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete))
                                
                                if next.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedRead) {
                                    accountManager.mediaBox.storeCachedResourceRepresentation(file.file.resource, representation: CachedPreparedPatternWallpaperRepresentation(), data: data)
                                }
                            }, error: subscriber.putError, completed: subscriber.putCompletion)
                            
                            return ActionDisposable {
                                fetchedFullSizeDisposable.dispose()
                                fullSizeDisposable.dispose()
                            }
                        }
                        let _ = accountFullSizeData.start()
                    }
                }
            }
        }
        
        private func enqueueTransition(_ transition: ThemeSettingsThemeItemNodeTransition) {
            self.enqueuedTransitions.append(transition)
            
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        private func dequeueTransition() {
            guard let transition = self.enqueuedTransitions.first else {
                return
            }
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if self.initialized && transition.crossfade {
                options.insert(.AnimateCrossfade)
            }
            options.insert(.Synchronous)
            
            var scrollToItem: ListViewScrollToItem?
            if !self.initialized {
                if let index = transition.entries.firstIndex(where: { entry in
                    return entry.chatTheme?.id == self.component?.initiallySelectedTheme?.id
                }) {
                    scrollToItem = ListViewScrollToItem(index: index, position: .bottom(-57.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Down)
                    self.initialized = true
                }
            }
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
        
        private func setChatTheme(_ chatTheme: ChatTheme?) {
            guard let component = self.component else {
                return
            }
            
            self.previewThemeChanged(chatTheme: chatTheme, dark: self.isDarkAppearance)
            self.selectedTheme = chatTheme
            self.rebuildEntries(crossfade: false)
            let _ = ensureThemeVisible(listNode: self.listNode, themeId: chatTheme?.id, animated: true)
            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: ChatThemeScreen.themeCrossfadeDuration, curve: .easeInOut)))
            
            self.themeSelectionsCount += 1
            if self.themeSelectionsCount == 2 {
                self.maybePresentPreviewTooltip(component: component)
            }
        }
        
        private func previewThemeChanged(chatTheme: ChatTheme?, dark: Bool?) {
            self.component?.previewTheme(chatTheme, dark)
            self.listNode.forEachVisibleItemNode { node in
                if let node = node as? ThemeSettingsThemeItemIconNode {
                    node.crossfade()
                }
            }
        }
        
        private func closeOrBackPressed() {
            if self.hasChanges() {
                self.setChatTheme(self.component?.initiallySelectedTheme)
            } else {
                self.component?.cancel()
            }
        }
        
        private func resetWallpaperPressed() {
            self.component?.resetWallpaper()
            self.closeOrBackPressed()
        }
        
        private func primaryPressed() {
            switch self.primaryAction() {
            case .chooseWallpaper:
                self.component?.changeWallpaper()
            case .resetTheme, .apply:
                self.complete()
            }
        }
        
        private func complete() {
            guard let component = self.component else {
                return
            }
            let proceed = { [weak self] in
                guard let self else {
                    return
                }
                self.isCompleting = true
                self.state?.updated(transition: .immediate)
                component.completion(self.selectedTheme)
            }
            if case let .gift(gift, _) = self.selectedTheme, case let .unique(uniqueGift) = gift, let themePeerId = uniqueGift.themePeerId {
                let _ = (component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: themePeerId))
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self, let peer else {
                        return
                    }
                    let controller = giftThemeTransferAlertController(
                        context: component.context,
                        gift: uniqueGift,
                        previousPeer: peer,
                        commit: {
                            proceed()
                        }
                    )
                    self.component?.presentInRoot(controller)
                })
            } else {
                proceed()
            }
        }
        
        func dimTapped() {
            guard let component = self.component else {
                return
            }
            if !self.hasChanges() {
                self.closeOrBackPressed()
            } else {
                let alertController = textAlertController(context: component.context, updatedPresentationData: (component.presentationData, .single(component.presentationData)), title: nil, text: component.presentationData.strings.Conversation_Theme_DismissAlert, actions: [TextAlertAction(type: .genericAction, title: component.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: component.presentationData.strings.Conversation_Theme_DismissAlertApply, action: { [weak self] in
                    self?.complete()
                })], actionLayout: .horizontal, dismissOnOutsideTap: true)
                component.present(alertController)
            }
        }
        
        private func switchThemePressed() {
            guard self.isSwitchThemeEnabled, let component = self.component else {
                return
            }
            self.isSwitchThemeEnabled = false
            Queue.mainQueue().after(0.5) { [weak self] in
                guard let self else {
                    return
                }
                self.isSwitchThemeEnabled = true
                self.state?.updated(transition: .immediate)
            }
            
            let isDarkAppearance = !self.isDarkAppearance
            self.isDarkAppearance = isDarkAppearance
            component.previewTheme(self.selectedTheme, isDarkAppearance)
            self.rebuildEntries(crossfade: false)
            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: ChatThemeScreen.themeCrossfadeDuration, curve: .easeInOut)))
            Queue.mainQueue().justDispatch { [weak self] in
                self?.switchThemePlayOnce.invoke(Void())
            }
            
            if isDarkAppearance {
                let _ = ApplicationSpecificNotice.incrementChatSpecificThemeDarkPreviewTip(accountManager: component.context.sharedContext.accountManager, count: 3, timestamp: Int32(Date().timeIntervalSince1970)).startStandalone()
            } else {
                let _ = ApplicationSpecificNotice.incrementChatSpecificThemeLightPreviewTip(accountManager: component.context.sharedContext.accountManager, count: 3, timestamp: Int32(Date().timeIntervalSince1970)).startStandalone()
            }
        }
        
        private func maybePresentPreviewTooltip(component: ChatThemeSheetContentComponent) {
            guard !self.displayedPreviewTooltip, !self.animatedOut, let switchThemeButtonView = self.switchThemeButton.view else {
                return
            }
            
            let frame = switchThemeButtonView.convert(switchThemeButtonView.bounds, to: self)
            let currentTimestamp = Int32(Date().timeIntervalSince1970)
            let isDark = component.presentationData.theme.overallDarkAppearance
            
            let signal: Signal<(Int32, Int32), NoError>
            if isDark {
                signal = ApplicationSpecificNotice.getChatSpecificThemeLightPreviewTip(accountManager: component.context.sharedContext.accountManager)
            } else {
                signal = ApplicationSpecificNotice.getChatSpecificThemeDarkPreviewTip(accountManager: component.context.sharedContext.accountManager)
            }
            
            let _ = (signal
            |> deliverOnMainQueue).startStandalone(next: { [weak self] count, timestamp in
                guard let self, count < 2 && currentTimestamp > timestamp + 24 * 60 * 60 else {
                    return
                }
                self.displayedPreviewTooltip = true
                
                component.present(TooltipScreen(account: component.context.account, sharedContext: component.context.sharedContext, text: .plain(text: isDark ? component.presentationData.strings.Conversation_Theme_PreviewLightShort : component.presentationData.strings.Conversation_Theme_PreviewDarkShort), style: .default, icon: nil, location: .point(frame.offsetBy(dx: 3.0, dy: 6.0), .bottom), displayDuration: .custom(3.0), inset: 3.0, shouldDismissOnTouch: { _, _ in
                    return .dismiss(consume: false)
                }))
                
                if isDark {
                    let _ = ApplicationSpecificNotice.incrementChatSpecificThemeLightPreviewTip(accountManager: component.context.sharedContext.accountManager, timestamp: currentTimestamp).startStandalone()
                } else {
                    let _ = ApplicationSpecificNotice.incrementChatSpecificThemeDarkPreviewTip(accountManager: component.context.sharedContext.accountManager, timestamp: currentTimestamp).startStandalone()
                }
            })
        }
        
        func update(component: ChatThemeSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
            let environmentValue = environment[EnvironmentType.self].value
            self.environment = environmentValue
            
            self.setupIfNeeded(component: component)
            
            if let previousComponent, previousComponent.presentationData.theme !== component.presentationData.theme || previousComponent.presentationData.strings !== component.presentationData.strings {
                self.rebuildEntries(crossfade: false)
            }
            
            let width = availableSize.width
            let topInset: CGFloat = 16.0
            let titleBarHeight: CGFloat = 44.0
            let sideInset: CGFloat = 16.0
            let buttonHeight: CGFloat = 52.0
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environmentValue.safeInsets.bottom, innerDiameter: buttonHeight, sideInset: 30.0)
            let bottomInset: CGFloat = environmentValue.safeInsets.bottom.isZero ? 24.0 : environmentValue.safeInsets.bottom + 10.0
            
            var contentHeight = topInset
            
            let leftButtonIconName = self.hasChanges() ? "Navigation/Back" : "Navigation/Close"
            let leftButtonSize = self.leftButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: component.presentationData.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: leftButtonIconName, component: AnyComponent(
                        BundleIconComponent(
                            name: leftButtonIconName,
                            tintColor: component.presentationData.theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        self?.closeOrBackPressed()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            if let leftButtonView = self.leftButton.view {
                if leftButtonView.superview == nil {
                    self.addSubview(leftButtonView)
                }
                transition.setFrame(view: leftButtonView, frame: CGRect(origin: CGPoint(x: sideInset, y: topInset), size: leftButtonSize))
            }
            
            let switchButtonSize = self.switchThemeButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: component.presentationData.theme.overallDarkAppearance,
                    state: .glass,
                    isEnabled: self.isSwitchThemeEnabled,
                    component: AnyComponentWithIdentity(id: self.isDarkAppearance ? "night" : "day", component: AnyComponent(
                        LottieComponent(
                            content: LottieComponent.AppBundleContent(name: self.isDarkAppearance ? "anim_sun_reverse" : "anim_sun"),
                            color: component.presentationData.theme.chat.inputPanel.panelControlColor,
                            startingPosition: .end,
                            size: CGSize(width: 28.0, height: 28.0),
                            playOnce: self.switchThemePlayOnce,
                            lottieSettings: component.context.lottieRenderingSettings
                        )
                    )),
                    action: { [weak self] _ in
                        self?.switchThemePressed()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            if let switchButtonView = self.switchThemeButton.view {
                if switchButtonView.superview == nil {
                    self.addSubview(switchButtonView)
                }
                transition.setFrame(view: switchButtonView, frame: CGRect(origin: CGPoint(x: width - sideInset - switchButtonSize.width, y: topInset), size: switchButtonSize))
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(Text(
                    text: component.presentationData.strings.Conversation_Theme_Title,
                    font: Font.semibold(17.0),
                    color: component.presentationData.theme.actionSheet.primaryTextColor
                )),
                environment: {},
                containerSize: CGSize(width: width - 120.0, height: titleBarHeight)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((width - titleSize.width) * 0.5), y: topInset + floorToScreenPixels((titleBarHeight - titleSize.height) * 0.5)), size: titleSize))
            }
            
            contentHeight += titleBarHeight + 8.0
            
            let listHeight: CGFloat = 120.0
            let listFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: listHeight))
            self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: listHeight, height: width)
            self.listNode.position = CGPoint(x: listFrame.midX, y: listFrame.midY)
            var listInsets = UIEdgeInsets()
            listInsets.top += environmentValue.safeInsets.left + 12.0
            listInsets.bottom += environmentValue.safeInsets.right + 12.0
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: listHeight, height: width), insets: listInsets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            contentHeight += listHeight + 12.0
            
            let showSubtitle = self.primaryAction() != .chooseWallpaper && component.canResetWallpaper
            if showSubtitle {
                let subtitleSize = self.subtitle.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.presentationData.strings.Conversation_Theme_Subtitle(component.peerName).string, font: Font.regular(15.0), textColor: component.presentationData.theme.actionSheet.secondaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: width - 90.0, height: 100.0)
                )
                if let subtitleView = self.subtitle.view {
                    if subtitleView.superview == nil {
                        self.addSubview(subtitleView)
                    }
                    transition.setAlpha(view: subtitleView, alpha: 1.0)
                    transition.setFrame(view: subtitleView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize))
                }
                contentHeight += subtitleSize.height + 12.0
            } else if let subtitleView = self.subtitle.view {
                transition.setAlpha(view: subtitleView, alpha: 0.0)
            }
            
            let primaryAction = self.primaryAction()
            let accentColor = component.presentationData.theme.actionSheet.controlAccentColor
            let primaryTextColor: UIColor
            let primaryBackground: ButtonComponent.Background
            switch primaryAction {
            case .chooseWallpaper:
                primaryTextColor = accentColor
                primaryBackground = ButtonComponent.Background(
                    style: .glass,
                    color: accentColor.withMultipliedAlpha(0.1),
                    foreground: accentColor,
                    pressedColor: accentColor.withMultipliedAlpha(0.2),
                    cornerRadius: 26.0
                )
            case .resetTheme, .apply:
                primaryTextColor = component.presentationData.theme.list.itemCheckColors.foregroundColor
                primaryBackground = ButtonComponent.Background(
                    style: .glass,
                    color: component.presentationData.theme.list.itemCheckColors.fillColor,
                    foreground: component.presentationData.theme.list.itemCheckColors.foregroundColor,
                    pressedColor: component.presentationData.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                    cornerRadius: 26.0
                )
            }
            
            let primaryButtonSize = self.primaryButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: primaryBackground,
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(self.primaryButtonTitle(strings: component.presentationData.strings)),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: self.primaryButtonTitle(strings: component.presentationData.strings),
                            badge: 0,
                            textColor: primaryTextColor,
                            badgeBackground: primaryTextColor,
                            badgeForeground: component.presentationData.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: !self.isCompleting,
                    displaysProgress: self.isCompleting,
                    action: { [weak self] in
                        self?.primaryPressed()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: width - buttonInsets.left - buttonInsets.right, height: buttonHeight)
            )
            if let primaryButtonView = self.primaryButton.view {
                if primaryButtonView.superview == nil {
                    self.addSubview(primaryButtonView)
                }
                transition.setFrame(view: primaryButtonView, frame: CGRect(origin: CGPoint(x: buttonInsets.left, y: contentHeight), size: primaryButtonSize))
            }
            contentHeight += primaryButtonSize.height
            
            let showResetWallpaper = component.canResetWallpaper && primaryAction == .chooseWallpaper
            if showResetWallpaper {
                contentHeight += 8.0
                let resetWallpaperButton: ComponentView<Empty>
                if let current = self.resetWallpaperButton {
                    resetWallpaperButton = current
                } else {
                    resetWallpaperButton = ComponentView()
                    self.resetWallpaperButton = resetWallpaperButton
                }
                
                let destructiveColor = component.presentationData.theme.actionSheet.destructiveActionTextColor
                let resetButtonSize = resetWallpaperButton.update(
                    transition: transition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: destructiveColor.withMultipliedAlpha(0.1),
                            foreground: destructiveColor,
                            pressedColor: destructiveColor.withMultipliedAlpha(0.2)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("resetWallpaper"),
                            component: AnyComponent(ButtonTextContentComponent(
                                text: component.presentationData.strings.Conversation_Theme_ResetWallpaper,
                                badge: 0,
                                textColor: destructiveColor,
                                badgeBackground: destructiveColor,
                                badgeForeground: component.presentationData.theme.actionSheet.itemBackgroundColor
                            ))
                        ),
                        action: { [weak self] in
                            self?.resetWallpaperPressed()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: width - buttonInsets.left - buttonInsets.right, height: buttonHeight)
                )
                if let resetButtonView = resetWallpaperButton.view {
                    if resetButtonView.superview == nil {
                        self.addSubview(resetButtonView)
                    }
                    transition.setAlpha(view: resetButtonView, alpha: 1.0)
                    transition.setFrame(view: resetButtonView, frame: CGRect(origin: CGPoint(x: buttonInsets.left, y: contentHeight), size: resetButtonSize))
                }
                contentHeight += resetButtonSize.height
            } else if let resetWallpaperButton = self.resetWallpaperButton {
                self.resetWallpaperButton = nil
                if let resetButtonView = resetWallpaperButton.view {
                    transition.setAlpha(view: resetButtonView, alpha: 0.0, completion: { _ in
                        resetButtonView.removeFromSuperview()
                    })
                }
            }
            
            contentHeight += bottomInset
            
            return CGSize(width: width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ChatThemeSheetScreenNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private weak var controller: ChatThemeScreen?
    
    private let animatedEmojiStickers: [String: [StickerPackItem]]
    private let initiallySelectedTheme: ChatTheme?
    private let peerName: String
    
    private let hostView: ComponentHostView<ViewControllerComponentContainer.Environment>
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var isDisplaying = false
    private var animatedOut = false
    
    var present: ((ViewController) -> Void)?
    var previewTheme: ((ChatTheme?, Bool?) -> Void)?
    var completion: ((ChatTheme?) -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    var passthroughHitTestImpl: ((CGPoint) -> UIView?)?
    
    init(context: AccountContext, presentationData: PresentationData, controller: ChatThemeScreen, animatedEmojiStickers: [String: [StickerPackItem]], initiallySelectedTheme: ChatTheme?, peerName: String) {
        self.context = context
        self.presentationData = presentationData
        self.controller = controller
        self.animatedEmojiStickers = animatedEmojiStickers
        self.initiallySelectedTheme = initiallySelectedTheme
        self.peerName = peerName
        self.hostView = ComponentHostView<ViewControllerComponentContainer.Environment>()
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        self.view.addSubview(self.hostView)
    }
    
    private func update(transition: ComponentTransition) {
        guard let (layout, navigationBarHeight) = self.containerLayout else {
            return
        }
        
        let environment = ViewControllerComponentContainer.Environment(
            statusBarHeight: layout.statusBarHeight ?? 0.0,
            navigationHeight: navigationBarHeight,
            safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.safeInsets.right),
            additionalInsets: layout.additionalInsets,
            inputHeight: layout.inputHeight ?? 0.0,
            metrics: layout.metrics,
            deviceMetrics: layout.deviceMetrics,
            orientation: layout.metrics.orientation,
            isVisible: self.isDisplaying,
            theme: self.presentationData.theme,
            strings: self.presentationData.strings,
            dateTimeFormat: self.presentationData.dateTimeFormat,
            controller: { [weak self] in
                return self?.controller
            }
        )
        
        let component = ChatThemeScreenComponent(
            context: self.context,
            presentationData: self.presentationData,
            animatedEmojiStickers: self.animatedEmojiStickers,
            initiallySelectedTheme: self.initiallySelectedTheme,
            peerName: self.peerName,
            canResetWallpaper: self.controller?.canResetWallpaper == true,
            present: { [weak self] controller in
                self?.present?(controller)
            },
            presentInRoot: { [weak self] controller in
                self?.controller?.present(controller, in: .window(.root))
            },
            previewTheme: { [weak self] chatTheme, dark in
                self?.previewTheme?(chatTheme, dark)
            },
            changeWallpaper: { [weak self] in
                self?.controller?.changeWallpaper()
            },
            resetWallpaper: { [weak self] in
                self?.controller?.resetWallpaper()
            },
            completion: { [weak self] chatTheme in
                self?.completion?(chatTheme)
            },
            cancel: { [weak self] in
                self?.cancel?()
            }
        )
        
        let _ = self.hostView.update(
            transition: transition,
            component: AnyComponent(component),
            environment: {
                environment
            },
            containerSize: layout.size
        )
        transition.setFrame(view: self.hostView, frame: CGRect(origin: CGPoint(), size: layout.size))
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        guard !self.animatedOut else {
            return
        }
        self.presentationData = presentationData
        self.update(transition: .immediate)
    }
    
    func animateIn() {
        self.isDisplaying = true
        self.update(transition: ComponentTransition(animation: .none).withUserData(ViewControllerComponentContainer.AnimateInTransition()))
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.animatedOut = true
        if let rootView = self.hostView.componentView as? ChatThemeScreenComponent.View {
            rootView.animateOut { [weak self] in
                self?.dismiss?()
                completion?()
            }
        } else {
            self.dismiss?()
            completion?()
        }
    }
    
    func dimTapped() {
        if let rootView = self.hostView.componentView as? ChatThemeScreenComponent.View {
            rootView.dimTapped()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        self.update(transition: ComponentTransition(transition))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var presentingAlertController = false
        self.controller?.forEachController({ c in
            if c is AlertScreen {
                presentingAlertController = true
            }
            return true
        })
        
        if !presentingAlertController && self.bounds.contains(point), let rootView = self.hostView.componentView as? ChatThemeScreenComponent.View, !rootView.containsContent(point: point) {
            if let result = self.passthroughHitTestImpl?(point) {
                return result
            } else {
                return nil
            }
        }
        return super.hitTest(point, with: event)
    }
}
