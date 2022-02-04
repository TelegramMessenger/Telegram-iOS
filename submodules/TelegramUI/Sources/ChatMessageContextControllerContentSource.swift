import Foundation
import UIKit
import Display
import ContextUI
import Postbox
import SwiftSignalKit

final class ChatMessageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    private weak var chatNode: ChatControllerNode?
    private let postbox: Postbox
    private let message: Message
    private let selectAll: Bool
    
    var shouldBeDismissed: Signal<Bool, NoError> {
        if self.message.adAttribute != nil {
            return .single(false)
        }
        let viewKey = PostboxViewKey.messages(Set([self.message.id]))
        return self.postbox.combinedView(keys: [viewKey])
        |> map { views -> Bool in
            guard let view = views.views[viewKey] as? MessagesView else {
                return false
            }
            if view.messages.isEmpty {
                return true
            } else {
                return false
            }
        }
        |> distinctUntilChanged
    }
    
    init(chatNode: ChatControllerNode, postbox: Postbox, message: Message, selectAll: Bool) {
        self.chatNode = chatNode
        self.postbox = postbox
        self.message = message
        self.selectAll = selectAll
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
                result = ContextControllerTakeViewInfo(contentContainingNode: contentNode, contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
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

final class ChatMessageReactionContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let centerActionsHorizontally: Bool = true
    
    private weak var chatNode: ChatControllerNode?
    private let postbox: Postbox
    private let message: Message
    private let contentNode: ContextExtractedContentContainingNode
    
    var shouldBeDismissed: Signal<Bool, NoError> {
        if self.message.adAttribute != nil {
            return .single(false)
        }
        let viewKey = PostboxViewKey.messages(Set([self.message.id]))
        return self.postbox.combinedView(keys: [viewKey])
        |> map { views -> Bool in
            guard let view = views.views[viewKey] as? MessagesView else {
                return false
            }
            if view.messages.isEmpty {
                return true
            } else {
                return false
            }
        }
        |> distinctUntilChanged
    }
    
    init(chatNode: ChatControllerNode, postbox: Postbox, message: Message, contentNode: ContextExtractedContentContainingNode) {
        self.chatNode = chatNode
        self.postbox = postbox
        self.message = message
        self.contentNode = contentNode
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
                result = ContextControllerTakeViewInfo(contentContainingNode: self.contentNode, contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
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
    let centerActionsHorizontally: Bool = true
    
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
        
        return ContextControllerTakeViewInfo(contentContainingNode: self.contentNode, contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
    }
}
