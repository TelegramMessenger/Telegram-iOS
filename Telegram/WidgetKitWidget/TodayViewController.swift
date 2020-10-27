import UIKit
import NotificationCenter
import BuildConfig
import WidgetItems
import AppLockState
import SwiftUI
import WidgetKit

private func rootPathForBasePath(_ appGroupPath: String) -> String {
    return appGroupPath + "/telegram-data"
}

struct Provider: TimelineProvider {
    public typealias Entry = SimpleEntry
    
    func placeholder(in context: Context) -> SimpleEntry {
        return SimpleEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        var entries: [SimpleEntry] = []
        
        let currentDate = Date()
        for hourOffset in 0 ..< 1 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

enum PeersWidgetData {
    case placeholder
    case empty
    case locked
    case data(WidgetData)
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
            rowHeight = 88.0
            topOffset = 12.0
        default:
            rowCount = 2
            rowHeight = 76.0
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
        case let .data(data):
            switch data {
            case let .peers(peers):
                return AnyView(GeometryReader { geometry in
                    peersView(geometry: geometry, peers: peers)
                })
            default:
                return AnyView(ZStack {
                    Circle()
                })
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
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

func getWidgetData() -> PeersWidgetData {
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
        return .data(widgetData)
    } else {
        return .placeholder
    }
}

@main
struct Static_Widget: Widget {
    private let kind: String = "Static_Widget"

    public var body: some WidgetConfiguration {
        return StaticConfiguration(
            kind: kind,
            provider: Provider(),
            content: { entry in
                WidgetView(data: getWidgetData())
            }
        )
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName(presentationData.widgetGalleryTitle)
        .description(presentationData.widgetGalleryDescription)
    }
}
