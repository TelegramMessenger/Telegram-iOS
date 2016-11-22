import Foundation

public enum PeerIndexNameRepresentation {
    case title(String)
    case personName(first: String, last: String)
}

public enum PeerNameIndex {
    case firstNameFirst
    case lastNameFirst
}

extension PeerIndexNameRepresentation {
    public func indexName(_ index: PeerNameIndex) -> String {
        switch self {
            case let .title(title):
                return title
            case let .personName(first, last):
                switch index {
                    case .firstNameFirst:
                        return first + last
                    case .lastNameFirst:
                        return last + first
                }
        }
    }
    
    public func match(query: String) -> Bool {
        switch self {
            case let .title(title):
                return title.lowercased().hasPrefix(query)
            case let .personName(first, last):
                return first.lowercased().hasPrefix(query) || last.lowercased().hasPrefix(query)
        }
        return false
    }
}
