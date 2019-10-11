import UIKit
import NotificationCenter
import BuildConfig
import WidgetItems

private func rootPathForBasePath(_ appGroupPath: String) -> String {
    return appGroupPath + "/telegram-data"
}

@objc(TodayViewController)
class TodayViewController: UIViewController, NCWidgetProviding {
    private var initializedInterface = false
    
    private var buildConfig: BuildConfig?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if self.initializedInterface {
            return
        }
        self.initializedInterface = true
        
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
        let dataPath = rootPath + "/widget-data"
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: dataPath)), let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) {
            self.setWidgetData(widgetData: widgetData)
        }
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        completionHandler(.newData)
    }
    
    @available(iOSApplicationExtension 10.0, *)
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        
    }
    
    private var widgetData: WidgetData?
    
    private func setWidgetData(widgetData: WidgetData) {
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
                let peerView = PeerView(accountPeerId: peers.accountPeerId, peer: peer, tapped: { [weak self] in
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
            peerView.frame = CGRect(origin: CGPoint(x: offset, y: 20.0), size: peerFrames[i].size)
            peerView.updateLayout(size: peerFrames[i].size)
            offset += peerFrames[i].width + spacing
        }
    }
}
