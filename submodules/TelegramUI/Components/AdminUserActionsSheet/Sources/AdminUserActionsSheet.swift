import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import ButtonComponent
import PresentationDataUtils
import Markdown
import UndoUI
import AvatarNode
import TelegramStringFormatting
import ListSectionComponent
import ListActionItemComponent
import PlainButtonComponent

private let banSendMediaFlags: TelegramChatBannedRightsFlags = [
    .banSendPhotos,
    .banSendVideos,
    .banSendGifs,
    .banSendMusic,
    .banSendFiles,
    .banSendVoice,
    .banSendInstantVideos,
    .banEmbedLinks,
    .banSendPolls
]

private final class AdminUserActionsSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let chatPeer: EnginePeer
    let peers: [EnginePeer]
    let messageCount: Int
    let completion: (AdminUserActionsSheet.Result) -> Void
    
    init(
        context: AccountContext,
        chatPeer: EnginePeer,
        peers: [EnginePeer],
        messageCount: Int,
        completion: @escaping (AdminUserActionsSheet.Result) -> Void
    ) {
        self.context = context
        self.chatPeer = chatPeer
        self.peers = peers
        self.messageCount = messageCount
        self.completion = completion
    }
    
    static func ==(lhs: AdminUserActionsSheetComponent, rhs: AdminUserActionsSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.chatPeer != rhs.chatPeer {
            return false
        }
        if lhs.peers != rhs.peers {
            return false
        }
        if lhs.messageCount != rhs.messageCount {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationBarSeparator: SimpleLayer
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let leftButton = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        
        private let optionsSection = ComponentView<Empty>()
        private let optionsFooter = ComponentView<Empty>()
        private let configSection = ComponentView<Empty>()
        
        private let bottomOverscrollLimit: CGFloat
        
        private var ignoreScrolling: Bool = false
        
        private var component: AdminUserActionsSheetComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        
        private var itemLayout: ItemLayout?
        
        private var topOffsetDistance: CGFloat?
        
        private var isOptionReportExpanded: Bool = false
        private var optionReportSelectedPeers = Set<EnginePeer.Id>()
        private var isOptionDeleteAllExpanded: Bool = false
        private var optionDeleteAllSelectedPeers = Set<EnginePeer.Id>()
        private var isOptionBanExpanded: Bool = false
        private var optionBanSelectedPeers = Set<EnginePeer.Id>()
        
        private var isConfigurationExpanded: Bool = false
        private var configSendMessages: Bool = false
        private var configSendMedia: Bool = false
        private var configAddUsers: Bool = false
        private var configPinMessages: Bool = false
        private var configChangeInfo: Bool = false
        
        private var previousWasConfigurationExpanded: Bool = false
        
        override init(frame: CGRect) {
            self.bottomOverscrollLimit = 200.0
            
            self.dimView = UIView()
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 10.0
            
            self.navigationBarContainer = SparseContainerView()
            
            self.navigationBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationBarSeparator = SimpleLayer()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.layer.addSublayer(self.backgroundLayer)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.addSubview(self.navigationBarContainer)
            
            self.navigationBarContainer.addSubview(self.navigationBackgroundView)
            self.navigationBarContainer.layer.addSublayer(self.navigationBarSeparator)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            /*guard let itemLayout = self.itemLayout, let topOffsetDistance = self.topOffsetDistance else {
                return
            }
            
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            
            if topOffset < topOffsetDistance {
                targetContentOffset.pointee.y = scrollView.contentOffset.y
                scrollView.setContentOffset(CGPoint(x: 0.0, y: itemLayout.topInset), animated: true)
            }*/
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        private func calculateResult() -> AdminUserActionsSheet.Result {
            var reportSpamPeers: [EnginePeer.Id] = []
            var deleteAllFromPeers: [EnginePeer.Id] = []
            var banPeers: [EnginePeer.Id] = []
            var updateBannedRights: [EnginePeer.Id: TelegramChatBannedRights] = [:]
            
            for id in self.optionReportSelectedPeers.sorted() {
                reportSpamPeers.append(id)
            }
            for id in self.optionDeleteAllSelectedPeers.sorted() {
                deleteAllFromPeers.append(id)
            }
            
            if !self.isConfigurationExpanded {
                for id in self.optionBanSelectedPeers.sorted() {
                    banPeers.append(id)
                }
            } else {
                var banFlags: TelegramChatBannedRightsFlags = []
                
                if !self.configSendMessages {
                    banFlags.insert(.banSendText)
                }
                if !self.configSendMedia {
                    banFlags.formUnion(banSendMediaFlags)
                }
                if !self.configAddUsers {
                    banFlags.insert(.banAddMembers)
                }
                if !self.configPinMessages {
                    banFlags.insert(.banPinMessages)
                }
                if !self.configChangeInfo {
                    banFlags.insert(.banChangeInfo)
                }
                
                let bannedRights = TelegramChatBannedRights(flags: banFlags, untilDate: Int32.max)
                for id in self.optionBanSelectedPeers.sorted() {
                    updateBannedRights[id] = bannedRights
                }
            }
            
            return AdminUserActionsSheet.Result(
                reportSpamPeers: reportSpamPeers,
                deleteAllFromPeers: deleteAllFromPeers,
                banPeers: banPeers,
                updateBannedRights: updateBannedRights
            )
        }
        
        private func updateScrolling(transition: Transition) {
            guard let environment = self.environment, let controller = environment.controller(), let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            
            let navigationAlpha: CGFloat = 1.0 - max(0.0, min(1.0, (topOffset + 20.0) / 20.0))
            transition.setAlpha(view: self.navigationBackgroundView, alpha: navigationAlpha)
            transition.setAlpha(layer: self.navigationBarSeparator, alpha: navigationAlpha)
            
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let topOffsetDistance: CGFloat = min(200.0, floor(itemLayout.containerSize.height * 0.25))
            self.topOffsetDistance = topOffsetDistance
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            if self.isUpdating {
                DispatchQueue.main.async { [weak controller] in
                    guard let controller else {
                        return
                    }
                    controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: transition.containedViewLayoutTransition)
                }
            } else {
                controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: transition.containedViewLayoutTransition)
            }
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
            
            if let environment = self.environment, let controller = environment.controller() {
                controller.updateModalStyleOverlayTransitionFactor(0.0, transition: .animated(duration: 0.3, curve: .easeInOut))
            }
        }
        
        func update(component: AdminUserActionsSheetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 16.0
            
            if self.component == nil {
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.list.blocksBackgroundColor.cgColor
                
                self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.navigationBarSeparator.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 54.0
            contentHeight += 16.0
            
            let leftButtonSize = self.leftButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: environment.theme.list.itemAccentColor)),
                    action: { [weak self] in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        controller.dismiss()
                    }
                ).minSize(CGSize(width: 44.0, height: 56.0))),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            let leftButtonFrame = CGRect(origin: CGPoint(x: 16.0, y: 0.0), size: leftButtonSize)
            if let leftButtonView = self.leftButton.view {
                if leftButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(leftButtonView)
                }
                transition.setFrame(view: leftButtonView, frame: leftButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            
            let clippingY: CGFloat
            
            enum OptionsSection {
                case report
                case deleteAll
                case ban
            }
            
            let optionsItem: (OptionsSection) -> AnyComponentWithIdentity<Empty> = { section in
                let sectionId: AnyHashable
                let selectedPeers: Set<EnginePeer.Id>
                let isExpanded: Bool
                let title: String
                
                switch section {
                case .report:
                    sectionId = "report"
                    selectedPeers = self.optionReportSelectedPeers
                    isExpanded = self.isOptionReportExpanded
                    
                    title = "Report Spam"
                case .deleteAll:
                    sectionId = "delete-all"
                    selectedPeers = self.optionDeleteAllSelectedPeers
                    isExpanded = self.isOptionDeleteAllExpanded
                    
                    if component.peers.count == 1 {
                        title = "Delete All from \(component.peers[0].compactDisplayTitle)"
                    } else {
                        title = "Delete All from Users"
                    }
                case .ban:
                    sectionId = "ban"
                    selectedPeers = self.optionBanSelectedPeers
                    isExpanded = self.isOptionBanExpanded
                    
                    let banTitle: String
                    let restrictTitle: String
                    if component.peers.count == 1 {
                        banTitle = "Ban \(component.peers[0].compactDisplayTitle)"
                        restrictTitle = "Restrict \(component.peers[0].compactDisplayTitle)"
                    } else {
                        banTitle = "Ban Users"
                        restrictTitle = "Restrict Users"
                    }
                    title = self.isConfigurationExpanded ? restrictTitle : banTitle
                }
                
                var accessory: ListActionItemComponent.Accessory?
                if component.peers.count > 1 {
                    accessory = .custom(ListActionItemComponent.CustomAccessory(
                        component: AnyComponentWithIdentity(id: 0, component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(OptionSectionExpandIndicatorComponent(
                                theme: environment.theme,
                                count: selectedPeers.isEmpty ? component.peers.count : selectedPeers.count,
                                isExpanded: isExpanded
                            )),
                            effectAlignment: .center,
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                
                                switch section {
                                case .report:
                                    self.isOptionReportExpanded = !self.isOptionReportExpanded
                                case .deleteAll:
                                    self.isOptionDeleteAllExpanded = !self.isOptionDeleteAllExpanded
                                case .ban:
                                    self.isOptionBanExpanded = !self.isOptionBanExpanded
                                }
                                
                                self.state?.updated(transition: .spring(duration: 0.35))
                            },
                            animateScale: false
                        ))),
                        insets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 2.0),
                        isInteractive: true
                    ))
                }
                
                return AnyComponentWithIdentity(id: sectionId, component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: title,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                    ], alignment: .left, spacing: 2.0)),
                    leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                        isSelected: !selectedPeers.isEmpty,
                        toggle: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            var selectedPeers: Set<EnginePeer.Id>
                            switch section {
                            case .report:
                                selectedPeers = self.optionReportSelectedPeers
                            case .deleteAll:
                                selectedPeers = self.optionDeleteAllSelectedPeers
                            case .ban:
                                selectedPeers = self.optionBanSelectedPeers
                            }
                            
                            if selectedPeers.isEmpty {
                                for peer in component.peers {
                                    selectedPeers.insert(peer.id)
                                }
                            } else {
                                selectedPeers.removeAll()
                            }
                            
                            switch section {
                            case .report:
                                self.optionReportSelectedPeers = selectedPeers
                            case .deleteAll:
                                self.optionDeleteAllSelectedPeers = selectedPeers
                            case .ban:
                                self.optionBanSelectedPeers = selectedPeers
                                if self.isConfigurationExpanded && self.optionBanSelectedPeers.isEmpty {
                                    self.isConfigurationExpanded = false
                                }
                            }
                            
                            self.state?.updated(transition: .spring(duration: 0.35))
                        }
                    )),
                    icon: .none,
                    accessory: accessory,
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        var selectedPeers: Set<EnginePeer.Id>
                        switch section {
                        case .report:
                            selectedPeers = self.optionReportSelectedPeers
                        case .deleteAll:
                            selectedPeers = self.optionDeleteAllSelectedPeers
                        case .ban:
                            selectedPeers = self.optionBanSelectedPeers
                        }
                        
                        if selectedPeers.isEmpty {
                            for peer in component.peers {
                                selectedPeers.insert(peer.id)
                            }
                        } else {
                            selectedPeers.removeAll()
                        }
                        
                        switch section {
                        case .report:
                            self.optionReportSelectedPeers = selectedPeers
                        case .deleteAll:
                            self.optionDeleteAllSelectedPeers = selectedPeers
                        case .ban:
                            self.optionBanSelectedPeers = selectedPeers
                        }
                        
                        self.state?.updated(transition: .spring(duration: 0.35))
                    },
                    highlighting: .disabled
                )))
            }
            
            let expandedPeersItem: (OptionsSection) -> AnyComponentWithIdentity<Empty> = { section in
                let sectionId: AnyHashable
                let selectedPeers: Set<EnginePeer.Id>
                switch section {
                case .report:
                    sectionId = "report-peers"
                    selectedPeers = self.optionReportSelectedPeers
                case .deleteAll:
                    sectionId = "delete-all-peers"
                    selectedPeers = self.optionDeleteAllSelectedPeers
                case .ban:
                    sectionId = "ban-peers"
                    selectedPeers = self.optionBanSelectedPeers
                }
                
                var peerItems: [AnyComponentWithIdentity<Empty>] = []
                for peer in component.peers {
                    peerItems.append(AnyComponentWithIdentity(id: peer.id, component: AnyComponent(AdminUserActionsPeerComponent(
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        sideInset: 0.0,
                        title: peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                        peer: peer,
                        selectionState: .editing(isSelected: selectedPeers.contains(peer.id)),
                        action: { [weak self] peer in
                            guard let self else {
                                return
                            }
                            
                            var selectedPeers: Set<EnginePeer.Id>
                            switch section {
                            case .report:
                                selectedPeers = self.optionReportSelectedPeers
                            case .deleteAll:
                                selectedPeers = self.optionDeleteAllSelectedPeers
                            case .ban:
                                selectedPeers = self.optionBanSelectedPeers
                            }
                            
                            if selectedPeers.contains(peer.id) {
                                selectedPeers.remove(peer.id)
                            } else {
                                selectedPeers.insert(peer.id)
                            }
                            
                            switch section {
                            case .report:
                                self.optionReportSelectedPeers = selectedPeers
                            case .deleteAll:
                                self.optionDeleteAllSelectedPeers = selectedPeers
                            case .ban:
                                self.optionBanSelectedPeers = selectedPeers
                            }
                            
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                        }
                    ))))
                }
                return AnyComponentWithIdentity(id: sectionId, component: AnyComponent(ListSubSectionComponent(
                    theme: environment.theme,
                    leftInset: 62.0,
                    items: peerItems
                )))
            }
             
            //TODO:localize
            let titleString: String
            if component.messageCount == 1 {
                titleString = "Delete 1 Message?"
            } else {
                titleString = "Delete \(component.messageCount) Messages?"
            }
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftButtonFrame.maxX * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: floor((54.0 - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let navigationBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: 54.0))
            transition.setFrame(view: self.navigationBackgroundView, frame: navigationBackgroundFrame)
            self.navigationBackgroundView.update(size: navigationBackgroundFrame.size, cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            transition.setFrame(layer: self.navigationBarSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            var optionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            
            optionsSectionItems.append(optionsItem(.report))
            if self.isOptionReportExpanded {
                optionsSectionItems.append(expandedPeersItem(.report))
            }
            
            optionsSectionItems.append(optionsItem(.deleteAll))
            if self.isOptionDeleteAllExpanded {
                optionsSectionItems.append(expandedPeersItem(.deleteAll))
            }
            
            optionsSectionItems.append(optionsItem(.ban))
            if self.isOptionBanExpanded {
                optionsSectionItems.append(expandedPeersItem(.ban))
            }
            
            var optionsSectionTransition = transition
            if self.previousWasConfigurationExpanded != self.isConfigurationExpanded {
                self.previousWasConfigurationExpanded = self.isConfigurationExpanded
                optionsSectionTransition = optionsSectionTransition.withAnimation(.none)
            }
            let optionsSectionSize = self.optionsSection.update(
                transition: optionsSectionTransition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "ADDITIONAL ACTIONS",
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: optionsSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100000.0)
            )
            
            let optionsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: optionsSectionSize)
            if let optionsSectionView = self.optionsSection.view {
                if optionsSectionView.superview == nil {
                    self.scrollContentView.addSubview(optionsSectionView)
                    self.optionsSection.parentState = state
                }
                transition.setFrame(view: optionsSectionView, frame: optionsSectionFrame)
            }
            contentHeight += optionsSectionSize.height
            
            let partiallyRestrictTitle: String
            let fullyBanTitle: String
            if component.peers.count == 1 {
                partiallyRestrictTitle = "Partially restrict this user"
                fullyBanTitle = "Fully ban this user"
            } else {
                partiallyRestrictTitle = "Partially restrict users"
                fullyBanTitle = "Fully ban users"
            }
            
            let optionsFooterSize = self.optionsFooter.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(OptionsSectionFooterComponent(
                        theme: environment.theme,
                        text: self.isConfigurationExpanded ? fullyBanTitle : partiallyRestrictTitle,
                        fontSize: presentationData.listsFontSize.itemListBaseHeaderFontSize,
                        isExpanded: self.isConfigurationExpanded
                    )),
                    effectAlignment: .left,
                    contentInsets: UIEdgeInsets(),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.isConfigurationExpanded = !self.isConfigurationExpanded
                        if self.isConfigurationExpanded && self.optionBanSelectedPeers.isEmpty {
                            for peer in component.peers {
                                self.optionBanSelectedPeers.insert(peer.id)
                            }
                        }
                        self.state?.updated(transition: .spring(duration: 0.35))
                    },
                    animateAlpha: true,
                    animateScale: false,
                    animateContents: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            
            var configSectionItems: [AnyComponentWithIdentity<Empty>] = []
            
            enum ConfigItem: Hashable {
                case sendMessages
                case sendMedia
                case addUsers
                case pinMessages
                case changeInfo
            }
            
            let allConfigItems: [ConfigItem] = [
                .sendMessages,
                .sendMedia,
                .addUsers,
                .pinMessages,
                .changeInfo
            ]
            if case let .channel(channel) = component.chatPeer {
                let defaultBannedFlags = channel.defaultBannedRights?.flags ?? []
                
                loop: for configItem in allConfigItems {
                    let itemTitle: String
                    let itemValue: Bool
                    switch configItem {
                    case .sendMessages:
                        if defaultBannedFlags.contains(.banSendText) {
                            continue loop
                        }
                        
                        itemTitle = "Send Text Messages"
                        itemValue = self.configSendMessages
                    case .sendMedia:
                        if !defaultBannedFlags.intersection(banSendMediaFlags).isEmpty {
                            continue loop
                        }
                        
                        itemTitle = "Send Media"
                        itemValue = self.configSendMedia
                    case .addUsers:
                        if defaultBannedFlags.contains(.banAddMembers) {
                            continue loop
                        }
                        
                        itemTitle = "Add Users"
                        itemValue = self.configAddUsers
                    case .pinMessages:
                        if defaultBannedFlags.contains(.banPinMessages) {
                            continue loop
                        }
                        
                        itemTitle = "Pin Messages"
                        itemValue = self.configPinMessages
                    case .changeInfo:
                        if defaultBannedFlags.contains(.banChangeInfo) {
                            continue loop
                        }
                        
                        itemTitle = "Change Chat Info"
                        itemValue = self.configChangeInfo
                    }
                    
                    configSectionItems.append(AnyComponentWithIdentity(id: configItem, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: itemTitle,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: environment.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        accessory: .toggle(ListActionItemComponent.Toggle(
                            style: .icons,
                            isOn: itemValue,
                            isInteractive: true,
                            action: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                switch configItem {
                                case .sendMessages:
                                    self.configSendMessages = !self.configSendMessages
                                case .sendMedia:
                                    self.configSendMedia = !self.configSendMedia
                                case .addUsers:
                                    self.configAddUsers = !self.configAddUsers
                                case .pinMessages:
                                    self.configPinMessages = !self.configPinMessages
                                case .changeInfo:
                                    self.configChangeInfo = !self.configChangeInfo
                                }
                                self.state?.updated(transition: .spring(duration: 0.35))
                            }
                        )),
                        action: nil
                    ))))
                }
            }
            
            let configSectionSize = self.configSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "WHAT CAN THIS USER DO?",
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: configSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100000.0)
            )
            let configSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + 30.0), size: configSectionSize)
            if let configSectionView = self.configSection.view {
                if configSectionView.superview == nil {
                    configSectionView.clipsToBounds = true
                    configSectionView.layer.cornerRadius = 11.0
                    self.scrollContentView.addSubview(configSectionView)
                    self.configSection.parentState = state
                }
                let effectiveConfigSectionFrame: CGRect
                if self.isConfigurationExpanded {
                    effectiveConfigSectionFrame = configSectionFrame
                } else {
                    effectiveConfigSectionFrame = CGRect(origin: CGPoint(x: configSectionFrame.minX, y: configSectionFrame.minY - 30.0), size: CGSize(width: configSectionFrame.width, height: 0.0))
                }
                transition.setFrame(view: configSectionView, frame: effectiveConfigSectionFrame)
                transition.setAlpha(view: configSectionView, alpha: self.isConfigurationExpanded ? 1.0 : 0.0)
            }
            
            let optionsFooterFrame: CGRect
            if self.isConfigurationExpanded {
                contentHeight += 30.0
                contentHeight += configSectionSize.height
                contentHeight += 7.0
                optionsFooterFrame = CGRect(origin: CGPoint(x: sideInset + 16.0, y: contentHeight), size: optionsFooterSize)
                contentHeight += optionsFooterSize.height
            } else {
                contentHeight += 7.0
                optionsFooterFrame = CGRect(origin: CGPoint(x: sideInset + 16.0, y: contentHeight), size: optionsFooterSize)
                contentHeight += optionsFooterSize.height
            }
            if let optionsFooterView = self.optionsFooter.view {
                if optionsFooterView.superview == nil {
                    self.scrollContentView.addSubview(optionsFooterView)
                }
                transition.setFrame(view: optionsFooterView, frame: optionsFooterFrame)
            }
            
            contentHeight += 30.0
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: "Proceed",
                            badge: 0,
                            textColor: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: environment.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                        component.completion(self.calculateResult())
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            let bottomPanelHeight = 8.0 + environment.safeInsets.bottom + actionButtonSize.height
            let actionButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - bottomPanelHeight), size: actionButtonSize)
            if let actionButtonView = actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
            
            contentHeight += bottomPanelHeight
            
            clippingY = actionButtonFrame.minY - 24.0
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - contentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 10.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: sideInset, y: containerInset), size: CGSize(width: availableSize.width - sideInset * 2.0, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            let previousBounds = self.scrollView.bounds
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            } else {
                if !previousBounds.isEmpty, !transition.animation.isImmediate {
                    let bounds = self.scrollView.bounds
                    if bounds.maxY != previousBounds.maxY {
                        let offsetY = previousBounds.maxY - bounds.maxY
                        transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                    }
                }
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class AdminUserActionsSheet: ViewControllerComponentContainer {
    public final class Result {
        public let reportSpamPeers: [EnginePeer.Id]
        public let deleteAllFromPeers: [EnginePeer.Id]
        public let banPeers: [EnginePeer.Id]
        public let updateBannedRights: [EnginePeer.Id: TelegramChatBannedRights]
        
        init(reportSpamPeers: [EnginePeer.Id], deleteAllFromPeers: [EnginePeer.Id], banPeers: [EnginePeer.Id], updateBannedRights: [EnginePeer.Id : TelegramChatBannedRights]) {
            self.reportSpamPeers = reportSpamPeers
            self.deleteAllFromPeers = deleteAllFromPeers
            self.banPeers = banPeers
            self.updateBannedRights = updateBannedRights
        }
    }
    
    private let context: AccountContext
    
    private var isDismissed: Bool = false
    
    public init(context: AccountContext, chatPeer: EnginePeer, peers: [EnginePeer], messageCount: Int, completion: @escaping (Result) -> Void) {
        self.context = context
        
        /*#if DEBUG
        var peers = peers
        
        if !"".isEmpty {
            var nextPeerId: Int64 = 1
            let makePeer: () -> EnginePeer = {
                guard case let .user(user) = peers[0] else {
                    preconditionFailure()
                }
                let id = nextPeerId
                nextPeerId += 1
                return .user(TelegramUser(
                    id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)),
                    accessHash: user.accessHash,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    username: user.username,
                    phone: user.phone,
                    photo: user.photo,
                    botInfo: user.botInfo,
                    restrictionInfo: user.restrictionInfo,
                    flags: user.flags,
                    emojiStatus: user.emojiStatus,
                    usernames: user.usernames,
                    storiesHidden: user.storiesHidden,
                    nameColor: user.nameColor,
                    backgroundEmojiId: user.backgroundEmojiId,
                    profileColor: user.profileColor,
                    profileBackgroundEmojiId: user.profileBackgroundEmojiId
                ))
            }
            
            for _ in 0 ..< 3 {
                peers.append(makePeer())
            }
        }
        #endif*/
        
        super.init(context: context, component: AdminUserActionsSheetComponent(context: context, chatPeer: chatPeer, peers: peers, messageCount: messageCount, completion: completion), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? AdminUserActionsSheetComponent.View {
            componentView.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? AdminUserActionsSheetComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}

private let optionExpandUsersIcon: UIImage? = {
    let sourceImage = UIImage(bundleImageName: "Chat/Input/Accessory Panels/PanelTextGroupIcon")!
    return generateImage(CGSize(width: sourceImage.size.width, height: sourceImage.size.height), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        UIGraphicsPushContext(context)
        sourceImage.draw(at: CGPoint(x: 0.0, y: 0.0))
        UIGraphicsPopContext()
    })!.precomposed().withRenderingMode(.alwaysTemplate)
}()

private final class OptionSectionExpandIndicatorComponent: Component {
    let theme: PresentationTheme
    let count: Int
    let isExpanded: Bool
    
    init(
        theme: PresentationTheme,
        count: Int,
        isExpanded: Bool
    ) {
        self.theme = theme
        self.count = count
        self.isExpanded = isExpanded
    }
    
    static func ==(lhs: OptionSectionExpandIndicatorComponent, rhs: OptionSectionExpandIndicatorComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let iconView: UIImageView
        private let arrowView: UIImageView
        private let count = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            self.iconView = UIImageView()
            self.arrowView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.iconView)
            self.addSubview(self.arrowView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: OptionSectionExpandIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let countArrowSpacing: CGFloat = -1.0
            let iconCountSpacing: CGFloat = 2.0
            
            if self.iconView.image == nil {
                self.iconView.image = optionExpandUsersIcon
            }
            self.iconView.tintColor = component.theme.list.itemPrimaryTextColor
            let iconSize = CGSize(width: 12.0, height: 12.0)
            
            if self.arrowView.image == nil {
                self.arrowView.image = PresentationResourcesItemList.downArrowImage(component.theme)?.withRenderingMode(.alwaysTemplate)
            }
            self.arrowView.tintColor = component.theme.list.itemPrimaryTextColor
            
            let arrowSize = CGSize(width: 20.0, height: 20.0)
            let countSize = self.count.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "\(component.count)", font: Font.semibold(13.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let size = CGSize(width: 60.0, height: availableSize.height)
            
            var arrowFrame = CGRect(origin: CGPoint(x: size.width - arrowSize.width - 10.0, y: floor((size.height - arrowSize.height) * 0.5)), size: arrowSize)
            if component.isExpanded {
                arrowFrame = arrowFrame.offsetBy(dx: 0.0, dy: -1.0)
            } else {
                arrowFrame = arrowFrame.offsetBy(dx: 0.0, dy: 1.0)
            }
            
            let countFrame = CGRect(origin: CGPoint(x: arrowFrame.minX - countArrowSpacing - countSize.width, y: floor((size.height - countSize.height) * 0.5)), size: countSize)
            
            let iconFrame = CGRect(origin: CGPoint(x: countFrame.minX - iconCountSpacing - iconSize.width, y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            
            if let countView = self.count.view {
                if countView.superview == nil {
                    self.addSubview(countView)
                }
                countView.frame = countFrame
            }
            
            transition.setPosition(view: self.arrowView, position: arrowFrame.center)
            self.arrowView.bounds = CGRect(origin: CGPoint(), size: arrowFrame.size)
            transition.setTransform(view: self.arrowView, transform: CATransform3DMakeRotation(component.isExpanded ? CGFloat.pi : 0.0, 0.0, 0.0, 1.0))
            
            self.iconView.frame = iconFrame
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class OptionsSectionFooterComponent: Component {
    let theme: PresentationTheme
    let text: String
    let fontSize: CGFloat
    let isExpanded: Bool
    
    init(
        theme: PresentationTheme,
        text: String,
        fontSize: CGFloat,
        isExpanded: Bool
    ) {
        self.theme = theme
        self.text = text
        self.fontSize = fontSize
        self.isExpanded = isExpanded
    }
    
    static func ==(lhs: OptionsSectionFooterComponent, rhs: OptionsSectionFooterComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let arrowView: UIImageView
        private let textView: ImmediateTextView
        
        override init(frame: CGRect) {
            self.arrowView = UIImageView()
            
            self.textView = ImmediateTextView()
            self.textView.maximumNumberOfLines = 0
            
            super.init(frame: frame)
            
            self.addSubview(self.arrowView)
            self.addSubview(self.textView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: OptionsSectionFooterComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            if self.arrowView.image == nil {
                self.arrowView.image = PresentationResourcesItemList.downArrowImage(component.theme)?.withRenderingMode(.alwaysTemplate)
            }
            self.arrowView.tintColor = component.theme.list.itemAccentColor
            
            let arrowSize = CGSize(width: 14.0, height: 14.0)
            
            let attributedText = NSMutableAttributedString(attributedString: NSAttributedString(string: component.text, font: Font.regular(component.fontSize), textColor: component.theme.list.itemAccentColor))
            attributedText.append(NSAttributedString(string: ">", font: Font.regular(component.fontSize), textColor: .clear))
            self.textView.attributedText = attributedText
            let textLayout = self.textView.updateLayoutFullInfo(availableSize)
            
            let size = textLayout.size
            let textFrame = CGRect(origin: CGPoint(), size: textLayout.size)
            self.textView.frame = textFrame
            
            var arrowFrame = CGRect()
            if let lineRect = textLayout.linesRects().last {
                arrowFrame = CGRect(origin: CGPoint(x: textFrame.minX + lineRect.maxX - arrowSize.width + 6.0, y: textFrame.minY + lineRect.maxY - lineRect.height - arrowSize.height + 4.0), size: arrowSize)
            }
            
            self.arrowView.center = arrowFrame.center
            self.arrowView.bounds = CGRect(origin: CGPoint(), size: arrowFrame.size)
            transition.setTransform(view: self.arrowView, transform: CATransform3DMakeRotation(component.isExpanded ? CGFloat.pi : 0.0, 0.0, 0.0, 1.0))
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

