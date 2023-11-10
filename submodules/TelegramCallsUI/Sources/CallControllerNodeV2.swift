import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TelegramAudio
import AccountContext
import TelegramPresentationData
import SwiftSignalKit
import CallScreen

final class CallControllerNodeV2: ViewControllerTracingNode, CallControllerNodeProtocol {
    private let sharedContext: SharedAccountContext
    private let account: Account
    private let presentationData: PresentationData
    private let statusBar: StatusBar
    private let call: PresentationCall
    
    private let callScreen: PrivateCallScreen
    
    var isMuted: Bool = false
    
    var toggleMute: (() -> Void)?
    var setCurrentAudioOutput: ((AudioSessionOutput) -> Void)?
    var beginAudioOuputSelection: ((Bool) -> Void)?
    var acceptCall: (() -> Void)?
    var endCall: (() -> Void)?
    var back: (() -> Void)?
    var presentCallRating: ((CallId, Bool) -> Void)?
    var present: ((ViewController) -> Void)?
    var callEnded: ((Bool) -> Void)?
    var dismissedInteractively: (() -> Void)?
    var dismissAllTooltips: (() -> Void)?
    
    init(
        sharedContext: SharedAccountContext,
        account: Account,
        presentationData: PresentationData,
        statusBar: StatusBar,
        debugInfo: Signal<(String, String), NoError>,
        shouldStayHiddenUntilConnection: Bool = false,
        easyDebugAccess: Bool,
        call: PresentationCall
    ) {
        self.sharedContext = sharedContext
        self.account = account
        self.presentationData = presentationData
        self.statusBar = statusBar
        self.call = call
        
        self.callScreen = PrivateCallScreen()
        
        super.init()
        
        self.view.addSubview(self.callScreen)
    }
    
    func updateAudioOutputs(availableOutputs: [AudioSessionOutput], currentOutput: AudioSessionOutput?) {
        
    }
    
    func updateCallState(_ callState: PresentationCallState) {
        if case let .terminated(id, _, reportRating) = callState.state, let callId = id {
            if reportRating {
                self.presentCallRating?(callId, self.call.isVideo)
            }
            self.callEnded?(reportRating)
        }
    }
    
    func updatePeer(accountPeer: Peer, peer: Peer, hasOther: Bool) {
        
    }
    
    func animateIn() {
        
    }
    
    func animateOut(completion: @escaping () -> Void) {
        
    }
    
    func expandFromPipIfPossible() {

    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.callScreen, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.callScreen.update(size: layout.size, insets: layout.insets(options: [.statusBar]))
    }
}
