import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState

private final class ChatTextInputAudioRecordingTimeNodeParameters: NSObject {
    let timestamp: Double
    let theme: PresentationTheme
    
    init(timestamp: Double, theme: PresentationTheme) {
        self.timestamp = timestamp
        self.theme = theme
        
        super.init()
    }
}

private let textFont = Font.regular(15.0)

final class ChatTextInputAudioRecordingTimeNode: ASDisplayNode {
    private let textNode: TextNode
    
    private var timestamp: Double = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    private let stateDisposable = MetaDisposable()
    
    var audioRecorder: ManagedAudioRecorder? {
        didSet {
            if self.audioRecorder !== oldValue {
                if let audioRecorder = self.audioRecorder {
                    self.stateDisposable.set(audioRecorder.recordingState.start(next: { [weak self] state in
                        if let strongSelf = self {
                            switch state {
                                case let .paused(duration):
                                    strongSelf.timestamp = duration
                                case let .recording(duration, _):
                                    strongSelf.timestamp = duration
                                case .stopped:
                                    break
                            }
                        }
                    }))
                } else {
                    self.stateDisposable.set(nil)
                }
            }
        }
    }
    
    private var durationDisposable: MetaDisposable?
    
    var videoRecordingStatus: InstantVideoControllerRecordingStatus? {
        didSet {
            if self.videoRecordingStatus !== oldValue {
                if self.durationDisposable == nil {
                    durationDisposable = MetaDisposable()
                }
                
                if let videoRecordingStatus = self.videoRecordingStatus {
                    self.durationDisposable?.set(videoRecordingStatus.duration.start(next: { [weak self] duration in
                        Queue.mainQueue().async { [weak self] in
                            self?.timestamp = duration
                        }
                    }))
                } else if self.audioRecorder == nil {
                    self.durationDisposable?.set(nil)
                }
            }
        }
    }
    
    private var theme: PresentationTheme
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.textNode = TextNode()
        super.init()
        self.isOpaque = false
    }
    
    deinit {
        self.stateDisposable.dispose()
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.theme = theme
        
        self.setNeedsDisplay()
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let makeLayout = TextNode.asyncLayout(self.textNode)
        let (size, apply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "00:00,00", font: Font.regular(15.0), textColor: theme.chat.inputPanel.primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 200.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = apply()
        self.textNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 1.0 + UIScreenPixel), size: size.size)
        return size.size
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return ChatTextInputAudioRecordingTimeNodeParameters(timestamp: self.timestamp, theme: self.theme)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? ChatTextInputAudioRecordingTimeNodeParameters {
            let currentAudioDurationSeconds = Int(parameters.timestamp)
            let currentAudioDurationMilliseconds = Int(parameters.timestamp * 100.0) % 100
            let text = String(format: "%d:%02d,%02d", currentAudioDurationSeconds / 60, currentAudioDurationSeconds % 60, currentAudioDurationMilliseconds)
            let string = NSAttributedString(string: text, font: textFont, textColor: parameters.theme.chat.inputPanel.primaryTextColor)
            string.draw(at: CGPoint())
        }
    }
}
