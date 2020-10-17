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
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    public let date: Date
}

struct Static_WidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        Text(entry.date, style: .time)
    }
}

enum PeersWidgetData {
    case placeholder
}

extension PeersWidgetData {
    static let previewData = PeersWidgetData.placeholder
}

struct WidgetView: View {
    let data: PeersWidgetData
    @Environment(\.widgetFamily) var widgetFamily
    
    func peerViews(geometry: GeometryProxy) -> some View {
        print("geometry: \(geometry.safeAreaInsets) frame \(geometry.frame(in: .local))")
        
        let defaultItemSize: CGFloat = 60.0
        
        let rowCount = Int(round(geometry.size.width / defaultItemSize))
        let itemSize = floor(geometry.size.width / CGFloat(rowCount))
        
        switch data {
        case .placeholder:
            return ZStack {
                ForEach(0 ..< rowCount, content: { i in
                    Circle().frame(width: itemSize, height: itemSize).position(x: CGFloat(i) * itemSize, y: 0.0).foregroundColor(.gray)
                })
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(.white)
            GeometryReader { geometry in
                peerViews(geometry: geometry)
            }
        }
        .padding(.all)
    }
}

private let presentationData: WidgetPresentationData = {
    let appBundleIdentifier = Bundle.main.bundleIdentifier!
    guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
        return WidgetPresentationData(applicationLockedString: "Unlock the app to use the widget", applicationStartRequiredString: "Open the app to use the widget")
    }
    let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
    
    let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
    //self.buildConfig = buildConfig
    
    let appGroupName = "group.\(baseAppBundleId)"
    let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
    
    guard let appGroupUrl = maybeAppGroupUrl else {
        return WidgetPresentationData(applicationLockedString: "Unlock the app to use the widget", applicationStartRequiredString: "Open the app to use the widget")
    }
    
    let rootPath = rootPathForBasePath(appGroupUrl.path)
    
    if let data = try? Data(contentsOf: URL(fileURLWithPath: widgetPresentationDataPath(rootPath: rootPath))), let value = try? JSONDecoder().decode(WidgetPresentationData.self, from: data) {
        return value
    } else {
        return WidgetPresentationData(applicationLockedString: "Unlock the app to use the widget", applicationStartRequiredString: "Open the app to use the widget")
    }
}()

@main
struct Static_Widget: Widget {
    private let kind: String = "Static_Widget"

    public var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider(),
            content: { entry in
                WidgetView(data: .previewData)
            }
        )
        .supportedFamilies([.systemMedium])
        .configurationDisplayName(presentationData.applicationLockedString)
        .description(presentationData.applicationStartRequiredString)
    }
}

@objc(TodayViewController)
class TodayViewController: UIViewController, NCWidgetProviding {
    private var initializedInterface = false
    
    private var buildConfig: BuildConfig?
    
    private var primaryColor: UIColor = .black
    private var placeholderLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            return
        }
        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        
        let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
        self.buildConfig = buildConfig
        
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            return
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        
        let presentationData: WidgetPresentationData
        if let data = try? Data(contentsOf: URL(fileURLWithPath: widgetPresentationDataPath(rootPath: rootPath))), let value = try? JSONDecoder().decode(WidgetPresentationData.self, from: data) {
            presentationData = value
        } else {
            presentationData = WidgetPresentationData(applicationLockedString: "Unlock the app to use the widget", applicationStartRequiredString: "Open the app to use the widget")
        }
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
            self.setPlaceholderText(presentationData.applicationLockedString)
            return
        }
        
        if self.initializedInterface {
            return
        }
        self.initializedInterface = true
        
        let dataPath = rootPath + "/widget-data"
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: dataPath)), let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) {
            self.setWidgetData(widgetData: widgetData, presentationData: presentationData)
        }
    }
    
    private func setPlaceholderText(_ text: String) {
        let fontSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        let placeholderLabel = UILabel()
        if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
            placeholderLabel.textColor = UIColor.label
        } else {
            placeholderLabel.textColor = self.primaryColor
        }
        placeholderLabel.font = UIFont.systemFont(ofSize: fontSize)
        placeholderLabel.text = text
        placeholderLabel.sizeToFit()
        self.placeholderLabel = placeholderLabel
        self.view.addSubview(placeholderLabel)
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        completionHandler(.newData)
    }
    
    @available(iOSApplicationExtension 10.0, iOS 10.0, *)
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        
    }
    
    private var widgetData: WidgetData?
    
    private func setWidgetData(widgetData: WidgetData, presentationData: WidgetPresentationData) {
        self.widgetData = widgetData
        self.peerViews.forEach {
            $0.removeFromSuperview()
        }
        self.peerViews = []
        switch widgetData {
        case .notAuthorized, .disabled:
            break
        case let .peers(peers):
            for peer in peers.peers {
                let peerView = PeerView(primaryColor: self.primaryColor, accountPeerId: peers.accountPeerId, peer: peer, tapped: { [weak self] in
                    if let strongSelf = self, let buildConfig = strongSelf.buildConfig {
                        if let url = URL(string: "\(buildConfig.appSpecificUrlScheme)://localpeer?id=\(peer.id)") {
                            strongSelf.extensionContext?.open(url, completionHandler: nil)
                        }
                    }
                })
                self.view.addSubview(peerView)
                self.peerViews.append(peerView)
            }
        }
        
        if self.peerViews.isEmpty {
            self.setPlaceholderText(presentationData.applicationStartRequiredString)
        } else {
            self.placeholderLabel?.removeFromSuperview()
            self.placeholderLabel = nil
        }
        
        if let size = self.validLayout {
            self.updateLayout(size: size)
        }
    }
    
    private var validLayout: CGSize?
    
    private var peerViews: [PeerView] = []
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.updateLayout(size: self.view.bounds.size)
    }
    
    private func updateLayout(size: CGSize) {
        self.validLayout = size
        
        if let placeholderLabel = self.placeholderLabel {
            placeholderLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - placeholderLabel.bounds.width) / 2.0), y: floor((size.height - placeholderLabel.bounds.height) / 2.0)), size: placeholderLabel.bounds.size)
        }
        
        let peerSize = CGSize(width: 70.0, height: 100.0)
        
        var peerFrames: [CGRect] = []
        
        var offset: CGFloat = 0.0
        for _ in self.peerViews {
            let peerFrame = CGRect(origin: CGPoint(x: offset, y: 10.0), size: peerSize)
            offset += peerFrame.size.width
            if peerFrame.maxX > size.width {
                break
            }
            peerFrames.append(peerFrame)
        }
        
        var totalSize: CGFloat = 0.0
        for i in 0 ..< peerFrames.count {
            totalSize += peerFrames[i].width
        }
        
        let spacing: CGFloat = floor((size.width - totalSize) /   CGFloat(peerFrames.count))
        offset = floor(spacing / 2.0)
        for i in 0 ..< peerFrames.count {
            let peerView = self.peerViews[i]
            peerView.frame = CGRect(origin: CGPoint(x: offset, y: 16.0), size: peerFrames[i].size)
            peerView.updateLayout(size: peerFrames[i].size)
            offset += peerFrames[i].width + spacing
        }
    }
}
