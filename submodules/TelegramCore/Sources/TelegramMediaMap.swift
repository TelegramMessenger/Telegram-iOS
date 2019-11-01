import Foundation
import Postbox
import TelegramApi

import SyncCore

func telegramMediaMapFromApiGeoPoint(_ geo: Api.GeoPoint, title: String?, address: String?, provider: String?, venueId: String?, venueType: String?, liveBroadcastingTimeout: Int32?) -> TelegramMediaMap {
    var venue: MapVenue?
    if let title = title {
        venue = MapVenue(title: title, address: address, provider: provider, id: venueId, type: venueType)
    }
    switch geo {
        case let .geoPoint(long, lat, _):
            return TelegramMediaMap(latitude: lat, longitude: long, geoPlace: nil, venue: venue, liveBroadcastingTimeout: liveBroadcastingTimeout)
        case .geoPointEmpty:
            return TelegramMediaMap(latitude: 0.0, longitude: 0.0, geoPlace: nil, venue: venue, liveBroadcastingTimeout: liveBroadcastingTimeout)
    }
}
