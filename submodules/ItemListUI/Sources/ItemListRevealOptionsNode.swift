import Foundation
import LottieSettings
import UIKit
import AsyncDisplayKit
import Display
import ManagedAnimationNode

public enum ItemListRevealOptionIcon: Equatable {
    case none
    case image(image: UIImage)
    case animation(animation: String, scale: CGFloat, offset: CGFloat, replaceColors: [UInt32]?, flip: Bool, startFrame: Int = 0)

    public static func ==(lhs: ItemListRevealOptionIcon, rhs: ItemListRevealOptionIcon) -> Bool {
        switch lhs {
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        case let .image(lhsImage):
            if case let .image(rhsImage) = rhs, lhsImage == rhsImage {
                return true
            } else {
                return false
            }
        case let .animation(lhsAnimation, lhsScale, lhsOffset, lhsKeysToColor, lhsFlip, lhsStartFrame):
            if case let .animation(rhsAnimation, rhsScale, rhsOffset, rhsKeysToColor, rhsFlip, rhsStartFrame) = rhs, lhsAnimation == rhsAnimation, lhsScale == rhsScale, lhsOffset == rhsOffset, lhsKeysToColor == rhsKeysToColor, lhsFlip == rhsFlip, lhsStartFrame == rhsStartFrame {
                return true
            } else {
                return false
            }
        }
    }
}

public struct ItemListRevealOption: Equatable {
    public let key: Int32
    public let title: String
    public let icon: ItemListRevealOptionIcon
    public let color: UIColor
    public let iconColor: UIColor
    public let textColor: UIColor

    public init(key: Int32, title: String, icon: ItemListRevealOptionIcon, color: UIColor, iconColor: UIColor, textColor: UIColor) {
        self.key = key
        self.title = title
        self.icon = icon
        self.color = color
        self.iconColor = iconColor
        self.textColor = textColor
    }

