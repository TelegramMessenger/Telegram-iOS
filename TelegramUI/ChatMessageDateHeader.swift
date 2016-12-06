import Foundation
import Display
import AsyncDisplayKit

private let timezoneOffset: Int = {
    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(nowTimestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    return Int(timeinfoNow.tm_gmtoff)
}()

private let granularity: Int32 = 60 * 60 * 24
//private let granularity: Int32 = 60 * 60

final class ChatMessageDateHeader: ListViewItemHeader {
    private let timestamp: Int32
    private let roundedTimestamp: Int32
    
    let id: Int64
    
    init(timestamp: Int32) {
        self.timestamp = timestamp
        if timestamp == Int32.max {
            self.roundedTimestamp = timestamp / (granularity) * (granularity)
        } else {
            self.roundedTimestamp = ((timestamp + timezoneOffset) / (granularity)) * (granularity)
        }
        self.id = Int64(self.roundedTimestamp)
    }
    
    let stickDirection: ListViewItemHeaderStickDirection = .bottom
    
    let height: CGFloat = 34.0
    
    func node() -> ListViewItemHeaderNode {
        return ChatMessageDateHeaderNode(timestamp: self.roundedTimestamp)
    }
}

private func backgroundImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 26.0, height: 26.0), contextGenerator: { size, context -> Void in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })?.stretchableImage(withLeftCapWidth: 13, topCapHeight: 13)
}

private let titleFont = Font.medium(13.0)

private let months: [String] = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
]

final class ChatMessageDateHeaderNode: ListViewItemHeaderNode {
    let labelNode: TextNode
    let backgroundNode: ASImageNode
    let stickBackgroundNode: ASImageNode
    
    private let timestamp: Int32
    
    private var flashingOnScrolling = false
    private var stickDistanceFactor: CGFloat = 0.0
    
    init(timestamp: Int32) {
        self.timestamp = timestamp
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.displaysAsynchronously = true
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.stickBackgroundNode = ASImageNode()
        self.stickBackgroundNode.isLayerBacked = true
        self.stickBackgroundNode.displayWithoutProcessing = true
        self.stickBackgroundNode.displaysAsynchronously = false
        
        super.init(dynamicBounce: true)
        
        self.isLayerBacked = true
        self.transform = CATransform3DMakeRotation(CGFloat(M_PI), 0.0, 0.0, 1.0)
        
        self.backgroundNode.image = backgroundImage(color: UIColor(0x748391, 0.45))
        self.stickBackgroundNode.image = backgroundImage(color: UIColor(0x939fab, 0.5))
        self.stickBackgroundNode.alpha = 0.0
        self.backgroundNode.addSubnode(self.stickBackgroundNode)
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
        
        let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        
        var t: time_t = time_t(timestamp)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
        var now: time_t = time_t(nowTimestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        let text: String
        if timeinfo.tm_year == timeinfoNow.tm_year && timeinfo.tm_yday == timeinfoNow.tm_yday {
            text = "Today"
        } else {
            text = "\(months[Int(timeinfo.tm_mon)]) \(timeinfo.tm_mday)"
        }
        
        let attributedString = NSAttributedString(string: text, font: titleFont, textColor: UIColor.white)
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        
        let (size, apply) = labelLayout(attributedString, nil, 1, .end, CGSize(width: 320.0, height: CGFloat.greatestFiniteMagnitude), nil)
        apply()
        self.labelNode.frame = CGRect(origin: CGPoint(), size: size.size)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        
        let size = self.labelNode.bounds.size
        let backgroundSize = CGSize(width: size.width + 8.0 + 8.0, height: 26.0)
        
        let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.size.width - backgroundSize.width) / 2.0), y: (34.0 - 26.0) / 2.0), size: backgroundSize)
        self.stickBackgroundNode.frame = CGRect(origin: CGPoint(), size: backgroundFrame.size)
        self.backgroundNode.frame = backgroundFrame
        self.labelNode.frame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + 8.0, y: backgroundFrame.origin.y + floorToScreenPixels((backgroundSize.height - size.height) / 2.0) - 1.0), size: size)
    }
    
    override func updateStickDistanceFactor(_ factor: CGFloat, transition: ContainedViewLayoutTransition) {
        if !self.stickDistanceFactor.isEqual(to: factor) {
            self.stickBackgroundNode.alpha = factor
            
            let wasZero = self.stickDistanceFactor < 0.5
            let isZero = factor < 0.5
            self.stickDistanceFactor = factor
            
            if wasZero != isZero {
                var animated = true
                if case .immediate = transition {
                    animated = false
                }
                self.updateFlashing(animated: animated)
            }
        }
    }
    
    override func updateFlashingOnScrolling(_ isFlashingOnScrolling: Bool, animated: Bool) {
        self.flashingOnScrolling = isFlashingOnScrolling
        self.updateFlashing(animated: animated)
    }
    
    private func updateFlashing(animated: Bool) {
        let flashing = self.flashingOnScrolling || self.stickDistanceFactor < 0.5
        
        let alpha: CGFloat = flashing ? 1.0 : 0.0
        let previousAlpha = self.backgroundNode.alpha
        
        if !previousAlpha.isEqual(to: alpha) {
            self.backgroundNode.alpha = alpha
            self.labelNode.alpha = alpha
            if animated {
                let duration: Double = flashing ? 0.3 : 0.4
                self.backgroundNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: duration)
                self.labelNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: duration)
            }
        }
    }
}
