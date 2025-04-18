import Postbox

public protocol EngineOpaqueChatState: AnyObject, Codable {
    func isEqual(to other: EngineOpaqueChatState) -> Bool
}
