import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import SyncCore
import TelegramPresentationData
import ItemListUI
import SolidRoundedButtonNode
import RadialStatusNode

private let itemSpacing: CGFloat = 10.0
private let titleFont = Font.semibold(17.0)
private let subtitleFont = Font.regular(12.0)

private func generateBackgroundImage(colors: NSArray) -> UIImage? {
    return generateImage(CGSize(width: 45, height: 45), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: 15)
        context.addPath(path.cgPath)
        context.clip()
        
        var locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: bounds.size.height), options: CGGradientDrawingOptions())
    })?.stretchableImage(withLeftCapWidth: 22, topCapHeight: 22)
}

func invitationAvailability(_ invite: ExportedInvitation) -> CGFloat {
    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
    var availability: CGFloat = 1.0
    if let expireDate = invite.expireDate {
        let startDate = invite.startDate ?? invite.date
        let fraction = CGFloat(expireDate - currentTime) / CGFloat(expireDate - startDate)
        availability = min(fraction, availability)
    }
    if let usageLimit = invite.usageLimit, let count = invite.count {
        let fraction = 1.0 - (CGFloat(count) / CGFloat(usageLimit))
        availability = min(fraction, availability)
    }
    return max(0.0, min(1.0, availability))
}

private enum ItemBackgroundColor: Equatable {
    case blue
    case green
    case yellow
    case red
    case gray
    
    var colors: (top: UIColor, bottom: UIColor, text: UIColor) {
        switch self {
            case .blue:
                return (UIColor(rgb: 0x00b5f7), UIColor(rgb: 0x00b2f6), UIColor(rgb: 0xa7f4ff))
            case .green:
                return (UIColor(rgb: 0x4aca62), UIColor(rgb: 0x43c85c), UIColor(rgb: 0xc5ffe6))
            case .yellow:
                return (UIColor(rgb: 0xf8a953), UIColor(rgb: 0xf7a64e), UIColor(rgb: 0xfeffd7))
            case .red:
                return (UIColor(rgb: 0xf2656a), UIColor(rgb: 0xf25f65), UIColor(rgb: 0xffd3de))
            case .gray:
                return (UIColor(rgb: 0xa8b2bb), UIColor(rgb: 0xa2abb4), UIColor(rgb: 0xe3e6e8))
        }
    }
}

private let moreIcon = generateImage(CGSize(width: 26.0, height: 26.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    
    context.setFillColor(UIColor.white.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    
    context.setBlendMode(.clear)
    context.fillEllipse(in: CGRect(origin: CGPoint(x: 4.0, y: 11.0), size: CGSize(width: 4.0, height: 4.0)))
    context.fillEllipse(in: CGRect(origin: CGPoint(x: 11.0, y: 11.0), size: CGSize(width: 4.0, height: 4.0)))
    context.fillEllipse(in: CGRect(origin: CGPoint(x: 18.0, y: 11.0), size: CGSize(width: 4.0, height: 4.0)))
})

private let shareIcon = generateImage(CGSize(width: 26.0, height: 26.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    
    context.setFillColor(UIColor.white.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    
    if let maskImage = UIImage(bundleImageName: "Chat/Links/Share") {
        context.clip(to: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - maskImage.size.width) / 2.0), y: floorToScreenPixels((size.height - maskImage.size.height) / 2.0)), size: maskImage.size), mask: maskImage.cgImage!)
        context.setBlendMode(.clear)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    }
})

private class ItemNode: ASDisplayNode {
    private let selectionNode: HighlightTrackingButtonNode
    private let wrapperNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let backgroundGradientLayer: CAGradientLayer
    
    private let iconNode: ASImageNode
    private var timerNode: TimerNode?
    
    private let extractedContainerNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonIconNode: ASImageNode
    
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    
    private var updateTimer: SwiftSignalKit.Timer?
    
    private var params: (size: CGSize, wide: Bool, invite: ExportedInvitation, color: ItemBackgroundColor, presentationData: ItemListPresentationData)?
    
    var action: (() -> Void)?
    var contextAction: ((ASDisplayNode) -> Void)?
    
    private let hapticFeedback = HapticFeedback()
    
    override init() {
        self.selectionNode = HighlightTrackingButtonNode()
        self.wrapperNode = ASDisplayNode()
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.clipsToBounds = true
        self.backgroundNode.cornerRadius = 15.0
        if #available(iOS 13.0, *) {
            self.backgroundNode.layer.cornerCurve = .continuous
        }
        self.backgroundNode.isUserInteractionEnabled = false
        
