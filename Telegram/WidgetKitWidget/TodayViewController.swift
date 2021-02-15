import UIKit
import NotificationCenter
import BuildConfig
import WidgetItems
import AppLockState
import SwiftUI
import WidgetKit
import Intents

import OpenSSLEncryptionProvider
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramCore
import OpenSSLEncryptionProvider
import WidgetItemsUtils

import GeneratedSources

struct ParsedPeer {
    var accountId: Int64
    var accountPeerId: Int64
    var peer: WidgetDataPeer
}

struct ParsedPeers {
    var peers: [ParsedPeer]
    var updateTimestamp: Int32
}

private extension ParsedPeers {
    init(accountId: Int64, peers: WidgetDataPeers) {
        self.init(peers: peers.peers.map { peer -> ParsedPeer in
            return ParsedPeer(
                accountId: accountId,
                accountPeerId: peers.accountPeerId,
                peer: peer
            )
        }, updateTimestamp: peers.updateTimestamp)
    }
}

private var installedSharedLogger = false

private func setupSharedLogger(rootPath: String, path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(rootPath: rootPath, basePath: path))
    }
}

private let accountAuxiliaryMethods = AccountAuxiliaryMethods(updatePeerChatInputState: { interfaceState, inputState -> PeerChatInterfaceState? in
    return interfaceState
}, fetchResource: { account, resource, ranges, _ in
    return nil
}, fetchResourceMediaReferenceHash: { resource in
    return .single(nil)
}, prepareSecretThumbnailData: { _ in
    return nil
})

private struct ApplicationSettings {
    let logging: LoggingSettings
}

private func applicationSettings(accountManager: AccountManager) -> Signal<ApplicationSettings, NoError> {
    return accountManager.transaction { transaction -> ApplicationSettings in
        let loggingSettings: LoggingSettings
        if let value = transaction.getSharedData(SharedDataKeys.loggingSettings) as? LoggingSettings {
            loggingSettings = value
        } else {
            loggingSettings = LoggingSettings.defaultSettings
        }
        return ApplicationSettings(logging: loggingSettings)
    }
}

private func rootPathForBasePath(_ appGroupPath: String) -> String {
    return appGroupPath + "/telegram-data"
}

struct Provider: IntentTimelineProvider {
    public typealias Entry = SimpleEntry
    
    func placeholder(in context: Context) -> SimpleEntry {
        return SimpleEntry(date: Date(), contents: .recent)
    }