    public static func ==(lhs: ItemListRevealOption, rhs: ItemListRevealOption) -> Bool {
        if lhs.key != rhs.key {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if !lhs.iconColor.isEqual(rhs.iconColor) {
            return false
        }
        if !lhs.textColor.isEqual(rhs.textColor) {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        return true
    }
}

private let titleFont = Font.regular(11.0)
private let iconlessTitleFont = Font.regular(13.0)

private let spacing: CGFloat = 10.0
private let edgeInset: CGFloat = 10.0
private let titleSpacing: CGFloat = 4.0
private let expandedActivationWidthFactor: CGFloat = 3.0
private let expandedTransitionDistance: CGFloat = 16.0
private let iconlessTitleExpandedHorizontalPadding: CGFloat = 8.0
private let iconlessTitleHorizontalPadding: CGFloat = 8.0
private let iconAnimationResponse: CGFloat = 18.0
private let iconAnimationSnapDistance: CGFloat = 0.5
private let animationTriggerProgress: CGFloat = 0.3
private let interactiveAnimationResetProgress: CGFloat = 0.1

public struct ItemListRevealOptionsAnimationSettings: Equatable {
    public var revealStartOverlap: CGFloat
    public var revealEndDistance: CGFloat
    public var revealProgressResponse: CGFloat
    public var minimumContentScale: CGFloat
    public var visualRevealSpring: CGFloat
    public var visualRevealDamping: CGFloat
    public var visualRevealSnapDistance: CGFloat
    public var visualRevealSnapVelocity: CGFloat

    public static let defaultSettings = ItemListRevealOptionsAnimationSettings(
        revealStartOverlap: 10.0,
        revealEndDistance: 10.0,
        revealProgressResponse: 2.7,
        minimumContentScale: 0.3,
        visualRevealSpring: 420.0,
        visualRevealDamping: 40.0,
        visualRevealSnapDistance: 0.25,
        visualRevealSnapVelocity: 12.0
    )

    public init(
        revealStartOverlap: CGFloat,
        revealEndDistance: CGFloat,
        revealProgressResponse: CGFloat,
        minimumContentScale: CGFloat,
        visualRevealSpring: CGFloat,
        visualRevealDamping: CGFloat,
        visualRevealSnapDistance: CGFloat,
        visualRevealSnapVelocity: CGFloat
    ) {
        self.revealStartOverlap = revealStartOverlap
        self.revealEndDistance = revealEndDistance
        self.revealProgressResponse = revealProgressResponse
        self.minimumContentScale = minimumContentScale
        self.visualRevealSpring = visualRevealSpring
        self.visualRevealDamping = visualRevealDamping
        self.visualRevealSnapDistance = visualRevealSnapDistance
        self.visualRevealSnapVelocity = visualRevealSnapVelocity
    }
}

public enum ItemListRevealOptionsAnimationSettingsStore {
    private static var settings: ItemListRevealOptionsAnimationSettings = .defaultSettings

    public static var current: ItemListRevealOptionsAnimationSettings {
        get {
            assert(Thread.isMainThread)
            return self.settings
        }
        set {
            assert(Thread.isMainThread)
            self.settings = newValue
        }
    }

    public static func resetToDefaults() {
        self.current = .defaultSettings
    }
}

private extension ItemListRevealOptionIcon {
    var hasVisualIcon: Bool {
        switch self {
        case .none:
            return false
        case .image, .animation:
            return true
        }
    }
}

private struct ItemListRevealOptionLayoutMetrics {
    let shapeSize: CGSize
    let slotWidth: CGFloat
    let titleWidth: CGFloat
    let iconMaxSide: CGFloat
    let cornerRadius: CGFloat
    let expandedIconInset: CGFloat

    var contentHeight: CGFloat {
        return self.shapeSize.height + titleSpacing + ceil(titleFont.lineHeight)
    }

    var slotShapeInset: CGFloat {
        return floorToScreenPixels((self.slotWidth - self.shapeSize.width) / 2.0)
    }

    static func metrics(for height: CGFloat, hasVisualIcons: Bool) -> ItemListRevealOptionLayoutMetrics {
        let regularShapeSize = CGSize(width: 50.0, height: 50.0)
        let compactShapeSize = CGSize(width: 60.0, height: 32.0)
        let regularContentHeight = regularShapeSize.height + titleSpacing + ceil(titleFont.lineHeight)
        if height < regularContentHeight || !hasVisualIcons {
            return ItemListRevealOptionLayoutMetrics(shapeSize: compactShapeSize, slotWidth: 70.0, titleWidth: 70.0, iconMaxSide: 24.0, cornerRadius: 16.0, expandedIconInset: 16.0)
        } else {
            return ItemListRevealOptionLayoutMetrics(shapeSize: regularShapeSize, slotWidth: 60.0, titleWidth: 60.0, iconMaxSide: 40.0, cornerRadius: 25.0, expandedIconInset: 20.0)
        }
    }

    func withGroupTitleWidth(_ maxTitleWidth: CGFloat) -> ItemListRevealOptionLayoutMetrics {
        if maxTitleWidth <= self.shapeSize.width - iconlessTitleExpandedHorizontalPadding {
            return self
        }

        let updatedShapeWidth = ceil(maxTitleWidth + iconlessTitleExpandedHorizontalPadding)
        let slotWidthDelta = self.slotWidth - self.shapeSize.width
        return ItemListRevealOptionLayoutMetrics(
            shapeSize: CGSize(width: updatedShapeWidth, height: self.shapeSize.height),
            slotWidth: updatedShapeWidth + slotWidthDelta,
            titleWidth: max(self.titleWidth, updatedShapeWidth - iconlessTitleExpandedHorizontalPadding),
            iconMaxSide: self.iconMaxSide,
            cornerRadius: self.cornerRadius,
            expandedIconInset: self.expandedIconInset
        )
    }

    func revealWidth(count: Int) -> CGFloat {
        if count == 0 {
            return 0.0
        }
        return edgeInset * 2.0 + self.shapeSize.width * CGFloat(count) + spacing * CGFloat(count - 1)
    }
}

private func clampToUnitInterval(_ value: CGFloat) -> CGFloat {
    return max(0.0, min(1.0, value))
}

private func frameCenter(_ frame: CGRect) -> CGPoint {
    return CGPoint(x: frame.midX, y: frame.midY)
}

private func revealProgressCurve(_ value: CGFloat, response: CGFloat) -> CGFloat {
    let value = clampToUnitInterval(value)
    return 1.0 - pow(1.0 - value, max(0.01, response))
}

private final class ItemListRevealOptionNode: ASDisplayNode {
    private let contentContainerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let highlightNode: ASDisplayNode
    private let titleNode: ImmediateTextNode
    private let iconNode: ASImageNode?
    private let animationNode: SimpleAnimationNode?

    private let enableAnimations: Bool
    private let displaysTitleInsidePill: Bool

    private var animationScale: CGFloat = 1.0
    private var animationNodeOffset: CGFloat = 0.0
    private var animationNodeFlip = false
    private var isAnimationTriggered = false

    private var contentAnimationLink: SharedDisplayLinkDriver.Link?
    private weak var manuallyAnimatedContentNode: ASDisplayNode?
    private var currentContentCenter: CGPoint?
    private var targetContentCenter: CGPoint?

    private var didApplyLayout = false
    var isExpanded: Bool = false

    var hasAppliedLayout: Bool {
        return self.didApplyLayout
    }

    var titleWidthForGroupPillSizing: CGFloat {
        var titleWidth = self.titleNode.updateLayout(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width
        if self.displaysTitleInsidePill {
            titleWidth += iconlessTitleHorizontalPadding
        }
        return titleWidth
    }

    init(title: String, icon: ItemListRevealOptionIcon, color: UIColor, iconColor: UIColor, textColor: UIColor, enableAnimations: Bool) {
        self.contentContainerNode = ASDisplayNode()
        self.backgroundNode = ASDisplayNode()
        self.highlightNode = ASDisplayNode()

        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.textAlignment = .center

        let displaysTitleInsidePill: Bool
        if case .none = icon {
            displaysTitleInsidePill = true
        } else {
            displaysTitleInsidePill = false
        }
        self.displaysTitleInsidePill = displaysTitleInsidePill
        self.titleNode.attributedText = NSAttributedString(string: title, font: displaysTitleInsidePill ? iconlessTitleFont : titleFont, textColor: displaysTitleInsidePill ? iconColor : textColor)

        self.enableAnimations = enableAnimations

        switch icon {
        case let .image(image):
            let iconNode = ASImageNode()
            iconNode.image = generateTintedImage(image: image, color: iconColor)
            self.iconNode = iconNode
            self.animationNode = nil

        case let .animation(animation, scale, offset, replaceColors, flip, startFrame):
            self.animationScale = scale
            self.iconNode = nil
            var colors: [UInt32: UInt32] = [:]
            if let replaceColors = replaceColors {
                for colorToReplace in replaceColors {
                    colors[colorToReplace] = color.rgb
                }
            }
            self.animationNode = SimpleAnimationNode(animationName: animation, replaceColors: colors, size: CGSize(width: 66.0, height: 66.0), playOnce: true, startFrame: startFrame, lottieSettings: .noAccountFallback)
            if !enableAnimations {
                self.animationNode!.seekToEnd(immediately: true)
            }
            if flip {
                self.animationNode!.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
            }
            self.animationNodeOffset = offset
            self.animationNodeFlip = flip
            break

        case .none:
            self.iconNode = nil
            self.animationNode = nil
        }

        super.init()

        self.contentContainerNode.layer.allowsGroupOpacity = true
        self.addSubnode(self.contentContainerNode)
        self.contentContainerNode.addSubnode(self.backgroundNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        if let iconNode = self.iconNode {
            self.contentContainerNode.addSubnode(iconNode)
        } else if let animationNode = self.animationNode {
            self.contentContainerNode.addSubnode(animationNode)
        }
        self.backgroundNode.backgroundColor = color
        self.highlightNode.backgroundColor = color.withMultipliedBrightnessBy(0.9)
    }

    deinit {
        self.stopManualContentAnimation()
    }

    func setHighlighted(_ highlighted: Bool) {
        if highlighted {
            self.contentContainerNode.insertSubnode(self.highlightNode, aboveSubnode: self.backgroundNode)
            self.highlightNode.layer.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.3)
            self.highlightNode.alpha = 1.0
        } else {
            self.highlightNode.removeFromSupernode()
            self.highlightNode.alpha = 0.0
        }
    }

    func resetAnimation() {
        self.setAnimationTriggered(false)
        self.stopManualContentAnimation()
    }

    private func setAnimationTriggered(_ isTriggered: Bool) {
        guard self.enableAnimations, self.isAnimationTriggered != isTriggered else {
            return
        }
        self.isAnimationTriggered = isTriggered
        if isTriggered {
            self.animationNode?.play(immediately: true)
        } else {
            self.animationNode?.reset(immediately: true)
        }
    }

    private func currentContentPresentationCenter(contentNode: ASDisplayNode) -> CGPoint {
        return contentNode.layer.presentation()?.position ?? contentNode.position
    }

    private func isManualContentAnimationAtTarget(center: CGPoint) -> Bool {
        guard let targetContentCenter = self.targetContentCenter else {
            return true
        }
        let centerDeltaX = targetContentCenter.x - center.x
        let centerDeltaY = targetContentCenter.y - center.y
        let centerDistance = sqrt(centerDeltaX * centerDeltaX + centerDeltaY * centerDeltaY)
        return centerDistance <= iconAnimationSnapDistance
    }

    private func stopManualContentAnimation() {
        self.contentAnimationLink?.isPaused = true
        self.contentAnimationLink?.invalidate()
        self.contentAnimationLink = nil
        self.manuallyAnimatedContentNode = nil
        self.currentContentCenter = nil
        self.targetContentCenter = nil
    }

    private func updateManualContentCenter(contentNode: ASDisplayNode, targetCenter: CGPoint, forceImmediate: Bool) {
        contentNode.layer.removeAnimation(forKey: "position")

        if self.manuallyAnimatedContentNode !== contentNode || self.currentContentCenter == nil {
            self.currentContentCenter = self.currentContentPresentationCenter(contentNode: contentNode)
            self.manuallyAnimatedContentNode = contentNode
        }

        self.targetContentCenter = targetCenter

        if forceImmediate {
            contentNode.position = targetCenter
            self.stopManualContentAnimation()
            return
        }

        if let currentContentCenter = self.currentContentCenter, self.isManualContentAnimationAtTarget(center: currentContentCenter) {
            contentNode.position = targetCenter
            self.stopManualContentAnimation()
            return
        }

        if self.contentAnimationLink == nil {
            self.contentAnimationLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
                self?.tickManualContentAnimation(deltaTime: deltaTime)
            })
            self.contentAnimationLink?.isPaused = false
        }
    }

    private func tickManualContentAnimation(deltaTime: CGFloat) {
        guard let contentNode = self.manuallyAnimatedContentNode, let currentContentCenter = self.currentContentCenter, let targetContentCenter = self.targetContentCenter else {
            self.stopManualContentAnimation()
            return
        }

        let clampedDeltaTime = min(0.05, max(0.0, deltaTime))
        let progress = 1.0 - exp(-clampedDeltaTime * iconAnimationResponse)
        let updatedCenter = CGPoint(
            x: currentContentCenter.x + (targetContentCenter.x - currentContentCenter.x) * progress,
            y: currentContentCenter.y + (targetContentCenter.y - currentContentCenter.y) * progress
        )

        if self.isManualContentAnimationAtTarget(center: updatedCenter) {
            contentNode.position = targetContentCenter
            self.stopManualContentAnimation()
        } else {
            self.currentContentCenter = updatedCenter
            contentNode.position = updatedCenter
        }
    }

    func updateLayout(
        isLeft: Bool,
        isPrimary: Bool,
        metrics: ItemListRevealOptionLayoutMetrics,
        revealProgress: CGFloat,
        animationRevealProgress: CGFloat,
        overswipeProgress: CGFloat,
        expandedProgress: CGFloat,
        isStretched: Bool,
        isExpanded: Bool,
        transition: ContainedViewLayoutTransition
    ) {
        let didApplyLayout = self.didApplyLayout
        let bounds = CGRect(origin: CGPoint(), size: self.bounds.size)
        transition.updateFrame(node: self.contentContainerNode, frame: bounds)

        let titleSize: CGSize
        if self.titleNode.frame.isEmpty {
            titleSize = self.titleNode.updateLayout(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        } else {
            titleSize = self.titleNode.cachedLayout?.size ?? CGSize()
        }

        let pillSize = metrics.shapeSize
        let shapeY: CGFloat
        if self.displaysTitleInsidePill {
            shapeY = floorToScreenPixels((bounds.height - pillSize.height) / 2.0)
        } else {
            let contentHeight = pillSize.height + titleSpacing + titleSize.height
            shapeY = floorToScreenPixels((bounds.height - contentHeight) / 2.0)
        }

        let shapeFrameX: CGFloat
        if isStretched {
            shapeFrameX = isLeft ? 0.0 : bounds.width - pillSize.width
        } else {
            shapeFrameX = floorToScreenPixels((metrics.slotWidth - pillSize.width) / 2.0)
        }
        let shapeFrame = CGRect(origin: CGPoint(x: shapeFrameX, y: shapeY), size: pillSize)
        let backgroundFrame: CGRect
        if isStretched {
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: shapeY), size: CGSize(width: bounds.width, height: pillSize.height))
        } else {
            backgroundFrame = shapeFrame
        }

        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.highlightNode, frame: backgroundFrame)
        transition.updateCornerRadius(node: self.backgroundNode, cornerRadius: metrics.cornerRadius)
        transition.updateCornerRadius(node: self.highlightNode, cornerRadius: metrics.cornerRadius)

