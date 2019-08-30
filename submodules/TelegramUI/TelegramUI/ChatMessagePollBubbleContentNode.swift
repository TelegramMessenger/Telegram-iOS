import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TextFormat
import UrlEscaping

struct PercentCounterItem: Comparable  {
    var index: Int = 0
    var percent: Int = 0
    var remainder: Int = 0
    
    static func <(lhs: PercentCounterItem, rhs: PercentCounterItem) -> Bool {
        if lhs.remainder > rhs.remainder {
            return true
        } else if lhs.remainder < rhs.remainder {
            return false
        }
        return lhs.percent < rhs.percent
    }
    
}

func adjustPercentCount(_ items: [PercentCounterItem], left: Int) -> [PercentCounterItem] {
    var left = left
    var items = items.sorted(by: <)
    var i:Int = 0
    while i != items.count {
        let item = items[i]
        var j = i + 1
        loop: while j != items.count {
            if items[j].percent != item.percent || items[j].remainder != item.remainder {
                break loop
            }
            j += 1
        }
        if items[i].remainder == 0 {
            break
        }
        let equal = j - i
        if equal <= left {
            left -= equal
            while i != j {
                items[i].percent += 1
                i += 1
            }
        } else {
            i = j
        }
    }
    return items
}

func countNicePercent(votes: [Int], total: Int) -> [Int] {
    var result:[Int] = []
    var items:[PercentCounterItem] = []
    for _ in votes {
        result.append(0)
        items.append(PercentCounterItem())
    }
    
    let count = votes.count
    
    var left:Int = 100
    for i in 0 ..< votes.count {
        let votes = votes[i]
        items[i].index = i
        items[i].percent = Int((Float(votes) * 100) / Float(total))
        items[i].remainder = (votes * 100) - (items[i].percent * total)
        left -= items[i].percent
    }
    
    if left > 0 && left <= count {
        items = adjustPercentCount(items, left: left)
    }
    for item in items {
        result[item.index] = item.percent
    }
    
    return result
}

private final class ChatMessagePollOptionRadioNodeParameters: NSObject {
    let staticColor: UIColor
    let animatedColor: UIColor
    let offset: Double?
    
    init(staticColor: UIColor, animatedColor: UIColor, offset: Double?) {
        self.staticColor = staticColor
        self.animatedColor = animatedColor
        self.offset = offset
        
        super.init()
    }
}

private final class ChatMessagePollOptionRadioNode: ASDisplayNode {
    private(set) var staticColor: UIColor?
    private(set) var animatedColor: UIColor?
    private var isInHierarchyValue: Bool = false
    private(set) var isAnimating: Bool = false
    private var startTime: Double?
    
    private var displayLink: CADisplayLink?
    
    private var shouldBeAnimating: Bool {
        return self.isInHierarchyValue && self.isAnimating
    }
    
