import Foundation
import Postbox

public final class TypingDraftMessageAttribute: MessageAttribute {
    public let randomId: Int64
    public let canStop: Bool
    public let keepOnStop: Bool
    public let isStopped: Bool

    public init(randomId: Int64, canStop: Bool, keepOnStop: Bool, isStopped: Bool) {
        self.randomId = randomId
        self.canStop = canStop
        self.keepOnStop = keepOnStop
        self.isStopped = isStopped
    }

    // Typing drafts are never persisted, so these were preconditionFailure(). They are
    // implemented because PostboxImpl.TypingDraft's == compares attributes by encoding
    // them, and only avoids that crash today because stableVersion is bumped on every
    // write and short-circuits the comparison first.
    public init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("id", orElse: 0)
        self.canStop = decoder.decodeBoolForKey("cs", orElse: false)
        self.keepOnStop = decoder.decodeBoolForKey("ks", orElse: false)
        self.isStopped = decoder.decodeBoolForKey("st", orElse: false)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "id")
        encoder.encodeBool(self.canStop, forKey: "cs")
        encoder.encodeBool(self.keepOnStop, forKey: "ks")
        encoder.encodeBool(self.isStopped, forKey: "st")
    }
}
