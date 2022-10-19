import Foundation

public struct MessageError: Error {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}

extension MessageError: LocalizedError {
    public var errorDescription: String? { message }
}

public var defaultErrorMessage: String {
    return NSLocalizedString("Error.Default", comment: "")
}

public extension MessageError {
    static var defaultError: Error {
        return MessageError(message: defaultErrorMessage)
    }
}


