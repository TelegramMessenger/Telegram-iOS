import Postbox

public final class EngineGroupCallDescription {
    public let id: Int64
    public let accessHash: Int64
    public let title: String?
    public let scheduleTimestamp: Int32?
    public let subscribedToScheduled: Bool

    public init(
        id: Int64,
        accessHash: Int64,
        title: String?,
        scheduleTimestamp: Int32?,
        subscribedToScheduled: Bool
    ) {
        self.id = id
        self.accessHash = accessHash
        self.title = title
        self.scheduleTimestamp = scheduleTimestamp
        self.subscribedToScheduled = subscribedToScheduled
    }
}

public extension EngineGroupCallDescription {
    convenience init(_ activeCall: CachedChannelData.ActiveCall) {
        self.init(
            id: activeCall.id,
            accessHash: activeCall.accessHash,
            title: activeCall.title,
            scheduleTimestamp: activeCall.scheduleTimestamp,
            subscribedToScheduled: activeCall.subscribedToScheduled
        )
    }
}
