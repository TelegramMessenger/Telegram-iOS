import Foundation
import NGLocalization

public struct UnexpectedError: Error {
    public init() {}
}

extension UnexpectedError: LocalizedError {
    public var errorDescription: String? {
        return ngLocalized("Error.Default")
    }
}
