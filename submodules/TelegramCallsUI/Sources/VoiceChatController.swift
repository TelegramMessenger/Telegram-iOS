import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
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
import AvatarNode
import TooltipUI
import LegacyUI
import LegacyComponents
import LegacyMediaPickerUI
import WebSearchUI
import MapResourceToAvatarSizes
import SolidRoundedButtonNode

private let panelBackgroundColor = UIColor(rgb: 0x1c1c1e)
private let secondaryPanelBackgroundColor = UIColor(rgb: 0x2c2c2e)
private let fullscreenBackgroundColor = UIColor(rgb: 0x000000)
private let dimColor = UIColor(white: 0.0, alpha: 0.5)
private let smallButtonSize = CGSize(width: 36.0, height: 36.0)
private let sideButtonSize = CGSize(width: 56.0, height: 56.0)
private let bottomAreaHeight: CGFloat = 205.0
private let fullscreenBottomAreaHeight: CGFloat = 80.0

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

final class GroupVideoNode: ASDisplayNode {
    private let videoViewContainer: UIView
    private let videoView: PresentationCallVideoView
    
    private var validLayout: CGSize?
    
    var tapped: (() -> Void)?
    
    init(videoView: PresentationCallVideoView) {
        self.videoViewContainer = UIView()
        self.videoView = videoView
        
        super.init()
        
        self.videoViewContainer.addSubview(self.videoView.view)
        self.view.addSubview(self.videoViewContainer)
        
        self.clipsToBounds = true
        
        videoView.setOnFirstFrameReceived({ [weak self] _ in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let size = strongSelf.validLayout {
                    strongSelf.updateLayout(size: size, transition: .immediate)
                }
            }
        })
        
        videoView.setOnOrientationUpdated({ [weak self] _, _ in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let size = strongSelf.validLayout {
                    strongSelf.updateLayout(size: size, transition: .immediate)
                }
            }
        })
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        self.videoViewContainer.frame = CGRect(origin: CGPoint(), size: size)
        
        let orientation = self.videoView.getOrientation()
        var aspect = self.videoView.getAspect()
        if aspect <= 0.01 {
            aspect = 3.0 / 4.0
        }
        
        let rotatedAspect: CGFloat
        let angle: CGFloat
        let switchOrientation: Bool
        switch orientation {
        case .rotation0:
            angle = 0.0
            rotatedAspect = 1 / aspect
            switchOrientation = false
        case .rotation90:
            angle = CGFloat.pi / 2.0
            rotatedAspect = aspect
            switchOrientation = true
        case .rotation180:
            angle = CGFloat.pi
            rotatedAspect = 1 / aspect
            switchOrientation = false
        case .rotation270:
            angle = CGFloat.pi * 3.0 / 2.0
            rotatedAspect = aspect
            switchOrientation = true
        }
        
        var rotatedVideoSize = CGSize(width: 100.0, height: rotatedAspect * 100.0)
        
        if size.width < 100.0 || true {
            rotatedVideoSize = rotatedVideoSize.aspectFilled(size)
        } else {
            rotatedVideoSize = rotatedVideoSize.aspectFitted(size)
        }
        
        if switchOrientation {
            rotatedVideoSize = CGSize(width: rotatedVideoSize.height, height: rotatedVideoSize.width)
        }
        var rotatedVideoFrame = CGRect(origin: CGPoint(x: floor((size.width - rotatedVideoSize.width) / 2.0), y: floor((size.height - rotatedVideoSize.height) / 2.0)), size: rotatedVideoSize)
        rotatedVideoFrame.origin.x = floor(rotatedVideoFrame.origin.x)
        rotatedVideoFrame.origin.y = floor(rotatedVideoFrame.origin.y)
        rotatedVideoFrame.size.width = ceil(rotatedVideoFrame.size.width)
        rotatedVideoFrame.size.height = ceil(rotatedVideoFrame.size.height)
        self.videoView.view.center = rotatedVideoFrame.center
        self.videoView.view.bounds = CGRect(origin: CGPoint(), size: rotatedVideoFrame.size)
        
        let transition: ContainedViewLayoutTransition = .immediate
        transition.updateTransformRotation(view: self.videoView.view, angle: angle)
    }
}

private final class MainVideoContainerNode: ASDisplayNode {
    private let context: AccountContext
    private let call: PresentationGroupCall
    
    private var currentVideoNode: GroupVideoNode?
    private var candidateVideoNode: GroupVideoNode?
    private var currentPeer: (PeerId, UInt32)?
    
    private var validLayout: CGSize?
    
    init(context: AccountContext, call: PresentationGroupCall) {
        self.context = context
        self.call = call
        
        super.init()
        
        self.backgroundColor = .black
    }
    
