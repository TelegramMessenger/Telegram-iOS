import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AccountContext

public enum ChatListFilterSettingsHeaderAnimation {
    case folders
    case newFolder
    case discussionGroupSetup
    case autoRemove
}

public class ChatListFilterSettingsHeaderItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let theme: PresentationTheme
    let text: String
    let animation: ChatListFilterSettingsHeaderAnimation
    public let sectionId: ItemListSectionId
    
    public init(context: AccountContext, theme: PresentationTheme, text: String, animation: ChatListFilterSettingsHeaderAnimation, sectionId: ItemListSectionId) {
        self.context = context
        self.theme = theme
        self.text = text
        self.animation = animation
        self.sectionId = sectionId
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListFilterSettingsHeaderItemNode()
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
            guard let nodeValue = node() as? ChatListFilterSettingsHeaderItemNode else {
                assertionFailure()
                return
            }
            
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

private let titleFont = Font.regular(13.0)

class ChatListFilterSettingsHeaderItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private var animationNode: AnimatedStickerNode
    
    private var item: ChatListFilterSettingsHeaderItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.animationNode = AnimatedStickerNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.animationNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.animationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.animationTapGesture(_:))))
    }
    
    @objc private func animationTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if !self.animationNode.isPlaying {
                self.animationNode.play()
            }
        }
    }
    
    func asyncLayout() -> (_ item: ChatListFilterSettingsHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, params, neighbors in
            let isHidden = params.width > params.availableHeight && params.availableHeight < 400.0
            
            let leftInset: CGFloat = 32.0 + params.leftInset
            
            let animationName: String
            var size = 192
            var insetDifference = 100
            var additionalBottomInset: CGFloat = 0.0
            var playbackMode: AnimatedStickerPlaybackMode = .once
            switch item.animation {
            case .folders:
                animationName = "ChatListFolders"
            case .newFolder:
                animationName = "ChatListNewFolder"
            case .discussionGroupSetup:
                animationName = "DiscussionGroupSetup"
            case .autoRemove:
                animationName = "MessageAutoRemove"
                size = 260
                insetDifference = 120
                playbackMode = .once
                additionalBottomInset = isHidden ? 8.0 : 16.0
            }
            
            let topInset: CGFloat = CGFloat(size - insetDifference)
            
            let attributedText = NSAttributedString(string: item.text, font: titleFont, textColor: item.theme.list.freeTextColor)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize = CGSize(width: params.width, height: topInset + titleLayout.size.height)
            var insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            if isHidden {
                insets = UIEdgeInsets()
            }
            insets.bottom += additionalBottomInset
            
            let layout = ListViewItemNodeLayout(contentSize: isHidden ? CGSize(width: params.width, height: 0.0) : contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    if strongSelf.item == nil {
                        strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: size, height: size, playbackMode: playbackMode, mode: .direct(cachePathPrefix: nil))
                        strongSelf.animationNode.visibility = true
                    }
                    
                    strongSelf.item = item
                    strongSelf.accessibilityLabel = attributedText.string
                                        
                    let iconSize = CGSize(width: CGFloat(size) / 2.0, height: CGFloat(size) / 2.0)
                    strongSelf.animationNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: -10.0), size: iconSize)
                    strongSelf.animationNode.updateLayout(size: iconSize)
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleLayout.size.width) / 2.0), y: topInset + 8.0), size: titleLayout.size)
                    
                    strongSelf.animationNode.alpha = isHidden ? 0.0 : 1.0
                    strongSelf.titleNode.alpha = isHidden ? 0.0 : 1.0
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
