import Foundation
import Display
import TelegramCore
import Postbox
import AsyncDisplayKit
import UIKit
import SwiftSignalKit

final class ProxyServerActionSheetController: ActionSheetController {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    private var isDismissed: Bool = false
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, server: ProxyServerSettings) {
        self.theme = theme
        self.strings = strings
        
        let sheetTheme = ActionSheetControllerTheme(presentationTheme: theme)
        super.init(theme: sheetTheme)
        
        self._ready.set(.single(true))
        
        var items: [ActionSheetItem] = []
        if case .mtp = server.connection {
            items.append(ActionSheetTextItem(title: strings.SocksProxySetup_AdNoticeHelp))
        }
        items.append(ProxyServerInfoItem(strings: strings, server: server))
        items.append(ProxyServerActionItem(account: account, strings: strings, server: server, dismiss: { [weak self] success in
            guard let strongSelf = self, !strongSelf.isDismissed else {
                return
            }
            strongSelf.isDismissed = true
            if success {
                strongSelf.present(OverlayStatusController(theme: theme, strings: strings, type: .shieldSuccess(strings.SocksProxySetup_ProxyEnabled)), in: .window(.root))
            }
            strongSelf.dismissAnimated()
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }))
        self.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                })
            ])
        ])
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ProxyServerInfoItem: ActionSheetItem {
    private let strings: PresentationStrings
    private let server: ProxyServerSettings
    
    init(strings: PresentationStrings, server: ProxyServerSettings) {
        self.strings = strings
        self.server = server
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ProxyServerInfoItemNode(theme: theme, strings: self.strings, server: self.server)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private let textFont = Font.regular(16.0)

private final class ProxyServerInfoItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    private let server: ProxyServerSettings
    
    private let fieldNodes: [(ImmediateTextNode, ImmediateTextNode)]
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, server: ProxyServerSettings) {
        self.theme = theme
        self.strings = strings
        self.server = server
        
        var fieldNodes: [(ImmediateTextNode, ImmediateTextNode)] = []
        let serverTitleNode = ImmediateTextNode()
        serverTitleNode.isUserInteractionEnabled = false
        serverTitleNode.displaysAsynchronously = false
        serverTitleNode.attributedText = NSAttributedString(string: strings.SocksProxySetup_Hostname, font: textFont, textColor: theme.secondaryTextColor)
        let serverTextNode = ImmediateTextNode()
        serverTextNode.isUserInteractionEnabled = false
        serverTextNode.displaysAsynchronously = false
        serverTextNode.attributedText = NSAttributedString(string: server.host, font: textFont, textColor: theme.primaryTextColor)
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
        
        self.fieldNodes = fieldNodes
        
        super.init(theme: theme)
        
        for (lhs, rhs) in fieldNodes {
            self.addSubnode(lhs)
            self.addSubnode(rhs)
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 36.0 * CGFloat(self.fieldNodes.count) + 12.0)
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        var offset: CGFloat = 15.0
        for (lhs, rhs) in self.fieldNodes {
            let lhsSize = lhs.updateLayout(CGSize(width: size.width - 18.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
            lhs.frame = CGRect(origin: CGPoint(x: 18, y: offset), size: lhsSize)
            
            let rhsSize = rhs.updateLayout(CGSize(width: max(1.0, size.width - 18 * 2.0 - lhsSize.width - 4.0), height: CGFloat.greatestFiniteMagnitude))
            rhs.frame = CGRect(origin: CGPoint(x: size.width - 18 - rhsSize.width, y: offset), size: rhsSize)
            
            offset += 36.0
        }
    }
}

private final class ProxyServerActionItem: ActionSheetItem {
    private let account: Account
    private let strings: PresentationStrings
    private let server: ProxyServerSettings
    private let dismiss: (Bool) -> Void
    private let present: (ViewController, Any?) -> Void
    
    init(account: Account, strings: PresentationStrings, server: ProxyServerSettings, dismiss: @escaping (Bool) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.account = account
        self.strings = strings
        self.server = server
        self.dismiss = dismiss
        self.present = present
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ProxyServerActionItemNode(account: self.account, theme: theme, strings: self.strings, server: self.server, dismiss: self.dismiss, present: self.present)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class ProxyServerActionItemNode: ActionSheetItemNode {
    private let account: Account
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    private let server: ProxyServerSettings
    private let dismiss: (Bool) -> Void
    private let present: (ViewController, Any?) -> Void
    
    private let buttonNode: HighlightableButtonNode
    private let titleNode: ImmediateTextNode
    private let activityIndicator: ActivityIndicator
    
    private let disposable = MetaDisposable()
    private var revertSettings: ProxySettings?
    
    init(account: Account, theme: ActionSheetControllerTheme, strings: PresentationStrings, server: ProxyServerSettings, dismiss: @escaping (Bool) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.server = server
        self.dismiss = dismiss
        self.present = present
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: strings.SocksProxySetup_ConnectAndSave, font: Font.regular(20.0), textColor: theme.controlAccentColor)
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.controlAccentColor, 24.0, 1.5, false))
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
            let _ = updateProxySettingsInteractively(postbox: self.account.postbox, network: self.account.network, { _ in
                return revertSettings
            })
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 57.0)
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        
        let labelSize = self.titleNode.updateLayout(CGSize(width: max(1.0, size.width - 10.0), height: size.height))
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        self.titleNode.frame = titleFrame
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: 14.0, y: titleFrame.minY - 0.0), size: CGSize(width: 24.0, height: 24.0))
    }
    
    @objc private func buttonPressed() {
        let proxyServerSettings = self.server
        let network = self.account.network
        let _ = (self.account.postbox.transaction { transaction -> ProxySettings in
            var currentSettings: ProxySettings?
            updateProxySettingsInteractively(transaction: transaction, network: network, { settings in
                currentSettings = settings
                var settings = settings
                if let index = settings.servers.index(of: proxyServerSettings) {
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
                strongSelf.titleNode.attributedText = NSAttributedString(string: strongSelf.strings.SocksProxySetup_Connecting, font: Font.regular(20.0), textColor: strongSelf.theme.primaryTextColor)
                strongSelf.activityIndicator.isHidden = false
                strongSelf.setNeedsLayout()
                
                let signal = strongSelf.account.network.connectionStatus
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
                            let _ = updateProxySettingsInteractively(postbox: strongSelf.account.postbox, network: strongSelf.account.network, { _ in
                                return previousSettings
                            })
                            strongSelf.titleNode.attributedText = NSAttributedString(string: strongSelf.strings.SocksProxySetup_ConnectAndSave, font: Font.regular(20.0), textColor: strongSelf.theme.controlAccentColor)
                            strongSelf.buttonNode.isUserInteractionEnabled = true
                            strongSelf.setNeedsLayout()
                            
                            let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                            
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.SocksProxySetup_FailedToConnect, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                        }
                    }
                }))
            }
        })
    }
}
