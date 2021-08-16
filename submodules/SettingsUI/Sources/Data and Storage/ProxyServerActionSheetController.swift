import Foundation
import UIKit
import Display
import TelegramCore
import Postbox
import AsyncDisplayKit
import UIKit
import SwiftSignalKit
import TelegramPresentationData
import ActivityIndicator
import OverlayStatusController
import AccountContext
import PresentationDataUtils
import UrlEscaping

public final class ProxyServerActionSheetController: ActionSheetController {
    private var presentationDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var isDismissed: Bool = false
    
    convenience public init(context: AccountContext, server: ProxyServerSettings) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.init(presentationData: presentationData, accountManager: context.sharedContext.accountManager, postbox: context.account.postbox, network: context.account.network, server: server, updatedPresentationData: context.sharedContext.presentationData)
    }
    
    public init(presentationData: PresentationData, accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox, network: Network, server: ProxyServerSettings, updatedPresentationData: Signal<PresentationData, NoError>?) {
        let sheetTheme = ActionSheetControllerTheme(presentationData: presentationData)
        super.init(theme: sheetTheme)
        
        self._ready.set(.single(true))
        
        var items: [ActionSheetItem] = []
        if case .mtp = server.connection {
            items.append(ActionSheetTextItem(title: presentationData.strings.SocksProxySetup_AdNoticeHelp))
        }
        items.append(ProxyServerInfoItem(strings: presentationData.strings, network: network, server: server))
        items.append(ProxyServerActionItem(accountManager:accountManager, postbox: postbox, network: network, presentationData: presentationData, server: server, dismiss: { [weak self] success in
            guard let strongSelf = self, !strongSelf.isDismissed else {
                return
            }
            strongSelf.isDismissed = true
            if success {
                strongSelf.present(OverlayStatusController(theme: presentationData.theme, type: .shieldSuccess(presentationData.strings.SocksProxySetup_ProxyEnabled, false)), in: .window(.root))
            }
            strongSelf.dismissAnimated()
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }))
        self.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                })
            ])
        ])
        
        if let updatedPresentationData = updatedPresentationData {
            self.presentationDisposable = updatedPresentationData.start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    strongSelf.theme = ActionSheetControllerTheme(presentationData: presentationData)
                }
            })
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDisposable?.dispose()
    }
}

private final class ProxyServerInfoItem: ActionSheetItem {
    private let strings: PresentationStrings
    private let network: Network
    private let server: ProxyServerSettings
    
