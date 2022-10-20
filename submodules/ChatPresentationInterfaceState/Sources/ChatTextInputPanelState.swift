import Foundation
import AccountContext
import SwiftSignalKit

public enum ChatTextInputAccessoryItem: Equatable {
    public enum Key: Hashable {
        case input
        case botInput
        case commands
        case silentPost
        case messageAutoremoveTimeout
        case scheduledMessages
    }
    
    public enum InputMode: Hashable {
        case keyboard
        case stickers
        case emoji
        case bot
    }
    case input(isEnabled: Bool, inputMode: InputMode)
    case botInput(isEnabled: Bool, inputMode: InputMode)
        
    case commands
    case silentPost(Bool)
    case messageAutoremoveTimeout(Int32?)
    case scheduledMessages
    
    public var key: Key {
        switch self {
        case .input:
            return .input
        case .botInput:
            return .botInput
        case .commands:
            return .commands
        case .silentPost:
            return .silentPost
        case .messageAutoremoveTimeout:
            return .messageAutoremoveTimeout
        case .scheduledMessages:
            return .scheduledMessages
        }
    }
}

public final class InstantVideoControllerRecordingStatus {
    public let micLevel: Signal<Float, NoError>
    public let duration: Signal<TimeInterval, NoError>
    
    public init(micLevel: Signal<Float, NoError>, duration: Signal<TimeInterval, NoError>) {
        self.micLevel = micLevel
        self.duration = duration
    }
}

public struct ChatTextInputPanelState: Equatable {
    public let accessoryItems: [ChatTextInputAccessoryItem]
    public let contextPlaceholder: NSAttributedString?
    public let mediaRecordingState: ChatTextInputPanelMediaRecordingState?
    
    public init(accessoryItems: [ChatTextInputAccessoryItem], contextPlaceholder: NSAttributedString?, mediaRecordingState: ChatTextInputPanelMediaRecordingState?) {
        self.accessoryItems = accessoryItems
        self.contextPlaceholder = contextPlaceholder
        self.mediaRecordingState = mediaRecordingState
    }
    
    public init() {
        self.accessoryItems = []
        self.contextPlaceholder = nil
        self.mediaRecordingState = nil
    }
    
    public func withUpdatedMediaRecordingState(_ mediaRecordingState: ChatTextInputPanelMediaRecordingState?) -> ChatTextInputPanelState {
        return ChatTextInputPanelState(accessoryItems: self.accessoryItems, contextPlaceholder: self.contextPlaceholder, mediaRecordingState: mediaRecordingState)
    }
    
    public static func ==(lhs: ChatTextInputPanelState, rhs: ChatTextInputPanelState) -> Bool {
        if lhs.accessoryItems != rhs.accessoryItems {
            return false
        }
        if let lhsContextPlaceholder = lhs.contextPlaceholder, let rhsContextPlaceholder = rhs.contextPlaceholder {
            return lhsContextPlaceholder.isEqual(to: rhsContextPlaceholder)
        } else if (lhs.contextPlaceholder != nil) != (rhs.contextPlaceholder != nil) {
            return false
        }
        if lhs.mediaRecordingState != rhs.mediaRecordingState {
            return false
        }
        return true
    }
}

public enum ChatVideoRecordingStatus: Equatable {
    case recording(InstantVideoControllerRecordingStatus)
    case editing
    
    public static func ==(lhs: ChatVideoRecordingStatus, rhs: ChatVideoRecordingStatus) -> Bool {
        switch lhs {
            case let .recording(lhsStatus):
                if case let .recording(rhsStatus) = rhs, lhsStatus === rhsStatus {
                    return true
                } else {
                    return false
                }
            case .editing:
                if case .editing = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum ChatTextInputPanelMediaRecordingState: Equatable {
    case audio(recorder: ManagedAudioRecorder, isLocked: Bool)
    case video(status: ChatVideoRecordingStatus, isLocked: Bool)
    case waitingForPreview
    
    public var isLocked: Bool {
        switch self {
        case let .audio(_, isLocked):
            return isLocked
        case let .video(_, isLocked):
            return isLocked
        case .waitingForPreview:
            return true
        }
    }
    
    public func withLocked(_ isLocked: Bool) -> ChatTextInputPanelMediaRecordingState {
        switch self {
        case let .audio(recorder, _):
            return .audio(recorder: recorder, isLocked: isLocked)
        case let .video(status, _):
            return .video(status: status, isLocked: isLocked)
        case .waitingForPreview:
            return .waitingForPreview
        }
    }
    
    public static func ==(lhs: ChatTextInputPanelMediaRecordingState, rhs: ChatTextInputPanelMediaRecordingState) -> Bool {
        switch lhs {
        case let .audio(lhsRecorder, lhsIsLocked):
            if case let .audio(rhsRecorder, rhsIsLocked) = rhs, lhsRecorder === rhsRecorder, lhsIsLocked == rhsIsLocked {
                return true
            } else {
                return false
            }
        case let .video(status, isLocked):
            if case .video(status, isLocked) = rhs {
                return true
            } else {
                return false
            }
        case .waitingForPreview:
            if case .waitingForPreview = rhs {
                return true
            }
            return false
        }
    }
}

