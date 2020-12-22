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
                        
                        peers.append(WidgetDataPeer(id: peer.id.toInt64(), name: name, lastName: lastName, letters: peer.displayLetters, avatarPath: smallestImageRepresentation(peer.profileImageRepresentations).flatMap { representation in
                            return postbox.mediaBox.resourcePath(representation.resource)
                        }, badge: badge))
                    }
                }
                return WidgetDataPeers(accountPeerId: widgetPeers.accountPeerId, peers: peers)
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
    
    var body: some View {
        return ZStack {
            Image(uiImage: avatarImage(accountPeerId: accountPeerId, peer: peer, size: CGSize(width: itemSize, height: itemSize)))
                .clipShape(Circle())
            if let badge = peer.badge, badge.count > 0 {
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
        let defaultItemSize: CGFloat = 60.0
        let defaultPaddingFraction: CGFloat = 0.36
        
        let rowCount: Int
        let rowHeight: CGFloat
        let topOffset: CGFloat
        switch self.widgetFamily {
        case .systemLarge:
            rowCount = 4
            rowHeight = 80.0
            topOffset = 10.0
        case .systemMedium:
            rowCount = 2
            rowHeight = 70.0
            topOffset = 0.0
        case .systemSmall:
            rowCount = 2
            rowHeight = 72.0
            topOffset = 0.0
        @unknown default:
            rowCount = 2
            rowHeight = 72.0
            topOffset = 0.0
        }
        let columnCount = Int(round(geometry.size.width / (defaultItemSize * (1.0 + defaultPaddingFraction))))
        let itemSize = floor(geometry.size.width / (CGFloat(columnCount) + defaultPaddingFraction * CGFloat(columnCount - 1)))
        
        let rowOffset: [CGFloat] = [
            topOffset + itemSize / 2.0,
            topOffset + itemSize / 2.0 + rowHeight,
            topOffset + itemSize / 2.0 + rowHeight * 2,
            topOffset + itemSize / 2.0 + rowHeight * 3,
        ]
        
        return ZStack {
            ForEach(0 ..< min(peers.peers.count, columnCount * rowCount), content: { i in
                Link(destination: URL(string: linkForPeer(id: peers.peers[i].id))!, label: {
                    AvatarItemView(
                        accountPeerId: peers.accountPeerId,
                        peer: peers.peers[i],
                        itemSize: itemSize
                    ).frame(width: itemSize, height: itemSize)
                }).frame(width: itemSize, height: itemSize)
                .position(x: itemSize / 2.0 + floor(CGFloat(i % columnCount) * itemSize * (1.0 + defaultPaddingFraction)), y: rowOffset[i / columnCount])
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
    
    var body: some View {
        ZStack {
            peerViews()
        }
        .padding(.all)
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName(presentationData.widgetGalleryTitle)
        .description(presentationData.widgetGalleryDescription)
    }
}
