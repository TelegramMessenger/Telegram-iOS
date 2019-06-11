import Foundation
#if os(macOS)
import PostboxMac
import MtProtoKitMac
import SwiftSignalKitMac
#else
import Postbox
#if BUCK
        import MtProtoKit
    #else
        import MtProtoKitDynamic
    #endif
import SwiftSignalKit
#endif

final class CachedSecureIdConfiguration: PostboxCoding {
    let value: SecureIdConfiguration
    let hash: Int32
    
    init(value: SecureIdConfiguration, hash: Int32) {
        self.value = value
        self.hash = hash
    }
    
    init(decoder: PostboxDecoder) {
        self.value = decoder.decodeObjectForKey("value", decoder: { SecureIdConfiguration(decoder: $0) }) as! SecureIdConfiguration
        self.hash = decoder.decodeInt32ForKey("hash", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.value, forKey: "value")
        encoder.encodeInt32(self.hash, forKey: "hash")
    }
}

public struct SecureIdConfiguration: PostboxCoding {
    public let nativeLanguageByCountry: [String: String]
    
    fileprivate init(jsonString: String) {
        self.nativeLanguageByCountry = (try? JSONDecoder().decode(Dictionary<String, String>.self, from: jsonString.data(using: .utf8) ?? Data())) ?? [:]
    }
    
    public init(decoder: PostboxDecoder) {
        let nativeLanguageByCountryData = decoder.decodeBytesForKey("nativeLanguageByCountry")!
        self.nativeLanguageByCountry = (try? JSONDecoder().decode(Dictionary<String, String>.self, from: nativeLanguageByCountryData.dataNoCopy())) ?? [:]
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let nativeLanguageByCountryData = (try? JSONEncoder().encode(self.nativeLanguageByCountry)) ?? Data()
        encoder.encodeBytes(MemoryBuffer(data: nativeLanguageByCountryData), forKey: "nativeLanguageByCountry")
    }
}

public func secureIdConfiguration(postbox: Postbox, network: Network) -> Signal<SecureIdConfiguration, NoError> {
    let cached: Signal<CachedSecureIdConfiguration?, NoError> = postbox.transaction { transaction -> CachedSecureIdConfiguration? in
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedSecureIdConfiguration, key: ValueBoxKey(length: 0))) as? CachedSecureIdConfiguration {
            return entry
        } else {
            return nil
        }
    }
    return cached
    |> mapToSignal { cached -> Signal<SecureIdConfiguration, NoError> in
        return network.request(Api.functions.help.getPassportConfig(hash: cached?.hash ?? 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<SecureIdConfiguration, NoError> in
            let parsed: CachedSecureIdConfiguration
            switch result {
                case .passportConfigNotModified:
                    if let cached = cached {
                        return .single(cached.value)
                    } else {
                        assertionFailure()
                        return .complete()
                    }
                case let .passportConfig(hash, countriesLangs):
                    switch countriesLangs {
                        case let .dataJSON(data):
                            let value = SecureIdConfiguration(jsonString: data)
                            parsed = CachedSecureIdConfiguration(value: value, hash: hash)
                    }
            }
            return postbox.transaction { transaction -> SecureIdConfiguration in
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedSecureIdConfiguration, key: ValueBoxKey(length: 0)), entry: parsed, collectionSpec: ItemCacheCollectionSpec(lowWaterItemCount: 1, highWaterItemCount: 1))
                return parsed.value
            }
        }
    }
}
