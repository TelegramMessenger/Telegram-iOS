import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting

private let textFont: UIFont = Font.regular(14.0)

private class ChatMessageLiveLocationTextNodeParams: NSObject {
    let color: UIColor
    let string: String
    
    init(color: UIColor, string: String) {
        self.color = color
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

final class ChatMessageLiveLocationTextNode: ASDisplayNode {
    private var timeoutAndColors: (UIColor, Double, PresentationStrings, PresentationDateTimeFormat)?
    private var updateTimer: Timer?
    
    override init() {
        super.init()
        
        self.isOpaque = false
    }
    
    deinit {
        self.updateTimer?.invalidate()
    }
    
    public func update(color: UIColor, timestamp: Double, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) {
        if self.timeoutAndColors?.1 != timestamp {
            self.updateTimer?.invalidate()
            self.timeoutAndColors = (color, timestamp, strings, dateTimeFormat)
            
            let updateTimer = Timer(timeInterval: 30.0, target: RadialTimeoutNodeTimer({ [weak self] in
                self?.setNeedsDisplay()
            }), selector: #selector(RadialTimeoutNodeTimer.event), userInfo: nil, repeats: true)
            self.updateTimer = updateTimer
            RunLoop.main.add(updateTimer, forMode: .common)
        }
    }
    
    public override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        if let (color, updateTimestamp, strings, dateTimeFormat) = self.timeoutAndColors {
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            
            let string = stringForRelativeLiveLocationTimestamp(strings: strings, relativeTimestamp: Int32(updateTimestamp), relativeTo: Int32(timestamp), dateTimeFormat: dateTimeFormat)
            
            return ChatMessageLiveLocationTextNodeParams(color: color, string: string)
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
        
        if let parameters = parameters as? ChatMessageLiveLocationTextNodeParams {
            let attributes: [NSAttributedString.Key: Any] = [.font: textFont, .foregroundColor: parameters.color]
            let nsString = parameters.string as NSString
            nsString.draw(at: CGPoint(x: 0.0, y: 0.0), withAttributes: attributes)
        }
    }
}
