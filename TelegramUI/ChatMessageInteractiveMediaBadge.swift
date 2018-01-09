import Foundation
import Display
import AsyncDisplayKit

enum ChatMessageInteractiveMediaBadgeShape: Equatable {
    case round
    case corners(CGFloat)
    
    static func ==(lhs: ChatMessageInteractiveMediaBadgeShape, rhs: ChatMessageInteractiveMediaBadgeShape) -> Bool {
        switch lhs {
            case .round:
                if case .round = rhs {
                    return true
                } else {
                    return false
                }
            case let .corners(radius):
                if case .corners(radius) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

enum ChatMessageInteractiveMediaBadgeContent: Equatable {
    case text(backgroundColor: UIColor, foregroundColor: UIColor, shape: ChatMessageInteractiveMediaBadgeShape, text: String)
    
    static func ==(lhs: ChatMessageInteractiveMediaBadgeContent, rhs: ChatMessageInteractiveMediaBadgeContent) -> Bool {
        switch lhs {
            case let .text(lhsBackgroundColor, lhsForegroundColor, lhsShape, lhsText):
                if case let .text(rhsBackgroundColor, rhsForegroundColor, rhsShape, rhsText) = rhs, lhsBackgroundColor.isEqual(rhsBackgroundColor), lhsForegroundColor.isEqual(rhsForegroundColor), lhsShape == rhsShape, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
}

private let font = Font.regular(11.0)

private final class ChatMessageInteractiveMediaBadgeParams: NSObject {
    let content: ChatMessageInteractiveMediaBadgeContent?
    
    init(content: ChatMessageInteractiveMediaBadgeContent?) {
        self.content = content
    }
}

final class ChatMessageInteractiveMediaBadge: ASDisplayNode {
    var content: ChatMessageInteractiveMediaBadgeContent? {
        didSet {
            if oldValue != self.content {
                self.setNeedsDisplay()
            }
        }
    }
    
    override init() {
        super.init()
        
        self.isLayerBacked = true
        self.contentMode = .topLeft
        self.contentsScale = UIScreenScale
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return ChatMessageInteractiveMediaBadgeParams(content: self.content)
    }
    
    @objc override public class func display(withParameters: Any?, isCancelled: () -> Bool) -> UIImage? {
        if let content = (withParameters as? ChatMessageInteractiveMediaBadgeParams)?.content {
            switch content {
                case let .text(backgroundColor, foregroundColor, shape, text):
                    let nsText: NSString = text as NSString
                    let textRect = nsText.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
                    let imageSize = CGSize(width: ceil(textRect.size.width) + 10.0, height: 18.0)
                    return generateImage(imageSize, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
                        context.setBlendMode(.copy)
                        context.setFillColor(backgroundColor.cgColor)
                        switch shape {
                            case .round:
                                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                                context.fill(CGRect(origin: CGPoint(x: size.height / 2.0, y: 0.0), size: CGSize(width: size.width - size.height, height: size.height)))
                            case let .corners(radius):
                                let diameter = radius * 2.0
                                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: diameter, height: diameter)))
                                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: size.height - diameter), size: CGSize(width: diameter, height: diameter)))
                                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - diameter, y: 0.0), size: CGSize(width: diameter, height: diameter)))
                                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - diameter, y: size.height - diameter), size: CGSize(width: diameter, height: diameter)))
                                context.fill(CGRect(origin: CGPoint(x: 0.0, y: radius), size: CGSize(width: diameter, height: size.height - diameter)))
                                context.fill(CGRect(origin: CGPoint(x: radius, y: 0.0), size: CGSize(width: size.width - diameter, height: size.height)))
                                context.fill(CGRect(origin: CGPoint(x: size.width - diameter, y: radius), size: CGSize(width: diameter, height: size.height - diameter)))
                        }
                        context.setBlendMode(.normal)
                        UIGraphicsPushContext(context)
                        nsText.draw(at: CGPoint(x: floor((size.width - textRect.size.width) / 2.0) + textRect.origin.x, y: 2.0 + textRect.origin.y), withAttributes: [.font: font, .foregroundColor: foregroundColor])
                        UIGraphicsPopContext()
                    })
            }
        }
        return nil
    }
}
