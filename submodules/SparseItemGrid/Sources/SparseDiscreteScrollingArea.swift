import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import TelegramPresentationData

public final class SparseDiscreteScrollingArea: ASDisplayNode {
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
    private let lineIndicator: UIImageView

    private var containerSize: CGSize?
    private var indicatorPosition: CGFloat?
    private var scrollIndicatorHeight: CGFloat?
    private var scrollIndicatorRange: (CGFloat, CGFloat)?

    private var initialDraggingOffset: CGFloat?
    private var draggingOffset: CGFloat?

    private var dragGesture: DragGesture?
    public private(set) var isDragging: Bool = false

    private var activityTimer: SwiftSignalKit.Timer?

    public var openCurrentDate: (() -> Void)?

    public var navigateToPosition: ((Float) -> Void)?
    private var navigatingToPositionOffset: CGFloat?

    private var offsetBarTimer: SwiftSignalKit.Timer?
    private let hapticFeedback = HapticFeedback()

    private var theme: PresentationTheme?

    private struct State {
        var containerSize: CGSize
        var containerInsets: UIEdgeInsets
        var scrollingState: ListView.ScrollingIndicatorState?
        var isScrolling: Bool
        var isDragging: Bool
        var theme: PresentationTheme
    }

    private var state: State?

    override public init() {
        self.dateIndicator = ComponentHostView<Empty>()
        self.lineIndicator = UIImageView()

        self.dateIndicator.alpha = 0.0
        self.lineIndicator.alpha = 0.0

        super.init()

        self.dateIndicator.isUserInteractionEnabled = false
        self.lineIndicator.isUserInteractionEnabled = false

        self.view.addSubview(self.dateIndicator)
        self.view.addSubview(self.lineIndicator)

        let dragGesture = DragGesture(
            shouldBegin: { [weak self] point in
                guard let _ = self else {
                    return false
                }
                return true
            },
            began: { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                let offsetBarTimer = SwiftSignalKit.Timer(timeout: 0.2, repeat: false, completion: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.performOffsetBarTimerEvent()
                }, queue: .mainQueue())
                strongSelf.offsetBarTimer?.invalidate()
                strongSelf.offsetBarTimer = offsetBarTimer
                offsetBarTimer.start()

                strongSelf.isDragging = true
                strongSelf.initialDraggingOffset = strongSelf.lineIndicator.frame.minY
                strongSelf.draggingOffset = 0.0

                if let state = strongSelf.state {
                    strongSelf.update(
                        containerSize: state.containerSize,
                        containerInsets: state.containerInsets,
                        scrollingState: state.scrollingState,
                        isScrolling: state.isScrolling,
                        theme: state.theme,
                        transition: .animated(duration: 0.2, curve: .easeInOut)
                    )
                }

                strongSelf.updateActivityTimer(isScrolling: false)
            },
            ended: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.offsetBarTimer != nil {
                    strongSelf.offsetBarTimer?.invalidate()
                    strongSelf.offsetBarTimer = nil

                    strongSelf.openCurrentDate?()
                }

                let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                transition.updateSublayerTransformOffset(layer: strongSelf.dateIndicator.layer, offset: CGPoint(x: 0.0, y: 0.0))

                strongSelf.isDragging = false
                if let _ = strongSelf.initialDraggingOffset, let _ = strongSelf.draggingOffset, let scrollIndicatorRange = strongSelf.scrollIndicatorRange {
                    strongSelf.navigatingToPositionOffset = strongSelf.lineIndicator.frame.minY
                    var absoluteOffset = strongSelf.lineIndicator.frame.minY - scrollIndicatorRange.0
                    absoluteOffset /= (scrollIndicatorRange.1 - scrollIndicatorRange.0)
                    absoluteOffset = abs(absoluteOffset)
                    absoluteOffset = 1.0 - absoluteOffset
                    strongSelf.navigateToPosition?(Float(absoluteOffset))
                } else {
                    strongSelf.navigatingToPositionOffset = nil
                }
                strongSelf.initialDraggingOffset = nil
                strongSelf.draggingOffset = nil

                if let state = strongSelf.state {
                    strongSelf.update(
                        containerSize: state.containerSize,
                        containerInsets: state.containerInsets,
                        scrollingState: state.scrollingState,
                        isScrolling: state.isScrolling,
                        theme: state.theme,
                        transition: transition
                    )
                }

                strongSelf.updateActivityTimer(isScrolling: false)
            },
            moved: { [weak self] relativeOffset in
                guard let strongSelf = self else {
                    return
                }

                if strongSelf.offsetBarTimer != nil {
                    strongSelf.offsetBarTimer?.invalidate()
                    strongSelf.offsetBarTimer = nil
                    strongSelf.performOffsetBarTimerEvent()
                }

                strongSelf.draggingOffset = relativeOffset

                if let state = strongSelf.state {
                    strongSelf.update(
                        containerSize: state.containerSize,
                        containerInsets: state.containerInsets,
                        scrollingState: state.scrollingState,
                        isScrolling: state.isScrolling,
                        theme: state.theme,
                        transition: .immediate
                    )
                }
            }
        )
        self.dragGesture = dragGesture

        self.view.addGestureRecognizer(dragGesture)
    }

    private func performOffsetBarTimerEvent() {
        self.hapticFeedback.impact()
        self.offsetBarTimer = nil

        /*let transition: ContainedViewLayoutTransition = .animated(duration: 0.1, curve: .easeInOut)
        transition.updateSublayerTransformOffset(layer: self.dateIndicator.layer, offset: CGPoint(x: -80.0, y: 0.0))
        self.updateLineIndicator(transition: transition)*/
    }

    func feedbackTap() {
        self.hapticFeedback.tap()
    }

    public func resetNavigatingToPosition() {
        self.navigatingToPositionOffset = nil
        if let state = self.state {
            self.update(
                containerSize: state.containerSize,
                containerInsets: state.containerInsets,
                scrollingState: state.scrollingState,
                isScrolling: state.isScrolling,
                theme: state.theme,
                transition: .animated(duration: 0.2, curve: .easeInOut)
            )
        }
    }

    public func update(
        containerSize: CGSize,
        containerInsets: UIEdgeInsets,
        scrollingState: ListView.ScrollingIndicatorState?,
        isScrolling: Bool,
        theme: PresentationTheme,
        transition: ContainedViewLayoutTransition
    ) {
        let updateLineImage = self.state?.isDragging != self.isDragging || self.state?.theme !== theme

        self.state = State(
            containerSize: containerSize,
            containerInsets: containerInsets,
            scrollingState: scrollingState,
            isScrolling: isScrolling,
            isDragging: self.isDragging,
            theme: theme
        )

        self.containerSize = containerSize
        if self.theme !== theme {
            self.theme = theme

            /*var backgroundColors: [UInt32] = []
            switch chatPresentationInterfaceState.chatWallpaper {
            case let .file(file):
                if file.isPattern {
                    backgroundColors = file.settings.colors
                }
            case let .gradient(gradient):
                backgroundColors = gradient.colors
            case let .color(color):
                backgroundColors = [color]
            default:
                break
            }*/

        }

        if updateLineImage {
            let lineColor: UIColor
            if theme.overallDarkAppearance {
                lineColor = UIColor(white: 0.0, alpha: 0.3)
            } else {
                lineColor = UIColor(white: 0.0, alpha: 0.3)
            }
            if let image = generateStretchableFilledCircleImage(diameter: self.isDragging ? 6.0 : 3.0, color: lineColor, strokeColor: nil, strokeWidth: nil, backgroundColor: nil) {
                if transition.isAnimated, let previousImage = self.lineIndicator.image {
                    self.lineIndicator.image = image
                    self.lineIndicator.layer.animate(from: previousImage.cgImage!, to: image.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                } else {
                    self.lineIndicator.image = image
                }
            }
        }

        if self.dateIndicator.alpha.isZero {
            let transition: ContainedViewLayoutTransition = .immediate
            transition.updateSublayerTransformOffset(layer: self.dateIndicator.layer, offset: CGPoint())
        }

        self.updateActivityTimer(isScrolling: isScrolling)

        let indicatorSize = self.dateIndicator.update(
            transition: .immediate,
            component: AnyComponent(SparseItemGridScrollingIndicatorComponent(
                backgroundColor: theme.list.itemBlocksBackgroundColor,
                shadowColor: .black,
                foregroundColor: theme.list.itemPrimaryTextColor,
                date: ("Date", 0),
                previousDate: nil
            )),
            environment: {},
            containerSize: containerSize
        )
        let _ = indicatorSize

        self.dateIndicator.isHidden = true

        if let scrollingIndicatorState = scrollingState {
            let averageRangeItemHeight: CGFloat = 44.0

            let upperItemsHeight = floor(averageRangeItemHeight * CGFloat(scrollingIndicatorState.topItem.index))
            let approximateContentHeight = CGFloat(scrollingIndicatorState.itemCount) * averageRangeItemHeight

            var convertedTopBoundary: CGFloat
            if scrollingIndicatorState.topItem.offset < scrollingIndicatorState.insets.top {
                convertedTopBoundary = (scrollingIndicatorState.topItem.offset - scrollingIndicatorState.insets.top) * averageRangeItemHeight / scrollingIndicatorState.topItem.height
            } else {
                convertedTopBoundary = scrollingIndicatorState.topItem.offset - scrollingIndicatorState.insets.top
            }
            convertedTopBoundary -= upperItemsHeight

            let approximateOffset = -convertedTopBoundary

            var convertedBottomBoundary: CGFloat = 0.0
            if scrollingIndicatorState.bottomItem.offset > containerSize.height - scrollingIndicatorState.insets.bottom {
                convertedBottomBoundary = ((containerSize.height - scrollingIndicatorState.insets.bottom) - scrollingIndicatorState.bottomItem.offset) * averageRangeItemHeight / scrollingIndicatorState.bottomItem.height
            } else {
                convertedBottomBoundary = (containerSize.height - scrollingIndicatorState.insets.bottom) - scrollingIndicatorState.bottomItem.offset
            }
            convertedBottomBoundary += CGFloat(scrollingIndicatorState.bottomItem.index + 1) * averageRangeItemHeight

            let approximateVisibleHeight = max(0.0, convertedBottomBoundary - approximateOffset)

            let approximateScrollingProgress = approximateOffset / (approximateContentHeight - approximateVisibleHeight)

            let indicatorSideInset: CGFloat = 3.0
            let indicatorTopInset: CGFloat = 3.0
            /*if self.verticalScrollIndicatorFollowsOverscroll {
                if scrollingIndicatorState.topItem.index == 0 {
                    indicatorTopInset = max(scrollingIndicatorState.topItem.offset + 3.0 - self.insets.top, 3.0)
                }
            }*/
            let indicatorBottomInset: CGFloat = 3.0
            let minIndicatorContentHeight: CGFloat = 12.0
            let minIndicatorHeight: CGFloat = 6.0

            let visibleHeightWithoutIndicatorInsets = containerSize.height - containerInsets.top - containerInsets.bottom - indicatorTopInset - indicatorBottomInset
            let indicatorHeight: CGFloat
            if approximateContentHeight <= 0 {
                indicatorHeight = 0.0
            } else {
                indicatorHeight = max(minIndicatorContentHeight, 44.0)//max(minIndicatorContentHeight, floor(visibleHeightWithoutIndicatorInsets * (containerSize.height - scrollingIndicatorState.insets.top - scrollingIndicatorState.insets.bottom) / approximateContentHeight))
            }

            let upperBound = containerInsets.top + indicatorTopInset
            let lowerBound = containerSize.height - containerInsets.bottom - indicatorTopInset - indicatorBottomInset - indicatorHeight

            let indicatorOffset = ceilToScreenPixels(upperBound * (1.0 - approximateScrollingProgress) + lowerBound * approximateScrollingProgress)

            var indicatorFrame = CGRect(origin: CGPoint(x: containerSize.width - 3.0 - indicatorSideInset, y: indicatorOffset), size: CGSize(width: 3.0, height: indicatorHeight))

            if indicatorFrame.minY < containerInsets.top + indicatorTopInset {
                indicatorFrame.size.height -= containerInsets.top + indicatorTopInset - indicatorFrame.minY
                indicatorFrame.origin.y = containerInsets.top + indicatorTopInset
                indicatorFrame.size.height = max(minIndicatorHeight, indicatorFrame.height)
            }
            if indicatorFrame.maxY > containerSize.height - (containerInsets.bottom + indicatorTopInset + indicatorBottomInset) {
                indicatorFrame.size.height -= indicatorFrame.maxY - (containerSize.height - (containerInsets.bottom + indicatorTopInset))
                indicatorFrame.size.height = max(minIndicatorHeight, indicatorFrame.height)
                indicatorFrame.origin.y = containerSize.height - (containerInsets.bottom + indicatorBottomInset) - indicatorFrame.height
            }

            if indicatorFrame.origin.y.isNaN {
               indicatorFrame.origin.y = indicatorTopInset
            }

            indicatorFrame.origin.y = containerSize.height - indicatorFrame.origin.y - indicatorFrame.height

            if self.isDragging {
                indicatorFrame.origin.x -= 3.0
                indicatorFrame.size.width += 3.0
            }

            var alternativeOffset: CGFloat?
            if let navigatingToPositionOffset = self.navigatingToPositionOffset {
                alternativeOffset = navigatingToPositionOffset
            } else if let initialDraggingOffset = self.initialDraggingOffset, let draggingOffset = self.draggingOffset {
                alternativeOffset = initialDraggingOffset + draggingOffset
            }

            if let alternativeOffset = alternativeOffset {
                indicatorFrame.origin.y = alternativeOffset

                if indicatorFrame.origin.y > containerSize.height - (containerInsets.top + indicatorBottomInset) - indicatorFrame.height {
                    indicatorFrame.origin.y = containerSize.height - (containerInsets.top + indicatorBottomInset) - indicatorFrame.height
                }
                if indicatorFrame.origin.y < containerInsets.bottom + indicatorTopInset {
                    indicatorFrame.origin.y = containerInsets.bottom + indicatorTopInset
                }
            }

            transition.updateFrame(view: self.lineIndicator, frame: indicatorFrame)

            if indicatorHeight >= visibleHeightWithoutIndicatorInsets {
                self.lineIndicator.isHidden = true
            } else {
                self.lineIndicator.isHidden = false
            }

            self.scrollIndicatorRange = (
                containerInsets.bottom + indicatorTopInset,
                containerSize.height - (containerInsets.top + indicatorBottomInset) - self.lineIndicator.bounds.height
            )
        } else {
            self.lineIndicator.isHidden = true
            self.scrollIndicatorRange = nil
        }
    }

    private func updateActivityTimer(isScrolling: Bool) {
        if self.isDragging || isScrolling {
            self.activityTimer?.invalidate()
            self.activityTimer = nil

            let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)
            transition.updateAlpha(layer: self.dateIndicator.layer, alpha: 1.0)
            transition.updateAlpha(layer: self.lineIndicator.layer, alpha: 1.0)
        } else {
            if self.activityTimer == nil {
                self.activityTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.activityTimer = nil

                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)
                    transition.updateAlpha(layer: strongSelf.dateIndicator.layer, alpha: 0.0)
                    transition.updateAlpha(layer: strongSelf.lineIndicator.layer, alpha: 0.0)
                }, queue: .mainQueue())
                self.activityTimer?.start()
            }
        }
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.lineIndicator.alpha <= 0.01 {
            return nil
        }
        if self.lineIndicator.frame.insetBy(dx: -8.0, dy: -4.0).contains(point) {
            return super.hitTest(point, with: event)
        }

        return nil
    }
}
