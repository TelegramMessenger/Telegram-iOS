import Foundation

public final class TelegramApplicationContext {
    public let openUrl: (String) -> Void
    
    public init(openUrl: @escaping (String) -> Void) {
        self.openUrl = openUrl
    }
}
