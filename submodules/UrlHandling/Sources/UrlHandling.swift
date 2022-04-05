import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import MtProtoKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramNotices
import AccountContext

private let baseTelegramMePaths = ["telegram.me", "t.me", "telegram.dog"]
private let baseTelegraPhPaths = [
    "telegra.ph/",
    "te.legra.ph/",
    "graph.org/",
    "t.me/iv?",
    "telegram.org/blog/",
    "telegram.org/tour/"
]

extension ResolvedBotAdminRights {
    init?(_ string: String) {
        var rawValue: UInt32 = 0
        
        let components = string.lowercased().components(separatedBy: "+")
        if components.contains("change_info") {
            rawValue |= ResolvedBotAdminRights.changeInfo.rawValue
        }
        if components.contains("post_messages") {
            rawValue |= ResolvedBotAdminRights.postMessages.rawValue
        }
        if components.contains("delete_messages") {
            rawValue |= ResolvedBotAdminRights.deleteMessages.rawValue
        }
        if components.contains("restrict_members") {
            rawValue |= ResolvedBotAdminRights.restrictMembers.rawValue
        }
        if components.contains("invite_users") {
            rawValue |= ResolvedBotAdminRights.inviteUsers.rawValue
        }
        if components.contains("pin_messages") {
            rawValue |= ResolvedBotAdminRights.pinMessages.rawValue
        }
        if components.contains("promote_members") {
            rawValue |= ResolvedBotAdminRights.promoteMembers.rawValue
        }
        if components.contains("manage_video_chats") {
            rawValue |= ResolvedBotAdminRights.manageVideoChats.rawValue
        }
        if components.contains("manage_chat") {
            rawValue |= ResolvedBotAdminRights.manageChat.rawValue
        }
        if components.contains("anonymous") {
            rawValue |= ResolvedBotAdminRights.canBeAnonymous.rawValue
        }
                
        if rawValue != 0 {
            self.init(rawValue: rawValue)
        } else {
            return nil
        }
    }
}

public enum ParsedInternalPeerUrlParameter {
    case botStart(String)
    case groupBotStart(String, ResolvedBotAdminRights?)
    case attachBotStart(String, String?)
    case channelMessage(Int32, Double?)
    case replyThread(Int32, Int32)
    case voiceChat(String?)
}

public enum ParsedInternalUrl {
    case peerName(String, ParsedInternalPeerUrlParameter?)
    case peerId(PeerId)
    case privateMessage(messageId: MessageId, threadId: Int32?, timecode: Double?)
    case stickerPack(String)
    case join(String)
    case localization(String)
    case proxy(host: String, port: Int32, username: String?, password: String?, secret: Data?)
    case internalInstantView(url: String)
    case confirmationCode(Int)
    case cancelAccountReset(phone: String, hash: String)
    case share(url: String?, text: String?, to: String?)
    case wallpaper(WallpaperUrlParameter)
    case theme(String)
    case phone(String, String?, String?)
    case startAttach(String, String?)
}

private enum ParsedUrl {
    case externalUrl(String)
    case internalUrl(ParsedInternalUrl)
}

