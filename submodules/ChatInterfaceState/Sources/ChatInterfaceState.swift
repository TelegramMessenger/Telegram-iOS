import Foundation
import UIKit
import TelegramCore
import TextFormat
import AccountContext
import SwiftSignalKit

public enum ChatTextInputMediaRecordingButtonMode: Int32 {
    case audio = 0
    case video = 1
}

public struct ChatInterfaceSelectionState: Codable, Equatable {
    public let selectedIds: Set<EngineMessage.Id>
    
    public static func ==(lhs: ChatInterfaceSelectionState, rhs: ChatInterfaceSelectionState) -> Bool {
        return lhs.selectedIds == rhs.selectedIds
    }
    
    public init(selectedIds: Set<EngineMessage.Id>) {
        self.selectedIds = selectedIds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let data = try? container.decodeIfPresent(Data.self, forKey: "i") {
            self.selectedIds = Set(EngineMessage.Id.decodeArrayFromData(data))
        } else {
            self.selectedIds = Set()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        let data = EngineMessage.Id.encodeArrayToData(Array(selectedIds))

        try container.encode(data, forKey: "i")
    }
}

public struct ChatEditMessageState: Codable, Equatable {
    public let messageId: EngineMessage.Id
    public let inputState: ChatTextInputState
    public let disableUrlPreview: String?
    public let inputTextMaxLength: Int32?
    
    public init(messageId: EngineMessage.Id, inputState: ChatTextInputState, disableUrlPreview: String?, inputTextMaxLength: Int32?) {
        self.messageId = messageId
        self.inputState = inputState
        self.disableUrlPreview = disableUrlPreview
        self.inputTextMaxLength = inputTextMaxLength
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.messageId = EngineMessage.Id(
            peerId: EnginePeer.Id((try? container.decode(Int64.self, forKey: "mp")) ?? 0),
            namespace: (try? container.decode(Int32.self, forKey: "mn")) ?? 0,
            id: (try? container.decode(Int32.self, forKey: "mi")) ?? 0
        )

        if let inputState = try? container.decode(ChatTextInputState.self, forKey: "is") {
            self.inputState = inputState
        } else {
            self.inputState = ChatTextInputState()
        }

        self.disableUrlPreview = try? container.decodeIfPresent(String.self, forKey: "dup")
        self.inputTextMaxLength = try? container.decodeIfPresent(Int32.self, forKey: "tl")
    }


    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.messageId.peerId.toInt64(), forKey: "mp")
        try container.encode(self.messageId.namespace, forKey: "mn")
        try container.encode(self.messageId.id, forKey: "mi")

        try container.encode(self.inputState, forKey: "is")

        try container.encodeIfPresent(self.disableUrlPreview, forKey: "dup")
        try container.encodeIfPresent(self.inputTextMaxLength, forKey: "tl")
    }
    
    public static func ==(lhs: ChatEditMessageState, rhs: ChatEditMessageState) -> Bool {
        return lhs.messageId == rhs.messageId && lhs.inputState == rhs.inputState && lhs.disableUrlPreview == rhs.disableUrlPreview && lhs.inputTextMaxLength == rhs.inputTextMaxLength
    }
    
    public func withUpdatedInputState(_ inputState: ChatTextInputState) -> ChatEditMessageState {
        return ChatEditMessageState(messageId: self.messageId, inputState: inputState, disableUrlPreview: self.disableUrlPreview, inputTextMaxLength: self.inputTextMaxLength)
    }
    
    public func withUpdatedDisableUrlPreview(_ disableUrlPreview: String?) -> ChatEditMessageState {
        return ChatEditMessageState(messageId: self.messageId, inputState: self.inputState, disableUrlPreview: disableUrlPreview, inputTextMaxLength: self.inputTextMaxLength)
    }
}

