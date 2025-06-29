import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TextFormat
import UrlEscaping
import SwiftSignalKit
import AccountContext
import AvatarNode
import TelegramPresentationData
import ChatMessageBackground
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import PollBubbleTimerNode
import TextNodeWithEntities
import ShimmeringLinkNode
import ChatControllerInteraction

private final class ChatMessageTaskOptionRadioNodeParameters: NSObject {
    let timestamp: Double
    let staticColor: UIColor
    let animatedColor: UIColor
    let fillColor: UIColor
    let foregroundColor: UIColor
    let offset: Double?
    let isChecked: Bool?
    let checkTransition: ChatMessageTaskOptionRadioNodeCheckTransition?
    
    init(timestamp: Double, staticColor: UIColor, animatedColor: UIColor, fillColor: UIColor, foregroundColor: UIColor, offset: Double?, isChecked: Bool?, checkTransition: ChatMessageTaskOptionRadioNodeCheckTransition?) {
        self.timestamp = timestamp
        self.staticColor = staticColor
        self.animatedColor = animatedColor
        self.fillColor = fillColor
        self.foregroundColor = foregroundColor
        self.offset = offset
        self.isChecked = isChecked
        self.checkTransition = checkTransition
        
        super.init()
    }
}

private final class ChatMessageTaskOptionRadioNodeCheckTransition {
    let startTime: Double
    let duration: Double
    let previousValue: Bool
    let updatedValue: Bool
    
    init(startTime: Double, duration: Double, previousValue: Bool, updatedValue: Bool) {
        self.startTime = startTime
        self.duration = duration
        self.previousValue = previousValue
        self.updatedValue = updatedValue
    }
}

private final class ChatMessageTaskOptionRadioNode: ASDisplayNode {
    private(set) var staticColor: UIColor?
    private(set) var animatedColor: UIColor?
    private(set) var fillColor: UIColor?
    private(set) var foregroundColor: UIColor?
    private var isInHierarchyValue: Bool = false
    private(set) var isAnimating: Bool = false
    private var startTime: Double?
    private var checkTransition: ChatMessageTaskOptionRadioNodeCheckTransition?
    private(set) var isChecked: Bool?
    
    private var displayLink: ConstantDisplayLinkAnimator?
    
    private var shouldBeAnimating: Bool {
        return self.isInHierarchyValue && (self.isAnimating || self.checkTransition != nil)
    }
    
    func updateIsChecked(_ value: Bool, animated: Bool) {
        if let previousValue = self.isChecked, previousValue != value {
            self.checkTransition = ChatMessageTaskOptionRadioNodeCheckTransition(startTime: CACurrentMediaTime(), duration: 0.15, previousValue: previousValue, updatedValue: value)
            self.isChecked = value
            self.updateAnimating()
            self.setNeedsDisplay()
        }
    }
    
    override init() {
        super.init()
        
        self.isUserInteractionEnabled = false
        self.isOpaque = false
    }
    
    deinit {
        self.displayLink?.isPaused = true
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        let previous = self.shouldBeAnimating
        self.isInHierarchyValue = true
        let updated = self.shouldBeAnimating
        if previous != updated {
            self.updateAnimating()
        }
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        let previous = self.shouldBeAnimating
        self.isInHierarchyValue = false
        let updated = self.shouldBeAnimating
        if previous != updated {
            self.updateAnimating()
        }
    }
    
    func update(staticColor: UIColor, animatedColor: UIColor, fillColor: UIColor, foregroundColor: UIColor, isSelectable: Bool, isAnimating: Bool) {
        var updated = false
        let shouldHaveBeenAnimating = self.shouldBeAnimating
        if !staticColor.isEqual(self.staticColor) {
            self.staticColor = staticColor
            updated = true
        }
        if !animatedColor.isEqual(self.animatedColor) {
            self.animatedColor = animatedColor
            updated = true
        }
        if !fillColor.isEqual(self.fillColor) {
            self.fillColor = fillColor
            updated = true
        }
        if !foregroundColor.isEqual(self.foregroundColor) {
            self.foregroundColor = foregroundColor
            updated = true
        }
        if isSelectable != (self.isChecked != nil) {
            if isSelectable {
                self.isChecked = false
            } else {
                self.isChecked = nil
                self.checkTransition = nil
            }
            updated = true
        }
        if isAnimating != self.isAnimating {
            self.isAnimating = isAnimating
            let updated = self.shouldBeAnimating
            if shouldHaveBeenAnimating != updated {
                self.updateAnimating()
            }
        }
        if updated {
            self.setNeedsDisplay()
        }
    }
    
