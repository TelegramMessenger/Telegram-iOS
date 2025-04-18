import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import TextFormat
import UIKit
import AppBundle
import TelegramStringFormatting
import ContextUI
import TelegramCore
import ComponentFlow
import MultilineTextComponent
import BundleIconComponent
import PlainButtonComponent
import AccountContext

func businessHoursTextToCopy(businessHours: TelegramBusinessHours, presentationData: PresentationData, displayLocalTimezone: Bool) -> String {
    var text = ""
    
    let cachedDays = businessHours.splitIntoWeekDays()
    
    var timezoneOffsetMinutes: Int = 0
    if displayLocalTimezone {
        var currentCalendar = Calendar(identifier: .gregorian)
        currentCalendar.timeZone = TimeZone(identifier: businessHours.timezoneId) ?? TimeZone.current
        
        let currentTimezone = TimeZone.current
        timezoneOffsetMinutes = (currentTimezone.secondsFromGMT() - currentCalendar.timeZone.secondsFromGMT()) / 60
    }
    
    let businessDays: [TelegramBusinessHours.WeekDay] = cachedDays
    
    for i in 0 ..< businessDays.count {
        let dayTitleValue: String
        switch i {
        case 0:
            dayTitleValue = presentationData.strings.Weekday_Monday
        case 1:
            dayTitleValue = presentationData.strings.Weekday_Tuesday
        case 2:
            dayTitleValue = presentationData.strings.Weekday_Wednesday
        case 3:
            dayTitleValue = presentationData.strings.Weekday_Thursday
        case 4:
            dayTitleValue = presentationData.strings.Weekday_Friday
        case 5:
            dayTitleValue = presentationData.strings.Weekday_Saturday
        case 6:
            dayTitleValue = presentationData.strings.Weekday_Sunday
        default:
            dayTitleValue = " "
        }
        
        let businessHoursText = dayBusinessHoursText(presentationData: presentationData, day: businessDays[i], offsetMinutes: timezoneOffsetMinutes, formatAsPlainText: true)
        
        if !text.isEmpty {
            text.append("\n")
        }
        text.append("\(dayTitleValue): \(businessHoursText)")
    }
    
    return text
}

private func dayBusinessHoursText(presentationData: PresentationData, day: TelegramBusinessHours.WeekDay, offsetMinutes: Int, formatAsPlainText: Bool = false) -> String {
    var businessHoursText: String = ""
    switch day {
    case .open:
        businessHoursText += presentationData.strings.PeerInfo_BusinessHours_DayOpen24h
    case .closed:
        businessHoursText += presentationData.strings.PeerInfo_BusinessHours_DayClosed
    case let .intervals(intervals):
        func clipMinutes(_ value: Int) -> Int {
            var value = value
            if value < 0 {
                value = 24 * 60 + value
            }
            return value % (24 * 60)
        }
        
        var resultText: String = ""
        for range in intervals {
            let range = TelegramBusinessHours.WorkingTimeInterval(startMinute: range.startMinute + offsetMinutes, endMinute: range.endMinute + offsetMinutes)
            
            if !resultText.isEmpty {
                if formatAsPlainText {
                    resultText.append(", ")
                } else {
                    resultText.append("\n")
                }
            }
            let startHours = clipMinutes(range.startMinute) / 60
            let startMinutes = clipMinutes(range.startMinute) % 60
            let startText = stringForShortTimestamp(hours: Int32(startHours), minutes: Int32(startMinutes), dateTimeFormat: presentationData.dateTimeFormat, formatAsPlainText: formatAsPlainText)
            let endHours = clipMinutes(range.endMinute) / 60
            let endMinutes = clipMinutes(range.endMinute) % 60
            let endText = stringForShortTimestamp(hours: Int32(endHours), minutes: Int32(endMinutes), dateTimeFormat: presentationData.dateTimeFormat, formatAsPlainText: formatAsPlainText)
            resultText.append("\(startText) - \(endText)")
        }
        businessHoursText += resultText
    }
    
    return businessHoursText
}

final class PeerInfoScreenBusinessHoursItem: PeerInfoScreenItem {
    let id: AnyHashable
    let label: String
    let businessHours: TelegramBusinessHours
    let requestLayout: (Bool) -> Void
    let longTapAction: ((ASDisplayNode, String) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    
    init(
        id: AnyHashable,
        label: String,
        businessHours: TelegramBusinessHours,
        requestLayout: @escaping (Bool) -> Void,
        longTapAction: ((ASDisplayNode, String) -> Void)? = nil,
        contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)? = nil
    ) {
        self.id = id
        self.label = label
        self.businessHours = businessHours
        self.requestLayout = requestLayout
        self.longTapAction = longTapAction
        self.contextAction = contextAction
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenBusinessHoursItemNode()
    }
}

