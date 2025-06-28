import Foundation
import AsyncDisplayKit
import SwiftSignalKit
import UIKit
import Display

public enum MediaPlayerTimeTextNodeMode {
    case normal
    case reversed
}

private struct MediaPlayerTimeTextNodeState: Equatable {
    let hours: Int32?
    let minutes: Int32?
    let seconds: Int32?
    
    init() {
        self.hours = nil
        self.minutes = nil
        self.seconds = nil
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

private extension MediaPlayerTimeTextNodeState {
    var string: String {
        if let hours = self.hours, let minutes = self.minutes, let seconds = self.seconds {
            if hours != 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%d:%02d", minutes, seconds)
            }
        } else {
            return "-:--"
        }
    }
}

private final class MediaPlayerTimeTextNodeParameters: NSObject {
    let state: MediaPlayerTimeTextNodeState
    let alignment: NSTextAlignment
    let mode: MediaPlayerTimeTextNodeMode
    let textColor: UIColor
    let textFont: UIFont
    
    init(state: MediaPlayerTimeTextNodeState, alignment: NSTextAlignment, mode: MediaPlayerTimeTextNodeMode, textColor: UIColor, textFont: UIFont) {
        self.state = state
        self.alignment = alignment
        self.mode = mode
        self.textColor = textColor
        self.textFont = textFont
        
        super.init()
    }
}

public final class MediaPlayerTimeTextNode: ASDisplayNode {
    public var alignment: NSTextAlignment = .left
    public var mode: MediaPlayerTimeTextNodeMode = .normal
    
    public var keepPreviousValueOnEmptyState = false
    
    public var textColor: UIColor {
        didSet {
            self.updateTimestamp()
        }
    }
    
    public var textFont: UIFont {
        didSet {
            self.updateTimestamp()
        }
    }
    
    public var defaultDuration: Double? {
        didSet {
            self.updateTimestamp()
        }
    }
    
    public var trimRange: Range<Double>? {
        didSet {
            self.updateTimestamp()
        }
    }
    
    public var showDurationIfNotStarted = false
    public var isScrubbing = false
    
    private var updateTimer: SwiftSignalKit.Timer?
    
    private var statusValue: MediaPlayerStatus? {
        didSet {
            if self.statusValue != oldValue {
                if let statusValue = statusValue, case .playing = statusValue.status {
                    self.ensureHasTimer()
                } else {
                    self.stopTimer()
                }
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
    
    public var status: Signal<MediaPlayerStatus, NoError>? {
        didSet {
            if let status = self.status {
                self.statusValuePromise.set(status)
            } else {
                self.statusValuePromise.set(.never())
            }
        }
    }
    
    public init(textColor: UIColor, textFont: UIFont = Font.regular(13.0)) {
        self.textColor = textColor
        self.textFont = textFont
        
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
        self.updateTimer?.invalidate()
    }
    
    private func ensureHasTimer() {
        if self.updateTimer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 0.2, repeat: true, completion: { [weak self] in
                self?.updateTimestamp()
            }, queue: Queue.mainQueue())
            self.updateTimer = timer
            timer.start()
        }
    }
    
    private func stopTimer() {
        self.updateTimer?.invalidate()
        self.updateTimer = nil
    }
    
    func updateTimestamp() {
        if ((self.statusValue?.duration ?? 0.0) < 0.1) && self.state.seconds != nil && self.keepPreviousValueOnEmptyState {
            return
        }
                
        if let statusValue = self.statusValue, Double(0.0).isLess(than: statusValue.duration) {
            let timestamp = max(0.0, statusValue.timestamp - (self.trimRange?.lowerBound ?? 0.0))
            var duration = statusValue.duration
            if let trimRange = self.trimRange {
                duration = trimRange.upperBound - trimRange.lowerBound
            }
            
            var isPlaying = false
            if case .playing = statusValue.status {
                isPlaying = true
            }
            
            if self.showDurationIfNotStarted && (timestamp < .ulpOfOne || self.isScrubbing) && !isPlaying {
                let timestamp = Int32(duration)
                self.state = MediaPlayerTimeTextNodeState(hours: timestamp / (60 * 60), minutes: timestamp % (60 * 60) / 60, seconds: timestamp % 60)
            } else {
                let timestampSeconds: Double
                if !statusValue.generationTimestamp.isZero {
                    timestampSeconds = timestamp + (CACurrentMediaTime() - statusValue.generationTimestamp)
                } else {
                    timestampSeconds = timestamp
                }
                switch self.mode {
                case .normal:
                    let timestamp = Int32(truncatingIfNeeded: Int64(floor(timestampSeconds)))
                    self.state = MediaPlayerTimeTextNodeState(hours: timestamp / (60 * 60), minutes: timestamp % (60 * 60) / 60, seconds: timestamp % 60)
                case .reversed:
                    let timestamp = abs(Int32(Int32(truncatingIfNeeded: Int64(floor(timestampSeconds - duration)))))
                    self.state = MediaPlayerTimeTextNodeState(hours: timestamp / (60 * 60), minutes: timestamp % (60 * 60) / 60, seconds: timestamp % 60)
                }
            }
        } else if let defaultDuration = self.defaultDuration {
            var timestamp = Int32(defaultDuration)
            if let trimRange = self.trimRange {
                timestamp = Int32(trimRange.upperBound - trimRange.lowerBound)
            }
            self.state = MediaPlayerTimeTextNodeState(hours: timestamp / (60 * 60), minutes: timestamp % (60 * 60) / 60, seconds: timestamp % 60)
        } else {
            self.state = MediaPlayerTimeTextNodeState()
        }
    }
    
    private let digitsSet = CharacterSet(charactersIn: "0123456789")
    private func widthForString(_ string: String) -> CGFloat {
        let convertedString = string.components(separatedBy: digitsSet).joined(separator: "8")
        let text = NSAttributedString(string: convertedString, font: textFont, textColor: .black)
        let size = text.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: NSStringDrawingOptions.usesLineFragmentOrigin, context: nil).size
        return size.width
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return MediaPlayerTimeTextNodeParameters(state: self.state, alignment: self.alignment, mode: self.mode, textColor: self.textColor, textFont: self.textFont)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? MediaPlayerTimeTextNodeParameters {
            let string = NSAttributedString(string: parameters.state.string, font: parameters.textFont, textColor: parameters.textColor)
            let size = string.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: NSStringDrawingOptions.usesLineFragmentOrigin, context: nil).size
            if parameters.alignment == .left {
                string.draw(at: CGPoint())
            } else {
                string.draw(at: CGPoint(x: bounds.size.width - size.width, y: 0.0))
            }
        }
    }
}
