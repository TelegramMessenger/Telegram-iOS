import Foundation
import SwiftSignalKit
import SyncCore
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import MapKit

extension TelegramMediaMap {
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}

extension MKMapRect {
    init(region: MKCoordinateRegion) {
        let point1 = MKMapPoint(CLLocationCoordinate2D(latitude: region.center.latitude + region.span.latitudeDelta / 2.0, longitude: region.center.longitude - region.span.longitudeDelta / 2.0))
        let point2 = MKMapPoint(CLLocationCoordinate2D(latitude: region.center.latitude - region.span.latitudeDelta / 2.0, longitude: region.center.longitude + region.span.longitudeDelta / 2.0))
        self = MKMapRect(x: min(point1.x, point2.x), y: min(point1.y, point2.y), width: abs(point1.x - point2.x), height: abs(point1.y - point2.y))
    }
}

extension CLLocationCoordinate2D: Equatable {

}

public func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}

public func nearbyVenues(account: Account, latitude: Double, longitude: Double, query: String? = nil) -> Signal<[TelegramMediaMap], NoError> {
    return resolvePeerByName(account: account, name: "foursquare")
    |> take(1)
    |> mapToSignal { peerId -> Signal<ChatContextResultCollection?, NoError> in
        guard let peerId = peerId else {
            return .single(nil)
        }
        return requestChatContextResults(account: account, botId: peerId, peerId: account.peerId, query: query ?? "", location: .single((latitude, longitude)), offset: "")
        |> `catch` { error -> Signal<ChatContextResultCollection?, NoError> in
            return .single(nil)
        }
    }
    |> map { contextResult -> [TelegramMediaMap] in
        guard let contextResult = contextResult else {
            return []
        }
        var list: [TelegramMediaMap] = []
        for result in contextResult.results {
            switch result.message {
                case let .mapLocation(mapMedia, _):
                    if let _ = mapMedia.venue {
                        list.append(mapMedia)
                    }
                default:
                    break
            }
        }
        return list
    }
}

private var sharedDistanceFormatter: MKDistanceFormatter?
func stringForDistance(strings: PresentationStrings, distance: CLLocationDistance) -> String {
    let distanceFormatter: MKDistanceFormatter
    if let currentDistanceFormatter = sharedDistanceFormatter {
        distanceFormatter = currentDistanceFormatter
    } else {
        distanceFormatter = MKDistanceFormatter()
        distanceFormatter.unitStyle = .full
        sharedDistanceFormatter = distanceFormatter
    }
    
    let locale = localeWithStrings(strings)
    if distanceFormatter.locale != locale {
        distanceFormatter.locale = locale
    }
    return distanceFormatter.string(fromDistance: distance)
}
