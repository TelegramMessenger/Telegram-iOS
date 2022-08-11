import Foundation

public struct MessageError: Error {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}

extension MessageError: LocalizedError {
    public var errorDescription: String? { return message }
}

public extension MessageError {
    static var unknown: MessageError {
        MessageError(message: NSLocalizedString("Nicegram.Alert.BaseError", comment: ""))
    }
}
