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
    
    public init(backgroundColor: UIColor, textColor: UIColor, secondaryTextColor: UIColor, accentColor: UIColor, disabledColor: UIColor, selectionColor: UIColor, selectionTextColor: UIColor, separatorColor: UIColor, segmentedControlTheme: SegmentedControlTheme) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.accentColor = accentColor
        self.disabledColor = disabledColor
        self.selectionColor = selectionColor
        self.selectionTextColor = selectionTextColor
        self.separatorColor = separatorColor
        self.segmentedControlTheme = segmentedControlTheme
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
        return true
    }
}

public extension DatePickerTheme {
    convenience init(theme: PresentationTheme) {
        self.init(backgroundColor: theme.list.itemBlocksBackgroundColor, textColor: theme.list.itemPrimaryTextColor, secondaryTextColor: theme.list.itemSecondaryTextColor, accentColor: theme.list.itemAccentColor, disabledColor: theme.list.itemDisabledTextColor, selectionColor: theme.list.itemCheckColors.fillColor, selectionTextColor: theme.list.itemCheckColors.foregroundColor, separatorColor: theme.list.itemBlocksSeparatorColor, segmentedControlTheme: SegmentedControlTheme(theme: theme))
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
        let selectedMonth: Date
    }
    
    private var state: State
    
    private var theme: DatePickerTheme
    private let strings: PresentationStrings
    
    private let timeTitleNode: ImmediateTextNode
    private let timePickerNode: TimePickerNode
    private let timeSeparatorNode: ASDisplayNode
        
    private let dayNodes: [ImmediateTextNode]
    private var currentIndex = 0
    private var months: [Date] = []
    private var monthNodes: [Date: MonthNode] = [:]
    private let contentNode: ASDisplayNode
    
    private let pickerBackgroundNode: ASDisplayNode
    private var pickerNode: MonthPickerNode
    
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
            
            let updatedState = State(minDate: newValue, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: self.state.selectedMonth)
            self.updateState(updatedState, animated: false)
            
            self.pickerNode.minimumDate = newValue
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
            
            let updatedState = State(minDate: self.state.minDate, maxDate: newValue, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: self.state.selectedMonth)
            self.updateState(updatedState, animated: false)
            
            self.pickerNode.maximumDate = newValue
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
            
