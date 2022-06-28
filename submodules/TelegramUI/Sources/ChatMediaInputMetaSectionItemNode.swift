import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AnimatedStickerNode
import TelegramAnimatedStickerNode

enum ChatMediaInputMetaSectionItemType: Equatable {
    case savedStickers
    case recentStickers
    case stickersMode
    case savedGifs
    case trendingGifs
    case premium
    case gifEmoji(String, TelegramMediaFile?)
}

final class ChatMediaInputMetaSectionItem: ListViewItem {
    let account: Account
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let type: ChatMediaInputMetaSectionItemType
    let theme: PresentationTheme
    let strings: PresentationStrings
    let expanded: Bool
    let selectedItem: () -> Void
    
    var selectable: Bool {
        return true
    }
    
    init(account: Account, inputNodeInteraction: ChatMediaInputNodeInteraction, type: ChatMediaInputMetaSectionItemType, theme: PresentationTheme, strings: PresentationStrings, expanded: Bool, selected: @escaping () -> Void) {
        self.account = account
        self.inputNodeInteraction = inputNodeInteraction
        self.type = type
        self.selectedItem = selected
        self.theme = theme
        self.strings = strings
        self.expanded = expanded
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatMediaInputMetaSectionItemNode()
            Queue.mainQueue().async {
                node.inputNodeInteraction = self.inputNodeInteraction
                node.setItem(item: self)
                node.updateTheme(account: self.account, theme: self.theme, strings: self.strings, expanded: self.expanded)
                node.updateIsHighlighted()
                node.updateAppearanceTransition(transition: .immediate)
                
                node.contentSize = self.expanded ? expandedBoundingSize : boundingSize
                node.insets = ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)
                
                completion(node, {
                    return (nil, { _ in
                        
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            completion(ListViewItemNodeLayout(contentSize: self.expanded ? expandedBoundingSize : boundingSize, insets: node().insets), { _ in
                (node() as? ChatMediaInputMetaSectionItemNode)?.setItem(item: self)
                (node() as? ChatMediaInputMetaSectionItemNode)?.updateTheme(account: self.account, theme: self.theme, strings: self.strings, expanded: self.expanded)
            })
        }
    }
    
    func selected(listView: ListView) {
        self.selectedItem()
    }
}

private let boundingSize = CGSize(width: 72.0, height: 41.0)
private let expandedBoundingSize = CGSize(width: 72.0, height: 72.0)
private let boundingImageScale: CGFloat = 0.625
private let highlightSize = CGSize(width: 56.0, height: 56.0)
private let verticalOffset: CGFloat = 3.0 + UIScreenPixel

final class ChatMediaInputMetaSectionItemNode: ListViewItemNode {
    private let containerNode: ASDisplayNode
    private let scalingNode: ASDisplayNode
    private let imageNode: ASImageNode
    private let textNodeContainer: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let highlightNode: ASImageNode
    private let titleNode: ImmediateTextNode
    
    private var animatedStickerNode: AnimatedStickerNode?
    
    private var currentExpanded = false
    
    var item: ChatMediaInputMetaSectionItem?
    var currentCollectionId: ItemCollectionId?
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    
    var theme: PresentationTheme?
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.visibilityStatus = self.visibility != .none
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                let loopAnimatedStickers = self.inputNodeInteraction?.stickerSettings?.loopAnimatedStickers ?? false
                self.animatedStickerNode?.visibility = self.visibilityStatus && loopAnimatedStickers
            }
        }
    }
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    init() {
        self.containerNode = ASDisplayNode()
        self.containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        self.scalingNode = ASDisplayNode()
        
        self.highlightNode = ASImageNode()
        self.highlightNode.isLayerBacked = true
        self.highlightNode.isHidden = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.contentMode = .center
        
        self.textNodeContainer = ASDisplayNode()
        self.textNodeContainer.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.textNodeContainer.addSubnode(self.textNode)
        self.textNodeContainer.isUserInteractionEnabled = false
        
        self.titleNode = ImmediateTextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.scalingNode)
        