    func getSnapshot(for configuration: SelectFriendsIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), contents: .peers(ParsedPeers(accountId: 0, peers: WidgetDataPeers(accountPeerId: 0, peers: [], updateTimestamp: 0))))
        completion(entry)
    }

    func getTimeline(for configuration: SelectFriendsIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entryDate = Calendar.current.date(byAdding: .hour, value: 0, to: currentDate)!
        
        guard let appBundleIdentifier = Bundle.main.bundleIdentifier, let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            completion(Timeline(entries: [SimpleEntry(date: entryDate, contents: .recent)], policy: .atEnd))
            return
        }
        
        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            completion(Timeline(entries: [SimpleEntry(date: entryDate, contents: .recent)], policy: .atEnd))
            return
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        
        TempBox.initializeShared(basePath: rootPath, processType: "widget", launchSpecificId: arc4random64())
        
        let logsPath = rootPath + "/widget-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        
        setupSharedLogger(rootPath: rootPath, path: logsPath)
        
        initializeAccountManagement()
        
        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
        
        var itemsByAccount: [Int64: [(Int64, Friend)]] = [:]
        var itemOrder: [(Int64, Int64)] = []
        if let friends = configuration.friends {
            for item in friends {
                guard let identifier = item.identifier else {
                    continue
                }
                guard let index = identifier.firstIndex(of: ":") else {
                    continue
                }
                guard let accountId = Int64(identifier[identifier.startIndex ..< index]) else {
                    continue
                }
                guard let peerId = Int64(identifier[identifier.index(after: index)...]) else {
                    continue
                }
                if itemsByAccount[accountId] == nil {
                    itemsByAccount[accountId] = []
                }
                itemsByAccount[accountId]?.append((peerId, item))
                itemOrder.append((accountId, peerId))
            }
        }
        
        var friendsByAccount: [Signal<[ParsedPeer], NoError>] = []
        for (accountId, items) in itemsByAccount {
            friendsByAccount.append(accountTransaction(rootPath: rootPath, id: AccountRecordId(rawValue: accountId), encryptionParameters: encryptionParameters, transaction: { postbox, transaction -> [ParsedPeer] in
                guard let state = transaction.getState() as? AuthorizedAccountState else {
                    return []
                }
                
                var result: [ParsedPeer] = []
                
                for (peerId, _) in items {
                    guard let peer = transaction.getPeer(PeerId(peerId)) else {
                        continue
                    }
                    
                    var name: String = ""
                    var lastName: String?
                    
                    if let user = peer as? TelegramUser {
                        if let firstName = user.firstName {
                            name = firstName
                            lastName = user.lastName
                        } else if let lastName = user.lastName {
                            name = lastName
                        } else if let phone = user.phone, !phone.isEmpty {
                            name = phone
                        }
                    } else {
                        name = peer.debugDisplayTitle
                    }
                    
                    var badge: WidgetDataPeer.Badge?
                    
                    if let readState = transaction.getCombinedPeerReadState(peer.id), readState.count > 0 {
                        var isMuted = false
                        if let notificationSettings = transaction.getPeerNotificationSettings(peer.id) as? TelegramPeerNotificationSettings {
                            isMuted = notificationSettings.isRemovedFromTotalUnreadCount(default: false)
                        }
                        badge = WidgetDataPeer.Badge(
                            count: Int(readState.count),
                            isMuted: isMuted
                        )
                    }
                    
                    var mappedMessage: WidgetDataPeer.Message?
                    if let index = transaction.getTopPeerMessageIndex(peerId: peer.id) {
                        if let message = transaction.getMessage(index.id) {
                            mappedMessage = WidgetDataPeer.Message(message: message)
                        }
                    }
                    
                    let widgetPeer = WidgetDataPeer(id: peer.id.toInt64(), name: name, lastName: lastName, letters: peer.displayLetters, avatarPath: smallestImageRepresentation(peer.profileImageRepresentations).flatMap { representation in
                        return postbox.mediaBox.resourcePath(representation.resource)
                    }, badge: badge, message: mappedMessage)
                    
                    result.append(ParsedPeer(accountId: accountId, accountPeerId: state.peerId.toInt64(), peer: widgetPeer))
                }
                
                return result
            })
            |> `catch` { _ -> Signal<[ParsedPeer], NoError> in
                return .single([])
            })
        }
        
        let _ = combineLatest(friendsByAccount).start(next: { allPeers in
            var orderedPeers: [ParsedPeer] = []
            
            outer: for (accountId, peerId) in itemOrder {
                for peerSet in allPeers {
                    for peer in peerSet {
                        if peer.accountId == accountId && peer.peer.id == peerId {
                            orderedPeers.append(peer)
                            continue outer
                        }
                    }
                }
            }
            
            let result = ParsedPeers(peers: orderedPeers, updateTimestamp: Int32(Date().timeIntervalSince1970))
            completion(Timeline(entries: [SimpleEntry(date: entryDate, contents: .peers(result))], policy: .atEnd))
        })
    }
}

struct AvatarsProvider: IntentTimelineProvider {
    public typealias Entry = SimpleEntry
    
    func placeholder(in context: Context) -> SimpleEntry {
        return SimpleEntry(date: Date(), contents: .recent)
    }

