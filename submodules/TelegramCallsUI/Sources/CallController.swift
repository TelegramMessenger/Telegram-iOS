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
import CallScreen

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
    var willBeDismissedInteractively: (() -> Void)? { get set }
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
    public let call: PresentationCall
    private let easyDebugAccess: Bool
    
    private var presentationData: PresentationData
    private var didPlayPresentationAnimation = false
    
    private var peer: Peer?
    
    private var peerDisposable: Disposable?
    private var disposable: Disposable?
    
    private var callMutedDisposable: Disposable?
    private var isMuted: Bool = false
    
    private var presentedCallRating = false
    
    private var audioOutputStateDisposable: Disposable?
    private var audioOutputState: ([AudioSessionOutput], AudioSessionOutput?)?
    
    private let idleTimerExtensionDisposable = MetaDisposable()
    
    public var restoreUIForPictureInPicture: ((@escaping (Bool) -> Void) -> Void)?
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    
    private var isAnimatingDismiss: Bool = false
    private var isDismissed: Bool = false
    
    public init(sharedContext: SharedAccountContext, account: Account, call: PresentationCall, easyDebugAccess: Bool) {
        self.sharedContext = sharedContext
        self.account = account
        self.call = call
        self.easyDebugAccess = easyDebugAccess
        
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        if let data = call.context.currentAppConfiguration.with({ $0 }).data, data["ios_killswitch_modalcalls"] != nil {
        } else {
            self.navigationPresentation = .flatModal
            self.flatReceivesModalTransition = true
        }
        
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
        
        self.disposable = (call.state
        |> deliverOnMainQueue).start(next: { [weak self] callState in
            self?.callStateUpdated(callState)
        })
        
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
        
        self.controllerNode.willBeDismissedInteractively = { [weak self] in
            guard let self else {
                return
            }
            self.notifyDismissed()
        }
        self.controllerNode.dismissedInteractively = { [weak self] in
            guard let self else {
                return
            }
            self.didPlayPresentationAnimation = false
            self.superDismiss()
        }
        
        let callPeerView: Signal<PeerView?, NoError>
        callPeerView = self.account.postbox.peerView(id: self.call.peerId) |> map(Optional.init)
        
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
        
        self.isDismissed = false
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            
            self.controllerNode.animateIn()
        }
        
        self.idleTimerExtensionDisposable.set(self.sharedContext.applicationBindings.pushIdleTimerExtension())
        
        DispatchQueue.main.async { [weak self] in
            self?.onViewDidAppear?()
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.idleTimerExtensionDisposable.set(nil)
        
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
    
    final class AnimateOutToGroupChat {
        let containerView: UIView
        let incomingPeerId: EnginePeer.Id
        let incomingVideoLayer: CALayer?
        let incomingVideoPlaceholder: VideoSource.Output?
        
        init(
            containerView: UIView,
            incomingPeerId: EnginePeer.Id,
            incomingVideoLayer: CALayer?,
            incomingVideoPlaceholder: VideoSource.Output?
        ) {
            self.containerView = containerView
            self.incomingPeerId = incomingPeerId
            self.incomingVideoLayer = incomingVideoLayer
            self.incomingVideoPlaceholder = incomingVideoPlaceholder
        }
    }
    
    func animateOutToGroupChat(completion: @escaping () -> Void) -> AnimateOutToGroupChat? {
        return (self.controllerNode as? CallControllerNodeV2)?.animateOutToGroupChat(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isAnimatingDismiss {
            self.notifyDismissed()
            
            self.isAnimatingDismiss = true
            self.controllerNode.animateOut(completion: { [weak self] in
                guard let self else {
                    return
                }
                self.isAnimatingDismiss = false
                self.superDismiss()
                completion?()
            })
        }
    }
    
    public func dismissWithoutAnimation() {
        self.superDismiss()
    }
    
    private func superDismiss() {
        self.didPlayPresentationAnimation = false
        if self.navigationPresentation == .flatModal {
            super.dismiss()
        } else {
            self.presentingViewController?.dismiss(animated: false, completion: nil)
        }
    }
    
    private func conferenceAddParticipant() {
        var disablePeerIds: [EnginePeer.Id] = []
        disablePeerIds.append(self.call.context.account.peerId)
        disablePeerIds.append(self.call.peerId)
        let controller = CallController.openConferenceAddParticipant(context: self.call.context, disablePeerIds: disablePeerIds, completion: { [weak self] peerIds in
            guard let self else {
                return
            }
            
            let _ = self.call.upgradeToConference(invitePeerIds: peerIds, completion: { _ in
            })
        })
        self.push(controller)
    }
    
    static func openConferenceAddParticipant(context: AccountContext, disablePeerIds: [EnginePeer.Id], completion: @escaping ([EnginePeer.Id]) -> Void) -> ViewController {
        //TODO:localize
        let presentationData = context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkPresentationTheme)
        let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(
            context: context,
            updatedPresentationData: (initial: presentationData, signal: .single(presentationData)),
            title: "Invite Members",
            mode: .peerSelection(searchChatList: true, searchGroups: false, searchChannels: false),
            isPeerEnabled: { peer in
                guard case let .user(user) = peer else {
                    return false
                }
                if disablePeerIds.contains(user.id) {
                    return false
                }
                if user.botInfo != nil {
                    return false
                }
                return true
            }
        ))
        controller.navigationPresentation = .modal
        let _ = (controller.result |> take(1) |> deliverOnMainQueue).startStandalone(next: { [weak controller] result in
            guard case let .result(peerIds, _) = result else {
                controller?.dismiss()
                return
            }
            if peerIds.isEmpty {
                controller?.dismiss()
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                controller?.dismiss()
            }
            
            let invitePeerIds = peerIds.compactMap { item -> EnginePeer.Id? in
                if case let .peer(peerId) = item {
                    return peerId
                } else {
                    return nil
                }
            }
            
            completion(invitePeerIds)
        })
        
        return controller
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    public func expandFromPipIfPossible() {
        self.controllerNode.expandFromPipIfPossible()
    }
}
