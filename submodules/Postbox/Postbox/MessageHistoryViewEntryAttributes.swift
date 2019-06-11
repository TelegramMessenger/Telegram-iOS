import Foundation

public struct MutableMessageHistoryEntryAttributes: Equatable {
    public var authorIsContact: Bool
    
    public init(authorIsContact: Bool) {
        self.authorIsContact = authorIsContact
    }
}
