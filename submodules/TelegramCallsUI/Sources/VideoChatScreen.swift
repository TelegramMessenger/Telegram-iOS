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

final class VideoChatScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let initialData: VideoChatScreenV2Impl.InitialData
    let call: PresentationGroupCall

    init(
        initialData: VideoChatScreenV2Impl.InitialData,
        call: PresentationGroupCall
    ) {
        self.initialData = initialData
        self.call = call
    }

    static func ==(lhs: VideoChatScreenComponent, rhs: VideoChatScreenComponent) -> Bool {
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
        
        var peer: EnginePeer?
        var callState: PresentationGroupCallState?
        var stateDisposable: Disposable?
        
        var audioOutputState: ([AudioSessionOutput], AudioSessionOutput?)?
        var audioOutputStateDisposable: Disposable?
        
        var displayAsPeers: [FoundPeer]?
        var displayAsPeersDisposable: Disposable?
        
        var inviteLinks: GroupCallInviteLinks?
        var inviteLinksDisposable: Disposable?
        
        var isPushToTalkActive: Bool = false
        
        var members: PresentationGroupCallMembers?
        var membersDisposable: Disposable?
        
        var speakingParticipantPeers: [EnginePeer] = []
        var visibleParticipants: Set<EnginePeer.Id> = Set()
        
        let isPresentedValue = ValuePromise<Bool>(false, ignoreRepeated: true)
        var applicationStateDisposable: Disposable?
        
        var expandedParticipantsVideoState: VideoChatParticipantsComponent.ExpandedVideoState?
        var focusedSpeakerAutoSwitchDeadline: Double = 0.0
        var isTwoColumnSidebarHidden: Bool = false
        
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
            self.applicationStateDisposable?.dispose()
            self.reconnectedAsEventsDisposable?.dispose()
            self.memberEventsDisposable?.dispose()
            self.displayAsPeersDisposable?.dispose()
            self.audioOutputStateDisposable?.dispose()
            self.inviteLinksDisposable?.dispose()
            self.updateAvatarDisposable.dispose()
            self.inviteDisposable.dispose()
        }
        
        func animateIn() {
            self.verticalPanState = PanState(fraction: 1.0, scrollView: nil)
            self.state?.updated(transition: .immediate)
            
            self.verticalPanState = nil
            self.state?.updated(transition: .spring(duration: 0.5))
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.verticalPanState = PanState(fraction: 1.0, scrollView: nil)
            self.completionOnPanGestureApply = completion
            self.state?.updated(transition: .spring(duration: 0.5))
        }
        
        @objc public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
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
            guard let component = self.component else {
                return
            }
            guard let peerId = component.call.peerId else {
                return
            }
            
            let _ = (component.call.accountContext.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { [weak self] chatPeer in
                guard let self, let component = self.component, let environment = self.environment else {
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

                let controller = voiceChatTitleEditController(sharedContext: component.call.accountContext.sharedContext, account: component.call.accountContext.account, forceTheme: environment.theme, title: title, text: text, placeholder: EnginePeer(chatPeer).displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder), value: initialTitle, maxLength: 40, apply: { [weak self] title in
                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }
                    guard let title = title, title != initialTitle else {
                        return
                    }
                    
                    component.call.updateTitle(title)

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
            guard let component = self.component, let environment = self.environment else {
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
            let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
            environment.controller()?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: action), in: .current)
        }
        
        func presentShare(_ inviteLinks: GroupCallInviteLinks) {
            guard let component = self.component else {
                return
            }
            guard let peerId = component.call.peerId else {
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
            
            let _ = (component.call.accountContext.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let component = self.component, let environment = self.environment else {
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
                let shareController = ShareController(context: component.call.accountContext, subject: .url(inviteLinks.listenerLink), segmentedValues: segmentedValues, forceTheme: environment.theme, forcedActionTitle: environment.strings.VoiceChat_CopyInviteLink)
                shareController.completed = { [weak self] peerIds in
                    guard let self, let component = self.component else {
                        return
                    }
                    let _ = (component.call.accountContext.engine.data.get(
                        EngineDataList(
                            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                        )
                    )
                    |> deliverOnMainQueue).start(next: { [weak self] peerList in
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        
                        let peers = peerList.compactMap { $0 }
                        let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                        
                        let text: String
                        var isSavedMessages = false
                        if peers.count == 1, let peer = peers.first {
                            isSavedMessages = peer.id == component.call.accountContext.account.peerId
                            let peerName = peer.id == component.call.accountContext.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.VoiceChat_ForwardTooltip_Chat(peerName).string
                        } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                            let firstPeerName = firstPeer.id == component.call.accountContext.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            let secondPeerName = secondPeer.id == component.call.accountContext.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
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
                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }
                    let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                    environment.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.VoiceChat_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                }
                environment.controller()?.present(shareController, in: .window(.root))
            })
        }
        
        private func onCameraPressed() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            HapticFeedback().impact(.light)
            if component.call.hasVideo {
                component.call.disableVideo()
            } else {
                let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                DeviceAccess.authorizeAccess(to: .camera(.videoCall), onlyCheck: true, presentationData: presentationData, present: { [weak self] c, a in
                    guard let self, let environment = self.environment, let controller = environment.controller() else {
                        return
                    }
                    controller.present(c, in: .window(.root), with: a)
                }, openSettings: { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.call.accountContext.sharedContext.applicationBindings.openSettings()
                }, _: { [weak self] ready in
                    guard let self, let component = self.component, let environment = self.environment, ready else {
                        return
                    }
                    var isFrontCamera = true
                    let videoCapturer = OngoingCallVideoCapturer()
                    let input = videoCapturer.video()
                    if let videoView = self.videoRenderingContext.makeView(input: input, blur: false) {
                        videoView.updateIsEnabled(true)
                        
                        let cameraNode = GroupVideoNode(videoView: videoView, backdropVideoView: nil)
                        let controller = VoiceChatCameraPreviewController(sharedContext: component.call.accountContext.sharedContext, cameraNode: cameraNode, shareCamera: { [weak self] _, unmuted in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            component.call.setIsMuted(action: unmuted ? .unmuted : .muted(isPushToTalkActive: false))
                            (component.call as! PresentationGroupCallImpl).requestVideo(capturer: videoCapturer, useFrontCamera: isFrontCamera)
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
            guard let component = self.component, let environment = self.environment else {
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
                        component.call.setCurrentAudioOutput(output)
                        break
                    }
                }
            } else {
                let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
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
                        
                        guard let self, let component = self.component else {
                            return
                        }
                        component.call.setCurrentAudioOutput(output)
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
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            //TODO:release
            let isScheduled = !"".isEmpty
            
            let action: (Bool) -> Void = { [weak self] terminateIfPossible in
                guard let self, let component = self.component else {
                    return
                }

                let _ = component.call.leave(terminateIfPossible: terminateIfPossible).startStandalone()
                
                if let controller = self.environment?.controller() as? VideoChatScreenV2Impl {
                    controller.dismiss(closing: true, manual: false)
                }
            }
            
            if let callState = self.callState, callState.canManageCall {
                let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
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
                    
                    guard let self, let component = self.component, let environment = self.environment else {
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
                        let alertController = textAlertController(context: component.call.accountContext, forceTheme: environment.theme, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: environment.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: isScheduled ? environment.strings.VoiceChat_CancelConfirmationEnd :  environment.strings.VoiceChat_EndConfirmationEnd, action: {
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
                self.callState = component.initialData.callState
                
                self.membersDisposable = (component.call.members
                |> deliverOnMainQueue).startStrict(next: { [weak self] members in
                    guard let self else {
                        return
                    }
                    if self.members != members {
                        var members = members
                        
                        #if DEBUG && false
                        if let membersValue = members {
                            var participants = membersValue.participants
                            for i in 1 ... 20 {
                                for participant in membersValue.participants {
                                    guard let user = participant.peer as? TelegramUser else {
                                        continue
                                    }
                                    let mappedUser = TelegramUser(
                                        id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(user.id.id._internalGetInt64Value() + Int64(i))),
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
                                        profileBackgroundEmojiId: user.profileBackgroundEmojiId,
                                        subscriberCount: user.subscriberCount,
                                        verification: user.verification
                                    )
                                    participants.append(GroupCallParticipantsContext.Participant(
                                        peer: mappedUser,
                                        ssrc: participant.ssrc,
                                        videoDescription: participant.videoDescription,
                                        presentationDescription: participant.presentationDescription,
                                        joinTimestamp: participant.joinTimestamp,
                                        raiseHandRating: participant.raiseHandRating,
                                        hasRaiseHand: participant.hasRaiseHand,
                                        activityTimestamp: participant.activityTimestamp,
                                        activityRank: participant.activityRank,
                                        muteState: participant.muteState,
                                        volume: participant.volume,
                                        about: participant.about,
                                        joinedVideo: participant.joinedVideo
                                    ))
                                }
                            }
                            members = PresentationGroupCallMembers(
                                participants: participants,
                                speakingParticipants: membersValue.speakingParticipants,
                                totalCount: membersValue.totalCount,
                                loadMoreToken: membersValue.loadMoreToken
                            )
                        }
                        #endif
                        
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
                
                self.stateDisposable = (component.call.state
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
                
                self.applicationStateDisposable = (combineLatest(queue: .mainQueue(),
                    component.call.accountContext.sharedContext.applicationBindings.applicationIsActive,
                    self.isPresentedValue.get()
                )
                |> deliverOnMainQueue).startStrict(next: { [weak self] applicationIsActive, isPresented in
                    guard let self, let component = self.component else {
                        return
                    }
                    let suspendVideoChannelRequests = !applicationIsActive || !isPresented
                    component.call.setSuspendVideoChannelRequests(suspendVideoChannelRequests)
                })
                
                self.audioOutputStateDisposable = (component.call.audioOutputState
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
                
                let currentAccountPeer = component.call.accountContext.account.postbox.loadedPeerWithId(component.call.accountContext.account.peerId)
                |> map { peer in
                    return [FoundPeer(peer: peer, subscribers: nil)]
                }
                let cachedDisplayAsAvailablePeers: Signal<[FoundPeer], NoError>
                if let peerId = component.call.peerId {
                    cachedDisplayAsAvailablePeers = component.call.accountContext.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId)
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
                self.displayAsPeersDisposable = (displayAsPeers
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.displayAsPeers = value
                })
                
                self.inviteLinksDisposable = (component.call.inviteLinks
                |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.inviteLinks = value
                })
                
                self.reconnectedAsEventsDisposable = (component.call.reconnectedAsEvents
                |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }
                    let text: String
                    if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                        text = environment.strings.LiveStream_DisplayAsSuccess(peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                    } else {
                        text = environment.strings.VoiceChat_DisplayAsSuccess(peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                    }
                    self.presentUndoOverlay(content: .invitedToVoiceChat(context: component.call.accountContext, peer: peer, title: nil, text: text, action: nil, duration: 3), action: { _ in return false })
                })
                
                self.memberEventsDisposable = (component.call.memberEvents
                |> deliverOnMainQueue).start(next: { [weak self] event in
                    guard let self, let members = self.members, let component = self.component, let environment = self.environment else {
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
                            let text = environment.strings.VoiceChat_PeerJoinedText(event.peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                            self.presentUndoOverlay(content: .invitedToVoiceChat(context: component.call.accountContext, peer: event.peer, title: nil, text: text, action: nil, duration: 3), action: { _ in return false })
                        }
                    }
                })
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
            }
            
            let navigationRightButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - navigationButtonAreaWidth + floor((navigationButtonAreaWidth - navigationRightButtonSize.width) * 0.5), y: topInset + floor((navigationBarHeight - navigationRightButtonSize.height) * 0.5)), size: navigationRightButtonSize)
            if let navigationRightButtonView = self.navigationRightButton.view {
                if navigationRightButtonView.superview == nil {
                    self.containerView.addSubview(navigationRightButtonView)
                }
                transition.setFrame(view: navigationRightButtonView, frame: navigationRightButtonFrame)
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
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(VideoChatTitleComponent(
                    title: self.callState?.title ?? self.peer?.debugDisplayTitle ?? " ",
                    status: idleTitleStatusText,
                    isRecording: self.callState?.recordingStartTimestamp != nil,
                    strings: environment.strings,
                    tapAction: self.callState?.recordingStartTimestamp != nil ? { [weak self] in
                        guard let self, let component = self.component, let environment = self.environment else {
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
                            environment.controller()?.present(TooltipScreen(account: component.call.accountContext.account, sharedContext: component.call.accountContext.sharedContext, text: .plain(text: text), icon: nil, location: .point(location.offsetBy(dx: 1.0, dy: 0.0), .top), displayDuration: .custom(3.0), shouldDismissOnTouch: { _, _ in
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
                    call: component.call,
                    participants: mappedParticipants,
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
                    call: component.call,
                    strings: environment.strings,
                    content: micButtonContent,
                    isCollapsed: areButtonsCollapsed,
                    updateUnmutedStateIsPushToTalk: { [weak self] unmutedStateIsPushToTalk in
                        guard let self, let component = self.component else {
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
                                        component.call.setIsMuted(action: .muted(isPushToTalkActive: true))
                                    } else {
                                        self.isPushToTalkActive = false
                                    }
                                } else {
                                    self.isPushToTalkActive = true
                                    component.call.setIsMuted(action: .muted(isPushToTalkActive: true))
                                }
                            } else {
                                if let muteState = callState.muteState {
                                    if muteState.canUnmute {
                                        component.call.setIsMuted(action: .unmuted)
                                    }
                                }
                                self.isPushToTalkActive = false
                            }
                            self.state?.updated(transition: .spring(duration: 0.5))
                        } else {
                            component.call.setIsMuted(action: .muted(isPushToTalkActive: false))
                            self.isPushToTalkActive = false
                            self.state?.updated(transition: .spring(duration: 0.5))
                        }
                    },
                    raiseHand: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard let callState = self.callState else {
                            return
                        }
                        if !callState.raisedHand {
                            component.call.raiseHand()
                        }
                    },
                    scheduleAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard let callState = self.callState else {
                            return
                        }
                        guard callState.scheduleTimestamp != nil else {
                            return
                        }
                        
                        if callState.canManageCall {
                            component.call.startScheduled()
                        } else {
                            component.call.toggleScheduledSubscription(!callState.subscribedToScheduled)
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
                //TODO:release
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
        
        init(
            peer: EnginePeer?,
            members: PresentationGroupCallMembers?,
            callState: PresentationGroupCallState
        ) {
            self.peer = peer
            self.members = members
            self.callState = callState
        }
    }
    
    public let call: PresentationGroupCall
    public var currentOverlayController: VoiceChatOverlayController?
    public var parentNavigationController: NavigationController?
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    
    private var isDismissed: Bool = true
    private var didAppearOnce: Bool = false
    private var isAnimatingDismiss: Bool = false
    
    private var idleTimerExtensionDisposable: Disposable?

    public init(
        initialData: InitialData,
        call: PresentationGroupCall
    ) {
        self.call = call

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
                call: call
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .default,
            presentationMode: .default,
            theme: .custom(theme)
        )
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.idleTimerExtensionDisposable?.dispose()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.isDismissed {
            self.isDismissed = false
            
            if let componentView = self.node.hostView.componentView as? VideoChatScreenComponent.View {
                componentView.animateIn()
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
    
    static func initialData(call: PresentationGroupCall) -> Signal<InitialData, NoError> {
        let callPeer: Signal<EnginePeer?, NoError>
        if let peerId = call.peerId {
            callPeer = call.accountContext.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            )
        } else {
            callPeer = .single(nil)
        }
        return combineLatest(
            callPeer,
            call.members |> take(1),
            call.state |> take(1)
        )
        |> map { peer, members, callState -> InitialData in
            return InitialData(
                peer: peer,
                members: members,
                callState: callState
            )
        }
    }
}