public func parseInternalUrl(query: String) -> ParsedInternalUrl? {
    var query = query
    if query.hasPrefix("s/") {
        query = String(query[query.index(query.startIndex, offsetBy: 2)...])
    }
    if query.hasSuffix("/") {
        query.removeLast()
    }
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
                                        let parsedSecret = MTProxySecret.parse(value)
                                        if let parsedSecret = parsedSecret {
                                            secret = parsedSecret.serialize()
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
                    } else if peerName == "login" {
                        var code: String?
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "code" {
                                    code = value
                                }
                            }
                        }
                        if let code = code, let codeValue = Int(code) {
                            return .confirmationCode(codeValue)
                        }
                    } else if peerName == "confirmphone" {
                        var phone: String?
                        var hash: String?
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "phone" {
                                    phone = value
                                } else if queryItem.name == "hash" {
                                    hash = value
                                }
                            }
                        }
                        if let phone = phone, let hash = hash {
                            return .cancelAccountReset(phone: phone, hash: hash)
                        }
                    } else {
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "attach" {
                                    var startAttach: String?
                                    for queryItem in queryItems {
                                        if queryItem.name == "startattach", let value = queryItem.value {
                                            startAttach = value
                                            break
                                        }
                                    }
                                    return .peerName(peerName, .attachBotStart(value, startAttach))
                                } else if queryItem.name == "start" {
                                    return .peerName(peerName, .botStart(value))
                                } else if queryItem.name == "startgroup" {
                                    var botAdminRights: ResolvedBotAdminRights?
                                    for queryItem in queryItems {
                                        if queryItem.name == "admin", let value = queryItem.value {
                                            botAdminRights = ResolvedBotAdminRights(value)
                                            break
                                        }
                                    }
                                    return .peerName(peerName, .groupBotStart(value, botAdminRights))
                                } else if queryItem.name == "game" {
                                    return nil
                                } else if ["voicechat", "videochat", "livestream"].contains(queryItem.name) {
                                    return .peerName(peerName, .voiceChat(value))
                                } else if queryItem.name == "startattach" {
                                    return .startAttach(peerName, value)
                                }
                            } else if ["voicechat", "videochat", "livestream"].contains(queryItem.name)  {
                                return .peerName(peerName, .voiceChat(nil))
                            } else if queryItem.name == "startattach" {
                                return .startAttach(peerName, nil)
                            }
                        }
                    }
                } else if pathComponents[0].hasPrefix(phonebookUsernamePathPrefix), let idValue = Int64(String(pathComponents[0][pathComponents[0].index(pathComponents[0].startIndex, offsetBy: phonebookUsernamePathPrefix.count)...])) {
                    return .peerId(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(idValue)))
                } else if pathComponents[0].hasPrefix("+") || pathComponents[0].hasPrefix("%20") {
                    let component = pathComponents[0].replacingOccurrences(of: "%20", with: "+")
                    if component.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789+").inverted) == nil {
                        var attach: String?
                        var startAttach: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "attach" {
                                        attach = value
                                    } else if queryItem.name == "startattach" {
                                        startAttach = value
                                    }
                                }
                            }
                        }
                        
                        return .phone(component.replacingOccurrences(of: "+", with: ""), attach, startAttach)
                    } else {
                        return .join(String(component.dropFirst()))
                    }
                }
                return .peerName(peerName, nil)
            } else if pathComponents.count == 2 || pathComponents.count == 3 {
                if pathComponents[0] == "addstickers" {
                    return .stickerPack(pathComponents[1])
                } else if pathComponents[0] == "joinchat" || pathComponents[0] == "joinchannel" {
                    return .join(pathComponents[1])
                } else if pathComponents[0] == "setlanguage" {
                    return .localization(pathComponents[1])
                } else if pathComponents[0] == "login" {
                    if let code = Int(pathComponents[1]) {
                        return .confirmationCode(code)
                    }
                } else if pathComponents[0] == "share" && pathComponents[1] == "url" {
                    if let queryItems = components.queryItems {
                        var url: String?
                        var text: String?
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "url" {
                                    url = value
                                } else if queryItem.name == "text" {
                                    text = value
                                }
                            }
                        }
                        
                        if let url = url {
                            return .share(url: url, text: text, to: nil)
                        }
                    }
                    return nil
                } else if pathComponents[0] == "bg" {
                    let component = pathComponents[1]
                    let parameter: WallpaperUrlParameter
                    if [6, 8].contains(component.count), component.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil, let color = UIColor(hexString: component) {
                        parameter = .color(color)
                    } else if [13, 15, 17].contains(component.count), component.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF-~").inverted) == nil {
                        var rotation: Int32?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "rotation" {
                                        rotation = Int32(value)
                                    }
                                }
                            }
                        }
                        if component.contains("~") {
                            let components = component.components(separatedBy: "~")

                            var colors: [UInt32] = []
                            if components.count >= 2 && components.count <= 4 {
                                colors = components.compactMap { component in
                                    return UIColor(hexString: component)?.rgb
                                }
                            }

                            if !colors.isEmpty {
                                parameter = .gradient(colors, rotation)
                            } else {
                                return nil
                            }
                        } else {
                            let components = component.components(separatedBy: "-")
                            if components.count == 2, let topColor = UIColor(hexString: components[0]), let bottomColor = UIColor(hexString: components[1])  {
                                parameter = .gradient([topColor.rgb, bottomColor.rgb], rotation)
                            } else {
                                return nil
                            }
                        }
                    } else if component.contains("~") {
                        let components = component.components(separatedBy: "~")
                        if components.count >= 1 && components.count <= 4 {
                            let colors = components.compactMap { component in
                                return UIColor(hexString: component)?.rgb
                            }
                            parameter = .gradient(colors, nil)
                        } else {
                            parameter = .color(UIColor(rgb: 0xffffff))
                        }
                    } else {
                        var options: WallpaperPresentationOptions = []
                        var intensity: Int32?
                        var colors: [UInt32] = []
                        var rotation: Int32?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "mode" {
                                        for option in value.components(separatedBy: "+") {
                                            switch option.lowercased() {
                                                case "motion":
                                                    options.insert(.motion)
                                                case "blur":
                                                    options.insert(.blur)
                                                default:
                                                    break
                                            }
                                        }
                                    } else if queryItem.name == "bg_color" {
                                        if [6, 8].contains(value.count), value.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil, let color = UIColor(hexString: value) {
                                            colors = [color.rgb]
                                        } else if [13, 15, 17].contains(value.count), value.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF-").inverted) == nil {
                                            let components = value.components(separatedBy: "-")
                                            if components.count == 2, let topColorValue = UIColor(hexString: components[0]), let bottomColorValue = UIColor(hexString: components[1]) {
                                                colors = [topColorValue.rgb, bottomColorValue.rgb]
                                            }
                                        } else if value.contains("~") {
                                            let components = value.components(separatedBy: "~")
                                            if components.count >= 2 && components.count <= 4 {
                                                colors = components.compactMap { component in
                                                    return UIColor(hexString: component)?.rgb
                                                }
                                            }
                                        }
                                    } else if queryItem.name == "intensity" {
                                        intensity = Int32(value)
                                    } else if queryItem.name == "rotation" {
                                        rotation = Int32(value)
                                    }
                                }
                            }
                        }
                        parameter = .slug(component, options, colors, intensity, rotation)
                    }
                    return .wallpaper(parameter)
                } else if pathComponents[0] == "addtheme" {
                    return .theme(pathComponents[1])
                } else if pathComponents.count == 3 && pathComponents[0] == "c" {
                    if let channelId = Int64(pathComponents[1]), let messageId = Int32(pathComponents[2]) {
                        var threadId: Int32?
                        var timecode: Double?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "thread" {
                                        if let intValue = Int32(value) {
                                            threadId = intValue
                                        }
                                    } else if queryItem.name == "t" {
                                        if let doubleValue = Double(value) {
                                            timecode = doubleValue
                                        }
                                    }
                                }
                            }
                        }
                        return .privateMessage(messageId: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, id: messageId), threadId: threadId, timecode: timecode)
                    } else {
                        return nil
                    }
                } else if let value = Int32(pathComponents[1]) {
                    var threadId: Int32?
                    var commentId: Int32?
                    var timecode: Double?
                    if let queryItems = components.queryItems {
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "thread" {
                                    if let intValue = Int32(value) {
                                        threadId = intValue
                                    }
                                } else if queryItem.name == "comment" {
                                    if let intValue = Int32(value) {
                                        commentId = intValue
                                    }
                                } else if queryItem.name == "t" {
                                    if let doubleValue = Double(value) {
                                        timecode = doubleValue
                                    }
                                }
                            }
                        }
                    }
                    if let threadId = threadId {
                        return .peerName(peerName, .replyThread(threadId, value))
                    } else if let commentId = commentId {
                        return .peerName(peerName, .replyThread(value, commentId))
                    } else {
                        return .peerName(peerName, .channelMessage(value, timecode))
                    }
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

