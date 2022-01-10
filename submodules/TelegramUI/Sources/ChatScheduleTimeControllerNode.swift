import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import SolidRoundedButtonNode
import PresentationDataUtils
import UIKitRuntimeUtils

class ChatScheduleTimeControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let mode: ChatScheduleTimeControllerMode
    private let controllerStyle: ChatScheduleTimeControllerStyle
    private var presentationData: PresentationData
    private let dismissByTapOutside: Bool
    private let minimalTime: Int32?
    
    private let dimNode: ASDisplayNode
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let effectNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let cancelButton: HighlightableButtonNode
    private let doneButton: SolidRoundedButtonNode
    private let onlineButton: SolidRoundedButtonNode
    
    private var pickerView: UIDatePicker?
    private let dateFormatter: DateFormatter
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var completion: ((Int32) -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(context: AccountContext, presentationData: PresentationData, mode: ChatScheduleTimeControllerMode, style: ChatScheduleTimeControllerStyle, currentTime: Int32?, minimalTime: Int32?, dismissByTapOutside: Bool) {
        self.context = context
        self.mode = mode
        self.controllerStyle = style
        self.presentationData = presentationData
        self.dismissByTapOutside = dismissByTapOutside
        self.minimalTime = minimalTime
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.clipsToBounds = true
        self.backgroundNode.cornerRadius = 16.0
        
        let backgroundColor: UIColor
        let textColor: UIColor
        let accentColor: UIColor
        let buttonColor: UIColor
        let buttonTextColor: UIColor
        let blurStyle: UIBlurEffect.Style
        switch style {
            case .default:
                backgroundColor = self.presentationData.theme.actionSheet.itemBackgroundColor
                textColor = self.presentationData.theme.actionSheet.primaryTextColor
                accentColor = self.presentationData.theme.actionSheet.controlAccentColor
                buttonColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
                buttonTextColor = accentColor
                blurStyle = self.presentationData.theme.actionSheet.backgroundType == .light ? .light : .dark
            case .media:
                backgroundColor = UIColor(rgb: 0x1c1c1e)
                textColor = .white
                accentColor = self.presentationData.theme.actionSheet.controlAccentColor
                buttonColor = UIColor(rgb: 0x2b2b2f)
                buttonTextColor = .white
                blurStyle = .dark
        }
        
        self.effectNode = ASDisplayNode(viewBlock: {
            return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        })
        
        self.contentBackgroundNode = ASDisplayNode()
        self.contentBackgroundNode.backgroundColor = backgroundColor
        
        let title: String
        switch mode {
            case .scheduledMessages:
                title = self.presentationData.strings.Conversation_ScheduleMessage_Title
            case .reminders:
                title = self.presentationData.strings.Conversation_SetReminder_Title
        }
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: textColor)
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setTitle(self.presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: accentColor, for: .normal)
        
        self.doneButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 52.0, cornerRadius: 11.0, gloss: false)
        
        self.onlineButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: buttonColor, foregroundColor: buttonTextColor), font: .regular, height: 52.0, cornerRadius: 11.0, gloss: false)
        self.onlineButton.title = self.presentationData.strings.Conversation_ScheduleMessage_SendWhenOnline

        self.dateFormatter = DateFormatter()
        self.dateFormatter.timeStyle = .none
        self.dateFormatter.dateStyle = .short
        self.dateFormatter.timeZone = TimeZone.current
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
        
        self.wrappingScrollNode.addSubnode(self.backgroundNode)
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        
        self.backgroundNode.addSubnode(self.effectNode)
        self.backgroundNode.addSubnode(self.contentBackgroundNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        self.contentContainerNode.addSubnode(self.cancelButton)
        self.contentContainerNode.addSubnode(self.doneButton)
        if case .scheduledMessages(true) = self.mode {
            self.contentContainerNode.addSubnode(self.onlineButton)
        }
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        self.doneButton.pressed = { [weak self] in
            if let strongSelf = self, let pickerView = strongSelf.pickerView {
                if pickerView.date < Date() {
                    strongSelf.updateMinimumDate()
                    strongSelf.updateButtonTitle()
                    pickerView.layer.addShakeAnimation()
                } else {
                    strongSelf.doneButton.isUserInteractionEnabled = false
                    strongSelf.completion?(Int32(pickerView.date.timeIntervalSince1970))
                }
            }
        }
        self.onlineButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.onlineButton.isUserInteractionEnabled = false
                strongSelf.completion?(scheduleWhenOnlineTimestamp)
            }
        }
        
        self.setupPickerView(currentTime: currentTime)
        self.updateButtonTitle()
    }
    
    func setupPickerView(currentTime: Int32? = nil) {
        var currentDate: Date?
        if let pickerView = self.pickerView {
            currentDate = pickerView.date
            pickerView.removeFromSuperview()
        }
        
        let textColor: UIColor
        switch self.controllerStyle {
            case .default:
                textColor = self.presentationData.theme.actionSheet.primaryTextColor
            case .media:
                textColor = UIColor.white
        }
        
        UILabel.setDateLabel(textColor)
        
        let pickerView = UIDatePicker()
        pickerView.timeZone = TimeZone(secondsFromGMT: 0)
        pickerView.datePickerMode = .countDownTimer
        pickerView.datePickerMode = .dateAndTime
        pickerView.locale = Locale.current
        pickerView.timeZone = TimeZone.current
        pickerView.minuteInterval = 1
        self.contentContainerNode.view.addSubview(pickerView)
        pickerView.addTarget(self, action: #selector(self.datePickerUpdated), for: .valueChanged)
        if #available(iOS 13.4, *) {
            pickerView.preferredDatePickerStyle = .wheels
        }
        pickerView.setValue(textColor, forKey: "textColor")
        self.pickerView = pickerView
        
        self.updateMinimumDate(currentTime: currentTime)
        if let currentDate = currentDate {
            pickerView.date = currentDate
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        let previousTheme = self.presentationData.theme
        self.presentationData = presentationData
        
        guard case .default = self.controllerStyle else {
            return
        }
        
        if let effectView = self.effectNode.view as? UIVisualEffectView {
            effectView.effect = UIBlurEffect(style: presentationData.theme.actionSheet.backgroundType == .light ? .light : .dark)
        }
        
        self.contentBackgroundNode.backgroundColor = self.presentationData.theme.actionSheet.itemBackgroundColor
        self.titleNode.attributedText = NSAttributedString(string: self.titleNode.attributedText?.string ?? "", font: Font.bold(17.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
        
        if previousTheme !== presentationData.theme, let (layout, navigationBarHeight) = self.containerLayout {
            self.setupPickerView()
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
        
        self.cancelButton.setTitle(self.presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
        self.doneButton.updateTheme(SolidRoundedButtonTheme(theme: self.presentationData.theme))
        self.onlineButton.updateTheme(SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor, foregroundColor: self.presentationData.theme.actionSheet.controlAccentColor))
    }
    
    private func updateMinimumDate(currentTime: Int32? = nil) {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let currentDate = Date()
        var components = calendar.dateComponents(Set([.era, .year, .month, .day, .hour, .minute, .second]), from: currentDate)
        components.second = 0
        let minute = (components.minute ?? 0) % 5
        
        let next1MinDate = calendar.date(byAdding: .minute, value: 1, to: calendar.date(from: components)!)
        let next5MinDate = calendar.date(byAdding: .minute, value: 5 - minute, to: calendar.date(from: components)!)
        
        if let date = calendar.date(byAdding: .day, value: 365, to: currentDate) {
            self.pickerView?.maximumDate = date
        }
        
        if let next1MinDate = next1MinDate, let next5MinDate = next5MinDate {
            let minimalTime = self.minimalTime.flatMap(Double.init) ?? 0.0
            self.pickerView?.minimumDate = max(next1MinDate, Date(timeIntervalSince1970: minimalTime))
            if let currentTime = currentTime, Double(currentTime) > max(currentDate.timeIntervalSince1970, minimalTime) {
                self.pickerView?.date = Date(timeIntervalSince1970: Double(currentTime))
            } else {
                self.pickerView?.date = next5MinDate
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
    }
    
    private let calendar = Calendar(identifier: .gregorian)
    private func updateButtonTitle() {
        guard let date = self.pickerView?.date else {
            return
        }
        
        let time = stringForMessageTimestamp(timestamp: Int32(date.timeIntervalSince1970), dateTimeFormat: self.presentationData.dateTimeFormat)
        switch mode {
            case .scheduledMessages:
                if calendar.isDateInToday(date) {
                    self.doneButton.title = self.presentationData.strings.Conversation_ScheduleMessage_SendToday(time).string
                } else if calendar.isDateInTomorrow(date) {
                    self.doneButton.title = self.presentationData.strings.Conversation_ScheduleMessage_SendTomorrow(time).string
                } else {
                    self.doneButton.title = self.presentationData.strings.Conversation_ScheduleMessage_SendOn(self.dateFormatter.string(from: date), time).string
                }
            case .reminders:
                if calendar.isDateInToday(date) {
                    self.doneButton.title = self.presentationData.strings.Conversation_SetReminder_RemindToday(time).string
                } else if calendar.isDateInTomorrow(date) {
                    self.doneButton.title = self.presentationData.strings.Conversation_SetReminder_RemindTomorrow(time).string
                } else {
                    self.doneButton.title = self.presentationData.strings.Conversation_SetReminder_RemindOn(self.dateFormatter.string(from: date), time).string
                }
        }
    }
    
    @objc private func datePickerUpdated() {
        self.updateButtonTitle()
        if let date = self.pickerView?.date, date < Date() {
            self.doneButton.alpha = 0.4
            self.doneButton.isUserInteractionEnabled = false
        } else {
            self.doneButton.alpha = 1.0
            self.doneButton.isUserInteractionEnabled = true
        }
    }
    
    @objc func cancelButtonPressed() {
        self.cancel?()
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if self.dismissByTapOutside, case .ended = recognizer.state {
            self.cancelButtonPressed()
        }
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        let targetBounds = self.bounds
        self.bounds = self.bounds.offsetBy(dx: 0.0, dy: -offset)
        self.dimNode.position = CGPoint(x: dimPosition.x, y: dimPosition.y - offset)
        transition.animateView({
            self.bounds = targetBounds
            self.dimNode.position = dimPosition
        })
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        var dimCompleted = false
        var offsetCompleted = false
        
        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted && offsetCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            offsetCompleted = true
            internalCompletion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) {
                return self.dimNode.view
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.cancelButtonPressed()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        var buttonOffset: CGFloat = 0.0
        if case .scheduledMessages(true) = self.mode {
            buttonOffset += 64.0
        }
        
        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        let titleHeight: CGFloat = 54.0
        var contentHeight = titleHeight + bottomInset + 52.0 + 17.0
        let pickerHeight: CGFloat = min(216.0, layout.size.height - contentHeight)
        contentHeight = titleHeight + bottomInset + 52.0 + 17.0 + pickerHeight + buttonOffset
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 0.0)
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentHeight), size: CGSize(width: width, height: contentHeight))
        let contentFrame = contentContainerFrame
        
        var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height + 2000.0))
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: width, height: titleHeight))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 16.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let cancelSize = self.cancelButton.measure(CGSize(width: width, height: titleHeight))
        let cancelFrame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: cancelSize)
        transition.updateFrame(node: self.cancelButton, frame: cancelFrame)
        
        let buttonInset: CGFloat = 16.0
        let doneButtonHeight = self.doneButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.doneButton, frame: CGRect(x: buttonInset, y: contentHeight - doneButtonHeight - insets.bottom - 16.0 - buttonOffset, width: contentFrame.width, height: doneButtonHeight))
        
        let onlineButtonHeight = self.onlineButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.onlineButton, frame: CGRect(x: buttonInset, y: contentHeight - onlineButtonHeight - insets.bottom - 16.0, width: contentFrame.width, height: onlineButtonHeight))
        
        self.pickerView?.frame = CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: contentFrame.width, height: pickerHeight))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
    }
}
