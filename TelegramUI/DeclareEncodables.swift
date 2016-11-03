import Postbox

private var telegramUIDeclaredEncodables: Void = {
    declareEncodable(ChatInterfaceState.self, f: { ChatInterfaceState(decoder: $0) })
    declareEncodable(ChatEmbeddedInterfaceState.self, f: { ChatEmbeddedInterfaceState(decoder: $0) })
    return
}()

public func telegramUIDeclareEncodables() {
    let _ = telegramUIDeclaredEncodables
}