    func getSnapshot(for configuration: SelectAvatarFriendsIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), contents: .peers(ParsedPeers(accountId: 0, peers: WidgetDataPeers(accountPeerId: 0, peers: [], updateTimestamp: 0))))
        completion(entry)
    }

    func getTimeline(for configuration: SelectAvatarFriendsIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entryDate = Calendar.current.date(byAdding: .hour, value: 0, to: currentDate)!
        
        guard let appBundleIdentifier = Bundle.main.bundleIdentifier, let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            completion(Timeline(entries: [SimpleEntry(date: entryDate, contents: .recent)], policy: .atEnd))
            return
        }
        
        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            completion(Timeline(entries: [SimpleEntry(date: entryDate, contents: .recent)], policy: .atEnd))
            return
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        
        TempBox.initializeShared(basePath: rootPath, processType: "widget", launchSpecificId: arc4random64())
        
        let logsPath = rootPath + "/widget-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        
        setupSharedLogger(rootPath: rootPath, path: logsPath)
        
        initializeAccountManagement()
        
        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
        
        var itemsByAccount: [Int64: [(Int64, Any)]] = [:]
        var itemOrder: [(Int64, Int64)] = []
        if let friends = configuration.friends {
            for item in friends {
                guard let identifier = item.identifier else {
                    continue
                }
                guard let index = identifier.firstIndex(of: ":") else {
                    continue
                }
                guard let accountId = Int64(identifier[identifier.startIndex ..< index]) else {
                    continue
                }
                guard let peerId = Int64(identifier[identifier.index(after: index)...]) else {
                    continue
                }
                if itemsByAccount[accountId] == nil {
                    itemsByAccount[accountId] = []
                }
                itemsByAccount[accountId]?.append((peerId, item))
                itemOrder.append((accountId, peerId))
            }
        }
        
        var friendsByAccount: [Signal<[ParsedPeer], NoError>] = []
        for (accountId, items) in itemsByAccount {
            friendsByAccount.append(accountTransaction(rootPath: rootPath, id: AccountRecordId(rawValue: accountId), encryptionParameters: encryptionParameters, transaction: { postbox, transaction -> [ParsedPeer] in
                guard let state = transaction.getState() as? AuthorizedAccountState else {
                    return []
                }
                
                var result: [ParsedPeer] = []
                
                for (peerId, _) in items {
                    guard let peer = transaction.getPeer(PeerId(peerId)) else {
                        continue
                    }
                    
                    var name: String = ""
                    var lastName: String?
                    
                    if let user = peer as? TelegramUser {
                        if let firstName = user.firstName {
                            name = firstName
                            lastName = user.lastName
                        } else if let lastName = user.lastName {
                            name = lastName
                        } else if let phone = user.phone, !phone.isEmpty {
                            name = phone
                        }
                    } else {
                        name = peer.debugDisplayTitle
                    }
                    
                    var badge: WidgetDataPeer.Badge?
                    
                    if let readState = transaction.getCombinedPeerReadState(peer.id), readState.count > 0 {
                        var isMuted = false
                        if let notificationSettings = transaction.getPeerNotificationSettings(peer.id) as? TelegramPeerNotificationSettings {
                            isMuted = notificationSettings.isRemovedFromTotalUnreadCount(default: false)
                        }
                        badge = WidgetDataPeer.Badge(
                            count: Int(readState.count),
                            isMuted: isMuted
                        )
                    }
                    
                    var mappedMessage: WidgetDataPeer.Message?
                    if let index = transaction.getTopPeerMessageIndex(peerId: peer.id) {
                        if let message = transaction.getMessage(index.id) {
                            mappedMessage = WidgetDataPeer.Message(message: message)
                        }
                    }
                    
                    let widgetPeer = WidgetDataPeer(id: peer.id.toInt64(), name: name, lastName: lastName, letters: peer.displayLetters, avatarPath: smallestImageRepresentation(peer.profileImageRepresentations).flatMap { representation in
                        return postbox.mediaBox.resourcePath(representation.resource)
                    }, badge: badge, message: mappedMessage)
                    
                    result.append(ParsedPeer(accountId: accountId, accountPeerId: state.peerId.toInt64(), peer: widgetPeer))
                }
                
                return result
            })
            |> `catch` { _ -> Signal<[ParsedPeer], NoError> in
                return .single([])
            })
        }
        
        let _ = combineLatest(friendsByAccount).start(next: { allPeers in
            var orderedPeers: [ParsedPeer] = []
            
            outer: for (accountId, peerId) in itemOrder {
                for peerSet in allPeers {
                    for peer in peerSet {
                        if peer.accountId == accountId && peer.peer.id == peerId {
                            orderedPeers.append(peer)
                            continue outer
                        }
                    }
                }
            }
            
            let result = ParsedPeers(peers: orderedPeers, updateTimestamp: Int32(Date().timeIntervalSince1970))
            completion(Timeline(entries: [SimpleEntry(date: entryDate, contents: .peers(result))], policy: .atEnd))
        })
    }
}

struct SimpleEntry: TimelineEntry {
    enum Contents {
        case recent
        case peers(ParsedPeers)
    }
    
    let date: Date
    let contents: Contents
}

enum PeersWidgetData {
    case empty
    case peers(ParsedPeers)
}

