import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import SolidRoundedButtonNode
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import PresentationDataUtils
import AnimationUI
import MergeLists
import MediaResources
import StickerResources
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AvatarNode
import UndoUI

private func closeButtonImage(theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: 0x808084, alpha: 0.1).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(theme.actionSheet.inputClearButtonColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

final class RecentSessionScreen: ViewController {
    enum Subject {
        case session(RecentAccountSession)
        case website(WebAuthorization, Peer?)
    }
    private var controllerNode: RecentSessionScreenNode {
        return self.displayNode as! RecentSessionScreenNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let subject: RecentSessionScreen.Subject
    private let remove: (@escaping () -> Void) -> Void
    private let updateAcceptSecretChats: (Bool) -> Void
    private let updateAcceptIncomingCalls: (Bool) -> Void
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    var dismissed: (() -> Void)?
    
    var passthroughHitTestImpl: ((CGPoint) -> UIView?)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.passthroughHitTestImpl = self.passthroughHitTestImpl
            }
        }
    }
    
    init(context: AccountContext, subject: RecentSessionScreen.Subject, updateAcceptSecretChats: @escaping (Bool) -> Void, updateAcceptIncomingCalls: @escaping (Bool) -> Void, remove: @escaping (@escaping () -> Void) -> Void) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.subject = subject
        self.remove = remove
        self.updateAcceptSecretChats = updateAcceptSecretChats
        self.updateAcceptIncomingCalls = updateAcceptIncomingCalls
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = RecentSessionScreenNode(context: self.context, presentationData: self.presentationData, controller: self, subject: self.subject)
        self.controllerNode.passthroughHitTestImpl = self.passthroughHitTestImpl
        self.controllerNode.present = { [weak self] c in
            self?.present(c, in: .current)
        }
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.remove = { [weak self] in
            self?.remove({
                self?.controllerNode.animateOut()
            })
        }
        self.controllerNode.updateAcceptSecretChats = { [weak self] value in
            self?.updateAcceptSecretChats(value)
        }
        self.controllerNode.updateAcceptIncomingCalls = { [weak self] value in
            self?.updateAcceptIncomingCalls(value)
        }
    }
    
    override public func loadView() {
        super.loadView()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: completion)
        
        self.dismissed?()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private class RecentSessionScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private weak var controller: RecentSessionScreen?
    private let subject: RecentSessionScreen.Subject
    
    private let dimNode: ASDisplayNode
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let topContentContainerNode: SparseNode
    private let backgroundNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    private var iconNode: ASImageNode?
    private var animationBackgroundNode: ASDisplayNode?
    private var animationNode: AnimationNode?
    private var avatarNode: AvatarNode?
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let fieldBackgroundNode: ASDisplayNode
    private let deviceTitleNode: ImmediateTextNode
    private let deviceValueNode: ImmediateTextNode
    private let firstSeparatorNode: ASDisplayNode
    private let ipTitleNode: ImmediateTextNode
    private let ipValueNode: ImmediateTextNode
    private let secondSeparatorNode: ASDisplayNode
    private let locationTitleNode: ImmediateTextNode
    private let locationValueNode: ImmediateTextNode
    private let locationInfoNode: ImmediateTextNode
    
    private let acceptBackgroundNode: ASDisplayNode
    private let acceptHeaderNode: ImmediateTextNode
    private let secretChatsTitleNode: ImmediateTextNode
    private let secretChatsSwitchNode: SwitchNode
    private let incomingCallsTitleNode: ImmediateTextNode
    private let incomingCallsSwitchNode: SwitchNode
    private let acceptSeparatorNode: ASDisplayNode
    
    private let cancelButton: HighlightableButtonNode
    private let terminateButton: SolidRoundedButtonNode
        
    private var containerLayout: (ContainerViewLayout, CGFloat)?
        
    var present: ((ViewController) -> Void)?
    var remove: (() -> Void)?
    var dismiss: (() -> Void)?
    var updateAcceptSecretChats: ((Bool) -> Void)?
    var updateAcceptIncomingCalls: ((Bool) -> Void)?
    
    init(context: AccountContext, presentationData: PresentationData, controller: RecentSessionScreen, subject: RecentSessionScreen.Subject) {
        self.context = context
        self.controller = controller
        self.presentationData = presentationData
        self.subject = subject
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.showsVerticalScrollIndicator = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false
        
        self.topContentContainerNode = SparseNode()
        self.topContentContainerNode.isOpaque = false

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.clipsToBounds = true
        self.backgroundNode.cornerRadius = 16.0
                
        let backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        let textColor = self.presentationData.theme.list.itemPrimaryTextColor
        let accentColor = self.presentationData.theme.list.itemAccentColor
        let secondaryTextColor = self.presentationData.theme.list.itemSecondaryTextColor
    
        self.contentBackgroundNode = ASDisplayNode()
        self.contentBackgroundNode.backgroundColor = backgroundColor
                
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 2
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 1
        self.textNode.textAlignment = .center
        
        self.fieldBackgroundNode = ASDisplayNode()
        self.fieldBackgroundNode.clipsToBounds = true
        self.fieldBackgroundNode.cornerRadius = 11
        self.fieldBackgroundNode.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
                
        self.deviceTitleNode = ImmediateTextNode()
        self.deviceValueNode = ImmediateTextNode()
                
        self.ipTitleNode = ImmediateTextNode()
        self.ipValueNode = ImmediateTextNode()
        
        self.locationTitleNode = ImmediateTextNode()
        self.locationValueNode = ImmediateTextNode()
        self.locationInfoNode = ImmediateTextNode()
        
        self.acceptHeaderNode = ImmediateTextNode()
        self.secretChatsTitleNode = ImmediateTextNode()
        self.secretChatsSwitchNode = SwitchNode()
        self.incomingCallsTitleNode = ImmediateTextNode()
        self.incomingCallsSwitchNode = SwitchNode()
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setImage(closeButtonImage(theme: self.presentationData.theme), for: .normal)
                
        self.terminateButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemBlocksBackgroundColor, foregroundColor: self.presentationData.theme.list.itemDestructiveColor), font: .regular, height: 44.0, cornerRadius: 11.0, gloss: false)
        
        var hasSecretChats = false
        var hasIncomingCalls = false
        
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        let title: String
        let subtitle: String
        let subtitleActive: Bool
        let device: String
        let deviceTitle: String
        let location: String
        let ip: String
        switch subject {
            case let .session(session):
                self.terminateButton.title = self.presentationData.strings.AuthSessions_View_TerminateSession
                var appVersion = session.appVersion
                appVersion = appVersion.replacingOccurrences(of: "APPSTORE", with: "").replacingOccurrences(of: "BETA", with: "Beta").trimmingTrailingSpaces()
                
                if session.isCurrent {
                    subtitle = presentationData.strings.Presence_online
                    subtitleActive = true
                } else {
                    subtitle = stringForRelativeActivityTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, relativeTimestamp: session.activityDate, relativeTo: timestamp)
                    subtitleActive = false
                }
                deviceTitle = presentationData.strings.AuthSessions_View_Application
            
                var deviceString = ""
                if !session.deviceModel.isEmpty {
                    deviceString = session.deviceModel
                }
