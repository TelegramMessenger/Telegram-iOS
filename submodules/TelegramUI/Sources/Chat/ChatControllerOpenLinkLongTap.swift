import Foundation
import Display
import ChatControllerInteraction
import AccountContext

extension ChatControllerImpl {
    func openLinkLongTap(_ action: ChatControllerInteractionLongTapAction, params: ChatControllerInteraction.LongTapParams?) {
        if self.presentationInterfaceState.interfaceState.selectionState != nil {
            return
        }
        
        self.dismissAllTooltips()
        
        (self.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
        self.chatDisplayNode.cancelInteractiveKeyboardGestures()
        self.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
        
        guard let params else {
            return
        }
        switch action {
        case let .url(url):
            self.openLinkContextMenu(url: url, params: params)
        case let .mention(mention):
            self.openMentionContextMenu(username: mention, peerId: nil, params: params)
        case let .peerMention(peerId, mention):
            self.openMentionContextMenu(username: mention, peerId: peerId, params: params)
        case let .command(command):
            self.openCommandContextMenu(command: command, params: params)
        case let .hashtag(hashtag):
            self.openHashtagContextMenu(hashtag: hashtag, params: params)
        case let .timecode(value, timecode):
            self.openTimecodeContextMenu(timecode: timecode, value: value, params: params)
        case let .bankCard(number):
            self.openBankCardContextMenu(number: number, params: params)
        case let .phone(number):
            self.openPhoneContextMenu(number: number, params: params)
        }
    }
}