public struct ChatInterfaceMessageActionsState: Codable, Equatable {
    public var closedButtonKeyboardMessageId: EngineMessage.Id?
    public var dismissedButtonKeyboardMessageId: EngineMessage.Id?
    public var processedSetupReplyMessageId: EngineMessage.Id?
    public var closedPinnedMessageId: EngineMessage.Id?
    public var closedPeerSpecificPackSetup: Bool = false
    public var dismissedAddContactPhoneNumber: String?
    
    public var isEmpty: Bool {
        return self.closedButtonKeyboardMessageId == nil && self.dismissedButtonKeyboardMessageId == nil && self.processedSetupReplyMessageId == nil && self.closedPinnedMessageId == nil && self.closedPeerSpecificPackSetup == false && self.dismissedAddContactPhoneNumber == nil
    }
    
    public init() {
        self.closedButtonKeyboardMessageId = nil
        self.dismissedButtonKeyboardMessageId = nil
        self.processedSetupReplyMessageId = nil
        self.closedPinnedMessageId = nil
        self.closedPeerSpecificPackSetup = false
        self.dismissedAddContactPhoneNumber = nil
    }
    
    public init(closedButtonKeyboardMessageId: EngineMessage.Id?, dismissedButtonKeyboardMessageId: EngineMessage.Id?, processedSetupReplyMessageId: EngineMessage.Id?, closedPinnedMessageId: EngineMessage.Id?, closedPeerSpecificPackSetup: Bool, dismissedAddContactPhoneNumber: String?) {
        self.closedButtonKeyboardMessageId = closedButtonKeyboardMessageId
        self.dismissedButtonKeyboardMessageId = dismissedButtonKeyboardMessageId
        self.processedSetupReplyMessageId = processedSetupReplyMessageId
        self.closedPinnedMessageId = closedPinnedMessageId
        self.closedPeerSpecificPackSetup = closedPeerSpecificPackSetup
        self.dismissedAddContactPhoneNumber = dismissedAddContactPhoneNumber
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let closedMessageIdPeerId = try? container.decodeIfPresent(Int64.self, forKey: "cb.p"), let closedMessageIdNamespace = try? container.decodeIfPresent(Int32.self, forKey: "cb.n"), let closedMessageIdId = try? container.decodeIfPresent(Int32.self, forKey: "cb.i") {
            self.closedButtonKeyboardMessageId = EngineMessage.Id(peerId: EnginePeer.Id(closedMessageIdPeerId), namespace: closedMessageIdNamespace, id: closedMessageIdId)
        } else {
            self.closedButtonKeyboardMessageId = nil
        }

        if let messageIdPeerId = try? container.decodeIfPresent(Int64.self, forKey: "dismissedbuttons.p"), let messageIdNamespace = try? container.decodeIfPresent(Int32.self, forKey: "dismissedbuttons.n"), let messageIdId = try? container.decodeIfPresent(Int32.self, forKey: "dismissedbuttons.i") {
            self.dismissedButtonKeyboardMessageId = EngineMessage.Id(peerId: EnginePeer.Id(messageIdPeerId), namespace: messageIdNamespace, id: messageIdId)
        } else {
            self.dismissedButtonKeyboardMessageId = nil
        }
        
        if let processedMessageIdPeerId = try? container.decodeIfPresent(Int64.self, forKey: "pb.p"), let processedMessageIdNamespace = try? container.decodeIfPresent(Int32.self, forKey: "pb.n"), let processedMessageIdId = try? container.decodeIfPresent(Int32.self, forKey: "pb.i") {
            self.processedSetupReplyMessageId = EngineMessage.Id(peerId: EnginePeer.Id(processedMessageIdPeerId), namespace: processedMessageIdNamespace, id: processedMessageIdId)
        } else {
            self.processedSetupReplyMessageId = nil
        }
        
        if let closedPinnedMessageIdPeerId = try? container.decodeIfPresent(Int64.self, forKey: "cp.p"), let closedPinnedMessageIdNamespace = try? container.decodeIfPresent(Int32.self, forKey: "cp.n"), let closedPinnedMessageIdId = try? container.decodeIfPresent(Int32.self, forKey: "cp.i") {
            self.closedPinnedMessageId = EngineMessage.Id(peerId: EnginePeer.Id(closedPinnedMessageIdPeerId), namespace: closedPinnedMessageIdNamespace, id: closedPinnedMessageIdId)
        } else {
            self.closedPinnedMessageId = nil
        }
        
        self.closedPeerSpecificPackSetup = ((try? container.decode(Int32.self, forKey: "cpss")) ?? 0) != 0

        self.dismissedAddContactPhoneNumber = try? container.decodeIfPresent(String.self, forKey: "dismissedAddContactPhoneNumber")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        if let closedButtonKeyboardMessageId = self.closedButtonKeyboardMessageId {
            try container.encode(closedButtonKeyboardMessageId.peerId.toInt64(), forKey: "cb.p")
            try container.encode(closedButtonKeyboardMessageId.namespace, forKey: "cb.n")
            try container.encode(closedButtonKeyboardMessageId.id, forKey: "cb.i")
        } else {
            try container.encodeNil(forKey: "cb.p")
            try container.encodeNil(forKey: "cb.n")
            try container.encodeNil(forKey: "cb.i")
        }

        if let dismissedButtonKeyboardMessageId = self.dismissedButtonKeyboardMessageId {
            try container.encode(dismissedButtonKeyboardMessageId.peerId.toInt64(), forKey: "dismissedbuttons.p")
            try container.encode(dismissedButtonKeyboardMessageId.namespace, forKey: "dismissedbuttons.n")
            try container.encode(dismissedButtonKeyboardMessageId.id, forKey: "dismissedbuttons.i")
        } else {
            try container.encodeNil(forKey: "dismissedbuttons.p")
            try container.encodeNil(forKey: "dismissedbuttons.n")
            try container.encodeNil(forKey: "dismissedbuttons.i")
        }
        
        if let processedSetupReplyMessageId = self.processedSetupReplyMessageId {
            try container.encode(processedSetupReplyMessageId.peerId.toInt64(), forKey: "pb.p")
            try container.encode(processedSetupReplyMessageId.namespace, forKey: "pb.n")
            try container.encode(processedSetupReplyMessageId.id, forKey: "pb.i")
        } else {
            try container.encodeNil(forKey: "pb.p")
            try container.encodeNil(forKey: "pb.n")
            try container.encodeNil(forKey: "pb.i")
        }
        
        if let closedPinnedMessageId = self.closedPinnedMessageId {
            try container.encode(closedPinnedMessageId.peerId.toInt64(), forKey: "cp.p")
            try container.encode(closedPinnedMessageId.namespace, forKey: "cp.n")
            try container.encode(closedPinnedMessageId.id, forKey: "cp.i")
        } else {
            try container.encodeNil(forKey: "cp.p")
            try container.encodeNil(forKey: "cp.n")
            try container.encodeNil(forKey: "cp.i")
        }
        
        try container.encode((self.closedPeerSpecificPackSetup ? 1 : 0) as Int32, forKey: "cpss")
        
        if let dismissedAddContactPhoneNumber = self.dismissedAddContactPhoneNumber {
            try container.encode(dismissedAddContactPhoneNumber, forKey: "dismissedAddContactPhoneNumber")
        } else {
            try container.encodeNil(forKey: "dismissedAddContactPhoneNumber")
        }
    }
}

