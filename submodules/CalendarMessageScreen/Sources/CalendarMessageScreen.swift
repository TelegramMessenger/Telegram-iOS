import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import ComponentFlow
import PhotoResources

private final class MediaPreviewView: UIView {
    private let context: AccountContext
    private let message: EngineMessage
    private let media: EngineMedia

    private let imageView: TransformImageView

    private var requestedImage: Bool = false
    private var disposable: Disposable?

    init(context: AccountContext, message: EngineMessage, media: EngineMedia) {
        self.context = context
        self.message = message
        self.media = media

        self.imageView = TransformImageView()

        super.init(frame: CGRect())

        self.addSubview(self.imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable?.dispose()
    }

    func updateLayout(size: CGSize, synchronousLoads: Bool) {
        var dimensions = CGSize(width: 100.0, height: 100.0)
        if case let .image(image) = self.media {
            if let largest = largestImageRepresentation(image.representations) {
                dimensions = largest.dimensions.cgSize
                if !self.requestedImage {
                    self.requestedImage = true
                    let signal = mediaGridMessagePhoto(account: self.context.account, photoReference: .message(message: MessageReference(self.message._asMessage()), media: image), fullRepresentationSize: CGSize(width: 36.0, height: 36.0), synchronousLoad: synchronousLoads)
                    self.imageView.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            }
        } else if case let .file(file) = self.media {
            if let mediaDimensions = file.dimensions {
                dimensions = mediaDimensions.cgSize
                if !self.requestedImage {
                    self.requestedImage = true
                    let signal = mediaGridMessageVideo(postbox: self.context.account.postbox, videoReference: .message(message: MessageReference(self.message._asMessage()), media: file), synchronousLoad: synchronousLoads, autoFetchFullSizeThumbnail: true, useMiniThumbnailIfAvailable: true)
                    self.imageView.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            }
        }

        let makeLayout = self.imageView.asyncLayout()
        self.imageView.frame = CGRect(origin: CGPoint(), size: size)
        let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: size.width / 2.0), imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
        apply()
    }
}

private func monthName(index: Int, strings: PresentationStrings) -> String {
    switch index {
    case 0:
        return strings.Month_GenJanuary
    case 1:
        return strings.Month_GenFebruary
    case 2:
        return strings.Month_GenMarch
    case 3:
        return strings.Month_GenApril
    case 4:
        return strings.Month_GenMay
    case 5:
        return strings.Month_GenJune
    case 6:
        return strings.Month_GenJuly
    case 7:
        return strings.Month_GenAugust
    case 8:
        return strings.Month_GenSeptember
    case 9:
        return strings.Month_GenOctober
    case 10:
        return strings.Month_GenNovember
    case 11:
        return strings.Month_GenDecember
    default:
        return ""
    }
}

private func dayName(index: Int, strings: PresentationStrings) -> String {
    let _ = strings
    //TODO:localize

    switch index {
    case 0:
        return "M"
    case 1:
        return "T"
    case 2:
        return "W"
    case 3:
        return "T"
    case 4:
        return "F"
    case 5:
        return "S"
    case 6:
        return "S"
    default:
        return ""
    }
}

private class Scroller: UIScrollView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }

    @objc func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

private final class ImageCache: Equatable {
    static func ==(lhs: ImageCache, rhs: ImageCache) -> Bool {
        return lhs === rhs
    }

    private struct FilledCircle: Hashable {
        var diameter: CGFloat
        var color: UInt32
    }

    private struct Text: Hashable {
        var fontSize: CGFloat
        var isSemibold: Bool
        var color: UInt32
        var string: String
    }

    private var items: [AnyHashable: UIImage] = [:]

    func filledCircle(diameter: CGFloat, color: UIColor) -> UIImage {
        let key = AnyHashable(FilledCircle(diameter: diameter, color: color.argb))
        if let image = self.items[key] {
            return image
        }
        let image = generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))

            context.setFillColor(color.cgColor)

