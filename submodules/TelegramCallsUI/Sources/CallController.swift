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
    private var controllerNode: CallControllerNodeProtocol {
        return self.displayNode as! CallControllerNodeProtocol
    }
    
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
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
    private var isMuted = false
    
    private var presentedCallRating = false
    
    private var audioOutputStateDisposable: Disposable?
    private var audioOutputState: ([AudioSessionOutput], AudioSessionOutput?)?
    
    private let idleTimerExtensionDisposable = MetaDisposable()
    
    public init(sharedContext: SharedAccountContext, account: Account, call: PresentationCall, easyDebugAccess: Bool) {
        self.sharedContext = sharedContext
        self.account = account
        self.call = call
        self.easyDebugAccess = easyDebugAccess
        
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
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
        if self.call.isVideoPossible {
            self.displayNode = CallControllerNode(sharedContext: self.sharedContext, account: self.account, presentationData: self.presentationData, statusBar: self.statusBar, debugInfo: self.call.debugInfo(), shouldStayHiddenUntilConnection: !self.call.isOutgoing && self.call.isIntegratedWithCallKit, easyDebugAccess: self.easyDebugAccess, call: self.call)
        } else {
            self.displayNode = LegacyCallControllerNode(sharedContext: self.sharedContext, account: self.account, presentationData: self.presentationData, statusBar: self.statusBar, debugInfo: self.call.debugInfo(), shouldStayHiddenUntilConnection: !self.call.isOutgoing && self.call.isIntegratedWithCallKit, easyDebugAccess: self.easyDebugAccess, call: self.call)
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
            self?.didPlayPresentationAnimation = false
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.peerDisposable = (combineLatest(self.account.postbox.peerView(id: self.account.peerId) |> take(1), self.account.postbox.peerView(id: self.call.peerId), self.sharedContext.activeAccountsWithInfo |> take(1))
        |> deliverOnMainQueue).start(next: { [weak self] accountView, view, activeAccountsWithInfo in
            if let strongSelf = self {
                if let accountPeer = accountView.peers[accountView.peerId], let peer = view.peers[view.peerId] {
                    strongSelf.peer = peer
                    strongSelf.controllerNode.updatePeer(accountPeer: accountPeer, peer: peer, hasOther: activeAccountsWithInfo.accounts.count > 1)
                    strongSelf._ready.set(.single(true))
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
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.idleTimerExtensionDisposable.set(nil)
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
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    public func expandFromPipIfPossible() {
        self.controllerNode.expandFromPipIfPossible()
    }
}
