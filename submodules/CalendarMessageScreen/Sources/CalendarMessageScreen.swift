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

private final class MediaPreviewNode: ASDisplayNode {
    private let context: AccountContext
    private let message: EngineMessage
    private let media: EngineMedia

    private let imageNode: TransformImageNode

    private var requestedImage: Bool = false
    private var disposable: Disposable?

    init(context: AccountContext, message: EngineMessage, media: EngineMedia) {
        self.context = context
        self.message = message
        self.media = media

        self.imageNode = TransformImageNode()

        super.init()

        self.addSubnode(self.imageNode)
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
                    self.imageNode.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            }
        } else if case let .file(file) = self.media {
            if let mediaDimensions = file.dimensions {
                dimensions = mediaDimensions.cgSize
                if !self.requestedImage {
                    self.requestedImage = true
                    let signal = mediaGridMessageVideo(postbox: self.context.account.postbox, videoReference: .message(message: MessageReference(self.message._asMessage()), media: file), synchronousLoad: synchronousLoads, autoFetchFullSizeThumbnail: true, useMiniThumbnailIfAvailable: true)
                    self.imageNode.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            }
        }

        let makeLayout = self.imageNode.asyncLayout()
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
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

private final class DayComponent: Component {
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
        private let buttonNode: HighlightableButtonNode

        private let highlightNode: ASImageNode
        private let titleNode: ImmediateTextNode
        private var mediaPreviewNode: MediaPreviewNode?

        private var currentTheme: PresentationTheme?
        private var currentDiameter: CGFloat?
        private var currentIsCurrent: Bool?
        private var action: (() -> Void)?
        private var currentMedia: DayMedia?

        init() {
            self.buttonNode = HighlightableButtonNode()
            self.highlightNode = ASImageNode()
            self.titleNode = ImmediateTextNode()

            super.init(frame: CGRect())

            self.buttonNode.addSubnode(self.highlightNode)
            self.buttonNode.addSubnode(self.titleNode)

            self.addSubnode(self.buttonNode)

            self.buttonNode.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        @objc private func pressed() {
            self.action?()
        }

        func update(component: DayComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.action = component.action

            let shadowInset: CGFloat = 0.0
            let diameter = min(availableSize.width, availableSize.height)

            var updated = false
            if self.currentTheme !== component.theme || self.currentIsCurrent != component.isCurrent {
                updated = true
            }

            if self.currentDiameter != diameter || updated {
                self.currentDiameter = diameter
                self.currentTheme = component.theme
                self.currentIsCurrent = component.isCurrent

                if component.isCurrent || component.media != nil {
                    self.highlightNode.image = generateImage(CGSize(width: diameter + shadowInset * 2.0, height: diameter + shadowInset * 2.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))

                        if component.media != nil {
                            context.setFillColor(UIColor(white: 0.0, alpha: 0.2).cgColor)
                        } else {
                            context.setFillColor(component.theme.list.itemAccentColor.cgColor)
                        }

                        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowInset, y: shadowInset), size: CGSize(width: size.width - shadowInset * 2.0, height: size.height - shadowInset * 2.0)))
                    })?.stretchableImage(withLeftCapWidth: Int(diameter + shadowInset * 2.0) / 2, topCapHeight: Int(diameter + shadowInset * 2.0) / 2)
                } else {
                    self.highlightNode.image = nil
                }
            }

            if self.currentMedia != component.media {
                if let mediaPreviewNode = self.mediaPreviewNode {
                    self.mediaPreviewNode = nil
                    mediaPreviewNode.removeFromSupernode()
                }

                if let media = component.media {
                    let mediaPreviewNode = MediaPreviewNode(context: component.context, message: media.message, media: media.media)
                    self.mediaPreviewNode = mediaPreviewNode
                    self.buttonNode.insertSubnode(mediaPreviewNode, belowSubnode: self.highlightNode)
                }
            }

            let titleColor: UIColor
            let titleFont: UIFont
            if component.isCurrent || component.media != nil {
                titleColor = component.theme.list.itemCheckColors.foregroundColor
                titleFont = Font.semibold(17.0)
            } else if component.isEnabled {
                titleColor = component.theme.list.itemPrimaryTextColor
                titleFont = Font.regular(17.0)
            } else {
                titleColor = component.theme.list.itemDisabledTextColor
                titleFont = Font.regular(17.0)
            }
            self.titleNode.attributedText = NSAttributedString(string: component.title, font: titleFont, textColor: titleColor)
            let titleSize = self.titleNode.updateLayout(availableSize)

            transition.setFrame(view: self.highlightNode.view, frame: CGRect(origin: CGPoint(x: -shadowInset, y: -shadowInset), size: CGSize(width: availableSize.width + shadowInset * 2.0, height: availableSize.height + shadowInset * 2.0)))

            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: floor((availableSize.height - titleSize.height) / 2.0)), size: titleSize)

            self.buttonNode.frame = CGRect(origin: CGPoint(), size: availableSize)
            self.buttonNode.isEnabled = component.isEnabled && component.media != nil

            if let mediaPreviewNode = self.mediaPreviewNode {
                mediaPreviewNode.frame = CGRect(origin: CGPoint(), size: availableSize)
                mediaPreviewNode.updateLayout(size: availableSize, synchronousLoads: false)
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

private final class MonthComponent: CombinedComponent {
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
        let days = ChildMap(environment: Empty.self, keyedBy: Int.self)

        return { context in
            let sideInset: CGFloat = 14.0
            let titleWeekdaysSpacing: CGFloat = 18.0
            let weekdayDaySpacing: CGFloat = 14.0
            let weekdaySize: CGFloat = 46.0
            let weekdaySpacing: CGFloat = 6.0

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
                    availableSize: CGSize(width: weekdaySize, height: weekdaySize),
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
        private let navigateToDay: (Int32) -> Void

        private var presentationData: PresentationData
        private var scrollView: Scroller

        private var initialMonthIndex: Int = 0
        private var months: [MonthModel] = []
        private var monthViews: [Int: ComponentHostView<Empty>] = [:]

        private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        private var scrollLayout: (width: CGFloat, contentHeight: CGFloat, frames: [Int: CGRect])?

        init(context: AccountContext, peerId: PeerId, initialTimestamp: Int32, navigateToDay: @escaping (Int32) -> Void) {
            self.context = context
            self.peerId = peerId
            self.navigateToDay = navigateToDay
            
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

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

            let calendar = Calendar(identifier: .gregorian)

            let baseDate = Date()
            let currentYear = calendar.component(.year, from: baseDate)
            let currentMonth = calendar.component(.month, from: baseDate)
            let currentDayOfMonth = calendar.component(.day, from: baseDate)

            let initialDate = Date(timeIntervalSince1970: TimeInterval(initialTimestamp))

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

            if self.months.count > 1 {
                for i in 0 ..< self.months.count - 1 {
                    if initialDate >= self.months[i].firstDay {
                        self.initialMonthIndex = i
                        break
                    }
                }
            }

            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor

            self.scrollView.delegate = self
            self.view.addSubview(self.scrollView)

            self.reloadMediaInfo()
        }

        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let isFirstLayout = self.validLayout == nil
            self.validLayout = (layout, navigationHeight)

            if self.updateScrollLayoutIfNeeded() {
            }

            if isFirstLayout, let frame = self.scrollLayout?.frames[self.initialMonthIndex] {
                var contentOffset = floor(frame.midY - self.scrollView.bounds.height / 2.0)
                if contentOffset < 0 {
                    contentOffset = 0
                }
                if contentOffset > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                    contentOffset = self.scrollView.contentSize.height - self.scrollView.bounds.height
                }
                self.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffset), animated: false)
            }

            updateMonthViews()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
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

            let measureView = ComponentHostView<Empty>()
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
                    environment: {},
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

            self.scrollView.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationHeight))
            self.scrollView.contentSize = CGSize(width: layout.size.width, height: contentHeight)
            self.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: layout.intrinsicInsets.bottom, left: 0.0, bottom: 0.0, right: 0.0)

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

                let monthView: ComponentHostView<Empty>
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
                    environment: {},
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
            let peerId = self.peerId
            let months = self.months
            let _ = (self.context.account.postbox.transaction { transaction -> [Int: [Int: DayMedia]] in
                var updatedMedia: [Int: [Int: DayMedia]] = [:]

                for i in 0 ..< months.count {
                    for day in 0 ..< months[i].numberOfDays {
                        let dayTimestamp = Int32(months[i].firstDay.timeIntervalSince1970) + 24 * 60 * 60 * Int32(day)
                        let nextDayTimestamp = Int32(months[i].firstDay.timeIntervalSince1970) + 24 * 60 * 60 * Int32(day - 1)
                        if let message = transaction.firstMessageInRange(peerId: peerId, namespace: Namespaces.Message.Cloud, tag: .photoOrVideo, timestampMax: dayTimestamp, timestampMin: nextDayTimestamp - 1) {
                            /*if message.timestamp < nextDayTimestamp {
                                continue
                            }*/
                            if updatedMedia[i] == nil {
                                updatedMedia[i] = [:]
                            }
                            mediaLoop: for media in message.media {
                                switch media {
                                case _ as TelegramMediaImage, _ as TelegramMediaFile:
                                    updatedMedia[i]![day] = DayMedia(message: EngineMessage(message), media: EngineMedia(media))
                                    break mediaLoop
                                default:
                                    break
                                }
                            }
                        }
                    }
                }

                return updatedMedia
            }
            |> deliverOnMainQueue).start(next: { [weak self] updatedMedia in
                guard let strongSelf = self else {
                    return
                }
                for (monthIndex, mediaByDay) in updatedMedia {
                    strongSelf.months[monthIndex].mediaByDay = mediaByDay
                }
                strongSelf.updateMonthViews()
            })
        }
    }

    private var node: Node {
        return self.displayNode as! Node
    }

    private let context: AccountContext
    private let peerId: PeerId
    private let initialTimestamp: Int32
    private let navigateToDay: (CalendarMessageScreen, Int32) -> Void

    public init(context: AccountContext, peerId: PeerId, initialTimestamp: Int32, navigateToDay: @escaping (CalendarMessageScreen, Int32) -> Void) {
        self.context = context
        self.peerId = peerId
        self.initialTimestamp = initialTimestamp
        self.navigateToDay = navigateToDay

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))

        self.navigationPresentation = .modal

        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(dismissPressed)), animated: false)
        //TODO:localize
        self.navigationItem.setTitle("Jump to Date", animated: false)
    }

    required public init(coder aDecoder: NSCoder) {
        preconditionFailure()
    }

    @objc private func dismissPressed() {
        self.dismiss()
    }

    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, peerId: self.peerId, initialTimestamp: self.initialTimestamp, navigateToDay: { [weak self] timestamp in
            guard let strongSelf = self else {
                return
            }
            strongSelf.navigateToDay(strongSelf, timestamp)
        })

        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.node.containerLayoutUpdated(layout: layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
