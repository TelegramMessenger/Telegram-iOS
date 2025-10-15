import Foundation
import Display
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import TelegramStringFormatting
import SegmentedControlNode
import DirectionalPanGesture

public final class DatePickerTheme: Equatable {
    public let backgroundColor: UIColor
    public let textColor: UIColor
    public let secondaryTextColor: UIColor
    public let accentColor: UIColor
    public let disabledColor: UIColor
    public let selectionColor: UIColor
    public let selectionTextColor: UIColor
    public let separatorColor: UIColor
    public let segmentedControlTheme: SegmentedControlTheme
    public let overallDarkAppearance: Bool
    
    public init(backgroundColor: UIColor, textColor: UIColor, secondaryTextColor: UIColor, accentColor: UIColor, disabledColor: UIColor, selectionColor: UIColor, selectionTextColor: UIColor, separatorColor: UIColor, segmentedControlTheme: SegmentedControlTheme, overallDarkAppearance: Bool) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.accentColor = accentColor
        self.disabledColor = disabledColor
        self.selectionColor = selectionColor
        self.selectionTextColor = selectionTextColor
        self.separatorColor = separatorColor
        self.segmentedControlTheme = segmentedControlTheme
        self.overallDarkAppearance = overallDarkAppearance
    }
    
    public static func ==(lhs: DatePickerTheme, rhs: DatePickerTheme) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.secondaryTextColor != rhs.secondaryTextColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.selectionColor != rhs.selectionColor {
            return false
        }
        if lhs.selectionTextColor != rhs.selectionTextColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        if lhs.overallDarkAppearance != rhs.overallDarkAppearance {
            return false
        }
        return true
    }
}

public extension DatePickerTheme {
    convenience init(theme: PresentationTheme) {
        self.init(backgroundColor: theme.list.itemBlocksBackgroundColor, textColor: theme.list.itemPrimaryTextColor, secondaryTextColor: theme.list.itemSecondaryTextColor, accentColor: theme.list.itemAccentColor, disabledColor: theme.list.itemDisabledTextColor, selectionColor: theme.list.itemCheckColors.fillColor, selectionTextColor: theme.list.itemCheckColors.foregroundColor, separatorColor: theme.list.itemBlocksSeparatorColor, segmentedControlTheme: SegmentedControlTheme(theme: theme), overallDarkAppearance: theme.overallDarkAppearance)
    }
}

private let telegramReleaseDate = Date(timeIntervalSince1970: 1376438400.0)
private let upperLimitDate = Date(timeIntervalSince1970: Double(Int32.max - 1))

private let controlFont = Font.regular(17.0)
private let dayFont = Font.regular(13.0)
private let dateFont = Font.with(size: 17.0, design: .regular, traits: .monospacedNumbers)
private let selectedDateFont = Font.with(size: 17.0, design: .regular, weight: .bold, traits: .monospacedNumbers)

private var calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale.current
    return calendar
}()

private func monthForDate(_ date: Date) -> Date {
    var components = calendar.dateComponents([.year, .month], from: date)
    components.hour = 0
    components.minute = 0
    components.second = 0
    return calendar.date(from: components)!
}

private func generateSmallArrowImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 7.0, height: 12.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.beginPath()
        context.move(to: CGPoint(x: 1.0, y: 1.0))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height / 2.0))
        context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
        context.strokePath()
    })
}

private func generateNavigationArrowImage(color: UIColor, mirror: Bool) -> UIImage? {
    return generateImage(CGSize(width: 10.0, height: 17.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.beginPath()
        if mirror {
            context.translateBy(x: 5.0, y: 8.5)
            context.scaleBy(x: -1.0, y: 1.0)
            context.translateBy(x: -5.0, y: -8.5)
        }
        context.move(to: CGPoint(x: 1.0, y: 1.0))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height / 2.0))
        context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
        context.strokePath()
    })
}

private func yearRange(for state: DatePickerNode.State) -> Range<Int> {
    let minYear = calendar.component(.year, from: state.minDate)
    let maxYear = calendar.component(.year, from: state.maxDate)
    return minYear ..< maxYear + 1
}

public final class DatePickerNode: ASDisplayNode {
    class MonthNode: ASDisplayNode {
        let month: Date
        
        var theme: DatePickerTheme {
            didSet {
                self.selectionNode.image = generateStretchableFilledCircleImage(diameter: 44.0, color: self.theme.selectionColor)
                if let size = self.validSize {
                    self.updateLayout(size: size)
                }
            }
        }
        
        var maximumDate: Date?
        var minimumDate: Date?
        var date: Date?
        
        private var validSize: CGSize?
        
        private let selectionNode: ASImageNode
        private let dateNodes: [ImmediateTextNode]
        
        private let firstWeekday: Int
        private let startWeekday: Int
        private let numberOfDays: Int
        