            context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        })!.stretchableImage(withLeftCapWidth: Int(diameter) / 2, topCapHeight: Int(diameter) / 2)
        self.items[key] = image
        return image
    }

    func text(fontSize: CGFloat, isSemibold: Bool, color: UIColor, string: String) -> UIImage {
        let key = AnyHashable(Text(fontSize: fontSize, isSemibold: isSemibold, color: color.argb, string: string))
        if let image = self.items[key] {
            return image
        }

        let font: UIFont
        if isSemibold {
            font = Font.semibold(fontSize)
        } else {
            font = Font.regular(fontSize)
        }
        let attributedString = NSAttributedString(string: string, font: font, textColor: color)
        let rect = attributedString.boundingRect(with: CGSize(width: 1000.0, height: 1000.0), options: .usesLineFragmentOrigin, context: nil)
        let image = generateImage(CGSize(width: ceil(rect.width), height: ceil(rect.height)), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))

            UIGraphicsPushContext(context)
            attributedString.draw(in: rect)
            UIGraphicsPopContext()
        })!
        self.items[key] = image
        return image
    }
}

private final class DayComponent: Component {
    typealias EnvironmentType = ImageCache

    let title: String
    let isCurrent: Bool
    let isEnabled: Bool
    let theme: PresentationTheme
    let context: AccountContext
    let media: DayMedia?
    let action: () -> Void

    init(
        title: String,
        isCurrent: Bool,
        isEnabled: Bool,
        theme: PresentationTheme,
        context: AccountContext,
        media: DayMedia?,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isCurrent = isCurrent
        self.isEnabled = isEnabled
        self.theme = theme
        self.context = context
        self.media = media
        self.action = action
    }

    static func ==(lhs: DayComponent, rhs: DayComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isCurrent != rhs.isCurrent {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.media != rhs.media {
            return false
        }
        return true
    }

    final class View: UIView {
        private let button: HighlightableButton

        private let highlightView: UIImageView
        private let titleView: UIImageView
        private var mediaPreviewView: MediaPreviewView?

        private var action: (() -> Void)?
        private var currentMedia: DayMedia?

        private(set) var index: MessageIndex?

        init() {
            self.button = HighlightableButton()
            self.highlightView = UIImageView()
            self.highlightView.isUserInteractionEnabled = false
            self.titleView = UIImageView()
            self.titleView.isUserInteractionEnabled = false

            super.init(frame: CGRect())

            self.button.addSubview(self.highlightView)
            self.button.addSubview(self.titleView)

            self.addSubview(self.button)

            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        @objc private func pressed() {
            self.action?()
        }

        func update(component: DayComponent, availableSize: CGSize, environment: Environment<ImageCache>, transition: Transition) -> CGSize {
            self.action = component.action
            self.index = component.media?.message.index

            let diameter = min(availableSize.width, availableSize.height)
            let contentFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - diameter) / 2.0), y: floor((availableSize.height - diameter) / 2.0)), size: CGSize(width: diameter, height: diameter))

            let imageCache = environment[ImageCache.self]
            if component.media != nil {
                self.highlightView.image = imageCache.value.filledCircle(diameter: diameter, color: UIColor(white: 0.0, alpha: 0.2))
            } else if component.isCurrent {
                self.highlightView.image = imageCache.value.filledCircle(diameter: diameter, color: component.theme.list.itemAccentColor)
            } else {
                self.highlightView.image = nil
            }

            if self.currentMedia != component.media {
                self.currentMedia = component.media

                if let mediaPreviewView = self.mediaPreviewView {
                    self.mediaPreviewView = nil
                    mediaPreviewView.removeFromSuperview()
                }

                if let media = component.media {
                    let mediaPreviewView = MediaPreviewView(context: component.context, message: media.message, media: media.media)
                    mediaPreviewView.isUserInteractionEnabled = false
                    self.mediaPreviewView = mediaPreviewView
                    self.button.insertSubview(mediaPreviewView, belowSubview: self.highlightView)
                }
            }

            let titleColor: UIColor
            let titleFontSize: CGFloat
            let titleFontIsSemibold: Bool
            if component.isCurrent || component.media != nil {
                titleColor = component.theme.list.itemCheckColors.foregroundColor
                titleFontSize = 17.0
                titleFontIsSemibold = true
            } else if component.isEnabled {
                titleColor = component.theme.list.itemPrimaryTextColor
                titleFontSize = 17.0
                titleFontIsSemibold = false
            } else {
                titleColor = component.theme.list.itemDisabledTextColor
                titleFontSize = 17.0
                titleFontIsSemibold = false
            }

            let titleImage = imageCache.value.text(fontSize: titleFontSize, isSemibold: titleFontIsSemibold, color: titleColor, string: component.title)
            self.titleView.image = titleImage
            let titleSize = titleImage.size

            transition.setFrame(view: self.highlightView, frame: contentFrame)