    private func updateAnimating() {
        let timestamp = CACurrentMediaTime()
        if let checkTransition = self.checkTransition {
            if checkTransition.startTime + checkTransition.duration <= timestamp {
                self.checkTransition = nil
            }
        }
        
        if self.shouldBeAnimating {
            if self.isAnimating && self.startTime == nil {
                self.startTime = timestamp
            }
            if self.displayLink == nil {
                self.displayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.updateAnimating()
                    self?.setNeedsDisplay()
                })
                self.displayLink?.isPaused = false
                self.setNeedsDisplay()
            }
        } else if let displayLink = self.displayLink {
            self.startTime = nil
            displayLink.invalidate()
            self.displayLink = nil
            self.setNeedsDisplay()
        }
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        if let staticColor = self.staticColor, let animatedColor = self.animatedColor, let fillColor = self.fillColor, let foregroundColor = self.foregroundColor {
            let timestamp = CACurrentMediaTime()
            var offset: Double?
            if let startTime = self.startTime {
                offset = CACurrentMediaTime() - startTime
            }
            return ChatMessageTaskOptionRadioNodeParameters(timestamp: timestamp, staticColor: staticColor, animatedColor: animatedColor, fillColor: fillColor, foregroundColor: foregroundColor, offset: offset, isChecked: self.isChecked, checkTransition: self.checkTransition)
        } else {
            return nil
        }
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        if isCancelled() {
            return
        }
        
        guard let parameters = parameters as? ChatMessageTaskOptionRadioNodeParameters else {
            return
        }
        
        let context = UIGraphicsGetCurrentContext()!
        
        if let offset = parameters.offset {
            let t = max(0.0, offset)
            let colorFadeInDuration = 0.2
            let color: UIColor
            if t < colorFadeInDuration {
                color = parameters.staticColor.mixedWith(parameters.animatedColor, alpha: CGFloat(t / colorFadeInDuration))
            } else {
                color = parameters.animatedColor
            }
            context.setStrokeColor(color.cgColor)
            
            let rotationDuration = 1.15
            let rotationProgress = CGFloat(offset.truncatingRemainder(dividingBy: rotationDuration) / rotationDuration)
            context.translateBy(x: bounds.midX, y: bounds.midY)
            context.rotate(by: rotationProgress * 2.0 * CGFloat.pi)
            context.translateBy(x: -bounds.midX, y: -bounds.midY)
            
            let fillDuration = 1.0
            if offset < fillDuration {
                let fillT = CGFloat(offset.truncatingRemainder(dividingBy: fillDuration) / fillDuration)
                let startAngle = fillT * 2.0 * CGFloat.pi - CGFloat.pi / 2.0
                let endAngle = -CGFloat.pi / 2.0
                
                let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: (bounds.size.width - 1.0) / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                path.lineWidth = 1.0
                path.lineCapStyle = .round
                path.stroke()
            } else {
                let halfProgress: CGFloat = 0.7
                let fillPhase = 0.6
                let keepPhase = 0.0
                let finishPhase = 0.6
                let totalDuration = fillPhase + keepPhase + finishPhase
                let localOffset = (offset - fillDuration).truncatingRemainder(dividingBy: totalDuration)
                
                let angleOffsetT: CGFloat = -CGFloat(floor((offset - fillDuration) / totalDuration))
                let angleOffset = (angleOffsetT * (1.0 - halfProgress) * 2.0 * CGFloat.pi).truncatingRemainder(dividingBy: 2.0 * CGFloat.pi)
                context.translateBy(x: bounds.midX, y: bounds.midY)
                context.rotate(by: angleOffset)
                context.translateBy(x: -bounds.midX, y: -bounds.midY)
                
                if localOffset < fillPhase + keepPhase {
                    let fillT = CGFloat(min(1.0, localOffset / fillPhase))
                    let startAngle = -CGFloat.pi / 2.0
                    let endAngle = (fillT * halfProgress) * 2.0 * CGFloat.pi - CGFloat.pi / 2.0
                    
                    let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: (bounds.size.width - 1.0) / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                    path.lineWidth = 1.0
                    path.lineCapStyle = .round
                    path.stroke()
                } else {
                    let finishT = CGFloat((localOffset - (fillPhase + keepPhase)) / finishPhase)
                    let endAngle = halfProgress * 2.0 * CGFloat.pi - CGFloat.pi / 2.0
                    let startAngle = -CGFloat.pi / 2.0 * (1.0 - finishT) + endAngle * finishT
                    
                    let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: (bounds.size.width - 1.0) / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                    path.lineWidth = 1.0
                    path.lineCapStyle = .round
                    path.stroke()
                }
            }
        } else {
            if let isChecked = parameters.isChecked {
                let checkedT: CGFloat
                let fromValue: CGFloat
                let toValue: CGFloat
                let fromAlpha: CGFloat
                let toAlpha: CGFloat
                if let checkTransition = parameters.checkTransition {
                    checkedT = CGFloat(max(0.0, min(1.0, (parameters.timestamp - checkTransition.startTime) / checkTransition.duration)))
                    fromValue = checkTransition.previousValue ? bounds.width : 0.0
                    fromAlpha = checkTransition.previousValue ? 1.0 : 0.0
                    toValue = checkTransition.updatedValue ? bounds.width : 0.0
                    toAlpha = checkTransition.updatedValue ? 1.0 : 0.0
                } else {
                    checkedT = 1.0
                    fromValue = isChecked ? bounds.width : 0.0
                    fromAlpha = isChecked ? 1.0 : 0.0
                    toValue = isChecked ? bounds.width : 0.0
                    toAlpha = isChecked ? 1.0 : 0.0
                }
                
                let diameter = fromValue * (1.0 - checkedT) + toValue * checkedT
                let alpha = fromAlpha * (1.0 - checkedT) + toAlpha * checkedT
                
                if abs(diameter - 1.0) > CGFloat.ulpOfOne {
                    context.setStrokeColor(parameters.staticColor.cgColor)
                    context.strokeEllipse(in: CGRect(origin: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: bounds.width - 1.0, height: bounds.height - 1.0)))
                }
                
                if !diameter.isZero {
                    context.setFillColor(parameters.fillColor.withAlphaComponent(alpha).cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: (bounds.width - diameter) / 2.0, y: (bounds.width - diameter) / 2.0), size: CGSize(width: diameter, height: diameter)))
                    
                    context.setLineWidth(1.5)
                    context.setLineJoin(.round)
                    context.setLineCap(.round)
                    
                    context.setStrokeColor(parameters.foregroundColor.withAlphaComponent(alpha).cgColor)
                    if parameters.foregroundColor.alpha.isZero {
                        context.setBlendMode(.clear)
                    }
                    let startPoint = CGPoint(x: 6.0, y: 12.13)
                    let centerPoint = CGPoint(x: 9.28, y: 15.37)
                    let endPoint = CGPoint(x: 16.0, y: 8.0)
                    
                    let pathStartT: CGFloat = 0.15
                    let pathT = max(0.0, (alpha - pathStartT) / (1.0 - pathStartT))
                    let pathMiddleT: CGFloat = 0.4
                    
                    context.move(to: startPoint)
                    if pathT >= pathMiddleT {
                        context.addLine(to: centerPoint)
                        
                        let pathEndT = (pathT - pathMiddleT) / (1.0 - pathMiddleT)
                        if pathEndT >= 1.0 {
                            context.addLine(to: endPoint)
                        } else {
                            context.addLine(to: CGPoint(x: (1.0 - pathEndT) * centerPoint.x + pathEndT * endPoint.x, y: (1.0 - pathEndT) * centerPoint.y + pathEndT * endPoint.y))
                        }
                    } else {
                        context.addLine(to: CGPoint(x: (1.0 - pathT) * startPoint.x + pathT * centerPoint.x, y: (1.0 - pathT) * startPoint.y + pathT * centerPoint.y))
                    }
                    context.strokePath()
                    context.setBlendMode(.normal)
                }
            } else {
                context.setStrokeColor(parameters.staticColor.cgColor)
                context.strokeEllipse(in: CGRect(origin: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: bounds.width - 1.0, height: bounds.height - 1.0)))
            }
        }
    }
}

private let percentageFont = Font.bold(14.5)
private let percentageSmallFont = Font.bold(12.5)

private func generatePercentageImage(presentationData: ChatPresentationData, incoming: Bool, value: Int, targetValue: Int) -> UIImage {
    return generateImage(CGSize(width: 42.0, height: 20.0), rotatedContext: { size, context in
        UIGraphicsPushContext(context)
        context.clear(CGRect(origin: CGPoint(), size: size))
        let font: UIFont
        if targetValue == 100 {
            font = percentageSmallFont
        } else {
            font = percentageFont
        }
        let string = NSAttributedString(string: "\(value)%", font: font, textColor: incoming ? presentationData.theme.theme.chat.message.incoming.primaryTextColor : presentationData.theme.theme.chat.message.outgoing.primaryTextColor, paragraphAlignment: .right)
        string.draw(in: CGRect(origin: CGPoint(x: 0.0, y: targetValue == 100 ? 3.0 : 2.0), size: size))
        UIGraphicsPopContext()
    })!
}

private func generatePercentageAnimationImages(presentationData: ChatPresentationData, incoming: Bool, from fromValue: Int, to toValue: Int, duration: Double) -> [UIImage] {
    let minimumFrameDuration = 1.0 / 40.0
    let numberOfFrames = max(1, Int(duration / minimumFrameDuration))
    var images: [UIImage] = []
    for i in 0 ..< numberOfFrames {
        let t = CGFloat(i) / CGFloat(numberOfFrames)
        images.append(generatePercentageImage(presentationData: presentationData, incoming: incoming, value: Int((1.0 - t) * CGFloat(fromValue) + t * CGFloat(toValue)), targetValue: toValue))
    }
    return images
}

private final class ChatMessageTodoItemNode: ASDisplayNode {
    private var backgroundWallpaperNode: ChatMessageBubbleBackdrop?
    private var backgroundNode: ChatMessageBackground?
    private var extractedRadioView: UIView?
    private var extractedIconView: UIView?
    private var extractedAvatarView: UIView?
    private var extractedTitleNode: TextNodeWithEntities?
    private var extractedNameView: UIView?
    
    fileprivate let contextSourceNode: ContextExtractedContentContainingNode
    fileprivate let containerNode: ASDisplayNode
    fileprivate let highlightedBackgroundNode: ASDisplayNode
    private var avatarNode: AvatarNode?
    private(set) var radioNode: ChatMessageTaskOptionRadioNode?
    private var iconNode: ASImageNode?
    fileprivate var titleNode: TextNodeWithEntities?
    fileprivate var nameNode: TextNode?
    
    private let buttonNode: HighlightTrackingButtonNode
    let separatorNode: ASDisplayNode
    
    var context: AccountContext?
    var message: Message?
    var option: TelegramMediaTodo.Item?
    
    var pressed: (() -> Void)?
    var selectionUpdated: (() -> Void)?
    var longTapped: (() -> Void)?
    
    private var presentationData: ChatPresentationData?
    private var presentationContext: ChatPresentationContext?
    
    weak var previousOptionNode: ChatMessageTodoItemNode?
    
    private var canMark = false
    private var isPremium = false
    
    private var ignoreNextTap = false
    
    var visibilityRect: CGRect? {
        didSet {
            if self.visibilityRect != oldValue {
                if let titleNode = self.titleNode {
                    if let visibilityRect = self.visibilityRect {
                        titleNode.visibilityRect = visibilityRect.offsetBy(dx: 0.0, dy: titleNode.textNode.frame.minY)
                    } else {
                        titleNode.visibilityRect = nil
                    }
                }
            }
        }
    }
    
    override init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ASDisplayNode()
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.alpha = 0.0
        self.highlightedBackgroundNode.isUserInteractionEnabled = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
                
        super.init()
                
        self.addSubnode(self.highlightedBackgroundNode)
        