        init(theme: DatePickerTheme, month: Date, minimumDate: Date?, maximumDate: Date?, date: Date?) {
            self.theme = theme
            self.month = month
            self.minimumDate = minimumDate
            self.maximumDate = maximumDate
            self.date = date
            
            self.selectionNode = ASImageNode()
            self.selectionNode.displaysAsynchronously = false
            self.selectionNode.displayWithoutProcessing = true
            self.selectionNode.image = generateStretchableFilledCircleImage(diameter: 44.0, color: theme.selectionColor)
            
            self.dateNodes = (0..<42).map { _ in ImmediateTextNode() }
            
            let components = calendar.dateComponents([.year, .month], from: month)
            let startDayDate = calendar.date(from: components)!
            
            self.firstWeekday = calendar.firstWeekday
            self.startWeekday = calendar.dateComponents([.weekday], from: startDayDate).weekday!
            self.numberOfDays = calendar.range(of: .day, in: .month, for: month)!.count
            
            super.init()
            
            self.addSubnode(self.selectionNode)
            self.dateNodes.forEach { self.addSubnode($0) }
        }
        
        func dateAtPoint(_ point: CGPoint) -> Int32? {
            var day: Int32 = 0
            for node in self.dateNodes {
                if node.isHidden {
                    continue
                }
                day += 1
                
                if node.frame.insetBy(dx: -15.0, dy: -15.0).contains(point) {
                    return day
                }
            }
            return nil
        }
        
        func updateLayout(size: CGSize) {
            var weekday = self.firstWeekday
            var started = false
            var ended = false
            var count = 0
            
            let sideInset: CGFloat = 12.0
            let cellSize: CGFloat = floor((size.width - sideInset * 2.0) / 7.0)
            
            self.selectionNode.isHidden = true
            for i in 0 ..< 42 {
                let row: Int = Int(floor(Float(i) / 7.0))
                let col: Int = i % 7
                
                if !started && weekday == self.startWeekday {
                    started = true
                }
                weekday += 1
                if weekday > 7 {
                    weekday = 1
                }
                
                let textNode = self.dateNodes[i]
                if started && !ended {
                    textNode.isHidden = false
                    count += 1
                    
                    var isAvailableDate = true
                    var components = calendar.dateComponents([.year, .month], from: self.month)
                    components.day = count
                    components.hour = 0
                    components.minute = 0
                    let date = calendar.date(from: components)!
                    
                    if let minimumDate = self.minimumDate {
                        if date < minimumDate {
                            isAvailableDate = false
                        }
                    }
                    if let maximumDate = self.maximumDate {
                        if date > maximumDate {
                            isAvailableDate = false
                        }
                    }
                    let isToday = calendar.isDateInToday(date)
                    let isSelected = self.date.flatMap { calendar.isDate(date, equalTo: $0, toGranularity: .day) } ?? false
                    
                    let color: UIColor
                    if isSelected {
                        color = self.theme.selectionTextColor
                    } else if isToday {
                        color = self.theme.accentColor
                    } else if !isAvailableDate {
                        color = self.theme.disabledColor
                    } else {
                        color = self.theme.textColor
                    }
                    
                    textNode.attributedText = NSAttributedString(string: "\(count)", font: isSelected ? selectedDateFont : dateFont, textColor: color)
                    
                    let textSize = textNode.updateLayout(size)
                    
                    let cellFrame = CGRect(x: sideInset + CGFloat(col) * cellSize, y: 0.0 + CGFloat(row) * cellSize, width: cellSize, height: cellSize)
                    let textFrame = CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - textSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - textSize.height) / 2.0)), size: textSize)
                    textNode.frame = textFrame
                    
