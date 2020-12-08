import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramVoip
import TelegramAudio
import AccountContext
import Postbox
import TelegramCore
import SyncCore
import MergeLists
import ItemListUI
import AppBundle
import ContextUI
import ShareController
import DeleteChatPeerActionSheetItem
import UndoUI
import AlertUI
import PresentationDataUtils
import DirectionalPanGesture
import PeerInfoUI

private let panelBackgroundColor = UIColor(rgb: 0x1c1c1e)
private let secondaryPanelBackgroundColor = UIColor(rgb: 0x2c2c2e)
private let fullscreenBackgroundColor = UIColor(rgb: 0x000000)
private let dimColor = UIColor(white: 0.0, alpha: 0.5)

private func cornersImage(top: Bool, bottom: Bool, dark: Bool) -> UIImage? {
    if !top && !bottom {
        return nil
    }
    return generateImage(CGSize(width: 50.0, height: 50.0), rotatedContext: { (size, context) in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.setFillColor((dark ? fullscreenBackgroundColor : panelBackgroundColor).cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        
        var corners: UIRectCorner = []
        if top {
            corners.insert(.topLeft)
            corners.insert(.topRight)
        }
        if bottom {
            corners.insert(.bottomLeft)
            corners.insert(.bottomRight)
        }
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: 11.0, height: 11.0))
        context.addPath(path.cgPath)
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 25, topCapHeight: 25)
}


private final class VoiceChatControllerTitleView: UIView {
    private var theme: PresentationTheme
    
    private let titleNode: ASTextNode
    private let infoNode: ASTextNode
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.titleNode = ASTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        
        self.infoNode = ASTextNode()
        self.infoNode.displaysAsynchronously = false
        self.infoNode.maximumNumberOfLines = 1
        self.infoNode.truncationMode = .byTruncatingTail
        self.infoNode.isOpaque = false
        
        super.init(frame: CGRect())
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.infoNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(title: String, subtitle: String) {
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(17.0), textColor: .white)
        self.infoNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: UIColor.white.withAlphaComponent(0.5))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        if size.height > 40.0 {
            let titleSize = self.titleNode.measure(size)
            let infoSize = self.infoNode.measure(size)
            let titleInfoSpacing: CGFloat = 0.0
            
            let combinedHeight = titleSize.height + infoSize.height + titleInfoSpacing
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
            self.infoNode.frame = CGRect(origin: CGPoint(x: floor((size.width - infoSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0) + titleSize.height + titleInfoSpacing), size: infoSize)
        } else {
            let titleSize = self.titleNode.measure(CGSize(width: floor(size.width / 2.0), height: size.height))
            let infoSize = self.infoNode.measure(CGSize(width: floor(size.width / 2.0), height: size.height))
            
            let titleInfoSpacing: CGFloat = 8.0
            let combinedWidth = titleSize.width + infoSize.width + titleInfoSpacing
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - combinedWidth) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
            self.infoNode.frame = CGRect(origin: CGPoint(x: floor((size.width - combinedWidth) / 2.0 + titleSize.width + titleInfoSpacing), y: floor((size.height - infoSize.height) / 2.0)), size: infoSize)
        }
    }
}

public final class VoiceChatController: ViewController {
    private final class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        private struct ListTransition {
            let deletions: [ListViewDeleteItem]
            let insertions: [ListViewInsertItem]
            let updates: [ListViewUpdateItem]
            let isLoading: Bool
            let isEmpty: Bool
            let crossFade: Bool
            let animated: Bool
        }
        
        private struct State: Equatable {
            var revealedPeerId: PeerId?
        }
        
        private final class Interaction {
            let updateIsMuted: (PeerId, Bool) -> Void
            let openPeer: (PeerId) -> Void
            let openInvite: () -> Void
            let peerContextAction: (PeerEntry, ASDisplayNode, ContextGesture?) -> Void
            let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
            
            private var audioLevels: [PeerId: ValuePipe<Float>] = [:]
            
            init(
                updateIsMuted: @escaping (PeerId, Bool) -> Void,
                openPeer: @escaping (PeerId) -> Void,
                openInvite: @escaping () -> Void,
                peerContextAction: @escaping (PeerEntry, ASDisplayNode, ContextGesture?) -> Void,
                setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void
            ) {
                self.updateIsMuted = updateIsMuted
                self.openPeer = openPeer
                self.openInvite = openInvite
                self.peerContextAction = peerContextAction
                self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
            }
            
            func getAudioLevel(_ peerId: PeerId) -> Signal<Float, NoError> {
                let signal: Signal<Float, NoError>
                if let current = self.audioLevels[peerId] {
                    signal = current.signal()
                } else {
                    let value = ValuePipe<Float>()
                    self.audioLevels[peerId] = value
                    signal = value.signal()
                }
                return signal
                |> mapToSignal { value in
                    return .single(value)
                }
            }
            
            func updateAudioLevels(_ levels: [(PeerId, Float)]) {
                var updated = Set<PeerId>()
                for (peerId, level) in levels {
                    if let pipe = self.audioLevels[peerId] {
                        pipe.putNext(max(0.001, level))
                        updated.insert(peerId)
                    }
                }
                for (peerId, pipe) in self.audioLevels {
                    if !updated.contains(peerId) {
                        pipe.putNext(0.0)
                    }
                }
            }
        }
        
        private struct PeerEntry: Comparable, Identifiable {
            enum State {
                case listening
                case speaking
                case invited
            }
            
            var peer: Peer
            var presence: TelegramUserPresence?
            var activityTimestamp: Int32
            var state: State
            var muteState: GroupCallParticipantsContext.Participant.MuteState?
            var revealed: Bool?
            var canManageCall: Bool
            
            var stableId: PeerId {
                return self.peer.id
            }
            
            static func ==(lhs: PeerEntry, rhs: PeerEntry) -> Bool {
                if !lhs.peer.isEqual(rhs.peer) {
                    return false
                }
                if lhs.presence != rhs.presence {
                    return false
                }
                if lhs.activityTimestamp != rhs.activityTimestamp {
                    return false
                }
                if lhs.state != rhs.state {
                    return false
                }
                if lhs.muteState != rhs.muteState {
                    return false
                }
                if lhs.revealed != rhs.revealed {
                    return false
                }
                if lhs.canManageCall != rhs.canManageCall {
                    return false
                }
                return true
            }
            
            static func <(lhs: PeerEntry, rhs: PeerEntry) -> Bool {
                if lhs.activityTimestamp != rhs.activityTimestamp {
                    return lhs.activityTimestamp > rhs.activityTimestamp
                }
                return lhs.peer.id < rhs.peer.id
            }
        }
        
        private enum EntryId: Hashable {
            case invite
            case peerId(PeerId)
            
            static func <(lhs: EntryId, rhs: EntryId) -> Bool {
                return lhs.hashValue < rhs.hashValue
            }
            
            static func ==(lhs: EntryId, rhs: EntryId) -> Bool {
                switch lhs {
                    case .invite:
                        switch rhs {
                            case .invite:
                                return true
                            default:
                                return false
                        }
                    case let .peerId(lhsId):
                        switch rhs {
                            case let .peerId(rhsId):
                                return lhsId == rhsId
                            default:
                                return false
                        }
                }
            }
        }
        
        private enum ListEntry: Comparable, Identifiable {
            case invite(PresentationTheme, PresentationStrings, String)
            case peer(PeerEntry)
            
            var stableId: EntryId {
                switch self {
                    case .invite:
                        return .invite
                    case let .peer(peerEntry):
                        return .peerId(peerEntry.peer.id)
                }
            }
            
            static func ==(lhs: ListEntry, rhs: ListEntry) -> Bool {
                switch lhs {
                    case let .invite(lhsTheme, lhsStrings, lhsText):
                        if case let .invite(rhsTheme, rhsStrings, rhsText) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsText == rhsText {
                            return true
                        } else {
                            return false
                        }
                    case let .peer(lhsPeerEntry):
                        switch rhs {
                            case let .peer(rhsPeerEntry):
                                return lhsPeerEntry == rhsPeerEntry
                            default:
                                return false
                        }
                }
            }

