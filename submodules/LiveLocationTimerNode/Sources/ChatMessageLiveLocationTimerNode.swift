import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let textFont = Font.with(size: 13.0, design: .round, weight: .bold)
private let smallTextFont = Font.with(size: 11.0, design: .round, weight: .bold)

private class ChatMessageLiveLocationTimerNodeParams: NSObject {
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let textColor: UIColor
    let value: CGFloat
    let string: String
    
    init(backgroundColor: UIColor, foregroundColor: UIColor, textColor: UIColor, value: CGFloat, string: String) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.textColor = textColor
        self.value = value
        self.string = string
        
        super.init()
    }
}

private final class RadialTimeoutNodeTimer: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
        
        super.init()
    }
    
    @objc func event() {
        self.action()
    }
}

public final class ChatMessageLiveLocationTimerNode: ASDisplayNode {
    private var timeoutAndColors: (UIColor, UIColor, UIColor, Double, Double, PresentationStrings)?
    private var animationTimer: Timer?
    
    override public init() {
        super.init()
        
        self.isOpaque = false
    }
    
    deinit {
        self.animationTimer?.invalidate()
    }
    
    public func update(backgroundColor: UIColor, foregroundColor: UIColor, textColor: UIColor, beginTimestamp: Double, timeout: Double, strings: PresentationStrings) {
        if self.timeoutAndColors?.3 != beginTimestamp || self.timeoutAndColors?.4 != timeout {
            self.animationTimer?.invalidate()
            self.timeoutAndColors = (backgroundColor, foregroundColor, textColor, beginTimestamp, timeout, strings)
            
            let animationTimer = Timer(timeInterval: 10.0, target: RadialTimeoutNodeTimer({ [weak self] in
                self?.setNeedsDisplay()
            }), selector: #selector(RadialTimeoutNodeTimer.event), userInfo: nil, repeats: true)
            self.animationTimer = animationTimer
            RunLoop.main.add(animationTimer, forMode: .common)
        }
    }
    
    public override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        var value: CGFloat = 0.0
        if let (backgroundColor, foregroundColor, textColor, beginTimestamp, timeout, strings) = self.timeoutAndColors {
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            let remaining = beginTimestamp + timeout - timestamp
            value = CGFloat(max(0.0, 1.0 - min(1.0, remaining / timeout)))
            
            let intRemaining = Int32(remaining)
            let string: String
            if intRemaining > 60 * 60 {
                let hours = Int32(round(remaining / (60.0 * 60.0)))
                string = strings.Map_LiveLocationShortHour("\(hours)").string
            } else {
                let minutes = Int32(round(remaining / (60.0)))
                string = "\(minutes)"
            }
            
            return ChatMessageLiveLocationTimerNodeParams(backgroundColor: backgroundColor, foregroundColor: foregroundColor, textColor: textColor, value: value, string: string)
        } else {
            return nil
        }
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? ChatMessageLiveLocationTimerNodeParams {
            let lineWidth: CGFloat = 1.5
            
            context.setBlendMode(.copy)
            context.setFillColor(parameters.backgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: bounds.size.width, height: bounds.size.height)))
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: lineWidth, y: lineWidth), size: CGSize(width: bounds.size.width - lineWidth * 2.0, height: bounds.size.height - lineWidth * 2.0)))
            context.setBlendMode(.normal)
            
            context.setStrokeColor(parameters.foregroundColor.cgColor)
            
            let progress = 1.0 - parameters.value
            let startAngle = -CGFloat(progress) * 2.0 * CGFloat.pi - CGFloat.pi / 2.0
            let endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
            
            let pathDiameter = bounds.size.width - lineWidth
            
            let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise:true)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.stroke()
            
            let attributes: [NSAttributedString.Key: Any] = [.font: parameters.string.count > 2 ? smallTextFont : textFont, .foregroundColor: parameters.foregroundColor]
            let nsString = parameters.string as NSString
            let size = nsString.size(withAttributes: attributes)
            
            var offset: CGFloat = 0.0
            if parameters.string.count > 2 {
                offset = UIScreenPixel
            }
            
            nsString.draw(at: CGPoint(x: floor((bounds.size.width - size.width) / 2.0), y: floor((bounds.size.height - size.height) / 2.0) + offset), withAttributes: attributes)
        }
    }
}

