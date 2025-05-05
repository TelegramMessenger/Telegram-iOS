import Foundation
import UIKit
import MetalEngine
import Display
import CallScreen
import ComponentFlow
import TelegramPresentationData

private extension UIScreen {
    private static let cornerRadiusKey: String = {
        let components = ["Radius", "Corner", "display", "_"]
        return components.reversed().joined()
    }()

    var displayCornerRadius: CGFloat {
        guard let cornerRadius = self.value(forKey: Self.cornerRadiusKey) as? CGFloat else {
            assertionFailure("Failed to detect screen corner radius")
            return 0
        }

        return cornerRadius
    }
}

public final class ViewController: UIViewController {    
    private var callScreenView: PrivateCallScreen?
    private var callState: PrivateCallScreen.State = PrivateCallScreen.State(
        strings: defaultPresentationStrings,
        lifecycleState: .connecting,
        name: "Emma Walters",
        shortName: "Emma",
        avatarImage: UIImage(named: "test"),
        audioOutput: .internalSpeaker,
        isLocalAudioMuted: false,
        isRemoteAudioMuted: false,
        localVideo: nil,
        remoteVideo: nil,
        isRemoteBatteryLow: false,
        enableVideoSharpening: false
    )
    
    private var currentLayout: (size: CGSize, insets: UIEdgeInsets)?
    private var viewLayoutTransition: Transition?
    
    private var audioLevelTimer: Foundation.Timer?
    
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
            case .requesting:
                self.callState.lifecycleState = .ringing
            case .ringing:
                self.callState.lifecycleState = .connecting
            case .connecting:
                self.callState.lifecycleState = .active(PrivateCallScreen.State.ActiveState(
                    startTime: Date().timeIntervalSince1970,
                    signalInfo: PrivateCallScreen.State.SignalInfo(quality: 1.0),
                    emojiKey: ["😂", "😘", "😍", "😊"]
                ))
            case var .active(activeState):
                activeState.signalInfo.quality = activeState.signalInfo.quality == 1.0 ? 0.1 : 1.0
                self.callState.lifecycleState = .active(activeState)
            case .reconnecting:
                self.callState.lifecycleState = .active(PrivateCallScreen.State.ActiveState(
                    startTime: Date().timeIntervalSince1970,
                    signalInfo: PrivateCallScreen.State.SignalInfo(quality: 1.0),
                    emojiKey: ["😂", "😘", "😍", "😊"]
                ))
            case .terminated:
                self.callState.lifecycleState = .active(PrivateCallScreen.State.ActiveState(
                    startTime: Date().timeIntervalSince1970,
                    signalInfo: PrivateCallScreen.State.SignalInfo(quality: 1.0),
                    emojiKey: ["😂", "😘", "😍", "😊"]
                ))
            }
            
            switch self.callState.lifecycleState {
            case .terminated:
                if let audioLevelTimer = self.audioLevelTimer {
                    self.audioLevelTimer = nil
                    audioLevelTimer.invalidate()
                }
            default:
                if self.audioLevelTimer == nil {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    self.audioLevelTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true, block: { [weak self] _ in
                        guard let self, let callScreenView = self.callScreenView else {
                            return
                        }
                        let timestamp = CFAbsoluteTimeGetCurrent() - startTime
                        let stream1 = sin(timestamp * Double.pi * 2.0)
                        let stream2 = sin(2.0 * timestamp * Double.pi * 2.0)
                        let stream3 = sin(3.0 * timestamp * Double.pi * 2.0)
                        let result = stream1 + stream2 + stream3
                        callScreenView.addIncomingAudioLevel(value: abs(Float(result)))
                    })
                }
            }
            
            self.update(transition: .spring(duration: 0.4))
        }
        callScreenView.flipCameraAction = { [weak self] in
            guard let self else {
                return
            }
            if let input = self.callState.localVideo as? FileVideoSource {
                input.sourceId = input.sourceId == 0 ? 1 : 0
                //input.fixedRotationAngle = input.sourceId == 0 ? Float.pi * 0.5 : Float.pi * 0.5
                //input.sizeMultiplicator = input.sourceId == 0 ? CGPoint(x: 1.0, y: 1.0) : CGPoint(x: 1.0, y: 0.5)
            }
        }
        callScreenView.videoAction = { [weak self] in
            guard let self else {
                return
            }
            if self.callState.localVideo == nil {
                self.callState.localVideo = FileVideoSource(device: MetalEngine.shared.device, url: Bundle.main.url(forResource: "test3", withExtension: "mp4")!, fixedRotationAngle: Float.pi * 0.5)
            } else {
                self.callState.localVideo = nil
            }
            self.update(transition: .spring(duration: 0.4))
        }
        callScreenView.microhoneMuteAction = {
            if self.callState.remoteVideo == nil {
                self.callState.remoteVideo = FileVideoSource(device: MetalEngine.shared.device, url: Bundle.main.url(forResource: "test4", withExtension: "mp4")!, fixedRotationAngle: Float.pi * 1.0)
            } else {
                self.callState.remoteVideo = nil
            }
            self.update(transition: .spring(duration: 0.4))
        }
        callScreenView.endCallAction = { [weak self] in
            guard let self else {
                return
            }
            self.callState.lifecycleState = .terminated(PrivateCallScreen.State.TerminatedState(duration: 82.0, reason: .hangUp))
            self.callState.remoteVideo = nil
            self.callState.localVideo = nil
            self.callState.isLocalAudioMuted = false
            self.callState.isRemoteBatteryLow = false
            self.update(transition: .spring(duration: 0.4))
        }
        callScreenView.backAction = { [weak self] in
            guard let self else {
                return
            }
            self.callState.isLocalAudioMuted = !self.callState.isLocalAudioMuted
            self.update(transition: .spring(duration: 0.4))
        }
        callScreenView.closeAction = { [weak self] in
            guard let self else {
                return
            }
            self.callScreenView?.speakerAction?()
        }
    }
    
    private func update(transition: Transition) {
        if let (size, insets) = self.currentLayout {
            self.update(size: size, insets: insets, interfaceOrientation: self.interfaceOrientation, transition: transition)
        }
    }
    
    private func update(size: CGSize, insets: UIEdgeInsets, interfaceOrientation: UIInterfaceOrientation, transition: Transition) {
        guard let callScreenView = self.callScreenView else {
            return
        }
        
        transition.setFrame(view: callScreenView, frame: CGRect(origin: CGPoint(), size: size))
        callScreenView.update(size: size, insets: insets, interfaceOrientation: interfaceOrientation, screenCornerRadius: UIScreen.main.displayCornerRadius, state: self.callState, transition: transition)
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
            self.update(size: size, insets: insets, interfaceOrientation: self.interfaceOrientation, transition: transition)
        }
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.viewLayoutTransition = .easeInOut(duration: 0.3)
    }
}