        let wasExpanded = self.isExpanded
        self.isExpanded = isExpanded
        self.didApplyLayout = true
        let contentAlpha: CGFloat
        if isPrimary {
            contentAlpha = revealProgress
        } else {
            contentAlpha = revealProgress * (1.0 - 0.3 * overswipeProgress)
        }
        let animationSettings = ItemListRevealOptionsAnimationSettingsStore.current
        let minimumContentScale = clampToUnitInterval(animationSettings.minimumContentScale)
        let contentScale = minimumContentScale + (1.0 - minimumContentScale) * revealProgress
        transition.updateAlpha(node: self.contentContainerNode, alpha: contentAlpha)
        transition.updateTransform(node: self.contentContainerNode, transform: CGAffineTransform(scaleX: contentScale, y: contentScale))

        let titleAlpha: CGFloat = isPrimary && !self.displaysTitleInsidePill ? (1.0 - expandedProgress) : 1.0
        var didApplyManualContentCenter = false

        let centeredIconCenterX = isPrimary ? backgroundFrame.midX : shapeFrame.midX
        let iconCenterX: CGFloat
        if isPrimary && expandedProgress > 0.0 {
            let expandedIconCenterX: CGFloat
            if isLeft {
                expandedIconCenterX = backgroundFrame.maxX - metrics.expandedIconInset
            } else {
                expandedIconCenterX = backgroundFrame.minX + metrics.expandedIconInset
            }
            iconCenterX = centeredIconCenterX + (expandedIconCenterX - centeredIconCenterX) * expandedProgress
        } else {
            iconCenterX = centeredIconCenterX
        }
        let iconCenterY = backgroundFrame.midY