        self.backgroundGradientLayer = CAGradientLayer()
        self.backgroundGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        self.backgroundGradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        self.backgroundNode.layer.addSublayer(self.backgroundGradientLayer)
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.extractedContainerNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.isGestureEnabled = false
        self.buttonIconNode = ASImageNode()
        self.buttonIconNode.displaysAsynchronously = false
        self.buttonIconNode.displayWithoutProcessing = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 2
        self.titleNode.isUserInteractionEnabled = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.isUserInteractionEnabled = false
        
        super.init()
    
        self.addSubnode(self.wrapperNode)
        self.wrapperNode.addSubnode(self.backgroundNode)
        self.wrapperNode.addSubnode(self.iconNode)
        
        self.containerNode.addSubnode(self.extractedContainerNode)
        self.extractedContainerNode.contentNode.addSubnode(self.buttonIconNode)
        self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
        self.buttonNode.addSubnode(self.containerNode)
        
        self.wrapperNode.addSubnode(self.selectionNode)
        self.wrapperNode.addSubnode(self.buttonNode)
        
        self.wrapperNode.addSubnode(self.titleNode)
        self.wrapperNode.addSubnode(self.subtitleNode)
        
        self.selectionNode.addTarget(self, action: #selector(self.tapped), forControlEvents: .touchUpInside)
        self.selectionNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.18, curve: .linear)
                    transition.updateSublayerTransformScale(node: strongSelf, scale: 0.95)
                } else {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .linear)
                    transition.updateSublayerTransformScale(node: strongSelf, scale: 1.0)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonIconNode.alpha = 0.4
                } else {
                    strongSelf.buttonIconNode.alpha = 1.0
                    strongSelf.buttonIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    deinit {
        self.updateTimer?.invalidate()
    }
    
    @objc private func tapped() {
        self.hapticFeedback.impact(.light)
        self.action?()
    }
    
    @objc private func buttonPressed() {
        self.contextAction?(self.extractedContainerNode)
    }
    
    func update(size: CGSize, wide: Bool, share: Bool, invite: ExportedInvitation, presentationData: ItemListPresentationData, transition: ContainedViewLayoutTransition) -> CGSize {
        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        
        let availability = invitationAvailability(invite)
        let transitionFraction: CGFloat
        let color: ItemBackgroundColor
        let nextColor: ItemBackgroundColor
        if invite.isRevoked {
            color = .gray
            nextColor = .gray
            transitionFraction = 0.0
        } else if invite.expireDate == nil && invite.usageLimit == nil {
            color = .blue
            nextColor = .blue
            transitionFraction = 0.0
        } else if availability >= 0.5 {
            color = .green
            nextColor = .yellow
            transitionFraction = (availability - 0.5) / 0.5
        } else if availability > 0.0 {
            color = .yellow
            nextColor = .red
            transitionFraction = availability / 0.5
        } else {
            color = .red
            nextColor = .red
            transitionFraction = 0.0
        }
        
        let previousParams = self.params
        self.params = (size, wide, invite, color, presentationData)
        
        let previousExpireDate = previousParams?.invite.expireDate
        if previousExpireDate != invite.expireDate {
            self.updateTimer?.invalidate()
            self.updateTimer = nil
            
            if let expireDate = invite.expireDate, availability > 0.0 {
                let timeout = min(2.0, max(0.001, Double(expireDate - currentTime)))
                let updateTimer = SwiftSignalKit.Timer(timeout: timeout, repeat: true, completion: { [weak self] in
                    if let strongSelf = self {
                        if let (size, wide, invite, _, presentationData) = strongSelf.params {
                            let _ = strongSelf.update(size: size, wide: wide, share: share, invite: invite, presentationData: presentationData, transition: .animated(duration: 0.3, curve: .linear))
                        }
                    }
                }, queue: Queue.mainQueue())
                self.updateTimer = updateTimer
                updateTimer.start()
            }
        } else if availability.isZero {
            self.updateTimer?.invalidate()
            self.updateTimer = nil
        }
    
        let topColor = color.colors.top
        let bottomColor = color.colors.bottom
        let nextTopColor = nextColor.colors.top
        let nextBottomColor = nextColor.colors.bottom
        let colors: NSArray = [nextTopColor.mixedWith(topColor, alpha: transitionFraction).cgColor, nextBottomColor.mixedWith(bottomColor, alpha: transitionFraction).cgColor]
                
        if let (_, _, previousInvite, previousColor, _) = previousParams, previousInvite == invite {
            if previousColor != color && color == .red {
                if let snapshotView = self.wrapperNode.view.snapshotContentTree() {
                    snapshotView.frame = self.wrapperNode.bounds
                    self.wrapperNode.view.addSubview(snapshotView)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
                self.backgroundGradientLayer.colors = colors as? [Any]
            } else if (color == .green && nextColor == .yellow) || (color == .yellow && nextColor == .red) {
                let previousColors = self.backgroundGradientLayer.colors
                if transition.isAnimated {
                    self.backgroundGradientLayer.animate(from: previousColors as AnyObject, to: self.backgroundGradientLayer.colors as AnyObject, keyPath: "colors", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 2.5)
                }
                self.backgroundGradientLayer.colors = colors as? [Any]
            }
        } else {
            self.backgroundGradientLayer.colors = colors as? [Any]
        }
                
        let secondaryTextColor = nextColor.colors.text.mixedWith(color.colors.text, alpha: transitionFraction)

        let itemWidth = wide ? size.width : floor((size.width - itemSpacing) / 2.0)
        var inviteLink = invite.link.replacingOccurrences(of: "https://", with: "")
        if !wide {
            inviteLink = inviteLink.replacingOccurrences(of: "joinchat/", with: "joinchat/\n")
            inviteLink = inviteLink.replacingOccurrences(of: "join/", with: "join/\n")
        }
        let title: NSMutableAttributedString = NSMutableAttributedString(string: inviteLink, font: titleFont, textColor: UIColor.white)
        if inviteLink.hasPrefix("t.me/joinchat/") {
            title.addAttribute(NSAttributedString.Key.foregroundColor, value: secondaryTextColor, range: NSMakeRange(0, "t.me/joinchat/".count))
        } else if inviteLink.hasPrefix("t.me/join/") {
            title.addAttribute(NSAttributedString.Key.foregroundColor, value: secondaryTextColor, range: NSMakeRange(0, "t.me/join/".count))
        }
        self.titleNode.attributedText = title
        
        self.buttonIconNode.image = share ? shareIcon : moreIcon
        
        var subtitleText: String = ""
        if let count = invite.count {
            subtitleText = presentationData.strings.InviteLink_PeopleJoinedShort(count)
        } else {
            subtitleText = [.red, .gray].contains(color) ? presentationData.strings.InviteLink_PeopleJoinedShortNoneExpired : presentationData.strings.InviteLink_PeopleJoinedShortNone
        }
        if invite.isRevoked {
            if !subtitleText.isEmpty {
                subtitleText += " • "
            }
            subtitleText += presentationData.strings.InviteLink_Revoked
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Links/Expired"), color: .white)
            self.timerNode?.removeFromSupernode()
            self.timerNode = nil
        } else if let expireDate = invite.expireDate, currentTime >= expireDate {
            if !subtitleText.isEmpty {
                subtitleText += " • "
            }
            if share {
                subtitleText = presentationData.strings.InviteLink_Expired
            } else {
                subtitleText += presentationData.strings.InviteLink_Expired
            }
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Links/Expired"), color: .white)
            self.timerNode?.removeFromSupernode()
            self.timerNode = nil
        } else if let usageLimit = invite.usageLimit, let count = invite.count, count >= usageLimit {
            if !subtitleText.isEmpty {
                subtitleText += " • "
            }
            if share {
                subtitleText = presentationData.strings.InviteLink_UsageLimitReached
            } else {
                subtitleText += presentationData.strings.InviteLink_UsageLimitReached
            }
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Links/Expired"), color: .white)
            self.timerNode?.removeFromSupernode()
            self.timerNode = nil
        } else if let expireDate = invite.expireDate {
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Links/Flame"), color: .white)
            let timerNode: TimerNode
            if let current = self.timerNode {
                timerNode = current
            } else {
                timerNode = TimerNode()
                timerNode.isUserInteractionEnabled = false
                self.timerNode = timerNode
                self.addSubnode(timerNode)
            }
            timerNode.update(color: UIColor.white, creationTimestamp: invite.startDate ?? invite.date, deadlineTimestamp: expireDate)
            if share {
                subtitleText = presentationData.strings.InviteLink_TapToCopy
            }
        } else {
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Links/Link"), color: .white)
            self.timerNode?.removeFromSupernode()
            self.timerNode = nil
            if share {
                subtitleText = presentationData.strings.InviteLink_TapToCopy
            }
        }
        
        self.iconNode.frame = CGRect(x: 10.0, y: 10.0, width: 30.0, height: 30.0)
        self.timerNode?.frame = CGRect(x: 8.0, y: 8.0, width: 34.0, height: 34.0)

        self.subtitleNode.attributedText = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: secondaryTextColor)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: itemWidth - 24.0, height: 100.0))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: itemWidth - 24.0, height: 100.0))
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 52.0), size: titleSize)
        self.subtitleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 52.0 + titleSize.height + 3.0), size: subtitleSize)
        
        let itemSize = CGSize(width: itemWidth, height: wide ? 102.0 : 122.0)
        
        let backgroundFrame = CGRect(origin: CGPoint(), size: itemSize)
        transition.updateFrame(node: self.wrapperNode, frame: backgroundFrame)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.selectionNode, frame: backgroundFrame)
        transition.updateFrame(layer: self.backgroundGradientLayer, frame: backgroundFrame)
        
        let buttonSize = CGSize(width: 26.0, height: 26.0)
        let buttonFrame = CGRect(origin: CGPoint(x: itemSize.width - buttonSize.width - 12.0, y: 12.0), size: buttonSize)
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        
        self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: buttonSize)
        self.extractedContainerNode.contentRect = CGRect(origin: CGPoint(), size: buttonSize)
        self.buttonIconNode.frame = CGRect(origin: CGPoint(), size: buttonSize)
        
        return itemSize
    }
}

