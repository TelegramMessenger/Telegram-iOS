import Postbox

public final class EngineCallList {
    public enum Scope {
        case all
        case missed
    }

    public enum Item {
        case message(message: EngineMessage, group: [EngineMessage])
        case hole(EngineMessage.Index)
    }

    public let items: [Item]
    public let hasEarlier: Bool
    public let hasLater: Bool

    init(
        items: [Item],
        hasEarlier: Bool,
        hasLater: Bool
    ) {
        self.items = items
        self.hasEarlier = hasEarlier
        self.hasLater = hasLater
    }
}
