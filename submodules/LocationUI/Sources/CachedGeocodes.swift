import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import PersistentStringHash
import AccountContext
import Geocoding

public final class CachedGeocode: Codable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.latitude = try container.decode(Double.self, forKey: "lat")
        self.longitude = try container.decode(Double.self, forKey: "lon")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.latitude, forKey: "lat")
        try container.encode(self.longitude, forKey: "lon")
    }
}

private func cachedGeocode(postbox: Postbox, address: DeviceContactAddressData) -> Signal<CachedGeocode?, NoError> {
    return postbox.transaction { transaction -> CachedGeocode? in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: Int64(bitPattern: address.string.persistentHashValue))
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.cachedGeocodes, key: key))?.get(CachedGeocode.self) {
            return entry
        } else {
            return nil
        }
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 10, highWaterItemCount: 20)

private func updateCachedGeocode(postbox: Postbox, address: DeviceContactAddressData, latitude: Double, longitude: Double) -> Signal<(Double, Double), NoError> {
    return postbox.transaction { transaction -> (Double, Double) in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: Int64(bitPattern: address.string.persistentHashValue))
        let id = ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.cachedGeocodes, key: key)
        if let entry = CodableEntry(CachedGeocode(latitude: latitude, longitude: longitude)) {
            transaction.putItemCacheEntry(id: id, entry: entry, collectionSpec: collectionSpec)
        }
        return (latitude, longitude)
    }
}

public func geocodeAddress(postbox: Postbox, address: DeviceContactAddressData) -> Signal<(Double, Double)?, NoError> {
    return cachedGeocode(postbox: postbox, address: address)
    |> mapToSignal { cached -> Signal<(Double, Double)?, NoError> in
        if let cached = cached {
            return .single((cached.latitude, cached.longitude))
        } else {
            return geocodeLocation(dictionary: address.dictionary)
            |> mapToSignal { coordinate in
                if let (latitude, longitude) = coordinate  {
                    return updateCachedGeocode(postbox: postbox, address: address, latitude: latitude, longitude: longitude)
                    |> map(Optional.init)
                } else {
                    return .single(nil)
                }
            }
        }
    }
}
