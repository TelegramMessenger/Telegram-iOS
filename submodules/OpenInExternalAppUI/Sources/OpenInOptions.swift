import Foundation
import UIKit
import TelegramCore
import CoreLocation
import MapKit
import AccountContext
import UrlEscaping

public enum OpenInItem {
    case url(url: String)
    case location(location: TelegramMediaMap, directions: OpenInLocationDirections?)
}

public enum OpenInLocationDirections: Equatable {
    case walking
    case driving
    case transit
    
    var transportType: MKDirectionsTransportType {
        switch self {
            case .walking:
                return .walking
            case .transit:
                return .transit
            case .driving:
                return .automobile
        }
    }
    
    public var launchOptions: String {
        switch self {
            case .walking:
                return MKLaunchOptionsDirectionsModeWalking
            case .transit:
                return MKLaunchOptionsDirectionsModeTransit
            case .driving:
                return MKLaunchOptionsDirectionsModeDriving
        }
    }
}

public enum OpenInApplication: Equatable {
    case safari
    case maps
    case other(title: String, identifier: Int64, scheme: String, store: String?)
}

public enum OpenInAction {
    case none
    case openUrl(url: String)
    case openLocation(latitude: Double, longitude: Double, directions: OpenInLocationDirections?)
}

public final class OpenInOption {
    public let identifier: String
    public let application: OpenInApplication
    public let action: () -> OpenInAction
    
    public init(identifier: String, application: OpenInApplication, action: @escaping () -> OpenInAction) {
        self.identifier = identifier
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
            var skipSafari = false
            if url.contains("youtube.com/") || url.contains("youtu.be/") {
                let updatedUrl = url.replacingOccurrences(of: "https://", with: "youtube://").replacingOccurrences(of: "http://", with: "youtube://")
                options.append(OpenInOption(identifier: "youtube", application: .other(title: "YouTube", identifier: 544007664, scheme: "youtube", store: nil), action: {
                    return .openUrl(url: updatedUrl)
                }))
                skipSafari = true
            }
            
            if !skipSafari {
                options.append(OpenInOption(identifier: "safari", application: .safari, action: {
                    return .openUrl(url: url)
                }))
            }

            options.append(OpenInOption(identifier: "chrome", application: .other(title: "Chrome", identifier: 535886823, scheme: "googlechrome", store: nil), action: {
                if let url = URL(string: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                    components.scheme = components.scheme == "https" ? "googlechromes" : "googlechrome"
                    if let url = components.string {
                        return .openUrl(url: url)
                    }
                }
                return .none
            }))
        
            options.append(OpenInOption(identifier: "firefox", application: .other(title: "Firefox", identifier: 989804926, scheme: "firefox", store: nil), action: {
                if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) {
                    return .openUrl(url: "firefox://open-url?url=\(escapedUrl)")
                }
                return .none
            }))
            
