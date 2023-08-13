import Foundation
import Contacts
import CoreLocation
import MapKit
import SwiftSignalKit

public func geocodeLocation(address: String, locale: Locale? = nil) -> Signal<[CLPlacemark]?, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address, in: nil, preferredLocale: locale) { placemarks, _ in
            subscriber.putNext(placemarks)
            subscriber.putCompletion()
        }
        return ActionDisposable {
            geocoder.cancelGeocode()
        }
    }
}

public func geocodeLocation(address: CNPostalAddress, locale: Locale? = nil) -> Signal<(Double, Double)?, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.geocodePostalAddress(address, preferredLocale: locale) { placemarks, _ in
            if let location = placemarks?.first?.location {
                subscriber.putNext((location.coordinate.latitude, location.coordinate.longitude))
            } else {
                subscriber.putNext(nil)
            }
            subscriber.putCompletion()
        }
        return ActionDisposable {
            geocoder.cancelGeocode()
        }
    }
}

public struct ReverseGeocodedPlacemark {
    public let name: String?
    public let street: String?
    public let city: String?
    public let country: String?
    public let countryCode: String?
    
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


private let regions = [
    (
        CLLocationCoordinate2D(latitude: 46.046331, longitude: 32.398307),
        CLLocationCoordinate2D(latitude: 44.326515, longitude: 36.613495)
    )
]

private func shouldDisplayActualCountryName(latitude: Double, longitude: Double) -> Bool {
    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    let point = MKMapPoint(coordinate)
    for region in regions {
        let p1 = MKMapPoint(region.0)
        let p2 = MKMapPoint(region.1)
        let rect = MKMapRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
        if rect.contains(point) {
            return false
        }
    }
    return true
}

public func reverseGeocodeLocation(latitude: Double, longitude: Double, locale: Locale? = nil) -> Signal<ReverseGeocodedPlacemark?, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude), preferredLocale: locale, completionHandler: { placemarks, _ in
            if let placemarks, let placemark = placemarks.first {
                var countryName = placemark.country
                var countryCode = placemark.isoCountryCode
                if !shouldDisplayActualCountryName(latitude: latitude, longitude: longitude) {
                    countryName = nil
                    countryCode = nil
                }
                let result: ReverseGeocodedPlacemark
                if placemark.thoroughfare == nil && placemark.locality == nil && placemark.country == nil {
                    result = ReverseGeocodedPlacemark(name: placemark.name, street: placemark.name, city: nil, country: nil, countryCode: nil)
                } else {
                    if placemark.thoroughfare == nil && placemark.locality == nil, let ocean = placemark.ocean {
                        result = ReverseGeocodedPlacemark(name: ocean, street: nil, city: nil, country: countryName, countryCode: countryCode)
                    } else {
                        result = ReverseGeocodedPlacemark(name: nil, street: placemark.thoroughfare, city: placemark.locality, country: countryName, countryCode: countryCode)
                    }
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

let customAbbreviations = ["AE": "UAE", "GB": "UK", "US": "USA"]
public func displayCountryName(_ countryCode: String, locale: Locale?) -> String {
    let locale = locale ?? Locale.current
    if locale.identifier.lowercased().contains("en"), let shortName = customAbbreviations[countryCode] {
        return shortName
    } else {
        return locale.localizedString(forRegionCode: countryCode) ?? countryCode
    }
}
