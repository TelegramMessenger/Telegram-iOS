import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

public final class CallController: ViewController {
    private var controllerNode: CallControllerNode {
        return self.displayNode as! CallControllerNode
    }
    
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let account: Account
    public let call: PresentationCall
    
    private var presentationData: PresentationData
    private var animatedAppearance = false
    
    private var peer: Peer?
    
    private var peerDisposable: Disposable?
    private var disposable: Disposable?
    
    private var callMutedDisposable: Disposable?
    private var isMuted = false
    
    private var speakerModeDisposable: Disposable?
    private var speakerMode = false
    
    public init(account: Account, call: PresentationCall) {
        self.account = account
        self.call = call
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .White
        self.statusBar.ignoreInCall = true
        
        self.supportedOrientations = .portrait
        
        self.disposable = (call.state |> deliverOnMainQueue).start(next: { [weak self] callState in
            self?.callStateUpdated(callState)
        })
        
        self.callMutedDisposable = (call.isMuted |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.isMuted = value
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.isMuted = value
                }
            }
        })
        
        self.speakerModeDisposable = (call.speakerMode |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.speakerMode = value
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.speakerMode = value
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
        self.speakerModeDisposable?.dispose()
    }
    
    private func callStateUpdated(_ callState: PresentationCallState) {
        if self.isNodeLoaded {
            self.controllerNode.updateCallState(callState)
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = CallControllerNode(account: self.account, presentationData: self.presentationData, statusBar: self.statusBar)
        self.displayNodeDidLoad()
        
        self.controllerNode.toggleMute = { [weak self] in
            self?.call.toggleIsMuted()
        }
        
        self.controllerNode.toggleSpeaker = { [weak self] in
            self?.call.toggleSpeaker()
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
        
        self.controllerNode.disissedInteractively = { [weak self] in
            self?.animatedAppearance = false
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.peerDisposable = (account.postbox.peerView(id: self.call.peerId)
            |> deliverOnMainQueue).start(next: { [weak self] view in
                if let strongSelf = self {
                    if let peer = view.peers[view.peerId] {
                        strongSelf.peer = peer
                        strongSelf.controllerNode.updatePeer(peer: peer)
                        strongSelf._ready.set(.single(true))
                    }
                }
            })
        
        self.controllerNode.isMuted = self.isMuted
        self.controllerNode.speakerMode = self.speakerMode
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedAppearance {
            self.animatedAppearance = true
            
            self.controllerNode.animateIn()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    override open func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.animatedAppearance = false
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            
            completion?()
        })
    }
    
    @objc func backPressed() {
        self.dismiss()
    }
}
