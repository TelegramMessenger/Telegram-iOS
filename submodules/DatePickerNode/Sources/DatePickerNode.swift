import Foundation
import Display
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import TelegramStringFormatting

private let textFont = Font.regular(13.0)
private let selectedTextFont = Font.bold(13.0)

public final class DatePickerTheme: Equatable {
    public let backgroundColor: UIColor
    public let textColor: UIColor
    public let secondaryTextColor: UIColor
    public let accentColor: UIColor
    public let disabledColor: UIColor
    public let selectionColor: UIColor
    public let selectedCurrentTextColor: UIColor
    public let secondarySelectionColor: UIColor
    
    public init(backgroundColor: UIColor, textColor: UIColor, secondaryTextColor: UIColor, accentColor: UIColor, disabledColor: UIColor, selectionColor: UIColor, selectedCurrentTextColor: UIColor, secondarySelectionColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.accentColor = accentColor
        self.disabledColor = disabledColor
        self.selectionColor = selectionColor
        self.selectedCurrentTextColor = selectedCurrentTextColor
        self.secondarySelectionColor = secondarySelectionColor
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
        if lhs.selectedCurrentTextColor != rhs.selectedCurrentTextColor {
            return false
        }
        if lhs.secondarySelectionColor != rhs.secondarySelectionColor {
            return false
        }
        return true
    }
}

//public extension DatePickerTheme {
//    convenience init(theme: PresentationTheme) {
//        self.init(backgroundColor: theme.rootController.navigationBar.segmentedBackgroundColor, foregroundColor: theme.rootController.navigationBar.segmentedForegroundColor, shadowColor: .black, textColor: theme.rootController.navigationBar.segmentedTextColor, dividerColor: theme.rootController.navigationBar.segmentedDividerColor)
//    }
//}

private class SegmentedControlItemNode: HighlightTrackingButtonNode {
}

private let telegramReleaseDate = Date(timeIntervalSince1970: 1376438400.0)
private let upperLimitDate = Date(timeIntervalSince1970: Double(Int32.max - 1))

private let dayFont = Font.regular(13.0)
private let dateFont = Font.with(size: 13.0, design: .regular, traits: .monospacedNumbers)
private let selectedDateFont = Font.bold(13.0)

private let calendar = Calendar(identifier: .gregorian)

private func monthForDate(_ date: Date) -> Date {
    var components = calendar.dateComponents([.year, .month], from: date)
    components.hour = 0
    components.minute = 0
    components.second = 0
    return calendar.date(from: components)!
}

public final class DatePickerNode: ASDisplayNode, UIScrollViewDelegate {
    class MonthNode: ASDisplayNode {
        private let month: Date
        