    override init() {
        super.init()
        
        self.isLayerBacked = true
        self.isOpaque = false
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
    
    func update(staticColor: UIColor, animatedColor: UIColor, isAnimating: Bool) {
        var updated = false
        if !staticColor.isEqual(self.staticColor) {
            self.staticColor = staticColor
            updated = true
        }
        if !animatedColor.isEqual(self.animatedColor) {
            self.animatedColor = animatedColor
            updated = true
        }
        if isAnimating != self.isAnimating {
            let previous = self.shouldBeAnimating
            self.isAnimating = isAnimating
            let updated = self.shouldBeAnimating
            if previous != updated {
                self.updateAnimating()
            }
        }
        if updated {
            self.setNeedsDisplay()
        }
    }
    
    private func updateAnimating() {
        if self.shouldBeAnimating {
            self.startTime = CACurrentMediaTime()
            if self.displayLink == nil {
                class DisplayLinkProxy: NSObject {
                    var f: () -> Void
                    init(_ f: @escaping () -> Void) {
                        self.f = f
                    }
                    
                    @objc func displayLinkEvent() {
                        self.f()
                    }
                }
                let displayLink = CADisplayLink(target: DisplayLinkProxy({ [weak self] in
                    self?.setNeedsDisplay()
                }), selector: #selector(DisplayLinkProxy.displayLinkEvent))
                displayLink.add(to: .main, forMode: .common)
                self.displayLink = displayLink
            }
            self.setNeedsDisplay()
        } else if let displayLink = self.displayLink {
            self.startTime = nil
            displayLink.invalidate()
            self.displayLink = nil
            self.setNeedsDisplay()
        }
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        if let staticColor = self.staticColor, let animatedColor = self.animatedColor {
            var offset: Double?
            if let startTime = self.startTime {
                offset = CACurrentMediaTime() - startTime
            }
            return ChatMessagePollOptionRadioNodeParameters(staticColor: staticColor, animatedColor: animatedColor, offset: offset)
        } else {
            return nil
        }
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        if isCancelled() {
            return
        }
        
        guard let parameters = parameters as? ChatMessagePollOptionRadioNodeParameters else {
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
            context.setStrokeColor(parameters.staticColor.cgColor)
            context.strokeEllipse(in: CGRect(origin: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: bounds.width - 1.0, height: bounds.height - 1.0)))
        }
    }
}

private let percentageFont = Font.bold(14.5)

private func generatePercentageImage(presentationData: ChatPresentationData, incoming: Bool, value: Int) -> UIImage {
    return generateImage(CGSize(width: 42.0, height: 20.0), rotatedContext: { size, context in
        UIGraphicsPushContext(context)
        context.clear(CGRect(origin: CGPoint(), size: size))
        let string = NSAttributedString(string: "\(value)%", font: percentageFont, textColor: incoming ? presentationData.theme.theme.chat.message.incoming.primaryTextColor : presentationData.theme.theme.chat.message.outgoing.primaryTextColor, paragraphAlignment: .right)
        string.draw(in: CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: size))
        UIGraphicsPopContext()
    })!
}

private func generatePercentageAnimationImages(presentationData: ChatPresentationData, incoming: Bool, from fromValue: Int, to toValue: Int, duration: Double) -> [UIImage] {
    let minimumFrameDuration = 1.0 / 40.0
    let numberOfFrames = max(1, Int(duration / minimumFrameDuration))
    var images: [UIImage] = []
    for i in 0 ..< numberOfFrames {
        let t = CGFloat(i) / CGFloat(numberOfFrames)
        images.append(generatePercentageImage(presentationData: presentationData, incoming: incoming, value: Int((1.0 - t) * CGFloat(fromValue) + t * CGFloat(toValue))))
    }
    return images
}

private struct ChatMessagePollOptionResult: Equatable {
    let normalized: CGFloat
    let percent: Int
    let count: Int32
}

private final class ChatMessagePollOptionNode: ASDisplayNode {
    private let highlightedBackgroundNode: ASImageNode
    private var radioNode: ChatMessagePollOptionRadioNode?
    private let percentageNode: ASDisplayNode
    private var percentageImage: UIImage?
    private var titleNode: TextNode?
    private let buttonNode: HighlightTrackingButtonNode
    private let separatorNode: ASDisplayNode
    private let resultBarNode: ASImageNode
    
    var option: TelegramMediaPollOption?
    public private(set) var currentResult: ChatMessagePollOptionResult?
    var pressed: (() -> Void)?
    
