import Foundation
import Display
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import TelegramStringFormatting

public final class DatePickerTheme: Equatable {
    public let backgroundColor: UIColor
    public let textColor: UIColor
    public let secondaryTextColor: UIColor
    public let accentColor: UIColor
    public let disabledColor: UIColor
    public let selectionColor: UIColor
    public let selectionTextColor: UIColor
    
    public init(backgroundColor: UIColor, textColor: UIColor, secondaryTextColor: UIColor, accentColor: UIColor, disabledColor: UIColor, selectionColor: UIColor, selectionTextColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.accentColor = accentColor
        self.disabledColor = disabledColor
        self.selectionColor = selectionColor
        self.selectionTextColor = selectionTextColor
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
        return true
    }
}

public extension DatePickerTheme {
    convenience init(theme: PresentationTheme) {
        self.init(backgroundColor: theme.list.itemBlocksBackgroundColor, textColor: theme.list.itemPrimaryTextColor, secondaryTextColor: theme.list.itemSecondaryTextColor, accentColor: theme.list.itemAccentColor, disabledColor: theme.list.itemDisabledTextColor, selectionColor: theme.list.itemCheckColors.fillColor, selectionTextColor: theme.list.itemCheckColors.foregroundColor)
    }
}

private let telegramReleaseDate = Date(timeIntervalSince1970: 1376438400.0)
private let upperLimitDate = Date(timeIntervalSince1970: Double(Int32.max - 1))

private let controlFont = Font.regular(17.0)
private let dayFont = Font.regular(13.0)
private let dateFont = Font.with(size: 17.0, design: .regular, traits: .monospacedNumbers)
private let selectedDateFont = Font.with(size: 17.0, design: .regular, traits: [.bold, .monospacedNumbers])

private let calendar = Calendar(identifier: .gregorian)

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

public final class DatePickerNode: ASDisplayNode {
    class MonthNode: ASDisplayNode {
        private let month: Date
        
        var theme: DatePickerTheme {
            didSet {
                self.selectionNode.image = generateStretchableFilledCircleImage(diameter: 44.0, color: self.theme.selectionColor)
                if let size = self.validSize {
                    self.updateLayout(size: size)
                }
            }
        }
        
        var maximumDate: Date? {
            didSet {
                if let size = self.validSize {
                    self.updateLayout(size: size)
                }
            }
        }

        var minimumDate: Date? {
            didSet {
                if let size = self.validSize {
                    self.updateLayout(size: size)
                }
            }
        }
        
        var date: Date? {
            didSet {
                if let size = self.validSize {
                    self.updateLayout(size: size)
                }
            }
        }
        
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
                
