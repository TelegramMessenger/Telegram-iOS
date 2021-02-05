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
        let contents: SimpleEntry.Contents
        switch configuration.contents {
        case .unknown, .recent:
            contents = .recent
        case .custom:
            contents = .recent
        }
        let entry = SimpleEntry(date: Date(), contents: contents)
        completion(entry)
    }

    func getTimeline(for configuration: SelectFriendsIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entryDate = Calendar.current.date(byAdding: .hour, value: 0, to: currentDate)!
        
        switch configuration.contents {
        case .unknown, .recent:
            completion(Timeline(entries: [SimpleEntry(date: entryDate, contents: .recent)], policy: .atEnd))
        case .custom:
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
            
            let dataPath = rootPath + "/widget-data"
            
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: dataPath)), let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data), case let .peers(widgetPeers) = widgetData.content else {
                completion(Timeline(entries: [SimpleEntry(date: entryDate, contents: .recent)], policy: .atEnd))
                return
            }
            
            TempBox.initializeShared(basePath: rootPath, processType: "widget", launchSpecificId: arc4random64())
            
            let logsPath = rootPath + "/widget-logs"
            let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
            
            setupSharedLogger(rootPath: rootPath, path: logsPath)
            
            initializeAccountManagement()
            
            let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
            let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
            
            let _ = (accountTransaction(rootPath: rootPath, id: AccountRecordId(rawValue: widgetData.accountId), encryptionParameters: encryptionParameters, transaction: { postbox, transaction -> WidgetDataPeers in
                var peers: [WidgetDataPeer] = []
                if let items = configuration.friends {
                    for item in items {
                        guard let identifier = item.identifier, let peerIdValue = Int64(identifier) else {
                            continue
                        }
                        guard let peer = transaction.getPeer(PeerId(peerIdValue)) else {
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
                        
                        peers.append(WidgetDataPeer(id: peer.id.toInt64(), name: name, lastName: lastName, letters: peer.displayLetters, avatarPath: smallestImageRepresentation(peer.profileImageRepresentations).flatMap { representation in
                            return postbox.mediaBox.resourcePath(representation.resource)
                        }, badge: badge, message: mappedMessage))
                    }
                }
                return WidgetDataPeers(accountPeerId: widgetPeers.accountPeerId, peers: peers, updateTimestamp: Int32(Date().timeIntervalSince1970))
            })
            |> deliverOnMainQueue).start(next: { peers in
                completion(Timeline(entries: [SimpleEntry(date: entryDate, contents: .peers(peers))], policy: .atEnd))
            })
        }
    }
}

struct SimpleEntry: TimelineEntry {
    enum Contents {
        case recent
        case peers(WidgetDataPeers)
    }
    
    let date: Date
    let contents: Contents
}

enum PeersWidgetData {
    case placeholder
    case empty
    case locked
    case peers(WidgetDataPeers)
}

extension PeersWidgetData {
    static let previewData = PeersWidgetData.placeholder
}

struct AvatarItemView: View {
    var accountPeerId: Int64
    var peer: WidgetDataPeer
    var itemSize: CGFloat
    var displayBadge: Bool = true
    
