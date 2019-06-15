import Foundation

public enum TelegramPeerAccessHash: Hashable {
    case personal(Int64)
    case genericPublic(Int64)
}