        if let animationNode = self.animationNode {
            var imageSize = CGSize(width: animationNode.size.width * self.animationScale, height: animationNode.size.height * self.animationScale)
            let imageMaxSide = max(imageSize.width, imageSize.height)
            if imageMaxSide > metrics.iconMaxSide {
                let imageScale = metrics.iconMaxSide / imageMaxSide * 1.5
                imageSize = CGSize(width: floorToScreenPixels(imageSize.width * imageScale), height: floorToScreenPixels(imageSize.height * imageScale))
            }
            let scaleFraction = imageSize.height / 56.0
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(iconCenterX - imageSize.width / 2.0), y: floorToScreenPixels(iconCenterY - imageSize.height / 2.0) + (6.0 + self.animationNodeOffset) * scaleFraction), size: imageSize)

            if isPrimary {
                didApplyManualContentCenter = true
                transition.updateBounds(node: animationNode, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
                let targetCenter = frameCenter(iconFrame)
                if didApplyLayout && wasExpanded != isExpanded && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: animationNode, targetCenter: targetCenter, forceImmediate: false)
                } else if self.manuallyAnimatedContentNode === animationNode && self.contentAnimationLink != nil && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: animationNode, targetCenter: targetCenter, forceImmediate: false)
                } else {
                    self.stopManualContentAnimation()
                    transition.updatePosition(node: animationNode, position: targetCenter)
                }
            } else {
                transition.updateFrame(node: animationNode, frame: iconFrame)
            }
            if self.enableAnimations {
                if animationRevealProgress >= animationTriggerProgress {
                    self.setAnimationTriggered(true)
                } else if !transition.isAnimated && revealProgress <= interactiveAnimationResetProgress {
                    self.setAnimationTriggered(false)
                }
            }
        } else if let iconNode = self.iconNode, let imageSize = iconNode.image?.size {
            var fittedSize = imageSize
            let imageMaxSide = max(fittedSize.width, fittedSize.height)
            if imageMaxSide > metrics.iconMaxSide {
                let imageScale = metrics.iconMaxSide / imageMaxSide
                fittedSize = CGSize(width: floorToScreenPixels(fittedSize.width * imageScale), height: floorToScreenPixels(fittedSize.height * imageScale))
            }
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(iconCenterX - fittedSize.width / 2.0), y: floorToScreenPixels(iconCenterY - fittedSize.height / 2.0)), size: fittedSize)
            if isPrimary {
                didApplyManualContentCenter = true
                transition.updateBounds(node: iconNode, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
                let targetCenter = frameCenter(iconFrame)
                if didApplyLayout && wasExpanded != isExpanded && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: iconNode, targetCenter: targetCenter, forceImmediate: false)
                } else if self.manuallyAnimatedContentNode === iconNode && self.contentAnimationLink != nil && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: iconNode, targetCenter: targetCenter, forceImmediate: false)
                } else {
                    self.stopManualContentAnimation()
                    transition.updatePosition(node: iconNode, position: targetCenter)
                }
            } else {
                transition.updateFrame(node: iconNode, frame: iconFrame)
            }
        }
        transition.updateAlpha(node: self.titleNode, alpha: titleAlpha)

        let titleFrame: CGRect
        if self.displaysTitleInsidePill {
            titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - titleSize.width / 2.0), y: floorToScreenPixels(backgroundFrame.midY - titleSize.height / 2.0)), size: titleSize)
            if isPrimary {
                didApplyManualContentCenter = true
                transition.updateBounds(node: self.titleNode, bounds: CGRect(origin: CGPoint(), size: titleFrame.size))
                let titleCenterX: CGFloat
                if expandedProgress > 0.0 {
                    let titleEdgeInset = max(metrics.expandedIconInset, titleSize.width / 2.0 + iconlessTitleExpandedHorizontalPadding)
                    let expandedTitleCenterX: CGFloat
                    if isLeft {
                        expandedTitleCenterX = backgroundFrame.maxX - titleEdgeInset
                    } else {
                        expandedTitleCenterX = backgroundFrame.minX + titleEdgeInset
                    }
                    titleCenterX = backgroundFrame.midX + (expandedTitleCenterX - backgroundFrame.midX) * expandedProgress
                } else {
                    titleCenterX = backgroundFrame.midX
                }
                let targetCenter = CGPoint(x: titleCenterX, y: backgroundFrame.midY)
                if didApplyLayout && wasExpanded != isExpanded && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: self.titleNode, targetCenter: targetCenter, forceImmediate: false)
                } else if self.manuallyAnimatedContentNode === self.titleNode && self.contentAnimationLink != nil && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: self.titleNode, targetCenter: targetCenter, forceImmediate: false)
                } else {
                    self.stopManualContentAnimation()
                    transition.updatePosition(node: self.titleNode, position: targetCenter)
                }
            } else {
                transition.updateFrame(node: self.titleNode, frame: titleFrame)
            }
        } else {
            let titleCenterX = isPrimary ? backgroundFrame.midX : shapeFrame.midX
            titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(titleCenterX - titleSize.width / 2.0), y: shapeFrame.maxY + titleSpacing), size: titleSize)
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
        }

        if !didApplyManualContentCenter {
            self.stopManualContentAnimation()
        }
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let metrics = ItemListRevealOptionLayoutMetrics.metrics(for: constrainedSize.height, hasVisualIcons: !self.displaysTitleInsidePill)
        return CGSize(width: metrics.slotWidth, height: constrainedSize.height)
    }
}

