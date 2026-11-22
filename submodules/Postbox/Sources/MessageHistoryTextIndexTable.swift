import Foundation

private func collectionId(_ peerId: PeerId) -> String {
    return "p\(UInt64(bitPattern: peerId.toInt64()))"
}

private func itemId(_ messageId: MessageId) -> String {
    return "p\(UInt64(bitPattern: messageId.peerId.toInt64()))a\(UInt32(bitPattern: messageId.namespace))b\(UInt32(bitPattern: messageId.id))"
}

private func messageTags(_ tags: MessageTags) -> String {
    var result = ""
    for tag in tags {
        if !result.isEmpty {
            result += " "
        }
        result += "t\(tag.rawValue)"
    }
    return result
}

private func parseMessageId(_ value: String) -> MessageId? {
    if !value.hasPrefix("p") {
        return nil
    }
    guard let aRange = value.range(of: "a") else {
        return nil
    }
    guard let bRange = value.range(of: "b") else {
        return nil
    }
    let pString = value[value.index(value.startIndex, offsetBy: 1) ..< aRange.lowerBound]
    let nString = value[aRange.upperBound ..< bRange.lowerBound]
    let iString = value[bRange.upperBound ..< value.endIndex]
    
    guard let pValue = UInt64(pString) else {
        return nil
    }
    guard let nValue = UInt32(nString) else {
        return nil
    }
    guard let iValue = UInt32(iString) else {
        return nil
    }
    
    return MessageId(peerId: PeerId(Int64(bitPattern: pValue)), namespace: Int32(bitPattern: nValue), id: Int32(bitPattern: iValue))
}

private let alphanumerics = CharacterSet.alphanumerics

final class MessageHistoryTextIndexTable {
    static func tableSpec(_ id: Int32) -> ValueBoxFullTextTable {
        return ValueBoxFullTextTable(id: id)
    }
    
    private let valueBox: ValueBox
    private let table: ValueBoxFullTextTable
    
    init(valueBox: ValueBox, table: ValueBoxFullTextTable) {
        self.valueBox = valueBox
        self.table = table
    }
    
    func add(messageId: MessageId, text: String, tags: MessageTags) {
        self.valueBox.fullTextSet(self.table, collectionId: collectionId(messageId.peerId), itemId: itemId(messageId), contents: text, tags: messageTags(tags))
    }
    
    func remove(messageId: MessageId) {
        self.valueBox.fullTextRemove(self.table, itemId: itemId(messageId), secure: true)
    }
    
    func search(peerId: PeerId?, text: String, tags: MessageTags?) -> [MessageId] {
        var escapedText = String(text.map({ c in
            var codeUnits: [UnicodeScalar] = []
            for codeUnit in String(c).unicodeScalars {
                codeUnits.append(codeUnit)
            }
            for codeUnit in codeUnits {
                if !alphanumerics.contains(codeUnit) {
                    return " "
                }
            }
            return c
        }))
        if !escapedText.isEmpty {
            escapedText += "*"
        }
        var result: [MessageId] = []
        self.valueBox.fullTextMatch(self.table, collectionId: peerId.flatMap { collectionId($0) }, query: escapedText, tags: tags.flatMap(messageTags), values: { _, itemId in
            if let messageId = parseMessageId(itemId) {
                result.append(messageId)
            } else {
                assertionFailure()
            }
            return true
        })
        return result
    }
}
