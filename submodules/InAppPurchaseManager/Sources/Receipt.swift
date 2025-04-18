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

private func parse(_ data: Data, startIndex: Int = 0) -> Asn1Entry {
    var index = startIndex
    var value = data[index]
    index += 1
    var tagValue = Int32(value & 0x1f)
    if tagValue == 31 {
        value = data[index]
        index += 1
        while (value & 0x80) != 0 {
            tagValue <<= 8
            tagValue |= Int32(value & 0x7f)
            value = data[index]
            index += 1
        }
        tagValue <<= 8
        tagValue |= Int32(value & 0x7f)
    }
    
    var length = 0
    var nextTag = 0
    value = data[index]
    index += 1
    if value & 0x80 == 0 {
        length = Int(value)
        nextTag = index + length
    } else if value != 0x80 {
        let octetsCount = Int(value & 0x7f)
        for _ in 0 ..< octetsCount {
            length <<= 8
            value = data[index]
            index += 1
            length |= Int(value) & 0xff
        }
        nextTag = index + length
    } else {
        var scanIndex = index
        while data[scanIndex] != 0 && data[scanIndex + 1] != 0 {
            scanIndex += 1
        }
        length = scanIndex - index
        nextTag = scanIndex + 2
    }
    return Asn1Entry(tag: tagValue, data: data.subdata(in: index ..< (index + length)), length: nextTag - startIndex)
}

private func parseSequence(_ data: Data) -> [Asn1Entry] {
    var result : [Asn1Entry] = []
    var index = 0
    while index < data.count {
        let entry = parse(data, startIndex: index)
        result.append(entry)
        index += entry.length
    }
    return result
}

private func parseInteger(_ data: Data) -> Int32 {
    let length = data.count
    var value: Int32 = 0
    for i in 0 ..< length {
        if i == 0 {
            value = Int32(data[i] & 0x7f)
        } else {
            value <<= 8
            value |= Int32(data[i])
        }
    }
    if length > 0 && data[0] & 0x80 != 0 {
        let complement: Int32 = 1 << (length * 8)
        value -= complement
    }
    return value
}

private func parseObjectIdentifier(_ data: Data, startIndex: Int = 0, length: Int? = nil) -> [Int32] {
    let dataLen = length ?? data.count
    var index = startIndex
    var identifier: [Int32] = []
    while index < startIndex + dataLen {
        var subidentifier: Int32 = 0
        var value = data[index]
        index += 1
        while (value & 0x80) != 0 {
            subidentifier <<= 7
            subidentifier |= Int32(value & 0x7f)
            value = data[index]
            index += 1
        }
        subidentifier <<= 7
        subidentifier |= Int32(value & 0x7f)
        identifier.append(subidentifier)
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
    let root = parseSequence(data)
    guard root.count == 1 && root[0].tag == Asn1Tag.sequence else {
        return nil
    }
    
    let rootSeq = parseSequence(root[0].data)
    guard rootSeq.count == 2 && rootSeq[0].tag == Asn1Tag.objectIdentifier && parseObjectIdentifier(rootSeq[0].data) == ObjectIdentifier.pkcs7SignedData else {
        return nil
    }
    
    let signedData = parseSequence(rootSeq[1].data)
    guard signedData.count == 1 && signedData[0].tag == Asn1Tag.sequence else {
        return nil
    }
    
    let signedDataSeq = parseSequence(signedData[0].data)
    guard signedDataSeq.count > 3 && signedDataSeq[2].tag == Asn1Tag.sequence else {
        return nil
    }
    
    let contentData = parseSequence(signedDataSeq[2].data)
    guard contentData.count == 2 && contentData[0].tag == Asn1Tag.objectIdentifier && parseObjectIdentifier(contentData[0].data) == ObjectIdentifier.pkcs7Data else {
        return nil
    }
    
    let payload = parse(contentData[1].data)
    guard payload.tag == Asn1Tag.octetString else {
        return nil
    }
            
    let payloadRoot = parse(payload.data)
    guard payloadRoot.tag == Asn1Tag.set else {
        return nil
    }
    
    var purchases: [Receipt.Purchase] = []
    
    let receiptAttributes = parseSequence(payloadRoot.data)
    for attribute in receiptAttributes {
        if attribute.tag != Asn1Tag.sequence { continue }
        let attributeEntries = parseSequence(attribute.data)
        guard attributeEntries.count == 3 && attributeEntries[0].tag == Asn1Tag.integer && attributeEntries[1].tag == Asn1Tag.integer && attributeEntries[2].tag == Asn1Tag.octetString else { return nil
        }
        
        let type = parseInteger(attributeEntries[0].data)
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
    
    let result = formatter1.date(from: str)
    if result != nil {
        return result
    }
    
    let formatter2 = DateFormatter()
    formatter2.locale = posixLocale
    formatter2.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSSSSSX5"
    formatter2.timeZone = TimeZone(secondsFromGMT: 0)
    
    return formatter2.date(from: str)
}

private func parsePurchaseAttributes(_ data: Data) -> Receipt.Purchase? {
    let root = parse(data)
    guard root.tag == Asn1Tag.set else {
        return nil
    }
        
    var productId: String?
    var transactionId: String?
    var expirationDate: Date?
    
    let receiptAttributes = parseSequence(root.data)
    for attribute in receiptAttributes {
        if attribute.tag != Asn1Tag.sequence { continue }
        let attributeEntries = parseSequence(attribute.data)
        guard attributeEntries.count == 3 && attributeEntries[0].tag == Asn1Tag.integer && attributeEntries[1].tag == Asn1Tag.integer && attributeEntries[2].tag == Asn1Tag.octetString else { return nil
        }
        
        let type = parseInteger(attributeEntries[0].data)
        let value = attributeEntries[2].data
        switch (type) {
        case Receipt.Purchase.Tag.productIdentifier:
            let valEntry = parse(value)
            guard valEntry.tag == Asn1Tag.utf8String else { return nil }
            productId = String(bytes: valEntry.data, encoding: .utf8)
        case Receipt.Purchase.Tag.transactionIdentifier:
            let valEntry = parse(value)
            guard valEntry.tag == Asn1Tag.utf8String else { return nil }
            transactionId = String(bytes: valEntry.data, encoding: .utf8)
        case Receipt.Purchase.Tag.expirationDate:
            let valEntry = parse(value)
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
