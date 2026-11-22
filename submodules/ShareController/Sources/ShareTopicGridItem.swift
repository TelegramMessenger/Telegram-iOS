import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import TelegramPresentationData
import TelegramStringFormatting
import SelectablePeerNode
import PeerPresenceStatusManager
import AccountContext
import ShimmerEffect
import ComponentFlow
import EmojiStatusComponent
import AvatarNode

final class ShareTopicGridItem: GridItem {
    let environment: ShareControllerEnvironment
    let context: ShareControllerAccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let basePeer: EnginePeer
    let peer: EngineRenderedPeer?
    let id: Int64
    let threadInfo: MessageHistoryThreadData?
    let controllerInteraction: ShareControllerInteraction
    
    let section: GridSection?
    
    init(environment: ShareControllerEnvironment, context: ShareControllerAccountContext, theme: PresentationTheme, strings: PresentationStrings, basePeer: EnginePeer, peer: EngineRenderedPeer?, id: Int64, threadInfo: MessageHistoryThreadData?, controllerInteraction: ShareControllerInteraction) {
        self.environment = environment
        self.context = context
        self.basePeer = basePeer
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
    private var currentState: (ShareControllerAccountContext, PresentationTheme, PresentationStrings, EngineRenderedPeer?, MessageHistoryThreadData?)?
    
    private let iconView: ComponentView<Empty>
    private let textNode: ImmediateTextNode
    private var avatarNode: AvatarNode?
        
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
            if let threadInfo = item.threadInfo {
                item.controllerInteraction.selectTopic(peer, item.id, threadInfo)
            } else {
                item.controllerInteraction.selectTopic(EngineRenderedPeer(peer: item.basePeer), item.id, nil)
            }
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
        
        if let threadInfo = item.threadInfo {
            self.textNode.attributedText = NSAttributedString(string: threadInfo.info.title, font: Font.regular(11.0), textColor: item.theme.actionSheet.primaryTextColor)
            
            let iconContent: EmojiStatusComponent.Content
            if let fileId = threadInfo.info.icon {
                iconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 96.0, height: 96.0), placeholderColor: item.theme.actionSheet.disabledActionTextColor, themeColor: item.theme.actionSheet.primaryTextColor, loopMode: .count(0))
            } else {
                iconContent = .topic(title: String(threadInfo.info.title.prefix(1)), color: threadInfo.info.iconColor, size: CGSize(width: 64.0, height: 64.0))
            }
                    
            let iconSize = self.iconView.update(
                transition: .easeInOut(duration: 0.2),
                component: AnyComponent(EmojiStatusComponent(
                    postbox: item.context.stateManager.postbox,
                    energyUsageSettings: item.environment.energyUsageSettings,
                    resolveInlineStickers: item.context.resolveInlineStickers,
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
        } else if let peer = item.peer, let mainPeer = peer.chatMainPeer {
            self.textNode.attributedText = NSAttributedString(string: mainPeer.compactDisplayTitle, font: Font.regular(11.0), textColor: item.theme.actionSheet.primaryTextColor)
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 12.0))
                self.avatarNode = avatarNode
                self.addSubnode(avatarNode)
            }
            let iconSize = CGSize(width: 54.0, height: 54.0)
            avatarNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - iconSize.width) / 2.0), y: 7.0), size: iconSize)
            avatarNode.updateSize(size: iconSize)
            
            avatarNode.setPeer(accountPeerId: item.context.accountPeerId, postbox: item.context.stateManager.postbox, network: item.context.stateManager.network, contentSettings: ContentSettings.default, theme: item.theme, peer: mainPeer, overrideImage: nil, emptyColor: item.theme.list.mediaPlaceholderColor, clipStyle: .round, synchronousLoad: false)
        }
        
        let textSize = self.textNode.updateLayout(size)
        let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: 4.0 + 60.0 + 4.0), size: textSize)
        self.textNode.frame = textFrame
    }
        
    override func layout() {
        super.layout()
        
    }
}