    func updatePeer(peer: (peerId: PeerId, source: UInt32)?, waitForFullSize: Bool) {
        if self.currentPeer?.0 == peer?.0 && self.currentPeer?.1 == peer?.1 {
            return
        }
        self.currentPeer = peer
        if let (_, source) = peer {
            self.call.makeIncomingVideoView(source: source, completion: { [weak self] videoView in
                Queue.mainQueue().async {
                    guard let strongSelf = self, let videoView = videoView else {
                        return
                    }

                    if waitForFullSize {
                        let candidateVideoNode = GroupVideoNode(videoView: videoView)
                        strongSelf.candidateVideoNode = candidateVideoNode

                        Queue.mainQueue().after(0.3, { [weak candidateVideoNode] in
                            guard let strongSelf = self, let videoNode = candidateVideoNode, videoNode === strongSelf.candidateVideoNode else {
                                return
                            }

                            if let currentVideoNode = strongSelf.currentVideoNode {
                                currentVideoNode.removeFromSupernode()
                                strongSelf.currentVideoNode = nil
                            }
                            strongSelf.currentVideoNode = videoNode
                            strongSelf.addSubnode(videoNode)
                            if let size = strongSelf.validLayout {
                                strongSelf.update(size: size, transition: .immediate)
                            }
                        })
                    } else {
                        strongSelf.candidateVideoNode = nil

                        let videoNode = GroupVideoNode(videoView: videoView)

                        if let currentVideoNode = strongSelf.currentVideoNode {
                            currentVideoNode.removeFromSupernode()
                            strongSelf.currentVideoNode = nil
                        }
                        strongSelf.currentVideoNode = videoNode
                        strongSelf.addSubnode(videoNode)
                        if let size = strongSelf.validLayout {
                            strongSelf.update(size: size, transition: .immediate)
                        }
                    }
                }
            })
        } else {
            if let currentVideoNode = self.currentVideoNode {
                currentVideoNode.removeFromSupernode()
                self.currentVideoNode = nil
            }
        }
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        if let currentVideoNode = self.currentVideoNode {
            transition.updateFrame(node: currentVideoNode, frame: CGRect(origin: CGPoint(), size: size))
            currentVideoNode.updateLayout(size: size, transition: .immediate)
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
            let canInvite: Bool
            let crossFade: Bool
            let count: Int
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
            let getPeerVideo: (UInt32) -> GroupVideoNode?
            var isExpanded: Bool = false
            
            private var audioLevels: [PeerId: ValuePipe<Float>] = [:]
            
            var updateAvatarPromise = Promise<(TelegramMediaImageRepresentation, Float)?>(nil)
            
            init(
                updateIsMuted: @escaping (PeerId, Bool) -> Void,
                openPeer: @escaping (PeerId) -> Void,
                openInvite: @escaping () -> Void,
                peerContextAction: @escaping (PeerEntry, ASDisplayNode, ContextGesture?) -> Void,
                setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void,
                getPeerVideo: @escaping (UInt32) -> GroupVideoNode?
            ) {
                self.updateIsMuted = updateIsMuted
                self.openPeer = openPeer
                self.openInvite = openInvite
                self.peerContextAction = peerContextAction
                self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
                self.getPeerVideo = getPeerVideo
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
            
            func updateAudioLevels(_ levels: [(PeerId, UInt32, Float, Bool)], reset: Bool = false) {
                var updated = Set<PeerId>()
                for (peerId, _, level, _) in levels {
                    if let pipe = self.audioLevels[peerId] {
                        if reset {
                            pipe.putNext(level)
                        } else {
                            pipe.putNext(max(0.001, level))
                        }
                        updated.insert(peerId)
                    }
                }
                if !reset {
                    for (peerId, pipe) in self.audioLevels {
                        if !updated.contains(peerId) {
                            pipe.putNext(0.0)
                        }
                    }
                }
            }
        }
        
        private struct PeerEntry: Comparable, Identifiable {
            enum State {
                case listening
                case speaking
                case invited
                case raisedHand
            }
            
            var peer: Peer
            var about: String?
            var isMyPeer: Bool
            var ssrc: UInt32?
            var presence: TelegramUserPresence?
            var activityTimestamp: Int32
            var state: State
            var muteState: GroupCallParticipantsContext.Participant.MuteState?
            var revealed: Bool?
            var canManageCall: Bool
            var volume: Int32?
            var raisedHand: Bool
            var displayRaisedHandStatus: Bool
            
            var stableId: PeerId {
                return self.peer.id
            }
            
            static func ==(lhs: PeerEntry, rhs: PeerEntry) -> Bool {
                if !lhs.peer.isEqual(rhs.peer) {
                    return false
                }
                if lhs.about != rhs.about {
                    return false
                }
                if lhs.isMyPeer != rhs.isMyPeer {
                    return false
                }
                if lhs.ssrc != rhs.ssrc {
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
                if lhs.volume != rhs.volume {
                    return false
                }
                if lhs.raisedHand != rhs.raisedHand {
                    return false
                }
                if lhs.displayRaisedHandStatus != rhs.displayRaisedHandStatus {
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
            case invite(PresentationTheme, PresentationStrings, String, Bool)
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
                    case let .invite(lhsTheme, lhsStrings, lhsText, lhsIsLink):
                        if case let .invite(rhsTheme, rhsStrings, rhsText, rhsIsLink) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsText == rhsText, lhsIsLink == rhsIsLink {
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
                    case let .invite(_, _, text, isLink):
                        return VoiceChatActionItem(presentationData: ItemListPresentationData(presentationData), title: text, icon: .generic(UIImage(bundleImageName: isLink ? "Chat/Context Menu/Link" : "Chat/Context Menu/AddUser")!), action: {
                            interaction.openInvite()
                        })
                    case let .peer(peerEntry):
                        let peer = peerEntry.peer
                        
                        var text: VoiceChatParticipantItem.ParticipantText
                        var expandedText: VoiceChatParticipantItem.ParticipantText?
                        let icon: VoiceChatParticipantItem.Icon
                        
                        var state = peerEntry.state
                        if let muteState = peerEntry.muteState, case .speaking = state, muteState.mutedByYou || !muteState.canUnmute {
                            state = .listening
                        }
                        
                        let yourText: String
                        if (peerEntry.about?.isEmpty ?? true) && peer.smallProfileImage == nil {
                            yourText = presentationData.strings.VoiceChat_TapToAddPhotoOrBio
                        } else if peer.smallProfileImage == nil {
                            yourText = presentationData.strings.VoiceChat_TapToAddPhoto
                        } else if (peerEntry.about?.isEmpty ?? true) {
                            yourText = presentationData.strings.VoiceChat_TapToAddBio
                        } else {
                            yourText = presentationData.strings.VoiceChat_You
                        }
                        switch state {
                        case .listening:
                            if peerEntry.isMyPeer {
                                text = .text(yourText, .accent)
                            } else if let muteState = peerEntry.muteState, muteState.mutedByYou {
                                text = .text(presentationData.strings.VoiceChat_StatusMutedForYou, .destructive)
                            } else if let about = peerEntry.about, !about.isEmpty {
                                text = .text(about, .generic)
                            } else {
                                text = .text(presentationData.strings.VoiceChat_StatusListening, .generic)
                            }
                            let microphoneColor: UIColor
                            if let muteState = peerEntry.muteState, !muteState.canUnmute || muteState.mutedByYou {
                                microphoneColor = UIColor(rgb: 0xff3b30)
                            } else {
                                microphoneColor = UIColor(rgb: 0x979797)
                            }
                            icon = .microphone(peerEntry.muteState != nil, microphoneColor)
                        case .speaking:
                            if let muteState = peerEntry.muteState, muteState.mutedByYou {
                                text = .text(presentationData.strings.VoiceChat_StatusMutedForYou, .destructive)
                                icon = .microphone(true, UIColor(rgb: 0xff3b30))
                            } else {
                                let volumeValue = peerEntry.volume.flatMap { $0 / 100 }
                                if let volume = volumeValue, volume != 100 {
                                    text = .text( presentationData.strings.VoiceChat_StatusSpeakingVolume("\(volume)%").0, .constructive)
                                } else {
                                    text = .text(presentationData.strings.VoiceChat_StatusSpeaking, .constructive)
                                }
                                icon = .microphone(false, UIColor(rgb: 0x34c759))
                            }
                        case .invited:
                            text = .text(presentationData.strings.VoiceChat_StatusInvited, .generic)
                            icon = .invite(true)
                        case .raisedHand:
                            if peerEntry.isMyPeer && !peerEntry.displayRaisedHandStatus {
                                text = .text(yourText, .accent)
                            } else if let about = peerEntry.about, !about.isEmpty && !peerEntry.displayRaisedHandStatus {
                                text = .text(about, .generic)
                            } else {
                                text = .text(presentationData.strings.VoiceChat_StatusWantsToSpeak, .accent)
                            }
                            icon = .wantsToSpeak
                        }
                        
                        if let about = peerEntry.about, !about.isEmpty {
                            expandedText = .text(about, .generic)
                        }
                                                
                        let revealOptions: [VoiceChatParticipantItem.RevealOption] = []
                        
                        return VoiceChatParticipantItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: context, peer: peer, ssrc: peerEntry.ssrc, presence: peerEntry.presence, text: text, expandedText: expandedText, icon: icon, enabled: true, transparent: false, selectable: true, getAudioLevel: { return interaction.getAudioLevel(peer.id) }, getVideo: {
                            if let ssrc = peerEntry.ssrc {
                                return interaction.getPeerVideo(ssrc)
                            } else {
                                return nil
                            }
                        }, revealOptions: revealOptions, revealed: peerEntry.revealed, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                            interaction.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                        }, action: { node in
                            interaction.peerContextAction(peerEntry, node, nil)
                        }, contextAction: nil, getIsExpanded: {
                            return interaction.isExpanded
                        }, getUpdatingAvatar: {
                            return interaction.updateAvatarPromise.get()
                        })
                }
            }
        }
        
        private func preparedTransition(from fromEntries: [ListEntry], to toEntries: [ListEntry], isLoading: Bool, isEmpty: Bool, canInvite: Bool, crossFade: Bool, animated: Bool, context: AccountContext, presentationData: PresentationData, interaction: Interaction) -> ListTransition {
            let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
            
            let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
            let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
            let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
            
            return ListTransition(deletions: deletions, insertions: insertions, updates: updates, isLoading: isLoading, isEmpty: isEmpty, canInvite: canInvite, crossFade: crossFade, count: toEntries.count, animated: animated)
        }
        
        private let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
        
        private weak var controller: VoiceChatController?
        private let sharedContext: SharedAccountContext
        private let context: AccountContext
        private let call: PresentationGroupCall
        private var presentationData: PresentationData
        private var presentationDataDisposable: Disposable?
        private var darkTheme: PresentationTheme
        
        private let dimNode: ASDisplayNode
        private let contentContainer: ASDisplayNode
        private let backgroundNode: ASDisplayNode
        private var mainVideoContainer: MainVideoContainerNode?
        private let listNode: ListView
        private let topPanelNode: ASDisplayNode
        private let topPanelEdgeNode: ASDisplayNode
        private let topPanelBackgroundNode: ASDisplayNode
        private let optionsButton: VoiceChatHeaderButton
        private var optionsButtonIsAvatar = false
        private let closeButton: VoiceChatHeaderButton
        private let topCornersNode: ASImageNode
        fileprivate let bottomPanelNode: ASDisplayNode
        private let bottomPanelBackgroundNode: ASDisplayNode
        private let bottomCornersNode: ASImageNode
        fileprivate let audioButton: CallControllerButtonItemNode
        fileprivate let cameraButton: CallControllerButtonItemNode
        fileprivate let switchCameraButton: CallControllerButtonItemNode
        fileprivate let leaveButton: CallControllerButtonItemNode
        fileprivate let actionButton: VoiceChatActionButton
        private let leftBorderNode: ASDisplayNode
        private let rightBorderNode: ASDisplayNode
        
        private var isScheduling = false
        private let timerNode: VoiceChatTimerNode
        private var pickerView: UIDatePicker?
        private let dateFormatter: DateFormatter
        private let scheduleTextNode: ImmediateTextNode
        private let scheduleCancelButton: SolidRoundedButtonNode
        private var scheduleButtonTitle = ""
        
        private let titleNode: VoiceChatTitleNode
        
        private var enqueuedTransitions: [ListTransition] = []
        private var floatingHeaderOffset: CGFloat?
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        private var didSetContentsReady: Bool = false
        private var didSetDataReady: Bool = false
        
        private var isFirstTime = true
        private var topInset: CGFloat?
        
        private var peer: Peer?
        private var currentTitle: String = ""
        private var currentTitleIsCustom = false
        private var currentSubtitle: String = ""
        private var currentCallMembers: ([GroupCallParticipantsContext.Participant], String?)?
        private var currentInvitedPeers: [Peer]?
        private var currentSpeakingPeers: Set<PeerId>?
        private var currentContentOffset: CGFloat?
        private var ignoreScrolling = false
        private var currentAudioButtonColor: UIColor?
        
        private var currentEntries: [ListEntry] = []
        
        private var peerViewDisposable: Disposable?
        private let leaveDisposable = MetaDisposable()
        
        private var isMutedDisposable: Disposable?
        private var isNoiseSuppressionEnabled: Bool = true
        private var isNoiseSuppressionEnabledDisposable: Disposable?
        private var callStateDisposable: Disposable?
        
        private var pushingToTalk = false
        private let hapticFeedback = HapticFeedback()
        
        private var callState: PresentationGroupCallState?
        
        private var currentLoadToken: String?
        
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
        private var actionButtonColorDisposable: Disposable?
        
        private var itemInteraction: Interaction?
                
        private let inviteDisposable = MetaDisposable()
        private let memberEventsDisposable = MetaDisposable()
        private let reconnectedAsEventsDisposable = MetaDisposable()
        private let voiceSourcesDisposable = MetaDisposable()
        
        private let displayAsPeersPromise = Promise<[FoundPeer]>([])
        private let inviteLinksPromise = Promise<GroupCallInviteLinks?>(nil)
        
        private var raisedHandDisplayDisposables: [PeerId: Disposable] = [:]
        private var displayedRaisedHands = Set<PeerId>() {
            didSet {
                self.displayedRaisedHandsPromise.set(self.displayedRaisedHands)
            }
        }
        private let displayedRaisedHandsPromise = ValuePromise<Set<PeerId>>(Set())
        
        private var requestedVideoSources = Set<UInt32>()
        private var videoNodes: [(PeerId, UInt32, GroupVideoNode)] = []
        private var currentDominantSpeakerWithVideo: (PeerId, UInt32)?
        
        private var updateAvatarDisposable = MetaDisposable()
        private let updateAvatarPromise = Promise<(TelegramMediaImageRepresentation, Float)?>(nil)
        private var currentUpdatingAvatar: TelegramMediaImageRepresentation?
        
        private var ignoreConnecting = false
        private var ignoreConnectingTimer: SwiftSignalKit.Timer?
        
        private enum DisplayMode {
            case `default`
            case fullscreen(controlsHidden: Bool)
        }
        
        private var displayMode: DisplayMode = .default
        
        init(controller: VoiceChatController, sharedContext: SharedAccountContext, call: PresentationGroupCall) {
            self.controller = controller
            self.sharedContext = sharedContext
            self.context = call.accountContext
            self.call = call
            
            self.isScheduling = call.schedulePending
                        
            let presentationData = sharedContext.currentPresentationData.with { $0 }
            self.presentationData = presentationData
            
            self.darkTheme = defaultDarkColorPresentationTheme
            self.currentSubtitle = self.presentationData.strings.SocksProxySetup_ProxyStatusConnecting
            
            self.dimNode = ASDisplayNode()
            self.dimNode.backgroundColor = dimColor
            
            self.contentContainer = ASDisplayNode()
            self.contentContainer.isHidden = true
            
            self.backgroundNode = ASDisplayNode()
            self.backgroundNode.backgroundColor = self.isScheduling ? panelBackgroundColor : secondaryPanelBackgroundColor
            self.backgroundNode.clipsToBounds = false
            
            if sharedContext.immediateExperimentalUISettings.demoVideoChats {
                self.mainVideoContainer = MainVideoContainerNode(context: call.accountContext, call: call)
            }
            
            self.listNode = ListView()
            self.listNode.alpha = self.isScheduling ? 0.0 : 1.0
            self.listNode.isUserInteractionEnabled = !self.isScheduling
            self.listNode.verticalScrollIndicatorColor = UIColor(white: 1.0, alpha: 0.3)
            self.listNode.clipsToBounds = true
            self.listNode.scroller.bounces = false
            self.listNode.accessibilityPageScrolledString = { row, count in
                return presentationData.strings.VoiceOver_ScrollStatus(row, count).0
            }
            
            self.topPanelNode = ASDisplayNode()
            self.topPanelNode.clipsToBounds = false
            
            self.topPanelBackgroundNode = ASDisplayNode()
            self.topPanelBackgroundNode.backgroundColor = panelBackgroundColor
            self.topPanelBackgroundNode.isUserInteractionEnabled = false
            
            self.topPanelEdgeNode = ASDisplayNode()
            self.topPanelEdgeNode.backgroundColor = panelBackgroundColor
            self.topPanelEdgeNode.cornerRadius = 12.0
            self.topPanelEdgeNode.isUserInteractionEnabled = false
            if #available(iOS 11.0, *) {
                self.topPanelEdgeNode.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            }
            
            self.optionsButton = VoiceChatHeaderButton(context: self.context)
            self.closeButton = VoiceChatHeaderButton(context: self.context)
            self.closeButton.setContent(.image(closeButtonImage(dark: false)))
            
            self.titleNode = VoiceChatTitleNode(theme: self.presentationData.theme)
            
            self.topCornersNode = ASImageNode()
            self.topCornersNode.displaysAsynchronously = false
            self.topCornersNode.displayWithoutProcessing = true
            self.topCornersNode.image = cornersImage(top: true, bottom: false, dark: false)
            
            self.bottomPanelNode = ASDisplayNode()
            self.bottomPanelNode.clipsToBounds = false
            
            self.bottomPanelBackgroundNode = ASDisplayNode()
            self.bottomPanelBackgroundNode.backgroundColor = panelBackgroundColor
            
            self.bottomCornersNode = ASImageNode()
            self.bottomCornersNode.displaysAsynchronously = false
            self.bottomCornersNode.displayWithoutProcessing = true
            self.bottomCornersNode.image = cornersImage(top: false, bottom: true, dark: false)
            
            self.audioButton = CallControllerButtonItemNode()
            self.cameraButton = CallControllerButtonItemNode()
            self.switchCameraButton = CallControllerButtonItemNode()
            self.switchCameraButton.alpha = 0.0
            self.switchCameraButton.isUserInteractionEnabled = false
            self.leaveButton = CallControllerButtonItemNode()
            self.actionButton = VoiceChatActionButton()
            
            if self.isScheduling {
                self.audioButton.alpha = 0.0
                self.audioButton.isUserInteractionEnabled = false
                self.leaveButton.alpha = 0.0
                self.leaveButton.isUserInteractionEnabled = false
            }

            self.leftBorderNode = ASDisplayNode()
            self.leftBorderNode.backgroundColor = panelBackgroundColor
            self.leftBorderNode.isUserInteractionEnabled = false
            self.leftBorderNode.clipsToBounds = false
            
            self.rightBorderNode = ASDisplayNode()
            self.rightBorderNode.backgroundColor = panelBackgroundColor
            self.rightBorderNode.isUserInteractionEnabled = false
            self.rightBorderNode.clipsToBounds = false
            
            self.scheduleTextNode = ImmediateTextNode()
            self.scheduleTextNode.isHidden = !self.isScheduling
            self.scheduleTextNode.isUserInteractionEnabled = false
            self.scheduleTextNode.textAlignment = .center
            self.scheduleTextNode.maximumNumberOfLines = 4
            
            self.scheduleCancelButton = SolidRoundedButtonNode(title: self.presentationData.strings.Common_Cancel, theme: SolidRoundedButtonTheme(backgroundColor:  UIColor(rgb: 0x2b2b2f), foregroundColor: .white), height: 52.0, cornerRadius: 10.0)
            self.scheduleCancelButton.isHidden = !self.isScheduling
            
            self.dateFormatter = DateFormatter()
            self.dateFormatter.timeStyle = .none
            self.dateFormatter.dateStyle = .short
            self.dateFormatter.timeZone = TimeZone.current
            
            self.timerNode = VoiceChatTimerNode(strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat)
            self.timerNode.isHidden = true
            
            super.init()
            
            let statePromise = ValuePromise(State(), ignoreRepeated: true)
            let stateValue = Atomic(value: State())
            let updateState: ((State) -> State) -> Void = { f in
                statePromise.set(stateValue.modify { f($0) })
            }
            
            let context = self.context
            let currentAccountPeer = self.context.account.postbox.loadedPeerWithId(context.account.peerId)
            |> map { peer in
                return [FoundPeer(peer: peer, subscribers: nil)]
            }

            self.isNoiseSuppressionEnabledDisposable = (call.isNoiseSuppressionEnabled
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isNoiseSuppressionEnabled = value
            })
            
            let displayAsPeers: Signal<[FoundPeer], NoError> = currentAccountPeer
            |> then(
                combineLatest(currentAccountPeer, cachedGroupCallDisplayAsAvailablePeers(account: context.account, peerId: call.peerId))
                |> map { currentAccountPeer, availablePeers -> [FoundPeer] in
                    var result = currentAccountPeer
                    result.append(contentsOf: availablePeers)
                    return result
                }
            )
            self.displayAsPeersPromise.set(displayAsPeers)

            self.inviteLinksPromise.set(.single(nil)
            |> then(call.inviteLinks))
            
            self.itemInteraction = Interaction(updateIsMuted: { [weak self] peerId, isMuted in
                let _ = self?.call.updateMuteState(peerId: peerId, isMuted: isMuted)
            }, openPeer: { [weak self] peerId in
                if let strongSelf = self {
                    for entry in strongSelf.currentEntries {
                        switch entry {
                        case let .peer(peer):
                            if peer.peer.id == peerId {
                                if let source = peer.ssrc {
                                    if strongSelf.currentDominantSpeakerWithVideo?.0 != peerId || strongSelf.currentDominantSpeakerWithVideo?.1 != source {
                                        strongSelf.currentDominantSpeakerWithVideo = (peerId, source)
                                        strongSelf.call.setFullSizeVideo(peerId: peerId)
                                        strongSelf.mainVideoContainer?.updatePeer(peer: (peerId: peerId, source: source), waitForFullSize: false)
                                    } else {
                                        strongSelf.currentDominantSpeakerWithVideo = nil
                                        strongSelf.call.setFullSizeVideo(peerId: nil)
                                        strongSelf.mainVideoContainer?.updatePeer(peer: nil, waitForFullSize: false)
                                    }
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }, openInvite: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                let groupPeerId = strongSelf.call.peerId
                let groupPeer = strongSelf.context.account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(groupPeerId)
                }
                
                let _ = combineLatest(queue: Queue.mainQueue(), groupPeer, strongSelf.inviteLinksPromise.get() |> take(1)).start(next: { groupPeer, inviteLinks in
                    guard let strongSelf = self else {
                        return
                    }
                    guard let groupPeer = groupPeer else {
                        return
                    }
                    
                    if let groupPeer = groupPeer as? TelegramChannel {
                        var canInviteMembers = true
                        if case .broadcast = groupPeer.info, !(groupPeer.addressName?.isEmpty ?? true) {
                            canInviteMembers = false
                        }
                        if !canInviteMembers {
                            if let inviteLinks = inviteLinks {
                                strongSelf.presentShare(inviteLinks)
                            }
                            return
                        }
                    }
                    
                    var filters: [ChannelMembersSearchFilter] = []
                    if let (currentCallMembers, _) = strongSelf.currentCallMembers {
                        filters.append(.disable(Array(currentCallMembers.map { $0.peer.id })))
                    }
                    if let groupPeer = groupPeer as? TelegramChannel {
                        if !groupPeer.hasPermission(.inviteMembers) && inviteLinks?.listenerLink == nil {
                            filters.append(.excludeNonMembers)
                        }
                    } else if let groupPeer = groupPeer as? TelegramGroup {
                        if groupPeer.hasBannedPermission(.banAddMembers) {
                            filters.append(.excludeNonMembers)
                        }
                    }
                    filters.append(.excludeBots)
                    
                    var dismissController: (() -> Void)?
                    let controller = ChannelMembersSearchController(context: strongSelf.context, peerId: groupPeer.id, forceTheme: strongSelf.darkTheme, mode: .inviteToCall, filters: filters, openPeer: { peer, participant in
                        guard let strongSelf = self else {
                            dismissController?()
                            return
                        }
                        
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        if peer.id == strongSelf.callState?.myPeerId {
                            return
                        }
                        if let participant = participant {
                            dismissController?()
                            
                            if strongSelf.call.invitePeer(participant.peer.id) {
                                strongSelf.presentUndoOverlay(content: .invitedToVoiceChat(context: strongSelf.context, peer: participant.peer, text: strongSelf.presentationData.strings.VoiceChat_InvitedPeerText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0), action: { _ in return false })
                            }
                        } else {
                            if let groupPeer = groupPeer as? TelegramChannel, let listenerLink = inviteLinks?.listenerLink, !groupPeer.hasPermission(.inviteMembers) {
                                let text = strongSelf.presentationData.strings.VoiceChat_SendPublicLinkText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), groupPeer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0
                                
                                strongSelf.controller?.present(textAlertController(context: strongSelf.context, forceTheme: strongSelf.darkTheme, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.VoiceChat_SendPublicLinkSend, action: { [weak self] in
                                    dismissController?()
                                    
                                    if let strongSelf = self {
                                        let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: [.message(text: listenerLink, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)])
                                        |> deliverOnMainQueue).start(next: { [weak self] _ in
                                            if let strongSelf = self {
                                                strongSelf.presentUndoOverlay(content: .forward(savedMessages: false, text: strongSelf.presentationData.strings.UserInfo_LinkForwardTooltip_Chat_One(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0), action: { _ in return true })
                                            }
                                        })
                                    }
                                })]), in: .window(.root))
                            } else {
                                let text: String
                                if let groupPeer = groupPeer as? TelegramChannel, case .broadcast = groupPeer.info {
                                    text = strongSelf.presentationData.strings.VoiceChat_InviteMemberToChannelFirstText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), groupPeer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0
                                } else {
                                    text = strongSelf.presentationData.strings.VoiceChat_InviteMemberToGroupFirstText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), groupPeer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0
                                }
                                
                                strongSelf.controller?.present(textAlertController(context: strongSelf.context, forceTheme: strongSelf.darkTheme, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.VoiceChat_InviteMemberToGroupFirstAdd, action: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    if let groupPeer = groupPeer as? TelegramChannel {
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
                                                    if case .broadcast = groupPeer.info {
                                                        text = presentationData.strings.Channel_AddUserLeftError
                                                    } else {
                                                        text = presentationData.strings.GroupInfo_AddUserLeftError
                                                    }
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
                                            dismissController?()
                                            
                                            if strongSelf.call.invitePeer(peer.id) {
                                                strongSelf.presentUndoOverlay(content: .invitedToVoiceChat(context: strongSelf.context, peer: peer, text: strongSelf.presentationData.strings.VoiceChat_InvitedPeerText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0), action: { _ in return false })
                                            }
                                        }))
                                    } else if let groupPeer = groupPeer as? TelegramGroup {
                                        let selfController = strongSelf.controller
                                        let inviteDisposable = strongSelf.inviteDisposable
                                        var inviteSignal = addGroupMember(account: strongSelf.context.account, peerId: groupPeer.id, memberId: peer.id)
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
                                            let context = strongSelf.context
                                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                            
                                            switch error {
                                            case .privacy:
                                                let _ = (strongSelf.context.account.postbox.loadedPeerWithId(peer.id)
                                                |> deliverOnMainQueue).start(next: { peer in
                                                    self?.controller?.present(textAlertController(context: context, title: nil, text: presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(peer.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                                })
                                            case .notMutualContact:
                                                strongSelf.controller?.present(textAlertController(context: context, title: nil, text: presentationData.strings.GroupInfo_AddUserLeftError, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                            case .tooManyChannels:
                                                strongSelf.controller?.present(textAlertController(context: context, title: nil, text: presentationData.strings.Invite_ChannelsTooMuch, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                            case .groupFull, .generic:
                                                strongSelf.controller?.present(textAlertController(context: strongSelf.context, forceTheme: strongSelf.darkTheme, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                            }
                                        }, completed: {
                                            guard let strongSelf = self else {
                                                dismissController?()
                                                return
                                            }
                                            dismissController?()
                                            
                                            if strongSelf.call.invitePeer(peer.id) {
                                                strongSelf.presentUndoOverlay(content: .invitedToVoiceChat(context: strongSelf.context, peer: peer, text: strongSelf.presentationData.strings.VoiceChat_InvitedPeerText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0), action: { _ in return false })
                                            }
                                        }))
                                    }
                                })]), in: .window(.root))
                            }
                        }
                    })
                    controller.copyInviteLink = {
                        dismissController?()
                        
                        guard let strongSelf = self else {
                            return
                        }
                        let callPeerId = strongSelf.call.peerId
                        
                        let _ = (strongSelf.context.account.postbox.transaction { transaction -> String? in
                            if let link = inviteLinks?.listenerLink {
                                return link
                            } else if let peer = transaction.getPeer(callPeerId), let addressName = peer.addressName, !addressName.isEmpty {
                                return "https://t.me/\(addressName)"
                            } else if let cachedData = transaction.getPeerCachedData(peerId: callPeerId) {
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
                                
                                strongSelf.presentUndoOverlay(content: .linkCopied(text: strongSelf.presentationData.strings.VoiceChat_InviteLinkCopiedText), action: { _ in return false })
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
                
                let muteStatePromise = Promise<GroupCallParticipantsContext.Participant.MuteState?>(entry.muteState)
                   
                let itemsForEntry: (PeerEntry, GroupCallParticipantsContext.Participant.MuteState?) -> [ContextMenuItem] = { entry, muteState in
                    var items: [ContextMenuItem] = []
                    
                    var hasVolumeSlider = false
                    let peer = entry.peer
                    if let muteState = muteState, !muteState.canUnmute || muteState.mutedByYou {
                    } else {
                        if entry.canManageCall || !entry.isMyPeer {
                            hasVolumeSlider = true
                            
                            let minValue: CGFloat
                            if let callState = strongSelf.callState, callState.canManageCall && callState.adminIds.contains(peer.id) && muteState != nil {
                                minValue = 0.01
                            } else {
                                minValue = 0.0
                            }
                            items.append(.custom(VoiceChatVolumeContextItem(minValue: minValue, value: entry.volume.flatMap { CGFloat($0) / 10000.0 } ?? 1.0, valueChanged: { newValue, finished in
                                if finished && newValue.isZero {
                                    let updatedMuteState = strongSelf.call.updateMuteState(peerId: peer.id, isMuted: true)
                                    muteStatePromise.set(.single(updatedMuteState))
                                } else {
                                    strongSelf.call.setVolume(peerId: peer.id, volume: Int32(newValue * 10000), sync: finished)
                                }
                            }), true))
                        }
                    }
                    
                    if entry.isMyPeer && !hasVolumeSlider && ((entry.about?.isEmpty ?? true) || entry.peer.smallProfileImage == nil) {
                        items.append(.custom(VoiceChatInfoContextItem(text: strongSelf.presentationData.strings.VoiceChat_ImproveYourProfileText, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Tip"), color: theme.actionSheet.primaryTextColor)
                        }), true))
                    }

                    if strongSelf.context.sharedContext.immediateExperimentalUISettings.demoVideoChats {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_PinVideo, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Pin"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            guard let strongSelf = self else {
                                return
                            }

                            strongSelf.itemInteraction?.openPeer(peer.id)
                            f(.default)
                        })))
                    }
                    
                    if peer.id == strongSelf.callState?.myPeerId {
                        if entry.raisedHand {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_CancelSpeakRequest, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/RevokeSpeak"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                let _ = strongSelf.call.lowerHand()
                                f(.default)
                            })))
                        }
                        items.append(.action(ContextMenuActionItem(text: peer.smallProfileImage == nil ? strongSelf.presentationData.strings.VoiceChat_AddPhoto : strongSelf.presentationData.strings.VoiceChat_ChangePhoto, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Camera"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            f(.default)
                                                        
                            Queue.mainQueue().after(0.1) {
                                strongSelf.openAvatarForEditing(fromGallery: false, completion: {})
                            }
                        })))
                        
                        items.append(.action(ContextMenuActionItem(text: (entry.about?.isEmpty ?? true) ? strongSelf.presentationData.strings.VoiceChat_AddBio : strongSelf.presentationData.strings.VoiceChat_EditBio, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            guard let strongSelf = self else {
                                return
                            }
                            f(.default)
                               
                            Queue.mainQueue().after(0.1) {
                                let maxBioLength: Int
                                if peer.id.namespace == Namespaces.Peer.CloudUser {
                                    maxBioLength = 70
                                } else {
                                    maxBioLength = 100
                                }
                                let controller = voiceChatTitleEditController(sharedContext: strongSelf.context.sharedContext, account: strongSelf.context.account, forceTheme: strongSelf.darkTheme, title: presentationData.strings.VoiceChat_EditBioTitle, text: presentationData.strings.VoiceChat_EditBioText, placeholder: presentationData.strings.VoiceChat_EditBioPlaceholder, doneButtonTitle: presentationData.strings.VoiceChat_EditBioSave, value: entry.about, maxLength: maxBioLength, apply: { bio in
                                    if let strongSelf = self, let bio = bio {
                                        if peer.id.namespace == Namespaces.Peer.CloudUser {
                                            let _ = (updateAbout(account: strongSelf.context.account, about: bio)
                                            |> `catch` { _ -> Signal<Void, NoError> in
                                                return .complete()
                                            }).start()
                                        } else {
                                            let _ = (updatePeerDescription(account: strongSelf.context.account, peerId: peer.id, description: bio)
                                            |> `catch` { _ -> Signal<Void, NoError> in
                                                return .complete()
                                            }).start()
                                        }
                                        
                                        strongSelf.presentUndoOverlay(content: .info(text: strongSelf.presentationData.strings.VoiceChat_EditBioSuccess), action: { _ in return false })
                                    }
                                })
                                self?.controller?.present(controller, in: .window(.root))
                            }
                        })))
                        
                        if let peer = peer as? TelegramUser {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_ChangeName, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/ChangeName"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                guard let strongSelf = self else {
                                    return
                                }
                                f(.default)
                                   
                                Queue.mainQueue().after(0.1) {
                                    let controller = voiceChatUserNameController(sharedContext: strongSelf.context.sharedContext, account: strongSelf.context.account, forceTheme: strongSelf.darkTheme, title: presentationData.strings.VoiceChat_ChangeNameTitle, firstNamePlaceholder: presentationData.strings.UserInfo_FirstNamePlaceholder, lastNamePlaceholder: presentationData.strings.UserInfo_LastNamePlaceholder, doneButtonTitle: presentationData.strings.VoiceChat_EditBioSave, firstName: peer.firstName, lastName: peer.lastName, maxLength: 128, apply: { firstAndLastName in
                                        if let strongSelf = self, let (firstName, lastName) = firstAndLastName {
                                            let _ = updateAccountPeerName(account: context.account, firstName: firstName, lastName: lastName).start()
                                            
                                            strongSelf.presentUndoOverlay(content: .info(text: strongSelf.presentationData.strings.VoiceChat_EditNameSuccess), action: { _ in return false })
                                        }
                                    })
                                    self?.controller?.present(controller, in: .window(.root))
                                }
                            })))
                        }
                    } else {
                        if let callState = strongSelf.callState, (callState.canManageCall || callState.adminIds.contains(strongSelf.context.account.peerId)) {
                            if callState.adminIds.contains(peer.id) {
                                if let _ = muteState {
                                } else {
                                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_MutePeer, icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                                    }, action: { _, f in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        let _ = strongSelf.call.updateMuteState(peerId: peer.id, isMuted: true)
                                        f(.default)
                                    })))
                                }
                            } else {
                                if let muteState = muteState, !muteState.canUnmute {
                                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_UnmutePeer, icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: entry.raisedHand ? "Call/Context Menu/AllowToSpeak" : "Call/Context Menu/Unmute"), color: theme.actionSheet.primaryTextColor)
                                    }, action: { _, f in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        let _ = strongSelf.call.updateMuteState(peerId: peer.id, isMuted: false)
                                        f(.default)
                                        
                                        strongSelf.presentUndoOverlay(content: .voiceChatCanSpeak(text: presentationData.strings.VoiceChat_UserCanNowSpeak(entry.peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0), action: { _ in return true })
                                    })))
                                } else {
                                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_MutePeer, icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                                    }, action: { _, f in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        let _ = strongSelf.call.updateMuteState(peerId: peer.id, isMuted: true)
                                        f(.default)
                                    })))
                                }
                            }
                        } else {
                            if let muteState = muteState, muteState.mutedByYou {
                                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_UnmuteForMe, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Unmute"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    let _ = strongSelf.call.updateMuteState(peerId: peer.id, isMuted: false)
                                    f(.default)
                                })))
                            } else {
                                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_MuteForMe, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    let _ = strongSelf.call.updateMuteState(peerId: peer.id, isMuted: true)
                                    f(.default)
                                })))
                            }
                        }
                        
                        let openTitle: String
                        let openIcon: UIImage?
                        if peer.id.namespace == Namespaces.Peer.CloudChannel {
                            openTitle = strongSelf.presentationData.strings.VoiceChat_OpenChannel
                            openIcon = UIImage(bundleImageName: "Chat/Context Menu/Channels")
                        } else {
                            openTitle = strongSelf.presentationData.strings.Conversation_ContextMenuSendMessage
                            openIcon = UIImage(bundleImageName: "Chat/Context Menu/Message")
                        }
                        items.append(.action(ContextMenuActionItem(text: openTitle, icon: { theme in
                            return generateTintedImage(image: openIcon, color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            guard let strongSelf = self, let navigationController = strongSelf.controller?.parentNavigationController else {
                                return
                            }
                        
                            let context = strongSelf.context
                            strongSelf.controller?.dismiss(completion: {
                                Queue.mainQueue().after(0.3) {
                                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer.id), keepStack: .always, purposefulAction: {}, peekData: nil))
                                }
                            })
                        
                            f(.dismissWithoutContent)
                        })))
                    
                        if let callState = strongSelf.callState, (callState.canManageCall && !callState.adminIds.contains(peer.id)) {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_RemovePeer, textColor: .destructive, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
                            }, action: { [weak self] c, _ in
                                c.dismiss(completion: {
                                    guard let strongSelf = self else {
                                        return
                                    }

                                    let _ = (strongSelf.context.account.postbox.loadedPeerWithId(strongSelf.call.peerId)
                                    |> deliverOnMainQueue).start(next: { [weak self] chatPeer in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme))
                                        var items: [ActionSheetItem] = []
                                        
                                        items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: peer, chatPeer: chatPeer, action: .removeFromGroup, strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder))

                                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.VoiceChat_RemovePeerRemove, color: .destructive, action: { [weak actionSheet] in
                                            actionSheet?.dismissAnimated()
                                            
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            
                                            let _ = strongSelf.context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: strongSelf.context.account, peerId: strongSelf.call.peerId, memberId: peer.id, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max)).start()
                                            strongSelf.call.removedPeer(peer.id)
                                            
                                            strongSelf.presentUndoOverlay(content: .banned(text: strongSelf.presentationData.strings.VoiceChat_RemovedPeerText(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0), action: { _ in return false })
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
                                })
                            })))
                        }
                    }
                    return items
                }
                
                let items = muteStatePromise.get()
                |> map { muteState -> [ContextMenuItem] in
                    return itemsForEntry(entry, muteState)
                }
                
                
                let dismissPromise = ValuePromise<Bool>(false)
                let source = VoiceChatContextExtractedContentSource(controller: controller, sourceNode: sourceNode, keepInPlace: false, blurBackground: true, centerVertically: entry.peer.smallProfileImage != nil, shouldBeDismissed: dismissPromise.get())
                sourceNode.requestDismiss = {
                    dismissPromise.set(true)
                }
                
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme), source: .extracted(source), items: items, reactionItems: [], gesture: gesture)
                contextController.useComplexItemsTransitionAnimation = true
                strongSelf.controller?.presentInGlobalOverlay(contextController)
            }, setPeerIdWithRevealedOptions: { peerId, _ in
                updateState { state in
                    var updated = state
                    updated.revealedPeerId = peerId
                    return updated
                }
            }, getPeerVideo: { [weak self] ssrc in
                guard let strongSelf = self else {
                    return nil
                }
                for (_, listSsrc, videoNode) in strongSelf.videoNodes {
                    if listSsrc == ssrc {
                        return videoNode
                    }
                }
                return nil
            })
            self.itemInteraction?.updateAvatarPromise = self.updateAvatarPromise
            
            self.topPanelNode.addSubnode(self.topPanelEdgeNode)
            self.topPanelNode.addSubnode(self.topPanelBackgroundNode)
            self.topPanelNode.addSubnode(self.titleNode)
            self.topPanelNode.addSubnode(self.optionsButton)
            self.topPanelNode.addSubnode(self.closeButton)
            self.topPanelNode.addSubnode(self.topCornersNode)
            
            self.bottomPanelNode.addSubnode(self.bottomCornersNode)
            self.bottomPanelNode.addSubnode(self.bottomPanelBackgroundNode)
            self.bottomPanelNode.addSubnode(self.audioButton)
            if let _ = self.mainVideoContainer {
                self.bottomPanelNode.addSubnode(self.cameraButton)
                self.bottomPanelNode.addSubnode(self.switchCameraButton)
            }
            self.bottomPanelNode.addSubnode(self.leaveButton)
            self.bottomPanelNode.addSubnode(self.actionButton)
            self.bottomPanelNode.addSubnode(self.scheduleCancelButton)
            
            self.addSubnode(self.dimNode)
            self.addSubnode(self.contentContainer)
            self.contentContainer.addSubnode(self.backgroundNode)
            
            self.contentContainer.addSubnode(self.listNode)
            if let mainVideoContainer = self.mainVideoContainer {
                self.contentContainer.addSubnode(mainVideoContainer)
            }
            self.contentContainer.addSubnode(self.topPanelNode)
            self.contentContainer.addSubnode(self.leftBorderNode)
            self.contentContainer.addSubnode(self.rightBorderNode)
            self.contentContainer.addSubnode(self.bottomPanelNode)
            self.contentContainer.addSubnode(self.timerNode)
            self.contentContainer.addSubnode(self.scheduleTextNode)
            
            let invitedPeers: Signal<[Peer], NoError> = self.call.invitedPeers
            |> mapToSignal { ids -> Signal<[Peer], NoError> in
                return context.account.postbox.transaction { transaction -> [Peer] in
                    return ids.compactMap(transaction.getPeer)
                }
            }
            
            self.presentationDataDisposable = (sharedContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    strongSelf.presentationData = presentationData
                    
                    let sourceColor = presentationData.theme.chatList.unreadBadgeInactiveBackgroundColor
                    let color: UIColor
                    if sourceColor.alpha < 1.0 {
                        color = presentationData.theme.chatList.unreadBadgeInactiveBackgroundColor.mixedWith(sourceColor.withAlphaComponent(1.0), alpha: sourceColor.alpha)
                    } else {
                        color = sourceColor
                    }
                    strongSelf.actionButton.connectingColor = color
                }
            })
            
            self.memberStatesDisposable = (combineLatest(queue: .mainQueue(),
                self.call.state,
                self.call.members,
                invitedPeers,
                self.displayAsPeersPromise.get()
            )
            |> mapToThrottled { values in
                return .single(values)
                |> then(.complete() |> delay(0.1, queue: Queue.mainQueue()))
            }).start(next: { [weak self] state, callMembers, invitedPeers, displayAsPeers in
                guard let strongSelf = self else {
                    return
                }
                
                if strongSelf.callState != state {
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
                
                strongSelf.updateMembers(muteState: strongSelf.effectiveMuteState, callMembers: (callMembers?.participants ?? [], callMembers?.loadMoreToken), invitedPeers: invitedPeers, speakingPeers: callMembers?.speakingParticipants ?? [])
                
                let subtitle = strongSelf.presentationData.strings.VoiceChat_Panel_Members(Int32(max(1, callMembers?.totalCount ?? 0)))
                strongSelf.currentSubtitle = subtitle
                
                if strongSelf.isScheduling {
                    strongSelf.optionsButtonIsAvatar = false
                    strongSelf.optionsButton.isUserInteractionEnabled = false
                    strongSelf.optionsButton.alpha = 0.0
                    strongSelf.closeButton.isUserInteractionEnabled = false
                    strongSelf.closeButton.alpha = 0.0
                } else if let callState = strongSelf.callState, callState.canManageCall {
                    strongSelf.optionsButtonIsAvatar = false
                    strongSelf.optionsButton.isUserInteractionEnabled = true
                    strongSelf.optionsButton.alpha = 1.0
                } else if displayAsPeers.count > 1 {
                    strongSelf.optionsButtonIsAvatar = true
                    for peer in displayAsPeers {
                        if peer.peer.id == state.myPeerId {
                            strongSelf.optionsButton.setContent(.avatar(peer.peer))
                        }
                    }
                    strongSelf.optionsButton.isUserInteractionEnabled = true
                    strongSelf.optionsButton.alpha = 1.0
                } else {
                    strongSelf.optionsButtonIsAvatar = false
                    strongSelf.optionsButton.isUserInteractionEnabled = false
                    strongSelf.optionsButton.alpha = 0.0
                }
                
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                }
            })
            
            
            let titleAndRecording: Signal<(String?, Bool), NoError> = self.call.state
            |> map { state -> (String?, Bool) in
                return (state.title, state.recordingStartTimestamp != nil)
            }
            self.peerViewDisposable = combineLatest(queue: Queue.mainQueue(), self.context.account.viewTracker.peerView(self.call.peerId), titleAndRecording).start(next: { [weak self] view, titleAndRecording in
                guard let strongSelf = self else {
                    return
                }
                
                let (title, isRecording) = titleAndRecording
                if let peer = peerViewMainPeer(view) {
                    strongSelf.peer = peer
                    strongSelf.currentTitleIsCustom = title != nil
                    strongSelf.currentTitle = title ?? peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)
                    
                    strongSelf.updateTitle(transition: .immediate)
                    strongSelf.titleNode.isRecording = isRecording
                }
                if !strongSelf.didSetDataReady {
                    strongSelf.didSetDataReady = true
                    
                    strongSelf.updateMembers(muteState: strongSelf.effectiveMuteState, callMembers: strongSelf.currentCallMembers ?? ([], nil), invitedPeers: strongSelf.currentInvitedPeers ?? [], speakingPeers: strongSelf.currentSpeakingPeers ?? Set())
                    
                    strongSelf.controller?.dataReady.set(true)
                }
            })
            
            self.audioOutputStateDisposable = (self.call.audioOutputState
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                let wasEmpty = strongSelf.audioOutputState == nil
                strongSelf.audioOutputState = state
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                }
                if wasEmpty {
                    strongSelf.controller?.audioOutputStateReady.set(true)
                }
            })
            
            self.audioLevelsDisposable = (self.call.audioLevels
            |> deliverOnMainQueue).start(next: { [weak self] levels in
                guard let strongSelf = self else {
                    return
                }
                var levels = levels
                if strongSelf.effectiveMuteState != nil {
                    levels = levels.filter { $0.0 != strongSelf.callState?.myPeerId }
                }
                
                var maxLevelWithVideo: (PeerId, UInt32, Float)?
                for (peerId, source, level, hasSpeech) in levels {
                    if hasSpeech && source != 0 {
                        if let (_, _, currentLevel) = maxLevelWithVideo {
                            if currentLevel < level {
                                maxLevelWithVideo = (peerId, source, level)
                            }
                        } else {
                            maxLevelWithVideo = (peerId, source, level)
                        }
                    }
                }
                
                if let (peerId, source, _) = maxLevelWithVideo {
                    if strongSelf.currentDominantSpeakerWithVideo?.0 != peerId || strongSelf.currentDominantSpeakerWithVideo?.1 != source {
                        strongSelf.currentDominantSpeakerWithVideo = (peerId, source)
                        strongSelf.call.setFullSizeVideo(peerId: peerId)
                        strongSelf.mainVideoContainer?.updatePeer(peer: (peerId: peerId, source: source), waitForFullSize: true)
                    }
                }
                
                strongSelf.itemInteraction?.updateAudioLevels(levels)
            })
            
            self.myAudioLevelDisposable = (self.call.myAudioLevel
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
            
            self.leaveButton.addTarget(self, action: #selector(self.leavePressed), forControlEvents: .touchUpInside)
            self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
            self.audioButton.addTarget(self, action: #selector(self.audioOutputPressed), forControlEvents: .touchUpInside)
            self.cameraButton.addTarget(self, action: #selector(self.cameraPressed), forControlEvents: .touchUpInside)
            self.switchCameraButton.addTarget(self, action: #selector(self.switchCameraPressed), forControlEvents: .touchUpInside)

            self.optionsButton.contextAction = { [weak self] sourceNode, gesture in
                self?.openContextMenu(sourceNode: sourceNode, gesture: gesture)
            }
            
            self.optionsButton.addTarget(self, action: #selector(self.optionsPressed), forControlEvents: .touchUpInside)
            self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: .touchUpInside)
            
            self.actionButtonColorDisposable = (self.actionButton.outerColor
            |> deliverOnMainQueue).start(next: { [weak self] color in
                if let strongSelf = self {
                    let animated = strongSelf.currentAudioButtonColor != nil
                    strongSelf.currentAudioButtonColor = color
                    strongSelf.updateButtons(animated: animated)
                }
            })
            
            self.listNode.updateFloatingHeaderOffset = { [weak self] offset, transition in
                if let strongSelf = self {
                    strongSelf.currentContentOffset = offset
                    if !strongSelf.animatingExpansion && !strongSelf.animatingInsertion && strongSelf.panGestureArguments == nil && !strongSelf.animatingAppearance {
                        strongSelf.updateFloatingHeaderOffset(offset: offset, transition: transition)
                    }
                }
            }
            
            self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
                guard let strongSelf = self else {
                    return
                }
                if case let .known(value) = offset, value < 200.0 {
                    if let loadMoreToken = strongSelf.currentCallMembers?.1 {
                        strongSelf.currentLoadToken = loadMoreToken
                        strongSelf.call.loadMoreMembers(token: loadMoreToken)
                    }
                }
            }
            
            self.reconnectedAsEventsDisposable.set((self.call.reconnectedAsEvents
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.presentUndoOverlay(content: .invitedToVoiceChat(context: strongSelf.context, peer: peer, text: strongSelf.presentationData.strings.VoiceChat_DisplayAsSuccess(peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0), action: { _ in return false })
            }))
            
            self.voiceSourcesDisposable.set((self.call.incomingVideoSources
            |> deliverOnMainQueue).start(next: { [weak self] sources in
                guard let strongSelf = self else {
                    return
                }
                var validSources = Set<UInt32>()
                for (peerId, source) in sources {
                    validSources.insert(source)
                    
                    if !strongSelf.requestedVideoSources.contains(source) {
                        strongSelf.requestedVideoSources.insert(source)
                        strongSelf.call.makeIncomingVideoView(source: source, completion: { videoView in
                            Queue.mainQueue().async {
                                guard let strongSelf = self, let videoView = videoView else {
                                    return
                                }
                                let videoNode = GroupVideoNode(videoView: videoView)
                                strongSelf.videoNodes.append((peerId, source, videoNode))
                                //strongSelf.addSubnode(videoNode)
                                if let (layout, navigationHeight) = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                                    
                                    loop: for i in 0 ..< strongSelf.currentEntries.count {
                                        let entry = strongSelf.currentEntries[i]
                                        switch entry {
                                        case let .peer(peerEntry):
                                            if peerEntry.ssrc == source {
                                                let presentationData = strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme)
                                                strongSelf.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [ListViewUpdateItem(index: i, previousIndex: i, item: entry.item(context: strongSelf.context, presentationData: presentationData, interaction: strongSelf.itemInteraction!), directionHint: nil)], options: [.Synchronous], updateOpaqueState: nil)
                                                break loop
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                            }
                        })
                    }
                }
                
                var updated = false
                for i in (0 ..< strongSelf.videoNodes.count).reversed() {
                    if !validSources.contains(strongSelf.videoNodes[i].1) {
                        let ssrc = strongSelf.videoNodes[i].1
                        strongSelf.videoNodes.remove(at: i)
                        
                        loop: for j in 0 ..< strongSelf.currentEntries.count {
                            let entry = strongSelf.currentEntries[j]
                            switch entry {
                            case let .peer(peerEntry):
                                if peerEntry.ssrc == ssrc {
                                    let presentationData = strongSelf.presentationData.withUpdated(theme: strongSelf.darkTheme)
                                    strongSelf.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [ListViewUpdateItem(index: i, previousIndex: i, item: entry.item(context: strongSelf.context, presentationData: presentationData, interaction: strongSelf.itemInteraction!), directionHint: nil)], options: [.Synchronous], updateOpaqueState: nil)
                                    break loop
                                }
                            default:
                                break
                            }
                        }
                        
                        //strongSelf.videoNodes[i].2.removeFromSupernode()
                        updated = true
                    }
                }
                
                if let (_, source) = strongSelf.currentDominantSpeakerWithVideo {
                    if !validSources.contains(source) {
                        strongSelf.currentDominantSpeakerWithVideo = nil
                        strongSelf.call.setFullSizeVideo(peerId: nil)
                        strongSelf.mainVideoContainer?.updatePeer(peer: nil, waitForFullSize: false)
                    }
                }
                
                if updated {
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                    }
                }
            }))
            
            self.titleNode.tapped = { [weak self] in
                if let strongSelf = self {
                    if strongSelf.callState?.canManageCall ?? false {
                        strongSelf.openTitleEditing()
                    } else if !strongSelf.titleNode.recordingIconNode.isHidden {
                        var hasTooltipAlready = false
                        strongSelf.controller?.forEachController { controller -> Bool in
                            if controller is TooltipScreen {
                                hasTooltipAlready = true
                            }
                            return true
                        }
                        if !hasTooltipAlready {
                            let location = strongSelf.titleNode.recordingIconNode.convert(strongSelf.titleNode.recordingIconNode.bounds, to: nil)
                            strongSelf.controller?.present(TooltipScreen(text: presentationData.strings.VoiceChat_RecordingInProgress, icon: nil, location: .point(location.offsetBy(dx: 1.0, dy: 0.0), .top), displayDuration: .custom(3.0), shouldDismissOnTouch: { _ in
                                return .dismiss(consume: true)
                            }), in: .window(.root))
                        }
                    }
                }
            }
            
            self.scheduleCancelButton.pressed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.dismissScheduled()
                }
            }
        }
        
        deinit {
            self.presentationDataDisposable?.dispose()
            self.peerViewDisposable?.dispose()
            self.leaveDisposable.dispose()
            self.isMutedDisposable?.dispose()
            self.isNoiseSuppressionEnabledDisposable?.dispose()
            self.callStateDisposable?.dispose()
            self.audioOutputStateDisposable?.dispose()
            self.memberStatesDisposable?.dispose()
            self.audioLevelsDisposable?.dispose()
            self.myAudioLevelDisposable?.dispose()
            self.inviteDisposable.dispose()
            self.memberEventsDisposable.dispose()
            self.reconnectedAsEventsDisposable.dispose()
            self.voiceSourcesDisposable.dispose()
            self.updateAvatarDisposable.dispose()
            self.ignoreConnectingTimer?.invalidate()
        }

        private func openContextMenu(sourceNode: ASDisplayNode, gesture: ContextGesture?) {
            let canManageCall = !self.optionsButtonIsAvatar
            let items: Signal<[ContextMenuItem], NoError>
            if canManageCall {
                items = self.contextMenuMainItems()
            } else {
                items = self.contextMenuDisplayAsItems()
            }
            if let controller = self.controller {
                let contextController = ContextController(account: self.context.account, presentationData: self.presentationData.withUpdated(theme: self.darkTheme), source: .reference(VoiceChatContextReferenceContentSource(controller: controller, sourceNode: self.optionsButton.referenceNode)), items: items, reactionItems: [], gesture: gesture)
                controller.presentInGlobalOverlay(contextController)
            }
        }

        private func contextMenuMainItems() -> Signal<[ContextMenuItem], NoError> {
            guard let myPeerId = self.callState?.myPeerId else {
                return .single([])
            }

            let avatarSize = CGSize(width: 28.0, height: 28.0)

            return combineLatest(self.displayAsPeersPromise.get(), self.context.account.postbox.loadedPeerWithId(self.call.peerId), self.inviteLinksPromise.get())
            |> take(1)
            |> deliverOnMainQueue
            |> map { [weak self] peers, chatPeer, inviteLinks -> [ContextMenuItem] in
                guard let strongSelf = self else {
                    return []
                }

                let presentationData = strongSelf.presentationData
                var items: [ContextMenuItem] = []

                if peers.count > 1 {
                    for peer in peers {
                        if peer.peer.id == myPeerId {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_DisplayAs, textLayout: .secondLineWithValue(peer.peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: strongSelf.context.account, peer: peer.peer, size: avatarSize)), action: { c, _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                c.setItems(strongSelf.contextMenuDisplayAsItems())
                            })))
                            items.append(.separator)
                            break
                        }
                    }
                }

                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_EditTitle, icon: { theme -> UIImage? in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Pencil"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    f(.default)

                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.openTitleEditing()
                })))

                var hasPermissions = true
                if let chatPeer = chatPeer as? TelegramChannel {
                    if case .broadcast = chatPeer.info {
                        hasPermissions = false
                    } else if chatPeer.flags.contains(.isGigagroup) {
                        hasPermissions = false
                    }
                }
                if hasPermissions {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_EditPermissions, icon: { theme -> UIImage? in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.actionSheet.primaryTextColor)
                    }, action: { c, _ in
                        guard let strongSelf = self else {
                            return
                        }
                        c.setItems(strongSelf.contextMenuPermissionItems())
                    })))
                }
            
                if let inviteLinks = inviteLinks {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_Share, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        f(.default)

                        self?.presentShare(inviteLinks)
                    })))
                }

                if let recordingStartTimestamp = strongSelf.callState?.recordingStartTimestamp {
                    items.append(.custom(VoiceChatRecordingContextItem(timestamp: recordingStartTimestamp, action: { _, f in
                        f(.dismissWithoutContent)

                        guard let strongSelf = self else {
                            return
                        }

                        let alertController = textAlertController(context: strongSelf.context, forceTheme: strongSelf.darkTheme, title: nil, text: strongSelf.presentationData.strings.VoiceChat_StopRecordingTitle, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.VoiceChat_StopRecordingStop, action: {
                            if let strongSelf = self {
                                strongSelf.call.setShouldBeRecording(false, title: nil)

                                strongSelf.presentUndoOverlay(content: .forward(savedMessages: true, text: strongSelf.presentationData.strings.VoiceChat_RecordingSaved), action: { [weak self] value in
                                    if case .info = value, let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                                        let context = strongSelf.context
                                        strongSelf.controller?.dismiss(completion: {
                                            Queue.mainQueue().justDispatch {
                                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(context.account.peerId), keepStack: .always, purposefulAction: {}, peekData: nil))
                                            }
                                        })
                                        
                                        return true
                                    }
                                    return false
                                })
                            }
                        })])
                        self?.controller?.present(alertController, in: .window(.root))
                    }), false))
                } else {
                    if strongSelf.callState?.scheduleTimestamp == nil {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_StartRecording, icon: { theme -> UIImage? in
                            return generateStartRecordingIcon(color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            f(.dismissWithoutContent)

                            guard let strongSelf = self else {
                                return
                            }

                            let controller = voiceChatTitleEditController(sharedContext: strongSelf.context.sharedContext, account: strongSelf.context.account, forceTheme: strongSelf.darkTheme, title: presentationData.strings.VoiceChat_StartRecordingTitle, text: presentationData.strings.VoiceChat_StartRecordingText, placeholder: presentationData.strings.VoiceChat_RecordingTitlePlaceholder, value: nil, maxLength: 40, apply: { title in
                                if let strongSelf = self, let title = title {
                                    strongSelf.call.setShouldBeRecording(true, title: title)

                                    strongSelf.presentUndoOverlay(content: .voiceChatRecording(text: strongSelf.presentationData.strings.VoiceChat_RecordingStarted), action: { _ in return false })
                                    strongSelf.call.playTone(.recordingStarted)
                                }
                            })
                            self?.controller?.present(controller, in: .window(.root))
                        })))
                    }
                }

                /*items.append(.action(ContextMenuActionItem(text: strongSelf.isNoiseSuppressionEnabled ? "Disable Noise Suppression" : "Enable Noise Suppression", textColor: .primary, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unmute"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)

                    guard let strongSelf = self else {
                        return
                    }

                    strongSelf.call.setIsNoiseSuppressionEnabled(!strongSelf.isNoiseSuppressionEnabled)
                })))*/

                if let callState = strongSelf.callState, callState.canManageCall {
                    let isScheduled = strongSelf.callState?.scheduleTimestamp != nil
                    items.append(.action(ContextMenuActionItem(text: isScheduled ? strongSelf.presentationData.strings.VoiceChat_CancelVoiceChat : strongSelf.presentationData.strings.VoiceChat_EndVoiceChat, textColor: .destructive, icon: { theme in
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

                        let alertController = textAlertController(context: strongSelf.context, forceTheme: strongSelf.darkTheme, title: isScheduled ? strongSelf.presentationData.strings.VoiceChat_CancelConfirmationTitle : strongSelf.presentationData.strings.VoiceChat_EndConfirmationTitle, text: isScheduled ? strongSelf.presentationData.strings.VoiceChat_CancelConfirmationText : strongSelf.presentationData.strings.VoiceChat_EndConfirmationText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: isScheduled ? strongSelf.presentationData.strings.VoiceChat_CancelConfirmationEnd : strongSelf.presentationData.strings.VoiceChat_EndConfirmationEnd, action: {
                            action()
                        })])
                        strongSelf.controller?.present(alertController, in: .window(.root))
                    })))
                }


                return items
            }
        }

        private func contextMenuDisplayAsItems() -> Signal<[ContextMenuItem], NoError> {
            guard let myPeerId = self.callState?.myPeerId else {
                return .single([])
            }

            let avatarSize = CGSize(width: 28.0, height: 28.0)
            let canManageCall = !self.optionsButtonIsAvatar
            let darkTheme = self.darkTheme

            return self.displayAsPeersPromise.get()
            |> take(1)
            |> map { [weak self] peers -> [ContextMenuItem] in
                guard let strongSelf = self else {
                    return []
                }

                var items: [ContextMenuItem] = []
                
                var isGroup = false
                for peer in peers {
                    if peer.peer is TelegramGroup {
                        isGroup = true
                        break
                    } else if let peer = peer.peer as? TelegramChannel, case .group = peer.info {
                        isGroup = true
                        break
                    }
                }
                
                items.append(.custom(VoiceChatInfoContextItem(text: isGroup ? strongSelf.presentationData.strings.VoiceChat_DisplayAsInfoGroup : strongSelf.presentationData.strings.VoiceChat_DisplayAsInfo, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Accounts"), color: theme.actionSheet.primaryTextColor)
                }), true))

                for peer in peers {
                    var subtitle: String?
                    if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                        subtitle = strongSelf.presentationData.strings.VoiceChat_PersonalAccount
                    } else if let subscribers = peer.subscribers {
                        if let peer = peer.peer as? TelegramChannel, case .broadcast = peer.info {
                            subtitle = strongSelf.presentationData.strings.Conversation_StatusSubscribers(subscribers)
                        } else {
                            subtitle = strongSelf.presentationData.strings.Conversation_StatusMembers(subscribers)
                        }
                    }

                    let isSelected = peer.peer.id == myPeerId
                    let extendedAvatarSize = CGSize(width: 35.0, height: 35.0)
                    let avatarSignal = peerAvatarCompleteImage(account: strongSelf.context.account, peer: peer.peer, size: avatarSize)
                    |> map { image -> UIImage? in
                        if isSelected, let image = image {
                            return generateImage(extendedAvatarSize, rotatedContext: { size, context in
                                let bounds = CGRect(origin: CGPoint(), size: size)
                                context.clear(bounds)
                                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                                context.scaleBy(x: 1.0, y: -1.0)
                                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                                context.draw(image.cgImage!, in: CGRect(x: (extendedAvatarSize.width - avatarSize.width) / 2.0, y: (extendedAvatarSize.height - avatarSize.height) / 2.0, width: avatarSize.width, height: avatarSize.height))

                                let lineWidth = 1.0 + UIScreenPixel
                                context.setLineWidth(lineWidth)
                                context.setStrokeColor(darkTheme.actionSheet.controlAccentColor.cgColor)
                                context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
                            })
                        } else {
                            return image
                        }
                    }

                    items.append(.action(ContextMenuActionItem(text: peer.peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), textLayout: subtitle.flatMap { .secondLineWithValue($0) } ?? .singleLine, icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: isSelected ? extendedAvatarSize : avatarSize, signal: avatarSignal), action: { _, f in
                        f(.default)

                        guard let strongSelf = self else {
                            return
                        }

                        if peer.peer.id != myPeerId {
                            strongSelf.call.reconnect(as: peer.peer.id)
                        }
                    })))

                    if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                        items.append(.separator)
                    }
                }
                if canManageCall {
                    items.append(.separator)
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Common_Back, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
                    }, action: { (c, _) in
                        guard let strongSelf = self else {
                            return
                        }
                        c.setItems(strongSelf.contextMenuMainItems())
                    })))
                }
                return items
            }
        }

        private func contextMenuPermissionItems() -> Signal<[ContextMenuItem], NoError> {
            var items: [ContextMenuItem] = []
            if let callState = self.callState, callState.canManageCall, let defaultParticipantMuteState = callState.defaultParticipantMuteState {
                let isMuted = defaultParticipantMuteState == .muted

                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.VoiceChat_SpeakPermissionEveryone, icon: { theme in
                    if isMuted {
                        return nil
                    } else {
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
                    }
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)

                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.call.updateDefaultParticipantsAreMuted(isMuted: false)
                })))
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.VoiceChat_SpeakPermissionAdmin, icon: { theme in
                    if !isMuted {
                        return nil
                    } else {
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
                    }
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)

                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.call.updateDefaultParticipantsAreMuted(isMuted: true)
                })))
                items.append(.separator)
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Common_Back, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] (c, _) in
                    guard let strongSelf = self else {
                        return
                    }
                    c.setItems(strongSelf.contextMenuMainItems())
                })))
            }
            return .single(items)
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
            
            if self.isScheduling {
                self.setupSchedulePickerView()
                self.updateScheduleButtonTitle()
            }
        }
        
        private func updateSchedulePickerLimits() {
            let timeZone = TimeZone(secondsFromGMT: 0)!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let currentDate = Date()
            var components = calendar.dateComponents(Set([.era, .year, .month, .day, .hour, .minute, .second]), from: currentDate)
            components.second = 0
            
            let roundedDate = calendar.date(from: components)!
            let next1MinDate = calendar.date(byAdding: .minute, value: 1, to: roundedDate)
            
            let minute = components.minute ?? 0
            components.minute = 0
            let roundedToHourDate = calendar.date(from: components)!
            
            components.hour = 0
            let roundedToMidnightDate = calendar.date(from: components)!
            
            let nextTwoHourDate = calendar.date(byAdding: .hour, value: minute > 30 ? 4 : 3, to: roundedToHourDate)
           
            let maxDate = calendar.date(byAdding: .day, value: 8, to: roundedToMidnightDate)
            
            if let date = calendar.date(byAdding: .day, value: 365, to: currentDate) {
                self.pickerView?.maximumDate = date
            }
            
            if let next1MinDate = next1MinDate, let nextTwoHourDate = nextTwoHourDate {
                self.pickerView?.minimumDate = next1MinDate
                self.pickerView?.maximumDate = maxDate
                self.pickerView?.date = nextTwoHourDate
            }
        }
        
        private func setupSchedulePickerView() {
            var currentDate: Date?
            if let pickerView = self.pickerView {
                currentDate = pickerView.date
                pickerView.removeFromSuperview()
            }
            
            let textColor = UIColor.white
            UILabel.setDateLabel(textColor)
            
            let pickerView = UIDatePicker()
            pickerView.timeZone = TimeZone(secondsFromGMT: 0)
            pickerView.datePickerMode = .countDownTimer
            pickerView.datePickerMode = .dateAndTime
            pickerView.locale = Locale.current
            pickerView.timeZone = TimeZone.current
            pickerView.minuteInterval = 1
            self.contentContainer.view.addSubview(pickerView)
            pickerView.addTarget(self, action: #selector(self.datePickerUpdated), for: .valueChanged)
            if #available(iOS 13.4, *) {
                pickerView.preferredDatePickerStyle = .wheels
            }
            pickerView.setValue(textColor, forKey: "textColor")
            self.pickerView = pickerView
            
            self.updateSchedulePickerLimits()
            if let currentDate = currentDate {
                pickerView.date = currentDate
            }
        }
        
        private let calendar = Calendar(identifier: .gregorian)
        private func updateScheduleButtonTitle() {
            guard let date = self.pickerView?.date else {
                return
            }
            
            let calendar = Calendar(identifier: .gregorian)
            let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            let timestamp = Int32(date.timeIntervalSince1970)
            let time = stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: self.presentationData.dateTimeFormat)
            let buttonTitle: String
            if calendar.isDateInToday(date) {
                buttonTitle = self.presentationData.strings.ScheduleVoiceChat_ScheduleToday(time).0
            } else if calendar.isDateInTomorrow(date) {
                buttonTitle = self.presentationData.strings.ScheduleVoiceChat_ScheduleTomorrow(time).0
            } else {
                buttonTitle = self.presentationData.strings.ScheduleVoiceChat_ScheduleOn(self.dateFormatter.string(from: date), time).0
            }
            self.scheduleButtonTitle = buttonTitle
            
            let delta = timestamp - currentTimestamp
            
            var isGroup = true
            if let peer = self.peer as? TelegramChannel, case .broadcast = peer.info {
                isGroup = false
            }
            let intervalString = scheduledTimeIntervalString(strings: self.presentationData.strings, value: max(60, delta))
            self.scheduleTextNode.attributedText = NSAttributedString(string: isGroup ? self.presentationData.strings.ScheduleVoiceChat_GroupText(intervalString).0 : self.presentationData.strings.ScheduleVoiceChat_ChannelText(intervalString).0, font: Font.regular(14.0), textColor: UIColor(rgb: 0x8e8e93))
            
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
            }
        }
        
        @objc private func datePickerUpdated() {
            self.updateScheduleButtonTitle()
        }
        
        private func schedule() {
            if let date = self.pickerView?.date, date > Date() {
                self.call.schedule(timestamp: Int32(date.timeIntervalSince1970))
                                   
                self.isScheduling = false
                self.transitionToScheduled()
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
                }
            }
        }
        
        private func dismissScheduled() {
            self.leaveDisposable.set((self.call.leave(terminateIfPossible: true)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                self?.controller?.dismiss(closing: true)
            }))
        }
        
        private func transitionToScheduled() {
            let springDuration: Double = 0.6
            let springDamping: CGFloat = 100.0
            
            self.optionsButton.alpha = 1.0
            self.optionsButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.optionsButton.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, damping: springDamping)
            self.optionsButton.isUserInteractionEnabled = true
            
            self.closeButton.alpha = 1.0
            self.closeButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.closeButton.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, damping: springDamping)
            self.closeButton.isUserInteractionEnabled = true
            
            self.audioButton.alpha = 1.0
            self.audioButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.audioButton.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, damping: springDamping)
            self.audioButton.isUserInteractionEnabled = true
            
            self.leaveButton.alpha = 1.0
            self.leaveButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.leaveButton.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, damping: springDamping)
            self.leaveButton.isUserInteractionEnabled = true
            
            self.scheduleCancelButton.alpha = 0.0
            self.scheduleCancelButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
            self.scheduleCancelButton.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: 26.0), duration: 0.2, removeOnCompletion: false, additive: true)
            
            self.actionButton.titleLabel.layer.animatePosition(from: CGPoint(x: 0.0, y: -26.0), to: CGPoint(), duration: 0.2, additive: true)
            
            if let pickerView = self.pickerView {
                self.pickerView = nil
                pickerView.alpha = 0.0
                pickerView.layer.animateScale(from: 1.0, to: 0.25, duration: 0.15, removeOnCompletion: false)
                pickerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak pickerView] _ in
                    pickerView?.removeFromSuperview()
                })
                pickerView.isUserInteractionEnabled = false
            }
            
            self.timerNode.isHidden = false
            self.timerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            self.timerNode.animateIn()
            
            self.scheduleTextNode.alpha = 0.0
            self.scheduleTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
            
            self.updateTitle(slide: true, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
        
        private func transitionToCall() {
            self.updateIsFullscreen(false, force: true)
            
            self.listNode.alpha = 1.0
            self.listNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.listNode.isUserInteractionEnabled = true
            
            self.timerNode.alpha = 0.0
            self.timerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.timerNode.isHidden = true
            })
            
            if self.audioButton.isHidden {
                self.audioButton.isHidden = false
                self.audioButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.audioButton.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6, damping: 100.0)
            }
            
            self.updateTitle(transition: .animated(duration: 0.2, curve: .easeInOut))
        }
        
        @objc private func optionsPressed() {
            if self.optionsButton.isUserInteractionEnabled {
                self.optionsButton.contextAction?(self.optionsButton.containerNode, nil)
            }
        }
        
        @objc private func closePressed() {
            self.controller?.dismiss(closing: false)
            self.controller?.dismissAllTooltips()
        }
        
        @objc private func leavePressed() {
            self.hapticFeedback.impact(.light)
            self.controller?.dismissAllTooltips()
            
            if let callState = self.callState, callState.canManageCall {
                let isScheduled = callState.scheduleTimestamp != nil
                let action: () -> Void = { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }

                    strongSelf.leaveDisposable.set((strongSelf.call.leave(terminateIfPossible: true)
                    |> deliverOnMainQueue).start(completed: {
                        self?.controller?.dismiss()
                    }))
                }
                
                let actionSheet = ActionSheetController(presentationData: self.presentationData.withUpdated(theme: self.darkTheme))
                var items: [ActionSheetItem] = []
                
                items.append(ActionSheetTextItem(title: self.presentationData.strings.VoiceChat_LeaveConfirmation))
                items.append(ActionSheetButtonItem(title: isScheduled ? self.presentationData.strings.VoiceChat_LeaveAndCancelVoiceChat : self.presentationData.strings.VoiceChat_LeaveAndEndVoiceChat, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    if let strongSelf = self {
                        if let (members, _) = strongSelf.currentCallMembers, members.count >= 10 || true {
                            let alertController = textAlertController(context: strongSelf.context, forceTheme: strongSelf.darkTheme, title: isScheduled ? strongSelf.presentationData.strings.VoiceChat_CancelConfirmationTitle : strongSelf.presentationData.strings.VoiceChat_EndConfirmationTitle, text: isScheduled ? strongSelf.presentationData.strings.VoiceChat_CancelConfirmationText :  strongSelf.presentationData.strings.VoiceChat_EndConfirmationText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: isScheduled ? strongSelf.presentationData.strings.VoiceChat_CancelConfirmationEnd :  strongSelf.presentationData.strings.VoiceChat_EndConfirmationEnd, action: {
                                action()
                            })])
                            strongSelf.controller?.present(alertController, in: .window(.root))
                        } else {
                            action()
                        }
                    }
                }))
                items.append(ActionSheetButtonItem(title: self.presentationData.strings.VoiceChat_LeaveVoiceChat, color: .accent, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    strongSelf.leaveDisposable.set((strongSelf.call.leave(terminateIfPossible: false)
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        self?.controller?.dismiss(closing: true)
                    }))
                }))
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                self.controller?.present(actionSheet, in: .window(.root))
            } else {
                self.leaveDisposable.set((self.call.leave(terminateIfPossible: false)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    self?.controller?.dismiss(closing: true)
                }))
            }
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                if self.isScheduling {
                    self.dismissScheduled()
                } else {
                    self.controller?.dismiss(closing: false)
                    self.controller?.dismissAllTooltips()
                }
            }
        }
        
        private func presentUndoOverlay(content: UndoOverlayContent, action: @escaping (UndoOverlayAction) -> Bool) {
            var animateInAsReplacement = false
            self.controller?.forEachController { c in
                if let c = c as? UndoOverlayController {
                    animateInAsReplacement = true
                    c.dismiss()
                }
                return true
            }
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: content, elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: action), in: .current)
        }
        
        private func presentShare(_ inviteLinks: GroupCallInviteLinks) {
            let formatSendTitle: (String) -> String = { string in
                var string = string
                if string.contains("[") && string.contains("]") {
                    if let startIndex = string.firstIndex(of: "["), let endIndex = string.firstIndex(of: "]") {
                        string.removeSubrange(startIndex ... endIndex)
                    }
                } else {
                    string = string.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789-,."))
                }
                return string
            }
            
            let _ = (self.context.account.postbox.loadedPeerWithId(self.call.peerId)
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                if let strongSelf = self {
                    var inviteLinks = inviteLinks
                    
                    if let peer = peer as? TelegramChannel, case .group = peer.info, !peer.flags.contains(.isGigagroup), !(peer.addressName ?? "").isEmpty, let callState = strongSelf.callState, let defaultParticipantMuteState = callState.defaultParticipantMuteState {
                        let isMuted = defaultParticipantMuteState == .muted
                        
                        if !isMuted {
                            inviteLinks = GroupCallInviteLinks(listenerLink: inviteLinks.listenerLink, speakerLink: nil)
                        }
                    }
                    
                    let presentationData = strongSelf.presentationData
                    
                    var segmentedValues: [ShareControllerSegmentedValue]?
                    if let speakerLink = inviteLinks.speakerLink {
                        segmentedValues = [ShareControllerSegmentedValue(title: presentationData.strings.VoiceChat_InviteLink_Speaker, subject: .url(speakerLink), actionTitle: presentationData.strings.VoiceChat_InviteLink_CopySpeakerLink, formatSendTitle: { count in
                            return formatSendTitle(presentationData.strings.VoiceChat_InviteLink_InviteSpeakers(Int32(count)))
                        }), ShareControllerSegmentedValue(title: presentationData.strings.VoiceChat_InviteLink_Listener, subject: .url(inviteLinks.listenerLink), actionTitle: presentationData.strings.VoiceChat_InviteLink_CopyListenerLink, formatSendTitle: { count in
                            return formatSendTitle(presentationData.strings.VoiceChat_InviteLink_InviteListeners(Int32(count)))
                        })]
                    }
                    let shareController = ShareController(context: strongSelf.context, subject: .url(inviteLinks.listenerLink), segmentedValues: segmentedValues, forceTheme: strongSelf.darkTheme, forcedActionTitle: presentationData.strings.VoiceChat_CopyInviteLink)
                    shareController.completed = { [weak self] peerIds in
                        if let strongSelf = self {
                            let _ = (strongSelf.context.account.postbox.transaction { transaction -> [Peer] in
                                var peers: [Peer] = []
                                for peerId in peerIds {
                                    if let peer = transaction.getPeer(peerId) {
                                        peers.append(peer)
                                    }
                                }
                                return peers
                            } |> deliverOnMainQueue).start(next: { [weak self] peers in
                                if let strongSelf = self {
                                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                    
                                    let text: String
                                    var isSavedMessages = false
                                    if peers.count == 1, let peer = peers.first {
                                        isSavedMessages = peer.id == strongSelf.context.account.peerId
                                        let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        text = presentationData.strings.VoiceChat_ForwardTooltip_Chat(peerName).0
                                    } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                        let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        text = presentationData.strings.VoiceChat_ForwardTooltip_TwoChats(firstPeerName, secondPeerName).0
                                    } else if let peer = peers.first {
                                        let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        text = presentationData.strings.VoiceChat_ForwardTooltip_ManyChats(peerName, "\(peers.count - 1)").0
                                    } else {
                                        text = ""
                                    }
                                    
                                    strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: isSavedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                }
                            })
                        }
                    }
                    shareController.actionCompleted = { [weak self] in
                        if let strongSelf = self {
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.VoiceChat_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                        }
                    }
                    strongSelf.controller?.present(shareController, in: .window(.root))
                }
            })
        }
        
        private var pressTimer: SwiftSignalKit.Timer?
        private func startPressTimer() {
            self.pressTimer?.invalidate()
            let pressTimer = SwiftSignalKit.Timer(timeout: 0.185, repeat: false, completion: { [weak self] in
                self?.pressTimerFired()
                self?.pressTimer = nil
            }, queue: Queue.mainQueue())
            self.pressTimer = pressTimer
            pressTimer.start()
        }
        
        private func stopPressTimer() {
            self.pressTimer?.invalidate()
            self.pressTimer = nil
        }
        
        private func pressTimerFired() {
            guard let callState = self.callState else {
                return
            }
            if callState.muteState != nil {
                self.pushingToTalk = true
                self.call.setIsMuted(action: .muted(isPushToTalkActive: true))
            }
                        
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
            }
            
            self.updateMembers(muteState: self.effectiveMuteState, callMembers: self.currentCallMembers ?? ([], nil), invitedPeers: self.currentInvitedPeers ?? [], speakingPeers: self.currentSpeakingPeers ?? Set())
        }
        
        @objc private func actionButtonPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
            guard let callState = self.callState else {
                return
            }
            if case .connecting = callState.networkState, callState.scheduleTimestamp == nil && !self.isScheduling {
                return
            }
            if callState.scheduleTimestamp != nil || self.isScheduling {
                switch gestureRecognizer.state {
                    case .began:
                        self.actionButton.pressing = true
                        self.hapticFeedback.impact(.light)
                    case .ended, .cancelled:
                        self.actionButton.pressing = false
                        
                        let location = gestureRecognizer.location(in: self.actionButton.view)
                        if self.actionButton.hitTest(location, with: nil) != nil {
                            if self.isScheduling {
                                self.schedule()
                            } else if callState.canManageCall {
                                self.call.startScheduled()
                            } else {
                                if !callState.subscribedToScheduled {
                                    let location = self.actionButton.view.convert(self.actionButton.bounds, to: self.view).center
                                    let point = CGRect(origin: CGPoint(x: location.x - 5.0, y: location.y - 5.0 - 68.0), size: CGSize(width: 10.0, height: 10.0))
                                    self.controller?.present(TooltipScreen(text: self.presentationData.strings.VoiceChat_ReminderNotify, style: .gradient(UIColor(rgb: 0x262c5a), UIColor(rgb: 0x5d2835)), icon: nil, location: .point(point, .bottom), displayDuration: .custom(3.0), shouldDismissOnTouch: { _ in
                                        return .dismiss(consume: false)
                                    }), in: .window(.root))
                                }
                                self.call.toggleScheduledSubscription(!callState.subscribedToScheduled)
                            }
                        }
                    default:
                        break
                }
                return
            }
            if let muteState = callState.muteState {
                if !muteState.canUnmute {
                    switch gestureRecognizer.state {
                        case .began:
                            self.actionButton.pressing = true
                            self.hapticFeedback.impact(.light)
                        case .ended, .cancelled:
                            self.actionButton.pressing = false
                            
                            let location = gestureRecognizer.location(in: self.actionButton.view)
                            if self.actionButton.hitTest(location, with: nil) != nil {
                                self.call.raiseHand()
                                self.actionButton.playAnimation()
                            }
                        default:
                            break
                    }
                    return
                }
            }
            switch gestureRecognizer.state {
                case .began:
                    self.actionButton.pressing = true
                    self.hapticFeedback.impact(.light)
                    self.startPressTimer()
                    if let (layout, navigationHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
                    }
                case .ended, .cancelled:
                    self.pushingToTalk = false
                    self.actionButton.pressing = false
                    
                    if self.pressTimer != nil {
                        self.stopPressTimer()
                        self.call.toggleIsMuted()
                    } else {
                        self.hapticFeedback.impact(.light)
                        self.call.setIsMuted(action: .muted(isPushToTalkActive: false))
                    }
                    
                    if let callState = self.callState {
                        self.itemInteraction?.updateAudioLevels([(callState.myPeerId, 0, 0.0, false)], reset: true)
                    }
                                        
                    if let (layout, navigationHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
                    }
                    self.updateMembers(muteState: self.effectiveMuteState, callMembers: self.currentCallMembers ?? ([], nil), invitedPeers: self.currentInvitedPeers ?? [], speakingPeers: self.currentSpeakingPeers ?? Set())
                default:
                    break
            }
        }
        
        @objc private func actionButtonPressed() {
            if self.isScheduling {
                self.schedule()
            }
        }
        
        @objc private func audioOutputPressed() {
            self.hapticFeedback.impact(.light)
                        
            if let _ = self.callState?.scheduleTimestamp {
                if let callState = self.callState, let peer = self.peer, !callState.canManageCall && (peer.addressName?.isEmpty ?? true) {
                    return
                }
                
                let _ = (self.inviteLinksPromise.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] inviteLinks in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let callPeerId = strongSelf.call.peerId
                    let _ = (strongSelf.context.account.postbox.transaction { transaction -> GroupCallInviteLinks? in
                        if let inviteLinks = inviteLinks {
                            return inviteLinks
                        } else if let peer = transaction.getPeer(callPeerId), let addressName = peer.addressName, !addressName.isEmpty {
                            return GroupCallInviteLinks(listenerLink: "https://t.me/\(addressName)?voicechat", speakerLink: nil)
                        } else if let cachedData = transaction.getPeerCachedData(peerId: callPeerId) {
                            if let cachedData = cachedData as? CachedChannelData, let link = cachedData.exportedInvitation?.link {
                                return GroupCallInviteLinks(listenerLink: link, speakerLink: nil)
                            } else if let cachedData = cachedData as? CachedGroupData, let link = cachedData.exportedInvitation?.link {
                                return GroupCallInviteLinks(listenerLink: link, speakerLink: nil)
                            }
                        }
                        return nil
                    }
                    |> deliverOnMainQueue).start(next: { links in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        if let links = links {
                            strongSelf.presentShare(links)
                        }
                    })
                })
                return
            }
            
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
                let actionSheet = ActionSheetController(presentationData: self.presentationData.withUpdated(theme: self.darkTheme))
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
        
        @objc private func cameraPressed() {
            if self.call.isVideo {
                self.call.disableVideo()
            } else {
                self.call.requestVideo()
            }
        }
        
        @objc private func switchCameraPressed() {
            
        }
        
        private var effectiveBottomAreaHeight: CGFloat {
            switch self.displayMode {
                case .default:
                    return bottomAreaHeight
                case let .fullscreen(controlsHidden):
                    return controlsHidden ? 0.0 : fullscreenBottomAreaHeight
            }
        }
        
        private func updateFloatingHeaderOffset(offset: CGFloat, transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
            guard let (layout, _) = self.validLayout else {
                return
            }

            let layoutTopInset: CGFloat = max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top)
            let topPanelHeight: CGFloat = 63.0
            let listTopInset = layoutTopInset + topPanelHeight
            let bottomPanelHeight = self.effectiveBottomAreaHeight + layout.intrinsicInsets.bottom
            
            var size = layout.size
            if case .regular = layout.metrics.widthClass {
                size.width = floor(min(size.width, size.height) * 0.5)
            }
            
            let listSize = CGSize(width: size.width, height: layout.size.height - listTopInset - bottomPanelHeight)
            let topInset: CGFloat
            if let (panInitialTopInset, panOffset) = self.panGestureArguments {
                if self.isExpanded {
                    topInset = min(self.topInset ?? listSize.height, panInitialTopInset + max(0.0, panOffset))
                } else {
                    topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
                }
            } else if let currentTopInset = self.topInset {
                topInset = self.isExpanded ? 0.0 : currentTopInset
            } else {
                topInset = listSize.height - 46.0 - floor(56.0 * 3.5)
            }
            
            var bottomEdge: CGFloat = 0.0
            self.listNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ListViewItemNode {
                    let convertedFrame = self.listNode.view.convert(itemNode.frame, to: self.contentContainer.view)
                    if convertedFrame.maxY > bottomEdge {
                        bottomEdge = convertedFrame.maxY
                    }
                }
            }

            
            let offset = (bottomEdge.isZero ? 0.0 : offset) + topInset
            self.floatingHeaderOffset = offset
             
            if bottomEdge.isZero {
                bottomEdge = self.listNode.frame.minY + 46.0 + 56.0
            }
            
            let rawPanelOffset = offset + listTopInset - topPanelHeight
            let panelOffset = max(layoutTopInset, rawPanelOffset)
            let topPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: panelOffset), size: CGSize(width: size.width, height: topPanelHeight))
            
            if let mainVideoContainer = self.mainVideoContainer {
                let videoContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelFrame.maxY), size: CGSize(width: layout.size.width, height: min(300.0, layout.size.width)))
                transition.updateFrameAdditive(node: mainVideoContainer, frame: videoContainerFrame)
                mainVideoContainer.update(size: videoContainerFrame.size, transition: transition)
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelFrame.maxY), size: CGSize(width: size.width, height: layout.size.height))
            let sideInset: CGFloat = 16.0
            let leftBorderFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelFrame.maxY - 16.0), size: CGSize(width: sideInset, height: layout.size.height))
            let rightBorderFrame = CGRect(origin: CGPoint(x: size.width - sideInset, y: topPanelFrame.maxY - 16.0), size: CGSize(width: sideInset, height: layout.size.height))
            
            let previousTopPanelFrame = self.topPanelNode.frame
            let previousBackgroundFrame = self.backgroundNode.frame
            let previousLeftBorderFrame = self.leftBorderNode.frame
            let previousRightBorderFrame = self.rightBorderNode.frame
            
            if !topPanelFrame.equalTo(previousTopPanelFrame) {
                self.topPanelNode.frame = topPanelFrame
                let positionDelta = CGPoint(x: 0.0, y: topPanelFrame.minY - previousTopPanelFrame.minY)
                transition.animateOffsetAdditive(layer: self.topPanelNode.layer, offset: positionDelta.y, completion: completion)

                self.backgroundNode.frame = backgroundFrame
                let backgroundPositionDelta = CGPoint(x: 0.0, y: previousBackgroundFrame.minY - backgroundFrame.minY)
                transition.animatePositionAdditive(node: self.backgroundNode, offset: backgroundPositionDelta)
                
                self.leftBorderNode.frame = leftBorderFrame
                let leftBorderPositionDelta = CGPoint(x: 0.0, y: previousLeftBorderFrame.minY - leftBorderFrame.minY)
                transition.animatePositionAdditive(node: self.leftBorderNode, offset: leftBorderPositionDelta)
                
                self.rightBorderNode.frame = rightBorderFrame
                let rightBorderPositionDelta = CGPoint(x: 0.0, y: previousRightBorderFrame.minY - rightBorderFrame.minY)
                transition.animatePositionAdditive(node: self.rightBorderNode, offset: rightBorderPositionDelta)
            } else {
                completion?()
            }
            self.topPanelBackgroundNode.frame = CGRect(x: 0.0, y: topPanelHeight - 24.0, width: size.width, height: 24.0)
            
            let listMaxY = listTopInset + listSize.height
            let bottomOffset: CGFloat = min(0.0, bottomEdge - listMaxY)
            
            let bottomCornersFrame = CGRect(origin: CGPoint(x: sideInset, y: -50.0 + bottomOffset), size: CGSize(width: size.width - sideInset * 2.0, height: 50.0))
            let previousBottomCornersFrame = self.bottomCornersNode.frame
            if !bottomCornersFrame.equalTo(previousBottomCornersFrame) {
                self.bottomCornersNode.frame = bottomCornersFrame
                self.bottomPanelBackgroundNode.frame = CGRect(x: 0.0, y: bottomOffset, width: size.width, height: 2000.0)
                
                let positionDelta = CGPoint(x: 0.0, y: previousBottomCornersFrame.minY - bottomCornersFrame.minY)
                transition.animatePositionAdditive(node: self.bottomCornersNode, offset: positionDelta)
                transition.animatePositionAdditive(node: self.bottomPanelBackgroundNode, offset: positionDelta)
            }
        }
        
        var isFullscreen = false
        func updateIsFullscreen(_ isFullscreen: Bool, force: Bool = false) {
            guard self.isFullscreen != isFullscreen || force, let (layout, _) = self.validLayout else {
                return
            }
            self.isFullscreen = isFullscreen

            self.controller?.statusBar.updateStatusBarStyle(isFullscreen ? .White : .Ignore, animated: true)
                        
            var size = layout.size
            if case .regular = layout.metrics.widthClass {
                size.width = floor(min(size.width, size.height) * 0.5)
            }
            
            let topPanelHeight: CGFloat = 63.0
            let topEdgeFrame: CGRect
            if isFullscreen {
                let offset: CGFloat
                if let statusBarHeight = layout.statusBarHeight {
                    offset = statusBarHeight
                } else {
                    offset = 44.0
                }
                topEdgeFrame = CGRect(x: 0.0, y: -offset, width: size.width, height: topPanelHeight + offset)
            } else {
                topEdgeFrame = CGRect(x: 0.0, y: 0.0, width: size.width, height: topPanelHeight)
            }
            
            var isScheduled = false
            if self.isScheduling || self.callState?.scheduleTimestamp != nil {
                isScheduled = true
            }
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .linear)
            transition.updateFrame(node: self.topPanelEdgeNode, frame: topEdgeFrame)
            transition.updateCornerRadius(node: self.topPanelEdgeNode, cornerRadius: isFullscreen ? layout.deviceMetrics.screenCornerRadius - 0.5 : 12.0)
            transition.updateBackgroundColor(node: self.topPanelBackgroundNode, color: isFullscreen ? fullscreenBackgroundColor : panelBackgroundColor)
            transition.updateBackgroundColor(node: self.topPanelEdgeNode, color: isFullscreen ? fullscreenBackgroundColor : panelBackgroundColor)
            transition.updateBackgroundColor(node: self.backgroundNode, color: isFullscreen || isScheduled ? panelBackgroundColor : secondaryPanelBackgroundColor)
            transition.updateBackgroundColor(node: self.bottomPanelBackgroundNode, color: isFullscreen ? fullscreenBackgroundColor : panelBackgroundColor)
            transition.updateBackgroundColor(node: self.leftBorderNode, color: isFullscreen ? fullscreenBackgroundColor : panelBackgroundColor)
            transition.updateBackgroundColor(node: self.rightBorderNode, color: isFullscreen ? fullscreenBackgroundColor : panelBackgroundColor)
            
            if let snapshotView = self.topCornersNode.view.snapshotContentTree() {
                snapshotView.frame = self.topCornersNode.frame
                self.topPanelNode.view.addSubview(snapshotView)
                
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
            }
            self.topCornersNode.image = cornersImage(top: true, bottom: false, dark: isFullscreen)
            
            if let snapshotView = self.bottomCornersNode.view.snapshotContentTree() {
                snapshotView.frame = self.bottomCornersNode.bounds
                self.bottomCornersNode.view.addSubview(snapshotView)
                
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
            }
            self.bottomCornersNode.image = cornersImage(top: false, bottom: true, dark: isFullscreen)

            if !self.optionsButtonIsAvatar {
                self.optionsButton.setContent(.image(optionsButtonImage(dark: isFullscreen)), animated: transition.isAnimated)
            }
            self.closeButton.setContent(.image(closeButtonImage(dark: isFullscreen)), animated: transition.isAnimated)
            
            self.updateTitle(transition: transition)
        }
        
        private func updateTitle(slide: Bool = false, transition: ContainedViewLayoutTransition) {
            guard let (layout, _) = self.validLayout else {
                return
            }
            var title = self.currentTitle
            if self.isScheduling {
                title = self.presentationData.strings.ScheduleVoiceChat_Title
            } else if !self.isFullscreen && !self.currentTitleIsCustom {
                if let navigationController = self.controller?.navigationController as? NavigationController {
                    for controller in navigationController.viewControllers.reversed() {
                        if let controller = controller as? ChatController, case let .peer(peerId) = controller.chatLocation, peerId == self.call.peerId {
                            title = self.presentationData.strings.VoiceChat_Title
                        }
                    }
                }
            }
            
            var subtitle = self.currentSubtitle
            if self.isScheduling {
                subtitle = ""
            } else if self.callState?.scheduleTimestamp != nil {
                if self.callState?.canManageCall ?? false {
                    subtitle = self.presentationData.strings.VoiceChat_TapToEditTitle
                } else {
                    subtitle = self.presentationData.strings.VoiceChat_Scheduled
                }
            }
            
            var size = layout.size
            if case .regular = layout.metrics.widthClass {
                size.width = floor(min(size.width, size.height) * 0.5)
            }
            
            self.titleNode.update(size: CGSize(width: size.width, height: 44.0), title: title, subtitle: subtitle, slide: slide, transition: transition)
        }
        
        private func updateButtons(animated: Bool) {
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
            
            let coloredButtonAppearance: CallControllerButtonItemNode.Content.Appearance
            if let color = self.currentAudioButtonColor {
                coloredButtonAppearance = .color(.custom(color.rgb, 1.0))
            } else {
                coloredButtonAppearance = .color(.custom(self.isFullscreen ? 0x1c1c1e : 0x2c2c2e, 1.0))
            }
            
            var soundImage: CallControllerButtonItemNode.Content.Image
            var soundAppearance: CallControllerButtonItemNode.Content.Appearance = coloredButtonAppearance
            var soundTitle: String = self.presentationData.strings.Call_Speaker
            switch audioMode {
            case .none, .builtin:
                soundImage = .speaker
            case .speaker:
                soundImage = .speaker
                soundAppearance = .blurred(isFilled: true)
            case .headphones:
                soundImage = .headphones
                soundTitle = self.presentationData.strings.Call_Audio
            case let .bluetooth(type):
                switch type {
                case .generic:
                    soundImage = .bluetooth
                case .airpods:
                    soundImage = .airpods
                case .airpodsPro:
                    soundImage = .airpodsPro
                }
                soundTitle = self.presentationData.strings.Call_Audio
            }
                        
            let isScheduled = self.isScheduling || self.callState?.scheduleTimestamp != nil
            
            var soundEnabled = true
            if isScheduled {
                if let callState = self.callState, let peer = self.peer, !callState.canManageCall && (peer.addressName?.isEmpty ?? true) {
                    soundEnabled = false
                } else {
                    soundImage = .share
                    soundTitle = self.presentationData.strings.VoiceChat_ShareShort
                    soundAppearance = coloredButtonAppearance
                }
            }
            
            let videoButtonSize: CGSize
            var buttonsTitleAlpha: CGFloat
            switch self.displayMode {
                case .default:
                    videoButtonSize = smallButtonSize
                    buttonsTitleAlpha = 1.0
                case .fullscreen:
                    videoButtonSize = sideButtonSize
                    buttonsTitleAlpha = 0.0
            }
            
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .linear) : .immediate
            self.cameraButton.update(size: videoButtonSize, content: CallControllerButtonItemNode.Content(appearance: coloredButtonAppearance, image: .camera), text: self.presentationData.strings.VoiceChat_Video, transition: transition)
                    
            self.switchCameraButton.update(size: videoButtonSize, content: CallControllerButtonItemNode.Content(appearance: coloredButtonAppearance, image: .flipCamera), text: "", transition: transition)
            
            self.audioButton.update(size: sideButtonSize, content: CallControllerButtonItemNode.Content(appearance: soundAppearance, image: soundImage, isEnabled: soundEnabled), text: soundTitle, transition: transition)
            self.audioButton.isUserInteractionEnabled = soundEnabled
            
            self.leaveButton.update(size: sideButtonSize, content: CallControllerButtonItemNode.Content(appearance: .color(.custom(0xff3b30, 0.3)), image: .cancel), text: self.presentationData.strings.VoiceChat_Leave, transition: .immediate)
            
            transition.updateAlpha(node: self.cameraButton.textNode, alpha: 0.0)
            transition.updateAlpha(node: self.switchCameraButton.textNode, alpha: buttonsTitleAlpha)
            transition.updateAlpha(node: self.audioButton.textNode, alpha: buttonsTitleAlpha)
            transition.updateAlpha(node: self.leaveButton.textNode, alpha: buttonsTitleAlpha)
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let isFirstTime = self.validLayout == nil
            self.validLayout = (layout, navigationHeight)

            var size = layout.size
            if case .regular = layout.metrics.widthClass {
                size.width = floor(min(size.width, size.height) * 0.5)
            }
            
            self.updateTitle(transition: transition)
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 10.0), size: CGSize(width: size.width, height: 44.0)))
            transition.updateFrame(node: self.optionsButton, frame: CGRect(origin: CGPoint(x: 20.0, y: 18.0), size: CGSize(width: 28.0, height: 28.0)))
            transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: size.width - 20.0 - 28.0, y: 18.0), size: CGSize(width: 28.0, height: 28.0)))
            
            transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            transition.updateFrame(node: self.contentContainer, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - size.width) / 2.0), y: 0.0), size: size))
            
            let layoutTopInset: CGFloat = max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top)
            
            let sideInset: CGFloat = 16.0
            var insets = UIEdgeInsets()
            insets.left = layout.safeInsets.left + sideInset
            insets.right = layout.safeInsets.right + sideInset
            
            let topPanelHeight: CGFloat = 63.0
            if let _ = self.panGestureArguments {
            } else {
                let topEdgeFrame: CGRect
                if self.isFullscreen {
                    let offset: CGFloat
                    if let statusBarHeight = layout.statusBarHeight {
                        offset = statusBarHeight
                    } else {
                        offset = 44.0
                    }
                    topEdgeFrame = CGRect(x: 0.0, y: -offset, width: size.width, height: topPanelHeight + offset)
                } else {
                    topEdgeFrame = CGRect(x: 0.0, y: 0.0, width: size.width, height: topPanelHeight)
                }
                transition.updateFrame(node: self.topPanelEdgeNode, frame: topEdgeFrame)
            }
            
            let bottomPanelHeight = self.effectiveBottomAreaHeight + layout.intrinsicInsets.bottom
            var listTopInset = layoutTopInset + topPanelHeight
            if self.mainVideoContainer != nil {
                listTopInset += min(300.0, layout.size.width)
            }
            let listSize = CGSize(width: size.width, height: layout.size.height - listTopInset - bottomPanelHeight)
                 
            let topInset: CGFloat
            if let (panInitialTopInset, panOffset) = self.panGestureArguments {
                if self.isExpanded {
                    topInset = min(self.topInset ?? listSize.height, panInitialTopInset + max(0.0, panOffset))
                } else {
                    topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
                }
            } else if let currentTopInset = self.topInset {
                topInset = self.isExpanded ? 0.0 : currentTopInset
            } else {
                topInset = listSize.height - 46.0 - floor(56.0 * 3.5)
            }
            
            transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(x: 0.0, y: listTopInset + topInset), size: listSize))
            
            let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listSize, insets: insets, duration: duration, curve: curve)
            
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            
            transition.updateFrame(node: self.topCornersNode, frame: CGRect(origin: CGPoint(x: sideInset, y: 63.0), size: CGSize(width: size.width - sideInset * 2.0, height: 50.0)))
            
            let bottomPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomPanelHeight), size: CGSize(width: size.width, height: bottomPanelHeight))
            transition.updateFrame(node: self.bottomPanelNode, frame: bottomPanelFrame)
            
            if let pickerView = self.pickerView {
                transition.updateFrame(view: pickerView, frame: CGRect(x: 0.0, y: layout.size.height - bottomPanelHeight - 216.0, width: size.width, height: 216.0))
            }
            
            let timerFrame = CGRect(x: 0.0, y: layout.size.height - bottomPanelHeight - 216.0, width: size.width, height: 216.0)
            transition.updateFrame(node: self.timerNode, frame: timerFrame)
            self.timerNode.update(size: timerFrame.size, scheduleTime: self.callState?.scheduleTimestamp, transition: .immediate)
            
            let scheduleTextSize = self.scheduleTextNode.updateLayout(CGSize(width: size.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
            self.scheduleTextNode.frame = CGRect(origin: CGPoint(x: floor((size.width - scheduleTextSize.width) / 2.0), y: layout.size.height - layout.intrinsicInsets.bottom - scheduleTextSize.height - 145.0), size: scheduleTextSize)
            
            let centralButtonSide = min(size.width, size.height) - 32.0
            let centralButtonSize = CGSize(width: centralButtonSide, height: centralButtonSide)
            let cameraButtonSize = CGSize(width: 36.0, height: 36.0)
            let sideButtonMinimalInset: CGFloat = 16.0
            let sideButtonOffset = min(42.0, floor((((size.width - 112.0) / 2.0) - sideButtonSize.width) / 2.0))
            let sideButtonOrigin = max(sideButtonMinimalInset, floor((size.width - 112.0) / 2.0) - sideButtonOffset - sideButtonSize.width)
            
            let upperButtonDistance: CGFloat = 12.0
            let firstButtonFrame: CGRect
            let secondButtonFrame: CGRect
            let thirdButtonFrame: CGRect
            let forthButtonFrame: CGRect
            
            let leftButtonFrame: CGRect
            if self.mainVideoContainer == nil {
                leftButtonFrame = CGRect(origin: CGPoint(x: sideButtonOrigin, y: floor((self.effectiveBottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize)
            } else {
                leftButtonFrame = CGRect(origin: CGPoint(x: sideButtonOrigin, y: floor((self.effectiveBottomAreaHeight - sideButtonSize.height - upperButtonDistance - cameraButtonSize.height) / 2.0) + upperButtonDistance + cameraButtonSize.height), size: sideButtonSize)
            }
            let rightButtonFrame = CGRect(origin: CGPoint(x: size.width - sideButtonOrigin - sideButtonSize.width, y: floor((self.effectiveBottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize)
            
            let smallButtons: Bool
            switch self.displayMode {
                case .default:
                    smallButtons = false
                    firstButtonFrame = CGRect(origin: CGPoint(x: floor(leftButtonFrame.midX - cameraButtonSize.width / 2.0), y: leftButtonFrame.minY - upperButtonDistance - cameraButtonSize.height), size: cameraButtonSize)
                    secondButtonFrame = leftButtonFrame
                    thirdButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - centralButtonSize.width) / 2.0), y: floor((self.effectiveBottomAreaHeight - centralButtonSize.height) / 2.0) - 3.0), size: centralButtonSize)
                    forthButtonFrame = rightButtonFrame
                case let .fullscreen(controlsHidden):
                    smallButtons = true
                    let sideInset: CGFloat = 26.0
                    let spacing = floor((layout.size.width - sideInset * 2.0 - sideButtonSize.width * 4.0) / 3.0)
                    
                    firstButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: controlsHidden ? layout.size.height : floor((self.effectiveBottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize)
                    secondButtonFrame = CGRect(origin: CGPoint(x: sideInset + sideButtonSize.width + spacing, y: controlsHidden ? layout.size.height : floor((self.effectiveBottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize)
                    let thirdButtonPreFrame = CGRect(origin: CGPoint(x: layout.size.width - sideInset - sideButtonSize.width - spacing - sideButtonSize.width, y: controlsHidden ? layout.size.height : floor((self.effectiveBottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize)
                    thirdButtonFrame = CGRect(origin: CGPoint(x: floor(thirdButtonPreFrame.midX - centralButtonSize.width / 2.0), y: floor(thirdButtonPreFrame.midY - centralButtonSize.height / 2.0)), size: centralButtonSize)
                    forthButtonFrame = CGRect(origin: CGPoint(x: layout.size.width - sideInset - sideButtonSize.width, y: controlsHidden ? layout.size.height : floor((self.effectiveBottomAreaHeight - sideButtonSize.height) / 2.0)), size: sideButtonSize)
            }
            
            let actionButtonState: VoiceChatActionButton.State
            let actionButtonTitle: String
            let actionButtonSubtitle: String
            var actionButtonEnabled = true
            if let callState = self.callState, !self.isScheduling {
                if callState.scheduleTimestamp != nil {
                    self.ignoreConnecting = true
                    if callState.canManageCall {
                        actionButtonState = .scheduled(state: .start)
                        actionButtonTitle = self.presentationData.strings.VoiceChat_StartNow
                        actionButtonSubtitle = ""
                    } else {
                        if callState.subscribedToScheduled {
                            actionButtonState = .scheduled(state: .unsubscribe)
                            actionButtonTitle = self.presentationData.strings.VoiceChat_CancelReminder
                        } else {
                            actionButtonState = .scheduled(state: .subscribe)
                            actionButtonTitle = self.presentationData.strings.VoiceChat_SetReminder
                        }
                        actionButtonSubtitle = ""
                    }
                } else {
                    let connected = self.ignoreConnecting || callState.networkState == .connected
                    if case .connected = callState.networkState {
                        self.ignoreConnecting = false
                        self.ignoreConnectingTimer?.invalidate()
                        self.ignoreConnectingTimer = nil
                    } else if self.ignoreConnecting {
                        if self.ignoreConnectingTimer == nil {
                            let timer = SwiftSignalKit.Timer(timeout: 3.0, repeat: false, completion: { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.ignoreConnecting = false
                                    strongSelf.ignoreConnectingTimer?.invalidate()
                                    strongSelf.ignoreConnectingTimer = nil
                                    
                                    if let (layout, navigationHeight) = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                                    }
                                }
                            }, queue: Queue.mainQueue())
                            self.ignoreConnectingTimer = timer
                            timer.start()
                        }
                    }

                    if connected {
                        if let muteState = callState.muteState, !self.pushingToTalk {
                            if muteState.canUnmute {
                                actionButtonState = .active(state: .muted)
                                
                                actionButtonTitle = self.presentationData.strings.VoiceChat_Unmute
                                actionButtonSubtitle = ""
                            } else {
                                actionButtonState = .active(state: .cantSpeak)
                                
                                if callState.raisedHand {
                                    actionButtonTitle = self.presentationData.strings.VoiceChat_AskedToSpeak
                                    actionButtonSubtitle = self.presentationData.strings.VoiceChat_AskedToSpeakHelp
                                } else {
                                    actionButtonTitle = self.presentationData.strings.VoiceChat_MutedByAdmin
                                    actionButtonSubtitle = self.presentationData.strings.VoiceChat_MutedByAdminHelp
                                }
                            }
                        } else {
                            actionButtonState = .active(state: .on)
                            
                            actionButtonTitle = self.pushingToTalk ? self.presentationData.strings.VoiceChat_Live : self.presentationData.strings.VoiceChat_Mute
                            actionButtonSubtitle = ""
                        }
                    } else {
                        actionButtonState = .connecting
                        actionButtonTitle = self.presentationData.strings.VoiceChat_Connecting
                        actionButtonSubtitle = ""
                        actionButtonEnabled = false
                    }
                }
            } else {
                if self.isScheduling {
                    actionButtonState = .button(text: self.scheduleButtonTitle)
                    actionButtonTitle = ""
                    actionButtonSubtitle = ""
                    actionButtonEnabled = true
                } else {
                    actionButtonState = .connecting
                    actionButtonTitle = self.presentationData.strings.VoiceChat_Connecting
                    actionButtonSubtitle = ""
                    actionButtonEnabled = false
                }
            }
            
            self.actionButton.isDisabled = !actionButtonEnabled
            self.actionButton.update(size: centralButtonSize, buttonSize: CGSize(width: 112.0, height: 112.0), state: actionButtonState, title: actionButtonTitle, subtitle: actionButtonSubtitle, dark: self.isFullscreen, small: smallButtons, animated: true)
            
            let buttonHeight = self.scheduleCancelButton.updateLayout(width: size.width - 32.0, transition: .immediate)
            self.scheduleCancelButton.frame = CGRect(x: 16.0, y: 137.0, width: size.width - 32.0, height: buttonHeight)
            
            if self.actionButton.supernode === self.bottomPanelNode {
                transition.updateFrame(node: self.actionButton, frame: thirdButtonFrame)
            }
            
            self.updateButtons(animated: !isFirstTime)
            
            /*var currentVideoOrigin = CGPoint(x: 4.0, y: (layout.statusBarHeight ?? 0.0) + 4.0)
            for (_, _, videoNode) in self.videoNodes {
                let videoSize = CGSize(width: 300.0, height: 500.0)
                if currentVideoOrigin.x + videoSize.width > layout.size.width {
                    currentVideoOrigin.x = 0.0
                    currentVideoOrigin.y += videoSize.height
                }
                
                videoNode.frame = CGRect(origin: currentVideoOrigin, size: videoSize)
                videoNode.updateLayout(size: videoSize, transition: .immediate)
                if videoNode.supernode == nil {
                    self.contentContainer.addSubnode(videoNode)
                }
                 
                currentVideoOrigin.x += videoSize.width + 4.0
            }*/
            
            if self.audioButton.supernode === self.bottomPanelNode {
                transition.updateFrame(node: self.cameraButton, frame: firstButtonFrame)
                transition.updateFrame(node: self.switchCameraButton, frame: firstButtonFrame)
                transition.updateFrame(node: self.audioButton, frame: secondButtonFrame)
                transition.updateFrame(node: self.leaveButton, frame: forthButtonFrame)
            }
            if isFirstTime {
                while !self.enqueuedTransitions.isEmpty {
                    self.dequeueTransition()
                }
            }
        }
        
        func animateIn() {
            guard let (layout, navigationHeight) = self.validLayout else {
                return
            }
            self.updateFloatingHeaderOffset(offset: 0.0, transition: .immediate)
            
            self.animatingAppearance = true
            
            let initialBounds = self.contentContainer.bounds
            let topPanelFrame = self.topPanelNode.view.convert(self.topPanelNode.bounds, to: self.view)
            self.contentContainer.bounds = initialBounds.offsetBy(dx: 0.0, dy: -(layout.size.height - topPanelFrame.minY))
            self.contentContainer.isHidden = false
            
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView({
                self.contentContainer.view.bounds = initialBounds
            }, completion: { _ in
                self.animatingAppearance = false
                if self.actionButton.supernode !== self.bottomPanelNode {
                    self.actionButton.ignoreHierarchyChanges = true
                    self.audioButton.isHidden = false
                    self.cameraButton.isHidden = false
                    self.leaveButton.isHidden = false
                    self.audioButton.layer.removeAllAnimations()
                    self.cameraButton.layer.removeAllAnimations()
                    self.leaveButton.layer.removeAllAnimations()
                    self.bottomPanelNode.addSubnode(self.audioButton)
                    //self.bottomPanelNode.addSubnode(self.cameraButtonNode)
                    self.bottomPanelNode.addSubnode(self.leaveButton)
                    self.bottomPanelNode.addSubnode(self.actionButton)
                    self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                    self.actionButton.ignoreHierarchyChanges = false
                }
                
                self.controller?.currentOverlayController?.dismiss()
                self.controller?.currentOverlayController = nil
            })
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        
        func animateOut(completion: (() -> Void)?) {
            guard let (layout, _) = self.validLayout else {
                return
            }
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
            
            let topPanelFrame = self.topPanelNode.view.convert(self.topPanelNode.bounds, to: self.view)
            self.contentContainer.layer.animateBoundsOriginYAdditive(from: self.contentContainer.bounds.origin.y, to: -(layout.size.height - topPanelFrame.minY) - 44.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
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
        
        private func dequeueTransition() {
            guard let (layout, _) = self.validLayout, let transition = self.enqueuedTransitions.first else {
                return
            }
            self.enqueuedTransitions.remove(at: 0)
            
            if let callState = self.callState {
                if callState.scheduleTimestamp != nil && self.listNode.alpha > 0.0 {
                    self.timerNode.isHidden = false
                    self.listNode.alpha = 0.0
                    self.listNode.isUserInteractionEnabled = false
                    self.backgroundNode.backgroundColor = panelBackgroundColor
                    self.updateIsFullscreen(false)
                } else if callState.scheduleTimestamp == nil && !self.isScheduling && self.listNode.alpha == 0.0 {
                    self.transitionToCall()
                }
            }
            
            var options = ListViewDeleteAndInsertOptions()
            let isFirstTime = self.isFirstTime
            if isFirstTime {
                self.isFirstTime = false
            } else {
                if transition.crossFade {
                    options.insert(.AnimateCrossfade)
                }
                if transition.animated {
                    options.insert(.AnimateInsertion)
                }
            }
            options.insert(.LowLatency)
            options.insert(.PreferSynchronousResourceLoading)
            
            var itemsHeight: CGFloat = 0.0
            var itemsCount = transition.count
            if transition.canInvite {
                itemsHeight += 46.0
                itemsCount -= 1
            }
            itemsHeight += CGFloat(itemsCount) * 56.0
           
            let layoutTopInset: CGFloat = max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top)
            
            let sideInset: CGFloat = 16.0
            var insets = UIEdgeInsets()
            insets.left = layout.safeInsets.left + sideInset
            insets.right = layout.safeInsets.right + sideInset
            
            var size = layout.size
            if case .regular = layout.metrics.widthClass {
                size.width = floor(min(size.width, size.height) * 0.5)
            }
            
            let bottomPanelHeight = self.effectiveBottomAreaHeight + layout.intrinsicInsets.bottom
            let listTopInset = layoutTopInset + 63.0
            let listSize = CGSize(width: size.width, height: layout.size.height - listTopInset - bottomPanelHeight)
            
            self.topInset = listSize.height - 46.0 - floor(56.0 * 3.5)
            
            let targetY = listTopInset + (self.topInset ?? listSize.height)
            
            if isFirstTime {
                var frame = self.listNode.frame
                frame.origin.y = targetY
                self.listNode.frame = frame
            }
                
            
            if transition.animated {
                self.animatingInsertion = true
            }
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: nil, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                if isFirstTime {
                    strongSelf.updateFloatingHeaderOffset(offset: strongSelf.currentContentOffset ?? 0.0, transition: .immediate)
                } else if strongSelf.animatingInsertion {
                    strongSelf.updateFloatingHeaderOffset(offset: strongSelf.currentContentOffset ?? 0.0, transition: .animated(duration: 0.2, curve: .easeInOut))
                }
                strongSelf.animatingInsertion = false
                if !strongSelf.didSetContentsReady {
                    strongSelf.didSetContentsReady = true
                    strongSelf.controller?.contentsReady.set(true)
                }
            })
        }
        
        private func updateMembers(muteState: GroupCallParticipantsContext.Participant.MuteState?, callMembers: ([GroupCallParticipantsContext.Participant], String?), invitedPeers: [Peer], speakingPeers: Set<PeerId>) {
            var disableAnimation = false
            if self.currentCallMembers?.1 != callMembers.1 {
                disableAnimation = true
            }
            
            self.currentCallMembers = callMembers
            self.currentSpeakingPeers = speakingPeers
            self.currentInvitedPeers = invitedPeers
            
            
            var entries: [ListEntry] = []
            var index: Int32 = 0
            var processedPeerIds = Set<PeerId>()
            
            var canInvite = true
            var inviteIsLink = false
            if let peer = self.peer as? TelegramChannel {
                if peer.flags.contains(.isGigagroup) || (peer.addressName?.isEmpty ?? true) {
                    if peer.flags.contains(.isCreator) || peer.adminRights != nil {
                    } else {
                        canInvite = false
                    }
                }
                if case .broadcast = peer.info, !(peer.addressName?.isEmpty ?? true) {
                    inviteIsLink = true
                }
            }
            if canInvite {
                entries.append(.invite(self.presentationData.theme, self.presentationData.strings, inviteIsLink ? self.presentationData.strings.VoiceChat_Share : self.presentationData.strings.VoiceChat_InviteMember, inviteIsLink))
            }
            
            for member in callMembers.0 {
                if processedPeerIds.contains(member.peer.id) {
                    continue
                }
                processedPeerIds.insert(member.peer.id)
                
                let memberState: PeerEntry.State
                var memberMuteState: GroupCallParticipantsContext.Participant.MuteState?
                if member.hasRaiseHand && !(member.muteState?.canUnmute ?? false) {
                    memberState = .raisedHand
                    memberMuteState = member.muteState
                    
                    if self.raisedHandDisplayDisposables[member.peer.id] == nil {
                        var displayedRaisedHands = self.displayedRaisedHands
                        displayedRaisedHands.insert(member.peer.id)
                        self.displayedRaisedHands = displayedRaisedHands
                        
                        let signal: Signal<Never, NoError> = Signal.complete() |> delay(3.0, queue: Queue.mainQueue())
                        self.raisedHandDisplayDisposables[member.peer.id] = signal.start(completed: { [weak self] in
                            if let strongSelf = self {
                                var displayedRaisedHands = strongSelf.displayedRaisedHands
                                displayedRaisedHands.remove(member.peer.id)
                                strongSelf.displayedRaisedHands = displayedRaisedHands
                                
                                strongSelf.updateMembers(muteState: strongSelf.effectiveMuteState, callMembers: strongSelf.currentCallMembers ?? ([], nil), invitedPeers: strongSelf.currentInvitedPeers ?? [], speakingPeers: strongSelf.currentSpeakingPeers ?? Set())
                            }
                        })
                    }
                } else {
                    if member.peer.id == self.callState?.myPeerId {
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
                    
                    if let disposable = self.raisedHandDisplayDisposables[member.peer.id] {
                        disposable.dispose()
                        self.raisedHandDisplayDisposables[member.peer.id] = nil
                    }
                }
                
                var memberPeer = member.peer
                if member.peer.id == self.callState?.myPeerId, let user = memberPeer as? TelegramUser, let photo = self.currentUpdatingAvatar {
                    memberPeer = user.withUpdatedPhoto([photo])
                }
                                
                entries.append(.peer(PeerEntry(
                    peer: memberPeer,
                    about: member.about,
                    isMyPeer: self.callState?.myPeerId == member.peer.id,
                    ssrc: member.ssrc,
                    presence: nil,
                    activityTimestamp: Int32.max - 1 - index,
                    state: memberState,
                    muteState: memberMuteState,
                    canManageCall: self.callState?.canManageCall ?? false,
                    volume: member.volume,
                    raisedHand: member.hasRaiseHand,
                    displayRaisedHandStatus: self.displayedRaisedHands.contains(member.peer.id)
                )))
                index += 1
            }
            
            for peer in invitedPeers {
                if processedPeerIds.contains(peer.id) {
                    continue
                }
                processedPeerIds.insert(peer.id)
                
                entries.append(.peer(PeerEntry(
                    peer: peer,
                    about: nil,
                    isMyPeer: false,
                    ssrc: nil,
                    presence: nil,
                    activityTimestamp: Int32.max - 1 - index,
                    state: .invited,
                    muteState: nil,
                    canManageCall: false,
                    volume: nil,
                    raisedHand: false,
                    displayRaisedHandStatus: false
                )))
                index += 1
            }
            
            guard self.didSetDataReady else {
                return
            }
          
            let previousEntries = self.currentEntries
            self.currentEntries = entries
            
            if previousEntries.count == entries.count {
                var allEqual = true
                for i in 0 ..< previousEntries.count {
                    if previousEntries[i].stableId != entries[i].stableId {
                        if case let .peer(lhsPeer) = previousEntries[i], case let .peer(rhsPeer) = entries[i] {
                            if lhsPeer.isMyPeer != rhsPeer.isMyPeer {
                                allEqual = false
                                break
                            }
                        } else {
                            allEqual = false
                            break
                        }
                    }
                }
                if allEqual {
                    disableAnimation = true
                }
            } else if abs(previousEntries.count - entries.count) > 10 {
                disableAnimation = true
            }
        
            let presentationData = self.presentationData.withUpdated(theme: self.darkTheme)
            let transition = preparedTransition(from: previousEntries, to: entries, isLoading: false, isEmpty: false, canInvite: canInvite, crossFade: false, animated: !disableAnimation, context: self.context, presentationData: presentationData, interaction: self.itemInteraction!)
            self.enqueueTransition(transition)
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UILongPressGestureRecognizer {
                return !self.isScheduling
            } else if gestureRecognizer is DirectionalPanGestureRecognizer {
                let location = gestureRecognizer.location(in: self.bottomPanelNode.view)
                let containerLocation = gestureRecognizer.location(in: self.contentContainer.view)
                if self.audioButton.frame.contains(location) || (!self.cameraButton.isHidden && self.cameraButton.frame.contains(location)) || self.leaveButton.frame.contains(location) || self.pickerView?.frame.contains(containerLocation) == true {
                    return false
                }
            }
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        private var isExpanded = false {
            didSet {
                self.itemInteraction?.isExpanded = self.isExpanded
            }
        }
        
        private var animatingInsertion = false
        private var animatingExpansion = false
        private var animatingAppearance = false
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat)?
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            let contentOffset = self.listNode.visibleContentOffset()
            let isScheduling = self.isScheduling || self.callState?.scheduleTimestamp != nil
            switch recognizer.state {
                case .began:
                    let topInset: CGFloat
                    if self.isExpanded {
                        topInset = 0.0
                    } else if let currentTopInset = self.topInset {
                        topInset = currentTopInset
                    } else {
                        topInset = self.listNode.frame.height
                    }
                    self.panGestureArguments = (topInset, 0.0)
                    
                    self.controller?.dismissAllTooltips()
                case .changed:
                    var translation = recognizer.translation(in: self.contentContainer.view).y
                    if isScheduling && translation < 0.0 {
                        return
                    }
                    var topInset: CGFloat = 0.0
                    if let (currentTopInset, currentPanOffset) = self.panGestureArguments {
                        topInset = currentTopInset
                        
                        if case let .known(value) = contentOffset, value <= 0.5 {
                        } else {
                            translation = currentPanOffset
                            if self.isExpanded {
                                recognizer.setTranslation(CGPoint(), in: self.contentContainer.view)
                            }
                        }
                        
                        self.panGestureArguments = (currentTopInset, translation)
                    }
                
                    let currentOffset = topInset + translation
                    if currentOffset < 20.0 {
                        self.updateIsFullscreen(true)
                    } else if currentOffset > 40.0 {
                        self.updateIsFullscreen(false)
                    }
                
                    if self.isExpanded {
                    } else {
                        if currentOffset > 0.0 {
                            self.listNode.scroller.panGestureRecognizer.setTranslation(CGPoint(), in: self.listNode.scroller)
                        }
                    }
                    
                    if let (layout, navigationHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                        self.updateFloatingHeaderOffset(offset: self.currentContentOffset ?? 0.0, transition: .immediate)
                    }
                    
                    if !self.isExpanded {
                        var bounds = self.contentContainer.bounds
                        bounds.origin.y = -translation
                        bounds.origin.y = min(0.0, bounds.origin.y)
                        self.contentContainer.bounds = bounds
                    }
                case .ended:
                    let translation = recognizer.translation(in: self.contentContainer.view)
                    var velocity = recognizer.velocity(in: self.contentContainer.view)
                    
                    if case let .known(value) = contentOffset, value > 0.0 {
                        velocity = CGPoint()
                    } else if case .unknown = contentOffset {
                        velocity = CGPoint()
                    }
                    
                    var bounds = self.contentContainer.bounds
                    bounds.origin.y = -translation.y
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    
                    let offset: CGFloat
                    if let (inset, panOffset) = self.panGestureArguments {
                        offset = inset + panOffset
                    } else {
                        offset = 0.0
                    }
                    
                    let topInset: CGFloat
                    if let currentTopInset = self.topInset {
                        topInset = currentTopInset
                    } else {
                        topInset = self.listNode.frame.height
                    }
                    
                    if self.isExpanded {
                        self.panGestureArguments = nil
                        if velocity.y > 300.0 || offset > topInset / 2.0 {
                            self.isExpanded = false
                            self.updateIsFullscreen(false)
                            self.animatingExpansion = true
                            self.listNode.scroller.setContentOffset(CGPoint(), animated: false)
                            
                            if let (layout, navigationHeight) = self.validLayout {
                                self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                            }
                            self.updateFloatingHeaderOffset(offset: self.currentContentOffset ?? 0.0, transition: .animated(duration: 0.3, curve: .easeInOut), completion: {
                                self.animatingExpansion = false
                            })
                        } else {
                            self.updateIsFullscreen(true)
                            self.animatingExpansion = true
                            
                            if let (layout, navigationHeight) = self.validLayout {
                                self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                            }
                            self.updateFloatingHeaderOffset(offset: self.currentContentOffset ?? 0.0, transition: .animated(duration: 0.3, curve: .easeInOut), completion: {
                                self.animatingExpansion = false
                            })
                        }
                    } else {
                        self.panGestureArguments = nil
                        var dismissing = false
                        if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) {
                            if self.isScheduling {
                                self.dismissScheduled()
                            } else {
                                self.controller?.dismiss(closing: false, manual: true)
                            }
                            dismissing = true
                        } else if !isScheduling && (velocity.y < -300.0 || offset < topInset / 2.0) {
                            if velocity.y > -1500.0 && !self.isFullscreen {
                                DispatchQueue.main.async {
                                    self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                                }
                            }
                            
                            self.isExpanded = true
                            self.updateIsFullscreen(true)
                            self.animatingExpansion = true
                            
                            if let (layout, navigationHeight) = self.validLayout {
                                self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                            }
                            self.updateFloatingHeaderOffset(offset: self.currentContentOffset ?? 0.0, transition: .animated(duration: 0.3, curve: .easeInOut), completion: {
                                self.animatingExpansion = false
                            })
                        } else if !isScheduling {
                            self.updateIsFullscreen(false)
                            self.animatingExpansion = true
                            self.listNode.scroller.setContentOffset(CGPoint(), animated: false)
                                                        
                            if let (layout, navigationHeight) = self.validLayout {
                                self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                            }
                            self.updateFloatingHeaderOffset(offset: self.currentContentOffset ?? 0.0, transition: .animated(duration: 0.3, curve: .easeInOut), completion: {
                                self.animatingExpansion = false
                            })
                        }
                        if !dismissing {
                            var bounds = self.contentContainer.bounds
                            let previousBounds = bounds
                            bounds.origin.y = 0.0
                            self.contentContainer.bounds = bounds
                            self.contentContainer.layer.animateBounds(from: previousBounds, to: self.contentContainer.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                        }
                    }
                case .cancelled:
                    self.panGestureArguments = nil
                    
                    let previousBounds = self.contentContainer.bounds
                    var bounds = self.contentContainer.bounds
                    bounds.origin.y = 0.0
                    self.contentContainer.bounds = bounds
                    self.contentContainer.layer.animateBounds(from: previousBounds, to: self.contentContainer.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    
                    if let (layout, navigationHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                    }
                    self.updateFloatingHeaderOffset(offset: self.currentContentOffset ?? 0.0, transition: .animated(duration: 0.3, curve: .easeInOut), completion: {
                        self.animatingExpansion = false
                    })
                default:
                    break
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            
            if let result = result {
                for (_, _, videoNode) in self.videoNodes {
                    if videoNode.view === result || result.isDescendant(of: videoNode.view) {
                        return result
                    }
                }
            }

            if result === self.topPanelNode.view {
                return self.view
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
        
        fileprivate func scrollToTop() {
            if self.isExpanded {
                self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            }
        }
        
        private func openTitleEditing() {
            let _ = (self.context.account.postbox.loadedPeerWithId(self.call.peerId)
            |> deliverOnMainQueue).start(next: { [weak self] chatPeer in
                guard let strongSelf = self else {
                    return
                }
                
                let initialTitle = strongSelf.callState?.title ?? ""
                let controller = voiceChatTitleEditController(sharedContext: strongSelf.context.sharedContext, account: strongSelf.context.account, forceTheme: strongSelf.darkTheme, title: strongSelf.presentationData.strings.VoiceChat_EditTitleTitle, text: strongSelf.presentationData.strings.VoiceChat_EditTitleText, placeholder: chatPeer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), value: initialTitle, maxLength: 40, apply: { title in
                    if let strongSelf = self, let title = title, title != initialTitle {
                        strongSelf.call.updateTitle(title)

                        strongSelf.presentUndoOverlay(content: .voiceChatFlag(text: title.isEmpty ? strongSelf.presentationData.strings.VoiceChat_EditTitleRemoveSuccess : strongSelf.presentationData.strings.VoiceChat_EditTitleSuccess(title).0), action: { _ in return false })
                    }
                })
                strongSelf.controller?.present(controller, in: .window(.root))
            })
        }
        
        private func openAvatarForEditing(fromGallery: Bool = false, completion: @escaping () -> Void = {}) {
            guard let peerId = self.callState?.myPeerId else {
                return
            }
            
            let _ = (self.context.account.postbox.transaction { transaction -> (Peer?, SearchBotsConfiguration) in
                return (transaction.getPeer(peerId), currentSearchBotsConfiguration(transaction: transaction))
            }
            |> deliverOnMainQueue).start(next: { [weak self] peer, searchBotsConfiguration in
                guard let strongSelf = self, let peer = peer else {
                    return
                }
                
                let presentationData = strongSelf.presentationData
                
                let legacyController = LegacyController(presentation: .custom, theme: strongSelf.darkTheme)
                legacyController.statusBar.statusBarStyle = .Ignore
                
                let emptyController = LegacyEmptyController(context: legacyController.context)!
                let navigationController = makeLegacyNavigationController(rootController: emptyController)
                navigationController.setNavigationBarHidden(true, animated: false)
                navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
                
                legacyController.bind(controller: navigationController)
                
                strongSelf.view.endEditing(true)
                strongSelf.controller?.present(legacyController, in: .window(.root))
                
                var hasPhotos = false
                if !peer.profileImageRepresentations.isEmpty {
                    hasPhotos = true
                }
                
                let paintStickersContext = LegacyPaintStickersContext(context: strongSelf.context)
//                paintStickersContext.presentStickersController = { completion in
//                    let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
//                        let coder = PostboxEncoder()
//                        coder.encodeRootObject(fileReference.media)
//                        completion?(coder.makeData(), fileReference.media.isAnimatedSticker, node.view, rect)
//                        return true
//                    })
//                    strongSelf.controller?.present(controller, in: .window(.root))
//                    return controller
//                }
                
                let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: hasPhotos && !fromGallery, hasViewButton: false, personalPhoto: peerId.namespace == Namespaces.Peer.CloudUser, isVideo: false, saveEditedPhotos: false, saveCapturedMedia: false, signup: false)!
                mixin.forceDark = true
                mixin.stickersContext = paintStickersContext
                let _ = strongSelf.currentAvatarMixin.swap(mixin)
                mixin.requestSearchController = { [weak self] assetsController in
                    guard let strongSelf = self else {
                        return
                    }
                    let controller = WebSearchController(context: strongSelf.context, peer: peer, chatLocation: nil, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: peer.id.namespace == Namespaces.Peer.CloudUser ? nil : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), completion: { [weak self] result in
                        assetsController?.dismiss()
                        self?.updateProfilePhoto(result)
                    }))
                    controller.navigationPresentation = .modal
                    strongSelf.controller?.push(controller)
                    
                    if fromGallery {
                        completion()
                    }
                }
                mixin.didFinishWithImage = { [weak self] image in
                    if let image = image {
                        completion()
                       self?.updateProfilePhoto(image)
                    }
                }
                mixin.didFinishWithVideo = { [weak self] image, asset, adjustments in
                    if let image = image, let asset = asset {
                        completion()
                        self?.updateProfileVideo(image, asset: asset, adjustments: adjustments)
                    }
                }
                mixin.didFinishWithDelete = {
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let proceed = {
                        let _ = strongSelf.currentAvatarMixin.swap(nil)
                        let postbox = strongSelf.context.account.postbox
                        strongSelf.updateAvatarDisposable.set((updatePeerPhoto(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, stateManager: strongSelf.context.account.stateManager, accountPeerId: strongSelf.context.account.peerId, peerId: peerId, photo: nil, mapResourceToAvatarSizes: { resource, representations in
                            return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
                        })
                        |> deliverOnMainQueue).start())
                    }
                    
                    let actionSheet = ActionSheetController(presentationData: presentationData.withUpdated(theme: strongSelf.darkTheme))
                    let items: [ActionSheetItem] = [
                        ActionSheetButtonItem(title: presentationData.strings.Settings_RemoveConfirmation, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            proceed()
                        })
                    ]
                    
                    actionSheet.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])
                    ])
                    strongSelf.controller?.present(actionSheet, in: .window(.root))
                }
                mixin.didDismiss = { [weak legacyController] in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = strongSelf.currentAvatarMixin.swap(nil)
                    legacyController?.dismiss()
                }
                let menuController = mixin.present()
                if let menuController = menuController {
                    menuController.customRemoveFromParentViewController = { [weak legacyController] in
                        legacyController?.dismiss()
                    }
                }
            })
        }
        
        private func updateProfilePhoto(_ image: UIImage) {
            guard let data = image.jpegData(compressionQuality: 0.6), let peerId = self.callState?.myPeerId else {
                return
            }
            
            let resource = LocalFileMediaResource(fileId: arc4random64())
            self.call.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
            let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)
            
            self.currentUpdatingAvatar = representation
            self.updateAvatarPromise.set(.single((representation, 0.0)))

            let postbox = self.call.account.postbox
            let signal = peerId.namespace == Namespaces.Peer.CloudUser ? updateAccountPhoto(account: self.call.account, resource: resource, videoResource: nil, videoStartTimestamp: nil, mapResourceToAvatarSizes: { resource, representations in
                return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
            }) : updatePeerPhoto(postbox: postbox, network: self.call.account.network, stateManager: self.call.account.stateManager, accountPeerId: self.context.account.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: postbox, network: self.call.account.network, resource: resource), mapResourceToAvatarSizes: { resource, representations in
                return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
            })
            
            self.updateAvatarDisposable.set((signal
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                    case .complete:
                        strongSelf.updateAvatarPromise.set(.single(nil))
                    case let .progress(value):
                        strongSelf.updateAvatarPromise.set(.single((representation, value)))
                }
            }))
            
            self.updateMembers(muteState: self.effectiveMuteState, callMembers: self.currentCallMembers ?? ([], nil), invitedPeers: self.currentInvitedPeers ?? [], speakingPeers: self.currentSpeakingPeers ?? Set())
        }
        
        private func updateProfileVideo(_ image: UIImage, asset: Any?, adjustments: TGVideoEditAdjustments?) {
            guard let data = image.jpegData(compressionQuality: 0.6), let peerId = self.callState?.myPeerId else {
                return
            }
            
            let photoResource = LocalFileMediaResource(fileId: arc4random64())
            self.context.account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
            let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: photoResource, progressiveSizes: [], immediateThumbnailData: nil)
            
            self.currentUpdatingAvatar = representation
            self.updateAvatarPromise.set(.single((representation, 0.0)))

            var videoStartTimestamp: Double? = nil
            if let adjustments = adjustments, adjustments.videoStartValue > 0.0 {
                videoStartTimestamp = adjustments.videoStartValue - adjustments.trimStartValue
            }
            
            let account = self.context.account
            let signal = Signal<TelegramMediaResource, UploadPeerPhotoError> { [weak self] subscriber in
                let entityRenderer: LegacyPaintEntityRenderer? = adjustments.flatMap { adjustments in
                    if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
                        return LegacyPaintEntityRenderer(account: account, adjustments: adjustments)
                    } else {
                        return nil
                    }
                }
                let uploadInterface = LegacyLiveUploadInterface(account: account)
                let signal: SSignal
                if let asset = asset as? AVAsset {
                    signal = TGMediaVideoConverter.convert(asset, adjustments: adjustments, watcher: uploadInterface, entityRenderer: entityRenderer)!
                } else if let url = asset as? URL, let data = try? Data(contentsOf: url, options: [.mappedRead]), let image = UIImage(data: data), let entityRenderer = entityRenderer {
                    let durationSignal: SSignal = SSignal(generator: { subscriber in
                        let disposable = (entityRenderer.duration()).start(next: { duration in
                            subscriber?.putNext(duration)
                            subscriber?.putCompletion()
                        })
                        
                        return SBlockDisposable(block: {
                            disposable.dispose()
                        })
                    })
                    signal = durationSignal.map(toSignal: { duration -> SSignal? in
                        if let duration = duration as? Double {
                            return TGMediaVideoConverter.renderUIImage(image, duration: duration, adjustments: adjustments, watcher: nil, entityRenderer: entityRenderer)!
                        } else {
                            return SSignal.single(nil)
                        }
                    })
                   
                } else {
                    signal = SSignal.complete()
                }
                
                let signalDisposable = signal.start(next: { next in
                    if let result = next as? TGMediaVideoConversionResult {
                        if let image = result.coverImage, let data = image.jpegData(compressionQuality: 0.7) {
                            account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
                        }
                        
                        if let timestamp = videoStartTimestamp {
                            videoStartTimestamp = max(0.0, min(timestamp, result.duration - 0.05))
                        }
                        
                        var value = stat()
                        if stat(result.fileURL.path, &value) == 0 {
                            if let data = try? Data(contentsOf: result.fileURL) {
                                let resource: TelegramMediaResource
                                if let liveUploadData = result.liveUploadData as? LegacyLiveUploadInterfaceResult {
                                    resource = LocalFileMediaResource(fileId: liveUploadData.id)
                                } else {
                                    resource = LocalFileMediaResource(fileId: arc4random64())
                                }
                                account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                                subscriber.putNext(resource)
                            }
                        }
                        subscriber.putCompletion()
                    } else if let strongSelf = self, let progress = next as? NSNumber {
                        Queue.mainQueue().async {
                            strongSelf.updateAvatarPromise.set(.single((representation, Float(truncating: progress) * 0.25)))
                        }
                    }
                }, error: { _ in
                }, completed: nil)
                
                let disposable = ActionDisposable {
                    signalDisposable?.dispose()
                }
                
                return ActionDisposable {
                    disposable.dispose()
                }
            }
            
            self.updateAvatarDisposable.set((signal
            |> mapToSignal { videoResource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                if peerId.namespace == Namespaces.Peer.CloudUser {
                    return updateAccountPhoto(account: account, resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                    })
                } else {
                    return updatePeerPhoto(postbox: account.postbox, network: account.network, stateManager: account.stateManager, accountPeerId: account.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: account.postbox, network: account.network, resource: photoResource), video: uploadedPeerVideo(postbox: account.postbox, network: account.network, messageMediaPreuploadManager: account.messageMediaPreuploadManager, resource: videoResource) |> map(Optional.init), videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                    })
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                    case .complete:
                        strongSelf.updateAvatarPromise.set(.single(nil))
                    case let .progress(value):
                        strongSelf.updateAvatarPromise.set(.single((representation, 0.25 + value * 0.75)))
                }
            }))
        }
    }
    
    private let sharedContext: SharedAccountContext
    public let call: PresentationGroupCall
    private let presentationData: PresentationData
    public var parentNavigationController: NavigationController?
        
    fileprivate let contentsReady = ValuePromise<Bool>(false, ignoreRepeated: true)
    fileprivate let dataReady = ValuePromise<Bool>(false, ignoreRepeated: true)
    fileprivate let audioOutputStateReady = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    private var reclaimActionButton: (() -> Void)?
    
    private var didAppearOnce: Bool = false
    private var isDismissed: Bool = false
    private var isDisconnected: Bool = false
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private let idleTimerExtensionDisposable = MetaDisposable()
    
    public weak var currentOverlayController: VoiceChatOverlayController?
    
    private var validLayout: ContainerViewLayout?
    
    public init(sharedContext: SharedAccountContext, accountContext: AccountContext, call: PresentationGroupCall) {
        self.sharedContext = sharedContext
        self.call = call
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
                 
        self.statusBar.statusBarStyle = .Ignore
        
        self._ready.set(combineLatest([
            self.contentsReady.get(),
            self.dataReady.get(),
            self.audioOutputStateReady.get()
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
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.idleTimerExtensionDisposable.dispose()
        
        if let currentOverlayController = self.currentOverlayController {
            currentOverlayController.animateOut(reclaim: false, completion: { _ in })
        }
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
            
            self.reclaimActionButton?()
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
        
        DispatchQueue.main.async {
            self.didAppearOnce = false
            self.isDismissed = true
            self.detachActionButton()
            self.onViewDidDisappear?()
        }
    }
        
    private var dismissedManually: Bool = false
    public func dismiss(closing: Bool, manual: Bool = false) {
        if closing {
            self.isDisconnected = true
        } else {
            if let navigationController = self.navigationController as? NavigationController {
                let count = navigationController.viewControllers.count
                if count == 2 || navigationController.viewControllers[count - 2] is ChatController {
                    if case .active(.cantSpeak) = self.controllerNode.actionButton.stateValue {
                    } else if case .button = self.controllerNode.actionButton.stateValue {
                    } else if case .scheduled = self.controllerNode.actionButton.stateValue {
                    } else if let chatController = navigationController.viewControllers[count - 2] as? ChatController, chatController.isSendButtonVisible {
                    } else if let tabBarController = navigationController.viewControllers[count - 2] as? TabBarController, let chatListController = tabBarController.controllers[tabBarController.selectedIndex] as? ChatListController, chatListController.isSearchActive {
                    } else {
                        if manual {
                            self.dismissedManually = true
                            Queue.mainQueue().after(0.05) {
                                self.detachActionButton()
                            }
                        } else {
                            self.detachActionButton()
                        }
                    }
                }
            }
        }
        
        self.dismiss()
    }
    
    private func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        })
    }
    
    private func detachActionButton() {
        guard self.currentOverlayController == nil && !self.isDisconnected else {
            return
        }
        
        let overlayController = VoiceChatOverlayController(actionButton: self.controllerNode.actionButton, audioOutputNode: self.controllerNode.audioButton, leaveNode: self.controllerNode.leaveButton, navigationController: self.navigationController as? NavigationController, initiallyHidden: self.dismissedManually)
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.presentOverlay(controller: overlayController, inGlobal: true, blockInteraction: false)
        }
        
        self.currentOverlayController = overlayController
        self.dismissedManually = false
        
        self.reclaimActionButton = { [weak self, weak overlayController] in
            if let strongSelf = self {
                overlayController?.animateOut(reclaim: true, completion: { immediate in
                    if let strongSelf = self, immediate {
                        strongSelf.controllerNode.actionButton.ignoreHierarchyChanges = true
                        strongSelf.controllerNode.bottomPanelNode.addSubnode(strongSelf.controllerNode.actionButton)
                        strongSelf.controllerNode.bottomPanelNode.addSubnode(strongSelf.controllerNode.audioButton)
                        strongSelf.controllerNode.bottomPanelNode.addSubnode(strongSelf.controllerNode.leaveButton)
                        
                        if immediate, let layout = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                        }
                        strongSelf.controllerNode.actionButton.ignoreHierarchyChanges = false
                    }
                })
                strongSelf.reclaimActionButton = nil
            }
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
        self.validLayout = layout
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class VoiceChatContextExtractedContentSource: ContextExtractedContentSource {
    var keepInPlace: Bool
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    var centerVertically: Bool
    var shouldBeDismissed: Signal<Bool, NoError>
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool, blurBackground: Bool, centerVertically: Bool, shouldBeDismissed: Signal<Bool, NoError>) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.keepInPlace = keepInPlace
        self.blurBackground = blurBackground
        self.centerVertically = centerVertically
        self.shouldBeDismissed = shouldBeDismissed
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class VoiceChatContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
