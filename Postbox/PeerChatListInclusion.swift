import Foundation

public enum PeerChatListInclusion {
    case never
    case ifHasMessages
    case always(minTimestamp: Int32)
}
