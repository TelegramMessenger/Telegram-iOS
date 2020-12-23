import Foundation
import UIKit
import Display
import ContextUI
import Postbox

final class ChatMessageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    private weak var chatNode: ChatControllerNode?
    private let message: Message
    private let selectAll: Bool
    
    init(chatNode: ChatControllerNode, message: Message, selectAll: Bool) {
        self.chatNode = chatNode
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
