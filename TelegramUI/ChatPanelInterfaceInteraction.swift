import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

final class ChatPanelInterfaceInteractionStatuses {
    let editingMessage: Signal<Bool, NoError>
    let startingBot: Signal<Bool, NoError>
    
    init(editingMessage: Signal<Bool, NoError>, startingBot: Signal<Bool, NoError>) {
        self.editingMessage = editingMessage
        self.startingBot = startingBot
    }
}

final class ChatPanelInterfaceInteraction {
    let setupReplyMessage: (MessageId) -> Void
    let setupEditMessage: (MessageId) -> Void
    let beginMessageSelection: (MessageId) -> Void
    let deleteSelectedMessages: () -> Void
    let forwardSelectedMessages: () -> Void
    let updateTextInputState: (@escaping (ChatTextInputState) -> ChatTextInputState) -> Void
    let updateInputModeAndDismissedButtonKeyboardMessageId: ((ChatPresentationInterfaceState) -> (ChatInputMode, MessageId?)) -> Void
    let editMessage: (MessageId, String) -> Void
    let beginMessageSearch: () -> Void
    let openPeerInfo: () -> Void
    let togglePeerNotifications: () -> Void
    let sendContextResult: (ChatContextResultCollection, ChatContextResult) -> Void
    let sendBotCommand: (Peer, String) -> Void
    let sendBotStart: (String?) -> Void
    let botSwitchChatWithPayload: (PeerId, String) -> Void
    let beginAudioRecording: () -> Void
    let finishAudioRecording: (Bool) -> Void
    let setupMessageAutoremoveTimeout: () -> Void
    let statuses: ChatPanelInterfaceInteractionStatuses?
    
    init(setupReplyMessage: @escaping (MessageId) -> Void, setupEditMessage: @escaping (MessageId) -> Void, beginMessageSelection: @escaping (MessageId) -> Void, deleteSelectedMessages: @escaping () -> Void, forwardSelectedMessages: @escaping () -> Void, updateTextInputState: @escaping ((ChatTextInputState) -> ChatTextInputState) -> Void, updateInputModeAndDismissedButtonKeyboardMessageId: @escaping ((ChatPresentationInterfaceState) -> (ChatInputMode, MessageId?)) -> Void, editMessage: @escaping (MessageId, String) -> Void, beginMessageSearch: @escaping () -> Void, openPeerInfo: @escaping () -> Void, togglePeerNotifications: @escaping () -> Void, sendContextResult: @escaping (ChatContextResultCollection, ChatContextResult) -> Void, sendBotCommand: @escaping (Peer, String) -> Void, sendBotStart: @escaping (String?) -> Void, botSwitchChatWithPayload: @escaping (PeerId, String) -> Void, beginAudioRecording: @escaping () -> Void, finishAudioRecording: @escaping (Bool) -> Void, setupMessageAutoremoveTimeout: @escaping () -> Void, statuses: ChatPanelInterfaceInteractionStatuses?) {
        self.setupReplyMessage = setupReplyMessage
        self.setupEditMessage = setupEditMessage
        self.beginMessageSelection = beginMessageSelection
        self.deleteSelectedMessages = deleteSelectedMessages
        self.forwardSelectedMessages = forwardSelectedMessages
        self.updateTextInputState = updateTextInputState
        self.updateInputModeAndDismissedButtonKeyboardMessageId = updateInputModeAndDismissedButtonKeyboardMessageId
        self.editMessage = editMessage
        self.beginMessageSearch = beginMessageSearch
        self.openPeerInfo = openPeerInfo
        self.togglePeerNotifications = togglePeerNotifications
        self.sendContextResult = sendContextResult
        self.sendBotCommand = sendBotCommand
        self.sendBotStart = sendBotStart
        self.botSwitchChatWithPayload = botSwitchChatWithPayload
        self.beginAudioRecording = beginAudioRecording
        self.finishAudioRecording = finishAudioRecording
        self.setupMessageAutoremoveTimeout = setupMessageAutoremoveTimeout
        self.statuses = statuses
    }
}