private func resolveInternalUrl(context: AccountContext, url: ParsedInternalUrl) -> Signal<ResolvedUrl?, NoError> {
    switch url {
        case let .phone(phone, attach, startAttach):
            return context.engine.peers.resolvePeerByPhone(phone: phone)
            |> take(1)
            |> mapToSignal { peer -> Signal<ResolvedUrl?, NoError> in
                if let peer = peer?._asPeer() {
                    if let attach = attach {
                        return context.engine.peers.resolvePeerByName(name: attach)
                        |> take(1)
                        |> map { botPeer -> ResolvedUrl? in
                            if let botPeer = botPeer?._asPeer() {
                                return .peer(peer.id, .withAttachBot(ChatControllerInitialAttachBotStart(botId: botPeer.id, payload: startAttach)))
                            } else {
                                return .peer(peer.id, .chat(textInputState: nil, subject: nil, peekData: nil))
                            }
                        }
                    } else {
                        return .single(.peer(peer.id, .chat(textInputState: nil, subject: nil, peekData: nil)))
                    }
                } else {
                    return .single(.peer(nil, .info))
                }
            }
        case let .peerName(name, parameter):
            return context.engine.peers.resolvePeerByName(name: name)
            |> take(1)
            |> mapToSignal { peer -> Signal<Peer?, NoError> in
                return .single(peer?._asPeer())
            }
            |> mapToSignal { peer -> Signal<ResolvedUrl?, NoError> in
                if let peer = peer {
                    if let parameter = parameter {
                        switch parameter {
                            case let .botStart(payload):
                                return .single(.botStart(peerId: peer.id, payload: payload))
                            case let .groupBotStart(payload, adminRights):
                                return .single(.groupBotStart(peerId: peer.id, payload: payload, adminRights: adminRights))
                            case let .attachBotStart(name, payload):
                                return context.engine.peers.resolvePeerByName(name: name)
                                |> take(1)
                                |> mapToSignal { botPeer -> Signal<Peer?, NoError> in
                                    return .single(botPeer?._asPeer())
                                }
                                |> mapToSignal { botPeer -> Signal<ResolvedUrl?, NoError> in
                                    if let botPeer = botPeer {
                                        return .single(.peer(peer.id, .withAttachBot(ChatControllerInitialAttachBotStart(botId: botPeer.id, payload: payload))))
                                    } else {
                                        return .single(.peer(peer.id, .chat(textInputState: nil, subject: nil, peekData: nil)))
                                    }
                                }
                            case let .channelMessage(id, timecode):
                                return .single(.channelMessage(peerId: peer.id, messageId: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: id), timecode: timecode))
                            case let .replyThread(id, replyId):
                                let replyThreadMessageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: id)
                                return context.engine.messages.fetchChannelReplyThreadMessage(messageId: replyThreadMessageId, atMessageId: nil)
                                |> map(Optional.init)
                                |> `catch` { _ -> Signal<ChatReplyThreadMessage?, NoError> in
                                    return .single(nil)
                                }
                                |> map { result -> ResolvedUrl? in
                                    guard let result = result else {
                                        return .channelMessage(peerId: peer.id, messageId: replyThreadMessageId, timecode: nil)
                                    }
                                    return .replyThreadMessage(replyThreadMessage: result, messageId: MessageId(peerId: result.messageId.peerId, namespace: Namespaces.Message.Cloud, id: replyId))
                                }
                            case let .voiceChat(invite):
                                return .single(.joinVoiceChat(peer.id, invite))
                        }
                    } else {
                        return .single(.peer(peer.id, .chat(textInputState: nil, subject: nil, peekData: nil)))
                    }
                } else {
                    return .single(.peer(nil, .info))
                }
            }
        case let .peerId(peerId):
            return context.account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
            }
            |> mapToSignal { peer -> Signal<ResolvedUrl?, NoError> in
                if let peer = peer {
                    return .single(.peer(peer.id, .chat(textInputState: nil, subject: nil, peekData: nil)))
                } else {
                    return .single(.inaccessiblePeer)
                }
            }
        case let .privateMessage(messageId, threadId, timecode):
            return context.account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(messageId.peerId)
            }
            |> mapToSignal { peer -> Signal<ResolvedUrl?, NoError> in
                let foundPeer: Signal<Peer?, NoError>
                if let peer = peer {
                    foundPeer = .single(peer)
                } else {
                    foundPeer = TelegramEngine(account: context.account).peers.findChannelById(channelId: messageId.peerId.id._internalGetInt64Value())
                }
                return foundPeer
                |> mapToSignal { foundPeer -> Signal<ResolvedUrl?, NoError> in
                    if let foundPeer = foundPeer {
                        if let threadId = threadId {
                            let replyThreadMessageId = MessageId(peerId: foundPeer.id, namespace: Namespaces.Message.Cloud, id: threadId)
                            return context.engine.messages.fetchChannelReplyThreadMessage(messageId: replyThreadMessageId, atMessageId: nil)
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<ChatReplyThreadMessage?, NoError> in
                                return .single(nil)
                            }
                            |> map { result -> ResolvedUrl? in
                                guard let result = result else {
                                    return .channelMessage(peerId: foundPeer.id, messageId: replyThreadMessageId, timecode: timecode)
                                }
                                return .replyThreadMessage(replyThreadMessage: result, messageId: messageId)
                            }
                        } else {
                            return .single(.peer(foundPeer.id, .chat(textInputState: nil, subject: .message(id: .id(messageId), highlight: true, timecode: timecode), peekData: nil)))
                        }
                    } else {
                        return .single(.inaccessiblePeer)
                    }
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
            return resolveInstantViewUrl(account: context.account, url: url)
            |> map(Optional.init)
        case let .confirmationCode(code):
            return .single(.confirmationCode(code))
        case let .cancelAccountReset(phone, hash):
            return .single(.cancelAccountReset(phone: phone, hash: hash))
        case let .share(url, text, to):
            return .single(.share(url: url, text: text, to: to))
        case let .wallpaper(parameter):
            return .single(.wallpaper(parameter))
        case let .theme(slug):
            return .single(.theme(slug))
        case let .startAttach(name, payload):
            return context.engine.peers.resolvePeerByName(name: name)
            |> take(1)
            |> mapToSignal { peer -> Signal<Peer?, NoError> in
                return .single(peer?._asPeer())
            }
            |> mapToSignal { peer -> Signal<ResolvedUrl?, NoError> in
                if let peer = peer {
                    return .single(.startAttach(peerId: peer.id, payload: payload))
                } else {
                    return .single(.inaccessiblePeer)
                }
            }
    }
}