    var body: some View {
        return ZStack {
            Image(uiImage: avatarImage(accountPeerId: accountPeerId, peer: peer, size: CGSize(width: itemSize, height: itemSize)))
                .clipShape(Circle())
            if displayBadge, let badge = peer.badge, badge.count > 0 {
                Text("\(badge.count)")
                    .font(Font.system(size: 16.0))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4.0)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(badge.isMuted ? Color.gray : Color.red)
                            .frame(minWidth: 20, idealWidth: 20, maxWidth: .infinity, minHeight: 20, idealHeight: 20, maxHeight: 20.0, alignment: .center)
                    )
                    .position(x: floor(0.84 * itemSize), y: floor(0.16 * itemSize))
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
    
    private func linkForPeer(id: Int64) -> String {
        switch self.widgetFamily {
        case .systemSmall:
            return "\(buildConfig.appSpecificUrlScheme)://"
        default:
            return "\(buildConfig.appSpecificUrlScheme)://localpeer?id=\(id)"
        }
    }
    
    func peersView(geometry: GeometryProxy, peers: WidgetDataPeers) -> some View {
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
                Link(destination: URL(string: linkForPeer(id: peers.peers[i].id))!, label: {
                    AvatarItemView(
                        accountPeerId: peers.accountPeerId,
                        peer: peers.peers[i],
                        itemSize: itemSize
                    ).frame(width: itemSize, height: itemSize)
                }).frame(width: itemSize, height: itemSize)
                .position(x: floor(horizontalInsetFraction * geometry.size.width + itemSize / 2.0 + CGFloat(i % columnCount) * (itemSize + horizontalSpacingFraction * geometry.size.width)), y: floor(verticalInsetFraction * geometry.size.height + itemSize / 2.0 + CGFloat(i / columnCount) * (itemSize + verticalSpacingFraction * geometry.size.height)))
            })
        }
    }
    
    func peerViews() -> AnyView {
        switch data {
        case .placeholder:
            return AnyView(GeometryReader { geometry in
                placeholder(geometry: geometry)
            })
        case .empty:
            return AnyView(VStack {
                Text(presentationData.applicationStartRequiredString)
            })
        case .locked:
            return AnyView(VStack {
                Text(presentationData.applicationLockedString)
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
    
    func chatTopLine(_ peer: WidgetDataPeer) -> some View {
        let dateText: String
        if let message = peer.message {
            dateText = DateFormatter.localizedString(from: Date(timeIntervalSince1970: Double(message.timestamp)), dateStyle: .none, timeStyle: .short)
        } else {
            dateText = ""
        }
        return HStack(alignment: .center, spacing: 0.0, content: {
            Text(peer.name).font(Font.system(size: 16.0, weight: .medium, design: .default)).foregroundColor(.primary)
            Spacer()
            Text(dateText).font(Font.system(size: 14.0, weight: .regular, design: .default)).foregroundColor(.secondary)
        })
    }
    
    func chatBottomLine(_ peer: WidgetDataPeer) -> some View {
        var text = peer.message?.text ?? ""
        if let message = peer.message {
            //TODO:localize
            switch message.content {
            case .text:
                break
            case .image:
                text = "🖼 Photo"
            case .video:
                text = "📹 Video"
            case .gif:
                text = "Gif"
            case let .file(file):
                text = "📎 \(file.name)"
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
        }
        
        var hasBadge = false
        if let badge = peer.badge, badge.count > 0 {
            hasBadge = true
        }
        
        return HStack(alignment: .center, spacing: hasBadge ? 6.0 : 0.0, content: {
            Text(text).lineLimit(nil).font(Font.system(size: 15.0, weight: .regular, design: .default)).foregroundColor(.secondary).multilineTextAlignment(.leading).frame(maxHeight: .infinity, alignment: .topLeading)
            Spacer()
            if let badge = peer.badge, badge.count > 0 {
                VStack {
                    Spacer()
                    Text("\(badge.count)")
                        .font(Font.system(size: 14.0))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4.0)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(badge.isMuted ? Color.gray : Color.blue)
                                .frame(minWidth: 20, idealWidth: 20, maxWidth: .infinity, minHeight: 20, idealHeight: 20, maxHeight: 20.0, alignment: .center)
                        )
                        .padding(EdgeInsets(top: 0.0, leading: 0.0, bottom: 6.0, trailing: 3.0))
                }
            }
        })
    }
    
    func chatContent(_ peer: WidgetDataPeer) -> some View {
        return VStack(alignment: .leading, spacing: 2.0, content: {
            chatTopLine(peer)
            chatBottomLine(peer).frame(maxHeight: .infinity)
        })
    }
    
    func chatContentView(_ index: Int, size: CGSize) -> AnyView {
        let peers: WidgetDataPeers
        switch data {
        case let .peers(peersValue):
            peers = peersValue
            if peers.peers.count <= index {
                return AnyView(Spacer())
            }
        default:
            return AnyView(Spacer())
        }
        
        let itemHeight = (size.height - 22.0) / 2.0
        
        return AnyView(
            Link(destination: URL(string: linkForPeer(id: peers.peers[index].id))!, label: {
                HStack(alignment: .center, spacing: 0.0, content: {
                AvatarItemView(accountPeerId: peers.accountPeerId, peer: peers.peers[index], itemSize: 54.0, displayBadge: false).frame(width: 54.0, height: 54.0, alignment: .leading).padding(EdgeInsets(top: 0.0, leading: 10.0, bottom: 0.0, trailing: 10.0))
                chatContent(peers.peers[index]).frame(maxWidth: .infinity).padding(EdgeInsets(top: 10.0, leading: 0.0, bottom: 10.0, trailing: 10.0))
                })
            }).position(x: size.width / 2.0, y: (itemHeight * 2.0) / 4.0 + CGFloat(index) * itemHeight).frame(width: size.width, height: itemHeight, alignment: .leading)
        )
    }
    
    func chatSeparatorView(size: CGSize) -> some View {
        let separatorWidth = size.width - 54.0 - 20.0
        let itemHeight = (size.height - 22.0) / 2.0
        return Rectangle().foregroundColor(getSeparatorColor()).position(x: (54.0 + 20.0 + separatorWidth) / 2.0, y: itemHeight / 2.0).frame(width: separatorWidth, height: 0.33, alignment: .leading)
    }
    
    func chatsUpdateBackgroundView(size: CGSize) -> some View {
        return Rectangle().foregroundColor(getUpdatedBackgroundColor()).position(x: size.width / 2.0, y: size.height - 22.0 - 11.0).frame(width: size.width, height: 22.0, alignment: .leading)
    }
    
    func chatsUpdateTimestampView(size: CGSize) -> some View {
        let text: String
        switch data {
        case let .peers(peersValue):
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
        default:
            text = ""
        }
        
        return HStack(alignment: .center, spacing: 0.0, content: {
            Text(text)
                .font(Font.system(size: 12.0))
                .foregroundColor(getUpdatedTextColor())
        }).position(x: size.width / 2.0, y: size.height - 22.0 - 11.0).frame(width: size.width, height: 22.0, alignment: .leading)
    }
    
    func getSeparatorColor() -> Color {
        switch colorScheme {
        case .light:
            return Color(.sRGB, red: 200.0 / 255.0, green: 199.0 / 255.0, blue: 204.0 / 255.0, opacity: 1.0)
        case .dark:
            return Color(.sRGB, red: 61.0 / 255.0, green: 61.0 / 255.0, blue: 64.0 / 255.0, opacity: 1.0)
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
    
    var body: some View {
        GeometryReader(content: { geometry in
            return ZStack {
                chatContentView(0, size: geometry.size)
                chatContentView(1, size: geometry.size)
                chatSeparatorView(size: geometry.size)
                chatsUpdateBackgroundView(size: geometry.size)
                chatsUpdateTimestampView(size: geometry.size)
            }
        })
        .padding(0.0)
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
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            return .placeholder
        }
        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            return .placeholder
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
            return .locked
        }
        
        let dataPath = rootPath + "/widget-data"
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: dataPath)), let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) {
            switch widgetData.content {
            case let .peers(peers):
                return .peers(peers)
            case .disabled:
                return .placeholder
            case .notAuthorized:
                return .locked
            }
        } else {
            return .placeholder
        }
    case let .peers(peers):
        return .peers(peers)
    }
}

@main
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