    init(strings: PresentationStrings, network: Network, server: ProxyServerSettings) {
        self.strings = strings
        self.network = network
        self.server = server
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ProxyServerInfoItemNode(theme: theme, strings: self.strings, network: self.network, server: self.server)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private enum ProxyServerInfoStatusType {
    case generic(String)
    case failed(String)
}

private final class ProxyServerInfoItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    private let textFont: UIFont
    
    private let network: Network
    private let server: ProxyServerSettings
    
    private let fieldNodes: [(ImmediateTextNode, ImmediateTextNode)]
    private let statusTextNode: ImmediateTextNode
    
    private let statusDisposable = MetaDisposable()
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, network: Network, server: ProxyServerSettings) {
        self.theme = theme
        self.strings = strings
        self.network = network
        self.server = server
        
        self.textFont = Font.regular(floor(theme.baseFontSize * 16.0 / 17.0))
        
        var fieldNodes: [(ImmediateTextNode, ImmediateTextNode)] = []
        let serverTitleNode = ImmediateTextNode()
        serverTitleNode.isUserInteractionEnabled = false
        serverTitleNode.displaysAsynchronously = false
        serverTitleNode.attributedText = NSAttributedString(string: strings.SocksProxySetup_Hostname, font: textFont, textColor: theme.secondaryTextColor)
        let serverTextNode = ImmediateTextNode()
        serverTextNode.isUserInteractionEnabled = false
        serverTextNode.displaysAsynchronously = false
        serverTextNode.attributedText = NSAttributedString(string: urlEncodedStringFromString(server.host), font: textFont, textColor: theme.primaryTextColor)
        fieldNodes.append((serverTitleNode, serverTextNode))
        
        let portTitleNode = ImmediateTextNode()
        portTitleNode.isUserInteractionEnabled = false
        portTitleNode.displaysAsynchronously = false
        portTitleNode.attributedText = NSAttributedString(string: strings.SocksProxySetup_Port, font: textFont, textColor: theme.secondaryTextColor)
        let portTextNode = ImmediateTextNode()
        portTextNode.isUserInteractionEnabled = false
        portTextNode.displaysAsynchronously = false
        portTextNode.attributedText = NSAttributedString(string: "\(server.port)", font: textFont, textColor: theme.primaryTextColor)
        fieldNodes.append((portTitleNode, portTextNode))
        
        switch server.connection {
            case let .socks5(username, password):
                if let username = username {
                    let usernameTitleNode = ImmediateTextNode()
                    usernameTitleNode.isUserInteractionEnabled = false
                    usernameTitleNode.displaysAsynchronously = false
                    usernameTitleNode.attributedText = NSAttributedString(string: strings.SocksProxySetup_Username, font: textFont, textColor: theme.secondaryTextColor)
                    let usernameTextNode = ImmediateTextNode()
                    usernameTextNode.isUserInteractionEnabled = false
                    usernameTextNode.displaysAsynchronously = false
                    usernameTextNode.attributedText = NSAttributedString(string: username, font: textFont, textColor: theme.primaryTextColor)
                    fieldNodes.append((usernameTitleNode, usernameTextNode))
                }
                
                if let password = password {
                    let passwordTitleNode = ImmediateTextNode()
                    passwordTitleNode.isUserInteractionEnabled = false
                    passwordTitleNode.displaysAsynchronously = false
                    passwordTitleNode.attributedText = NSAttributedString(string: strings.SocksProxySetup_Password, font: textFont, textColor: theme.secondaryTextColor)
                    let passwordTextNode = ImmediateTextNode()
                    passwordTextNode.isUserInteractionEnabled = false
                    passwordTextNode.displaysAsynchronously = false
                    passwordTextNode.attributedText = NSAttributedString(string: password, font: textFont, textColor: theme.primaryTextColor)
                    fieldNodes.append((passwordTitleNode, passwordTextNode))
                }
            case .mtp:
                let passwordTitleNode = ImmediateTextNode()
                passwordTitleNode.isUserInteractionEnabled = false
                passwordTitleNode.displaysAsynchronously = false
                passwordTitleNode.attributedText = NSAttributedString(string: strings.SocksProxySetup_Secret, font: textFont, textColor: theme.secondaryTextColor)
                let passwordTextNode = ImmediateTextNode()
                passwordTextNode.isUserInteractionEnabled = false
                passwordTextNode.displaysAsynchronously = false
                passwordTextNode.attributedText = NSAttributedString(string: "•••••", font: textFont, textColor: theme.primaryTextColor)
                fieldNodes.append((passwordTitleNode, passwordTextNode))
        }
        
        let statusTitleNode = ImmediateTextNode()
        statusTitleNode.isUserInteractionEnabled = false
        statusTitleNode.displaysAsynchronously = false
        statusTitleNode.attributedText = NSAttributedString(string: strings.SocksProxySetup_Status, font: textFont, textColor: theme.secondaryTextColor)
        let statusTextNode = ImmediateTextNode()
        statusTextNode.isUserInteractionEnabled = false
        statusTextNode.displaysAsynchronously = false
        statusTextNode.attributedText = NSAttributedString(string: strings.SocksProxySetup_ProxyStatusChecking, font: textFont, textColor: theme.primaryTextColor)
        fieldNodes.append((statusTitleNode, statusTextNode))
        
        self.fieldNodes = fieldNodes
        self.statusTextNode = statusTextNode
        
        super.init(theme: theme)
        
        for (lhs, rhs) in fieldNodes {
            self.addSubnode(lhs)
            self.addSubnode(rhs)
        }
    }
    
