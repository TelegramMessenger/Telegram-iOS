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

private func cachedGeocode(engine: TelegramEngine, address: DeviceContactAddressData) -> Signal<CachedGeocode?, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: Int64(bitPattern: address.string.persistentHashValue))
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.cachedGeocodes, id: key))
    |> map { entry -> CachedGeocode? in
        return entry?.get(CachedGeocode.self)
    }
}

private func updateCachedGeocode(engine: TelegramEngine, address: DeviceContactAddressData, latitude: Double, longitude: Double) -> Signal<(Double, Double), NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: Int64(bitPattern: address.string.persistentHashValue))
    
    return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.cachedGeocodes, id: key, item: CachedGeocode(latitude: latitude, longitude: longitude))
    |> map { _ -> (Double, Double) in }
    |> then(.single((latitude, longitude)))
}

public func geocodeAddress(engine: TelegramEngine, address: DeviceContactAddressData) -> Signal<(Double, Double)?, NoError> {
    return cachedGeocode(engine: engine, address: address)
    |> mapToSignal { cached -> Signal<(Double, Double)?, NoError> in
        if let cached = cached {
            return .single((cached.latitude, cached.longitude))
        } else {
            return geocodeLocation(address: address.asPostalAddress)
            |> mapToSignal { coordinate in
                if let (latitude, longitude) = coordinate  {
                    return updateCachedGeocode(engine: engine, address: address, latitude: latitude, longitude: longitude)
                    |> map(Optional.init)
                } else {
                    return .single(nil)
                }
            }
        }
    }
}
