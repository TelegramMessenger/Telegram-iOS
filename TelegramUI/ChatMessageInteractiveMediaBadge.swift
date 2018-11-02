import Foundation
import Display
import AsyncDisplayKit

enum ChatMessageInteractiveMediaBadgeShape: Equatable {
    case round
    case corners(CGFloat)
}

enum ChatMessageInteractiveMediaDownloadState: Equatable {
    case remote
    case fetching(progress: Float)
}

enum ChatMessageInteractiveMediaBadgeContent: Equatable {
    case text(backgroundColor: UIColor, foregroundColor: UIColor, shape: ChatMessageInteractiveMediaBadgeShape, text: NSAttributedString)
    case mediaDownload(backgroundColor: UIColor, foregroundColor: UIColor, duration: String, size: String)
    
    static func ==(lhs: ChatMessageInteractiveMediaBadgeContent, rhs: ChatMessageInteractiveMediaBadgeContent) -> Bool {
        switch lhs {
            case let .text(lhsBackgroundColor, lhsForegroundColor, lhsShape, lhsText):
                if case let .text(rhsBackgroundColor, rhsForegroundColor, rhsShape, rhsText) = rhs, lhsBackgroundColor.isEqual(rhsBackgroundColor), lhsForegroundColor.isEqual(rhsForegroundColor), lhsShape == rhsShape, lhsText.isEqual(to: rhsText) {
                    return true
                } else {
                    return false
                }
            case let .mediaDownload(lhsBackgroundColor, lhsForegroundColor, lhsDuration, lhsSize):
                if case let .mediaDownload(rhsBackgroundColor, rhsForegroundColor, rhsDuration, rhsSize) = rhs, lhsBackgroundColor.isEqual(rhsBackgroundColor), lhsForegroundColor.isEqual(rhsForegroundColor), lhsDuration == rhsDuration, lhsSize == rhsSize {
                    return true
                } else {
                    return false
                }
        }
    }
}

private let font = Font.regular(11.0)
private let boldFont = Font.semibold(11.0)

private final class ChatMessageInteractiveMediaBadgeParams: NSObject {
    let content: ChatMessageInteractiveMediaBadgeContent?
    
    init(content: ChatMessageInteractiveMediaBadgeContent?) {
        self.content = content
    }
}

final class ChatMessageInteractiveMediaBadge: ASDisplayNode {
    var pressed: (() -> Void)?
    
    private var content: ChatMessageInteractiveMediaBadgeContent?
    
    private var mediaDownloadStatusNode: RadialStatusNode?
    private var mediaDownloadState: ChatMessageInteractiveMediaDownloadState?
    
    override init() {
        super.init()
        
        self.contentMode = .topLeft
        self.contentsScale = UIScreenScale
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.pressed?()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let contents = self.contents, CFGetTypeID(contents as CFTypeRef) == CGImage.typeID {
            let image = contents as! CGImage
            if CGRect(origin: CGPoint(), size: CGSize(width: CGFloat(image.width) / UIScreenScale, height: CGFloat(image.height) / UIScreenScale)).contains(point) {
                return self.view
            }
        }
        return nil
    }
    