public func isTelegramMeLink(_ url: String) -> Bool {
    let schemes = ["http://", "https://", ""]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                return true
            }
        }
    }
    return false
}

public func isTelegraPhLink(_ url: String) -> Bool {
    let schemes = ["http://", "https://", ""]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                return true
            }
        }
    }
    return false
}

public func parseProxyUrl(_ url: String) -> (host: String, port: Int32, username: String?, password: String?, secret: Data?)? {
    let schemes = ["http://", "https://", ""]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                if let internalUrl = parseInternalUrl(query: String(url[basePrefix.endIndex...])), case let .proxy(host, port, username, password, secret) = internalUrl {
                    return (host, port, username, password, secret)
                }
            }
        }
    }
    if let parsedUrl = URL(string: url), parsedUrl.scheme == "tg", let host = parsedUrl.host, let query = parsedUrl.query {
        if let internalUrl = parseInternalUrl(query: host + "?" + query), case let .proxy(host, port, username, password, secret) = internalUrl {
            return (host, port, username, password, secret)
        }
    }
    
    return nil
}

public func parseStickerPackUrl(_ url: String) -> String? {
    let schemes = ["http://", "https://", ""]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                if let internalUrl = parseInternalUrl(query: String(url[basePrefix.endIndex...])), case let .stickerPack(name) = internalUrl {
                    return name
                }
            }
        }
    }
    if let parsedUrl = URL(string: url), parsedUrl.scheme == "tg", let host = parsedUrl.host, let query = parsedUrl.query {
        if let internalUrl = parseInternalUrl(query: host + "?" + query), case let .stickerPack(name) = internalUrl {
            return name
        }
    }
    
    return nil
}

