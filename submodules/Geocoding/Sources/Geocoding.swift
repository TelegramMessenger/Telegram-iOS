import Foundation
import Contacts
import CoreLocation
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

public func reverseGeocodeLocation(latitude: Double, longitude: Double, locale: Locale? = nil) -> Signal<ReverseGeocodedPlacemark?, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude), preferredLocale: locale, completionHandler: { placemarks, _ in
            if let placemarks = placemarks, let placemark = placemarks.first {
                let result: ReverseGeocodedPlacemark
                if placemark.thoroughfare == nil && placemark.locality == nil && placemark.country == nil {
                    result = ReverseGeocodedPlacemark(name: placemark.name, street: placemark.name, city: nil, country: nil, countryCode: nil)
                } else {
                    if placemark.thoroughfare == nil && placemark.locality == nil, let ocean = placemark.ocean {
                        result = ReverseGeocodedPlacemark(name: ocean, street: nil, city: nil, country: placemark.country, countryCode: placemark.isoCountryCode)
                    } else {
                        result = ReverseGeocodedPlacemark(name: nil, street: placemark.thoroughfare, city: placemark.locality, country: placemark.country, countryCode: placemark.isoCountryCode)
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
