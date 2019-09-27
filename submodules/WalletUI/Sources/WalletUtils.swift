import Foundation
import TelegramStringFormatting

let walletAddressLength: Int = 48

func formatAddress(_ address: String) -> String {
    var address = address
    address.insert("\n", at: address.index(address.startIndex, offsetBy: address.count / 2))
    return address
}

func formatBalanceText(_ value: Int64, decimalSeparator: String) -> String {
    var balanceText = "\(abs(value))"
    while balanceText.count < 10 {
        balanceText.insert("0", at: balanceText.startIndex)
    }
    balanceText.insert(contentsOf: decimalSeparator, at: balanceText.index(balanceText.endIndex, offsetBy: -9))
    while true {
        if balanceText.hasSuffix("0") {
            if balanceText.hasSuffix("\(decimalSeparator)0") {
                break
            } else {
                balanceText.removeLast()
            }
        } else {
            break
        }
    }
    if value < 0 {
        balanceText.insert("-", at: balanceText.startIndex)
    }
    return balanceText
}

private let invalidAmountCharacters = CharacterSet(charactersIn: "01234567890.,").inverted
func isValidAmount(_ amount: String) -> Bool {
    let amount = normalizeArabicNumeralString(amount, type: .western)
    if amount.rangeOfCharacter(from: invalidAmountCharacters) != nil {
        return false
    }
    var hasDecimalSeparator = false
    var hasLeadingZero = false
    var index = 0
    for c in amount {
        if c == "." || c == "," {
            if !hasDecimalSeparator {
                hasDecimalSeparator = true
            } else {
                return false
            }
        }
        index += 1
    }
    
    var decimalIndex: String.Index?
    if let index = amount.firstIndex(of: ".") {
        decimalIndex = index
    } else if let index = amount.firstIndex(of: ",") {
        decimalIndex = index
    }
    
    if let decimalIndex = decimalIndex, amount.distance(from: decimalIndex, to: amount.endIndex) > 10 {
        return false
    }
    
    return true
}

func amountValue(_ string: String) -> Int64 {
    return Int64((Double(string.replacingOccurrences(of: ",", with: ".")) ?? 0.0) * 1000000000.0)
}

func normalizedStringForGramsString(_ string: String, decimalSeparator: String = ".") -> String {
    return formatBalanceText(amountValue(string), decimalSeparator: decimalSeparator)
}

func formatAmountText(_ text: String, decimalSeparator: String) -> String {
    var text = normalizeArabicNumeralString(text, type: .western)
    if text == "." || text == "," {
        text = "0\(decimalSeparator)"
    } else if text == "0" {
        text = "0\(decimalSeparator)"
    } else if text.hasPrefix("0") && text.firstIndex(of: ".") == nil && text.firstIndex(of: ",") == nil {
        var trimmedText = text
        while trimmedText.first == "0" {
            trimmedText.removeFirst()
        }
        text = trimmedText
    }
    return text
}

private let invalidAddressCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=").inverted
private let invalidUrlAddressCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=").inverted

func isValidAddress(_ address: String, exactLength: Bool = false, url: Bool = false) -> Bool {
    if address.count > walletAddressLength || address.rangeOfCharacter(from: url ? invalidUrlAddressCharacters : invalidAddressCharacters) != nil {
        return false
    }
    if exactLength && address.count != walletAddressLength {
        return false
    }
    return true
}

func convertedAddress(_ address: String, url: Bool) -> String {
    if url {
        return address.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    } else {
        return address.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    }
}