public final class ItemListRevealOptionsNode: ASDisplayNode {
    private let optionSelected: (ItemListRevealOption) -> Void
    private let tapticAction: () -> Void
    private let clippingContainerNode: ASDisplayNode
    private let optionsContainerNode: ASDisplayNode

    private var options: [ItemListRevealOption] = []
    private var isLeft: Bool = false

    private var optionNodes: [ItemListRevealOptionNode] = []
    private var revealOffset: CGFloat = 0.0
    private var sideInset: CGFloat = 0.0
    private var currentMetrics: (containerSize: CGSize, metrics: ItemListRevealOptionLayoutMetrics)?

    private var visualRevealDistance: CGFloat = 0.0
    private var visualRevealVelocity: CGFloat = 0.0
    private var targetVisualRevealDistance: CGFloat = 0.0
    private var visualRevealAnimationLink: SharedDisplayLinkDriver.Link?

    public init(optionSelected: @escaping (ItemListRevealOption) -> Void, tapticAction: @escaping () -> Void) {
        self.optionSelected = optionSelected
        self.tapticAction = tapticAction
        self.clippingContainerNode = ASDisplayNode()
        self.optionsContainerNode = ASDisplayNode()

        super.init()

        self.clippingContainerNode.clipsToBounds = true
        self.addSubnode(self.clippingContainerNode)
        self.clippingContainerNode.addSubnode(self.optionsContainerNode)
    }