extension PeersWidgetData {
    static let previewData = PeersWidgetData.empty
}

struct AvatarItemView: View {
    var peer: ParsedPeer?
    var itemSize: CGFloat
    var placeholderColor: Color
    
    var body: some View {
        return ZStack {
            if let peer = peer {
                Image(uiImage: avatarImage(accountPeerId: peer.accountPeerId, peer: peer.peer, size: CGSize(width: itemSize, height: itemSize)))
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(placeholderColor)
                    .frame(width: itemSize, height: itemSize)
            }
        }
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.colorScheme) private var colorScheme
    let data: PeersWidgetData
    
    func placeholder(geometry: GeometryProxy) -> some View {
        let defaultItemSize: CGFloat = 60.0
        let defaultPaddingFraction: CGFloat = 0.36
        
        let columnCount = Int(round(geometry.size.width / (defaultItemSize * (1.0 + defaultPaddingFraction))))
        let itemSize = floor(geometry.size.width / (CGFloat(columnCount) + defaultPaddingFraction * CGFloat(columnCount - 1)))
        
        let firstRowY = itemSize / 2.0
        let secondRowY = itemSize / 2.0 + geometry.size.height - itemSize
        
        return ZStack {
            ForEach(0 ..< columnCount * 2, content: { i in
                return Circle().frame(width: itemSize, height: itemSize).position(x: itemSize / 2.0 + floor(CGFloat(i % columnCount) * itemSize * (1.0 + defaultPaddingFraction)), y: i / columnCount == 0 ? firstRowY : secondRowY).foregroundColor(.gray)
            })
        }
    }
    
    private func linkForPeer(accountId: Int64, id: Int64) -> String {
        switch self.widgetFamily {
        case .systemSmall:
            return "\(buildConfig.appSpecificUrlScheme)://"
        default:
            return "\(buildConfig.appSpecificUrlScheme)://localpeer?id=\(id)&accountId=\(accountId)"
        }
    }
    
    func peersView(geometry: GeometryProxy, peers: ParsedPeers) -> some View {
        let columnCount: Int
        let rowCount: Int
        
        let itemSizeFraction: CGFloat
        let horizontalInsetFraction: CGFloat
        let verticalInsetFraction: CGFloat
        let horizontalSpacingFraction: CGFloat
        let verticalSpacingFraction: CGFloat
        
        switch self.widgetFamily {
        case .systemLarge:
            itemSizeFraction = 0.1762917933
            horizontalInsetFraction = 0.04863221884
            verticalInsetFraction = 0.04863221884
            horizontalSpacingFraction = 0.06079027356
            verticalSpacingFraction = 0.06079027356
            columnCount = 4
            rowCount = 4
        case .systemMedium:
            itemSizeFraction = 0.1762917933
            horizontalInsetFraction = 0.04863221884
            verticalInsetFraction = 0.1032258065
            horizontalSpacingFraction = 0.06079027356
            verticalSpacingFraction = 0.07741935484
            columnCount = 4
            rowCount = 2
        case .systemSmall:
            itemSizeFraction = 0.335483871
            horizontalInsetFraction = 0.1032258065
            verticalInsetFraction = 0.1032258065
            horizontalSpacingFraction = 0.1161290323
            verticalSpacingFraction = 0.1161290323
            columnCount = 2
            rowCount = 2
        @unknown default:
            itemSizeFraction = 0.335483871
            horizontalInsetFraction = 0.1032258065
            verticalInsetFraction = 0.1032258065
            horizontalSpacingFraction = 0.1161290323
            verticalSpacingFraction = 0.1161290323
            columnCount = 2
            rowCount = 2
        }
        
        let itemSize = floor(geometry.size.width * itemSizeFraction)
        
        return ZStack {
            ForEach(0 ..< min(peers.peers.count, columnCount * rowCount), content: { i in
                Link(destination: URL(string: linkForPeer(accountId: peers.peers[i].accountId, id: peers.peers[i].peer.id))!, label: {
                    AvatarItemView(
                        peer: peers.peers[i],
                        itemSize: itemSize,
                        placeholderColor: getPlaceholderColor()
                    ).frame(width: itemSize, height: itemSize)
                }).frame(width: itemSize, height: itemSize)
                .position(x: floor(horizontalInsetFraction * geometry.size.width + itemSize / 2.0 + CGFloat(i % columnCount) * (itemSize + horizontalSpacingFraction * geometry.size.width)), y: floor(verticalInsetFraction * geometry.size.height + itemSize / 2.0 + CGFloat(i / columnCount) * (itemSize + verticalSpacingFraction * geometry.size.height)))
            })
        }
    }
    
