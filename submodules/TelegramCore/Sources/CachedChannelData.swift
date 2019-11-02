import Foundation
import Postbox
import TelegramApi

import SyncCore

extension PeerGeoLocation {
    init?(apiLocation: Api.ChannelLocation) {
        switch apiLocation {
            case let .channelLocation(geopoint, address):
                if case let .geoPoint(longitude, latitude, _) = geopoint {
                    self.init(latitude: latitude, longitude: longitude, address: address)
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
}
