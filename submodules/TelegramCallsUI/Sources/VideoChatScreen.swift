import Foundation
import AVFoundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import ViewControllerComponent
import Postbox
import TelegramCore
import AccountContext
import PlainButtonComponent
import SwiftSignalKit
import LottieComponent
import BundleIconComponent
import ContextUI
import TelegramPresentationData
import DeviceAccess
import TelegramVoip
import PresentationDataUtils
import UndoUI
import ShareController
import AvatarNode
import TelegramAudio
import LegacyComponents
import TooltipUI

extension VideoChatCall {    
    var myAudioLevelAndSpeaking: Signal<(Float, Bool), NoError> {
        switch self {
        case let .group(group):
            return group.myAudioLevelAndSpeaking
        case let .conferenceSource(conferenceSource):
            return conferenceSource.audioLevel |> map { value in
                return (value, false)
            }
        }
    }
    
    var audioLevels: Signal<[(EnginePeer.Id, UInt32, Float, Bool)], NoError> {
        switch self {
        case let .group(group):
            return group.audioLevels
        case let .conferenceSource(conferenceSource):
            let peerId = conferenceSource.peerId
            return conferenceSource.audioLevel |> map { value in
                return [(peerId, 0, value, false)]
            }
        }
    }
    
    func video(endpointId: String) -> Signal<OngoingGroupCallContext.VideoFrameData, NoError>? {
        switch self {
        case let .group(group):
            return (group as! PresentationGroupCallImpl).video(endpointId: endpointId)
        case let .conferenceSource(conferenceSource):
            if endpointId == "temp-local" {
                return (conferenceSource as! PresentationCallImpl).video(isIncoming: false)
            } else {
                return (conferenceSource as! PresentationCallImpl).video(isIncoming: true)
            }
        }
    }
    
    func loadMoreMembers(token: String) {
        switch self {
        case let .group(group):
            group.loadMoreMembers(token: token)
        case .conferenceSource:
            break
        }
    }
    
    func setRequestedVideoList(items: [PresentationGroupCallRequestedVideo]) {
        switch self {
        case let .group(group):
            group.setRequestedVideoList(items: items)
        case .conferenceSource:
            break
        }
    }
    
    var hasVideo: Bool {
        switch self {
        case let .group(group):
            return group.hasVideo
        case let .conferenceSource(conferenceSource):
            return (conferenceSource as! PresentationCallImpl).hasVideo
        }
    }
    
    var hasScreencast: Bool {
        switch self {
        case let .group(group):
            return group.hasScreencast
        case let .conferenceSource(conferenceSource):
            return (conferenceSource as! PresentationCallImpl).hasScreencast
        }
    }
    
    func disableVideo() {
        switch self {
        case let .group(group):
            group.disableVideo()
        case let .conferenceSource(conferenceSource):
            conferenceSource.disableVideo()
        }
    }
    
    func disableScreencast() {
        switch self {
        case let .group(group):
            group.disableScreencast()
        case let .conferenceSource(conferenceSource):
            (conferenceSource as! PresentationCallImpl).disableScreencast()
        }
    }
    
    func setIsMuted(action: PresentationGroupCallMuteAction) {
        switch self {
        case let .group(group):
            group.setIsMuted(action: action)
        case let .conferenceSource(conferenceSource):
            switch action {
            case .unmuted:
                conferenceSource.setIsMuted(false)
            case let .muted(isPushToTalkActive):
                conferenceSource.setIsMuted(!isPushToTalkActive)
            }
        }
    }
    
    func requestVideo(capturer: OngoingCallVideoCapturer, useFrontCamera: Bool) {
        switch self {
        case let .group(groupCall):
            (groupCall as! PresentationGroupCallImpl).requestVideo(capturer: capturer, useFrontCamera: useFrontCamera)
        case let .conferenceSource(conferenceSource):
            (conferenceSource as! PresentationCallImpl).requestVideo(capturer: capturer)
        }
    }
    
    func setCurrentAudioOutput(_ output: AudioSessionOutput) {
        switch self {
        case let .group(group):
            group.setCurrentAudioOutput(output)
        case let .conferenceSource(conferenceSource):
            conferenceSource.setCurrentAudioOutput(output)
        }
    }
}

