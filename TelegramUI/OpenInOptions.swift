import UIKit
import TelegramCore
import CoreLocation
import MapKit

enum OpenInItem {
    case url(_ url: String)
    case location(_ location: TelegramMediaMap, withDirections: Bool)
}

enum OpenInApplication {
    case safari
    case maps
    case other(title: String, identifier: Int64, scheme: String)
}

enum OpenInAction {
    case none
    case openUrl(_ url: String)
    case openLocation(latitude: Double, longitude: Double, withDirections: Bool)
}

final class OpenInOption {
    let application: OpenInApplication
    let action: () -> OpenInAction
    
    init(application: OpenInApplication, action: @escaping () -> OpenInAction) {
        self.application = application
        self.action = action
    }
    
    var title: String {
        get {
            switch self.application {
                case .safari:
                    return "Safari"
                case .maps:
                    return "Maps"
                case let .other(title, _, _):
                    return title
            }
        }
    }
}

func availableOpenInOptions(applicationContext: TelegramApplicationContext, item: OpenInItem) -> [OpenInOption] {
    return allOpenInOptions(applicationContext: applicationContext, item: item).filter { option in
        if case let .other(_, _, scheme) = option.application {
            return applicationContext.applicationBindings.canOpenUrl("\(scheme)://")
        } else {
            return true
        }
    }
}

private func allOpenInOptions(applicationContext: TelegramApplicationContext, item: OpenInItem) -> [OpenInOption] {
    var options: [OpenInOption] = []
    switch item {
        case let .url(url):
            options.append(OpenInOption(application: .safari, action: {
                return .openUrl(url)
            }))

            options.append(OpenInOption(application: .other(title: "Chrome", identifier: 535886823, scheme: "chrome"), action: {
                if let url = URL(string: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                    components.scheme = components.scheme == "https" ? "googlechromes" : "googlechrome"
                    if let url = components.string {
                        return .openUrl(url)
                    }
                }
                return .none
            }))
        
            options.append(OpenInOption(application: .other(title: "Firefox", identifier: 989804926, scheme: "firefox"), action: {
                if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) {
                    return .openUrl("firefox://open-url?url=\(escapedUrl)")
                }
                return .none
            }))
        
            options.append(OpenInOption(application: .other(title: "Opera Mini", identifier: 363729560, scheme: "opera-http"), action: {
                if let url = URL(string: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                    components.scheme = components.scheme == "https" ? "opera-https" : "opera-http"
                    if let url = components.string {
                        return .openUrl(url)
                    }
                }
                return .none
            }))
        
            options.append(OpenInOption(application: .other(title: "Yandex", identifier: 483693909, scheme: "yandexbrowser-open-url"), action: {
                if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                    return .openUrl("yandexbrowser-open-url://\(escapedUrl)")
                }
                return .none
            }))
        
        
        case let .location(location, withDirections):
            let lat = location.latitude
            let lon = location.longitude
        
            if let venue = location.venue, let venueId = venue.id, let provider = venue.provider, provider == "foursquare" {
                options.append(OpenInOption(application: .other(title: "Foursquare", identifier: 306934924, scheme: "foursquare"), action: {
                    return .openUrl("foursquare://venues/\(venueId)")
                }))
            }
            
            options.append(OpenInOption(application: .maps, action: {
                return .openLocation(latitude: lat, longitude: lon, withDirections: withDirections)
            }))
        
            options.append(OpenInOption(application: .other(title: "Google Maps", identifier: 585027354, scheme: "comgooglemaps-x-callback"), action: {
                let coordinates = "\(lat),\(lon)"
                if withDirections {
                    return .openUrl("comgooglemaps-x-callback://?daddr=\(coordinates)&directionsmode=driving&x-success=telegram://?resume=true&&x-source=Telegram")
                } else {
                    return .openUrl("comgooglemaps-x-callback://?center=\(coordinates)&q=\(coordinates)&x-success=telegram://?resume=true&&x-source=Telegram")
                }
            }))
        
            options.append(OpenInOption(application: .other(title: "Yandex.Maps", identifier: 313877526, scheme: "yandexmaps"), action: {
                if withDirections {
                    return .openUrl("yandexmaps://build_route_on_map?lat_to=\(lat)&lon_to=\(lon)")
                } else {
                    return .openUrl("yandexmaps://maps.yandex.ru/?pt=\(lat),\(lon)&z=16")
                }
            }))
            
            options.append(OpenInOption(application: .other(title: "Uber", identifier: 368677368, scheme: "uber"), action: {
                let dropoffName: String
                let dropoffAddress: String
                if let title = location.venue?.title.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed), title.count > 0 {
                    dropoffName = title
                } else {
                    dropoffName = ""
                }
                if let address = location.venue?.address?.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed), address.count > 0  {
                    dropoffAddress = address
                } else {
                    dropoffAddress = ""
                }
                return .openUrl("uber://?client_id=&action=setPickup&pickup=my_location&dropoff[latitude]=\(lat)&dropoff[longitude]=\(lon)&dropoff[nickname]=\(dropoffName)&dropoff[formatted_address]=\(dropoffAddress)")
            }))
            
            options.append(OpenInOption(application: .other(title: "Lyft", identifier: 529379082, scheme: "lyft"), action: {
                return .openUrl("lyft://ridetype?id=lyft&destination[latitude]=\(lat)&destination[longitude]=\(lon)")
            }))
            
            options.append(OpenInOption(application: .other(title: "Citymapper", identifier: 469463298, scheme: "citymapper"), action: {
                let endName: String
                let endAddress: String
                if let title = location.venue?.title.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed), title.count > 0 {
                    endName = title
                } else {
                    endName = ""
                }
                if let address = location.venue?.address?.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed), address.count > 0  {
                    endAddress = address
                } else {
                    endAddress = ""
                }
                return .openUrl("citymapper://directions?endcoord=\(lat),\(lon)&endname=\(endName)&endaddress=\(endAddress)")
            }))
        
            if withDirections {
                options.append(OpenInOption(application: .other(title: "Yandex.Navi", identifier: 474500851, scheme: "yandexnavi"), action: {
                    return .openUrl("yandexnavi://build_route_on_map?lat_to=\(lat)&lon_to=\(lon)")
                }))
            }
        
            options.append(OpenInOption(application: .other(title: "HERE Maps", identifier: 955837609, scheme: "here-location"), action: {
                return .openUrl("here-location://\(lat),\(lon)")
            }))
            
            options.append(OpenInOption(application: .other(title: "Waze", identifier: 323229106, scheme: "waze"), action: {
                let url = "waze://?ll=\(lat),\(lon)"
                if withDirections {
                    return .openUrl(url.appending("&navigate=yes"))
                } else {
                    return .openUrl(url)
                }
            }))
    }
    return options
}
