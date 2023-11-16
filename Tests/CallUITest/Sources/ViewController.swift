import Foundation
import UIKit
import MetalEngine
import Display
import CallScreen
import ComponentFlow

public final class ViewController: UIViewController {
    private var callScreenView: PrivateCallScreen?
    private var callState: PrivateCallScreen.State = PrivateCallScreen.State(
        lifecycleState: .connecting,
        name: "Emma Walters",
        avatarImage: UIImage(named: "test"),
        audioOutput: .internalSpeaker,
        isMicrophoneMuted: false,
        localVideo: nil,
        remoteVideo: nil
    )
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.layer.addSublayer(MetalEngine.shared.rootLayer)
        MetalEngine.shared.rootLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -101.0), size: CGSize(width: 100.0, height: 100.0))
        
        self.view.backgroundColor = .black
        
        SharedDisplayLinkDriver.shared.updateForegroundState(true)
        
        let callScreenView = PrivateCallScreen(frame: self.view.bounds)
        self.callScreenView = callScreenView
        self.view.addSubview(callScreenView)
        
        callScreenView.speakerAction = { [weak self] in
            guard let self else {
                return
            }
            
            switch self.callState.lifecycleState {
            case .connecting:
                self.callState.lifecycleState = .ringing
            case .ringing:
                self.callState.lifecycleState = .exchangingKeys
            case .exchangingKeys:
                self.callState.lifecycleState = .active(PrivateCallScreen.State.ActiveState(
                    startTime: Date().timeIntervalSince1970,
                    signalInfo: PrivateCallScreen.State.SignalInfo(quality: 1.0),
                    emojiKey: ["A", "B", "C", "D"]
                ))
            case var .active(activeState):
                activeState.signalInfo.quality = activeState.signalInfo.quality == 1.0 ? 0.1 : 1.0
                self.callState.lifecycleState = .active(activeState)
            case .terminated:
                self.callState.lifecycleState = .active(PrivateCallScreen.State.ActiveState(
                    startTime: Date().timeIntervalSince1970,
                    signalInfo: PrivateCallScreen.State.SignalInfo(quality: 1.0),
                    emojiKey: ["A", "B", "C", "D"]
                ))
            }
            
            self.update(transition: .spring(duration: 0.4))
        }
        callScreenView.flipCameraAction = { [weak self] in
            guard let self else {
                return
            }
            if let input = self.callState.localVideo as? FileVideoSource {
                input.sourceId = input.sourceId == 0 ? 1 : 0
            }
        }
        callScreenView.videoAction = { [weak self] in
            guard let self else {
                return
            }
            if self.callState.localVideo == nil {
                self.callState.localVideo = FileVideoSource(device: MetalEngine.shared.device, url: Bundle.main.url(forResource: "test2", withExtension: "mp4")!)
            } else {
                self.callState.localVideo = nil
            }
            self.update(transition: .spring(duration: 0.4))
        }
        callScreenView.microhoneMuteAction = {
            if self.callState.remoteVideo == nil {
                self.callState.remoteVideo = FileVideoSource(device: MetalEngine.shared.device, url: Bundle.main.url(forResource: "test2", withExtension: "mp4")!)
            } else {
                self.callState.remoteVideo = nil
            }
            self.update(transition: .spring(duration: 0.4))
        }
        callScreenView.endCallAction = { [weak self] in
            guard let self else {
                return
            }
            self.callState.lifecycleState = .terminated(PrivateCallScreen.State.TerminatedState(duration: 82.0))
            self.callState.remoteVideo = nil
            self.callState.localVideo = nil
            self.update(transition: .spring(duration: 0.4))
        }
        
        self.update(transition: .immediate)
    }
    
    private func update(transition: Transition) {
        self.update(size: self.view.bounds.size, transition: transition)
    }
    
    private func update(size: CGSize, transition: Transition) {
        guard let callScreenView = self.callScreenView else {
            return
        }
        
        transition.setFrame(view: callScreenView, frame: CGRect(origin: CGPoint(), size: size))
        let insets: UIEdgeInsets
        if size.width < size.height {
            insets = UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
        } else {
            insets = UIEdgeInsets(top: 0.0, left: 44.0, bottom: 0.0, right: 44.0)
        }
        callScreenView.update(size: size, insets: insets, screenCornerRadius: 55.0, state: self.callState, transition: transition)
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.update(size: size, transition: .easeInOut(duration: 0.3))
    }
}
