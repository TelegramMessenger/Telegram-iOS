import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramUIPreferences
import PersistentStringHash
import AccountContext
import Geocoding

public final class CachedGeocode: PostboxCoding {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public init(decoder: PostboxDecoder) {
        self.latitude = decoder.decodeDoubleForKey("lat", orElse: 0.0)
        self.longitude = decoder.decodeDoubleForKey("lon", orElse: 0.0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeDouble(self.latitude, forKey: "lat")
        encoder.encodeDouble(self.longitude, forKey: "lon")
    }
}

private func cachedGeocode(postbox: Postbox, address: DeviceContactAddressData) -> Signal<CachedGeocode?, NoError> {
    return postbox.transaction { transaction -> CachedGeocode? in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: Int64(bitPattern: address.string.persistentHashValue))
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.cachedGeocodes, key: key)) as? CachedGeocode {
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
        transaction.putItemCacheEntry(id: id, entry: CachedGeocode(latitude: latitude, longitude: longitude), collectionSpec: collectionSpec)
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
