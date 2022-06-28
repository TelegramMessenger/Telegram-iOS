import Foundation
import Display
import SafariServices
import TelegramCore
import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import UrlEscaping
import PassportUI
import UrlHandling
import OpenInExternalAppUI
import BrowserUI
import OverlayStatusController
import PresentationDataUtils

public struct ParsedSecureIdUrl {
    public let peerId: PeerId
    public let scope: String
    public let publicKey: String
    public let callbackUrl: String
    public let opaquePayload: Data
    public let opaqueNonce: Data
}

public func parseProxyUrl(_ url: URL) -> ProxyServerSettings? {
    guard let proxy = parseProxyUrl(url.absoluteString) else {
        return nil
    }
    if let secret = proxy.secret, let _ = MTProxySecret.parseData(secret) {
        return ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .mtp(secret: secret))
    } else {
        return ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .socks5(username: proxy.username, password: proxy.password))
    }
}

public func parseSecureIdUrl(_ url: URL) -> ParsedSecureIdUrl? {
    guard let query = url.query else {
        return nil
    }
    
    if url.host == "passport" || url.host == "resolve" {
        if let components = URLComponents(string: "/?" + query) {
            var domain: String?
            var botId: Int64?
            var scope: String?
            var publicKey: String?
            var callbackUrl: String?
            var opaquePayload = Data()
            var opaqueNonce = Data()
            if let queryItems = components.queryItems {
                for queryItem in queryItems {
                    if let value = queryItem.value {
                        if queryItem.name == "domain" {
                            domain = value
                        } else if queryItem.name == "bot_id" {
                            botId = Int64(value)
                        } else if queryItem.name == "scope" {
                            scope = value
                        } else if queryItem.name == "public_key" {
                            publicKey = value
                        } else if queryItem.name == "callback_url" {
                            callbackUrl = value
                        } else if queryItem.name == "payload" {
                            if let data = value.data(using: .utf8) {
                                opaquePayload = data
                            }
                        } else if queryItem.name == "nonce" {
                            if let data = value.data(using: .utf8) {
                                opaqueNonce = data
                            }
                        }
                    }
                }
            }
            
            let valid: Bool
            if url.host == "resolve" {
                if domain == "telegrampassport" {
                    valid = true
                } else {
                    valid = false
                }
            } else {
                valid = true
            }
            
            if valid {
                if let botId = botId, let scope = scope, let publicKey = publicKey, let callbackUrl = callbackUrl {
                    if scope.hasPrefix("{") && scope.hasSuffix("}") {
                        opaquePayload = Data()
                        if opaqueNonce.isEmpty {
                            return nil
                        }
                    } else if opaquePayload.isEmpty {
                        return nil
                    }
                    
                    return ParsedSecureIdUrl(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)), scope: scope, publicKey: publicKey, callbackUrl: callbackUrl, opaquePayload: opaquePayload, opaqueNonce: opaqueNonce)
                }
            }
        }
    }
    
    return nil
}

public func parseConfirmationCodeUrl(_ url: URL) -> Int? {
    if url.pathComponents.count == 3 && url.pathComponents[1].lowercased() == "login" {
        if let code = Int(url.pathComponents[2]) {
            return code
        }
    }
    if url.scheme == "tg" {
        if let host = url.host, let query = url.query, let parsedUrl = parseInternalUrl(query: host + "?" + query) {
            switch parsedUrl {
                case let .confirmationCode(code):
                    return code
                default:
                    break
            }
        }
    }
    return nil
}

func formattedConfirmationCode(_ code: Int) -> String {
    let source = "\(code)"
    let segmentLength = 3
    var result = ""
    for c in source {
        if !result.isEmpty && result.count % segmentLength == 0 {
            result.append("-")
        }
        result.append(c)
    }
    return result
}

