import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import MtProtoKitDynamic

private enum ParsedInternalPeerUrlParameter {
    case botStart(String)
    case groupBotStart(String)
    case channelMessage(Int32)
}

private enum ParsedInternalUrl {
    case peerName(String, ParsedInternalPeerUrlParameter?)
    case stickerPack(String)
    case join(String)
    case localization(String)
    case proxy(host: String, port: Int32, username: String?, password: String?, secret: Data?)
    case internalInstantView(url: String)
}

private enum ParsedUrl {
    case externalUrl(String)
    case internalUrl(ParsedInternalUrl)
}

enum ResolvedUrl {
    case externalUrl(String)
    case peer(PeerId?, ChatControllerInteractionNavigateToPeer)
    case botStart(peerId: PeerId, payload: String)
    case groupBotStart(peerId: PeerId, payload: String)
    case channelMessage(peerId: PeerId, messageId: MessageId)
    case stickerPack(name: String)
    case instantView(TelegramMediaWebpage, String?)
    case proxy(host: String, port: Int32, username: String?, password: String?, secret: Data?)
    case join(String)
    case localization(String)
}

private func parseInternalUrl(query: String) -> ParsedInternalUrl? {
    if let components = URLComponents(string: "/" + query) {
        var pathComponents = components.path.components(separatedBy: "/")
        if !pathComponents.isEmpty {
            pathComponents.removeFirst()
        }
        if !pathComponents.isEmpty && !pathComponents[0].isEmpty {
            let peerName: String = pathComponents[0]
            if pathComponents.count == 1 {
                if let queryItems = components.queryItems {
                    if peerName == "socks" || peerName == "proxy" {
                        var server: String?
                        var port: String?
                        var user: String?
                        var pass: String?
                        var secret: Data?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "server" || queryItem.name == "proxy" {
                                        server = value
                                    } else if queryItem.name == "port" {
                                        port = value
                                    } else if queryItem.name == "user" {
                                        user = value
                                    } else if queryItem.name == "pass" {
                                        pass = value
                                    } else if queryItem.name == "secret" {
                                        let data = dataWithHexString(value)
                                        if data.count == 16 || (data.count == 17 && MTSocksProxySettings.secretSupportsExtendedPadding(data)) {
                                            secret = data
                                        }
                                    }
                                }
                            }
                        }
                        
                        if let server = server, !server.isEmpty, let port = port, let portValue = Int32(port) {
                            return .proxy(host: server, port: portValue, username: user, password: pass, secret: secret)
                        }
                    } else if peerName == "iv" {
                        var url: String?
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "url" {
                                    url = value
                                }
                            }
                        }
                        if let _ = url {
                            return .internalInstantView(url: "https://t.me/\(query)")
                        }
                    } else {
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "start" {
                                    return .peerName(peerName, .botStart(value))
                                } else if queryItem.name == "startgroup" {
                                    return .peerName(peerName, .groupBotStart(value))
                                } else if queryItem.name == "game" {
                                    return nil
                                }
                            }
                        }
                    }
                }
                return .peerName(peerName, nil)
            } else if pathComponents.count == 2 {
                if pathComponents[0] == "addstickers" {
                    return .stickerPack(pathComponents[1])
                } else if pathComponents[0] == "joinchat" || pathComponents[0] == "joinchannel" {
                    return .join(pathComponents[1])
                } else if pathComponents[0] == "setlanguage" {
                    return .localization(pathComponents[1])
                } else if let value = Int(pathComponents[1]) {
                    return .peerName(peerName, .channelMessage(Int32(value)))
                } else {
                    return nil
                }
            }
        } else {
            return nil
        }
    }
    return nil
}

private func resolveInternalUrl(account: Account, url: ParsedInternalUrl) -> Signal<ResolvedUrl?, NoError> {
    switch url {
        case let .peerName(name, parameter):
            return resolvePeerByName(account: account, name: name)
            |> take(1)
            |> map { peerId -> ResolvedUrl? in
                if let peerId = peerId {
                    if let parameter = parameter {
                        switch parameter {
                            case let .botStart(payload):
                                return .botStart(peerId: peerId, payload: payload)
                            case let .groupBotStart(payload):
                                return .groupBotStart(peerId: peerId, payload: payload)
                            case let .channelMessage(id):
                                return .channelMessage(peerId: peerId, messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id))
                        }
                    } else {
                        return .peer(peerId, .chat(textInputState: nil, messageId: nil))
                    }
                } else {
                    return nil
                }
            }
        case let .stickerPack(name):
            return .single(.stickerPack(name: name))
        case let .join(link):
            return .single(.join(link))
        case let .localization(identifier):
            return .single(.localization(identifier))
        case let .proxy(host, port, username, password, secret):
            return .single(.proxy(host: host, port: port, username: username, password: password, secret: secret))
        case let .internalInstantView(url):
            return resolveInstantViewUrl(account: account, url: url)
            |> map(Optional.init)
    }
}

func parseProxyUrl(_ url: String) -> (host: String, port: Int32, username: String?, password: String?, secret: Data?)? {
    let schemes = ["http://", "https://", ""]
    let baseTelegramMePaths = ["telegram.me", "t.me"]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                if let internalUrl = parseInternalUrl(query: String(url[basePrefix.endIndex...])), case let .proxy(proxy) = internalUrl {
                    return (proxy.host, proxy.port, proxy.username, proxy.password, proxy.secret)
                }
            }
        }
    }
    if let parsedUrl = URL(string: url), parsedUrl.scheme == "tg", let host = parsedUrl.host, let query = parsedUrl.query {
        if let internalUrl = parseInternalUrl(query: host + "?" + query), case let .proxy(proxy) = internalUrl {
            return (proxy.host, proxy.port, proxy.username, proxy.password, proxy.secret)
        }
    }
    
    return nil
}

func resolveUrl(account: Account, url: String) -> Signal<ResolvedUrl, NoError> {
    let schemes = ["http://", "https://", ""]
    let baseTelegramMePaths = ["telegram.me", "t.me"]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                if let internalUrl = parseInternalUrl(query: String(url[basePrefix.endIndex...])) {
                    return resolveInternalUrl(account: account, url: internalUrl)
                    |> map { resolved -> ResolvedUrl in
                        if let resolved = resolved {
                            return resolved
                        } else {
                            return .externalUrl(url)
                        }
                    }
                } else {
                    return .single(.externalUrl(url))
                }
            }
        }
    }
    let baseTelegraPhPaths = ["telegra.ph"]
    for basePath in baseTelegraPhPaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                return resolveInstantViewUrl(account: account, url: url)
            }
        }
    }
    return .single(.externalUrl(url))
}

func resolveInstantViewUrl(account: Account, url: String) -> Signal<ResolvedUrl, NoError> {
    return webpagePreview(account: account, url: url)
    |> map { webpage -> ResolvedUrl in
        if let webpage = webpage, case let .Loaded(content) = webpage.content, content.instantPage != nil {
            var anchorValue: String?
            if let anchorRange = url.range(of: "#") {
                let anchor = url[anchorRange.upperBound...]
                if !anchor.isEmpty {
                    anchorValue = String(anchor)
                }
            }
            return .instantView(webpage, anchorValue)
        } else {
            return .externalUrl(url)
        }
    }
}

/*private final class SafariLegacyPresentedController: LegacyPresentedController, SFSafariViewControllerDelegate {
    @available(iOSApplicationExtension 9.0, *)
    init(legacyController: SFSafariViewController) {
        super.init(legacyController: legacyController, presentation: .custom)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @available(iOSApplicationExtension 9.0, *)
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        self.dismiss()
    }
}*/
