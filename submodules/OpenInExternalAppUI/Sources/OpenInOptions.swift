import Foundation
import UIKit
import TelegramCore
import CoreLocation
import MapKit
import AccountContext
import UrlEscaping

public enum OpenInItem {
    case url(url: String)
    case location(location: TelegramMediaMap, withDirections: Bool)
}

public enum OpenInApplication {
    case safari
    case maps
    case other(title: String, identifier: Int64, scheme: String, store: String?)
}

public enum OpenInAction {
    case none
    case openUrl(url: String)
    case openLocation(latitude: Double, longitude: Double, withDirections: Bool)
}

public final class OpenInOption {
    public let application: OpenInApplication
    public let action: () -> OpenInAction
    
    public init(application: OpenInApplication, action: @escaping () -> OpenInAction) {
        self.application = application
        self.action = action
    }
    
    public var title: String {
        get {
            switch self.application {
                case .safari:
                    return "Safari"
                case .maps:
                    return "Maps"
                case let .other(title, _, _, _):
                    return title
            }
        }
    }
}

public func availableOpenInOptions(context: AccountContext, item: OpenInItem) -> [OpenInOption] {
    return allOpenInOptions(context: context, item: item).filter { option in
        if case let .other(_, _, scheme, _) = option.application {
            return context.sharedContext.applicationBindings.canOpenUrl("\(scheme)://")
        } else {
            return true
        }
    }
}

