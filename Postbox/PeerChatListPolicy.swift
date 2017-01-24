import Foundation

public enum PeerChatListInclusion {
    case never
    case ifNotEmpty
    case always(minTimestamp: Int32)
}
