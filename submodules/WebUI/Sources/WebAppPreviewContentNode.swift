import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import PhotoResources

private final class WebAppPreviewContentNode: AlertContentNode {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let result: ChatContextResult
    private let outgoingMessage: EnqueueMessage?
    private var previewItem: ListViewItem?
    private var previewNode: ListViewItemNode?
    
    private let titleNode: ASTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
    
    private var iconDisposable: Disposable?
    
    
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(context: AccountContext, theme: AlertControllerTheme, presentationData: PresentationData, to peerId: PeerId, botId: PeerId, result: ChatContextResult, actions: [TextAlertAction]) {
        self.context = context
        self.presentationData = presentationData
        self.result = result
                
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 0
              
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(theme: theme, action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        self.outgoingMessage = self.context.engine.messages.outgoingMessageWithChatContextResult(to: peerId, botId: botId, result: result, replyToMessageId: nil, hideVia: true, silentPosting: false, scheduleTime: nil, correlationId: nil)
        
        super.init()
        
        self.addSubnode(self.titleNode)
    
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
                
        self.updateTheme(theme)
        
        if let outgoingMessage = self.outgoingMessage, case let .message(text, attributes, mediaReference, _, _, _) = outgoingMessage {
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
            var peers = SimpleDictionary<PeerId, Peer>()
            peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: "", lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
            
            var media: [Media] = []
            if let mediaReference = mediaReference {
                media.append(mediaReference.media)
            }
            
            let previewMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: scheduleWhenOnlineTimestamp, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: text, attributes: attributes, media: media, peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [])
            
            let previewItem = context.sharedContext.makeChatMessagePreviewItem(context: context, messages: [previewMessage], theme: presentationData.theme.withUpdated(preview: true), strings: presentationData.strings, wallpaper: .color(0xffffff), fontSize: presentationData.chatFontSize, chatBubbleCorners: presentationData.chatBubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: nil, availableReactions: nil, isCentered: true)
            self.previewItem = previewItem
        }
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.WebApp_MessagePreview, font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        for actionNode in self.actionNodes {
            actionNode.updateTheme(theme)
        }
        for separatorNode in self.actionVerticalSeparators {
            separatorNode.backgroundColor = theme.separatorColor
        }
        
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var size = size
        size.width = min(size.width , 290.0)
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
                
        let textSize = self.titleNode.measure(size)
        var textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize)
        origin.y += textSize.height + 12.0
        
        var iconSize = CGSize()
        var iconFrame = CGRect()

        let sideInset: CGFloat = 0.0
        let params = ListViewItemLayoutParams(width: size.width, leftInset: sideInset, rightInset: sideInset, availableHeight: size.height)
        if let previewItem = self.previewItem {
            if let previewNode = self.previewNode {
                previewItem.updateNode(async: { $0() }, node: {
                    return previewNode
                }, params: params, previousItem: nil, nextItem: nil, animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: layout.size.height))
                    
                    previewNode.contentSize = layout.contentSize
                    previewNode.insets = layout.insets
                    previewNode.frame = nodeFrame
                    previewNode.isUserInteractionEnabled = false
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            } else {
                var itemNode: ListViewItemNode?
                previewItem.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                itemNode!.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
                itemNode!.isUserInteractionEnabled = false
                self.addSubnode(itemNode!)
                self.previewNode = itemNode
            }
            iconSize = CGSize(width: 0.0, height: self.previewNode?.frame.height ?? 0.0)
            
            self.previewNode?.frame = CGRect(x: 4.0, y: origin.y, width: size.width, height: iconSize.height)
            origin.y += iconSize.height
        }
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: maxActionWidth, height: actionButtonHeight))
            if case .horizontal = effectiveActionLayout, actionTitleSize.height > actionButtonHeight * 0.6667 {
                effectiveActionLayout = .vertical
            }
            switch effectiveActionLayout {
                case .horizontal:
                    minActionsWidth += actionTitleSize.width + actionTitleInsets
                case .vertical:
                    minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
            }
        }
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var contentWidth = max(textSize.width, minActionsWidth)
        contentWidth = max(contentWidth, 260.0)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultWidth = contentWidth + insets.left + insets.right
        let resultSize = CGSize(width: resultWidth, height: iconSize.height + textSize.height + actionsHeight + 17.0 + insets.top + insets.bottom)
        
        transition.updateFrame(node: self.actionNodesSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                switch effectiveActionLayout {
                    case .horizontal:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - UIScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: UIScreenPixel, height: actionsHeight - UIScreenPixel)))
                    case .vertical:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            switch effectiveActionLayout {
                case .horizontal:
                    if nodeIndex == self.actionNodes.count - 1 {
                        currentActionWidth = resultSize.width - actionOffset
                    } else {
                        currentActionWidth = actionWidth
                    }
                case .vertical:
                    currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            switch effectiveActionLayout {
                case .horizontal:
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += currentActionWidth
                case .vertical:
                    actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += actionButtonHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        iconFrame.origin.x = floorToScreenPixels((resultSize.width - iconFrame.width) / 2.0) + 19.0
    
    
        textFrame.origin.x = floorToScreenPixels((resultSize.width - textFrame.width) / 2.0)
        transition.updateFrame(node: self.titleNode, frame: textFrame)
        
        return resultSize
    }
}

public func webAppPreviewResultController(context: AccountContext, to peerId: PeerId, botId: PeerId, result: ChatContextResult, completion: @escaping () -> Void) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

    var dismissImpl: ((Bool) -> Void)?
    var contentNode: WebAppPreviewContentNode?
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.WebApp_Send, action: {
        dismissImpl?(true)
      
        completion()
    })]
    
    contentNode = WebAppPreviewContentNode(context: context, theme: AlertControllerTheme(presentationData: presentationData), presentationData: presentationData, to: peerId, botId: botId, result: result, actions: actions)
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode!)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