private func allOpenInOptions(context: AccountContext, item: OpenInItem) -> [OpenInOption] {
    var options: [OpenInOption] = []
    switch item {
        case let .url(url):
            options.append(OpenInOption(application: .safari, action: {
                return .openUrl(url: url)
            }))

            options.append(OpenInOption(application: .other(title: "Chrome", identifier: 535886823, scheme: "googlechrome", store: nil), action: {
                if let url = URL(string: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                    components.scheme = components.scheme == "https" ? "googlechromes" : "googlechrome"
                    if let url = components.string {
                        return .openUrl(url: url)
                    }
                }
                return .none
            }))
        
            options.append(OpenInOption(application: .other(title: "Firefox", identifier: 989804926, scheme: "firefox", store: nil), action: {
                if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) {
                    return .openUrl(url: "firefox://open-url?url=\(escapedUrl)")
                }
                return .none
            }))
            
            options.append(OpenInOption(application: .other(title: "Firefox Focus", identifier: 1055677337, scheme: "firefox-focus", store: nil), action: {
                if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) {
                    return .openUrl(url: "firefox-focus://open-url?url=\(escapedUrl)")
                }
                return .none
            }))
            
            options.append(OpenInOption(application: .other(title: "Opera Mini", identifier: 363729560, scheme: "opera-http", store: "es"), action: {
                if let url = URL(string: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                    components.scheme = components.scheme == "https" ? "opera-https" : "opera-http"
                    if let url = components.string {
                        return .openUrl(url: url)
                    }
                }
                return .none
            }))
        
            options.append(OpenInOption(application: .other(title: "Opera Touch", identifier: 1411869974, scheme: "touch-http", store: nil), action: {
                if let url = URL(string: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                    components.scheme = components.scheme == "https" ? "touch-https" : "touch-http"
                    if let url = components.string {
                        return .openUrl(url: url)
                    }
                }
                return .none
            }))
        
            options.append(OpenInOption(application: .other(title: "Yandex", identifier: 483693909, scheme: "yandexbrowser-open-url", store: nil), action: {
                if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                    return .openUrl(url: "yandexbrowser-open-url://\(escapedUrl)")
                }
                return .none
            }))
        
            options.append(OpenInOption(application: .other(title: "DuckDuckGo", identifier: 663592361, scheme: "ddgQuickLink", store: nil), action: {
                return .openUrl(url: "ddgQuickLink://\(url)")
            }))
        
        
        case let .location(location, withDirections):
            let lat = location.latitude
            let lon = location.longitude
        
            if !withDirections {
                if let venue = location.venue, let venueId = venue.id, let provider = venue.provider, provider == "foursquare" {
                    options.append(OpenInOption(application: .other(title: "Foursquare", identifier: 306934924, scheme: "foursquare", store: nil), action: {
                        return .openUrl(url: "foursquare://venues/\(venueId)")
                    }))
                }
            }
            
            options.append(OpenInOption(application: .maps, action: {
                return .openLocation(latitude: lat, longitude: lon, withDirections: withDirections)
            }))
        
            options.append(OpenInOption(application: .other(title: "Google Maps", identifier: 585027354, scheme: "comgooglemaps-x-callback", store: nil), action: {
                let coordinates = "\(lat),\(lon)"
                if withDirections {
                    return .openUrl(url: "comgooglemaps-x-callback://?daddr=\(coordinates)&directionsmode=driving&x-success=telegram://?resume=true&x-source=Telegram")
                } else {
                    return .openUrl(url: "comgooglemaps-x-callback://?center=\(coordinates)&q=\(coordinates)&x-success=telegram://?resume=true&x-source=Telegram")
                }
            }))
        
            options.append(OpenInOption(application: .other(title: "Yandex.Maps", identifier: 313877526, scheme: "yandexmaps", store: nil), action: {
                if withDirections {
                    return .openUrl(url: "yandexmaps://build_route_on_map?lat_to=\(lat)&lon_to=\(lon)")
                } else {
                    return .openUrl(url: "yandexmaps://maps.yandex.ru/?pt=\(lon),\(lat)&z=16")
                }
            }))
            
            options.append(OpenInOption(application: .other(title: "Uber", identifier: 368677368, scheme: "uber", store: nil), action: {
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
                return .openUrl(url: "uber://?client_id=&action=setPickup&pickup=my_location&dropoff[latitude]=\(lat)&dropoff[longitude]=\(lon)&dropoff[nickname]=\(dropoffName)&dropoff[formatted_address]=\(dropoffAddress)")
            }))
            
            options.append(OpenInOption(application: .other(title: "Lyft", identifier: 529379082, scheme: "lyft", store: nil), action: {
                return .openUrl(url: "lyft://ridetype?id=lyft&destination[latitude]=\(lat)&destination[longitude]=\(lon)")
            }))
            
            if withDirections {
                options.append(OpenInOption(application: .other(title: "Citymapper", identifier: 469463298, scheme: "citymapper", store: nil), action: {
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
                    return .openUrl(url: "citymapper://directions?endcoord=\(lat),\(lon)&endname=\(endName)&endaddress=\(endAddress)")
                }))
            
                options.append(OpenInOption(application: .other(title: "Yandex.Navi", identifier: 474500851, scheme: "yandexnavi", store: nil), action: {
                    return .openUrl(url: "yandexnavi://build_route_on_map?lat_to=\(lat)&lon_to=\(lon)")
                }))
            }
            
            options.append(OpenInOption(application: .other(title: "Moovit", identifier: 498477945, scheme: "moovit", store: nil), action: {
                if withDirections {
                    let destName: String
                    if let title = location.venue?.title.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed), title.count > 0 {
                        destName = title
                    } else {
                        destName = ""
                    }
                    return .openUrl(url: "moovit://directions?dest_lat=\(lat)&dest_lon=\(lon)&dest_name=\(destName)&partner_id=Telegram")
                } else {
                    return .openUrl(url: "moovit://nearby?lat=\(lat)&lon=\(lon)&partner_id=Telegram")
                }
            }))
        
            if !withDirections {
                options.append(OpenInOption(application: .other(title: "HERE Maps", identifier: 955837609, scheme: "here-location", store: nil), action: {
                    return .openUrl(url: "here-location://\(lat),\(lon)")
                }))
            }
            
            options.append(OpenInOption(application: .other(title: "Waze", identifier: 323229106, scheme: "waze", store: nil), action: {
                let url = "waze://?ll=\(lat),\(lon)"
                if withDirections {
                    return .openUrl(url: url.appending("&navigate=yes"))
                } else {
                    return .openUrl(url: url)
                }
            }))
    }
    return options
}
