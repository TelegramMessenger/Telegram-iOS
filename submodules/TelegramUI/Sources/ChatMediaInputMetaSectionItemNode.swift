import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData

enum ChatMediaInputMetaSectionItemType: Equatable {
    case savedStickers
    case recentStickers
    case stickersMode
    case savedGifs
    case trendingGifs
    case gifEmoji(String)
}

final class ChatMediaInputMetaSectionItem: ListViewItem {
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let type: ChatMediaInputMetaSectionItemType
    let theme: PresentationTheme
    let selectedItem: () -> Void
    
    var selectable: Bool {
        return true
    }
    
    init(inputNodeInteraction: ChatMediaInputNodeInteraction, type: ChatMediaInputMetaSectionItemType, theme: PresentationTheme, selected: @escaping () -> Void) {
        self.inputNodeInteraction = inputNodeInteraction
        self.type = type
        self.selectedItem = selected
        self.theme = theme
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatMediaInputMetaSectionItemNode()
            Queue.mainQueue().async {
                node.inputNodeInteraction = self.inputNodeInteraction
                node.setItem(item: self)
                node.updateTheme(theme: self.theme)
                node.updateIsHighlighted()
                node.updateAppearanceTransition(transition: .immediate)
                
                node.contentSize = CGSize(width: 41.0, height: 41.0)
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
            completion(ListViewItemNodeLayout(contentSize: node().contentSize, insets: node().insets), { _ in
                (node() as? ChatMediaInputMetaSectionItemNode)?.setItem(item: self)
                (node() as? ChatMediaInputMetaSectionItemNode)?.updateTheme(theme: self.theme)
            })
        }
    }
    
    func selected(listView: ListView) {
        self.selectedItem()
    }
}

private let boundingSize = CGSize(width: 41.0, height: 41.0)
private let boundingImageSize = CGSize(width: 30.0, height: 30.0)
private let highlightSize = CGSize(width: 35.0, height: 35.0)
private let verticalOffset: CGFloat = 3.0 + UIScreenPixel

final class ChatMediaInputMetaSectionItemNode: ListViewItemNode {
    private let imageNode: ASImageNode
    private let textNodeContainer: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let highlightNode: ASImageNode
    
    var item: ChatMediaInputMetaSectionItem?
    var currentCollectionId: ItemCollectionId?
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    
    var theme: PresentationTheme?
    
    init() {
        self.highlightNode = ASImageNode()
        self.highlightNode.isLayerBacked = true
        self.highlightNode.isHidden = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        
        self.textNodeContainer = ASDisplayNode()
        self.textNodeContainer.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.textNodeContainer.addSubnode(self.textNode)
        self.textNodeContainer.isUserInteractionEnabled = false
        
        self.highlightNode.frame = CGRect(origin: CGPoint(x: floor((boundingSize.width - highlightSize.width) / 2.0) + verticalOffset, y: floor((boundingSize.height - highlightSize.height) / 2.0)), size: highlightSize)
        
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        self.textNodeContainer.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.highlightNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.textNodeContainer)
        
        let imageSize = CGSize(width: 26.0, height: 26.0)
        self.imageNode.frame = CGRect(origin: CGPoint(x: floor((boundingSize.width - imageSize.width) / 2.0) + verticalOffset, y: floor((boundingSize.height - imageSize.height) / 2.0) + UIScreenPixel), size: imageSize)
        
        self.textNodeContainer.frame = CGRect(origin: CGPoint(x: floor((boundingSize.width - imageSize.width) / 2.0) + verticalOffset, y: floor((boundingSize.height - imageSize.height) / 2.0) + 1.0), size: imageSize)
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
        default:
            break
        }
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.highlightNode.image = PresentationResourcesChat.chatMediaInputPanelHighlightedIconImage(theme)
            if let item = self.item {
                switch item.type {
                case .savedStickers:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelSavedStickersIcon(theme)
                case .recentStickers:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelRecentStickersIcon(theme)
                case .stickersMode:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelStickersModeIcon(theme)
                case .savedGifs:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelRecentStickersIcon(theme)
                case .trendingGifs:
                    self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelTrendingGifsIcon(theme)
                case let .gifEmoji(emoji):
                    self.imageNode.image = nil
                    self.textNode.attributedText = NSAttributedString(string: emoji, font: Font.regular(27.0), textColor: .black)
                    let textSize = self.textNode.updateLayout(CGSize(width: 100.0, height: 100.0))
                    self.textNode.frame = CGRect(origin: CGPoint(x: floor((self.textNodeContainer.bounds.width - textSize.width) / 2.0), y: floor((self.textNodeContainer.bounds.height - textSize.height) / 2.0)), size: textSize)
                }
            }
        }
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
            case let .gifEmoji(emoji):
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
