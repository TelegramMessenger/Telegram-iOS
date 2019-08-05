import Foundation
import AccountContext

struct ChatTextInputPanelState: Equatable {
    let accessoryItems: [ChatTextInputAccessoryItem]
    let contextPlaceholder: NSAttributedString?
    let mediaRecordingState: ChatTextInputPanelMediaRecordingState?
    
    init(accessoryItems: [ChatTextInputAccessoryItem], contextPlaceholder: NSAttributedString?, mediaRecordingState: ChatTextInputPanelMediaRecordingState?) {
        self.accessoryItems = accessoryItems
        self.contextPlaceholder = contextPlaceholder
        self.mediaRecordingState = mediaRecordingState
    }
    
    init() {
        self.accessoryItems = []
        self.contextPlaceholder = nil
        self.mediaRecordingState = nil
    }
    
    func withUpdatedMediaRecordingState(_ mediaRecordingState: ChatTextInputPanelMediaRecordingState?) -> ChatTextInputPanelState {
        return ChatTextInputPanelState(accessoryItems: self.accessoryItems, contextPlaceholder: self.contextPlaceholder, mediaRecordingState: mediaRecordingState)
    }
    
    static func ==(lhs: ChatTextInputPanelState, rhs: ChatTextInputPanelState) -> Bool {
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

enum ChatVideoRecordingStatus: Equatable {
    case recording(InstantVideoControllerRecordingStatus)
    case editing
    
    static func ==(lhs: ChatVideoRecordingStatus, rhs: ChatVideoRecordingStatus) -> Bool {
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

enum ChatTextInputPanelMediaRecordingState: Equatable {
    case audio(recorder: ManagedAudioRecorder, isLocked: Bool)
    case video(status: ChatVideoRecordingStatus, isLocked: Bool)
    
    var isLocked: Bool {
        switch self {
            case let .audio(_, isLocked):
                return isLocked
            case let .video(_, isLocked):
                return isLocked
        }
    }
    
    func withLocked(_ isLocked: Bool) -> ChatTextInputPanelMediaRecordingState {
        switch self {
            case let .audio(recorder, _):
                return .audio(recorder: recorder, isLocked: isLocked)
            case let .video(status, _):
                return .video(status: status, isLocked: isLocked)
        }
    }
    
    static func ==(lhs: ChatTextInputPanelMediaRecordingState, rhs: ChatTextInputPanelMediaRecordingState) -> Bool {
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
        }
    }
}

