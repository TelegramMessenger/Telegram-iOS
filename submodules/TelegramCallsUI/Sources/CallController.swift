import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramVoip
import TelegramAudio
import AccountContext
import TelegramNotices
import AppBundle
import TooltipUI

protocol CallControllerNodeProtocol: AnyObject {
    var isMuted: Bool { get set }
    
    var toggleMute: (() -> Void)? { get set }
    var setCurrentAudioOutput: ((AudioSessionOutput) -> Void)? { get set }
    var beginAudioOuputSelection: ((Bool) -> Void)? { get set }
    var acceptCall: (() -> Void)? { get set }
    var endCall: (() -> Void)? { get set }
    var back: (() -> Void)? { get set }
    var presentCallRating: ((CallId, Bool) -> Void)? { get set }
    var present: ((ViewController) -> Void)? { get set }
    var callEnded: ((Bool) -> Void)? { get set }
    var dismissedInteractively: (() -> Void)? { get set }
    var dismissAllTooltips: (() -> Void)? { get set }
    
    func updateAudioOutputs(availableOutputs: [AudioSessionOutput], currentOutput: AudioSessionOutput?)
    func updateCallState(_ callState: PresentationCallState)
    func updatePeer(accountPeer: Peer, peer: Peer, hasOther: Bool)
    
    func animateIn()
    func animateOut(completion: @escaping () -> Void)
    func expandFromPipIfPossible()
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition)
}

public final class CallController: ViewController {
    public enum Call: Equatable {
        case call(PresentationCall)
        case groupCall(PresentationGroupCall)
        
        public static func ==(lhs: Call, rhs: Call) -> Bool {
            switch lhs {
            case let .call(lhsCall):
                if case let .call(rhsCall) = rhs {
                    return lhsCall === rhsCall
                } else {
                    return false
                }
            case let .groupCall(lhsGroupCall):
                if case let .groupCall(rhsGroupCall) = rhs {
                    return lhsGroupCall === rhsGroupCall
                } else {
                    return false
                }
            }
        }
        
        public var context: AccountContext {
            switch self {
            case let .call(call):
                return call.context
            case let .groupCall(groupCall):
                return groupCall.accountContext
            }
        }
        
        public var peerId: EnginePeer.Id? {
            switch self {
            case let .call(call):
                return call.peerId
            case let .groupCall(groupCall):
                return groupCall.peerId
            }
        }
        
        public func requestVideo() {
            switch self {
            case let .call(call):
                call.requestVideo()
            case let .groupCall(groupCall):
                groupCall.requestVideo()
            }
        }
        
        public func disableVideo() {
            switch self {
            case let .call(call):
                call.disableVideo()
            case let .groupCall(groupCall):
                groupCall.disableVideo()
            }
        }
        
        public func disableScreencast() {
            switch self {
            case let .call(call):
                (call as? PresentationCallImpl)?.disableScreencast()
            case let .groupCall(groupCall):
                groupCall.disableScreencast()
            }
        }
        
        public func switchVideoCamera() {
            switch self {
            case let .call(call):
                call.switchVideoCamera()
            case let .groupCall(groupCall):
                groupCall.switchVideoCamera()
            }
        }
        
        public func toggleIsMuted() {
            switch self {
            case let .call(call):
                call.toggleIsMuted()
            case let .groupCall(groupCall):
                groupCall.toggleIsMuted()
            }
        }
        
        public func setCurrentAudioOutput(_ output: AudioSessionOutput) {
            switch self {
            case let .call(call):
                call.setCurrentAudioOutput(output)
            case let .groupCall(groupCall):
                groupCall.setCurrentAudioOutput(output)
            }
        }
        
        public var isMuted: Signal<Bool, NoError> {
            switch self {
            case let .call(call):
                return call.isMuted
            case let .groupCall(groupCall):
                return groupCall.isMuted
            }
        }
        
        public var audioLevel: Signal<Float, NoError> {
            switch self {
            case let .call(call):
                return call.audioLevel
            case let .groupCall(groupCall):
                var audioLevelId: UInt32?
                return groupCall.audioLevels |> map { audioLevels -> Float in
                    var result: Float = 0
                    for item in audioLevels {
                        if let audioLevelId {
                            if item.1 == audioLevelId {
                                result = item.2
                                break
                            }
                        } else {
                            if item.1 != 0 {
                                audioLevelId = item.1
                                result = item.2
                                break
                            }
                        }
                    }
                    
                    return result
                }
            }
        }
        
        public var isOutgoing: Bool {
            switch self {
            case let .call(call):
                return call.isOutgoing
            case .groupCall:
                return false
            }
        }
        