            self.titleView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: floor((availableSize.height - titleSize.height) / 2.0)), size: titleSize)

            self.button.frame = CGRect(origin: CGPoint(), size: availableSize)
            self.button.isEnabled = component.isEnabled && component.media != nil

            if let mediaPreviewView = self.mediaPreviewView {
                mediaPreviewView.frame = contentFrame
                mediaPreviewView.updateLayout(size: contentFrame.size, synchronousLoads: false)
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, environment: Environment<ImageCache>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private final class MonthComponent: CombinedComponent {
    typealias EnvironmentType = ImageCache

    let context: AccountContext
    let model: MonthModel
    let foregroundColor: UIColor
    let strings: PresentationStrings
    let theme: PresentationTheme
    let navigateToDay: (Int32) -> Void

    init(
        context: AccountContext,
        model: MonthModel,
        foregroundColor: UIColor,
        strings: PresentationStrings,
        theme: PresentationTheme,
        navigateToDay: @escaping (Int32) -> Void
    ) {
        self.context = context
        self.model = model
        self.foregroundColor = foregroundColor
        self.strings = strings
        self.theme = theme
        self.navigateToDay = navigateToDay
    }

    static func ==(lhs: MonthComponent, rhs: MonthComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.model != rhs.model {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }

    static var body: Body {
        let title = Child(Text.self)
        let weekdayTitles = ChildMap(environment: Empty.self, keyedBy: Int.self)
        let days = ChildMap(environment: ImageCache.self, keyedBy: Int.self)

        return { context in
            let sideInset: CGFloat = 14.0
            let titleWeekdaysSpacing: CGFloat = 18.0
            let weekdayDaySpacing: CGFloat = 14.0
            let weekdaySize: CGFloat = 46.0
            let weekdaySpacing: CGFloat = 6.0

            let usableWeekdayWidth = floor((context.availableSize.width - sideInset * 2.0 - weekdaySpacing * 6.0) / 7.0)
            let weekdayWidth = floor((context.availableSize.width - sideInset * 2.0) / 7.0)

            let title = title.update(
                component: Text(
                    text: "\(monthName(index: context.component.model.index - 1, strings: context.component.strings)) \(context.component.model.year)",
                    font: Font.semibold(17.0),
                    color: .black
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 100.0),
                transition: .immediate
            )

            let updatedWeekdayTitles = (0 ..< 7).map { index in
                return weekdayTitles[index].update(
                    component: AnyComponent(Text(
                        text: dayName(index: index, strings: context.component.strings),
                        font: Font.regular(10.0),
                        color: .black
                    )),
                    availableSize: CGSize(width: 100.0, height: 100.0),
                    transition: .immediate
                )
            }

            let updatedDays = (0 ..< context.component.model.numberOfDays).map { index -> _UpdatedChildComponent in
                let dayOfMonth = index + 1
                let isCurrent = context.component.model.currentYear == context.component.model.year && context.component.model.currentMonth == context.component.model.index && context.component.model.currentDayOfMonth == dayOfMonth
                var isEnabled = true
                if context.component.model.currentYear == context.component.model.year {
                    if context.component.model.currentMonth == context.component.model.index {
                        if dayOfMonth > context.component.model.currentDayOfMonth {
                            isEnabled = false
                        }
                    } else if context.component.model.index > context.component.model.currentMonth {
                        isEnabled = false
                    }
                } else if context.component.model.year > context.component.model.currentYear {
                    isEnabled = false
                }

                let dayTimestamp = Int32(context.component.model.firstDay.timeIntervalSince1970) + 24 * 60 * 60 * Int32(index)
                let navigateToDay = context.component.navigateToDay

                return days[index].update(
                    component: AnyComponent(DayComponent(
                        title: "\(dayOfMonth)",
                        isCurrent: isCurrent,
                        isEnabled: isEnabled,
                        theme: context.component.theme,
                        context: context.component.context,
                        media: context.component.model.mediaByDay[index],
                        action: {
                            navigateToDay(dayTimestamp)
                        }
                    )),
                    environment: {
                        context.environment[ImageCache.self]
                    },
                    availableSize: CGSize(width: usableWeekdayWidth, height: weekdaySize),
                    transition: .immediate
                )
            }

            let titleFrame = CGRect(origin: CGPoint(x: floor((context.availableSize.width - title.size.width) / 2.0), y: 0.0), size: title.size)

            context.add(title
                .position(CGPoint(x: titleFrame.midX, y: titleFrame.midY))
            )

            let baseWeekdayTitleY = titleFrame.maxY + titleWeekdaysSpacing
            var maxWeekdayY = baseWeekdayTitleY

            for i in 0 ..< updatedWeekdayTitles.count {
                let weekdaySize = updatedWeekdayTitles[i].size
                let weekdayFrame = CGRect(origin: CGPoint(x: sideInset + CGFloat(i) * weekdayWidth + floor((weekdayWidth - weekdaySize.width) / 2.0), y: baseWeekdayTitleY), size: weekdaySize)
                maxWeekdayY = max(maxWeekdayY, weekdayFrame.maxY)
                context.add(updatedWeekdayTitles[i]
                    .position(CGPoint(x: weekdayFrame.midX, y: weekdayFrame.midY))
                )
            }

            let baseDayY = maxWeekdayY + weekdayDaySpacing
            var maxDayY = baseDayY

            for i in 0 ..< updatedDays.count {
                let gridIndex = (context.component.model.firstDayWeekday - 1) + i
                let gridX = sideInset + CGFloat(gridIndex % 7) * weekdayWidth
                let gridY = baseDayY + CGFloat(gridIndex / 7) * (weekdaySize + weekdaySpacing)
                let dayItemSize = updatedDays[i].size
                let dayFrame = CGRect(origin: CGPoint(x: gridX + floor((weekdayWidth - dayItemSize.width) / 2.0), y: gridY + floor((weekdaySize - dayItemSize.height) / 2.0)), size: dayItemSize)
                maxDayY = max(maxDayY, gridY + weekdaySize)
                context.add(updatedDays[i]
                    .position(CGPoint(x: dayFrame.midX, y: dayFrame.midY))
                )
            }

            return CGSize(width: context.availableSize.width, height: maxDayY)
        }
    }
}

private struct DayMedia: Equatable {
    var message: EngineMessage
    var media: EngineMedia

    static func ==(lhs: DayMedia, rhs: DayMedia) -> Bool {
        if lhs.message.id != rhs.message.id {
            return false
        }
        return true
    }
}

private struct MonthModel: Equatable {
    var year: Int
    var index: Int
    var numberOfDays: Int
    var firstDay: Date
    var firstDayWeekday: Int
    var currentYear: Int
    var currentMonth: Int
    var currentDayOfMonth: Int
    var mediaByDay: [Int: DayMedia]

    init(
        year: Int,
        index: Int,
        numberOfDays: Int,
        firstDay: Date,
        firstDayWeekday: Int,
        currentYear: Int,
        currentMonth: Int,
        currentDayOfMonth: Int,
        mediaByDay: [Int: DayMedia]
    ) {
        self.year = year
        self.index = index
        self.numberOfDays = numberOfDays
        self.firstDay = firstDay
        self.firstDayWeekday = firstDayWeekday
        self.currentYear = currentYear
        self.currentMonth = currentMonth
        self.currentDayOfMonth = currentDayOfMonth
        self.mediaByDay = mediaByDay
    }
}

private func monthMetadata(calendar: Calendar, for baseDate: Date, currentYear: Int, currentMonth: Int, currentDayOfMonth: Int) -> MonthModel? {
    guard let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: baseDate)?.count, let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: baseDate)) else {
        return nil
    }

    let year = calendar.component(.year, from: firstDayOfMonth)
    let month = calendar.component(.month, from: firstDayOfMonth)
    let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)

    return MonthModel(
        year: year,
        index: month,
        numberOfDays: numberOfDaysInMonth,
        firstDay: firstDayOfMonth,
        firstDayWeekday: firstDayWeekday,
        currentYear: currentYear,
        currentMonth: currentMonth,
        currentDayOfMonth: currentDayOfMonth,
        mediaByDay: [:]
    )
}