            let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: newValue, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: self.state.selectedMonth)
            self.updateState(updatedState, animated: false)
            
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public init(theme: DatePickerTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) {
        self.theme = theme
        self.strings = strings
        self.state = State(minDate: telegramReleaseDate, maxDate: upperLimitDate, date: nil, displayingMonthSelection: false, selectedMonth: monthForDate(Date()))
                
        self.timeTitleNode = ImmediateTextNode()
        self.timeTitleNode.attributedText = NSAttributedString(string: strings.InviteLink_Create_TimeLimitExpiryTime, font: Font.regular(17.0), textColor: theme.textColor)
        
        self.timePickerNode = TimePickerNode(theme: theme, dateTimeFormat: dateTimeFormat, date: self.state.date)
    
        self.timeSeparatorNode = ASDisplayNode()
        self.timeSeparatorNode.backgroundColor = theme.separatorColor
        
        self.dayNodes = (0..<7).map { _ in ImmediateTextNode() }
        
        self.contentNode = ASDisplayNode()
        
        self.pickerBackgroundNode = ASDisplayNode()
        self.pickerBackgroundNode.alpha = 0.0
        self.pickerBackgroundNode.backgroundColor = theme.backgroundColor
        self.pickerBackgroundNode.isUserInteractionEnabled = false
        
        var monthChangedImpl: ((Date) -> Void)?
        
        let initialDate: Date
        if let date = calendar.date(byAdding: .hour, value: 11, to: monthForDate(Date())) {
            initialDate = date
        } else {
            initialDate = monthForDate(Date())
        }
        self.pickerNode = MonthPickerNode(theme: theme, strings: strings, date: self.state.date ?? initialDate, yearRange: yearRange(for: self.state), valueChanged: { date in
            monthChangedImpl?(date)
        })
        self.pickerNode.minimumDate = self.state.minDate
        self.pickerNode.maximumDate = self.state.maxDate
        
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
        
        super.init()
        
        self.clipsToBounds = true
        self.backgroundColor = theme.backgroundColor
        
        self.addSubnode(self.timeTitleNode)
        self.addSubnode(self.timePickerNode)
        
        self.addSubnode(self.contentNode)
                
        self.dayNodes.forEach { self.addSubnode($0) }
        
        self.addSubnode(self.previousButtonNode)
        self.addSubnode(self.nextButtonNode)
        
        self.addSubnode(self.pickerBackgroundNode)
        self.pickerBackgroundNode.addSubnode(self.pickerNode)
        
        self.addSubnode(self.monthTextNode)
        self.addSubnode(self.monthArrowNode)
        self.addSubnode(self.monthButtonNode)
        
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
        
        self.timePickerNode.valueChanged = { [weak self] date in
            if let strongSelf = self {
                let updatedState = State(minDate: strongSelf.state.minDate, maxDate: strongSelf.state.maxDate, date: date, displayingMonthSelection: strongSelf.state.displayingMonthSelection, selectedMonth: strongSelf.state.selectedMonth)
                strongSelf.updateState(updatedState, animated: false)
                
                strongSelf.valueUpdated?(date)
            }
        }
        
        monthChangedImpl = { [weak self] date in
            if let strongSelf = self {
                let updatedState = State(minDate: strongSelf.state.minDate, maxDate: strongSelf.state.maxDate, date: date, displayingMonthSelection: strongSelf.state.displayingMonthSelection, selectedMonth: monthForDate(date))
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
        
        if previousState.minDate != state.minDate || previousState.maxDate != state.maxDate {
            self.pickerNode.yearRange = yearRange(for: state)
            self.setupItems()
        } else if previousState.selectedMonth != state.selectedMonth {
            for i in 0 ..< self.months.count {
                if self.months[i].timeIntervalSince1970 > state.selectedMonth.timeIntervalSince1970 {
                    self.currentIndex = max(0, min(self.months.count - 1, i - 1))
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
        self.pickerNode.date = self.state.date ?? initialDate
        self.timePickerNode.date = self.state.date
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: animated ? .animated(duration: 0.3, curve: .spring) : .immediate)
        }
    }
    
    private func setupItems() {
        let startMonth = monthForDate(self.state.minDate)
        let endMonth = monthForDate(self.state.maxDate)
        let selectedMonth = monthForDate(self.state.selectedMonth)
                
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
                if nextMonth >= endMonth {
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
            
            if let date = calendar.date(from: dateComponents), date >= self.minimumDate && date < self.maximumDate {
                let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: monthNode.month)
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
            
            let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: self.months[updatedIndex])
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
    
        let timeHeight: CGFloat = 44.0
        let topInset: CGFloat = 78.0 + timeHeight
        let sideInset: CGFloat = 16.0
        
        let month = monthForDate(self.state.selectedMonth)
        let components = calendar.dateComponents([.month, .year], from: month)
        
        let timeTitleSize = self.timeTitleNode.updateLayout(size)
        self.timeTitleNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 14.0), size: timeTitleSize)
        
        let timePickerSize = self.timePickerNode.updateLayout(size: size)
        self.timePickerNode.frame = CGRect(origin: CGPoint(x: size.width - timePickerSize.width - 16.0, y: 6.0), size: timePickerSize)
        self.timeSeparatorNode.frame = CGRect(x: 16.0, y: timeHeight, width: size.width - 16.0, height: UIScreenPixel)
        
        self.monthTextNode.attributedText = NSAttributedString(string: stringForMonth(strings: self.strings, month: components.month.flatMap { Int32($0) - 1 } ?? 0, ofYear: components.year.flatMap { Int32($0) - 1900 } ?? 100), font: controlFont, textColor: self.state.displayingMonthSelection ? self.theme.accentColor : self.theme.textColor)
        let monthSize = self.monthTextNode.updateLayout(size)
        
        let monthTextFrame = CGRect(x: sideInset, y: 11.0 + timeHeight, width: monthSize.width, height: monthSize.height)
        self.monthTextNode.frame = monthTextFrame
        
        let monthArrowFrame = CGRect(x: monthTextFrame.maxX + 10.0, y: monthTextFrame.minY + 4.0, width: 7.0, height: 12.0)
        self.monthArrowNode.position = monthArrowFrame.center
        self.monthArrowNode.bounds = CGRect(origin: CGPoint(), size: monthArrowFrame.size)
        
        transition.updateTransformRotation(node: self.monthArrowNode, angle: self.state.displayingMonthSelection ? CGFloat.pi / 2.0 : 0.0)
        
        self.monthButtonNode.frame = monthTextFrame.inset(by: UIEdgeInsets(top: -6.0, left: -6.0, bottom: -6.0, right: -30.0))
        
        self.previousButtonNode.isEnabled = self.currentIndex > 0
        self.previousButtonNode.frame = CGRect(x: size.width - sideInset - 54.0, y: monthTextFrame.minY + 1.0, width: 10.0, height: 17.0)
        self.nextButtonNode.isEnabled = self.currentIndex < self.months.count - 1
        self.nextButtonNode.frame = CGRect(x: size.width - sideInset - 13.0, y: monthTextFrame.minY + 1.0, width: 10.0, height: 17.0)

        let daysSideInset: CGFloat = 12.0
        let cellSize: CGFloat = floor((size.width - daysSideInset * 2.0) / 7.0)
        
        var dayIndex: Int32 = Int32(calendar.firstWeekday) - 1
        for i in 0 ..< self.dayNodes.count {
            let dayNode = self.dayNodes[i]
            dayNode.attributedText = NSAttributedString(string: shortStringForDayOfWeek(strings: self.strings, day: dayIndex % 7).uppercased(), font: dayFont, textColor: theme.secondaryTextColor)
            
            let textSize = dayNode.updateLayout(size)
            let cellFrame = CGRect(x: daysSideInset + CGFloat(i) * cellSize, y: topInset - 38.0, width: cellSize, height: cellSize)
            let textFrame = CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - textSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - textSize.height) / 2.0)), size: textSize)
            
            dayNode.frame = textFrame
            dayIndex += 1
        }
        
        let containerSize = CGSize(width: size.width, height: size.height - topInset)
        self.contentNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: containerSize)
        
        self.updateItems(size: containerSize, transition: transition)
        
        self.pickerBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.pickerBackgroundNode.isUserInteractionEnabled = self.state.displayingMonthSelection
        transition.updateAlpha(node: self.pickerBackgroundNode, alpha: self.state.displayingMonthSelection ? 1.0 : 0.0)
        
        self.pickerNode.frame = CGRect(x: sideInset, y: topInset, width: size.width - sideInset * 2.0, height: 180.0)
    }
    
    @objc private func monthButtonPressed() {
        let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: !self.state.displayingMonthSelection, selectedMonth: self.state.selectedMonth)
        self.updateState(updatedState, animated: true)
    }
    
    @objc private func previousButtonPressed() {
        guard let month = calendar.date(byAdding: .month, value: -1, to: self.state.selectedMonth), let size = self.validLayout else {
            return
        }
            
        let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: month)
        self.updateState(updatedState, animated: false)
        
        self.contentNode.layer.animatePosition(from: CGPoint(x: -size.width, y: 0.0), to: CGPoint(), duration: 0.3, additive: true)
    }
    
    @objc private func nextButtonPressed() {
        guard let month = calendar.date(byAdding: .month, value: 1, to: self.state.selectedMonth), let size = self.validLayout else {
            return
        }
            
        let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: month)
        self.updateState(updatedState, animated: false)
        
        self.contentNode.layer.animatePosition(from: CGPoint(x: size.width, y: 0.0), to: CGPoint(), duration: 0.3, additive: true)
    }
}

