import Foundation
import AsyncDisplayKit
import SwiftSignalKit
import Display

private let textFont = Font.regular(13.0)

enum MediaPlayerTimeTextNodeMode {
    case normal
    case reversed
}

private struct MediaPlayerTimeTextNodeState: Equatable {
    let hours: Int32
    let minutes: Int32
    let seconds: Int32
    
    init() {
        self.hours = 0
        self.minutes = 0
        self.seconds = 0
    }
    
    init(hours: Int32, minutes: Int32, seconds: Int32) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
    
    static func ==(lhs: MediaPlayerTimeTextNodeState, rhs: MediaPlayerTimeTextNodeState) -> Bool {
        if lhs.hours != rhs.hours || lhs.minutes != rhs.minutes || lhs.seconds != rhs.seconds {
            return false
        }
        return true
    }
}

private final class MediaPlayerTimeTextNodeParameters: NSObject {
    let state: MediaPlayerTimeTextNodeState
    let alignment: NSTextAlignment
    let mode: MediaPlayerTimeTextNodeMode
    
    init(state: MediaPlayerTimeTextNodeState, alignment: NSTextAlignment, mode: MediaPlayerTimeTextNodeMode) {
        self.state = state
        self.alignment = alignment
        self.mode = mode
        super.init()
    }
}

final class MediaPlayerTimeTextNode: ASDisplayNode {
    var alignment: NSTextAlignment = .left
    var mode: MediaPlayerTimeTextNodeMode = .normal
    
    private var statusValue: MediaPlayerStatus? {
        didSet {
            if self.statusValue != oldValue {
                self.updateTimestamp()
            }
        }
    }
    
    private var state = MediaPlayerTimeTextNodeState() {
        didSet {
            if self.state != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
    private var statusDisposable: Disposable?
    private var statusValuePromise = Promise<MediaPlayerStatus>()
    
    var status: Signal<MediaPlayerStatus, NoError>? {
        didSet {
            if let status = self.status {
                self.statusValuePromise.set(status)
            } else {
                self.statusValuePromise.set(.never())
            }
        }
    }
    
    override init() {
        super.init()
        self.isOpaque = false
        
        self.statusDisposable = (self.statusValuePromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    strongSelf.statusValue = status
                }
            })
    }
    
    deinit {
        self.statusDisposable?.dispose()
    }
    
    func updateTimestamp() {
        if let statusValue = self.statusValue, Double(0.0).isLess(than: statusValue.duration) {
            switch self.mode {
                case .normal:
                    let timestamp = Int32(statusValue.timestamp)
                    self.state = MediaPlayerTimeTextNodeState(hours: timestamp / (60 * 60), minutes: timestamp % (60 * 60) / 60, seconds: timestamp % 60)
                case .reversed:
                    let timestamp = abs(Int32(statusValue.timestamp - statusValue.duration))
                    self.state = MediaPlayerTimeTextNodeState(hours: timestamp / (60 * 60), minutes: timestamp % (60 * 60) / 60, seconds: timestamp % 60)
            }
        } else {
            self.state = MediaPlayerTimeTextNodeState()
        }
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return MediaPlayerTimeTextNodeParameters(state: self.state, alignment: self.alignment, mode: self.mode)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: NSObjectProtocol?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? MediaPlayerTimeTextNodeParameters {
            let text = String(format: "%d:%02d", parameters.state.minutes, parameters.state.seconds)
            let string = NSAttributedString(string: text, font: textFont, textColor: UIColor(0x686669))
            let size = string.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: NSStringDrawingOptions.usesLineFragmentOrigin, context: nil).size
            
            if parameters.alignment == .left {
                string.draw(at: CGPoint())
            } else {
                string.draw(at: CGPoint(x: bounds.size.width - size.width, y: 0.0))
            }
        }
    }
}
