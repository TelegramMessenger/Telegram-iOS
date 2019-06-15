import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import UniversalMediaPlayer

private let textFont = Font.regular(11.0)

private struct ChatInstantVideoMessageDurationNodeState: Equatable {
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
    
    static func ==(lhs: ChatInstantVideoMessageDurationNodeState, rhs: ChatInstantVideoMessageDurationNodeState) -> Bool {
        if lhs.hours != rhs.hours || lhs.minutes != rhs.minutes || lhs.seconds != rhs.seconds {
            return false
        }
        return true
    }
}

private final class ChatInstantVideoMessageDurationNodeParameters: NSObject {
    let state: ChatInstantVideoMessageDurationNodeState
    let isSeen: Bool
    let backgroundColor: UIColor
    let textColor: UIColor
    
    init(state: ChatInstantVideoMessageDurationNodeState, isSeen: Bool, backgroundColor: UIColor, textColor: UIColor) {
        self.state = state
        self.isSeen = isSeen
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        
        super.init()
    }
}

final class ChatInstantVideoMessageDurationNode: ASDisplayNode {
    private var textColor: UIColor
    private var fillColor: UIColor
    
    var defaultDuration: Double? {
        didSet {
            if self.defaultDuration != oldValue {
                self.updateTimestamp()
                self.setNeedsDisplay()
            }
        }
    }
    
    var isSeen: Bool = false {
        didSet {
            if self.isSeen != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
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
    
    private var state = ChatInstantVideoMessageDurationNodeState() {
        didSet {
            if self.state != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
    private var statusDisposable: Disposable?
    private var statusValuePromise = Promise<MediaPlayerStatus?>()
    
    var status: Signal<MediaPlayerStatus?, NoError>? {
        didSet {
            if let status = self.status {
                self.statusValuePromise.set(status)
            } else {
                self.statusValuePromise.set(.never())
            }
        }
    }
    
    init(textColor: UIColor, fillColor: UIColor) {
        self.textColor = textColor
        self.fillColor = fillColor
        
        super.init()
        
        self.isOpaque = false
        self.contentsScale = UIScreenScale
        self.contentMode = .topRight
        
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
    
    func updateTheme(textColor: UIColor, fillColor: UIColor) {
        if !self.textColor.isEqual(textColor) || !self.fillColor.isEqual(textColor) {
            self.textColor = textColor
            self.fillColor = fillColor
            self.setNeedsDisplay()
        }
    }
    
    private func ensureHasTimer() {
        if self.updateTimer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
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
        if let statusValue = self.statusValue, Double(0.0).isLess(than: statusValue.duration) {
            let timestampSeconds: Double
            if !statusValue.generationTimestamp.isZero {
                timestampSeconds = statusValue.timestamp + (CACurrentMediaTime() - statusValue.generationTimestamp)
            } else {
                timestampSeconds = statusValue.timestamp
            }
            let timestamp = Int32(timestampSeconds)
            self.state = ChatInstantVideoMessageDurationNodeState(hours: timestamp / (60 * 60), minutes: timestamp % (60 * 60) / 60, seconds: timestamp % 60)
        } else if let defaultDuration = self.defaultDuration {
            let timestamp = Int32(defaultDuration)
            self.state = ChatInstantVideoMessageDurationNodeState(hours: timestamp / (60 * 60), minutes: timestamp % (60 * 60) / 60, seconds: timestamp % 60)
        } else {
            self.state = ChatInstantVideoMessageDurationNodeState()
        }
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return ChatInstantVideoMessageDurationNodeParameters(state: self.state, isSeen: self.isSeen, backgroundColor: self.fillColor, textColor: self.textColor)
    }
    
    @objc override public class func display(withParameters: Any?, isCancelled: () -> Bool) -> UIImage? {
        guard let parameters = withParameters as? ChatInstantVideoMessageDurationNodeParameters else {
            return nil
        }
        
        let text: String
        if let hours = parameters.state.hours, let minutes = parameters.state.minutes, let seconds = parameters.state.seconds {
            if hours != 0 {
                text = String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                text = String(format: "%d:%02d", minutes, seconds)
            }
        } else {
            text = "-:--"
        }
        let string = NSAttributedString(string: text, font: textFont, textColor: parameters.textColor)
        let textRect = string.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: NSStringDrawingOptions.usesLineFragmentOrigin, context: nil)
        
        let unseenInset: CGFloat = (parameters.isSeen ? 0.0 : 10.0)
        let imageSize = CGSize(width: ceil(textRect.width) + 10.0 + unseenInset, height: 18.0)
        
        return generateImage(imageSize, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
            context.setBlendMode(.copy)
            context.setFillColor(parameters.backgroundColor.cgColor)
            
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.height, height: size.height)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height, y: 0.0), size: CGSize(width: size.height, height: size.height)))
            context.fill(CGRect(origin: CGPoint(x: size.height / 2.0, y: 0.0), size: CGSize(width: size.width - size.height, height: size.height)))
            
            if !parameters.isSeen {
                context.setFillColor(parameters.textColor.cgColor)
                let diameter: CGFloat = 4.0
                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height + floor((size.height - diameter) / 2.0), y: floor((size.height - diameter) / 2.0)), size: CGSize(width: diameter, height: diameter)))
            }
        
            context.setBlendMode(.normal)
            UIGraphicsPushContext(context)
            string.draw(at: CGPoint(x: floor((size.width - unseenInset - textRect.size.width) / 2.0) + textRect.origin.x, y: 2.0 + textRect.origin.y + UIScreenPixel))
            UIGraphicsPopContext()
        })
    }
}