//                if !session.platform.isEmpty {
//                    if !deviceString.isEmpty {
//                        deviceString += ", "
//                    }
//                    deviceString += session.platform
//                }
//                if !session.systemVersion.isEmpty {
//                    if !deviceString.isEmpty {
//                        deviceString += ", "
//                    }
//                    deviceString += session.systemVersion
//                }
                title = deviceString
                device = "\(session.appName) \(appVersion)"
                location = session.country
                ip = session.ip
            
                let (icon, backgroundColor, animationName, colorsArray) = iconForSession(session)
                if let animationName = animationName {
                    var colors: [String: UIColor] = [:]
                    if let colorsArray = colorsArray {
                        for color in colorsArray {
                            colors[color] = backgroundColor
                        }
                    }
                    let animationNode = AnimationNode(animation: animationName, colors: colors, scale: 1.0)
                    self.animationNode = animationNode
                    
                    animationNode.animationView()?.logHierarchyKeypaths()
                    
                    let animationBackgroundNode = ASDisplayNode()
                    animationBackgroundNode.cornerRadius = 20.0
                    animationBackgroundNode.backgroundColor = backgroundColor
                    self.animationBackgroundNode = animationBackgroundNode
                } else if let icon = icon {
                    let iconNode = ASImageNode()
                    iconNode.displaysAsynchronously = false
                    iconNode.image = icon
                    self.iconNode = iconNode
                }
            
                self.secretChatsSwitchNode.isOn = session.flags.contains(.acceptsSecretChats)
                self.incomingCallsSwitchNode.isOn = session.flags.contains(.acceptsIncomingCalls)
            
                if !session.flags.contains(.passwordPending) {
                    hasIncomingCalls = true
                    if ![2040, 2496].contains(session.apiId)  {
                        hasSecretChats = true
                    }
                }
            case let .website(website, peer):
                self.terminateButton.title = self.presentationData.strings.AuthSessions_View_Logout
            
                if let peer = peer {
                    title = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                } else {
                    title = ""
                }
            
                subtitle = website.domain
                subtitleActive = false
            
                deviceTitle = presentationData.strings.AuthSessions_View_Browser
            
                var deviceString = ""
                if !website.browser.isEmpty {
                    deviceString += website.browser
                }
                if !website.platform.isEmpty {
                    if !deviceString.isEmpty {
                        deviceString += ", "
                    }
                    deviceString += website.platform
                }
                device = deviceString
                location = website.region
                ip = website.ip
            
                let avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 12.0))
                avatarNode.clipsToBounds = true
                avatarNode.cornerRadius = 17.0
                if let peer = peer.flatMap({ EnginePeer($0) }) {
                    avatarNode.setPeer(context: context, theme: presentationData.theme, peer: peer, authorOfMessage: nil, overrideImage: nil, emptyColor: nil, clipStyle: .none, synchronousLoad: false, displayDimensions: CGSize(width: 72.0, height: 72.0), storeUnrounded: false)
                }
                self.avatarNode = avatarNode
        }
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(30.0), textColor: textColor)
        self.textNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(17.0), textColor: subtitleActive ? accentColor : secondaryTextColor)
        
        self.deviceTitleNode.attributedText = NSAttributedString(string: deviceTitle, font: Font.regular(17.0), textColor: textColor)
        self.deviceValueNode.attributedText = NSAttributedString(string: device, font: Font.regular(17.0), textColor: secondaryTextColor)
      
        self.firstSeparatorNode = ASDisplayNode()
        self.firstSeparatorNode.backgroundColor = self.presentationData.theme.list.itemBlocksSeparatorColor
        
        self.ipTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.AuthSessions_View_IP, font: Font.regular(17.0), textColor: textColor)
        self.ipValueNode.attributedText = NSAttributedString(string: ip, font: Font.regular(17.0), textColor: secondaryTextColor)
        
        self.secondSeparatorNode = ASDisplayNode()
        self.secondSeparatorNode.backgroundColor = self.presentationData.theme.list.itemBlocksSeparatorColor
        
        self.locationTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.AuthSessions_View_Location, font: Font.regular(17.0), textColor: textColor)
        self.locationValueNode.attributedText = NSAttributedString(string: location, font: Font.regular(17.0), textColor: secondaryTextColor)
        self.locationInfoNode.attributedText = NSAttributedString(string: self.presentationData.strings.AuthSessions_View_LocationInfo, font: Font.regular(13.0), textColor: secondaryTextColor)
        self.locationInfoNode.maximumNumberOfLines = 4
        
        self.acceptBackgroundNode = ASDisplayNode()
        self.acceptBackgroundNode.clipsToBounds = true
        self.acceptBackgroundNode.cornerRadius = 11
        self.acceptBackgroundNode.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
        
        self.acceptHeaderNode.attributedText = NSAttributedString(string: self.presentationData.strings.AuthSessions_View_AcceptTitle.uppercased(), font: Font.regular(17.0), textColor: textColor)
        self.secretChatsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.AuthSessions_View_AcceptSecretChats, font: Font.regular(17.0), textColor: textColor)
        self.incomingCallsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.AuthSessions_View_AcceptIncomingCalls, font: Font.regular(17.0), textColor: textColor)
        
        self.acceptSeparatorNode = ASDisplayNode()
        self.acceptSeparatorNode.backgroundColor = self.presentationData.theme.list.itemBlocksSeparatorColor
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
        
        self.wrappingScrollNode.addSubnode(self.backgroundNode)
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        self.wrappingScrollNode.addSubnode(self.topContentContainerNode)
        
        self.backgroundNode.addSubnode(self.contentBackgroundNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        self.contentContainerNode.addSubnode(self.textNode)
        
        self.contentContainerNode.addSubnode(self.fieldBackgroundNode)
        
        self.contentContainerNode.addSubnode(self.deviceTitleNode)
        self.contentContainerNode.addSubnode(self.deviceValueNode)
        
        self.contentContainerNode.addSubnode(self.ipTitleNode)
        self.contentContainerNode.addSubnode(self.ipValueNode)
        
        self.contentContainerNode.addSubnode(self.locationTitleNode)
        self.contentContainerNode.addSubnode(self.locationValueNode)
        self.contentContainerNode.addSubnode(self.locationInfoNode)
        
        self.contentContainerNode.addSubnode(self.firstSeparatorNode)
        self.contentContainerNode.addSubnode(self.secondSeparatorNode)
        
        self.contentContainerNode.addSubnode(self.terminateButton)
        self.topContentContainerNode.addSubnode(self.cancelButton)
        
        self.iconNode.flatMap { self.contentContainerNode.addSubnode($0) }
        self.animationBackgroundNode.flatMap { self.contentContainerNode.addSubnode($0) }
        self.animationNode.flatMap { self.contentContainerNode.addSubnode($0) }
        self.avatarNode.flatMap { self.contentContainerNode.addSubnode($0) }
        
        if hasIncomingCalls {
            self.contentContainerNode.addSubnode(self.acceptBackgroundNode)
            self.contentContainerNode.addSubnode(self.acceptHeaderNode)
            if hasSecretChats {
                self.contentContainerNode.addSubnode(self.secretChatsTitleNode)
                self.contentContainerNode.addSubnode(self.secretChatsSwitchNode)
                
                self.secretChatsSwitchNode.valueUpdated = { [weak self] value in
                    if let strongSelf = self {
                        strongSelf.updateAcceptSecretChats?(value)
                    }
                }
                
                self.contentContainerNode.addSubnode(self.acceptSeparatorNode)
            }
            self.contentContainerNode.addSubnode(self.incomingCallsTitleNode)
            self.contentContainerNode.addSubnode(self.incomingCallsSwitchNode)
            
            self.incomingCallsSwitchNode.valueUpdated = { [weak self] value in
                if let strongSelf = self {
                    strongSelf.updateAcceptIncomingCalls?(value)
                }
            }
        }
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        self.terminateButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.remove?()
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture)))
        
        let titleGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleTitleLongPress(_:)))
        self.titleNode.view.addGestureRecognizer(titleGestureRecognizer)
        
        let deviceGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleDeviceLongPress(_:)))
        self.deviceValueNode.view.addGestureRecognizer(deviceGestureRecognizer)
        
        let locationGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLocationLongPress(_:)))
        self.locationValueNode.view.addGestureRecognizer(locationGestureRecognizer)
        
        let ipGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleIpLongPress(_:)))
        self.ipValueNode.view.addGestureRecognizer(ipGestureRecognizer)
        
        if let animationNode = self.animationNode {
            animationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.animationPressed)))
        }
    }
    
    @objc private func handleTitleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            self.displayCopyContextMenu(self.titleNode, self.titleNode.attributedText?.string ?? "")
        }
    }
    
    @objc private func handleDeviceLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            self.displayCopyContextMenu(self.deviceValueNode, self.deviceValueNode.attributedText?.string ?? "")
        }
    }
    
    @objc private func handleLocationLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            self.displayCopyContextMenu(self.locationValueNode, self.locationValueNode.attributedText?.string ?? "")
        }
    }
    
    @objc private func handleIpLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            self.displayCopyContextMenu(self.ipValueNode, self.ipValueNode.attributedText?.string ?? "")
        }
    }
    
    private func displayCopyContextMenu(_ node: ASDisplayNode, _ string: String) {
        if !string.isEmpty {
            var actions: [ContextMenuAction] = []
            actions.append(ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                UIPasteboard.general.string = string
                
                if let strongSelf = self {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                }
            }))
            let contextMenuController = ContextMenuController(actions: actions)
            self.controller?.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                if let strongSelf = self {
                    return (node, node.bounds.insetBy(dx: 0.0, dy: -2.0), strongSelf, strongSelf.view.bounds)
                } else {
                    return nil
                }
            }))
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        guard !self.animatedOut else {
            return
        }
        let previousTheme = self.presentationData.theme
        self.presentationData = presentationData
        
        self.contentBackgroundNode.backgroundColor =  self.presentationData.theme.list.blocksBackgroundColor
                        
        self.titleNode.attributedText = NSAttributedString(string: self.titleNode.attributedText?.string ?? "", font: Font.regular(30.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        
        let subtitleColor: UIColor
        if case let .session(session) = self.subject, session.isCurrent {
            subtitleColor = self.presentationData.theme.list.itemAccentColor
        } else {
            subtitleColor = self.presentationData.theme.list.itemSecondaryTextColor
        }
        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: subtitleColor)
        
        self.fieldBackgroundNode.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
        self.firstSeparatorNode.backgroundColor = self.presentationData.theme.list.itemBlocksSeparatorColor
        self.secondSeparatorNode.backgroundColor = self.presentationData.theme.list.itemBlocksSeparatorColor
        self.acceptSeparatorNode.backgroundColor = self.presentationData.theme.list.itemBlocksSeparatorColor
        
        self.deviceTitleNode.attributedText = NSAttributedString(string: self.deviceTitleNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.locationTitleNode.attributedText = NSAttributedString(string: self.locationTitleNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.ipTitleNode.attributedText = NSAttributedString(string: self.ipTitleNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        
        self.deviceValueNode.attributedText = NSAttributedString(string: self.deviceValueNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
        self.locationValueNode.attributedText = NSAttributedString(string: self.locationValueNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
        self.ipValueNode.attributedText = NSAttributedString(string: self.ipValueNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
        self.locationInfoNode.attributedText = NSAttributedString(string: self.locationInfoNode.attributedText?.string ?? "", font: Font.regular(13.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
        
        self.acceptHeaderNode.attributedText = NSAttributedString(string: self.acceptHeaderNode.attributedText?.string ?? "", font: Font.regular(13.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
        self.secretChatsTitleNode.attributedText = NSAttributedString(string: self.secretChatsTitleNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.incomingCallsTitleNode.attributedText = NSAttributedString(string: self.incomingCallsTitleNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.acceptBackgroundNode.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
        
        if previousTheme !== presentationData.theme, let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
        
        self.cancelButton.setImage(closeButtonImage(theme: self.presentationData.theme), for: .normal)
        self.terminateButton.updateTheme(SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemBlocksBackgroundColor, foregroundColor: self.presentationData.theme.list.itemDestructiveColor))
    }
    
    @objc func animationPressed() {
        if let animationNode = self.animationNode, !animationNode.isPlaying {
            animationNode.playOnce()
        }
    }
    
    @objc func cancelButtonPressed() {
        self.animateOut()
    }
    
    @objc func dimTapGesture() {
        self.cancelButtonPressed()
    }
    
    private var animatedOut = false
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        let targetBounds = self.bounds
        self.bounds = self.bounds.offsetBy(dx: 0.0, dy: -offset)
        self.dimNode.position = CGPoint(x: dimPosition.x, y: dimPosition.y - offset)
        transition.animateView({
            self.bounds = targetBounds
            self.dimNode.position = dimPosition
        })
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.animatedOut = true
        
        var dimCompleted = false
        var offsetCompleted = false
        
        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted && offsetCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        self.wrappingScrollNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            offsetCompleted = true
            internalCompletion()
        })
        
        
        self.controller?.window?.forEachController { c in
            if let c = c as? UndoOverlayController {
                c.dismiss()
            }
        }
    }
    
    var passthroughHitTestImpl: ((CGPoint) -> UIView?)?
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) {
                return self.dimNode.view
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.cancelButtonPressed()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstTime = self.containerLayout == nil
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 0.0)
                
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let iconSize = CGSize(width: 72.0, height: 72.0)
        let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - iconSize.width) / 2.0), y: 36.0), size: iconSize)
        
        if let iconNode = self.iconNode {
            transition.updateFrame(node: iconNode, frame: iconFrame)
        } else if let animationNode = self.animationNode, let animationBackgroundNode = self.animationBackgroundNode {
            transition.updateFrame(node: animationNode, frame: iconFrame)
            transition.updateFrame(node: animationBackgroundNode, frame: iconFrame)
            if #available(iOS 13.0, *) {
                animationBackgroundNode.layer.cornerCurve = .continuous
            }
            if isFirstTime {
                Queue.mainQueue().after(0.5) {
                    animationNode.playOnce()
                }
            }
        } else if let avatarNode = self.avatarNode {
            transition.updateFrame(node: avatarNode, frame: iconFrame)
        }
        
        let inset: CGFloat = 16.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - inset * 2.0, height: 100.0))
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - titleSize.width) / 2.0), y: 120.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - inset * 2.0, height: 60.0))
        let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - textSize.width) / 2.0), y: titleFrame.maxY), size: textSize)
        transition.updateFrame(node: self.textNode, frame: textFrame)
                
        let cancelSize = CGSize(width: 44.0, height: 44.0)
        let cancelFrame = CGRect(origin: CGPoint(x: width - cancelSize.width - 3.0, y: 6.0), size: cancelSize)
        transition.updateFrame(node: self.cancelButton, frame: cancelFrame)
        
        let fieldItemHeight: CGFloat = 44.0
        let fieldFrame = CGRect(x: inset, y: textFrame.maxY + 24.0, width: width - inset * 2.0, height: fieldItemHeight * 3.0)
        transition.updateFrame(node: self.fieldBackgroundNode, frame: fieldFrame)
        
        let maxFieldTitleWidth = (width - inset * 4.0) * 0.4
    
        let deviceTitleTextSize = self.deviceTitleNode.updateLayout(CGSize(width: maxFieldTitleWidth, height: fieldItemHeight))
        let deviceTitleTextFrame = CGRect(origin: CGPoint(x: fieldFrame.minX + inset, y: fieldFrame.minY + floorToScreenPixels((fieldItemHeight - deviceTitleTextSize.height) / 2.0)), size: deviceTitleTextSize)
        transition.updateFrame(node: self.deviceTitleNode, frame: deviceTitleTextFrame)
        
        let deviceValueTextSize = self.deviceValueNode.updateLayout(CGSize(width: fieldFrame.width - inset * 2.0 - deviceTitleTextSize.width - 10.0, height: fieldItemHeight))
        let deviceValueTextFrame = CGRect(origin: CGPoint(x: fieldFrame.maxX - deviceValueTextSize.width - inset, y: fieldFrame.minY + floorToScreenPixels((fieldItemHeight - deviceValueTextSize.height) / 2.0)), size: deviceValueTextSize)
        transition.updateFrame(node: self.deviceValueNode, frame: deviceValueTextFrame)
        
        transition.updateFrame(node: self.firstSeparatorNode, frame: CGRect(x: fieldFrame.minX + inset, y: fieldFrame.minY + fieldItemHeight, width: fieldFrame.width - inset, height: UIScreenPixel))
        
        let ipTitleTextSize = self.ipTitleNode.updateLayout(CGSize(width: maxFieldTitleWidth, height: fieldItemHeight))
        let ipTitleTextFrame = CGRect(origin: CGPoint(x: fieldFrame.minX + inset, y: fieldFrame.minY + fieldItemHeight  + floorToScreenPixels((fieldItemHeight - ipTitleTextSize.height) / 2.0)), size: ipTitleTextSize)
        transition.updateFrame(node: self.ipTitleNode, frame: ipTitleTextFrame)
        
        let ipValueTextSize = self.ipValueNode.updateLayout(CGSize(width: fieldFrame.width - inset * 2.0 - ipTitleTextSize.width - 10.0, height: fieldItemHeight))
        let ipValueTextFrame = CGRect(origin: CGPoint(x: fieldFrame.maxX - ipValueTextSize.width - inset, y: fieldFrame.minY + fieldItemHeight + floorToScreenPixels((fieldItemHeight - ipValueTextSize.height) / 2.0)), size: ipValueTextSize)
        transition.updateFrame(node: self.ipValueNode, frame: ipValueTextFrame)
        
        transition.updateFrame(node: self.secondSeparatorNode, frame: CGRect(x: fieldFrame.minX + inset, y: fieldFrame.minY + fieldItemHeight + fieldItemHeight, width: fieldFrame.width - inset, height: UIScreenPixel))
                
        let locationTitleTextSize = self.locationTitleNode.updateLayout(CGSize(width: maxFieldTitleWidth, height: fieldItemHeight))
        let locationTitleTextFrame = CGRect(origin: CGPoint(x: fieldFrame.minX + inset, y: fieldFrame.minY + fieldItemHeight + fieldItemHeight + floorToScreenPixels((fieldItemHeight - locationTitleTextSize.height) / 2.0)), size: locationTitleTextSize)
        transition.updateFrame(node: self.locationTitleNode, frame: locationTitleTextFrame)
        
        let locationValueTextSize = self.locationValueNode.updateLayout(CGSize(width: fieldFrame.width - inset * 2.0 - locationTitleTextSize.width - 10.0, height: fieldItemHeight))
        let locationValueTextFrame = CGRect(origin: CGPoint(x: fieldFrame.maxX - locationValueTextSize.width - inset, y: fieldFrame.minY + fieldItemHeight + fieldItemHeight + floorToScreenPixels((fieldItemHeight - locationValueTextSize.height) / 2.0)), size: locationValueTextSize)
        transition.updateFrame(node: self.locationValueNode, frame: locationValueTextFrame)
        
        let locationInfoTextSize = self.locationInfoNode.updateLayout(CGSize(width: fieldFrame.width - inset * 2.0, height: fieldItemHeight * 2.0))
        let locationInfoTextFrame = CGRect(origin: CGPoint(x: fieldFrame.minX + inset, y: fieldFrame.maxY + 6.0), size: locationInfoTextSize)
        transition.updateFrame(node: self.locationInfoNode, frame: locationInfoTextFrame)
        
        var contentHeight = locationInfoTextFrame.maxY + bottomInset + 64.0
        
        var secretFrame = CGRect(x: inset, y: locationInfoTextFrame.maxY + 59.0, width: width - inset * 2.0, height: fieldItemHeight)
        if let _ = self.secretChatsTitleNode.supernode {
            secretFrame.size.height += fieldItemHeight
        }
        transition.updateFrame(node: self.acceptBackgroundNode, frame: secretFrame)
        
        let secretChatsHeaderTextSize = self.acceptHeaderNode.updateLayout(CGSize(width: secretFrame.width - inset * 2.0, height: fieldItemHeight))
        let secretChatsHeaderTextFrame = CGRect(origin: CGPoint(x: secretFrame.minX + inset, y: secretFrame.minY - secretChatsHeaderTextSize.height - 6.0), size: secretChatsHeaderTextSize)
        transition.updateFrame(node: self.acceptHeaderNode, frame: secretChatsHeaderTextFrame)
        
        if let _ = self.secretChatsTitleNode.supernode {
            let secretChatsTitleTextSize = self.secretChatsTitleNode.updateLayout(CGSize(width: width - inset * 4.0 - 80.0, height: fieldItemHeight))
            let secretChatsTitleTextFrame = CGRect(origin: CGPoint(x: secretFrame.minX + inset, y: secretFrame.minY + floorToScreenPixels((fieldItemHeight - secretChatsTitleTextSize.height) / 2.0)), size: secretChatsTitleTextSize)
            transition.updateFrame(node: self.secretChatsTitleNode, frame: secretChatsTitleTextFrame)

            if let switchView = self.secretChatsSwitchNode.view as? UISwitch {
                if self.secretChatsSwitchNode.bounds.size.width.isZero {
                    switchView.sizeToFit()
                }
                let switchSize = switchView.bounds.size
                
                self.secretChatsSwitchNode.frame = CGRect(origin: CGPoint(x: fieldFrame.maxX - switchSize.width - inset, y: secretFrame.minY + floorToScreenPixels((fieldItemHeight - switchSize.height) / 2.0)), size: switchSize)
            }
        }
                
        let incomingCallsTitleTextSize = self.incomingCallsTitleNode.updateLayout(CGSize(width: width - inset * 4.0 - 80.0, height: fieldItemHeight))
        let incomingCallsTitleTextFrame = CGRect(origin: CGPoint(x: secretFrame.minX + inset, y: secretFrame.maxY - fieldItemHeight + floorToScreenPixels((fieldItemHeight - incomingCallsTitleTextSize.height) / 2.0)), size: incomingCallsTitleTextSize)
        transition.updateFrame(node: self.incomingCallsTitleNode, frame: incomingCallsTitleTextFrame)
        
        transition.updateFrame(node: self.acceptSeparatorNode, frame: CGRect(x: secretFrame.minX + inset, y: secretFrame.minY + fieldItemHeight, width: fieldFrame.width - inset, height: UIScreenPixel))

        if let switchView = self.incomingCallsSwitchNode.view as? UISwitch {
            if self.incomingCallsSwitchNode.bounds.size.width.isZero {
                switchView.sizeToFit()
            }
            let switchSize = switchView.bounds.size
            
            self.incomingCallsSwitchNode.frame = CGRect(origin: CGPoint(x:  fieldFrame.maxX - switchSize.width - inset, y: secretFrame.maxY - fieldItemHeight + floorToScreenPixels((fieldItemHeight - switchSize.height) / 2.0)), size: switchSize)
        }
        
        if let _ = self.acceptBackgroundNode.supernode {
            contentHeight += secretFrame.maxY - locationInfoTextFrame.maxY
        }
        contentHeight += 40.0
        
        let isCurrent: Bool
        if case let .session(session) = self.subject, session.isCurrent {
            isCurrent = true
        } else {
            isCurrent = false
        }
        
        if isCurrent {
            contentHeight -= 68.0
            self.terminateButton.isHidden = true
        } else {
            self.terminateButton.isHidden = false
        }
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        let scrollContentHeight = max(layout.size.height, contentHeight)
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: max(layout.statusBarHeight ?? 20.0, layout.size.height - contentHeight)), size: CGSize(width: width, height: contentHeight))
        let contentFrame = contentContainerFrame
        
        self.wrappingScrollNode.view.contentSize = CGSize(width: layout.size.width, height: scrollContentHeight)
        
        var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: width, height: contentFrame.height + 2000.0))
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        
        let doneButtonHeight = self.terminateButton.updateLayout(width: width - inset * 2.0, transition: transition)
        transition.updateFrame(node: self.terminateButton, frame: CGRect(x: inset, y: contentHeight - doneButtonHeight - 40.0 - insets.bottom - 6.0, width: width, height: doneButtonHeight))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        transition.updateFrame(node: self.topContentContainerNode, frame: contentContainerFrame)
    }
}
