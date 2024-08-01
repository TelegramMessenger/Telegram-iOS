import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TextFormat
import UrlWhitelist
import Svg

private var faviconCache: [String: UIImage] = [:]
func fetchFavicon(context: AccountContext, url: String, size: CGSize) -> Signal<UIImage?, NoError> {
    if let icon = faviconCache[url] {
        return .single(icon)
    }
    return context.engine.resources.httpData(url: url)
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Data?, NoError> in
        return .single(nil)
    }
    |> map { data in
        if let data {
            if let image = UIImage(data: data) {
                return image
            } else if url.lowercased().contains(".svg"), let preparedData = prepareSvgImage(data, false), let image = renderPreparedImage(preparedData, size, .clear, UIScreenScale, false) {
                return image
            }
            return nil
        } else {
            return nil
        }
    }
    |> beforeNext { image in
        if let image {
            Queue.mainQueue().async {
                faviconCache[url] = image
            }
        }
    }
}

func getPrimaryUrl(message: Message) -> String? {
    var primaryUrl: String?
    if let webPage = message.media.first(where: { $0 is TelegramMediaWebpage }) as? TelegramMediaWebpage, let url = webPage.content.url {
        primaryUrl = url
    } else {
        var entities = message.textEntitiesAttribute?.entities
        if entities == nil {
            let parsedEntities = generateTextEntities(message.text, enabledTypes: .all)
            if !parsedEntities.isEmpty {
                entities = parsedEntities
            }
        }
        
        if let entities {
            loop: for entity in entities {
                switch entity.type {
                case .Url, .Email:
                    var range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                    let nsString = message.text as NSString
                    if range.location + range.length > nsString.length {
                        range.location = max(0, nsString.length - range.length)
                        range.length = nsString.length - range.location
                    }
                    let tempUrlString = nsString.substring(with: range)
                    
                    var (urlString, concealed) = parseUrl(url: tempUrlString, wasConcealed: false)
                    var parsedUrl = URL(string: urlString)
                    if (parsedUrl == nil || parsedUrl!.host == nil || parsedUrl!.host!.isEmpty) && !urlString.contains("@") {
                        urlString = "http://" + urlString
                        parsedUrl = URL(string: urlString)
                    }
                    var host: String? = concealed ? urlString : parsedUrl?.host
                    if host == nil {
                        host = urlString
                    }
                    if let _ = parsedUrl, let _ = host {
                        primaryUrl = urlString
                    }
                    break loop
                case let .TextUrl(url):
                    let messageText = message.text
                    
                    var range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                    let nsString = messageText as NSString
                    if range.location + range.length > nsString.length {
                        range.location = max(0, nsString.length - range.length)
                        range.length = nsString.length - range.location
                    }
                    
                    var (urlString, concealed) = parseUrl(url: url, wasConcealed: false)
                    var parsedUrl = URL(string: urlString)
                    if (parsedUrl == nil || parsedUrl!.host == nil || parsedUrl!.host!.isEmpty) && !urlString.contains("@") {
                        urlString = "http://" + urlString
                        parsedUrl = URL(string: urlString)
                    }
                    let host: String? = concealed ? urlString : parsedUrl?.host
                    if let _ = parsedUrl, let _ = host {
                        primaryUrl = urlString
                    }
                    break loop
                default:
                    break
                }
            }
        }
    }
    return primaryUrl
}

private let asciiChars = CharacterSet(charactersIn: "a".unicodeScalars.first! ... "z".unicodeScalars.first!)

func getDisplayUrl(_ url: String, hostOnly: Bool = false, trim: Bool = true) -> String {
    if hostOnly {
        var title = url
        if let parsedUrl = URL(string: url) {
            title = parsedUrl.host ?? url
            if title.hasPrefix("www.") {
                title.removeSubrange(title.startIndex ..< title.index(title.startIndex, offsetBy: 4))
            }
            if let decoded = title.idnaDecoded, title != decoded {
                if decoded.lowercased().rangeOfCharacter(from: asciiChars) == nil {
                    title = decoded
                }
            }
        }
        return title
    } else {
        var address = url
        if let components = URLComponents(string: address) {
            if #available(iOS 16.0, *), let encodedHost = components.encodedHost {
                if let decodedHost = components.host, encodedHost != decodedHost {
                    if decodedHost.lowercased().rangeOfCharacter(from: asciiChars) == nil {
                        address = address.replacingOccurrences(of: encodedHost, with: decodedHost)
                    }
                }
            } else if let encodedHost = components.host {
                if let decodedHost = components.host?.idnaDecoded, encodedHost != decodedHost {
                    if decodedHost.lowercased().rangeOfCharacter(from: asciiChars) == nil {
                        address = address.replacingOccurrences(of: encodedHost, with: decodedHost)
                    }
                }
            }
        }
        if trim {
            address = address.replacingOccurrences(of: "https://www.", with: "")
            address = address.replacingOccurrences(of: "https://", with: "")
            address = address.replacingOccurrences(of: "tonsite://", with: "")
            address = address.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return address
    }
}