class InviteLinksGridNode: ASDisplayNode {
    private var items: [ExportedInvitation] = []
    private var itemNodes: [String: ItemNode] = [:]
    
    var action: ((ExportedInvitation) -> Void)?
    var contextAction: ((ASDisplayNode, ExportedInvitation) -> Void)?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result
    }
    
    func update(size: CGSize, safeInset: CGFloat, items: [ExportedInvitation], share: Bool, presentationData: ItemListPresentationData, transition: ContainedViewLayoutTransition) -> CGSize {
        self.items = items
        
        var contentSize: CGSize = size
        var contentHeight: CGFloat = 0.0
        
        let sideInset: CGFloat = 16.0 + safeInset
        
        var validIds = Set<String>()
        
        for i in 0 ..< self.items.count {
            let invite = self.items[i]
            validIds.insert(invite.link)
            var itemNode: ItemNode?
            var wasAdded = false
            if let current = self.itemNodes[invite.link] {
                itemNode = current
            } else {
                wasAdded = true
                let addedItemNode = ItemNode()
                itemNode = addedItemNode
                self.itemNodes[invite.link] = addedItemNode
                self.addSubnode(addedItemNode)
            }
            if let itemNode = itemNode {
                let col = CGFloat(i % 2)
                let row = floor(CGFloat(i) / 2.0)
                let wide = (i == self.items.count - 1 && (self.items.count % 2) != 0)
                let itemSize = itemNode.update(size: CGSize(width: size.width - sideInset * 2.0, height: size.height), wide: wide, share: share, invite: invite, presentationData: presentationData, transition: transition)
                var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: 4.0 + row * (122.0 + itemSpacing)), size: itemSize)
                if !wide && col > 0 {
                    itemFrame.origin.x += itemSpacing + itemSize.width
                }
                
                contentHeight = max(contentHeight, itemFrame.maxY + itemSpacing)
                
                if wasAdded {
                    itemNode.frame = itemFrame
                } else {
                    transition.updateFrame(node: itemNode, frame: itemFrame)
                }
                itemNode.action = { [weak self] in
                    self?.action?(invite)
                }
                itemNode.contextAction = { [weak self] node in
                    self?.contextAction?(node, invite)
                }
            }
        }

        var removeIds: [String] = []
        for (id, _) in self.itemNodes {
            if !validIds.contains(id) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                itemNode.removeFromSupernode()
            }
        }
        
        contentSize.height = contentHeight
        return contentSize
    }
}

