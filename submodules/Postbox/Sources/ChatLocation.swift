import Foundation
import SwiftSignalKit

public enum ChatLocationInput {
    case peer(peerId: PeerId)
    case thread(peerId: PeerId, threadId: Int64, data: Signal<MessageHistoryViewExternalInput, NoError>)
    case feed(id: Int32, data: Signal<MessageHistoryViewExternalInput, NoError>)
}

public enum ResolvedChatLocationInput {
    case peer(PeerId)
    case external(MessageHistoryViewExternalInput)
}
