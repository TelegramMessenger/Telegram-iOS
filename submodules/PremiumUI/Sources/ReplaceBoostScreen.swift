import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import UndoUI
import Markdown
import TextFormat
import ButtonComponent
import PeerListItemComponent
import TelegramStringFormatting
import AvatarNode
import ResizableSheetComponent
import GlassBarButtonComponent
import ListSectionComponent

private final class ReplaceBoostSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let myBoostStatus: MyBoostStatus
    let selectedSlots: [Int32]
    let toggleSlot: (Int32) -> Void
    let presentController: (ViewController) -> Void
    let giftPremium: () -> Void
    
    init(context: AccountContext, peerId: EnginePeer.Id, myBoostStatus: MyBoostStatus, selectedSlots: [Int32], toggleSlot: @escaping (Int32) -> Void, presentController: @escaping (ViewController) -> Void, giftPremium: @escaping () -> Void) {
        self.context = context
        self.peerId = peerId
        self.myBoostStatus = myBoostStatus
        self.selectedSlots = selectedSlots
        self.toggleSlot = toggleSlot
        self.presentController = presentController
        self.giftPremium = giftPremium
    }
    
    static func ==(lhs: ReplaceBoostSheetContent, rhs: ReplaceBoostSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.myBoostStatus != rhs.myBoostStatus {
            return false
        }
        if lhs.selectedSlots != rhs.selectedSlots {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let disposable = MetaDisposable()
        private var timer: SwiftSignalKit.Timer?
        
        var peer: EnginePeer?
        var currentTime: Int32
        
        init(context: AccountContext, peerId: EnginePeer.Id) {
            self.currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            
            super.init()
            
            self.disposable.set((context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                guard let self else {
                    return
                }
                self.peer = peer
                self.updated()
            }))
            
            self.timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                if let self {
                    self.currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                    self.updated()
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
        
        deinit {
            self.disposable.dispose()
            self.timer?.invalidate()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, peerId: self.peerId)
    }
    
    static var body: Body {
        let header = Child(ReplaceBoostHeaderComponent.self)
        let description = Child(MultilineTextComponent.self)
        let boostsSection = Child(ListSectionComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let state = context.state
            let availableSize = context.availableSize
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            
            let textSideInset: CGFloat = 32.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let rightSideInset: CGFloat = 16.0 + environment.safeInsets.right
            let bandCenterX: CGFloat = environment.safeInsets.left + (availableSize.width - environment.safeInsets.left - environment.safeInsets.right) / 2.0
            
            let occupiedBoosts = component.myBoostStatus.boosts.filter { $0.peer?.id != component.peerId && $0.peer != nil }.sorted { lhs, rhs in
                return lhs.date < rhs.date
            }
            
            var otherPeers: [EnginePeer] = []
            for slot in component.selectedSlots {
                if let peer = occupiedBoosts.first(where: { $0.slot == slot })?.peer {
                    if !otherPeers.contains(where: { $0.id == peer.id }) {
                        otherPeers.append(peer)
                    }
                }
            }
            
            var contentHeight: CGFloat = 66.0
            
            let avatarHeight: CGFloat = 60.0
            if let mainPeer = state.peer {
                let header = header.update(
                    component: ReplaceBoostHeaderComponent(
                        context: component.context,
                        theme: theme,
                        mainPeer: mainPeer,
                        otherPeers: otherPeers.reversed()
                    ),
                    availableSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: avatarHeight),
                    transition: context.transition
                )
                context.add(header
                    .position(CGPoint(x: bandCenterX, y: contentHeight + header.size.height / 2.0))
                )
            }
            contentHeight += avatarHeight + 20.0
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.list.itemPrimaryTextColor
            let linkColor = theme.list.itemAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with({ $0 }))
            
            var channelName = state.peer?.compactDisplayTitle ?? ""
            if channelName.count > 48 {
                channelName = "\(channelName.prefix(48))..."
            }
            let descriptionString = strings.ReassignBoost_DescriptionWithLink(channelName, "\(premiumConfiguration.boostsPerGiftCount)").string
            
            let giftPremium = component.giftPremium
            let description = description.update(
                component: MultilineTextComponent(
                    text: .markdown(text: descriptionString, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1,
                    highlightColor: theme.list.itemAccentColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        giftPremium()
                    }
                ),
                environment: {},
                availableSize: CGSize(width: availableSize.width - sideInset - rightSideInset - textSideInset, height: availableSize.height),
                transition: .immediate
            )
            context.add(description
                .position(CGPoint(x: bandCenterX, y: contentHeight + description.size.height / 2.0))
            )
            contentHeight += description.size.height + 24.0
            
            let hasSelection = occupiedBoosts.count > 1
            
            let accountContext = component.context
            let toggleSlot = component.toggleSlot
            let presentController = component.presentController
            
            var boostItems: [AnyComponentWithIdentity<Empty>] = []
            for boost in occupiedBoosts {
                guard let peer = boost.peer else {
                    continue
                }
                
                var isEnabled = true
                let subtitle: String
                if let cooldownUntil = boost.cooldownUntil, cooldownUntil > state.currentTime {
                    let duration = cooldownUntil - state.currentTime
                    let durationValue = stringForDuration(duration, position: nil)
                    subtitle = strings.ReassignBoost_AvailableIn(durationValue).string
                    isEnabled = false
                } else {
                    let expiresValue = stringForDate(timestamp: boost.expires, strings: strings)
                    subtitle = strings.ReassignBoost_ExpiresOn(expiresValue).string
                }
                
                boostItems.append(
                    AnyComponentWithIdentity(
                        id: AnyHashable(boost.slot),
                        component: AnyComponent(
                            PeerListItemComponent(
                                context: accountContext,
                                theme: theme,
                                strings: strings,
                                style: .generic,
                                sideInset: 0.0,
                                title: peer.compactDisplayTitle,
                                peer: peer,
                                subtitle: PeerListItemComponent.Subtitle(text: subtitle, color: .neutral),
                                subtitleAccessory: .none,
                                presence: nil,
                                selectionState: hasSelection ? .editing(isSelected: component.selectedSlots.contains(boost.slot), isTinted: false) : .none,
                                selectionPosition: .right,
                                isEnabled: isEnabled,
                                hasNext: false,
                                action: { _, _, _ in
                                    guard hasSelection else {
                                        return
                                    }
                                    if isEnabled {
                                        toggleSlot(boost.slot)
                                    } else {
                                        let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
                                        let undoController = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: strings.ReassignBoost_WaitForCooldown("\(premiumConfiguration.boostsPerGiftCount)").string, timeout: nil, customUndoText: nil), elevatedLayout: false, position: .top, action: { _ in return true })
                                        presentController(undoController)
                                    }
                                }
                            )
                        )
                    )
                )
            }
            
            let boostsSection = boostsSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: boostItems
                ),
                availableSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: 100000.0),
                transition: context.transition
            )
            context.add(boostsSection
                .position(CGPoint(x: sideInset + boostsSection.size.width / 2.0, y: contentHeight + boostsSection.size.height / 2.0))
            )
            contentHeight += boostsSection.size.height + 24.0
            
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            contentHeight += 52.0
            contentHeight += buttonInsets.bottom
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
}

