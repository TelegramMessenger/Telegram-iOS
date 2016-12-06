import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

final class ChatPanelInterfaceInteractionStatuses {
    let editingMessage: Signal<Bool, NoError>
    
    init(editingMessage: Signal<Bool, NoError>) {
        self.editingMessage = editingMessage
    }
}

final class ChatPanelInterfaceInteraction {
    let setupReplyMessage: (MessageId) -> Void
    let setupEditMessage: (MessageId) -> Void
    let beginMessageSelection: (MessageId) -> Void
    let deleteSelectedMessages: () -> Void
    let forwardSelectedMessages: () -> Void
    let updateTextInputState: (@escaping (ChatTextInputState) -> ChatTextInputState) -> Void
    let updateInputMode: ((ChatInputMode) -> ChatInputMode) -> Void
    let editMessage: (MessageId, String) -> Void
    let beginMessageSearch: () -> Void
    let openPeerInfo: () -> Void
    let togglePeerNotifications: () -> Void
    let sendContextResult: (ChatContextResultCollection, ChatContextResult) -> Void
    let sendBotCommand: (Peer, String) -> Void
    let beginAudioRecording: () -> Void
    let finishAudioRecording: (Bool) -> Void
    let statuses: ChatPanelInterfaceInteractionStatuses?
    
    init(setupReplyMessage: @escaping (MessageId) -> Void, setupEditMessage: @escaping (MessageId) -> Void, beginMessageSelection: @escaping (MessageId) -> Void, deleteSelectedMessages: @escaping () -> Void, forwardSelectedMessages: @escaping () -> Void, updateTextInputState: @escaping ((ChatTextInputState) -> ChatTextInputState) -> Void, updateInputMode: @escaping ((ChatInputMode) -> ChatInputMode) -> Void, editMessage: @escaping (MessageId, String) -> Void, beginMessageSearch: @escaping () -> Void, openPeerInfo: @escaping () -> Void, togglePeerNotifications: @escaping () -> Void, sendContextResult: @escaping (ChatContextResultCollection, ChatContextResult) -> Void, sendBotCommand: @escaping (Peer, String) -> Void, beginAudioRecording: @escaping () -> Void, finishAudioRecording: @escaping (Bool) -> Void, statuses: ChatPanelInterfaceInteractionStatuses?) {
        self.setupReplyMessage = setupReplyMessage
        self.setupEditMessage = setupEditMessage
        self.beginMessageSelection = beginMessageSelection
        self.deleteSelectedMessages = deleteSelectedMessages
        self.forwardSelectedMessages = forwardSelectedMessages
        self.updateTextInputState = updateTextInputState
        self.updateInputMode = updateInputMode
        self.editMessage = editMessage
        self.beginMessageSearch = beginMessageSearch
        self.openPeerInfo = openPeerInfo
        self.togglePeerNotifications = togglePeerNotifications
        self.sendContextResult = sendContextResult
        self.sendBotCommand = sendBotCommand
        self.beginAudioRecording = beginAudioRecording
        self.finishAudioRecording = finishAudioRecording
        self.statuses = statuses
    }
}