    override init() {
        self.highlightedBackgroundNode = ASImageNode()
        self.highlightedBackgroundNode.displayWithoutProcessing = true
        self.highlightedBackgroundNode.displaysAsynchronously = false
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        self.highlightedBackgroundNode.isUserInteractionEnabled = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.resultBarNode = ASImageNode()
        self.resultBarNode.isLayerBacked = true
        self.resultBarNode.alpha = 0.0
        
        self.percentageNode = ASDisplayNode()
        self.percentageNode.alpha = 0.0
        self.percentageNode.isLayerBacked = true
        //self.percentageNode.displaysAsynchronously = false
        //self.percentageNode.displayWithoutProcessing = true
        
        super.init()
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.resultBarNode)
        self.addSubnode(self.percentageNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }
    }
    
    @objc private func buttonPressed() {
        self.pressed?()
    }
    
    static func asyncLayout(_ maybeNode: ChatMessagePollOptionNode?) -> (_ accountPeerId: PeerId, _ presentationData: ChatPresentationData, _ message: Message, _ option: TelegramMediaPollOption, _ optionResult: ChatMessagePollOptionResult?, _ constrainedWidth: CGFloat) -> (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, (Bool, Bool) -> ChatMessagePollOptionNode))) {
        let makeTitleLayout = TextNode.asyncLayout(maybeNode?.titleNode)
        let currentResult = maybeNode?.currentResult
        
        return { accountPeerId, presentationData, message, option, optionResult, constrainedWidth in
            let leftInset: CGFloat = 50.0
            let rightInset: CGFloat = 12.0
            
            let incoming = message.effectivelyIncoming(accountPeerId)
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: option.text, font: presentationData.messageFont, textColor: incoming ? presentationData.theme.theme.chat.message.incoming.primaryTextColor : presentationData.theme.theme.chat.message.outgoing.primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: max(1.0, constrainedWidth - leftInset - rightInset), height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets(top: 1.0, left: 0.0, bottom: 1.0, right: 0.0)))
            
            let contentHeight: CGFloat = max(46.0, titleLayout.size.height + 22.0)
            
            let shouldHaveRadioNode = optionResult == nil
            
            var updatedPercentageImage: UIImage?
            if currentResult != optionResult {
                updatedPercentageImage = generatePercentageImage(presentationData: presentationData, incoming: incoming, value: optionResult?.percent ?? 0)
            }
            
            return (titleLayout.size.width + leftInset + rightInset, { width in
                return (CGSize(width: width, height: contentHeight), { animated, inProgress in
                    let node: ChatMessagePollOptionNode
                    if let maybeNode = maybeNode {
                        node = maybeNode
                    } else {
                        node = ChatMessagePollOptionNode()
                    }
                    
                    node.option = option
                    let previousResult = node.currentResult
                    node.currentResult = optionResult
                    
                    node.highlightedBackgroundNode.backgroundColor = (incoming ? presentationData.theme.theme.chat.message.incoming.accentTextColor : presentationData.theme.theme.chat.message.outgoing.accentTextColor).withAlphaComponent(0.15)
                    
                    node.buttonNode.accessibilityLabel = option.text
                    
                    let titleNode = titleApply()
                    if node.titleNode !== titleNode {
                        node.titleNode = titleNode
                        node.addSubnode(titleNode)
                        titleNode.isUserInteractionEnabled = false
                    }
                    if titleLayout.hasRTL {
                        titleNode.frame = CGRect(origin: CGPoint(x: width - rightInset - titleLayout.size.width, y: 11.0), size: titleLayout.size)
                    } else {
                        titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleLayout.size)
                    }
                    
                    if shouldHaveRadioNode {
                        let radioNode: ChatMessagePollOptionRadioNode
                        if let current = node.radioNode {
                            radioNode = current
                        } else {
                            radioNode = ChatMessagePollOptionRadioNode()
                            node.addSubnode(radioNode)
                            node.radioNode = radioNode
                            if animated {
                                radioNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        }
                        let radioSize: CGFloat = 22.0
                        radioNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: CGSize(width: radioSize, height: radioSize))
                        radioNode.update(staticColor: incoming ? presentationData.theme.theme.chat.message.incoming.polls.radioButton : presentationData.theme.theme.chat.message.outgoing.polls.radioButton, animatedColor: incoming ? presentationData.theme.theme.chat.message.incoming.polls.radioProgress : presentationData.theme.theme.chat.message.outgoing.polls.radioProgress, isAnimating: inProgress)
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
                    
                    if let updatedPercentageImage = updatedPercentageImage {
                        node.percentageNode.contents = updatedPercentageImage.cgImage
                        node.percentageImage = updatedPercentageImage
                    }
                    if let image = node.percentageImage {
                        node.percentageNode.frame = CGRect(origin: CGPoint(x: leftInset - 7.0 - image.size.width, y: 12.0), size: image.size)
                        if animated && previousResult?.percent != optionResult?.percent {
                            let percentageDuration = 0.27
                            let images = generatePercentageAnimationImages(presentationData: presentationData, incoming: incoming, from: previousResult?.percent ?? 0, to: optionResult?.percent ?? 0, duration: percentageDuration)
                            if !images.isEmpty {
                                let animation = CAKeyframeAnimation(keyPath: "contents")
                                animation.values = images.map { $0.cgImage! }
                                animation.duration = percentageDuration * UIView.animationDurationFactor()
                                animation.calculationMode = .discrete
                                node.percentageNode.layer.add(animation, forKey: "image")
                            }
                        }
                    }
                    
                    node.buttonNode.frame = CGRect(origin: CGPoint(x: 1.0, y: 0.0), size: CGSize(width: width - 2.0, height: contentHeight))
                    node.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: contentHeight + UIScreenPixel))
                    
                    node.separatorNode.backgroundColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.separator : presentationData.theme.theme.chat.message.outgoing.polls.separator
                    node.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentHeight - UIScreenPixel), size: CGSize(width: width - leftInset, height: UIScreenPixel))
                    
                    if node.resultBarNode.image == nil {
                        node.resultBarNode.image = generateStretchableFilledCircleImage(diameter: 6.0, color: incoming ? presentationData.theme.theme.chat.message.incoming.polls.bar : presentationData.theme.theme.chat.message.outgoing.polls.bar)
                    }
                    
                    let minBarWidth: CGFloat = 6.0
                    let resultBarWidth = minBarWidth + floor((width - leftInset - rightInset - minBarWidth) * (optionResult?.normalized ?? 0.0))
                    node.resultBarNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentHeight - 6.0 - 1.0), size: CGSize(width: resultBarWidth, height: 6.0))
                    node.resultBarNode.alpha = optionResult != nil ? 1.0 : 0.0
                    node.percentageNode.alpha = optionResult != nil ? 1.0 : 0.0
                    node.separatorNode.alpha = optionResult == nil ? 1.0 : 0.0
                    if animated, currentResult != optionResult {
                        if (currentResult != nil) != (optionResult != nil) {
                            if optionResult != nil {
                                node.resultBarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                                node.percentageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                node.separatorNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08)
                            } else {
                                node.resultBarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.4)
                                node.percentageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                                node.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        }
                        
                        node.buttonNode.isAccessibilityElement = shouldHaveRadioNode
                        
                        let previousResultBarWidth = minBarWidth + floor((width - leftInset - rightInset - minBarWidth) * (currentResult?.normalized ?? 0.0))
                        let previousFrame = CGRect(origin: CGPoint(x: leftInset, y: contentHeight - 6.0 - 1.0), size: CGSize(width: previousResultBarWidth, height: 6.0))
                        
                        node.resultBarNode.layer.animateSpring(from: NSValue(cgPoint: previousFrame.center), to: NSValue(cgPoint: node.resultBarNode.frame.center), keyPath: "position", duration: 0.6, damping: 110.0)
                        node.resultBarNode.layer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: previousFrame.size)), to: NSValue(cgRect: CGRect(origin: CGPoint(), size: node.resultBarNode.frame.size)), keyPath: "bounds", duration: 0.6, damping: 110.0)
                    }
                    
                    return node
                })
            })
        }
    }
}

