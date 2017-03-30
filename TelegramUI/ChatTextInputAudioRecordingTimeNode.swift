import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

private final class ChatTextInputAudioRecordingTimeNodeParameters: NSObject {
    let timestamp: Double
    
    init(timestamp: Double) {
        self.timestamp = timestamp
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
                            }
                        }
                    }))
                } else {
                    self.stateDisposable.set(nil)
                }
            }
        }
    }
    
    override init() {
        self.textNode = TextNode()
        super.init()
        self.isOpaque = false
    }
    
    deinit {
        self.stateDisposable.dispose()
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let makeLayout = TextNode.asyncLayout(self.textNode)
        let (size, apply) = makeLayout(NSAttributedString(string: "00:00,00", font: Font.regular(15.0), textColor: .black), nil, 1, .end, CGSize(width: 200.0, height: 100.0), .natural, nil, UIEdgeInsets())
        apply()
        self.textNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 1.0 + UIScreenPixel), size: size.size)
        return size.size
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return ChatTextInputAudioRecordingTimeNodeParameters(timestamp: self.timestamp)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: NSObjectProtocol?, isCancelled: () -> Bool, isRasterizing: Bool) {
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
            let string = NSAttributedString(string: text, font: textFont, textColor: .black)
            string.draw(at: CGPoint())
        }
    }
}
