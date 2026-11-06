import Foundation
import TelegramCore

/// Validates the atom selected by the collective-mention suggestion. Literal text alone never
/// creates an entity; editing the selected atom into a username or an email invalidates it.
public func isValidAllMentionRange(in text: String, range: NSRange) -> Bool {
    let nsText = text as NSString
    guard range.location != NSNotFound, range.location >= 0, range.length == 4,
          range.location <= nsText.length, range.length <= nsText.length - range.location,
          let tokenRange = Range(range, in: text), text[tokenRange] == "@all" else {
        return false
    }
    func isIdentifier(_ scalar: UnicodeScalar) -> Bool {
        return scalar == "@" || scalar == "_" || CharacterSet.alphanumerics.contains(scalar) || CharacterSet.nonBaseCharacters.contains(scalar)
    }
    if let scalar = text[..<tokenRange.lowerBound].unicodeScalars.last, isIdentifier(scalar) {
        return false
    }
    if let scalar = text[tokenRange.upperBound...].unicodeScalars.first, isIdentifier(scalar) {
        return false
    }
    return true
}

/// Reads a selected mention as one range even if inline formatting splits its text into runs.
public func allMentionRanges(in text: NSAttributedString) -> [NSRange] {
    var result: [NSRange] = []
    text.enumerateAttribute(ChatTextInputAttributes.allMention, in: NSRange(location: 0, length: text.length)) { value, range, _ in
        if let value = value as? NSNumber, value.boolValue, isValidAllMentionRange(in: text.string, range: range), isAllMentionContextAllowed(in: text, range: range) {
            result.append(range)
        }
    }
    return result
}

/// Code, quotations and explicit links/peer mentions retain their original meaning.
/// This also applies to incomplete queries such as @ or @al in autocomplete.
public func isAllMentionContextAllowed(in text: NSAttributedString, range: NSRange) -> Bool {
    guard range.location != NSNotFound, range.location >= 0, range.length > 0,
          range.location <= text.length, range.length <= text.length - range.location else { return false }
    var allowed = true
    text.enumerateAttributes(in: range) { attributes, _, stop in
        if attributes[ChatTextInputAttributes.monospace] != nil
            || attributes[ChatTextInputAttributes.block] is ChatTextInputTextQuoteAttribute
            || attributes[ChatTextInputAttributes.textUrl] is ChatTextInputTextUrlAttribute
            || attributes[ChatTextInputAttributes.textMention] is ChatTextInputTextMentionAttribute {
            allowed = false
            stop.pointee = true
        }
    }
    return allowed
}

private func protectsFromAllMention(_ entity: MessageTextEntity) -> Bool {
    switch entity.type {
    case .Code, .Pre, .BlockQuote, .Url, .TextUrl, .Email, .TextMention:
        return true
    default:
        return false
    }
}

/// Literal collective-mention candidates for the opt-in local demo's enqueue boundary only.
/// Production sending must not promote these until Telegram provides a server capability.
public func allMentionTextRanges(in text: String, entities: [MessageTextEntity] = []) -> [NSRange] {
    let nsText = text as NSString
    let protectedEntities = (entities + generateTextEntities(text, enabledTypes: .allUrl)).filter(protectsFromAllMention)
    var result: [NSRange] = []
    var searchLocation = 0
    while searchLocation < nsText.length {
        let range = nsText.range(of: "@all", range: NSRange(location: searchLocation, length: nsText.length - searchLocation))
        guard range.location != NSNotFound else { break }
        let tokenRange = range.location ..< NSMaxRange(range)
        if isValidAllMentionRange(in: text, range: range), !protectedEntities.contains(where: { $0.range.overlaps(tokenRange) }) {
            result.append(range)
        }
        searchLocation = NSMaxRange(range)
    }
    return result
}

/// Normalizes the isolated demo's send/edit boundary, including stale selected atoms.
/// Formatting and ordinary personal mentions are preserved when a collective call is suppressed.
public func allMentionEntitiesForLocalDemo(text: String, entities: [MessageTextEntity], isEnabled: Bool) -> [MessageTextEntity] {
    let literalRanges = allMentionTextRanges(in: text)
    var result = entities.filter { entity in
        if case .Custom(type: ApplicationSpecificEntityType.AllMention) = entity.type { return false }
        if case .Mention = entity.type {
            return !literalRanges.contains(where: { entity.range.overlaps($0.location ..< NSMaxRange($0)) })
        }
        return true
    }
    if isEnabled {
        for range in allMentionTextRanges(in: text, entities: entities) {
            result.append(MessageTextEntity(range: range.location ..< NSMaxRange(range), type: .Custom(type: ApplicationSpecificEntityType.AllMention)))
        }
    }
    return result
}

/// Delivery may retain an existing queued call, never promote text that was
/// queued while the permission was disabled into a new collective call.
public func allMentionEntitiesForScheduledDemoDelivery(text: String, entities: [MessageTextEntity]) -> [MessageTextEntity] {
    let requestedRanges = Set(entities.filter { $0.type == .Custom(type: ApplicationSpecificEntityType.AllMention) }.map { $0.range })
    return allMentionEntitiesForLocalDemo(text: text, entities: entities, isEnabled: true).filter { entity in
        if entity.type == .Custom(type: ApplicationSpecificEntityType.AllMention) { return requestedRanges.contains(entity.range) }
        return true
    }
}

/// The explicitly selected composer atom; the caller adds an unformatted trailing space.
public func allMentionInputString() -> NSAttributedString {
    return NSAttributedString(string: "@all", attributes: [ChatTextInputAttributes.allMention: true as NSNumber])
}

/// Private marker used only by the native editor's shared link field, like the mention/date markers.
public func allMentionMarkdownURL() -> String {
    return "tg://all-mention"
}
