import Foundation
import Contacts
import CoreLocation
import SwiftSignalKit

public func geocodeLocation(address: String) -> Signal<[CLPlacemark]?, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { (placemarks, _) in
            subscriber.putNext(placemarks)
            subscriber.putCompletion()
        }
        return ActionDisposable {
            geocoder.cancelGeocode()
        }
    }
}

public func geocodeLocation(address: CNPostalAddress) -> Signal<(Double, Double)?, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.geocodePostalAddress(address, completionHandler: { placemarks, _ in
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

public struct ReverseGeocodedPlacemark {
    public let street: String?
    public let city: String?
    public let country: String?
    
    public var compactDisplayAddress: String? {
        if let street = self.street {
            return street
        }
        if let city = self.city {
            return city
        }
        if let country = self.country {
            return country
        }
        return nil
    }
    
    public var fullAddress: String {
        var components: [String] = []
        if let street = self.street {
            components.append(street)
        }
        if let city = self.city {
            components.append(city)
        }
        if let country = self.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
}

public func reverseGeocodeLocation(latitude: Double, longitude: Double) -> Signal<ReverseGeocodedPlacemark?, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude), completionHandler: { placemarks, _ in
            if let placemarks = placemarks, let placemark = placemarks.first {
                let result: ReverseGeocodedPlacemark
                if placemark.thoroughfare == nil && placemark.locality == nil && placemark.country == nil {
                    result = ReverseGeocodedPlacemark(street: placemark.name, city: nil, country: nil)
                } else {
                    result = ReverseGeocodedPlacemark(street: placemark.thoroughfare, city: placemark.locality, country: placemark.country)
                }
                subscriber.putNext(result)
                subscriber.putCompletion()
            } else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
            }
        })
        return ActionDisposable {
            geocoder.cancelGeocode()
        }
    }
}