private final class MonthPickerNode: ASDisplayNode, UIPickerViewDelegate, UIPickerViewDataSource {
    private let theme: DatePickerTheme
    private let strings: PresentationStrings
    
    var date: Date
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
        
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
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
        
        var invalid = false
        if let minimumDate = self.minimumDate, let maximumDate = self.maximumDate {
            if date < minimumDate {
                date = minimumDate
                invalid = true
            }
            if date > maximumDate {
                date = maximumDate
                invalid = true
            }
            if invalid {
                let month = calendar.component(.month, from: date)
                let year = calendar.component(.year, from: date)
                self.pickerView.selectRow(month - 1, inComponent: 0, animated: true)
                self.pickerView.selectRow(year - yearRange.startIndex, inComponent: 1, animated: true)
            }
        }
        
        if !invalid {
            self.date = date
            self.valueChanged(date)
        }
    }
    
    override func layout() {
        super.layout()
        
        self.pickerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.size.width, height: 180.0))
    }
}

private class TimeInputView: UIView, UIKeyInput {
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    var keyboardType: UIKeyboardType = .numberPad
    
    var text: String = ""
    var hasText: Bool {
        return !self.text.isEmpty
    }
    
    var focusUpdated: ((Bool) -> Void)?
    var textUpdated: ((String) -> Void)?
    