private final class PeerInfoScreenBusinessHoursItemNode: PeerInfoScreenItemNode {
    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    
    private let extractedBackgroundImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let maskNode: ASImageNode
    private let labelNode: ImmediateTextNode
    private let currentStatusText = ComponentView<Empty>()
    private let currentDayText = ComponentView<Empty>()
    private var timezoneSwitchButton: ComponentView<Empty>?
    private var dayTitles: [ComponentView<Empty>] = []
    private var dayValues: [ComponentView<Empty>] = []
    private let arrowIcon = ComponentView<Empty>()
    
    private let bottomSeparatorNode: ASDisplayNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenBusinessHoursItem?
    private var presentationData: PresentationData?
    private var theme: PresentationTheme?
    
    private var currentTimezone: TimeZone
    private var displayLocalTimezone: Bool = false
    private var cachedDays: [TelegramBusinessHours.WeekDay] = []
    private var cachedWeekMinuteSet = IndexSet()
    
    private var isExpanded: Bool = false
    
    override init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        self.currentTimezone = TimeZone.current
        
        super.init()
        
        self.addSubnode(self.bottomSeparatorNode)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.addSubnode(self.maskNode)
        
        self.contextSourceNode.contentNode.clipsToBounds = true
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.labelNode)
        
        self.addSubnode(self.activateArea)
        
        self.containerNode.isGestureEnabled = false
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.contextSourceNode, gesture, nil)
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let theme = strongSelf.theme else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: theme.list.plainBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] _ in
            guard let self, let item = self.item else {
                return .keepWithSingleTap
            }
            
            if item.longTapAction != nil {
                return .waitForSingleTap
            }
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateTouchesAtPoint(point)
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
                    self.isExpanded = !self.isExpanded
                    self.item?.requestLayout(true)
                case .longTap:
                    if let item = self.item, let presentationData = self.presentationData {
                        item.longTapAction?(self, businessHoursTextToCopy(businessHours: item.businessHours, presentationData: presentationData, displayLocalTimezone: self.displayLocalTimezone))
                    }
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenBusinessHoursItem else {
            return 10.0
        }
        
        let businessDays: [TelegramBusinessHours.WeekDay]
        if self.item?.businessHours != item.businessHours {
            businessDays = item.businessHours.splitIntoWeekDays()
            self.cachedDays = businessDays
            self.cachedWeekMinuteSet = item.businessHours.weekMinuteSet()
        } else {
            businessDays = self.cachedDays
        }
        
        self.item = item
        self.presentationData = presentationData
        self.theme = presentationData.theme
        
        self.containerNode.isGestureEnabled = item.contextAction != nil
                
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.labelNode.attributedText = NSAttributedString(string: item.label, font: Font.regular(14.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
        
        let labelSize = self.labelNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        var topOffset = 10.0
        let labelFrame = CGRect(origin: CGPoint(x: sideInset, y: topOffset), size: labelSize)
        if labelSize.height > 0.0 {
            topOffset += labelSize.height
            topOffset += 3.0
        }
        
        let arrowIconSize = self.arrowIcon.update(
            transition: .immediate,
            component: AnyComponent(BundleIconComponent(
                name: "Item List/DownArrow",
                tintColor: presentationData.theme.list.disclosureArrowColor
            )),
            environment: {},
            containerSize: CGSize(width: 100.0, height: 100.0)
        )
        let arrowIconFrame = CGRect(origin: CGPoint(x: width - sideInset + 1.0 - arrowIconSize.width, y: topOffset + 5.0), size: arrowIconSize)
        if let arrowIconView = self.arrowIcon.view {
            if arrowIconView.superview == nil {
                self.contextSourceNode.contentNode.view.addSubview(arrowIconView)
                arrowIconView.frame = arrowIconFrame
            }
            transition.updatePosition(layer: arrowIconView.layer, position: arrowIconFrame.center)
            transition.updateBounds(layer: arrowIconView.layer, bounds: CGRect(origin: CGPoint(), size: arrowIconFrame.size))
            transition.updateTransformRotation(view: arrowIconView, angle: self.isExpanded ? CGFloat.pi * 1.0 : CGFloat.pi * 0.0)
        }
        
        var currentCalendar = Calendar(identifier: .gregorian)
        currentCalendar.timeZone = TimeZone(identifier: item.businessHours.timezoneId) ?? TimeZone.current
        let currentDate = Date()
        var currentDayIndex = currentCalendar.component(.weekday, from: currentDate)
        if currentDayIndex == 1 {
            currentDayIndex = 6
        } else {
            currentDayIndex -= 2
        }
        
        let currentMinute = currentCalendar.component(.minute, from: currentDate)
        let currentHour = currentCalendar.component(.hour, from: currentDate)
        let currentWeekMinute = currentDayIndex * 24 * 60 + currentHour * 60 + currentMinute
        
        var timezoneOffsetMinutes: Int = 0
        if self.displayLocalTimezone {
            timezoneOffsetMinutes = (self.currentTimezone.secondsFromGMT() - currentCalendar.timeZone.secondsFromGMT()) / 60
        }
        
        let isOpen = self.cachedWeekMinuteSet.contains(currentWeekMinute)
        let openStatusText = isOpen ? presentationData.strings.PeerInfo_BusinessHours_StatusOpen : presentationData.strings.PeerInfo_BusinessHours_StatusClosed
        
        var currentDayStatusText = currentDayIndex >= 0 && currentDayIndex < businessDays.count ? dayBusinessHoursText(presentationData: presentationData, day: businessDays[currentDayIndex], offsetMinutes: timezoneOffsetMinutes) : " "
        
        if !isOpen {
            for range in self.cachedWeekMinuteSet.rangeView {
                if range.lowerBound > currentWeekMinute {
                    let openInMinutes = range.lowerBound - currentWeekMinute
                    if openInMinutes < 60 {
                        currentDayStatusText = presentationData.strings.PeerInfo_BusinessHours_StatusOpensInMinutes(Int32(openInMinutes))
                    } else if openInMinutes < 6 * 60 {
                        currentDayStatusText = presentationData.strings.PeerInfo_BusinessHours_StatusOpensInHours(Int32(openInMinutes / 60))
                    } else {
                        let openDate = currentDate.addingTimeInterval(Double(openInMinutes * 60))
                        let openTimestamp = Int32(openDate.timeIntervalSince1970) + Int32(currentCalendar.timeZone.secondsFromGMT() - TimeZone.current.secondsFromGMT())
                        
                        let dateText = humanReadableStringForTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, timestamp: openTimestamp, alwaysShowTime: true, allowYesterday: false, format: HumanReadableStringFormat(
                            dateFormatString: { value in
                                let text = PresentationStrings.FormattedString(string: presentationData.strings.Chat_MessageSeenTimestamp_Date(value).string, ranges: [])
                                return presentationData.strings.PeerInfo_BusinessHours_StatusOpensOnDate(text.string)
                            },
                            tomorrowFormatString: { value in
                                return PresentationStrings.FormattedString(string: presentationData.strings.PeerInfo_BusinessHours_StatusOpensTomorrowAt(value).string, ranges: [])
                            },
                            todayFormatString: { value in
                                return PresentationStrings.FormattedString(string: presentationData.strings.PeerInfo_BusinessHours_StatusOpensTodayAt(value).string, ranges: [])
                            },
                            yesterdayFormatString: { value in
                                return PresentationStrings.FormattedString(string: presentationData.strings.PeerInfo_BusinessHours_StatusOpensTodayAt(value).string, ranges: [])
                            },
                            daysFormatString: { value in
                                return PresentationStrings.FormattedString(string: presentationData.strings.PeerInfo_BusinessHours_StatusOpensInDays(Int32(value)), ranges: [])
                            }
                        )).string
                        currentDayStatusText = dateText
                    }
                    break
                }
            }
        }
        
        let currentStatusTextSize = self.currentStatusText.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: openStatusText, font: Font.regular(15.0), textColor: isOpen ? presentationData.theme.list.freeTextSuccessColor : presentationData.theme.list.itemDestructiveColor))
            )),
            environment: {},
            containerSize: CGSize(width: width - sideInset * 2.0, height: 100.0)
        )
        let currentStatusTextFrame = CGRect(origin: CGPoint(x: sideInset, y: topOffset), size: currentStatusTextSize)
        if let currentStatusTextView = self.currentStatusText.view {
            if currentStatusTextView.superview == nil {
                currentStatusTextView.layer.anchorPoint = CGPoint()
                self.contextSourceNode.contentNode.view.addSubview(currentStatusTextView)
            }
            transition.updatePosition(layer: currentStatusTextView.layer, position: currentStatusTextFrame.origin)
            currentStatusTextView.bounds = CGRect(origin: CGPoint(), size: currentStatusTextFrame.size)
        }
        
        let dayRightInset = sideInset + 17.0
        
        let currentDayTextSize = self.currentDayText.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: currentDayStatusText, font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)),
                horizontalAlignment: .right,
                maximumNumberOfLines: 0
            )),
            environment: {},
            containerSize: CGSize(width: width - sideInset - dayRightInset, height: 100.0)
        )
        
        var hasTimezoneDependentEntries = false
        if item.businessHours.timezoneId != self.currentTimezone.identifier {
            var currentCalendar = Calendar(identifier: .gregorian)
            currentCalendar.timeZone = TimeZone(identifier: item.businessHours.timezoneId) ?? TimeZone.current
            
            let timezoneOffsetMinutes = (self.currentTimezone.secondsFromGMT() - currentCalendar.timeZone.secondsFromGMT()) / 60
            
            for i in 0 ..< businessDays.count {
                let businessHoursTextLocal = dayBusinessHoursText(presentationData: presentationData, day: businessDays[i], offsetMinutes: 0)
                let businessHoursTextOffset = dayBusinessHoursText(presentationData: presentationData, day: businessDays[i], offsetMinutes: timezoneOffsetMinutes)
                if businessHoursTextOffset != businessHoursTextLocal {
                    hasTimezoneDependentEntries = true
                    break
                }
            }
        }
        
        var timezoneSwitchButtonSize: CGSize?
        if hasTimezoneDependentEntries {
            let timezoneSwitchButton: ComponentView<Empty>
            if let current = self.timezoneSwitchButton {
                timezoneSwitchButton = current
            } else {
                timezoneSwitchButton = ComponentView()
                self.timezoneSwitchButton = timezoneSwitchButton
            }
            let timezoneSwitchTitle: String
            if self.displayLocalTimezone {
                timezoneSwitchTitle = presentationData.strings.PeerInfo_BusinessHours_TimezoneSwitchMy
            } else {
                timezoneSwitchTitle = presentationData.strings.PeerInfo_BusinessHours_TimezoneSwitchBusiness
            }
            timezoneSwitchButtonSize = timezoneSwitchButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: timezoneSwitchTitle, font: Font.regular(12.0), textColor: presentationData.theme.list.itemAccentColor))
                    )),
                    background: AnyComponent(RoundedRectangle(
                        color: presentationData.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                        cornerRadius: nil
                    )),
                    effectAlignment: .center,
                    contentInsets: UIEdgeInsets(top: 1.0, left: 7.0, bottom: 2.0, right: 7.0),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.displayLocalTimezone = !self.displayLocalTimezone
                        self.item?.requestLayout(false)
                        
                        if !self.isExpanded {
                            self.isExpanded = true
                            self.item?.requestLayout(true)
                        }
                    },
                    animateAlpha: true,
                    animateScale: false,
                    animateContents: false
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
        } else {
            if let timezoneSwitchButton = self.timezoneSwitchButton {
                self.timezoneSwitchButton = nil
                timezoneSwitchButton.view?.removeFromSuperview()
            }
        }
        
        let timezoneSwitchButtonSpacing: CGFloat = 3.0
        if timezoneSwitchButtonSize != nil {
            topOffset -= 20.0
        }
        
        let currentDayTextFrame = CGRect(origin: CGPoint(x: width - dayRightInset - currentDayTextSize.width, y: topOffset), size: currentDayTextSize)
        if let currentDayTextView = self.currentDayText.view {
            if currentDayTextView.superview == nil {
                currentDayTextView.layer.anchorPoint = CGPoint()
                self.contextSourceNode.contentNode.view.addSubview(currentDayTextView)
            }
            transition.updatePosition(layer: currentDayTextView.layer, position: currentDayTextFrame.origin)
            currentDayTextView.bounds = CGRect(origin: CGPoint(), size: currentDayTextFrame.size)
        }
        
        topOffset += max(currentStatusTextSize.height, currentDayTextSize.height)
        
        if let timezoneSwitchButtonView = self.timezoneSwitchButton?.view, let timezoneSwitchButtonSize {
            topOffset += timezoneSwitchButtonSpacing
            
            var timezoneSwitchButtonTransition = transition
            if timezoneSwitchButtonView.superview == nil {
                timezoneSwitchButtonTransition = .immediate
                self.contextSourceNode.contentNode.view.addSubview(timezoneSwitchButtonView)
            }
            let timezoneSwitchButtonFrame = CGRect(origin: CGPoint(x: width - dayRightInset - timezoneSwitchButtonSize.width, y: topOffset), size: timezoneSwitchButtonSize)
            timezoneSwitchButtonTransition.updateFrame(view: timezoneSwitchButtonView, frame: timezoneSwitchButtonFrame)
            
            topOffset += timezoneSwitchButtonSize.height
        }
        
        let daySpacing: CGFloat = 15.0
        
        var dayHeights: CGFloat = 0.0
        
        for rawI in 0 ..< businessDays.count {
            if rawI == 0 {
                //skip current day
                continue
            }
            let i = (rawI + currentDayIndex) % businessDays.count
            
            dayHeights += daySpacing
            
            var dayTransition = transition
            let dayTitle: ComponentView<Empty>
            if self.dayTitles.count > i {
                dayTitle = self.dayTitles[i]
            } else {
                dayTransition = .immediate
                dayTitle = ComponentView()
                self.dayTitles.append(dayTitle)
            }
            
            let dayValue: ComponentView<Empty>
            if self.dayValues.count > i {
                dayValue = self.dayValues[i]
            } else {
                dayValue = ComponentView()
                self.dayValues.append(dayValue)
            }
            
            let dayTitleValue: String
            switch i {
            case 0:
                dayTitleValue = presentationData.strings.Weekday_Monday
            case 1:
                dayTitleValue = presentationData.strings.Weekday_Tuesday
            case 2:
                dayTitleValue = presentationData.strings.Weekday_Wednesday
            case 3:
                dayTitleValue = presentationData.strings.Weekday_Thursday
            case 4:
                dayTitleValue = presentationData.strings.Weekday_Friday
            case 5:
                dayTitleValue = presentationData.strings.Weekday_Saturday
            case 6:
                dayTitleValue = presentationData.strings.Weekday_Sunday
            default:
                dayTitleValue = " "
            }
            
            let businessHoursText = dayBusinessHoursText(presentationData: presentationData, day: businessDays[i], offsetMinutes: timezoneOffsetMinutes)
            
            let dayTitleSize = dayTitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: dayTitleValue, font: Font.regular(15.0), textColor: presentationData.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: width - sideInset * 2.0, height: 100.0)
            )
            let dayTitleFrame = CGRect(origin: CGPoint(x: sideInset, y: topOffset + dayHeights), size: dayTitleSize)
            if let dayTitleView = dayTitle.view {
                if dayTitleView.superview == nil {
                    dayTitleView.layer.anchorPoint = CGPoint()
                    self.contextSourceNode.contentNode.view.addSubview(dayTitleView)
                    dayTitleView.alpha = 0.0
                }
                dayTransition.updatePosition(layer: dayTitleView.layer, position: dayTitleFrame.origin)
                dayTitleView.bounds = CGRect(origin: CGPoint(), size: dayTitleFrame.size)
                
                transition.updateAlpha(layer: dayTitleView.layer, alpha: self.isExpanded ? 1.0 : 0.0)
            }
            
            let dayValueSize = dayValue.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: businessHoursText, font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor, paragraphAlignment: .right)),
                    horizontalAlignment: .right,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: width - sideInset - dayRightInset, height: 100.0)
            )
            let dayValueFrame = CGRect(origin: CGPoint(x: width - dayRightInset - dayValueSize.width, y: topOffset + dayHeights), size: dayValueSize)
            if let dayValueView = dayValue.view {
                if dayValueView.superview == nil {
                    dayValueView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                    self.contextSourceNode.contentNode.view.addSubview(dayValueView)
                    dayValueView.alpha = 0.0
                }
                dayTransition.updatePosition(layer: dayValueView.layer, position: CGPoint(x: dayValueFrame.maxX, y: dayValueFrame.minY))
                dayValueView.bounds = CGRect(origin: CGPoint(), size: dayValueFrame.size)
                
                transition.updateAlpha(layer: dayValueView.layer, alpha: self.isExpanded ? 1.0 : 0.0)
            }
            
            dayHeights += max(dayTitleSize.height, dayValueSize.height)
        }
        
        if self.isExpanded {
            topOffset += dayHeights
        }
        
        topOffset += 11.0
        
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
        let height = topOffset
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        transition.updateFrame(node: self.maskNode, frame: CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height)))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        self.activateArea.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: height))
        self.activateArea.accessibilityLabel = item.label
        
        let contentSize = CGSize(width: width, height: height)
        self.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        transition.updateFrame(node: self.contextSourceNode.contentNode, frame: CGRect(origin: CGPoint(), size: contentSize))
        
        let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: contentSize.height))
        let extractedRect = nonExtractedRect
        self.extractedRect = extractedRect
        self.nonExtractedRect = nonExtractedRect
        
        if self.contextSourceNode.isExtractedToContextPreview {
            self.extractedBackgroundImageNode.frame = extractedRect
        } else {
            self.extractedBackgroundImageNode.frame = nonExtractedRect
        }
        self.contextSourceNode.contentRect = extractedRect
        
        return height
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
    }
}
