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
    private final class Node: ViewControllerTracingNode {
        private struct ListTransition {
            let deletions: [ListViewDeleteItem]
            let insertions: [ListViewInsertItem]
            let updates: [ListViewUpdateItem]
            let isLoading: Bool
            let isEmpty: Bool
            let crossFade: Bool
            let count: Int
        }
        
        private final class Interaction {
            let updateIsMuted: (PeerId, Bool) -> Void
            let invitePeer: (Peer) -> Void
            let peerContextAction: (PeerEntry, ASDisplayNode, ContextGesture?) -> Void
            
            private var audioLevels: [PeerId: ValuePipe<Float>] = [:]
            
            init(
                updateIsMuted: @escaping (PeerId, Bool) -> Void,
                invitePeer: @escaping (Peer) -> Void,
                peerContextAction: @escaping (PeerEntry, ASDisplayNode, ContextGesture?) -> Void
            ) {
                self.updateIsMuted = updateIsMuted
                self.invitePeer = invitePeer
                self.peerContextAction = peerContextAction
            }
            
            func getAudioLevel(_ peerId: PeerId) -> Signal<Float, NoError>? {
                if let current = self.audioLevels[peerId] {
                    return current.signal()
                } else {
                    let value = ValuePipe<Float>()
                    self.audioLevels[peerId] = value
                    return value.signal()
                }
            }
            
            func updateAudioLevels(_ levels: [(PeerId, Float)]) {
                for (peerId, level) in levels {
                    if let pipe = self.audioLevels[peerId] {
                        pipe.putNext(level)
                    }
                }
            }
        }
        
        private struct PeerEntry: Comparable, Identifiable {
            enum State {
                case inactive
                case listening
                case speaking
            }
            
            var peer: Peer
            var presence: TelegramUserPresence?
            var activityTimestamp: Int32
            var state: State
            var muteState: GroupCallParticipantsContext.Participant.MuteState?
            var invited: Bool
            
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
                if lhs.invited != rhs.invited {
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
            
            func item(context: AccountContext, presentationData: PresentationData, interaction: Interaction) -> ListViewItem {
                let peer = self.peer
                
                let text: VoiceChatParticipantItem.ParticipantText
                let icon: VoiceChatParticipantItem.Icon
                switch self.state {
                case .inactive:
                    text = .presence
                    icon = .invite(self.invited)
                case .listening:
                    text = .text(presentationData.strings.VoiceChat_StatusListening, .accent)
                    let microphoneColor: UIColor
                    if let muteState = self.muteState, !muteState.canUnmute {
                        microphoneColor = UIColor(rgb: 0xff3b30)
                    } else {
                        microphoneColor = UIColor(rgb: 0x979797)
                    }
                    icon = .microphone(true, microphoneColor)
                case .speaking:
                    text = .text(presentationData.strings.VoiceChat_StatusSpeaking, .constructive)
                    icon = .microphone(false, UIColor(rgb: 0x34c759))
                }
                
                return VoiceChatParticipantItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: context, peer: peer, presence: self.presence, text: text, icon: icon, enabled: true, audioLevel: interaction.getAudioLevel(peer.id), action: {
                    interaction.invitePeer(peer)
                }, contextAction: { node, gesture in
                    interaction.peerContextAction(self, node, gesture)
                })
            }
        }
        
        private func preparedTransition(from fromEntries: [PeerEntry], to toEntries: [PeerEntry], isLoading: Bool, isEmpty: Bool, crossFade: Bool, context: AccountContext, presentationData: PresentationData, interaction: Interaction) -> ListTransition {
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
        private let contentContainer: ASDisplayNode
        private let listNode: ListView
        private let audioOutputNode: CallControllerButtonItemNode
        private let leaveNode: CallControllerButtonItemNode
        private let actionButton: VoiceChatActionButton
        
        private var enqueuedTransitions: [ListTransition] = []
        private var maxListHeight: CGFloat?
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        private var didSetContentsReady: Bool = false
        private var didSetDataReady: Bool = false
        
        private var currentMembers: [RenderedChannelParticipant]?
        private var currentMemberStates: [PeerId: PresentationGroupCallMemberState]?
        private var currentInvitedPeers: Set<PeerId>?
        
        private var currentEntries: [PeerEntry] = []
        private var peersDisposable: Disposable?
        
        private var peerViewDisposable: Disposable?
        private let leaveDisposable = MetaDisposable()
        
        private var isMutedDisposable: Disposable?
        private var callStateDisposable: Disposable?
        
        private var pushingToTalk = false
        
        private var callState: PresentationGroupCallState?
        
        private var audioOutputStateDisposable: Disposable?
        private var audioOutputState: ([AudioSessionOutput], AudioSessionOutput?)?
        
        private var audioLevelsDisposable: Disposable?
        private var myAudioLevelDisposable: Disposable?
        private var memberStatesDisposable: Disposable?
        private var invitedPeersDisposable: Disposable?
        
        private var itemInteraction: Interaction?
        
        init(controller: VoiceChatController, sharedContext: SharedAccountContext, call: PresentationGroupCall) {
            self.controller = controller
            self.sharedContext = sharedContext
            self.context = call.accountContext
            self.call = call
            
            self.presentationData = sharedContext.currentPresentationData.with { $0 }
            self.darkTheme = defaultDarkColorPresentationTheme
            
            self.optionsButton = VoiceChatOptionsButton()
            
            self.contentContainer = ASDisplayNode()
            self.contentContainer.backgroundColor = .black
            
            self.listNode = ListView()
            self.listNode.backgroundColor = self.darkTheme.list.itemBlocksBackgroundColor
            self.listNode.verticalScrollIndicatorColor = UIColor(white: 1.0, alpha: 0.3)
            self.listNode.clipsToBounds = true
            self.listNode.cornerRadius = 16.0
            
            self.audioOutputNode = CallControllerButtonItemNode()
            self.leaveNode = CallControllerButtonItemNode()
            self.actionButton = VoiceChatActionButton()
                        
            super.init()
            
            let invitePeer: (Peer) -> Void = { [weak self] peer in
                guard let strongSelf = self else {
                    return
                }
                
                if let invitedPeers = strongSelf.currentInvitedPeers, invitedPeers.contains(peer.id) {
                    return
                }
                
                strongSelf.controller?.present(
                    UndoOverlayController(
                        presentationData: strongSelf.presentationData,
                        content: .invitedToVoiceChat(
                            context: strongSelf.context,
                            peer: peer,
                            text: strongSelf.presentationData.strings.VoiceChat_UserInvited(peer.compactDisplayTitle).0
                        ),
                        elevatedLayout: false,
                        action: { action in
                            return true
                        }
                    ),
                    in: .current
                )
                strongSelf.call.invitePeer(peer.id)
            }
            
            self.itemInteraction = Interaction(
                updateIsMuted: { [weak self] peerId, isMuted in
                    self?.call.updateMuteState(peerId: peerId, isMuted: isMuted)
            }, invitePeer: { peer in
                invitePeer(peer)
            }, peerContextAction: { [weak self] entry, sourceNode, gesture in
                guard let strongSelf = self, let controller = strongSelf.controller, let sourceNode = sourceNode as? ContextExtractedContentContainingNode else {
                    return
                }
                
                let peer = entry.peer
   
                var items: [ContextMenuItem] = []
                switch entry.state {
                case .inactive:
                    if let invitedPeers = strongSelf.currentInvitedPeers, invitedPeers.contains(peer.id) {
                    } else {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_InvitePeer, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            invitePeer(peer)
                            f(.default)
                        })))
                    }
                default:
                    if entry.muteState == nil {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_MutePeer, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.call.updateMuteState(peerId: peer.id, isMuted: true)
                            f(.default)
                        })))
                    } else {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_UnmutePeer, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Unmute"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.call.updateMuteState(peerId: peer.id, isMuted: false)
                            f(.default)
                        })))
                    }
                    
                    if peer.id != strongSelf.context.account.peerId {
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
            })
            
            self.contentContainer.addSubnode(self.listNode)
            self.contentContainer.addSubnode(self.audioOutputNode)
            self.contentContainer.addSubnode(self.leaveNode)
            self.contentContainer.addSubnode(self.actionButton)
            
            self.addSubnode(self.contentContainer)
            
            let (disposable, loadMoreControl) = self.context.peerChannelMemberCategoriesContextsManager.recent(postbox: self.context.account.postbox, network: self.context.account.network, accountPeerId: self.context.account.peerId, peerId: self.call.peerId, updated: { [weak self] state in
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateMembers(isMuted: strongSelf.callState?.isMuted ?? true, members: state.list, memberStates: strongSelf.currentMemberStates ?? [:], invitedPeers: strongSelf.currentInvitedPeers ?? Set())
                }
            })
            
            self.memberStatesDisposable = (self.call.members
            |> deliverOnMainQueue).start(next: { [weak self] memberStates in
                guard let strongSelf = self else {
                    return
                }
                if let members = strongSelf.currentMembers {
                    strongSelf.updateMembers(isMuted: strongSelf.callState?.isMuted ?? true, members: members, memberStates: memberStates, invitedPeers: strongSelf.currentInvitedPeers ?? Set())
                } else {
                    strongSelf.currentMemberStates = memberStates
                }
            })
            
            self.invitedPeersDisposable = (self.call.invitedPeers
            |> deliverOnMainQueue).start(next: { [weak self] invitedPeers in
                guard let strongSelf = self else {
                    return
                }
                if let members = strongSelf.currentMembers {
                    strongSelf.updateMembers(isMuted: strongSelf.callState?.isMuted ?? true, members: members, memberStates: strongSelf.currentMemberStates ?? [:], invitedPeers: invitedPeers)
                } else {
                    strongSelf.currentInvitedPeers = invitedPeers
                }
            })
            
            self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
                guard let strongSelf = self else {
                    return
                }
                if case let .known(value) = offset, value < 40.0 {
                    strongSelf.context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: strongSelf.call.peerId, control: loadMoreControl)
                }
            }
            
            self.peersDisposable = disposable
            
            self.peerViewDisposable = (self.context.account.viewTracker.peerView(self.call.peerId)
            |> deliverOnMainQueue).start(next: { [weak self] view in
                guard let strongSelf = self else {
                    return
                }
                
                guard let peer = view.peers[view.peerId] else {
                    return
                }
                //TODO:localize
                var subtitle = "group"
                if let cachedData = view.cachedData as? CachedChannelData {
                    if let memberCount = cachedData.participantsSummary.memberCount {
                        subtitle = strongSelf.presentationData.strings.Conversation_StatusMembers(memberCount)
                    }
                }
                
                let titleView = VoiceChatControllerTitleView(theme: strongSelf.presentationData.theme)
                titleView.set(title: "Voice Chat", subtitle: subtitle)
                strongSelf.controller?.navigationItem.titleView = titleView
                
                if !strongSelf.didSetDataReady {
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
                    let wasMuted = strongSelf.callState?.isMuted ?? true
                    strongSelf.callState = state
                    
                    if wasMuted != state.isMuted, let members = strongSelf.currentMembers {
                        strongSelf.updateMembers(isMuted: state.isMuted, members: members, memberStates: strongSelf.currentMemberStates ?? [:], invitedPeers: strongSelf.currentInvitedPeers ?? Set())
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
                if let state = strongSelf.callState, !state.isMuted {
                    effectiveLevel = level
                }
                strongSelf.itemInteraction?.updateAudioLevels([(strongSelf.context.account.peerId, effectiveLevel)])
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
                /*items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_SpeakPermissionEveryone, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                  
                })))
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_SpeakPermissionAdmin, icon: { _ in return nil}, action: { _, f in
                    f(.dismissWithoutContent)
                  
                })))
                items.append(.separator)*/
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_Share, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                  
                    if let strongSelf = self {
                        let shareController = ShareController(context: strongSelf.context, subject: .url("url"), forcedTheme: strongSelf.darkTheme, forcedActionTitle: strongSelf.presentationData.strings.VoiceChat_CopyInviteLink)
                        strongSelf.controller?.present(shareController, in: .window(.root))
                    }
                })))
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_EndVoiceChat, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                })))
            
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme), source: .extracted(VoiceChatContextExtractedContentSource(controller: controller, sourceNode: strongOptionsButton.extractedContainerNode, keepInPlace: true)), items: .single(items), reactionItems: [], gesture: gesture)
                strongSelf.controller?.presentInGlobalOverlay(contextController)
            }
            let optionsButtonItem = UIBarButtonItem(customDisplayNode: self.optionsButton)!
            optionsButtonItem.target = self
            optionsButtonItem.action = #selector(self.rightNavigationButtonAction)
            self.controller?.navigationItem.setRightBarButton(optionsButtonItem, animated: false)
        }
        
        deinit {
            self.peersDisposable?.dispose()
            self.peerViewDisposable?.dispose()
            self.leaveDisposable.dispose()
            self.isMutedDisposable?.dispose()
            self.callStateDisposable?.dispose()
            self.audioOutputStateDisposable?.dispose()
            self.memberStatesDisposable?.dispose()
            self.invitedPeersDisposable?.dispose()
            self.audioLevelsDisposable?.dispose()
            self.myAudioLevelDisposable?.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            let longTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.actionButtonPressGesture(_:)))
            longTapRecognizer.minimumPressDuration = 0.1
            self.actionButton.view.addGestureRecognizer(longTapRecognizer)
            
            let panRecognizer = CallPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.shouldBegin = { [weak self] _ in
                guard let strongSelf = self else {
                    return false
                }
                return true
            }
            self.view.addGestureRecognizer(panRecognizer)
        }
        
        @objc private func rightNavigationButtonAction() {
            self.optionsButton.contextAction?(self.optionsButton.containerNode, nil)
        }
        
        @objc private func leavePressed() {
            self.leaveDisposable.set((self.call.leave()
            |> deliverOnMainQueue).start(completed: { [weak self] in
                self?.controller?.dismiss()
            }))
        }
        
        @objc private func actionButtonPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
            switch gestureRecognizer.state {
                case .began:
                    self.pushingToTalk = true
                    self.actionButton.pressing = true
                    self.call.setIsMuted(false)
                case .ended, .cancelled:
                    self.pushingToTalk = false
                    self.actionButton.pressing = false
                    self.call.setIsMuted(true)
                default:
                    break
            }
        }
        
        @objc private func actionButtonPressed() {
            self.call.toggleIsMuted()
        }
        
        @objc private func audioOutputPressed() {
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
            
            transition.updateFrame(node: self.contentContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            let bottomAreaHeight: CGFloat = 290.0
            
            let listOrigin = CGPoint(x: 16.0, y: navigationHeight + 10.0)
            
            var listHeight: CGFloat = 56.0
            if let maxListHeight = self.maxListHeight {
                listHeight = min(max(1.0, layout.size.height - bottomAreaHeight - listOrigin.y - layout.intrinsicInsets.bottom + 25.0), maxListHeight)
            }
            
            let listFrame = CGRect(origin: listOrigin, size: CGSize(width: layout.size.width - 16.0 * 2.0, height: listHeight))
            transition.updateFrame(node: self.listNode, frame: listFrame)
            
            let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listFrame.size, insets: UIEdgeInsets(top: -1.0, left: -6.0, bottom: -1.0, right: -6.0), scrollIndicatorInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0), duration: duration, curve: curve)
            
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            
            let sideButtonSize = CGSize(width: 60.0, height: 60.0)
            let centralButtonSize = CGSize(width: 244.0, height: 244.0)
            let sideButtonInset: CGFloat = 27.0
            
            let actionButtonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - centralButtonSize.width) / 2.0), y: layout.size.height - bottomAreaHeight - layout.intrinsicInsets.bottom + floor((bottomAreaHeight - centralButtonSize.height) / 2.0)), size: centralButtonSize)
            
            var isMicOn = false
            
            let actionButtonState: VoiceChatActionButtonState
            let actionButtonTitle: String
            let actionButtonSubtitle: String
            let audioButtonAppearance: CallControllerButtonItemNode.Content.Appearance
            var actionButtonEnabled = true
            if let callState = callState {
                isMicOn = !callState.isMuted
                
                switch callState.networkState {
                case .connecting:
                    actionButtonState = .connecting
                    actionButtonTitle = self.presentationData.strings.VoiceChat_Connecting
                    actionButtonSubtitle = ""
                    audioButtonAppearance = .color(.custom(0x1c1c1e))
                    actionButtonEnabled = false
                case .connected:
                    actionButtonState = .active(state: isMicOn ? .on : .muted)
                    if isMicOn {
                        actionButtonTitle = self.pushingToTalk ? self.presentationData.strings.VoiceChat_Live : self.presentationData.strings.VoiceChat_Mute
                        actionButtonSubtitle = ""
                        audioButtonAppearance = .color(.custom(0x005720))
                    } else {
                        actionButtonTitle = self.presentationData.strings.VoiceChat_Unmute
                        actionButtonSubtitle = self.presentationData.strings.VoiceChat_UnmuteHelp
                        audioButtonAppearance = .color(.custom(0x00274d))
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
            self.actionButton.update(size: centralButtonSize, buttonSize: CGSize(width: 144.0, height: 144.0), state: actionButtonState, title: actionButtonTitle, subtitle: actionButtonSubtitle, animated: true)
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
            
            self.audioOutputNode.update(size: sideButtonSize, content: CallControllerButtonItemNode.Content(appearance: soundAppearance, image: soundImage), text: self.presentationData.strings.VoiceChat_Audio, transition: .animated(duration: 0.4, curve: .linear))
            
            self.leaveNode.update(size: sideButtonSize, content: CallControllerButtonItemNode.Content(appearance: .color(.custom(0x4d120e)), image: .end), text: self.presentationData.strings.VoiceChat_Leave, transition: .immediate)
            
            transition.updateFrame(node: self.audioOutputNode, frame: CGRect(origin: CGPoint(x: sideButtonInset, y: layout.size.height - bottomAreaHeight - layout.intrinsicInsets.bottom + floor((bottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize))
            transition.updateFrame(node: self.leaveNode, frame: CGRect(origin: CGPoint(x: layout.size.width - sideButtonInset - sideButtonSize.width, y: layout.size.height - bottomAreaHeight - layout.intrinsicInsets.bottom + floor((bottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize))
            
            if isFirstTime {
                while !self.enqueuedTransitions.isEmpty {
                    self.dequeueTransition()
                }
            }
        }
        
        func animateIn() {
            self.alpha = 1.0
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            
            self.listNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        
            self.actionButton.layer.animateScale(from: 0.1, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            
            self.audioOutputNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            self.leaveNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            
            self.actionButton.titleLabel.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
            self.actionButton.subtitleLabel.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
            self.audioOutputNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
            self.leaveNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
            
            self.contentContainer.layer.animateBoundsOriginYAdditive(from: 80.0, to: 0.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
        func animateOut(completion: (() -> Void)?) {
            self.alpha = 0.0
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { _ in
                completion?()
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
                    strongSelf.maxListHeight = CGFloat(transition.count) * itemHeight
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
                    }
                }
            })
        }
        
        private func updateMembers(isMuted: Bool, members: [RenderedChannelParticipant], memberStates: [PeerId: PresentationGroupCallMemberState], invitedPeers: Set<PeerId>) {
            var members = members
            members.sort(by: { lhs, rhs in
                if lhs.peer.id == self.context.account.peerId {
                    return true
                } else if rhs.peer.id == self.context.account.peerId {
                    return false
                }
                let lhsHasState = memberStates[lhs.peer.id] != nil
                let rhsHasState = memberStates[rhs.peer.id] != nil
                if lhsHasState != rhsHasState {
                    if lhsHasState {
                        return true
                    } else {
                        return false
                    }
                }
                return lhs.peer.id < rhs.peer.id
            })
            
            self.currentMembers = members
            self.currentMemberStates = memberStates
            self.currentInvitedPeers = invitedPeers
            
            let previousEntries = self.currentEntries
            var entries: [PeerEntry] = []
            
            var index: Int32 = 0
            
            for member in members {
                if let user = member.peer as? TelegramUser, user.botInfo != nil || user.isDeleted {
                    continue
                }
                
                let memberState: PeerEntry.State
                var memberMuteState: GroupCallParticipantsContext.Participant.MuteState?
                if member.peer.id == self.context.account.peerId {
                    if !isMuted {
                        memberState = .speaking
                    } else {
                        memberState = .listening
                    }
                } else if let state = memberStates[member.peer.id] {
                    memberState = .listening
                    memberMuteState = state.muteState
                } else {
                    memberState = .inactive
                }
                
                entries.append(PeerEntry(
                    peer: member.peer,
                    presence: member.presences[member.peer.id] as? TelegramUserPresence,
                    activityTimestamp: Int32.max - 1 - index,
                    state: memberState,
                    muteState: memberMuteState,
                    invited: invitedPeers.contains(member.peer.id)
                ))
                index += 1
            }
            
            self.currentEntries = entries
            
            let presentationData = self.presentationData.withUpdated(theme: self.darkTheme)
            let transition = preparedTransition(from: previousEntries, to: entries, isLoading: false, isEmpty: false, crossFade: false, context: self.context, presentationData: presentationData, interaction: self.itemInteraction!)
            self.enqueueTransition(transition)
        }
        
        @objc private func panGesture(_ recognizer: CallPanGestureRecognizer) {
            switch recognizer.state {
                case .began:
                    guard let (layout, _) = self.validLayout else {
                        return
                    }
                    self.contentContainer.clipsToBounds = true
                    self.contentContainer.cornerRadius = layout.deviceMetrics.screenCornerRadius
                case .changed:
                    let offset = recognizer.translation(in: self.view).y
                    var bounds = self.bounds
                    bounds.origin.y = -offset
                    
                    let transition = offset / bounds.height
                    if transition > 0.02 {
                        self.controller?.statusBar.statusBarStyle = .Ignore
                    } else {
                        self.controller?.statusBar.statusBarStyle = .White
                    }
                    self.bounds = bounds
                case .cancelled, .ended:
                    let velocity = recognizer.velocity(in: self.view).y
                    if abs(velocity) < 200.0 {
                        var bounds = self.bounds
                        let previous = bounds
                        bounds.origin = CGPoint()
                        self.bounds = bounds
                        self.layer.animateBounds(from: previous, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
                            self.contentContainer.cornerRadius = 0.0
                        })
                        self.controller?.statusBar.statusBarStyle = .White
                    } else {
                        var bounds = self.bounds
                        let previous = bounds
                        bounds.origin = CGPoint(x: 0.0, y: velocity > 0.0 ? -bounds.height: bounds.height)
                        self.bounds = bounds
                        self.layer.animateBounds(from: previous, to: bounds, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, completion: { [weak self] _ in
                            self?.controller?.dismissInteractively()
                            var initialBounds = bounds
                            initialBounds.origin = CGPoint()
                            self?.bounds = initialBounds
                            self?.controller?.statusBar.statusBarStyle = .White
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
    
    public init(sharedContext: SharedAccountContext, accountContext: AccountContext, call: PresentationGroupCall) {
        self.sharedContext = sharedContext
        self.call = call
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
        let darkNavigationTheme = NavigationBarTheme(buttonColor: .white, disabledButtonColor: UIColor(rgb: 0x525252), primaryTextColor: .white, backgroundColor: .clear, separatorColor: UIColor(white: 0.0, alpha: 0.8), badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
         
        let backItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.VoiceChat_BackTitle, target: self, action: #selector(self.closePressed))
        self.navigationItem.leftBarButtonItem = backItem
        
        self.statusBar.statusBarStyle = .White
        
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
    
    @objc private func closePressed() {
        self.dismiss()
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
        }
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