private final class ReplaceBoostSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let myBoostStatus: MyBoostStatus
    let initiallySelectedSlot: Int32?
    
    init(context: AccountContext, peerId: EnginePeer.Id, myBoostStatus: MyBoostStatus, initiallySelectedSlot: Int32?) {
        self.context = context
        self.peerId = peerId
        self.myBoostStatus = myBoostStatus
        self.initiallySelectedSlot = initiallySelectedSlot
    }
    
    static func ==(lhs: ReplaceBoostSheetComponent, rhs: ReplaceBoostSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.myBoostStatus != rhs.myBoostStatus {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var selectedSlots: [Int32] = []
        var inProgress = false
        
        init(initiallySelectedSlot: Int32?) {
            super.init()
            
            if let initiallySelectedSlot {
                self.selectedSlots.append(initiallySelectedSlot)
            }
        }
    }
    
    func makeState() -> State {
        return State(initiallySelectedSlot: self.initiallySelectedSlot)
    }
    
    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let component = context.component
            let state = context.state
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            
            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                } else if let controller = controller() {
                    controller.dismiss(completion: nil)
                }
            }
            
            let accountContext = component.context
            
            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(ReplaceBoostSheetContent(
                        context: accountContext,
                        peerId: component.peerId,
                        myBoostStatus: component.myBoostStatus,
                        selectedSlots: state.selectedSlots,
                        toggleSlot: { [weak state] slot in
                            guard let state, !state.inProgress else {
                                return
                            }
                            if state.selectedSlots.contains(slot) {
                                state.selectedSlots.removeAll(where: { $0 == slot })
                            } else {
                                state.selectedSlots.append(slot)
                            }
                            state.updated(transition: .easeInOut(duration: 0.2))
                        },
                        presentController: { c in
                            guard let controller = controller() as? ReplaceBoostScreen else {
                                return
                            }
                            controller.dismissAllTooltips()
                            controller.present(c, in: .window(.root))
                        },
                        giftPremium: {
                            guard let controller = controller() else {
                                return
                            }
                            let navigationController = controller.navigationController
                            animateOut.invoke(Action { _ in
                                controller.dismiss(completion: {
                                    let giftController = accountContext.sharedContext.makePremiumGiftController(context: accountContext, source: .channelBoost, completion: nil)
                                    navigationController?.pushViewController(giftController, animated: true)
                                })
                            })
                        }
                    )),
                    titleItem: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: strings.ReassignBoost_Title, font: Font.semibold(17.0), textColor: theme.list.itemPrimaryTextColor)))
                    ),
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    bottomItem: AnyComponent(
                        ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .glass,
                                color: theme.list.itemCheckColors.fillColor,
                                foreground: theme.list.itemCheckColors.foregroundColor,
                                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            ),
                            content: AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(ButtonTextContentComponent(
                                    text: strings.ReassignBoost_ReassignBoosts,
                                    badge: state.selectedSlots.count,
                                    textColor: theme.list.itemCheckColors.foregroundColor,
                                    badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                    badgeForeground: theme.list.itemCheckColors.fillColor,
                                    badgeStyle: .roundedRectangle,
                                    badgeIconName: "Premium/BoostButtonIcon",
                                    combinedAlignment: true
                                ))
                            ),
                            isEnabled: !state.selectedSlots.isEmpty,
                            displaysProgress: state.inProgress,
                            action: { [weak state] in
                                guard let state, !state.inProgress, !state.selectedSlots.isEmpty else {
                                    return
                                }
                                state.inProgress = true
                                state.updated()
                                (controller() as? ReplaceBoostScreen)?.replaceBoosts(state.selectedSlots)
                            }
                        )
                    ),
                    backgroundColor: .color(theme.list.modalBlocksBackgroundColor),
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: environment.inputHeight,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        screenSize: context.availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public class ReplaceBoostScreen: ViewControllerComponentContainer {
    fileprivate let replaceBoosts: ([Int32]) -> Void
    
    public init(context: AccountContext, peerId: EnginePeer.Id, myBoostStatus: MyBoostStatus, replaceBoosts: @escaping ([Int32]) -> Void) {
        var initiallySelectedSlot: Int32?
        let occupiedBoosts = myBoostStatus.boosts.filter { $0.peer?.id != peerId && $0.peer != nil }
        if occupiedBoosts.count == 1, let boost = occupiedBoosts.first {
            initiallySelectedSlot = boost.slot
        }
        
        self.replaceBoosts = replaceBoosts
        
        super.init(
            context: context,
            component: ReplaceBoostSheetComponent(
                context: context,
                peerId: peerId,
                myBoostStatus: myBoostStatus,
                initiallySelectedSlot: initiallySelectedSlot
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.dismissAllTooltips()
    }
}

private func generateBoostIcon(theme: PresentationTheme) -> UIImage? {
    if let image = UIImage(bundleImageName: "Premium/AvatarBoost") {
        let size = CGSize(width: image.size.width + 4.0, height: image.size.height + 4.0)
        return generateImage(size, contextGenerator: { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            context.clear(bounds)
            if let cgImage = image.cgImage {
                context.draw(cgImage, in: CGRect(origin: CGPoint(x: 2.0, y: 2.0), size: image.size))
            }
            
            let lineWidth = 2.0 - UIScreenPixel
            context.setLineWidth(lineWidth)
            context.setStrokeColor(theme.list.modalBlocksBackgroundColor.cgColor)
            context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0 + UIScreenPixel, dy: lineWidth / 2.0 + UIScreenPixel))
        }, opaque: false)
    }
    return nil
}

private final class ReplaceBoostHeaderComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let mainPeer: EnginePeer
    let otherPeers: [EnginePeer]

    init(context: AccountContext, theme: PresentationTheme, mainPeer: EnginePeer, otherPeers: [EnginePeer]) {
        self.context = context
        self.theme = theme
        self.mainPeer = mainPeer
        self.otherPeers = otherPeers
    }

    static func ==(lhs: ReplaceBoostHeaderComponent, rhs: ReplaceBoostHeaderComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.mainPeer != rhs.mainPeer {
            return false
        }
        if lhs.otherPeers != rhs.otherPeers {
            return false
        }
        return true
    }
    
    final class WrapperAvatarView: UIView {
        let backgroundView = UIView()
        let avatarNode: AvatarNode
        let badgeImageView: UIImageView
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
            self.avatarNode.frame = CGRect(origin: .zero, size: CGSize(width: 60.0, height: 60.0))
            self.backgroundView.frame = self.avatarNode.frame.insetBy(dx: -3.0 + UIScreenPixel, dy: -3.0 + UIScreenPixel)
            self.backgroundView.layer.cornerRadius = self.backgroundView.frame.height / 2.0
            
            self.badgeImageView = UIImageView(frame: CGRect(x: 60.0 - 24.0, y: 60.0 - 24.0, width: 28.0, height: 28.0))
            self.badgeImageView.alpha = 0.0
            
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            
            self.addSubview(self.backgroundView)
            self.addSubnode(self.avatarNode)
            self.addSubview(self.badgeImageView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    

    final class View: UIView {
        private let containerView = UIView()
        private let avatarNode: AvatarNode
        private let arrowView: UIImageView
        
        private var otherAvatarNodes: [EnginePeer.Id: WrapperAvatarView] = [:]
        
        private var component: ReplaceBoostHeaderComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
            self.avatarNode.frame = CGRect(origin: .zero, size: CGSize(width: 60.0, height: 60.0))
            
            self.arrowView = UIImageView(image: UIImage(bundleImageName: "Peer Info/AlertArrow")?.withRenderingMode(.alwaysTemplate))
          
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.arrowView)
            self.containerView.addSubnode(self.avatarNode)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var badgeImage: UIImage?
        func update(component: ReplaceBoostHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let avatarSize = CGSize(width: 60.0, height: 60.0)
            
            let spacing: CGFloat = 27.0
            var totalWidth: CGFloat = avatarSize.width
            if !component.otherPeers.isEmpty {
                totalWidth += spacing
                totalWidth += avatarSize.width
                
                if component.otherPeers.count > 1 {
                    totalWidth += (avatarSize.width / 2.0) * CGFloat(component.otherPeers.count - 1)
                }
            }
            
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: (availableSize.width - totalWidth) / 2.0, y: 0.0), size: CGSize(width: totalWidth, height: avatarSize.height)))

            var originX: CGFloat = 0.0
            var validIds: [EnginePeer.Id] = []
            for i in 0 ..< component.otherPeers.count {
                let peer = component.otherPeers[i]
                validIds.append(peer.id)
                
                let avatarView: WrapperAvatarView
                var avatarTransition = transition
                if let current = self.otherAvatarNodes[peer.id] {
                    avatarView = current
                } else {
                    avatarTransition = .immediate
                     
                    avatarView = WrapperAvatarView()
                    avatarView.bounds = CGRect(origin: .zero, size: avatarSize)
                    avatarView.avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, synchronousLoad: true)
                    avatarView.backgroundView.backgroundColor = component.theme.list.modalBlocksBackgroundColor
                    
                    if self.badgeImage == nil {
                        self.badgeImage = generateBoostIcon(theme: component.theme)
                    }
                    avatarView.badgeImageView.image = self.badgeImage
                    
                    self.otherAvatarNodes[peer.id] = avatarView
                    self.containerView.insertSubview(avatarView, at: 0)
                    
                    avatarView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    avatarView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
                
                let isLast = i == component.otherPeers.count - 1
                avatarTransition.setAlpha(view: avatarView.badgeImageView, alpha: isLast ? 1.0 : 0.0)
                avatarTransition.setScale(view: avatarView.badgeImageView, scale: isLast ? 1.0 : 0.1)
                
                avatarTransition.setPosition(view: avatarView, position: CGPoint(x: originX + avatarSize.width / 2.0, y: avatarSize.height / 2.0))
                if isLast {
                    originX += avatarSize.width
                } else {
                    originX += avatarSize.width / 2.0
                }
            }
            
            if !component.otherPeers.isEmpty {
                originX += spacing
            }
            
            self.arrowView.tintColor = component.theme.list.itemSecondaryTextColor
            transition.setAlpha(view: self.arrowView, alpha: component.otherPeers.isEmpty ? 0.0 : 1.0)
            transition.setScale(view: self.arrowView, scale: component.otherPeers.isEmpty ? 0.1 : 1.0)
            transition.setPosition(view: self.arrowView, position: CGPoint(x: originX - 13.0, y: avatarSize.height / 2.0))
            
            transition.setFrame(view: self.avatarNode.view, frame: CGRect(origin: CGPoint(x: originX, y: 0.0), size: avatarSize))
            self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.mainPeer, synchronousLoad: true)
            
            var removeIds: [EnginePeer.Id] = []
            for (id, avatarView) in self.otherAvatarNodes {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    avatarView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        avatarView.removeFromSuperview()
                    })
                    avatarView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                }
            }
            for id in removeIds {
                self.otherAvatarNodes.removeValue(forKey: id)
            }
            
            return CGSize(width: availableSize.width, height: avatarSize.height)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