    func update(theme: PresentationTheme, content: ChatMessageInteractiveMediaBadgeContent?, mediaDownloadState: ChatMessageInteractiveMediaDownloadState?, animated: Bool) {
        if self.content != content {
            self.content = content
            self.setNeedsDisplay()
        }
        if self.mediaDownloadState != mediaDownloadState {
            self.mediaDownloadState = mediaDownloadState
            if let mediaDownloadState = self.mediaDownloadState {
                let mediaDownloadStatusNode: RadialStatusNode
                if let current = self.mediaDownloadStatusNode {
                    mediaDownloadStatusNode = current
                } else {
                    mediaDownloadStatusNode = RadialStatusNode(backgroundNodeColor: .clear)
                    self.mediaDownloadStatusNode = mediaDownloadStatusNode
                    mediaDownloadStatusNode.frame = CGRect(origin: CGPoint(x: 7.0, y: 6.0), size: CGSize(width: 28.0, height: 28.0))
                    self.addSubnode(mediaDownloadStatusNode)
                }
                let state: RadialStatusNodeState
                switch mediaDownloadState {
                    case .remote:
                        if let image = PresentationResourcesChat.chatBubbleFileCloudFetchMediaIcon(theme) {
                            state = .customIcon(image)
                        } else {
                            state = .none
                        }
                    case let .fetching(progress):
                        state = .cloudProgress(color: .white, strokeBackgroundColor: UIColor(white: 1.0, alpha: 0.3), lineWidth: 2.0, value: CGFloat(progress))
                }
                mediaDownloadStatusNode.transitionToState(state, animated: true, completion: {})
            } else if let mediaDownloadStatusNode = self.mediaDownloadStatusNode {
                self.mediaDownloadStatusNode = nil
                mediaDownloadStatusNode.removeFromSupernode()
            }
        }
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return ChatMessageInteractiveMediaBadgeParams(content: self.content)
    }
    
    @objc override public class func display(withParameters: Any?, isCancelled: () -> Bool) -> UIImage? {
        if let content = (withParameters as? ChatMessageInteractiveMediaBadgeParams)?.content {
            switch content {
                case let .text(backgroundColor, foregroundColor, shape, text):
                    let convertedText = NSMutableAttributedString(string: text.string, attributes: [.font: font, .foregroundColor: foregroundColor])
                    text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: []) { attributes, range, _ in
                        if let _ = attributes[ChatTextInputAttributes.bold] {
                            convertedText.addAttribute(.font, value: boldFont, range: range)
                        }
                    }
                    let textRect = convertedText.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
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
                        convertedText.draw(at: CGPoint(x: floor((size.width - textRect.size.width) / 2.0) + textRect.origin.x, y: 2.0 + textRect.origin.y))
                        UIGraphicsPopContext()
                    })
                case let .mediaDownload(backgroundColor, foregroundColor, duration, size):
                    let durationString = NSMutableAttributedString(string: duration, attributes: [.font: font, .foregroundColor: foregroundColor])
                    let sizeString = NSMutableAttributedString(string: size, attributes: [.font: font, .foregroundColor: foregroundColor])
                    let durationRect = durationString.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                    let sizeRect = sizeString.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                    let leftInset: CGFloat = 42.0
                    let imageSize = CGSize(width: leftInset + max(ceil(durationRect.width), ceil(sizeRect.width)) + 10.0, height: 40.0)
                    return generateImage(imageSize, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
                        context.setBlendMode(.copy)
                        context.setFillColor(backgroundColor.cgColor)
                        
                        let radius: CGFloat = 12.0
                        let diameter = radius * 2.0
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: diameter, height: diameter)))
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: size.height - diameter), size: CGSize(width: diameter, height: diameter)))
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - diameter, y: 0.0), size: CGSize(width: diameter, height: diameter)))
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - diameter, y: size.height - diameter), size: CGSize(width: diameter, height: diameter)))
                        context.fill(CGRect(origin: CGPoint(x: 0.0, y: radius), size: CGSize(width: diameter, height: size.height - diameter)))
                        context.fill(CGRect(origin: CGPoint(x: radius, y: 0.0), size: CGSize(width: size.width - diameter, height: size.height)))
                        context.fill(CGRect(origin: CGPoint(x: size.width - diameter, y: radius), size: CGSize(width: diameter, height: size.height - diameter)))
                        
                        context.setBlendMode(.normal)
                        UIGraphicsPushContext(context)
                        durationString.draw(at: CGPoint(x: leftInset + durationRect.origin.x, y: 7.0 + durationRect.origin.y))
                        sizeString.draw(at: CGPoint(x: leftInset + sizeRect.origin.x, y: 21.0 + sizeRect.origin.y))
                        UIGraphicsPopContext()
                    })
            }
        }
        return nil
    }
}