func openExternalUrlImpl(context: AccountContext, urlContext: OpenURLContext, url: String, forceExternal: Bool, presentationData: PresentationData, navigationController: NavigationController?, dismissInput: @escaping () -> Void) {
    if forceExternal || url.lowercased().hasPrefix("tel:") || url.lowercased().hasPrefix("calshow:") {
        context.sharedContext.applicationBindings.openUrl(url)
        return
    }
    
    var parsedUrlValue: URL?
    var urlWithScheme = url
    if !url.contains("://") && !url.hasPrefix("mailto:") {
        urlWithScheme = "http://" + url
    }
    if let parsed = URL(string: urlWithScheme) {
        parsedUrlValue = parsed
    } else if let encoded = (urlWithScheme as NSString).addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed), let parsed = URL(string: encoded) {
        parsedUrlValue = parsed
    }
    
    if let parsedUrlValue = parsedUrlValue, parsedUrlValue.scheme == "mailto" {
        context.sharedContext.applicationBindings.openUrl(url)
        return
    }
    
    guard let parsedUrl = parsedUrlValue else {
        return
    }
    
    if let host = parsedUrl.host?.lowercased() {
        if host == "itunes.apple.com" {
            if context.sharedContext.applicationBindings.canOpenUrl(parsedUrl.absoluteString) {
                context.sharedContext.applicationBindings.openUrl(url)
                return
            }
        }
        if host == "twitter.com" || host == "mobile.twitter.com" {
            if context.sharedContext.applicationBindings.canOpenUrl("twitter://status") {
                context.sharedContext.applicationBindings.openUrl(url)
                return
            }
        } else if host == "instagram.com" {
            if context.sharedContext.applicationBindings.canOpenUrl("instagram://photo") {
                context.sharedContext.applicationBindings.openUrl(url)
                return
            }
        }
    }
    
    let continueHandling: () -> Void = {
        let handleResolvedUrl: (ResolvedUrl) -> Void = { resolved in
            if case let .externalUrl(value) = resolved {
                context.sharedContext.applicationBindings.openUrl(value)
            } else {
                context.sharedContext.openResolvedUrl(resolved, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, openPeer: { peerId, navigation in
                    switch navigation {
                        case .info:
                            let _ = (context.account.postbox.loadedPeerWithId(peerId)
                            |> deliverOnMainQueue).start(next: { peer in
                                if let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                    context.sharedContext.applicationBindings.dismissNativeController()
                                    navigationController?.pushViewController(infoController)
                                }
                            })
                        case let .chat(_, subject, peekData):
                            context.sharedContext.applicationBindings.dismissNativeController()
                            if let navigationController = navigationController {
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId), subject: subject, peekData: peekData))
                            }
                        case let .withBotStartPayload(payload):
                            context.sharedContext.applicationBindings.dismissNativeController()
                            if let navigationController = navigationController {
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId), botStart: payload))
                            }
                        case let .withAttachBot(attachBotStart):
                            context.sharedContext.applicationBindings.dismissNativeController()
                            if let navigationController = navigationController {
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId), attachBotStart: attachBotStart))
                            }
                        default:
                            break
                    }
                }, sendFile: nil,
                sendSticker: nil,
                requestMessageActionUrlAuth: nil,
                joinVoiceChat: { peerId, invite, call in
                    
                }, present: { c, a in
                    context.sharedContext.applicationBindings.dismissNativeController()
                    
                    c.presentationArguments = a
                    
                    context.sharedContext.applicationBindings.getWindowHost()?.present(c, on: .root, blockInteraction: false, completion: {})
                }, dismissInput: {
                    dismissInput()
                }, contentContext: nil)
            }
        }
        
        let handleInternalUrl: (String) -> Void = { url in
            let _ = (context.sharedContext.resolveUrl(context: context, peerId: nil, url: url, skipUrlAuth: true)
            |> deliverOnMainQueue).start(next: handleResolvedUrl)
        }
        
        if let scheme = parsedUrl.scheme, (scheme == "tg" || scheme == context.sharedContext.applicationBindings.appSpecificScheme) {
            var convertedUrl: String?
            if let query = parsedUrl.query {
                if parsedUrl.host == "localpeer" {
                     if let components = URLComponents(string: "/?" + query) {
                        var peerId: PeerId?
                        var accountId: Int64?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "id", let intValue = Int64(value) {
                                        peerId = PeerId(intValue)
                                    } else if queryItem.name == "accountId", let intValue = Int64(value) {
                                        accountId = intValue
                                    }
                                }
                            }
                        }
                        if let peerId = peerId, let accountId = accountId {
                            context.sharedContext.applicationBindings.dismissNativeController()
                            context.sharedContext.navigateToChat(accountId: AccountRecordId(rawValue: accountId), peerId: peerId, messageId: nil)
                        }
                    }
                } else if parsedUrl.host == "join" {
                    if let components = URLComponents(string: "/?" + query) {
                        var invite: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "invite" {
                                        invite = value
                                    }
                                }
                            }
                        }
                        if let invite = invite {
                            convertedUrl = "https://t.me/joinchat/\(invite)"
                        }
                    }
                } else if parsedUrl.host == "addstickers" {
                    if let components = URLComponents(string: "/?" + query) {
                        var set: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "set" {
                                        set = value
                                    }
                                }
                            }
                        }
                        if let set = set {
                            convertedUrl = "https://t.me/addstickers/\(set)"
                        }
                    }
                } else if parsedUrl.host == "invoice" {
                    if let components = URLComponents(string: "/?" + query) {
                        var slug: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "slug" {
                                        slug = value
                                    }
                                }
                            }
                        }
                        if let slug = slug {
                            convertedUrl = "https://t.me/invoice/\(slug)"
                        }
                    }
                } else if parsedUrl.host == "setlanguage" {
                    if let components = URLComponents(string: "/?" + query) {
                        var lang: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "lang" {
                                        lang = value
                                    }
                                }
                            }
                        }
                        if let lang = lang {
                            convertedUrl = "https://t.me/setlanguage/\(lang)"
                        }
                    }
                } else if parsedUrl.host == "msg" {
                    if let components = URLComponents(string: "/?" + query) {
                        var sharePhoneNumber: String?
                        var shareText: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "to" {
                                        sharePhoneNumber = value
                                    } else if queryItem.name == "text" {
                                        shareText = value
                                    }
                                }
                            }
                        }
                        if sharePhoneNumber != nil || shareText != nil {
                            handleResolvedUrl(.share(url: nil, text: shareText, to: sharePhoneNumber))
                            return
                        }
                    }
                } else if parsedUrl.host == "msg_url" {
                    if let components = URLComponents(string: "/?" + query) {
                        var shareUrl: String?
                        var shareText: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "url" {
                                        shareUrl = value
                                    } else if queryItem.name == "text" {
                                        shareText = value
                                    }
                                }
                            }
                        }
                        if let shareUrl = shareUrl {
                            var resultUrl = "https://t.me/share/url?url=\(urlEncodedStringFromString(shareUrl))"
                            if let shareText = shareText {
                                resultUrl += "&text=\(urlEncodedStringFromString(shareText))"
                            }
                            convertedUrl = resultUrl
                        }
                    }
                } else if parsedUrl.host == "socks" || parsedUrl.host == "proxy" {
                    if let components = URLComponents(string: "/?" + query) {
                        var server: String?
                        var port: String?
                        var user: String?
                        var pass: String?
                        var secret: String?
                        var secretHost: String?
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
                                        secret = value
                                    } else if queryItem.name == "host" {
                                        secretHost = value
                                    }
                                }
                            }
                        }
                        
                        if let server = server, !server.isEmpty, let port = port, let _ = Int32(port) {
                            var result = "https://t.me/proxy?proxy=\(server)&port=\(port)"
                            if let user = user {
                                result += "&user=\((user as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
                                if let pass = pass {
                                    result += "&pass=\((pass as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
                                }
                            }
                            if let secret = secret {
                                result += "&secret=\((secret as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
                            }
                            if let secretHost = secretHost?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) {
                                result += "&host=\(secretHost)"
                            }
                            convertedUrl = result
                        }
                    }
                } else if parsedUrl.host == "passport" || parsedUrl.host == "resolve" {
                    if let components = URLComponents(string: "/?" + query) {
                        var domain: String?
                        var botId: Int64?
                        var scope: String?
                        var publicKey: String?
                        var callbackUrl: String?
                        var opaquePayload = Data()
                        var opaqueNonce = Data()
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "domain" {
                                        domain = value
                                    } else if queryItem.name == "bot_id" {
                                        botId = Int64(value)
                                    } else if queryItem.name == "scope" {
                                        scope = value
                                    } else if queryItem.name == "public_key" {
                                        publicKey = value
                                    } else if queryItem.name == "callback_url" {
                                        callbackUrl = value
                                    } else if queryItem.name == "payload" {
                                        if let data = value.data(using: .utf8) {
                                            opaquePayload = data
                                        }
                                    } else if queryItem.name == "nonce" {
                                        if let data = value.data(using: .utf8) {
                                            opaqueNonce = data
                                        }
                                    }
                                }
                            }
                        }
                        
                        let valid: Bool
                        if parsedUrl.host == "resolve" {
                            if domain == "telegrampassport" {
                                valid = true
                            } else {
                                valid = false
                            }
                        } else {
                            valid = true
                        }
                        
                        if valid {
                            if let botId = botId, let scope = scope, let publicKey = publicKey {
                                if scope.hasPrefix("{") && scope.hasSuffix("}") {
                                    opaquePayload = Data()
                                    if opaqueNonce.isEmpty {
                                        return
                                    }
                                } else if opaquePayload.isEmpty {
                                    return
                                }
                                if case .chat = urlContext {
                                    return
                                }
                                let controller = SecureIdAuthController(context: context, mode: .form(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)), scope: scope, publicKey: publicKey, callbackUrl: callbackUrl, opaquePayload: opaquePayload, opaqueNonce: opaqueNonce))
                                
                                if let navigationController = navigationController {
                                    context.sharedContext.applicationBindings.dismissNativeController()
                                    
                                    navigationController.view.window?.endEditing(true)
                                    context.sharedContext.applicationBindings.getWindowHost()?.present(controller, on: .root, blockInteraction: false, completion: {})
                                }
                            }
                            return
                        }
                    }
                } else if parsedUrl.host == "user" {
                    if let components = URLComponents(string: "/?" + query) {
                        var id: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "id" {
                                        id = value
                                    }
                                }
                            }
                        }
                        
                        if let id = id, !id.isEmpty, let idValue = Int64(id), idValue > 0 {
                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(idValue))))
                            |> deliverOnMainQueue).start(next: { peer in
                                if let peer = peer, let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                    navigationController?.pushViewController(controller)
                                }
                            })
                            return
                        }
                    }
                } else if parsedUrl.host == "login" {
                    if let components = URLComponents(string: "/?" + query) {
                        var code: String?
                        var isToken: Bool = false
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "code" {
                                        code = value
                                    }
                                }
                                if queryItem.name == "token" {
                                    isToken = true
                                }
                            }
                        }
                        if isToken {
                            context.sharedContext.presentGlobalController(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.AuthSessions_AddDevice_UrlLoginHint, actions: [
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                }),
                            ], parseMarkdown: true), nil)
                            return
                        }
                        if let code = code {
                            convertedUrl = "https://t.me/login/\(code)"
                        }
                    }
                } else if parsedUrl.host == "confirmphone" {
                    if let components = URLComponents(string: "/?" + query) {
                        var phone: String?
                        var hash: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "phone" {
                                        phone = value
                                    } else if queryItem.name == "hash" {
                                        hash = value
                                    }
                                }
                            }
                        }
                        if let phone = phone, let hash = hash {
                            convertedUrl = "https://t.me/confirmphone?phone=\(phone)&hash=\(hash)"
                        }
                    }
                } else if parsedUrl.host == "bg" {
                    if let components = URLComponents(string: "/?" + query) {
                        var parameter: String?
                        var query: [String] = []
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "slug" {
                                        parameter = value
                                    } else if queryItem.name == "color" {
                                        parameter = value
                                    } else if queryItem.name == "gradient" {
                                        parameter = value
                                    } else if queryItem.name == "mode" {
                                        query.append("mode=\(value)")
                                    } else if queryItem.name == "bg_color" {
                                        query.append("bg_color=\(value)")
                                    } else if queryItem.name == "intensity" {
                                        query.append("intensity=\(value)")
                                    } else if queryItem.name == "rotation" {
                                        query.append("rotation=\(value)")
                                    }
                                }
                            }
                        }
                        var queryString = ""
                        if !query.isEmpty {
                            queryString = "?\(query.joined(separator: "&"))"
                        }
                        if let parameter = parameter {
                            convertedUrl = "https://t.me/bg/\(parameter)\(queryString)"
                        }
                    }
                } else if parsedUrl.host == "addtheme" {
                    if let components = URLComponents(string: "/?" + query) {
                        var parameter: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "slug" {
                                        parameter = value
                                    }
                                }
                            }
                        }
                        if let parameter = parameter {
                            convertedUrl = "https://t.me/addtheme/\(parameter)"
                        }
                    }
                } else if parsedUrl.host == "privatepost" {
                    if let components = URLComponents(string: "/?" + query) {
                        var channelId: Int64?
                        var postId: Int32?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "channel" {
                                        channelId = Int64(value)
                                    } else if queryItem.name == "post" {
                                        postId = Int32(value)
                                    }
                                }
                            }
                        }
                        if let channelId = channelId, let postId = postId {
                            convertedUrl = "https://t.me/c/\(channelId)/\(postId)"
                        }
                    }
                }
                
                if parsedUrl.host == "resolve" {
                    if let components = URLComponents(string: "/?" + query) {
                        var phone: String?
                        var domain: String?
                        var start: String?
                        var startGroup: String?
                        var admin: String?
                        var game: String?
                        var post: String?
                        var voiceChat: String?
                        var attach: String?
                        var startAttach: String?
                        var choose: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "phone" {
                                        phone = value
                                    } else if queryItem.name == "domain" {
                                        domain = value
                                    } else if queryItem.name == "start" {
                                        start = value
                                    } else if queryItem.name == "startgroup" {
                                        startGroup = value
                                    } else if queryItem.name == "admin" {
                                        admin = value
                                    } else if queryItem.name == "game" {
                                        game = value
                                    } else if queryItem.name == "post" {
                                        post = value
                                    } else if ["voicechat", "videochat", "livestream"].contains(queryItem.name) {
                                        voiceChat = value
                                    } else if queryItem.name == "attach" {
                                        attach = value
                                    } else if queryItem.name == "startattach" {
                                        startAttach = value
                                    } else if queryItem.name == "choose" {
                                        choose = value
                                    }
                                } else if ["voicechat", "videochat", "livestream"].contains(queryItem.name) {
                                    voiceChat = ""
                                } else if queryItem.name == "startattach" {
                                    startAttach = ""
                                }
                            }
                        }
                        
                        if let phone = phone {
                            convertedUrl = "https://t.me/+\(phone)"
                        } else if let domain = domain {
                            var result = "https://t.me/\(domain)"
                            if let post = post, let postValue = Int(post) {
                                result += "/\(postValue)"
                            }
                            if let start = start {
                                result += "?start=\(start)"
                            } else if let startGroup = startGroup {
                                result += "?startgroup=\(startGroup)"
                                if let admin = admin {
                                    result += "&admin=\(admin)"
                                }
                            } else if let game = game {
                                result += "?game=\(game)"
                            } else if let voiceChat = voiceChat {
                                if !voiceChat.isEmpty {
                                    result += "?voicechat=\(voiceChat)"
                                } else {
                                    result += "?voicechat="
                                }
                            } else if let attach = attach {
                                result += "?attach=\(attach)"
                            }
                            if let startAttach = startAttach {
                                if attach == nil {
                                    result += "?"
                                } else {
                                    result += "&"
                                }
                                if !startAttach.isEmpty {
                                    result += "startattach=\(startAttach)"
                                } else {
                                    result += "startattach"
                                }
                                if let choose = choose {
                                    result += "&choose=\(choose)"
                                }
                            }
                            convertedUrl = result
                        }
                    }
                } else if parsedUrl.host == "hostOverride" {
                    if let components = URLComponents(string: "/?" + query) {
                        var host: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "host" {
                                        host = value
                                    }
                                }
                            }
                        }
                        if let host = host {
                            let _ = updateNetworkSettingsInteractively(postbox: context.account.postbox, network: context.account.network, { settings in
                                var settings = settings
                                settings.backupHostOverride = host
                                return settings
                            }).start()
                            return
                        }
                    }
                } else if parsedUrl.host == "premium_offer" {
                    var reference: String?
                    if let components = URLComponents(string: "/?" + query) {
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "ref" {
                                        reference = value
                                    }
                                }
                            }
                        }
                    }
                    handleResolvedUrl(.premiumOffer(reference: reference))
                }
            } else {
                if parsedUrl.host == "importStickers" {
                    handleResolvedUrl(.importStickers)
                } else if parsedUrl.host == "settings" {
                    if let path = parsedUrl.pathComponents.last {
                        var section: ResolvedUrlSettingsSection?
                        switch path {
                            case "themes":
                                section = .theme
                            case "devices":
                                section = .devices
                            default:
                                break
                        }
                        if let section = section {
                            handleResolvedUrl(.settings(section))
                        }
                    }
                } else if parsedUrl.host == "premium_offer" {
                    handleResolvedUrl(.premiumOffer(reference: nil))
                } else if parsedUrl.host == "restore_purchases" {
                    let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                    context.sharedContext.presentGlobalController(statusController, nil)
                    
                    context.inAppPurchaseManager?.restorePurchases(completion: { [weak statusController] result in
                        statusController?.dismiss()
                        
                        let text: String?
                        switch result {
                            case let .succeed(serverProvided):
                                text = serverProvided ? nil : presentationData.strings.Premium_Restore_Success
                            case .failed:
                                text = presentationData.strings.Premium_Restore_ErrorUnknown
                        }
                        if let text = text {
                            let alertController = textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                            context.sharedContext.presentGlobalController(alertController, nil)
                        }
                    })
                }
            }
            
            if let convertedUrl = convertedUrl {
                handleInternalUrl(convertedUrl)
            }
            return
        }
        
        if parsedUrl.scheme == "http" || parsedUrl.scheme == "https" {
            if parsedUrl.host == "t.me" || parsedUrl.host == "telegram.me" {
                handleInternalUrl(parsedUrl.absoluteString)
            } else {
                let settings = combineLatest(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings, ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]), context.sharedContext.accountManager.accessChallengeData())
                |> take(1)
                |> map { sharedData, accessChallengeData -> WebBrowserSettings in
                    let passcodeSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]?.get(PresentationPasscodeSettings.self) ?? PresentationPasscodeSettings.defaultSettings
                    if accessChallengeData.data.isLockable {
                        if passcodeSettings.autolockTimeout != nil {
                            return WebBrowserSettings(defaultWebBrowser: "Safari")
                        }
                    }
                    
                    if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings]?.get(WebBrowserSettings.self) {
                        return current   
                    } else {
                        return WebBrowserSettings.defaultSettings
                    }
                }

                let _ = (settings
                |> deliverOnMainQueue).start(next: { settings in
                    if settings.defaultWebBrowser == nil {
//                        let controller = BrowserScreen(context: context, subject: .webPage(parsedUrl.absoluteString))
//                        navigationController?.pushViewController(controller)
                        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                            if let window = navigationController?.view.window {
                                let controller = SFSafariViewController(url: parsedUrl)
                                if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                                    controller.preferredBarTintColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
                                    controller.preferredControlTintColor = presentationData.theme.rootController.navigationBar.accentTextColor
                                }
                                window.rootViewController?.present(controller, animated: true)
                            } else {
                                context.sharedContext.applicationBindings.openUrl(parsedUrl.absoluteString)
                            }
                        } else {
                            context.sharedContext.applicationBindings.openUrl(url)
                        }
                    } else {
                        let openInOptions = availableOpenInOptions(context: context, item: .url(url: url))
                        if let option = openInOptions.first(where: { $0.identifier == settings.defaultWebBrowser }) {
                            if case let .openUrl(url) = option.action() {
                                context.sharedContext.applicationBindings.openUrl(url)
                            } else {
                                context.sharedContext.applicationBindings.openUrl(url)
                            }
                        } else {
                            context.sharedContext.applicationBindings.openUrl(url)
                        }
                    }
                })
            }
        } else {
            context.sharedContext.applicationBindings.openUrl(url)
        }
    }
    
    if parsedUrl.scheme == "http" || parsedUrl.scheme == "https" {
        let nativeHosts = ["t.me", "telegram.me"]
        if let host = parsedUrl.host, nativeHosts.contains(host) {
            continueHandling()
        } else {
            context.sharedContext.applicationBindings.openUniversalUrl(url, TelegramApplicationOpenUrlCompletion(completion: { success in
                if !success {
                    continueHandling()
                }
            }))
        }
    } else {
        continueHandling()
    }
}
