import Foundation
import TelegramCore
import ChatPresentationInterfaceState

/// Whether the composer shows the bot's Start button in place of its input: in a bot chat with no messages yet (outside
/// a thread) and in a blocked bot's chat, never among scheduled messages. The input it replaces is hidden while it
/// shows, so the chat shows no input node then either (`inputNodeForChatPresentationIntefaceState`): a bot's reply
/// keyboard would otherwise stay up below Start when the bot is blocked.
public func chatDisplaysBotStartButton(isBot: Bool, isScheduledMessages: Bool, historyIsEmpty: Bool, isThread: Bool, peerIsBlocked: Bool) -> Bool {
    if isScheduledMessages || !isBot {
        return false
    }
    if historyIsEmpty && !isThread {
        return true
    }
    return peerIsBlocked
}

public func chatDisplaysBotStartButton(_ interfaceState: ChatPresentationInterfaceState) -> Bool {
    var isScheduledMessages = false
    if case .scheduledMessages = interfaceState.subject {
        isScheduledMessages = true
    }
    var isBot = false
    if let user = interfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
        isBot = true
    }
    var historyIsEmpty = false
    if let chatHistoryState = interfaceState.chatHistoryState, case .loaded(true, _) = chatHistoryState {
        historyIsEmpty = true
    }
    return chatDisplaysBotStartButton(isBot: isBot, isScheduledMessages: isScheduledMessages, historyIsEmpty: historyIsEmpty, isThread: interfaceState.chatLocation.threadId != nil, peerIsBlocked: interfaceState.peerIsBlocked)
}