            static func <(lhs: ListEntry, rhs: ListEntry) -> Bool {
                switch lhs {
                    case .invite:
                        return true
                    case let .peer(lhsPeerEntry):
                        switch rhs {
                            case .invite:
                                return false
                            case let .peer(rhsPeerEntry):
                                return lhsPeerEntry < rhsPeerEntry
                        }
                }
            }
            
            func item(context: AccountContext, presentationData: PresentationData, interaction: Interaction) -> ListViewItem {
                switch self {
                    case let .invite(_, _, text):
                        return VoiceChatActionItem(presentationData: ItemListPresentationData(presentationData), title: text, icon: .generic(UIImage(bundleImageName: "Chat/Context Menu/AddUser")!), action: {
                            interaction.openInvite()
                        })
                    case let .peer(peerEntry):
                        let peer = peerEntry.peer
                        
                        let text: VoiceChatParticipantItem.ParticipantText
                        let icon: VoiceChatParticipantItem.Icon
                        switch peerEntry.state {
                        case .listening:
                            text = .text(presentationData.strings.VoiceChat_StatusListening, .accent)
                            let microphoneColor: UIColor
                            if let muteState = peerEntry.muteState, !muteState.canUnmute {
                                microphoneColor = UIColor(rgb: 0xff3b30)
                            } else {
                                microphoneColor = UIColor(rgb: 0x979797)
                            }
                            icon = .microphone(peerEntry.muteState != nil, microphoneColor)
                        case .speaking:
                            text = .text(presentationData.strings.VoiceChat_StatusSpeaking, .constructive)
                            icon = .microphone(false, UIColor(rgb: 0x34c759))
                        case .invited:
                            text = .text(presentationData.strings.VoiceChat_StatusInvited, .generic)
                            icon = .invite(true)
                        }
                        
                        let revealOptions: [VoiceChatParticipantItem.RevealOption] = []
                        
                        return VoiceChatParticipantItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: context, peer: peer, presence: peerEntry.presence, text: text, icon: icon, enabled: true, selectable: peer.id != context.account.peerId, getAudioLevel: { return interaction.getAudioLevel(peer.id) }, revealOptions: revealOptions, revealed: peerEntry.revealed, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                            interaction.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                        }, action: {
                            interaction.openPeer(peer.id)
                        }, contextAction: peer.id == context.account.peerId || !peerEntry.canManageCall ? nil : { node, gesture in
                            interaction.peerContextAction(peerEntry, node, gesture)
                        })
                }
            }
        }
        
        private func preparedTransition(from fromEntries: [ListEntry], to toEntries: [ListEntry], isLoading: Bool, isEmpty: Bool, crossFade: Bool, context: AccountContext, presentationData: PresentationData, interaction: Interaction) -> ListTransition {
            let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
            
            let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
            let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
            let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
            
            return ListTransition(deletions: deletions, insertions: insertions, updates: updates, isLoading: isLoading, isEmpty: isEmpty, crossFade: crossFade, animated: fromEntries.count != toEntries.count)
        }
        
        private weak var controller: VoiceChatController?
        private let sharedContext: SharedAccountContext
        private let context: AccountContext
        private let call: PresentationGroupCall
        private var presentationData: PresentationData
        private var darkTheme: PresentationTheme
        
        private let dimNode: ASDisplayNode
        private let contentContainer: ASDisplayNode
        private let backgroundNode: ASDisplayNode
        private let listNode: ListView
        private let topPanelNode: ASDisplayNode
        private let optionsButton: VoiceChatHeaderButton
        private let closeButton: VoiceChatHeaderButton
        private let topCornersNode: ASImageNode
        private let bottomPanelNode: ASDisplayNode
        private let bottomCornersNode: ASImageNode
        private let audioOutputNode: CallControllerButtonItemNode
        private let leaveNode: CallControllerButtonItemNode
        private let actionButton: VoiceChatActionButton
        private let leftBorderNode: ASDisplayNode
        private let rightBorderNode: ASDisplayNode
        
        private let titleView: VoiceChatControllerTitleView
        
        private var enqueuedTransitions: [ListTransition] = []
        private var floatingHeaderOffset: CGFloat?
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        private var didSetContentsReady: Bool = false
        private var didSetDataReady: Bool = false
        
        private var currentCallMembers: [GroupCallParticipantsContext.Participant]?
        private var currentInvitedPeers: [Peer]?
        private var currentSpeakingPeers: Set<PeerId>?
        private var accountPeer: Peer?
        
        private var currentEntries: [ListEntry] = []
        
        private var peerViewDisposable: Disposable?
        private let leaveDisposable = MetaDisposable()
        
        private var isMutedDisposable: Disposable?
        private var callStateDisposable: Disposable?
        
        private var pushingToTalk = false
        private let hapticFeedback = HapticFeedback()
        
        private var callState: PresentationGroupCallState?
        
        private var effectiveMuteState: GroupCallParticipantsContext.Participant.MuteState? {
            if self.pushingToTalk {
                return nil
            } else {
                return self.callState?.muteState
            }
        }
        
        private var audioOutputStateDisposable: Disposable?
        private var audioOutputState: ([AudioSessionOutput], AudioSessionOutput?)?
        
        private var audioLevelsDisposable: Disposable?
        private var myAudioLevelDisposable: Disposable?
        private var memberStatesDisposable: Disposable?
        
        private var itemInteraction: Interaction?
        
        private let inviteDisposable = MetaDisposable()
        
        init(controller: VoiceChatController, sharedContext: SharedAccountContext, call: PresentationGroupCall) {
            self.controller = controller
            self.sharedContext = sharedContext
            self.context = call.accountContext
            self.call = call
            
            self.presentationData = sharedContext.currentPresentationData.with { $0 }
            self.darkTheme = defaultDarkColorPresentationTheme
                        
            self.dimNode = ASDisplayNode()
            self.dimNode.backgroundColor = dimColor
            
            self.contentContainer = ASDisplayNode()
            
            self.backgroundNode = ASDisplayNode()
            self.backgroundNode.backgroundColor = secondaryPanelBackgroundColor
            
            self.listNode = ListView()
            self.listNode.verticalScrollIndicatorColor = UIColor(white: 1.0, alpha: 0.3)
            self.listNode.clipsToBounds = true
            self.listNode.stackFromBottom = true
            self.listNode.keepMinimalScrollHeightWithTopInset = 0
            
            self.topPanelNode = ASDisplayNode()
            self.topPanelNode.backgroundColor = panelBackgroundColor
            self.topPanelNode.clipsToBounds = false
            self.topPanelNode.layer.cornerRadius = 12.0
            
            self.optionsButton = VoiceChatHeaderButton()
            self.optionsButton.setImage(optionsButtonImage(dark: false))
            self.closeButton = VoiceChatHeaderButton()
            self.closeButton.setImage(closeButtonImage(dark: false))
            
            self.titleView = VoiceChatControllerTitleView(theme: self.presentationData.theme)
            self.titleView.set(title: self.presentationData.strings.VoiceChat_Title, subtitle: self.presentationData.strings.SocksProxySetup_ProxyStatusConnecting)
            self.titleView.isUserInteractionEnabled = false
            
            self.topCornersNode = ASImageNode()
            self.topCornersNode.displaysAsynchronously = false
            self.topCornersNode.displayWithoutProcessing = true
            self.topCornersNode.image = cornersImage(top: true, bottom: false, dark: false)
            
            self.bottomPanelNode = ASDisplayNode()
            self.bottomPanelNode.backgroundColor = panelBackgroundColor
            self.bottomPanelNode.clipsToBounds = false
            
            self.bottomCornersNode = ASImageNode()
            self.bottomCornersNode.displaysAsynchronously = false
            self.bottomCornersNode.displayWithoutProcessing = true
            self.bottomCornersNode.image = cornersImage(top: false, bottom: true, dark: false)
            
            self.audioOutputNode = CallControllerButtonItemNode()
            self.leaveNode = CallControllerButtonItemNode()
            self.actionButton = VoiceChatActionButton()

            self.leftBorderNode = ASDisplayNode()
            self.leftBorderNode.backgroundColor = panelBackgroundColor
            self.leftBorderNode.isUserInteractionEnabled = false
            
            self.rightBorderNode = ASDisplayNode()
            self.rightBorderNode.backgroundColor = panelBackgroundColor
            self.rightBorderNode.isUserInteractionEnabled = false
            
            super.init()
            
            let statePromise = ValuePromise(State(), ignoreRepeated: true)
            let stateValue = Atomic(value: State())
            let updateState: ((State) -> State) -> Void = { f in
                statePromise.set(stateValue.modify { f($0) })
            }
            
            self.itemInteraction = Interaction(
                updateIsMuted: { [weak self] peerId, isMuted in
                    self?.call.updateMuteState(peerId: peerId, isMuted: isMuted)
            }, openPeer: { [weak self] peerId in
                if let strongSelf = self, let navigationController = strongSelf.controller?.parentNavigationController {
                    let context = strongSelf.context
                    strongSelf.controller?.dismiss(completion: {
                        Queue.mainQueue().justDispatch {
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId), keepStack: .always, purposefulAction: {}, peekData: nil))
                        }
                    })
                }
            }, openInvite: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                let groupPeerId = strongSelf.call.peerId
                let _ = (strongSelf.context.account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(groupPeerId)
                }
                |> deliverOnMainQueue).start(next: { groupPeer in
                    guard let strongSelf = self else {
                        return
                    }
                    guard let groupPeer = groupPeer as? TelegramChannel else {
                        return
                    }
                    
                    var filters: [ChannelMembersSearchFilter] = []
                    if let currentCallMembers = strongSelf.currentCallMembers {
                        filters.append(.disable(Array(currentCallMembers.map { $0.peer.id })))
                    }
                    if !groupPeer.hasPermission(.inviteMembers) {
                        filters.append(.excludeNonMembers)
                    }
                    filters.append(.excludeBots)
                    
                    var dismissController: (() -> Void)?
                    let controller = ChannelMembersSearchController(context: strongSelf.context, peerId: groupPeer.id, forceTheme: strongSelf.darkTheme, mode: .inviteToCall, filters: filters, openPeer: { peer, participant in
                        guard let strongSelf = self else {
                            dismissController?()
                            return
                        }
                        
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        if peer.id == strongSelf.context.account.peerId {
                            return
                        }
                        if let participant = participant {
                            strongSelf.call.invitePeer(participant.peer.id)
                            dismissController?()
                            
                            strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .invitedToVoiceChat(context: strongSelf.context, peer: participant.peer, text: strongSelf.presentationData.strings.VoiceChat_InvitedPeerText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0), elevatedLayout: false, action: { _ in return false }), in: .current)
                        } else {
                            strongSelf.controller?.present(textAlertController(context: strongSelf.context, forceTheme: strongSelf.darkTheme, title: nil, text: strongSelf.presentationData.strings.VoiceChat_InviteMemberToGroupFirstText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), groupPeer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.VoiceChat_InviteMemberToGroupFirstAdd, action: {
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                let selfController = strongSelf.controller
                                let inviteDisposable = strongSelf.inviteDisposable
                                var inviteSignal = strongSelf.context.peerChannelMemberCategoriesContextsManager.addMembers(account: strongSelf.context.account, peerId: groupPeer.id, memberIds: [peer.id])
                                var cancelImpl: (() -> Void)?
                                let progressSignal = Signal<Never, NoError> { [weak selfController] subscriber in
                                    let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                        cancelImpl?()
                                    }))
                                    selfController?.present(controller, in: .window(.root))
                                    return ActionDisposable { [weak controller] in
                                        Queue.mainQueue().async() {
                                            controller?.dismiss()
                                        }
                                    }
                                }
                                |> runOn(Queue.mainQueue())
                                |> delay(0.15, queue: Queue.mainQueue())
                                let progressDisposable = progressSignal.start()
                                
                                inviteSignal = inviteSignal
                                |> afterDisposed {
                                    Queue.mainQueue().async {
                                        progressDisposable.dispose()
                                    }
                                }
                                cancelImpl = {
                                    inviteDisposable.set(nil)
                                }
                                
                                inviteDisposable.set((inviteSignal |> deliverOnMainQueue).start(error: { error in
                                    dismissController?()
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                    
                                    let text: String
                                    switch error {
                                        case .limitExceeded:
                                            text = presentationData.strings.Channel_ErrorAddTooMuch
                                        case .tooMuchJoined:
                                            text = presentationData.strings.Invite_ChannelsTooMuch
                                        case .generic:
                                            text = presentationData.strings.Login_UnknownError
                                        case .restricted:
                                            text = presentationData.strings.Channel_ErrorAddBlocked
                                        case .notMutualContact:
                                            text = presentationData.strings.GroupInfo_AddUserLeftError
                                        case .botDoesntSupportGroups:
                                            text = presentationData.strings.Channel_BotDoesntSupportGroups
                                        case .tooMuchBots:
                                            text = presentationData.strings.Channel_TooMuchBots
                                        case .bot:
                                            text = presentationData.strings.Login_UnknownError
                                    }
                                    strongSelf.controller?.present(textAlertController(context: strongSelf.context, forceTheme: strongSelf.darkTheme, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                }, completed: {
                                    guard let strongSelf = self else {
                                        dismissController?()
                                        return
                                    }
                                    strongSelf.call.invitePeer(peer.id)
                                    dismissController?()
                                    
                                    strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .invitedToVoiceChat(context: strongSelf.context, peer: peer, text: strongSelf.presentationData.strings.VoiceChat_InvitedPeerText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0), elevatedLayout: false, action: { _ in return false }), in: .current)
                                }))
                            })]), in: .window(.root))
                        }
                    })
                    controller.copyInviteLink = {
                        dismissController?()
                        
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let _ = (strongSelf.context.account.postbox.transaction { transaction -> String? in
                            if let peer = transaction.getPeer(call.peerId), let addressName = peer.addressName, !addressName.isEmpty {
                                return "https://t.me/\(addressName)"
                            } else if let cachedData = transaction.getPeerCachedData(peerId: call.peerId) {
                                if let cachedData = cachedData as? CachedChannelData {
                                    return cachedData.exportedInvitation?.link
                                } else if let cachedData = cachedData as? CachedGroupData {
                                    return cachedData.exportedInvitation?.link
                                }
                            }
                            return nil
                        }
                        |> deliverOnMainQueue).start(next: { link in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if let link = link {
                                UIPasteboard.general.string = link
                                
                                strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .linkCopied(text: strongSelf.presentationData.strings.VoiceChat_InviteLinkCopiedText), elevatedLayout: false, action: { _ in return false }), in: .current)
                            }
                        })
                    }
                    dismissController = { [weak controller] in
                        controller?.dismiss()
                    }
                    strongSelf.controller?.push(controller)
                })
            }, peerContextAction: { [weak self] entry, sourceNode, gesture in
                guard let strongSelf = self, let controller = strongSelf.controller, let sourceNode = sourceNode as? ContextExtractedContentContainingNode else {
                    return
                }
                
                let peer = entry.peer
   
                var items: [ContextMenuItem] = []

                if peer.id != strongSelf.context.account.peerId {
                    if let callState = strongSelf.callState, (callState.canManageCall || callState.adminIds.contains(strongSelf.context.account.peerId)) {
                        if callState.adminIds.contains(peer.id) {
                            if let _ = entry.muteState {
                            } else {
                                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_MutePeer, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    strongSelf.call.updateMuteState(peerId: peer.id, isMuted: true)
                                    f(.default)
                                })))
                            }
                        } else {
                            if let muteState = entry.muteState, !muteState.canUnmute {
                                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_UnmutePeer, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Unmute"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    strongSelf.call.updateMuteState(peerId: peer.id, isMuted: false)
                                    f(.default)
                                })))
                            } else {
                                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_MutePeer, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    strongSelf.call.updateMuteState(peerId: peer.id, isMuted: true)
                                    f(.default)
                                })))
                            }
                        }
                    }
                
                    if let callState = strongSelf.callState, (callState.canManageCall && !callState.adminIds.contains(peer.id)) {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_RemovePeer, textColor: .destructive, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
                        }, action: { [weak self] c, _ in
                            c.dismiss(completion: {
                                guard let strongSelf = self else {
                                    return
                                }

                                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme))
                                var items: [ActionSheetItem] = []

                                items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: peer, chatPeer: peer, action: .removeFromGroup, strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder))

                                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.VoiceChat_RemovePeerRemove, color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    let _ = strongSelf.context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: strongSelf.context.account, peerId: strongSelf.call.peerId, memberId: peer.id, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max)).start()
                                    strongSelf.call.removedPeer(peer.id)
                                    
                                    strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .banned(text: strongSelf.presentationData.strings.VoiceChat_RemovedPeerText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0), elevatedLayout: false, action: { _ in return false }), in: .current)
                                }))

                                actionSheet.setItemGroups([
                                    ActionSheetItemGroup(items: items),
                                    ActionSheetItemGroup(items: [
                                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                            actionSheet?.dismissAnimated()
                                        })
                                    ])
                                ])
                                strongSelf.controller?.present(actionSheet, in: .window(.root))
                            })
                        })))
                    }
                }
                
                guard !items.isEmpty else {
                    return
                }
            
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme), source: .extracted(VoiceChatContextExtractedContentSource(controller: controller, sourceNode: sourceNode, keepInPlace: false, blurBackground: true)), items: .single(items), reactionItems: [], gesture: gesture)
                strongSelf.controller?.presentInGlobalOverlay(contextController)
            }, setPeerIdWithRevealedOptions: { peerId, _ in
                updateState { state in
                    var updated = state
                    updated.revealedPeerId = peerId
                    return updated
                }
            })
            
            self.topPanelNode.view.addSubview(self.titleView)
            self.topPanelNode.addSubnode(self.optionsButton)
            self.topPanelNode.addSubnode(self.closeButton)
            self.topPanelNode.addSubnode(self.topCornersNode)
            
            self.bottomPanelNode.addSubnode(self.bottomCornersNode)
            self.bottomPanelNode.addSubnode(self.audioOutputNode)
            self.bottomPanelNode.addSubnode(self.leaveNode)
            self.bottomPanelNode.addSubnode(self.actionButton)
            
            self.addSubnode(self.dimNode)
            self.addSubnode(self.contentContainer)
            self.contentContainer.addSubnode(self.backgroundNode)
            
            self.contentContainer.addSubnode(self.listNode)
            self.contentContainer.addSubnode(self.topPanelNode)
            self.contentContainer.addSubnode(self.leftBorderNode)
            self.contentContainer.addSubnode(self.rightBorderNode)
            self.contentContainer.addSubnode(self.bottomPanelNode)
            
            
            let context = self.context
            let invitedPeers: Signal<[Peer], NoError> = self.call.invitedPeers
            |> mapToSignal { ids -> Signal<[Peer], NoError> in
                return context.account.postbox.transaction { transaction -> [Peer] in
                    return ids.compactMap(transaction.getPeer)
                }
            }
            
            self.memberStatesDisposable = (combineLatest(queue: .mainQueue(),
                self.call.state,
                self.call.members,
                invitedPeers
            )
            |> mapToSignal { values in
                return .single(values)
                |> delay(0.0, queue: .mainQueue())
            }).start(next: { [weak self] state, callMembers, invitedPeers in
                guard let strongSelf = self else {
                    return
                }
                
                if strongSelf.callState != state {
                    let wasMuted = strongSelf.callState?.muteState != nil
                    strongSelf.callState = state
                    
                    if let muteState = state.muteState, !muteState.canUnmute {
                        if strongSelf.pushingToTalk {
                            strongSelf.pushingToTalk = false
                            strongSelf.actionButton.pressing = false
                            strongSelf.actionButton.isUserInteractionEnabled = false
                            strongSelf.actionButton.isUserInteractionEnabled = true
                        }
                    }
                }
                
                strongSelf.updateMembers(muteState: strongSelf.effectiveMuteState, callMembers: callMembers?.participants ?? [], invitedPeers: invitedPeers, speakingPeers: callMembers?.speakingParticipants ?? [])
                
                let subtitle = strongSelf.presentationData.strings.VoiceChat_Panel_Members(Int32(max(1, callMembers?.totalCount ?? 0)))
                strongSelf.titleView.set(title: strongSelf.presentationData.strings.VoiceChat_Title, subtitle: subtitle)
                
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                }
            })
            
            self.peerViewDisposable = (combineLatest(self.context.account.viewTracker.peerView(self.call.peerId), self.context.account.postbox.loadedPeerWithId(self.context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] view, accountPeer in
                guard let strongSelf = self else {
                    return
                }
                                
                if !strongSelf.didSetDataReady {
                    strongSelf.accountPeer = accountPeer
                    strongSelf.updateMembers(muteState: strongSelf.effectiveMuteState, callMembers: strongSelf.currentCallMembers ?? [], invitedPeers: strongSelf.currentInvitedPeers ?? [], speakingPeers: strongSelf.currentSpeakingPeers ?? Set())
                    
                    if let peer = peerViewMainPeer(view), let channel = peer as? TelegramChannel {
                        let addressName = channel.addressName ?? ""
                        if !addressName.isEmpty || (channel.flags.contains(.isCreator) || channel.hasPermission(.inviteMembers)) {
                            if addressName.isEmpty {
                                let _ = ensuredExistingPeerExportedInvitation(account: strongSelf.context.account, peerId: call.peerId).start()
                            }
                        }
                    }
                    
                    strongSelf.didSetDataReady = true
                    strongSelf.controller?.dataReady.set(true)
                }
                
                if let peer = peerViewMainPeer(view), let channel = peer as? TelegramChannel {
                    if channel.hasPermission(.manageCalls) {
                        strongSelf.optionsButton.isUserInteractionEnabled = true
                        strongSelf.optionsButton.alpha = 1.0
                    } else {
                        strongSelf.optionsButton.isUserInteractionEnabled = false
                        strongSelf.optionsButton.alpha = 0.0
                    }
                }
            })
            
            self.audioOutputStateDisposable = (call.audioOutputState
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.audioOutputState = state
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                }
            })
            
            self.audioLevelsDisposable = (call.audioLevels
            |> deliverOnMainQueue).start(next: { [weak self] levels in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.itemInteraction?.updateAudioLevels(levels)
            })
            
            self.myAudioLevelDisposable = (call.myAudioLevel
            |> deliverOnMainQueue).start(next: { [weak self] level in
                guard let strongSelf = self else {
                    return
                }
                var effectiveLevel: Float = 0.0
                if let state = strongSelf.callState, state.muteState == nil || strongSelf.pushingToTalk {
                    effectiveLevel = level
                }
                strongSelf.actionButton.updateLevel(CGFloat(effectiveLevel))
            })
            
            self.leaveNode.addTarget(self, action: #selector(self.leavePressed), forControlEvents: .touchUpInside)
            
            self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
            
            self.audioOutputNode.addTarget(self, action: #selector(self.audioOutputPressed), forControlEvents: .touchUpInside)
            
            self.optionsButton.contextAction = { [weak self, weak optionsButton] sourceNode, gesture in
                guard let strongSelf = self, let controller = strongSelf.controller, let strongOptionsButton = optionsButton else {
                    return
                }
   
                var items: [ContextMenuItem] = []
                
                if let callState = strongSelf.callState, callState.canManageCall, let defaultParticipantMuteState = callState.defaultParticipantMuteState {
                    let isMuted = defaultParticipantMuteState == .muted
                    
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_SpeakPermissionEveryone, icon: { theme in
                        if isMuted {
                            return nil
                        } else {
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
                        }
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                      
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.call.updateDefaultParticipantsAreMuted(isMuted: false)
                    })))
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_SpeakPermissionAdmin, icon: { theme in
                        if !isMuted {
                            return nil
                        } else {
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
                        }
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                      
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.call.updateDefaultParticipantsAreMuted(isMuted: true)
                    })))
                }
                
                if !items.isEmpty {
                    items.append(.separator)
                }
                
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_Share, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                  
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let _ = (strongSelf.context.account.postbox.transaction { transaction -> String? in
                        if let peer = transaction.getPeer(call.peerId), let addressName = peer.addressName, !addressName.isEmpty {
                            return "https://t.me/\(addressName)"
                        } else if let cachedData = transaction.getPeerCachedData(peerId: call.peerId) {
                            if let cachedData = cachedData as? CachedChannelData {
                                return cachedData.exportedInvitation?.link
                            } else if let cachedData = cachedData as? CachedGroupData {
                                return cachedData.exportedInvitation?.link
                            }
                        }
                        return nil
                    } |> deliverOnMainQueue).start(next: { link in
                        if let link = link {
                            if let strongSelf = self {
                                let shareController = ShareController(context: strongSelf.context, subject: .url(link), forcedTheme: strongSelf.darkTheme, forcedActionTitle: strongSelf.presentationData.strings.VoiceChat_CopyInviteLink)
                                strongSelf.controller?.present(shareController, in: .window(.root))
                            }
                        }
                    })
                })))
                
                if let callState = strongSelf.callState, callState.canManageCall {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_EndVoiceChat, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let action: () -> Void = {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            let _ = (strongSelf.call.leave(terminateIfPossible: true)
                            |> filter { $0 }
                            |> take(1)
                            |> deliverOnMainQueue).start(completed: {
                                self?.controller?.dismiss()
                            })
                        }
                        
                        let alert = textAlertController(context: strongSelf.context, forceTheme: strongSelf.darkTheme, title: strongSelf.presentationData.strings.VoiceChat_EndConfirmationTitle, text: strongSelf.presentationData.strings.VoiceChat_EndConfirmationText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.VoiceChat_EndConfirmationEnd, action: {
                            action()
                        })])
                        strongSelf.controller?.present(alert, in: .window(.root))
                    })))
                }
            
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme), source: .extracted(VoiceChatContextExtractedContentSource(controller: controller, sourceNode: strongOptionsButton.extractedContainerNode, keepInPlace: false, blurBackground: false)), items: .single(items), reactionItems: [], gesture: gesture)
                strongSelf.controller?.presentInGlobalOverlay(contextController)
            }
            
            self.optionsButton.addTarget(self, action: #selector(self.optionsPressed), forControlEvents: .touchUpInside)
            self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: .touchUpInside)
            
            self.listNode.updateFloatingHeaderOffset = { [weak self] offset, transition in
                if let strongSelf = self {
                    strongSelf.updateFloatingHeaderOffset(offset: offset, transition: transition)
                }
            }
            
            self.listNode.endedInteractiveDragging = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                switch strongSelf.listNode.visibleContentOffset() {
                case let .known(value):
                    if value <= -10.0 {
//                        strongSelf.controller?.dismiss()
                    }
                default:
                    break
                }
            }
        }
        
        deinit {
            self.peerViewDisposable?.dispose()
            self.leaveDisposable.dispose()
            self.isMutedDisposable?.dispose()
            self.callStateDisposable?.dispose()
            self.audioOutputStateDisposable?.dispose()
            self.memberStatesDisposable?.dispose()
            self.audioLevelsDisposable?.dispose()
            self.myAudioLevelDisposable?.dispose()
            self.inviteDisposable.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveTransitionGestureRecognizer = true
            self.view.disablesInteractiveModalDismiss = true
            
            self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            let longTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.actionButtonPressGesture(_:)))
            longTapRecognizer.minimumPressDuration = 0.001
            longTapRecognizer.delegate = self
            self.actionButton.view.addGestureRecognizer(longTapRecognizer)
            
            let panRecognizer = DirectionalPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.view.addGestureRecognizer(panRecognizer)
        }
        
        @objc private func optionsPressed() {
            if self.optionsButton.isUserInteractionEnabled {
                self.optionsButton.contextAction?(self.optionsButton.containerNode, nil)
            }
        }
        
        @objc private func closePressed() {
            self.controller?.dismiss()
        }
        
        @objc private func leavePressed() {
            self.hapticFeedback.impact(.light)
            
            self.leaveDisposable.set((self.call.leave(terminateIfPossible: false)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                self?.controller?.dismiss()
            }))
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss()
            }
        }
        
        private var actionButtonPressGestureStartTime: Double = 0.0
        @objc private func actionButtonPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
            guard let callState = self.callState else {
                return
            }
            if let muteState = callState.muteState {
                if !muteState.canUnmute {
                    return
                }
            }
            switch gestureRecognizer.state {
                case .began:
                    self.hapticFeedback.impact(.light)
                    
                    self.actionButtonPressGestureStartTime = CACurrentMediaTime()
                    self.actionButton.pressing = true
                    if callState.muteState != nil {
                        self.pushingToTalk = true
                        self.call.setIsMuted(action: .muted(isPushToTalkActive: true))
                    }
                    if let (layout, navigationHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
                    }
                    self.updateMembers(muteState: self.effectiveMuteState, callMembers: self.currentCallMembers ?? [], invitedPeers: self.currentInvitedPeers ?? [], speakingPeers: self.currentSpeakingPeers ?? Set())
                case .ended, .cancelled:
                    self.pushingToTalk = false
                    self.actionButton.pressing = false
                    let timestamp = CACurrentMediaTime()
                    if timestamp - self.actionButtonPressGestureStartTime < 0.2 {
                        self.call.toggleIsMuted()
                    } else {
                        self.hapticFeedback.impact(.light)
                        self.call.setIsMuted(action: .muted(isPushToTalkActive: false))
                    }
                    
                    if let (layout, navigationHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
                    }
                    self.updateMembers(muteState: self.effectiveMuteState, callMembers: self.currentCallMembers ?? [], invitedPeers: self.currentInvitedPeers ?? [], speakingPeers: self.currentSpeakingPeers ?? Set())
                default:
                    break
            }
        }
        
        @objc private func actionButtonPressed() {
            if let callState = self.callState, case .connected = callState.networkState, let muteState = callState.muteState, !muteState.canUnmute {
                self.hapticFeedback.error()
                self.actionButton.layer.addShakeAnimation()
                return
            }

            self.call.toggleIsMuted()
        }
        
        @objc private func audioOutputPressed() {
            self.hapticFeedback.impact(.light)
            
            guard let (availableOutputs, currentOutput) = self.audioOutputState else {
                return
            }
            guard availableOutputs.count >= 2 else {
                return
            }
            let hasMute = false
            
            if availableOutputs.count == 2 {
                for output in availableOutputs {
                    if output != currentOutput {
                        self.call.setCurrentAudioOutput(output)
                        break
                    }
                }
            } else {
                let actionSheet = ActionSheetController(presentationData: self.presentationData)
                var items: [ActionSheetItem] = []
                for output in availableOutputs {
                    if hasMute, case .builtin = output {
                        continue
                    }
                    let title: String
                    var icon: UIImage?
                    switch output {
                        case .builtin:
                            title = UIDevice.current.model
                        case .speaker:
                            title = self.presentationData.strings.Call_AudioRouteSpeaker
                            icon = generateScaledImage(image: UIImage(bundleImageName: "Call/CallSpeakerButton"), size: CGSize(width: 48.0, height: 48.0), opaque: false)
                        case .headphones:
                            title = self.presentationData.strings.Call_AudioRouteHeadphones
                        case let .port(port):
                            title = port.name
                            if port.type == .bluetooth {
                                var image = UIImage(bundleImageName: "Call/CallBluetoothButton")
                                let portName = port.name.lowercased()
                                if portName.contains("airpods pro") {
                                    image = UIImage(bundleImageName: "Call/CallAirpodsProButton")
                                } else if portName.contains("airpods") {
                                    image = UIImage(bundleImageName: "Call/CallAirpodsButton")
                                }
                                icon = generateScaledImage(image: image, size: CGSize(width: 48.0, height: 48.0), opaque: false)
                            }
                    }
                    items.append(CallRouteActionSheetItem(title: title, icon: icon, selected: output == currentOutput, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        self?.call.setCurrentAudioOutput(output)
                    }))
                }
                
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: self.presentationData.strings.Call_AudioRouteHide, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                self.controller?.present(actionSheet, in: .window(.calls))
            }
        }
        
        private func updateFloatingHeaderOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
            guard let (validLayout, _) = self.validLayout else {
                return
            }
            
            self.floatingHeaderOffset = offset
            
            let layoutTopInset: CGFloat = max(validLayout.statusBarHeight ?? 0.0, validLayout.safeInsets.top)
            
            let topPanelHeight: CGFloat = 63.0
            let listTopInset = layoutTopInset + topPanelHeight
            
            let rawPanelOffset = offset + listTopInset - topPanelHeight
            let panelOffset = max(layoutTopInset, rawPanelOffset)
            let topPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: panelOffset), size: CGSize(width: validLayout.size.width, height: topPanelHeight))
            
            let previousFrame = self.topPanelNode.frame
            if !topPanelFrame.equalTo(previousFrame) {
                self.topPanelNode.frame = topPanelFrame

                let positionDelta = CGPoint(x: topPanelFrame.minX - previousFrame.minX, y: topPanelFrame.minY - previousFrame.minY)
                transition.animateOffsetAdditive(node: self.topPanelNode, offset: positionDelta.y)
            }
                        
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelFrame.maxY), size: CGSize(width: validLayout.size.width, height: validLayout.size.height))
            
            let sideInset: CGFloat = 16.0
            let leftBorderFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelFrame.maxY - 16.0), size: CGSize(width: sideInset, height: validLayout.size.height))
            let rightBorderFrame = CGRect(origin: CGPoint(x: validLayout.size.width - sideInset, y: topPanelFrame.maxY - 16.0), size: CGSize(width: sideInset, height: validLayout.size.height))
            
            let previousBackgroundFrame = self.backgroundNode.frame
            let previousLeftBorderFrame = self.leftBorderNode.frame
            let previousRightBorderFrame = self.rightBorderNode.frame
            
            self.updateColors(fullscreen: abs(panelOffset - layoutTopInset) < 1.0)
            
            if !backgroundFrame.equalTo(previousBackgroundFrame) {
                self.backgroundNode.frame = backgroundFrame
                self.leftBorderNode.frame = leftBorderFrame
                self.rightBorderNode.frame = rightBorderFrame
                
                let backgroundPositionDelta = CGPoint(x: backgroundFrame.minX - previousBackgroundFrame.minX, y: backgroundFrame.minY - previousBackgroundFrame.minY)
                transition.animateOffsetAdditive(node: self.backgroundNode, offset: backgroundPositionDelta.y)
                
                let leftBorderPositionDelta = CGPoint(x: leftBorderFrame.minX - previousLeftBorderFrame.minX, y: leftBorderFrame.minY - previousLeftBorderFrame.minY)
                transition.animateOffsetAdditive(node: self.leftBorderNode, offset: leftBorderPositionDelta.y)
                
                let rightBorderPositionDelta = CGPoint(x: rightBorderFrame.minX - previousRightBorderFrame.minX, y: rightBorderFrame.minY - previousRightBorderFrame.minY)
                transition.animateOffsetAdditive(node: self.rightBorderNode, offset: rightBorderPositionDelta.y)
            }
        }
        
        var isFullscreen = false
        func updateColors(fullscreen: Bool) {
            guard self.isFullscreen != fullscreen else {
                return
            }
            self.isFullscreen = fullscreen
            
            self.controller?.statusBar.statusBarStyle = fullscreen ? .White : .Ignore
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .linear)
            
            transition.updateBackgroundColor(node: self.dimNode, color: fullscreen ? fullscreenBackgroundColor : dimColor)
            transition.updateBackgroundColor(node: self.backgroundNode, color: fullscreen ? panelBackgroundColor : secondaryPanelBackgroundColor)
            transition.updateBackgroundColor(node: self.topPanelNode, color: fullscreen ? fullscreenBackgroundColor : panelBackgroundColor)
            transition.updateBackgroundColor(node: self.bottomPanelNode, color: fullscreen ? fullscreenBackgroundColor : panelBackgroundColor)
            transition.updateBackgroundColor(node: self.leftBorderNode, color: fullscreen ? fullscreenBackgroundColor : panelBackgroundColor)
            transition.updateBackgroundColor(node: self.rightBorderNode, color: fullscreen ? fullscreenBackgroundColor : panelBackgroundColor)
            transition.updateBackgroundColor(node: self.rightBorderNode, color: fullscreen ? fullscreenBackgroundColor : panelBackgroundColor)
            
            if let snapshotView = self.topCornersNode.view.snapshotContentTree() {
                snapshotView.frame = self.topCornersNode.frame
                self.topPanelNode.view.addSubview(snapshotView)
                
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
            }
            self.topCornersNode.image = cornersImage(top: true, bottom: false, dark: fullscreen)
            
            if let snapshotView = self.bottomCornersNode.view.snapshotContentTree() {
                snapshotView.frame = self.bottomCornersNode.frame
                self.bottomPanelNode.view.addSubview(snapshotView)
                
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
            }
            self.bottomCornersNode.image = cornersImage(top: false, bottom: true, dark: fullscreen)

            self.optionsButton.setImage(optionsButtonImage(dark: fullscreen), animated: transition.isAnimated)
            self.closeButton.setImage(closeButtonImage(dark: fullscreen), animated: transition.isAnimated)
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let isFirstTime = self.validLayout == nil
            self.validLayout = (layout, navigationHeight)
            
            transition.updateFrame(view: self.titleView, frame: CGRect(origin: CGPoint(x: 0.0, y: 10.0), size: CGSize(width: layout.size.width, height: 44.0)))
            transition.updateFrame(node: self.optionsButton, frame: CGRect(origin: CGPoint(x: 20.0, y: 18.0), size: CGSize(width: 28.0, height: 28.0)))
            transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: layout.size.width - 20.0 - 28.0, y: 18.0), size: CGSize(width: 28.0, height: 28.0)))
            
            transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            transition.updateFrame(node: self.contentContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            let bottomAreaHeight: CGFloat = 268.0
            let layoutTopInset: CGFloat = max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top)
            
            let sideInset: CGFloat = 16.0
            var insets = UIEdgeInsets()
            insets.left = layout.safeInsets.left + sideInset
            insets.right = layout.safeInsets.right + sideInset
            
            let bottomPanelHeight = bottomAreaHeight + layout.intrinsicInsets.bottom
            let listTopInset = layoutTopInset + 63.0
            let listSize = CGSize(width: layout.size.width, height: layout.size.height - listTopInset - bottomPanelHeight)
            
            insets.top = max(0.0, listSize.height - 44.0 - floor(56.0 * 3.5))
            
            transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(x: 0.0, y: listTopInset), size: listSize))
            
            let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listSize, insets: insets, duration: duration, curve: curve)
            
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            
            transition.updateFrame(node: self.topCornersNode, frame: CGRect(origin: CGPoint(x: sideInset, y: 63.0), size: CGSize(width: layout.size.width - sideInset * 2.0, height: 50.0)))
            
            let bottomPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomPanelHeight), size: CGSize(width: layout.size.width, height: bottomPanelHeight))
            transition.updateFrame(node: self.bottomPanelNode, frame: bottomPanelFrame)
            transition.updateFrame(node: self.bottomCornersNode, frame: CGRect(origin: CGPoint(x: sideInset, y: -50.0), size: CGSize(width: layout.size.width - sideInset * 2.0, height: 50.0)))
            
            let sideButtonSize = CGSize(width: 60.0, height: 60.0)
            let centralButtonSize = CGSize(width: 440.0, height: 440.0)
                        
            let actionButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - centralButtonSize.width) / 2.0), y: floorToScreenPixels((bottomAreaHeight - centralButtonSize.height) / 2.0)), size: centralButtonSize)
            
            let actionButtonState: VoiceChatActionButton.State
            let actionButtonTitle: String
            let actionButtonSubtitle: String
            let audioButtonAppearance: CallControllerButtonItemNode.Content.Appearance
            var actionButtonEnabled = true
            if let callState = self.callState {
                switch callState.networkState {
                case .connecting:
                    actionButtonState = .connecting
                    actionButtonTitle = self.presentationData.strings.VoiceChat_Connecting
                    actionButtonSubtitle = ""
                    audioButtonAppearance = .color(.custom(0x2c2c2e))
                    actionButtonEnabled = false
                case .connected:
                    if let muteState = callState.muteState, !self.pushingToTalk {
                        if muteState.canUnmute {
                            actionButtonState = .active(state: .muted)
                            
                            actionButtonTitle = self.presentationData.strings.VoiceChat_Unmute
                            actionButtonSubtitle = self.presentationData.strings.VoiceChat_UnmuteHelp
                            audioButtonAppearance = .color(.custom(0x00274d))
                        } else {
                            actionButtonState = .active(state: .cantSpeak)
                            
                            actionButtonTitle = self.presentationData.strings.VoiceChat_Muted
                            actionButtonSubtitle = self.presentationData.strings.VoiceChat_MutedHelp
                            audioButtonAppearance = .color(.custom(0x00274d))
                        }
                    } else {
                        actionButtonState = .active(state: .on)
                        
                        actionButtonTitle = self.pushingToTalk ? self.presentationData.strings.VoiceChat_Live : self.presentationData.strings.VoiceChat_Mute
                        actionButtonSubtitle = ""
                        audioButtonAppearance = .color(.custom(0x005720))
                    }
                }
            } else {
                actionButtonState = .connecting
                actionButtonTitle = self.presentationData.strings.VoiceChat_Connecting
                actionButtonSubtitle = ""
                audioButtonAppearance = .color(.custom(0x1c1c1e))
                actionButtonEnabled = false
            }
            
            self.actionButton.isUserInteractionEnabled = actionButtonEnabled
            self.actionButton.update(size: centralButtonSize, buttonSize: CGSize(width: 144.0, height: 144.0), state: actionButtonState, title: actionButtonTitle, subtitle: actionButtonSubtitle, dark: false, small: layout.size.width < 330.0, animated: true)
            transition.updateFrame(node: self.actionButton, frame: actionButtonFrame)
            
            var audioMode: CallControllerButtonsSpeakerMode = .none
            //var hasAudioRouteMenu: Bool = false
            if let (availableOutputs, maybeCurrentOutput) = self.audioOutputState, let currentOutput = maybeCurrentOutput {
                //hasAudioRouteMenu = availableOutputs.count > 2
                switch currentOutput {
                    case .builtin:
                        audioMode = .builtin
                    case .speaker:
                        audioMode = .speaker
                    case .headphones:
                        audioMode = .headphones
                    case let .port(port):
                        var type: CallControllerButtonsSpeakerMode.BluetoothType = .generic
                        let portName = port.name.lowercased()
                        if portName.contains("airpods pro") {
                            type = .airpodsPro
                        } else if portName.contains("airpods") {
                            type = .airpods
                        }
                        audioMode = .bluetooth(type)
                }
                if availableOutputs.count <= 1 {
                    audioMode = .none
                }
            }
            
            let soundImage: CallControllerButtonItemNode.Content.Image
            var soundAppearance: CallControllerButtonItemNode.Content.Appearance = audioButtonAppearance
            switch audioMode {
            case .none, .builtin:
                soundImage = .speaker
            case .speaker:
                soundImage = .speaker
                soundAppearance = .blurred(isFilled: true)
            case .headphones:
                soundImage = .bluetooth
            case let .bluetooth(type):
                switch type {
                case .generic:
                    soundImage = .bluetooth
                case .airpods:
                    soundImage = .airpods
                case .airpodsPro:
                    soundImage = .airpodsPro
                }
            }
            
            self.audioOutputNode.update(size: sideButtonSize, content: CallControllerButtonItemNode.Content(appearance: soundAppearance, image: soundImage), text: self.presentationData.strings.VoiceChat_Audio, transition: .animated(duration: 0.3, curve: .linear))
            
            self.leaveNode.update(size: sideButtonSize, content: CallControllerButtonItemNode.Content(appearance: .color(.custom(0x602522)), image: .end), text: self.presentationData.strings.VoiceChat_Leave, transition: .immediate)
            
            let sideButtonMinimalInset: CGFloat = 16.0
            let sideButtonOffset = min(36.0, floor((((layout.size.width - 144.0) / 2.0) - sideButtonSize.width) / 2.0))
            let sideButtonOrigin = max(sideButtonMinimalInset, floor((layout.size.width - 144.0) / 2.0) - sideButtonOffset - sideButtonSize.width)
            
            transition.updateFrame(node: self.audioOutputNode, frame: CGRect(origin: CGPoint(x: sideButtonOrigin, y: floor((bottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize))
            transition.updateFrame(node: self.leaveNode, frame: CGRect(origin: CGPoint(x: layout.size.width - sideButtonOrigin - sideButtonSize.width, y: floor((bottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize))
            
            if isFirstTime {
                while !self.enqueuedTransitions.isEmpty {
                    self.dequeueTransition()
                }
            }
        }
        
        func animateIn() {
            guard let (layout, _) = self.validLayout else {
                return
            }
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            
            let topPanelFrame = self.topPanelNode.view.convert(self.topPanelNode.bounds, to: self.view)

            let initialBounds = self.contentContainer.bounds
            self.contentContainer.bounds = initialBounds.offsetBy(dx: 0.0, dy: -(layout.size.height - topPanelFrame.minY))
            transition.animateView {
                self.contentContainer.view.bounds = initialBounds
            }
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        
        func animateOut(completion: (() -> Void)?) {
            var offsetCompleted = false
            let internalCompletion: () -> Void = { [weak self] in
                if offsetCompleted {
                    if let strongSelf = self {
                        strongSelf.contentContainer.layer.removeAllAnimations()
                        strongSelf.dimNode.layer.removeAllAnimations()
                        
                        var bounds = strongSelf.contentContainer.bounds
                        bounds.origin.y = 0.0
                        strongSelf.contentContainer.bounds = bounds
                    }
                    completion?()
                }
            }
            
            self.contentContainer.layer.animateBoundsOriginYAdditive(from: self.contentContainer.bounds.origin.y, to: -self.contentContainer.bounds.size.height, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                offsetCompleted = true
                internalCompletion()
            })
            self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        
        private func enqueueTransition(_ transition: ListTransition) {
            self.enqueuedTransitions.append(transition)
            
            if let _ = self.validLayout {
                while !self.enqueuedTransitions.isEmpty {
                    self.dequeueTransition()
                }
            }
        }
        
        private var isFirstTime = true
        private func dequeueTransition() {
            guard let _ = self.validLayout, let transition = self.enqueuedTransitions.first else {
                return
            }
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if transition.crossFade {
                options.insert(.AnimateCrossfade)
            }
            if transition.animated {
                options.insert(.AnimateInsertion)
            }
            options.insert(.LowLatency)
            options.insert(.PreferSynchronousResourceLoading)
            
            
            var scrollToItem: ListViewScrollToItem?
            if self.isFirstTime {
                self.isFirstTime = false
                scrollToItem = ListViewScrollToItem(index: 0, position: .bottom(0), animated: false, curve: .Default(duration: nil), directionHint: .Up)
            }
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                if !strongSelf.didSetContentsReady {
                    strongSelf.didSetContentsReady = true
                    strongSelf.controller?.contentsReady.set(true)
                }
            })
        }
        
        private func updateMembers(muteState: GroupCallParticipantsContext.Participant.MuteState?, callMembers: [GroupCallParticipantsContext.Participant], invitedPeers: [Peer], speakingPeers: Set<PeerId>) {
            self.currentCallMembers = callMembers
            self.currentSpeakingPeers = speakingPeers
            self.currentInvitedPeers = invitedPeers
            
            let previousEntries = self.currentEntries
            var entries: [ListEntry] = []
            
            var index: Int32 = 0
            
            var processedPeerIds = Set<PeerId>()
            
            entries.append(.invite(self.presentationData.theme, self.presentationData.strings, self.presentationData.strings.VoiceChat_InviteMember))

            for member in callMembers {
                if processedPeerIds.contains(member.peer.id) {
                    continue
                }
                processedPeerIds.insert(member.peer.id)
                
                let memberState: PeerEntry.State
                var memberMuteState: GroupCallParticipantsContext.Participant.MuteState?
                if member.peer.id == self.context.account.peerId {
                    if muteState == nil {
                        memberState = speakingPeers.contains(member.peer.id) ? .speaking : .listening
                    } else {
                        memberState = .listening
                        memberMuteState = member.muteState
                    }
                } else {
                    memberState = speakingPeers.contains(member.peer.id) ? .speaking : .listening
                    memberMuteState = member.muteState
                }
                
                entries.append(.peer(PeerEntry(
                    peer: member.peer,
                    presence: nil,
                    activityTimestamp: Int32.max - 1 - index,
                    state: memberState,
                    muteState: memberMuteState,
                    canManageCall: callState?.canManageCall ?? false
                )))
                index += 1
            }
            
            if let accountPeer = self.accountPeer, !processedPeerIds.contains(accountPeer.id) {
                entries.insert(.peer(PeerEntry(
                    peer: accountPeer,
                    presence: nil,
                    activityTimestamp: Int32.max - 1 - index,
                    state: .listening,
                    muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: true),
                    canManageCall: callState?.canManageCall ?? false
                )), at: 1)
            }
            
            for peer in invitedPeers {
                if processedPeerIds.contains(peer.id) {
                    continue
                }
                processedPeerIds.insert(peer.id)
                
                entries.append(.peer(PeerEntry(
                    peer: peer,
                    presence: nil,
                    activityTimestamp: Int32.max - 1 - index,
                    state: .invited,
                    muteState: nil,
                    canManageCall: false
                )))
                index += 1
            }
            
            self.currentEntries = entries
            
            let presentationData = self.presentationData.withUpdated(theme: self.darkTheme)
            let transition = preparedTransition(from: previousEntries, to: entries, isLoading: false, isEmpty: false, crossFade: false, context: self.context, presentationData: presentationData, interaction: self.itemInteraction!)
            self.enqueueTransition(transition)
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
//            if let callState = self.callState, case .connected = callState.networkState, let muteState = callState.muteState, !muteState.canUnmute {
//                return false
//            }
            if let recognizer = gestureRecognizer as? UIPanGestureRecognizer {
                let location = recognizer.location(in: self.view)
                if let view = super.hitTest(location, with: nil) {
                    if let gestureRecognizers = view.gestureRecognizers, view != self.view {
                        for gestureRecognizer in gestureRecognizers {
                            if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer, gestureRecognizer.isEnabled {
                                if panGestureRecognizer.state != .began {
                                    panGestureRecognizer.isEnabled = false
                                    panGestureRecognizer.isEnabled = true
                                }
                            }
                        }
                    }
                }
            }
            return true
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
                case .began:
                    break
                case .changed:
                    let translation = recognizer.translation(in: self.contentContainer.view)
                    var bounds = self.contentContainer.bounds
                    bounds.origin.y = -translation.y
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.contentContainer.bounds = bounds
                case .ended:
                    let translation = recognizer.translation(in: self.contentContainer.view)
                    var bounds = self.contentContainer.bounds
                    bounds.origin.y = -translation.y
                    
                    let velocity = recognizer.velocity(in: self.contentContainer.view)
                    
                    if (bounds.minY < -60.0 || velocity.y > 300.0) {
                        self.controller?.dismiss()
                    } else {
                        var bounds = self.contentContainer.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.contentContainer.bounds = bounds
                        self.contentContainer.layer.animateBounds(from: previousBounds, to: self.contentContainer.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                case .cancelled:
                    let previousBounds = self.contentContainer.bounds
                    var bounds = self.contentContainer.bounds
                    bounds.origin.y = 0.0
                    self.contentContainer.bounds = bounds
                    self.contentContainer.layer.animateBounds(from: previousBounds, to: self.contentContainer.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                default:
                    break
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)

            if result === self.topPanelNode.view {
                return self.listNode.view
            }
            
            if result === self.bottomPanelNode.view {
                return self.view
            }
            
            if !self.bounds.contains(point) {
                return nil
            }
            if point.y < self.topPanelNode.frame.minY {
                return self.dimNode.view
            }
            return result
        }
    }
    
    private let sharedContext: SharedAccountContext
    public let call: PresentationGroupCall
    private let presentationData: PresentationData
    public var parentNavigationController: NavigationController?
        
    fileprivate let contentsReady = ValuePromise<Bool>(false, ignoreRepeated: true)
    fileprivate let dataReady = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    
    private var didAppearOnce: Bool = false
    private var isDismissed: Bool = false
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private let idleTimerExtensionDisposable = MetaDisposable()
    
    public init(sharedContext: SharedAccountContext, accountContext: AccountContext, call: PresentationGroupCall) {
        self.sharedContext = sharedContext
        self.call = call
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
                 
        self.statusBar.statusBarStyle = .Ignore
        
        self._ready.set(combineLatest([
            self.contentsReady.get(),
            self.dataReady.get()
        ])
        |> map { values -> Bool in
            for value in values {
                if !value {
                    return false
                }
            }
            return true
        }
        |> filter { $0 })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.idleTimerExtensionDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self, sharedContext: self.sharedContext, call: self.call)
        
        self.displayNodeDidLoad()
    }
        
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.isDismissed = false
        
        if !self.didAppearOnce {
            self.didAppearOnce = true
            
            self.controllerNode.animateIn()
            
            self.idleTimerExtensionDisposable.set(self.sharedContext.applicationBindings.pushIdleTimerExtension())
        }
        
        DispatchQueue.main.async {
            self.onViewDidAppear?()
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.idleTimerExtensionDisposable.set(nil)
        self.onViewDidDisappear?()
    }
    
    func dismissInteractively(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            self.didAppearOnce = false
            
            completion?()
            self.dismiss(animated: false)
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            self.didAppearOnce = false
            
            self.controllerNode.animateOut(completion: { [weak self] in
                completion?()
                self?.dismiss(animated: false)
            })
            
            DispatchQueue.main.async {
                self.onViewDidDisappear?()
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class VoiceChatContextExtractedContentSource: ContextExtractedContentSource {
    var keepInPlace: Bool
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool, blurBackground: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.keepInPlace = keepInPlace
        self.blurBackground = blurBackground
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