public struct ChatInterfaceHistoryScrollState: Codable, Equatable {
    public let messageIndex: EngineMessage.Index
    public let relativeOffset: Double
    
    public init(messageIndex: EngineMessage.Index, relativeOffset: Double) {
        self.messageIndex = messageIndex
        self.relativeOffset = relativeOffset
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.messageIndex = EngineMessage.Index(
            id: EngineMessage.Id(
                peerId: EnginePeer.Id((try? container.decode(Int64.self, forKey: "m.p")) ?? 0),
                namespace: (try? container.decode(Int32.self, forKey: "m.n")) ?? 0,
                id: (try? container.decode(Int32.self, forKey: "m.i")) ?? 0
            ),
            timestamp: (try? container.decode(Int32.self, forKey: "m.t")) ?? 0
        )
        self.relativeOffset = (try? container.decode(Double.self, forKey: "ro")) ?? 0.0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.messageIndex.timestamp, forKey: "m.t")
        try container.encode(self.messageIndex.id.peerId.toInt64(), forKey: "m.p")
        try container.encode(self.messageIndex.id.namespace, forKey: "m.n")
        try container.encode(self.messageIndex.id.id, forKey: "m.i")
        try container.encode(self.relativeOffset, forKey: "ro")
    }
    
    public static func ==(lhs: ChatInterfaceHistoryScrollState, rhs: ChatInterfaceHistoryScrollState) -> Bool {
        if lhs.messageIndex != rhs.messageIndex {
            return false
        }
        if !lhs.relativeOffset.isEqual(to: rhs.relativeOffset) {
            return false
        }
        return true
    }
}