    func peerViews() -> AnyView {
        switch data {
        case .empty:
            return AnyView(GeometryReader { geometry in
                placeholder(geometry: geometry)
            })
        case let .peers(peers):
            return AnyView(GeometryReader { geometry in
                peersView(geometry: geometry, peers: peers)
            })
        }
    }
    
    var body1: some View {
        ZStack {
            peerViews()
        }
        .padding(0.0)
    }
    
    func chatTopLine(_ peer: ParsedPeer?) -> some View {
        let dateText: String
        
        let chatTitle: AnyView
        let date: Text
        
        if let peer = peer {
            if let message = peer.peer.message {
                dateText = DateFormatter.localizedString(from: Date(timeIntervalSince1970: Double(message.timestamp)), dateStyle: .none, timeStyle: .short)
            } else {
                dateText = ""
            }
            chatTitle = AnyView(Text(peer.peer.name)
                .lineLimit(1)
                .font(Font.system(size: 16.0, weight: .medium, design: .default))
                .foregroundColor(.primary))
            date = Text(dateText)
            .font(Font.system(size: 14.0, weight: .regular, design: .default)).foregroundColor(.secondary)
        } else {
            dateText = "         "
            chatTitle = AnyView(Text(" ").font(Font.system(size: 16.0, weight: .medium, design: .default)).foregroundColor(.primary))
            date = Text(dateText)
            .font(Font.system(size: 16.0, weight: .regular, design: .default)).foregroundColor(.secondary)
        }
        return HStack(alignment: .center, spacing: 0.0, content: {
            if peer != nil {
                chatTitle
            } else {
                chatTitle
                    .frame(minWidth: 48.0)
                    .background(GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4.0)
                            .fill(getPlaceholderColor())
                            .frame(width: geometry.size.width, height: 8.0, alignment: .center)
                            .offset(x: 0.0, y: (geometry.size.height - 8.0) / 2.0 + 1.0)
                        }
                    )
            }
            Spacer()
            if peer != nil {
                date
            } else {
                date
                    .background(GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4.0)
                            .fill(getPlaceholderColor())
                            .frame(width: geometry.size.width, height: 8.0, alignment: .center)
                            .offset(x: 0.0, y: (geometry.size.height - 8.0) / 2.0)
                        }
                    )
            }
        })
        .padding(0.0)
    }
    
    func chatBottomLine(_ peer: ParsedPeer?) -> AnyView {
        var text = peer?.peer.message?.text ?? ""
        text += "\n"
        if peer == nil {
            text = "First Line Of Text Here\nSecond line fwqefeqwfqwef qwef wq"
        }
        if let message = peer?.peer.message {
            //TODO:localize
            switch message.content {
            case .text:
                break
            case .image:
                if !message.text.isEmpty {
                    text = "🖼 \(message.text)"
                } else {
                    text = "🖼 Photo"
                }
            case .video:
                if !message.text.isEmpty {
                    text = "📹 \(message.text)"
                } else {
                    text = "📹 Video"
                }
            case .gif:
                if !message.text.isEmpty {
                    text = "\(message.text)"
                } else {
                    text = "Gif"
                }
            case let .file(file):
                if !message.text.isEmpty {
                    text = "📹 \(message.text)"
                } else {
                    text = "📎 \(file.name)"
                }
            case let .music(music):
                if !music.title.isEmpty && !music.artist.isEmpty {
                    text = "\(music.artist) — \(music.title)"
                } else if !music.title.isEmpty {
                    text = music.title
                } else if !music.artist.isEmpty {
                    text = music.artist
                } else {
                    text = "Music"
                }
            case .voiceMessage:
                text = "🎤 Voice Message"
            case .videoMessage:
                text = "Video Message"
            case let .sticker(sticker):
                text = "\(sticker.altText) Sticker"
            case let .call(call):
                if call.isVideo {
                    text = "Video Call"
                } else {
                    text = "Voice Call"
                }
            case .mapLocation:
                text = "Location"
            case let .game(game):
                text = "🎮 \(game.title)"
            case let .poll(poll):
                text = "📊 \(poll.title)"
            }
            
            if let author = message.author {
                if author.isMe {
                    text = "You: \(text)"
                } else {
                    text = "\(author.title): \(text)"
                }
            }
        }
        
        let textView = Text(text)
            .lineLimit(2)
            .font(Font.system(size: 15.0, weight: .regular, design: .default))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .padding(0.0)
        
        if peer != nil {
            return AnyView(textView)
        } else {
            return AnyView(
                VStack(alignment: .leading, spacing: 0.0, content: {
                    Text(" ")
                        .lineLimit(1)
                        .font(Font.system(size: 15.0, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(0.0)
                        .frame(minWidth: 182.0)
                    .background(GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4.0)
                            .fill(getPlaceholderColor())
                            .frame(width: geometry.size.width, height: 8.0, alignment: .center)
                            .offset(x: 0.0, y: (geometry.size.height - 8.0) / 2.0 - 1.0)
                        }
                    )
                    Text(" ")
                        .lineLimit(1)
                        .font(Font.system(size: 15.0, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(0.0)
                        .frame(minWidth: 96.0)
                    .background(GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4.0)
                            .fill(getPlaceholderColor())
                            .frame(width: geometry.size.width, height: 8.0, alignment: .center)
                            .offset(x: 0.0, y: (geometry.size.height - 8.0) / 2.0 - 1.0)
                        }
                    )
                })
            )
        }
    }
    
    func chatContent(_ peer: ParsedPeer?) -> some View {
        return VStack(alignment: .leading, spacing: 0.0, content: {
            chatTopLine(peer)
            chatBottomLine(peer)
        })
    }
    
    func chatContentView(_ index: Int, size: CGSize) -> AnyView {
        let peers: ParsedPeers?
        var isPlaceholder = false
        switch data {
        case let .peers(peersValue):
            if peersValue.peers.count <= index {
                isPlaceholder = peersValue.peers.count != 0
                peers = nil
            } else {
                peers = peersValue
            }
        default:
            peers = nil
        }
        
        let itemHeight = (size.height - 22.0) / 2.0
        
        if isPlaceholder {
            return AnyView(Spacer()
                .frame(width: size.width, height: itemHeight, alignment: .leading)
            )
        }
        
        let url: URL
        if let peers = peers {
            url = URL(string: linkForPeer(accountId: peers.peers[index].accountId, id: peers.peers[index].peer.id))!
        } else {
            url = URL(string: "\(buildConfig.appSpecificUrlScheme)://")!
        }
        
        return AnyView(
            Link(destination: url, label: {
                HStack(alignment: .center, spacing: 0.0, content: {
                    AvatarItemView(peer: peers?.peers[index], itemSize: 54.0, placeholderColor: getPlaceholderColor()).frame(width: 54.0, height: 54.0, alignment: .leading).padding(EdgeInsets(top: 0.0, leading: 10.0, bottom: 0.0, trailing: 10.0))
                    chatContent(peers?.peers[index]).frame(maxWidth: .infinity).padding(EdgeInsets(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 10.0))
                })
            })
            .frame(width: size.width, height: itemHeight, alignment: .leading)
        )
    }
    
    func chatSeparatorView(size: CGSize) -> some View {
        return HStack(alignment: .center, spacing: 0.0, content: {
            Spacer()
            Rectangle()
                .foregroundColor(getSeparatorColor())
                .frame(width: size.width - 54.0 - 20.0, height: 0.5, alignment: .leading)
        })
        .frame(width: size.width, height: 1.0, alignment: .leading)
    }
    
    func chatsUpdateBackgroundView(size: CGSize) -> some View {
        return Rectangle().foregroundColor(getUpdatedBackgroundColor())
            //.position(x: size.width / 2.0, y: size.height - 11.0)
            .frame(width: size.width, height: 22.0, alignment: .center)
    }
    
    func chatUpdateView(size: CGSize) -> some View {
        return ZStack(alignment: Alignment(horizontal: .center, vertical: .center), content: {
            Rectangle().foregroundColor(getUpdatedBackgroundColor())
            chatsUpdateTimestampView(size: size)
        })
        .frame(width: size.width, height: 22.0 - 1.0, alignment: .center)
    }
    
    func chatsUpdateTimestampView(size: CGSize) -> some View {
        let text: String
        switch data {
        case let .peers(peersValue):
            if peersValue.peers.isEmpty {
                text = "Long tap to edit widget"
            } else {
                let date = Date(timeIntervalSince1970: Double(peersValue.updateTimestamp))
                let calendar = Calendar.current
                //TODO:localize
                if !calendar.isDate(Date(), inSameDayAs: date) {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .none
                    text = "updated on \(formatter.string(from: date))"
                } else {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .none
                    formatter.timeStyle = .short
                    text = "updated at \(formatter.string(from: date))"
                }
            }
        default:
            text = "Long tap to edit widget"
        }
        
        return Text(text)
            .font(Font.system(size: 12.0))
            .foregroundColor(getUpdatedTextColor())
    }
    
    func getSeparatorColor() -> Color {
        switch colorScheme {
        case .light:
            return Color(.sRGB, red: 216.0 / 255.0, green: 216.0 / 255.0, blue: 216.0 / 255.0, opacity: 1.0)
        case .dark:
            return Color(.sRGB, red: 0.0 / 255.0, green: 0.0 / 255.0, blue: 0.0 / 255.0, opacity: 1.0)
        @unknown default:
            return .secondary
        }
    }
    
    func getUpdatedBackgroundColor() -> Color {
        switch colorScheme {
        case .light:
            return Color(.sRGB, red: 242.0 / 255.0, green: 242.0 / 255.0, blue: 247.0 / 255.0, opacity: 1.0)
        case .dark:
            return Color(.sRGB, red: 21.0 / 255.0, green: 21.0 / 255.0, blue: 21.0 / 255.0, opacity: 1.0)
        @unknown default:
            return .secondary
        }
    }
    
    func getUpdatedTextColor() -> Color {
        switch colorScheme {
        case .light:
            return Color(.sRGB, red: 142.0 / 255.0, green: 142.0 / 255.0, blue: 146.0 / 255.0, opacity: 1.0)
        case .dark:
            return Color(.sRGB, red: 142.0 / 255.0, green: 142.0 / 255.0, blue: 146.0 / 255.0, opacity: 1.0)
        @unknown default:
            return .secondary
        }
    }
    
    func getPlaceholderColor() -> Color {
        switch colorScheme {
        case .light:
            return Color(.sRGB, red: 235.0 / 255.0, green: 235.0 / 255.0, blue: 241.0 / 255.0, opacity: 1.0)
        case .dark:
            return Color(.sRGB, red: 38.0 / 255.0, green: 38.0 / 255.0, blue: 41.0 / 255.0, opacity: 1.0)
        @unknown default:
            return .secondary
        }
    }
    
    var body: some View {
        GeometryReader(content: { geometry in
            return VStack(alignment: .center, spacing: 0.0, content: {
                chatContentView(0, size: geometry.size)
                chatSeparatorView(size: geometry.size)
                chatContentView(1, size: geometry.size)
                chatUpdateView(size: geometry.size)
            })
        })
        .padding(0.0)
        .unredacted()
    }
}

