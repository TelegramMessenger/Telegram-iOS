import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit

private final class RoundedRectangle: Component {
    let color: UIColor

    init(color: UIColor) {
        self.color = color
    }

    static func ==(lhs: RoundedRectangle, rhs: RoundedRectangle) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        return true
    }

    final class View: UIView {
        private let backgroundView: UIImageView

        private var currentColor: UIColor?
        private var currentDiameter: CGFloat?

        init() {
            self.backgroundView = UIImageView()

            super.init(frame: CGRect())

            self.addSubview(self.backgroundView)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: RoundedRectangle, availableSize: CGSize, transition: Transition) -> CGSize {
            let shadowInset: CGFloat = 0.0
            let diameter = min(availableSize.width, availableSize.height)

            var updated = false
            if let currentColor = self.currentColor {
                if !component.color.isEqual(currentColor) {
                    updated = true
                }
            } else {
                updated = true
            }

            if self.currentDiameter != diameter || updated {
                self.currentDiameter = diameter
                self.currentColor = component.color

                self.backgroundView.image = generateImage(CGSize(width: diameter + shadowInset * 2.0, height: diameter + shadowInset * 2.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))

                    context.setFillColor(component.color.cgColor)

                    context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowInset, y: shadowInset), size: CGSize(width: size.width - shadowInset * 2.0, height: size.height - shadowInset * 2.0)))
                })?.stretchableImage(withLeftCapWidth: Int(diameter + shadowInset * 2.0) / 2, topCapHeight: Int(diameter + shadowInset * 2.0) / 2)
            }

            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: -shadowInset, y: -shadowInset), size: CGSize(width: availableSize.width + shadowInset * 2.0, height: availableSize.height + shadowInset * 2.0)))

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

private final class ShadowRoundedRectangle: Component {
    let color: UIColor

    init(color: UIColor) {
        self.color = color
    }

    static func ==(lhs: ShadowRoundedRectangle, rhs: ShadowRoundedRectangle) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        return true
    }

    final class View: UIView {
        private let backgroundView: UIImageView

        private var currentColor: UIColor?
        private var currentDiameter: CGFloat?

        init() {
            self.backgroundView = UIImageView()

            super.init(frame: CGRect())

            self.addSubview(self.backgroundView)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: ShadowRoundedRectangle, availableSize: CGSize, transition: Transition) -> CGSize {
            let shadowInset: CGFloat = 10.0
            let diameter = min(availableSize.width, availableSize.height)

            var updated = false
            if let currentColor = self.currentColor {
                if !component.color.isEqual(currentColor) {
                    updated = true
                }
            } else {
                updated = true
            }

            if self.currentDiameter != diameter || updated {
                self.currentDiameter = diameter
                self.currentColor = component.color

                self.backgroundView.image = generateImage(CGSize(width: diameter + shadowInset * 2.0, height: diameter + shadowInset * 2.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))

                    context.setFillColor(component.color.cgColor)
                    context.setShadow(offset: CGSize(width: 0.0, height: -2.0), blur: 5.0, color: UIColor(white: 0.0, alpha: 0.3).cgColor)

                    context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowInset, y: shadowInset), size: CGSize(width: size.width - shadowInset * 2.0, height: size.height - shadowInset * 2.0)))
                })?.stretchableImage(withLeftCapWidth: Int(diameter + shadowInset * 2.0) / 2, topCapHeight: Int(diameter + shadowInset * 2.0) / 2)
            }

            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: -shadowInset, y: -shadowInset), size: CGSize(width: availableSize.width + shadowInset * 2.0, height: availableSize.height + shadowInset * 2.0)))

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

private final class SparseItemGridScrollingIndicatorComponent: CombinedComponent {
    let backgroundColor: UIColor
    let shadowColor: UIColor
    let foregroundColor: UIColor
    let dateString: String

    init(
        backgroundColor: UIColor,
        shadowColor: UIColor,
        foregroundColor: UIColor,
        dateString: String
    ) {
        self.backgroundColor = backgroundColor
        self.shadowColor = shadowColor
        self.foregroundColor = foregroundColor
        self.dateString = dateString
    }

    static func ==(lhs: SparseItemGridScrollingIndicatorComponent, rhs: SparseItemGridScrollingIndicatorComponent) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.shadowColor != rhs.shadowColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.dateString != rhs.dateString {
            return false
        }
        return true
    }

    static var body: Body {
        let rect = Child(ShadowRoundedRectangle.self)
        let text = Child(Text.self)

        return { context in
            let text = text.update(
                component: Text(
                    text: context.component.dateString,
                    font: Font.medium(13.0),
                    color: .black
                ),
                availableSize: CGSize(width: 200.0, height: 100.0),
                transition: .immediate
            )

            let rect = rect.update(
                component: ShadowRoundedRectangle(
                    color: .white
                ),
                availableSize: CGSize(width: text.size.width + 26.0, height: 32.0),
                transition: .immediate
            )

            let rectFrame = rect.size.centered(around: CGPoint(
                x: rect.size.width / 2.0,
                y: rect.size.height / 2.0
            ))

            context.add(rect
                .position(CGPoint(x: rectFrame.midX, y: rectFrame.midY))
            )

            let textFrame = text.size.centered(in: rectFrame)
            context.add(text
                .position(CGPoint(x: textFrame.midX, y: textFrame.midY))
            )

            return rect.size
        }
    }
}

