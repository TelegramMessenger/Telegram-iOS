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

struct MediaRight: OptionSet, Hashable {
    var rawValue: Int
    
    static let photos = MediaRight(rawValue: 1 << 0)
    static let videos = MediaRight(rawValue: 1 << 1)
    static let stickersAndGifs = MediaRight(rawValue: 1 << 2)
    static let music = MediaRight(rawValue: 1 << 3)
    static let files = MediaRight(rawValue: 1 << 4)
    static let voiceMessages = MediaRight(rawValue: 1 << 5)
    static let videoMessages = MediaRight(rawValue: 1 << 6)
    static let links = MediaRight(rawValue: 1 << 7)
    static let polls = MediaRight(rawValue: 1 << 8)
}

extension MediaRight {
    var count: Int {
        var result = 0
        var index = 0
        while index < 31 {
            let currentValue = self.rawValue >> UInt32(index)
            index += 1
            if currentValue == 0 {
                break
            }
            
            if (currentValue & 1) != 0 {
                result += 1
            }
        }
        return result
    }
}

private struct ParticipantRight: OptionSet {
    var rawValue: Int
    
    static let sendMessages = ParticipantRight(rawValue: 1 << 0)
    static let addMembers = ParticipantRight(rawValue: 1 << 2)
    static let pinMessages = ParticipantRight(rawValue: 1 << 3)
    static let changeInfo = ParticipantRight(rawValue: 1 << 4)
}

private func rightsFromBannedRights(_ rights: TelegramChatBannedRightsFlags) -> (participantRights: ParticipantRight, mediaRights: MediaRight) {
    var participantResult: ParticipantRight = [
        .sendMessages,
        .addMembers,
        .pinMessages,
        .changeInfo
    ]
    var mediaResult: MediaRight = [
        .photos,
        .videos,
        .stickersAndGifs,
        .music,
        .files,
        .voiceMessages,
        .videoMessages,
        .links,
        .polls
    ]
    
    if rights.contains(.banSendText) {
        participantResult.remove(.sendMessages)
    }
    if rights.contains(.banAddMembers) {
        participantResult.remove(.addMembers)
    }
    if rights.contains(.banPinMessages) {
        participantResult.remove(.pinMessages)
    }
    if rights.contains(.banChangeInfo) {
        participantResult.remove(.changeInfo)
    }
    
    if rights.contains(.banSendPhotos) {
        mediaResult.remove(.photos)
    }
    if rights.contains(.banSendVideos) {
        mediaResult.remove(.videos)
    }
    if rights.contains(.banSendStickers) || rights.contains(.banSendGifs) || rights.contains(.banSendGames) || rights.contains(.banSendInline) {
        mediaResult.remove(.stickersAndGifs)
    }
    if rights.contains(.banSendMusic) {
        mediaResult.remove(.music)
    }
    if rights.contains(.banSendFiles) {
        mediaResult.remove(.files)
    }
    if rights.contains(.banSendVoice) {
        mediaResult.remove(.voiceMessages)
    }
    if rights.contains(.banSendInstantVideos) {
        mediaResult.remove(.videoMessages)
    }
    if rights.contains(.banEmbedLinks) {
        mediaResult.remove(.links)
    }
    if rights.contains(.banSendPolls) {
        mediaResult.remove(.polls)
    }
    
    return (participantResult, mediaResult)
}

private func rightFlagsFromRights(participantRights: ParticipantRight, mediaRights: MediaRight) -> TelegramChatBannedRightsFlags {
    var result: TelegramChatBannedRightsFlags = []
    
    if !participantRights.contains(.sendMessages) {
        result.insert(.banSendText)
    }
    if !participantRights.contains(.addMembers) {
        result.insert(.banAddMembers)
    }
    if !participantRights.contains(.pinMessages) {
        result.insert(.banPinMessages)
    }
    if !participantRights.contains(.changeInfo) {
        result.insert(.banChangeInfo)
    }
    
    if !mediaRights.contains(.photos) {
        result.insert(.banSendPhotos)
    }
    if !mediaRights.contains(.videos) {
        result.insert(.banSendVideos)
    }
    if !mediaRights.contains(.stickersAndGifs) {
        result.insert(.banSendStickers)
        result.insert(.banSendGifs)
        result.insert(.banSendGames)
        result.insert(.banSendInline)
    }
    if !mediaRights.contains(.music) {
        result.insert(.banSendMusic)
    }
    if !mediaRights.contains(.files) {
        result.insert(.banSendFiles)
    }
    if !mediaRights.contains(.voiceMessages) {
        result.insert(.banSendVoice)
    }
    if !mediaRights.contains(.videoMessages) {
        result.insert(.banSendInstantVideos)
    }
    if !mediaRights.contains(.links) {
        result.insert(.banEmbedLinks)
    }
    if !mediaRights.contains(.polls) {
        result.insert(.banSendPolls)
    }
    
    return result
}

