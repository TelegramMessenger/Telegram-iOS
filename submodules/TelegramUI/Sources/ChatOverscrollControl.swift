import UIKit
import ComponentFlow
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import AccountContext
import AvatarNode
import TextFormat
import Markdown
import WallpaperBackgroundNode

final class BlurredRoundedRectangle: Component {
    let color: UIColor

    init(color: UIColor) {
        self.color = color
    }

    static func ==(lhs: BlurredRoundedRectangle, rhs: BlurredRoundedRectangle) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        return true
    }

    final class View: UIView {
        private let background: NavigationBackgroundNode

        init() {
            self.background = NavigationBackgroundNode(color: .clear)

            super.init(frame: CGRect())

            self.addSubview(self.background.view)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: BlurredRoundedRectangle, availableSize: CGSize, transition: Transition) -> CGSize {
            transition.setFrame(view: self.background.view, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.background.updateColor(color: component.color, transition: .immediate)
            self.background.update(size: availableSize, cornerRadius: min(availableSize.width, availableSize.height) / 2.0, transition: .immediate)

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class RadialProgressComponent: Component {
    let color: UIColor
    let lineWidth: CGFloat
    let value: CGFloat

    init(
        color: UIColor,
        lineWidth: CGFloat,
        value: CGFloat
    ) {
        self.color = color
        self.lineWidth = lineWidth
        self.value = value
    }

    static func ==(lhs: RadialProgressComponent, rhs: RadialProgressComponent) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if lhs.lineWidth != rhs.lineWidth {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }

    final class View: UIView {
        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: RadialProgressComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            func draw(context: CGContext) {
                let diameter = availableSize.width

                context.saveGState()

                context.setBlendMode(.normal)
                context.setFillColor(component.color.cgColor)
                context.setStrokeColor(component.color.cgColor)

                var progress: CGFloat
                var startAngle: CGFloat
                var endAngle: CGFloat

                let value = component.value

                progress = value
                startAngle = -CGFloat.pi / 2.0
                endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle

                if progress > 1.0 {
                    progress = 2.0 - progress
                    let tmp = startAngle
                    startAngle = endAngle
                    endAngle = tmp
                }
                progress = min(1.0, progress)

                let lineWidth: CGFloat = component.lineWidth

                let pathDiameter: CGFloat

                pathDiameter = diameter - lineWidth

                var angle: Double = 0.0
                angle *= 4.0

                context.translateBy(x: diameter / 2.0, y: diameter / 2.0)
                context.rotate(by: CGFloat(angle.truncatingRemainder(dividingBy: Double.pi * 2.0)))
                context.translateBy(x: -diameter / 2.0, y: -diameter / 2.0)

                let path = UIBezierPath(arcCenter: CGPoint(x: diameter / 2.0, y: diameter / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                path.lineWidth = lineWidth
                path.lineCapStyle = .round
                path.stroke()

                context.restoreGState()
            }

            if #available(iOS 10.0, *) {
                let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: availableSize))
                let image = renderer.image { context in
                    UIGraphicsPushContext(context.cgContext)
                    draw(context: context.cgContext)
                    UIGraphicsPopContext()
                }
                self.layer.contents = image.cgImage
            } else {
                UIGraphicsBeginImageContextWithOptions(availableSize, false, 0.0)
                draw(context: UIGraphicsGetCurrentContext()!)
                self.layer.contents = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
                UIGraphicsEndImageContext()
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class CheckComponent: Component {
    let color: UIColor
    let lineWidth: CGFloat
    let value: CGFloat

    init(
        color: UIColor,
        lineWidth: CGFloat,
        value: CGFloat
    ) {
        self.color = color
        self.lineWidth = lineWidth
        self.value = value
    }

    static func ==(lhs: CheckComponent, rhs: CheckComponent) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if lhs.lineWidth != rhs.lineWidth {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }

    final class View: UIView {
        private var currentValue: CGFloat?
        private var animator: DisplayLinkAnimator?

        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        private func updateContent(size: CGSize, color: UIColor, lineWidth: CGFloat, value: CGFloat) {
            func draw(context: CGContext) {
                let diameter = size.width

                let factor = diameter / 50.0

                context.saveGState()

                context.setBlendMode(.normal)
                context.setFillColor(color.cgColor)
                context.setStrokeColor(color.cgColor)

                let center = CGPoint(x: diameter / 2.0, y: diameter / 2.0)

                context.setLineWidth(max(1.7, lineWidth * factor))
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.setMiterLimit(10.0)

                let progress = value
                let firstSegment: CGFloat = max(0.0, min(1.0, progress * 3.0))

                var s = CGPoint(x: center.x - 10.0 * factor, y: center.y + 1.0 * factor)
                var p1 = CGPoint(x: 7.0 * factor, y: 7.0 * factor)
                var p2 = CGPoint(x: 13.0 * factor, y: -15.0 * factor)

                if diameter < 36.0 {
                    s = CGPoint(x: center.x - 7.0 * factor, y: center.y + 1.0 * factor)
                    p1 = CGPoint(x: 4.5 * factor, y: 4.5 * factor)
                    p2 = CGPoint(x: 10.0 * factor, y: -11.0 * factor)
                }

                if !firstSegment.isZero {
                    if firstSegment < 1.0 {
                        context.move(to: CGPoint(x: s.x + p1.x * firstSegment, y: s.y + p1.y * firstSegment))
                        context.addLine(to: s)
                    } else {
                        let secondSegment = (progress - 0.33) * 1.5
                        context.move(to: CGPoint(x: s.x + p1.x + p2.x * secondSegment, y: s.y + p1.y + p2.y * secondSegment))
                        context.addLine(to: CGPoint(x: s.x + p1.x, y: s.y + p1.y))
                        context.addLine(to: s)
                    }
                }
                context.strokePath()

                context.restoreGState()
            }

            if #available(iOS 10.0, *) {
                let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: size))
                let image = renderer.image { context in
                    UIGraphicsPushContext(context.cgContext)
                    draw(context: context.cgContext)
                    UIGraphicsPopContext()
                }
                self.layer.contents = image.cgImage
            } else {
                UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                draw(context: UIGraphicsGetCurrentContext()!)
                self.layer.contents = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
                UIGraphicsEndImageContext()
            }
        }

        func update(component: CheckComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if let currentValue = self.currentValue, currentValue != component.value, case .curve = transition.animation {
                self.animator?.invalidate()

                let animator = DisplayLinkAnimator(duration: 0.15, from: currentValue, to: component.value, update: { [weak self] value in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateContent(size: availableSize, color: component.color, lineWidth: component.lineWidth, value: value)
                }, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.animator?.invalidate()
                    strongSelf.animator = nil
                })
                self.animator = animator
            } else {
                if self.animator == nil {
                    self.updateContent(size: availableSize, color: component.color, lineWidth: component.lineWidth, value: component.value)
                }
            }

            self.currentValue = component.value

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class BadgeComponent: CombinedComponent {
    let count: Int
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let rect: CGRect
    let withinSize: CGSize
    let wallpaperNode: WallpaperBackgroundNode?

    init(
        count: Int,
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        rect: CGRect,
        withinSize: CGSize,
        wallpaperNode: WallpaperBackgroundNode?
    ) {
        self.count = count
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.rect = rect
        self.withinSize = withinSize
        self.wallpaperNode = wallpaperNode
    }

    static func ==(lhs: BadgeComponent, rhs: BadgeComponent) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        if !lhs.backgroundColor.isEqual(rhs.backgroundColor) {
            return false
        }
        if !lhs.foregroundColor.isEqual(rhs.foregroundColor) {
            return false
        }
        if lhs.rect != rhs.rect {
            return false
        }
        if lhs.withinSize != rhs.withinSize {
            return false
        }
        if lhs.wallpaperNode != rhs.wallpaperNode {
            return false
        }
        return true
    }

    static var body: Body {
        let background = Child(WallpaperBlurComponent.self)
        let text = Child(Text.self)

        return { context in
            let text = text.update(
                component: Text(
                    text: "\(context.component.count)",
                    font: Font.regular(13.0),
                    color: context.component.foregroundColor
                ),
                availableSize: CGSize(width: 100.0, height: 100.0),
                transition: .immediate
            )

            let height = text.size.height + 4.0
            let backgroundSize = CGSize(width: max(height, text.size.width + 8.0), height: height)

            let background = background.update(
                component: WallpaperBlurComponent(
                    rect: CGRect(origin: context.component.rect.origin, size: backgroundSize),
                    withinSize: context.component.withinSize,
                    color: context.component.backgroundColor,
                    wallpaperNode: context.component.wallpaperNode
                ),
                availableSize: backgroundSize,
                transition: .immediate
            )

            context.add(background
                .position(CGPoint(x: backgroundSize.width / 2.0, y: backgroundSize.height / 2.0))
                .cornerRadius(min(backgroundSize.width, backgroundSize.height) / 2.0)
                .clipsToBounds(true)
            )

            context.add(text
                .position(CGPoint(x: backgroundSize.width / 2.0, y: backgroundSize.height / 2.0))
            )

            return backgroundSize
        }
    }
}

final class AvatarComponent: Component {
    final class Badge: Equatable {
        let count: Int
        let backgroundColor: UIColor
        let foregroundColor: UIColor

        init(count: Int, backgroundColor: UIColor, foregroundColor: UIColor) {
            self.count = count
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
        }

        static func ==(lhs: Badge, rhs: Badge) -> Bool {
            if lhs.count != rhs.count {
                return false
            }
            if !lhs.backgroundColor.isEqual(rhs.backgroundColor) {
                return false
            }
            if !lhs.foregroundColor.isEqual(rhs.foregroundColor) {
                return false
            }
            return true
        }
    }

    let context: AccountContext
    let peer: EnginePeer
    let badge: Badge?
    let rect: CGRect
    let withinSize: CGSize
    let wallpaperNode: WallpaperBackgroundNode?

    init(
        context: AccountContext,
        peer: EnginePeer,
        badge: Badge?,
        rect: CGRect,
        withinSize: CGSize,
        wallpaperNode: WallpaperBackgroundNode?
    ) {
        self.context = context
        self.peer = peer
        self.badge = badge
        self.rect = rect
        self.withinSize = withinSize
        self.wallpaperNode = wallpaperNode
    }

    static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        if lhs.rect != rhs.rect {
            return false
        }
        if lhs.withinSize != rhs.withinSize {
            return false
        }
        if lhs.wallpaperNode !== rhs.wallpaperNode {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode
        private let avatarMask: CAShapeLayer
        private var badgeView: ComponentHostView<Empty>?

        init() {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
            self.avatarMask = CAShapeLayer()

            super.init(frame: CGRect())

            self.addSubview(self.avatarNode.view)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: AvatarComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.avatarNode.frame = CGRect(origin: CGPoint(), size: availableSize)
            let theme = component.context.sharedContext.currentPresentationData.with({ $0 }).theme
            self.avatarNode.setPeer(context: component.context, theme: theme, peer: component.peer, emptyColor: theme.list.mediaPlaceholderColor, synchronousLoad: true)

            if let badge = component.badge {
                let badgeView: ComponentHostView<Empty>
                let animateIn = self.badgeView == nil
                if let current = self.badgeView {
                    badgeView = current
                } else {
                    badgeView = ComponentHostView<Empty>()
                    self.badgeView = badgeView
                    self.addSubview(badgeView)
                }

                let badgeSize = badgeView.update(
                    transition: .immediate,
                    component: AnyComponent(BadgeComponent(
                        count: badge.count,
                        backgroundColor: badge.backgroundColor,
                        foregroundColor: badge.foregroundColor,
                        rect: CGRect(origin: component.rect.offsetBy(dx: 0.0, dy: 0.0).origin, size: CGSize()),
                        withinSize: component.withinSize,
                        wallpaperNode: component.wallpaperNode
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0
                ))
                let badgeDiameter = min(badgeSize.width, badgeSize.height)
                let circlePoint = CGPoint(
                    x: availableSize.width / 2.0 + cos(CGFloat.pi / 4) * availableSize.width / 2.0,
                    y: availableSize.height / 2.0 - sin(CGFloat.pi / 4) * availableSize.width / 2.0
                )
                badgeView.frame = CGRect(origin: CGPoint(x: circlePoint.x - badgeDiameter / 2.0, y: circlePoint.y - badgeDiameter / 2.0), size: badgeSize)

                self.avatarMask.frame = self.avatarNode.bounds
                self.avatarMask.fillRule = .evenOdd

                let path = UIBezierPath(rect: self.avatarMask.bounds)
                path.append(UIBezierPath(roundedRect: badgeView.frame.insetBy(dx: -2.0, dy: -2.0), cornerRadius: badgeDiameter / 2.0))
                self.avatarMask.path = path.cgPath

                self.avatarNode.view.layer.mask = self.avatarMask

                if animateIn {
                    badgeView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.14)
                }
            } else if let badgeView = self.badgeView {
                self.badgeView = nil

                badgeView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.14, removeOnCompletion: false, completion: { [weak badgeView] _ in
                    badgeView?.removeFromSuperview()
                })

                self.avatarNode.view.layer.mask = nil
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class WallpaperBlurNode: ASDisplayNode {
    private var backgroundNode: WallpaperBackgroundNode.BubbleBackgroundNode?
    private let colorNode: ASDisplayNode

    override init() {
        self.colorNode = ASDisplayNode()

        super.init()

        self.addSubnode(self.colorNode)
    }

    func update(rect: CGRect, within size: CGSize, color: UIColor, wallpaperNode: WallpaperBackgroundNode?, transition: ContainedViewLayoutTransition) {
        var transition = transition
        if self.backgroundNode == nil {
            if let backgroundNode = wallpaperNode?.makeBubbleBackground(for: .free) {
                self.backgroundNode = backgroundNode
                self.insertSubnode(backgroundNode, at: 0)
                transition = .immediate
            }
        }

        self.colorNode.backgroundColor = color
        transition.updateFrame(node: self.colorNode, frame: CGRect(origin: CGPoint(), size: rect.size))

        if let backgroundNode = self.backgroundNode {
            transition.updateFrame(node: backgroundNode, frame: CGRect(origin: CGPoint(), size: rect.size))
            backgroundNode.update(rect: rect, within: size, transition: transition)
        }
    }
}

private final class WallpaperBlurComponent: Component {
    let rect: CGRect
    let withinSize: CGSize
    let color: UIColor
    let wallpaperNode: WallpaperBackgroundNode?

    init(
        rect: CGRect,
        withinSize: CGSize,
        color: UIColor,
        wallpaperNode: WallpaperBackgroundNode?
    ) {
        self.rect = rect
        self.withinSize = withinSize
        self.color = color
        self.wallpaperNode = wallpaperNode
    }

    static func ==(lhs: WallpaperBlurComponent, rhs: WallpaperBlurComponent) -> Bool {
        if lhs.rect != rhs.rect {
            return false
        }
        if lhs.withinSize != rhs.withinSize {
            return false
        }
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if lhs.wallpaperNode !== rhs.wallpaperNode {
            return false
        }
        return true
    }

    final class View: UIView {
        private let background: WallpaperBlurNode

        init() {
            self.background = WallpaperBlurNode()

            super.init(frame: CGRect())

            self.addSubview(self.background.view)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: WallpaperBlurComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            transition.setFrame(view: self.background.view, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.background.update(rect: component.rect, within: component.withinSize, color: component.color, wallpaperNode: component.wallpaperNode, transition: .immediate)

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class OverscrollContentsComponent: Component {
    let context: AccountContext
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let peer: EnginePeer?
    let unreadCount: Int
    let location: TelegramEngine.NextUnreadChannelLocation
    let expandOffset: CGFloat
    let freezeProgress: Bool
    let absoluteRect: CGRect
    let absoluteSize: CGSize
    let wallpaperNode: WallpaperBackgroundNode?

    init(
        context: AccountContext,
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        peer: EnginePeer?,
        unreadCount: Int,
        location: TelegramEngine.NextUnreadChannelLocation,
        expandOffset: CGFloat,
        freezeProgress: Bool,
        absoluteRect: CGRect,
        absoluteSize: CGSize,
        wallpaperNode: WallpaperBackgroundNode?
    ) {
        self.context = context
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.peer = peer
        self.unreadCount = unreadCount
        self.location = location
        self.expandOffset = expandOffset
        self.freezeProgress = freezeProgress
        self.absoluteRect = absoluteRect
        self.absoluteSize = absoluteSize
        self.wallpaperNode = wallpaperNode
    }

    static func ==(lhs: OverscrollContentsComponent, rhs: OverscrollContentsComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if !lhs.backgroundColor.isEqual(rhs.backgroundColor) {
            return false
        }
        if !lhs.foregroundColor.isEqual(rhs.foregroundColor) {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.unreadCount != rhs.unreadCount {
            return false
        }
        if lhs.location != rhs.location {
            return false
        }
        if lhs.expandOffset != rhs.expandOffset {
            return false
        }
        if lhs.freezeProgress != rhs.freezeProgress {
            return false
        }
        if lhs.absoluteRect != rhs.absoluteRect {
            return false
        }
        if lhs.absoluteSize != rhs.absoluteSize {
            return false
        }
        if lhs.wallpaperNode !== rhs.wallpaperNode {
            return false
        }
        return true
    }

    final class View: UIView {
        private let backgroundScalingContainer: ASDisplayNode
        private let backgroundNode: WallpaperBlurNode
        private let backgroundFolderMask: UIImageView
        private let backgroundClippingNode: ASDisplayNode
        private let avatarView = ComponentHostView<Empty>()
        private let checkView = ComponentHostView<Empty>()
        private let arrowNode: ASImageNode
        private let avatarScalingContainer: ASDisplayNode
        private let avatarExtraScalingContainer: ASDisplayNode
        private let avatarOffsetContainer: ASDisplayNode
        private let arrowOffsetContainer: ASDisplayNode

        private let titleOffsetContainer: ASDisplayNode
        private let titleBackgroundNode: WallpaperBlurNode
        private let titleNode: ImmediateTextNode

        private var isFullyExpanded: Bool = false

        private var validForegroundColor: UIColor?

        init() {
            self.backgroundScalingContainer = ASDisplayNode()
            self.backgroundNode = WallpaperBlurNode()
            self.backgroundNode.clipsToBounds = true

            self.backgroundFolderMask = UIImageView()
            self.backgroundFolderMask.image = UIImage(bundleImageName: "Chat/OverscrollFolder")?.stretchableImage(withLeftCapWidth: 0, topCapHeight: 40)

            self.backgroundClippingNode = ASDisplayNode()
            self.backgroundClippingNode.clipsToBounds = true
            self.arrowNode = ASImageNode()
            self.avatarScalingContainer = ASDisplayNode()
            self.avatarExtraScalingContainer = ASDisplayNode()
            self.avatarOffsetContainer = ASDisplayNode()
            self.arrowOffsetContainer = ASDisplayNode()

            self.titleOffsetContainer = ASDisplayNode()
            self.titleBackgroundNode = WallpaperBlurNode()
            self.titleBackgroundNode.clipsToBounds = true
            self.titleNode = ImmediateTextNode()

            super.init(frame: CGRect())

            self.addSubview(self.backgroundScalingContainer.view)

            self.backgroundClippingNode.addSubnode(self.backgroundNode)
            self.backgroundScalingContainer.addSubnode(self.backgroundClippingNode)

            self.avatarScalingContainer.view.addSubview(self.avatarView)
            self.avatarScalingContainer.view.addSubview(self.checkView)
            self.avatarExtraScalingContainer.addSubnode(self.avatarScalingContainer)
            self.avatarOffsetContainer.addSubnode(self.avatarExtraScalingContainer)
            self.arrowOffsetContainer.addSubnode(self.arrowNode)
            self.backgroundNode.addSubnode(self.arrowOffsetContainer)
            self.addSubnode(self.avatarOffsetContainer)

            self.titleOffsetContainer.addSubnode(self.titleBackgroundNode)
            self.titleOffsetContainer.addSubnode(self.titleNode)
            self.addSubnode(self.titleOffsetContainer)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: OverscrollContentsComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if let _ = component.peer {
                self.avatarView.isHidden = false
                self.checkView.isHidden = true
            } else {
                self.avatarView.isHidden = true
                self.checkView.isHidden = false
            }

            let fullHeight: CGFloat = 94.0
            let backgroundWidth: CGFloat = 56.0
            let minBackgroundHeight: CGFloat = backgroundWidth + 5.0
            let avatarInset: CGFloat = 6.0

            let apparentExpandOffset: CGFloat
            if component.freezeProgress {
                apparentExpandOffset = fullHeight
            } else {
                apparentExpandOffset = component.expandOffset
            }

            let isFullyExpanded = apparentExpandOffset >= fullHeight

            let isFolderMask: Bool
            switch component.location {
            case .archived, .folder:
                isFolderMask = true
            default:
                isFolderMask = false
            }

            let expandProgress: CGFloat = max(0.1, min(1.0, apparentExpandOffset / fullHeight))
            let trueExpandProgress: CGFloat = max(0.1, min(1.0, component.expandOffset / fullHeight))

            func interpolate(from: CGFloat, to: CGFloat, value: CGFloat) -> CGFloat {
                return (1.0 - value) * from + value * to
            }

            let backgroundHeight: CGFloat = interpolate(from: minBackgroundHeight, to: fullHeight, value: trueExpandProgress)

            let backgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - backgroundWidth) / 2.0), y: fullHeight - backgroundHeight), size: CGSize(width: backgroundWidth, height: backgroundHeight))

            let alphaProgress: CGFloat = max(0.0, min(1.0, apparentExpandOffset / 10.0))

            let maxAvatarScale: CGFloat = 1.0
            var avatarExpandProgress: CGFloat = max(0.01, min(maxAvatarScale, apparentExpandOffset / fullHeight))
            avatarExpandProgress *= expandProgress

            let avatarOffsetProgress = interpolate(from: 0.1, to: 1.0, value: avatarExpandProgress)

            transition.setAlpha(view: self.backgroundScalingContainer.view, alpha: alphaProgress)
            transition.setFrame(view: self.backgroundScalingContainer.view, frame: CGRect(origin: CGPoint(x: floor(availableSize.width / 2.0), y: fullHeight), size: CGSize(width: 0.0, height: 0.0)))
            transition.setSublayerTransform(view: self.backgroundScalingContainer.view, transform: CATransform3DMakeScale(expandProgress, expandProgress, 1.0))

            transition.setFrame(view: self.backgroundNode.view, frame: CGRect(origin: CGPoint(x: 0.0, y: fullHeight - backgroundFrame.size.height), size: backgroundFrame.size))
            self.backgroundNode.update(rect: backgroundFrame.offsetBy(dx: component.absoluteRect.minX, dy: component.absoluteRect.minY), within: component.absoluteSize, color: component.backgroundColor, wallpaperNode: component.wallpaperNode, transition: .immediate)
            self.backgroundFolderMask.frame = CGRect(origin: CGPoint(), size: backgroundFrame.size)

            let avatarFrame = CGRect(origin: CGPoint(x: floor(-backgroundWidth / 2.0), y: floor(-backgroundWidth / 2.0)), size: CGSize(width: backgroundWidth, height: backgroundWidth))
            self.avatarView.frame = avatarFrame

            transition.setFrame(view: self.avatarOffsetContainer.view, frame: CGRect())
            transition.setFrame(view: self.avatarScalingContainer.view, frame: CGRect())
            transition.setFrame(view: self.avatarExtraScalingContainer.view, frame: CGRect(origin: CGPoint(x: availableSize.width / 2.0, y: fullHeight - backgroundWidth / 2.0), size: CGSize()).offsetBy(dx: 0.0, dy: (1.0 - avatarOffsetProgress) * backgroundWidth * 0.5))
            transition.setSublayerTransform(view: self.avatarScalingContainer.view, transform: CATransform3DMakeScale(avatarExpandProgress, avatarExpandProgress, 1.0))

            let titleText: String
            if let peer = component.peer {
                titleText = peer.compactDisplayTitle
            } else {
                titleText = component.context.sharedContext.currentPresentationData.with({ $0 }).strings.Chat_NavigationNoChannels
            }
            self.titleNode.attributedText = NSAttributedString(string: titleText, font: Font.semibold(13.0), textColor: component.foregroundColor)
            let titleSize = self.titleNode.updateLayout(CGSize(width: availableSize.width - 32.0, height: 100.0))
            let titleBackgroundSize = CGSize(width: titleSize.width + 18.0, height: titleSize.height + 8.0)
            let titleBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleBackgroundSize.width) / 2.0), y: fullHeight - titleBackgroundSize.height - 8.0), size: titleBackgroundSize)
            self.titleBackgroundNode.frame = titleBackgroundFrame
            self.titleBackgroundNode.update(rect: titleBackgroundFrame.offsetBy(dx: component.absoluteRect.minX, dy: component.absoluteRect.minY), within: component.absoluteSize, color: component.backgroundColor, wallpaperNode: component.wallpaperNode, transition: .immediate)
            self.titleBackgroundNode.cornerRadius = min(titleBackgroundFrame.width, titleBackgroundFrame.height) / 2.0
            self.titleNode.frame = titleSize.centered(in: titleBackgroundFrame)

            let backgroundClippingFrame = CGRect(origin: CGPoint(x: floor(-backgroundWidth / 2.0), y: -fullHeight), size: CGSize(width: backgroundWidth, height: isFullyExpanded ? backgroundWidth : fullHeight))
            self.backgroundClippingNode.cornerRadius = isFolderMask ? 10.0 : backgroundWidth / 2.0
            self.backgroundNode.cornerRadius = isFolderMask ? 0.0 : backgroundWidth / 2.0
            self.backgroundNode.view.mask = isFolderMask ? self.backgroundFolderMask : nil

            if !(self.validForegroundColor?.isEqual(component.foregroundColor) ?? false) {
                self.validForegroundColor = component.foregroundColor
                self.arrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/OverscrollArrow"), color: component.foregroundColor)
            }

            if let arrowImage = self.arrowNode.image {
                self.arrowNode.frame = CGRect(origin: CGPoint(x: floor((backgroundWidth - arrowImage.size.width) / 2.0), y: floor((backgroundWidth - arrowImage.size.width) / 2.0)), size: arrowImage.size)
            }

            let transformTransition: ContainedViewLayoutTransition
            if self.isFullyExpanded != isFullyExpanded {
                self.isFullyExpanded = isFullyExpanded
                transformTransition = .animated(duration: 0.12, curve: .easeInOut)

                if isFullyExpanded {
                    func animateBounce(layer: CALayer) {
                        layer.animateScale(from: 1.0, to: 1.1, duration: 0.1, removeOnCompletion: false, completion: { [weak layer] _ in
                            layer?.animateScale(from: 1.1, to: 1.0, duration: 0.14, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                        })
                    }

                    animateBounce(layer: self.backgroundClippingNode.layer)
                    animateBounce(layer: self.avatarExtraScalingContainer.layer)

                    func animateOffsetBounce(layer: CALayer) {
                        let firstAnimation = layer.makeAnimation(from: 0.0 as NSNumber, to: -5.0 as NSNumber, keyPath: "transform.translation.y", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.1, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                            guard let layer = layer else {
                                return
                            }
                            let secondAnimation = layer.makeAnimation(from: -5.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "transform.translation.y", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.14, removeOnCompletion: true, additive: true)
                            layer.add(secondAnimation, forKey: "bounceY")
                        })
                        layer.add(firstAnimation, forKey: "bounceY")
                    }

                    animateOffsetBounce(layer: self.layer)
                }
            } else {
                transformTransition = .immediate
            }

            let checkSize: CGFloat = 56.0
            self.checkView.frame = CGRect(origin: CGPoint(x: floor(-checkSize / 2.0), y: floor(-checkSize / 2.0)), size: CGSize(width: checkSize, height: checkSize))
            let _ = self.checkView.update(
                transition: Transition(animation: transformTransition.isAnimated ? .curve(duration: 0.2, curve: .easeInOut) : .none),
                component: AnyComponent(CheckComponent(
                    color: component.foregroundColor,
                    lineWidth: 3.0,
                    value: isFullyExpanded ? 1.0 : 0.0
                )),
                environment: {},
                containerSize: CGSize(width: checkSize, height: checkSize)
            )

            if let peer = component.peer {
                let _ = self.avatarView.update(
                    transition: Transition(animation: transformTransition.isAnimated ? .curve(duration: 0.2, curve: .easeInOut) : .none),
                    component: AnyComponent(AvatarComponent(
                        context: component.context,
                        peer: peer,
                        badge: isFullyExpanded ? AvatarComponent.Badge(count: component.unreadCount, backgroundColor: component.backgroundColor, foregroundColor: component.foregroundColor) : nil,
                        rect: avatarFrame.offsetBy(dx: self.avatarExtraScalingContainer.frame.midX + component.absoluteRect.minX, dy: self.avatarExtraScalingContainer.frame.midY + component.absoluteRect.minY),
                        withinSize: component.absoluteSize,
                        wallpaperNode: component.wallpaperNode
                    )),
                    environment: {},
                    containerSize: self.avatarView.bounds.size
                )
            }

            transformTransition.updateAlpha(node: self.backgroundNode, alpha: (isFullyExpanded && component.peer != nil) ? 0.0 : 1.0)
            transformTransition.updateAlpha(node: self.arrowNode, alpha: isFullyExpanded ? 0.0 : 1.0)

            transformTransition.updateSublayerTransformOffset(layer: self.avatarOffsetContainer.layer, offset: CGPoint(x: 0.0, y: isFullyExpanded ? -(fullHeight - backgroundWidth) : 0.0))
            transformTransition.updateSublayerTransformOffset(layer: self.arrowOffsetContainer.layer, offset: CGPoint(x: 0.0, y: isFullyExpanded ? -(fullHeight - backgroundWidth) : 0.0))

            transformTransition.updateSublayerTransformOffset(layer: self.titleOffsetContainer.layer, offset: CGPoint(x: 0.0, y: isFullyExpanded ? 0.0 : (titleBackgroundSize.height + 50.0)))

            transformTransition.updateSublayerTransformScale(node: self.avatarExtraScalingContainer, scale: isFullyExpanded ? 1.0 : ((backgroundWidth - avatarInset * 2.0) / backgroundWidth))

            transformTransition.updateFrame(node: self.backgroundClippingNode, frame: backgroundClippingFrame)

            return CGSize(width: availableSize.width, height: fullHeight)
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class ChatOverscrollControl: CombinedComponent {
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let peer: EnginePeer?
    let unreadCount: Int
    let location: TelegramEngine.NextUnreadChannelLocation
    let context: AccountContext
    let expandDistance: CGFloat
    let freezeProgress: Bool
    let absoluteRect: CGRect
    let absoluteSize: CGSize
    let wallpaperNode: WallpaperBackgroundNode?

    init(
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        peer: EnginePeer?,
        unreadCount: Int,
        location: TelegramEngine.NextUnreadChannelLocation,
        context: AccountContext,
        expandDistance: CGFloat,
        freezeProgress: Bool,
        absoluteRect: CGRect,
        absoluteSize: CGSize,
        wallpaperNode: WallpaperBackgroundNode?
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.peer = peer
        self.unreadCount = unreadCount
        self.location = location
        self.context = context
        self.expandDistance = expandDistance
        self.freezeProgress = freezeProgress
        self.absoluteRect = absoluteRect
        self.absoluteSize = absoluteSize
        self.wallpaperNode = wallpaperNode
    }

    static func ==(lhs: ChatOverscrollControl, rhs: ChatOverscrollControl) -> Bool {
        if !lhs.backgroundColor.isEqual(rhs.backgroundColor) {
            return false
        }
        if !lhs.foregroundColor.isEqual(rhs.foregroundColor) {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.unreadCount != rhs.unreadCount {
            return false
        }
        if lhs.location != rhs.location {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.expandDistance != rhs.expandDistance {
            return false
        }
        if lhs.freezeProgress != rhs.freezeProgress {
            return false
        }
        if lhs.absoluteRect != rhs.absoluteRect {
            return false
        }
        if lhs.absoluteSize != rhs.absoluteSize {
            return false
        }
        if lhs.wallpaperNode !== rhs.wallpaperNode {
            return false
        }
        return true
    }

    static var body: Body {
        let contents = Child(OverscrollContentsComponent.self)

        return { context in
            let contents = contents.update(
                component: OverscrollContentsComponent(
                    context: context.component.context,
                    backgroundColor: context.component.backgroundColor,
                    foregroundColor: context.component.foregroundColor,
                    peer: context.component.peer,
                    unreadCount: context.component.unreadCount,
                    location: context.component.location,
                    expandOffset: context.component.expandDistance,
                    freezeProgress: context.component.freezeProgress,
                    absoluteRect: context.component.absoluteRect,
                    absoluteSize: context.component.absoluteSize,
                    wallpaperNode: context.component.wallpaperNode
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )

            let size = CGSize(width: context.availableSize.width, height: contents.size.height)

            context.add(contents
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
            )

            return size
        }
    }
}

final class ChatInputPanelOverscrollNode: ASDisplayNode {
    let text: (String, [(Int, NSRange)])
    let priority: Int
    private let titleNode: ImmediateTextNode

    init(text: (String, [(Int, NSRange)]), color: UIColor, priority: Int) {
        self.text = text
        self.priority = priority
        self.titleNode = ImmediateTextNode()

        super.init()

        let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: color)
        let bold = MarkdownAttributeSet(font: Font.bold(14.0), textColor: color)

        self.titleNode.attributedText = addAttributesToStringWithRanges(text, body: body, argumentAttributes: [0: bold])

        self.addSubnode(self.titleNode)
    }

    func update(size: CGSize) {
        let titleSize = self.titleNode.updateLayout(size)
        self.titleNode.frame = titleSize.centered(in: CGRect(origin: CGPoint(), size: size))
    }
}
