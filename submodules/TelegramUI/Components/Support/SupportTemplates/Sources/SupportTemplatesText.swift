import Foundation

func utf16Less(_ lhs: String, _ rhs: String) -> Bool {
    return lhs.utf16.lexicographicallyPrecedes(rhs.utf16)
}

func utf16Equal(_ lhs: String, _ rhs: String) -> Bool {
    return lhs.utf16.elementsEqual(rhs.utf16)
}

func utf16HasPrefix(_ string: String, _ prefix: String) -> Bool {
    return string.utf16.starts(with: prefix.utf16)
}

func stringFromUnits<S: Sequence>(_ units: S) -> String where S.Element == UInt16 {
    return String(decoding: Array(units), as: UTF16.self)
}

private func generalCategory(_ unit: UInt16) -> Unicode.GeneralCategory? {
    guard let scalar = Unicode.Scalar(unit) else {
        return nil
    }
    return scalar.properties.generalCategory
}

func isSpaceUnit(_ unit: UInt16) -> Bool {
    switch unit {
    case 0x09 ... 0x0D, 0x20, 0x85, 0xA0:
        return true
    default:
        if unit < 0x100 {
            return false
        }
        switch generalCategory(unit) {
        case .spaceSeparator?, .lineSeparator?, .paragraphSeparator?:
            return true
        default:
            return false
        }
    }
}

func trimmedUnits(_ units: [UInt16]) -> ArraySlice<UInt16> {
    var start = units.startIndex
    var end = units.endIndex
    while start < end && isSpaceUnit(units[start]) {
        start += 1
    }
    while end > start && isSpaceUnit(units[end - 1]) {
        end -= 1
    }
    return units[start ..< end]
}

public func trimmedString(_ string: String) -> String {
    return stringFromUnits(trimmedUnits(Array(string.utf16)))
}

private func isLetterOrNumber(_ unit: UInt16) -> Bool {
    switch generalCategory(unit) {
    case .uppercaseLetter?, .lowercaseLetter?, .titlecaseLetter?, .modifierLetter?, .otherLetter?, .decimalNumber?, .letterNumber?, .otherNumber?:
        return true
    default:
        return false
    }
}

private func lowercasedUnit(_ unit: UInt16) -> UInt16 {
    guard let scalar = Unicode.Scalar(unit) else {
        return unit
    }
    let lowered = Array(scalar.properties.lowercaseMapping.utf16)
    if lowered.count == 1 {
        return lowered[0]
    }
    return unit
}

public func supportTemplatesNormalizedQuestion(_ question: String) -> String {
    var result: [UInt16] = []
    for unit in question.utf16 where isLetterOrNumber(unit) {
        result.append(lowercasedUnit(unit))
    }
    return stringFromUnits(result)
}

public func supportTemplatesNormalizedKey(_ key: String) -> String {
    return supportTemplatesRemovingAccents(trimmedString(key).lowercased())
}

private func isFoldableUnit(_ unit: UInt16) -> Bool {
    switch unit {
    case 0x00C0 ... 0x024F, 0x1E00 ... 0x1EFF, 0xFF00 ... 0xFFEF:
        return true
    default:
        return false
    }
}

func supportTemplatesRemovingAccents(_ string: String) -> String {
    var result: [UInt16] = []
    result.reserveCapacity(string.utf16.count)
    for unit in string.utf16 {
        if unit < 0x80 {
            result.append(unit)
        } else if unit == 1652 || (unit >= 64606 && unit <= 64611) || generalCategory(unit) == .nonspacingMark {
            continue
        } else if unit == 0x0451 {
            result.append(0x0435)
        } else if isFoldableUnit(unit), let scalar = Unicode.Scalar(unit) {
            let folded = String(Character(scalar)).folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
            result.append(contentsOf: folded.utf16)
        } else {
            result.append(unit)
        }
    }
    return stringFromUnits(result)
}

private func isWordSeparator(_ unit: UInt16) -> Bool {
    switch unit {
    case 0x00, 0x09 ... 0x0D, 0x20, 0x21, 0x22, 0x27, 0x28, 0x29, 0x2B, 0x2C, 0x2D, 0x2E, 0x3A, 0x3B, 0x3C, 0x3E, 0x40, 0x5B, 0x5D, 0x5F, 0x7B, 0x7D:
        return true
    default:
        return false
    }
}

public func supportTemplatesSearchWords(_ query: String) -> [String] {
    let clean = supportTemplatesRemovingAccents(trimmedString(query).lowercased())
    var result: [String] = []
    var current: [UInt16] = []
    func flush() {
        let word = trimmedUnits(current)
        if !word.isEmpty {
            result.append(stringFromUnits(word))
        }
        current.removeAll()
    }
    for unit in clean.utf16 {
        if isWordSeparator(unit) {
            flush()
        } else {
            current.append(unit)
        }
    }
    flush()
    return result
}