        self.scalingNode.addSubnode(self.highlightNode)
        self.scalingNode.addSubnode(self.titleNode)
        self.scalingNode.addSubnode(self.imageNode)
        self.scalingNode.addSubnode(self.textNodeContainer)
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    func setItem(item: ChatMediaInputMetaSectionItem) {
        self.item = item
        switch item.type {
        case .savedStickers:
            self.currentCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue, id: 0)
        case .recentStickers:
            self.currentCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue, id: 0)
        case .premium:
            self.currentCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.premium.rawValue, id: 0)
        default:
            break
        }
    }
    
    func updateTheme(account: Account, theme: PresentationTheme, strings: PresentationStrings, expanded: Bool) {
        let imageSize = CGSize(width: 44.0, height: 42.0)
        self.imageNode.frame = CGRect(origin: CGPoint(x: floor((expandedBoundingSize.width - imageSize.width) / 2.0), y: floor((expandedBoundingSize.height - imageSize.height) / 2.0) + UIScreenPixel), size: imageSize)
        
        self.textNodeContainer.frame = CGRect(origin: CGPoint(x: floor((expandedBoundingSize.width - imageSize.width) / 2.0) + verticalOffset, y: floor((expandedBoundingSize.height - imageSize.height) / 2.0) + 1.0), size: imageSize)
        
        if self.theme !== theme {
            self.theme = theme
            
            self.highlightNode.image = PresentationResourcesChat.chatMediaInputPanelHighlightedIconImage(theme)
            var title = ""
            if let item = self.item {
                switch item.type {
                case .savedStickers:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelSavedStickersIcon(theme)
                    title = strings.Stickers_Favorites
                case .recentStickers:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelRecentStickersIcon(theme)
                    title = strings.Stickers_Recent
                case .stickersMode:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelStickersModeIcon(theme)
                    title = strings.Stickers_Stickers
                case .savedGifs:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelRecentStickersIcon(theme)
                    title = strings.Stickers_Gifs
                case .trendingGifs:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelTrendingGifsIcon(theme)
                    title = strings.Stickers_Trending
                case .premium:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelPremiumIcon(theme)
                    title = strings.Stickers_PremiumStickers
                case let .gifEmoji(emoji, file):
                    switch emoji {
                        case "😡":
                            title = strings.Gif_Emotion_Angry
                        case "😮":
                            title = strings.Gif_Emotion_Surprised
                        case "😂":
                            title = strings.Gif_Emotion_Joy
                        case "😘":
                            title = strings.Gif_Emotion_Kiss
                        case "😍":
                            title = strings.Gif_Emotion_Hearts
                        case "👍":
                            title = strings.Gif_Emotion_ThumbsUp
                        case "👎":
                            title = strings.Gif_Emotion_ThumbsDown
                        case "🙄":
                            title = strings.Gif_Emotion_RollEyes
                        case "😎":
                            title = strings.Gif_Emotion_Cool
                        case "🥳":
                            title = strings.Gif_Emotion_Party
                        default:
                            break
                    }
                    self.imageNode.image = nil
                    
                    if let file = file {
                        let loopAnimatedStickers = self.inputNodeInteraction?.stickerSettings?.loopAnimatedStickers ?? false
                        let animatedStickerNode: AnimatedStickerNode
                        if let current = self.animatedStickerNode {
                            animatedStickerNode = current
                        } else {
                            animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                            self.animatedStickerNode = animatedStickerNode
                            self.scalingNode.addSubnode(animatedStickerNode)
                            animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: account, resource: file.resource), width: 128, height: 128, playbackMode: .loop, mode: .cached)
                        }
                        animatedStickerNode.visibility = self.visibilityStatus && loopAnimatedStickers
                        
                        self.stickerFetchedDisposable.set(fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: MediaResourceReference.media(media: .standalone(media: file), resource: file.resource)).start())
                    } else {
                        self.textNode.attributedText = NSAttributedString(string: emoji, font: Font.regular(43.0), textColor: .black)
                        let textSize = self.textNode.updateLayout(CGSize(width: 100.0, height: 100.0))
                        self.textNode.frame = CGRect(origin: CGPoint(x: floor((self.textNodeContainer.bounds.width - textSize.width) / 2.0), y: floor((self.textNodeContainer.bounds.height - textSize.height) / 2.0)), size: textSize)
                    }
                }
            }
            self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(11.0), textColor: theme.chat.inputPanel.primaryTextColor)
        }
                
        self.containerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedBoundingSize)
        self.scalingNode.bounds = CGRect(origin: CGPoint(), size: expandedBoundingSize)
        
        let boundsSize = expanded ? expandedBoundingSize : CGSize(width: boundingSize.height, height: boundingSize.height)
        let expandScale: CGFloat = expanded ? 1.0 : boundingImageScale
        let expandTransition: ContainedViewLayoutTransition = self.currentExpanded != expanded ? .animated(duration: 0.3, curve: .spring) : .immediate
        expandTransition.updateTransformScale(node: self.scalingNode, scale: expandScale)
        expandTransition.updatePosition(node: self.scalingNode, position: CGPoint(x: boundsSize.width / 2.0, y: boundsSize.height / 2.0 + (expanded ? -53.0 : -7.0)))

        let titleSize = self.titleNode.updateLayout(CGSize(width: expandedBoundingSize.width + 10.0, height: expandedBoundingSize.height))
        
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((expandedBoundingSize.width - titleSize.width) / 2.0), y: expandedBoundingSize.height - titleSize.height + 6.0), size: titleSize)
        let displayTitleFrame = expanded ? titleFrame : CGRect(origin: CGPoint(x: titleFrame.minX, y: self.imageNode.position.y - titleFrame.size.height), size: titleFrame.size)
        expandTransition.updateFrameAsPositionAndBounds(node: self.titleNode, frame: displayTitleFrame)
        expandTransition.updateTransformScale(node: self.titleNode, scale: expanded ? 1.0 : 0.001)
        
        let alphaTransition: ContainedViewLayoutTransition = self.currentExpanded != expanded ? .animated(duration: expanded ? 0.15 : 0.1, curve: .linear) : .immediate
        alphaTransition.updateAlpha(node: self.titleNode, alpha: expanded ? 1.0 : 0.0, delay: expanded ? 0.05 : 0.0)
        
        self.currentExpanded = expanded
        
        if let animatedStickerNode = self.animatedStickerNode {
            animatedStickerNode.frame = self.imageNode.frame
            animatedStickerNode.updateLayout(size: self.imageNode.frame.size)
        }
        
        expandTransition.updateFrame(node: self.highlightNode, frame: expanded ? titleFrame.insetBy(dx: -7.0, dy: -2.0) : CGRect(origin: CGPoint(x: self.imageNode.position.x - highlightSize.width / 2.0, y: self.imageNode.position.y - highlightSize.height / 2.0), size: highlightSize))
    }
    
    func updateIsHighlighted() {
        guard let inputNodeInteraction = self.inputNodeInteraction else {
            return
        }
        if let currentCollectionId = self.currentCollectionId {
            self.highlightNode.isHidden = inputNodeInteraction.highlightedItemCollectionId != currentCollectionId
        } else if let item = self.item {
            var isHighlighted = false
            switch item.type {
            case .savedGifs:
                if case .recent = inputNodeInteraction.highlightedGifMode {
                    isHighlighted = true
                }
            case .trendingGifs:
                if case .trending = inputNodeInteraction.highlightedGifMode {
                    isHighlighted = true
                }
            case let .gifEmoji(emoji, _):
                if case .emojiSearch(emoji) = inputNodeInteraction.highlightedGifMode {
                    isHighlighted = true
                }
            default:
                break
            }
            self.highlightNode.isHidden = !isHighlighted
        }
    }
    
    func updateAppearanceTransition(transition: ContainedViewLayoutTransition) {
        if let inputNodeInteraction = self.inputNodeInteraction {
            transition.updateSublayerTransformScale(node: self, scale: inputNodeInteraction.appearanceTransition)
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
        self.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
    }
}
