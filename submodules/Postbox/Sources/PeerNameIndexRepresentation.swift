import Foundation

public enum PeerIndexNameRepresentation: Equatable {
    case title(title: String, addressName: String?)
    case personName(first: String, last: String, addressName: String?, phoneNumber: String?)
    
    public var isEmpty: Bool {
        switch self {
            case let .title(title, addressName):
                if !title.isEmpty {
                    return false
                }
                if let addressName = addressName, !addressName.isEmpty {
                    return false
                }
                return true
            case let .personName(first, last, addressName, phoneNumber):
                if !first.isEmpty {
                    return false
                }
                if !last.isEmpty {
                    return false
                }
                if let addressName = addressName, !addressName.isEmpty {
                    return false
                }
                if let phoneNumber = phoneNumber, !phoneNumber.isEmpty {
                    return false
                }
                return true
        }
    }
}

public enum PeerNameIndex {
    case firstNameFirst
    case lastNameFirst
}

extension PeerIndexNameRepresentation {
    public func indexName(_ index: PeerNameIndex) -> String {
        switch self {
            case let .title(title, _):
                return title
            case let .personName(first, last, _, _):
                switch index {
                    case .firstNameFirst:
                        return first + last
                    case .lastNameFirst:
                        return last + first
                }
        }
    }
    
    public func matchesByTokens(_ other: String) -> Bool {
        var foundAtLeastOne = false
        for searchToken in stringIndexTokens(other, transliteration: .none) {
            var found = false
            for token in self.indexTokens {
                if searchToken.isPrefix(to: token) {
                    found = true
                    break
                }
            }
            if !found {
                return false
            }
            foundAtLeastOne = true
        }
        return foundAtLeastOne
    }
    
    public var indexTokens: [ValueBoxKey] {
        switch self {
            case let .title(title, addressName):
                var tokens: [ValueBoxKey] = stringIndexTokens(title, transliteration: .combined)
                if let addressName = addressName {
                    tokens.append(contentsOf: stringIndexTokens(addressName, transliteration: .none))
                }
                return tokens
            case let .personName(first, last, addressName, phoneNumber):
                var tokens: [ValueBoxKey] = stringIndexTokens(first, transliteration: .combined)
                tokens.append(contentsOf: stringIndexTokens(last, transliteration: .combined))
                if let addressName = addressName {
                    tokens.append(contentsOf: stringIndexTokens(addressName, transliteration: .none))
                }
                if let phoneNumber = phoneNumber {
                    tokens.append(contentsOf: stringIndexTokens(phoneNumber, transliteration: .none))
                }
                return tokens
        }
    }
}
