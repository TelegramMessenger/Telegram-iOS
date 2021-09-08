import Foundation
import AppBundle

private final class CurrencyFormatterEntry {
    let symbol: String
    let thousandsSeparator: String
    let decimalSeparator: String
    let symbolOnLeft: Bool
    let spaceBetweenAmountAndSymbol: Bool
    let decimalDigits: Int
    
    init(symbol: String, thousandsSeparator: String, decimalSeparator: String, symbolOnLeft: Bool, spaceBetweenAmountAndSymbol: Bool, decimalDigits: Int) {
        self.symbol = symbol
        self.thousandsSeparator = thousandsSeparator
        self.decimalSeparator = decimalSeparator
        self.symbolOnLeft = symbolOnLeft
        self.spaceBetweenAmountAndSymbol = spaceBetweenAmountAndSymbol
        self.decimalDigits = decimalDigits
    }
}

private func loadCurrencyFormatterEntries() -> [String: CurrencyFormatterEntry] {
    guard let filePath = getAppBundle().path(forResource: "currencies", ofType: "json") else {
        return [:]
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        return [:]
    }
    
    guard let object = try? JSONSerialization.jsonObject(with: data, options: []), let dict = object as? [String: AnyObject] else {
        return [:]
    }
    
    var result: [String: CurrencyFormatterEntry] = [:]
    
    for (code, contents) in dict {
        if let contentsDict = contents as? [String: AnyObject] {
            let entry = CurrencyFormatterEntry(symbol: contentsDict["symbol"] as! String, thousandsSeparator: contentsDict["thousandsSeparator"] as! String, decimalSeparator: contentsDict["decimalSeparator"] as! String, symbolOnLeft: (contentsDict["symbolOnLeft"] as! NSNumber).boolValue, spaceBetweenAmountAndSymbol: (contentsDict["spaceBetweenAmountAndSymbol"] as! NSNumber).boolValue, decimalDigits: (contentsDict["decimalDigits"] as! NSNumber).intValue)
            result[code] = entry
            result[code.lowercased()] = entry
        }
    }
    
    return result
}

private let currencyFormatterEntries = loadCurrencyFormatterEntries()

public func setupCurrencyNumberFormatter(currency: String) -> NumberFormatter {
    guard let entry = currencyFormatterEntries[currency] ?? currencyFormatterEntries["USD"] else {
        preconditionFailure()
    }

    var result = ""
    if entry.symbolOnLeft {
        result.append("¤")
        if entry.spaceBetweenAmountAndSymbol {
            result.append(" ")
        }
    }

    result.append("#")

    if entry.decimalDigits != 0 {
        result.append(entry.decimalSeparator)
    }

    for _ in 0 ..< entry.decimalDigits {
        result.append("#")
    }
    if entry.decimalDigits != 0 {
        result.append("0")
    }

    if !entry.symbolOnLeft {
        if entry.spaceBetweenAmountAndSymbol {
            result.append(" ")
        }
        result.append("¤")
    }

    let numberFormatter = NumberFormatter()

    numberFormatter.numberStyle = .currency

    numberFormatter.positiveFormat = result
    numberFormatter.negativeFormat = "-\(result)"

    numberFormatter.currencySymbol = ""
    numberFormatter.currencyDecimalSeparator = entry.decimalSeparator
    numberFormatter.currencyGroupingSeparator = entry.thousandsSeparator

    numberFormatter.minimumFractionDigits = entry.decimalDigits
    numberFormatter.maximumFractionDigits = entry.decimalDigits
    numberFormatter.minimumIntegerDigits = 1

    return numberFormatter
}

public func fractionalToCurrencyAmount(value: Double, currency: String) -> Int64? {
    guard let entry = currencyFormatterEntries[currency] ?? currencyFormatterEntries["USD"] else {
        return nil
    }
    var factor: Double = 1.0
    for _ in 0 ..< entry.decimalDigits {
        factor *= 10.0
    }
    if value > Double(Int64.max) / factor {
        return nil
    } else {
        return Int64(value * factor)
    }
}

public func currencyToFractionalAmount(value: Int64, currency: String) -> Double? {
    guard let entry = currencyFormatterEntries[currency] ?? currencyFormatterEntries["USD"] else {
        return nil
    }
    var factor: Double = 1.0
    for _ in 0 ..< entry.decimalDigits {
        factor *= 10.0
    }
    return Double(value) / factor
}

public func formatCurrencyAmount(_ amount: Int64, currency: String) -> String {
    if let entry = currencyFormatterEntries[currency] ?? currencyFormatterEntries["USD"] {
        var result = ""
        if amount < 0 {
            result.append("-")
        }
        if entry.symbolOnLeft {
            result.append(entry.symbol)
            if entry.spaceBetweenAmountAndSymbol {
                result.append(" ")
            }
        }
        var integerPart = abs(amount)
        var fractional: [Character] = []
        for _ in 0 ..< entry.decimalDigits {
            let part = integerPart % 10
            integerPart /= 10
            if let scalar = UnicodeScalar(UInt32(part + 48)) {
                fractional.append(Character(scalar))
            }
        }
        result.append("\(integerPart)")
        if !fractional.isEmpty {
            result.append(entry.decimalSeparator)
        }
        for i in 0 ..< fractional.count {
            result.append(fractional[fractional.count - i - 1])
        }
        if !entry.symbolOnLeft {
            if entry.spaceBetweenAmountAndSymbol {
                result.append(" ")
            }
            result.append(entry.symbol)
        }
        
        return result
    } else {
        assertionFailure()
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.negativeFormat = "-¤#,##0.00"
        return formatter.string(from: (Float(amount) * 0.01) as NSNumber) ?? ""
    }
}

public func formatCurrencyAmountCustom(_ amount: Int64, currency: String) -> (String, String, Bool) {
    if let entry = currencyFormatterEntries[currency] ?? currencyFormatterEntries["USD"] {
        var result = ""
        if amount < 0 {
            result.append("-")
        }
        /*if entry.symbolOnLeft {
            result.append(entry.symbol)
            if entry.spaceBetweenAmountAndSymbol {
                result.append(" ")
            }
        }*/
        var integerPart = abs(amount)
        var fractional: [Character] = []
        for _ in 0 ..< entry.decimalDigits {
            let part = integerPart % 10
            integerPart /= 10
            if let scalar = UnicodeScalar(UInt32(part + 48)) {
                fractional.append(Character(scalar))
            }
        }
        result.append("\(integerPart)")
        if !fractional.isEmpty {
            result.append(entry.decimalSeparator)
        }
        for i in 0 ..< fractional.count {
            result.append(fractional[fractional.count - i - 1])
        }
        /*if !entry.symbolOnLeft {
            if entry.spaceBetweenAmountAndSymbol {
                result.append(" ")
            }
            result.append(entry.symbol)
        }*/

        return (result, entry.symbol, entry.symbolOnLeft)
    } else {
        return ("", "", false)
    }
}

public struct CurrencyFormat {
    public var symbol: String
    public var symbolOnLeft: Bool
    public var decimalSeparator: String
    public var decimalDigits: Int

    public init?(currency: String) {
        guard let entry = currencyFormatterEntries[currency] else {
            return nil
        }
        self.symbol = entry.symbol
        self.symbolOnLeft = entry.symbolOnLeft
        self.decimalSeparator = entry.decimalSeparator
        self.decimalDigits = entry.decimalDigits
    }
}
