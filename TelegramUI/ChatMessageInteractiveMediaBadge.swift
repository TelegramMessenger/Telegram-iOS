import Foundation
import Display
import AsyncDisplayKit

enum ChatMessageInteractiveMediaBadgeShape: Equatable {
    case round
    case corners(CGFloat)
}

enum ChatMessageInteractiveMediaDownloadState: Equatable {
    case remote
    case fetching(progress: Float?)
    case compactRemote
    case compactFetching(progress: Float)
}

enum ChatMessageInteractiveMediaBadgeContent: Equatable {
    case text(inset: CGFloat, backgroundColor: UIColor, foregroundColor: UIColor, shape: ChatMessageInteractiveMediaBadgeShape, text: NSAttributedString)
    case mediaDownload(backgroundColor: UIColor, foregroundColor: UIColor, duration: String, size: String?, muted: Bool, active: Bool)
    
    static func ==(lhs: ChatMessageInteractiveMediaBadgeContent, rhs: ChatMessageInteractiveMediaBadgeContent) -> Bool {
        switch lhs {
            case let .text(lhsInset, lhsBackgroundColor, lhsForegroundColor, lhsShape, lhsText):
                if case let .text(rhsInset, rhsBackgroundColor, rhsForegroundColor, rhsShape, rhsText) = rhs, lhsInset.isEqual(to: rhsInset), lhsBackgroundColor.isEqual(rhsBackgroundColor), lhsForegroundColor.isEqual(rhsForegroundColor), lhsShape == rhsShape, lhsText.isEqual(to: rhsText) {
                    return true
                } else {
                    return false
                }
            case let .mediaDownload(lhsBackgroundColor, lhsForegroundColor, lhsDuration, lhsSize, lhsMuted, lhsActive):
                if case let .mediaDownload(rhsBackgroundColor, rhsForegroundColor, rhsDuration, rhsSize, rhsMuted, rhsActive) = rhs, lhsBackgroundColor.isEqual(rhsBackgroundColor), lhsForegroundColor.isEqual(rhsForegroundColor), lhsDuration == rhsDuration, lhsSize == rhsSize, lhsMuted == rhsMuted, lhsActive == rhsActive {
                    return true
                } else {
                    return false
                }
        }
    }
}

private let font = Font.regular(11.0)
private let boldFont = Font.semibold(11.0)

final class ChatMessageInteractiveMediaBadge: ASDisplayNode {
    private var content: ChatMessageInteractiveMediaBadgeContent?
    var pressed: (() -> Void)?
    
    private var mediaDownloadState: ChatMessageInteractiveMediaDownloadState?
    private var backgroundNodeColor: UIColor?
    private var foregroundColor: UIColor?
    
