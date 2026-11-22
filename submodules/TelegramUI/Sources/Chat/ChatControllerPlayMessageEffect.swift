import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import AccountContext
import ChatMessageItemView

extension ChatControllerImpl {
    func playMessageEffect(message: EngineMessage) {
        var messageItemNode: ChatMessageItemView?
        self.chatDisplayNode.historyNode.forEachVisibleMessageItemNode { itemNode in
            if let item = itemNode.item, item.message.id == message.id {
                messageItemNode = itemNode
            }
        }
        
        messageItemNode?.playMessageEffect(force: true)
    }
}