private let labelsFont = Font.regular(14.0)

class ChatMessagePollBubbleContentNode: ChatMessageBubbleContentNode {
    private let textNode: TextNode
    private let typeNode: TextNode
    private let votersNode: TextNode
    private let statusNode: ChatMessageDateAndStatusNode
    private var optionNodes: [ChatMessagePollOptionNode] = []
    
    required init() {
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .topLeft
        self.textNode.contentsScale = UIScreenScale
        self.textNode.displaysAsynchronously = true
        
        self.typeNode = TextNode()
        self.typeNode.isUserInteractionEnabled = false
        self.typeNode.contentMode = .topLeft
        self.typeNode.contentsScale = UIScreenScale
        self.typeNode.displaysAsynchronously = true
        
        self.votersNode = TextNode()
        self.votersNode.isUserInteractionEnabled = false
        self.votersNode.contentMode = .topLeft
        self.votersNode.contentsScale = UIScreenScale
        self.votersNode.displaysAsynchronously = true
        
        self.statusNode = ChatMessageDateAndStatusNode()
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.typeNode)
        self.addSubnode(self.votersNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeTypeLayout = TextNode.asyncLayout(self.typeNode)
        let makeVotersLayout = TextNode.asyncLayout(self.votersNode)
        let statusLayout = self.statusNode.asyncLayout()
        
        var previousPoll: TelegramMediaPoll?
        if let item = self.item {
            for media in item.message.media {
                if let media = media as? TelegramMediaPoll {
                    previousPoll = media
                }
            }
        }
        
        var previousOptionNodeLayouts: [Data: (_ accountPeerId: PeerId, _ presentationData: ChatPresentationData, _ message: Message, _ option: TelegramMediaPollOption, _ optionResult: ChatMessagePollOptionResult?, _ constrainedWidth: CGFloat) -> (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, (Bool, Bool) -> ChatMessagePollOptionNode)))] = [:]
        for optionNode in self.optionNodes {
            if let option = optionNode.option {
                previousOptionNodeLayouts[option.opaqueIdentifier] = ChatMessagePollOptionNode.asyncLayout(optionNode)
            }
        }
        
        return { item, layoutConstants, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: constrainedSize.width - horizontalInset, height: constrainedSize.height)
                
                var edited = false
                var viewCount: Int?
                for attribute in item.message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    }
                }
                
                var dateReactions: [MessageReaction] = []
                var dateReactionCount = 0
                if let reactionsAttribute = mergedMessageReactions(attributes: item.message.attributes), !reactionsAttribute.reactions.isEmpty {
                    for reaction in reactionsAttribute.reactions {
                        if reaction.isSelected {
                            dateReactions.insert(reaction, at: 0)
                        } else {
                            dateReactions.append(reaction)
                        }
                        dateReactionCount += Int(reaction.count)
                    }
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, reactionCount: dateReactionCount)
                
                let statusType: ChatMessageDateAndStatusType?
                switch position {
                    case .linear(_, .None):
                        if incoming {
                            statusType = .BubbleIncoming
                        } else {
                            if message.flags.contains(.Failed) {
                                statusType = .BubbleOutgoing(.Failed)
                            } else if message.flags.isSending && !message.isSentOrAcknowledged {
                                statusType = .BubbleOutgoing(.Sending)
                            } else {
                                statusType = .BubbleOutgoing(.Sent(read: item.read))
                            }
                        }
                    default:
                        statusType = nil
                }
                
                var statusSize: CGSize?
                var statusApply: ((Bool) -> Void)?
                
                if let statusType = statusType {
                    let (size, apply) = statusLayout(item.context, item.presentationData, edited, viewCount, dateText, statusType, textConstrainedSize, dateReactions)
                    statusSize = size
                    statusApply = apply
                }
                
                var poll: TelegramMediaPoll?
                for media in item.message.media {
                    if let media = media as? TelegramMediaPoll {
                        poll = media
                        break
                    }
                }

                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                let attributedText = NSAttributedString(string: poll?.text ?? "", font: item.presentationData.messageBoldFont, textColor: messageTheme.primaryTextColor)
                
                let textInsets = UIEdgeInsets(top: 2.0, left: 0.0, bottom: 5.0, right: 0.0)
                
                let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets))
                let typeText: String
                if let poll = poll, poll.isClosed {
                    typeText = item.presentationData.strings.MessagePoll_LabelClosed
                } else {
                    typeText = item.presentationData.strings.MessagePoll_LabelAnonymous
                }
                let (typeLayout, typeApply) = makeTypeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: typeText, font: labelsFont, textColor: messageTheme.secondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let votersString: String
                if let totalVoters = poll?.results.totalVoters {
                    if totalVoters == 0 {
                        votersString = item.presentationData.strings.MessagePoll_NoVotes
                    } else {
                        votersString = item.presentationData.strings.MessagePoll_VotedCount(totalVoters)
                    }
                } else {
                    votersString = " "
                }
                let (votersLayout, votersApply) = makeVotersLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: votersString, font: labelsFont, textColor: messageTheme.secondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets))
                
                var textFrame = CGRect(origin: CGPoint(x: -textInsets.left, y: -textInsets.top), size: textLayout.size)
                var textFrameWithoutInsets = CGRect(origin: CGPoint(x: textFrame.origin.x + textInsets.left, y: textFrame.origin.y + textInsets.top), size: CGSize(width: textFrame.width - textInsets.left - textInsets.right, height: textFrame.height - textInsets.top - textInsets.bottom))
                
                var statusFrame: CGRect?
                if let statusSize = statusSize {
                    statusFrame = CGRect(origin: CGPoint(x: textFrameWithoutInsets.maxX - statusSize.width, y: textFrameWithoutInsets.maxY - statusSize.height), size: statusSize)
                }
                
                textFrame = textFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                textFrameWithoutInsets = textFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                statusFrame = statusFrame?.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                
                var boundingSize: CGSize = textFrameWithoutInsets.size
                boundingSize.width = max(boundingSize.width, typeLayout.size.width)
                boundingSize.width = max(boundingSize.width, votersLayout.size.width + 4.0 + (statusSize?.width ?? 0.0))
                
                boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                
                var pollOptionsFinalizeLayouts: [(CGFloat) -> (CGSize, (Bool, Bool) -> ChatMessagePollOptionNode)] = []
                if let poll = poll {
                    var optionVoterCount: [Int: Int32] = [:]
                    var maxOptionVoterCount: Int32 = 0
                    var totalVoterCount: Int32 = 0
                    let voters: [TelegramMediaPollOptionVoters]?
                    if poll.isClosed {
                        voters = poll.results.voters ?? []
                    } else {
                        voters = poll.results.voters
                    }
                    if let voters = voters, let totalVoters = poll.results.totalVoters {
                        var didVote = false
                        for voter in voters {
                            if voter.selected {
                                didVote = true
                            }
                        }
                        totalVoterCount = totalVoters
                        if didVote || poll.isClosed {
                            for i in 0 ..< poll.options.count {
                                inner: for optionVoters in voters {
                                    if optionVoters.opaqueIdentifier == poll.options[i].opaqueIdentifier {
                                        optionVoterCount[i] = optionVoters.count
                                        maxOptionVoterCount = max(maxOptionVoterCount, optionVoters.count)
                                        break inner
                                    }
                                }
                            }
                        }
                    }
                    
                    var optionVoterCounts: [Int]
                    if totalVoterCount != 0 {
                        optionVoterCounts = countNicePercent(votes: (0 ..< poll.options.count).map({ Int(optionVoterCount[$0] ?? 0) }), total: Int(totalVoterCount))
                    } else {
                        optionVoterCounts = Array(repeating: 0, count: poll.options.count)
                    }
                    
                    for i in 0 ..< poll.options.count {
                        let option = poll.options[i]
                        
                        let makeLayout: (_ accountPeerId: PeerId, _ presentationData: ChatPresentationData, _ message: Message, _ option: TelegramMediaPollOption, _ optionResult: ChatMessagePollOptionResult?, _ constrainedWidth: CGFloat) -> (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, (Bool, Bool) -> ChatMessagePollOptionNode)))
                        if let previous = previousOptionNodeLayouts[option.opaqueIdentifier] {
                            makeLayout = previous
                        } else {
                            makeLayout = ChatMessagePollOptionNode.asyncLayout(nil)
                        }
                        var optionResult: ChatMessagePollOptionResult?
                        if let count = optionVoterCount[i] {
                            if maxOptionVoterCount != 0 && totalVoterCount != 0 {
                                optionResult = ChatMessagePollOptionResult(normalized: CGFloat(count) / CGFloat(maxOptionVoterCount), percent: optionVoterCounts[i], count: count)
                            } else if poll.isClosed {
                                optionResult = ChatMessagePollOptionResult(normalized: 0, percent: 0, count: 0)
                            }
                        } else if poll.isClosed {
                            optionResult = ChatMessagePollOptionResult(normalized: 0, percent: 0, count: 0)
                        }
                        let result = makeLayout(item.context.account.peerId, item.presentationData, item.message, option, optionResult, constrainedSize.width - layoutConstants.bubble.borderInset * 2.0)
                        boundingSize.width = max(boundingSize.width, result.minimumWidth + layoutConstants.bubble.borderInset * 2.0)
                        pollOptionsFinalizeLayouts.append(result.1)
                    }
                }
                
                boundingSize.width = max(boundingSize.width, min(270.0, constrainedSize.width))
                
                var canVote = false
                if item.message.id.namespace == Namespaces.Message.Cloud, let poll = poll, poll.pollId.namespace == Namespaces.Media.CloudPoll, !poll.isClosed {
                    var hasVoted = false
                    if let voters = poll.results.voters {
                        for voter in voters {
                            if voter.selected {
                                hasVoted = true
                                break
                            }
                        }
                    }
                    if !hasVoted {
                        canVote = true
                    }
                }
                if Namespaces.Message.allScheduled.contains(item.message.id.namespace) {
                    canVote = true
                }
                
                return (boundingSize.width, { boundingWidth in
                    var resultSize = CGSize(width: max(boundingSize.width, boundingWidth), height: boundingSize.height)
                    
                    let titleTypeSpacing: CGFloat = -4.0
                    let typeOptionsSpacing: CGFloat = 3.0
                    resultSize.height += titleTypeSpacing + typeLayout.size.height + typeOptionsSpacing
                    
                    var optionNodesSizesAndApply: [(CGSize, (Bool, Bool) -> ChatMessagePollOptionNode)] = []
                    for finalizeLayout in pollOptionsFinalizeLayouts {
                        let result = finalizeLayout(boundingWidth -  layoutConstants.bubble.borderInset * 2.0)
                        resultSize.width = max(resultSize.width, result.0.width + layoutConstants.bubble.borderInset * 2.0)
                        resultSize.height += result.0.height
                        optionNodesSizesAndApply.append(result)
                    }
                    
                    let optionsVotersSpacing: CGFloat = 11.0
                    let votersBottomSpacing: CGFloat = 8.0
                    resultSize.height += optionsVotersSpacing + votersLayout.size.height + votersBottomSpacing
                    
                    var adjustedStatusFrame: CGRect?
                    if let statusFrame = statusFrame {
                        adjustedStatusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusFrame.size.width - layoutConstants.text.bubbleInsets.right, y: resultSize.height - statusFrame.size.height - 6.0), size: statusFrame.size)
                    }
                    
                    return (resultSize, { [weak self] animation, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            let cachedLayout = strongSelf.textNode.cachedLayout
                            
                            if case .System = animation {
                                if let cachedLayout = cachedLayout {
                                    if cachedLayout != textLayout {
                                        if let textContents = strongSelf.textNode.contents {
                                            let fadeNode = ASDisplayNode()
                                            fadeNode.displaysAsynchronously = false
                                            fadeNode.contents = textContents
                                            fadeNode.frame = strongSelf.textNode.frame
                                            fadeNode.isLayerBacked = true
                                            strongSelf.addSubnode(fadeNode)
                                            fadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak fadeNode] _ in
                                                fadeNode?.removeFromSupernode()
                                            })
                                            strongSelf.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                        }
                                    }
                                }
                            }
                            
                            let _ = textApply()
                            let _ = typeApply()
                            
                            var verticalOffset = textFrame.maxY + titleTypeSpacing + typeLayout.size.height + typeOptionsSpacing
                            var updatedOptionNodes: [ChatMessagePollOptionNode] = []
                            for i in 0 ..< optionNodesSizesAndApply.count {
                                let (size, apply) = optionNodesSizesAndApply[i]
                                var isRequesting = false
                                if let poll = poll, i < poll.options.count {
                                    isRequesting = item.controllerInteraction.pollActionState.pollMessageIdsInProgress[item.message.id] == poll.options[i].opaqueIdentifier
                                }
                                let optionNode = apply(animation.isAnimated, isRequesting)
                                if optionNode.supernode !== strongSelf {
                                    strongSelf.addSubnode(optionNode)
                                    let option = optionNode.option
                                    optionNode.pressed = {
                                        guard let strongSelf = self, let item = strongSelf.item, let option = option else {
                                            return
                                        }
                                        
                                        item.controllerInteraction.requestSelectMessagePollOption(item.message.id, option.opaqueIdentifier)
                                    }
                                }
                                optionNode.frame = CGRect(origin: CGPoint(x: layoutConstants.bubble.borderInset, y: verticalOffset), size: size)
                                verticalOffset += size.height
                                updatedOptionNodes.append(optionNode)
                                optionNode.isUserInteractionEnabled = canVote && item.controllerInteraction.pollActionState.pollMessageIdsInProgress[item.message.id] == nil
                            }
                            for optionNode in strongSelf.optionNodes {
                                if !updatedOptionNodes.contains(where: { $0 === optionNode }) {
                                    optionNode.removeFromSupernode()
                                }
                            }
                            strongSelf.optionNodes = updatedOptionNodes
                            
                            if let statusApply = statusApply, let adjustedStatusFrame = adjustedStatusFrame {
                                let previousStatusFrame = strongSelf.statusNode.frame
                                strongSelf.statusNode.frame = adjustedStatusFrame
                                var hasAnimation = true
                                if case .None = animation {
                                    hasAnimation = false
                                }
                                statusApply(hasAnimation)
                                if strongSelf.statusNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.statusNode)
                                } else {
                                    if case let .System(duration) = animation {
                                        let delta = CGPoint(x: previousStatusFrame.maxX - adjustedStatusFrame.maxX, y: previousStatusFrame.minY - adjustedStatusFrame.minY)
                                        let statusPosition = strongSelf.statusNode.layer.position
                                        let previousPosition = CGPoint(x: statusPosition.x + delta.x, y: statusPosition.y + delta.y)
                                        strongSelf.statusNode.layer.animatePosition(from: previousPosition, to: statusPosition, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                                    }
                                }
                            } else if strongSelf.statusNode.supernode != nil {
                                strongSelf.statusNode.removeFromSupernode()
                            }
                            
                            if textLayout.hasRTL {
                                strongSelf.textNode.frame = CGRect(origin: CGPoint(x: resultSize.width - textFrame.size.width - textInsets.left - layoutConstants.text.bubbleInsets.right, y: textFrame.origin.y), size: textFrame.size)
                            } else {
                                strongSelf.textNode.frame = textFrame
                            }
                            strongSelf.typeNode.frame = CGRect(origin: CGPoint(x: textFrame.minX, y: textFrame.maxY + titleTypeSpacing), size: typeLayout.size)
                            
                            let _ = votersApply()
                            strongSelf.votersNode.frame = CGRect(origin: CGPoint(x: textFrame.minX, y: verticalOffset + optionsVotersSpacing), size: votersLayout.size)
                            if animation.isAnimated, let previousPoll = previousPoll, let poll = poll {
                                if previousPoll.results.totalVoters == nil && poll.results.totalVoters != nil {
                                    strongSelf.votersNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                                }
                            }
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.textNode.frame
        if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return .url(url: url, concealed: concealed)
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return .peerMention(peerMention.peerId, peerMention.mention)
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .textMention(peerName)
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return .botCommand(botCommand)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            } else {
                return .none
            }
        } else {
            for optionNode in self.optionNodes {
                if optionNode.frame.contains(point) {
                    if optionNode.isUserInteractionEnabled {
                        return .ignore
                    } else if let result = optionNode.currentResult, let item = self.item {
                        let string: String
                        if result.count == 0 {
                            string = item.presentationData.strings.MessagePoll_NoVotes
                        } else {
                            string = item.presentationData.strings.MessagePoll_VotedCount(result.count)
                        }
                        return .tooltip(string, optionNode, optionNode.bounds.offsetBy(dx: 0.0, dy: 10.0))
                    }
                }
            }
            return .none
        }
    }
    
    override func reactionTargetNode(value: String) -> (ASImageNode, Int)? {
        if !self.statusNode.isHidden {
            return self.statusNode.reactionNode(value: value)
        }
        return nil
    }
}