    private let backgroundNode: ASImageNode
    private let durationNode: ASTextNode
    private var sizeNode: ASTextNode?
    private var iconNode: ASImageNode?
    private var mediaDownloadStatusNode: RadialStatusNode?
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.clipsToBounds = true
        self.durationNode = ASTextNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.durationNode)
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
    
    func update(theme: PresentationTheme, content: ChatMessageInteractiveMediaBadgeContent?, mediaDownloadState: ChatMessageInteractiveMediaDownloadState?, alignment: NSTextAlignment = .left, animated: Bool) {
        var transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
        
        var contentSize = CGSize()
        
        if self.content != content {
            let previousContent = self.content
            self.content = content
        
            if let content = self.content {
                var previousActive: Bool?
                if let previousContent = previousContent, case let .mediaDownload(_, _, _, _, _, active) = previousContent {
                    previousActive = active
                }
                
                switch content {
                    case let .text(inset, backgroundColor, foregroundColor, shape, text):
                        transition = .immediate
                        
                        if self.backgroundNodeColor != backgroundColor {
                            self.backgroundNodeColor = backgroundColor
                            self.backgroundNode.image = generateStretchableFilledCircleImage(radius: 9.0, color: backgroundColor)
                        }
                        let convertedText = NSMutableAttributedString(string: text.string, attributes: [.font: font, .foregroundColor: foregroundColor])
                        text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: []) { attributes, range, _ in
                            if let _ = attributes[ChatTextInputAttributes.bold] {
                                convertedText.addAttribute(.font, value: boldFont, range: range)
                            }
                        }
                        self.durationNode.attributedText = convertedText
                        let durationSize = self.durationNode.measure(CGSize(width: 160.0, height: 160.0))
                        self.durationNode.frame = CGRect(x: 7.0 + inset, y: 2.0, width: durationSize.width, height: durationSize.height)
                        contentSize = CGSize(width: durationSize.width + 14.0 + inset, height: 18.0)
                    
                        if let iconNode = self.iconNode {
                            transition.updateTransformScale(node: iconNode, scale: 0.001)
                            transition.updateAlpha(node: iconNode, alpha: 0.0)
                        }
                    case let .mediaDownload(backgroundColor, foregroundColor, duration, size, muted, active):
                        if self.backgroundNodeColor != backgroundColor {
                            self.backgroundNodeColor = backgroundColor
                            self.backgroundNode.image = generateStretchableFilledCircleImage(radius: 9.0, color: backgroundColor)
                        }
                        
                        if previousActive == nil {
                            previousActive = active
                        }
                        
                        transition = previousActive != active ? transition : .immediate
                        
                        let durationString = NSMutableAttributedString(string: duration, attributes: [.font: font, .foregroundColor: foregroundColor])
                        self.durationNode.attributedText = durationString
                        
                        var sizeSize: CGSize = CGSize()
                        if let size = size {
                            let sizeNode: ASTextNode
                            if let current = self.sizeNode {
                                sizeNode = current
                            } else {
                                sizeNode = ASTextNode()
                                self.sizeNode = sizeNode
                                self.backgroundNode.addSubnode(sizeNode)
                            }
                            
                            let sizeString = NSMutableAttributedString(string: size, attributes: [.font: font, .foregroundColor: foregroundColor])
                            sizeNode.attributedText = sizeString
                            sizeSize = sizeNode.measure(CGSize(width: 160.0, height: 160.0))
                            
                            transition.updateFrame(node: sizeNode, frame: CGRect(x: active ? 42.0 : 7.0, y: active ? 20.0 : 2.0, width: sizeSize.width, height: sizeSize.height))
                            transition.updateAlpha(node: sizeNode, alpha: 1.0)
                        } else if let sizeNode = self.sizeNode {
                            let sizeSize = sizeNode.frame.size
                            transition.updateFrame(node: sizeNode, frame: CGRect(x: active ? 42.0 : 7.0, y: active ? 20.0 : 2.0, width: sizeSize.width, height: sizeSize.height))
                            transition.updateAlpha(node: sizeNode, alpha: 0.0)
                        }
                        
                        var durationSize = self.durationNode.measure(CGSize(width: 160.0, height: 160.0))
                        durationSize.width = max(25.0, durationSize.width)
                        if let statusNode = self.mediaDownloadStatusNode {
                            transition.updateAlpha(node: statusNode, alpha: active ? 1.0 : 0.0)
                        }
                        
                        transition.updateFrame(node: self.durationNode, frame: CGRect(x: active ? 42.0 : 7.0, y: active ? 7.0 : 2.0, width: durationSize.width, height: durationSize.height))
                        
                        let iconNode: ASImageNode
                        if let current = self.iconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.frame = CGRect(x: 0.0, y: 0.0, width: 14.0, height: 9.0)
                            self.iconNode = iconNode
                            self.backgroundNode.addSubnode(iconNode)
                        }
                        
                        if self.foregroundColor != foregroundColor {
                            self.foregroundColor = foregroundColor
                            iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/InlineVideoMute"), color: foregroundColor)
                        }
                        
                        transition.updatePosition(node: iconNode, position: CGPoint(x: (active ? 42.0 : 7.0) + floor(durationSize.width) + 4.0 + 7.0, y: (active ? 9.0 : 4.0) + 5.0))
                        
                        if muted {
                            transition.updateAlpha(node: iconNode, alpha: 1.0)
                            transition.updateTransformScale(node: iconNode, scale: 1.0)
                        } else if let iconNode = self.iconNode {
                            transition.updateAlpha(node: iconNode, alpha: 0.0)
                            transition.updateTransformScale(node: iconNode, scale: 0.001)
                        }
                        
                        var contentWidth: CGFloat = max(sizeSize.width, durationSize.width + (muted ? 17.0 : 0.0)) + 14.0
                        if active {
                            contentWidth += 36.0
                        }
                        contentSize = CGSize(width: contentWidth, height: active ? 38.0 : 18.0)
                }
            }
            
            var originX: CGFloat = 0.0
            if alignment == .right {
                originX = -contentSize.width
            }
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(x: originX, y: 0.0, width: contentSize.width, height: contentSize.height))
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
                    self.addSubnode(mediaDownloadStatusNode)
                }
                let state: RadialStatusNodeState
                var isCompact = false
                var originX: CGFloat = 0.0
                if alignment == .right {
                    originX -= contentSize.width
                }
                var originY: CGFloat = 6.0
                switch mediaDownloadState {
                    case .remote:
                        if let image = PresentationResourcesChat.chatBubbleFileCloudFetchMediaIcon(theme) {
                            state = .customIcon(image)
                        } else {
                            state = .none
                        }
                    case let .fetching(progress):
                        var cloudProgress: CGFloat?
                        if let progress = progress {
                            cloudProgress = CGFloat(progress)
                        }
                        state = .cloudProgress(color: .white, strokeBackgroundColor: UIColor(white: 1.0, alpha: 0.3), lineWidth: 2.0 - UIScreenPixel, value: cloudProgress)
                    case .compactRemote:
                        state = .download(.white)
                        isCompact = true
                        originY = -1.0 - UIScreenPixel
                    case .compactFetching:
                        state = .progress(color: .white, lineWidth: nil, value: 0.0, cancelEnabled: true)
                        isCompact = true
                        originY = -1.0
                }
                let mediaStatusFrame: CGRect
                if isCompact {
                    mediaStatusFrame = CGRect(origin: CGPoint(x: 1.0 + originX, y: originY), size: CGSize(width: 20.0, height: 20.0))
                } else {
                    mediaStatusFrame = CGRect(origin: CGPoint(x: 7.0 + originX, y: originY), size: CGSize(width: 28.0, height: 28.0))
                }
                mediaDownloadStatusNode.frame = mediaStatusFrame
                mediaDownloadStatusNode.transitionToState(state, animated: true, completion: {})
            } else if let mediaDownloadStatusNode = self.mediaDownloadStatusNode {
                mediaDownloadStatusNode.transitionToState(.none, animated: true, completion: {})
            }
        }
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.backgroundNode.frame.contains(point)
    }
}