        public func makeOutgoingVideoView(completion: @escaping (PresentationCallVideoView?) -> Void) {
            switch self {
            case let .call(call):
                call.makeOutgoingVideoView(completion: completion)
            case let .groupCall(groupCall):
                groupCall.makeOutgoingVideoView(requestClone: false, completion: { a, _ in
                    completion(a)
                })
            }
        }
        
        public var audioOutputState: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> {
            switch self {
            case let .call(call):
                return call.audioOutputState
            case let .groupCall(groupCall):
                return groupCall.audioOutputState
            }
        }
        
        public func debugInfo() -> Signal<(String, String), NoError> {
            switch self {
            case let .call(call):
                return call.debugInfo()
            case .groupCall:
                return .single(("", ""))
            }
        }
        
        public func answer() {
            switch self {
            case let .call(call):
                call.answer()
            case .groupCall:
                break
            }
        }
        
        public func hangUp() -> Signal<Bool, NoError> {
            switch self {
            case let .call(call):
                return call.hangUp()
            case let .groupCall(groupCall):
                return groupCall.leave(terminateIfPossible: false)
            }
        }
    }
    
    private var controllerNode: CallControllerNodeProtocol {
        return self.displayNode as! CallControllerNodeProtocol
    }
    
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let isDataReady = Promise<Bool>(false)
    private let isContentsReady = Promise<Bool>(false)
    
    private let sharedContext: SharedAccountContext
    private let account: Account
    public let call: CallController.Call
    private let easyDebugAccess: Bool
    
    private var presentationData: PresentationData
    private var didPlayPresentationAnimation = false
    
    private var peer: Peer?
    
    private var peerDisposable: Disposable?
    private var disposable: Disposable?
    
    private var callMutedDisposable: Disposable?
    private var isMuted = false
    
    private var presentedCallRating = false
    
    private var audioOutputStateDisposable: Disposable?
    private var audioOutputState: ([AudioSessionOutput], AudioSessionOutput?)?
    
    private let idleTimerExtensionDisposable = MetaDisposable()
    
    public var restoreUIForPictureInPicture: ((@escaping (Bool) -> Void) -> Void)?
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    
    public init(sharedContext: SharedAccountContext, account: Account, call: CallController.Call, easyDebugAccess: Bool) {
        self.sharedContext = sharedContext
        self.account = account
        self.call = call
        self.easyDebugAccess = easyDebugAccess
        
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self._ready.set(combineLatest(queue: .mainQueue(), self.isDataReady.get(), self.isContentsReady.get())
        |> map { a, b -> Bool in
            return a && b
        }
        |> filter { $0 }
        |> take(1)
        |> timeout(2.0, queue: .mainQueue(), alternate: .single(true)))
        
        self.isOpaqueWhenInOverlay = true
        
        self.statusBar.statusBarStyle = .White
        self.statusBar.ignoreInCall = true
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
        
        switch call {
        case let .call(call):
            self.disposable = (call.state
            |> deliverOnMainQueue).start(next: { [weak self] callState in
                self?.callStateUpdated(callState)
            })
        case let .groupCall(groupCall):
            let accountPeerId = groupCall.account.peerId
            let videoEndpoints: Signal<(local: String?, remote: PresentationGroupCallRequestedVideo?), NoError> = groupCall.members
            |> map { members -> (local: String?, remote: PresentationGroupCallRequestedVideo?) in
                guard let members else {
                    return (nil, nil)
                }
                var local: String?
                var remote: PresentationGroupCallRequestedVideo?
                for participant in members.participants {
                    if let video = participant.requestedPresentationVideoChannel(minQuality: .thumbnail, maxQuality: .full) ?? participant.requestedVideoChannel(minQuality: .thumbnail, maxQuality: .full) {
                        if participant.peer.id == accountPeerId {
                            local = video.endpointId
                        } else {
                            if remote == nil {
                                remote = video
                            }
                        }
                    }
                }
                return (local, remote)
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                return lhs == rhs
            })
            
            var startTimestamp: Double?
            self.disposable = (combineLatest(queue: .mainQueue(),
                groupCall.state,
                videoEndpoints
            )
            |> deliverOnMainQueue).start(next: { [weak self] callState, videoEndpoints in
                guard let self else {
                    return
                }
                let mappedState: PresentationCallState.State
                switch callState.networkState {
                case .connecting:
                    mappedState = .connecting(nil)
                case .connected:
                    let timestamp = startTimestamp ?? CFAbsoluteTimeGetCurrent()
                    startTimestamp = timestamp
                    mappedState = .active(timestamp, nil, Data())
                }
                
                var mappedLocalVideoState: PresentationCallState.VideoState = .inactive
                var mappedRemoteVideoState: PresentationCallState.RemoteVideoState = .inactive
                
                if let local = videoEndpoints.local {
                    mappedLocalVideoState = .active(isScreencast: false, endpointId: local)
                }
                if let remote = videoEndpoints.remote {
                    mappedRemoteVideoState = .active(endpointId: remote.endpointId)
                }
                
                if case let .groupCall(groupCall) = self.call {
                    var requestedVideo: [PresentationGroupCallRequestedVideo] = []
                    if let remote = videoEndpoints.remote {
                        requestedVideo.append(remote)
                    }
                    groupCall.setRequestedVideoList(items: requestedVideo)
                }
                
                self.callStateUpdated(PresentationCallState(
                    state: mappedState,
                    videoState: mappedLocalVideoState,
                    remoteVideoState: mappedRemoteVideoState,
                    remoteAudioState: .active,
                    remoteBatteryLevel: .normal
                ))
            })
        }
        
