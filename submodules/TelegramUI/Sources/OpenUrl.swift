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

public func parseProxyUrl(sharedContext: SharedAccountContext, url: URL) -> ProxyServerSettings? {
    guard let proxy = parseProxyUrl(sharedContext: sharedContext, url: url.absoluteString) else {
        return nil
    }
    if let secret = proxy.secret, let _ = MTProxySecret.parseData(secret) {
        return ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .mtp(secret: secret))
    } else {
        return ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .socks5(username: proxy.username, password: proxy.password))
    }
}

public func isOAuthUrl(_ url: URL) -> Bool {
    guard let query = url.query, let params = QueryParameters(query), ["oauth", "resolve"].contains(url.host) else {
        return false
    }
    
    let domain = params["domain"]
    let startApp = params["startapp"]
    let token = params["token"]
    
    var valid = false
    if url.host == "resolve" {
        if domain == "oauth", let _ = startApp {
            valid = true
        }
    } else {
        if let _ = token {
            valid = true
        }
    }
    
    return valid
}

public func parseSecureIdUrl(_ url: URL) -> ParsedSecureIdUrl? {
    guard let query = url.query, let params = QueryParameters(query), ["passport", "resolve"].contains(url.host) else {
        return nil
    }
    
    let domain = params["domain"]
    let botId = params["bot_id"].flatMap(Int64.init)
    let scope = params["scope"]
    let publicKey = params["public_key"]
    let callbackUrl = params["callback_url"]
    var opaquePayload = Data()
    var opaqueNonce = Data()
    if let payloadValue = params["payload"], let data = payloadValue.data(using: .utf8) {
        opaquePayload = data
    }
    if let nonceValue = params["nonce"], let data = nonceValue.data(using: .utf8) {
        opaqueNonce = data
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
    
    return nil
}

public func parseConfirmationCodeUrl(sharedContext: SharedAccountContext, url: URL) -> Int? {
    if url.pathComponents.count == 3 && url.pathComponents[1].lowercased() == "login" {
        if let code = Int(url.pathComponents[2]) {
            return code
        }
    }
    if url.scheme == "tg" {
        if let host = url.host, let query = url.query, let parsedUrl = parseInternalUrl(sharedContext: sharedContext, context: nil, query: host + "?" + query) {
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

private func canonicalExternalUrl(from url: String) -> URL? {
    var urlWithScheme = url
    if !url.contains("://") && !url.hasPrefix("mailto:") {
        urlWithScheme = "http://" + url
    }
    if let parsed = URL(string: urlWithScheme) {
        return parsed
    } else if let encoded = (urlWithScheme as NSString).addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) {
        return URL(string: encoded)
    }
    return nil
}

private func makeResolvedUrlHandler(
    context: AccountContext,
    presentationData: PresentationData,
    navigationController: NavigationController?,
    dismissInput: @escaping () -> Void
) -> (ResolvedUrl) -> Void {
    return { resolved in
        if case let .externalUrl(value) = resolved {
            context.sharedContext.applicationBindings.openUrl(value)
        } else {
            context.sharedContext.openResolvedUrl(
                resolved,
                context: context,
                urlContext: .generic,
                navigationController: navigationController,
                forceExternal: false,
                forceUpdate: false,
                openPeer: { peer, navigation in
                    switch navigation {
                    case .info:
                        if let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                            context.sharedContext.applicationBindings.dismissNativeController()
                            navigationController?.pushViewController(infoController)
                        }
                    case let .chat(textInputState, subject, peekData):
                        context.sharedContext.applicationBindings.dismissNativeController()
                        if let navigationController {
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: subject, updateTextInputState: !peer.id.isGroupOrChannel ? textInputState : nil, peekData: peekData))
                        }
                    case let .withBotStartPayload(payload):
                        context.sharedContext.applicationBindings.dismissNativeController()
                        if let navigationController {
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), botStart: payload))
                        }
                    case let .withAttachBot(attachBotStart):
                        context.sharedContext.applicationBindings.dismissNativeController()
                        if let navigationController {
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), attachBotStart: attachBotStart))
                        }
                    case let .withBotApp(botAppStart):
                        context.sharedContext.applicationBindings.dismissNativeController()
                        if let navigationController {
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), botAppStart: botAppStart))
                        }
                    default:
                        break
                    }
                },
                sendFile: nil,
                sendSticker: nil,
                sendEmoji: nil,
                requestMessageActionUrlAuth: nil,
                joinVoiceChat: { _, _, _ in },
                present: { c, a in
                    context.sharedContext.applicationBindings.dismissNativeController()
                    c.presentationArguments = a
                    context.sharedContext.applicationBindings.getWindowHost()?.present(c, on: .root, blockInteraction: false, completion: {})
                },
                dismissInput: {
                    dismissInput()
                },
                contentContext: nil,
                progress: nil,
                completion: nil
            )
        }
    }
}