    override func becomeFirstResponder() -> Bool {
        self.didReset = false
        let result = super.becomeFirstResponder()
        self.focusUpdated?(true)
        return result
    }
    
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        self.focusUpdated?(false)
        return result
    }
    
    var length: Int = 4
    
    var didReset = false
    private let nonDigits = CharacterSet.decimalDigits.inverted
    func insertText(_ text: String) {
        if text.rangeOfCharacter(from: nonDigits) != nil {
            return
        }
        if !self.didReset {
            self.text = ""
            self.didReset = true
        }
        var updatedText = self.text
        updatedText.append(text)
        self.text = String(updatedText.suffix(length))
        self.textUpdated?(self.text)
    }
    
    func deleteBackward() {
        self.didReset = true
        var updatedText = self.text
        if !updatedText.isEmpty {
            updatedText.removeLast()
        }
        self.text = updatedText
        self.textUpdated?(self.text)
    }
}

private class TimeInputNode: ASDisplayNode {
    var length: Int {
        get {
            if let view = self.view as? TimeInputView {
                return view.length
            } else {
                return 4
            }
        }
        set {
            if let view = self.view as? TimeInputView {
                view.length = newValue
            }
        }
    }
    var text: String {
        get {
            if let view = self.view as? TimeInputView {
                return view.text
            } else {
                return ""
            }
        }
        set {
            if let view = self.view as? TimeInputView {
                view.text = newValue
            }
        }
    }
    var textUpdated: ((String) -> Void)? {
        didSet {
            if let view = self.view as? TimeInputView {
                view.textUpdated = self.textUpdated
            }
        }
    }
    
    var focusUpdated: ((Bool) -> Void)? {
        didSet {
            if let view = self.view as? TimeInputView {
                view.focusUpdated = self.focusUpdated
            }
        }
    }
    
    override init() {
        super.init()
        
        self.setViewBlock { () -> UIView in
            return TimeInputView()
        }
    }
    
    override func didLoad() {
        super.didLoad()
               
        if let view = self.view as? TimeInputView {
            view.textUpdated = self.textUpdated
        }
    }
    
    func reset() {
        if let view = self.view as? TimeInputView {
            view.didReset = false
        }
    }
}

private final class TimePickerNode: ASDisplayNode {
    enum Selection {
        case none
        case hours
        case minutes
        case all
    }
    
    private var theme: DatePickerTheme
    private let dateTimeFormat: PresentationDateTimeFormat
    
    private let backgroundNode: ASDisplayNode
    private let hoursNode: TapeNode
    private let minutesNode: TapeNode
    private let hoursTopMaskNode: ASDisplayNode
    private let hoursBottomMaskNode: ASDisplayNode
    private let minutesTopMaskNode: ASDisplayNode
    private let minutesBottomMaskNode: ASDisplayNode
    private let colonNode: ImmediateTextNode
    private let borderNode: ASDisplayNode
    private let inputNode: TimeInputNode
    private let amPMSelectorNode: SegmentedControlNode
    
    private var typing = false
    private var typingString = ""
    
    private var typingHours: Int?
    private var typingMinutes: Int?
    private let hoursTypingNode: ImmediateTextNode
    private let minutesTypingNode: ImmediateTextNode
    
