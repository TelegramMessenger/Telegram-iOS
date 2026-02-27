import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import ViewControllerComponent
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import SheetComponent
import ButtonComponent
import PlainButtonComponent
import BundleIconComponent
import GlassBackgroundComponent
import GlassBarButtonComponent
import DatePickerNode
import UndoUI

private let calendar = Calendar(identifier: .gregorian)

private final class ChatScheduleTimeSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    public class ExternalState {
        public fileprivate(set) var repeatValueFrame: CGRect
        
        public init() {
            self.repeatValueFrame = .zero
        }
    }
    
    let context: AccountContext
    let mode: ChatScheduleTimeScreen.Mode
    let currentTime: Int32?
    let currentRepeatPeriod: Int32?
    let minimalTime: Int32?
    let externalState: ExternalState
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        mode: ChatScheduleTimeScreen.Mode,
        currentTime: Int32?,
        currentRepeatPeriod: Int32?,
        minimalTime: Int32?,
        externalState: ExternalState,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.currentTime = currentTime
        self.currentRepeatPeriod = currentRepeatPeriod
        self.minimalTime = minimalTime
        self.externalState = externalState
        self.dismiss = dismiss
    }
    
    static func ==(lhs: ChatScheduleTimeSheetContentComponent, rhs: ChatScheduleTimeSheetContentComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let cancel = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        private let onlineButton = ComponentView<Empty>()
        
        private var datePicker: DatePickerNode?
        
        private let topSeparator = SimpleLayer()
        
        private let timeTitle = ComponentView<Empty>()
        private let timeValue = ComponentView<Empty>()
        
        private let bottomSeparator = SimpleLayer()
        
        private let repeatTitle = ComponentView<Empty>()
        private let repeatValue = ComponentView<Empty>()
        
        private var timePicker = ComponentView<Empty>()
        private var repeatPicker = ComponentView<Empty>()
        
        private var component: ChatScheduleTimeSheetContentComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var isUpdating = false
        
        private var monthHeight: CGFloat?
        
        private var date: Date?
        private var minDate: Date?
        private var maxDate: Date?
        
        private var isPickingTime = false
        private var isPickingRepeatPeriod = false
        
        private var repeatPeriod: Int32?
        
        private let dateFormatter: DateFormatter
        
        override init(frame: CGRect) {
            self.dateFormatter = DateFormatter()
            self.dateFormatter.timeStyle = .none
            self.dateFormatter.dateStyle = .short
            self.dateFormatter.timeZone = TimeZone.current
            
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func updateMinimumDate(currentTime: Int32? = nil, minimalTime: Int32? = nil) {
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
                self.maxDate = date
            }
            
            if let next1MinDate = next1MinDate, let next5MinDate = next5MinDate {
                let minimalTimeValue = minimalTime.flatMap(Double.init) ?? 0.0
                self.minDate = max(next1MinDate, Date(timeIntervalSince1970: minimalTimeValue))
                if let currentTime = currentTime, Double(currentTime) > max(currentDate.timeIntervalSince1970, minimalTimeValue) {
                    self.date = Date(timeIntervalSince1970: Double(currentTime))
                } else {
                    self.date = next5MinDate
                }
            }
        }
        
        func update(component: ChatScheduleTimeSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            
            let themeUpdated = self.environment?.theme != environment.theme
            
            self.environment = environment
            
            if self.component == nil {
                self.updateMinimumDate(currentTime: component.currentTime, minimalTime: component.minimalTime)
                self.repeatPeriod = component.currentRepeatPeriod
            }
                        
            self.component = component
            self.state = state
            
            let strings = environment.strings
            
            let sideInset: CGFloat = 39.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 30.0
                        
            let barButtonSize = CGSize(width: 44.0, height: 44.0)
            let cancelSize = self.cancel.update(
                transition: transition,
                component: AnyComponent(
                    GlassBarButtonComponent(
                        size: barButtonSize,
                        backgroundColor: nil,
                        isDark: environment.theme.overallDarkAppearance,
                        state: .glass,
                        component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                            BundleIconComponent(
                                name: "Navigation/Close",
                                tintColor: environment.theme.chat.inputPanel.panelControlColor
                            )
                        )),
                        action: { [weak self] _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.dismiss()
                        }
                    )
                ),
                environment: {},
                containerSize: barButtonSize
            )
            let cancelFrame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: cancelSize)
            if let cancelView = self.cancel.view {
                if cancelView.superview == nil {
                    self.addSubview(cancelView)
                }
                transition.setFrame(view: cancelView, frame: cancelFrame)
            }
            
            let title: String
            switch component.mode {
            case .scheduledMessages:
                title = strings.Conversation_ScheduleMessage_Title
            case .reminders:
                title = strings.Conversation_SetReminder_Title
            }
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: title, font: Font.semibold(17.0), color: environment.theme.actionSheet.primaryTextColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: 27.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            contentHeight += 62.0
            
            let datePicker: DatePickerNode
            if let current = self.datePicker {
                datePicker = current
                
                if themeUpdated {
                    datePicker.updateTheme(DatePickerTheme(theme: environment.theme))
                }
            } else {
                datePicker = DatePickerNode(
                    theme: DatePickerTheme(theme: environment.theme),
                    strings: strings,
                    dateTimeFormat: environment.dateTimeFormat,
                    hasValueRow: false
                )
                datePicker.date = self.date
                datePicker.valueUpdated = { [weak self] date in
                    if let self {
                        self.date = date
                        self.state?.updated()
                    }
                }
                self.addSubview(datePicker.view)
                self.datePicker = datePicker
            }
            datePicker.heightUpdated = { [weak self] height in
                guard let self else {
                    return
                }
                var transition = ComponentTransition.spring(duration: 0.3)
                if self.monthHeight == nil {
                    transition = .immediate
                }
                if height != self.monthHeight {
                    self.monthHeight = height
                    if !self.isUpdating {
                        self.state?.updated(transition: transition)
                    }
                }
            }
            datePicker.displayDateSelection = true
            
            if let minDate = self.minDate {
                datePicker.minimumDate = minDate
            } else {
                datePicker.minimumDate = Date()
            }
            if let maxDate = self.maxDate {
                datePicker.maximumDate = maxDate
            }
            
            let constrainedWidth = min(390.0, availableSize.width)
            let cellSize = floor((constrainedWidth - 12.0 * 2.0) / 7.0)
            let pickerHeight = 59.0 + cellSize * 6.0
            
            let datePickerSize = CGSize(width: availableSize.width - 22.0, height: pickerHeight)
            datePicker.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - datePickerSize.width) / 2.0), y: contentHeight), size: datePickerSize)
            datePicker.updateLayout(size: datePickerSize, transition: .immediate)
            
            if let monthHeight = self.monthHeight {
                contentHeight += monthHeight + 79.0
            } else {
                contentHeight += pickerHeight
            }
            
            transition.setFrame(layer: self.topSeparator, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: UIScreenPixel)))
            self.topSeparator.backgroundColor = environment.theme.list.itemBlocksSeparatorColor.cgColor
            if self.topSeparator.superlayer == nil {
                self.layer.addSublayer(self.topSeparator)
            }
            
            let timeTitleSize = self.timeTitle.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: strings.ScheduleMessage_Time, font: Font.regular(17.0), color: environment.theme.actionSheet.primaryTextColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            let timeTitleFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + 16.0), size: timeTitleSize)
            if let timeTitleView = self.timeTitle.view {
                if timeTitleView.superview == nil {
                    self.addSubview(timeTitleView)
                }
                transition.setFrame(view: timeTitleView, frame: timeTitleFrame)
            }
            
            let date = self.date ?? Date()
            
            var t: time_t = Int(date.timeIntervalSince1970)
            var timeinfo = tm()
            localtime_r(&t, &timeinfo);
            
            let timeString = stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min), dateTimeFormat: environment.dateTimeFormat)
            let timeValueSize = self.timeValue.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            ButtonContentComponent(
                                theme: environment.theme,
                                text: timeString,
                                isActive: self.isPickingTime,
                                isLocked: false
                            )
                        ),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            if self.isPickingRepeatPeriod {
                                self.isPickingRepeatPeriod = false
                            } else {
                                self.isPickingTime = !self.isPickingTime
                            }
                            self.state?.updated()
                        },
                        animateScale: false
                    )
                ),
                environment: {
                },
                containerSize: availableSize
            )
            let timeValueFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - timeValueSize.width, y: contentHeight + 10.0), size: timeValueSize)
            if let timeValueView = self.timeValue.view {
                if timeValueView.superview == nil {
                    self.addSubview(timeValueView)
                }
                transition.setFrame(view: timeValueView, frame: timeValueFrame)
            }
            
            contentHeight += 56.0
            
            transition.setFrame(layer: self.bottomSeparator, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: UIScreenPixel)))
            self.bottomSeparator.backgroundColor = environment.theme.list.itemBlocksSeparatorColor.cgColor
            if self.bottomSeparator.superlayer == nil {
                self.layer.addSublayer(self.bottomSeparator)
            }
            
            let repeatTitleSize = self.repeatTitle.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: strings.ScheduleMessage_Repeat, font: Font.regular(17.0), color: environment.theme.actionSheet.primaryTextColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            let repeatTitleFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + 16.0), size: repeatTitleSize)
            if let timeTitleView = self.repeatTitle.view {
                if timeTitleView.superview == nil {
                    self.addSubview(timeTitleView)
                }
                transition.setFrame(view: timeTitleView, frame: repeatTitleFrame)
            }
            
            let repeatString: String
            if let repeatPeriod = self.repeatPeriod {
                switch repeatPeriod {
                case 86400:
                    repeatString = strings.ScheduleMessage_RepeatPeriod_Daily
                case 7 * 86400:
                    repeatString = strings.ScheduleMessage_RepeatPeriod_Weekly
                case 14 * 86400:
                    repeatString = strings.ScheduleMessage_RepeatPeriod_Biweekly
                case 30 * 86400:
                    repeatString = strings.ScheduleMessage_RepeatPeriod_Monthly
                case 91 * 86400:
                    repeatString = strings.ScheduleMessage_RepeatPeriod_3Months
                case 182 * 86400:
                    repeatString = strings.ScheduleMessage_RepeatPeriod_6Months
                case 365 * 86400:
                    repeatString = strings.ScheduleMessage_RepeatPeriod_Yearly
                default:
                    repeatString = "\(repeatPeriod)s"
                }
            } else {
                repeatString = strings.ScheduleMessage_RepeatPeriod_Never
            }
            
            let repeatValueSize = self.repeatValue.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            ButtonContentComponent(
                                theme: environment.theme,
                                text: repeatString,
                                isActive: self.isPickingRepeatPeriod,
                                isLocked: !component.context.isPremium
                            )
                        ),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            if self.isPickingTime {
                                self.isPickingTime = false
                            } else {
                                self.isPickingRepeatPeriod = !self.isPickingRepeatPeriod
                            }
                            self.state?.updated()
                        }
                    )
                ),
                environment: {
                },
                containerSize: availableSize
            )
            let repeatValueFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - repeatValueSize.width, y: contentHeight + 10.0), size: repeatValueSize)
            if let repeatValueView = self.repeatValue.view {
                if repeatValueView.superview == nil {
                    self.addSubview(repeatValueView)
                }
                transition.setFrame(view: repeatValueView, frame: repeatValueFrame)
            }
            contentHeight += 70.0
            
            let time = stringForMessageTimestamp(timestamp: Int32(date.timeIntervalSince1970), dateTimeFormat: environment.dateTimeFormat)
            let buttonTitle: String
            switch component.mode {
            case .scheduledMessages:
                if calendar.isDateInToday(date) {
                    buttonTitle = strings.Conversation_ScheduleMessage_SendToday(time).string
                } else if calendar.isDateInTomorrow(date) {
                    buttonTitle = strings.Conversation_ScheduleMessage_SendTomorrow(time).string
                } else {
                    buttonTitle = strings.Conversation_ScheduleMessage_SendOn(self.dateFormatter.string(from: date), time).string
                }
            case .reminders:
                if calendar.isDateInToday(date) {
                    buttonTitle = strings.Conversation_SetReminder_RemindToday(time).string
                } else if calendar.isDateInTomorrow(date) {
                    buttonTitle = strings.Conversation_SetReminder_RemindTomorrow(time).string
                } else {
                    buttonTitle = strings.Conversation_SetReminder_RemindOn(self.dateFormatter.string(from: date), time).string
                }
            }
                
            let buttonSideInset: CGFloat = 30.0
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8),
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        Text(text: buttonTitle, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
                    )),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component, let controller = self.environment?.controller() as? ChatScheduleTimeScreen else {
                            return
                        }
                        controller.completion(
                            ChatScheduleTimeScreen.Result(
                                time: Int32(self.date?.timeIntervalSince1970 ?? 0),
                                repeatPeriod: self.repeatPeriod
                            )
                        )
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - buttonSideInset * 2.0, height: 52.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: buttonSideInset, y: contentHeight), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            contentHeight += buttonSize.height
            
            if case .scheduledMessages(true) = component.mode {
                contentHeight += 8.0
                
                let buttonSize = self.onlineButton.update(
                    transition: transition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.1),
                            foreground: environment.theme.list.itemCheckColors.fillColor,
                            pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8),
                        ),
                        content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                            Text(text: strings.Conversation_ScheduleMessage_SendWhenOnline, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.fillColor)
                        )),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak self] in
                            guard let self, let component = self.component, let controller = self.environment?.controller() as? ChatScheduleTimeScreen else {
                                return
                            }
                            controller.completion(
                                ChatScheduleTimeScreen.Result(
                                    time: scheduleWhenOnlineTimestamp,
                                    repeatPeriod: nil
                                )
                            )
                            component.dismiss()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - buttonSideInset * 2.0, height: 52.0)
                )
                let buttonFrame = CGRect(origin: CGPoint(x: buttonSideInset, y: contentHeight), size: buttonSize)
                if let buttonView = self.onlineButton.view {
                    if buttonView.superview == nil {
                        self.addSubview(buttonView)
                    }
                    transition.setFrame(view: buttonView, frame: buttonFrame)
                }
                contentHeight += buttonSize.height
            }
            
            let bottomPanelPadding: CGFloat = 15.0
            let bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            contentHeight += bottomInset
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            
            if self.isPickingTime {
                let _ = self.timePicker.update(
                    transition: transition,
                    component: AnyComponent(
                        MenuComponent(
                            theme: environment.theme,
                            sourceFrame: timeValueFrame,
                            component: AnyComponent(TimeMenuComponent(
                                value: self.date ?? Date(),
                                valueUpdated: { [weak self] value in
                                    guard let self else {
                                        return
                                    }
                                    self.date = value
                                    self.state?.updated()
                                }
                            )),
                            dismiss: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.isPickingTime = false
                                self.state?.updated()
                            }
                        )
                    ),
                    environment: {
                    },
                    containerSize: contentSize
                )
                let timePickerFrame = CGRect(origin: .zero, size: contentSize)
                if let timePickerView = self.timePicker.view as? MenuComponent.View {
                    if timePickerView.superview == nil {
                        self.addSubview(timePickerView)
                        
                        timePickerView.animateIn()
                    }
                    transition.setFrame(view: timePickerView, frame: timePickerFrame)
                }
            } else if let timePicker = self.timePicker.view as? MenuComponent.View, timePicker.superview != nil {
                self.timePicker = ComponentView()
                timePicker.animateOut(completion: {
                    timePicker.removeFromSuperview()
                })
            }
            
            if self.isPickingRepeatPeriod {
                let _ = self.repeatPicker.update(
                    transition: transition,
                    component: AnyComponent(
                        MenuComponent(
                            theme: environment.theme,
                            sourceFrame: repeatValueFrame,
                            component: AnyComponent(RepeatMenuComponent(
                                theme: environment.theme,
                                strings: strings,
                                value: self.repeatPeriod,
                                valueUpdated: { [weak self] value in
                                    guard let self, let component = self.component, let environment = self.environment else {
                                        return
                                    }
                                    self.isPickingRepeatPeriod = false
                                    if component.context.isPremium {
                                        self.repeatPeriod = value
                                    } else {
                                        let toastController = UndoOverlayController(
                                            presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                                            content: .premiumPaywall(
                                                title: strings.ScheduleMessage_PremiumRequired_Title,
                                                text: strings.ScheduleMessage_PremiumRequired_Text,
                                                customUndoText: strings.ScheduleMessage_PremiumRequired_Add,
                                                timeout: nil,
                                                linkAction: nil
                                            ),
                                            elevatedLayout: false,
                                            action: { [weak environment] action in
                                                if case .undo = action {
                                                    let controller = component.context.sharedContext.makePremiumIntroController(context: component.context, source: .nameColor, forceDark: false, dismissed: nil)
                                                    environment?.controller()?.push(controller)
                                                }
                                                return true
                                            }
                                        )
                                        environment.controller()?.present(toastController, in: .current)
                                    }
                                    self.state?.updated()
                                }
                            )),
                            dismiss: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.isPickingRepeatPeriod = false
                                self.state?.updated()
                            }
                        )
                    ),
                    environment: {
                    },
                    containerSize: contentSize
                )
                let repeatPickerFrame = CGRect(origin: .zero, size: contentSize)
                if let repeatPickerView = self.repeatPicker.view as? MenuComponent.View {
                    if repeatPickerView.superview == nil {
                        self.addSubview(repeatPickerView)
                        
                        repeatPickerView.animateIn()
                    }
                    transition.setFrame(view: repeatPickerView, frame: repeatPickerFrame)
                }
            } else if let repeatPicker = self.repeatPicker.view as? MenuComponent.View, repeatPicker.superview != nil {
                self.repeatPicker = ComponentView()
                repeatPicker.animateOut(completion: {
                    repeatPicker.removeFromSuperview()
                })
            }
            
            component.externalState.repeatValueFrame = repeatValueFrame
            
            return contentSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ChatScheduleTimeScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mode: ChatScheduleTimeScreen.Mode
    let currentTime: Int32?
    let currentRepeatPeriod: Int32?
    let minimalTime: Int32?
    
    init(
        context: AccountContext,
        mode: ChatScheduleTimeScreen.Mode,
        currentTime: Int32?,
        currentRepeatPeriod: Int32?,
        minimalTime: Int32?
    ) {
        self.context = context
        self.mode = mode
        self.currentTime = currentTime
        self.currentRepeatPeriod = currentRepeatPeriod
        self.minimalTime = minimalTime
    }
    
    static func ==(lhs: ChatScheduleTimeScreenComponent, rhs: ChatScheduleTimeScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.currentTime != rhs.currentTime {
            return false
        }
        if lhs.currentRepeatPeriod != rhs.currentRepeatPeriod {
            return false
        }
        if lhs.minimalTime != rhs.minimalTime {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        private let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        private let contentExternalState = ChatScheduleTimeSheetContentComponent.ExternalState()
        
        private var component: ChatScheduleTimeScreenComponent?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ChatScheduleTimeScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            let sheetEnvironment = SheetComponentEnvironment(
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                isDisplaying: environment.isVisible,
                isCentered: environment.metrics.widthClass == .regular,
                hasInputHeight: !environment.inputHeight.isZero,
                regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                dismiss: { [weak self] _ in
                    guard let self, let environment = self.environment else {
                        return
                    }
                    self.sheetAnimateOut.invoke(Action { _ in
                        if let controller = environment.controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                }
            )
            let _ = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent(
                    content: AnyComponent(ChatScheduleTimeSheetContentComponent(
                        context: component.context,
                        mode: component.mode,
                        currentTime: component.currentTime,
                        currentRepeatPeriod: component.currentRepeatPeriod,
                        minimalTime: component.minimalTime,
                        externalState: self.contentExternalState,
                        dismiss: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sheetAnimateOut.invoke(Action { _ in
                                if let controller = environment.controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    externalState: self.sheetExternalState,
                    animateOut: self.sheetAnimateOut
                )),
                environment: {
                    environment
                    sheetEnvironment
                },
                containerSize: availableSize
            )
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            
            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout {
                let sideInset: CGFloat = 20.0
                let bottomInset: CGFloat = self.sheetExternalState.contentHeight - self.contentExternalState.repeatValueFrame.minY + 14.0

                let layout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class ChatScheduleTimeScreen: ViewControllerComponentContainer {
    public enum Mode: Equatable {
        case scheduledMessages(sendWhenOnlineAvailable: Bool)
        case reminders
    }
    
    public struct Result {
        public let time: Int32
        public let repeatPeriod: Int32?
    }
    
    fileprivate let completion: (Result) -> Void
    
    public init(
        context: AccountContext,
        mode: Mode,
        currentTime: Int32?,
        currentRepeatPeriod: Int32?,
        minimalTime: Int32?,
        isDark: Bool,
        completion: @escaping (Result) -> Void
    ) {
        self.completion = completion
        
        super.init(context: context, component: ChatScheduleTimeScreenComponent(
            context: context,
            mode: mode,
            currentTime: currentTime,
            currentRepeatPeriod: currentRepeatPeriod,
            minimalTime: minimalTime
        ), navigationBarAppearance: .none, theme: isDark ? .dark : .default)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
    }
}

private final class ButtonContentComponent: Component {
    let theme: PresentationTheme
    let text: String
    let isActive: Bool
    let isLocked: Bool
    
    init(
        theme: PresentationTheme,
        text: String,
        isActive: Bool,
        isLocked: Bool
    ) {
        self.theme = theme
        self.text = text
        self.isActive = isActive
        self.isLocked = isLocked
    }

    static func ==(lhs: ButtonContentComponent, rhs: ButtonContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.isActive != rhs.isActive {
            return false
        }
        if lhs.isLocked != rhs.isLocked {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: ButtonContentComponent?
        private weak var componentState: EmptyComponentState?
        
        private let backgroundLayer = SimpleLayer()
        private let title = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
                
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundLayer)
            self.backgroundLayer.masksToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: ButtonContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
                        
            let backgroundColor: UIColor = component.isActive ? component.theme.actionSheet.controlAccentColor.withMultipliedAlpha(0.1) : component.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.07)
            let textColor: UIColor = component.isActive ? component.theme.actionSheet.controlAccentColor : component.theme.actionSheet.primaryTextColor
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: component.text, font: Font.regular(17.0), color: textColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            
            var totalWidth = titleSize.width
            
            var iconSize = CGSize()
            if component.isLocked {
                iconSize = self.icon.update(
                    transition: .immediate,
                    component: AnyComponent(
                        BundleIconComponent(
                            name: "Media Grid/Lock",
                            tintColor: textColor
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                totalWidth += iconSize.width + 2.0
            }
            
            let padding: CGFloat = 12.0
            let size = CGSize(width: totalWidth + padding * 2.0, height: 36.0)
                                    
            let titleFrame = CGRect(origin: CGPoint(x: padding, y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let iconFrame = CGRect(origin: CGPoint(x: size.width - padding - iconSize.width, y: floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: iconFrame)
            }
            
            self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: .zero, size: size))
            self.backgroundLayer.cornerRadius = size.height / 2.0
                        
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}



private final class MenuComponent: Component {
    let theme: PresentationTheme
    let sourceFrame: CGRect
    let component: AnyComponent<Empty>
    let dismiss: () -> Void

    init(
        theme: PresentationTheme,
        sourceFrame: CGRect,
        component: AnyComponent<Empty>,
        dismiss: @escaping () -> Void
    ) {
        self.theme = theme
        self.sourceFrame = sourceFrame
        self.component = component
        self.dismiss = dismiss
    }

    public static func ==(lhs: MenuComponent, rhs: MenuComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.sourceFrame != rhs.sourceFrame {
            return false
        }
        if lhs.component != rhs.component {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let buttonView: UIButton
        private let containerView: GlassBackgroundContainerView
        private let backgroundView: GlassBackgroundView
        private var componentView: ComponentView<Empty>?
        
        private var component: MenuComponent?
        
        public override init(frame: CGRect) {
            self.buttonView = UIButton()
            self.containerView = GlassBackgroundContainerView()
            self.backgroundView = GlassBackgroundView()
            
            super.init(frame: frame)
            
            self.addSubview(self.buttonView)
            self.addSubview(self.containerView)
            self.containerView.contentView.addSubview(self.backgroundView)
            
            self.buttonView.addTarget(self, action: #selector(self.tapped), for: .touchUpInside)
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc func tapped() {
            if let component = self.component {
                component.dismiss()
            }
        }
        
        func animateIn() {
            guard let component = self.component else {
                return
            }
            let transition = ComponentTransition.spring(duration: 0.3)
            transition.animatePosition(view: self.backgroundView, from: component.sourceFrame.center, to: self.backgroundView.center)
            transition.animateScale(view: self.backgroundView, from: 0.2, to: 1.0)
            self.containerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        }
        
        public func animateOut(completion: (() -> Void)? = nil) {
            guard let component = self.component else {
                return
            }
            
            let transition = ComponentTransition.spring(duration: 0.3)
            transition.setPosition(view: self.backgroundView, position: component.sourceFrame.center)
            transition.setScale(view: self.backgroundView, scale: 0.2)
            self.containerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
                completion?()
            })
        }
                
        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.backgroundView.frame.contains(point) && self.buttonView.frame.contains(point) {
                return self.buttonView
            }
            return super.hitTest(point, with: event)
        }
        
        func update(component: MenuComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            var componentView: ComponentView<Empty>
            var componentTransition = transition
            if let current = self.componentView {
                componentView = current
            } else {
                componentTransition = .immediate
                componentView = ComponentView()
                self.componentView = componentView
            }
            
            let componentSize = componentView.update(
                transition: componentTransition,
                component: component.component,
                environment: {},
                containerSize: availableSize
            )
            let backgroundFrame = CGRect(origin: CGPoint(x: component.sourceFrame.maxX - componentSize.width, y: component.sourceFrame.minY - componentSize.height - 20.0), size: componentSize)
            if let view = componentView.view {
                if view.superview == nil {
                    self.backgroundView.contentView.addSubview(view)
                }
                componentTransition.setFrame(view: view, frame: CGRect(origin: .zero, size: componentSize))
            }
            
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: 30.0, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: transition)
            self.backgroundView.frame = backgroundFrame
            
            self.containerView.frame = CGRect(origin: .zero, size: availableSize)
            self.containerView.update(size: availableSize, isDark: component.theme.overallDarkAppearance, transition: transition)
            
            self.buttonView.frame = CGRect(origin: .zero, size: availableSize)
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class MenuButtonComponent: Component {
    let theme: PresentationTheme
    let text: String
    let isSelected: Bool
    let width: CGFloat?
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        text: String,
        isSelected: Bool,
        width: CGFloat?,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.text = text
        self.isSelected = isSelected
        self.width = width
        self.action = action
    }

    static func ==(lhs: MenuButtonComponent, rhs: MenuButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.width != rhs.width {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: MenuButtonComponent?
        private weak var componentState: EmptyComponentState?
        
        private let selectionLayer = SimpleLayer()
        private let title = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        private let button = HighlightTrackingButton()
                
        override init(frame: CGRect) {
            super.init(frame: frame)
                        
            self.layer.addSublayer(self.selectionLayer)
            self.selectionLayer.masksToBounds = true
            self.selectionLayer.opacity = 0.0
            
            self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
            
            self.button.highligthedChanged = { [weak self] highlighted in
                if let self {
                    if highlighted {
                        self.selectionLayer.opacity = 1.0
                        self.selectionLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    } else {
                        self.selectionLayer.opacity = 0.0
                        self.selectionLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func buttonPressed() {
            if let component = self.component {
                component.action()
            }
        }
                
        func update(component: MenuButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
            
            let leftInset: CGFloat = 60.0
            let rightInset: CGFloat = 40.0
                        
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: component.text, font: Font.regular(17.0), color: component.theme.contextMenu.primaryColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            let titleFrame = CGRect(origin: CGPoint(x: 60.0, y: floorToScreenPixels((availableSize.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            let size = CGSize(width: component.width ?? (leftInset + rightInset + titleSize.width), height: availableSize.height)
            
            if component.isSelected {
                let iconSize = self.icon.update(
                    transition: .immediate,
                    component: AnyComponent(
                        BundleIconComponent(
                            name: "Media Gallery/Check",
                            tintColor: component.theme.contextMenu.primaryColor
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                let iconFrame = CGRect(origin: CGPoint(x: 25.0, y: floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
                if let iconView = self.icon.view {
                    if iconView.superview == nil {
                        self.addSubview(iconView)
                    }
                    iconView.frame = iconFrame
                }
            }
            
            self.selectionLayer.backgroundColor = component.theme.contextMenu.itemHighlightedBackgroundColor.withMultipliedAlpha(0.5).cgColor
            transition.setFrame(layer: self.selectionLayer, frame: CGRect(origin: .zero, size: size).insetBy(dx: 10.0, dy: 0.0))
            self.selectionLayer.cornerRadius = size.height / 2.0
                       
            if self.button.superview == nil {
                self.addSubview(self.button)
            }
            self.button.frame = CGRect(origin: .zero, size: size)
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class RepeatMenuComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let value: Int32?
    let valueUpdated: (Int32?) -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        value: Int32?,
        valueUpdated: @escaping (Int32?) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.valueUpdated = valueUpdated
    }

    public static func ==(lhs: RepeatMenuComponent, rhs: RepeatMenuComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let backgroundView: GlassBackgroundView
        private let never = ComponentView<Empty>()
        private let separator = SimpleLayer()
        private var itemViews: [Int32: ComponentView<Empty>] = [:]
        
        private var component: RepeatMenuComponent?
        
        private let values: [Int32] = [
            86400,
            7 * 86400,
            14 * 86400,
            30 * 86400,
            91 * 86400,
            182 * 86400,
            365 * 86400
        ]
        
        private var width: CGFloat?
        
        public override init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.separator)
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: RepeatMenuComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let sideInset: CGFloat = 18.0
            let itemHeight: CGFloat = 40.0
            
            let neverSize = self.never.update(
                transition: transition,
                component: AnyComponent(
                    MenuButtonComponent(
                        theme: component.theme,
                        text: component.strings.ScheduleMessage_RepeatPeriod_Never,
                        isSelected: component.value == nil,
                        width: self.width,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.component?.valueUpdated(nil)
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: itemHeight)
            )
            let neverFrame = CGRect(origin: CGPoint(x: 0.0, y: 12.0), size: neverSize)
            if let neverView = self.never.view {
                if neverView.superview == nil {
                    self.addSubview(neverView)
                }
                transition.setFrame(view: neverView, frame: neverFrame)
            }
            
            var maxWidth: CGFloat = 0.0
            var originY: CGFloat = 72.0
            for value in self.values {
                let itemView: ComponentView<Empty>
                if let current = self.itemViews[value] {
                    itemView = current
                } else {
                    itemView = ComponentView()
                    self.itemViews[value] = itemView
                }
                
                let repeatString: String
                switch value {
                case 86400:
                    repeatString = component.strings.ScheduleMessage_RepeatPeriod_Daily
                case 7 * 86400:
                    repeatString = component.strings.ScheduleMessage_RepeatPeriod_Weekly
                case 14 * 86400:
                    repeatString = component.strings.ScheduleMessage_RepeatPeriod_Biweekly
                case 30 * 86400:
                    repeatString = component.strings.ScheduleMessage_RepeatPeriod_Monthly
                case 91 * 86400:
                    repeatString = component.strings.ScheduleMessage_RepeatPeriod_3Months
                case 182 * 86400:
                    repeatString = component.strings.ScheduleMessage_RepeatPeriod_6Months
                case 365 * 86400:
                    repeatString = component.strings.ScheduleMessage_RepeatPeriod_Yearly
                default:
                    repeatString = "\(value)s"
                }
                
                let itemSize = itemView.update(
                    transition: transition,
                    component: AnyComponent(
                        MenuButtonComponent(
                            theme: component.theme,
                            text: repeatString,
                            isSelected: component.value == value,
                            width: self.width,
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.component?.valueUpdated(value)
                            }
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: itemHeight)
                )
                maxWidth = max(maxWidth, itemSize.width)
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: originY), size: itemSize)
                if let itemView = itemView.view {
                    if itemView.superview == nil {
                        self.addSubview(itemView)
                    }
                    transition.setFrame(view: itemView, frame: itemFrame)
                }
                originY += 40.0
            }
            
            let size = CGSize(width: maxWidth, height: originY + 8.0)
            
            self.separator.backgroundColor = component.theme.contextMenu.primaryColor.withMultipliedAlpha(0.5).cgColor
            self.separator.frame = CGRect(origin: CGPoint(x: sideInset, y: 62.0), size: CGSize(width: size.width - sideInset * 2.0, height: UIScreenPixel))
            
            if self.width == nil {
                self.width = maxWidth
                Queue.mainQueue().justDispatch {
                    state.updated()
                }
            }
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class TimeMenuComponent: Component {
    let value: Date
    let valueUpdated: (Date) -> Void

    init(
        value: Date,
        valueUpdated: @escaping (Date) -> Void
    ) {
        self.value = value
        self.valueUpdated = valueUpdated
    }

    public static func == (lhs: TimeMenuComponent, rhs: TimeMenuComponent) -> Bool {
        return lhs.value == rhs.value
    }

    public final class View: UIView {
        private let picker = UIDatePicker()
        private var component: TimeMenuComponent?

        public override init(frame: CGRect) {
            super.init(frame: frame)

            self.picker.datePickerMode = .time
            if #available(iOS 13.4, *) {
                self.picker.preferredDatePickerStyle = .wheels
            }
            self.picker.addTarget(self, action: #selector(valueChanged), for: .valueChanged)

            self.addSubview(self.picker)
        }

        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func valueChanged() {
            guard let component = self.component else {
                return
            }
            component.valueUpdated(self.picker.date)
        }

        func update(component: TimeMenuComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previous = self.component
            self.component = component

            if previous == nil || abs(component.value.timeIntervalSince(self.picker.date)) > 0.5 {
                self.picker.setDate(component.value, animated: false)
            }

            let pickerSize = self.picker.sizeThatFits(availableSize)
            let width = min(availableSize.width, max(pickerSize.width, 230.0))
            let height = pickerSize.height > 0 ? pickerSize.height : 216.0

            let frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
            transition.setFrame(view: self.picker, frame: frame)

            return frame.size
        }
    }

    public func makeView() -> View {
        return View(frame: .zero)
    }

    public func update( view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