private func makeInternalUrlHandler(
    context: AccountContext,
    resolvedHandler: @escaping (ResolvedUrl) -> Void
) -> (String) -> Void {
    return { url in
        let _ = (context.sharedContext.resolveUrl(context: context, peerId: nil, url: url, skipUrlAuth: true)
        |> deliverOnMainQueue).startStandalone(next: resolvedHandler)
    }
}

private let internetSchemes: [String] = ["http", "https"]
private let telegramMeHosts: [String] = ["t.me", "telegram.me", "telegram.dog"]

private func handleInternetUrl(
    parsedUrl: URL,
    originalUrl: String,
    context: AccountContext,
    presentationData: PresentationData,
    navigationController: NavigationController?,
    handleInternalUrl: @escaping (String) -> Void
) {
    let urlScheme = (parsedUrl.scheme ?? "").lowercased()
    var isInternetUrl = false
    if internetSchemes.contains(urlScheme) {
        isInternetUrl = true
    }
    if urlScheme == "tonsite" {
        isInternetUrl = true
    }
    
    if isInternetUrl {
        if let host = parsedUrl.host, telegramMeHosts.contains(host) {
            handleInternalUrl(parsedUrl.absoluteString)
        } else {
            let settings = combineLatest(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings, ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]), context.sharedContext.accountManager.accessChallengeData())
            |> take(1)
            |> map { sharedData, accessChallengeData -> WebBrowserSettings in
                let passcodeSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]?.get(PresentationPasscodeSettings.self) ?? PresentationPasscodeSettings.defaultSettings
                
                var settings: WebBrowserSettings
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings]?.get(WebBrowserSettings.self) {
                    settings = current
                } else {
                    settings = .defaultSettings
                }
                if accessChallengeData.data.isLockable {
                    if passcodeSettings.autolockTimeout != nil && settings.defaultWebBrowser == "inApp" {
                        settings = WebBrowserSettings(defaultWebBrowser: "safari", exceptions: [])
                    }
                }
                return settings
            }
            
            let _ = (settings
            |> deliverOnMainQueue).startStandalone(next: { settings in
                var isTonSite = false
                if let host = parsedUrl.host, host.lowercased().hasSuffix(".ton") {
                    isTonSite = true
                } else if let scheme = parsedUrl.scheme, scheme.lowercased().hasPrefix("tonsite") {
                    isTonSite = true
                }
                
                if let defaultWebBrowser = settings.defaultWebBrowser, defaultWebBrowser != "inApp" && !isTonSite {
                    let openInOptions = availableOpenInOptions(context: context, item: .url(url: originalUrl))
                    if let option = openInOptions.first(where: { $0.identifier == settings.defaultWebBrowser }) {
                        if case let .openUrl(openInUrl) = option.action() {
                            context.sharedContext.applicationBindings.openUrl(openInUrl)
                        } else {
                            context.sharedContext.applicationBindings.openUrl(originalUrl)
                        }
                    } else {
                        context.sharedContext.applicationBindings.openUrl(originalUrl)
                    }
                } else {
                    var isExceptedDomain = false
                    let host = ".\((parsedUrl.host ?? "").lowercased())"
                    for exception in settings.exceptions {
                        if host.hasSuffix(".\(exception.domain)") {
                            isExceptedDomain = true
                            break
                        }
                    }
                    
                    if (settings.defaultWebBrowser == nil && !isExceptedDomain) || isTonSite {
                        let controller = BrowserScreen(context: context, subject: .webPage(url: parsedUrl.absoluteString))
                        navigationController?.pushViewController(controller)
                    } else {
                        if let window = navigationController?.view.window, !isExceptedDomain {
                            let controller = SFSafariViewController(url: parsedUrl)
                            controller.preferredBarTintColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
                            controller.preferredControlTintColor = presentationData.theme.rootController.navigationBar.accentTextColor
                            window.rootViewController?.present(controller, animated: true)
                        } else {
                            context.sharedContext.applicationBindings.openUrl(parsedUrl.absoluteString)
                        }
                    }
                }
            })
        }
    } else {
        context.sharedContext.applicationBindings.openUrl(originalUrl)
    }
}

