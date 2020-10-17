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

struct WidgetView: View {
    let data: PeersWidgetData
    
    func placeholder(geometry: GeometryProxy) -> some View {
        let defaultItemSize: CGFloat = 60.0
        let defaultPaddingFraction: CGFloat = 0.36
        
        let rowCount = Int(round(geometry.size.width / (defaultItemSize * (1.0 + defaultPaddingFraction))))
        let itemSize = floor(geometry.size.width / (CGFloat(rowCount) + defaultPaddingFraction * CGFloat(rowCount - 1)))
        
        let firstRowY = itemSize / 2.0
        let secondRowY = itemSize / 2.0 + geometry.size.height - itemSize
        
        return ZStack {
            ForEach(0 ..< rowCount * 2, content: { i in
                return Circle().frame(width: itemSize, height: itemSize).position(x: itemSize / 2.0 + floor(CGFloat(i % rowCount) * itemSize * (1.0 + defaultPaddingFraction)), y: i / rowCount == 0 ? firstRowY : secondRowY).foregroundColor(.gray)
            })
        }
    }
    
    func peersView(geometry: GeometryProxy, peers: WidgetDataPeers) -> some View {
        let defaultItemSize: CGFloat = 60.0
        let defaultPaddingFraction: CGFloat = 0.36
        
        let rowCount = Int(round(geometry.size.width / (defaultItemSize * (1.0 + defaultPaddingFraction))))
        let itemSize = floor(geometry.size.width / (CGFloat(rowCount) + defaultPaddingFraction * CGFloat(rowCount - 1)))
        
        let firstRowY = itemSize / 2.0
        let secondRowY = itemSize / 2.0 + geometry.size.height - itemSize
        
        return ZStack {
            ForEach(0 ..< min(peers.peers.count, rowCount * 2), content: { i in
                Link(destination: URL(string: "\(buildConfig.appSpecificUrlScheme)://localpeer?id=\(peers.peers[i].id)")!, label: {
                    Image(uiImage: avatarImage(accountPeerId: peers.accountPeerId, peer: peers.peers[i], size: CGSize(width: itemSize, height: itemSize)))
                        .frame(width: itemSize, height: itemSize)
                }).frame(width: itemSize, height: itemSize)
                .position(x: itemSize / 2.0 + floor(CGFloat(i % rowCount) * itemSize * (1.0 + defaultPaddingFraction)), y: i / rowCount == 0 ? firstRowY : secondRowY)
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
        .supportedFamilies([.systemMedium])
        .configurationDisplayName(presentationData.widgetGalleryTitle)
        .description(presentationData.widgetGalleryDescription)
    }
}
