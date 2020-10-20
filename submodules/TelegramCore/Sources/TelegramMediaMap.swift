import Foundation
import Postbox
import TelegramApi

import SyncCore

func telegramMediaMapFromApiGeoPoint(_ geo: Api.GeoPoint, title: String?, address: String?, provider: String?, venueId: String?, venueType: String?, liveBroadcastingTimeout: Int32?, heading: Int32?) -> TelegramMediaMap {
    var venue: MapVenue?
    if let title = title {
        venue = MapVenue(title: title, address: address, provider: provider, id: venueId, type: venueType)
    }
    switch geo {
        case let .geoPoint(_, long, lat, _, accuracyRadius):
            return TelegramMediaMap(latitude: lat, longitude: long, heading: heading.flatMap { Double($0) }, accuracyRadius: accuracyRadius.flatMap { Double($0) }, geoPlace: nil, venue: venue, liveBroadcastingTimeout: liveBroadcastingTimeout)
        case .geoPointEmpty:
            return TelegramMediaMap(latitude: 0.0, longitude: 0.0, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: venue, liveBroadcastingTimeout: liveBroadcastingTimeout)
    }
}