private struct ContentParticle {
    var position: CGPoint
    var direction: CGPoint
    var velocity: CGFloat
    var alpha: CGFloat
    var lifetime: Double
    var beginTime: Double
    
    init(position: CGPoint, direction: CGPoint, velocity: CGFloat, alpha: CGFloat, lifetime: Double, beginTime: Double) {
        self.position = position
        self.direction = direction
        self.velocity = velocity
        self.alpha = alpha
        self.lifetime = lifetime
        self.beginTime = beginTime
    }
}

private final class TimerNode: ASDisplayNode {
    private struct Params: Equatable {
        var color: UIColor
        var creationTimestamp: Int32
        var deadlineTimestamp: Int32
    }
    
    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var inHierarchyValue: Bool = false
    
    private var animator: ConstantDisplayLinkAnimator?
    private let contentNode: ASDisplayNode
    private var particles: [ContentParticle] = []
    
    private var currentParams: Params?
    
    var reachedTimeout: (() -> Void)?
    
    override init() {
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        self.contentNode = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
        
        updateInHierarchy = { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inHierarchyValue = value
            strongSelf.animator?.isPaused = value
        }
    }
    
    deinit {
        self.animator?.invalidate()
    }
    
    func update(color: UIColor, creationTimestamp: Int32, deadlineTimestamp: Int32) {
        let params = Params(
            color: color,
            creationTimestamp: creationTimestamp,
            deadlineTimestamp: deadlineTimestamp
        )
        self.currentParams = params
        
        self.updateValues()
    }
    