public func parseWallpaperUrl(_ url: String) -> WallpaperUrlParameter? {
    let schemes = ["http://", "https://", ""]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                if let internalUrl = parseInternalUrl(query: String(url[basePrefix.endIndex...])), case let .wallpaper(wallpaper) = internalUrl {
                    return wallpaper
                }
            }
        }
    }
    if let parsedUrl = URL(string: url), parsedUrl.scheme == "tg", let host = parsedUrl.host, let query = parsedUrl.query {
        if let internalUrl = parseInternalUrl(query: host + "?" + query), case let .wallpaper(wallpaper) = internalUrl {
            return wallpaper
        }
    }
    
    return nil
}

private struct UrlHandlingConfiguration {
    static var defaultValue: UrlHandlingConfiguration {
        return UrlHandlingConfiguration(token: nil, domains: [], urlAuthDomains: [])
    }
    
    public let token: String?
    public let domains: [String]
    public let urlAuthDomains: [String]
    
    fileprivate init(token: String?, domains: [String], urlAuthDomains: [String]) {
        self.token = token
        self.domains = domains
        self.urlAuthDomains = urlAuthDomains
    }
    
    static func with(appConfiguration: AppConfiguration) -> UrlHandlingConfiguration {
        if let data = appConfiguration.data {
            let urlAuthDomains = data["url_auth_domains"] as? [String] ?? []
            if let token = data["autologin_token"] as? String, let domains = data["autologin_domains"] as? [String] {
                return UrlHandlingConfiguration(token: token, domains: domains, urlAuthDomains: urlAuthDomains)
            }
        }
        return .defaultValue
    }
}

