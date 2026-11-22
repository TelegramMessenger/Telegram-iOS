//import Foundation
//import UIKit
//import AsyncDisplayKit
//import Display
//import SwiftSignalKit
//import TelegramCore
//import TelegramPresentationData
//import AccountContext
//
//private let sharePeersHeaderHeight: CGFloat = 0.0
//
//public final class SharePeersSheetContentView: UIView {
//    public struct InteractionState {
//        public var foundPeers: [(peer: EngineRenderedPeer, requiresPremiumForMessaging: Bool)]
//        public var selectedPeerIds: Set<EnginePeer.Id>
//        public var selectedPeers: [EngineRenderedPeer]
//        public var selectedTopics: [EnginePeer.Id: (Int64, MessageHistoryThreadData?)]
//
//        public init(
//            foundPeers: [(peer: EngineRenderedPeer, requiresPremiumForMessaging: Bool)] = [],
//            selectedPeerIds: Set<EnginePeer.Id> = Set(),
//            selectedPeers: [EngineRenderedPeer] = [],
//            selectedTopics: [EnginePeer.Id: (Int64, MessageHistoryThreadData?)] = [:]
//        ) {
//            self.foundPeers = foundPeers
//            self.selectedPeerIds = selectedPeerIds
//            self.selectedPeers = selectedPeers
//            self.selectedTopics = selectedTopics
//        }
//    }
//
//    private let context: AccountContext
//    private let subject: ShareControllerSubject
//    private let externalShare: Bool
//
//    private let environment: ShareControllerAppEnvironment
//    private let accountContext: ShareControllerAppAccountContext
//
//    private let clippingView: UIView
//    private let peersDisposable = MetaDisposable()
//
//    private var currentTheme: PresentationTheme?
//    private var currentStrings: PresentationStrings?
//    private var currentAvailableSize: CGSize = .zero
//    private var pendingPeerList: ShareControllerPeerList?
//
//    private var peersContentNode: SharePeersContainerNode?
//
//    public var interactionUpdated: ((InteractionState) -> Void)?
//    public var trackedScrollViewUpdated: ((UIScrollView?) -> Void)? {
//        didSet {
//            self.trackedScrollViewUpdated?(self.peersContentNode?.contentGridNode.scrollView)
//        }
//    }
//
//    private lazy var controllerInteraction: ShareControllerInteraction = {
//        ShareControllerInteraction(
//            togglePeer: { [weak self] peer, search in
//                self?.togglePeer(peer, search: search)
//            },
//            selectTopic: { [weak self] peer, threadId, threadData in
//                self?.selectTopic(peer, threadId: threadId, threadData: threadData)
//            },
//            shareStory: nil,
//            disabledPeerSelected: { _ in
//            }
//        )
//    }()
//
//    public init(context: AccountContext, subject: ShareControllerSubject, externalShare: Bool) {
//        self.context = context
//        self.subject = subject
//        self.externalShare = externalShare
//
//        self.environment = ShareControllerAppEnvironment(sharedContext: context.sharedContext)
//        self.accountContext = ShareControllerAppAccountContext(context: context)
//
//        self.clippingView = UIView()
//        self.clippingView.clipsToBounds = true
//
//        super.init(frame: .zero)
//
//        self.backgroundColor = .clear
//        self.addSubview(self.clippingView)
//
//        self.peersDisposable.set((shareControllerPeerListSignal(account: self.accountContext)
//        |> deliverOnMainQueue).start(next: { [weak self] peerList in
//            guard let self else {
//                return
//            }
//            self.pendingPeerList = peerList
//            self.ensurePeersContentNode()
//            if let peersContentNode = self.peersContentNode {
//                peersContentNode.peersValue.set(.single(peerList.0))
//            }
//        }))
//    }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    deinit {
//        self.trackedScrollViewUpdated?(nil)
//        self.peersDisposable.dispose()
//    }
//
//    public func update(availableSize: CGSize, theme: PresentationTheme, strings: PresentationStrings, transition: ContainedViewLayoutTransition) {
//        self.currentTheme = theme
//        self.currentStrings = strings
//        self.currentAvailableSize = availableSize
//
//        transition.updateFrame(view: self.clippingView, frame: CGRect(origin: .zero, size: availableSize))
//
//        self.ensurePeersContentNode()
//        if let peersContentNode = self.peersContentNode {
//            peersContentNode.updateTheme(theme)
//        }
//        self.updateNodeLayout(transition: transition)
//    }
//
//    public override func safeAreaInsetsDidChange() {
//        super.safeAreaInsetsDidChange()
//
//        self.updateNodeLayout(transition: .immediate)
//    }
//
//    private func ensurePeersContentNode() {
//        guard self.peersContentNode == nil, let pendingPeerList = self.pendingPeerList, let theme = self.currentTheme, let strings = self.currentStrings else {
//            return
//        }
//
//        let peersContentNode = SharePeersContainerNode(
//            environment: self.environment,
//            context: self.accountContext,
//            switchableAccounts: [],
//            theme: theme,
//            strings: strings,
//            nameDisplayOrder: self.context.sharedContext.currentPresentationData.with { $0.nameDisplayOrder },
//            peers: pendingPeerList.0,
//            accountPeer: pendingPeerList.1,
//            controllerInteraction: self.controllerInteraction,
//            externalShare: self.externalShare,
//            isMainApp: self.environment.isMainApp,
//            switchToAnotherAccount: {
//            },
//            debugAction: {
//            },
//            extendedInitialReveal: false,
//            segmentedValues: nil,
//            fromPublicChannel: false
//        )
//        peersContentNode.isEmbedded = true
//        self.peersContentNode = peersContentNode
//
//        self.clippingView.addSubview(peersContentNode.view)
//        self.trackedScrollViewUpdated?(peersContentNode.contentGridNode.scrollView)
//        self.updateNodeLayout(transition: .immediate)
//    }
//
//    private func updateNodeLayout(transition: ContainedViewLayoutTransition) {
//        guard let peersContentNode = self.peersContentNode, self.currentAvailableSize.width > 0.0, self.currentAvailableSize.height > 0.0 else {
//            return
//        }
//
//        let contentSize = CGSize(width: self.currentAvailableSize.width, height: self.currentAvailableSize.height + sharePeersHeaderHeight)
//        transition.updateFrame(node: peersContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -sharePeersHeaderHeight), size: contentSize))
//        peersContentNode.updateLayout(
//            size: contentSize,
//            isLandscape: contentSize.width > contentSize.height,
//            bottomInset: self.safeAreaInsets.bottom,
//            transition: transition
//        )
//    }
//
//    private func updateSelectedPeer(_ peer: EngineRenderedPeer) {
//        if let index = self.controllerInteraction.selectedPeers.firstIndex(where: { $0.peerId == peer.peerId }) {
//            self.controllerInteraction.selectedPeers[index] = peer
//        } else {
//            self.controllerInteraction.selectedPeers.append(peer)
//        }
//    }
//
//    private func emitInteractionUpdated() {
//        self.interactionUpdated?(InteractionState(
//            foundPeers: self.controllerInteraction.foundPeers,
//            selectedPeerIds: self.controllerInteraction.selectedPeerIds,
//            selectedPeers: self.controllerInteraction.selectedPeers,
//            selectedTopics: self.controllerInteraction.selectedTopics
//        ))
//    }
//
//    private func togglePeer(_ peer: EngineRenderedPeer, search: Bool) {
//        var added = false
//
//        if self.controllerInteraction.selectedPeerIds.contains(peer.peerId) {
//            if self.controllerInteraction.selectedTopics.removeValue(forKey: peer.peerId) != nil {
//                self.peersContentNode?.update()
//            }
//            self.controllerInteraction.selectedPeerIds.remove(peer.peerId)
//            self.controllerInteraction.selectedPeers.removeAll(where: { $0.peerId == peer.peerId })
//        } else {
//            self.controllerInteraction.selectedPeerIds.insert(peer.peerId)
//            self.updateSelectedPeer(peer)
//            self.peersContentNode?.setEnsurePeerVisibleOnLayout(peer.peerId)
//            added = true
//        }
//
//        if search && added {
//            self.controllerInteraction.foundPeers.removeAll(where: { $0.peer.peerId == peer.peerId })
//            self.controllerInteraction.foundPeers.append((peer, false))
//            self.peersContentNode?.updateFoundPeers()
//        }
//
//        self.peersContentNode?.updateSelectedPeers(animated: true)
//        self.emitInteractionUpdated()
//    }
//
//    private func selectTopic(_ peer: EngineRenderedPeer, threadId: Int64, threadData: MessageHistoryThreadData?) {
//        self.controllerInteraction.selectedPeerIds.insert(peer.peerId)
//        self.updateSelectedPeer(peer)
//        self.controllerInteraction.selectedTopics[peer.peerId] = (threadId, threadData)
//
//        self.peersContentNode?.setEnsurePeerVisibleOnLayout(peer.peerId)
//        self.peersContentNode?.update()
//        self.peersContentNode?.updateSelectedPeers(animated: false)
//        self.emitInteractionUpdated()
//    }
//}
