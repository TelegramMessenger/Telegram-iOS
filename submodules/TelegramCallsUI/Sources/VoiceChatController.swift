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
    
    func animateIn(duration: Double) {
        self.titleNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 49.0), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        self.infoNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 49.0), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        self.titleNode.layer.animateScale(from: 0.882, to: 1.0, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
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
            let count: Int
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
            
            return ListTransition(deletions: deletions, insertions: insertions, updates: updates, isLoading: isLoading, isEmpty: isEmpty, crossFade: crossFade, count: toEntries.count)
        }
        
        private weak var controller: VoiceChatController?
        private let sharedContext: SharedAccountContext
        private let context: AccountContext
        private let call: PresentationGroupCall
        private var presentationData: PresentationData
        private var darkTheme: PresentationTheme
        
        private let optionsButton: VoiceChatOptionsButton
        private let closeButton: HighlightableButtonNode
        
        private let dimNode: ASDisplayNode
        private let contentContainer: ASDisplayNode
        private let backgroundNode: ASDisplayNode
        private let listNode: ListView
        private let audioOutputNode: CallControllerButtonItemNode
        private let leaveNode: CallControllerButtonItemNode
        private let actionButton: VoiceChatActionButton
        
        private let titleView: VoiceChatControllerTitleView
        
        private var enqueuedTransitions: [ListTransition] = []
        private var maxListHeight: CGFloat?
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        private var didSetContentsReady: Bool = false
        private var didSetDataReady: Bool = false
        
        private var currentGroupMembers: [RenderedChannelParticipant]?
        private var currentCallMembers: [GroupCallParticipantsContext.Participant]?
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
        
        init(controller: VoiceChatController, sharedContext: SharedAccountContext, call: PresentationGroupCall) {
            self.controller = controller
            self.sharedContext = sharedContext
            self.context = call.accountContext
            self.call = call
            
            self.presentationData = sharedContext.currentPresentationData.with { $0 }
            self.darkTheme = defaultDarkColorPresentationTheme
            
            self.optionsButton = VoiceChatOptionsButton()
            self.closeButton = HighlightableButtonNode()
            
            self.dimNode = ASDisplayNode()
            self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            
            self.contentContainer = ASDisplayNode()
            
            self.backgroundNode = ASDisplayNode()
            self.backgroundNode.backgroundColor = UIColor(rgb: 0x000000)
            self.backgroundNode.cornerRadius = 12.0
            
            self.listNode = ListView()
            self.listNode.backgroundColor = self.darkTheme.list.itemBlocksBackgroundColor
            self.listNode.verticalScrollIndicatorColor = UIColor(white: 1.0, alpha: 0.3)
            self.listNode.clipsToBounds = true
            self.listNode.cornerRadius = 12.0
            
            self.audioOutputNode = CallControllerButtonItemNode()
            self.leaveNode = CallControllerButtonItemNode()
            self.actionButton = VoiceChatActionButton()
                        
            self.titleView = VoiceChatControllerTitleView(theme: self.presentationData.theme)
            self.titleView.set(title: self.presentationData.strings.VoiceChat_Title, subtitle: self.presentationData.strings.SocksProxySetup_ProxyStatusConnecting)
            
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
                    strongSelf.controller?.dismiss()
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), keepStack: .always, purposefulAction: {}, peekData: nil))
                }
            }, openInvite: {
                
            }, peerContextAction: { [weak self] entry, sourceNode, gesture in
                guard let strongSelf = self, let controller = strongSelf.controller, let sourceNode = sourceNode as? ContextExtractedContentContainingNode else {
                    return
                }
                
                let peer = entry.peer
   
                var items: [ContextMenuItem] = []

                if peer.id != strongSelf.context.account.peerId {
                    if let callState = strongSelf.callState, (callState.canManageCall || callState.adminIds.contains(strongSelf.context.account.peerId)), !callState.adminIds.contains(peer.id) {
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
                
                    if let callState = strongSelf.callState, (callState.canManageCall && !callState.adminIds.contains(peer.id)) {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_RemovePeer, textColor: .destructive, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            guard let strongSelf = self else {
                                return
                            }

                            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme))
                            var items: [ActionSheetItem] = []

                            items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: peer, chatPeer: peer, action: .removeFromGroup, strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder))

                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.VoiceChat_RemovePeerRemove, color: .destructive, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                
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
                        })))
                    }
                }
                
                guard !items.isEmpty else {
                    return
                }
            
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme), source: .extracted(VoiceChatContextExtractedContentSource(controller: controller, sourceNode: sourceNode, keepInPlace: false)), items: .single(items), reactionItems: [], gesture: gesture)
                strongSelf.controller?.presentInGlobalOverlay(contextController)
            }, setPeerIdWithRevealedOptions: { peerId, _ in
                updateState { state in
                    var updated = state
                    updated.revealedPeerId = peerId
                    return updated
                }
            })
            
            self.backgroundNode.addSubnode(self.listNode)
            self.backgroundNode.addSubnode(self.audioOutputNode)
            self.backgroundNode.addSubnode(self.leaveNode)
            self.backgroundNode.addSubnode(self.actionButton)
            self.backgroundNode.view.addSubview(self.titleView)
            self.backgroundNode.addSubnode(self.optionsButton)
            self.backgroundNode.addSubnode(self.closeButton)
            
            self.addSubnode(self.dimNode)
            self.addSubnode(self.contentContainer)
            self.contentContainer.addSubnode(self.backgroundNode)
                        
            self.memberStatesDisposable = (self.call.members
            |> deliverOnMainQueue).start(next: { [weak self] callMembers in
                guard let strongSelf = self, let callMembers = callMembers else {
                    return
                }
                if let groupMembers = strongSelf.currentGroupMembers {
                    strongSelf.updateMembers(muteState: strongSelf.effectiveMuteState, groupMembers: groupMembers, callMembers: callMembers.participants, speakingPeers: callMembers.speakingParticipants)
                } else {
                    strongSelf.currentCallMembers = callMembers.participants
                }
                
                let subtitle = strongSelf.presentationData.strings.VoiceChat_Panel_Members(Int32(max(1, callMembers.totalCount)))
                strongSelf.titleView.set(title: strongSelf.presentationData.strings.VoiceChat_Title, subtitle: subtitle)
            })
            
            self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
                guard let strongSelf = self else {
                    return
                }
                if case let .known(value) = offset, value < 40.0 {
                }
            }
            
            self.peerViewDisposable = (combineLatest(self.context.account.viewTracker.peerView(self.call.peerId), self.context.account.postbox.loadedPeerWithId(self.context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] view, accountPeer in
                guard let strongSelf = self else {
                    return
                }
                                
                if !strongSelf.didSetDataReady {
                    strongSelf.accountPeer = accountPeer
                    strongSelf.updateMembers(muteState: strongSelf.effectiveMuteState, groupMembers: [], callMembers: strongSelf.currentCallMembers ?? [], speakingPeers: strongSelf.currentSpeakingPeers ?? Set())
                    
                    if let peer = peerViewMainPeer(view), let channel = peer as? TelegramChannel {
                        let addressName = channel.addressName ?? ""
                        if !addressName.isEmpty || (channel.flags.contains(.isCreator) || channel.hasPermission(.inviteMembers)) {
                            if addressName.isEmpty {
                                let _ = ensuredExistingPeerExportedInvitation(account: strongSelf.context.account, peerId: call.peerId).start()
                            }
                        } else {
                            strongSelf.optionsButton.isUserInteractionEnabled = false
                            strongSelf.optionsButton.alpha = 0.0
                        }
                    }
                    
                    strongSelf.didSetDataReady = true
                    strongSelf.controller?.dataReady.set(true)
                }
            })
            
            self.callStateDisposable = (self.call.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
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
                    
                    if wasMuted != (state.muteState != nil), let groupMembers = strongSelf.currentGroupMembers {
                        strongSelf.updateMembers(muteState: strongSelf.effectiveMuteState, groupMembers: groupMembers, callMembers: strongSelf.currentCallMembers ?? [], speakingPeers: strongSelf.currentSpeakingPeers ?? Set())
                    }
                    
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
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
                        
                        let alert = textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.VoiceChat_EndConfirmationTitle, text: strongSelf.presentationData.strings.VoiceChat_EndConfirmationText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.VoiceChat_EndConfirmationEnd, action: {
                            action()
                        })])
                        strongSelf.controller?.present(alert, in: .window(.root))
                    })))
                }
            
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme), source: .extracted(VoiceChatContextExtractedContentSource(controller: controller, sourceNode: strongOptionsButton.extractedContainerNode, keepInPlace: true)), items: .single(items), reactionItems: [], gesture: gesture)
                strongSelf.controller?.presentInGlobalOverlay(contextController)
            }
            
            self.closeButton.setImage(closeButtonImage(), for: [.normal])
            self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: .touchUpInside)
            
            self.optionsButton.addTarget(self, action: #selector(self.optionsPressed), forControlEvents: .touchUpInside)
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
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            let longTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.actionButtonPressGesture(_:)))
            longTapRecognizer.minimumPressDuration = 0.001
            longTapRecognizer.delegate = self
            self.actionButton.view.addGestureRecognizer(longTapRecognizer)
            
            let panRecognizer = CallPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.shouldBegin = { [weak self] _ in
                guard let _ = self else {
                    return false
                }
                return true
            }
            self.backgroundNode.view.addGestureRecognizer(panRecognizer)
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
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let callState = self.callState, case .connected = callState.networkState, let muteState = callState.muteState, !muteState.canUnmute {
                return false
            } else {
                return true
            }
        }
        
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
                    self.updateMembers(muteState: self.effectiveMuteState, groupMembers: self.currentGroupMembers ?? [], callMembers: self.currentCallMembers ?? [], speakingPeers: self.currentSpeakingPeers ?? Set())
                case .ended, .cancelled:
                    self.hapticFeedback.impact(.light)
                    
                    self.pushingToTalk = false
                    self.actionButton.pressing = false
                    let timestamp = CACurrentMediaTime()
                    if timestamp - self.actionButtonPressGestureStartTime < 0.1 {
                        self.call.toggleIsMuted()
                    } else {
                        self.call.setIsMuted(action: .muted(isPushToTalkActive: false))
                    }
                    if let (layout, navigationHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
                    }
                    self.updateMembers(muteState: self.effectiveMuteState, groupMembers: self.currentGroupMembers ?? [], callMembers: self.currentCallMembers ?? [], speakingPeers: self.currentSpeakingPeers ?? Set())
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
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let isFirstTime = self.validLayout == nil
            self.validLayout = (layout, navigationHeight)
            
            transition.updateFrame(view: self.titleView, frame: CGRect(origin: CGPoint(x: 0.0, y: 10.0), size: CGSize(width: layout.size.width, height: 44.0)))
            transition.updateFrame(node: self.optionsButton, frame: CGRect(origin: CGPoint(x: 20.0, y: 18.0), size: CGSize(width: 28.0, height: 28.0)))
            transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: layout.size.width - 20.0 - 28.0, y: 18.0), size: CGSize(width: 28.0, height: 28.0)))
            
            transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            let contentHeight: CGFloat = layout.size.height - 240.0
            
            transition.updateFrame(node: self.contentContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - contentHeight), size: CGSize(width: layout.size.width, height: contentHeight + 1000.0)))
            
            let bottomAreaHeight: CGFloat = 290.0
            let listOrigin = CGPoint(x: 16.0, y: 64.0)
            
            var listHeight: CGFloat = 44.0 + 56.0
            if let maxListHeight = self.maxListHeight {
                listHeight = min(max(1.0, contentHeight - bottomAreaHeight - listOrigin.y - layout.intrinsicInsets.bottom + 25.0), maxListHeight + 44.0)
            }
            
            let listFrame = CGRect(origin: listOrigin, size: CGSize(width: layout.size.width - 16.0 * 2.0, height: listHeight))
            transition.updateFrame(node: self.listNode, frame: listFrame)
            
            let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listFrame.size, insets: UIEdgeInsets(top: -1.0, left: -6.0, bottom: -1.0, right: -6.0), scrollIndicatorInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0), duration: duration, curve: curve)
            
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            
            let sideButtonSize = CGSize(width: 60.0, height: 60.0)
            let centralButtonSize = CGSize(width: 370.0, height: 370.0)
                        
            let actionButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - centralButtonSize.width) / 2.0), y: contentHeight - bottomAreaHeight - layout.intrinsicInsets.bottom + floorToScreenPixels((bottomAreaHeight - centralButtonSize.height) / 2.0)), size: centralButtonSize)
            
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
                    audioButtonAppearance = .color(.custom(0x1c1c1e))
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
            self.actionButton.update(size: centralButtonSize, buttonSize: CGSize(width: 144.0, height: 144.0), state: actionButtonState, title: actionButtonTitle, subtitle: actionButtonSubtitle, small: layout.size.width < 330.0, animated: true)
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
            
            self.leaveNode.update(size: sideButtonSize, content: CallControllerButtonItemNode.Content(appearance: .color(.custom(0x4d120e)), image: .end), text: self.presentationData.strings.VoiceChat_Leave, transition: .immediate)
            
            let sideButtonMinimalInset: CGFloat = 16.0
            let sideButtonOffset = min(36.0, floor((((layout.size.width - 144.0) / 2.0) - sideButtonSize.width) / 2.0))
            let sideButtonOrigin = max(sideButtonMinimalInset, floor((layout.size.width - 144.0) / 2.0) - sideButtonOffset - sideButtonSize.width)
            
            transition.updateFrame(node: self.audioOutputNode, frame: CGRect(origin: CGPoint(x: sideButtonOrigin, y: contentHeight - bottomAreaHeight - layout.intrinsicInsets.bottom + floor((bottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize))
            transition.updateFrame(node: self.leaveNode, frame: CGRect(origin: CGPoint(x: layout.size.width - sideButtonOrigin - sideButtonSize.width, y: contentHeight - bottomAreaHeight - layout.intrinsicInsets.bottom + floor((bottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize))
            
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
            
            self.isHidden = false
            
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
            
            let offset: CGFloat = layout.size.height - 240.0
            self.contentContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true, completion: { _ in
            })
        }
        
        func animateOut(completion: (() -> Void)?) {
            guard let (layout, _) = self.validLayout else {
                return
            }
            
            var dimCompleted = false
            var offsetCompleted = false
            
            let internalCompletion: () -> Void = { [weak self] in
                if dimCompleted && offsetCompleted {
                    if let strongSelf = self {
                        strongSelf.dimNode.layer.removeAllAnimations()
                        strongSelf.contentContainer.layer.removeAllAnimations()
                    }
                    completion?()
                }
            }
            
            self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                dimCompleted = true
                internalCompletion()
            })
            
            let offset: CGFloat = layout.size.height - 240.0
            self.contentContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { _ in
                offsetCompleted = true
                internalCompletion()
            })
        }
        
        private func enqueueTransition(_ transition: ListTransition) {
            self.enqueuedTransitions.append(transition)
            
            if let _ = self.validLayout {
                while !self.enqueuedTransitions.isEmpty {
                    self.dequeueTransition()
                }
            }
        }
        
        private func dequeueTransition() {
            guard let _ = self.validLayout, let transition = self.enqueuedTransitions.first else {
                return
            }
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if transition.crossFade {
                options.insert(.AnimateCrossfade)
            }
            options.insert(.LowLatency)
            options.insert(.PreferSynchronousResourceLoading)
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                if !strongSelf.didSetContentsReady {
                    strongSelf.didSetContentsReady = true
                    strongSelf.controller?.contentsReady.set(true)
                }
                
                if !transition.deletions.isEmpty || !transition.insertions.isEmpty {
                    var itemHeight: CGFloat = 56.0
                    strongSelf.listNode.forEachVisibleItemNode { node in
                        if node.frame.height > 0 {
                            itemHeight = node.frame.height
                        }
                    }
                    strongSelf.maxListHeight = CGFloat(transition.count - 1) * itemHeight
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
                    }
                }
            })
        }
        
        private func updateMembers(muteState: GroupCallParticipantsContext.Participant.MuteState?, groupMembers: [RenderedChannelParticipant], callMembers: [GroupCallParticipantsContext.Participant], speakingPeers: Set<PeerId>) {
            var sortedCallMembers = callMembers
            sortedCallMembers.sort()
            
            /*for i in 0 ..< sortedCallMembers.count {
                if sortedCallMembers[i].peer.id == self.context.account.peerId {
                    let member = sortedCallMembers[i]
                    sortedCallMembers.remove(at: i)
                    sortedCallMembers.insert(member, at: 0)
                    break
                }
            }*/
            
            //assert(sortedCallMembers == callMembers)
            
            self.currentGroupMembers = groupMembers
            self.currentCallMembers = callMembers
            self.currentSpeakingPeers = speakingPeers
            
            let previousEntries = self.currentEntries
            var entries: [ListEntry] = []
            
            var index: Int32 = 0
            
            var processedPeerIds = Set<PeerId>()
            
            entries.append(.invite(self.presentationData.theme, self.presentationData.strings, "Invite Member"))

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
            
            if callMembers.isEmpty, let accountPeer = self.accountPeer {
                entries.append(.peer(PeerEntry(
                    peer: accountPeer,
                    presence: nil,
                    activityTimestamp: Int32.max - 1 - index,
                    state: .listening,
                    muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: true),
                    canManageCall: callState?.canManageCall ?? false
                )))
            }
            
            self.currentEntries = entries
            
            let presentationData = self.presentationData.withUpdated(theme: self.darkTheme)
            let transition = preparedTransition(from: previousEntries, to: entries, isLoading: false, isEmpty: false, crossFade: false, context: self.context, presentationData: presentationData, interaction: self.itemInteraction!)
            self.enqueueTransition(transition)
        }
        
        @objc private func panGesture(_ recognizer: CallPanGestureRecognizer) {
            switch recognizer.state {
                case .began:
                    self.contentContainer.clipsToBounds = true
                case .changed:
                    let offset = recognizer.translation(in: self.view).y
                    var bounds = self.contentContainer.bounds
                    bounds.origin.y = -offset
                    self.contentContainer.bounds = bounds
                case .cancelled, .ended:
                    let velocity = recognizer.velocity(in: self.view).y
                    if velocity < 200.0 {
                        var bounds = self.contentContainer.bounds
                        let previous = bounds
                        bounds.origin = CGPoint()
                        self.contentContainer.bounds = bounds
                        self.contentContainer.layer.animateBounds(from: previous, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    } else {
                        var bounds = self.contentContainer.bounds
                        let previous = bounds
                        bounds.origin = CGPoint(x: 0.0, y: velocity > 0.0 ? -bounds.height: bounds.height)
                        self.contentContainer.bounds = bounds
                        self.contentContainer.layer.animateBounds(from: previous, to: bounds, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, completion: { [weak self] _ in
                            self?.controller?.dismissInteractively()
                            var initialBounds = bounds
                            initialBounds.origin = CGPoint()
                            self?.contentContainer.bounds = initialBounds
                        })
                    }
                default:
                    break
            }
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
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.idleTimerExtensionDisposable.set(nil)
    }
    
    func dismissInteractively(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            self.didAppearOnce = false
            
            completion?()
            self.presentingViewController?.dismiss(animated: false)
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            self.didAppearOnce = false
            
            self.controllerNode.animateOut(completion: { [weak self] in
                completion?()
                self?.presentingViewController?.dismiss(animated: false)
            })
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
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.keepInPlace = keepInPlace
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