private struct QueryParameters {
    private let map: [String: [String?]]
    let items: [URLQueryItem]
    
    init?(_ query: String) {
        guard let components = URLComponents(string: "/?" + query) else {
            return nil
        }
        let queryItems = components.queryItems ?? []
        self.items = queryItems
        
        var map: [String: [String?]] = [:]
        for item in queryItems {
            map[item.name, default: []].append(item.value)
        }
        self.map = map
    }
    
    subscript(_ name: String) -> String? {
        return self.map[name]?.first ?? nil
    }
}

private func appendQueryItems(to base: String, items: [URLQueryItem]) -> String {
    guard !items.isEmpty else {
        return base
    }
    var components = URLComponents()
    components.queryItems = items
    guard let query = components.percentEncodedQuery, !query.isEmpty else {
        return base
    }
    let separator = base.contains("?") ? "&" : "?"
    return base + separator + query
}

private func makeTelegramUrl(_ path: String, queryItems: [URLQueryItem] = []) -> String {
    return appendQueryItems(to: "https://t.me\(path)", items: queryItems)
}

func openExternalUrlImpl(context: AccountContext, urlContext: OpenURLContext, url: String, forceExternal: Bool, presentationData: PresentationData, navigationController: NavigationController?, dismissInput: @escaping () -> Void) {
    if forceExternal || url.lowercased().hasPrefix("tel:") || url.lowercased().hasPrefix("calshow:") {
        if url.lowercased().hasPrefix("tel:+888") {
            context.sharedContext.presentGlobalController(textAlertController(context: context, title: nil, text: presentationData.strings.Conversation_CantPhoneCallAnonymousNumberError, actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                }),
            ], parseMarkdown: true), nil)
            return
        }
        context.sharedContext.applicationBindings.openUrl(url)
        return
    }
    
    guard let canonicalUrl = canonicalExternalUrl(from: url) else {
        return
    }
    
    if canonicalUrl.scheme == "mailto" {
        context.sharedContext.applicationBindings.openUrl(url)
        return
    }
    
    var parsedUrl = canonicalUrl
    
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
    
    let handleResolvedUrl = makeResolvedUrlHandler(
        context: context,
        presentationData: presentationData,
        navigationController: navigationController,
        dismissInput: dismissInput
    )
    let handleInternalUrl = makeInternalUrlHandler(
        context: context,
        resolvedHandler: handleResolvedUrl
    )
    
    let continueHandling: () -> Void = {
        if let scheme = parsedUrl.scheme, (scheme == "tg" || scheme == context.sharedContext.applicationBindings.appSpecificScheme) {
            if parsedUrl.host == "tonsite" {
                if let value = URL(string: "tonsite:/" + parsedUrl.path) {
                    parsedUrl = value
                }
            }
        }
        
        if let scheme = parsedUrl.scheme, (scheme == "tg" || scheme == context.sharedContext.applicationBindings.appSpecificScheme) {
            var convertedUrl: String?
            let host = parsedUrl.host?.lowercased() ?? ""
            if let query = parsedUrl.query, let params = QueryParameters(query) {
                switch host {
                case "localpeer":
                    if let peerIdValue = params["id"].flatMap(Int64.init), let accountId = params["accountId"].flatMap(Int64.init) {
                        let peerId = PeerId(peerIdValue)
                        context.sharedContext.applicationBindings.dismissNativeController()
                        context.sharedContext.navigateToChat(accountId: AccountRecordId(rawValue: accountId), peerId: peerId, messageId: nil)
                    }
                case "join":
                    if let invite = params["invite"] {
                        convertedUrl = makeTelegramUrl("/joinchat/\(invite)")
                    }
                case "addstickers":
                    if let set = params["set"] {
                        convertedUrl = makeTelegramUrl("/addstickers/\(set)")
                    }
                case "addemoji":
                    if let set = params["set"] {
                        convertedUrl = makeTelegramUrl("/addemoji/\(set)")
                    }
                case "invoice":
                    if let slug = params["slug"] {
                        convertedUrl = makeTelegramUrl("/invoice/\(slug)")
                    }
                case "setlanguage":
                    if let lang = params["lang"] {
                        convertedUrl = makeTelegramUrl("/setlanguage/\(lang)")
                    }
                case "msg":
                    let sharePhoneNumber = params["to"]
                    let shareText = params["text"]
                    if sharePhoneNumber != nil || shareText != nil {
                        handleResolvedUrl(.share(url: nil, text: shareText, to: sharePhoneNumber))
                        return
                    }
                case "msg_url":
                    if let shareUrl = params["url"] {
                        var queryItems: [URLQueryItem] = [URLQueryItem(name: "url", value: shareUrl)]
                        if let shareText = params["text"] {
                            queryItems.append(URLQueryItem(name: "text", value: shareText))
                        }
                        convertedUrl = makeTelegramUrl("/share/url", queryItems: queryItems)
                    }
                case "socks", "proxy":
                    let server = params["server"] ?? params["proxy"]
                    let port = params["port"]
                    let user = params["user"]
                    let pass = params["pass"]
                    let secret = params["secret"]
                    let secretHost = params["host"]
                    
                    if let server, !server.isEmpty, let port, let _ = Int32(port) {
                        var queryItems: [URLQueryItem] = [
                            URLQueryItem(name: "proxy", value: server),
                            URLQueryItem(name: "port", value: port)
                        ]
                        if let user {
                            queryItems.append(URLQueryItem(name: "user", value: user))
                            if let pass {
                                queryItems.append(URLQueryItem(name: "pass", value: pass))
                            }
                        }
                        if let secret {
                            queryItems.append(URLQueryItem(name: "secret", value: secret))
                        }
                        if let secretHost {
                            queryItems.append(URLQueryItem(name: "host", value: secretHost))
                        }
                        convertedUrl = makeTelegramUrl("/proxy", queryItems: queryItems)
                    }
                case "passport", "oauth", "resolve":
                    if isOAuthUrl(parsedUrl) {
                        handleResolvedUrl(.oauth(url: url))
                        return
                    } else if let secureId = parseSecureIdUrl(parsedUrl) {
                        if case .chat = urlContext {
                            return
                        }
                        let controller = SecureIdAuthController(context: context, mode: .form(peerId: secureId.peerId, scope: secureId.scope, publicKey: secureId.publicKey, callbackUrl: secureId.callbackUrl, opaquePayload: secureId.opaquePayload, opaqueNonce: secureId.opaqueNonce))
                        
                        if let navigationController = navigationController {
                            context.sharedContext.applicationBindings.dismissNativeController()
                            
                            navigationController.view.window?.endEditing(true)
                            context.sharedContext.applicationBindings.getWindowHost()?.present(controller, on: .root, blockInteraction: false, completion: {})
                        }
                        return
                    }
                case "user":
                    if let idValue = params["id"].flatMap(Int64.init), idValue > 0 {
                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(idValue))))
                        |> deliverOnMainQueue).startStandalone(next: { peer in
                            if let peer = peer, let controller = context.sharedContext.makePeerInfoController(
                                context: context,
                                updatedPresentationData: nil,
                                peer: peer._asPeer(),
                                mode: .generic,
                                avatarInitiallyExpanded: false,
                                fromChat: false,
                                requestsContext: nil
                            ) {
                                navigationController?.pushViewController(controller)
                            }
                        })
                        return
                    }
                case "login":
                    if let _ = params["token"] {
                        let alertController = textAlertController(
                            context: context,
                            title: nil,
                            text: presentationData.strings.AuthSessions_AddDevice_UrlLoginHint,
                            actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})],
                            parseMarkdown: true
                        )
                        context.sharedContext.presentGlobalController(alertController, nil)
                        return
                    }
                    if let code = params["code"] {
                        convertedUrl = makeTelegramUrl("/login/\(code)")
                    }
                case "contact":
                    if let token = params["token"] {
                        convertedUrl = makeTelegramUrl("/contact/\(token)")
                    }
                case "confirmphone":
                    if let phone = params["phone"], let hash = params["hash"] {
                        let queryItems = [
                            URLQueryItem(name: "phone", value: phone),
                            URLQueryItem(name: "hash", value: hash)
                        ]
                        convertedUrl = makeTelegramUrl("/confirmphone", queryItems: queryItems)
                    }
                case "bg":
                    var parameter: String?
                    var queryItems: [URLQueryItem] = []
                    for item in params.items {
                        guard let value = item.value else {
                            continue
                        }
                        switch item.name {
                        case "slug", "color", "gradient":
                            parameter = value
                        case "mode", "bg_color", "intensity", "rotation":
                            queryItems.append(URLQueryItem(name: item.name, value: value))
                        default:
                            break
                        }
                    }
                    if let parameter = parameter {
                        convertedUrl = makeTelegramUrl("/bg/\(parameter)", queryItems: queryItems)
                    }
                case "addtheme":
                    if let parameter = params["slug"] {
                        convertedUrl = makeTelegramUrl("/addtheme/\(parameter)")
                    }
                case "nft":
                    if let slug = params["slug"] {
                        convertedUrl = makeTelegramUrl("/nft/\(slug)")
                    }
                case "stargift_auction":
                    if let slug = params["slug"] {
                        convertedUrl = makeTelegramUrl("/auction/\(slug)")
                    }
                case "privatepost":
                    let channelId = params["channel"].flatMap(Int64.init)
                    let postId = params["post"].flatMap(Int32.init)
                    let threadId = params["thread"].flatMap(Int64.init)
                    
                    if let channelId {
                        if let postId {
                            if let threadId {
                                convertedUrl = makeTelegramUrl("/c/\(channelId)/\(threadId)/\(postId)")
                            } else {
                                convertedUrl = makeTelegramUrl("/c/\(channelId)/\(postId)")
                            }
                        } else if let threadId {
                            convertedUrl = makeTelegramUrl("/c/\(channelId)/\(threadId)")
                        }
                    }
                case "giftcode":
                    if let slug = params["slug"] {
                        convertedUrl = makeTelegramUrl("/giftcode/\(slug)")
                    }
                case "message":
                    if let parameter = params["slug"] {
                        convertedUrl = makeTelegramUrl("/m/\(parameter)")
                    }
                case "hostoverride":
                    if let override = params["host"] {
                        let _ = updateNetworkSettingsInteractively(postbox: context.account.postbox, network: context.account.network, { settings in
                            var settings = settings
                            settings.backupHostOverride = override
                            return settings
                        }).startStandalone()
                        return
                    }
                case "premium_offer":
                    let reference = params["ref"]
                    handleResolvedUrl(.premiumOffer(reference: reference))
                case "premium_multigift":
                    let reference = params["ref"]
                    handleResolvedUrl(.premiumMultiGift(reference: reference))
                case "stars_topup":
                    let amount = params["balance"].flatMap(Int64.init)
                    let purpose = params["purpose"]
                    if let amount, amount > 0 && amount < Int64(Int32.max) {
                        handleResolvedUrl(.starsTopup(amount: amount, purpose: purpose))
                    } else {
                        handleResolvedUrl(.starsTopup(amount: nil, purpose: purpose))
                    }
                case "addlist":
                    if let slug = params["slug"] {
                        convertedUrl = makeTelegramUrl("/addlist/\(slug)")
                    }
                case "boost":
                    if let domain = params["domain"] {
                        convertedUrl = makeTelegramUrl("/\(domain)", queryItems: [URLQueryItem(name: "boost", value: nil)])
                    } else if let channel = params["channel"].flatMap(Int64.init) {
                        convertedUrl = makeTelegramUrl("/c/\(channel)", queryItems: [URLQueryItem(name: "boost", value: nil)])
                    }
                case "call":
                    if let slug = params["slug"] {
                        convertedUrl = makeTelegramUrl("/call/\(slug)")
                    }
                case "sharestory":
                    if let session = params["session"].flatMap(Int64.init) {
                        handleResolvedUrl(.shareStory(session))
                        return
                    }
                case "send_gift":
                    if let recipient = params["to"] {
                        if let id = Int64(recipient) {
                            handleResolvedUrl(.sendGift(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))))
                        } else {
                            let _ = (context.engine.peers.resolvePeerByName(name: recipient, referrer: nil)
                            |> deliverOnMainQueue).start(next: { result in
                                guard case let .result(peer) = result, let peer else {
                                    return
                                }
                                handleResolvedUrl(.sendGift(peerId: peer.id))
                            })
                        }
                    } else {
                        handleResolvedUrl(.sendGift(peerId: nil))
                    }
                default:
                    break
                }
                
                if host == "resolve" {
                    var phone: String?
                    var domain: String?
                    var start: String?
                    var startGroup: String?
                    var startChannel: String?
                    var admin: String?
                    var game: String?
                    var post: String?
                    var voiceChat: String?
                    var attach: String?
                    var startAttach: String?
                    var choose: String?
                    var threadId: Int64?
                    var appName: String?
                    var startApp: String?
                    var text: String?
                    var profile = false
                    var direct = false
                    var referrer: String?
                    var albumId: Int64?
                    var collectionId: Int64?
                    
                    for queryItem in params.items {
                        if let value = queryItem.value {
                            switch queryItem.name {
                            case "phone":
                                phone = value
                            case "domain":
                                domain = value
                            case "start":
                                start = value
                            case "startgroup":
                                startGroup = value
                            case "admin":
                                admin = value
                            case "game":
                                game = value
                            case "post":
                                post = value
                            case "voicechat", "videochat", "livestream":
                                voiceChat = value
                            case "attach":
                                attach = value
                            case "startattach":
                                startAttach = value
                            case "choose":
                                choose = value
                            case "thread":
                                threadId = Int64(value)
                            case "appname":
                                appName = value
                            case "startapp":
                                startApp = value
                            case "text":
                                text = value
                            case "ref":
                                referrer = value
                            case "album":
                                albumId = Int64(value)
                            case "collection":
                                collectionId = Int64(value)
                            default:
                                break
                            }
                        } else {
                            switch queryItem.name {
                            case "voicechat", "videochat", "livestream":
                                voiceChat = ""
                            case "startattach":
                                startAttach = ""
                            case "startgroup":
                                startGroup = ""
                            case "startchannel":
                                startChannel = ""
                            case "profile":
                                profile = true
                            case "direct":
                                direct = true
                            case "startapp":
                                startApp = ""
                            default:
                                break
                            }
                        }
                    }
                    
                    if let phone = phone {
                        var queryItems: [URLQueryItem] = []
                        if let text {
                            queryItems.append(URLQueryItem(name: "text", value: text))
                        }
                        if let referrer {
                            queryItems.append(URLQueryItem(name: "ref", value: referrer))
                        }
                        if profile {
                            queryItems.append(URLQueryItem(name: "profile", value: nil))
                        }
                        if direct {
                            queryItems.append(URLQueryItem(name: "direct", value: nil))
                        }
                        convertedUrl = makeTelegramUrl("/+\(phone)", queryItems: queryItems)
                    } else if let domain = domain {
                        var path = "/\(domain)"
                        if let appName {
                            path += "/\(appName)"
                        }
                        if let threadId {
                            path += "/\(threadId)"
                            if let post, let postValue = Int(post) {
                                path += "/\(postValue)"
                            }
                        } else if let post, let postValue = Int(post) {
                            path += "/\(postValue)"
                        }
                        if let albumId {
                            path += "/a/\(albumId)"
                        } else if let collectionId {
                            path += "/c/\(collectionId)"
                        }
                        
                        var queryItems: [URLQueryItem] = []
                        if let startApp {
                            queryItems.append(URLQueryItem(name: "startapp", value: startApp.isEmpty ? "" : startApp))
                        }
                        if let start {
                            queryItems.append(URLQueryItem(name: "start", value: start))
                        } else if let startGroup {
                            queryItems.append(URLQueryItem(name: "startgroup", value: startGroup.isEmpty ? nil : startGroup))
                            if let admin {
                                queryItems.append(URLQueryItem(name: "admin", value: admin))
                            }
                        } else if let startChannel {
                            queryItems.append(URLQueryItem(name: "startchannel", value: startChannel.isEmpty ? nil : startChannel))
                            if let admin = admin {
                                queryItems.append(URLQueryItem(name: "admin", value: admin))
                            }
                        } else if let game {
                            queryItems.append(URLQueryItem(name: "game", value: game))
                        } else if let voiceChat {
                            queryItems.append(URLQueryItem(name: "voicechat", value: voiceChat.isEmpty ? "" : voiceChat))
                        } else if let attach {
                            queryItems.append(URLQueryItem(name: "attach", value: attach))
                        }
                        
                        if let startAttach {
                            queryItems.append(URLQueryItem(name: "startattach", value: startAttach.isEmpty ? nil : startAttach))
                            if let choose {
                                queryItems.append(URLQueryItem(name: "choose", value: choose))
                            }
                        }
                        if let text {
                            queryItems.append(URLQueryItem(name: "text", value: text))
                        }
                        if let referrer {
                            queryItems.append(URLQueryItem(name: "ref", value: referrer))
                        }
                        if profile {
                            queryItems.append(URLQueryItem(name: "profile", value: nil))
                        }
                        if direct {
                            queryItems.append(URLQueryItem(name: "direct", value: nil))
                        }
                        
                        convertedUrl = makeTelegramUrl(path, queryItems: queryItems)
                    }
                }
            } else {
                switch host {
                case "stars":
                    handleResolvedUrl(.stars)
                case "ton":
                    handleResolvedUrl(.ton)
                case "importstickers":
                    handleResolvedUrl(.importStickers)
                case "premium_offer":
                    handleResolvedUrl(.premiumOffer(reference: nil))
                case "restore_purchases":
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
                        if let text {
                            let alertController = textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                            context.sharedContext.presentGlobalController(alertController, nil)
                        }
                    })
                case "send_gift":
                    handleResolvedUrl(.sendGift(peerId: nil))
                case "contacts":
                    var section: ResolvedUrl.ContactsSection?
                    if let path = parsedUrl.pathComponents.last {
                        switch path {
                        case "search":
                            section = .search
                        case "sort":
                            section = .sort
                        case "new":
                            section = .new
                        case "invite":
                            section = .invite
                        case "manage":
                            section = .manage
                        default:
                            break
                        }
                    }
                    handleResolvedUrl(.contacts(section))
                case "chats":
                    var section: ResolvedUrl.ChatsSection?
                    if let path = parsedUrl.pathComponents.last {
                        switch path {
                        case "search":
                            section = .search
                        case "edit":
                            section = .edit
                        case "emoji-status":
                            section = .emojiStatus
                        default:
                            break
                        }
                    }
                    handleResolvedUrl(.chats(section))
                case "new":
                    var section: ResolvedUrl.ComposeSection?
                    if let path = parsedUrl.pathComponents.last {
                        switch path {
                        case "group":
                            section = .group
                        case "channel":
                            section = .channel
                        case "contact":
                            section = .contact
                        default:
                            break
                        }
                    }
                    handleResolvedUrl(.compose(section))
                case "post":
                    var section: ResolvedUrl.PostStorySection?
                    if let path = parsedUrl.pathComponents.last {
                        switch path {
                        case "photo":
                            section = .photo
                        case "video":
                            section = .video
                        case "live":
                            section = .live
                        default:
                            break
                        }
                    }
                    handleResolvedUrl(.postStory(section))
                case "settings":
                    if let lastComponent = parsedUrl.pathComponents.last {
                        var section: ResolvedUrl.SettingsSection?
                        switch lastComponent {
                        case "themes":
                            section = .legacy(.theme)
                        case "devices":
                            section = .legacy(.devices)
                        case "enable_log":
                            section = .legacy(.enableLog)
                        case "phone_privacy":
                            section = .legacy(.phonePrivacy)
                        case "login_email":
                            section = .legacy(.loginEmail)
                        default:
                            let fullPath = parsedUrl.pathComponents.joined(separator: "/").replacingOccurrences(of: "//", with: "")
                            section = .path(fullPath)
                        }
                        if let section {
                            handleResolvedUrl(.settings(section))
                        }
                    } else {
                        handleResolvedUrl(.settings(.path("")))
                    }
                default:
                    break
                }
            }
            
            if let convertedUrl {
                handleInternalUrl(convertedUrl)
            } else if let path = parsedUrl.host {
                handleResolvedUrl(.unknownDeepLink(path: path))
            }
            return
        }
        
        handleInternetUrl(
            parsedUrl: parsedUrl,
            originalUrl: url,
            context: context,
            presentationData: presentationData,
            navigationController: navigationController,
            handleInternalUrl: handleInternalUrl
        )
    }
    
    if let scheme = parsedUrl.scheme, internetSchemes.contains(scheme) {
        if let host = parsedUrl.host, telegramMeHosts.contains(host) {
            continueHandling()
        } else {
            if isTelegraPhLink(parsedUrl.absoluteString) {
                continueHandling()
            } else {
                context.sharedContext.applicationBindings.openUniversalUrl(url, TelegramApplicationOpenUrlCompletion(completion: { success in
                    if !success {
                        continueHandling()
                    }
                }))
            }
        }
    } else {
        continueHandling()
    }
}
