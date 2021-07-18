import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TextFormat
import RadialStatusNode
import AppBundle

private let font = Font.with(size: 11.0, design: .regular, weight: .regular, traits: [.monospacedNumbers])
private let boldFont = Font.with(size: 11.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers])

public enum ChatMessageInteractiveMediaDownloadState: Equatable {
    case remote
    case fetching(progress: Float?)
    case compactRemote
    case compactFetching(progress: Float)
}

public enum ChatMessageInteractiveMediaBadgeContent: Equatable {
    case text(inset: CGFloat, backgroundColor: UIColor, foregroundColor: UIColor, text: NSAttributedString)
    case mediaDownload(backgroundColor: UIColor, foregroundColor: UIColor, duration: String, size: String?, muted: Bool, active: Bool)
    
    public static func ==(lhs: ChatMessageInteractiveMediaBadgeContent, rhs: ChatMessageInteractiveMediaBadgeContent) -> Bool {
        switch lhs {
            case let .text(lhsInset, lhsBackgroundColor, lhsForegroundColor, lhsText):
                if case let .text(rhsInset, rhsBackgroundColor, rhsForegroundColor, rhsText) = rhs, lhsInset.isEqual(to: rhsInset), lhsBackgroundColor.isEqual(rhsBackgroundColor), lhsForegroundColor.isEqual(rhsForegroundColor), lhsText.isEqual(to: rhsText) {
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

public final class ChatMessageInteractiveMediaBadge: ASDisplayNode {
    private var content: ChatMessageInteractiveMediaBadgeContent?
    public var pressed: (() -> Void)?
    
    private var mediaDownloadState: ChatMessageInteractiveMediaDownloadState?
    
    private var previousContentSize: CGSize?
    private var backgroundNodeColor: UIColor?
    private var foregroundColor: UIColor?
    
    private let backgroundNode: ASImageNode
    private let durationNode: ASTextNode
    private var sizeNode: ASTextNode?
    private var measureNode: ASTextNode
    private var iconNode: ASImageNode?
    private var mediaDownloadStatusNode: RadialStatusNode?
    
    override public init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.clipsToBounds = true
        self.durationNode = ASTextNode()
        self.measureNode = ASTextNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.durationNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.pressed?()
        }
    }
    
    private let digitsSet = CharacterSet(charactersIn: "0123456789")
    private func widthForString(_ string: String) -> CGFloat {
        let convertedString = string.components(separatedBy: digitsSet).joined(separator: "8")
        self.measureNode.attributedText = NSMutableAttributedString(string: convertedString, attributes: [.font: font])
        return self.measureNode.measure(CGSize(width: 240.0, height: 160.0)).width
    }
    
    public func update(theme: PresentationTheme?, content: ChatMessageInteractiveMediaBadgeContent?, mediaDownloadState: ChatMessageInteractiveMediaDownloadState?, alignment: NSTextAlignment = .left, animated: Bool, badgeAnimated: Bool = true) {
        var transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
        
        let previousContentSize = self.previousContentSize
        var contentSize: CGSize?
        
        if self.content != content {
            let previousContent = self.content
            self.content = content
            var currentContentSize = CGSize()
        
            if let content = self.content {
                var previousActive: Bool?
                var previousMuted: Bool?
                if let previousContent = previousContent, case let .mediaDownload(_, _, _, _, muted, active) = previousContent {
                    previousActive = active
                    previousMuted = muted
                }
                
                switch content {
                    case let .text(inset, backgroundColor, foregroundColor, text):
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
                        self.durationNode.frame = CGRect(x: 7.0 + inset, y: 3.0, width: durationSize.width, height: durationSize.height)
                        currentContentSize = CGSize(width: widthForString(text.string) + 14.0 + inset, height: 18.0)
                    
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
                        if previousMuted == nil {
                            previousMuted = muted
                        }
                        
                        let textTransition = previousActive != active ? transition : .immediate
                        transition = (previousMuted != muted || previousActive != active) ? transition : .immediate
                        
                        let durationString = NSMutableAttributedString(string: duration, attributes: [.font: font, .foregroundColor: foregroundColor])
                        self.durationNode.attributedText = durationString
                        
                        var sizeWidth: CGFloat = 0.0
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
                            sizeWidth = widthForString(size)
                            sizeNode.attributedText = sizeString
                            let sizeSize = sizeNode.measure(CGSize(width: 160.0, height: 160.0))
                            let sizeFrame = CGRect(x: active ? 42.0 : 7.0, y: active ? 19.0 : 2.0, width: sizeSize.width, height: sizeSize.height)
                            sizeNode.bounds = CGRect(origin: CGPoint(), size: sizeFrame.size)
                            
                            let previousFrame = sizeNode.frame
                            if previousFrame.center.y != sizeFrame.center.y {
                                textTransition.updatePosition(node: sizeNode, position: sizeFrame.center)
                            } else {
                                sizeNode.layer.removeAllAnimations()
                                sizeNode.frame = sizeFrame
                            }
                            transition.updateAlpha(node: sizeNode, alpha: 1.0)
                        } else if let sizeNode = self.sizeNode {
                            let sizeSize = sizeNode.frame.size
                            let sizeFrame = CGRect(x: active ? 42.0 : 7.0, y: active ? 19.0 : 2.0, width: sizeSize.width, height: sizeSize.height)
                            sizeNode.bounds = CGRect(origin: CGPoint(), size: sizeFrame.size)
                            textTransition.updatePosition(node: sizeNode, position: sizeFrame.center)
                            
                            transition.updateAlpha(node: sizeNode, alpha: 0.0)
                        }
                        
                        let durationSize = self.durationNode.measure(CGSize(width: 160.0, height: 160.0))
                        if let statusNode = self.mediaDownloadStatusNode {
                            transition.updateAlpha(node: statusNode, alpha: active ? 1.0 : 0.0)
                        }
                        
                        let durationFrame = CGRect(x: active ? 42.0 : 7.0, y: active ? 6.0 : 2.0 + UIScreenPixel, width: durationSize.width, height: durationSize.height)
                        self.durationNode.bounds = CGRect(origin: CGPoint(), size: durationFrame.size)
                        textTransition.updatePosition(node: self.durationNode, position: durationFrame.center)
                        
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
                        
                        let durationWidth = widthForString(duration)
                        transition.updatePosition(node: iconNode, position: CGPoint(x: (active ? 42.0 : 7.0) + durationWidth + 4.0 + 7.0, y: (active ? 8.0 : 4.0) + 5.0))
                        
                        if muted {
                            transition.updateAlpha(node: iconNode, alpha: 1.0)
                            transition.updateTransformScale(node: iconNode, scale: 1.0)
                        } else if let iconNode = self.iconNode {
                            transition.updateAlpha(node: iconNode, alpha: 0.0)
                            transition.updateTransformScale(node: iconNode, scale: 0.001)
                        }
                        
                        var contentWidth: CGFloat = max(sizeWidth, durationWidth + (muted ? 17.0 : 0.0)) + 14.0
                        if active {
                            contentWidth += 36.0
                        }
                        currentContentSize = CGSize(width: contentWidth, height: active ? 38.0 : 18.0)
                }
            }
            
            var originX: CGFloat = 0.0
            if alignment == .right {
                originX = -currentContentSize.width
            }
            let previousSize = self.backgroundNode.frame.size
            if previousSize.height == 0 || (previousSize.height == currentContentSize.height && currentContentSize.height == 38.0) {
                self.backgroundNode.frame = CGRect(x: originX, y: 0.0, width: currentContentSize.width, height: currentContentSize.height)
            } else {
                transition.updateFrame(node: self.backgroundNode, frame: CGRect(x: originX, y: 0.0, width: currentContentSize.width, height: currentContentSize.height))
            }
            
            contentSize = currentContentSize
            self.previousContentSize = contentSize
        } else {
            contentSize = previousContentSize
        }
        
        if self.mediaDownloadState != mediaDownloadState || previousContentSize != contentSize {
            self.mediaDownloadState = mediaDownloadState
            if let mediaDownloadState = self.mediaDownloadState, let contentSize = contentSize {
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
                var originY: CGFloat = 5.0
                switch mediaDownloadState {
                    case .remote:
                        if let theme = theme, let image = PresentationResourcesChat.chatBubbleFileCloudFetchMediaIcon(theme) {
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
                        state = .progress(color: .white, lineWidth: nil, value: 0.0, cancelEnabled: true, animateRotation: true)
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
                mediaDownloadStatusNode.transitionToState(state, animated: badgeAnimated, completion: {})
            } else if let mediaDownloadStatusNode = self.mediaDownloadStatusNode {
                mediaDownloadStatusNode.transitionToState(.none, animated: badgeAnimated, completion: {})
            }
        }
    }
    
    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.backgroundNode.frame.contains(point)
    }
}