public final class ChatInterfaceState: Codable, Equatable {
    public let timestamp: Int32
    public let composeInputState: ChatTextInputState
    public let composeDisableUrlPreview: String?
    public let replyMessageId: EngineMessage.Id?
    public let forwardMessageIds: [EngineMessage.Id]?
    public let forwardOptionsState: ChatInterfaceForwardOptionsState?
    public let editMessage: ChatEditMessageState?
    public let selectionState: ChatInterfaceSelectionState?
    public let messageActionsState: ChatInterfaceMessageActionsState
    public let historyScrollState: ChatInterfaceHistoryScrollState?
    public let mediaRecordingMode: ChatTextInputMediaRecordingButtonMode
    public let silentPosting: Bool
    public let inputLanguage: String?
    
    public var synchronizeableInputState: SynchronizeableChatInputState? {
        if self.composeInputState.inputText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && self.replyMessageId == nil {
            return nil
        } else {
            return SynchronizeableChatInputState(replyToMessageId: self.replyMessageId, text: self.composeInputState.inputText.string, entities: generateChatInputTextEntities(self.composeInputState.inputText), timestamp: self.timestamp, textSelection: self.composeInputState.selectionRange)
        }
    }

    public func withUpdatedSynchronizeableInputState(_ state: SynchronizeableChatInputState?) -> ChatInterfaceState {
        var result = self.withUpdatedComposeInputState(ChatTextInputState(inputText: chatInputStateStringWithAppliedEntities(state?.text ?? "", entities: state?.entities ?? []))).withUpdatedReplyMessageId(state?.replyToMessageId)
        if let timestamp = state?.timestamp {
            result = result.withUpdatedTimestamp(timestamp)
        }
        return result
    }
    
    public var historyScrollMessageIndex: EngineMessage.Index? {
        return self.historyScrollState?.messageIndex
    }
    
    public var effectiveInputState: ChatTextInputState {
        if let editMessage = self.editMessage {
            return editMessage.inputState
        } else {
            return self.composeInputState
        }
    }
    
    public init() {
        self.timestamp = 0
        self.composeInputState = ChatTextInputState()
        self.composeDisableUrlPreview = nil
        self.replyMessageId = nil
        self.forwardMessageIds = nil
        self.forwardOptionsState = nil
        self.editMessage = nil
        self.selectionState = nil
        self.messageActionsState = ChatInterfaceMessageActionsState()
        self.historyScrollState = nil
        self.mediaRecordingMode = .audio
        self.silentPosting = false
        self.inputLanguage = nil
    }
    
