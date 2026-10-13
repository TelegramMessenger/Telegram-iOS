import Foundation
import LottieSettings
import UIKit
import AppBundle
import Display
import AsyncDisplayKit
import AccountContext
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import MergeLists
import ItemListUI
import ContactsPeerItem
import ChatListSearchItemHeader
import ContextUI
import ComponentFlow
import ViewControllerComponent
import ChatListHeaderComponent
import GlassBackgroundComponent
import SearchBarNode
import QrCodeUI
import MultilineTextComponent
import ButtonComponent
import LottieComponent
import UndoUI
import WalletContext
import WalletSendScreen

public enum WalletPeerSelectionScreenMode: Equatable {
    case transfer
    case collectible(WalletContext.Collectible)
}

func walletPeerSelectionIsEligiblePeer(_ peer: EnginePeer, accountPeerId: EnginePeer.Id) -> Bool {
    guard case let .user(user) = peer else {
        return false
    }
    return user.isGenericUser && !peer.isService && peer.id != accountPeerId
}

private final class WalletPeerSelectionClearRecentSource: ContextReferenceContentSource {
    private let sourceNode: ASDisplayNode
    let keepInPlace: Bool = true

    init(sourceNode: ASDisplayNode) {
        self.sourceNode = sourceNode
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: .bottom)
    }
}

private struct WalletPeerSelectionResolvedPeer {
    let peer: EnginePeer
    let address: WalletUserAddress
}

private func walletPeerSelectionResolvePeer(context: AccountContext, address: String) -> Signal<WalletPeerSelectionResolvedPeer?, NoError> {
    guard let normalizedAddress = WalletContext.transferAddress(from: address) else {
        return .single(nil)
    }
    return context.engine.wallet.getUserAddresses(addresses: [address])
    |> `catch` { _ -> Signal<[WalletUserAddress], NoError> in
        return .single([])
    }
    |> mapToSignal { addresses -> Signal<WalletPeerSelectionResolvedPeer?, NoError> in
        guard let userAddress = addresses.first(where: { WalletContext.transferAddress(from: $0.address) == normalizedAddress }),
              let userId = userAddress.userId else {
            return .single(nil)
        }
        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: userId))
        |> map { peer -> WalletPeerSelectionResolvedPeer? in
            guard let peer, walletPeerSelectionIsEligiblePeer(peer, accountPeerId: context.account.peerId) else {
                return nil
            }
            return WalletPeerSelectionResolvedPeer(peer: peer, address: WalletUserAddress(userId: peer.id, address: address, publicKey: userAddress.publicKey))
        }
    }
}

private func walletPeerSelectionShortAddress(_ address: String) -> String {
    guard address.count > 8 else {
        return address
    }
    return "\(address.prefix(4))…\(address.suffix(4))"
}

private func walletPeerSelectionIsAddressQuery(_ query: String) -> Bool {
    if query.lowercased().hasPrefix("ton://") {
        return true
    }
    if let separator = query.firstIndex(of: ":"), Int(query[..<separator]) != nil {
        return true
    }
    guard !query.hasPrefix("@"), !query.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains) else {
        return false
    }
    return query.count == 48 || (query.count > 32 && ["EQ", "UQ", "kQ", "0Q", "Ef", "Uf", "kf", "0f"].contains(where: query.hasPrefix))
}

