import Foundation
import Postbox
        
public class DerivedDataMessageAttribute: MessageAttribute {
    private struct EntryData: PostboxCoding {
        var data: CodableEntry
        
        init(data: CodableEntry) {
            self.data = data
        }
        
        init(decoder: PostboxDecoder) {
            self.data = CodableEntry(data: decoder.decodeDataForKey("d") ?? Data())
        }
        
        func encode(_ encoder: PostboxEncoder) {
            encoder.encodeData(self.data.data, forKey: "d")
        }
    }
    
    public let data: [String: CodableEntry]

    public init(data: [String: CodableEntry]) {
        self.data = data
    }
    
    required public init(decoder: PostboxDecoder) {
        let data = decoder.decodeObjectDictionaryForKey("d", keyDecoder: { key in
            return key.decodeStringForKey("k", orElse: "")
        }, valueDecoder: { value in
            return EntryData(data: CodableEntry(data: value.decodeDataForKey("d") ?? Data()))
        })
        self.data = data.mapValues(\.data)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectDictionary(self.data.mapValues(EntryData.init(data:)), forKey: "d", keyEncoder: { k, e in
            e.encodeString(k, forKey: "k")
        })
    }
}