public final class CalendarMessageScreen: ViewController {
    private final class Node: ViewControllerTracingNode, UIScrollViewDelegate {
        private let context: AccountContext
        private let peerId: PeerId
        private let initialTimestamp: Int32
        private let navigateToDay: (Int32) -> Void
        private let previewDay: (MessageIndex, ASDisplayNode, CGRect, ContextGesture) -> Void

        private var presentationData: PresentationData
        private var scrollView: Scroller

        private let calendarSource: SparseMessageCalendar

        private var months: [MonthModel] = []
        private var monthViews: [Int: ComponentHostView<ImageCache>] = [:]
        private let contextGestureContainerNode: ContextControllerSourceNode

        private let imageCache = ImageCache()

        private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        private var scrollLayout: (width: CGFloat, contentHeight: CGFloat, frames: [Int: CGRect])?

        private var calendarState: SparseMessageCalendar.State?

        private var isLoadingMoreDisposable: Disposable?
        private var stateDisposable: Disposable?

        private weak var currentGestureDayView: DayComponent.View?

        init(context: AccountContext, peerId: PeerId, calendarSource: SparseMessageCalendar, initialTimestamp: Int32, navigateToDay: @escaping (Int32) -> Void, previewDay: @escaping (MessageIndex, ASDisplayNode, CGRect, ContextGesture) -> Void) {
            self.context = context
            self.peerId = peerId
            self.initialTimestamp = initialTimestamp
            self.calendarSource = calendarSource
            self.navigateToDay = navigateToDay
            self.previewDay = previewDay
            
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

            self.contextGestureContainerNode = ContextControllerSourceNode()

            self.scrollView = Scroller()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            if #available(iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            self.scrollView.layer.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
            self.scrollView.disablesInteractiveModalDismiss = true

            super.init()

            self.contextGestureContainerNode.shouldBegin = { [weak self] point in
                guard let strongSelf = self else {
                    return false
                }

                guard let result = strongSelf.contextGestureContainerNode.view.hitTest(point, with: nil) as? HighlightableButton else {
                    return false
                }

                guard let dayView = result.superview as? DayComponent.View else {
                    return false
                }

                strongSelf.currentGestureDayView = dayView

                return true
            }

            self.contextGestureContainerNode.customActivationProgress = { [weak self] progress, update in
                guard let strongSelf = self, let currentGestureDayView = strongSelf.currentGestureDayView else {
                    return
                }
                let itemLayer = currentGestureDayView.layer

                let targetContentRect = CGRect(origin: CGPoint(), size: itemLayer.bounds.size)

                let scaleSide = itemLayer.bounds.width
                let minScale: CGFloat = max(0.7, (scaleSide - 15.0) / scaleSide)
                let currentScale = 1.0 * (1.0 - progress) + minScale * progress

                let originalCenterOffsetX: CGFloat = itemLayer.bounds.width / 2.0 - targetContentRect.midX
                let scaledCenterOffsetX: CGFloat = originalCenterOffsetX * currentScale

                let originalCenterOffsetY: CGFloat = itemLayer.bounds.height / 2.0 - targetContentRect.midY
                let scaledCenterOffsetY: CGFloat = originalCenterOffsetY * currentScale

                let scaleMidX: CGFloat = scaledCenterOffsetX - originalCenterOffsetX
                let scaleMidY: CGFloat = scaledCenterOffsetY - originalCenterOffsetY

                switch update {
                case .update:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    itemLayer.sublayerTransform = sublayerTransform
                case .begin:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    itemLayer.sublayerTransform = sublayerTransform
                case .ended:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    let previousTransform = itemLayer.sublayerTransform
                    itemLayer.sublayerTransform = sublayerTransform

                    itemLayer.animate(from: NSValue(caTransform3D: previousTransform), to: NSValue(caTransform3D: sublayerTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                }
            }

            self.contextGestureContainerNode.activated = { [weak self] gesture, _ in
                guard let strongSelf = self, let currentGestureDayView = strongSelf.currentGestureDayView else {
                    return
                }
                strongSelf.currentGestureDayView = nil

                currentGestureDayView.isUserInteractionEnabled = false
                currentGestureDayView.isUserInteractionEnabled = true

                if let index = currentGestureDayView.index {
                    strongSelf.previewDay(index, strongSelf, currentGestureDayView.convert(currentGestureDayView.bounds, to: strongSelf.view), gesture)
                }
            }

            let calendar = Calendar(identifier: .gregorian)

            let baseDate = Date()
            let currentYear = calendar.component(.year, from: baseDate)
            let currentMonth = calendar.component(.month, from: baseDate)
            let currentDayOfMonth = calendar.component(.day, from: baseDate)

            for i in 0 ..< 12 * 20 {
                guard let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: baseDate)) else {
                    break
                }
                guard let monthBaseDate = calendar.date(byAdding: .month, value: -i, to: firstDayOfMonth) else {
                    break
                }

                guard let monthModel = monthMetadata(calendar: calendar, for: monthBaseDate, currentYear: currentYear, currentMonth: currentMonth, currentDayOfMonth: currentDayOfMonth) else {
                    break
                }

                let firstDayTimestamp = Int32(monthModel.firstDay.timeIntervalSince1970)
                let lastDayTimestamp = firstDayTimestamp + 24 * 60 * 60 * Int32(monthModel.numberOfDays)

                if let minTimestamp = calendarSource.minTimestamp, minTimestamp > lastDayTimestamp {
                    break
                }

                if monthModel.year < 2013 {
                    break
                }
                if monthModel.year == 2013 {
                    if monthModel.index < 8 {
                        break
                    }
                }

                self.months.append(monthModel)
            }

            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor

            self.scrollView.delegate = self
            self.addSubnode(self.contextGestureContainerNode)
            self.contextGestureContainerNode.view.addSubview(self.scrollView)

            self.isLoadingMoreDisposable = (self.calendarSource.isLoadingMore
            |> distinctUntilChanged
            |> filter { !$0 }
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.calendarSource.loadMore()
            })

