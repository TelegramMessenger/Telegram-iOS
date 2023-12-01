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
    
    private var currentLayout: (size: CGSize, insets: UIEdgeInsets)?
    private var viewLayoutTransition: Transition?
    
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
                    emojiKey: ["😂", "😘", "😍", "😊"]
                ))
            case var .active(activeState):
                activeState.signalInfo.quality = activeState.signalInfo.quality == 1.0 ? 0.1 : 1.0
                self.callState.lifecycleState = .active(activeState)
            case .terminated:
                self.callState.lifecycleState = .active(PrivateCallScreen.State.ActiveState(
                    startTime: Date().timeIntervalSince1970,
                    signalInfo: PrivateCallScreen.State.SignalInfo(quality: 1.0),
                    emojiKey: ["😂", "😘", "😍", "😊"]
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
                input.fixedRotationAngle = input.sourceId == 0 ? Float.pi * 0.0 : Float.pi * 0.5
                input.sizeMultiplicator = input.sourceId == 0 ? CGPoint(x: 1.0, y: 1.0) : CGPoint(x: 1.5, y: 1.0)
            }
        }
        callScreenView.videoAction = { [weak self] in
            guard let self else {
                return
            }
            if self.callState.localVideo == nil {
                self.callState.localVideo = FileVideoSource(device: MetalEngine.shared.device, url: Bundle.main.url(forResource: "test3", withExtension: "mp4")!, fixedRotationAngle: Float.pi * 0.0)
            } else {
                self.callState.localVideo = nil
            }
            self.update(transition: .spring(duration: 0.4))
        }
        callScreenView.microhoneMuteAction = {
            if self.callState.remoteVideo == nil {
                self.callState.remoteVideo = FileVideoSource(device: MetalEngine.shared.device, url: Bundle.main.url(forResource: "test4", withExtension: "mp4")!, fixedRotationAngle: Float.pi * 0.0)
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
    }
    
    private func update(transition: Transition) {
        if let (size, insets) = self.currentLayout {
            self.update(size: size, insets: insets, transition: transition)
        }
    }
    
    private func update(size: CGSize, insets: UIEdgeInsets, transition: Transition) {
        guard let callScreenView = self.callScreenView else {
            return
        }
        
        transition.setFrame(view: callScreenView, frame: CGRect(origin: CGPoint(), size: size))
        callScreenView.update(size: size, insets: insets, screenCornerRadius: 55.0, state: self.callState, transition: transition)
    }
    
    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let safeAreaLayoutGuide = self.view.safeAreaLayoutGuide
        
        let size = self.view.bounds.size
        let insets = UIEdgeInsets(top: safeAreaLayoutGuide.layoutFrame.minY, left: safeAreaLayoutGuide.layoutFrame.minX, bottom: size.height - safeAreaLayoutGuide.layoutFrame.maxY, right: safeAreaLayoutGuide.layoutFrame.minX)
        
        let transition = self.viewLayoutTransition ?? .immediate
        self.viewLayoutTransition = nil
        
        if let currentLayout = self.currentLayout, currentLayout == (size, insets) {
        } else {
            self.currentLayout = (size, insets)
            self.update(size: size, insets: insets, transition: transition)
        }
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.viewLayoutTransition = .easeInOut(duration: 0.3)
    }
}