private final class WalletPeerSelectionRecipientView: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevronView = UIImageView()

    var pressed: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.iconView.contentMode = .scaleAspectFill
        self.iconView.clipsToBounds = true
        self.iconView.image = UIImage(bundleImageName: "Wallet/Ton")
        self.addSubview(self.iconView)

        self.titleLabel.numberOfLines = 1
        self.titleLabel.lineBreakMode = .byTruncatingMiddle
        self.addSubview(self.titleLabel)

        self.subtitleLabel.numberOfLines = 1
        self.subtitleLabel.lineBreakMode = .byTruncatingMiddle
        self.addSubview(self.subtitleLabel)

        self.chevronView.contentMode = .center
        self.addSubview(self.chevronView)

        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            self.alpha = self.isHighlighted ? 0.55 : 1.0
        }
    }

    @objc private func buttonPressed() {
        self.pressed?()
    }

    func update(
        recipient: WalletContext.ResolvedTransferRecipient,
        theme: PresentationTheme,
        size: CGSize,
        transition: ComponentTransition
    ) {
        let title: String
        let subtitle: String?
        if let displayName = recipient.displayName {
            title = displayName
            subtitle = walletPeerSelectionShortAddress(recipient.address)
        } else {
            title = walletPeerSelectionShortAddress(recipient.address)
            subtitle = nil
        }

        self.titleLabel.text = title
        self.titleLabel.font = Font.medium(16.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.subtitleLabel.text = subtitle
        self.subtitleLabel.font = Font.regular(14.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.isHidden = subtitle == nil
        self.chevronView.image = generateTintedImage(
            image: UIImage(bundleImageName: "Wallet/Chevron"),
            color: theme.list.itemSecondaryTextColor
        )
        self.accessibilityLabel = title
        self.accessibilityValue = subtitle

        let sideInset: CGFloat = 16.0
        let iconSize = CGSize(width: 40.0, height: 40.0)
        self.iconView.layer.cornerRadius = iconSize.width / 2.0
        transition.setFrame(
            view: self.iconView,
            frame: CGRect(
                x: sideInset,
                y: floorToScreenPixels((size.height - iconSize.height) * 0.5),
                width: iconSize.width,
                height: iconSize.height
            )
        )

        let chevronSize = CGSize(width: 10.0, height: 20.0)
        transition.setFrame(
            view: self.chevronView,
            frame: CGRect(
                x: size.width - sideInset - chevronSize.width,
                y: floorToScreenPixels((size.height - chevronSize.height) * 0.5),
                width: chevronSize.width,
                height: chevronSize.height
            )
        )

        let textOriginX = sideInset + iconSize.width + 11.0
        let textWidth = max(1.0, size.width - textOriginX - chevronSize.width - sideInset - 8.0)
        if subtitle != nil {
            let titleHeight: CGFloat = 20.0
            let subtitleHeight: CGFloat = 18.0
            let textSpacing: CGFloat = 1.0
            let textOriginY = floorToScreenPixels(
                (size.height - titleHeight - textSpacing - subtitleHeight) * 0.5
            )
            transition.setFrame(
                view: self.titleLabel,
                frame: CGRect(x: textOriginX, y: textOriginY, width: textWidth, height: titleHeight)
            )
            transition.setFrame(
                view: self.subtitleLabel,
                frame: CGRect(
                    x: textOriginX,
                    y: textOriginY + titleHeight + textSpacing,
                    width: textWidth,
                    height: subtitleHeight
                )
            )
        } else {
            let titleHeight: CGFloat = 20.0
            transition.setFrame(
                view: self.titleLabel,
                frame: CGRect(
                    x: textOriginX,
                    y: floorToScreenPixels((size.height - titleHeight) * 0.5),
                    width: textWidth,
                    height: titleHeight
                )
            )
        }
    }
}

private final class WalletPeerSelectionScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
    let walletContext: WalletContext
    let mode: WalletPeerSelectionScreenMode
    let dismissSourceScreen: () -> Void
    let transferAnimation: WalletSendTransferAnimation?
    let returnedToWallet: (() -> Void)?

    init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
        walletContext: WalletContext,
        mode: WalletPeerSelectionScreenMode,
        dismissSourceScreen: @escaping () -> Void,
        transferAnimation: WalletSendTransferAnimation?,
        returnedToWallet: (() -> Void)?
    ) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.walletContext = walletContext
        self.mode = mode
        self.dismissSourceScreen = dismissSourceScreen
        self.transferAnimation = transferAnimation
        self.returnedToWallet = returnedToWallet
    }

    static func ==(lhs: WalletPeerSelectionScreenComponent, rhs: WalletPeerSelectionScreenComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.updatedPresentationData.initial === rhs.updatedPresentationData.initial
            && lhs.updatedPresentationData.signal === rhs.updatedPresentationData.signal
            && lhs.walletContext === rhs.walletContext
            && lhs.mode == rhs.mode
    }

    private struct PeerInfo: Equatable {
        let peer: EnginePeer
        let presence: EnginePeer.Presence?
    }

    private enum PeerSection {
        case none
        case recent
        case local
        case global
    }

    private enum ContentEntry: Comparable, Identifiable {
        enum Id: Hashable {
            case topPeers
            case peer(EnginePeer.Id)
        }

        var stableId: Id {
            switch self {
            case .topPeers:
                return .topPeers
            case let .peer(peer, _, _, _, _):
                return .peer(peer.id)
            }
        }

        case topPeers
        case peer(peer: EnginePeer, presence: EnginePeer.Presence?, sortIndex: Int, section: PeerSection = .none, query: String? = nil)

        static func <(lhs: ContentEntry, rhs: ContentEntry) -> Bool {
            switch (lhs, rhs) {
            case (.topPeers, .topPeers):
                return false
            case (.topPeers, _):
                return true
            case (_, .topPeers):
                return false
            case let (.peer(lhsPeer, _, lhsSortIndex, _, _), .peer(rhsPeer, _, rhsSortIndex, _, _)):
                if lhsSortIndex != rhsSortIndex {
                    return lhsSortIndex < rhsSortIndex
                }
                return lhsPeer.id < rhsPeer.id
            }
        }

        func item(listNode: ContentListNode) -> ListViewItem {
            switch self {
            case .topPeers:
                return WalletPeerSelectionTopPeersItem(context: listNode.context, presentationData: listNode.presentationData, peerSelected: { [weak listNode] peer in
                    listNode?.parentView?.peerSelected(peer: peer)
                })
            case let .peer(peer, presence, _, section, query):
                let status: ContactsPeerItemStatus
                if section == .global {
                    status = .addressName("")
                } else if let presence {
                    status = .presence(presence, listNode.presentationData.dateTimeFormat)
                } else {
                    status = .none
                }

                let header: ChatListSearchItemHeader?
                switch section {
                case .none:
                    header = nil
                case .recent:
                    header = ChatListSearchItemHeader(
                        type: .recentPeers,
                        theme: listNode.presentationData.theme,
                        strings: listNode.presentationData.strings,
                        actionTitle: query == nil ? listNode.presentationData.strings.WebSearch_RecentSectionClear : nil,
                        action: query == nil ? { [weak listNode] sourceNode in
                            listNode?.parentView?.clearRecentSearch(sourceNode: sourceNode)
                        } : nil
                    )
                case .local, .global:
                    header = ChatListSearchItemHeader(type: section == .local ? .localPeers : .globalPeers, theme: listNode.presentationData.theme, strings: listNode.presentationData.strings)
                }

                return ContactsPeerItem(
                    presentationData: ItemListPresentationData(listNode.presentationData),
                    style: .plain,
                    sectionId: 0,
                    sortOrder: listNode.presentationData.nameSortOrder,
                    displayOrder: listNode.presentationData.nameDisplayOrder,
                    context: listNode.context,
                    peerMode: section == .none ? .peer : .generalSearch(isSavedMessages: false),
                    peer: .peer(peer: peer, chatPeer: peer),
                    status: status,
                    badge: nil,
                    requiresPremiumForMessaging: false,
                    enabled: true,
                    selection: .none,
                    selectionPosition: .left,
                    editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                    options: [],
                    additionalActions: [],
                    actionIcon: .none,
                    index: nil,
                    header: header,
                    searchQuery: section == .global ? query : nil,
                    hideBackground: true,
                    action: { [weak listNode] _ in
                        guard let listNode, let parentView = listNode.parentView else {
                            return
                        }
                        parentView.peerSelected(peer: peer)
                    }
                )
            }
        }
    }

    private final class ContentListNode: ListViewImpl {
        weak var parentView: View?
        let context: AccountContext
        var presentationData: PresentationData
        private var currentEntries: [ContentEntry] = []
        private var currentLayout: (size: CGSize, insets: UIEdgeInsets)?

        init(parentView: View, context: AccountContext, presentationData: PresentationData) {
            self.parentView = parentView
            self.context = context
            self.presentationData = presentationData

            super.init()
        }

        func update(size: CGSize, insets: UIEdgeInsets, transition: ComponentTransition) {
            if let currentLayout = self.currentLayout, currentLayout.size == size, currentLayout.insets == insets {
                return
            }
            self.currentLayout = (size, insets)
            let (listViewDuration, listViewCurve) = listViewAnimationDurationAndCurve(
                transition: transition.containedViewLayoutTransition
            )
            self.transaction(
                deleteIndices: [],
                insertIndicesAndItems: [],
                updateIndicesAndItems: [],
                options: [.Synchronous, .LowLatency, .PreferSynchronousResourceLoading],
                additionalScrollDistance: 0.0,
                updateSizeAndInsets: ListViewUpdateSizeAndInsets(
                    size: size,
                    insets: insets,
                    duration: listViewDuration,
                    curve: listViewCurve
                ),
                updateOpaqueState: nil
            )
        }

        func setEntries(_ entries: [ContentEntry], allUpdated: Bool) {
            guard allUpdated || self.currentEntries != entries else {
                return
            }
            let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(
                leftList: self.currentEntries,
                rightList: entries,
                allUpdated: allUpdated
            )
            self.currentEntries = entries

            let deletions = deleteIndices.map {
                ListViewDeleteItem(index: $0, directionHint: nil)
            }
            let insertions = indicesAndItems.map {
                ListViewInsertItem(
                    index: $0.0,
                    previousIndex: $0.2,
                    item: $0.1.item(listNode: self),
                    directionHint: nil
                )
            }
            let updates = updateIndices.map {
                ListViewUpdateItem(
                    index: $0.0,
                    previousIndex: $0.2,
                    item: $0.1.item(listNode: self),
                    directionHint: nil
                )
            }

            self.transaction(
                deleteIndices: deletions,
                insertIndicesAndItems: insertions,
                updateIndicesAndItems: updates,
                options: [.Synchronous, .LowLatency, .PreferSynchronousResourceLoading],
                scrollToItem: nil,
                stationaryItemRange: nil,
                updateOpaqueState: nil,
                completion: { _ in
                }
            )
        }
    }

    final class View: UIView {
        private var contentListNode: ContentListNode?
        private var suggestionsListNode: ContentListNode?
        private let suggestionsContainerView = UIView()
        private let navigationGlassContainer = GlassBackgroundContainerView()
        private let navigationBarView = ComponentView<Empty>()
        private var navigationHeight: CGFloat?
        private var searchBarNode: SearchBarNode?
        private var activeSearch: ChatListNavigationBar.ActiveSearch?
        private let pasteButton = ComponentView<Empty>()
        private let scanQrButton = UIButton(type: .custom)

        private let recipientSectionTitle = UILabel()
        private let recipientView = WalletPeerSelectionRecipientView()
        private let emptyResultsAnimation = ComponentView<Empty>()
        private let emptyResultsTitle = ComponentView<Empty>()
        private let emptyResultsText = ComponentView<Empty>()
        private let continueButton = ComponentView<Empty>()

        private var component: WalletPeerSelectionScreenComponent?
        private var environment: EnvironmentType?
        private(set) weak var state: EmptyComponentState?
        private var isUpdating = false

        private var walletContext: WalletContext?
        private let walletStateDisposable = MetaDisposable()
        private var chatListDisposable: Disposable?
        private var recentPeersDisposable: Disposable?
        private var updatedRecentPeersDisposable: Disposable?
        private let localPeerSearchDisposable = MetaDisposable()
        private let remotePeerSearchDisposable = MetaDisposable()
        private let resolveDisposable = MetaDisposable()
        private let peerAddressDisposable = MetaDisposable()
        private var resolveTimer: SwiftSignalKit.Timer?
        private var navigationButtonsRevealTimer: SwiftSignalKit.Timer?
        private var resolveGeneration: Int = 0
        private var query: String = ""
        private var peers: [PeerInfo]?
        private var hasTopPeers = false
        private var hasLoadedRecentPeers = false
        private var recentlySearchedPeers: [PeerInfo] = []
        private var localSearchQuery: String?
        private var localSearchPeers: [PeerInfo] = []
        private var remoteLocalSearchPeers: [EnginePeer] = []
        private var globalSearchPeers: [EnginePeer] = []
        private var isSearchingLocalPeers = false
        private var isSearchingRemotePeers = false
        private var isResolvingRecipient = false
        private var recipient: WalletContext.ResolvedTransferRecipient?
        private var recipientPeer: WalletPeerSelectionResolvedPeer?
        private var displaysEmptyResults = false
        private var resolvingPeerId: EnginePeer.Id?
        private var actionGeneration = 0
        private var hasPasteboardText = UIPasteboard.general.hasStrings
        private var hasSpaceForPasteButton = false
        private var navigationButtonsVisible = true
        private var navigationButtonsFieldAlpha: CGFloat = 1.0

        private var isSearching: Bool {
            return self.isSearchingLocalPeers || self.isSearchingRemotePeers || self.isResolvingRecipient
        }

        private func currentPresentationData(for component: WalletPeerSelectionScreenComponent) -> (initial: PresentationData, signal: Signal<PresentationData, NoError>) {
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            return (
                initial: presentationData.withUpdated(theme: self.environment?.theme ?? component.updatedPresentationData.initial.theme),
                signal: component.updatedPresentationData.signal
            )
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.recipientSectionTitle.alpha = 0.0
            self.addSubview(self.recipientSectionTitle)

            self.recipientView.alpha = 0.0
            self.recipientView.pressed = { [weak self] in
                self?.openRecipient()
            }
            self.addSubview(self.recipientView)

            self.addSubview(self.navigationGlassContainer)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.pasteboardDidChange(_:)),
                name: UIPasteboard.changedNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.pasteboardDidChange(_:)),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )

            self.scanQrButton.accessibilityTraits = .button
            self.scanQrButton.addTarget(self, action: #selector(self.scanQrPressed), for: .touchUpInside)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            self.resolveTimer?.invalidate()
            self.navigationButtonsRevealTimer?.invalidate()
            self.chatListDisposable?.dispose()
            self.recentPeersDisposable?.dispose()
            self.updatedRecentPeersDisposable?.dispose()
            self.localPeerSearchDisposable.dispose()
            self.remotePeerSearchDisposable.dispose()
            self.resolveDisposable.dispose()
            self.peerAddressDisposable.dispose()
            self.walletStateDisposable.dispose()
        }

        func cancelPendingActions() {
            self.actionGeneration &+= 1
            self.peerAddressDisposable.set(nil)
            self.resolvingPeerId = nil
            if !self.isUpdating {
                self.state?.updated(transition: .immediate)
            }
        }

        @objc private func pasteboardDidChange(_ notification: Notification) {
            let hasPasteboardText = UIPasteboard.general.hasStrings
            guard self.hasPasteboardText != hasPasteboardText else {
                return
            }
            self.hasPasteboardText = hasPasteboardText
            self.state?.updated(transition: .easeInOut(duration: 0.2))
        }

        private func clearEmptyResults() {
            self.displaysEmptyResults = false
            self.emptyResultsAnimation.view?.removeFromSuperview()
            self.emptyResultsTitle.view?.removeFromSuperview()
            self.emptyResultsText.view?.removeFromSuperview()
        }

        private func resetQuery(keepPeerResults: Bool = false) {
            self.actionGeneration &+= 1
            self.peerAddressDisposable.set(nil)
            self.resolvingPeerId = nil
            self.resolveGeneration &+= 1
            self.resolveTimer?.invalidate()
            self.resolveTimer = nil
            self.resolveDisposable.set(nil)
            self.localPeerSearchDisposable.set(nil)
            self.remotePeerSearchDisposable.set(nil)
            if !keepPeerResults {
                self.localSearchQuery = nil
                self.localSearchPeers = []
                self.remoteLocalSearchPeers = []
                self.globalSearchPeers = []
            }
            self.isSearchingLocalPeers = false
            self.isSearchingRemotePeers = false
            self.isResolvingRecipient = false
            self.query = ""
            self.recipient = nil
            self.recipientPeer = nil
            self.clearEmptyResults()
            self.searchBarNode?.activity = false
        }

        private func updateQuery(_ value: String, transition: ComponentTransition = .easeInOut(duration: 0.2)) {
            let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard self.query != query else {
                return
            }

            self.resetQuery(keepPeerResults: !self.query.isEmpty && !query.isEmpty)
            let generation = self.resolveGeneration
            self.query = query
            self.isSearchingLocalPeers = !query.isEmpty
            self.isSearchingRemotePeers = !query.isEmpty
            self.isResolvingRecipient = !query.isEmpty
            self.searchBarNode?.activity = self.isSearching
            self.state?.updated(transition: transition)

            guard !query.isEmpty, let component = self.component else {
                return
            }

            let context = component.context
            self.localPeerSearchDisposable.set((context.engine.contacts.searchLocalPeers(query: query.lowercased())
            |> mapToSignal { peers -> Signal<[PeerInfo], NoError> in
                var peerIds = Set<EnginePeer.Id>()
                let peers = peers.compactMap { renderedPeer -> EnginePeer? in
                    guard let peer = renderedPeer.chatMainPeer,
                          walletPeerSelectionIsEligiblePeer(peer, accountPeerId: context.account.peerId),
                          peerIds.insert(peer.id).inserted else {
                        return nil
                    }
                    return peer
                }
                return context.engine.data.subscribe(EngineDataMap(peers.map { peer in
                    return TelegramEngine.EngineData.Item.Peer.Presence(id: peer.id)
                }))
                |> map { presences -> [PeerInfo] in
                    return peers.map { peer in
                        return PeerInfo(peer: peer, presence: presences[peer.id] ?? nil)
                    }
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] peers in
                guard let self, self.resolveGeneration == generation, self.query == query else {
                    return
                }
                self.localSearchQuery = query
                self.localSearchPeers = peers
                self.isSearchingLocalPeers = false
                self.searchResultsUpdated()
            }))

            let timer = SwiftSignalKit.Timer(timeout: 0.4, repeat: false, completion: { [weak self] in
                guard let self, self.resolveGeneration == generation, self.query == query else {
                    return
                }
                self.resolveTimer = nil
                self.remotePeerSearchDisposable.set((context.engine.contacts.searchRemotePeers(query: query)
                |> deliverOnMainQueue).start(next: { [weak self] local, global in
                    guard let self, self.resolveGeneration == generation, self.query == query else {
                        return
                    }
                    self.remoteLocalSearchPeers = local.map(\.peer).filter {
                        walletPeerSelectionIsEligiblePeer($0, accountPeerId: context.account.peerId)
                    }
                    self.globalSearchPeers = global.map(\.peer).filter {
                        walletPeerSelectionIsEligiblePeer($0, accountPeerId: context.account.peerId)
                    }
                    self.isSearchingRemotePeers = false
                    self.searchResultsUpdated()
                }))
                self.resolve(query: query, generation: generation)
            }, queue: Queue.mainQueue())
            self.resolveTimer = timer
            timer.start()
        }

        private func searchResultsUpdated() {
            self.searchBarNode?.activity = self.isSearching
            if !self.isUpdating {
                self.state?.updated(transition: .immediate)
            }
        }

        private func resolve(query: String, generation: Int) {
            guard let component = self.component else {
                return
            }
            self.resolveDisposable.set((component.walletContext.resolveTransferRecipient(query)
            |> mapToSignal { recipient -> Signal<(recipient: WalletContext.ResolvedTransferRecipient?, peer: WalletPeerSelectionResolvedPeer?), WalletContext.WalletError> in
                guard let recipient else {
                    return .single((nil, nil))
                }
                return walletPeerSelectionResolvePeer(context: component.context, address: recipient.address)
                |> map { peer -> (recipient: WalletContext.ResolvedTransferRecipient?, peer: WalletPeerSelectionResolvedPeer?) in
                    return (recipient, peer)
                }
                |> castError(WalletContext.WalletError.self)
            }
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let self, self.resolveGeneration == generation, self.query == query else {
                    return
                }
                self.isResolvingRecipient = false
                self.recipient = result.recipient
                self.recipientPeer = result.peer
                self.searchResultsUpdated()
            }, error: { [weak self] _ in
                guard let self, self.resolveGeneration == generation, self.query == query else {
                    return
                }
                self.isResolvingRecipient = false
                self.recipient = nil
                self.recipientPeer = nil
                self.searchResultsUpdated()
            }))
        }

        private func cancelSearch() {
            self.searchBarNode?.deactivate()
            self.resetQuery()
            self.activeSearch = nil
            self.state?.updated(transition: .spring(duration: 0.4))

            self.navigationButtonsRevealTimer?.invalidate()
            let timer = SwiftSignalKit.Timer(timeout: 0.3, repeat: false, completion: { [weak self] in
                guard let self, self.activeSearch == nil else {
                    return
                }
                self.navigationButtonsRevealTimer = nil
                self.navigationButtonsVisible = true
                self.state?.updated(transition: .easeInOut(duration: 0.2))
            }, queue: Queue.mainQueue())
            self.navigationButtonsRevealTimer = timer
            timer.start()
        }

        private func hideNavigationButtons() {
            self.navigationButtonsRevealTimer?.invalidate()
            self.navigationButtonsRevealTimer = nil
            self.navigationButtonsVisible = false

            self.scanQrButton.layer.removeAllAnimations()
            self.scanQrButton.alpha = 0.0
            self.scanQrButton.isUserInteractionEnabled = false
            if let pasteButtonView = self.pasteButton.view {
                pasteButtonView.layer.removeAllAnimations()
                pasteButtonView.alpha = 0.0
                pasteButtonView.isUserInteractionEnabled = false
            }
        }

        private func updateNavigationButtonsAppearance(transition: ComponentTransition) {
            let displaysNavigationButtons = self.activeSearch == nil && self.navigationButtonsVisible
            let alpha: CGFloat = displaysNavigationButtons ? self.navigationButtonsFieldAlpha : 0.0
            let alphaTransition: ComponentTransition = displaysNavigationButtons ? transition : .immediate
            alphaTransition.setAlpha(view: self.scanQrButton, alpha: alpha)

            let buttonsAreInteractive = alpha >= 0.999
                && self.resolvingPeerId == nil
            self.scanQrButton.isUserInteractionEnabled = buttonsAreInteractive
            if let pasteButtonView = self.pasteButton.view {
                let displaysPasteButton = self.hasPasteboardText && self.hasSpaceForPasteButton
                alphaTransition.setAlpha(
                    view: pasteButtonView,
                    alpha: displaysPasteButton ? alpha : 0.0
                )
                pasteButtonView.isUserInteractionEnabled = displaysPasteButton
                    && buttonsAreInteractive
            }
        }

        private func updateNavigationButtonsPosition() {
            guard let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View,
                  let placeholderNode = navigationBarView.searchContentNode?.placeholderNode else {
                return
            }
            self.navigationButtonsFieldAlpha = placeholderNode.labelNode.alpha

            let searchFieldView = placeholderNode.backgroundView
            let searchFieldFrame = searchFieldView.convert(searchFieldView.bounds, to: self.navigationGlassContainer.contentView)
            guard !searchFieldFrame.isEmpty else {
                return
            }

            var scanQrFrame = self.scanQrButton.frame
            scanQrFrame.origin.y = floor(searchFieldFrame.midY - scanQrFrame.height / 2.0)
            ComponentTransition.immediate.setFrame(view: self.scanQrButton, frame: scanQrFrame)

            if let pasteButtonView = self.pasteButton.view {
                var pasteButtonFrame = pasteButtonView.frame
                pasteButtonFrame.origin.y = floor(searchFieldFrame.midY - pasteButtonFrame.height / 2.0)
                ComponentTransition.immediate.setFrame(view: pasteButtonView, frame: pasteButtonFrame)
            }

            if self.activeSearch == nil {
                var buttonsMinX = scanQrFrame.minX
                if self.hasPasteboardText && self.hasSpaceForPasteButton, let pasteButtonView = self.pasteButton.view {
                    buttonsMinX = min(buttonsMinX, pasteButtonView.frame.minX)
                }
                let placeholderOrigin = placeholderNode.labelNode.view.convert(CGPoint(), to: self.navigationGlassContainer.contentView)
                placeholderNode.maximumPlaceholderWidth = max(0.0, buttonsMinX - 8.0 - placeholderOrigin.x)
            }
        }

        private func subscribeToRecentPeers(context: AccountContext) {
            guard self.recentPeersDisposable == nil else {
                return
            }
            self.recentPeersDisposable = (combineLatest(
                context.engine.peers.recentPeers(),
                context.engine.peers.recentlySearchedPeers()
            )
            |> deliverOnMainQueue).start(next: { [weak self] topPeers, recentlySearchedPeers in
                guard let self else {
                    return
                }
                self.hasLoadedRecentPeers = true
                switch topPeers {
                case .disabled:
                    self.hasTopPeers = false
                case let .peers(peers):
                    self.hasTopPeers = peers.contains(where: {
                        walletPeerSelectionIsEligiblePeer(EnginePeer($0), accountPeerId: context.account.peerId)
                    })
                }

                var peerIds = Set<EnginePeer.Id>()
                self.recentlySearchedPeers = recentlySearchedPeers.compactMap { searchedPeer in
                    guard let peer = searchedPeer.peer.chatMainPeer else {
                        return nil
                    }
                    let enginePeer = EnginePeer(peer)
                    guard walletPeerSelectionIsEligiblePeer(enginePeer, accountPeerId: context.account.peerId),
                          peerIds.insert(enginePeer.id).inserted else {
                        return nil
                    }
                    return PeerInfo(peer: enginePeer, presence: EnginePeer.Presence(searchedPeer.presence ?? TelegramUserPresence(status: .none, lastActivity: 0)))
                }
                if !self.isUpdating {
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                }
            })
            self.updatedRecentPeersDisposable = context.engine.peers.managedUpdatedRecentPeers().start()
        }

        func clearRecentSearch(sourceNode: ASDisplayNode) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = self.currentPresentationData(for: component).initial
            let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil
            let items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(text: presentationData.strings.ChatList_ClearSearchHistory, textFont: .small, icon: { _ in nil }, action: emptyAction)),
                .action(ContextMenuActionItem(text: presentationData.strings.ChatList_ClearSearchHistory_Confirm, textColor: .destructive, icon: { _ in nil }, action: { c, _ in
                    let clear = {
                        let _ = component.context.engine.peers.clearRecentlySearchedPeers().startStandalone()
                    }
                    if let c {
                        c.dismiss(completion: clear)
                    } else {
                        clear()
                    }
                }))
            ]
            self.searchBarNode?.deactivate(clear: false)
            controller.present(makeContextController(
                presentationData: presentationData,
                source: .reference(WalletPeerSelectionClearRecentSource(sourceNode: sourceNode)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            ), in: .window(.root))
        }

        private func rememberSearchedPeerOnCompletion(_ peer: EnginePeer?) -> (() -> Void)? {
            guard self.activeSearch != nil, let component = self.component, let peer else {
                return nil
            }
            let context = component.context
            return {
                let _ = context.engine.peers.addRecentlySearchedPeer(peerId: peer.id).startStandalone()
            }
        }

        func peerSelected(peer: EnginePeer) {
            guard let component = self.component,
                  self.resolvingPeerId == nil else {
                return
            }

            self.contentListNode?.clearHighlightAnimated(true)
            self.suggestionsListNode?.clearHighlightAnimated(true)
            if self.recipientPeer?.peer.id == peer.id {
                self.openRecipient()
                return
            }
            if case .transfer = component.mode {
                self.openSendScreen(peer: peer)
                return
            }
            self.resolvingPeerId = peer.id
            let generation = self.actionGeneration

            let addressSignal: Signal<String?, WalletGetUserAddressesError> = component.context.engine.wallet.getUserAddresses(
                userIds: [peer.id],
                force: true
            )
            |> map { addresses -> String? in
                guard let result = addresses.first(where: { $0.userId == peer.id }) else {
                    return nil
                }
                let address = result.address.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !address.isEmpty else {
                    return nil
                }
                return address
            }

            self.peerAddressDisposable.set((addressSignal
            |> deliverOnMainQueue).start(next: { [weak self] address in
                guard let self, self.actionGeneration == generation, self.resolvingPeerId == peer.id else {
                    return
                }
                self.resolvingPeerId = nil

                if let address {
                    self.openRecipient(
                        WalletContext.ResolvedTransferRecipient(
                            address: address,
                            displayName: peer.compactDisplayTitle
                        ),
                        selectedPeer: peer
                    )
                } else {
                    self.presentRecipientErrorAlert()
                }
            }, error: { [weak self] _ in
                guard let self, self.actionGeneration == generation, self.resolvingPeerId == peer.id else {
                    return
                }
                self.resolvingPeerId = nil
                self.presentRecipientErrorAlert()
            }))
        }

        private func presentRecipientErrorAlert() {
            guard let component = self.component,
                  let environment = self.environment,
                  let controller = environment.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                updatedPresentationData: self.currentPresentationData(for: component),
                title: nil,
                text: environment.strings.Wallet_Recipient_Error,
                actions: [TextAlertAction(type: .defaultAction, title: environment.strings.Common_OK, action: {
                })]
            ), in: .window(.root))
        }

        private func presentInvalidPasteToast() {
            guard let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            let presentationData = self.currentPresentationData(for: component).initial
            controller.present(
                UndoOverlayController(
                    presentationData: presentationData,
                    content: .info(
                        title: nil,
                        text: presentationData.strings.Wallet_Recipient_InvalidAddress,
                        timeout: nil,
                        customUndoText: nil
                    ),
                    elevatedLayout: false,
                    position: .bottom,
                    action: { _ in false }
                ),
                in: .current
            )
        }

        private func pasteRecipient() {
            guard self.resolvingPeerId == nil else {
                return
            }
            guard let clipboardValue = UIPasteboard.general.string else {
                self.presentInvalidPasteToast()
                return
            }
            let value = clipboardValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let query: String
            if let recipient = WalletContext.transferRecipient(from: value) {
                query = recipient.transferInput
            } else {
                let lowercaseValue = value.lowercased()
                guard (lowercaseValue.hasSuffix(".ton") || lowercaseValue.hasSuffix(".t.me"))
                    && !value.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains) else {
                    self.presentInvalidPasteToast()
                    return
                }
                query = value
            }

            self.hideNavigationButtons()
            self.activeSearch = ChatListNavigationBar.ActiveSearch(isExternal: false)
            self.updateQuery(query, transition: .spring(duration: 0.4))
        }

        @objc private func scanQrPressed() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  self.resolvingPeerId == nil else {
                return
            }
            let scanner = QrCodeScanScreen(context: component.context, subject: .customValidated(
                info: self.currentPresentationData(for: component).initial.strings.Wallet_Recipient_ScanQR,
                validate: { value in
                    return WalletContext.transferAddress(from: value) != nil
                }
            ))
            scanner.completion = { [weak self, weak scanner] value in
                guard let self,
                      let value,
                      let recipient = WalletContext.transferRecipient(from: value) else {
                    return
                }
                let generation = self.actionGeneration
                Queue.mainQueue().after(0.15) { [self, controller] in
                    guard self.actionGeneration == generation else { return }
                    scanner?.dismiss()
                    if case .transfer = component.mode {
                        self.peerAddressDisposable.set((walletPeerSelectionResolvePeer(context: component.context, address: recipient.address)
                        |> deliverOnMainQueue).start(next: { [weak self, weak controller] peer in
                            guard let self, self.actionGeneration == generation,
                                  let controller, controller.navigationController?.viewControllers.last === controller else {
                                return
                            }
                            self.openSendScreen(peer: peer?.peer, address: recipient.transferInput, resolvedAddress: peer?.address)
                        }))
                    } else {
                        self.openRecipient(recipient)
                    }
                }
            }
            controller.push(scanner)
        }

        private func openRecipient() {
            guard let recipient = self.recipient else {
                return
            }
            self.openRecipient(recipient, peer: self.recipientPeer)
        }

        private func openSendScreen(peer: EnginePeer? = nil, address: String? = nil, resolvedAddress: WalletUserAddress? = nil) {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  self.resolvingPeerId == nil else {
                return
            }

            let rememberSearchedPeer = self.rememberSearchedPeerOnCompletion(peer)
            self.searchBarNode?.deactivate(clear: false)
            let dismissSelectionScreen: () -> Void = { [weak controller] in
                if let controller {
                    if let navigationController = controller.navigationController as? NavigationController {
                        var viewControllers = navigationController.viewControllers
                        viewControllers.removeAll(where: { $0 === controller })
                        navigationController.setViewControllers(viewControllers, animated: false)
                    } else {
                        controller.dismiss(animated: false)
                    }
                }
                component.dismissSourceScreen()
            }
            let sendScreen: WalletSendScreen
            if let peer {
                sendScreen = WalletSendScreen(
                    context: component.context,
                    peer: peer,
                    walletContext: component.walletContext,
                    resolvedAddress: resolvedAddress,
                    initialAddress: address ?? "",
                    refreshBalanceOnOpen: false,
                    transferAnimation: address == nil ? component.transferAnimation : nil,
                    completed: { [weak controller] in
                        rememberSearchedPeer?()
                        let navigationController = controller?.navigationController as? NavigationController
                        dismissSelectionScreen()
                        if address == nil { component.returnedToWallet?() }
                        if address != nil, let navigationController {
                            component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: component.context, chatLocation: .peer(peer), keepStack: .default, useExisting: true, completion: { chatController in
                                chatController.scrollToEndOfHistory()
                            }, forceOpenChat: true))
                        }
                    }
                )
            } else if let address {
                sendScreen = WalletSendScreen(
                    context: component.context,
                    walletContext: component.walletContext,
                    address: address,
                    refreshBalanceOnOpen: false,
                    transferAnimation: component.transferAnimation,
                    completed: {
                        dismissSelectionScreen()
                        component.returnedToWallet?()
                    }
                )
            } else {
                return
            }
            sendScreen.navigationPresentation = .modal
            controller.push(sendScreen)
        }

        private func openRecipient(_ recipient: WalletContext.ResolvedTransferRecipient, peer: WalletPeerSelectionResolvedPeer? = nil, selectedPeer: EnginePeer? = nil) {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  self.resolvingPeerId == nil else {
                return
            }

            switch component.mode {
            case .transfer:
                self.openSendScreen(peer: peer?.peer, address: recipient.transferInput, resolvedAddress: peer?.address)
            case let .collectible(collectible):
                let rememberSearchedPeer = self.rememberSearchedPeerOnCompletion(peer?.peer ?? selectedPeer)
                self.searchBarNode?.deactivate(clear: false)
                let dismissSourceScreens: () -> Void = { [weak controller] in
                    rememberSearchedPeer?()
                    if let controller {
                        if let navigationController = controller.navigationController as? NavigationController {
                            var viewControllers = navigationController.viewControllers
                            viewControllers.removeAll(where: { $0 === controller })
                            navigationController.setViewControllers(viewControllers, animated: false)
                        } else {
                            controller.dismiss(animated: false)
                        }
                    }
                    component.dismissSourceScreen()
                }
                controller.push(component.context.sharedContext.makeWalletTransactionPreviewScreen(
                    context: component.context,
                    walletContext: component.walletContext,
                    address: recipient.address,
                    recipientPeer: peer?.peer ?? selectedPeer,
                    collectible: collectible,
                    comment: nil,
                    dismissSendScreen: dismissSourceScreens
                ))
            }
        }

        private func updateNavigationBar(
            component: WalletPeerSelectionScreenComponent,
            theme: PresentationTheme,
            strings: PresentationStrings,
            size: CGSize,
            insets: UIEdgeInsets,
            statusBarHeight: CGFloat,
            isModal: Bool,
            transition: ComponentTransition,
            deferScrollApplication: Bool
        ) -> CGFloat {
            let headerContent = ChatListHeaderComponent.Content(
                title: "",
                navigationBackTitle: nil,
                titleComponent: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.Wallet_Recipient_Title,
                        font: Font.semibold(17.0),
                        textColor: theme.rootController.navigationBar.primaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                chatListTitle: nil,
                leftButton: isModal ? AnyComponentWithIdentity(id: "close", component: AnyComponent(NavigationButtonComponent(
                    content: .icon(imageName: "Navigation/Close"),
                    pressed: { [weak self] _ in
                        self?.environment?.controller()?.dismiss()
                    }
                ))) : nil,
                rightButtons: [],
                backPressed: isModal ? nil : { [weak self] in
                    self?.environment?.controller()?.dismiss()
                }
            )

            let navigationBarSize = self.navigationBarView.update(
                transition: transition,
                component: AnyComponent(ChatListNavigationBar(
                    context: component.context,
                    theme: theme,
                    strings: strings,
                    statusBarHeight: statusBarHeight,
                    leftInset: insets.left,
                    rightInset: insets.right,
                    search: ChatListNavigationBar.Search(
                        isEnabled: true,
                        placeholder: strings.Wallet_Recipient_Placeholder,
                        displayGlassBackgroundWhenInactive: true,
                        alignPlaceholderToLeftWhenInactive: true
                    ),
                    activeSearch: self.activeSearch,
                    primaryContent: headerContent,
                    secondaryContent: nil,
                    secondaryTransition: 0.0,
                    storySubscriptions: nil,
                    storiesIncludeHidden: false,
                    uploadProgress: [:],
                    headerPanels: nil,
                    tabsNode: nil,
                    tabsNodeIsSearch: false,
                    accessoryPanelContainer: nil,
                    accessoryPanelContainerHeight: 0.0,
                    edgeEffectColor: theme.list.modalPlainBackgroundColor,
                    hasOwnGlassContainer: false,
                    activateSearch: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.hideNavigationButtons()
                        self.activeSearch = ChatListNavigationBar.ActiveSearch(isExternal: false)
                        self.state?.updated(transition: .spring(duration: 0.4))
                    },
                    openStatusSetup: { _ in
                    },
                    allowAutomaticOrder: {
                    }
                )),
                environment: {},
                containerSize: size
            )
            if let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View {
                if deferScrollApplication {
                    navigationBarView.deferScrollApplication = true
                }
                if navigationBarView.superview == nil {
                    self.navigationGlassContainer.contentView.addSubview(navigationBarView)
                }
                let edgeEffectBackgroundView = navigationBarView.edgeEffectBackgroundView
                if edgeEffectBackgroundView.superview !== self {
                    edgeEffectBackgroundView.isUserInteractionEnabled = false
                    self.insertSubview(edgeEffectBackgroundView, belowSubview: self.navigationGlassContainer)
                }
                transition.setFrame(view: navigationBarView, frame: CGRect(origin: CGPoint(), size: navigationBarSize))
                return navigationBarSize.height
            }
            return 0.0
        }

        private func updateNavigationScrolling(
            navigationHeight: CGFloat,
            transition: ComponentTransition
        ) {
            var offset: CGFloat
            if let contentListNode = self.contentListNode {
                switch contentListNode.visibleContentOffset() {
                case .none:
                    offset = 0.0
                case .unknown:
                    offset = navigationHeight
                case let .known(value):
                    offset = value
                }
            } else {
                offset = navigationHeight
            }
            offset = min(offset, ChatListNavigationBar.searchScrollHeight)
            if abs(offset) < 0.1 || self.activeSearch != nil {
                offset = 0.0
            }

            guard let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View else {
                self.updateNavigationButtonsAppearance(transition: transition)
                return
            }
            navigationBarView.applyScroll(
                offset: offset,
                allowAvatarsExpansion: false,
                forceUpdate: false,
                transition: transition.withUserData(ChatListNavigationBar.AnimationHint(
                    disableStoriesAnimations: false,
                    crossfadeStoryPeers: false
                ))
            )
            self.updateNavigationButtonsPosition()
            self.updateNavigationButtonsAppearance(transition: transition)
        }

        func update(
            component: WalletPeerSelectionScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.component = component
            self.environment = environment
            self.recipientSectionTitle.text = environment.strings.Wallet_Transaction_Recipient.uppercased()
            self.scanQrButton.accessibilityLabel = environment.strings.Contacts_ScanQrCode
            self.state = state
            self.hasSpaceForPasteButton = availableSize.width - environment.safeInsets.left - environment.safeInsets.right >= 390.0

            self.subscribeToRecentPeers(context: component.context)

            transition.setFrame(view: self.navigationGlassContainer, frame: CGRect(origin: .zero, size: availableSize))
            self.navigationGlassContainer.update(size: availableSize, isDark: environment.theme.overallDarkAppearance, transition: transition)

            if self.peers == nil && self.chatListDisposable == nil {
                self.chatListDisposable = (component.context.engine.messages.chatList(
                    group: .root,
                    count: 100
                )
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] chatList in
                    guard let self else {
                        return
                    }

                    var peerIds = Set<EnginePeer.Id>()
                    var peers: [PeerInfo] = []
                    for item in chatList.items.reversed() {
                        guard case let .user(user) = item.renderedPeer.chatMainPeer else {
                            continue
                        }
                        let peer = EnginePeer.user(user)
                        guard walletPeerSelectionIsEligiblePeer(peer, accountPeerId: component.context.account.peerId),
                              peerIds.insert(peer.id).inserted else {
                            continue
                        }
                        peers.append(PeerInfo(peer: peer, presence: item.presence))
                    }
                    self.peers = peers
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                    self.environment?.controller()?.ready.set(.single(true))
                })
            }

            if self.walletContext !== component.walletContext {
                self.cancelPendingActions()
                self.walletContext = component.walletContext
                self.walletStateDisposable.set(component.walletContext.state.start(next: { _ in
                }))
            }

            if themeUpdated {
                self.backgroundColor = environment.theme.list.modalPlainBackgroundColor
            }

            let isModal = environment.controller()?.navigationPresentation == .modal
            var statusBarHeight = environment.statusBarHeight
            if isModal {
                statusBarHeight = max(statusBarHeight, self.activeSearch == nil ? 6.0 : 1.0)
            }

            let navigationHeight = self.updateNavigationBar(
                component: component,
                theme: environment.theme,
                strings: environment.strings,
                size: availableSize,
                insets: environment.safeInsets,
                statusBarHeight: statusBarHeight,
                isModal: isModal,
                transition: transition,
                deferScrollApplication: true
            )
            self.navigationHeight = navigationHeight

            if self.scanQrButton.superview == nil {
                self.navigationGlassContainer.contentView.addSubview(self.scanQrButton)
            }
            self.scanQrButton.setImage(
                generateTintedImage(
                    image: UIImage(bundleImageName: "Wallet/ScanQr"),
                    color: environment.theme.list.itemAccentColor
                ),
                for: .normal
            )
            let scanQrFrame = CGRect(
                x: availableSize.width - environment.safeInsets.right - 16.0 - 46.0,
                y: navigationHeight - 57.0,
                width: 44.0,
                height: 44.0
            )
            ComponentTransition.immediate.setFrame(view: self.scanQrButton, frame: scanQrFrame)
            let displaysNavigationButtons = self.activeSearch == nil && self.navigationButtonsVisible

            let displaysPasteButton = displaysNavigationButtons && self.hasPasteboardText && self.hasSpaceForPasteButton
            if displaysPasteButton {
                let pasteButtonHeight: CGFloat = 28.0
                let pasteButtonSize = self.pasteButton.update(
                    transition: transition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .legacy,
                            color: environment.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                            foreground: environment.theme.list.itemAccentColor,
                            pressedColor: environment.theme.list.itemInputField.backgroundColor,
                            cornerRadius: pasteButtonHeight / 2.0
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("paste"),
                            component: AnyComponent(Text(
                                text: environment.strings.Common_Paste,
                                font: Font.semibold(15.0),
                                color: environment.theme.list.itemAccentColor
                            ))
                        ),
                        restrictContentAnimations: true,
                        contentInsets: UIEdgeInsets(
                            top: 0.0,
                            left: 16.0,
                            bottom: 0.0,
                            right: 16.0
                        ),
                        fitToContentWidth: true,
                        isEnabled: self.resolvingPeerId == nil,
                        displaysProgress: false,
                        action: { [weak self] in
                            self?.pasteRecipient()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(
                        width: max(1.0, scanQrFrame.minX - environment.safeInsets.left - 16.0),
                        height: pasteButtonHeight
                    )
                )
                if let pasteButtonView = self.pasteButton.view {
                    if pasteButtonView.superview == nil {
                        pasteButtonView.alpha = 0.0
                        self.navigationGlassContainer.contentView.addSubview(pasteButtonView)
                    }
                    ComponentTransition.immediate.setFrame(
                        view: pasteButtonView,
                        frame: CGRect(
                            x: scanQrFrame.minX - 4.0 - pasteButtonSize.width,
                            y: scanQrFrame.midY - floor(pasteButtonSize.height / 2.0),
                            width: pasteButtonSize.width,
                            height: pasteButtonSize.height
                        )
                    )
                }
            } else if let pasteButtonView = self.pasteButton.view {
                ComponentTransition.immediate.setAlpha(view: pasteButtonView, alpha: 0.0)
                pasteButtonView.isUserInteractionEnabled = false
            }
            self.updateNavigationButtonsPosition()
            self.updateNavigationButtonsAppearance(transition: transition)

            var removedSearchBar: SearchBarNode?
            if self.activeSearch != nil {
                let searchBarNode: SearchBarNode
                var searchBarTransition = transition
                if let current = self.searchBarNode {
                    searchBarNode = current
                } else {
                    searchBarTransition = .immediate
                    let searchBarTheme = SearchBarNodeTheme(theme: environment.theme, hasSeparator: false)
                    searchBarNode = SearchBarNode(
                        theme: searchBarTheme,
                        presentationTheme: environment.theme,
                        strings: environment.strings,
                        fieldStyle: .glass,
                        displayBackground: false,
                        hasOwnGlassContainer: false
                    )
                    searchBarNode.placeholderString = NSAttributedString(
                        string: environment.strings.Wallet_Recipient_Placeholder,
                        font: Font.regular(17.0),
                        textColor: searchBarTheme.placeholder
                    )
                    searchBarNode.autocapitalization = .none
                    searchBarNode.cancel = { [weak self] in
                        self?.cancelSearch()
                    }
                    searchBarNode.textUpdated = { [weak self] query, _ in
                        self?.updateQuery(query)
                    }
                    searchBarNode.textReturned = { [weak self] _ in
                        guard let self, self.recipient != nil else {
                            return
                        }
                        self.openRecipient()
                    }
                    self.searchBarNode = searchBarNode
                }

                searchBarNode.activity = self.isSearching
                let searchBarFrame = CGRect(
                    origin: CGPoint(x: 0.0, y: environment.statusBarHeight + 16.0),
                    size: CGSize(width: availableSize.width, height: 54.0)
                )
                searchBarNode.updateThemeAndStrings(
                    theme: SearchBarNodeTheme(theme: environment.theme, hasSeparator: false),
                    presentationTheme: environment.theme,
                    strings: environment.strings
                )
                searchBarNode.updateLayout(
                    boundingSize: searchBarFrame.size,
                    leftInset: environment.safeInsets.left,
                    rightInset: environment.safeInsets.right,
                    transition: searchBarTransition.containedViewLayoutTransition
                )
                searchBarTransition.setFrame(view: searchBarNode.view, frame: searchBarFrame)
                if searchBarNode.view.superview == nil {
                    self.navigationGlassContainer.contentView.addSubview(searchBarNode.view)
                    searchBarNode.layout()
                    searchBarNode.activate()
                    searchBarNode.text = self.query
                    searchBarNode.view.layoutIfNeeded()
                    if case let .curve(duration, curve) = transition.animation,
                       let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View,
                       let placeholderNode = navigationBarView.searchContentNode?.placeholderNode {
                        let timingFunction: String
                        switch curve {
                        case .easeInOut:
                            timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
                        case .easeIn:
                            timingFunction = CAMediaTimingFunctionName.easeIn.rawValue
                        case .linear:
                            timingFunction = CAMediaTimingFunctionName.linear.rawValue
                        case .spring, .custom, .bounce:
                            timingFunction = kCAMediaTimingFunctionSpring
                        }
                        searchBarNode.animateIn(from: placeholderNode, duration: duration, timingFunction: timingFunction)
                    }
                }
            } else if let searchBarNode = self.searchBarNode {
                searchBarNode.deactivate()
                self.searchBarNode = nil
                removedSearchBar = searchBarNode
            }

            let presentationData = self.currentPresentationData(for: component).initial
            self.recipientSectionTitle.font = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            self.recipientSectionTitle.textColor = environment.theme.list.freeTextColor
            let contentSideInset = environment.safeInsets.left + 16.0
            let hasRecipient = self.recipient != nil
            let displaysAddressRecipient = hasRecipient && self.recipientPeer == nil
            let resultVisibilityTransition = ComponentTransition.easeInOut(duration: 0.2)
            let sectionTitleFrame = CGRect(
                x: contentSideInset,
                y: navigationHeight + 18.0,
                width: max(1.0, availableSize.width - contentSideInset - environment.safeInsets.right - 16.0),
                height: 24.0
            )
            transition.setFrame(view: self.recipientSectionTitle, frame: sectionTitleFrame)
            resultVisibilityTransition.setAlpha(view: self.recipientSectionTitle, alpha: hasRecipient ? 1.0 : 0.0)

            let recipientFrame = CGRect(
                x: environment.safeInsets.left,
                y: sectionTitleFrame.maxY + 4.0,
                width: max(1.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right),
                height: 56.0
            )
            transition.setFrame(view: self.recipientView, frame: recipientFrame)
            resultVisibilityTransition.setAlpha(view: self.recipientView, alpha: displaysAddressRecipient ? 1.0 : 0.0)
            self.recipientView.isUserInteractionEnabled = displaysAddressRecipient
                && self.resolvingPeerId == nil
            if displaysAddressRecipient, let recipient = self.recipient {
                self.recipientView.update(
                    recipient: recipient,
                    theme: environment.theme,
                    size: recipientFrame.size,
                    transition: .immediate
                )
            }

            let buttonHeight: CGFloat = 50.0
            let keyboardTop = availableSize.height - environment.inputHeight
            let buttonBottomInset: CGFloat
            if environment.inputHeight > 0.0 {
                buttonBottomInset = 12.0
            } else {
                buttonBottomInset = max(
                    environment.safeInsets.bottom,
                    environment.additionalInsets.bottom
                ) + 16.0
            }

            let contentListNode: ContentListNode
            if let current = self.contentListNode {
                contentListNode = current
            } else {
                contentListNode = ContentListNode(parentView: self, context: component.context, presentationData: presentationData)
                self.contentListNode = contentListNode
                contentListNode.visibleContentOffsetChanged = { [weak self] _, _ in
                    guard let self, let navigationHeight = self.navigationHeight else {
                        return
                    }
                    self.updateNavigationScrolling(
                        navigationHeight: navigationHeight,
                        transition: .immediate
                    )
                }
                self.insertSubview(contentListNode.view, at: 0)
            }
            transition.setFrame(
                view: contentListNode.view,
                frame: CGRect(origin: .zero, size: availableSize)
            )

            var entries: [ContentEntry] = []
            var peerIds = Set<EnginePeer.Id>()
            if let recipientPeer = self.recipientPeer?.peer {
                peerIds.insert(recipientPeer.id)
                entries.append(.peer(
                    peer: recipientPeer,
                    presence: self.peers?.first(where: { $0.peer.id == recipientPeer.id })?.presence,
                    sortIndex: entries.count
                ))
            }
            func appendPeer(_ peerInfo: PeerInfo, section: PeerSection) {
                guard peerIds.insert(peerInfo.peer.id).inserted else {
                    return
                }
                entries.append(.peer(
                    peer: peerInfo.peer,
                    presence: peerInfo.presence,
                    sortIndex: entries.count,
                    section: section,
                    query: section == .global ? self.query : nil
                ))
            }
            if self.query.isEmpty {
                for peerInfo in self.peers ?? [] {
                    appendPeer(peerInfo, section: .none)
                }
            } else {
                if let localSearchQuery = self.localSearchQuery {
                    for peerInfo in self.recentlySearchedPeers {
                        if peerInfo.peer._asPeer().indexName.matchesByTokens(localSearchQuery) {
                            appendPeer(peerInfo, section: .local)
                        }
                    }
                }
                for peerInfo in self.localSearchPeers {
                    appendPeer(peerInfo, section: .local)
                }
                for peer in self.remoteLocalSearchPeers {
                    appendPeer(PeerInfo(peer: peer, presence: nil), section: .local)
                }
                for peer in self.globalSearchPeers {
                    appendPeer(PeerInfo(peer: peer, presence: nil), section: .global)
                }
            }

            let listTopInset: CGFloat
            if hasRecipient {
                listTopInset = displaysAddressRecipient ? recipientFrame.maxY + 8.0 : recipientFrame.minY
            } else {
                listTopInset = navigationHeight
            }
            var listBottomInset = max(
                environment.safeInsets.bottom + environment.additionalInsets.bottom,
                environment.inputHeight
            )
            if hasRecipient {
                let buttonTop = keyboardTop - buttonBottomInset - buttonHeight
                listBottomInset = max(
                    listBottomInset,
                    availableSize.height - buttonTop + 12.0
                )
            }
            contentListNode.update(
                size: availableSize,
                insets: UIEdgeInsets(
                    top: listTopInset,
                    left: environment.safeInsets.left,
                    bottom: listBottomInset,
                    right: environment.safeInsets.right
                ),
                transition: transition
            )
            let displaysSuggestions = self.activeSearch != nil && self.query.isEmpty
            if !displaysSuggestions {
                let listPresentationDataUpdated = contentListNode.presentationData != presentationData
                contentListNode.presentationData = presentationData
                contentListNode.setEntries(entries, allUpdated: listPresentationDataUpdated)
            }
            let suggestionsVisibilityTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            let displaysContent = !displaysSuggestions && (self.query.isEmpty || !entries.isEmpty)
            contentListNode.view.isUserInteractionEnabled = displaysContent
            contentListNode.view.accessibilityElementsHidden = !displaysContent
            let contentVisibilityTransition = self.activeSearch != nil ? resultVisibilityTransition : suggestionsVisibilityTransition
            contentVisibilityTransition.setAlpha(view: contentListNode.view, alpha: displaysContent ? 1.0 : 0.0)
            let suggestionsListNode: ContentListNode
            let needsInitialSuggestionsLayout = self.suggestionsListNode == nil
            let suggestionsLayoutTransition: ComponentTransition = displaysSuggestions && !needsInitialSuggestionsLayout && self.suggestionsContainerView.alpha == 1.0 ? transition : .immediate
            if let current = self.suggestionsListNode {
                suggestionsListNode = current
            } else {
                suggestionsListNode = ContentListNode(parentView: self, context: component.context, presentationData: presentationData)
                self.suggestionsListNode = suggestionsListNode
                self.suggestionsContainerView.alpha = 0.0
                self.suggestionsContainerView.isHidden = true
                self.insertSubview(self.suggestionsContainerView, aboveSubview: contentListNode.view)
                self.suggestionsContainerView.addSubview(suggestionsListNode.view)
            }
            let suggestionsPresentationDataUpdated = suggestionsListNode.presentationData != presentationData
            suggestionsListNode.presentationData = presentationData
            suggestionsListNode.backgroundColor = environment.theme.list.modalPlainBackgroundColor
            if displaysSuggestions || needsInitialSuggestionsLayout {
                suggestionsLayoutTransition.setFrame(view: self.suggestionsContainerView, frame: CGRect(origin: .zero, size: availableSize))
                suggestionsLayoutTransition.setFrame(view: suggestionsListNode.view, frame: CGRect(origin: .zero, size: availableSize))
                suggestionsListNode.update(
                    size: availableSize,
                    insets: UIEdgeInsets(top: navigationHeight, left: environment.safeInsets.left, bottom: listBottomInset, right: environment.safeInsets.right),
                    transition: suggestionsLayoutTransition
                )
            }
            var suggestions: [ContentEntry] = []
            if self.hasTopPeers {
                suggestions.append(.topPeers)
            }
            for peerInfo in self.recentlySearchedPeers {
                suggestions.append(.peer(peer: peerInfo.peer, presence: peerInfo.presence, sortIndex: suggestions.count, section: .recent))
            }
            suggestionsListNode.setEntries(suggestions, allUpdated: suggestionsPresentationDataUpdated)
            suggestionsListNode.view.isUserInteractionEnabled = displaysSuggestions
            suggestionsListNode.view.accessibilityElementsHidden = !displaysSuggestions
            self.suggestionsContainerView.isUserInteractionEnabled = displaysSuggestions
            self.suggestionsContainerView.accessibilityElementsHidden = !displaysSuggestions
            if displaysSuggestions {
                self.suggestionsContainerView.isHidden = false
            }
            let suggestionsAlpha: CGFloat = displaysSuggestions ? 1.0 : 0.0
            if self.suggestionsContainerView.alpha != suggestionsAlpha {
                suggestionsVisibilityTransition.setAlpha(view: self.suggestionsContainerView, alpha: suggestionsAlpha, completion: { [weak self] completed in
                    guard let self, completed, !self.suggestionsContainerView.isUserInteractionEnabled else {
                        return
                    }
                    self.suggestionsContainerView.isHidden = true
                })
            }

            let displayNoResultsQuery: String?
            if !self.query.isEmpty, !self.isSearching, entries.isEmpty, self.recipient == nil {
                displayNoResultsQuery = self.query
            } else {
                displayNoResultsQuery = nil
            }
            let displaysEmptyRecentPeers = displaysSuggestions && self.hasLoadedRecentPeers && self.recentlySearchedPeers.isEmpty
            let emptyResultsText: String?
            if displaysEmptyRecentPeers {
                emptyResultsText = environment.strings.Wallet_Recipient_NoRecentRecipients
            } else if let noResultsQuery = displayNoResultsQuery {
                emptyResultsText = walletPeerSelectionIsAddressQuery(noResultsQuery)
                    ? environment.strings.Wallet_Recipient_InvalidAddressText
                    : environment.strings.Wallet_Recipient_NoResultsText(noResultsQuery).string
            } else {
                emptyResultsText = nil
            }
            self.displaysEmptyResults = emptyResultsText != nil

            let emptyResultsFadeTransition = ComponentTransition.easeInOut(duration: 0.25)
            if let emptyResultsText {
                let sideInset: CGFloat = 44.0
                let animationHeight: CGFloat = displaysEmptyRecentPeers ? 120.0 : 148.0
                let animationSpacing: CGFloat = 8.0
                let textSpacing: CGFloat = displaysEmptyRecentPeers ? 0.0 : 8.0

                let emptyResultsTitleSize: CGSize
                if displaysEmptyRecentPeers {
                    emptyResultsTitleSize = .zero
                    self.emptyResultsTitle.view?.removeFromSuperview()
                } else {
                    emptyResultsTitleSize = self.emptyResultsTitle.update(
                        transition: .immediate,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Wallet_Recipient_NoResults,
                                font: Font.semibold(17.0),
                                textColor: environment.theme.list.itemSecondaryTextColor
                            )),
                            horizontalAlignment: .center
                        )),
                        environment: {},
                        containerSize: availableSize
                    )
                }

                let emptyResultsTextSize = self.emptyResultsText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: emptyResultsText,
                            font: Font.regular(15.0),
                            textColor: environment.theme.list.itemSecondaryTextColor
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(
                        width: max(1.0, availableSize.width - sideInset * 2.0),
                        height: availableSize.height
                    )
                )

                let emptyResultsAnimationSize = self.emptyResultsAnimation.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: displaysEmptyRecentPeers ? "Loupe" : "ChatListNoResults"),
                        startingPosition: .begin,
                        lottieSettings: component.context.lottieRenderingSettings
                    )),
                    environment: {},
                    containerSize: CGSize(width: animationHeight, height: animationHeight)
                )

                let topInset = displaysEmptyRecentPeers
                    ? navigationHeight
                    : environment.safeInsets.top
                let bottomInset = max(environment.safeInsets.bottom, environment.inputHeight)
                let emptyResultsHeight = animationHeight
                    + animationSpacing
                    + emptyResultsTitleSize.height
                    + textSpacing
                    + emptyResultsTextSize.height
                let animationY = topInset + floorToScreenPixels(
                    (availableSize.height - topInset - bottomInset - emptyResultsHeight) * 0.5
                )
                let emptyResultsAnimationFrame = CGRect(
                    x: floorToScreenPixels((availableSize.width - emptyResultsAnimationSize.width) * 0.5),
                    y: animationY,
                    width: emptyResultsAnimationSize.width,
                    height: emptyResultsAnimationSize.height
                )
                let emptyResultsTitleFrame = CGRect(
                    x: floorToScreenPixels((availableSize.width - emptyResultsTitleSize.width) * 0.5),
                    y: emptyResultsAnimationFrame.maxY + animationSpacing,
                    width: emptyResultsTitleSize.width,
                    height: emptyResultsTitleSize.height
                )
                let emptyResultsTextFrame = CGRect(
                    x: floorToScreenPixels((availableSize.width - emptyResultsTextSize.width) * 0.5),
                    y: emptyResultsTitleFrame.maxY + textSpacing,
                    width: emptyResultsTextSize.width,
                    height: emptyResultsTextSize.height
                )

                if let view = self.emptyResultsAnimation.view as? LottieComponent.View {
                    if view.superview == nil {
                        view.alpha = 0.0
                        self.addSubview(view)
                        view.playOnce()
                    }
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 1.0)
                    view.transform = displaysEmptyRecentPeers ? CGAffineTransform(scaleX: -1.0, y: 1.0) : .identity
                    view.bounds = CGRect(origin: .zero, size: emptyResultsAnimationFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsAnimationFrame.center)
                }
                if !displaysEmptyRecentPeers, let view = self.emptyResultsTitle.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        self.addSubview(view)
                    }
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 1.0)
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTitleFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsTitleFrame.center)
                }
                if let view = self.emptyResultsText.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        self.addSubview(view)
                    }
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 1.0)
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTextFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsTextFrame.center)
                }
            } else {
                if let view = self.emptyResultsAnimation.view {
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 0.0, completion: { [weak self, weak view] _ in
                        guard self?.displaysEmptyResults == false else {
                            return
                        }
                        view?.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsTitle.view {
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 0.0, completion: { [weak self, weak view] _ in
                        guard self?.displaysEmptyResults == false else {
                            return
                        }
                        view?.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsText.view {
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 0.0, completion: { [weak self, weak view] _ in
                        guard self?.displaysEmptyResults == false else {
                            return
                        }
                        view?.removeFromSuperview()
                    })
                }
            }

            let buttonSideInset = environment.safeInsets.left + 16.0
            let buttonWidth = max(
                1.0,
                availableSize.width - buttonSideInset - environment.safeInsets.right - 16.0
            )
            let buttonSize = self.continueButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Wallet_Continue,
                                font: Font.semibold(17.0),
                                textColor: environment.theme.list.itemCheckColors.foregroundColor
                            )),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 1
                        ))
                    ),
                    isEnabled: hasRecipient && self.resolvingPeerId == nil,
                    displaysProgress: false,
                    action: { [weak self] in
                        self?.openRecipient()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: buttonHeight)
            )
            if let buttonView = self.continueButton.view {
                if buttonView.superview == nil {
                    buttonView.alpha = 0.0
                    self.addSubview(buttonView)
                }
                transition.setFrame(
                    view: buttonView,
                    frame: CGRect(
                        x: buttonSideInset,
                        y: keyboardTop - buttonBottomInset - buttonSize.height,
                        width: buttonSize.width,
                        height: buttonSize.height
                    )
                )
                resultVisibilityTransition.setAlpha(view: buttonView, alpha: hasRecipient ? 1.0 : 0.0)
                buttonView.isUserInteractionEnabled = hasRecipient
                    && self.resolvingPeerId == nil
            }

            self.updateNavigationScrolling(
                navigationHeight: navigationHeight,
                transition: transition
            )
            if let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View {
                navigationBarView.deferScrollApplication = false
                navigationBarView.applyCurrentScroll(transition: transition)
            }
            self.updateNavigationButtonsPosition()
            self.updateNavigationButtonsAppearance(transition: transition)

            if let removedSearchBar {
                if !transition.animation.isImmediate,
                   let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View,
                   let placeholderNode = navigationBarView.searchContentNode?.placeholderNode {
                    removedSearchBar.transitionOut(
                        to: placeholderNode,
                        transition: transition.containedViewLayoutTransition,
                        completion: { [weak removedSearchBar] in
                            removedSearchBar?.view.removeFromSuperview()
                        }
                    )
                } else {
                    removedSearchBar.view.removeFromSuperview()
                }
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

public final class WalletPeerSelectionScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        walletContext: WalletContext,
        mode: WalletPeerSelectionScreenMode = .transfer,
        dismissSourceScreen: @escaping () -> Void = {},
        transferAnimation: WalletSendTransferAnimation? = nil,
        returnedToWallet: (() -> Void)? = nil
    ) {
        let updatedPresentationData = presentationDataWithDefaultAccent((
            initial: context.sharedContext.currentPresentationData.with { $0 },
            signal: context.sharedContext.presentationData
        ))
        super.init(
            context: context,
            component: WalletPeerSelectionScreenComponent(
                context: context,
                updatedPresentationData: updatedPresentationData,
                walletContext: walletContext,
                mode: mode,
                dismissSourceScreen: dismissSourceScreen,
                transferAnimation: transferAnimation,
                returnedToWallet: returnedToWallet
            ),
            navigationBarAppearance: .none,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )
        self.ready.set(.never())
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        guard layout.metrics.widthClass == .regular else {
            return nil
        }
        return CGSize(
            width: min(480.0, layout.size.width - 20.0),
            height: min(layout.size.width, layout.size.height) - 88.0
        )
    }

    public override func viewWillDisappear(_ animated: Bool) {
        (self.node.hostView.componentView as? WalletPeerSelectionScreenComponent.View)?.cancelPendingActions()
        super.viewWillDisappear(animated)
    }
}
