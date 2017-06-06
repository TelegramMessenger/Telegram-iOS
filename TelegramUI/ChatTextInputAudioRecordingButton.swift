import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit

private let offsetThreshold: CGFloat = 10.0
private let dismissOffsetThreshold: CGFloat = 70.0

final class ChatTextInputAudioRecordingButton: UIButton {
    var account: Account?
    var beginRecording: () -> Void = { }
    var endRecording: (Bool) -> Void = { _ in }
    var offsetRecordingControls: () -> Void = { }
    
    private var recordingOverlay: ChatTextInputAudioRecordingOverlay?
    private var startTouchLocation: CGPoint?
    private(set) var controlsOffset: CGFloat = 0.0
    
    private var micLevelDisposable: MetaDisposable?
    
    var audioRecorder: ManagedAudioRecorder? {
        didSet {
            if self.audioRecorder !== oldValue {
                if self.micLevelDisposable == nil {
                    micLevelDisposable = MetaDisposable()
                }
                if let audioRecorder = self.audioRecorder {
                    self.micLevelDisposable?.set(audioRecorder.micLevel.start(next: { [weak self] level in
                        Queue.mainQueue().async {
                            self?.recordingOverlay?.addImmediateMicLevel(CGFloat(level))
                        }
                    }))
                } else {
                    self.micLevelDisposable?.set(nil)
                }
            }
        }
    }
    
    init() {
        super.init(frame: CGRect())
        
        self.isExclusiveTouch = true
        self.adjustsImageWhenHighlighted = false
        self.adjustsImageWhenDisabled = false
        self.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.setImage(PresentationResourcesChat.chatInputPanelVoiceButtonImage(theme), for: [])
    }
    
    deinit {
        if let micLevelDisposable = self.micLevelDisposable {
            micLevelDisposable.dispose()
        }
        if let recordingOverlay = self.recordingOverlay {
            recordingOverlay.dismiss()
        }
    }
    
    func cancelRecording() {
        self.isEnabled = false
        self.isEnabled = true
    }
    
    override func beginTracking(_ touch: UITouch, with touchEvent: UIEvent?) -> Bool {
        if super.beginTracking(touch, with: touchEvent) {
            self.startTouchLocation = touch.location(in: self)
            
            self.controlsOffset = 0.0
            self.beginRecording()
            let recordingOverlay: ChatTextInputAudioRecordingOverlay
            if let currentRecordingOverlay = self.recordingOverlay {
                recordingOverlay = currentRecordingOverlay
            } else {
                recordingOverlay = ChatTextInputAudioRecordingOverlay(anchorView: self)
                self.recordingOverlay = recordingOverlay
            }
            if let account = self.account, let applicationContext = account.applicationContext as? TelegramApplicationContext, let topWindow = applicationContext.applicationBindings.getTopWindow() {
                recordingOverlay.present(in: topWindow)
            }
            return true
        } else {
            return false
        }
    }
    
    override func endTracking(_ touch: UITouch?, with touchEvent: UIEvent?) {
        super.endTracking(touch, with: touchEvent)
        
        self.endRecording(self.controlsOffset < 40.0)
        self.dismissRecordingOverlay()
    }
    
    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        
        self.endRecording(false)
        self.dismissRecordingOverlay()
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        if super.continueTracking(touch, with: event) {
            if let startTouchLocation = self.startTouchLocation {
                let horiontalOffset = startTouchLocation.x - touch.location(in: self).x
                let controlsOffset = max(0.0, horiontalOffset - offsetThreshold)
                if !controlsOffset.isEqual(to: self.controlsOffset) {
                    self.recordingOverlay?.dismissFactor = 1.0 - controlsOffset / dismissOffsetThreshold
                    self.controlsOffset = controlsOffset
                    self.offsetRecordingControls()
                }
            }
            return true
        } else {
            return false
        }
    }
    
    private func dismissRecordingOverlay() {
        if let recordingOverlay = self.recordingOverlay {
            self.recordingOverlay = nil
            recordingOverlay.dismiss()
        }
    }
}