    var date: Date? {
        didSet {
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size)
            }
        }
    }
        
    var minimumDate: Date?
    var maximumDate: Date?
    
    var valueChanged: ((Date) -> Void)?
    
    private var validLayout: CGSize?
    
    init(theme: DatePickerTheme, dateTimeFormat: PresentationDateTimeFormat, date: Date?) {
        self.theme = theme
        self.dateTimeFormat = dateTimeFormat
        self.date = date
        self.selection = .none
        
        let backgroundColor = theme.backgroundColor.mixedWith(theme.segmentedControlTheme.backgroundColor.withAlphaComponent(1.0), alpha: theme.segmentedControlTheme.backgroundColor.alpha)
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = backgroundColor
        self.backgroundNode.cornerRadius = 9.0
        
        self.borderNode = ASDisplayNode()
        self.borderNode.cornerRadius = 9.0
        self.borderNode.isUserInteractionEnabled = false
        self.borderNode.isHidden = true
        self.borderNode.borderWidth = 2.0
        self.borderNode.borderColor = theme.accentColor.cgColor
        
        self.colonNode = ImmediateTextNode()
        self.hoursNode = TapeNode()
        self.minutesNode = TapeNode()
        
        self.hoursTypingNode = ImmediateTextNode()
        self.hoursTypingNode.isHidden = true
        self.hoursTypingNode.textAlignment = .right
        self.minutesTypingNode = ImmediateTextNode()
        self.minutesTypingNode.isHidden = true
        self.minutesTypingNode.textAlignment = .right
        
        self.inputNode = TimeInputNode()
        
        self.hoursTopMaskNode = ASDisplayNode()
        self.hoursTopMaskNode.backgroundColor = backgroundColor
        self.hoursBottomMaskNode = ASDisplayNode()
        self.hoursBottomMaskNode.backgroundColor = backgroundColor
        
        self.minutesTopMaskNode = ASDisplayNode()
        self.minutesTopMaskNode.backgroundColor = backgroundColor
        self.minutesBottomMaskNode = ASDisplayNode()
        self.minutesBottomMaskNode.backgroundColor = backgroundColor
        
        let isPM: Bool
        if let date = date {
            let hours = calendar.component(.hour, from: date)
            isPM = hours > 12
        } else {
            isPM = true
        }
        
        self.amPMSelectorNode = SegmentedControlNode(theme: theme.segmentedControlTheme, items: [SegmentedControlItem(title: "AM"), SegmentedControlItem(title: "PM")], selectedIndex: isPM ? 1 : 0)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.colonNode)
        self.addSubnode(self.hoursNode)
        self.addSubnode(self.minutesNode)
        self.addSubnode(self.hoursTopMaskNode)
        self.addSubnode(self.hoursBottomMaskNode)
        self.addSubnode(self.minutesTopMaskNode)
        self.addSubnode(self.minutesBottomMaskNode)
        self.addSubnode(self.hoursTypingNode)
        self.addSubnode(self.minutesTypingNode)
        self.addSubnode(self.borderNode)
        self.addSubnode(self.inputNode)
        self.addSubnode(self.amPMSelectorNode)
        
        self.amPMSelectorNode.selectedIndexChanged = { [weak self] index in
            guard let strongSelf = self, let date = strongSelf.date else {
                return
            }
            let hours = calendar.component(.hour, from: date)
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            if index == 0 && hours >= 12 {
                components.hour = hours - 12
            } else if index == 1 && hours < 12 {
                components.hour = hours + 12
            }
            if let newDate = calendar.date(from: components) {
                strongSelf.date = newDate
                strongSelf.valueChanged?(newDate)
            }
        }
        
        self.inputNode.textUpdated = { [weak self] text in
            self?.handleTextInput(text)
        }
        
        self.inputNode.focusUpdated = { [weak self] focus in
            if focus {
                self?.selection = .all
            } else {
                self?.selection = .none
            }
        }
        
        self.hoursNode.count = {
            switch dateTimeFormat.timeFormat {
                case .military:
                    return 24
                case .regular:
                    return 12
            }
        }
        self.hoursNode.titleAt = { i in
            switch dateTimeFormat.timeFormat {
                case .military:
                    if i < 10 {
                        return "0\(i)"
                    } else {
                        return "\(i)"
                    }
                case .regular:
                    if i == 0 {
                        return "12"
                    } else if i < 10 {
                        return "0\(i)"
                    } else {
                        return "\(i)"
                    }
            }
        }
        self.hoursNode.isScrollingUpdated = { [weak self] scrolling in
            if let strongSelf = self {
                if scrolling {
                    strongSelf.typing = false
                    strongSelf.selection = .hours
                } else {
                    if strongSelf.inputNode.view.isFirstResponder {
                        strongSelf.selection = .all
                    } else {
                        strongSelf.selection = .none
                    }
                }
            }
        }
        self.hoursNode.selected = { [weak self] index in
            self?.updateTime()
        }
        
        self.minutesNode.count = {
            return 60
        }
        self.minutesNode.titleAt = { i in
            if i < 10 {
                return "0\(i)"
            } else {
                return "\(i)"
            }
        }
        self.minutesNode.isScrollingUpdated = { [weak self] scrolling in
            if let strongSelf = self {
                if scrolling {
                    strongSelf.typing = false
                    strongSelf.selection = .minutes
                } else {
                    if strongSelf.inputNode.view.isFirstResponder {
                        strongSelf.selection = .all
                    } else {
                        strongSelf.selection = .none
                    }
                }
            }
        }
        self.minutesNode.selected = { [weak self] _ in
            self?.updateTime()
        }
        
        self.update()
    }
    
    private func updateTime() {
        switch self.dateTimeFormat.timeFormat {
            case .military:
                let hour = self.hoursNode.currentSelectedIndex
                let minute = self.minutesNode.currentSelectedIndex
                
                let date = self.date ?? Date()
                
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                components.hour =  hour
                components.minute = minute
                if var newDate = calendar.date(from: components) {
                    if let minDate = self.minimumDate, newDate <= minDate {
                        if let nextDate = calendar.date(byAdding: .day, value: 1, to: newDate) {
                            newDate = nextDate
                        }
                    }
                    self.date = newDate
                    self.valueChanged?(newDate)
                }
                
            case .regular:
                let hour = self.hoursNode.currentSelectedIndex
                let minute = self.minutesNode.currentSelectedIndex
                
                let date = self.date ?? Date()
                
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                if self.amPMSelectorNode.selectedIndex == 0 {
                    components.hour = hour >= 12 ? hour - 12 : hour
                } else if self.amPMSelectorNode.selectedIndex == 1 {
                    components.hour = hour < 12 ? hour + 12 : hour
                }
                components.minute = minute
                if var newDate = calendar.date(from: components) {
                    if let minDate = self.minimumDate, newDate <= minDate {
                        if let nextDate = calendar.date(byAdding: .day, value: 1, to: newDate) {
                            newDate = nextDate
                        }
                    }
                    self.date = newDate
                    self.valueChanged?(newDate)
                }
        }
    }
    
    override func didLoad() {
        super.didLoad()
                
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.disablesInteractiveModalDismiss = true
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:))))
    }
    
    private func handleTextInput(_ input: String) {
        self.typing = true
        
        let maxHoursValue: Int
        switch self.dateTimeFormat.timeFormat {
            case .military:
                maxHoursValue = 23
            case .regular:
                maxHoursValue = 12
        }
        
        var text = input
        var typingHours: Int?
        var typingMinutes: Int?
        if self.selection == .all {
            if text.count < 2 {
                typingHours = nil
            } else {
                if var value = Int(String(text.prefix(2))) {
                    if value > maxHoursValue {
                        value = value % 10
                    }
                    typingHours = value
                }
            }
            if var value = Int(String(text.suffix(2))) {
                if value >= 60 {
                    value = value % 10
                }
                typingMinutes = value
            }
        } else if self.selection == .hours {
            text = String(text.suffix(2))
            if var value = Int(text) {
                if value > maxHoursValue {
                    value = value % 10
                }
                typingHours = value
            } else {
                typingHours = nil
            }
        } else if self.selection == .minutes {
            text = String(text.suffix(2))
            if var value = Int(text) {
                if value >= 60 {
                    value = value % 10
                }
                typingMinutes = value
            } else {
                typingMinutes = nil
            }
        }
        self.typingHours = typingHours
        self.typingMinutes = typingMinutes
        
        if let date = self.date {
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            if let typingHours = typingHours {
                components.hour = typingHours
            }
            if let typingMinutes = typingMinutes {
                components.minute = typingMinutes
            }
            if let newDate = calendar.date(from: components) {
                self.date = newDate
                self.valueChanged?(newDate)
                self.updateTapes()
            }
        }
        
        self.update()
    }
    
    private var selection: Selection {
        didSet {
            self.typing = false
            self.inputNode.reset()
            switch self.selection {
                case .none:
                    break
                case .hours:
                    self.inputNode.text = self.hoursNode.titleAt?(self.hoursNode.currentSelectedIndex) ?? ""
                    self.inputNode.length = 2
                case .minutes:
                    self.inputNode.text = self.minutesNode.titleAt?(self.minutesNode.currentSelectedIndex) ?? ""
                    self.inputNode.length = 2
                case .all:
                    let hours = self.minutesNode.titleAt?(self.hoursNode.currentSelectedIndex) ?? ""
                    let minutes = self.minutesNode.titleAt?(self.minutesNode.currentSelectedIndex) ?? ""
                    self.inputNode.text = "\(hours)\(minutes)"
                    self.inputNode.length = 4
            }
            self.update()
        }
    }
    
    private func update() {
        if case .none = self.selection {
            self.borderNode.isHidden = true
        } else {
            self.borderNode.isHidden = false
        }
        
        let colonColor: UIColor
        switch self.selection {
            case .none:
                colonColor = self.theme.textColor
                self.colonNode.alpha = 1.0
                
                self.hoursNode.textColor = self.theme.textColor
                self.minutesNode.textColor = self.theme.textColor
                self.hoursNode.alpha = 1.0
                self.minutesNode.alpha = 1.0
                
                self.hoursTopMaskNode.alpha = 1.0
                self.hoursBottomMaskNode.alpha = 1.0
                self.minutesTopMaskNode.alpha = 1.0
                self.minutesBottomMaskNode.alpha = 1.0
                
                self.typing = false
                self.typingHours = nil
                self.typingMinutes = nil
                self.hoursTypingNode.isHidden = true
                self.minutesTypingNode.isHidden = true
                
                self.hoursNode.isHidden = false
                self.minutesNode.isHidden = false
            case .hours:
                colonColor = self.theme.textColor
                self.colonNode.alpha = 0.35
                
                self.hoursNode.textColor = self.theme.accentColor
                self.minutesNode.textColor = self.theme.textColor
                self.hoursNode.alpha = 1.0
                self.minutesNode.alpha = 0.35
                
                self.hoursTopMaskNode.alpha = 0.5
                self.hoursBottomMaskNode.alpha = 0.5
                self.minutesTopMaskNode.alpha = 1.0
                self.minutesBottomMaskNode.alpha = 1.0
                
                if self.typing {
                    self.hoursTypingNode.isHidden = false
                    self.minutesTypingNode.isHidden = true
                    
                    self.hoursNode.isHidden = true
                    self.minutesNode.isHidden = false
                } else {
                    self.hoursTypingNode.isHidden = true
                    self.minutesTypingNode.isHidden = true
                    
                    self.hoursNode.isHidden = false
                    self.minutesNode.isHidden = false
                }
            case .minutes:
                colonColor = self.theme.textColor
                self.colonNode.alpha = 0.35
                
                self.hoursNode.textColor = self.theme.textColor
                self.minutesNode.textColor = self.theme.accentColor
                self.hoursNode.alpha = 0.35
                self.minutesNode.alpha = 1.0
                
                self.hoursTopMaskNode.alpha = 1.0
                self.hoursBottomMaskNode.alpha = 1.0
                self.minutesTopMaskNode.alpha = 0.5
                self.minutesBottomMaskNode.alpha = 0.5
                
                if self.typing {
                    self.hoursTypingNode.isHidden = true
                    self.minutesTypingNode.isHidden = false
                    
                    self.hoursNode.isHidden = false
                    self.minutesNode.isHidden = true
                } else {
                    self.hoursTypingNode.isHidden = true
                    self.minutesTypingNode.isHidden = true
                    
                    self.hoursNode.isHidden = false
                    self.minutesNode.isHidden = false
                }
            case .all:
                colonColor = self.theme.accentColor
                self.colonNode.alpha = 1.0
                
                self.hoursNode.textColor = self.theme.accentColor
                self.minutesNode.textColor = self.theme.accentColor
                self.hoursNode.alpha = 1.0
                self.minutesNode.alpha = 1.0
                
                self.hoursTopMaskNode.alpha = 0.5
                self.hoursBottomMaskNode.alpha = 0.5
                self.minutesTopMaskNode.alpha = 0.5
                self.minutesBottomMaskNode.alpha = 0.5
                
                if self.typing {
                    self.hoursTypingNode.isHidden = false
                    self.minutesTypingNode.isHidden = false
                    
                    self.hoursNode.isHidden = true
                    self.minutesNode.isHidden = true
                } else {
                    self.hoursTypingNode.isHidden = true
                    self.minutesTypingNode.isHidden = true
                    
                    self.hoursNode.isHidden = false
                    self.minutesNode.isHidden = false
                }
        }
        
        if let size = self.validLayout {
            let hoursString: String
            if let typingHours = self.typingHours {
                if typingHours < 10 {
                    hoursString = "0\(typingHours)"
                } else {
                    hoursString = "\(typingHours)"
                }
            } else {
                hoursString = ""
            }
            let minutesString: String
            if let typingMinutes = self.typingMinutes {
                if typingMinutes < 10 {
                    minutesString = "0\(typingMinutes)"
                } else {
                    minutesString = "\(typingMinutes)"
                }
            } else {
                minutesString = ""
            }
            self.hoursTypingNode.attributedText = NSAttributedString(string: hoursString, font: Font.with(size: 21.0, design: .regular, weight: .regular, traits: [.monospacedNumbers]), textColor: theme.textColor)
            
            let hoursSize = self.hoursTypingNode.updateLayout(size)
            self.hoursTypingNode.frame = CGRect(origin: CGPoint(x: 37.0 - hoursSize.width - 3.0 + UIScreenPixel, y: 6.0), size: hoursSize)
            
            self.minutesTypingNode.attributedText = NSAttributedString(string: minutesString, font: Font.with(size: 21.0, design: .regular, weight: .regular, traits: [.monospacedNumbers]), textColor: theme.textColor)
            
            let minutesSize = self.minutesTypingNode.updateLayout(size)
            self.minutesTypingNode.frame = CGRect(origin: CGPoint(x: 75.0 - minutesSize.width - 9.0 + UIScreenPixel, y: 6.0), size: minutesSize)
            
            self.colonNode.attributedText = NSAttributedString(string: ":", font: Font.with(size: 21.0, design: .regular, weight: .regular, traits: [.monospacedNumbers]), textColor: colonColor)
            let _ = self.colonNode.updateLayout(size)
        }
    }
    
    @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if !self.inputNode.view.isFirstResponder {
            self.inputNode.view.becomeFirstResponder()
            self.selection = .all
        } else {
            let location = gestureRecognizer.location(in: self.view)
            if location.x < 37.0 {
                if self.selection == .hours {
                    self.selection = .all
                } else {
                    self.selection = .hours
                }
            } else if location.x > 37.0 && location.x < 75.0 {
                if self.selection == .minutes {
                    self.selection = .all
                } else {
                    self.selection = .minutes
                }
            }
        }
    }
    
    func updateTheme(_ theme: DatePickerTheme) {
        self.theme = theme
        
        self.backgroundNode.backgroundColor = theme.segmentedControlTheme.backgroundColor
        self.borderNode.borderColor = theme.accentColor.cgColor
    }
    
    func updateTapes() {
        let hours: Int32
        let minutes: Int32
        if let date = self.date {
            hours = Int32(calendar.component(.hour, from: date))
            minutes = Int32(calendar.component(.minute, from: date))
        } else {
            hours = 11
            minutes = 0
        }
        
        switch self.dateTimeFormat.timeFormat {
            case .military:
                self.hoursNode.selectRow(Int(hours), animated: false)
                self.minutesNode.selectRow(Int(minutes), animated: false)
            case .regular:
                var h12Hours = hours
                if hours == 0 {
                    h12Hours = 12
                } else if hours > 12 {
                    h12Hours = hours - 12
                }
                self.hoursNode.selectRow(Int(h12Hours), animated: false)
                self.minutesNode.selectRow(Int(minutes), animated: false)
        }
    }
    
    func updateLayout(size: CGSize) -> CGSize {
        self.validLayout = size
        
        self.backgroundNode.frame = CGRect(x: 0.0, y: 0.0, width: 75.0, height: 36.0)
        self.borderNode.frame = self.backgroundNode.frame
        
        var contentSize = CGSize()
        
        self.updateTapes()
    
        self.hoursNode.frame = CGRect(x: 3.0, y: 0.0, width: 36.0, height: 36.0)
        self.minutesNode.frame = CGRect(x: 35.0, y: 0.0, width: 36.0, height: 36.0)

        self.hoursTopMaskNode.frame = CGRect(x: 9.0, y: 0.0, width: 28.0, height: 5.0)
        self.hoursBottomMaskNode.frame = CGRect(x: 9.0, y: 36.0 - 5.0, width: 28.0, height: 5.0)
        self.minutesTopMaskNode.frame = CGRect(x: 37.0, y: 0.0, width: 28.0, height: 5.0)
        self.minutesBottomMaskNode.frame = CGRect(x: 37.0, y: 36.0 - 5.0, width: 28.0, height: 5.0)
        
        self.colonNode.attributedText = NSAttributedString(string: ":", font: Font.with(size: 21.0, design: .regular, weight: .regular, traits: [.monospacedNumbers]), textColor: self.theme.textColor)
        
        let colonSize = self.colonNode.updateLayout(size)
        self.colonNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((self.backgroundNode.frame.width - colonSize.width) / 2.0), y: floorToScreenPixels((self.backgroundNode.frame.height - colonSize.height) / 2.0) - 2.0), size: colonSize)
        
        self.inputNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0))
        
        if self.dateTimeFormat.timeFormat == .military {
            contentSize = self.backgroundNode.frame.size
            self.amPMSelectorNode.isHidden = true
        } else {
            self.amPMSelectorNode.isHidden = false
            let segmentedSize = self.amPMSelectorNode.updateLayout(.sizeToFit(maximumWidth: 120.0, minimumWidth: 80.0, height: 36.0), transition: .immediate)
            self.amPMSelectorNode.frame = CGRect(x: 85.0, y: 0.0, width: segmentedSize.width, height: 36.0)
            contentSize = CGSize(width: 85.0 + segmentedSize.width, height: 36.0)
        }
        
        return contentSize
    }
}
