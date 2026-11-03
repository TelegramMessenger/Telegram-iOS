import Foundation

private struct Asn1Tag {
    static let integer: Int32 = 0x02
    static let octetString: Int32 = 0x04
    static let objectIdentifier: Int32 = 0x06
    static let sequence: Int32 = 0x10
    static let set: Int32 = 0x11
    static let utf8String: Int32 = 0x0c
    static let date: Int32 = 0x16
}

private struct Asn1Entry {
    let tag: Int32
    let data: Data
    let length: Int
}

private func dataByte(_ data: Data, at index: Int) -> UInt8? {
    guard index >= 0 && index < data.count else {
        return nil
    }
    return data[index]
}

private func parse(_ data: Data, startIndex: Int = 0) -> Asn1Entry? {
    guard startIndex >= 0 && startIndex < data.count else {
        return nil
    }
    
    var index = startIndex
    guard var value = dataByte(data, at: index) else {
        return nil
    }
    index += 1
    var tagValue = Int32(value & 0x1f)
    if tagValue == 31 {
        repeat {
            guard let nextValue = dataByte(data, at: index) else {
                return nil
            }
            value = nextValue
            index += 1
            guard tagValue <= Int32.max >> 8 else {
                return nil
            }
            tagValue <<= 8
            tagValue |= Int32(value & 0x7f)
        } while (value & 0x80) != 0
    }
    
    var length = 0
    guard let lengthValue = dataByte(data, at: index) else {
        return nil
    }
    value = lengthValue
    let isIndefiniteLength = value == 0x80
    index += 1
    if !isIndefiniteLength && value & 0x80 == 0 {
        length = Int(value)
    } else if !isIndefiniteLength {
        let octetsCount = Int(value & 0x7f)
        guard octetsCount > 0 else {
            return nil
        }
        for _ in 0 ..< octetsCount {
            guard length <= Int.max >> 8 else {
                return nil
            }
            length <<= 8
            guard let nextValue = dataByte(data, at: index) else {
                return nil
            }
            value = nextValue
            index += 1
            length |= Int(value) & 0xff
        }
    } else {
        var scanIndex = index
        while true {
            guard scanIndex + 1 < data.count else {
                return nil
            }
            if data[scanIndex] == 0 && data[scanIndex + 1] == 0 {
                break
            }
            scanIndex += 1
        }
        length = scanIndex - index
    }
    
    guard length >= 0, length <= data.count - index else {
        return nil
    }
    
    let payloadEndIndex = index + length
    let entryEndIndex: Int
    if isIndefiniteLength {
        entryEndIndex = payloadEndIndex + 2
        guard entryEndIndex <= data.count else {
            return nil
        }
    } else {
        entryEndIndex = payloadEndIndex
    }
    
    return Asn1Entry(tag: tagValue, data: data.subdata(in: index ..< payloadEndIndex), length: entryEndIndex - startIndex)
}

private func parseSequence(_ data: Data) -> [Asn1Entry]? {
    var result : [Asn1Entry] = []
    var index = 0
    while index < data.count {
        guard let entry = parse(data, startIndex: index), entry.length > 0 else {
            return nil
        }
        result.append(entry)
        index += entry.length
    }
    return result
}

private func parseInteger(_ data: Data) -> Int32? {
    guard !data.isEmpty, data.count <= MemoryLayout<Int32>.size else {
        return nil
    }
    
    var value: UInt32 = 0
    for byte in data {
        value = (value << 8) | UInt32(byte)
    }
    
    if let firstByte = data.first, firstByte & 0x80 != 0 && data.count < MemoryLayout<UInt32>.size {
        let shift = UInt32(data.count * 8)
        value |= ~UInt32(0) << shift
    }
    
    return Int32(bitPattern: value)
}

private func parseObjectIdentifier(_ data: Data, startIndex: Int = 0, length: Int? = nil) -> [Int32]? {
    let dataLen = length ?? data.count
    guard startIndex >= 0, dataLen > 0, startIndex <= data.count, dataLen <= data.count - startIndex else {
        return nil
    }
    
    let endIndex = startIndex + dataLen
    var index = startIndex
    var identifier: [Int32] = []
    while index < endIndex {
        var subidentifier: Int64 = 0
        while true {
            guard let value = dataByte(data, at: index) else {
                return nil
            }
            index += 1
            guard subidentifier <= Int64(Int32.max >> 7) else {
                return nil
            }
            subidentifier <<= 7
            subidentifier |= Int64(value & 0x7f)
            if (value & 0x80) == 0 {
                break
            }
            guard index < endIndex else {
                return nil
            }
        }
        identifier.append(Int32(subidentifier))
    }
    return identifier
}

private struct ObjectIdentifier {
    static let pkcs7Data: [Int32] = [42, 840, 113549, 1, 7, 1]
    static let pkcs7SignedData: [Int32] = [42, 840, 113549, 1, 7, 2]
}

struct Receipt {
    fileprivate struct Tag {
        static let purchases: Int32 = 17
    }
    
    struct Purchase {
        fileprivate struct Tag {
            static let productIdentifier: Int32 = 1702
            static let transactionIdentifier: Int32 = 1703
            static let expirationDate: Int32 = 1708
        }
        
        let productId: String
        let transactionId: String
        let expirationDate: Date
    }
    
    let purchases: [Purchase]
}

