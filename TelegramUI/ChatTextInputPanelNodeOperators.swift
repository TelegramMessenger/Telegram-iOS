import Foundation

extension ChatTextInputAccessoryItem {
    static func ==(lhs: ChatTextInputAccessoryItem, rhs: ChatTextInputAccessoryItem) -> Bool {
        switch lhs {
            case .keyboard:
                if case .keyboard = rhs {
                    return true
                } else {
                    return false
                }
            case .stickers:
                if case .stickers = rhs {
                    return true
                } else {
                    return false
                }
            case .inputButtons:
                if case .inputButtons = rhs {
                    return true
                } else {
                    return false
                }
            case let .messageAutoremoveTimeout(lhsTimeout):
                if case let .messageAutoremoveTimeout(rhsTimeout) = rhs, lhsTimeout == rhsTimeout {
                    return true
                } else {
                    return false
                }
        }
    }
}

extension ChatVideoRecordingStatus {
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

extension ChatTextInputPanelMediaRecordingState {
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

extension ChatTextInputPanelState {
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

