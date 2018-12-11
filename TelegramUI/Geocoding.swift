import Foundation
import CoreLocation
import SwiftSignalKit

func geocodeLocation(dictionary: [String: String]) -> Signal<(Double, Double)?, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressDictionary(dictionary, completionHandler: { placemarks, _ in
            if let location = placemarks?.first?.location {
                subscriber.putNext((location.coordinate.latitude, location.coordinate.longitude))
            } else {
                subscriber.putNext(nil)
            }
            subscriber.putCompletion()
        })
        return ActionDisposable {
            geocoder.cancelGeocode()
        }
    }
}

func reverseGeocodeLocation(latitude: Double, longitude: Double) -> Signal<String, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude), completionHandler: { placemarks, _ in
            if let placemarks = placemarks, let locality = placemarks.first?.locality {
                subscriber.putNext(locality)
                subscriber.putCompletion()
            }
        })
        return ActionDisposable {
            geocoder.cancelGeocode()
        }
    }
}