public final class SparseItemGridScrollingArea: ASDisplayNode {
    private final class DragGesture: UIGestureRecognizer {
        private let shouldBegin: (CGPoint) -> Bool
        private let began: () -> Void
        private let ended: () -> Void
        private let moved: (CGFloat) -> Void

        private var initialLocation: CGPoint?

        public init(
            shouldBegin: @escaping (CGPoint) -> Bool,
            began: @escaping () -> Void,
            ended: @escaping () -> Void,
            moved: @escaping (CGFloat) -> Void
        ) {
            self.shouldBegin = shouldBegin
            self.began = began
            self.ended = ended
            self.moved = moved

            super.init(target: nil, action: nil)
        }

        deinit {
        }

        override public func reset() {
            super.reset()

            self.initialLocation = nil
            self.initialLocation = nil
        }

        override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)

            if self.numberOfTouches > 1 {
                self.state = .failed
                self.ended()
                return
            }

            if self.state == .possible {
                if let location = touches.first?.location(in: self.view) {
                    if self.shouldBegin(location) {
                        self.initialLocation = location
                        self.state = .began
                        self.began()
                    } else {
                        self.state = .failed
                    }
                } else {
                    self.state = .failed
                }
            }
        }

        override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesEnded(touches, with: event)

            self.initialLocation = nil

            if self.state == .began || self.state == .changed {
                self.ended()
                self.state = .failed
            }
        }

        override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesCancelled(touches, with: event)

            self.initialLocation = nil

            if self.state == .began || self.state == .changed {
                self.ended()
                self.state = .failed
            }
        }

        override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesMoved(touches, with: event)

            if (self.state == .began || self.state == .changed), let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) {
                self.state = .changed
                let offset = location.y - initialLocation.y
                self.moved(offset)
            }
        }
    }

    private let dateIndicator: ComponentHostView<Empty>

    private let lineIndicator: ComponentHostView<Empty>
    private var indicatorPosition: CGFloat?
    private var scrollIndicatorHeight: CGFloat?

    private var dragGesture: DragGesture?
    public private(set) var isDragging: Bool = false

    private weak var draggingScrollView: UIScrollView?
    private var scrollingInitialOffset: CGFloat?

    private var activityTimer: SwiftSignalKit.Timer?

    public var beginScrolling: (() -> UIScrollView?)?

    private struct ProjectionData {
        var minY: CGFloat
        var maxY: CGFloat
        var indicatorHeight: CGFloat
        var scrollableHeight: CGFloat
    }
    private var projectionData: ProjectionData?

    override public init() {
        self.dateIndicator = ComponentHostView<Empty>()
        self.lineIndicator = ComponentHostView<Empty>()

        self.dateIndicator.alpha = 0.0
        self.lineIndicator.alpha = 0.0

        super.init()

        self.view.addSubview(self.dateIndicator)
        self.view.addSubview(self.lineIndicator)

        let dragGesture = DragGesture(
            shouldBegin: { [weak self] point in
                guard let strongSelf = self else {
                    return false
                }
                if !strongSelf.dateIndicator.frame.contains(point) {
                    return false
                }

                return true
            },
            began: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.1, curve: .easeInOut)
                transition.updateSublayerTransformOffset(layer: strongSelf.dateIndicator.layer, offset: CGPoint(x: -80.0, y: 0.0))

                strongSelf.isDragging = true

                strongSelf.updateLineIndicator(transition: transition)

                if let scrollView = strongSelf.beginScrolling?() {
                    strongSelf.draggingScrollView = scrollView
                    strongSelf.scrollingInitialOffset = scrollView.contentOffset.y
                    scrollView.setContentOffset(scrollView.contentOffset, animated: false)
                }

                strongSelf.updateActivityTimer()
            },
            ended: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.draggingScrollView = nil

                let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                transition.updateSublayerTransformOffset(layer: strongSelf.dateIndicator.layer, offset: CGPoint(x: 0.0, y: 0.0))

                strongSelf.isDragging = false

                strongSelf.updateLineIndicator(transition: transition)

                strongSelf.updateActivityTimer()
            },
            moved: { [weak self] relativeOffset in
                guard let strongSelf = self else {
                    return
                }
                guard let scrollView = strongSelf.draggingScrollView, let scrollingInitialOffset = strongSelf.scrollingInitialOffset else {
                    return
                }
                guard let projectionData = strongSelf.projectionData else {
                    return
                }

                let indicatorArea = projectionData.maxY - projectionData.minY
                let scrollFraction = projectionData.scrollableHeight / indicatorArea

                var offset = scrollingInitialOffset + scrollFraction * relativeOffset
                if offset < 0.0 {
                    offset = 0.0
                }
                if offset > scrollView.contentSize.height - scrollView.bounds.height {
                    offset = scrollView.contentSize.height - scrollView.bounds.height
                }

                scrollView.setContentOffset(CGPoint(x: 0.0, y: offset), animated: false)
                let _ = scrollView
                let _ = projectionData
            }
        )
        self.dragGesture = dragGesture

        self.view.addGestureRecognizer(dragGesture)
    }

    public func update(
        containerSize: CGSize,
        containerInsets: UIEdgeInsets,
        contentHeight: CGFloat,
        contentOffset: CGFloat,
        isScrolling: Bool,
        dateString: String,
        transition: ContainedViewLayoutTransition
    ) {
        if isScrolling {
            self.updateActivityTimer()
        }

        let indicatorSize = self.dateIndicator.update(
            transition: .immediate,
            component: AnyComponent(SparseItemGridScrollingIndicatorComponent(
                backgroundColor: .white,
                shadowColor: .black,
                foregroundColor: .black,
                dateString: dateString
            )),
            environment: {},
            containerSize: containerSize
        )

        let scrollIndicatorHeightFraction = min(1.0, max(0.0, (containerSize.height - containerInsets.top - containerInsets.bottom) / contentHeight))
        if scrollIndicatorHeightFraction >= 1.0 - .ulpOfOne {
            self.dateIndicator.isHidden = true
            self.lineIndicator.isHidden = true
        } else {
            self.dateIndicator.isHidden = false
            self.lineIndicator.isHidden = false
        }

        let indicatorVerticalInset: CGFloat = 3.0
        let topIndicatorInset: CGFloat = indicatorVerticalInset
        let bottomIndicatorInset: CGFloat = indicatorVerticalInset + containerInsets.bottom

        let scrollIndicatorHeight = max(35.0, ceil(scrollIndicatorHeightFraction * containerSize.height))

        let indicatorPositionFraction = min(1.0, max(0.0, contentOffset / (contentHeight - containerSize.height)))

        let indicatorTopPosition = topIndicatorInset
        let indicatorBottomPosition = containerSize.height - bottomIndicatorInset - scrollIndicatorHeight

        let dateIndicatorTopPosition = topIndicatorInset
        let dateIndicatorBottomPosition = containerSize.height - bottomIndicatorInset - indicatorSize.height

        self.indicatorPosition = indicatorTopPosition * (1.0 - indicatorPositionFraction) + indicatorBottomPosition * indicatorPositionFraction
        self.scrollIndicatorHeight = scrollIndicatorHeight

        let dateIndicatorPosition = dateIndicatorTopPosition * (1.0 - indicatorPositionFraction) + dateIndicatorBottomPosition * indicatorPositionFraction

        self.projectionData = ProjectionData(
            minY: dateIndicatorTopPosition,
            maxY: dateIndicatorBottomPosition,
            indicatorHeight: indicatorSize.height,
            scrollableHeight: contentHeight - containerSize.height
        )

        transition.updateFrame(view: self.dateIndicator, frame: CGRect(origin: CGPoint(x: containerSize.width - 12.0 - indicatorSize.width, y: dateIndicatorPosition), size: indicatorSize))
        if isScrolling {
            self.dateIndicator.alpha = 1.0
            self.lineIndicator.alpha = 1.0
        }

        self.updateLineIndicator(transition: transition)
    }

    private func updateLineIndicator(transition: ContainedViewLayoutTransition) {
        guard let indicatorPosition = self.indicatorPosition, let scrollIndicatorHeight = self.scrollIndicatorHeight else {
            return
        }

        let lineIndicatorSize = CGSize(width: self.isDragging ? 6.0 : 3.0, height: scrollIndicatorHeight)
        let _ = self.lineIndicator.update(
            transition: .immediate,
            component: AnyComponent(RoundedRectangle(
                color: UIColor(white: 0.0, alpha: 0.3)
            )),
            environment: {},
            containerSize: lineIndicatorSize
        )

        transition.updateFrame(view: self.lineIndicator, frame: CGRect(origin: CGPoint(x: self.bounds.size.width - 3.0 - lineIndicatorSize.width, y: indicatorPosition), size: lineIndicatorSize))
    }

    private func updateActivityTimer() {
        self.activityTimer?.invalidate()

        if self.isDragging {
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)
            transition.updateAlpha(layer: self.dateIndicator.layer, alpha: 1.0)
            transition.updateAlpha(layer: self.lineIndicator.layer, alpha: 1.0)
        } else {
            self.activityTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)
                transition.updateAlpha(layer: strongSelf.dateIndicator.layer, alpha: 0.0)
                transition.updateAlpha(layer: strongSelf.lineIndicator.layer, alpha: 0.0)
            }, queue: .mainQueue())
            self.activityTimer?.start()
        }
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.dateIndicator.frame.contains(point) {
            return super.hitTest(point, with: event)
        }

        return nil
    }
}
