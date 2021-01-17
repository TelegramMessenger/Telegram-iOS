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
    return availability
}

private class ItemNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    
    private let iconNode: ASImageNode
    private var timerNode: TimerNode?
    
    private let extractedContainerNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonIconNode: ASImageNode
    
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    
    private var params: (size: CGSize, wide: Bool, invite: ExportedInvitation, presentationData: ItemListPresentationData)?
    
    var action: (() -> Void)?
    var contextAction: ((ASDisplayNode) -> Void)?
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.extractedContainerNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.isGestureEnabled = false
        self.buttonIconNode = ASImageNode()
        self.buttonIconNode.displaysAsynchronously = false
        self.buttonIconNode.displayWithoutProcessing = true
        self.buttonIconNode.image = generateImage(CGSize(width: 26.0, height: 26.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            context.setBlendMode(.clear)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 4.0, y: 11.0), size: CGSize(width: 4.0, height: 4.0)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 11.0, y: 11.0), size: CGSize(width: 4.0, height: 4.0)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 18.0, y: 11.0), size: CGSize(width: 4.0, height: 4.0)))
        })
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 2
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.maximumNumberOfLines = 1
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
        
        self.containerNode.addSubnode(self.extractedContainerNode)
        self.extractedContainerNode.contentNode.addSubnode(self.buttonIconNode)
        self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
        self.buttonNode.addSubnode(self.containerNode)
        self.addSubnode(self.buttonNode)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        
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
    
    override func didLoad() {
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        self.action?()
    }
    
    @objc private func buttonPressed() {
        self.contextAction?(self.extractedContainerNode)
    }
    
    func update(size: CGSize, wide: Bool, invite: ExportedInvitation, presentationData: ItemListPresentationData, transition: ContainedViewLayoutTransition) -> CGSize {
        let updated = self.params?.size != size || self.params?.wide != wide || self.params?.invite != invite
        self.params = (size, wide, invite, presentationData)
        
        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        let availability = invitationAvailability(invite)

        var isExpired = false
        let secondaryTextColor: UIColor
        if invite.isRevoked {
            self.backgroundNode.image = generateBackgroundImage(colors: [UIColor(rgb: 0xd4d8db).cgColor, UIColor(rgb: 0xced2d5).cgColor])
            secondaryTextColor = UIColor(rgb: 0xf8f9f9)
        } else if invite.expireDate == nil && invite.usageLimit == nil {
            self.backgroundNode.image = generateBackgroundImage(colors: [UIColor(rgb: 0x00b5f7).cgColor, UIColor(rgb: 0x00b2f6).cgColor])
            secondaryTextColor = UIColor(rgb: 0xa7f4ff)
        } else if availability >= 0.5 {
            self.backgroundNode.image = generateBackgroundImage(colors: [UIColor(rgb: 0x4aca62).cgColor, UIColor(rgb: 0x43c85c).cgColor])
            secondaryTextColor = UIColor(rgb: 0xc5ffe6)
        } else if availability > 0.0 {
            self.backgroundNode.image = generateBackgroundImage(colors: [UIColor(rgb: 0xf8a953).cgColor, UIColor(rgb: 0xf7a64e).cgColor])
            secondaryTextColor = UIColor(rgb: 0xfeffd7)
        } else {
            self.backgroundNode.image = generateBackgroundImage(colors: [UIColor(rgb: 0xf2656a).cgColor, UIColor(rgb: 0xf25f65).cgColor])
            secondaryTextColor = UIColor(rgb: 0xffd3de)
            isExpired = true
        }
        
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
        
        var subtitleText: String = ""
        if let count = invite.count {
            subtitleText = presentationData.strings.InviteLink_PeopleJoinedShort(count)
        } else {
            subtitleText = isExpired || invite.isRevoked ? presentationData.strings.InviteLink_PeopleJoinedShortNoneExpired : presentationData.strings.InviteLink_PeopleJoinedShortNone
        }
        if invite.isRevoked {
            if !subtitleText.isEmpty {
                subtitleText += " • "
            }
            subtitleText += presentationData.strings.InviteLink_Revoked
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Links/Expired"), color: .white)
            self.timerNode?.removeFromSupernode()
            self.timerNode = nil
        } else if let expireDate = invite.expireDate, currentTime > expireDate {
            if !subtitleText.isEmpty {
                subtitleText += " • "
            }
            subtitleText += presentationData.strings.InviteLink_Expired
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
                self.timerNode = timerNode
                self.addSubnode(timerNode)
            }
            timerNode.update(color: UIColor.white, creationTimestamp: invite.date, deadlineTimestamp: expireDate)
        } else {
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Links/Link"), color: .white)
            self.timerNode?.removeFromSupernode()
            self.timerNode = nil
        }
        
        self.iconNode.frame = CGRect(x: 10.0, y: 10.0, width: 30.0, height: 30.0)
        self.timerNode?.frame = CGRect(x: 8.0, y: 8.0, width: 34.0, height: 34.0)

        let subtitle: NSMutableAttributedString = NSMutableAttributedString(string: subtitleText, font: subtitleFont, textColor: secondaryTextColor)
        self.subtitleNode.attributedText = subtitle
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: itemWidth - 24.0, height: 100.0))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: itemWidth - 24.0, height: 100.0))
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 52.0), size: titleSize)
        self.subtitleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 52.0 + titleSize.height + 3.0), size: subtitleSize)
        
        let itemSize = CGSize(width: itemWidth, height: wide ? 102.0 : 122.0)
        
        let backgroundFrame = CGRect(origin: CGPoint(), size: itemSize)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        
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
    
    func update(size: CGSize, safeInset: CGFloat, items: [ExportedInvitation], presentationData: ItemListPresentationData, transition: ContainedViewLayoutTransition) -> CGSize {
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
                let itemSize = itemNode.update(size: CGSize(width: size.width - sideInset * 2.0, height: size.height), wide: wide, invite: invite, presentationData: presentationData, transition: transition)
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
        fraction = 1.0 - max(0.0, min(0.94, fraction))
      
        let image: UIImage?
        
        let diameter: CGFloat = 26.0
        let inset: CGFloat = 8.0
        let lineWidth: CGFloat = 2.0

        let timestamp = CACurrentMediaTime()
        
        let center = CGPoint(x: (diameter + inset) / 2.0, y: (diameter + inset) / 2.0)
        let radius: CGFloat = (diameter - lineWidth / 2.0) / 2.0
        
        let startAngle: CGFloat = -CGFloat.pi / 2.0
        let endAngle: CGFloat = -CGFloat.pi / 2.0 + 2.0 * CGFloat.pi * fraction
        
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
            
            for particle in self.particles {
                let size: CGFloat = 2.0
                context.setAlpha(particle.alpha)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: particle.position.x - size / 2.0, y: particle.position.y - size / 2.0), size: CGSize(width: size, height: size)))
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
