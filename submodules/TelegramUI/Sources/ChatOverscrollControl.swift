import UIKit
import ComponentFlow
import Display
import TelegramCore
import Postbox
import AccountContext
import AvatarNode

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
        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: CheckComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            func draw(context: CGContext) {
                let size = availableSize

                let diameter = size.width

                let factor = diameter / 50.0

                context.saveGState()

                context.setBlendMode(.normal)
                context.setFillColor(component.color.cgColor)
                context.setStrokeColor(component.color.cgColor)

                let center = CGPoint(x: diameter / 2.0, y: diameter / 2.0)

                let lineWidth = component.lineWidth

                context.setLineWidth(max(1.7, lineWidth * factor))
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.setMiterLimit(10.0)

                let progress = component.value
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

final class AvatarComponent: Component {
    let context: AccountContext
    let peer: EnginePeer

    init(context: AccountContext, peer: EnginePeer) {
        self.context = context
        self.peer = peer
    }

    static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode

        init() {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))

            super.init(frame: CGRect())

            self.addSubview(self.avatarNode.view)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: AvatarComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.avatarNode.frame = CGRect(origin: CGPoint(), size: availableSize)
            self.avatarNode.setPeer(context: component.context, theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme, peer: component.peer, synchronousLoad: true)

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

final class ChatOverscrollControl: CombinedComponent {
    let text: String
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let peer: EnginePeer?
    let context: AccountContext
    let expandProgress: CGFloat

    init(
        text: String,
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        peer: EnginePeer?,
        context: AccountContext,
        expandProgress: CGFloat
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.peer = peer
        self.context = context
        self.expandProgress = expandProgress
    }

    static func ==(lhs: ChatOverscrollControl, rhs: ChatOverscrollControl) -> Bool {
        if lhs.text != rhs.text {
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
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.expandProgress != rhs.expandProgress {
            return false
        }
        return true
    }

    static var body: Body {
        let avatarBackground = Child(BlurredRoundedRectangle.self)
        let avatarExpandProgress = Child(RadialProgressComponent.self)
        let avatarCheck = Child(CheckComponent.self)
        let avatar = Child(AvatarComponent.self)
        let textBackground = Child(BlurredRoundedRectangle.self)
        let text = Child(Text.self)

        return { context in
            let text = text.update(
                component: Text(
                    text: context.component.text,
                    font: Font.regular(12.0),
                    color: context.component.foregroundColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: 100.0),
                transition: context.transition
            )

            let textHorizontalPadding: CGFloat = 6.0
            let textVerticalPadding: CGFloat = 2.0
            let avatarSize: CGFloat = 48.0
            let avatarPadding: CGFloat = 8.0
            let avatarTextSpacing: CGFloat = 8.0
            let avatarProgressPadding: CGFloat = 2.5

            let avatarBackgroundSize: CGFloat = context.component.peer != nil ? (avatarSize + avatarPadding * 2.0) : avatarSize

            let avatarBackground = avatarBackground.update(
                component: BlurredRoundedRectangle(
                    color: context.component.backgroundColor
                ),
                availableSize: CGSize(width: avatarBackgroundSize, height: avatarBackgroundSize),
                transition: context.transition
            )

            let avatarCheck = Condition(context.component.peer == nil, { () -> _UpdatedChildComponent in
                let avatarCheckSize = avatarBackgroundSize + 2.0

                return avatarCheck.update(
                    component: CheckComponent(
                        color: context.component.foregroundColor,
                        lineWidth: 2.5,
                        value: 1.0
                    ),
                    availableSize: CGSize(width: avatarCheckSize, height: avatarCheckSize),
                    transition: context.transition
                )
            })

            let avatarExpandProgress = avatarExpandProgress.update(
                component: RadialProgressComponent(
                    color: context.component.foregroundColor,
                    lineWidth: 2.5,
                    value: context.component.peer == nil ? 0.0 : context.component.expandProgress
                ),
                availableSize: CGSize(width: avatarBackground.size.width - avatarProgressPadding * 2.0, height: avatarBackground.size.height - avatarProgressPadding * 2.0),
                transition: context.transition
            )

            let textBackground = textBackground.update(
                component: BlurredRoundedRectangle(
                    color: context.component.backgroundColor
                ),
                availableSize: CGSize(width: text.size.width + textHorizontalPadding * 2.0, height: text.size.height + textVerticalPadding * 2.0),
                transition: context.transition
            )

            let size = CGSize(width: context.availableSize.width, height: avatarBackground.size.height + avatarTextSpacing + textBackground.size.height)

            let avatarBackgroundFrame = avatarBackground.size.topCentered(in: CGRect(origin: CGPoint(), size: size))

            let avatar = context.component.peer.flatMap { peer in
                avatar.update(
                    component: AvatarComponent(
                        context: context.component.context,
                        peer: peer
                    ),
                    availableSize: CGSize(width: avatarSize, height: avatarSize),
                    transition: context.transition
                )
            }

            context.add(avatarBackground
                .position(CGPoint(
                    x: avatarBackgroundFrame.midX,
                    y: avatarBackgroundFrame.midY
                ))
            )

            if let avatarCheck = avatarCheck {
                context.add(avatarCheck
                    .position(CGPoint(
                        x: avatarBackgroundFrame.midX,
                        y: avatarBackgroundFrame.midY
                    ))
                )
            }

            context.add(avatarExpandProgress
                .position(CGPoint(
                    x: avatarBackgroundFrame.midX,
                    y: avatarBackgroundFrame.midY
                ))
            )

            if let avatar = avatar {
                context.add(avatar
                    .position(CGPoint(
                        x: avatarBackgroundFrame.midX,
                        y: avatarBackgroundFrame.midY
                    ))
                )
            }

            let textBackgroundFrame = textBackground.size.bottomCentered(in: CGRect(origin: CGPoint(), size: size))
            context.add(textBackground
                .position(CGPoint(
                    x: textBackgroundFrame.midX,
                    y: textBackgroundFrame.midY
                ))
            )

            let textFrame = text.size.centered(in: textBackgroundFrame)
            context.add(text
                .position(CGPoint(
                    x: textFrame.midX,
                    y: textFrame.midY
                ))
            )

            return size
        }
    }
}