                    if isSelected {
                        self.selectionNode.isHidden = false
                        let selectionSize = CGSize(width: 44.0, height: 44.0)
                        self.selectionNode.frame = CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - selectionSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - selectionSize.height) / 2.0)), size: selectionSize)
                    }
                    
                    if count == self.numberOfDays {
                        ended = true
                    }
                } else {
                    textNode.isHidden = true
                }
            }
        }
    }
    
    struct State {
        let minDate: Date
        let maxDate: Date
        let date: Date?
        
        let displayingMonthSelection: Bool
        let displayingDateSelection: Bool
        let displayingTimeSelection: Bool
        let selectedMonth: Date
    }
    
    private var state: State
    
    private var theme: DatePickerTheme
    private let strings: PresentationStrings
    private let dateTimeFormat: PresentationDateTimeFormat
    private let title: String
    
    private let timeTitleNode: ImmediateTextNode
    
    private let dayNodes: [ImmediateTextNode]
    private var currentIndex = 0
    private var months: [Date] = []
    private var monthNodes: [Date: MonthNode] = [:]
    private let contentNode: ASDisplayNode
    
    private let datePickerBackgroundNode: ASDisplayNode
    
    private let monthPickerBackgroundNode: ASDisplayNode
    private var monthPickerNode: MonthPickerNode
    
    private let timePickerBackgroundNode: ASDisplayNode
    private var timePickerNode: TimePickerNode
    
    private let dateButtonNode: HighlightableButtonNode
    private let timeButtonNode: HighlightableButtonNode
    
    private let monthButtonNode: HighlightTrackingButtonNode
    private let monthTextNode: ImmediateTextNode
    private let monthArrowNode: ASImageNode
    private let previousButtonNode: HighlightableButtonNode
    private let nextButtonNode: HighlightableButtonNode
    
    private var transitionFraction: CGFloat = 0.0
    
    private var validLayout: CGSize?
    
    public var valueUpdated: ((Date) -> Void)?
    
    public var minimumDate: Date {
        get {
            return self.state.minDate
        }
        set {
            guard newValue != self.minimumDate else {
                return
            }
            
            let updatedState = State(minDate: newValue, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, displayingDateSelection: self.state.displayingDateSelection, displayingTimeSelection: self.state.displayingTimeSelection, selectedMonth: self.state.selectedMonth)
            self.updateState(updatedState, animated: false)
            
            self.monthPickerNode.minimumDate = newValue
            self.timePickerNode.minimumDate = newValue
            
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public var maximumDate: Date {
        get {
            return self.state.maxDate
        }
        set {
            guard newValue != self.maximumDate else {
                return
            }
            
            let updatedState = State(minDate: self.state.minDate, maxDate: newValue, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, displayingDateSelection: self.state.displayingDateSelection, displayingTimeSelection: self.state.displayingTimeSelection, selectedMonth: self.state.selectedMonth)
            self.updateState(updatedState, animated: false)
            
            self.monthPickerNode.maximumDate = newValue
            self.timePickerNode.maximumDate = newValue
            
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public var date: Date? {
        get {
            return self.state.date
        }
        set {
            guard newValue != self.date else {
                return
            }
            
            let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: newValue, displayingMonthSelection: self.state.displayingMonthSelection, displayingDateSelection: self.state.displayingDateSelection, displayingTimeSelection: self.state.displayingTimeSelection, selectedMonth: newValue.flatMap { monthForDate($0) } ?? self.state.selectedMonth)
            self.updateState(updatedState, animated: false)
            
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public init(theme: DatePickerTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, title: String) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        
        self.state = State(minDate: telegramReleaseDate, maxDate: upperLimitDate, date: nil, displayingMonthSelection: false, displayingDateSelection: false, displayingTimeSelection: false, selectedMonth: monthForDate(Date()))
        self.title = title
        
        let initialDate: Date
        if let date = calendar.date(byAdding: .hour, value: 11, to: monthForDate(Date())) {
            initialDate = date
        } else {
            initialDate = monthForDate(Date())
        }
        
        self.timeTitleNode = ImmediateTextNode()
        self.timeTitleNode.attributedText = NSAttributedString(string: title, font: Font.regular(17.0), textColor: theme.textColor)
        
        var timeChangedImpl: ((Date) -> Void)?
        self.timePickerNode = TimePickerNode(theme: theme, date: self.state.date ?? initialDate, valueChanged: { date in
            timeChangedImpl?(date)
        })
        
        self.dayNodes = (0..<7).map { _ in ImmediateTextNode() }
        
        self.datePickerBackgroundNode = ASDisplayNode()
        self.datePickerBackgroundNode.alpha = 0.0
        self.datePickerBackgroundNode.backgroundColor = theme.backgroundColor
        self.datePickerBackgroundNode.isUserInteractionEnabled = false
        
        self.contentNode = ASDisplayNode()
        
        self.monthPickerBackgroundNode = ASDisplayNode()
        self.monthPickerBackgroundNode.alpha = 0.0
        self.monthPickerBackgroundNode.backgroundColor = theme.backgroundColor
        self.monthPickerBackgroundNode.isUserInteractionEnabled = false
        
        self.timePickerBackgroundNode = ASDisplayNode()
        self.timePickerBackgroundNode.alpha = 0.0
        self.timePickerBackgroundNode.backgroundColor = theme.backgroundColor
        self.timePickerBackgroundNode.isUserInteractionEnabled = false
        
        var monthChangedImpl: ((Date) -> Void)?
        self.monthPickerNode = MonthPickerNode(theme: theme, strings: strings, date: self.state.date ?? initialDate, yearRange: yearRange(for: self.state), valueChanged: { date in
            monthChangedImpl?(date)
        })
        self.monthPickerNode.minimumDate = self.state.minDate
        self.monthPickerNode.maximumDate = self.state.maxDate
        
        self.timePickerNode.minimumDate = self.state.minDate
        self.timePickerNode.maximumDate = self.state.maxDate
        
        self.monthButtonNode = HighlightTrackingButtonNode()
        self.monthTextNode = ImmediateTextNode()
        self.monthArrowNode = ASImageNode()
        self.monthArrowNode.displaysAsynchronously = false
        self.monthArrowNode.displayWithoutProcessing = true
        
        self.previousButtonNode = HighlightableButtonNode()
        self.previousButtonNode.hitTestSlop = UIEdgeInsets(top: -6.0, left: -10.0, bottom: -6.0, right: -10.0)
        self.nextButtonNode = HighlightableButtonNode()
        self.nextButtonNode.hitTestSlop = UIEdgeInsets(top: -6.0, left: -10.0, bottom: -6.0, right: -10.0)
        
        self.dateButtonNode = HighlightableButtonNode()
        self.dateButtonNode.clipsToBounds = true
        self.dateButtonNode.backgroundColor = theme.segmentedControlTheme.backgroundColor
        self.dateButtonNode.cornerRadius = 9.0
        
        self.timeButtonNode = HighlightableButtonNode()
        self.timeButtonNode.clipsToBounds = true
        self.timeButtonNode.backgroundColor = theme.segmentedControlTheme.backgroundColor
        self.timeButtonNode.cornerRadius = 9.0
        
        super.init()
        
        self.clipsToBounds = true
        self.backgroundColor = theme.backgroundColor
        
        self.addSubnode(self.datePickerBackgroundNode)
        self.datePickerBackgroundNode.addSubnode(self.contentNode)
        
        self.dayNodes.forEach { self.datePickerBackgroundNode.addSubnode($0) }
        
        self.datePickerBackgroundNode.addSubnode(self.previousButtonNode)
        self.datePickerBackgroundNode.addSubnode(self.nextButtonNode)
        
        self.addSubnode(self.monthPickerBackgroundNode)
        self.monthPickerBackgroundNode.addSubnode(self.monthPickerNode)
        
        self.datePickerBackgroundNode.addSubnode(self.monthTextNode)
        self.datePickerBackgroundNode.addSubnode(self.monthArrowNode)
        self.datePickerBackgroundNode.addSubnode(self.monthButtonNode)
        
        self.addSubnode(self.timePickerBackgroundNode)
        self.timePickerBackgroundNode.addSubnode(self.timePickerNode)
        
        self.addSubnode(self.timeTitleNode)
        
        self.addSubnode(self.dateButtonNode)
        self.addSubnode(self.timeButtonNode)
        
        self.monthArrowNode.image = generateSmallArrowImage(color: theme.accentColor)
        self.previousButtonNode.setImage(generateNavigationArrowImage(color: theme.accentColor, mirror: true), for: .normal)
        self.previousButtonNode.setImage(generateNavigationArrowImage(color: theme.disabledColor, mirror: true), for: .disabled)
        self.nextButtonNode.setImage(generateNavigationArrowImage(color: theme.accentColor, mirror: false), for: .normal)
        self.nextButtonNode.setImage(generateNavigationArrowImage(color: theme.disabledColor, mirror: false), for: .disabled)
        
        self.setupItems()
        
        self.monthButtonNode.addTarget(self, action: #selector(self.monthButtonPressed), forControlEvents: .touchUpInside)
        self.monthButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.monthTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.monthTextNode.alpha = 0.4
                    strongSelf.monthArrowNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.monthArrowNode.alpha = 0.4
                } else {
                    strongSelf.monthTextNode.alpha = 1.0
                    strongSelf.monthTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.monthArrowNode.alpha = 1.0
                    strongSelf.monthArrowNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.previousButtonNode.addTarget(self, action: #selector(self.previousButtonPressed), forControlEvents: .touchUpInside)
        self.nextButtonNode.addTarget(self, action: #selector(self.nextButtonPressed), forControlEvents: .touchUpInside)
        
        self.dateButtonNode.addTarget(self, action: #selector(self.dateButtonPressed), forControlEvents: .touchUpInside)
        self.timeButtonNode.addTarget(self, action: #selector(self.timeButtonPressed), forControlEvents: .touchUpInside)
        
        timeChangedImpl = { [weak self] date in
            if let strongSelf = self {
                let updatedState = State(minDate: strongSelf.state.minDate, maxDate: strongSelf.state.maxDate, date: date, displayingMonthSelection: strongSelf.state.displayingMonthSelection, displayingDateSelection: strongSelf.state.displayingDateSelection, displayingTimeSelection: strongSelf.state.displayingTimeSelection, selectedMonth: strongSelf.state.selectedMonth)
                strongSelf.updateState(updatedState, animated: false)
                
                strongSelf.valueUpdated?(date)
            }
        }
        
        monthChangedImpl = { [weak self] date in
            if let strongSelf = self {
                let updatedState = State(minDate: strongSelf.state.minDate, maxDate: strongSelf.state.maxDate, date: date, displayingMonthSelection: strongSelf.state.displayingMonthSelection, displayingDateSelection: strongSelf.state.displayingDateSelection, displayingTimeSelection: strongSelf.state.displayingTimeSelection, selectedMonth: monthForDate(date))
                strongSelf.updateState(updatedState, animated: false)
                
                strongSelf.valueUpdated?(date)
            }
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        let panGesture = DirectionalPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panGesture.direction = .horizontal
        
        self.contentNode.view.addGestureRecognizer(panGesture)
        self.contentNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    private func updateState(_ state: State, animated: Bool) {
        let previousState = self.state
        self.state = state
        
        if previousState.minDate != state.minDate || previousState.maxDate != state.maxDate || previousState.date == nil && state.date != nil {
            self.monthPickerNode.yearRange = yearRange(for: state)
            self.setupItems()
        } else if previousState.selectedMonth != state.selectedMonth {
            for i in 0 ..< self.months.count {
                if self.months[i].timeIntervalSince1970 >= state.selectedMonth.timeIntervalSince1970 {
                    self.currentIndex = max(0, min(self.months.count - 1, i))
                    break
                }
            }
        }
        
        let initialDate: Date
        if let date = calendar.date(byAdding: .hour, value: 11, to: self.state.selectedMonth) {
            initialDate = date
        } else {
            initialDate = self.state.selectedMonth
        }
        self.monthPickerNode.date = self.state.date ?? initialDate
        self.timePickerNode.date = self.state.date ?? initialDate
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: animated ? .animated(duration: 0.3, curve: .spring) : .immediate)
        }
    }
    
    private func setupItems() {
        let startMonth = monthForDate(self.state.minDate)
        let endMonth = monthForDate(self.state.maxDate)
        let selectedMonth = monthForDate(self.state.date ?? self.state.selectedMonth)
        
        var currentIndex = 0
        
        var months: [Date] = [startMonth]
        var index = 1
        
        var nextMonth = startMonth
        while true {
            if let month = calendar.date(byAdding: .month, value: 1, to: nextMonth) {
                nextMonth = month
                if nextMonth == selectedMonth {
                    currentIndex = index
                }
                if nextMonth > endMonth {
                    break
                } else {
                    months.append(nextMonth)
                }
                index += 1
            } else {
                break
            }
        }
        
        self.months = months
        self.currentIndex = currentIndex
    }
    
    public func updateTheme(_ theme: DatePickerTheme) {
        guard theme != self.theme else {
            return
        }
        self.theme = theme
        
        self.backgroundColor = self.theme.backgroundColor
        self.monthArrowNode.image = generateSmallArrowImage(color: theme.accentColor)
        self.previousButtonNode.setImage(generateNavigationArrowImage(color: theme.accentColor, mirror: true), for: .normal)
        self.nextButtonNode.setImage(generateNavigationArrowImage(color: theme.accentColor, mirror: false), for: .normal)
        
        self.dateButtonNode.backgroundColor = theme.segmentedControlTheme.backgroundColor
        self.timeButtonNode.backgroundColor = theme.segmentedControlTheme.backgroundColor
        
        for (_, monthNode) in self.monthNodes {
            monthNode.theme = theme
        }
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        guard let monthNode = self.monthNodes[self.months[self.currentIndex]] else {
            return
        }
        
        let location = recognizer.location(in: monthNode.view)
        if let day = monthNode.dateAtPoint(location) {
            let monthComponents = calendar.dateComponents([.month, .year], from: monthNode.month)
            
            var dateComponents: DateComponents
            if let date = self.date {
                dateComponents = calendar.dateComponents([.hour, .minute, .day, .month, .year], from: date)
                dateComponents.year = monthComponents.year
                dateComponents.month = monthComponents.month
                dateComponents.day = Int(day)
            } else {
                dateComponents = DateComponents()
                dateComponents.year = monthComponents.year
                dateComponents.month = monthComponents.month
                dateComponents.day = Int(day)
                dateComponents.hour = 11
                dateComponents.minute = 0
            }
            
            if let date = calendar.date(from: dateComponents), date <= self.minimumDate {
                let minimumDateComponents = calendar.dateComponents([.hour, .minute, .day, .month, .year], from: self.minimumDate)
                if let hour = minimumDateComponents.hour {
                    dateComponents.hour = hour + 3
                }
            }
            
            if let date = calendar.date(from: dateComponents), date > self.maximumDate {
                let maximumDateComponents = calendar.dateComponents([.hour, .minute, .day, .month, .year], from: self.maximumDate)
                if let hour = maximumDateComponents.hour {
                    dateComponents.hour = hour - 1
                }
            }
            
            if let date = calendar.date(from: dateComponents), date >= self.minimumDate && date < self.maximumDate {
                let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: date, displayingMonthSelection: self.state.displayingMonthSelection, displayingDateSelection: self.state.displayingDateSelection, displayingTimeSelection: self.state.displayingTimeSelection, selectedMonth: monthNode.month)
                self.updateState(updatedState, animated: false)
                
                self.valueUpdated?(date)
            }
        }
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.view.window?.endEditing(true)
        case .changed:
            let translation = recognizer.translation(in: self.view)
            var transitionFraction = translation.x / self.bounds.width
            if self.currentIndex <= 0 {
                transitionFraction = min(0.0, transitionFraction)
            }
            if self.currentIndex >= self.months.count - 1 {
                transitionFraction = max(0.0, transitionFraction)
            }
            self.transitionFraction = transitionFraction
            if let size = self.validLayout {
                let topInset: CGFloat = 78.0 + 44.0
                let containerSize = CGSize(width: size.width, height: size.height - topInset)
                self.updateItems(size: containerSize, transition: .animated(duration: 0.3, curve: .spring))
            }
        case .cancelled, .ended:
            let velocity = recognizer.velocity(in: self.view)
            var directionIsToRight: Bool?
            if abs(velocity.x) > 10.0 {
                directionIsToRight = velocity.x < 0.0
            } else if abs(self.transitionFraction) > 0.5 {
                directionIsToRight = self.transitionFraction < 0.0
            }
            var updatedIndex = self.currentIndex
            if let directionIsToRight = directionIsToRight {
                if directionIsToRight {
                    updatedIndex = min(updatedIndex + 1, self.months.count - 1)
                } else {
                    updatedIndex = max(updatedIndex - 1, 0)
                }
            }
            self.currentIndex = updatedIndex
            self.transitionFraction = 0.0
            
            let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, displayingDateSelection: self.state.displayingDateSelection, displayingTimeSelection: self.state.displayingTimeSelection, selectedMonth: self.months[updatedIndex])
            self.updateState(updatedState, animated: true)
        default:
            break
        }
    }
    
    private func updateItems(size: CGSize, update: Bool = false, transition: ContainedViewLayoutTransition) {
        var validIds: [Date] = []
        
        if self.currentIndex >= 0 && self.currentIndex < self.months.count {
            let preloadSpan: Int = 1
            for i in max(0, self.currentIndex - preloadSpan) ... min(self.currentIndex + preloadSpan, self.months.count - 1) {
                validIds.append(self.months[i])
                var itemNode: MonthNode?
                var wasAdded = false
                if let current = self.monthNodes[self.months[i]] {
                    itemNode = current
                    current.minimumDate = self.state.minDate
                    current.maximumDate = self.state.maxDate
                    current.date = self.state.date
                    current.updateLayout(size: size)
                } else {
                    wasAdded = true
                    let addedItemNode = MonthNode(theme: self.theme, month: self.months[i], minimumDate: self.state.minDate, maximumDate: self.state.maxDate, date: self.state.date)
                    itemNode = addedItemNode
                    self.monthNodes[self.months[i]] = addedItemNode
                    self.contentNode.addSubnode(addedItemNode)
                }
                if let itemNode = itemNode {
                    let indexOffset = CGFloat(i - self.currentIndex)
                    let itemFrame = CGRect(origin: CGPoint(x: indexOffset * size.width + self.transitionFraction * size.width, y: 0.0), size: size)
                    
                    if wasAdded {
                        itemNode.frame = itemFrame
                        itemNode.updateLayout(size: size)
                    } else {
                        transition.updateFrame(node: itemNode, frame: itemFrame)
                        itemNode.updateLayout(size: size)
                    }
                }
            }
        }
        
        var removeIds: [Date] = []
        for (id, _) in self.monthNodes {
            if !validIds.contains(id) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            if let itemNode = self.monthNodes.removeValue(forKey: id) {
                itemNode.removeFromSupernode()
            }
        }
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let constrainedSize = CGSize(width: min(390.0, size.width), height: size.height)
        
        let timeHeight: CGFloat = 50.0
        let topInset: CGFloat = 78.0 + timeHeight
        let sideInset: CGFloat = 16.0
        
        let month = monthForDate(self.state.selectedMonth)
        let components = calendar.dateComponents([.month, .year], from: month)
        
        let timeTitleSize = self.timeTitleNode.updateLayout(size)
        self.timeTitleNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 12.0), size: timeTitleSize)
        
        let timePickerSize = CGSize(width: constrainedSize.width, height: 180.0)
        self.timePickerNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - constrainedSize.width) / 2.0), y: timeHeight + 11.0), size: timePickerSize)
        
        self.monthTextNode.attributedText = NSAttributedString(string: stringForMonth(strings: self.strings, month: components.month.flatMap { Int32($0) - 1 } ?? 0, ofYear: components.year.flatMap { Int32($0) - 1900 } ?? 100), font: controlFont, textColor: self.state.displayingMonthSelection ? self.theme.accentColor : self.theme.textColor)
        let monthSize = self.monthTextNode.updateLayout(size)
        
        let monthTextFrame = CGRect(x: sideInset, y: 11.0 + timeHeight, width: monthSize.width, height: monthSize.height)
        self.monthTextNode.frame = monthTextFrame
        
        let monthArrowFrame = CGRect(x: monthTextFrame.maxX + 10.0, y: monthTextFrame.minY + 4.0, width: 7.0, height: 12.0)
        self.monthArrowNode.position = CGPoint(x: monthArrowFrame.midX, y: monthArrowFrame.midY)
        self.monthArrowNode.bounds = CGRect(origin: CGPoint(), size: monthArrowFrame.size)
        
        transition.updateTransformRotation(node: self.monthArrowNode, angle: self.state.displayingMonthSelection ? CGFloat.pi / 2.0 : 0.0)
        
        self.monthButtonNode.frame = monthTextFrame.inset(by: UIEdgeInsets(top: -6.0, left: -6.0, bottom: -6.0, right: -30.0))
        
        self.previousButtonNode.isEnabled = self.currentIndex > 0
        self.previousButtonNode.frame = CGRect(x: size.width - sideInset - 54.0, y: monthTextFrame.minY + 1.0, width: 10.0, height: 17.0)
        self.nextButtonNode.isEnabled = self.currentIndex < self.months.count - 1
        self.nextButtonNode.frame = CGRect(x: size.width - sideInset - 13.0, y: monthTextFrame.minY + 1.0, width: 10.0, height: 17.0)
        
        let date = self.date ?? Date()
        var t: time_t = Int(date.timeIntervalSince1970)
        var timeinfo = tm()
        localtime_r(&t, &timeinfo);
        
        let timeString = stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min), dateTimeFormat: self.dateTimeFormat)
        self.timeButtonNode.setTitle(timeString, with: Font.with(size: 17.0, traits: .monospacedNumbers), with: self.state.displayingTimeSelection ? self.theme.accentColor : self.theme.textColor, for: .normal)
        
        var timeSize = self.timeButtonNode.measure(size)
        timeSize.width += 24.0
        timeSize.height = 36.0
        self.timeButtonNode.frame = CGRect(x: size.width - timeSize.width - 4.0, y: 4.0, width: timeSize.width, height: timeSize.height)
        
        let dateString = stringForMediumDate(timestamp: Int32(date.timeIntervalSince1970), strings: self.strings, dateTimeFormat: self.dateTimeFormat, withTime: false)
        self.dateButtonNode.setTitle(dateString, with: Font.with(size: 17.0, traits: .monospacedNumbers), with: self.state.displayingDateSelection ? self.theme.accentColor : self.theme.textColor, for: .normal)
        
        var dateSize = self.dateButtonNode.measure(size)
        dateSize.width += 24.0
        dateSize.height = 36.0
        self.dateButtonNode.frame = CGRect(x: size.width - timeSize.width - 4.0 - 4.0 - dateSize.width, y: 4.0, width: dateSize.width, height: dateSize.height)
        
        let daysSideInset: CGFloat = 12.0
        let cellSize: CGFloat = floor((constrainedSize.width - daysSideInset * 2.0) / 7.0)
        
        var dayIndex: Int32 = Int32(calendar.firstWeekday) - 1
        for i in 0 ..< self.dayNodes.count {
            let dayNode = self.dayNodes[i]
            dayNode.attributedText = NSAttributedString(string: shortStringForDayOfWeek(strings: self.strings, day: dayIndex % 7).uppercased(), font: dayFont, textColor: theme.secondaryTextColor)
            
            let textSize = dayNode.updateLayout(constrainedSize)
            let cellFrame = CGRect(x: floorToScreenPixels((size.width - constrainedSize.width) / 2.0) + daysSideInset + CGFloat(i) * cellSize, y: topInset - 38.0, width: cellSize, height: cellSize)
            let textFrame = CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - textSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - textSize.height) / 2.0)), size: textSize)
            
            dayNode.frame = textFrame
            dayIndex += 1
        }
        
        let containerSize = CGSize(width: constrainedSize.width, height: size.height - topInset)
        self.contentNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - constrainedSize.width) / 2.0), y: topInset), size: containerSize)
        
        self.updateItems(size: containerSize, transition: transition)
        
        let monthInset: CGFloat = timeHeight + 30.0
        self.monthPickerBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: monthInset), size: size)
        self.monthPickerBackgroundNode.isUserInteractionEnabled = self.state.displayingMonthSelection
        transition.updateAlpha(node: self.monthPickerBackgroundNode, alpha: self.state.displayingMonthSelection ? 1.0 : 0.0)
        
        transition.updateAlpha(node: self.previousButtonNode, alpha: self.state.displayingMonthSelection ? 0.0 : 1.0)
        transition.updateAlpha(node: self.nextButtonNode, alpha: self.state.displayingMonthSelection ? 0.0 : 1.0)
        
        self.timePickerBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.timePickerBackgroundNode.isUserInteractionEnabled = self.state.displayingTimeSelection
        transition.updateAlpha(node: self.timePickerBackgroundNode, alpha: self.state.displayingTimeSelection ? 1.0 : 0.0)
        
        self.datePickerBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.datePickerBackgroundNode.isUserInteractionEnabled = self.state.displayingDateSelection
        transition.updateAlpha(node: self.datePickerBackgroundNode, alpha: self.state.displayingDateSelection ? 1.0 : 0.0)
        
        self.monthPickerNode.frame = CGRect(x: sideInset, y: topInset - monthInset, width: size.width - sideInset * 2.0, height: 180.0)
    }
    
    public var toggleDateSelection: () -> Void = {}
    public var toggleTimeSelection: () -> Void = {}

    @objc private func dateButtonPressed() {
        self.toggleDateSelection()
    }
    
    public var displayDateSelection = false {
        didSet {
            if self.displayDateSelection != oldValue {
                let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, displayingDateSelection: self.displayDateSelection, displayingTimeSelection: self.state.displayingTimeSelection, selectedMonth: self.state.selectedMonth)
                self.updateState(updatedState, animated: true)
            }
        }
    }
    
    @objc private func timeButtonPressed() {
        self.toggleTimeSelection()
    }
    
    public var displayTimeSelection = false {
        didSet {
            if self.displayTimeSelection != oldValue {
                let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, displayingDateSelection: self.state.displayingDateSelection, displayingTimeSelection: self.displayTimeSelection, selectedMonth: self.state.selectedMonth)
                self.updateState(updatedState, animated: true)
            }
        }
    }
    
    @objc private func monthButtonPressed() {
        let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: !self.state.displayingMonthSelection, displayingDateSelection: self.state.displayingDateSelection, displayingTimeSelection: self.state.displayingTimeSelection, selectedMonth: self.state.selectedMonth)
        self.updateState(updatedState, animated: true)
    }

    @objc private func previousButtonPressed() {
        guard let month = calendar.date(byAdding: .month, value: -1, to: self.state.selectedMonth), let size = self.validLayout else {
            return
        }
            
        let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, displayingDateSelection: self.state.displayingDateSelection, displayingTimeSelection: self.state.displayingTimeSelection, selectedMonth: month)
        self.updateState(updatedState, animated: false)
        
        self.contentNode.layer.animatePosition(from: CGPoint(x: -size.width, y: 0.0), to: CGPoint(), duration: 0.3, additive: true)
    }
    
    @objc private func nextButtonPressed() {
        guard let month = calendar.date(byAdding: .month, value: 1, to: self.state.selectedMonth), let size = self.validLayout else {
            return
        }
            
        let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, displayingDateSelection: self.state.displayingDateSelection, displayingTimeSelection: self.state.displayingTimeSelection, selectedMonth: month)
        self.updateState(updatedState, animated: false)
        
        self.contentNode.layer.animatePosition(from: CGPoint(x: size.width, y: 0.0), to: CGPoint(), duration: 0.3, additive: true)
    }
}

