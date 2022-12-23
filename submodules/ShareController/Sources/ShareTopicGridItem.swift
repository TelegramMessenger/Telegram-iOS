import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import TelegramPresentationData
import TelegramStringFormatting
import SelectablePeerNode
import PeerPresenceStatusManager
import AccountContext
import ShimmerEffect
import ComponentFlow
import EmojiStatusComponent

final class ShareTopicGridItem: GridItem {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EngineRenderedPeer?
    let id: Int64
    let threadInfo: MessageHistoryThreadData
    let controllerInteraction: ShareControllerInteraction
    
    let section: GridSection?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peer: EngineRenderedPeer?, id: Int64, threadInfo: MessageHistoryThreadData, controllerInteraction: ShareControllerInteraction) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.id = id
        self.threadInfo = threadInfo
        self.controllerInteraction = controllerInteraction
        
        self.section = nil
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        return ShareTopicGridItemNode()
    }
    
    func update(node: GridItemNode) {

    }
}

final class ShareTopicGridItemNode: GridItemNode {
    private var currentState: (AccountContext, PresentationTheme, PresentationStrings, EngineRenderedPeer?, MessageHistoryThreadData?)?
    
    private let iconView: ComponentView<Empty>
    private let textNode: ImmediateTextNode
        
    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var currentItem: ShareTopicGridItem?
    var id: Int64? {
        return self.currentItem?.id
    }
    
    override init() {
        self.iconView = ComponentView<Empty>()
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 2
        self.textNode.textAlignment = .center
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }
                                       
    @objc private func tapped() {
        if let item = self.currentItem, let peer = item.peer {
            item.controllerInteraction.selectTopic(peer, item.id, item.threadInfo)
        }
    }
    
    override func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
        let rect = absoluteRect
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    override func updateLayout(item: GridItem, size: CGSize, isVisible: Bool, synchronousLoads: Bool) {
        super.updateLayout(item: item, size: size, isVisible: isVisible, synchronousLoads: synchronousLoads)
        
        guard let item = item as? ShareTopicGridItem else {
            return
        }
        self.currentItem = item
        
        self.textNode.attributedText = NSAttributedString(string: item.threadInfo.info.title, font: Font.regular(11.0), textColor: item.theme.actionSheet.primaryTextColor)
        let textSize = self.textNode.updateLayout(size)
        let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: 4.0 + 60.0 + 4.0), size: textSize)
        self.textNode.frame = textFrame
        
        let iconContent: EmojiStatusComponent.Content
        if let fileId = item.threadInfo.info.icon {
            iconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 96.0, height: 96.0), placeholderColor: item.theme.actionSheet.disabledActionTextColor, themeColor: item.theme.actionSheet.primaryTextColor, loopMode: .count(2))
        } else {
            iconContent = .topic(title: String(item.threadInfo.info.title.prefix(1)), color: item.threadInfo.info.iconColor, size: CGSize(width: 64.0, height: 64.0))
        }
                
        let iconSize = self.iconView.update(
            transition: .easeInOut(duration: 0.2),
            component: AnyComponent(EmojiStatusComponent(
                context: item.context,
                animationCache: item.context.animationCache,
                animationRenderer: item.context.animationRenderer,
                content: iconContent,
                isVisibleForAnimations: true,
                action: nil
            )),
            environment: {},
            containerSize: CGSize(width: 54.0, height: 54.0)
        )
        
        if let iconComponentView = self.iconView.view {
            if iconComponentView.superview == nil {
                self.view.addSubview(iconComponentView)
            }
            iconComponentView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - iconSize.width) / 2.0), y: 7.0), size: iconSize)
        }
    }
        
    override func layout() {
        super.layout()
        
    }
}