            options.append(OpenInOption(identifier: "firefoxFocus", application: .other(title: "Firefox Focus", identifier: 1055677337, scheme: "firefox-focus", store: nil), action: {
                if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) {
                    return .openUrl(url: "firefox-focus://open-url?url=\(escapedUrl)")
                }
                return .none
            }))
            
            options.append(OpenInOption(identifier: "operaMini", application: .other(title: "Opera Mini", identifier: 363729560, scheme: "opera-http", store: "es"), action: {
                if let url = URL(string: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                    components.scheme = components.scheme == "https" ? "opera-https" : "opera-http"
                    if let url = components.string {
                        return .openUrl(url: url)
                    }
                }
                return .none
            }))
        
            options.append(OpenInOption(identifier: "operaTouch", application: .other(title: "Opera Touch", identifier: 1411869974, scheme: "touch-http", store: nil), action: {
                if let url = URL(string: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                    components.scheme = components.scheme == "https" ? "touch-https" : "touch-http"
                    if let url = components.string {
                        return .openUrl(url: url)
                    }
                }
                return .none
            }))
            
            options.append(OpenInOption(identifier: "duckDuckGo", application: .other(title: "DuckDuckGo", identifier: 663592361, scheme: "ddgQuickLink", store: nil), action: {
                return .openUrl(url: "ddgQuickLink://\(url)")
            }))
                    
            options.append(OpenInOption(identifier: "edge", application: .other(title: "Microsoft Edge", identifier: 1288723196, scheme: "microsoft-edge-http", store: nil), action: {
                if let url = URL(string: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                    components.scheme = components.scheme == "https" ? "microsoft-edge-https" : "microsoft-edge-http"
                    if let url = components.string {
                        return .openUrl(url: url)
                    }
                }
                return .none
            }))
            
            options.append(OpenInOption(identifier: "yandex", application: .other(title: "Yandex Browser", identifier: 483693909, scheme: "yandexbrowser-open-url", store: nil), action: {
                if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                    return .openUrl(url: "yandexbrowser-open-url://\(escapedUrl)")
                }
                return .none
            }))

            options.append(OpenInOption(identifier: "brave", application: .other(title: "Brave", identifier: 1052879175, scheme: "brave", store: nil), action: {
                if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) {
                    return .openUrl(url: "brave://open-url?url=\(escapedUrl)")
                }
                return .none
            }))
            
            options.append(OpenInOption(identifier: "dolphin", application: .other(title: "Dolphin", identifier: 1440710469, scheme: "dolphin", store: "us"), action: {
                return .openUrl(url: "dolphin://\(url)")
            }))
                
            options.append(OpenInOption(identifier: "onion", application: .other(title: "Onion Browser", identifier: 519296448, scheme: "onionhttp", store: nil), action: {
                if let url = URL(string: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                    components.scheme = components.scheme == "https" ? "onionhttps" : "onionhttp"
                    if let url = components.string {
                        return .openUrl(url: url)
                    }
                }
                return .none
            }))

            options.append(OpenInOption(identifier: "ucbrowser", application: .other(title: "UC Browser", identifier: 1048518592, scheme: "ucbrowser", store: nil), action: {
                return .openUrl(url: "ucbrowser://\(url)")
            }))
        
            options.append(OpenInOption(identifier: "alook", application: .other(title: "Alook Browser", identifier: 1261944766, scheme: "alook", store: nil), action: {
                return .openUrl(url: "alook://\(url)")
            }))
        case let .location(location, directions):
            let lat = location.latitude
            let lon = location.longitude
        
            if directions == nil {
                if let venue = location.venue, let venueId = venue.id, let provider = venue.provider, provider == "foursquare" {
                    options.append(OpenInOption(identifier: "foursquare", application: .other(title: "Foursquare", identifier: 306934924, scheme: "foursquare", store: nil), action: {
                        return .openUrl(url: "foursquare://venues/\(venueId)")
                    }))
                }
            }
            
            options.append(OpenInOption(identifier: "appleMaps", application: .maps, action: {
                return .openLocation(latitude: lat, longitude: lon, directions: directions)
            }))
        
            options.append(OpenInOption(identifier: "googleMaps", application: .other(title: "Google Maps", identifier: 585027354, scheme: "comgooglemaps-x-callback", store: nil), action: {
                let coordinates = "\(lat),\(lon)"
                if let directions = directions {
                    let directionsMode: String
                    switch directions {
                        case .walking:
                            directionsMode = "walking"
                        case .driving:
                            directionsMode = "driving"
                        case .transit:
                            directionsMode = "transit"
                    }
                    return .openUrl(url: "comgooglemaps-x-callback://?daddr=\(coordinates)&directionsmode=\(directionsMode)&x-success=telegram://?resume=true&x-source=Telegram")
                } else {
                    if let venue = location.venue, let venueId = venue.id, let provider = venue.provider, provider == "gplaces" {
                        return .openUrl(url: "https://www.google.com/maps/search/?api=1&query=\(venue.address ?? "")&query_place_id=\(venueId)")
                    } else {
                        return .openUrl(url: "comgooglemaps-x-callback://?center=\(coordinates)&q=\(coordinates)&x-success=telegram://?resume=true&x-source=Telegram")
                    }
                }
            }))
        
            options.append(OpenInOption(identifier: "yandexMaps", application: .other(title: "Yandex.Maps", identifier: 313877526, scheme: "yandexmaps", store: nil), action: {
                if let _ = directions {
                    return .openUrl(url: "yandexmaps://build_route_on_map?lat_to=\(lat)&lon_to=\(lon)")
                } else {
                    return .openUrl(url: "yandexmaps://maps.yandex.ru/?pt=\(lon),\(lat)&z=16")
                }
            }))
            
            options.append(OpenInOption(identifier: "uber", application: .other(title: "Uber", identifier: 368677368, scheme: "uber", store: nil), action: {
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
            
            options.append(OpenInOption(identifier: "lyft", application: .other(title: "Lyft", identifier: 529379082, scheme: "lyft", store: nil), action: {
                return .openUrl(url: "lyft://ridetype?id=lyft&destination[latitude]=\(lat)&destination[longitude]=\(lon)")
            }))
            
            if let _ = directions {
                options.append(OpenInOption(identifier: "citymapper", application: .other(title: "Citymapper", identifier: 469463298, scheme: "citymapper", store: nil), action: {
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
            
                options.append(OpenInOption(identifier: "yandexNavi", application: .other(title: "Yandex.Navi", identifier: 474500851, scheme: "yandexnavi", store: nil), action: {
                    return .openUrl(url: "yandexnavi://build_route_on_map?lat_to=\(lat)&lon_to=\(lon)")
                }))
            }
            
            options.append(OpenInOption(identifier: "2gis", application: .other(title: "2GIS", identifier: 481627348, scheme: "dgis", store: nil), action: {
                let coordinates = "\(lon),\(lat)"
                if let _ = directions {
                    return .openUrl(url: "dgis://2gis.ru/routeSearch/to/\(coordinates)/go")
                } else {
                    return .openUrl(url: "dgis://2gis.ru/geo/\(coordinates)")
                }
            }))
            
            options.append(OpenInOption(identifier: "moovit", application: .other(title: "Moovit", identifier: 498477945, scheme: "moovit", store: nil), action: {
                if let _ = directions {
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
        
            if directions == nil {
                options.append(OpenInOption(identifier: "hereMaps", application: .other(title: "HERE Maps", identifier: 955837609, scheme: "here-location", store: nil), action: {
                    return .openUrl(url: "here-location://\(lat),\(lon)")
                }))
            }
            
            options.append(OpenInOption(identifier: "waze", application: .other(title: "Waze", identifier: 323229106, scheme: "waze", store: nil), action: {
                let url = "waze://?ll=\(lat),\(lon)"
                if let _ = directions {
                    return .openUrl(url: url.appending("&navigate=yes"))
                } else {
                    return .openUrl(url: url)
                }
            }))
    }
    return options
}
