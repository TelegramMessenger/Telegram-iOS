import SwiftSignalKitMac
import MtProtoKitMac
import PostboxMac

public enum TypingEntry : Comparable, Hashable, Identifiable {
    case text(timestamp:Int32)
    case voice(timestamp:Int32)
    case photo(timestamp:Int32, progress:Int32)
    case file(timestamp:Int32, progress:Int32)
    case video(timestamp:Int32, progress:Int32)
    case game(timestamp:Int32)
    case cancel
    
    public var stableId:Int {
        switch self {
        case .cancel:
            return 7
        case .text:
            return 1
        case .voice:
            return 2
        case .photo:
            return 3
        case .file:
            return 4
        case .video:
            return 5
        case .game:
            return 6
        }
    }
    
    public var progress:Int32 {
        switch self {
        case let .photo(data), let .file(data), let .video(data):
            return data.progress
        default:
            return 0
        }
    }
    
    public var timestamp:Int32 {
        switch self {
        case let .photo(data), let .file(data), let .video(data):
            return data.timestamp
        case let .text(timestamp), let .voice(timestamp), let .game(timestamp):
            return timestamp
        default:
            return Int32.max
        }
    }
    
    public var hashValue: Int {
        return stableId
    }
    
}

public func ==(lhs:TypingEntry, rhs:TypingEntry) -> Bool {
    return lhs.stableId == rhs.stableId //lhs.progress == rhs.progress && lhs.stableId == rhs.stableId && lhs.timestamp == rhs.timestamp
}

public func <(lhs:TypingEntry, rhs:TypingEntry) -> Bool {
    return lhs.stableId < rhs.stableId
}

extension TypingEntry {
    
    static func entry(from action:Api.SendMessageAction, timestamp:Int32) -> TypingEntry? {
        switch action {
        case .sendMessageTypingAction:
            return .text(timestamp:timestamp)
        case .sendMessageCancelAction:
            return .cancel
        case .sendMessageGamePlayAction:
            return .game(timestamp:timestamp)
        case .sendMessageRecordAudioAction:
            return .voice(timestamp:timestamp)
        case let .sendMessageUploadPhotoAction(progress: progress):
            return .photo(timestamp:timestamp, progress:progress)
        case let .sendMessageUploadDocumentAction(progress: progress):
            return .file(timestamp:timestamp, progress:progress)
        case let .sendMessageUploadVideoAction(progress: progress):
            return .video(timestamp:timestamp, progress:progress)
        default:
            return nil
        }
    }
    
}

public struct WrappedTypingEntry {
    public let peerId:PeerId
    public let entry:TypingEntry
}

public protocol TMProcessable {
    func update(for wrapped:WrappedTypingEntry)
    func observer(for peerId:PeerId) -> Signal<TypingEntry?,Void>
}
