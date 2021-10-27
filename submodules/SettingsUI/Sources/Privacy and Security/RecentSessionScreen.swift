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
        case website(WebAuthorization)
    }
    private var controllerNode: RecentSessionScreenNode {
        return self.displayNode as! RecentSessionScreenNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let subject: RecentSessionScreen.Subject
    private let remove: () -> Void
    
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
    
    init(context: AccountContext, subject: RecentSessionScreen.Subject, remove: @escaping () -> Void) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.subject = subject
        self.remove = remove
        
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
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let fieldBackgroundNode: ASDisplayNode
    private let deviceTitleNode: ImmediateTextNode
    private let deviceValueNode: ImmediateTextNode
    private let firstSeparatorNode: ASDisplayNode
    private let locationTitleNode: ImmediateTextNode
    private let locationValueNode: ImmediateTextNode
    private let secondSeparatorNode: ASDisplayNode
    private let ipTitleNode: ImmediateTextNode
    private let ipValueNode: ImmediateTextNode
    
    private let cancelButton: HighlightableButtonNode
    private let terminateButton: SolidRoundedButtonNode
        
    private var containerLayout: (ContainerViewLayout, CGFloat)?
        
    var present: ((ViewController) -> Void)?
    var remove: (() -> Void)?
    var dismiss: (() -> Void)?
    
    init(context: AccountContext, presentationData: PresentationData, controller: RecentSessionScreen, subject: RecentSessionScreen.Subject) {
        self.context = context
        self.controller = controller
        self.presentationData = presentationData
        self.subject = subject
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
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
        self.textNode = ImmediateTextNode()
        
        self.fieldBackgroundNode = ASDisplayNode()
        self.fieldBackgroundNode.clipsToBounds = true
        self.fieldBackgroundNode.cornerRadius = 11
        self.fieldBackgroundNode.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
        
        self.deviceTitleNode = ImmediateTextNode()
        self.deviceValueNode = ImmediateTextNode()
        
        self.locationTitleNode = ImmediateTextNode()
        self.locationValueNode = ImmediateTextNode()
        
        self.ipTitleNode = ImmediateTextNode()
        self.ipValueNode = ImmediateTextNode()
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setImage(closeButtonImage(theme: self.presentationData.theme), for: .normal)
                
        self.terminateButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemBlocksBackgroundColor, foregroundColor: self.presentationData.theme.list.itemDestructiveColor), font: .regular, height: 44.0, cornerRadius: 11.0, gloss: false)
        
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        let title: String
        let subtitle: String
        let subtitleActive: Bool
        let device: String
        let location: String
        let ip: String
        switch subject {
            case let .session(session):
                self.terminateButton.title = self.presentationData.strings.AuthSessions_View_TerminateSession
                title = "\(session.appName) \(session.appVersion)"
                if session.isCurrent {
                    subtitle = presentationData.strings.Presence_online
                    subtitleActive = true
                } else {
                    subtitle = stringForRelativeActivityTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, relativeTimestamp: session.activityDate, relativeTo: timestamp)
                    subtitleActive = false
                }
                var deviceString = ""
                if !session.deviceModel.isEmpty {
                    deviceString = session.deviceModel
                }
                if !session.platform.isEmpty {
                    if !deviceString.isEmpty {
                        deviceString += ", "
                    }
                    deviceString += session.platform
                }
                if !session.systemVersion.isEmpty {
                    if !deviceString.isEmpty {
                        deviceString += ", "
                    }
                    deviceString += session.systemVersion
                }
                device = deviceString
                location = session.country
                ip = session.ip
            case let .website(website):
                self.terminateButton.title = self.presentationData.strings.AuthSessions_View_Logout
                title = website.domain
                subtitle = stringForRelativeActivityTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, relativeTimestamp: website.dateActive, relativeTo: timestamp)
                subtitleActive = false
            
                var deviceString = ""
                if !website.domain.isEmpty {
                    deviceString = website.domain
                }
                if !website.browser.isEmpty {
                    if !deviceString.isEmpty {
                        deviceString += ", "
                    }
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
        }
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(30.0), textColor: textColor)
        self.textNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(17.0), textColor: subtitleActive ? accentColor : secondaryTextColor)
        
        self.deviceTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.AuthSessions_View_Device, font: Font.regular(17.0), textColor: textColor)
        self.deviceValueNode.attributedText = NSAttributedString(string: device, font: Font.regular(17.0), textColor: secondaryTextColor)
      
        self.firstSeparatorNode = ASDisplayNode()
        
        self.locationTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.AuthSessions_View_Location, font: Font.regular(17.0), textColor: textColor)
        self.locationValueNode.attributedText = NSAttributedString(string: location, font: Font.regular(17.0), textColor: secondaryTextColor)
      
        self.secondSeparatorNode = ASDisplayNode()
        
        self.ipTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.AuthSessions_View_IP, font: Font.regular(17.0), textColor: textColor)
        self.ipValueNode.attributedText = NSAttributedString(string: ip, font: Font.regular(17.0), textColor: secondaryTextColor)
                
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
        
        self.contentContainerNode.addSubnode(self.locationTitleNode)
        self.contentContainerNode.addSubnode(self.locationValueNode)
        
        self.contentContainerNode.addSubnode(self.ipTitleNode)
        self.contentContainerNode.addSubnode(self.ipValueNode)
        
        self.contentContainerNode.addSubnode(self.terminateButton)
        self.topContentContainerNode.addSubnode(self.cancelButton)
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        self.terminateButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.terminateButton.isUserInteractionEnabled = false
                strongSelf.remove?()
            }
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        guard !self.animatedOut else {
            return
        }
        let previousTheme = self.presentationData.theme
        self.presentationData = presentationData
                        
        self.titleNode.attributedText = NSAttributedString(string: self.titleNode.attributedText?.string ?? "", font: Font.regular(30.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
        
        self.fieldBackgroundNode.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
        
        self.deviceTitleNode.attributedText = NSAttributedString(string: self.deviceTitleNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.locationTitleNode.attributedText = NSAttributedString(string: self.locationTitleNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.ipTitleNode.attributedText = NSAttributedString(string: self.ipTitleNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        
        self.deviceValueNode.attributedText = NSAttributedString(string: self.deviceValueNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
        self.locationValueNode.attributedText = NSAttributedString(string: self.locationValueNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
        self.ipValueNode.attributedText = NSAttributedString(string: self.ipValueNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
        
        if previousTheme !== presentationData.theme, let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
        
        self.cancelButton.setImage(closeButtonImage(theme: self.presentationData.theme), for: .normal)
        self.terminateButton.updateTheme(SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemBlocksBackgroundColor, foregroundColor: self.presentationData.theme.list.itemDestructiveColor))
    }
        
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture)))
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
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        let titleHeight: CGFloat = 54.0
        let contentHeight = titleHeight + bottomInset + 188.0
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentHeight), size: CGSize(width: width, height: contentHeight))
        let contentFrame = contentContainerFrame
        
        var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height + 2000.0))
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - 90.0, height: titleHeight))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 120.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - 90.0, height: titleHeight))
        let textFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - textSize.width) / 2.0), y: titleFrame.maxY), size: textSize)
        transition.updateFrame(node: self.textNode, frame: textFrame)
                
        let cancelSize = CGSize(width: 44.0, height: 44.0)
        let cancelFrame = CGRect(origin: CGPoint(x: contentFrame.width - cancelSize.width - 3.0, y: 6.0), size: cancelSize)
        transition.updateFrame(node: self.cancelButton, frame: cancelFrame)
        
        let buttonInset: CGFloat = 16.0
        let doneButtonHeight = self.terminateButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.terminateButton, frame: CGRect(x: buttonInset, y: contentHeight - doneButtonHeight - insets.bottom - 6.0, width: contentFrame.width, height: doneButtonHeight))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        transition.updateFrame(node: self.topContentContainerNode, frame: contentContainerFrame)
        
        var listInsets = UIEdgeInsets()
        listInsets.top += layout.safeInsets.left + 12.0
        listInsets.bottom += layout.safeInsets.right + 12.0
        
        
    }
}
