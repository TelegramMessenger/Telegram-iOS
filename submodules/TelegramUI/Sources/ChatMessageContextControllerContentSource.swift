import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ContextUI
import Postbox
import TelegramCore
import SwiftSignalKit
import ChatMessageItemView
import AccountContext
import WallpaperBackgroundNode
import TelegramPresentationData
import DustEffect
import TooltipUI
import TelegramNotices
 
final class ChatMessageContextLocationContentSource: ContextLocationContentSource {
    private let controller: ViewController
    private let location: CGPoint
    
    init(controller: ViewController, location: CGPoint) {
        self.controller = controller
        self.location = location
    }
    
    func transitionInfo() -> ContextControllerLocationViewInfo? {
        return ContextControllerLocationViewInfo(location: self.location, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

final class ChatMessageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    let centerVertically: Bool
    
    private weak var chatNode: ChatControllerNode?
    private let engine: TelegramEngine
    private let message: Message
    private let selectAll: Bool
    
    var shouldBeDismissed: Signal<Bool, NoError> {
        if self.message.adAttribute != nil {
            return .single(false)
        }
    
        return self.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: self.message.id))
        |> map { message -> Bool in
            if let _ = message {
                return false
            } else {
                return true
            }
        }
        |> distinctUntilChanged
    }
    
