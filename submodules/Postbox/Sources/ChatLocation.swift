import Foundation
import SwiftSignalKit

public enum ChatLocationInput {
    case peer(peerId: PeerId, threadId: Int64?)
    case thread(peerId: PeerId, threadId: Int64, data: Signal<MessageHistoryViewExternalInput, NoError>)
    case customChatContents
}

public extension ChatLocationInput {
    var peerId: PeerId? {
        switch self {
        case let .peer(peerId, _):
            return peerId
        case let .thread(peerId, _, _):
            return peerId
        case .customChatContents:
            return nil
        }
    }
    
    var threadId: Int64? {
        switch self {
        case let .peer(_, threadId):
            return threadId
        case let .thread(_, threadId, _):
            return threadId
        case .customChatContents:
            return nil
        }
    }
}

public enum ResolvedChatLocationInput {
    case peer(peerId: PeerId, threadId: Int64?)
    case external(MessageHistoryViewExternalInput)
}