            self.stateDisposable = (self.calendarSource.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.calendarState = state
                strongSelf.reloadMediaInfo()
            })
        }

        deinit {
            self.isLoadingMoreDisposable?.dispose()
            self.stateDisposable?.dispose()
        }

        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let isFirstLayout = self.validLayout == nil
            self.validLayout = (layout, navigationHeight)

            if self.updateScrollLayoutIfNeeded() {
            }

            if isFirstLayout {
                let initialDate = Date(timeIntervalSince1970: TimeInterval(self.initialTimestamp))
                var initialMonthIndex: Int?

                if self.months.count > 1 {
                    for i in 0 ..< self.months.count - 1 {
                        if initialDate >= self.months[i].firstDay {
                            initialMonthIndex = i
                            break
                        }
                    }
                }

                if isFirstLayout, let initialMonthIndex = initialMonthIndex, let frame = self.scrollLayout?.frames[initialMonthIndex] {
                    var contentOffset = floor(frame.midY - self.scrollView.bounds.height / 2.0)
                    if contentOffset < 0 {
                        contentOffset = 0
                    }
                    if contentOffset > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                        contentOffset = self.scrollView.contentSize.height - self.scrollView.bounds.height
                    }
                    self.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffset), animated: false)
                }
            }

            updateMonthViews()
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.contextGestureContainerNode.cancelGesture()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if let indicator = scrollView.value(forKey: "_verticalScrollIndicator") as? UIView {
                indicator.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
            }

            self.updateMonthViews()
        }

        func updateScrollLayoutIfNeeded() -> Bool {
            guard let (layout, navigationHeight) = self.validLayout else {
                return false
            }
            if self.scrollLayout?.width == layout.size.width {
                return false
            }

            var contentHeight: CGFloat = layout.intrinsicInsets.bottom
            var frames: [Int: CGRect] = [:]

            let measureView = ComponentHostView<ImageCache>()
            let imageCache = ImageCache()
            for i in 0 ..< self.months.count {
                let monthSize = measureView.update(
                    transition: .immediate,
                    component: AnyComponent(MonthComponent(
                        context: self.context,
                        model: self.months[i],
                        foregroundColor: .black,
                        strings: self.presentationData.strings,
                        theme: self.presentationData.theme,
                        navigateToDay: { _ in
                        }
                    )),
                    environment: {
                        imageCache
                    },
                    containerSize: CGSize(width: layout.size.width, height: 10000.0
                ))
                let monthFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: monthSize)
                contentHeight += monthSize.height
                if i != self.months.count {
                    contentHeight += 16.0
                }
                frames[i] = monthFrame
            }

            self.scrollLayout = (layout.size.width, contentHeight, frames)

            self.contextGestureContainerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationHeight))
            self.scrollView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: layout.size.height - navigationHeight))
            self.scrollView.contentSize = CGSize(width: layout.size.width, height: contentHeight)
            self.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: layout.intrinsicInsets.bottom, left: 0.0, bottom: 0.0, right: layout.size.width - 3.0 - 6.0)

            return true
        }

        func updateMonthViews() {
            guard let (width, _, frames) = self.scrollLayout else {
                return
            }

            let visibleRect = self.scrollView.bounds.insetBy(dx: 0.0, dy: -200.0)
            var validMonths = Set<Int>()

            for i in 0 ..< self.months.count {
                guard let monthFrame = frames[i] else {
                    continue
                }
                if !visibleRect.intersects(monthFrame) {
                    continue
                }
                validMonths.insert(i)

                let monthView: ComponentHostView<ImageCache>
                if let current = self.monthViews[i] {
                    monthView = current
                } else {
                    monthView = ComponentHostView()
                    monthView.layer.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
                    self.monthViews[i] = monthView
                    self.scrollView.addSubview(monthView)
                }
                let _ = monthView.update(
                    transition: .immediate,
                    component: AnyComponent(MonthComponent(
                        context: self.context,
                        model: self.months[i],
                        foregroundColor: self.presentationData.theme.list.itemPrimaryTextColor,
                        strings: self.presentationData.strings,
                        theme: self.presentationData.theme,
                        navigateToDay: { [weak self] timestamp in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.navigateToDay(timestamp)
                        }
                    )),
                    environment: {
                        self.imageCache
                    },
                    containerSize: CGSize(width: width, height: 10000.0
                ))
                monthView.frame = monthFrame
            }

            var removeMonths: [Int] = []
            for (index, view) in self.monthViews {
                if !validMonths.contains(index) {
                    view.removeFromSuperview()
                    removeMonths.append(index)
                }
            }
            for index in removeMonths {
                self.monthViews.removeValue(forKey: index)
            }
        }

        private func reloadMediaInfo() {
            guard let calendarState = self.calendarState else {
                return
            }
            var messageMap: [Message] = []
            for (_, message) in calendarState.messagesByDay {
                messageMap.append(message)
            }

            var updatedMedia: [Int: [Int: DayMedia]] = [:]
            for i in 0 ..< self.months.count {
                for day in 0 ..< self.months[i].numberOfDays {
                    let firstDayTimestamp = Int32(self.months[i].firstDay.timeIntervalSince1970)

                    let dayTimestamp = firstDayTimestamp + 24 * 60 * 60 * Int32(day)
                    let nextDayTimestamp = firstDayTimestamp + 24 * 60 * 60 * Int32(day - 1)

                    for message in messageMap {
                        if message.timestamp <= dayTimestamp && message.timestamp >= nextDayTimestamp {
                            mediaLoop: for media in message.media {
                                switch media {
                                case _ as TelegramMediaImage, _ as TelegramMediaFile:
                                    if updatedMedia[i] == nil {
                                        updatedMedia[i] = [:]
                                    }
                                    updatedMedia[i]![day] = DayMedia(message: EngineMessage(message), media: EngineMedia(media))
                                    break mediaLoop
                                default:
                                    break
                                }
                            }

                            break
                        }
                    }
                }
            }
            for (monthIndex, mediaByDay) in updatedMedia {
                self.months[monthIndex].mediaByDay = mediaByDay
            }

            self.updateMonthViews()
        }
    }

    private var node: Node {
        return self.displayNode as! Node
    }

    private let context: AccountContext
    private let peerId: PeerId
    private let calendarSource: SparseMessageCalendar
    private let initialTimestamp: Int32
    private let navigateToDay: (CalendarMessageScreen, Int32) -> Void
    private let previewDay: (MessageIndex, ASDisplayNode, CGRect, ContextGesture) -> Void

    public init(context: AccountContext, peerId: PeerId, calendarSource: SparseMessageCalendar, initialTimestamp: Int32, navigateToDay: @escaping (CalendarMessageScreen, Int32) -> Void, previewDay: @escaping (MessageIndex, ASDisplayNode, CGRect, ContextGesture) -> Void) {
        self.context = context
        self.peerId = peerId
        self.calendarSource = calendarSource
        self.initialTimestamp = initialTimestamp
        self.navigateToDay = navigateToDay
        self.previewDay = previewDay

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))

        self.navigationPresentation = .modal

        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(dismissPressed)), animated: false)
        //TODO:localize
        self.navigationItem.setTitle("Calendar", animated: false)
    }

    required public init(coder aDecoder: NSCoder) {
        preconditionFailure()
    }

    @objc private func dismissPressed() {
        self.dismiss()
    }

    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, peerId: self.peerId, calendarSource: self.calendarSource, initialTimestamp: self.initialTimestamp, navigateToDay: { [weak self] timestamp in
            guard let strongSelf = self else {
                return
            }
            strongSelf.navigateToDay(strongSelf, timestamp)
        }, previewDay: self.previewDay)

        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.node.containerLayoutUpdated(layout: layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