final class VideoChatScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let initialData: VideoChatScreenV2Impl.InitialData
    let initialCall: VideoChatCall

    init(
        initialData: VideoChatScreenV2Impl.InitialData,
        initialCall: VideoChatCall
    ) {
        self.initialData = initialData
        self.initialCall = initialCall
    }

    static func ==(lhs: VideoChatScreenComponent, rhs: VideoChatScreenComponent) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.initialData !== rhs.initialData {
            return false
        }
        if lhs.initialCall != rhs.initialCall {
            return false
        }
        
        return true
    }
    
    private final class PanState {
        var fraction: CGFloat
        weak var scrollView: UIScrollView?
        var startContentOffsetY: CGFloat = 0.0
        var accumulatedOffset: CGFloat = 0.0
        var dismissedTooltips: Bool = false
        var didLockScrolling: Bool = false
        var contentOffset: CGFloat?
        
        init(fraction: CGFloat, scrollView: UIScrollView?) {
            self.fraction = fraction
            self.scrollView = scrollView
        }
    }
    
    struct InvitedPeer: Equatable {
        var peer: EnginePeer
        var state: PresentationGroupCallInvitedPeer.State?
        
        init(peer: EnginePeer, state: PresentationGroupCallInvitedPeer.State?) {
            self.peer = peer
            self.state = state
        }
    }

    final class View: UIView, UIGestureRecognizerDelegate {
        let containerView: UIView
        
        var component: VideoChatScreenComponent?
        var environment: ViewControllerComponentContainer.Environment?
        weak var state: EmptyComponentState?
        var isUpdating: Bool = false
        
        private var verticalPanState: PanState?
        var notifyDismissedInteractivelyOnPanGestureApply: Bool = false
        var completionOnPanGestureApply: (() -> Void)?
        
        let videoRenderingContext = VideoRenderingContext()
        
        let title = ComponentView<Empty>()
        let navigationLeftButton = ComponentView<Empty>()
        let navigationRightButton = ComponentView<Empty>()
        var navigationSidebarButton: ComponentView<Empty>?
        
        let videoButton = ComponentView<Empty>()
        let leaveButton = ComponentView<Empty>()
        let microphoneButton = ComponentView<Empty>()
        
        let participants = ComponentView<Empty>()
        var scheduleInfo: ComponentView<Empty>?
        
        var reconnectedAsEventsDisposable: Disposable?
        var memberEventsDisposable: Disposable?
        
        var currentCall: VideoChatCall?
        var appliedCurrentCall: VideoChatCall?
        
        var peer: EnginePeer?
        var callState: PresentationGroupCallState?
        var stateDisposable: Disposable?
        var conferenceCallStateDisposable: Disposable?
        
        var audioOutputState: ([AudioSessionOutput], AudioSessionOutput?)?
        var audioOutputStateDisposable: Disposable?
        
        var displayAsPeers: [FoundPeer]?
        var displayAsPeersDisposable: Disposable?
        
        var inviteLinks: GroupCallInviteLinks?
        var inviteLinksDisposable: Disposable?
        
        var isPushToTalkActive: Bool = false
        
        var members: PresentationGroupCallMembers?
        var membersDisposable: Disposable?
        
        var invitedPeers: [InvitedPeer] = []
        var invitedPeersDisposable: Disposable?
        
        var speakingParticipantPeers: [EnginePeer] = []
        var visibleParticipants: Set<EnginePeer.Id> = Set()
        
        let isPresentedValue = ValuePromise<Bool>(false, ignoreRepeated: true)
        var applicationStateDisposable: Disposable?
        
        var expandedParticipantsVideoState: VideoChatParticipantsComponent.ExpandedVideoState?
        var focusedSpeakerAutoSwitchDeadline: Double = 0.0
        var isTwoColumnSidebarHidden: Bool = false
        
        var isAnimatedOutFromPrivateCall: Bool = false
        
        let inviteDisposable = MetaDisposable()
        let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
        let updateAvatarDisposable = MetaDisposable()
        var currentUpdatingAvatar: (TelegramMediaImageRepresentation, Float)?
        
        var maxVideoQuality: Int = Int.max
        
        override init(frame: CGRect) {
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.backgroundColor = nil
            self.isOpaque = false
            
            self.addSubview(self.containerView)
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panGestureRecognizer.delegate = self
            self.addGestureRecognizer(panGestureRecognizer)
            
            self.verticalPanState = PanState(fraction: 1.0, scrollView: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stateDisposable?.dispose()
            self.membersDisposable?.dispose()
            self.invitedPeersDisposable?.dispose()
            self.applicationStateDisposable?.dispose()
            self.reconnectedAsEventsDisposable?.dispose()
            self.memberEventsDisposable?.dispose()
            self.displayAsPeersDisposable?.dispose()
            self.audioOutputStateDisposable?.dispose()
            self.inviteLinksDisposable?.dispose()
            self.updateAvatarDisposable.dispose()
            self.inviteDisposable.dispose()
            self.conferenceCallStateDisposable?.dispose()
        }
        
        func animateIn() {
            self.verticalPanState = PanState(fraction: 1.0, scrollView: nil)
            self.state?.updated(transition: .immediate)
            
            self.verticalPanState = nil
            self.state?.updated(transition: .spring(duration: 0.5))
        }
        
        func animateIn(sourceCallController: CallController) {
            var isAnimationFinished = false
            var sourceCallControllerAnimatedOut: (() -> Void)?
            let animateOutData = sourceCallController.animateOutToGroupChat(completion: {
                isAnimationFinished = true
                sourceCallControllerAnimatedOut?()
            })
            let sourceCallControllerView = animateOutData?.containerView
            sourceCallControllerView?.isUserInteractionEnabled = false
            sourceCallControllerAnimatedOut = { [weak sourceCallControllerView] in
                sourceCallControllerView?.removeFromSuperview()
            }
            
            var expandedPeer: (id: EnginePeer.Id, isPresentation: Bool)?
            if let animateOutData, animateOutData.incomingVideoLayer != nil, let members = self.members {
                if let participant = members.participants.first(where: { $0.peer.id == animateOutData.incomingPeerId }) {
                    if let _ = participant.videoDescription {
                        expandedPeer = (participant.peer.id, false)
                        self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: false), isMainParticipantPinned: false, isUIHidden: true)
                    }
                } else if let participant = members.participants.first(where: { $0.peer.id == sourceCallController.call.context.account.peerId }) {
                    if let _ = participant.videoDescription {
                        expandedPeer = (participant.peer.id, false)
                        self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: false), isMainParticipantPinned: false, isUIHidden: true)
                    }
                }
            }
            
            self.isAnimatedOutFromPrivateCall = true
            self.verticalPanState = nil
            
            self.state?.updated(transition: .immediate)
            
            if !isAnimationFinished, let sourceCallControllerView {
                if let participantsView = self.participants.view {
                    self.containerView.insertSubview(sourceCallControllerView, belowSubview: participantsView)
                } else {
                    self.containerView.addSubview(sourceCallControllerView)
                }
            }
            
            let transition: ComponentTransition = .spring(duration: 0.4)
            let alphaTransition: ComponentTransition = .easeInOut(duration: 0.25)
            
            self.isAnimatedOutFromPrivateCall = false
            self.expandedParticipantsVideoState = nil
            self.state?.updated(transition: transition)
            
            if let animateOutData, let expandedPeer, let incomingVideoLayer = animateOutData.incomingVideoLayer, let participantsView = self.participants.view as? VideoChatParticipantsComponent.View, let targetFrame = participantsView.itemFrame(peerId: expandedPeer.id, isPresentation: expandedPeer.isPresentation) {
                if let incomingVideoPlaceholder = animateOutData.incomingVideoPlaceholder {
                    participantsView.updateItemPlaceholder(peerId: expandedPeer.id, isPresentation: expandedPeer.isPresentation, placeholder: incomingVideoPlaceholder)
                }
                
                let incomingVideoLayerFrame = incomingVideoLayer.convert(incomingVideoLayer.frame, to: sourceCallControllerView?.layer)
                
                let targetContainer = SimpleLayer()
                targetContainer.masksToBounds = true
                targetContainer.backgroundColor = UIColor.blue.cgColor
                targetContainer.cornerRadius = 10.0
                
                self.containerView.layer.insertSublayer(targetContainer, above: participantsView.layer)
                
                targetContainer.frame = incomingVideoLayerFrame
                
                targetContainer.addSublayer(incomingVideoLayer)
                incomingVideoLayer.position = CGRect(origin: CGPoint(), size: incomingVideoLayerFrame.size).center
                let sourceFitScale = max(incomingVideoLayerFrame.width / incomingVideoLayerFrame.width, incomingVideoLayerFrame.height / incomingVideoLayerFrame.height)
                incomingVideoLayer.transform = CATransform3DMakeScale(sourceFitScale, sourceFitScale, 1.0)
                
                let targetFrame = participantsView.convert(targetFrame, to: self)
                let targetFitScale = min(incomingVideoLayerFrame.width / targetFrame.width, incomingVideoLayerFrame.height / targetFrame.height)
                
                transition.setFrame(layer: targetContainer, frame: targetFrame, completion: { [weak targetContainer] _ in
                    targetContainer?.removeFromSuperlayer()
                })
                transition.setTransform(layer: incomingVideoLayer, transform: CATransform3DMakeScale(targetFitScale, targetFitScale, 1.0))
                alphaTransition.setAlpha(layer: targetContainer, alpha: 0.0)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.verticalPanState = PanState(fraction: 1.0, scrollView: nil)
            self.completionOnPanGestureApply = completion
            self.state?.updated(transition: .spring(duration: 0.5))
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            
            return result
        }
        
        @objc func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UITapGestureRecognizer {
                if otherGestureRecognizer is UIPanGestureRecognizer {
                    return true
                }
                return false
            } else {
                return false
            }
        }
        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer {
                if let otherGestureRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer {
                    if otherGestureRecognizer.view is UIScrollView {
                        return true
                    }
                    if let participantsView = self.participants.view as? VideoChatParticipantsComponent.View {
                        if otherGestureRecognizer.view === participantsView {
                            return true
                        }
                    }
                }
                return false
            } else {
                return false
            }
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                if !self.bounds.height.isZero && !self.notifyDismissedInteractivelyOnPanGestureApply {
                    let translation = recognizer.translation(in: self)
                    let fraction = max(0.0, translation.y / self.bounds.height)
                    if let verticalPanState = self.verticalPanState {
                        verticalPanState.fraction = fraction
                    } else {
                        var targetScrollView: UIScrollView?
                        if case .began = recognizer.state, let participantsView = self.participants.view as? VideoChatParticipantsComponent.View {
                            if let hitResult = participantsView.hitTest(self.convert(recognizer.location(in: self), to: participantsView), with: nil) {
                                func findTargetScrollView(target: UIView, minParent: UIView) -> UIScrollView? {
                                    if target === participantsView {
                                        return nil
                                    }
                                    if let target = target as? UIScrollView {
                                        return target
                                    }
                                    if let parent = target.superview {
                                        return findTargetScrollView(target: parent, minParent: minParent)
                                    } else {
                                        return nil
                                    }
                                }
                                targetScrollView = findTargetScrollView(target: hitResult, minParent: participantsView)
                            }
                        }
                        self.verticalPanState = PanState(fraction: fraction, scrollView: targetScrollView)
                        if let targetScrollView {
                            self.verticalPanState?.contentOffset = targetScrollView.contentOffset.y
                            self.verticalPanState?.startContentOffsetY = recognizer.translation(in: self).y
                        }
                    }
                    
                    if let verticalPanState = self.verticalPanState {
                        /*if abs(verticalPanState.fraction) >= 0.1 && !verticalPanState.dismissedTooltips {
                            verticalPanState.dismissedTooltips = true
                            self.dismissAllTooltips()
                        }*/
                        
                        if let scrollView = verticalPanState.scrollView {
                            let relativeTranslationY = recognizer.translation(in: self).y - verticalPanState.startContentOffsetY
                            let overflowY = scrollView.contentOffset.y - relativeTranslationY
                            
                            if !verticalPanState.didLockScrolling {
                                if scrollView.contentOffset.y == 0.0 {
                                    verticalPanState.didLockScrolling = true
                                }
                                if let previousContentOffset = verticalPanState.contentOffset, (previousContentOffset < 0.0) != (scrollView.contentOffset.y < 0.0) {
                                    verticalPanState.didLockScrolling = true
                                }
                            }
                            
                            var resetContentOffset = false
                            if verticalPanState.didLockScrolling {
                                verticalPanState.accumulatedOffset += -overflowY
                                
                                if verticalPanState.accumulatedOffset < 0.0 {
                                    verticalPanState.accumulatedOffset = 0.0
                                }
                                if scrollView.contentOffset.y < 0.0 {
                                    resetContentOffset = true
                                }
                            } else {
                                verticalPanState.accumulatedOffset += -overflowY
                                verticalPanState.accumulatedOffset = max(0.0, verticalPanState.accumulatedOffset)
                            }
                            
                            if verticalPanState.accumulatedOffset > 0.0 || resetContentOffset {
                                scrollView.contentOffset = CGPoint()
                                
                                if let participantsView = self.participants.view as? VideoChatParticipantsComponent.View {
                                    let eventCycleState = VideoChatParticipantsComponent.EventCycleState()
                                    eventCycleState.ignoreScrolling = true
                                    participantsView.setEventCycleState(scrollView: scrollView, eventCycleState: eventCycleState)
                                    
                                    DispatchQueue.main.async { [weak scrollView, weak participantsView] in
                                        guard let participantsView, let scrollView else {
                                            return
                                        }
                                        participantsView.setEventCycleState(scrollView: scrollView, eventCycleState: nil)
                                    }
                                }
                            }
                            
                            verticalPanState.contentOffset = scrollView.contentOffset.y
                            verticalPanState.startContentOffsetY = recognizer.translation(in: self).y
                        }
                        
                        self.state?.updated(transition: .immediate)
                    }
                }
            case .cancelled, .ended:
                if !self.bounds.height.isZero, let verticalPanState = self.verticalPanState {
                    let translation = recognizer.translation(in: self)
                    verticalPanState.fraction = max(0.0, translation.y / self.bounds.height)
                    
                    let effectiveFraction: CGFloat
                    if verticalPanState.scrollView != nil {
                        effectiveFraction = verticalPanState.accumulatedOffset / self.bounds.height
                    } else {
                        effectiveFraction = verticalPanState.fraction
                    }
                    
                    let velocity = recognizer.velocity(in: self)
                    
                    self.verticalPanState = nil
                    if effectiveFraction > 0.6 || (effectiveFraction > 0.0 && velocity.y >= 100.0) {
                        self.verticalPanState = PanState(fraction: effectiveFraction < 0.0 ? -1.0 : 1.0, scrollView: nil)
                        self.notifyDismissedInteractivelyOnPanGestureApply = true
                        if let controller = self.environment?.controller() as? VideoChatScreenV2Impl {
                            controller.notifyDismissed()
                        }
                    }
                    
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
            default:
                break
            }
        }
        
        func openTitleEditing() {
            guard case let .group(groupCall) = self.currentCall else {
                return
            }
            guard let peerId = groupCall.peerId else {
                return
            }
            
            let _ = (groupCall.accountContext.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { [weak self] chatPeer in
                guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                    return
                }
                guard let callState = self.callState, let peer = self.peer else {
                    return
                }
                
                let initialTitle = callState.title

                let title: String
                let text: String
                if case let .channel(channel) = peer, case .broadcast = channel.info {
                    title = environment.strings.LiveStream_EditTitle
                    text = environment.strings.LiveStream_EditTitleText
                } else {
                    title = environment.strings.VoiceChat_EditTitle
                    text = environment.strings.VoiceChat_EditTitleText
                }

                let controller = voiceChatTitleEditController(sharedContext: groupCall.accountContext.sharedContext, account: groupCall.accountContext.account, forceTheme: environment.theme, title: title, text: text, placeholder: EnginePeer(chatPeer).displayTitle(strings: environment.strings, displayOrder: groupCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder), value: initialTitle, maxLength: 40, apply: { [weak self] title in
                    guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                        return
                    }
                    guard let title = title, title != initialTitle else {
                        return
                    }
                    
                    groupCall.updateTitle(title)

                    let text: String
                    if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                        text = title.isEmpty ? environment.strings.LiveStream_EditTitleRemoveSuccess : environment.strings.LiveStream_EditTitleSuccess(title).string
                    } else {
                        text = title.isEmpty ? environment.strings.VoiceChat_EditTitleRemoveSuccess : environment.strings.VoiceChat_EditTitleSuccess(title).string
                    }

                    self.presentUndoOverlay(content: .voiceChatFlag(text: text), action: { _ in return false })
                })
                environment.controller()?.present(controller, in: .window(.root))
            })
        }
        
        func presentUndoOverlay(content: UndoOverlayContent, action: @escaping (UndoOverlayAction) -> Bool) {
            guard let environment = self.environment, let currentCall = self.currentCall else {
                return
            }
            var animateInAsReplacement = false
            environment.controller()?.forEachController { c in
                if let c = c as? UndoOverlayController {
                    animateInAsReplacement = true
                    c.dismiss()
                }
                return true
            }
            let presentationData = currentCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
            environment.controller()?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: action), in: .current)
        }
        
        func presentShare(_ inviteLinks: GroupCallInviteLinks) {
            guard case let .group(groupCall) = self.currentCall else {
                return
            }
            guard let peerId = groupCall.peerId else {
                return
            }
            
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
            
            let _ = (groupCall.accountContext.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                    return
                }
                guard let peer = self.peer else {
                    return
                }
                guard let callState = self.callState else {
                    return
                }
                var inviteLinks = inviteLinks
                
                if case let .channel(peer) = peer, case .group = peer.info, !peer.flags.contains(.isGigagroup), !(peer.addressName ?? "").isEmpty, let defaultParticipantMuteState = callState.defaultParticipantMuteState {
                    let isMuted = defaultParticipantMuteState == .muted
                    
                    if !isMuted {
                        inviteLinks = GroupCallInviteLinks(listenerLink: inviteLinks.listenerLink, speakerLink: nil)
                    }
                }
                
                var segmentedValues: [ShareControllerSegmentedValue]?
                if let speakerLink = inviteLinks.speakerLink {
                    segmentedValues = [ShareControllerSegmentedValue(title: environment.strings.VoiceChat_InviteLink_Speaker, subject: .url(speakerLink), actionTitle: environment.strings.VoiceChat_InviteLink_CopySpeakerLink, formatSendTitle: { count in
                        return formatSendTitle(environment.strings.VoiceChat_InviteLink_InviteSpeakers(Int32(count)))
                    }), ShareControllerSegmentedValue(title: environment.strings.VoiceChat_InviteLink_Listener, subject: .url(inviteLinks.listenerLink), actionTitle: environment.strings.VoiceChat_InviteLink_CopyListenerLink, formatSendTitle: { count in
                        return formatSendTitle(environment.strings.VoiceChat_InviteLink_InviteListeners(Int32(count)))
                    })]
                }
                let shareController = ShareController(context: groupCall.accountContext, subject: .url(inviteLinks.listenerLink), segmentedValues: segmentedValues, forceTheme: environment.theme, forcedActionTitle: environment.strings.VoiceChat_CopyInviteLink)
                shareController.completed = { [weak self] peerIds in
                    guard let self, case let .group(groupCall) = self.currentCall else {
                        return
                    }
                    let _ = (groupCall.accountContext.engine.data.get(
                        EngineDataList(
                            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                        )
                    )
                    |> deliverOnMainQueue).start(next: { [weak self] peerList in
                        guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                            return
                        }
                        
                        let peers = peerList.compactMap { $0 }
                        let presentationData = groupCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                        
                        let text: String
                        var isSavedMessages = false
                        if peers.count == 1, let peer = peers.first {
                            isSavedMessages = peer.id == groupCall.accountContext.account.peerId
                            let peerName = peer.id == groupCall.accountContext.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.VoiceChat_ForwardTooltip_Chat(peerName).string
                        } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                            let firstPeerName = firstPeer.id == groupCall.accountContext.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            let secondPeerName = secondPeer.id == groupCall.accountContext.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.VoiceChat_ForwardTooltip_TwoChats(firstPeerName, secondPeerName).string
                        } else if let peer = peers.first {
                            let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.VoiceChat_ForwardTooltip_ManyChats(peerName, "\(peers.count - 1)").string
                        } else {
                            text = ""
                        }
                        
                        environment.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: isSavedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })
                }
                shareController.actionCompleted = { [weak self] in
                    guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                        return
                    }
                    let presentationData = groupCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                    environment.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.VoiceChat_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                }
                environment.controller()?.present(shareController, in: .window(.root))
            })
        }
        
        private func onCameraPressed() {
            guard let environment = self.environment else {
                return
            }
            guard let currentCall = self.currentCall else {
                return
            }
            
            HapticFeedback().impact(.light)
            if currentCall.hasVideo {
                currentCall.disableVideo()
            } else {
                let presentationData = currentCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                DeviceAccess.authorizeAccess(to: .camera(.videoCall), onlyCheck: true, presentationData: presentationData, present: { [weak self] c, a in
                    guard let self, let environment = self.environment, let controller = environment.controller() else {
                        return
                    }
                    controller.present(c, in: .window(.root), with: a)
                }, openSettings: { [weak self] in
                    guard let self, let currentCall = self.currentCall else {
                        return
                    }
                    currentCall.accountContext.sharedContext.applicationBindings.openSettings()
                }, _: { [weak self] ready in
                    guard let self, let environment = self.environment, let currentCall = self.currentCall, ready else {
                        return
                    }
                    var isFrontCamera = true
                    let videoCapturer = OngoingCallVideoCapturer()
                    let input = videoCapturer.video()
                    if let videoView = self.videoRenderingContext.makeView(input: input, blur: false) {
                        videoView.updateIsEnabled(true)
                        
                        let cameraNode = GroupVideoNode(videoView: videoView, backdropVideoView: nil)
                        let controller = VoiceChatCameraPreviewController(sharedContext: currentCall.accountContext.sharedContext, cameraNode: cameraNode, shareCamera: { [weak self] _, unmuted in
                            guard let self, let currentCall = self.currentCall else {
                                return
                            }
                            
                            currentCall.setIsMuted(action: unmuted ? .unmuted : .muted(isPushToTalkActive: false))
                            currentCall.requestVideo(capturer: videoCapturer, useFrontCamera: isFrontCamera)
                        }, switchCamera: {
                            Queue.mainQueue().after(0.1) {
                                isFrontCamera = !isFrontCamera
                                videoCapturer.switchVideoInput(isFront: isFrontCamera)
                            }
                        })
                        environment.controller()?.present(controller, in: .window(.root))
                    }
                })
            }
        }
        
        private func onAudioRoutePressed() {
            guard let environment = self.environment, let currentCall = self.currentCall else {
                return
            }
            
            HapticFeedback().impact(.light)
            
            guard let (availableOutputs, currentOutput) = self.audioOutputState else {
                return
            }
            guard availableOutputs.count >= 2 else {
                return
            }

            if availableOutputs.count == 2 {
                for output in availableOutputs {
                    if output != currentOutput {
                        currentCall.setCurrentAudioOutput(output)
                        break
                    }
                }
            } else {
                let presentationData = currentCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = []
                for output in availableOutputs {
                    let title: String
                    var icon: UIImage?
                    switch output {
                    case .builtin:
                        title = UIDevice.current.model
                    case .speaker:
                        title = environment.strings.Call_AudioRouteSpeaker
                        icon = generateScaledImage(image: UIImage(bundleImageName: "Call/CallSpeakerButton"), size: CGSize(width: 48.0, height: 48.0), opaque: false)
                    case .headphones:
                        title = environment.strings.Call_AudioRouteHeadphones
                    case let .port(port):
                        title = port.name
                        if port.type == .bluetooth {
                            var image = UIImage(bundleImageName: "Call/CallBluetoothButton")
                            let portName = port.name.lowercased()
                            if portName.contains("airpods max") {
                                image = UIImage(bundleImageName: "Call/CallAirpodsMaxButton")
                            } else if portName.contains("airpods pro") {
                                image = UIImage(bundleImageName: "Call/CallAirpodsProButton")
                            } else if portName.contains("airpods") {
                                image = UIImage(bundleImageName: "Call/CallAirpodsButton")
                            }
                            icon = generateScaledImage(image: image, size: CGSize(width: 48.0, height: 48.0), opaque: false)
                        }
                    }
                    items.append(CallRouteActionSheetItem(title: title, icon: icon, selected: output == currentOutput, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        guard let self, let currentCall = self.currentCall else {
                            return
                        }
                        currentCall.setCurrentAudioOutput(output)
                    }))
                }
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: environment.strings.Call_AudioRouteHide, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                environment.controller()?.present(actionSheet, in: .window(.root))
            }
        }
        
        private func onLeavePressed() {
            guard let environment = self.environment, let currentCall = self.currentCall else {
                return
            }
            
            switch currentCall {
            case let .group(groupCall):
                let isScheduled = self.callState?.scheduleTimestamp != nil
                
                let action: (Bool) -> Void = { [weak self] terminateIfPossible in
                    guard let self, case let .group(groupCall) = self.currentCall else {
                        return
                    }

                    let _ = groupCall.leave(terminateIfPossible: terminateIfPossible).startStandalone()
                    
                    if let controller = self.environment?.controller() as? VideoChatScreenV2Impl {
                        controller.dismiss(closing: true, manual: false)
                    }
                }
                
                if let callState = self.callState, callState.canManageCall {
                    let presentationData = groupCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                    let actionSheet = ActionSheetController(presentationData: presentationData)
                    var items: [ActionSheetItem] = []

                    let leaveTitle: String
                    let leaveAndCancelTitle: String

                    if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                        leaveTitle = environment.strings.LiveStream_LeaveConfirmation
                        leaveAndCancelTitle = isScheduled ? environment.strings.LiveStream_LeaveAndCancelVoiceChat : environment.strings.LiveStream_LeaveAndEndVoiceChat
                    } else {
                        leaveTitle = environment.strings.VoiceChat_LeaveConfirmation
                        leaveAndCancelTitle = isScheduled ? environment.strings.VoiceChat_LeaveAndCancelVoiceChat : environment.strings.VoiceChat_LeaveAndEndVoiceChat
                    }
                    
                    items.append(ActionSheetTextItem(title: leaveTitle))
                    items.append(ActionSheetButtonItem(title: leaveAndCancelTitle, color: .destructive, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                            return
                        }
                        let title: String
                        let text: String
                        if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                            title = isScheduled ? environment.strings.LiveStream_CancelConfirmationTitle : environment.strings.LiveStream_EndConfirmationTitle
                            text = isScheduled ? environment.strings.LiveStream_CancelConfirmationText :  environment.strings.LiveStream_EndConfirmationText
                        } else {
                            title = isScheduled ? environment.strings.VoiceChat_CancelConfirmationTitle : environment.strings.VoiceChat_EndConfirmationTitle
                            text = isScheduled ? environment.strings.VoiceChat_CancelConfirmationText :  environment.strings.VoiceChat_EndConfirmationText
                        }

                        if let _ = self.members {
                            let alertController = textAlertController(context: groupCall.accountContext, forceTheme: environment.theme, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: environment.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: isScheduled ? environment.strings.VoiceChat_CancelConfirmationEnd :  environment.strings.VoiceChat_EndConfirmationEnd, action: {
                                action(true)
                            })])
                            environment.controller()?.present(alertController, in: .window(.root))
                        } else {
                            action(true)
                        }
                    }))

                    let leaveText: String
                    if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                        leaveText = environment.strings.LiveStream_LeaveVoiceChat
                    } else {
                        leaveText = environment.strings.VoiceChat_LeaveVoiceChat
                    }

                    items.append(ActionSheetButtonItem(title: leaveText, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        action(false)
                    }))
                    
                    actionSheet.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: environment.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])
                    ])
                    environment.controller()?.present(actionSheet, in: .window(.root))
                } else {
                    action(false)
                }
            case let .conferenceSource(conferenceSource):
                let _ = conferenceSource.hangUp().startStandalone()
            }
        }
        
        private func onVisibleParticipantsUpdated(ids: Set<EnginePeer.Id>) {
            if self.visibleParticipants == ids {
                return
            }
            self.visibleParticipants = ids
            self.updateTitleSpeakingStatus()
        }
        
        private func updateTitleSpeakingStatus() {
            guard let titleView = self.title.view as? VideoChatTitleComponent.View else {
                return
            }
            
            if self.speakingParticipantPeers.isEmpty {
                titleView.updateActivityStatus(value: nil, transition: .easeInOut(duration: 0.2))
            } else {
                var titleSpeakingStatusValue = ""
                for participant in self.speakingParticipantPeers {
                    if !self.visibleParticipants.contains(participant.id) {
                        if !titleSpeakingStatusValue.isEmpty {
                            titleSpeakingStatusValue.append(", ")
                        }
                        titleSpeakingStatusValue.append(participant.compactDisplayTitle)
                    }
                }
                if titleSpeakingStatusValue.isEmpty {
                    titleView.updateActivityStatus(value: nil, transition: .easeInOut(duration: 0.2))
                } else {
                    titleView.updateActivityStatus(value: titleSpeakingStatusValue, transition: .easeInOut(duration: 0.2))
                }
            }
        }
        
        static func groupCallStateForConferenceSource(conferenceSource: PresentationCall) -> Signal<(state: PresentationGroupCallState, invitedPeers: [InvitedPeer]), NoError> {
            let invitedPeers = conferenceSource.context.engine.data.subscribe(
                EngineDataList((conferenceSource as! PresentationCallImpl).pendingInviteToConferencePeerIds.map { TelegramEngine.EngineData.Item.Peer.Peer(id: $0) })
            )
            
            let accountPeerId = conferenceSource.context.account.peerId
            let conferenceSourcePeerId = conferenceSource.peerId
            
            return combineLatest(queue: .mainQueue(),
                conferenceSource.state,
                conferenceSource.isMuted,
                invitedPeers
            )
            |> mapToSignal { state, isMuted, invitedPeers -> Signal<(state: PresentationGroupCallState, invitedPeers: [VideoChatScreenComponent.InvitedPeer]), NoError> in
                let mappedNetworkState: PresentationGroupCallState.NetworkState
                switch state.state {
                case .active:
                    mappedNetworkState = .connected
                default:
                    mappedNetworkState = .connecting
                }
                
                let callState = PresentationGroupCallState(
                    myPeerId: accountPeerId,
                    networkState: mappedNetworkState,
                    canManageCall: false,
                    adminIds: Set([accountPeerId, conferenceSourcePeerId]),
                    muteState: isMuted ? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: true) : nil,
                    defaultParticipantMuteState: nil,
                    recordingStartTimestamp: nil,
                    title: nil,
                    raisedHand: false,
                    scheduleTimestamp: nil,
                    subscribedToScheduled: false,
                    isVideoEnabled: true,
                    isVideoWatchersLimitReached: false
                )
                
                return .single((callState, invitedPeers.compactMap({ peer -> VideoChatScreenComponent.InvitedPeer? in
                    guard let peer else {
                        return nil
                    }
                    return VideoChatScreenComponent.InvitedPeer(peer: peer, state: .requesting)
                })))
            }
        }
        
        static func groupCallMembersForConferenceSource(conferenceSource: PresentationCall) -> Signal<PresentationGroupCallMembers, NoError> {
            return combineLatest(queue: .mainQueue(),
                conferenceSource.context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: conferenceSource.context.account.peerId),
                    TelegramEngine.EngineData.Item.Peer.Peer(id: conferenceSource.peerId)
                ),
                conferenceSource.state
            )
            |> map { peers, state in
                var participants: [GroupCallParticipantsContext.Participant] = []
                let (myPeer, remotePeer) = peers
                if let myPeer {
                    var myVideoDescription: GroupCallParticipantsContext.Participant.VideoDescription?
                    switch state.videoState {
                    case .active:
                        myVideoDescription = GroupCallParticipantsContext.Participant.VideoDescription(endpointId: "temp-local", ssrcGroups: [], audioSsrc: nil, isPaused: false)
                    default:
                        break
                    }
                    
                    participants.append(GroupCallParticipantsContext.Participant(
                        peer: myPeer._asPeer(),
                        ssrc: nil,
                        videoDescription: myVideoDescription,
                        presentationDescription: nil,
                        joinTimestamp: 0,
                        raiseHandRating: nil,
                        hasRaiseHand: false,
                        activityTimestamp: nil,
                        activityRank: nil,
                        muteState: nil,
                        volume: nil,
                        about: nil,
                        joinedVideo: false
                    ))
                }
                if let remotePeer {
                    var remoteVideoDescription: GroupCallParticipantsContext.Participant.VideoDescription?
                    switch state.remoteVideoState {
                    case .active:
                        remoteVideoDescription = GroupCallParticipantsContext.Participant.VideoDescription(endpointId: "temp-remote", ssrcGroups: [], audioSsrc: nil, isPaused: false)
                    default:
                        break
                    }
                    
                    participants.append(GroupCallParticipantsContext.Participant(
                        peer: remotePeer._asPeer(),
                        ssrc: nil,
                        videoDescription: remoteVideoDescription,
                        presentationDescription: nil,
                        joinTimestamp: 0,
                        raiseHandRating: nil,
                        hasRaiseHand: false,
                        activityTimestamp: nil,
                        activityRank: nil,
                        muteState: nil,
                        volume: nil,
                        about: nil,
                        joinedVideo: false
                    ))
                }
                let members = PresentationGroupCallMembers(
                    participants: participants,
                    speakingParticipants: Set(),
                    totalCount: 2,
                    loadMoreToken: nil
                )
                return members
            }
        }
        
        func update(component: VideoChatScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let alphaTransition: ComponentTransition
            if transition.animation.isImmediate {
                alphaTransition = .immediate
            } else {
                alphaTransition = .easeInOut(duration: 0.25)
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            if self.component == nil {
                self.peer = component.initialData.peer
                self.members = component.initialData.members
                self.invitedPeers = component.initialData.invitedPeers
                if let members = self.members {
                    self.invitedPeers.removeAll(where: { invitedPeer in members.participants.contains(where: { $0.peer.id == invitedPeer.peer.id }) })
                }
                self.callState = component.initialData.callState
            }
            
            var call: VideoChatCall
            if let previousComponent = self.component, previousComponent.initialCall != component.initialCall {
                call = component.initialCall
            } else {
                call = self.currentCall ?? component.initialCall
            }
            if case let .conferenceSource(conferenceSource) = call, let conferenceCall = conferenceSource.conferenceCall, conferenceSource.conferenceStateValue == .ready {
                call = .group(conferenceCall)
            }
            
            self.currentCall = call
            if self.appliedCurrentCall != call {
                self.appliedCurrentCall = call
                
                switch call {
                case let .group(groupCall):
                    self.membersDisposable?.dispose()
                    self.membersDisposable = (groupCall.members
                    |> deliverOnMainQueue).startStrict(next: { [weak self] members in
                        guard let self else {
                            return
                        }
                        if self.members != members {
                            var members = members
                            if let membersValue = members {
                                let participants = membersValue.participants
                                members = PresentationGroupCallMembers(
                                    participants: participants,
                                    speakingParticipants: membersValue.speakingParticipants,
                                    totalCount: membersValue.totalCount,
                                    loadMoreToken: membersValue.loadMoreToken
                                )
                            }
                            
                            self.members = members
                            if let members {
                                self.invitedPeers.removeAll(where: { invitedPeer in members.participants.contains(where: { $0.peer.id == invitedPeer.peer.id }) })
                            }
                            
                            if let members, let expandedParticipantsVideoState = self.expandedParticipantsVideoState, !expandedParticipantsVideoState.isUIHidden {
                                var videoCount = 0
                                for participant in members.participants {
                                    if participant.presentationDescription != nil {
                                        videoCount += 1
                                    }
                                    if participant.videoDescription != nil {
                                        videoCount += 1
                                    }
                                }
                                if videoCount == 1, let participantsView = self.participants.view as? VideoChatParticipantsComponent.View, let participantsComponent = participantsView.component {
                                    if participantsComponent.layout.videoColumn != nil {
                                        self.expandedParticipantsVideoState = nil
                                        self.focusedSpeakerAutoSwitchDeadline = 0.0
                                    }
                                }
                            }
                            
                            if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, let members {
                                if CFAbsoluteTimeGetCurrent() > self.focusedSpeakerAutoSwitchDeadline, !expandedParticipantsVideoState.isMainParticipantPinned, let participant = members.participants.first(where: { participant in
                                    if let callState = self.callState, participant.peer.id == callState.myPeerId {
                                        return false
                                    }
                                    if participant.videoDescription != nil || participant.presentationDescription != nil {
                                        if members.speakingParticipants.contains(participant.peer.id) {
                                            return true
                                        }
                                    }
                                    return false
                                }) {
                                    if participant.peer.id != expandedParticipantsVideoState.mainParticipant.id {
                                        if participant.presentationDescription != nil {
                                            self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: true), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                        } else {
                                            self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: false), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                        }
                                        self.focusedSpeakerAutoSwitchDeadline = CFAbsoluteTimeGetCurrent() + 1.0
                                    }
                                }
                                
                                if let _ = members.participants.first(where: { participant in
                                    if participant.peer.id == expandedParticipantsVideoState.mainParticipant.id {
                                        if expandedParticipantsVideoState.mainParticipant.isPresentation {
                                            if participant.presentationDescription == nil {
                                                return false
                                            }
                                        } else {
                                            if participant.videoDescription == nil {
                                                return false
                                            }
                                        }
                                        return true
                                    }
                                    return false
                                }) {
                                } else if let participant = members.participants.first(where: { participant in
                                    if participant.presentationDescription != nil {
                                        return true
                                    }
                                    if participant.videoDescription != nil {
                                        return true
                                    }
                                    return false
                                }) {
                                    if participant.presentationDescription != nil {
                                        self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: true), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                    } else {
                                        self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: false), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                    }
                                    self.focusedSpeakerAutoSwitchDeadline = CFAbsoluteTimeGetCurrent() + 1.0
                                } else {
                                    self.expandedParticipantsVideoState = nil
                                    self.focusedSpeakerAutoSwitchDeadline = 0.0
                                }
                            } else {
                                self.expandedParticipantsVideoState = nil
                                self.focusedSpeakerAutoSwitchDeadline = 0.0
                            }
                            
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                            
                            var speakingParticipantPeers: [EnginePeer] = []
                            if let members, !members.speakingParticipants.isEmpty {
                                for participant in members.participants {
                                    if members.speakingParticipants.contains(participant.peer.id) {
                                        speakingParticipantPeers.append(EnginePeer(participant.peer))
                                    }
                                }
                            }
                            if self.speakingParticipantPeers != speakingParticipantPeers {
                                self.speakingParticipantPeers = speakingParticipantPeers
                                self.updateTitleSpeakingStatus()
                            }
                        }
                    })
                    
                    self.invitedPeersDisposable?.dispose()
                    let accountContext = groupCall.accountContext
                    self.invitedPeersDisposable = (groupCall.invitedPeers
                    |> mapToSignal { invitedPeers in
                        return accountContext.engine.data.get(
                            EngineDataMap(invitedPeers.map({ TelegramEngine.EngineData.Item.Peer.Peer(id: $0.id) }))
                        )
                        |> map { peers -> [InvitedPeer] in
                            var result: [InvitedPeer] = []
                            for invitedPeer in invitedPeers {
                                if let maybePeer = peers[invitedPeer.id], let peer = maybePeer {
                                    result.append(InvitedPeer(peer: peer, state: invitedPeer.state))
                                }
                            }
                            return result
                        }
                    }
                    |> deliverOnMainQueue).startStrict(next: { [weak self] invitedPeers in
                        guard let self else {
                            return
                        }
                        
                        var invitedPeers = invitedPeers
                        if let members {
                            invitedPeers.removeAll(where: { invitedPeer in members.participants.contains(where: { $0.peer.id == invitedPeer.peer.id }) })
                        }
                        
                        if self.invitedPeers != invitedPeers {
                            self.invitedPeers = invitedPeers
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        }
                    })
                    
                    self.stateDisposable?.dispose()
                    self.stateDisposable = (groupCall.state
                    |> deliverOnMainQueue).startStrict(next: { [weak self] callState in
                        guard let self else {
                            return
                        }
                        if self.callState != callState {
                            self.callState = callState
                            
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        }
                    })
                    
                    self.conferenceCallStateDisposable?.dispose()
                    self.conferenceCallStateDisposable = nil
                    
                    self.applicationStateDisposable?.dispose()
                    self.applicationStateDisposable = (combineLatest(queue: .mainQueue(),
                        groupCall.accountContext.sharedContext.applicationBindings.applicationIsActive,
                        self.isPresentedValue.get()
                    )
                    |> deliverOnMainQueue).startStrict(next: { [weak self] applicationIsActive, isPresented in
                        guard let self, let currentCall = self.currentCall else {
                            return
                        }
                        let suspendVideoChannelRequests = !applicationIsActive || !isPresented
                        if case let .group(groupCall) = currentCall {
                            groupCall.setSuspendVideoChannelRequests(suspendVideoChannelRequests)
                        }
                    })
                    
                    self.audioOutputStateDisposable?.dispose()
                    self.audioOutputStateDisposable = (groupCall.audioOutputState
                    |> deliverOnMainQueue).start(next: { [weak self] state in
                        guard let self else {
                            return
                        }
                        
                        var existingOutputs = Set<String>()
                        var filteredOutputs: [AudioSessionOutput] = []
                        for output in state.0 {
                            if case let .port(port) = output {
                                if !existingOutputs.contains(port.name) {
                                    existingOutputs.insert(port.name)
                                    filteredOutputs.append(output)
                                }
                            } else {
                                filteredOutputs.append(output)
                            }
                        }
                        
                        self.audioOutputState = (filteredOutputs, state.1)
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    })
                    
                    let currentAccountPeer = groupCall.accountContext.account.postbox.loadedPeerWithId(groupCall.accountContext.account.peerId)
                    |> map { peer in
                        return [FoundPeer(peer: peer, subscribers: nil)]
                    }
                    let cachedDisplayAsAvailablePeers: Signal<[FoundPeer], NoError>
                    if let peerId = groupCall.peerId {
                        cachedDisplayAsAvailablePeers = groupCall.accountContext.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId)
                    } else {
                        cachedDisplayAsAvailablePeers = .single([])
                    }
                    let displayAsPeers: Signal<[FoundPeer], NoError> = currentAccountPeer
                    |> then(
                        combineLatest(currentAccountPeer, cachedDisplayAsAvailablePeers)
                        |> map { currentAccountPeer, availablePeers -> [FoundPeer] in
                            var result = currentAccountPeer
                            result.append(contentsOf: availablePeers)
                            return result
                        }
                    )
                    self.displayAsPeersDisposable?.dispose()
                    self.displayAsPeersDisposable = (displayAsPeers
                    |> deliverOnMainQueue).start(next: { [weak self] value in
                        guard let self else {
                            return
                        }
                        self.displayAsPeers = value
                    })
                    
                    self.inviteLinksDisposable?.dispose()
                    self.inviteLinksDisposable = (groupCall.inviteLinks
                    |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                        guard let self else {
                            return
                        }
                        self.inviteLinks = value
                    })
                    
                    self.reconnectedAsEventsDisposable?.dispose()
                    self.reconnectedAsEventsDisposable = (groupCall.reconnectedAsEvents
                    |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                        guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                            return
                        }
                        let text: String
                        if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                            text = environment.strings.LiveStream_DisplayAsSuccess(peer.displayTitle(strings: environment.strings, displayOrder: groupCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                        } else {
                            text = environment.strings.VoiceChat_DisplayAsSuccess(peer.displayTitle(strings: environment.strings, displayOrder: groupCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                        }
                        self.presentUndoOverlay(content: .invitedToVoiceChat(context: groupCall.accountContext, peer: peer, title: nil, text: text, action: nil, duration: 3), action: { _ in return false })
                    })
                    
                    self.memberEventsDisposable?.dispose()
                    if groupCall.peerId != nil {
                        self.memberEventsDisposable = (groupCall.memberEvents
                        |> deliverOnMainQueue).start(next: { [weak self] event in
                            guard let self, let members = self.members, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                                return
                            }
                            if event.joined {
                                var displayEvent = false
                                if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                                    displayEvent = false
                                }
                                if members.totalCount < 40 {
                                    displayEvent = true
                                } else if event.peer.isVerified {
                                    displayEvent = true
                                } else if event.isContact || event.isInChatList {
                                    displayEvent = true
                                }
                                
                                if displayEvent {
                                    let text = environment.strings.VoiceChat_PeerJoinedText(event.peer.displayTitle(strings: environment.strings, displayOrder: groupCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                                    self.presentUndoOverlay(content: .invitedToVoiceChat(context: groupCall.accountContext, peer: event.peer, title: nil, text: text, action: nil, duration: 3), action: { _ in return false })
                                }
                            }
                        })
                    }
                case let .conferenceSource(conferenceSource):
                    self.membersDisposable?.dispose()
                    self.membersDisposable = (View.groupCallMembersForConferenceSource(conferenceSource: conferenceSource)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] members in
                        guard let self else {
                            return
                        }
                        if self.members != members {
                            var members = members
                            let membersValue = members
                            let participants = membersValue.participants
                            members = PresentationGroupCallMembers(
                                participants: participants,
                                speakingParticipants: membersValue.speakingParticipants,
                                totalCount: membersValue.totalCount,
                                loadMoreToken: membersValue.loadMoreToken
                            )
                            
                            self.members = members
                            
                            if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, !expandedParticipantsVideoState.isUIHidden {
                                var videoCount = 0
                                for participant in members.participants {
                                    if participant.presentationDescription != nil {
                                        videoCount += 1
                                    }
                                    if participant.videoDescription != nil {
                                        videoCount += 1
                                    }
                                }
                                if videoCount == 1, let participantsView = self.participants.view as? VideoChatParticipantsComponent.View, let participantsComponent = participantsView.component {
                                    if participantsComponent.layout.videoColumn != nil {
                                        self.expandedParticipantsVideoState = nil
                                        self.focusedSpeakerAutoSwitchDeadline = 0.0
                                    }
                                }
                            }
                            
                            if let expandedParticipantsVideoState = self.expandedParticipantsVideoState {
                                if CFAbsoluteTimeGetCurrent() > self.focusedSpeakerAutoSwitchDeadline, !expandedParticipantsVideoState.isMainParticipantPinned, let participant = members.participants.first(where: { participant in
                                    if let callState = self.callState, participant.peer.id == callState.myPeerId {
                                        return false
                                    }
                                    if participant.videoDescription != nil || participant.presentationDescription != nil {
                                        if members.speakingParticipants.contains(participant.peer.id) {
                                            return true
                                        }
                                    }
                                    return false
                                }) {
                                    if participant.peer.id != expandedParticipantsVideoState.mainParticipant.id {
                                        if participant.presentationDescription != nil {
                                            self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: true), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                        } else {
                                            self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: false), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                        }
                                        self.focusedSpeakerAutoSwitchDeadline = CFAbsoluteTimeGetCurrent() + 1.0
                                    }
                                }
                                
                                if let _ = members.participants.first(where: { participant in
                                    if participant.peer.id == expandedParticipantsVideoState.mainParticipant.id {
                                        if expandedParticipantsVideoState.mainParticipant.isPresentation {
                                            if participant.presentationDescription == nil {
                                                return false
                                            }
                                        } else {
                                            if participant.videoDescription == nil {
                                                return false
                                            }
                                        }
                                        return true
                                    }
                                    return false
                                }) {
                                } else if let participant = members.participants.first(where: { participant in
                                    if participant.presentationDescription != nil {
                                        return true
                                    }
                                    if participant.videoDescription != nil {
                                        return true
                                    }
                                    return false
                                }) {
                                    if participant.presentationDescription != nil {
                                        self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: true), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                    } else {
                                        self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: false), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                    }
                                    self.focusedSpeakerAutoSwitchDeadline = CFAbsoluteTimeGetCurrent() + 1.0
                                } else {
                                    self.expandedParticipantsVideoState = nil
                                    self.focusedSpeakerAutoSwitchDeadline = 0.0
                                }
                            } else {
                                self.expandedParticipantsVideoState = nil
                                self.focusedSpeakerAutoSwitchDeadline = 0.0
                            }
                            
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                            
                            var speakingParticipantPeers: [EnginePeer] = []
                            if !members.speakingParticipants.isEmpty {
                                for participant in members.participants {
                                    if members.speakingParticipants.contains(participant.peer.id) {
                                        speakingParticipantPeers.append(EnginePeer(participant.peer))
                                    }
                                }
                            }
                            if self.speakingParticipantPeers != speakingParticipantPeers {
                                self.speakingParticipantPeers = speakingParticipantPeers
                                self.updateTitleSpeakingStatus()
                            }
                        }
                    })
                    
                    self.invitedPeersDisposable?.dispose()
                    self.invitedPeersDisposable = nil
                    
                    self.stateDisposable?.dispose()
                    self.stateDisposable = (View.groupCallStateForConferenceSource(conferenceSource: conferenceSource)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] callState, invitedPeers in
                        guard let self else {
                            return
                        }
                        
                        var isUpdated = false
                        if self.callState != callState {
                            self.callState = callState
                            isUpdated = true
                        }
                        if self.invitedPeers != invitedPeers {
                            self.invitedPeers = invitedPeers
                            isUpdated = true
                        }
                         
                        if isUpdated {
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        }
                    })
                    
                    self.conferenceCallStateDisposable?.dispose()
                    self.conferenceCallStateDisposable = (conferenceSource.conferenceState
                    |> filter { $0 == .ready }
                    |> take(1)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
                        guard let self, case let .conferenceSource(conferenceSource) = self.currentCall else {
                            return
                        }
                        guard let conferenceCall = conferenceSource.conferenceCall else {
                            return
                        }
                        self.currentCall = .group(conferenceCall)
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    })
                    
                    self.applicationStateDisposable?.dispose()
                    self.applicationStateDisposable = nil
                    
                    self.audioOutputStateDisposable?.dispose()
                    self.audioOutputStateDisposable = (conferenceSource.audioOutputState
                    |> deliverOnMainQueue).start(next: { [weak self] state in
                        guard let self else {
                            return
                        }
                        
                        var existingOutputs = Set<String>()
                        var filteredOutputs: [AudioSessionOutput] = []
                        for output in state.0 {
                            if case let .port(port) = output {
                                if !existingOutputs.contains(port.name) {
                                    existingOutputs.insert(port.name)
                                    filteredOutputs.append(output)
                                }
                            } else {
                                filteredOutputs.append(output)
                            }
                        }
                        
                        self.audioOutputState = (filteredOutputs, state.1)
                        self.state?.updated(transition: .spring(duration: 0.4))
                    })
                    
                    self.displayAsPeersDisposable?.dispose()
                    self.displayAsPeersDisposable = nil
                    self.displayAsPeers = nil
                    
                    self.inviteLinksDisposable?.dispose()
                    self.inviteLinksDisposable = nil
                    self.inviteLinks = nil
                    
                    self.reconnectedAsEventsDisposable?.dispose()
                    self.reconnectedAsEventsDisposable = nil
                    
                    self.memberEventsDisposable?.dispose()
                    self.memberEventsDisposable = nil
                }
            }
            
            self.isPresentedValue.set(environment.isVisible)
            
            self.component = component
            self.environment = environment
            self.state = state
            
            if themeUpdated {
                self.containerView.backgroundColor = .black
            }
            
            var mappedParticipants: VideoChatParticipantsComponent.Participants?
            if let members = self.members, let callState = self.callState {
                var canInvite = true
                var inviteIsLink = false
                if case let .group(groupCall) = self.currentCall, groupCall.isConference {
                    canInvite = true
                } else {
                    if case let .channel(peer) = self.peer {
                        if peer.flags.contains(.isGigagroup) {
                            if peer.flags.contains(.isCreator) || peer.adminRights != nil {
                            } else {
                                canInvite = false
                            }
                        }
                        if case .broadcast = peer.info, !(peer.addressName?.isEmpty ?? true) {
                            inviteIsLink = true
                        }
                    }
                }
                var inviteType: VideoChatParticipantsComponent.Participants.InviteType?
                if canInvite {
                    if inviteIsLink {
                        inviteType = .shareLink
                    } else {
                        inviteType = .invite
                    }
                }
                
                mappedParticipants = VideoChatParticipantsComponent.Participants(
                    myPeerId: callState.myPeerId,
                    participants: members.participants,
                    totalCount: members.totalCount,
                    loadMoreToken: members.loadMoreToken,
                    inviteType: inviteType
                )
            }
            
            let maxSingleColumnWidth: CGFloat = 620.0
            let isTwoColumnLayout: Bool
            if availableSize.width > maxSingleColumnWidth {
                if let mappedParticipants, mappedParticipants.participants.contains(where: { $0.videoDescription != nil || $0.presentationDescription != nil }) {
                    isTwoColumnLayout = true
                } else {
                    isTwoColumnLayout = false
                }
            } else {
                isTwoColumnLayout = false
            }
            
            var containerOffset: CGFloat = 0.0
            if let verticalPanState = self.verticalPanState {
                if verticalPanState.scrollView != nil {
                    containerOffset = verticalPanState.accumulatedOffset
                } else {
                    containerOffset = verticalPanState.fraction * availableSize.height
                }
                self.containerView.layer.cornerRadius = containerOffset.isZero ? 0.0 : environment.deviceMetrics.screenCornerRadius
            }
            
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: 0.0, y: containerOffset), size: availableSize), completion: { [weak self] completed in
                guard let self, completed else {
                    return
                }
                if self.verticalPanState == nil {
                    self.containerView.layer.cornerRadius = 0.0
                }
                if self.notifyDismissedInteractivelyOnPanGestureApply {
                    self.notifyDismissedInteractivelyOnPanGestureApply = false
                    
                    if let controller = self.environment?.controller() as? VideoChatScreenV2Impl {
                        if self.isUpdating {
                            DispatchQueue.main.async { [weak controller] in
                                controller?.superDismiss()
                            }
                        } else {
                            controller.superDismiss()
                        }
                    }
                }
                if let completionOnPanGestureApply = self.completionOnPanGestureApply {
                    self.completionOnPanGestureApply = nil
                    DispatchQueue.main.async {
                        completionOnPanGestureApply()
                    }
                }
            })
            
            let sideInset: CGFloat = max(environment.safeInsets.left, 14.0)
            
            let topInset: CGFloat = environment.statusBarHeight + 2.0
            let navigationBarHeight: CGFloat = 61.0
            let navigationHeight = topInset + navigationBarHeight
            
            let navigationButtonAreaWidth: CGFloat = 40.0
            let navigationButtonDiameter: CGFloat = 28.0
            
            let navigationLeftButtonSize = self.navigationLeftButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: "anim_profilemore"
                        ),
                        color: .white
                    )),
                    background: AnyComponent(Circle(
                        fillColor: UIColor(white: 1.0, alpha: 0.1),
                        size: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openMoreMenu()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
            )
            
            let navigationRightButtonSize = self.navigationRightButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(Image(
                        image: closeButtonImage(dark: false)
                    )),
                    background: AnyComponent(Circle(
                        fillColor: UIColor(white: 1.0, alpha: 0.1),
                        size: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
            )
            
            let navigationLeftButtonFrame = CGRect(origin: CGPoint(x: sideInset + floor((navigationButtonAreaWidth - navigationLeftButtonSize.width) * 0.5), y: topInset + floor((navigationBarHeight - navigationLeftButtonSize.height) * 0.5)), size: navigationLeftButtonSize)
            if let navigationLeftButtonView = self.navigationLeftButton.view {
                if navigationLeftButtonView.superview == nil {
                    self.containerView.addSubview(navigationLeftButtonView)
                }
                transition.setFrame(view: navigationLeftButtonView, frame: navigationLeftButtonFrame)
                alphaTransition.setAlpha(view: navigationLeftButtonView, alpha: self.isAnimatedOutFromPrivateCall ? 0.0 : 1.0)
            }
            
            let navigationRightButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - navigationButtonAreaWidth + floor((navigationButtonAreaWidth - navigationRightButtonSize.width) * 0.5), y: topInset + floor((navigationBarHeight - navigationRightButtonSize.height) * 0.5)), size: navigationRightButtonSize)
            if let navigationRightButtonView = self.navigationRightButton.view {
                if navigationRightButtonView.superview == nil {
                    self.containerView.addSubview(navigationRightButtonView)
                }
                transition.setFrame(view: navigationRightButtonView, frame: navigationRightButtonFrame)
                alphaTransition.setAlpha(view: navigationRightButtonView, alpha: self.isAnimatedOutFromPrivateCall ? 0.0 : 1.0)
            }
            
            if isTwoColumnLayout {
                var navigationSidebarButtonTransition = transition
                let navigationSidebarButton: ComponentView<Empty>
                if let current = self.navigationSidebarButton {
                    navigationSidebarButton = current
                } else {
                    navigationSidebarButtonTransition = navigationSidebarButtonTransition.withAnimation(.none)
                    navigationSidebarButton = ComponentView()
                    self.navigationSidebarButton = navigationSidebarButton
                }
                let navigationSidebarButtonSize = navigationSidebarButton.update(
                    transition: .immediate,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(BundleIconComponent(
                            name: "Call/PanelIcon",
                            tintColor: .white
                        )),
                        background: AnyComponent(FilledRoundedRectangleComponent(
                            color: UIColor(white: 1.0, alpha: 0.1),
                            cornerRadius: .value(navigationButtonDiameter * 0.5),
                            smoothCorners: false
                        )),
                        effectAlignment: .center,
                        minSize: CGSize(width: navigationButtonDiameter + 10.0, height: navigationButtonDiameter),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.isTwoColumnSidebarHidden = !self.isTwoColumnSidebarHidden
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
                )
                let navigationSidebarButtonFrame = CGRect(origin: CGPoint(x: navigationRightButtonFrame.minX - 32.0 - navigationSidebarButtonSize.width, y: topInset + floor((navigationBarHeight - navigationSidebarButtonSize.height) * 0.5)), size: navigationSidebarButtonSize)
                if let navigationSidebarButtonView = navigationSidebarButton.view {
                    var animateIn = false
                    if navigationSidebarButtonView.superview == nil {
                        animateIn = true
                        if let navigationRightButtonView = self.navigationRightButton.view {
                            self.containerView.insertSubview(navigationSidebarButtonView, aboveSubview: navigationRightButtonView)
                        }
                    }
                    navigationSidebarButtonTransition.setFrame(view: navigationSidebarButtonView, frame: navigationSidebarButtonFrame)
                    if animateIn {
                        transition.animateScale(view: navigationSidebarButtonView, from: 0.001, to: 1.0)
                        transition.animateAlpha(view: navigationSidebarButtonView, from: 0.0, to: 1.0)
                    }
                }
            } else if let navigationSidebarButton = self.navigationSidebarButton {
                self.navigationSidebarButton = nil
                if let navigationSidebarButtonView = navigationSidebarButton.view {
                    transition.setScale(view: navigationSidebarButtonView, scale: 0.001)
                    transition.setAlpha(view: navigationSidebarButtonView, alpha: 0.0, completion: { [weak navigationSidebarButtonView] _ in
                        navigationSidebarButtonView?.removeFromSuperview()
                    })
                }
            }
            
            let idleTitleStatusText: String
            if let callState = self.callState {
                if callState.networkState == .connected, let members = self.members {
                    idleTitleStatusText = environment.strings.VoiceChat_Panel_Members(Int32(max(1, members.totalCount)))
                } else if callState.scheduleTimestamp != nil {
                    idleTitleStatusText = environment.strings.VoiceChat_Scheduled
                } else {
                    idleTitleStatusText = environment.strings.VoiceChat_Connecting
                }
            } else {
                idleTitleStatusText = " "
            }
            
            let canManageCall = self.callState?.canManageCall ?? false
            
            var maxTitleWidth: CGFloat = availableSize.width - sideInset * 2.0 - navigationButtonAreaWidth * 2.0 - 4.0 * 2.0
            if isTwoColumnLayout {
                maxTitleWidth -= 110.0
            }
            
            //TODO:localize
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(VideoChatTitleComponent(
                    title: self.callState?.title ?? self.peer?.debugDisplayTitle ?? "Group Call",
                    status: idleTitleStatusText,
                    isRecording: self.callState?.recordingStartTimestamp != nil,
                    strings: environment.strings,
                    tapAction: self.callState?.recordingStartTimestamp != nil ? { [weak self] in
                        guard let self, let environment = self.environment, let currentCall = self.currentCall else {
                            return
                        }
                        guard let titleView = self.title.view as? VideoChatTitleComponent.View, let recordingIndicatorView = titleView.recordingIndicatorView else {
                            return
                        }
                        var hasTooltipAlready = false
                        environment.controller()?.forEachController { controller -> Bool in
                            if controller is TooltipScreen {
                                hasTooltipAlready = true
                            }
                            return true
                        }
                        if !hasTooltipAlready {
                            let location = recordingIndicatorView.convert(recordingIndicatorView.bounds, to: self)
                            let text: String
                            if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                                text = environment.strings.LiveStream_RecordingInProgress
                            } else {
                                text = environment.strings.VoiceChat_RecordingInProgress
                            }
                            environment.controller()?.present(TooltipScreen(account: currentCall.accountContext.account, sharedContext: currentCall.accountContext.sharedContext, text: .plain(text: text), icon: nil, location: .point(location.offsetBy(dx: 1.0, dy: 0.0), .top), displayDuration: .custom(3.0), shouldDismissOnTouch: { _, _ in
                                return .dismiss(consume: true)
                            }), in: .current)
                        }
                    } : nil,
                    longTapAction: canManageCall ? { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openTitleEditing()
                    } : nil
                )),
                environment: {},
                containerSize: CGSize(width: maxTitleWidth, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: topInset + floor((navigationBarHeight - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.containerView.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
                alphaTransition.setAlpha(view: titleView, alpha: self.isAnimatedOutFromPrivateCall ? 0.0 : 1.0)
            }
            
            let areButtonsCollapsed: Bool
            let mainColumnWidth: CGFloat
            let mainColumnSideInset: CGFloat
            
            if isTwoColumnLayout {
                areButtonsCollapsed = false
                
                mainColumnWidth = 320.0
                mainColumnSideInset = 0.0
            } else {
                areButtonsCollapsed = self.expandedParticipantsVideoState != nil
                
                if availableSize.width > maxSingleColumnWidth {
                    mainColumnWidth = 420.0
                    mainColumnSideInset = 0.0
                } else {
                    mainColumnWidth = availableSize.width
                    mainColumnSideInset = sideInset
                }
            }
            
            let actionButtonDiameter: CGFloat = 56.0
            let expandedMicrophoneButtonDiameter: CGFloat = actionButtonDiameter
            var collapsedMicrophoneButtonDiameter: CGFloat = 116.0
            
            let maxActionMicrophoneButtonSpacing: CGFloat = 38.0
            let minActionMicrophoneButtonSpacing: CGFloat = 20.0
            
            if actionButtonDiameter * 2.0 + collapsedMicrophoneButtonDiameter + maxActionMicrophoneButtonSpacing * 2.0 > mainColumnWidth {
                collapsedMicrophoneButtonDiameter = mainColumnWidth - (actionButtonDiameter * 2.0 + minActionMicrophoneButtonSpacing * 2.0)
                collapsedMicrophoneButtonDiameter = max(actionButtonDiameter, collapsedMicrophoneButtonDiameter)
            }
            
            let microphoneButtonDiameter: CGFloat
            if isTwoColumnLayout {
                microphoneButtonDiameter = collapsedMicrophoneButtonDiameter
            } else {
                if areButtonsCollapsed {
                    microphoneButtonDiameter = expandedMicrophoneButtonDiameter
                } else {
                    microphoneButtonDiameter = self.expandedParticipantsVideoState == nil ? collapsedMicrophoneButtonDiameter : expandedMicrophoneButtonDiameter
                }
            }
            
            let buttonsSideInset: CGFloat = 26.0
            
            let buttonsWidth: CGFloat = actionButtonDiameter * 2.0 + microphoneButtonDiameter
            let remainingButtonsSpace: CGFloat = availableSize.width - buttonsSideInset * 2.0 - buttonsWidth
            
            let effectiveMaxActionMicrophoneButtonSpacing: CGFloat
            if areButtonsCollapsed {
                effectiveMaxActionMicrophoneButtonSpacing = 80.0
            } else {
                effectiveMaxActionMicrophoneButtonSpacing = maxActionMicrophoneButtonSpacing
            }
            
            let actionMicrophoneButtonSpacing = min(effectiveMaxActionMicrophoneButtonSpacing, floor(remainingButtonsSpace * 0.5))
            
            var collapsedMicrophoneButtonFrame: CGRect = CGRect(origin: CGPoint(x: floor((availableSize.width - collapsedMicrophoneButtonDiameter) * 0.5), y: availableSize.height - 48.0 - environment.safeInsets.bottom - collapsedMicrophoneButtonDiameter), size: CGSize(width: collapsedMicrophoneButtonDiameter, height: collapsedMicrophoneButtonDiameter))
            if self.isAnimatedOutFromPrivateCall {
                collapsedMicrophoneButtonFrame.origin.y = availableSize.height + 48.0
            }
            
            var expandedMicrophoneButtonFrame: CGRect = CGRect(origin: CGPoint(x: floor((availableSize.width - expandedMicrophoneButtonDiameter) * 0.5), y: availableSize.height - environment.safeInsets.bottom - expandedMicrophoneButtonDiameter - 12.0), size: CGSize(width: expandedMicrophoneButtonDiameter, height: expandedMicrophoneButtonDiameter))
            
            var isMainColumnHidden = false
            if isTwoColumnLayout {
                if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, expandedParticipantsVideoState.isUIHidden {
                    isMainColumnHidden = true
                } else if self.isTwoColumnSidebarHidden {
                    isMainColumnHidden = true
                }
            }
            
            if isTwoColumnLayout {
                if isMainColumnHidden {
                    collapsedMicrophoneButtonFrame.origin.x = availableSize.width - sideInset - mainColumnWidth + floor((mainColumnWidth - collapsedMicrophoneButtonDiameter) * 0.5) + sideInset + mainColumnWidth
                } else {
                    collapsedMicrophoneButtonFrame.origin.x = availableSize.width - sideInset - mainColumnWidth + floor((mainColumnWidth - collapsedMicrophoneButtonDiameter) * 0.5)
                }
                expandedMicrophoneButtonFrame = collapsedMicrophoneButtonFrame
            } else {
                if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, expandedParticipantsVideoState.isUIHidden {
                    expandedMicrophoneButtonFrame.origin.y = availableSize.height + expandedMicrophoneButtonDiameter + 12.0
                }
            }
            
            let microphoneButtonFrame: CGRect
            if areButtonsCollapsed {
                microphoneButtonFrame = expandedMicrophoneButtonFrame
            } else {
                microphoneButtonFrame = collapsedMicrophoneButtonFrame
            }
            
            let collapsedParticipantsClippingY: CGFloat
            collapsedParticipantsClippingY = collapsedMicrophoneButtonFrame.minY - 16.0
            
            let expandedParticipantsClippingY: CGFloat
            if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, expandedParticipantsVideoState.isUIHidden {
                if isTwoColumnLayout {
                    expandedParticipantsClippingY = expandedMicrophoneButtonFrame.minY - 24.0
                } else {
                    expandedParticipantsClippingY = availableSize.height - max(14.0, environment.safeInsets.bottom)
                }
            } else {
                expandedParticipantsClippingY = expandedMicrophoneButtonFrame.minY - 24.0
            }
            
            let leftActionButtonFrame = CGRect(origin: CGPoint(x: microphoneButtonFrame.minX - actionMicrophoneButtonSpacing - actionButtonDiameter, y: microphoneButtonFrame.minY + floor((microphoneButtonFrame.height - actionButtonDiameter) * 0.5)), size: CGSize(width: actionButtonDiameter, height: actionButtonDiameter))
            let rightActionButtonFrame = CGRect(origin: CGPoint(x: microphoneButtonFrame.maxX + actionMicrophoneButtonSpacing, y: microphoneButtonFrame.minY + floor((microphoneButtonFrame.height - actionButtonDiameter) * 0.5)), size: CGSize(width: actionButtonDiameter, height: actionButtonDiameter))
            
            let participantsSize = availableSize
            
            let columnSpacing: CGFloat = 14.0
            let participantsLayout: VideoChatParticipantsComponent.Layout
            if isTwoColumnLayout {
                let mainColumnInsets: UIEdgeInsets = UIEdgeInsets(top: navigationHeight, left: mainColumnSideInset, bottom: availableSize.height - collapsedParticipantsClippingY, right: mainColumnSideInset)
                let videoColumnWidth: CGFloat = max(10.0, availableSize.width - sideInset * 2.0 - mainColumnWidth - columnSpacing)
                participantsLayout = VideoChatParticipantsComponent.Layout(
                    videoColumn: VideoChatParticipantsComponent.Layout.Column(
                        width: videoColumnWidth,
                        insets: UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: max(14.0, environment.safeInsets.bottom), right: 0.0)
                    ),
                    mainColumn: VideoChatParticipantsComponent.Layout.Column(
                        width: mainColumnWidth,
                        insets: mainColumnInsets
                    ),
                    columnSpacing: columnSpacing,
                    isMainColumnHidden: self.isTwoColumnSidebarHidden
                )
            } else {
                let mainColumnInsets: UIEdgeInsets = UIEdgeInsets(top: navigationHeight, left: mainColumnSideInset, bottom: availableSize.height - collapsedParticipantsClippingY, right: mainColumnSideInset)
                participantsLayout = VideoChatParticipantsComponent.Layout(
                    videoColumn: nil,
                    mainColumn: VideoChatParticipantsComponent.Layout.Column(
                        width: mainColumnWidth,
                        insets: mainColumnInsets
                    ),
                    columnSpacing: columnSpacing,
                    isMainColumnHidden: false
                )
            }
            
            let participantsSafeInsets = UIEdgeInsets(
                top: environment.statusBarHeight,
                left: environment.safeInsets.left,
                bottom: max(14.0, environment.safeInsets.bottom),
                right: environment.safeInsets.right
            )
            let participantsExpandedInsets: UIEdgeInsets
            if isTwoColumnLayout {
                participantsExpandedInsets = UIEdgeInsets(
                    top: navigationHeight,
                    left: max(14.0, participantsSafeInsets.left),
                    bottom: participantsSafeInsets.bottom,
                    right: max(14.0, participantsSafeInsets.right)
                )
            } else {
                participantsExpandedInsets = UIEdgeInsets(
                    top: participantsSafeInsets.top,
                    left: participantsSafeInsets.left,
                    bottom: availableSize.height - expandedParticipantsClippingY,
                    right: participantsSafeInsets.right
                )
            }
            
            let _ = self.participants.update(
                transition: transition,
                component: AnyComponent(VideoChatParticipantsComponent(
                    call: call,
                    participants: mappedParticipants,
                    invitedPeers: self.invitedPeers,
                    speakingParticipants: self.members?.speakingParticipants ?? Set(),
                    expandedVideoState: self.expandedParticipantsVideoState,
                    maxVideoQuality: self.maxVideoQuality,
                    theme: environment.theme,
                    strings: environment.strings,
                    layout: participantsLayout,
                    expandedInsets: participantsExpandedInsets,
                    safeInsets: participantsSafeInsets,
                    interfaceOrientation: environment.orientation ?? .portrait,
                    openParticipantContextMenu: { [weak self] id, sourceView, gesture in
                        guard let self else {
                            return
                        }
                        self.openParticipantContextMenu(id: id, sourceView: sourceView, gesture: gesture)
                    },
                    updateMainParticipant: { [weak self] key, alsoSetIsUIHidden in
                        guard let self else {
                            return
                        }
                        if let key {
                            if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, expandedParticipantsVideoState.mainParticipant == key {
                                return
                            }
                            
                            var isUIHidden = self.expandedParticipantsVideoState?.isUIHidden ?? false
                            if let alsoSetIsUIHidden {
                                isUIHidden = alsoSetIsUIHidden
                            }
                            
                            self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: key, isMainParticipantPinned: false, isUIHidden: isUIHidden)
                            self.focusedSpeakerAutoSwitchDeadline = CFAbsoluteTimeGetCurrent() + 3.0
                            self.state?.updated(transition: .spring(duration: 0.4))
                        } else if self.expandedParticipantsVideoState != nil {
                            self.expandedParticipantsVideoState = nil
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    updateIsMainParticipantPinned: { [weak self] isPinned in
                        guard let self else {
                            return
                        }
                        guard let expandedParticipantsVideoState = self.expandedParticipantsVideoState else {
                            return
                        }
                        let updatedExpandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(
                            mainParticipant: expandedParticipantsVideoState.mainParticipant,
                            isMainParticipantPinned: isPinned,
                            isUIHidden: expandedParticipantsVideoState.isUIHidden
                        )
                        if self.expandedParticipantsVideoState != updatedExpandedParticipantsVideoState {
                            self.expandedParticipantsVideoState = updatedExpandedParticipantsVideoState
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    updateIsExpandedUIHidden: { [weak self] isUIHidden in
                        guard let self else {
                            return
                        }
                        guard let expandedParticipantsVideoState = self.expandedParticipantsVideoState else {
                            return
                        }
                        let updatedExpandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(
                            mainParticipant: expandedParticipantsVideoState.mainParticipant,
                            isMainParticipantPinned: expandedParticipantsVideoState.isMainParticipantPinned,
                            isUIHidden: isUIHidden
                        )
                        if self.expandedParticipantsVideoState != updatedExpandedParticipantsVideoState {
                            self.expandedParticipantsVideoState = updatedExpandedParticipantsVideoState
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    openInviteMembers: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openInviteMembers()
                    },
                    visibleParticipantsUpdated: { [weak self] visibleParticipants in
                        guard let self else {
                            return
                        }
                        self.onVisibleParticipantsUpdated(ids: visibleParticipants)
                    }
                )),
                environment: {},
                containerSize: participantsSize
            )
            let participantsFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: participantsSize)
            if let participantsView = self.participants.view {
                if participantsView.superview == nil {
                    participantsView.layer.allowsGroupOpacity = true
                    self.containerView.addSubview(participantsView)
                }
                transition.setFrame(view: participantsView, frame: participantsFrame)
                var participantsAlpha: CGFloat = 1.0
                if let callState = self.callState, callState.scheduleTimestamp != nil {
                    participantsAlpha = 0.0
                }
                if self.isAnimatedOutFromPrivateCall {
                    participantsAlpha = 0.0
                }
                alphaTransition.setAlpha(view: participantsView, alpha: participantsAlpha)
            }
            
            if let callState = self.callState, let scheduleTimestamp = callState.scheduleTimestamp {
                let scheduleInfo: ComponentView<Empty>
                var scheduleInfoTransition = transition
                if let current = self.scheduleInfo {
                    scheduleInfo = current
                } else {
                    scheduleInfoTransition = scheduleInfoTransition.withAnimation(.none)
                    scheduleInfo = ComponentView()
                    self.scheduleInfo = scheduleInfo
                }
                let scheduleInfoSize = scheduleInfo.update(
                    transition: scheduleInfoTransition,
                    component: AnyComponent(VideoChatScheduledInfoComponent(
                        timestamp: scheduleTimestamp,
                        strings: environment.strings
                    )),
                    environment: {},
                    containerSize: participantsSize
                )
                let scheduleInfoFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: scheduleInfoSize)
                if let scheduleInfoView = scheduleInfo.view {
                    if scheduleInfoView.superview == nil {
                        scheduleInfoView.isUserInteractionEnabled = false
                        self.containerView.addSubview(scheduleInfoView)
                    }
                    scheduleInfoTransition.setFrame(view: scheduleInfoView, frame: scheduleInfoFrame)
                }
            } else if let scheduleInfo = self.scheduleInfo {
                self.scheduleInfo = nil
                if let scheduleInfoView = scheduleInfo.view {
                    alphaTransition.setAlpha(view: scheduleInfoView, alpha: 0.0, completion: { [weak scheduleInfoView] _ in
                        scheduleInfoView?.removeFromSuperview()
                    })
                }
            }
            
            let micButtonContent: VideoChatMicButtonComponent.Content
            let actionButtonMicrophoneState: VideoChatActionButtonComponent.MicrophoneState
            if let callState = self.callState {
                if callState.scheduleTimestamp != nil {
                    let scheduledState: VideoChatMicButtonComponent.ScheduledState
                    if callState.canManageCall {
                        scheduledState = .start
                    } else {
                        scheduledState = .toggleSubscription(isSubscribed: callState.subscribedToScheduled)
                    }
                    micButtonContent = .scheduled(state: scheduledState)
                    actionButtonMicrophoneState = .scheduled
                } else {
                    switch callState.networkState {
                    case .connecting:
                        micButtonContent = .connecting
                        actionButtonMicrophoneState = .connecting
                    case .connected:
                        if let muteState = callState.muteState {
                            if muteState.canUnmute {
                                if self.isPushToTalkActive {
                                    micButtonContent = .unmuted(pushToTalk: self.isPushToTalkActive)
                                    actionButtonMicrophoneState = .unmuted
                                } else {
                                    micButtonContent = .muted
                                    actionButtonMicrophoneState = .muted
                                }
                            } else {
                                micButtonContent = .raiseHand(isRaised: callState.raisedHand)
                                actionButtonMicrophoneState = .raiseHand
                            }
                        } else {
                            micButtonContent = .unmuted(pushToTalk: false)
                            actionButtonMicrophoneState = .unmuted
                        }
                    }
                }
            } else {
                micButtonContent = .connecting
                actionButtonMicrophoneState = .connecting
            }
            
            let _ = self.microphoneButton.update(
                transition: transition,
                component: AnyComponent(VideoChatMicButtonComponent(
                    call: call,
                    strings: environment.strings,
                    content: micButtonContent,
                    isCollapsed: areButtonsCollapsed,
                    updateUnmutedStateIsPushToTalk: { [weak self] unmutedStateIsPushToTalk in
                        guard let self, let currentCall = self.currentCall else {
                            return
                        }
                        guard let callState = self.callState else {
                            return
                        }
                        
                        if let unmutedStateIsPushToTalk {
                            if unmutedStateIsPushToTalk {
                                if let muteState = callState.muteState {
                                    if muteState.canUnmute {
                                        self.isPushToTalkActive = true
                                        currentCall.setIsMuted(action: .muted(isPushToTalkActive: true))
                                    } else {
                                        self.isPushToTalkActive = false
                                    }
                                } else {
                                    self.isPushToTalkActive = true
                                    currentCall.setIsMuted(action: .muted(isPushToTalkActive: true))
                                }
                            } else {
                                if let muteState = callState.muteState {
                                    if muteState.canUnmute {
                                        currentCall.setIsMuted(action: .unmuted)
                                    }
                                }
                                self.isPushToTalkActive = false
                            }
                            self.state?.updated(transition: .spring(duration: 0.5))
                        } else {
                            currentCall.setIsMuted(action: .muted(isPushToTalkActive: false))
                            self.isPushToTalkActive = false
                            self.state?.updated(transition: .spring(duration: 0.5))
                        }
                    },
                    raiseHand: { [weak self] in
                        guard let self else {
                            return
                        }
                        guard let callState = self.callState else {
                            return
                        }
                        if !callState.raisedHand {
                            if case let .group(groupCall) = self.currentCall {
                                groupCall.raiseHand()
                            }
                        }
                    },
                    scheduleAction: { [weak self] in
                        guard let self, case let .group(groupCall) = self.currentCall else {
                            return
                        }
                        guard let callState = self.callState else {
                            return
                        }
                        guard callState.scheduleTimestamp != nil else {
                            return
                        }
                        
                        if callState.canManageCall {
                            groupCall.startScheduled()
                        } else {
                            groupCall.toggleScheduledSubscription(!callState.subscribedToScheduled)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: microphoneButtonDiameter, height: microphoneButtonDiameter)
            )
            if let microphoneButtonView = self.microphoneButton.view {
                if microphoneButtonView.superview == nil {
                    self.containerView.addSubview(microphoneButtonView)
                }
                transition.setPosition(view: microphoneButtonView, position: microphoneButtonFrame.center)
                transition.setBounds(view: microphoneButtonView, bounds: CGRect(origin: CGPoint(), size: microphoneButtonFrame.size))
            }
            
            let videoButtonContent: VideoChatActionButtonComponent.Content
            if let callState = self.callState, let muteState = callState.muteState, !muteState.canUnmute {
                var buttonAudio: VideoChatActionButtonComponent.Content.Audio = .speaker
                var buttonIsEnabled = false
                if let (availableOutputs, maybeCurrentOutput) = self.audioOutputState, let currentOutput = maybeCurrentOutput {
                    buttonIsEnabled = availableOutputs.count > 1
                    switch currentOutput {
                    case .builtin:
                        buttonAudio = .builtin
                    case .speaker:
                        buttonAudio = .speaker
                    case .headphones:
                        buttonAudio = .headphones
                    case let .port(port):
                        var type: VideoChatActionButtonComponent.Content.BluetoothType = .generic
                        let portName = port.name.lowercased()
                        if portName.contains("airpods max") {
                            type = .airpodsMax
                        } else if portName.contains("airpods pro") {
                            type = .airpodsPro
                        } else if portName.contains("airpods") {
                            type = .airpods
                        }
                        buttonAudio = .bluetooth(type)
                    }
                    if availableOutputs.count <= 1 {
                        buttonAudio = .none
                    }
                }
                videoButtonContent = .audio(audio: buttonAudio, isEnabled: buttonIsEnabled)
            } else {
                videoButtonContent = .video(isActive: false)
            }
            let _ = self.videoButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(VideoChatActionButtonComponent(
                        strings: environment.strings,
                        content: videoButtonContent,
                        microphoneState: actionButtonMicrophoneState,
                        isCollapsed: areButtonsCollapsed
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let callState = self.callState, let muteState = callState.muteState, !muteState.canUnmute {
                            self.onAudioRoutePressed()
                        } else {
                            self.onCameraPressed()
                        }
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: CGSize(width: actionButtonDiameter, height: actionButtonDiameter)
            )
            if let videoButtonView = self.videoButton.view {
                if videoButtonView.superview == nil {
                    self.containerView.addSubview(videoButtonView)
                }
                transition.setPosition(view: videoButtonView, position: leftActionButtonFrame.center)
                transition.setBounds(view: videoButtonView, bounds: CGRect(origin: CGPoint(), size: leftActionButtonFrame.size))
            }
            
            let _ = self.leaveButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(VideoChatActionButtonComponent(
                        strings: environment.strings,
                        content: .leave,
                        microphoneState: actionButtonMicrophoneState,
                        isCollapsed: areButtonsCollapsed
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.onLeavePressed()
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: CGSize(width: actionButtonDiameter, height: actionButtonDiameter)
            )
            if let leaveButtonView = self.leaveButton.view {
                if leaveButtonView.superview == nil {
                    self.containerView.addSubview(leaveButtonView)
                }
                transition.setPosition(view: leaveButtonView, position: rightActionButtonFrame.center)
                transition.setBounds(view: leaveButtonView, bounds: CGRect(origin: CGPoint(), size: rightActionButtonFrame.size))
            }
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class VideoChatScreenV2Impl: ViewControllerComponentContainer, VoiceChatController {
    final class InitialData {
        let peer: EnginePeer?
        let members: PresentationGroupCallMembers?
        let callState: PresentationGroupCallState
        let invitedPeers: [VideoChatScreenComponent.InvitedPeer]
        
        init(
            peer: EnginePeer?,
            members: PresentationGroupCallMembers?,
            callState: PresentationGroupCallState,
            invitedPeers: [VideoChatScreenComponent.InvitedPeer]
        ) {
            self.peer = peer
            self.members = members
            self.callState = callState
            self.invitedPeers = invitedPeers
        }
    }
    
    public fileprivate(set) var call: VideoChatCall
    public var currentOverlayController: VoiceChatOverlayController?
    public var parentNavigationController: NavigationController?
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    
    private var isDismissed: Bool = true
    private var didAppearOnce: Bool = false
    private var isAnimatingDismiss: Bool = false
    
    private var idleTimerExtensionDisposable: Disposable?
    
    private var sourceCallController: CallController?

    public init(
        initialData: InitialData,
        call: VideoChatCall,
        sourceCallController: CallController?
    ) {
        self.call = call
        self.sourceCallController = sourceCallController

        let theme = customizeDefaultDarkPresentationTheme(
            theme: defaultDarkPresentationTheme,
            editing: false,
            title: nil,
            accentColor: UIColor(rgb: 0x3E88F7),
            backgroundColors: [],
            bubbleColors: [],
            animateBubbleColors: false
        )
        
        super.init(
            context: call.accountContext,
            component: VideoChatScreenComponent(
                initialData: initialData,
                initialCall: call
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .default,
            presentationMode: .default,
            theme: .custom(theme)
        )
        
        self.flatReceivesModalTransition = true
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.idleTimerExtensionDisposable?.dispose()
    }
    
    func updateCall(call: VideoChatCall) {
        self.call = call
        if let component = self.component.wrapped as? VideoChatScreenComponent {
            // This is only to clear the reference to regular call
            self.updateComponent(component: AnyComponent(VideoChatScreenComponent(
                initialData: component.initialData,
                initialCall: call
            )), transition: .immediate)
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.isDismissed {
            self.isDismissed = false
            
            if let componentView = self.node.hostView.componentView as? VideoChatScreenComponent.View {
                if let sourceCallController = self.sourceCallController {
                    self.sourceCallController = nil
                    componentView.animateIn(sourceCallController: sourceCallController)
                } else {
                    componentView.animateIn()
                }
            }
        }
        
        if !self.didAppearOnce {
            self.didAppearOnce = true
            
            self.idleTimerExtensionDisposable?.dispose()
            self.idleTimerExtensionDisposable = self.call.accountContext.sharedContext.applicationBindings.pushIdleTimerExtension()
        }
        
        DispatchQueue.main.async {
            self.onViewDidAppear?()
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.idleTimerExtensionDisposable?.dispose()
        self.idleTimerExtensionDisposable = nil
        
        self.didAppearOnce = false
        self.notifyDismissed()
    }
    
    func notifyDismissed() {
        if !self.isDismissed {
            self.isDismissed = true
            DispatchQueue.main.async {
                self.onViewDidDisappear?()
            }
        }
    }

    public func dismiss(closing: Bool, manual: Bool) {
        self.dismiss()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isAnimatingDismiss {
            self.notifyDismissed()
            
            if let componentView = self.node.hostView.componentView as? VideoChatScreenComponent.View {
                self.isAnimatingDismiss = true
                componentView.animateOut(completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isAnimatingDismiss = false
                    self.superDismiss()
                    completion?()
                })
            } else {
                self.superDismiss()
                completion?()
            }
        }
    }
    
    func superDismiss() {
        super.dismiss()
    }
    
    static func initialData(call: VideoChatCall) -> Signal<InitialData, NoError> {
        switch call {
        case let .group(groupCall):
            let callPeer: Signal<EnginePeer?, NoError>
            if let peerId = groupCall.peerId {
                callPeer = groupCall.accountContext.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                )
            } else {
                callPeer = .single(nil)
            }
            let accountContext = groupCall.accountContext
            let invitedPeers = groupCall.invitedPeers |> take(1) |> mapToSignal { invitedPeers in
                return accountContext.engine.data.get(
                    EngineDataList(invitedPeers.map(\.id).map({ TelegramEngine.EngineData.Item.Peer.Peer(id: $0) }))
                )
            }
            return combineLatest(
                callPeer,
                groupCall.members |> take(1),
                groupCall.state |> take(1),
                invitedPeers
            )
            |> map { peer, members, callState, invitedPeers -> InitialData in
                return InitialData(
                    peer: peer,
                    members: members,
                    callState: callState,
                    invitedPeers: invitedPeers.compactMap { peer -> VideoChatScreenComponent.InvitedPeer? in
                        guard let peer else {
                            return nil
                        }
                        return VideoChatScreenComponent.InvitedPeer(peer: peer, state: nil)
                    }
                )
            }
        case let .conferenceSource(conferenceSource):
            return combineLatest(
                VideoChatScreenComponent.View.groupCallStateForConferenceSource(conferenceSource: conferenceSource) |> take(1),
                VideoChatScreenComponent.View.groupCallMembersForConferenceSource(conferenceSource: conferenceSource) |> take(1)
            )
            |> map { stateAndInvitedPeers, members in
                let (state, invitedPeers) = stateAndInvitedPeers
                return InitialData(
                    peer: nil,
                    members: members,
                    callState: state,
                    invitedPeers: invitedPeers
                )
            }
        }
    }
}
