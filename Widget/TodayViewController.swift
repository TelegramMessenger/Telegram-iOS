import UIKit
import TelegramCore
import SwiftSignalKit
import Postbox
import NotificationCenter

private var installedSharedLogger = false

private func setupSharedLogger(_ path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(basePath: path))
    }
}

private let auxiliaryMethods = AccountAuxiliaryMethods(updatePeerChatInputState: { _, _ in
    return nil
}, fetchResource: { _, _, _, _ in
    return nil
}, fetchResourceMediaReferenceHash: { _ in
    return .single(nil)
}, prepareSecretThumbnailData: { _ in
    return nil
})

class TodayViewController: UIViewController, NCWidgetProviding {
    private var initializedInterface = false
    
    private let disposable = MetaDisposable()
    
    deinit {
        self.disposable.dispose()
    }
    
    private var snapshotView: UIImageView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.snapshotView?.removeFromSuperview()
        let snapshotView = UIImageView()
        if let path = self.getSnapshotPath(), let image = UIImage(contentsOfFile: path) {
            snapshotView.image = image
        }
        self.snapshotView = snapshotView
        self.view.addSubview(snapshotView)
        
        if self.initializedInterface {
            return
        }
        self.initializedInterface = true
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            return
        }
        
        let apiId: Int32 = BuildConfig.shared().apiId
        let languagesCategory = "ios"
        
        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            return
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        performAppGroupUpgrades(appGroupPath: appGroupUrl.path, rootPath: rootPath)
        
        TempBox.initializeShared(basePath: rootPath, processType: "widget", launchSpecificId: arc4random64())
        
        let logsPath = rootPath + "/today-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        
        setupSharedLogger(logsPath)
        
        let account: Signal<Account, NoError>
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        initializeAccountManagement()
        let accountManager = AccountManager(basePath: rootPath + "/accounts-metadata")
        
        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
        
        account = currentAccount(allocateIfNotExists: false, networkArguments: NetworkInitializationArguments(apiId: apiId, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0, appData: BuildConfig.shared().bundleData), supplementary: true, manager: accountManager, rootPath: rootPath, auxiliaryMethods: auxiliaryMethods, encryptionParameters: encryptionParameters)
        |> mapToSignal { account -> Signal<Account, NoError> in
            if let account = account {
                switch account {
                    case .upgrading:
                        return .complete()
                    case let .authorized(account):
                        return .single(account)
                    case .unauthorized:
                        return .complete()
                }
            } else {
                return .complete()
            }
        }
        
        let applicationInterface = account
        |> deliverOnMainQueue
        |> afterNext { [weak self] account in
            let _ = (recentPeers(account: account)
            |> deliverOnMainQueue).start(next: { peers in
                if let strongSelf = self {
                    switch peers {
                        case let .peers(peers):
                            strongSelf.setPeers(account: account, peers: peers.filter { !$0.isDeleted })
                        case .disabled:
                            strongSelf.setPeers(account: account, peers: [])
                    }
                }
            })
        }
        
        self.disposable.set(applicationInterface.start())
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        completionHandler(.newData)
    }
    
    @available(iOSApplicationExtension 10.0, *)
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        
    }
    
    private var peers: [Peer]?
    
    private func setPeers(account: Account, peers: [Peer]) {
        self.peers = peers
        self.peerViews.forEach {
            $0.removeFromSuperview()
        }
        self.peerViews = []
        for peer in peers {
            let peerView = PeerView(account: account, peer: peer, tapped: { [weak self] in
                if let strongSelf = self {
                    if let url = URL(string: "\(BuildConfig.shared().appSpecificUrlScheme)://localpeer?id=\(peer.id.toInt64())") {
                        strongSelf.extensionContext?.open(url, completionHandler: nil)
                    }
                }
            })
            self.view.addSubview(peerView)
            self.peerViews.append(peerView)
        }
        
        self.validSnapshotSize = nil
        if let size = self.validLayout {
            self.updateLayout(size: size)
        }
    }
    
    private var validLayout: CGSize?
    private var validSnapshotSize: CGSize?
    
    private var peerViews: [PeerView] = []
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.updateLayout(size: self.view.bounds.size)
    }
    
    private func updateLayout(size: CGSize) {
        self.validLayout = size
        
        if let image = self.snapshotView?.image {
            let scale = UIScreen.main.scale
            self.snapshotView?.frame = CGRect(origin: CGPoint(), size: CGSize(width: image.size.width / scale, height: image.size.height / scale))
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
            peerView.frame = CGRect(origin: CGPoint(x: offset, y: 20.0), size: peerFrames[i].size)
            peerView.updateLayout(size: peerFrames[i].size)
            offset += peerFrames[i].width + spacing
        }
        
        if self.peers != nil {
            self.snapshotView?.removeFromSuperview()
            if self.validSnapshotSize != size {
                self.validSnapshotSize = size
                self.updateSnapshot()
            }
        }
    }
    
    private func updateSnapshot() {
        if let path = self.getSnapshotPath() {
            DispatchQueue.main.async {
                UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, false, 0.0)
                self.view.drawHierarchy(in: self.view.bounds, afterScreenUpdates: false)
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                if let image = image, let data = UIImagePNGRepresentation(image) {
                    let _ = try? FileManager.default.removeItem(atPath: path)
                    do {
                        try data.write(to: URL(fileURLWithPath: path))
                    } catch let e {
                        print("\(e)")
                    }
                }
            }
        }
    }
    
    private func getSnapshotPath() -> String? {
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            return nil
        }
        
        let appGroupName = "group.\(appBundleIdentifier[..<lastDotRange.lowerBound])"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            return nil
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        return rootPath + "/widget-snapshot.png"
    }
}