struct AvatarsWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.colorScheme) private var colorScheme
    let data: PeersWidgetData
    
    func placeholder(geometry: GeometryProxy) -> some View {
        return Spacer()
    }
    
    private func linkForPeer(accountId: Int64, id: Int64) -> String {
        switch self.widgetFamily {
        case .systemSmall:
            return "\(buildConfig.appSpecificUrlScheme)://"
        default:
            return "\(buildConfig.appSpecificUrlScheme)://localpeer?id=\(id)&accountId=\(accountId)"
        }
    }
    
    func getPlaceholderColor() -> Color {
        switch colorScheme {
        case .light:
            return Color(.sRGB, red: 235.0 / 255.0, green: 235.0 / 255.0, blue: 241.0 / 255.0, opacity: 1.0)
        case .dark:
            return Color(.sRGB, red: 38.0 / 255.0, green: 38.0 / 255.0, blue: 41.0 / 255.0, opacity: 1.0)
        @unknown default:
            return .secondary
        }
    }
    
    func itemView(index: Int) -> some View {
        let peers: ParsedPeers?
        var isPlaceholder = false
        switch data {
        case let .peers(peersValue):
            if peersValue.peers.count <= index {
                isPlaceholder = peersValue.peers.count != 0
                peers = nil
            } else {
                peers = peersValue
            }
        default:
            peers = nil
        }
        
        if let peers = peers {
            return AnyView(Link(destination: URL(string: linkForPeer(accountId: peers.peers[index].accountId, id: peers.peers[index].peer.id))!, label: {
                GeometryReader(content: { geometry in
                    AvatarItemView(peer: peers.peers[index], itemSize: geometry.size.height, placeholderColor: getPlaceholderColor())
                })
            }).aspectRatio(1.0, contentMode: .fit))
        } else if isPlaceholder {
            //return AnyView(Circle().aspectRatio(1.0, contentMode: .fit).foregroundColor(.clear))
            return AnyView(Circle().aspectRatio(1.0, contentMode: .fit).foregroundColor(getPlaceholderColor()))
        } else {
            return AnyView(Circle().aspectRatio(1.0, contentMode: .fit).foregroundColor(getPlaceholderColor()))
        }
    }
    
    var body: some View {
        return VStack(alignment: .center, spacing: 18.0, content: {
            HStack(alignment: .center, spacing: nil, content: {
                ForEach(0 ..< 4, id: \.self) { index in
                    itemView(index: index)
                    if index != 3 {
                        Spacer()
                    }
                }
            })
            HStack(alignment: .center, spacing: nil, content: {
                ForEach(0 ..< 4, id: \.self) { index in
                    itemView(index: 4 + index)
                    if index != 3 {
                        Spacer()
                    }
                }
            })
        })
        .padding(EdgeInsets(top: 10.0, leading: 10.0, bottom: 10.0, trailing: 10.0))
        .unredacted()
    }
}