        func updateLayout(size: CGSize) {
            var weekday = self.firstWeekday
            var started = false
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
                if started {
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
                    
                    let textNode = self.dateNodes[i]
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
                        break
                    }
                }
            }
        }
    }
    
    struct State {
        let minDate: Date
        let maxDate: Date
        let date: Date
        
        let displayingMonthSelection: Bool
        let selectedMonth: Date
    }
    
    private var state: State
    
    private var theme: DatePickerTheme
    private let strings: PresentationStrings
    
    private let timeTitleNode: ImmediateTextNode
    private let timeFieldNode: ASImageNode
        
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
    
    private var gestureRecognizer: UIPanGestureRecognizer?
    private var gestureSelectedIndex: Int?
    
    private var validLayout: CGSize?
    
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
            
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
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
            
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    public var date: Date {
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
    
    public init(theme: DatePickerTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        self.state = State(minDate: telegramReleaseDate, maxDate: upperLimitDate, date: Date(), displayingMonthSelection: false, selectedMonth: monthForDate(Date()))
                
        self.timeTitleNode = ImmediateTextNode()
        self.timeFieldNode = ASImageNode()
        self.timeFieldNode.displaysAsynchronously = false
        self.timeFieldNode.displayWithoutProcessing = true
    
        self.dayNodes = (0..<7).map { _ in ImmediateTextNode() }
        
        self.contentNode = ASDisplayNode()
        
        self.pickerBackgroundNode = ASDisplayNode()
        self.pickerBackgroundNode.alpha = 0.0
        self.pickerBackgroundNode.backgroundColor = theme.backgroundColor
        self.pickerBackgroundNode.isUserInteractionEnabled = false
        
        self.pickerNode = MonthPickerNode(theme: theme, strings: strings, date: self.state.date, yearRange: 2013 ..< 2038, valueChanged: { date in
            
        })
        
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
        self.nextButtonNode.setImage(generateNavigationArrowImage(color: theme.accentColor, mirror: false), for: .normal)
        
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
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.contentNode.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
        self.contentNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    private func updateState(_ state: State, animated: Bool) {
        let previousState = self.state
        self.state = state
        
        if previousState.minDate != state.minDate || previousState.maxDate != state.maxDate {
            self.setupItems()
        } else if previousState.selectedMonth != state.selectedMonth {
            for i in 0 ..< self.months.count {
                if self.months[i].timeIntervalSince1970 > state.selectedMonth.timeIntervalSince1970 {
                    self.currentIndex = max(0, min(self.months.count - 1, i - 1))
                    break
                }
            }
        }
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: animated ? .animated(duration: 0.3, curve: .spring) : .immediate)
        }
    }
    
    private func setupItems() {
        let startMonth = monthForDate(self.state.minDate)
        let endMonth = monthForDate(self.state.maxDate)
        let selectedMonth = monthForDate(self.state.selectedMonth)
        
        let calendar = Calendar.current
        
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
                let topInset: CGFloat = 78.0
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
                    current.updateLayout(size: size)
                } else {
                    wasAdded = true
                    let addedItemNode = MonthNode(theme: self.theme, month: self.months[i], minimumDate: self.minimumDate, maximumDate: self.maximumDate, date: self.date)
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
    
        let topInset: CGFloat = 78.0
        let sideInset: CGFloat = 16.0
        
        let month = monthForDate(self.state.selectedMonth)
        let components = calendar.dateComponents([.month, .year], from: month)
        
        self.monthTextNode.attributedText = NSAttributedString(string: stringForMonth(strings: self.strings, month: components.month.flatMap { Int32($0) - 1 } ?? 0, ofYear: components.year.flatMap { Int32($0) - 1900 } ?? 100), font: controlFont, textColor: theme.textColor)
        let monthSize = self.monthTextNode.updateLayout(size)
        
        let monthTextFrame = CGRect(x: sideInset, y: 10.0, width: monthSize.width, height: monthSize.height)
        self.monthTextNode.frame = monthTextFrame
        self.monthArrowNode.frame = CGRect(x: monthTextFrame.maxX + 10.0, y: monthTextFrame.minY + 4.0, width: 7.0, height: 12.0)
        self.monthButtonNode.frame = monthTextFrame.inset(by: UIEdgeInsets(top: -6.0, left: -6.0, bottom: -6.0, right: -30.0))
        
        self.previousButtonNode.frame = CGRect(x: size.width - sideInset - 54.0, y: monthTextFrame.minY + 1.0, width: 10.0, height: 17.0)
        self.nextButtonNode.frame = CGRect(x: size.width - sideInset - 13.0, y: monthTextFrame.minY + 1.0, width: 10.0, height: 17.0)

        let daysSideInset: CGFloat = 12.0
        let cellSize: CGFloat = floor((size.width - daysSideInset * 2.0) / 7.0)
        
        for i in 0 ..< self.dayNodes.count {
            let dayNode = self.dayNodes[i]
            dayNode.attributedText = NSAttributedString(string: shortStringForDayOfWeek(strings: self.strings, day: Int32(i)).uppercased(), font: dayFont, textColor: theme.secondaryTextColor)
            
            let textSize = dayNode.updateLayout(size)
            let cellFrame = CGRect(x: daysSideInset + CGFloat(i) * cellSize, y: 40.0, width: cellSize, height: cellSize)
            let textFrame = CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - textSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - textSize.height) / 2.0)), size: textSize)
            
            dayNode.frame = textFrame
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
    
    private var date: Date
    private var yearRange: Range<Int> {
        didSet {
            self.pickerView.reloadAllComponents()
        }
    }
    
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
        
        self.pickerView.reloadAllComponents()

//        self.pickerView.selectRow(index, inComponent: 0, animated: false)
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
//        self.valueChanged(timeoutValues[row])
    }
    
    override func layout() {
        super.layout()
        
        self.pickerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.size.width, height: 180.0))
    }
}
