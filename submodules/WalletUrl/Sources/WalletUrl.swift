import Foundation

public struct ParsedWalletUrl {
    public let address: String
    public let amount: Int64?
    public let comment: String?
}

private let invalidWalletAddressCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=").inverted
private func isValidWalletAddress(_ address: String) -> Bool {
    if address.count != 48 || address.rangeOfCharacter(from: invalidWalletAddressCharacters) != nil {
        return false
    }
    return true
}

public func parseWalletUrl(_ url: URL) -> ParsedWalletUrl? {
    guard url.scheme == "ton" && url.host == "transfer" else {
        return nil
    }
    let updatedUrl = URL(string: url.absoluteString.replacingOccurrences(of: "+", with: "%20"), relativeTo: nil) ?? url

    var address: String?
    let path = updatedUrl.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if isValidWalletAddress(path) {
        address = path
    }
    var amount: Int64?
    var comment: String?
    if let query = updatedUrl.query, let components = URLComponents(string: "/?" + query), let queryItems = components.queryItems {
        for queryItem in queryItems {
            if let value = queryItem.value {
                if queryItem.name == "amount", !value.isEmpty, let amountValue = Int64(value) {
                    amount = amountValue
                } else if queryItem.name == "text", !value.isEmpty {
                    comment = value
                }
            }
        }
    }
    return address.flatMap { ParsedWalletUrl(address: $0, amount: amount, comment: comment) }
}