    private func updateValues() {
        guard let params = self.currentParams else {
            return
        }

        let color = params.color

        let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        var fraction = CGFloat(params.deadlineTimestamp - currentTimestamp) / CGFloat(params.deadlineTimestamp - params.creationTimestamp)
        fraction = max(0.0001, 1.0 - max(0.0, min(1.0, fraction)))
      
        let image: UIImage?
        
        let diameter: CGFloat = 26.0
        let inset: CGFloat = 8.0
        let lineWidth: CGFloat = 2.0

        let timestamp = CACurrentMediaTime()
        
        let center = CGPoint(x: (diameter + inset) / 2.0, y: (diameter + inset) / 2.0)
        let radius: CGFloat = (diameter - lineWidth / 2.0) / 2.0
        
        let startAngle: CGFloat = -CGFloat.pi / 2.0
        let endAngle: CGFloat = -CGFloat.pi / 2.0 + 2.0 * CGFloat.pi * fraction
        
        let sparks = fraction > 0.1 && fraction != 1.0
        if sparks {
            let v = CGPoint(x: sin(endAngle), y: -cos(endAngle))
            let c = CGPoint(x: -v.y * radius + center.x, y: v.x * radius + center.y)
            
            let dt: CGFloat = 1.0 / 60.0
            var removeIndices: [Int] = []
            for i in 0 ..< self.particles.count {
                let currentTime = timestamp - self.particles[i].beginTime
                if currentTime > self.particles[i].lifetime {
                    removeIndices.append(i)
                } else {
                    let input: CGFloat = CGFloat(currentTime / self.particles[i].lifetime)
                    let decelerated: CGFloat = (1.0 - (1.0 - input) * (1.0 - input))
                    self.particles[i].alpha = 1.0 - decelerated
                    
                    var p = self.particles[i].position
                    let d = self.particles[i].direction
                    let v = self.particles[i].velocity
                    p = CGPoint(x: p.x + d.x * v * dt, y: p.y + d.y * v * dt)
                    self.particles[i].position = p
                }
            }
            
            for i in removeIndices.reversed() {
                self.particles.remove(at: i)
            }
            
            let newParticleCount = 1
            for _ in 0 ..< newParticleCount {
                let degrees: CGFloat = CGFloat(arc4random_uniform(140)) - 40.0
                let angle: CGFloat = degrees * CGFloat.pi / 180.0
                
                let direction = CGPoint(x: v.x * cos(angle) - v.y * sin(angle), y: v.x * sin(angle) + v.y * cos(angle))
                let velocity = (20.0 + (CGFloat(arc4random()) / CGFloat(UINT32_MAX)) * 4.0) * 0.3
                
                let lifetime = Double(0.4 + CGFloat(arc4random_uniform(100)) * 0.01)
                
                let particle = ContentParticle(position: c, direction: direction, velocity: velocity, alpha: 1.0, lifetime: lifetime, beginTime: timestamp)
                self.particles.append(particle)
            }
        }
        
        image = generateImage(CGSize(width: diameter + inset, height: diameter + inset), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            
            let path = CGMutablePath()
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            context.addPath(path)
            context.strokePath()
            
            if sparks {
                for particle in self.particles {
                    let size: CGFloat = 2.0
                    context.setAlpha(particle.alpha)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: particle.position.x - size / 2.0, y: particle.position.y - size / 2.0), size: CGSize(width: size, height: size)))
                }
            }
        })
        
        self.contentNode.contents = image?.cgImage
        if let image = image {
            self.contentNode.frame = CGRect(origin: CGPoint(), size: image.size)
        }
             
        if fraction <= .ulpOfOne {
            self.animator?.invalidate()
            self.animator = nil
        } else {
            if self.animator == nil {
                let animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.updateValues()
                })
                self.animator = animator
                animator.isPaused = self.inHierarchyValue
            }
        }
    }
}