    init(chatNode: ChatControllerNode, engine: TelegramEngine, message: Message, selectAll: Bool, centerVertically: Bool = false) {
        self.chatNode = chatNode
        self.engine = engine
        self.message = message
        self.selectAll = selectAll
        self.centerVertically = centerVertically
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        
        var result: ContextControllerTakeViewInfo?
        chatNode.historyNode.forEachItemNode { itemNode in
            guard let itemNode = itemNode as? ChatMessageItemView else {
                return
            }
            guard let item = itemNode.item else {
                return
            }
            if item.content.contains(where: { $0.0.stableId == self.message.stableId }), let contentNode = itemNode.getMessageContextSourceNode(stableId: self.selectAll ? nil : self.message.stableId) {
                result = ContextControllerTakeViewInfo(containingItem: .node(contentNode), contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
            }
        }
        return result
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        
        var result: ContextControllerPutBackViewInfo?
        chatNode.historyNode.forEachItemNode { itemNode in
            guard let itemNode = itemNode as? ChatMessageItemView else {
                return
            }
            guard let item = itemNode.item else {
                return
            }
            if item.content.contains(where: { $0.0.stableId == self.message.stableId }) {
                result = ContextControllerPutBackViewInfo(contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
            }
        }
        return result
    }
}

final class ChatViewOnceMessageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    let centerVertically: Bool = true
    
    private let context: AccountContext
    private let presentationData: PresentationData
    private weak var chatNode: ChatControllerNode?
    private weak var backgroundNode: WallpaperBackgroundNode?
    private let engine: TelegramEngine
    private let message: Message
    private let present: (ViewController) -> Void

    private var messageNodeCopy: ChatMessageItemView?
    private weak var tooltipController: TooltipScreen?
    
    private let idleTimerExtensionDisposable = MetaDisposable()
    
    var shouldBeDismissed: Signal<Bool, NoError> {
        return self.context.sharedContext.mediaManager.globalMediaPlayerState
        |> filter { playlistStateAndType in
            if let (_, state, _) = playlistStateAndType, case .state = state {
                return true
            } else {
                return false
            }
        }
        |> take(1)
        |> map { _ in
            return false
        }
        |> then(
            self.context.sharedContext.mediaManager.globalMediaPlayerState
            |> filter { playlistStateAndType in
                return playlistStateAndType == nil
            }
            |> take(1)
            |> map { _ in
                return true
            }
        )
    }
    
    init(context: AccountContext, presentationData: PresentationData, chatNode: ChatControllerNode, backgroundNode: WallpaperBackgroundNode, engine: TelegramEngine, message: Message, present: @escaping (ViewController) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.chatNode = chatNode
        self.backgroundNode = backgroundNode
        self.engine = engine
        self.message = message
        self.present = present
    }
    
    deinit {
        self.idleTimerExtensionDisposable.dispose()
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        guard let chatNode = self.chatNode, let backgroundNode = self.backgroundNode, let validLayout = chatNode.validLayout?.0 else {
            return nil
        }
        
        self.idleTimerExtensionDisposable.set(self.context.sharedContext.applicationBindings.pushIdleTimerExtension())
        
        var result: ContextControllerTakeViewInfo?
        var sourceNode: ContextExtractedContentContainingNode?
        var sourceRect: CGRect = .zero
        chatNode.historyNode.forEachItemNode { itemNode in
            guard let itemNode = itemNode as? ChatMessageItemView else {
                return
            }
            guard let item = itemNode.item else {
                return
            }
            if item.content.contains(where: { $0.0.stableId == self.message.stableId }), let contentNode = itemNode.getMessageContextSourceNode(stableId: self.message.stableId) {
                sourceNode = contentNode
                sourceRect = itemNode.frame
            }
        }
        
        let isIncoming = self.message.effectivelyIncoming(self.context.account.peerId)
        let isVideo = (self.message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile)?.isInstantVideo ?? false
        
        var tooltipSourceRect: CGRect = .zero
        
        if let sourceNode {
            var bubbleWidth: CGFloat = 0.0
            
            if (isIncoming || "".isEmpty) && !isVideo {
                let messageItem = self.context.sharedContext.makeChatMessagePreviewItem(
                    context: self.context,
                    messages: [self.message],
                    theme: self.presentationData.theme,
                    strings: self.presentationData.strings,
                    wallpaper: self.presentationData.chatWallpaper,
                    fontSize: self.presentationData.chatFontSize,
                    chatBubbleCorners: self.presentationData.chatBubbleCorners,
                    dateTimeFormat: self.presentationData.dateTimeFormat,
                    nameOrder: self.presentationData.nameDisplayOrder,
                    forcedResourceStatus: nil,
                    tapMessage: nil,
                    clickThroughMessage: nil,
                    backgroundNode: backgroundNode,
                    availableReactions: nil,
                    accountPeer: nil,
                    isCentered: false,
                    isPreview: false
                )
                
                let params = ListViewItemLayoutParams(width: chatNode.historyNode.frame.width, leftInset: validLayout.safeInsets.left, rightInset: validLayout.safeInsets.right, availableHeight: chatNode.historyNode.frame.height, isStandalone: false)
                var node: ListViewItemNode?
                
                messageItem.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { messageNode, apply in
                    node = messageNode
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                
                if let messageNode = node as? ChatMessageItemView, let copyContentNode = messageNode.getMessageContextSourceNode(stableId: self.message.stableId) {
                    messageNode.frame.origin.y = chatNode.frame.height - sourceRect.origin.y - sourceRect.size.height
                    chatNode.addSubnode(messageNode)
                    result = ContextControllerTakeViewInfo(containingItem: .node(copyContentNode), contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
                    
                    bubbleWidth = copyContentNode.contentNode.subnodes?.first?.frame.width ?? messageNode.frame.width
                }
                
                self.messageNodeCopy = node as? ChatMessageItemView
            } else {
                result = ContextControllerTakeViewInfo(containingItem: .node(sourceNode), contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
            }
            
            tooltipSourceRect = CGRect(x: isIncoming ? 22.0 : chatNode.frame.width - bubbleWidth + 10.0, y: floorToScreenPixels((chatNode.frame.height - 75.0) / 2.0) - 43.0, width: 44.0, height: 44.0)
        }
        
        if !isVideo {
            let displayTooltip = { [weak self] in
                guard let self else {
                    return
                }
                let absoluteFrame = tooltipSourceRect
                let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.maxY), size: CGSize())
                
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                var tooltipText: String?
                if isIncoming {
                    tooltipText = presentationData.strings.Chat_PlayOnceVoiceMessageTooltip
                } else if let peer = self.message.peers[self.message.id.peerId] {
                    let peerName = EnginePeer(peer).compactDisplayTitle
                    tooltipText = presentationData.strings.Chat_PlayOnceVoiceMessageYourTooltip(peerName).string
                }
                
                if let tooltipText {
                    let tooltipController = TooltipScreen(
                        account: self.context.account,
                        sharedContext: self.context.sharedContext,
                        text: .markdown(text: tooltipText),
                        balancedTextLayout: true,
                        constrainWidth: 240.0,
                        style: .customBlur(UIColor(rgb: 0x18181a), 0.0),
                        arrowStyle: .small,
                        icon: nil,
                        location: .point(location, .bottom),
                        displayDuration: .custom(3.0),
                        inset: 8.0,
                        cornerRadius: 11.0,
                        shouldDismissOnTouch: { _, _ in
                            return .ignore
                        }
                    )
                    self.tooltipController = tooltipController
                    self.present(tooltipController)
                }
            }
            
            if isIncoming {
                let _ = (ApplicationSpecificNotice.getIncomingVoiceMessagePlayOnceTip(accountManager: self.context.sharedContext.accountManager)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] counter in
                    guard let self else {
                        return
                    }
                    if counter >= 2 {
                        return
                    }
                    Queue.mainQueue().after(0.3) {
                        displayTooltip()
                    }
                    let _ = ApplicationSpecificNotice.incrementIncomingVoiceMessagePlayOnceTip(accountManager: self.context.sharedContext.accountManager).startStandalone()
                })
            } else {
                let _ = (ApplicationSpecificNotice.getOutgoingVoiceMessagePlayOnceTip(accountManager: self.context.sharedContext.accountManager)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] counter in
                    guard let self else {
                        return
                    }
                    if counter >= 2 {
                        return
                    }
                    Queue.mainQueue().after(0.3) {
                        displayTooltip()
                    }
                    let _ = ApplicationSpecificNotice.incrementOutgoingVoiceMessagePlayOnceTip(accountManager: self.context.sharedContext.accountManager).startStandalone()
                })
            }
        }
        return result
    }
    
    private var dustEffectLayer: DustEffectLayer?
    func putBack() -> ContextControllerPutBackViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        
        self.idleTimerExtensionDisposable.set(nil)
        
        if let tooltipController = self.tooltipController {
            tooltipController.dismiss()
        }
        
        if let messageNodeCopy = self.messageNodeCopy, let sourceView = messageNodeCopy.supernode?.view, let contentNode = messageNodeCopy.getMessageContextSourceNode(stableId: nil)?.contentNode, let parentNode = contentNode.supernode?.supernode?.supernode {
            let dustEffectLayer = DustEffectLayer()
            dustEffectLayer.position = sourceView.bounds.center
            dustEffectLayer.bounds = CGRect(origin: CGPoint(), size: sourceView.bounds.size)
            dustEffectLayer.zPosition = 10.0
            parentNode.layer.addSublayer(dustEffectLayer)
            
            guard let (image, subFrame) = messageNodeCopy.makeContentSnapshot() else {
                return nil
            }
            var itemFrame = subFrame //messageNodeCopy.layer.convert(subFrame, to: dustEffectLayer)
            itemFrame.origin.y = floorToScreenPixels((sourceView.frame.height - subFrame.height) / 2.0)
            dustEffectLayer.addItem(frame: itemFrame, image: image)
            messageNodeCopy.removeFromSupernode()
            contentNode.removeFromSupernode()
            return nil
        } else {
            var result: ContextControllerPutBackViewInfo?
            chatNode.historyNode.forEachItemNode { itemNode in
                guard let itemNode = itemNode as? ChatMessageItemView else {
                    return
                }
                guard let item = itemNode.item else {
                    return
                }
                if item.content.contains(where: { $0.0.stableId == self.message.stableId }) {
                    result = ContextControllerPutBackViewInfo(contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
                }
            }
            return result
        }
    }
}