        self.addSubnode(self.contextSourceNode)
        self.addSubnode(self.containerNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    if let theme = strongSelf.presentationData?.theme.theme, theme.overallDarkAppearance, let contentNode = strongSelf.supernode as? ChatMessageTodoBubbleContentNode, let backdropNode = contentNode.bubbleBackgroundNode?.backdropNode {
                        strongSelf.highlightedBackgroundNode.layer.compositingFilter = "overlayBlendMode"
                        strongSelf.highlightedBackgroundNode.frame = strongSelf.view.convert(strongSelf.highlightedBackgroundNode.frame, to: backdropNode.view)
                        backdropNode.addSubnode(strongSelf.highlightedBackgroundNode)
                    } else {
                        strongSelf.insertSubnode(strongSelf.highlightedBackgroundNode, at: 0)
                    }
                    
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                    
                    strongSelf.separatorNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.separatorNode.alpha = 0.0
                    
                    strongSelf.previousOptionNode?.separatorNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.previousOptionNode?.separatorNode.alpha = 0.0
                    
                    Queue.mainQueue().after(0.5) {
                        if strongSelf.highlightedBackgroundNode.alpha == 1.0 {
                            strongSelf.ignoreNextTap = true
                            strongSelf.longTapped?()
                        }
                    }
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { finished in
                        if finished && strongSelf.highlightedBackgroundNode.supernode != strongSelf {
                            strongSelf.highlightedBackgroundNode.layer.compositingFilter = nil
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: strongSelf.highlightedBackgroundNode.frame.size)
                            strongSelf.insertSubnode(strongSelf.highlightedBackgroundNode, at: 0)
                        }
                    })
                    
                    strongSelf.separatorNode.alpha = 1.0
                    strongSelf.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    
                    strongSelf.previousOptionNode?.separatorNode.alpha = 1.0
                    strongSelf.previousOptionNode?.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                }
            }
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtractedToContextPreview, transition in
            guard let self else {
                return
            }
            if isExtractedToContextPreview {
                self.buttonNode.highligthedChanged(false)
                
                var offset: CGFloat = 0.0
                var inset: CGFloat = 0.0
                var type: ChatMessageBackgroundType
                
                var incoming = false
                if let context = self.context, let message = self.message {
                    incoming = message.effectivelyIncoming(context.account.peerId)
                }
                
                if incoming {
                    type = .incoming(.Extracted)
                    offset = -5.0
                    inset = 5.0
                } else {
                    type = .outgoing(.Extracted)
                    inset = 5.0
                }
                
                if let _ = self.backgroundNode {
                } else if let presentationData = self.presentationData, let presentationContext = self.presentationContext {
                    let graphics = PresentationResourcesChat.principalGraphics(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, bubbleCorners: presentationData.chatBubbleCorners)
                    
                    let backgroundWallpaperNode = ChatMessageBubbleBackdrop()
                    backgroundWallpaperNode.alpha = 0.0
                    
                    let backgroundNode = ChatMessageBackground()
                    backgroundNode.alpha = 0.0
                                        
                    self.contextSourceNode.contentNode.insertSubnode(backgroundNode, at: 0)
                    self.contextSourceNode.contentNode.insertSubnode(backgroundWallpaperNode, at: 0)
                    
                    self.backgroundWallpaperNode = backgroundWallpaperNode
                    self.backgroundNode = backgroundNode
                    
                    transition.updateAlpha(node: backgroundNode, alpha: 1.0)
                    transition.updateAlpha(node: backgroundWallpaperNode, alpha: 1.0)
                    
                    backgroundNode.setType(type: type, highlighted: false, graphics: graphics, maskMode: true, hasWallpaper: presentationData.theme.wallpaper.hasWallpaper, transition: .immediate, backgroundNode: presentationContext.backgroundNode)
                    backgroundWallpaperNode.setType(type: type, theme: presentationData.theme, essentialGraphics: graphics, maskMode: true, backgroundNode: presentationContext.backgroundNode)
                }
                
                let backgroundFrame = CGRect(x: offset, y: 0.0, width: self.bounds.width + inset, height: self.bounds.height)
                self.backgroundNode?.updateLayout(size: backgroundFrame.size, transition: .immediate)
                self.backgroundNode?.frame = backgroundFrame
                self.backgroundWallpaperNode?.frame = backgroundFrame
                
//                if let (rect, containerSize) = self.absoluteRect {
//                    let mappedRect = CGRect(origin: CGPoint(x: rect.minX + backgroundFrame.minX, y: rect.minY + backgroundFrame.minY), size: rect.size)
//                    self.backgroundWallpaperNode?.update(rect: mappedRect, within: containerSize)
//                }
                
                if let extractedIconView = self.iconNode?.view.snapshotContentTree() {
                    self.extractedIconView = extractedIconView
                    self.contextSourceNode.contentNode.view.addSubview(extractedIconView)
                }
                
                if let extractedRadioView = self.radioNode?.view.snapshotContentTree() {
                    self.extractedRadioView = extractedRadioView
                    self.contextSourceNode.contentNode.view.addSubview(extractedRadioView)
                }
                
                if let extractedAvatarView = self.avatarNode?.view.snapshotContentTree() {
                    self.extractedAvatarView = extractedAvatarView
                    self.contextSourceNode.contentNode.view.addSubview(extractedAvatarView)
                }
                
                if let titleNode = self.titleNode, let context = self.context, let presentationData = self.presentationData {
                    let titleConstrainedWidth = titleNode.textNode.cachedLayout?.size.width ?? 1.0
                    let makeTitleLayout = TextNodeWithEntities.asyncLayout(self.extractedTitleNode)
                    let (_, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: self.titleNode?.textNode.cachedLayout?.attributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: titleConstrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets(top: 1.0, left: 0.0, bottom: 1.0, right: 0.0)))
                    let extractedTitleNode = titleApply(TextNodeWithEntities.Arguments(
                        context: context,
                        cache: context.animationCache,
                        renderer: context.animationRenderer,
                        placeholderColor: incoming ? presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor,
                        attemptSynchronous: true
                    ))
                    extractedTitleNode.textNode.frame = titleNode.textNode.frame
                    self.contextSourceNode.contentNode.addSubnode(extractedTitleNode.textNode)
                    self.extractedTitleNode = extractedTitleNode
                }
                
                if let extractedNameView = self.nameNode?.view.snapshotContentTree() {
                    self.extractedNameView = extractedNameView
                    self.contextSourceNode.contentNode.view.addSubview(extractedNameView)
                }
            } else {
                if let backgroundNode = self.backgroundNode {
                    self.backgroundNode = nil
                    transition.updateAlpha(node: backgroundNode, alpha: 0.0, completion: { [weak backgroundNode] _ in
                        self.extractedRadioView?.removeFromSuperview()
                        self.extractedRadioView = nil
                        self.extractedIconView?.removeFromSuperview()
                        self.extractedIconView = nil
                        self.extractedAvatarView?.removeFromSuperview()
                        self.extractedAvatarView = nil
                        self.extractedTitleNode?.textNode.removeFromSupernode()
                        self.extractedTitleNode = nil
                        self.extractedNameView?.removeFromSuperview()
                        self.extractedNameView = nil
                        
                        backgroundNode?.removeFromSupernode()
                    })
                }
                if let backgroundWallpaperNode = self.backgroundWallpaperNode {
                    self.backgroundWallpaperNode = nil
                    transition.updateAlpha(node: backgroundWallpaperNode, alpha: 0.0, completion: { [weak backgroundWallpaperNode] _ in
                        backgroundWallpaperNode?.removeFromSupernode()
                    })
                }
            }
        }
    }
    
    @objc private func buttonPressed() {
        guard !self.ignoreNextTap else {
            self.ignoreNextTap = false
            return
        }

        var isScheduledMessages = false
        if let message = self.message, Namespaces.Message.allScheduled.contains(message.id.namespace) {
            isScheduledMessages = true
        }
        let canUpdate = self.canMark && self.isPremium && !isScheduledMessages
        
        if let radioNode = self.radioNode, let isChecked = radioNode.isChecked, canUpdate {
            radioNode.updateIsChecked(!isChecked, animated: true)
            self.selectionUpdated?()
        } else {
            self.pressed?()
        }
    }
        
    func linkRectsAtPoint(_ point: CGPoint?) -> [CGRect]? {
        guard let textNode = self.titleNode else {
            return nil
        }
        var rects: [CGRect]?
        if let point = point {
            let textNodeFrame = textNode.textNode.frame
            if let (index, attributes) = textNode.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                let possibleNames: [String] = [
                    TelegramTextAttributes.URL,
                    TelegramTextAttributes.PeerMention,
                    TelegramTextAttributes.PeerTextMention,
                    TelegramTextAttributes.BotCommand,
                    TelegramTextAttributes.Hashtag,
                    TelegramTextAttributes.BankCard
                ]
                for name in possibleNames {
                    if let _ = attributes[NSAttributedString.Key(rawValue: name)], let textRects = textNode.textNode.attributeRects(name: name, at: index) {
                        rects = textRects.map { $0.offsetBy(dx: textNodeFrame.minX, dy: textNodeFrame.minY) }
                        break
                    }
                }
            }
        }
        return rects
    }
    
    func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        guard let textNode = self.titleNode else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
        let textNodeFrame = textNode.textNode.frame
        if let (index, attributes) = textNode.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = textNode.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: concealed)))
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: false))
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return ChatMessageBubbleContentTapAction(content: .textMention(peerName))
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return ChatMessageBubbleContentTapAction(content: .botCommand(botCommand))
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return ChatMessageBubbleContentTapAction(content: .hashtag(hashtag.peerName, hashtag.hashtag))
            } else {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    static func asyncLayout(_ maybeNode: ChatMessageTodoItemNode?) -> (_ context: AccountContext, _ presentationData: ChatPresentationData, _ presentationContext: ChatPresentationContext, _ message: Message, _ todo: TelegramMediaTodo, _ option: TelegramMediaTodo.Item, _ completion: TelegramMediaTodo.Completion?, _ translation: TranslationMessageAttribute.Additional?, _ constrainedWidth: CGFloat) -> (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, (Bool, Bool, Bool) -> ChatMessageTodoItemNode))) {
        let makeTitleLayout = TextNodeWithEntities.asyncLayout(maybeNode?.titleNode)
        let makeNameLayout = TextNode.asyncLayout(maybeNode?.nameNode)
        
        return { context, presentationData, presentationContext, message, todo, option, completion, translation, constrainedWidth in
            var canMark = false
            if (todo.flags.contains(.othersCanComplete) || message.author?.id == context.account.peerId) {
                if let _ = message.forwardInfo {
                } else {
                    canMark = true
                }
            }
            
            let leftInset: CGFloat = canMark ? 57.0 : 29.0
            let rightInset: CGFloat = 12.0
            
            let incoming = message.effectivelyIncoming(context.account.peerId)
            let messageTheme = incoming ? presentationData.theme.theme.chat.message.incoming : presentationData.theme.theme.chat.message.outgoing
            
            var optionText = option.text
            var optionEntities = option.entities
            if let translation {
                optionText = translation.text
                optionEntities = translation.entities
            }
            
            if !canMark && completion != nil {
                optionEntities.append(MessageTextEntity(range: 0 ..< (optionText as NSString).length, type: .Strikethrough))
            }
            
            var underlineLinks = true
            if !messageTheme.primaryTextColor.isEqual(messageTheme.linkTextColor) {
                underlineLinks = false
            }
            
            let optionAttributedText = stringWithAppliedEntities(
                optionText,
                entities: optionEntities,
                baseColor: messageTheme.primaryTextColor,
                linkColor: messageTheme.linkTextColor,
                baseFont: presentationData.messageFont,
                linkFont: presentationData.messageFont,
                boldFont: presentationData.messageFont,
                italicFont: presentationData.messageFont,
                boldItalicFont: presentationData.messageFont,
                fixedFont: presentationData.messageFont,
                blockQuoteFont: presentationData.messageFont,
                underlineLinks: underlineLinks,
                message: message
            )
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: optionAttributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: max(1.0, constrainedWidth - leftInset - rightInset), height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets(top: 1.0, left: 0.0, bottom: 1.0, right: 0.0)))
            
            let nameLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if let completion, let peer = message.peers[completion.completedBy], todo.flags.contains(.othersCanComplete) {
                nameLayoutAndApply = makeNameLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.regular(11.0), textColor: messageTheme.secondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: max(1.0, constrainedWidth - leftInset - rightInset), height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets(top: 1.0, left: 0.0, bottom: 1.0, right: 0.0)))
            } else {
                nameLayoutAndApply = nil
            }
            
            let contentHeight: CGFloat = max(46.0, titleLayout.size.height + 22.0)
            
            let isSelectable: Bool = true
                                    
            return (titleLayout.size.width + leftInset + rightInset, { width in
                return (CGSize(width: width, height: contentHeight), { animated, inProgress, attemptSynchronous in
                    let node: ChatMessageTodoItemNode
                    if let maybeNode = maybeNode {
                        node = maybeNode
                    } else {
                        node = ChatMessageTodoItemNode()
                    }
                    
                    node.option = option
                    node.context = context
                    node.presentationData = presentationData
                    node.presentationContext = presentationContext
                    
                    node.canMark = canMark
                    node.isPremium = context.isPremium
                    
                    node.highlightedBackgroundNode.backgroundColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.highlight : presentationData.theme.theme.chat.message.outgoing.polls.highlight
                    
                    node.buttonNode.accessibilityLabel = option.text
                                        
                    if animated {
                        if let titleNode = node.titleNode, let cachedLayout = titleNode.textNode.cachedLayout {
                            if !cachedLayout.areLinesEqual(to: titleLayout) {
                                if let textContents = titleNode.textNode.contents {
                                    let fadeNode = ASDisplayNode()
                                    fadeNode.displaysAsynchronously = false
                                    fadeNode.contents = textContents
                                    fadeNode.frame = titleNode.textNode.frame
                                    fadeNode.isLayerBacked = true
                                    node.addSubnode(fadeNode)
                                    fadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak fadeNode] _ in
                                        fadeNode?.removeFromSupernode()
                                    })
                                    titleNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                }
                            }
                        }
                    }
                    
                    let titleNode = titleApply(TextNodeWithEntities.Arguments(
                        context: context,
                        cache: context.animationCache,
                        renderer: context.animationRenderer,
                        placeholderColor: incoming ? presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor,
                        attemptSynchronous: attemptSynchronous
                    ))
                    var titleNodeFrame: CGRect
                    if titleLayout.hasRTL {
                        titleNodeFrame = CGRect(origin: CGPoint(x: width - rightInset - titleLayout.size.width, y: 12.0), size: titleLayout.size)
                    } else {
                        titleNodeFrame = CGRect(origin: CGPoint(x: leftInset, y: 12.0), size: titleLayout.size)
                    }
                    if let _ = completion, todo.flags.contains(.othersCanComplete) {
                        titleNodeFrame = titleNodeFrame.offsetBy(dx: 0.0, dy: -6.0)
                    }
                    
                    if node.titleNode !== titleNode {
                        node.titleNode = titleNode
                        node.containerNode.addSubnode(titleNode.textNode)
                        titleNode.textNode.isUserInteractionEnabled = false
                        
                        if let visibilityRect = node.visibilityRect {
                            titleNode.visibilityRect = visibilityRect.offsetBy(dx: 0.0, dy: titleNodeFrame.minY)
                        }
                    }
                    
                    let previousFrame = titleNode.textNode.frame
                    titleNode.textNode.frame = titleNodeFrame
                    
                    if animated, previousFrame != titleNodeFrame {
                        titleNode.textNode.layer.animateFrame(from: previousFrame, to: titleNodeFrame, duration: 0.2)
                    }
                    
                    if let (nameLayout, nameApply) = nameLayoutAndApply {
                        var nameNodeFrame: CGRect
                        if titleLayout.hasRTL {
                            nameNodeFrame = CGRect(origin: CGPoint(x: width - rightInset - nameLayout.size.width, y: titleNodeFrame.maxY - 4.0), size: nameLayout.size)
                        } else {
                            nameNodeFrame = CGRect(origin: CGPoint(x: leftInset, y: titleNodeFrame.maxY - 4.0), size: nameLayout.size)
                        }
                        let nameNode = nameApply()
                        if node.nameNode !== nameNode {
                            node.nameNode = nameNode
                            node.containerNode.addSubnode(nameNode)
                            nameNode.isUserInteractionEnabled = false
                            
                            if animated {
                                nameNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        }
                        nameNode.frame = nameNodeFrame
                    } else if let nameNode = node.nameNode {
                        node.nameNode = nil
                        if animated {
                            nameNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak nameNode] _ in
                                nameNode?.removeFromSupernode()
                            })
                        } else {
                            nameNode.removeFromSupernode()
                        }
                    }
                    
                    if let completion, canMark && todo.flags.contains(.othersCanComplete) {
                        let avatarNode: AvatarNode
                        if let current = node.avatarNode {
                            avatarNode = current
                        } else {
                            avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 12.0))
                            node.containerNode.insertSubnode(avatarNode, at: 0)
                            node.avatarNode = avatarNode
                            if animated {
                                avatarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                avatarNode.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2, removeOnCompletion: false)
                            }
                        }
                        let avatarSize = CGSize(width: 22.0, height: 22.0)
                        avatarNode.frame = CGRect(origin: CGPoint(x: 24.0, y: 12.0), size: avatarSize)
                        if let peer = message.peers[completion.completedBy] {
                            avatarNode.setPeer(context: context, theme: presentationData.theme.theme, peer: EnginePeer(peer), displayDimensions: avatarSize, cutoutRect: CGRect(origin: CGPoint(x: -12.0, y: -1.0), size: CGSize(width: 24.0, height: 24.0)))
                        }
                    } else if let avatarNode = node.avatarNode {
                        node.avatarNode = nil
                        if animated {
                            avatarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak avatarNode] _ in
                                avatarNode?.removeFromSupernode()
                            })
                            avatarNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                        } else {
                            avatarNode.removeFromSupernode()
                        }
                    }
                    
                    if canMark {
                        let radioNode: ChatMessageTaskOptionRadioNode
                        if let current = node.radioNode {
                            radioNode = current
                        } else {
                            radioNode = ChatMessageTaskOptionRadioNode()
                            node.containerNode.addSubnode(radioNode)
                            node.radioNode = radioNode
                            if animated {
                                radioNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        }
                        let radioSize: CGFloat = 22.0
                        radioNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: CGSize(width: radioSize, height: radioSize))
                        radioNode.update(staticColor: incoming ? presentationData.theme.theme.chat.message.incoming.polls.radioButton : presentationData.theme.theme.chat.message.outgoing.polls.radioButton, animatedColor: incoming ? presentationData.theme.theme.chat.message.incoming.polls.radioProgress : presentationData.theme.theme.chat.message.outgoing.polls.radioProgress, fillColor: incoming ? presentationData.theme.theme.chat.message.incoming.polls.bar : presentationData.theme.theme.chat.message.outgoing.polls.bar, foregroundColor: incoming ? presentationData.theme.theme.chat.message.incoming.polls.barIconForeground : presentationData.theme.theme.chat.message.outgoing.polls.barIconForeground, isSelectable: isSelectable, isAnimating: inProgress)
                        
                        radioNode.updateIsChecked(completion != nil, animated: false)
                    } else if let radioNode = node.radioNode {
                        node.radioNode = nil
                        if animated {
                            radioNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak radioNode] _ in
                                radioNode?.removeFromSupernode()
                            })
                        } else {
                            radioNode.removeFromSupernode()
                        }
                    }
                    
                    if !canMark {
                        let iconNode: ASImageNode
                        if let current = node.iconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.displaysAsynchronously = false
                            node.containerNode.addSubnode(iconNode)
                            node.iconNode = iconNode
                            if animated {
                                iconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        }
                        
                        let icon: UIImage?
                        if incoming {
                            icon = completion != nil ? PresentationResourcesChat.chatBubbleTodoCheckIncomingIcon(presentationData.theme.theme) : PresentationResourcesChat.chatBubbleTodoDotIncomingIcon(presentationData.theme.theme)
                        } else {
                            icon = completion != nil ? PresentationResourcesChat.chatBubbleTodoCheckOutgoingIcon(presentationData.theme.theme) : PresentationResourcesChat.chatBubbleTodoDotOutgoingIcon(presentationData.theme.theme)
                        }
                        iconNode.image = icon
                        
                        let iconSize: CGFloat = 10.0
                        iconNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 19.0), size: CGSize(width: iconSize, height: iconSize))
                    } else if let iconNode = node.iconNode {
                        node.iconNode = nil
                        if animated {
                            iconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak iconNode] _ in
                                iconNode?.removeFromSupernode()
                            })
                        } else {
                            iconNode.removeFromSupernode()
                        }
                    }
                    
                    node.buttonNode.frame = CGRect(origin: CGPoint(x: 1.0, y: 0.0), size: CGSize(width: width - 2.0, height: contentHeight))
                    if node.highlightedBackgroundNode.supernode == node {
                        node.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: contentHeight + UIScreenPixel))
                    }
                    node.separatorNode.backgroundColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.separator : presentationData.theme.theme.chat.message.outgoing.polls.separator
                    node.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentHeight - UIScreenPixel), size: CGSize(width: width - leftInset, height: UIScreenPixel))
                    
                    node.containerNode.frame = CGRect(origin: .zero, size: CGSize(width: width, height: contentHeight))
                    node.contextSourceNode.frame = CGRect(origin: .zero, size: CGSize(width: width, height: contentHeight))
                    node.contextSourceNode.contentRect = CGRect(origin: .zero, size: CGSize(width: width, height: contentHeight))
                    
                    node.buttonNode.isAccessibilityElement = true
                    
                    return node
                })
            })
        }
    }
}

