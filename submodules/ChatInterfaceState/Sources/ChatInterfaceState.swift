import Foundation
import UIKit
import Postbox
import TelegramCore
import TextFormat
import AccountContext
import SwiftSignalKit
import AudioWaveform

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
    public var messageId: EngineMessage.Id
    public var inputState: ChatTextInputState
    public var disableUrlPreviews: [String]
    public var inputTextMaxLength: Int32?
    public var mediaCaptionIsAbove: Bool?
    
    public init(messageId: EngineMessage.Id, inputState: ChatTextInputState, disableUrlPreviews: [String], inputTextMaxLength: Int32?, mediaCaptionIsAbove: Bool?) {
        self.messageId = messageId
        self.inputState = inputState
        self.disableUrlPreviews = disableUrlPreviews
        self.inputTextMaxLength = inputTextMaxLength
        self.mediaCaptionIsAbove = mediaCaptionIsAbove
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

        if let disableUrlPreviews = try? container.decodeIfPresent([String].self, forKey: "dupl") {
            self.disableUrlPreviews = disableUrlPreviews
        } else {
            if let disableUrlPreview = try? container.decodeIfPresent(String.self, forKey: "dup") {
                self.disableUrlPreviews = [disableUrlPreview]
            } else {
                self.disableUrlPreviews = []
            }
        }
        self.inputTextMaxLength = try? container.decodeIfPresent(Int32.self, forKey: "tl")
        
        self.mediaCaptionIsAbove = try? container.decodeIfPresent(Bool.self, forKey: "mediaCaptionIsAbove")
    }


    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.messageId.peerId.toInt64(), forKey: "mp")
        try container.encode(self.messageId.namespace, forKey: "mn")
        try container.encode(self.messageId.id, forKey: "mi")

        try container.encode(self.inputState, forKey: "is")

        try container.encode(self.disableUrlPreviews, forKey: "dupl")
        try container.encodeIfPresent(self.inputTextMaxLength, forKey: "tl")
        
        try container.encodeIfPresent(self.mediaCaptionIsAbove, forKey: "mediaCaptionIsAbove")
    }
    
    public static func ==(lhs: ChatEditMessageState, rhs: ChatEditMessageState) -> Bool {
        return lhs.messageId == rhs.messageId && lhs.inputState == rhs.inputState && lhs.disableUrlPreviews == rhs.disableUrlPreviews && lhs.inputTextMaxLength == rhs.inputTextMaxLength && lhs.mediaCaptionIsAbove == rhs.mediaCaptionIsAbove
    }
    
    public func withUpdatedInputState(_ inputState: ChatTextInputState) -> ChatEditMessageState {
        return ChatEditMessageState(messageId: self.messageId, inputState: inputState, disableUrlPreviews: self.disableUrlPreviews, inputTextMaxLength: self.inputTextMaxLength, mediaCaptionIsAbove: self.mediaCaptionIsAbove)
    }
    
    public func withUpdatedDisableUrlPreviews(_ disableUrlPreviews: [String]) -> ChatEditMessageState {
        return ChatEditMessageState(messageId: self.messageId, inputState: self.inputState, disableUrlPreviews: disableUrlPreviews, inputTextMaxLength: self.inputTextMaxLength, mediaCaptionIsAbove: self.mediaCaptionIsAbove)
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

public enum ChatInterfaceMediaDraftState: Codable, Equatable {
    enum DecodingError: Error {
        case generic
    }
    
    public struct Audio: Codable, Equatable {
        public let resource: LocalFileMediaResource
        public let fileSize: Int32
        public let duration: Double
        public let waveform: AudioWaveform
        public let trimRange: Range<Double>?
        public let resumeData: Data?
        
        public init(
            resource: LocalFileMediaResource,
            fileSize: Int32,
            duration: Double,
            waveform: AudioWaveform,
            trimRange: Range<Double>?,
            resumeData: Data?
        ) {
            self.resource = resource
            self.fileSize = fileSize
            self.duration = duration
            self.waveform = waveform
            self.trimRange = trimRange
            self.resumeData = resumeData
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)

            let resourceData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: "r")
            self.resource = LocalFileMediaResource(decoder: PostboxDecoder(buffer: MemoryBuffer(data: resourceData.data)))
            
            self.fileSize = try container.decode(Int32.self, forKey: "s")
            
            if let doubleValue = try container.decodeIfPresent(Double.self, forKey: "dd") {
                self.duration = doubleValue
            } else {
                self.duration = Double(try container.decode(Int32.self, forKey: "d"))
            }
            
            let waveformData = try container.decode(Data.self, forKey: "wd")
            let waveformPeak = try container.decode(Int32.self, forKey: "wp")
            self.waveform = AudioWaveform(samples: waveformData, peak: waveformPeak)
            
            if let trimLowerBound = try container.decodeIfPresent(Double.self, forKey: "tl"), let trimUpperBound = try container.decodeIfPresent(Double.self, forKey: "tu") {
                self.trimRange = trimLowerBound ..< trimUpperBound
            } else {
                self.trimRange = nil
            }
            
            self.resumeData = try container.decode(Data.self, forKey: "rd")
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)

            try container.encode(PostboxEncoder().encodeObjectToRawData(self.resource), forKey: "r")
            try container.encode(self.fileSize, forKey: "s")
            try container.encode(self.duration, forKey: "dd")
            try container.encode(self.waveform.samples, forKey: "wd")
            try container.encode(self.waveform.peak, forKey: "wp")
            
            if let trimRange = self.trimRange {
                try container.encode(trimRange.lowerBound, forKey: "tl")
                try container.encode(trimRange.upperBound, forKey: "tu")
            }
            
            if let resumeData = self.resumeData {
                try container.encode(resumeData, forKey: "rd")
            }
        }
        
        public static func ==(lhs: Audio, rhs: Audio) -> Bool {
            if !lhs.resource.isEqual(to: rhs.resource) {
                return false
            }
            if lhs.duration != rhs.duration {
                return false
            }
            if lhs.fileSize != rhs.fileSize {
                return false
            }
            if lhs.waveform != rhs.waveform {
                return false
            }
            if lhs.trimRange != rhs.trimRange {
                return false
            }
            if lhs.resumeData != rhs.resumeData {
                return false
            }
            return true
        }
    }
    
    public struct Video: Codable, Equatable {
        public let duration: Double
        public let frames: [UIImage]
        public let framesUpdateTimestamp: Double
        public let trimRange: Range<Double>?
        
        public init(
            duration: Double,
            frames: [UIImage],
            framesUpdateTimestamp: Double,
            trimRange: Range<Double>?
        ) {
            self.duration = duration
            self.frames = frames
            self.framesUpdateTimestamp = framesUpdateTimestamp
            self.trimRange = trimRange
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)
            
            if let doubleValue = try container.decodeIfPresent(Double.self, forKey: "dd") {
                self.duration = doubleValue
            } else {
                self.duration = Double(try container.decode(Int32.self, forKey: "d"))
            }
            self.frames = []
            self.framesUpdateTimestamp = try container.decode(Double.self, forKey: "fu")
            if let trimLowerBound = try container.decodeIfPresent(Double.self, forKey: "tl"), let trimUpperBound = try container.decodeIfPresent(Double.self, forKey: "tu") {
                self.trimRange = trimLowerBound ..< trimUpperBound
            } else {
                self.trimRange = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)

            try container.encode(self.duration, forKey: "dd")
            try container.encode(self.framesUpdateTimestamp, forKey: "fu")
            if let trimRange = self.trimRange {
                try container.encode(trimRange.lowerBound, forKey: "tl")
                try container.encode(trimRange.upperBound, forKey: "tu")
            }
        }
        
        public static func ==(lhs: Video, rhs: Video) -> Bool {
            if lhs.duration != rhs.duration {
                return false
            }
            if lhs.framesUpdateTimestamp != rhs.framesUpdateTimestamp {
                return false
            }
            if lhs.trimRange != rhs.trimRange {
                return false
            }
            return true
        }
    }
    
    case audio(Audio)
    case video(Video)
    
    enum MediaType: Int32 {
        case audio
        case video
    }
    
    public var contentType: EngineChatList.MediaDraftContentType {
        switch self {
        case .audio:
            return .audio
        case .video:
            return .video
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        guard let mediaType = MediaType(rawValue: try container.decode(Int32.self, forKey: "t")) else {
            throw DecodingError.generic
        }
        switch mediaType {
        case .audio:
            self = .audio(try container.decode(Audio.self, forKey: "a"))
        case .video:
            self = .video(try container.decode(Video.self, forKey: "v"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self {
        case let .audio(audio):
            try container.encode(MediaType.audio.rawValue, forKey: "t")
            try container.encode(audio, forKey: "a")
        case let .video(video):
            try container.encode(MediaType.video.rawValue, forKey: "t")
            try container.encode(video, forKey: "v")
        }
    }
}

public final class ChatInterfaceState: Codable, Equatable {
    public struct ReplyMessageSubject: Codable, Equatable {
        public var messageId: EngineMessage.Id
        public var quote: EngineMessageReplyQuote?
        
        public init(messageId: EngineMessage.Id, quote: EngineMessageReplyQuote?) {
            self.messageId = messageId
            self.quote = quote
        }
        
        public var subjectModel: EngineMessageReplySubject {
            return EngineMessageReplySubject(
                messageId: self.messageId,
                quote: self.quote
            )
        }
    }
    
    public let timestamp: Int32
    public let composeInputState: ChatTextInputState
    public let composeDisableUrlPreviews: [String]
    public let replyMessageSubject: ReplyMessageSubject?
    public let forwardMessageIds: [EngineMessage.Id]?
    public let forwardOptionsState: ChatInterfaceForwardOptionsState?
    public let editMessage: ChatEditMessageState?
    public let selectionState: ChatInterfaceSelectionState?
    public let messageActionsState: ChatInterfaceMessageActionsState
    public let historyScrollState: ChatInterfaceHistoryScrollState?
    public let mediaRecordingMode: ChatTextInputMediaRecordingButtonMode
    public let mediaDraftState: ChatInterfaceMediaDraftState?
    public let silentPosting: Bool
    public let inputLanguage: String?
    public let sendMessageEffect: Int64?
    
    public var synchronizeableInputState: SynchronizeableChatInputState? {
        if self.composeInputState.inputText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && self.replyMessageSubject == nil {
            return nil
        } else {
            let sourceText = expandedInputStateAttributedString(self.composeInputState.inputText)
            return SynchronizeableChatInputState(replySubject: self.replyMessageSubject?.subjectModel, text: sourceText.string, entities: generateChatInputTextEntities(sourceText), timestamp: self.timestamp, textSelection: self.composeInputState.selectionRange, messageEffectId: self.sendMessageEffect)
        }
    }

    public func withUpdatedSynchronizeableInputState(_ state: SynchronizeableChatInputState?) -> ChatInterfaceState {
        var result = self.withUpdatedComposeInputState(ChatTextInputState(inputText: chatInputStateStringWithAppliedEntities(state?.text ?? "", entities: state?.entities ?? []))).withUpdatedReplyMessageSubject((state?.replySubject).flatMap {
            return ReplyMessageSubject(
                messageId: $0.messageId,
                quote: $0.quote
            )
        })
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
        self.composeDisableUrlPreviews = []
        self.replyMessageSubject = nil
        self.forwardMessageIds = nil
        self.forwardOptionsState = nil
        self.editMessage = nil
        self.selectionState = nil
        self.messageActionsState = ChatInterfaceMessageActionsState()
        self.historyScrollState = nil
        self.mediaRecordingMode = .audio
        self.mediaDraftState = nil
        self.silentPosting = false
        self.inputLanguage = nil
        self.sendMessageEffect = nil
    }
    
    public init(timestamp: Int32, composeInputState: ChatTextInputState, composeDisableUrlPreviews: [String], replyMessageSubject: ReplyMessageSubject?, forwardMessageIds: [EngineMessage.Id]?, forwardOptionsState: ChatInterfaceForwardOptionsState?, editMessage: ChatEditMessageState?, selectionState: ChatInterfaceSelectionState?, messageActionsState: ChatInterfaceMessageActionsState, historyScrollState: ChatInterfaceHistoryScrollState?, mediaRecordingMode: ChatTextInputMediaRecordingButtonMode, mediaDraftState: ChatInterfaceMediaDraftState?, silentPosting: Bool, inputLanguage: String?, sendMessageEffect: Int64?) {
        self.timestamp = timestamp
        self.composeInputState = composeInputState
        self.composeDisableUrlPreviews = composeDisableUrlPreviews
        self.replyMessageSubject = replyMessageSubject
        self.forwardMessageIds = forwardMessageIds
        self.forwardOptionsState = forwardOptionsState
        self.editMessage = editMessage
        self.selectionState = selectionState
        self.messageActionsState = messageActionsState
        self.historyScrollState = historyScrollState
        self.mediaRecordingMode = mediaRecordingMode
        self.mediaDraftState = mediaDraftState
        self.silentPosting = silentPosting
        self.inputLanguage = inputLanguage
        self.sendMessageEffect = sendMessageEffect
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.timestamp = (try? container.decode(Int32.self, forKey: "ts")) ?? 0
        if let inputState = try? container.decode(ChatTextInputState.self, forKey: "is") {
            self.composeInputState = inputState
        } else {
            self.composeInputState = ChatTextInputState()
        }
        
        if let composeDisableUrlPreviews = try? container.decodeIfPresent([String].self, forKey: "dupl") {
            self.composeDisableUrlPreviews = composeDisableUrlPreviews
        } else if let composeDisableUrlPreview = try? container.decodeIfPresent(String.self, forKey: "dup") {
            self.composeDisableUrlPreviews = [composeDisableUrlPreview]
        } else {
            self.composeDisableUrlPreviews = []
        }
        
        if let replyMessageSubject = try? container.decodeIfPresent(ReplyMessageSubject.self, forKey: "replyMessageSubject") {
            self.replyMessageSubject = replyMessageSubject
        } else {
            let replyMessageIdPeerId: Int64? = try? container.decodeIfPresent(Int64.self, forKey: "r.p")
            let replyMessageIdNamespace: Int32? = try? container.decodeIfPresent(Int32.self, forKey: "r.n")
            let replyMessageIdId: Int32? = try? container.decodeIfPresent(Int32.self, forKey: "r.i")
            if let replyMessageIdPeerId = replyMessageIdPeerId, let replyMessageIdNamespace = replyMessageIdNamespace, let replyMessageIdId = replyMessageIdId {
                self.replyMessageSubject = ReplyMessageSubject(messageId: EngineMessage.Id(peerId: EnginePeer.Id(replyMessageIdPeerId), namespace: replyMessageIdNamespace, id: replyMessageIdId), quote: nil)
            } else {
                self.replyMessageSubject = nil
            }
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

        if let mediaDraftState = try? container.decodeIfPresent(ChatInterfaceMediaDraftState.self, forKey: "mds") {
            self.mediaDraftState = mediaDraftState
        } else {
            self.mediaDraftState = nil
        }
        
        self.silentPosting = ((try? container.decode(Int32.self, forKey: "sip")) ?? 0) != 0
        self.inputLanguage = try? container.decodeIfPresent(String.self, forKey: "inputLanguage")
        
        self.sendMessageEffect = try? container.decodeIfPresent(Int64.self, forKey: "sendMessageEffect")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.timestamp, forKey: "ts")
        try container.encode(self.composeInputState, forKey: "is")
        try container.encode(self.composeDisableUrlPreviews, forKey: "dup;")
        
        if let replyMessageSubject = self.replyMessageSubject {
            try container.encode(replyMessageSubject, forKey: "replyMessageSubject")
        } else {
            try container.encodeNil(forKey: "replyMessageSubject")
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
        if let mediaDraftState = self.mediaDraftState {
            try container.encode(mediaDraftState, forKey: "mds")
        } else {
            try container.encodeNil(forKey: "mds")
        }
        try container.encode((self.silentPosting ? 1 : 0) as Int32, forKey: "sip")
        if let inputLanguage = self.inputLanguage {
            try container.encode(inputLanguage, forKey: "inputLanguage")
        } else {
            try container.encodeNil(forKey: "inputLanguage")
        }
        
        try container.encodeIfPresent(self.sendMessageEffect, forKey: "sendMessageEffect")
    }
    
    public static func ==(lhs: ChatInterfaceState, rhs: ChatInterfaceState) -> Bool {
        if lhs.composeDisableUrlPreviews != rhs.composeDisableUrlPreviews {
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
        if lhs.mediaDraftState != rhs.mediaDraftState {
            return false
        }
        if lhs.silentPosting != rhs.silentPosting {
            return false
        }
        if lhs.inputLanguage != rhs.inputLanguage {
            return false
        }
        if lhs.sendMessageEffect != rhs.sendMessageEffect {
            return false
        }
        return lhs.composeInputState == rhs.composeInputState && lhs.replyMessageSubject == rhs.replyMessageSubject && lhs.selectionState == rhs.selectionState && lhs.editMessage == rhs.editMessage
    }
    
    public func withUpdatedComposeInputState(_ inputState: ChatTextInputState) -> ChatInterfaceState {
        let updatedComposeInputState = inputState
        
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: updatedComposeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedComposeDisableUrlPreviews(_ disableUrlPreviews: [String]) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: disableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedEffectiveInputState(_ inputState: ChatTextInputState) -> ChatInterfaceState {
        var updatedEditMessage = self.editMessage
        var updatedComposeInputState = self.composeInputState
        if let editMessage = self.editMessage {
            updatedEditMessage = editMessage.withUpdatedInputState(inputState)
        } else {
            updatedComposeInputState = inputState
        }
        
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: updatedComposeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: updatedEditMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedReplyMessageSubject(_ replyMessageSubject: ReplyMessageSubject?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedForwardMessageIds(_ forwardMessageIds: [EngineMessage.Id]?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedForwardOptionsState(_ forwardOptionsState: ChatInterfaceForwardOptionsState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedSelectedMessages(_ messageIds: [EngineMessage.Id]) -> ChatInterfaceState {
        var selectedIds = Set<EngineMessage.Id>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        for messageId in messageIds {
            selectedIds.insert(messageId)
        }
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
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
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withoutSelectionState() -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: nil, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedTimestamp(_ timestamp: Int32) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedEditMessage(_ editMessage: ChatEditMessageState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedMessageActionsState(_ f: (ChatInterfaceMessageActionsState) -> ChatInterfaceMessageActionsState) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: f(self.messageActionsState), historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedHistoryScrollState(_ historyScrollState: ChatInterfaceHistoryScrollState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedMediaRecordingMode(_ mediaRecordingMode: ChatTextInputMediaRecordingButtonMode) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedMediaDraftState(_ mediaDraftState: ChatInterfaceMediaDraftState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedSilentPosting(_ silentPosting: Bool) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedInputLanguage(_ inputLanguage: String?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: inputLanguage, sendMessageEffect: self.sendMessageEffect)
    }
    
    public func withUpdatedSendMessageEffect(_ sendMessageEffect: Int64?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, composeDisableUrlPreviews: self.composeDisableUrlPreviews, replyMessageSubject: self.replyMessageSubject, forwardMessageIds: self.forwardMessageIds, forwardOptionsState: self.forwardOptionsState, editMessage: self.editMessage, selectionState: self.selectionState, messageActionsState: self.messageActionsState, historyScrollState: self.historyScrollState, mediaRecordingMode: self.mediaRecordingMode, mediaDraftState: self.mediaDraftState, silentPosting: self.silentPosting, inputLanguage: self.inputLanguage, sendMessageEffect: sendMessageEffect)
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
            
            var mediaDraftState: MediaDraftState?
            if let interfaceMediaDraftState = updatedState.mediaDraftState {
                mediaDraftState = MediaDraftState(contentType: interfaceMediaDraftState.contentType, timestamp: Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970))
            }
            
            return engine.peers.setOpaqueChatInterfaceState(
                peerId: peerId,
                threadId: threadId,
                state: OpaqueChatInterfaceState(
                    opaqueData: updatedOpaqueData,
                    historyScrollMessageIndex: updatedState.historyScrollMessageIndex,
                    mediaDraftState: mediaDraftState,
                    synchronizeableInputState: updatedState.synchronizeableInputState
                ))
        }
    }
}
