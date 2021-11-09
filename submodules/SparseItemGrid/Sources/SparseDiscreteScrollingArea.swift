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

    private var dragGesture: DragGesture?
    public private(set) var isDragging: Bool = false

    private var activityTimer: SwiftSignalKit.Timer?

    public var openCurrentDate: (() -> Void)?

    private var offsetBarTimer: SwiftSignalKit.Timer?
    private let hapticFeedback = HapticFeedback()

    private var theme: PresentationTheme?

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

                /*if let scrollView = strongSelf.beginScrolling?() {
                    strongSelf.draggingScrollView = scrollView
                    strongSelf.scrollingInitialOffset = scrollView.contentOffset.y
                    strongSelf.setContentOffset?(scrollView.contentOffset)
                }*/

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

                //strongSelf.updateLineIndicator(transition: transition)

                strongSelf.updateActivityTimer(isScrolling: false)
            },
            moved: { [weak self] relativeOffset in
                guard let strongSelf = self else {
                    return
                }

                let _ = relativeOffset

                if strongSelf.offsetBarTimer != nil {
                    strongSelf.offsetBarTimer?.invalidate()
                    strongSelf.offsetBarTimer = nil
                    strongSelf.performOffsetBarTimerEvent()
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

    public func update(
        containerSize: CGSize,
        containerInsets: UIEdgeInsets,
        scrollingState: ListView.ScrollingIndicatorState?,
        isScrolling: Bool,
        theme: PresentationTheme,
        transition: ContainedViewLayoutTransition
    ) {
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
            let lineColor: UIColor
            if theme.overallDarkAppearance {
                lineColor = UIColor(white: 0.0, alpha: 0.3)
            } else {
                lineColor = UIColor(white: 0.0, alpha: 0.3)
            }
            self.lineIndicator.image = generateStretchableFilledCircleImage(diameter: 3.0, color: lineColor, strokeColor: nil, strokeWidth: nil, backgroundColor: nil)
        }

        if self.dateIndicator.alpha.isZero {
            let transition: ContainedViewLayoutTransition = .immediate
            transition.updateSublayerTransformOffset(layer: self.dateIndicator.layer, offset: CGPoint())
        }

        if isScrolling {
            self.updateActivityTimer(isScrolling: true)
        }

        let indicatorSize = self.dateIndicator.update(
            transition: .immediate,
            component: AnyComponent(SparseItemGridScrollingIndicatorComponent(
                backgroundColor: theme.list.itemBlocksBackgroundColor,
                shadowColor: .black,
                foregroundColor: theme.list.itemPrimaryTextColor,
                dateString: "Date"
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
                indicatorHeight = max(minIndicatorContentHeight, floor(visibleHeightWithoutIndicatorInsets * (containerSize.height - scrollingIndicatorState.insets.top - scrollingIndicatorState.insets.bottom) / approximateContentHeight))
            }

            let upperBound = containerInsets.top + indicatorTopInset
            let lowerBound = containerSize.height - containerInsets.bottom - indicatorTopInset - indicatorBottomInset - indicatorHeight

            let indicatorOffset = ceilToScreenPixels(upperBound * (1.0 - approximateScrollingProgress) + lowerBound * approximateScrollingProgress)

            //var indicatorFrame = CGRect(origin: CGPoint(x: self.rotated ? indicatorSideInset : (self.visibleSize.width - 3.0 - indicatorSideInset), y: indicatorOffset), size: CGSize(width: 3.0, height: indicatorHeight))

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

            if indicatorHeight >= visibleHeightWithoutIndicatorInsets {
                self.lineIndicator.isHidden = true
                self.lineIndicator.frame = indicatorFrame
            } else {
                if self.lineIndicator.isHidden {
                    self.lineIndicator.isHidden = false
                    self.lineIndicator.frame = indicatorFrame
                } else {
                    self.lineIndicator.frame = indicatorFrame
                }
            }
        } else {
            self.lineIndicator.isHidden = true
        }
    }

    private func updateActivityTimer(isScrolling: Bool) {
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
        if self.lineIndicator.alpha <= 0.01 {
            return nil
        }
        if self.lineIndicator.frame.insetBy(dx: -4.0, dy: -2.0).contains(point) {
            return super.hitTest(point, with: event)
        }

        return nil
    }
}