    public init(timestamp: Int32, composeInputState: ChatTextInputState, composeDisableUrlPreview: String?, replyMessageId: EngineMessage.Id?, forwardMessageIds: [EngineMessage.Id]?, forwardOptionsState: ChatInterfaceForwardOptionsState?, editMessage: ChatEditMessageState?, selectionState: ChatInterfaceSelectionState?, messageActionsState: ChatInterfaceMessageActionsState, historyScrollState: ChatInterfaceHistoryScrollState?, mediaRecordingMode: ChatTextInputMediaRecordingButtonMode, silentPosting: Bool, inputLanguage: String?) {
        self.timestamp = timestamp
        self.composeInputState = composeInputState
        self.composeDisableUrlPreview = composeDisableUrlPreview
        self.replyMessageId = replyMessageId
        self.forwardMessageIds = forwardMessageIds
        self.forwardOptionsState = forwardOptionsState
        self.editMessage = editMessage
        self.selectionState = selectionState
        self.messageActionsState = messageActionsState
        self.historyScrollState = historyScrollState
        self.mediaRecordingMode = mediaRecordingMode
        self.silentPosting = silentPosting
        self.inputLanguage = inputLanguage
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.timestamp = (try? container.decode(Int32.self, forKey: "ts")) ?? 0
        if let inputState = try? container.decode(ChatTextInputState.self, forKey: "is") {
            self.composeInputState = inputState
        } else {
            self.composeInputState = ChatTextInputState()
        }
        if let composeDisableUrlPreview = try? container.decodeIfPresent(String.self, forKey: "dup") {
            self.composeDisableUrlPreview = composeDisableUrlPreview
        } else {
            self.composeDisableUrlPreview = nil
        }
        let replyMessageIdPeerId: Int64? = try? container.decodeIfPresent(Int64.self, forKey: "r.p")
        let replyMessageIdNamespace: Int32? = try? container.decodeIfPresent(Int32.self, forKey: "r.n")
        let replyMessageIdId: Int32? = try? container.decodeIfPresent(Int32.self, forKey: "r.i")
        if let replyMessageIdPeerId = replyMessageIdPeerId, let replyMessageIdNamespace = replyMessageIdNamespace, let replyMessageIdId = replyMessageIdId {
            self.replyMessageId = EngineMessage.Id(peerId: EnginePeer.Id(replyMessageIdPeerId), namespace: replyMessageIdNamespace, id: replyMessageIdId)
        } else {
            self.replyMessageId = nil
        }
        if let forwardMessageIdsData = try? container.decodeIfPresent(Data.self, forKey: "fm") {
            self.forwardMessageIds = EngineMessage.Id.decodeArrayFromData(forwardMessageIdsData)
        } else {
            self.forwardMessageIds = nil
        }
        if let forwardOptionsState = try? container.decodeIfPresent(ChatInterfaceForwardOptionsState.self, forKey: "fo") {
            self.forwardOptionsState = forwardOptionsState
        } else {
            self.forwardOptionsState = nil
        }
        if let editMessage = try? container.decodeIfPresent(ChatEditMessageState.self, forKey: "em") {
            self.editMessage = editMessage
        } else {
            self.editMessage = nil
        }
        if let selectionState = try? container.decodeIfPresent(ChatInterfaceSelectionState.self, forKey: "ss") {
            self.selectionState = selectionState
        } else {
            self.selectionState = nil
        }

        if let messageActionsState = try? container.decodeIfPresent(ChatInterfaceMessageActionsState.self, forKey: "as") {
            self.messageActionsState = messageActionsState
        } else {
            self.messageActionsState = ChatInterfaceMessageActionsState()
        }

        self.historyScrollState = try? container.decodeIfPresent(ChatInterfaceHistoryScrollState.self, forKey: "hss")
        
        self.mediaRecordingMode = ChatTextInputMediaRecordingButtonMode(rawValue: (try? container.decodeIfPresent(Int32.self, forKey: "mrm")) ?? 0) ?? .audio
        
        self.silentPosting = ((try? container.decode(Int32.self, forKey: "sip")) ?? 0) != 0
        self.inputLanguage = try? container.decodeIfPresent(String.self, forKey: "inputLanguage")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.timestamp, forKey: "ts")
        try container.encode(self.composeInputState, forKey: "is")
        if let composeDisableUrlPreview = self.composeDisableUrlPreview {
            try container.encode(composeDisableUrlPreview, forKey: "dup")
        } else {
            try container.encodeNil(forKey: "dup")
        }
        if let replyMessageId = self.replyMessageId {
            try container.encode(replyMessageId.peerId.toInt64(), forKey: "r.p")
            try container.encode(replyMessageId.namespace, forKey: "r.n")
            try container.encode(replyMessageId.id, forKey: "r.i")
        } else {
            try container.encodeNil(forKey: "r.p")
            try container.encodeNil(forKey: "r.n")
            try container.encodeNil(forKey: "r.i")
        }
        if let forwardMessageIds = self.forwardMessageIds {
            try container.encode(EngineMessage.Id.encodeArrayToData(forwardMessageIds), forKey: "fm")
        } else {
            try container.encodeNil(forKey: "fm")
        }
        if let forwardOptionsState = self.forwardOptionsState {
            try container.encode(forwardOptionsState, forKey: "fo")
        } else {
            try container.encodeNil(forKey: "fo")
        }
        if let editMessage = self.editMessage {
            try container.encode(editMessage, forKey: "em")
        } else {
            try container.encodeNil(forKey: "em")
        }
        if let selectionState = self.selectionState {
            try container.encode(selectionState, forKey: "ss")
        } else {
            try container.encodeNil(forKey: "ss")
        }
        if self.messageActionsState.isEmpty {
            try container.encodeNil(forKey: "as")
        } else {
            try container.encode(self.messageActionsState, forKey: "as")
        }
        if let historyScrollState = self.historyScrollState {
            try container.encode(historyScrollState, forKey: "hss")
        } else {
            try container.encodeNil(forKey: "hss")
        }
        try container.encode(self.mediaRecordingMode.rawValue, forKey: "mrm")
        try container.encode((self.silentPosting ? 1 : 0) as Int32, forKey: "sip")
        if let inputLanguage = self.inputLanguage {
            try container.encode(inputLanguage, forKey: "inputLanguage")
        } else {
            try container.encodeNil(forKey: "inputLanguage")
        }
    }
    
    public static func ==(lhs: ChatInterfaceState, rhs: ChatInterfaceState) -> Bool {
        if lhs.composeDisableUrlPreview != rhs.composeDisableUrlPreview {
            return false
        }
        if let lhsForwardMessageIds = lhs.forwardMessageIds, let rhsForwardMessageIds = rhs.forwardMessageIds {
            if lhsForwardMessageIds != rhsForwardMessageIds {
                return false
            }
        } else if (lhs.forwardMessageIds != nil) != (rhs.forwardMessageIds != nil) {
            return false
        }
        if lhs.forwardOptionsState != rhs.forwardOptionsState {
            return false
        }
        if lhs.messageActionsState != rhs.messageActionsState {
            return false
        }
        if lhs.historyScrollState != rhs.historyScrollState {
            return false
        }
        if lhs.mediaRecordingMode != rhs.mediaRecordingMode {
            return false
        }
        if lhs.silentPosting != rhs.silentPosting {
            return false
        }
        if lhs.inputLanguage != rhs.inputLanguage {
            return false
        }
        return lhs.composeInputState == rhs.composeInputState && lhs.replyMessageId == rhs.replyMessageId && lhs.selectionState == rhs.selectionState && lhs.editMessage == rhs.editMessage
    }
    
    public func withUpdatedComposeInputState(_ inputState: ChatTextInputState) -> ChatInterfaceState {
        let updatedComposeInputState = inputState
        
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: updatedComposeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedComposeDisableUrlPreview(_ disableUrlPreview: String?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: disableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedEffectiveInputState(_ inputState: ChatTextInputState) -> ChatInterfaceState {
        var updatedEditMessage = self.editMessage
        var updatedComposeInputState = self.composeInputState
        if let editMessage = self.editMessage {
            updatedEditMessage = editMessage.withUpdatedInputState(inputState)
        } else {
            updatedComposeInputState = inputState
        }
        
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: updatedComposeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: updatedEditMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedReplyMessageId(_ replyMessageId: EngineMessage.Id?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedForwardMessageIds(_ forwardMessageIds: [EngineMessage.Id]?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedForwardOptionsState(_ forwardOptionsState: ChatInterfaceForwardOptionsState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedSelectedMessages(_ messageIds: [EngineMessage.Id]) -> ChatInterfaceState {
        var selectedIds = Set<EngineMessage.Id>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        for messageId in messageIds {
            selectedIds.insert(messageId)
        }
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withToggledSelectedMessages(_ messageIds: [EngineMessage.Id], value: Bool) -> ChatInterfaceState {
        var selectedIds = Set<EngineMessage.Id>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        for messageId in messageIds {
            if value {
                selectedIds.insert(messageId)
            } else {
                selectedIds.remove(messageId)
            }
        }
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withoutSelectionState() -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: nil, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedTimestamp(_ timestamp: Int32) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedEditMessage(_ editMessage: ChatEditMessageState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedMessageActionsState(_ f: (ChatInterfaceMessageActionsState) -> ChatInterfaceMessageActionsState) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: f(self.messageActionsState), historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedHistoryScrollState(_ historyScrollState: ChatInterfaceHistoryScrollState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedMediaRecordingMode(_ mediaRecordingMode: ChatTextInputMediaRecordingButtonMode) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedSilentPosting(_ silentPosting: Bool) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: silentPosting, inputLanguage: self.inputLanguage)
    }
    
    public func withUpdatedInputLanguage(_ inputLanguage: String?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreview: self.composeDisableUrlPreview, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, silentPosting: self.silentPosting, inputLanguage: inputLanguage)
    }

    public static func parse(_ state: OpaqueChatInterfaceState) -> ChatInterfaceState {
        guard let opaqueData = state.opaqueData else {
            return ChatInterfaceState().withUpdatedSynchronizeableInputState(state.synchronizeableInputState)
        }
        guard var decodedState = try? EngineDecoder.decode(ChatInterfaceState.self, from: opaqueData) else {
            return ChatInterfaceState().withUpdatedSynchronizeableInputState(state.synchronizeableInputState)
        }
        decodedState = decodedState.withUpdatedSynchronizeableInputState(state.synchronizeableInputState)
        return decodedState
    }

    public static func update(engine: TelegramEngine, peerId: EnginePeer.Id, threadId: Int64?, _ f: @escaping (ChatInterfaceState) -> ChatInterfaceState) -> Signal<Never, NoError> {
        return engine.peers.getOpaqueChatInterfaceState(peerId: peerId, threadId: threadId)
        |> mapToSignal { previousOpaqueState -> Signal<Never, NoError> in
            let previousState = previousOpaqueState.flatMap(ChatInterfaceState.parse)
            let updatedState = f(previousState ?? ChatInterfaceState())

            let updatedOpaqueData = try? EngineEncoder.encode(updatedState)

            return engine.peers.setOpaqueChatInterfaceState(
                peerId: peerId,
                threadId: threadId,
                state: OpaqueChatInterfaceState(
                    opaqueData: updatedOpaqueData,
                    historyScrollMessageIndex: updatedState.historyScrollMessageIndex,
                    synchronizeableInputState: updatedState.synchronizeableInputState
                ))
        }
    }
}
