import Foundation
import SwiftSignalKit

public enum ChatLocationInput {
    case peer(PeerId)
    case external(PeerId, Signal<MessageHistoryViewExternalInput, NoError>)
}

enum ResolvedChatLocationInput {
    case peer(PeerId)
    case external(MessageHistoryViewExternalInput)
}