public func resolveUrlImpl(context: AccountContext, peerId: PeerId?, url: String, skipUrlAuth: Bool) -> Signal<ResolvedUrl, NoError> {
    let schemes = ["http://", "https://", ""]
    
    return ApplicationSpecificNotice.getSecretChatLinkPreviews(accountManager: context.sharedContext.accountManager)
    |> mapToSignal { linkPreviews -> Signal<ResolvedUrl, NoError> in
        return context.account.postbox.transaction { transaction -> Signal<ResolvedUrl, NoError> in
            let appConfiguration: AppConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
            let urlHandlingConfiguration = UrlHandlingConfiguration.with(appConfiguration: appConfiguration)
            
            var skipUrlAuth = skipUrlAuth
            if let peerId = peerId, peerId.namespace == Namespaces.Peer.SecretChat {
                if let linkPreviews = linkPreviews, linkPreviews {
                } else {
                    skipUrlAuth = true
                }
            }
            
            var url = url
            if !url.contains("://") && !url.hasPrefix("tel:") && !url.hasPrefix("mailto:") && !url.hasPrefix("calshow:") {
                if !(url.hasPrefix("http") || url.hasPrefix("https")) {
                    url = "http://\(url)"
                }
            }
            
            if let urlValue = URL(string: url), let host = urlValue.host?.lowercased() {
                if urlHandlingConfiguration.domains.contains(host), var components = URLComponents(string: url) {
                    components.scheme = "https"
                    var queryItems = components.queryItems ?? []
                    queryItems.append(URLQueryItem(name: "autologin_token", value: urlHandlingConfiguration.token))
                    components.queryItems = queryItems
                    url = components.url?.absoluteString ?? url
                } else if !skipUrlAuth && urlHandlingConfiguration.urlAuthDomains.contains(host) {
                    return .single(.urlAuth(url))
                }
            }
            
            for basePath in baseTelegramMePaths {
                for scheme in schemes {
                    let basePrefix = scheme + basePath + "/"
                    if url.lowercased().hasPrefix(basePrefix) {
                        if let internalUrl = parseInternalUrl(query: String(url[basePrefix.endIndex...])) {
                            return resolveInternalUrl(context: context, url: internalUrl)
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
            for basePath in baseTelegraPhPaths {
                for scheme in schemes {
                    let basePrefix = scheme + basePath
                    if url.lowercased().hasPrefix(basePrefix) {
                        return resolveInstantViewUrl(account: context.account, url: url)
                    }
                }
            }
            return .single(.externalUrl(url))
        } |> switchToLatest
    }
}

public func resolveInstantViewUrl(account: Account, url: String) -> Signal<ResolvedUrl, NoError> {
    return webpagePreview(account: account, url: url)
    |> mapToSignal { webpage -> Signal<ResolvedUrl, NoError> in
        if let webpage = webpage {
            if case let .Loaded(content) = webpage.content {
                if content.instantPage != nil {
                    var anchorValue: String?
                    if let anchorRange = url.range(of: "#") {
                        let anchor = url[anchorRange.upperBound...]
                        if !anchor.isEmpty {
                            anchorValue = String(anchor)
                        }
                    }
                    return .single(.instantView(webpage, anchorValue))
                } else {
                    return .single(.externalUrl(url))
                }
            } else {
                return .complete()
            }
        } else {
            return .single(.externalUrl(url))
        }
    }
}