func parseReceipt(_ data: Data) -> Receipt? {
    guard let root = parseSequence(data) else {
        return nil
    }
    guard root.count == 1 && root[0].tag == Asn1Tag.sequence else {
        return nil
    }
    
    guard let rootSeq = parseSequence(root[0].data) else {
        return nil
    }
    guard rootSeq.count == 2 && rootSeq[0].tag == Asn1Tag.objectIdentifier && parseObjectIdentifier(rootSeq[0].data) == ObjectIdentifier.pkcs7SignedData else {
        return nil
    }
    
    guard let signedData = parseSequence(rootSeq[1].data) else {
        return nil
    }
    guard signedData.count == 1 && signedData[0].tag == Asn1Tag.sequence else {
        return nil
    }
    
    guard let signedDataSeq = parseSequence(signedData[0].data) else {
        return nil
    }
    guard signedDataSeq.count > 3 && signedDataSeq[2].tag == Asn1Tag.sequence else {
        return nil
    }
    
    guard let contentData = parseSequence(signedDataSeq[2].data) else {
        return nil
    }
    guard contentData.count == 2 && contentData[0].tag == Asn1Tag.objectIdentifier && parseObjectIdentifier(contentData[0].data) == ObjectIdentifier.pkcs7Data else {
        return nil
    }
    
    guard let payload = parse(contentData[1].data) else {
        return nil
    }
    guard payload.tag == Asn1Tag.octetString else {
        return nil
    }
            
    guard let payloadRoot = parse(payload.data) else {
        return nil
    }
    guard payloadRoot.tag == Asn1Tag.set else {
        return nil
    }
    
    var purchases: [Receipt.Purchase] = []
    
    guard let receiptAttributes = parseSequence(payloadRoot.data) else {
        return nil
    }
    for attribute in receiptAttributes {
        if attribute.tag != Asn1Tag.sequence { continue }
        guard let attributeEntries = parseSequence(attribute.data) else {
            return nil
        }
        guard attributeEntries.count == 3 && attributeEntries[0].tag == Asn1Tag.integer && attributeEntries[1].tag == Asn1Tag.integer && attributeEntries[2].tag == Asn1Tag.octetString else { return nil
        }
        
        guard let type = parseInteger(attributeEntries[0].data) else {
            return nil
        }
        let value = attributeEntries[2].data
        switch (type) {
        case Receipt.Tag.purchases:
            if let purchase = parsePurchaseAttributes(value) {
                purchases.append(purchase)
            }
        default:
            break
        }
    }
    return Receipt(purchases: purchases)
}

private func parseRfc3339Date(_ str: String) -> Date? {
    let posixLocale = Locale(identifier: "en_US_POSIX")
    
    let formatter1 = DateFormatter()
    formatter1.locale = posixLocale
    formatter1.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssX5"
    formatter1.timeZone = TimeZone(secondsFromGMT: 0)

    var result = formatter1.date(from: str)
    if result != nil {
        return result
    }

    let formatter2 = DateFormatter()
    formatter2.locale = posixLocale
    formatter2.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSSSSSX5"
    formatter2.timeZone = TimeZone(secondsFromGMT: 0)

    result = formatter2.date(from: str)
    if result != nil {
        return result
    }
    
    let formatterWithFractionalSeconds = ISO8601DateFormatter()
    formatterWithFractionalSeconds.timeZone = TimeZone(secondsFromGMT: 0)
    formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    if let result = formatterWithFractionalSeconds.date(from: str) {
        return result
    }
    
    let formatterWithoutFractionalSeconds = ISO8601DateFormatter()
    formatterWithoutFractionalSeconds.timeZone = TimeZone(secondsFromGMT: 0)
    formatterWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]
    
    return formatterWithoutFractionalSeconds.date(from: str)
}

private func parsePurchaseAttributes(_ data: Data) -> Receipt.Purchase? {
    guard let root = parse(data) else {
        return nil
    }
    guard root.tag == Asn1Tag.set else {
        return nil
    }
        
    var productId: String?
    var transactionId: String?
    var expirationDate: Date?
    
    guard let receiptAttributes = parseSequence(root.data) else {
        return nil
    }
    for attribute in receiptAttributes {
        if attribute.tag != Asn1Tag.sequence { continue }
        guard let attributeEntries = parseSequence(attribute.data) else {
            return nil
        }
        guard attributeEntries.count == 3 && attributeEntries[0].tag == Asn1Tag.integer && attributeEntries[1].tag == Asn1Tag.integer && attributeEntries[2].tag == Asn1Tag.octetString else { return nil
        }
        
        guard let type = parseInteger(attributeEntries[0].data) else {
            return nil
        }
        let value = attributeEntries[2].data
        switch (type) {
        case Receipt.Purchase.Tag.productIdentifier:
            guard let valEntry = parse(value) else {
                return nil
            }
            guard valEntry.tag == Asn1Tag.utf8String else { return nil }
            productId = String(bytes: valEntry.data, encoding: .utf8)
        case Receipt.Purchase.Tag.transactionIdentifier:
            guard let valEntry = parse(value) else {
                return nil
            }
            guard valEntry.tag == Asn1Tag.utf8String else { return nil }
            transactionId = String(bytes: valEntry.data, encoding: .utf8)
        case Receipt.Purchase.Tag.expirationDate:
            guard let valEntry = parse(value) else {
                return nil
            }
            guard valEntry.tag == Asn1Tag.date else { return nil }
            expirationDate = parseRfc3339Date(String(bytes: valEntry.data, encoding: .utf8) ?? "")
        default:
            break
        }
    }
    guard let productId, let transactionId, let expirationDate else {
        return nil
    }
    return Receipt.Purchase(productId: productId, transactionId: transactionId, expirationDate: expirationDate)
}