    deinit {
        self.statusDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let statusesContext = ProxyServersStatuses(network: network, servers: .single([self.server]))
        self.statusDisposable.set((statusesContext.statuses()
        |> map { return $0.first?.value }
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self, let status = status {
                let statusType: ProxyServerInfoStatusType
                switch status {
                    case .checking:
                        statusType = .generic(strongSelf.strings.SocksProxySetup_ProxyStatusChecking)
                    case let .available(rtt):
                        let pingTime = Int(rtt * 1000.0)
                        statusType = .generic(strongSelf.strings.SocksProxySetup_ProxyStatusPing("\(pingTime)").string)
                    case .notAvailable:
                        statusType = .failed(strongSelf.strings.SocksProxySetup_ProxyStatusUnavailable)
                }
                strongSelf.setStatus(statusType)
            }
        }))
    }
    
    func setStatus(_ status: ProxyServerInfoStatusType) {
        let attributedString: NSAttributedString
        switch status {
            case let .generic(text):
                attributedString = NSAttributedString(string: text, font: textFont, textColor: theme.primaryTextColor)
            case let .failed(text):
                attributedString = NSAttributedString(string: text, font: textFont, textColor: theme.destructiveActionTextColor)
        }
        self.statusTextNode.attributedText = attributedString
        self.requestLayoutUpdate()
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 36.0 * CGFloat(self.fieldNodes.count) + 12.0)
        
        var offset: CGFloat = 15.0
        for (lhs, rhs) in self.fieldNodes {
            let lhsSize = lhs.updateLayout(CGSize(width: size.width - 18.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
            lhs.frame = CGRect(origin: CGPoint(x: 18, y: offset), size: lhsSize)
            
            let rhsSize = rhs.updateLayout(CGSize(width: max(1.0, size.width - 18 * 2.0 - lhsSize.width - 4.0), height: CGFloat.greatestFiniteMagnitude))
            rhs.frame = CGRect(origin: CGPoint(x: size.width - 18 - rhsSize.width, y: offset), size: rhsSize)
            
            offset += 36.0
        }
  
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}

private final class ProxyServerActionItem: ActionSheetItem {
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let postbox: Postbox
    private let network: Network
    private let presentationData: PresentationData
    private let server: ProxyServerSettings
    private let dismiss: (Bool) -> Void
    private let present: (ViewController, Any?) -> Void
    
    init(accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox, network: Network, presentationData: PresentationData, server: ProxyServerSettings, dismiss: @escaping (Bool) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.accountManager = accountManager
        self.postbox = postbox
        self.network = network
        self.presentationData = presentationData
        self.server = server
        self.dismiss = dismiss
        self.present = present
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ProxyServerActionItemNode(accountManager: self.accountManager, postbox: self.postbox, network: self.network, presentationData: self.presentationData, theme: theme, server: self.server, dismiss: self.dismiss, present: self.present)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class ProxyServerActionItemNode: ActionSheetItemNode {
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let postbox: Postbox
    private let network: Network
    private let presentationData: PresentationData
    private let theme: ActionSheetControllerTheme
    private let server: ProxyServerSettings
    private let dismiss: (Bool) -> Void
    private let present: (ViewController, Any?) -> Void
    
    private let buttonNode: HighlightableButtonNode
    private let titleNode: ImmediateTextNode
    private let activityIndicator: ActivityIndicator
    
    private let disposable = MetaDisposable()
    private var revertSettings: ProxySettings?
    
    init(accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox, network: Network, presentationData: PresentationData, theme: ActionSheetControllerTheme, server: ProxyServerSettings, dismiss: @escaping (Bool) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.accountManager = accountManager
        self.postbox = postbox
        self.network = network
        self.theme = theme
        self.presentationData = presentationData
        self.server = server
        self.dismiss = dismiss
        self.present = present
        
        let titleFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: presentationData.strings.SocksProxySetup_ConnectAndSave, font: titleFont, textColor: theme.controlAccentColor)
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.controlAccentColor, 22.0, 1.5, false))
        self.activityIndicator.isHidden = true
        
        self.buttonNode = HighlightableButtonNode()
        
        super.init(theme: theme)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.activityIndicator)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.backgroundColor = strongSelf.theme.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.backgroundNode.backgroundColor = strongSelf.theme.itemBackgroundColor
                    })
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.disposable.dispose()
        if let revertSettings = self.revertSettings {
            let _ = updateProxySettingsInteractively(accountManager: self.accountManager, { _ in
                return revertSettings
            })
        }
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 57.0)
        
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        
        let labelSize = self.titleNode.updateLayout(CGSize(width: max(1.0, size.width - 10.0), height: size.height))
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        let activitySize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        self.titleNode.frame = titleFrame
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: 14.0, y: titleFrame.minY - 0.0), size: activitySize)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }

    @objc private func buttonPressed() {
        let proxyServerSettings = self.server
        let _ = (self.accountManager.transaction { transaction -> ProxySettings in
            var currentSettings: ProxySettings?
            let _ = updateProxySettingsInteractively(transaction: transaction, { settings in
                currentSettings = settings
                var settings = settings
                if let index = settings.servers.firstIndex(of: proxyServerSettings) {
                    settings.servers[index] = proxyServerSettings
                    settings.activeServer = proxyServerSettings
                } else {
                    settings.servers.insert(proxyServerSettings, at: 0)
                    settings.activeServer = proxyServerSettings
                }
                settings.enabled = true
                return settings
            })
            return currentSettings ?? ProxySettings.defaultSettings
        } |> deliverOnMainQueue).start(next: { [weak self] previousSettings in
            if let strongSelf = self {
                strongSelf.revertSettings = previousSettings
                strongSelf.buttonNode.isUserInteractionEnabled = false
                strongSelf.titleNode.attributedText = NSAttributedString(string: strongSelf.presentationData.strings.SocksProxySetup_Connecting, font: Font.regular(20.0), textColor: strongSelf.theme.primaryTextColor)
                strongSelf.activityIndicator.isHidden = false
                strongSelf.requestLayoutUpdate()
                
                let signal = strongSelf.network.connectionStatus
                |> filter { status in
                    switch status {
                        case let .online(proxyAddress):
                            if proxyAddress == proxyServerSettings.host {
                                return true
                            } else {
                                return false
                            }
                        default:
                            return false
                    }
                }
                |> map { _ -> Bool in
                    return true
                }
                |> timeout(15.0, queue: Queue.mainQueue(), alternate: .single(false))
                |> deliverOnMainQueue
                strongSelf.disposable.set(signal.start(next: { value in
                    if let strongSelf = self {
                        strongSelf.activityIndicator.isHidden = true
                        strongSelf.revertSettings = nil
                        if value {
                            strongSelf.dismiss(true)
                        } else {
                            let _ = updateProxySettingsInteractively(accountManager: strongSelf.accountManager, { _ in
                                return previousSettings
                            })
                            strongSelf.titleNode.attributedText = NSAttributedString(string: strongSelf.presentationData.strings.SocksProxySetup_ConnectAndSave, font: Font.regular(20.0), textColor: strongSelf.theme.controlAccentColor)
                            strongSelf.buttonNode.isUserInteractionEnabled = true
                            strongSelf.requestLayoutUpdate()
                            
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.SocksProxySetup_FailedToConnect, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                        }
                    }
                }))
            }
        })
    }
}
