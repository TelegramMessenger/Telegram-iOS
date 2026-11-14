import Foundation

private func isTagTailUnit(_ unit: UInt16) -> Bool {
    switch unit {
    case 0x09 ... 0x0D, 0x20, 0x23, 0x2D, 0x5F, 0x30 ... 0x39, 0x41 ... 0x5A, 0x61 ... 0x7A:
        return true
    default:
        return false
    }
}

private func isTsfTag(_ units: [UInt16], at index: Int) -> Bool {
    guard index + 4 <= units.count, units[index] == 0x23 else {
        return false
    }
    return (units[index + 1] | 0x20) == 0x74 && (units[index + 2] | 0x20) == 0x73 && (units[index + 3] | 0x20) == 0x66
}

// The UTF-16 length the text keeps once a trailing `#tsf` tag group is removed, or nil if it has none.
public func supportHashtagStripLength(_ text: String) -> Int? {
    let units = Array(text.utf16)
    var start = units.count
    while start > 0 && isTagTailUnit(units[start - 1]) {
        start -= 1
    }
    for index in start ..< units.count where isTsfTag(units, at: index) {
        if index > 0 && units[index - 1] == 0x0A {
            return index - 1
        }
        return index
    }
    return nil
}

public func supportStrippingHashtag<Entity>(text: String, entities: [Entity], range: (Entity) -> Range<Int>, updatedRange: (Entity, Range<Int>) -> Entity) -> (text: String, entities: [Entity]) {
    guard let length = supportHashtagStripLength(text) else {
        return (text, entities)
    }
    if length == 0 {
        return ("", [])
    }
    let strippedText = stringFromUnits(text.utf16.prefix(length))
    var strippedEntities: [Entity] = []
    for entity in entities {
        let entityRange = range(entity)
        if entityRange.lowerBound >= length {
            continue
        }
        if entityRange.upperBound > length {
            strippedEntities.append(updatedRange(entity, entityRange.lowerBound ..< length))
        } else {
            strippedEntities.append(entity)
        }
    }
    return (strippedText, strippedEntities)
}
