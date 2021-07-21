import Foundation
import Postbox
import TelegramApi


extension PeerGeoLocation {
    init?(apiLocation: Api.ChannelLocation) {
        switch apiLocation {
            case let .channelLocation(geopoint, address):
                if case let .geoPoint(_, longitude, latitude, _, _) = geopoint {
                    self.init(latitude: latitude, longitude: longitude, address: address)
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
}