        self.callMutedDisposable = (call.isMuted
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.isMuted = value
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.isMuted = value
                }
            }
        })
        
        self.audioOutputStateDisposable = (call.audioOutputState
        |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                strongSelf.audioOutputState = state
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.updateAudioOutputs(availableOutputs: state.0, currentOutput: state.1)
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.peerDisposable?.dispose()
        self.disposable?.dispose()
        self.callMutedDisposable?.dispose()
        self.audioOutputStateDisposable?.dispose()
        self.idleTimerExtensionDisposable.dispose()
    }
    
    private func callStateUpdated(_ callState: PresentationCallState) {
        if self.isNodeLoaded {
            self.controllerNode.updateCallState(callState)
        }
    }
    
    override public func loadDisplayNode() {
        let displayNode = CallControllerNodeV2(
            sharedContext: self.sharedContext,
            account: self.account,
            presentationData: self.presentationData,
            statusBar: self.statusBar,
            debugInfo: self.call.debugInfo(),
            easyDebugAccess: self.easyDebugAccess,
            call: self.call
        )
        self.displayNode = displayNode
        self.isContentsReady.set(displayNode.isReady.get())
        
        displayNode.restoreUIForPictureInPicture = { [weak self] completion in
            guard let self, let restoreUIForPictureInPicture = self.restoreUIForPictureInPicture else {
                completion(false)
                return
            }
            restoreUIForPictureInPicture(completion)
        }
        self.displayNodeDidLoad()
        
        self.controllerNode.toggleMute = { [weak self] in
            self?.call.toggleIsMuted()
        }
        
        self.controllerNode.setCurrentAudioOutput = { [weak self] output in
            self?.call.setCurrentAudioOutput(output)
        }
        
        self.controllerNode.beginAudioOuputSelection = { [weak self] hasMute in
            guard let strongSelf = self, let (availableOutputs, currentOutput) = strongSelf.audioOutputState else {
                return
            }
            guard availableOutputs.count >= 2 else {
                return
            }
            if availableOutputs.count == 2 {
                for output in availableOutputs {
                    if output != currentOutput {
                        strongSelf.call.setCurrentAudioOutput(output)
                        break
                    }
                }
            } else {
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
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
                            title = strongSelf.presentationData.strings.Call_AudioRouteSpeaker
                            icon = generateScaledImage(image: UIImage(bundleImageName: "Call/CallSpeakerButton"), size: CGSize(width: 48.0, height: 48.0), opaque: false)
                        case .headphones:
                            title = strongSelf.presentationData.strings.Call_AudioRouteHeadphones
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
                    items.append(CallRouteActionSheetItem(title: title, icon: icon, selected: output == currentOutput, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        self?.call.setCurrentAudioOutput(output)
                    }))
                }
                
                if hasMute {
                    items.append(CallRouteActionSheetItem(title: strongSelf.presentationData.strings.Call_AudioRouteMute, icon:  generateScaledImage(image: UIImage(bundleImageName: "Call/CallMuteButton"), size: CGSize(width: 48.0, height: 48.0), opaque: false), selected: strongSelf.isMuted, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        self?.call.toggleIsMuted()
                    }))
                }
                
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Call_AudioRouteHide, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                strongSelf.present(actionSheet, in: .window(.calls))
            }
        }
        
        self.controllerNode.acceptCall = { [weak self] in
            let _ = self?.call.answer()
        }
        
        self.controllerNode.endCall = { [weak self] in
            let _ = self?.call.hangUp()
        }
        
        self.controllerNode.back = { [weak self] in
            let _ = self?.dismiss()
        }
        
        displayNode.conferenceAddParticipant = { [weak self] in
            guard let self else {
                return
            }
            self.conferenceAddParticipant()
        }
        
        self.controllerNode.presentCallRating = { [weak self] callId, isVideo in
            if let strongSelf = self, !strongSelf.presentedCallRating {
                strongSelf.presentedCallRating = true
                
                Queue.mainQueue().after(0.5, {
                    let window = strongSelf.window
                    let controller = callRatingController(sharedContext: strongSelf.sharedContext, account: strongSelf.account, callId: callId, userInitiated: false, isVideo: isVideo, present: { c, a in
                        if let window = window {
                            c.presentationArguments = a
                            window.present(c, on: .root, blockInteraction: false, completion: {})
                        }
                    }, push: { [weak self] c in
                        if let strongSelf = self {
                            strongSelf.push(c)
                        }
                    })
                    strongSelf.present(controller, in: .window(.root))
                })
            }
        }
        
        self.controllerNode.present = { [weak self] controller in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root))
            }
        }
        
        self.controllerNode.dismissAllTooltips = { [weak self] in
            if let strongSelf = self {
                strongSelf.forEachController({ controller in
                    if let controller = controller as? TooltipScreen {
                        controller.dismiss()
                    }
                    return true
                })
            }
        }
        
        self.controllerNode.callEnded = { [weak self] didPresentRating in
            if let strongSelf = self, !didPresentRating {
                let _ = (combineLatest(strongSelf.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.callListSettings]), ApplicationSpecificNotice.getCallsTabTip(accountManager: strongSelf.sharedContext.accountManager))
                |> map { sharedData, callsTabTip -> Int32 in
                    var value = false
                    if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings]?.get(CallListSettings.self) {
                        value = settings.showTab
                    }
                    if value {
                        return 3
                    } else {
                        return callsTabTip
                    }
                } |> deliverOnMainQueue).start(next: { [weak self] callsTabTip in
                    if let strongSelf = self {
                        if callsTabTip == 2 {
                            Queue.mainQueue().after(1.0) {
                                let controller = callSuggestTabController(sharedContext: strongSelf.sharedContext)
                                strongSelf.present(controller, in: .window(.root))
                            }
                        }
                        if callsTabTip < 3 {
                            let _ = ApplicationSpecificNotice.incrementCallsTabTips(accountManager: strongSelf.sharedContext.accountManager).start()
                        }
                    }
                })
            }
        }
        
        self.controllerNode.dismissedInteractively = { [weak self] in
            guard let self else {
                return
            }
            self.didPlayPresentationAnimation = false
            self.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        let callPeerView: Signal<PeerView?, NoError>
        if let peerId = self.call.peerId {
            callPeerView = self.account.postbox.peerView(id: peerId) |> map(Optional.init)
        } else {
            callPeerView = .single(nil)
        }
        
        self.peerDisposable = (combineLatest(queue: .mainQueue(),
            self.account.postbox.peerView(id: self.account.peerId) |> take(1),
            callPeerView,
            self.sharedContext.activeAccountsWithInfo |> take(1)
        )
        |> deliverOnMainQueue).start(next: { [weak self] accountView, view, activeAccountsWithInfo in
            if let strongSelf = self {
                if let view {
                    if let accountPeer = accountView.peers[accountView.peerId], let peer = view.peers[view.peerId] {
                        strongSelf.peer = peer
                        strongSelf.controllerNode.updatePeer(accountPeer: accountPeer, peer: peer, hasOther: activeAccountsWithInfo.accounts.count > 1)
                        strongSelf.isDataReady.set(.single(true))
                    }
                } else {
                    strongSelf.isDataReady.set(.single(true))
                }
            }
        })
        
        self.controllerNode.isMuted = self.isMuted
       
        if let audioOutputState = self.audioOutputState {
            self.controllerNode.updateAudioOutputs(availableOutputs: audioOutputState.0, currentOutput: audioOutputState.1)
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            
            self.controllerNode.animateIn()
        }
        
        self.idleTimerExtensionDisposable.set(self.sharedContext.applicationBindings.pushIdleTimerExtension())
        
        self.onViewDidAppear?()
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.idleTimerExtensionDisposable.set(nil)
        
        self.onViewDidDisappear?()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.didPlayPresentationAnimation = false
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            
            completion?()
        })
    }
    
    private func conferenceAddParticipant() {
        let controller = self.call.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(
            context: self.call.context,
            filter: [.onlyWriteable],
            hasChatListSelector: true,
            hasContactSelector: true,
            hasGlobalSearch: true,
            title: "Add Participant",
            pretendPresentedInModal: false
        ))
        controller.peerSelected = { [weak self, weak controller] peer, _ in
            controller?.dismiss()
            
            guard let self else {
                return
            }
            guard case let .call(call) = self.call else {
                return
            }
            guard let call = call as? PresentationCallImpl else {
                return
            }
            let _ = call.requestAddToConference(peerId: peer.id)
        }
        self.dismiss()
        
        (self.call.context.sharedContext.mainWindow?.viewController as? NavigationController)?.pushViewController(controller)
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    public func expandFromPipIfPossible() {
        self.controllerNode.expandFromPipIfPossible()
    }
}
