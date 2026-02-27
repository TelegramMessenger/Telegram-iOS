import Foundation
import Postbox
import TelegramApi


extension PeerGeoLocation {
    init?(apiLocation: Api.ChannelLocation) {
        switch apiLocation {
            case let .channelLocation(channelLocationData):
                let (geopoint, address) = (channelLocationData.geoPoint, channelLocationData.address)
                if case let .geoPoint(geoPointData) = geopoint {
                    let (longitude, latitude) = (geoPointData.long, geoPointData.lat)
                    self.init(latitude: latitude, longitude: longitude, address: address)
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
}