private final class MonthPickerNode: ASDisplayNode, UIPickerViewDelegate, UIPickerViewDataSource {
    private let theme: DatePickerTheme
    private let strings: PresentationStrings
    
    var date: Date {
        didSet {
            self.updateSelection()
        }
    }
    var yearRange: Range<Int> {
        didSet {
            self.reload()
        }
    }
    
    var minimumDate: Date?
    var maximumDate: Date?
    
    private let valueChanged: (Date) -> Void
    private let pickerView: UIPickerView
    
    init(theme: DatePickerTheme, strings: PresentationStrings, date: Date, yearRange: Range<Int>, valueChanged: @escaping (Date) -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.date = date
        self.yearRange = yearRange
        
        self.valueChanged = valueChanged
        
        self.pickerView = UIPickerView()
        
        super.init()
        
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        self.view.addSubview(self.pickerView)
        
        self.reload()
    }
    
    private func reload() {
        self.pickerView.reloadAllComponents()
        
        self.updateSelection()
    }
    
    private func updateSelection() {
        let month = calendar.component(.month, from: self.date)
        let year = calendar.component(.year, from: self.date)
        
        let monthIndex = month - 1
        if self.pickerView.selectedRow(inComponent: 0) != monthIndex {
            self.pickerView.selectRow(monthIndex, inComponent: 0, animated: false)
        }
        let yearIndex = year - self.yearRange.startIndex
        if self.pickerView.selectedRow(inComponent: 1) != yearIndex {
            self.pickerView.selectRow(yearIndex, inComponent: 1, animated: false)
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 180.0)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 1 {
            return self.yearRange.count
        } else {
            return 12
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 40.0
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let string: String
        if component == 1 {
            string = "\(self.yearRange.startIndex + row)"
        } else {
            string = stringForMonth(strings: self.strings, month: Int32(row))
        }
        return NSAttributedString(string: string, font: Font.medium(15.0), textColor: self.theme.textColor)
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let month = pickerView.selectedRow(inComponent: 0) + 1
        let year = self.yearRange.startIndex + pickerView.selectedRow(inComponent: 1)
        
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self.date)
        let day = components.day ?? 1
        components.day = 1
        components.month = month
        components.year = year
        
        let tempDate = calendar.date(from: components)!
        let numberOfDays = calendar.range(of: .day, in: .month, for: tempDate)!.count
        components.day = min(day, numberOfDays)
        
        var date = calendar.date(from: components)!
        
//        var invalid = false
        if let minimumDate = self.minimumDate, let maximumDate = self.maximumDate {
            let minimumMonthDate = monthForDate(minimumDate)
            var fixDate: Date?
            if date < minimumDate {
                fixDate = minimumMonthDate
                date = minimumDate
            }
            if date > maximumDate {
                fixDate = maximumDate
                date = maximumDate
            }
            if let fixDate {
                let month = calendar.component(.month, from: fixDate)
                let year = calendar.component(.year, from: fixDate)
                self.pickerView.selectRow(month - 1, inComponent: 0, animated: true)
                self.pickerView.selectRow(year - yearRange.startIndex, inComponent: 1, animated: true)
            }
        }
        
//        if !invalid {
        self.date = date
        self.valueChanged(date)
//        }
    }
    