    deinit {
        self.stopVisualRevealAnimation()
    }

    override public func didLoad() {
        super.didLoad()

        let gestureRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        gestureRecognizer.highlight = { [weak self] location in
            guard let strongSelf = self, let location = location else {
                return
            }
            for node in strongSelf.optionNodes {
                if node.frame.contains(location) {
                    //node.setHighlighted(true)
                    break
                }
            }
        }
        gestureRecognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(gestureRecognizer)
    }

    public func setOptions(_ options: [ItemListRevealOption], isLeft: Bool, enableAnimations: Bool) {
        if self.options != options || self.isLeft != isLeft {
            self.resetVisualRevealDistance(to: abs(self.revealOffset))
            self.options = options
            self.isLeft = isLeft
            for node in self.optionNodes {
                node.removeFromSupernode()
            }
            self.optionNodes = options.map { option in
                return ItemListRevealOptionNode(title: option.title, icon: option.icon, color: option.color, iconColor: option.iconColor, textColor: option.textColor, enableAnimations: enableAnimations)
            }
            if isLeft {
                for node in self.optionNodes.reversed() {
                    self.optionsContainerNode.addSubnode(node)
                }
            } else {
                for node in self.optionNodes {
                    self.optionsContainerNode.addSubnode(node)
                }
            }
            self.currentMetrics = nil
            self.invalidateCalculatedLayout()
        }
    }