private let labelsFont = Font.regular(14.0)


public class ChatMessageTodoBubbleContentNode: ChatMessageBubbleContentNode {
    private let textNode: TextNodeWithEntities
    private let typeNode: TextNode
    private var timerNode: PollBubbleTimerNode?
    private let buttonViewResultsTextNode: TextNode
    private let buttonNode: HighlightableButtonNode
    private let statusNode: ChatMessageDateAndStatusNode
    private var optionNodes: [ChatMessageTodoItemNode] = []
    private var shimmeringNodes: [ShimmeringLinkNode] = []
    
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private var todo: TelegramMediaTodo?
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            if oldValue != self.visibility {
                switch self.visibility {
                case .none:
                    self.textNode.visibilityRect = nil
                    for optionNode in self.optionNodes {
                        optionNode.visibilityRect = nil
                    }
                case let .visible(_, subRect):
                    var subRect = subRect
                    subRect.origin.x = 0.0
                    subRect.size.width = 10000.0
                    self.textNode.visibilityRect = subRect.offsetBy(dx: 0.0, dy: -self.textNode.textNode.frame.minY)
                    for optionNode in self.optionNodes {
                        optionNode.visibilityRect = subRect.offsetBy(dx: 0.0, dy: -optionNode.frame.minY)
                    }
                }
            }
        }
    }
    
    required public init() {
        self.textNode = TextNodeWithEntities()
        self.textNode.textNode.isUserInteractionEnabled = false
        self.textNode.textNode.contentMode = .topLeft
        self.textNode.textNode.contentsScale = UIScreenScale
        self.textNode.textNode.displaysAsynchronously = false
        
        self.typeNode = TextNode()
        self.typeNode.isUserInteractionEnabled = false
        self.typeNode.contentMode = .topLeft
        self.typeNode.contentsScale = UIScreenScale
        self.typeNode.displaysAsynchronously = false
                        
        self.buttonViewResultsTextNode = TextNode()
        self.buttonViewResultsTextNode.isUserInteractionEnabled = false
        self.buttonViewResultsTextNode.contentMode = .topLeft
        self.buttonViewResultsTextNode.contentsScale = UIScreenScale
        self.buttonViewResultsTextNode.displaysAsynchronously = false
        
        self.buttonNode = HighlightableButtonNode()
        
        self.statusNode = ChatMessageDateAndStatusNode()
        
        super.init()
        
        self.addSubnode(self.textNode.textNode)
        self.addSubnode(self.typeNode)
        self.addSubnode(self.buttonViewResultsTextNode)
        self.addSubnode(self.buttonNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeTextLayout = TextNodeWithEntities.asyncLayout(self.textNode)
        let makeTypeLayout = TextNode.asyncLayout(self.typeNode)
        let makeViewResultsTextLayout = TextNode.asyncLayout(self.buttonViewResultsTextNode)
        let statusLayout = self.statusNode.asyncLayout()
                
        var previousOptionNodeLayouts: [Int32: (_ contet: AccountContext, _ presentationData: ChatPresentationData, _ presentationContext: ChatPresentationContext, _ message: Message, _ poll: TelegramMediaTodo, _ option: TelegramMediaTodo.Item, _ completion: TelegramMediaTodo.Completion?, _ translation: TranslationMessageAttribute.Additional?, _ constrainedWidth: CGFloat) -> (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, (Bool, Bool, Bool) -> ChatMessageTodoItemNode)))] = [:]
        for optionNode in self.optionNodes {
            if let option = optionNode.option {
                previousOptionNodeLayouts[option.id] = ChatMessageTodoItemNode.asyncLayout(optionNode)
            }
        }
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let additionalTextRightInset: CGFloat = 24.0
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: constrainedSize.width - horizontalInset - additionalTextRightInset, height: constrainedSize.height)
                
                var edited = false
                if item.attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var dateReplies = 0
                var starsCount: Int64?
                var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: item.message)
                if item.message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }
                for attribute in item.message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    } else if let attribute = attribute as? PaidStarsMessageAttribute, item.message.id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        starsCount = attribute.stars.value
                    }
                }
                
                let dateFormat: MessageTimestampStatusFormat
                if item.presentationData.isPreview {
                    dateFormat = .full
                } else {
                    dateFormat = .regular
                }
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: dateFormat, associatedData: item.associatedData)
                
                let statusType: ChatMessageDateAndStatusType?
                if case .customChatContents = item.associatedData.subject {
                    statusType = nil
                } else {
                    switch position {
                    case .linear(_, .None), .linear(_, .Neighbour(true, _, _)):
                        if incoming {
                            statusType = .BubbleIncoming
                        } else {
                            if message.flags.contains(.Failed) {
                                statusType = .BubbleOutgoing(.Failed)
                            } else if (message.flags.isSending && !message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                                statusType = .BubbleOutgoing(.Sending)
                            } else {
                                statusType = .BubbleOutgoing(.Sent(read: item.read))
                            }
                        }
                    default:
                        statusType = nil
                    }
                }
                    
                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))?
                
                if let statusType = statusType {
                    var isReplyThread = false
                    if case .replyThread = item.chatLocation {
                        isReplyThread = true
                    }
                    
                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: item.context,
                        presentationData: item.presentationData,
                        edited: edited,
                        impressionCount: viewCount,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: .trailingContent(contentWidth: 1000.0, reactionSettings: shouldDisplayInlineDateReactions(message: item.message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: true, preferAdditionalInset: false) : nil),
                        constrainedSize: textConstrainedSize,
                        availableReactions: item.associatedData.availableReactions,
                        savedMessageTags: item.associatedData.savedMessageTags,
                        reactions: dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        areReactionsTags: item.topMessage.areReactionsTags(accountPeerId: item.context.account.peerId),
                        messageEffect: item.topMessage.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects),
                        replyCount: dateReplies,
                        starsCount: starsCount,
                        isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && !isReplyThread,
                        hasAutoremove: item.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: item.topMessage),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                }
                
                var todo: TelegramMediaTodo?
                for media in item.message.media {
                    if let media = media as? TelegramMediaTodo {
                        todo = media
                        break
                    }
                }

                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                var todoTitleText = todo?.text ?? ""
                var todoTitleEntities = todo?.textEntities ?? []
                var pollOptions: [TranslationMessageAttribute.Additional] = []
                
                var isTranslating = false
                if let todo, let translateToLanguage = item.associatedData.translateToLanguage, !todo.text.isEmpty && incoming {
                    isTranslating = true
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? TranslationMessageAttribute, !attribute.text.isEmpty, attribute.toLang == translateToLanguage {
                            todoTitleText = attribute.text
                            todoTitleEntities = attribute.entities
                            pollOptions = attribute.additional
                            isTranslating = false
                            break
                        }
                    }
                }
                
                let attributedText = stringWithAppliedEntities(
                    todoTitleText,
                    entities: todoTitleEntities,
                    baseColor: messageTheme.primaryTextColor,
                    linkColor: messageTheme.linkTextColor,
                    baseFont: item.presentationData.messageBoldFont,
                    linkFont: item.presentationData.messageBoldFont,
                    boldFont: item.presentationData.messageBoldFont,
                    italicFont: item.presentationData.messageBoldFont,
                    boldItalicFont: item.presentationData.messageBoldFont,
                    fixedFont: item.presentationData.messageBoldFont,
                    blockQuoteFont: item.presentationData.messageBoldFont,
                    message: message
                )
                
                let textInsets = UIEdgeInsets(top: 2.0, left: 0.0, bottom: 5.0, right: 0.0)
                
                let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets))
                let typeText: String
                
                if let todo, todo.flags.contains(.othersCanComplete) {
                    typeText = item.presentationData.strings.Chat_Todo_Message_TitleGroup
                } else {
                    if let author = item.message.author, author.id != item.context.account.peerId {
                        typeText = item.presentationData.strings.Chat_Todo_Message_TitlePersonal(EnginePeer(author).compactDisplayTitle).string
                    } else {
                        typeText = item.presentationData.strings.Chat_Todo_Message_Title
                    }
                }
                
                let (typeLayout, typeApply) = makeTypeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: typeText, font: labelsFont, textColor: messageTheme.secondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                var bottomText: String = ""
                if let todo {
                    let format: String
                    if let author = item.message.author, author.id != item.context.account.peerId && !todo.flags.contains(.othersCanComplete) {
                        format = item.presentationData.strings.Chat_Todo_Message_CompletedBy(Int32(todo.completions.count)).replacingOccurrences(of: "{name}", with: EnginePeer(author).compactDisplayTitle)
                    } else {
                        format = item.presentationData.strings.Chat_Todo_Message_Completed(Int32(todo.completions.count))
                    }
                    bottomText = format.replacingOccurrences(of: "{count}", with: "\(todo.items.count)")
                }
                
                let (buttonViewResultsTextLayout, buttonViewResultsTextApply) = makeViewResultsTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: bottomText, font: labelsFont, textColor: messageTheme.secondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets))
                
                var textFrame = CGRect(origin: CGPoint(x: -textInsets.left, y: -textInsets.top), size: textLayout.size)
                var textFrameWithoutInsets = CGRect(origin: CGPoint(x: textFrame.origin.x + textInsets.left, y: textFrame.origin.y + textInsets.top), size: CGSize(width: textFrame.width - textInsets.left - textInsets.right, height: textFrame.height - textInsets.top - textInsets.bottom))
                
                textFrame = textFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                textFrameWithoutInsets = textFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                
                var boundingSize: CGSize = textFrameWithoutInsets.size
                boundingSize.width += additionalTextRightInset
                boundingSize.width = max(boundingSize.width, typeLayout.size.width)
                boundingSize.width = max(boundingSize.width, buttonViewResultsTextLayout.size.width + 4.0/* + (statusSize?.width ?? 0.0)*/)
                
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    boundingSize.width = max(boundingSize.width, statusSuggestedWidthAndContinue.0)
                }
                
                boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                
                var pollOptionsFinalizeLayouts: [(CGFloat) -> (CGSize, (Bool, Bool, Bool) -> ChatMessageTodoItemNode)] = []
                if let todo {
                    for i in 0 ..< todo.items.count {
                        let todoItem = todo.items[i]
                        
                        let makeLayout: (_ context: AccountContext, _ presentationData: ChatPresentationData, _ presentationContext: ChatPresentationContext, _ message: Message, _ todo: TelegramMediaTodo, _ item: TelegramMediaTodo.Item, _ completion: TelegramMediaTodo.Completion?, _ translation: TranslationMessageAttribute.Additional?, _ constrainedWidth: CGFloat) -> (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, (Bool, Bool, Bool) -> ChatMessageTodoItemNode)))
                        if let previous = previousOptionNodeLayouts[todoItem.id] {
                            makeLayout = previous
                        } else {
                            makeLayout = ChatMessageTodoItemNode.asyncLayout(nil)
                        }
                        
                        var translation: TranslationMessageAttribute.Additional?
                        if !pollOptions.isEmpty && i < pollOptions.count {
                            translation = pollOptions[i]
                        }
                        
                        let itemCompletion = todo.completions.first(where: { $0.id == todoItem.id })
                        
                        let result = makeLayout(item.context, item.presentationData, item.controllerInteraction.presentationContext, item.message, todo, todoItem, itemCompletion, translation, constrainedSize.width - layoutConstants.bubble.borderInset * 2.0)
                        boundingSize.width = max(boundingSize.width, result.minimumWidth + layoutConstants.bubble.borderInset * 2.0)
                        pollOptionsFinalizeLayouts.append(result.1)
                    }
                }
                
                boundingSize.width = max(boundingSize.width, min(270.0, constrainedSize.width))
                
                return (boundingSize.width, { boundingWidth in
                    var resultSize = CGSize(width: max(boundingSize.width, boundingWidth), height: boundingSize.height)
                    
                    let titleTypeSpacing: CGFloat = -4.0
                    let typeOptionsSpacing: CGFloat = 3.0
                    resultSize.height += titleTypeSpacing + typeLayout.size.height + typeOptionsSpacing
                    
                    var optionNodesSizesAndApply: [(CGSize, (Bool, Bool, Bool) -> ChatMessageTodoItemNode)] = []
                    for finalizeLayout in pollOptionsFinalizeLayouts {
                        let result = finalizeLayout(boundingWidth - layoutConstants.bubble.borderInset * 2.0)
                        resultSize.width = max(resultSize.width, result.0.width + layoutConstants.bubble.borderInset * 2.0)
                        resultSize.height += result.0.height
                        optionNodesSizesAndApply.append(result)
                    }
                    
                    let statusSpacing: CGFloat = 33.0
                    let optionsButtonSpacing: CGFloat = 12.0
                    resultSize.height += 44.0
                    
                    var statusSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> Void)?
                    if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                        statusSizeAndApply = statusSuggestedWidthAndContinue.1(boundingWidth)
                    }
                    
                    if let statusSizeAndApply = statusSizeAndApply {
                        resultSize.height += statusSizeAndApply.0.height - 6.0
                    }
                    
                    let buttonViewResultsTextFrame = CGRect(origin: CGPoint(x: floor((resultSize.width - buttonViewResultsTextLayout.size.width) / 2.0), y: optionsButtonSpacing), size: buttonViewResultsTextLayout.size)
                    
                    return (resultSize, { [weak self] animation, synchronousLoad, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.todo = todo
                            
                            let cachedLayout = strongSelf.textNode.textNode.cachedLayout
                            if case .System = animation {
                                if let cachedLayout = cachedLayout {
                                    if !cachedLayout.areLinesEqual(to: textLayout) {
                                        if let textContents = strongSelf.textNode.textNode.contents {
                                            let fadeNode = ASDisplayNode()
                                            fadeNode.displaysAsynchronously = false
                                            fadeNode.contents = textContents
                                            fadeNode.frame = strongSelf.textNode.textNode.frame
                                            fadeNode.isLayerBacked = true
                                            strongSelf.addSubnode(fadeNode)
                                            fadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak fadeNode] _ in
                                                fadeNode?.removeFromSupernode()
                                            })
                                            strongSelf.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                        }
                                    }
                                }
                            }
                            
                            let _ = textApply(TextNodeWithEntities.Arguments(
                                context: item.context,
                                cache: item.context.animationCache,
                                renderer: item.context.animationRenderer,
                                placeholderColor: incoming ? item.presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : item.presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor,
                                attemptSynchronous: synchronousLoad)
                            )
                            let _ = typeApply()
                            
                            var verticalOffset = textFrame.maxY + titleTypeSpacing + typeLayout.size.height + typeOptionsSpacing
                            var updatedOptionNodes: [ChatMessageTodoItemNode] = []
                            for i in 0 ..< optionNodesSizesAndApply.count {
                                let (size, apply) = optionNodesSizesAndApply[i]
                                var isRequesting = false
                                if let todo, i < todo.items.count {
                                    isRequesting = false
                                }
                                let optionNode = apply(animation.isAnimated, isRequesting, synchronousLoad)
                                let optionNodeFrame = CGRect(origin: CGPoint(x: layoutConstants.bubble.borderInset, y: verticalOffset), size: size)
                                if optionNode.supernode !== strongSelf {
                                    strongSelf.addSubnode(optionNode)
                                    let todoItem = optionNode.option
                                    optionNode.selectionUpdated = {
                                        guard let strongSelf = self, let item = strongSelf.item, let todoItem else {
                                            return
                                        }
                                        item.controllerInteraction.requestToggleTodoMessageItem(item.message.id, todoItem.id, optionNode.radioNode?.isChecked == true)
                                    }
                                    optionNode.pressed = {
                                        guard let strongSelf = self, let item = strongSelf.item else {
                                            return
                                        }
                                        item.controllerInteraction.displayTodoToggleUnavailable(item.message.id)
                                    }
                                    optionNode.longTapped = { [weak optionNode] in
                                        guard let strongSelf = self, let item = strongSelf.item, let todoItem, let optionNode else {
                                            return
                                        }
                                        item.controllerInteraction.todoItemLongTap(todoItem.id, ChatControllerInteraction.LongTapParams(message: item.message, contentNode: optionNode.contextSourceNode, messageNode: strongSelf, progress: nil))
                                    }
                                    optionNode.frame = optionNodeFrame
                                } else {
                                    animation.animator.updateFrame(layer: optionNode.layer, frame: optionNodeFrame, completion: nil)
                                }
                                                                
                                verticalOffset += size.height
                                updatedOptionNodes.append(optionNode)
                                
                                if i > 0 {
                                    optionNode.previousOptionNode = updatedOptionNodes[i - 1]
                                }
                            }
                            for optionNode in strongSelf.optionNodes {
                                if !updatedOptionNodes.contains(where: { $0 === optionNode }) {
                                    optionNode.removeFromSupernode()
                                }
                            }
                            strongSelf.optionNodes = updatedOptionNodes
                            
                            if textLayout.hasRTL {
                                strongSelf.textNode.textNode.frame = CGRect(origin: CGPoint(x: resultSize.width - textFrame.size.width - textInsets.left - layoutConstants.text.bubbleInsets.right - additionalTextRightInset, y: textFrame.origin.y), size: textFrame.size)
                            } else {
                                strongSelf.textNode.textNode.frame = textFrame
                            }
                            let typeFrame = CGRect(origin: CGPoint(x: textFrame.minX, y: textFrame.maxY + titleTypeSpacing), size: typeLayout.size)
                            animation.animator.updateFrame(layer: strongSelf.typeNode.layer, frame: typeFrame, completion: nil)
                                                                                                                                                   
                            if let statusSizeAndApply = statusSizeAndApply {
                                let statusFrame = CGRect(origin: CGPoint(x: resultSize.width - statusSizeAndApply.0.width - layoutConstants.text.bubbleInsets.right, y: verticalOffset + statusSpacing), size: statusSizeAndApply.0)
                                
                                if strongSelf.statusNode.supernode == nil {
                                    statusSizeAndApply.1(.None)
                                    strongSelf.statusNode.frame = statusFrame
                                    strongSelf.addSubnode(strongSelf.statusNode)
                                } else {
                                    statusSizeAndApply.1(animation)
                                    animation.animator.updateFrame(layer: strongSelf.statusNode.layer, frame: statusFrame, completion: nil)
                                }
                            } else if strongSelf.statusNode.supernode != nil {
                                strongSelf.statusNode.removeFromSupernode()
                            }
                            
                            let _ = buttonViewResultsTextApply()
                            strongSelf.buttonViewResultsTextNode.frame = buttonViewResultsTextFrame.offsetBy(dx: 0.0, dy: verticalOffset)
                            
                            strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: resultSize.width, height: 44.0))
                                                        
                            strongSelf.updateIsTranslating(isTranslating)
                        }
                    })
                })
            })
        }
    }
    
    private func updateIsTranslating(_ isTranslating: Bool) {
        guard let item = self.item else {
            return
        }
        var rects: [[CGRect]] = []
        let titleRects = (self.textNode.textNode.rangeRects(in: NSRange(location: 0, length: self.textNode.textNode.cachedLayout?.attributedString?.length ?? 0))?.rects ?? []).map { self.textNode.textNode.view.convert($0, to: self.view) }
        rects.append(titleRects)
        
        for optionNode in self.optionNodes {
            if let titleNode = optionNode.titleNode {
                let optionRects = (titleNode.textNode.rangeRects(in: NSRange(location: 0, length: titleNode.textNode.cachedLayout?.attributedString?.length ?? 0))?.rects ?? []).map { titleNode.textNode.view.convert($0, to: self.view) }
                rects.append(optionRects)
            }
        }
        
        if isTranslating, !rects.isEmpty {
            if self.shimmeringNodes.isEmpty {
                for rects in rects {
                    let shimmeringNode = ShimmeringLinkNode(color: item.message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.secondaryTextColor.withAlphaComponent(0.1) : item.presentationData.theme.theme.chat.message.outgoing.secondaryTextColor.withAlphaComponent(0.1))
                    shimmeringNode.updateRects(rects)
                    shimmeringNode.frame = self.bounds
                    shimmeringNode.updateLayout(self.bounds.size)
                    shimmeringNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.shimmeringNodes.append(shimmeringNode)
                    self.insertSubnode(shimmeringNode, belowSubnode: self.textNode.textNode)
                }
            }
        } else if !self.shimmeringNodes.isEmpty {
            let shimmeringNodes = self.shimmeringNodes
            self.shimmeringNodes = []
            
            for shimmeringNode in shimmeringNodes {
                shimmeringNode.alpha = 0.0
                shimmeringNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak shimmeringNode] _ in
                    shimmeringNode?.removeFromSupernode()
                })
            }
        }
    }
        
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.textNode.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.textNode.textNode.frame
        if let (index, attributes) = self.textNode.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.textNode.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: concealed)))
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: false))
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return ChatMessageBubbleContentTapAction(content: .textMention(peerName))
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return ChatMessageBubbleContentTapAction(content: .botCommand(botCommand))
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return ChatMessageBubbleContentTapAction(content: .hashtag(hashtag.peerName, hashtag.hashtag))
            } else {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
        } else {
            for optionNode in self.optionNodes {
                if optionNode.frame.contains(point) {
                    let optionAction = optionNode.tapActionAtPoint(self.view.convert(point, to: optionNode.view), gesture: gesture, isEstimating: isEstimating)
                    if case .none = optionAction.content {
                        if optionNode.isUserInteractionEnabled, case .tap = gesture {
                            return ChatMessageBubbleContentTapAction(content: .ignore)
                        }
                    } else {
                        var rects: [CGRect]?
                        if let optionRects = optionNode.linkRectsAtPoint(self.view.convert(point, to: optionNode.view)), let rect = optionRects.first {
                            rects = [rect.offsetBy(dx: optionNode.frame.minX - 11.0, dy: optionNode.frame.minY - 5.0)]
                        }
                        return ChatMessageBubbleContentTapAction(content: optionAction.content, rects: rects)
                    }
                }
            }
            if self.buttonNode.isUserInteractionEnabled, !self.buttonNode.isHidden, self.buttonNode.frame.contains(point) {
                return ChatMessageBubbleContentTapAction(content: .ignore)
            }
            return ChatMessageBubbleContentTapAction(content: .none)
        }
    }
    
    public override func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let item = self.item else {
            return
        }
        var rects: [CGRect]?
        if let point = point {
            let textNodeFrame = self.textNode.textNode.frame
            if let (index, attributes) = self.textNode.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                let possibleNames: [String] = [
                    TelegramTextAttributes.URL,
                    TelegramTextAttributes.PeerMention,
                    TelegramTextAttributes.PeerTextMention,
                    TelegramTextAttributes.BotCommand,
                    TelegramTextAttributes.Hashtag,
                    TelegramTextAttributes.BankCard
                ]
                for name in possibleNames {
                    if let _ = attributes[NSAttributedString.Key(rawValue: name)], let textRects = self.textNode.textNode.attributeRects(name: name, at: index) {
                        rects = textRects.map { $0.offsetBy(dx: textNodeFrame.minX, dy: textNodeFrame.minY) }
                        break
                    }
                }
            }
            
            for optionNode in self.optionNodes {
                if optionNode.frame.contains(point), let optionRects = optionNode.linkRectsAtPoint(CGPoint(x: point.x - optionNode.frame.minX, y: point.y - optionNode.frame.minY)) {
                    rects = optionRects.map { $0.offsetBy(dx: optionNode.frame.minX - 11.0, dy: optionNode.frame.minY - 4.0) }
                }
            }
        }
        
        if let rects {
            let linkHighlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                linkHighlightingNode = current
            } else {
                linkHighlightingNode = LinkHighlightingNode(color: item.message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.linkHighlightColor : item.presentationData.theme.theme.chat.message.outgoing.linkHighlightColor)
                self.linkHighlightingNode = linkHighlightingNode
                self.insertSubnode(linkHighlightingNode, belowSubnode: self.textNode.textNode)
            }
            linkHighlightingNode.frame = self.textNode.textNode.frame
            linkHighlightingNode.updateRects(rects)
        } else if let linkHighlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                linkHighlightingNode?.removeFromSupernode()
            })
        }
    }
        
    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if !self.statusNode.isHidden {
            return self.statusNode.reactionView(value: value)
        }
        return nil
    }
    
    override public func messageEffectTargetView() -> UIView? {
        if !self.statusNode.isHidden {
            return self.statusNode.messageEffectTargetView()
        }
        return nil
    }
    
    public func getTaskRect(id: Int32?) -> CGRect? {
        var rectsSet: [CGRect] = []
        for node in self.optionNodes {
            if node.option?.id == id {
                rectsSet.append(node.frame.insetBy(dx: 3.0 - UIScreenPixel, dy: 2.0 - UIScreenPixel))
            }
        }
        if !rectsSet.isEmpty {
            var currentRect = CGRect()
            for rect in rectsSet {
                if currentRect.isEmpty {
                    currentRect = rect
                } else {
                    currentRect = currentRect.union(rect)
                }
            }
            
            return currentRect.offsetBy(dx: self.textNode.textNode.frame.minX, dy: self.textNode.textNode.frame.minY)
        }
        return nil
    }
    
    private var taskHighlightingNode: LinkHighlightingNode?
    public func updateTaskHighlightState(id: Int32?, color: UIColor, animated: Bool) {
        var rectsSet: [CGRect] = []
        for node in self.optionNodes {
            if node.option?.id == id {
                rectsSet.append(node.frame.insetBy(dx: 3.0 - UIScreenPixel, dy: 2.0 - UIScreenPixel))
            }
        }
        if !rectsSet.isEmpty {
            let rects = rectsSet
            let taskHighlightingNode: LinkHighlightingNode
            if let current = self.taskHighlightingNode {
                taskHighlightingNode = current
            } else {
                taskHighlightingNode = LinkHighlightingNode(color: color)
                taskHighlightingNode.innerRadius = 0.0
                taskHighlightingNode.outerRadius = 0.0
                self.taskHighlightingNode = taskHighlightingNode
                self.insertSubnode(taskHighlightingNode, belowSubnode: self.buttonNode)
            }
            taskHighlightingNode.frame = self.bounds
            taskHighlightingNode.updateRects(rects)
        } else {
            if let taskHighlightingNode = self.taskHighlightingNode {
                self.taskHighlightingNode = nil
                if animated {
                    taskHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak taskHighlightingNode] _ in
                        taskHighlightingNode?.removeFromSupernode()
                    })
                } else {
                    taskHighlightingNode.removeFromSupernode()
                }
            }
        }
    }
    
    public func animateTaskItemHighlightIn(id: Int32, sourceFrame: CGRect, transition: ContainedViewLayoutTransition) -> CGRect? {
        if let taskHighlightingNode = self.taskHighlightingNode {
            var currentRect = CGRect()
            for rect in taskHighlightingNode.rects {
                if currentRect.isEmpty {
                    currentRect = rect
                } else {
                    currentRect = currentRect.union(rect)
                }
            }
            if !currentRect.isEmpty {
                currentRect = currentRect.insetBy(dx: -taskHighlightingNode.inset, dy: -taskHighlightingNode.inset)
                let innerRect = currentRect.offsetBy(dx: taskHighlightingNode.frame.minX, dy: taskHighlightingNode.frame.minY)
                
                taskHighlightingNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, delay: 0.04)
                
                let fromScale = CGPoint(x: sourceFrame.width / innerRect.width, y: sourceFrame.height / innerRect.height)
                
                var fromTransform = CATransform3DIdentity
                let fromOffset = CGPoint(x: sourceFrame.midX - innerRect.midX, y: sourceFrame.midY - innerRect.midY)
                
                fromTransform = CATransform3DTranslate(fromTransform, fromOffset.x, fromOffset.y, 0.0)
                
                fromTransform = CATransform3DTranslate(fromTransform, -taskHighlightingNode.bounds.width * 0.5 + currentRect.midX, -taskHighlightingNode.bounds.height * 0.5 + currentRect.midY, 0.0)
                fromTransform = CATransform3DScale(fromTransform, fromScale.x, fromScale.y, 1.0)
                fromTransform = CATransform3DTranslate(fromTransform, taskHighlightingNode.bounds.width * 0.5 - currentRect.midX, taskHighlightingNode.bounds.height * 0.5 - currentRect.midY, 0.0)
                
                taskHighlightingNode.transform = fromTransform
                transition.updateTransform(node: taskHighlightingNode, transform: CGAffineTransformIdentity)
                
                return currentRect.offsetBy(dx: taskHighlightingNode.frame.minX, dy: taskHighlightingNode.frame.minY)
            }
        }
        return nil
    }
}
