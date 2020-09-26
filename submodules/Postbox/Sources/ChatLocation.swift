import Foundation
import SwiftSignalKit

public enum ChatLocationInput {
    case peer(PeerId)
    case external(PeerId, Int64, Signal<MessageHistoryViewExternalInput, NoError>)
}

public enum ResolvedChatLocationInput {
    case peer(PeerId)
    case external(MessageHistoryViewExternalInput)
}
