import Foundation
import SwiftSignalKit

public enum ChatLocationInput {
    case peer(PeerId)
    case external(PeerId, Signal<MessageHistoryViewExternalInput, NoError>)
}

public enum ResolvedChatLocationInput {
    case peer(PeerId)
    case external(MessageHistoryViewExternalInput)
}
