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
    return "Something went wrong. Please try again later"
}

public extension MessageError {
    static var defaultError: Error {
        return MessageError(message: defaultErrorMessage)
    }
}


