import Foundation

enum WalletSendInputMode: Equatable {
    case gram
    case fiat
}

func walletSendNormalizedDigits(_ text: String) -> String {
    return String(text.unicodeScalars.map { scalar -> Character in
        let character = Character(String(scalar))
        if CharacterSet.decimalDigits.contains(scalar), let digit = character.wholeNumberValue {
            return Character(String(digit))
        }
        return character
    })
}

func walletSendNanograms(
    text: String,
    mode: WalletSendInputMode,
    rate: Double?,
    decimalSeparator: String
) -> Int64? {
    guard !text.isEmpty else {
        return 0
    }

    guard !decimalSeparator.isEmpty else { return nil }
    let normalizedText = walletSendNormalizedDigits(text).replacingOccurrences(of: decimalSeparator, with: ".")
    let parts = normalizedText.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count <= 2,
          parts.allSatisfy({ $0.utf8.allSatisfy({ (48 ... 57).contains($0) }) }) else {
        return nil
    }
    switch mode {
    case .gram:
        let wholeText = parts.first.map(String.init) ?? ""
        let whole: Int64
        if wholeText.isEmpty {
            whole = 0
        } else if let value = Int64(wholeText) {
            whole = value
        } else {
            return nil
        }
        guard whole >= 0 else {
            return nil
        }
        let scale: Int64 = 1_000_000_000
        let (scaledWhole, didOverflow) = whole.multipliedReportingOverflow(by: scale)
        guard !didOverflow else {
            return nil
        }

        var fractionalText = parts.count == 2 ? String(parts[1]) : ""
        guard fractionalText.count <= 9 else {
            return nil
        }
        fractionalText = fractionalText.padding(toLength: 9, withPad: "0", startingAt: 0)
        guard let fractional = Int64(fractionalText) else { return nil }
        let (result, didAddOverflow) = scaledWhole.addingReportingOverflow(fractional)
        return didAddOverflow ? nil : result
    case .fiat:
        guard let rate, rate.isFinite, rate > 0.0,
              let fiatValue = Double(normalizedText), fiatValue.isFinite, fiatValue >= 0.0 else {
            return nil
        }
        let nanograms = fiatValue / rate * 1_000_000_000.0
        let roundedNanograms = nanograms.rounded()
        guard roundedNanograms.isFinite,
              roundedNanograms >= 0.0,
              roundedNanograms < Double(Int64.max) else {
            return nil
        }
        return Int64(roundedNanograms)
    }
}

func walletSendGroupedAmountText(_ text: String, decimalSeparator: String, groupingSeparator: String) -> String {
    guard !groupingSeparator.isEmpty else {
        return text
    }
    let integralEnd = text.range(of: decimalSeparator)?.lowerBound ?? text.endIndex
    let integralPart = text[..<integralEnd]
    let integralLength = integralPart.count
    guard integralLength > 3 else {
        return text
    }

    var result = ""
    for (index, character) in integralPart.enumerated() {
        if index > 0 && (integralLength - index) % 3 == 0 {
            result.append(contentsOf: groupingSeparator)
        }
        result.append(character)
    }
    result.append(contentsOf: text[integralEnd...])
    return result
}

struct WalletSendAmountEdit: Equatable {
    let text: String
    let selection: NSRange
}

func walletSendReplacingAmountText(
    _ text: String,
    range: NSRange,
    replacement string: String,
    mode: WalletSendInputMode,
    rate: Double?,
    decimalSeparator: String
) -> WalletSendAmountEdit? {
    guard !decimalSeparator.isEmpty else { return nil }
    var replacement = walletSendNormalizedDigits(string)
    if replacement == "." || replacement == "," {
        replacement = decimalSeparator
    }
    let previousText = text as NSString
    guard range.location != NSNotFound, range.location >= 0, range.location <= previousText.length,
          range.length >= 0, range.length <= previousText.length - range.location else { return nil }
    var updatedText = previousText.replacingCharacters(in: range, with: replacement)
    var selectionOffset = range.location + replacement.utf16.count

    let allowedCharacters = CharacterSet(charactersIn: "0123456789" + decimalSeparator)
    guard updatedText.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
        return nil
    }
    guard updatedText.components(separatedBy: decimalSeparator).count <= 2 else {
        return nil
    }
    let maximumFractionalDigits = mode == .gram ? 9 : 2
    if let range = updatedText.range(of: decimalSeparator) {
        let fractionalCount = updatedText[range.upperBound...].count
        guard fractionalCount <= maximumFractionalDigits else {
            return nil
        }
    }
    if updatedText == decimalSeparator {
        updatedText = "0" + decimalSeparator
        selectionOffset += 1
    }
    if updatedText.count > 1 && updatedText.hasPrefix("0") && !updatedText.hasPrefix("0" + decimalSeparator) {
        updatedText.removeFirst()
        selectionOffset = max(0, selectionOffset - 1)
    }
    let shouldAppendDecimalSeparator = !replacement.isEmpty && updatedText == "0"
    if shouldAppendDecimalSeparator {
        updatedText += decimalSeparator
        selectionOffset = updatedText.utf16.count
    }
    guard walletSendNanograms(
        text: updatedText,
        mode: mode,
        rate: rate,
        decimalSeparator: decimalSeparator
    ) != nil else {
        return nil
    }

    return WalletSendAmountEdit(text: updatedText, selection: NSRange(location: selectionOffset, length: 0))
}