final class ChatMessageReactionContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .center
    
    private weak var chatNode: ChatControllerNode?
    private let engine: TelegramEngine
    private let message: Message
    private let contentView: ContextExtractedContentContainingView
    
    var shouldBeDismissed: Signal<Bool, NoError> {
        if self.message.adAttribute != nil {
            return .single(false)
        }
        
        return self.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: self.message.id))
        |> map { message -> Bool in
            if let _ = message {
                return false
            } else {
                return true
            }
        }
        |> distinctUntilChanged
    }
    
    init(chatNode: ChatControllerNode, engine: TelegramEngine, message: Message, contentView: ContextExtractedContentContainingView) {
        self.chatNode = chatNode
        self.engine = engine
        self.message = message
        self.contentView = contentView
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        
        var result: ContextControllerTakeViewInfo?
        chatNode.historyNode.forEachItemNode { itemNode in
            guard let itemNode = itemNode as? ChatMessageItemView else {
                return
            }
            guard let item = itemNode.item else {
                return
            }
            if item.content.contains(where: { $0.0.stableId == self.message.stableId }) {
                result = ContextControllerTakeViewInfo(containingItem: .view(self.contentView), contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
            }
        }
        return result
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        
        var result: ContextControllerPutBackViewInfo?
        chatNode.historyNode.forEachItemNode { itemNode in
            guard let itemNode = itemNode as? ChatMessageItemView else {
                return
            }
            guard let item = itemNode.item else {
                return
            }
            if item.content.contains(where: { $0.0.stableId == self.message.stableId }) {
                result = ContextControllerPutBackViewInfo(contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
            }
        }
        return result
    }
}

final class ChatMessageNavigationButtonContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .center
    
    private weak var chatNode: ChatControllerNode?
    private let contentNode: ContextExtractedContentContainingNode
    
    var shouldBeDismissed: Signal<Bool, NoError> {
        return .single(false)
    }
    
    init(chatNode: ChatControllerNode, contentNode: ContextExtractedContentContainingNode) {
        self.chatNode = chatNode
        self.contentNode = contentNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        
        return ContextControllerTakeViewInfo(containingItem: .node(self.contentNode), contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
    }
}