private let buildConfig: BuildConfig = {
    let appBundleIdentifier = Bundle.main.bundleIdentifier!
    guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
        preconditionFailure()
    }
    let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
    
    let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
    return buildConfig
}()

private extension WidgetPresentationData {
    static var `default` = WidgetPresentationData(
        applicationLockedString: "Unlock the app to use the widget",
        applicationStartRequiredString: "Open the app to use the widget",
        widgetGalleryTitle: "Telegram",
        widgetGalleryDescription: ""
    )
}

private let presentationData: WidgetPresentationData = {
    let appBundleIdentifier = Bundle.main.bundleIdentifier!
    guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
        return WidgetPresentationData.default
    }
    let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
    
    let appGroupName = "group.\(baseAppBundleId)"
    let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
    
    guard let appGroupUrl = maybeAppGroupUrl else {
        return WidgetPresentationData.default
    }
    
    let rootPath = rootPathForBasePath(appGroupUrl.path)
    
    if let data = try? Data(contentsOf: URL(fileURLWithPath: widgetPresentationDataPath(rootPath: rootPath))), let value = try? JSONDecoder().decode(WidgetPresentationData.self, from: data) {
        return value
    } else {
        return WidgetPresentationData.default
    }
}()

func getWidgetData(contents: SimpleEntry.Contents) -> PeersWidgetData {
    switch contents {
    case .recent:
        return .empty
    case let .peers(peers):
        return .peers(peers)
    }
}

struct Static_Widget: Widget {
    private let kind: String = "Static_Widget"

    public var body: some WidgetConfiguration {
        return IntentConfiguration(kind: kind, intent: SelectFriendsIntent.self, provider: Provider(), content: { entry in
            WidgetView(data: getWidgetData(contents: entry.contents))
        })
        .supportedFamilies([.systemMedium])
        .configurationDisplayName(presentationData.widgetGalleryTitle)
        .description(presentationData.widgetGalleryDescription)
    }
}

struct Static_AvatarsWidget: Widget {
    private let kind: String = "Static_AvatarsWidget"

    public var body: some WidgetConfiguration {
        return IntentConfiguration(kind: kind, intent: SelectAvatarFriendsIntent.self, provider: AvatarsProvider(), content: { entry in
            AvatarsWidgetView(data: getWidgetData(contents: entry.contents))
        })
        .supportedFamilies([.systemMedium])
        .configurationDisplayName(presentationData.widgetGalleryTitle)
        .description(presentationData.widgetGalleryDescription)
    }
}

@main
struct AllWidgets: WidgetBundle {
   var body: some Widget {
        Static_Widget()
        Static_AvatarsWidget()
   }
}