    override func layout() {
        super.layout()
        
        self.pickerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.size.width, height: 180.0))
    }
}

private final class TimePickerNode: ASDisplayNode {
    private let theme: DatePickerTheme
    
    var date: Date {
        get {
            return self.pickerView.date
        }
        set {
            self.pickerView.date = newValue
        }
    }
    
    var minimumDate: Date?
    var maximumDate: Date?
    
    private let valueChanged: (Date) -> Void
    private let pickerView: UIDatePicker
    
    init(theme: DatePickerTheme, date: Date, valueChanged: @escaping (Date) -> Void) {
        self.theme = theme
        UILabel.setDateLabel(theme.textColor)
        
        self.valueChanged = valueChanged
        
        self.pickerView = UIDatePicker()
        if #available(iOS 13.4, *) {
            self.pickerView.preferredDatePickerStyle = .wheels
        }
        
        super.init()
        
        self.pickerView.datePickerMode = .time
        self.view.addSubview(self.pickerView)
        
        self.pickerView.addTarget(self, action: #selector(self.datePickerUpdated), for: .valueChanged)
        
        self.date = date
    }
    
    @objc private func datePickerUpdated() {
        var newDate = self.date
        if let minDate = self.minimumDate, newDate <= minDate {
            if let nextDate = calendar.date(byAdding: .day, value: 1, to: newDate) {
                newDate = nextDate
            }
        }
        self.date = newDate
        self.valueChanged(newDate)
    }

    private func reload() {
        self.pickerView.date = self.date
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 180.0)
    }
    
    override func layout() {
        super.layout()
        
        self.pickerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.size.width, height: 180.0))
    }
}