        var theme: DatePickerTheme {
            didSet {
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
            
            for i in 0 ..< 42 {
                let row: Int = Int(floor(Float(i) / 7.0))
                let col: Int = i % 7
                
                if !started && weekday == self.startWeekday {
                    started = true
                }
                if started {
                    count += 1
                    
                    var isAvailableDate = true
                    if let minimumDate = self.minimumDate {
                        var components = calendar.dateComponents([.year, .month], from: self.month)
                        components.day = count
                        components.hour = 0
                        components.minute = 0
                        let date = calendar.date(from: components)!
                        if date < minimumDate {
                            isAvailableDate = false
                        }
                    }
                    if let maximumDate = self.maximumDate {
                        var components = calendar.dateComponents([.year, .month], from: self.month)
                        components.day = count
                        components.hour = 0
                        components.minute = 0
                        let date = calendar.date(from: components)!
                        if date > maximumDate {
                            isAvailableDate = false
                        }
                    }
                    var isSelectedDate = false
                    var isSelectedAndCurrentDate = false
                    
                    let color: UIColor
                    if !isAvailableDate {
                        color = self.theme.disabledColor
                    } else if isSelectedAndCurrentDate {
                        color = .white
                    } else if isSelectedDate {
                        color = self.theme.accentColor
                    } else {
                        color = self.theme.textColor
                    }
                    
                    let textNode = self.dateNodes[i]
                    textNode.attributedText = NSAttributedString(string: "\(count)", font: dateFont, textColor: color)
                    
                    let textSize = textNode.updateLayout(size)
                    textNode.frame = CGRect(origin: CGPoint(x: CGFloat(col) * 20.0, y: CGFloat(row) * 20.0), size: textSize)
                    
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
    
    private let monthButtonNode: HighlightTrackingButtonNode
    private let monthTextNode: ImmediateTextNode
    private let monthArrowNode: ASImageNode
    
    private let previousButtonNode: HighlightableButtonNode
    private let nextButtonNode: HighlightableButtonNode
    
    private let dayNodes: [ImmediateTextNode]
    private var previousMonthNode: MonthNode?
    private var currentMonthNode: MonthNode?
    private var nextMonthNode: MonthNode?
    private let scrollNode: ASScrollNode
    
    private var gestureRecognizer: UIPanGestureRecognizer?
    private var gestureSelectedIndex: Int?
    
    private var validLayout: CGSize?
    
    public var maximumDate: Date? {
        didSet {
            
        }
    }
    public var minimumDate: Date = telegramReleaseDate {
        didSet {
            
        }
    }
    public var date: Date = Date() {
        didSet {
            guard self.date != oldValue else {
                return
            }
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
    
        self.monthButtonNode = HighlightTrackingButtonNode()
        
        self.monthTextNode = ImmediateTextNode()
        
        self.monthArrowNode = ASImageNode()
        self.monthArrowNode.displaysAsynchronously = false
        self.monthArrowNode.displayWithoutProcessing = true
        
        self.previousButtonNode = HighlightableButtonNode()
        self.nextButtonNode = HighlightableButtonNode()
        
        self.dayNodes = (0..<7).map { _ in ImmediateTextNode() }
        
        self.scrollNode = ASScrollNode()
        
        super.init()
        
        self.backgroundColor = theme.backgroundColor
        
        self.addSubnode(self.monthTextNode)
        self.addSubnode(self.monthArrowNode)
        self.addSubnode(self.monthButtonNode)
        
        self.addSubnode(self.previousButtonNode)
        self.addSubnode(self.nextButtonNode)
        
        self.addSubnode(self.scrollNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.scrollNode.view.isPagingEnabled = true
        self.scrollNode.view.delegate = self
    }
    
    private func updateState(_ state: State, animated: Bool) {
        self.state = state
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
        }
    }
    
    public func updateTheme(_ theme: DatePickerTheme) {
        guard theme != self.theme else {
            return
        }
        self.theme = theme
        
        self.backgroundColor = self.theme.backgroundColor
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.view.window?.endEditing(true)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            if let size = self.validLayout {
                self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
    
        let topInset: CGFloat = 60.0
        
        let scrollSize = CGSize(width: size.width, height: size.height - topInset)
        self.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: scrollSize)
        self.scrollNode.view.contentSize = CGSize(width: scrollSize.width * 3.0, height: scrollSize.height)
        self.scrollNode.view.contentOffset = CGPoint(x: scrollSize.width, y: 0.0)
        
        for i in 0 ..< self.dayNodes.count {
            let dayNode = self.dayNodes[i]
            
            let day = Int32(i)
            dayNode.attributedText = NSAttributedString(string: shortStringForDayOfWeek(strings: self.strings, day: day), font: dayFont, textColor: theme.secondaryTextColor)
            let size = dayNode.updateLayout(size)
            dayNode.frame = CGRect(origin: CGPoint(x: CGFloat(i) * 20.0, y: 0.0), size: size)
        }
    }
    
    @objc private func monthButtonPressed(_ button: SegmentedControlItemNode) {
        
    }
    
    @objc private func previousButtonPressed(_ button: SegmentedControlItemNode) {
     
    }
    
    @objc private func nextButtonPressed(_ button: SegmentedControlItemNode) {
     
    }
}
