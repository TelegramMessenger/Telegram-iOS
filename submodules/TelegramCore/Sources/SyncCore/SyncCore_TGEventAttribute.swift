import Foundation
import Postbox

public final class TGEventAttribute: MessageAttribute {
    public let eventId: String
    public let title: String
    public let startTimestamp: Double
    public let endTimestamp: Double
    public let location: String?

    public var associatedPeerIds: [PeerId] { [] }
    public var associatedMessageIds: [MessageId] { [] }

    public init(eventId: String, title: String, startTimestamp: Double, endTimestamp: Double, location: String?) {
        self.eventId = eventId
        self.title = title
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.location = location
    }

    required public init(decoder: PostboxDecoder) {
        self.eventId = decoder.decodeStringForKey("eid", orElse: UUID().uuidString)
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.startTimestamp = decoder.decodeDoubleForKey("s", orElse: 0)
        self.endTimestamp = decoder.decodeDoubleForKey("e", orElse: 0)
        self.location = decoder.decodeOptionalStringForKey("l")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(eventId, forKey: "eid")
        encoder.encodeString(title, forKey: "t")
        encoder.encodeDouble(startTimestamp, forKey: "s")
        encoder.encodeDouble(endTimestamp, forKey: "e")
        if let location {
            encoder.encodeString(location, forKey: "l")
        } else {
            encoder.encodeNil(forKey: "l")
        }
    }
}