    private func layoutMetrics(for containerSize: CGSize) -> ItemListRevealOptionLayoutMetrics {
        if let currentMetrics = self.currentMetrics, currentMetrics.containerSize == containerSize {
            return currentMetrics.metrics
        }

        let metrics = ItemListRevealOptionLayoutMetrics.metrics(for: containerSize.height, hasVisualIcons: self.options.contains(where: { $0.icon.hasVisualIcon }))
        let maxTitleWidth = self.optionNodes.reduce(0.0) { result, node in
            return max(result, node.titleWidthForGroupPillSizing)
        }
        let updatedMetrics = metrics.withGroupTitleWidth(maxTitleWidth)
        self.currentMetrics = (containerSize, updatedMetrics)
        return updatedMetrics
    }

    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let metrics = self.layoutMetrics(for: constrainedSize)
        for node in self.optionNodes {
            let _ = node.measure(constrainedSize)
        }
        return CGSize(width: metrics.revealWidth(count: self.optionNodes.count), height: constrainedSize.height)
    }

    public func updateRevealOffset(offset: CGFloat, sideInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.revealOffset = offset
        self.sideInset = sideInset
        self.updateVisualRevealDistance(targetDistance: abs(offset), transition: transition)
        self.updateNodesLayout(transition: transition)
    }

    private func stopVisualRevealAnimation() {
        self.visualRevealAnimationLink?.isPaused = true
        self.visualRevealAnimationLink?.invalidate()
        self.visualRevealAnimationLink = nil
    }

    private func resetVisualRevealDistance(to distance: CGFloat) {
        let distance = max(0.0, distance)
        self.stopVisualRevealAnimation()
        self.visualRevealDistance = distance
        self.targetVisualRevealDistance = distance
        self.visualRevealVelocity = 0.0
    }

    private func updateVisualRevealDistance(targetDistance: CGFloat, transition: ContainedViewLayoutTransition) {
        let targetDistance = max(0.0, targetDistance)
        let animationSettings = ItemListRevealOptionsAnimationSettingsStore.current
        self.targetVisualRevealDistance = targetDistance

        if transition.isAnimated {
            self.resetVisualRevealDistance(to: targetDistance)
            return
        }

        if self.visualRevealDistance > targetDistance {
            self.visualRevealDistance = targetDistance
            self.visualRevealVelocity = 0.0
        }

        if abs(self.visualRevealDistance - targetDistance) <= animationSettings.visualRevealSnapDistance && abs(self.visualRevealVelocity) <= animationSettings.visualRevealSnapVelocity {
            self.resetVisualRevealDistance(to: targetDistance)
            return
        }

        if self.visualRevealAnimationLink == nil {
            self.visualRevealAnimationLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
                self?.tickVisualRevealAnimation(deltaTime: deltaTime)
            })
            self.visualRevealAnimationLink?.isPaused = false
        }
    }

    private func tickVisualRevealAnimation(deltaTime: CGFloat) {
        let clampedDeltaTime = min(0.05, max(0.0, deltaTime))
        let targetDistance = self.targetVisualRevealDistance
        let animationSettings = ItemListRevealOptionsAnimationSettingsStore.current

        if self.visualRevealDistance > targetDistance {
            self.visualRevealDistance = targetDistance
            self.visualRevealVelocity = 0.0
        }

        let acceleration = (targetDistance - self.visualRevealDistance) * animationSettings.visualRevealSpring - self.visualRevealVelocity * animationSettings.visualRevealDamping
        self.visualRevealVelocity += acceleration * clampedDeltaTime

        var updatedDistance = self.visualRevealDistance + self.visualRevealVelocity * clampedDeltaTime
        if updatedDistance > targetDistance {
            updatedDistance = targetDistance
            self.visualRevealVelocity = 0.0
        } else if updatedDistance < 0.0 {
            updatedDistance = 0.0
            self.visualRevealVelocity = 0.0
        }
        self.visualRevealDistance = updatedDistance

        if abs(self.visualRevealDistance - targetDistance) <= animationSettings.visualRevealSnapDistance && abs(self.visualRevealVelocity) <= animationSettings.visualRevealSnapVelocity {
            self.resetVisualRevealDistance(to: targetDistance)
        }

        self.updateNodesLayout(transition: .immediate)
    }

    private func updateNodesLayout(transition: ContainedViewLayoutTransition) {
        let size = self.bounds.size
        if size.width.isLessThanOrEqualTo(0.0) || self.optionNodes.isEmpty {
            return
        }
        let metrics = self.layoutMetrics(for: size)
        let animationSettings = ItemListRevealOptionsAnimationSettingsStore.current
        let revealedDistance = abs(self.revealOffset)
        let boundedRevealedDistance = min(revealedDistance, size.width)
        let boundedVisualRevealedDistance = min(self.visualRevealDistance, revealedDistance, size.width)
        let overswipeDistance = max(0.0, revealedDistance - size.width)
        let overswipeProgress = clampToUnitInterval(overswipeDistance / expandedTransitionDistance)
        let expandedActivationDistance = 50.0 * (expandedActivationWidthFactor - 1.0)
        let primaryIndex = self.isLeft ? 0 : self.optionNodes.count - 1
        let stride = metrics.shapeSize.width + spacing

        let clippingFrameX: CGFloat
        if self.isLeft {
            clippingFrameX = max(0.0, size.width - revealedDistance)
        } else {
            clippingFrameX = 0.0
        }
        let clippingFrame = CGRect(origin: CGPoint(x: clippingFrameX, y: 0.0), size: CGSize(width: revealedDistance, height: size.height))
        transition.updateFrame(node: self.clippingContainerNode, frame: clippingFrame, completion: { [weak self] completed in
            guard completed, revealedDistance < CGFloat.ulpOfOne, let self, abs(self.revealOffset) < CGFloat.ulpOfOne else {
                return
            }
            for node in self.optionNodes {
                node.resetAnimation()
            }
        })
        transition.updateFrame(node: self.optionsContainerNode, frame: CGRect(origin: CGPoint(x: -clippingFrameX, y: 0.0), size: CGSize(width: max(size.width, revealedDistance), height: size.height)))

        var i = self.isLeft ? (self.optionNodes.count - 1) : 0
        while i >= 0 && i < self.optionNodes.count {
            let node = self.optionNodes[i]
            let isPrimary = i == primaryIndex
            let isStretched = isPrimary && overswipeDistance > CGFloat.ulpOfOne
            let isExpanded = isPrimary && overswipeDistance > expandedActivationDistance
            let expandedProgress: CGFloat = isExpanded ? 1.0 : 0.0
            if node.hasAppliedLayout && node.isExpanded != isExpanded && !transition.isAnimated {
                self.tapticAction()
            }

            let baseCircleFrame: CGRect
            let nodeFrame: CGRect
            let revealProgress: CGFloat
            let animationRevealProgress: CGFloat

            if self.isLeft {
                let baseCircleLeft = size.width - boundedRevealedDistance + self.sideInset + edgeInset + CGFloat(i) * stride
                baseCircleFrame = CGRect(origin: CGPoint(x: baseCircleLeft, y: 0.0), size: metrics.shapeSize)
                let visualBaseCircleLeft = size.width - boundedVisualRevealedDistance + self.sideInset + edgeInset + CGFloat(i) * stride
                let distanceFromShutterEdge = size.width - (visualBaseCircleLeft + metrics.shapeSize.width)
                revealProgress = revealProgressCurve((distanceFromShutterEdge + animationSettings.revealStartOverlap) / max(1.0, animationSettings.revealStartOverlap + animationSettings.revealEndDistance), response: animationSettings.revealProgressResponse)
                let animationDistanceFromShutterEdge = size.width - (baseCircleLeft + metrics.shapeSize.width)
                animationRevealProgress = revealProgressCurve((animationDistanceFromShutterEdge + animationSettings.revealStartOverlap) / max(1.0, animationSettings.revealStartOverlap + animationSettings.revealEndDistance), response: animationSettings.revealProgressResponse)

                if isStretched {
                    let primaryLeft = size.width - boundedRevealedDistance + self.sideInset + edgeInset
                    let primaryRight: CGFloat
                    if self.optionNodes.count > 1 {
                        let neighborLeft = primaryLeft + stride + overswipeDistance
                        primaryRight = max(primaryLeft + metrics.shapeSize.width, neighborLeft - spacing)
                    } else {
                        primaryRight = primaryLeft + metrics.shapeSize.width + overswipeDistance
                    }
                    nodeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(primaryLeft), y: 0.0), size: CGSize(width: max(metrics.shapeSize.width, primaryRight - primaryLeft), height: size.height))
                } else {
                    let circleLeft = baseCircleLeft + (isPrimary ? 0.0 : overswipeDistance)
                    nodeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(circleLeft - metrics.slotShapeInset), y: 0.0), size: CGSize(width: metrics.slotWidth, height: size.height))
                }
            } else {
                let baseCircleRight = revealedDistance + self.sideInset - edgeInset - CGFloat(self.optionNodes.count - 1 - i) * stride
                baseCircleFrame = CGRect(origin: CGPoint(x: baseCircleRight - metrics.shapeSize.width, y: 0.0), size: metrics.shapeSize)
                let visualBaseCircleRight = boundedVisualRevealedDistance + self.sideInset - edgeInset - CGFloat(self.optionNodes.count - 1 - i) * stride
                revealProgress = revealProgressCurve((visualBaseCircleRight - metrics.shapeSize.width + animationSettings.revealStartOverlap) / max(1.0, animationSettings.revealStartOverlap + animationSettings.revealEndDistance), response: animationSettings.revealProgressResponse)
                let animationBaseCircleRight = boundedRevealedDistance + self.sideInset - edgeInset - CGFloat(self.optionNodes.count - 1 - i) * stride
                animationRevealProgress = revealProgressCurve((animationBaseCircleRight - metrics.shapeSize.width + animationSettings.revealStartOverlap) / max(1.0, animationSettings.revealStartOverlap + animationSettings.revealEndDistance), response: animationSettings.revealProgressResponse)

                if isStretched {
                    let primaryRight = revealedDistance + self.sideInset - edgeInset
                    let primaryLeft: CGFloat
                    if self.optionNodes.count > 1 {
                        let neighborRight = primaryRight - stride - overswipeDistance
                        primaryLeft = min(primaryRight - metrics.shapeSize.width, neighborRight + spacing)
                    } else {
                        primaryLeft = primaryRight - metrics.shapeSize.width - overswipeDistance
                    }
                    nodeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(primaryLeft), y: 0.0), size: CGSize(width: max(metrics.shapeSize.width, primaryRight - primaryLeft), height: size.height))
                } else {
                    let circleLeft = baseCircleFrame.minX - (isPrimary ? 0.0 : overswipeDistance)
                    nodeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(circleLeft - metrics.slotShapeInset), y: 0.0), size: CGSize(width: metrics.slotWidth, height: size.height))
                }
            }

            transition.updateFrame(node: node, frame: nodeFrame)

            node.updateLayout(isLeft: self.isLeft, isPrimary: isPrimary, metrics: metrics, revealProgress: revealProgress, animationRevealProgress: animationRevealProgress, overswipeProgress: overswipeProgress, expandedProgress: expandedProgress, isStretched: isStretched, isExpanded: isExpanded, transition: transition)

            if self.isLeft {
                i -= 1
            } else {
                i += 1
            }
        }
    }

    @objc private func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        if case .ended = recognizer.state, let gesture = recognizer.lastRecognizedGestureAndLocation?.0, case .tap = gesture {
            let location = recognizer.location(in: self.view)
            var selectedOption: Int?

            var i = self.isLeft ? 0 : (self.optionNodes.count - 1)
            while i >= 0 && i < self.optionNodes.count {
                self.optionNodes[i].setHighlighted(false)
                if self.optionNodes[i].frame.contains(location) {
                    selectedOption = i
                    break
                }
                if self.isLeft {
                    i += 1
                } else {
                    i -= 1
                }
            }
            if let selectedOption = selectedOption {
                self.optionSelected(self.options[selectedOption])
            }
        }
    }

    public func isDisplayingExtendedAction() -> Bool {
        return self.optionNodes.contains(where: { $0.isExpanded })
    }
}
