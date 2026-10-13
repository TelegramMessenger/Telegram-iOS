import Foundation
import UIKit
import TelegramCore
import TelegramPresentationData

let walletAddressLength: Int = 48

public func formatTonAddress(_ address: String) -> String {
    var address = address
    address.insert("\n", at: address.index(address.startIndex, offsetBy: address.count / 2))
    return address
}

public func convertStarsToTon(_ amount: StarsAmount, tonUsdRate: Double, starsUsdRate: Double) -> Int64 {
    let usdRate = starsUsdRate / 1000.0 / 100.0
    let usdValue = Double(amount.value) * usdRate
    let tonValue = usdValue / tonUsdRate * 1000000000.0
    return Int64(tonValue)
}

public func convertTonToStars(_ amount: StarsAmount, tonUsdRate: Double, starsUsdRate: Double) -> Int64 {
    let usdRate = starsUsdRate / 1000.0 / 100.0
    let usdValue = Double(amount.value) / 1000000000 * tonUsdRate
    let starsValue = usdValue / usdRate
    return Int64(starsValue)
}

public func formatFiatValue(_ value: Double, currencySymbol: String, maxDecimalPositions: Int = 2, dateTimeFormat: PresentationDateTimeFormat) -> String {
    let decimalSeparator = dateTimeFormat.decimalSeparator
    var formattedValue = String(
        format: "%0.\(maxDecimalPositions)f",
        locale: Locale(identifier: "en_US_POSIX"),
        value
    )
    formattedValue = formattedValue.replacingOccurrences(of: ".", with: decimalSeparator)
    if let dotIndex = formattedValue.firstIndex(of: decimalSeparator.first!) {
        let integerPartString = formattedValue[..<dotIndex]
        if let integerPart = Int64(integerPartString) {
            let modifiedIntegerPart = presentationStringsFormattedNumber(integerPart, dateTimeFormat.groupingSeparator)
            
            let resultString = "\(currencySymbol)\(modifiedIntegerPart)\(formattedValue[dotIndex...])"
            return resultString
        }
    }
    if let integerPart = Int32(formattedValue) {
        return "\(currencySymbol)\(presentationStringsFormattedNumber(integerPart, dateTimeFormat.groupingSeparator))"
    }
    return "\(currencySymbol)\(formattedValue)"
}

public func formatTonFiatValue(_ value: Int64, divide: Bool = true, rate: Double = 1.0, currencySymbol: String, maxDecimalPositions: Int = 2, dateTimeFormat: PresentationDateTimeFormat) -> String {
    let normalizedValue: Double = divide ? Double(value) / 1000000000 : Double(value)
    return formatFiatValue(
        normalizedValue * rate,
        currencySymbol: currencySymbol,
        maxDecimalPositions: maxDecimalPositions,
        dateTimeFormat: dateTimeFormat
    )
}

public func formatTonUsdValue(_ value: Int64, divide: Bool = true, rate: Double = 1.0, maxDecimalPositions: Int = 2, dateTimeFormat: PresentationDateTimeFormat) -> String {
    return formatTonFiatValue(
        value,
        divide: divide,
        rate: rate,
        currencySymbol: "$",
        maxDecimalPositions: maxDecimalPositions,
        dateTimeFormat: dateTimeFormat
    )
}

public func formatTonAmountText(_ value: Int64, dateTimeFormat: PresentationDateTimeFormat, showPlus: Bool = false, maxDecimalPositions: Int? = 2, formatString: ((Int32) -> String)? = nil) -> String {
    let magnitude = value.magnitude
    let integerPart = magnitude / 1_000_000_000
    let fractionalPart = magnitude % 1_000_000_000
    let decimalPositions = min(9, max(0, maxDecimalPositions ?? 9))

    let fractionalDigits = String(fractionalPart)
    let fullFractionalPart = String(repeating: "0", count: 9 - fractionalDigits.count) + fractionalDigits
    var fractionalPartString = String(fullFractionalPart.prefix(decimalPositions))
    if integerPart == 0 && magnitude != 0 && fractionalPartString.allSatisfy({ $0 == "0" }) {
        fractionalPartString = fullFractionalPart
    }
    while fractionalPartString.hasSuffix("0") {
        fractionalPartString.removeLast()
    }

    var balanceText = String(integerPart)
    if !dateTimeFormat.groupingSeparator.isEmpty {
        var groupingOffset = balanceText.count - 3
        while groupingOffset > 0 {
            balanceText.insert(contentsOf: dateTimeFormat.groupingSeparator, at: balanceText.index(balanceText.startIndex, offsetBy: groupingOffset))
            groupingOffset -= 3
        }
    }
    if !fractionalPartString.isEmpty {
        balanceText += dateTimeFormat.decimalSeparator + fractionalPartString
    }

    if value < 0 {
        balanceText.insert("-", at: balanceText.startIndex)
    } else if showPlus {
        balanceText.insert("+", at: balanceText.startIndex)
    }

    if let formatString {
        let pluralizationValue: Int32 = (integerPart == 1 && fractionalPartString.isEmpty) ? 1 : 100
        return formatString(pluralizationValue).replacingOccurrences(of: "\(pluralizationValue)", with: balanceText)
    }
    return balanceText
}

public func formatStarsAmountText(_ amount: StarsAmount, dateTimeFormat: PresentationDateTimeFormat, showPlus: Bool = false) -> String {
    var balanceText = presentationStringsFormattedNumber(Int32(clamping: amount.value), dateTimeFormat.groupingSeparator)
    let fraction = abs(Double(amount.nanos)) / 10e6
    if fraction > 0.0 {
        balanceText.append(dateTimeFormat.decimalSeparator)
        balanceText.append("\(Int32(fraction))")
    }
    if amount.value < 0 {
    } else if showPlus {
        balanceText.insert("+", at: balanceText.startIndex)
    }
    return balanceText
}

public func formatCurrencyAmountText(_ amount: CurrencyAmount, dateTimeFormat: PresentationDateTimeFormat, showPlus: Bool = false, maxDecimalPositions: Int? = 2) -> String {
    switch amount.currency {
    case .stars:
        return formatStarsAmountText(amount.amount, dateTimeFormat: dateTimeFormat, showPlus: showPlus)
    case .ton:
        return formatTonAmountText(amount.amount.value, dateTimeFormat: dateTimeFormat, showPlus: showPlus, maxDecimalPositions: maxDecimalPositions)
    }
}

private let invalidAddressCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=").inverted
public func isValidTonAddress(_ address: String, exactLength: Bool = false) -> Bool {
    if address.count > walletAddressLength || address.rangeOfCharacter(from: invalidAddressCharacters) != nil {
        return false
    }
    if exactLength && address.count != walletAddressLength {
        return false
    }
    return true
}

public func tonAmountAttributedString(_ string: String, integralFont: UIFont, fractionalFont: UIFont, color: UIColor, decimalSeparator: String) -> NSAttributedString {
    let result = NSMutableAttributedString()
    if let range = string.range(of: decimalSeparator) {
        let integralPart = String(string[..<range.lowerBound])
        let fractionalPart = String(string[range.lowerBound...])
        result.append(NSAttributedString(string: integralPart, font: integralFont, textColor: color))
        result.append(NSAttributedString(string: fractionalPart, font: fractionalFont, textColor: color))
    } else {
        result.append(NSAttributedString(string: string, font: integralFont, textColor: color))
    }
    return result
}