private let allMediaRightItems: [MediaRight] = [
    .photos,
    .videos,
    .stickersAndGifs,
    .music,
    .files,
    .voiceMessages,
    .videoMessages,
    .links,
    .polls
]

private final class AdminUserActionsSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let chatPeer: EnginePeer
    let peers: [RenderedChannelParticipant]
    let messageCount: Int
    let deleteAllMessageCount: Int?
    let completion: (AdminUserActionsSheet.Result) -> Void
    
    init(
        context: AccountContext,
        chatPeer: EnginePeer,
        peers: [RenderedChannelParticipant],
        messageCount: Int,
        deleteAllMessageCount: Int?,
        completion: @escaping (AdminUserActionsSheet.Result) -> Void
    ) {
        self.context = context
        self.chatPeer = chatPeer
        self.peers = peers
        self.messageCount = messageCount
        self.deleteAllMessageCount = deleteAllMessageCount
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
        if lhs.deleteAllMessageCount != rhs.deleteAllMessageCount {
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
        private var isMediaSectionExpanded: Bool = false
        
        private var allowedParticipantRights: ParticipantRight = []
        private var allowedMediaRights: MediaRight = []
        private var participantRights: ParticipantRight = []
        private var mediaRights: MediaRight = []
        
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
                banFlags = rightFlagsFromRights(participantRights: self.participantRights, mediaRights: self.mediaRights)
                
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
        
        private func updateScrolling(transition: ComponentTransition) {
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
        
        func update(component: AdminUserActionsSheetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            if self.component == nil {
                let _ = (component.context.account.postbox.peerView(id: component.chatPeer.id)
                |> take(1)).start(next: { [weak self] peerView in
                    guard let self else{
                        return
                    }
                    
                    var selectAll = false
                    if let cachedData = peerView.cachedData as? CachedChannelData {
                        if let memberCount = cachedData.participantsSummary.memberCount, memberCount >= 1000 {
                            selectAll = true
                        } else if case let .known(peerId) = cachedData.linkedDiscussionPeerId, let _ = peerId {
                            selectAll = true
                        }
                    }
                    
                    if selectAll && !"".isEmpty {
                        var selectedPeers = Set<EnginePeer.Id>()
                        for peer in component.peers {
                            selectedPeers.insert(peer.peer.id)
                        }
                        self.optionReportSelectedPeers = selectedPeers
                        self.optionDeleteAllSelectedPeers = selectedPeers
                        self.optionBanSelectedPeers = selectedPeers
                    }
                    
                    if !self.isUpdating {
                        self.state?.updated()
                    }
                })
                
                var (allowedParticipantRights, allowedMediaRights) = rightsFromBannedRights([])
                if case let .channel(channel) = component.chatPeer {
                    (allowedParticipantRights, allowedMediaRights) = rightsFromBannedRights(channel.defaultBannedRights?.flags ?? [])
                }
                
                var (commonParticipantRights, commonMediaRights) = rightsFromBannedRights([])
                
                loop: for peer in component.peers {
                    var (peerParticipantRights, peerMediaRights) = rightsFromBannedRights([])
                    switch peer.participant {
                    case .creator:
                        allowedParticipantRights = []
                        allowedMediaRights = []
                        break loop
                    case let .member(_, _, adminInfo, banInfo, _, _):
                        if adminInfo != nil {
                            (allowedParticipantRights, allowedMediaRights) = rightsFromBannedRights([])
                            break loop
                        } else if let banInfo {
                            (peerParticipantRights, peerMediaRights) = rightsFromBannedRights(banInfo.rights.flags)
                        }
                    }
                    peerParticipantRights = peerParticipantRights.intersection(allowedParticipantRights)
                    peerMediaRights = peerMediaRights.intersection(allowedMediaRights)
                    
                    commonParticipantRights = commonParticipantRights.intersection(peerParticipantRights)
                    commonMediaRights = commonMediaRights.intersection(peerMediaRights)
                }
                
                commonParticipantRights = commonParticipantRights.intersection(allowedParticipantRights)
                commonMediaRights = commonMediaRights.intersection(allowedMediaRights)
                
                self.allowedParticipantRights = allowedParticipantRights
                self.participantRights = commonParticipantRights
                
                self.allowedMediaRights = allowedMediaRights
                self.mediaRights = commonMediaRights
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
            let leftButtonFrame = CGRect(origin: CGPoint(x: 16.0 + environment.safeInsets.left, y: 0.0), size: leftButtonSize)
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
            
            var availableOptions: [OptionsSection] = []
            availableOptions.append(.report)
            
            if case let .channel(channel) = component.chatPeer {
                if channel.hasPermission(.deleteAllMessages) {
                    availableOptions.append(.deleteAll)
                    
                    if channel.hasPermission(.banMembers) {
                        var canBanEveryone = true
                        for peer in component.peers {
                            if peer.peer.id == component.context.account.peerId {
                                canBanEveryone = false
                                continue
                            }
                            
                            switch peer.participant {
                            case .creator:
                                canBanEveryone = false
                            case let .member(_, _, adminInfo, banInfo, _, _):
                                let _ = banInfo
                                if let adminInfo {
                                    if channel.flags.contains(.isCreator) {
                                    } else if adminInfo.promotedBy == component.context.account.peerId {
                                    } else {
                                        canBanEveryone = false
                                    }
                                }
                            }
                        }
                        
                        if canBanEveryone {
                            availableOptions.append(.ban)
                        }
                    }
                }
            }
            
            let optionsItem: (OptionsSection) -> AnyComponentWithIdentity<Empty> = { section in
                let sectionId: AnyHashable
                let selectedPeers: Set<EnginePeer.Id>
                let isExpanded: Bool
                var title: String
                
                switch section {
                case .report:
                    sectionId = "report"
                    selectedPeers = self.optionReportSelectedPeers
                    isExpanded = self.isOptionReportExpanded
                    
                    title = environment.strings.Chat_AdminActionSheet_ReportSpam
                case .deleteAll:
                    sectionId = "delete-all"
                    selectedPeers = self.optionDeleteAllSelectedPeers
                    isExpanded = self.isOptionDeleteAllExpanded
                    
                    if component.peers.count == 1 {
                        title = environment.strings.Chat_AdminActionSheet_DeleteAllSingle(EnginePeer(component.peers[0].peer).compactDisplayTitle).string
                    } else {
                        title = environment.strings.Chat_AdminActionSheet_DeleteAllMultiple
                    }
                case .ban:
                    sectionId = "ban"
                    selectedPeers = self.optionBanSelectedPeers
                    isExpanded = self.isOptionBanExpanded
                    
                    let banTitle: String
                    let restrictTitle: String
                    if component.peers.count == 1 {
                        banTitle = environment.strings.Chat_AdminActionSheet_BanSingle(EnginePeer(component.peers[0].peer).compactDisplayTitle).string
                        restrictTitle = environment.strings.Chat_AdminActionSheet_RestrictSingle(EnginePeer(component.peers[0].peer).compactDisplayTitle).string
                    } else {
                        banTitle = environment.strings.Chat_AdminActionSheet_BanMultiple
                        restrictTitle = environment.strings.Chat_AdminActionSheet_RestrictMultiple
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
                                    selectedPeers.insert(peer.peer.id)
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
                                selectedPeers.insert(peer.peer.id)
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
                    peerItems.append(AnyComponentWithIdentity(id: peer.peer.id, component: AnyComponent(AdminUserActionsPeerComponent(
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        baseFontSize: presentationData.listsFontSize.baseDisplaySize,
                        sideInset: 0.0,
                        title: EnginePeer(peer.peer).displayTitle(strings: environment.strings, displayOrder: .firstLast),
                        peer: EnginePeer(peer.peer),
                        selectionState: .editing(isSelected: selectedPeers.contains(peer.peer.id)),
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
                            
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                        }
                    ))))
                }
                return AnyComponentWithIdentity(id: sectionId, component: AnyComponent(ListSubSectionComponent(
                    theme: environment.theme,
                    leftInset: 62.0,
                    items: peerItems
                )))
            }
            
            var titleString: String = environment.strings.Chat_AdminActionSheet_DeleteTitle(Int32(component.messageCount))
            
            if let deleteAllMessageCount = component.deleteAllMessageCount {
                if self.optionDeleteAllSelectedPeers == Set(component.peers.map(\.peer.id)) {
                    titleString = environment.strings.Chat_AdminActionSheet_DeleteTitle(Int32(deleteAllMessageCount))
                }
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
                //transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.center = titleFrame.center
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            let navigationBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: 54.0))
            transition.setFrame(view: self.navigationBackgroundView, frame: navigationBackgroundFrame)
            self.navigationBackgroundView.update(size: navigationBackgroundFrame.size, cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            transition.setFrame(layer: self.navigationBarSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            var optionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            
            for option in availableOptions {
                let isOptionExpanded: Bool
                switch option {
                case .report:
                    isOptionExpanded = self.isOptionReportExpanded
                case .deleteAll:
                    isOptionExpanded = self.isOptionDeleteAllExpanded
                case .ban:
                    isOptionExpanded = self.isOptionBanExpanded
                }
                
                optionsSectionItems.append(optionsItem(option))
                if isOptionExpanded {
                    optionsSectionItems.append(expandedPeersItem(option))
                }
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
                            string: environment.strings.Chat_AdminActionSheet_RestrictSectionHeader,
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
                partiallyRestrictTitle = environment.strings.Chat_AdminActionSheet_RestrictFooterSingle
                fullyBanTitle = environment.strings.Chat_AdminActionSheet_BanFooterSingle
            } else {
                partiallyRestrictTitle = environment.strings.Chat_AdminActionSheet_RestrictFooterMultiple
                fullyBanTitle = environment.strings.Chat_AdminActionSheet_BanFooterMultiple
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
                                self.optionBanSelectedPeers.insert(peer.peer.id)
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
            
            enum ConfigItem: Hashable, CaseIterable {
                case sendMessages
                case sendMedia
                case addUsers
                case pinMessages
                case changeInfo
            }
            
            if case let .channel(channel) = component.chatPeer, channel.isMonoForum {
            } else {
                var allConfigItems: [(ConfigItem, Bool)] = []
                if !self.allowedMediaRights.isEmpty || !self.allowedParticipantRights.isEmpty {
                    for configItem in ConfigItem.allCases {
                        let isEnabled: Bool
                        switch configItem {
                        case .sendMessages:
                            isEnabled = self.allowedParticipantRights.contains(.sendMessages)
                        case .sendMedia:
                            isEnabled = !self.allowedMediaRights.isEmpty
                        case .addUsers:
                            isEnabled = self.allowedParticipantRights.contains(.addMembers)
                        case .pinMessages:
                            isEnabled = self.allowedParticipantRights.contains(.pinMessages)
                        case .changeInfo:
                            isEnabled = self.allowedParticipantRights.contains(.changeInfo)
                        }
                        allConfigItems.append((configItem, isEnabled))
                    }
                }
                
                loop: for (configItem, isEnabled) in allConfigItems {
                    let itemTitle: AnyComponent<Empty>
                    let itemValue: Bool
                    switch configItem {
                    case .sendMessages:
                        itemTitle = AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Channel_BanUser_PermissionSendMessages,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))
                        itemValue = self.participantRights.contains(.sendMessages)
                    case .sendMedia:
                        if isEnabled {
                            itemTitle = AnyComponent(HStack([
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: environment.strings.Channel_BanUser_PermissionSendMedia,
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                                AnyComponentWithIdentity(id: 1, component: AnyComponent(MediaSectionExpandIndicatorComponent(
                                    theme: environment.theme,
                                    title: "\(self.mediaRights.count)/\(self.allowedMediaRights.count)",
                                    isExpanded: self.isMediaSectionExpanded
                                )))
                            ], spacing: 7.0))
                        } else {
                            itemTitle = AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: environment.strings.Channel_BanUser_PermissionSendMedia,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: environment.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))
                        }
                        
                        itemValue = !self.mediaRights.isEmpty
                    case .addUsers:
                        itemTitle = AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Channel_BanUser_PermissionAddMembers,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))
                        itemValue = self.participantRights.contains(.addMembers)
                    case .pinMessages:
                        itemTitle = AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Channel_EditAdmin_PermissionPinMessages,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))
                        itemValue = self.participantRights.contains(.pinMessages)
                    case .changeInfo:
                        itemTitle = AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Channel_BanUser_PermissionChangeGroupInfo,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))
                        itemValue = self.participantRights.contains(.changeInfo)
                    }
                    
                    configSectionItems.append(AnyComponentWithIdentity(id: configItem, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        title: itemTitle,
                        accessory: .toggle(ListActionItemComponent.Toggle(
                            style: isEnabled ? .icons : .lock,
                            isOn: itemValue,
                            isInteractive: isEnabled,
                            action: isEnabled ? { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                
                                switch configItem {
                                case .sendMessages:
                                    if self.participantRights.contains(.sendMessages) {
                                        self.participantRights.remove(.sendMessages)
                                    } else {
                                        self.participantRights.insert(.sendMessages)
                                    }
                                case .sendMedia:
                                    if self.mediaRights.isEmpty {
                                        self.mediaRights = self.allowedMediaRights
                                    } else {
                                        self.mediaRights = []
                                    }
                                case .addUsers:
                                    if self.participantRights.contains(.addMembers) {
                                        self.participantRights.remove(.addMembers)
                                    } else {
                                        self.participantRights.insert(.addMembers)
                                    }
                                case .pinMessages:
                                    if self.participantRights.contains(.pinMessages) {
                                        self.participantRights.remove(.pinMessages)
                                    } else {
                                        self.participantRights.insert(.pinMessages)
                                    }
                                case .changeInfo:
                                    if self.participantRights.contains(.changeInfo) {
                                        self.participantRights.remove(.changeInfo)
                                    } else {
                                        self.participantRights.insert(.changeInfo)
                                    }
                                }
                                self.state?.updated(transition: .spring(duration: 0.35))
                            } : nil
                        )),
                        action: ((isEnabled && configItem == .sendMedia) || !isEnabled) ? { [weak self] _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            if !isEnabled {
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                self.environment?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: environment.strings.GroupPermission_PermissionDisabledByDefault, actions: [
                                    TextAlertAction(type: .defaultAction, title: environment.strings.Common_OK, action: {
                                    })
                                ]), in: .window(.root))
                            } else {
                                self.isMediaSectionExpanded = !self.isMediaSectionExpanded
                                self.state?.updated(transition: .spring(duration: 0.35))
                            }
                        } : nil,
                        highlighting: .disabled
                    ))))
                    
                    if isEnabled, case .sendMedia = configItem, self.isMediaSectionExpanded {
                        var mediaItems: [AnyComponentWithIdentity<Empty>] = []
                        mediaRightsLoop: for possibleMediaItem in allMediaRightItems {
                            if !self.allowedMediaRights.contains(possibleMediaItem) {
                                continue
                            }
                            
                            let mediaItemTitle: String
                            switch possibleMediaItem {
                            case .photos:
                                mediaItemTitle = environment.strings.Channel_BanUser_PermissionSendPhoto
                            case .videos:
                                mediaItemTitle = environment.strings.Channel_BanUser_PermissionSendVideo
                            case .stickersAndGifs:
                                mediaItemTitle = environment.strings.Channel_BanUser_PermissionSendStickersAndGifs
                            case .music:
                                mediaItemTitle = environment.strings.Channel_BanUser_PermissionSendMusic
                            case .files:
                                mediaItemTitle = environment.strings.Channel_BanUser_PermissionSendFile
                            case .voiceMessages:
                                mediaItemTitle = environment.strings.Channel_BanUser_PermissionSendVoiceMessage
                            case .videoMessages:
                                mediaItemTitle = environment.strings.Channel_BanUser_PermissionSendVideoMessage
                            case .links:
                                mediaItemTitle = environment.strings.Channel_BanUser_PermissionEmbedLinks
                            case .polls:
                                mediaItemTitle = environment.strings.Channel_BanUser_PermissionSendPolls
                            default:
                                continue mediaRightsLoop
                            }
                            
                            mediaItems.append(AnyComponentWithIdentity(id: possibleMediaItem, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                title: AnyComponent(VStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: mediaItemTitle,
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: environment.theme.list.itemPrimaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    ))),
                                ], alignment: .left, spacing: 2.0)),
                                leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                                    isSelected: self.mediaRights.contains(possibleMediaItem),
                                    toggle: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        
                                        if self.mediaRights.contains(possibleMediaItem) {
                                            self.mediaRights.remove(possibleMediaItem)
                                        } else {
                                            self.mediaRights.insert(possibleMediaItem)
                                        }
                                        
                                        self.state?.updated(transition: .spring(duration: 0.35))
                                    }
                                )),
                                icon: .none,
                                accessory: .none,
                                action: { [weak self] _ in
                                    guard let self else {
                                        return
                                    }
                                    
                                    if self.mediaRights.contains(possibleMediaItem) {
                                        self.mediaRights.remove(possibleMediaItem)
                                    } else {
                                        self.mediaRights.insert(possibleMediaItem)
                                    }
                                    
                                    self.state?.updated(transition: .spring(duration: 0.35))
                                },
                                highlighting: .disabled
                            ))))
                        }
                        configSectionItems.append(AnyComponentWithIdentity(id: "media-sub", component: AnyComponent(ListSubSectionComponent(
                            theme: environment.theme,
                            leftInset: 0.0,
                            items: mediaItems
                        ))))
                    }
                }
            }
            
            let configSectionSize = self.configSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.peers.count == 1 ? environment.strings.Chat_AdminActionSheet_PermissionsSectionHeader : environment.strings.Chat_AdminActionSheet_PermissionsSectionHeaderMultiple,
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
            
            if availableOptions.contains(.ban) && !configSectionItems.isEmpty {
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
                    transition.setAlpha(view: optionsFooterView, alpha: 1.0)
                }
            } else {
                if let optionsFooterView = self.optionsFooter.view {
                    if optionsFooterView.superview == nil {
                        self.scrollContentView.addSubview(optionsFooterView)
                    }
                    let optionsFooterFrame = CGRect(origin: CGPoint(x: sideInset + 16.0, y: contentHeight), size: optionsFooterSize)
                    transition.setFrame(view: optionsFooterView, frame: optionsFooterFrame)
                    transition.setAlpha(view: optionsFooterView, alpha: 0.0)
                }
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
                            text: environment.strings.Chat_AdminActionSheet_ActionButton,
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class AdminUserActionsSheet: ViewControllerComponentContainer {
    public final class Result {
        public let reportSpamPeers: [EnginePeer.Id]
        public let deleteAllFromPeers: [EnginePeer.Id]
        public let banPeers: [EnginePeer.Id]
        public let updateBannedRights: [EnginePeer.Id: TelegramChatBannedRights]
        
        init(reportSpamPeers: [EnginePeer.Id], deleteAllFromPeers: [EnginePeer.Id], banPeers: [EnginePeer.Id], updateBannedRights: [EnginePeer.Id: TelegramChatBannedRights]) {
            self.reportSpamPeers = reportSpamPeers
            self.deleteAllFromPeers = deleteAllFromPeers
            self.banPeers = banPeers
            self.updateBannedRights = updateBannedRights
        }
    }
    
    private let context: AccountContext
    
    private var isDismissed: Bool = false
    
    public init(context: AccountContext, chatPeer: EnginePeer, peers: [RenderedChannelParticipant], messageCount: Int, deleteAllMessageCount: Int?, completion: @escaping (Result) -> Void) {
        self.context = context
        
        super.init(context: context, component: AdminUserActionsSheetComponent(context: context, chatPeer: chatPeer, peers: peers, messageCount: messageCount, deleteAllMessageCount: deleteAllMessageCount, completion: completion), navigationBarAppearance: .none)
        
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
    let sourceImage = UIImage(bundleImageName: "Item List/InlineIconUsers")!
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
        
        func update(component: OptionSectionExpandIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let countArrowSpacing: CGFloat = 1.0
            let iconCountSpacing: CGFloat = 1.0
            
            if self.iconView.image == nil {
                self.iconView.image = optionExpandUsersIcon
            }
            self.iconView.tintColor = component.theme.list.itemPrimaryTextColor
            let iconSize = self.iconView.image?.size ?? CGSize(width: 12.0, height: 12.0)
            
            if self.arrowView.image == nil {
                self.arrowView.image = PresentationResourcesItemList.expandDownArrowImage(component.theme)
            }
            self.arrowView.tintColor = component.theme.list.itemPrimaryTextColor
            let arrowSize = self.arrowView.image?.size ?? CGSize(width: 1.0, height: 1.0)

            let countSize = self.count.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "\(component.count)", font: Font.semibold(13.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let size = CGSize(width: 60.0, height: availableSize.height)
            
            let arrowFrame = CGRect(origin: CGPoint(x: size.width - arrowSize.width - 12.0, y: floor((size.height - arrowSize.height) * 0.5)), size: arrowSize)
            
            let countFrame = CGRect(origin: CGPoint(x: arrowFrame.minX - countArrowSpacing - countSize.width, y: floor((size.height - countSize.height) * 0.5)), size: countSize)
            
            let iconFrame = CGRect(origin: CGPoint(x: countFrame.minX - iconCountSpacing - iconSize.width, y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            
            if let countView = self.count.view {
                if countView.superview == nil {
                    self.addSubview(countView)
                }
                countView.frame = countFrame
            }
            
            self.arrowView.center = arrowFrame.center
            self.arrowView.bounds = CGRect(origin: CGPoint(), size: arrowFrame.size)
            transition.setTransform(view: self.arrowView, transform: CATransform3DTranslate(CATransform3DMakeRotation(component.isExpanded ? CGFloat.pi : 0.0, 0.0, 0.0, 1.0), 0.0, component.isExpanded ? 1.0 : 0.0, 0.0))
            
            self.iconView.frame = iconFrame
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class MediaSectionExpandIndicatorComponent: Component {
    let theme: PresentationTheme
    let title: String
    let isExpanded: Bool
    
    init(
        theme: PresentationTheme,
        title: String,
        isExpanded: Bool
    ) {
        self.theme = theme
        self.title = title
        self.isExpanded = isExpanded
    }
    
    static func ==(lhs: MediaSectionExpandIndicatorComponent, rhs: MediaSectionExpandIndicatorComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let arrowView: UIImageView
        private let title = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            self.arrowView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.arrowView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: MediaSectionExpandIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let titleArrowSpacing: CGFloat = 1.0
            
            if self.arrowView.image == nil {
                self.arrowView.image = PresentationResourcesItemList.expandDownArrowImage(component.theme)
            }
            self.arrowView.tintColor = component.theme.list.itemPrimaryTextColor
            let arrowSize = self.arrowView.image?.size ?? CGSize(width: 1.0, height: 1.0)
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(13.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let size = CGSize(width: titleSize.width + titleArrowSpacing + arrowSize.width, height: titleSize.height)
            
            let titleFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
            let arrowFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + titleArrowSpacing, y: floor((size.height - arrowSize.height) * 0.5) + 2.0), size: arrowSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            self.arrowView.center = arrowFrame.center
            self.arrowView.bounds = CGRect(origin: CGPoint(), size: arrowFrame.size)
            transition.setTransform(view: self.arrowView, transform: CATransform3DTranslate(CATransform3DMakeRotation(component.isExpanded ? CGFloat.pi : 0.0, 0.0, 0.0, 1.0), 0.0, component.isExpanded ? 1.0 : -1.0, 0.0))
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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
        
        func update(component: OptionsSectionFooterComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.arrowView.image == nil {
                self.arrowView.image = PresentationResourcesItemList.expandSmallDownArrowImage(component.theme)
            }
            self.arrowView.tintColor = component.theme.list.itemAccentColor
            let arrowSize = self.arrowView.image?.size ?? CGSize(width: 1.0, height: 1.0)
            
            let attributedText = NSMutableAttributedString(attributedString: NSAttributedString(string: component.text, font: Font.regular(component.fontSize), textColor: component.theme.list.itemAccentColor))
            attributedText.append(NSAttributedString(string: ">", font: Font.regular(component.fontSize), textColor: .clear))
            self.textView.attributedText = attributedText
            let textLayout = self.textView.updateLayoutFullInfo(availableSize)
            
            let size = textLayout.size
            let textFrame = CGRect(origin: CGPoint(), size: textLayout.size)
            self.textView.frame = textFrame
            
            var arrowFrame = CGRect()
            if let lineRect = textLayout.linesRects().last {
                arrowFrame = CGRect(origin: CGPoint(x: textFrame.minX + lineRect.maxX - arrowSize.width + 6.0, y: textFrame.minY + lineRect.maxY - lineRect.height - arrowSize.height - 1.0), size: arrowSize)
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
