import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import SheetComponent
import ButtonComponent
import TelegramCore
import AnimatedTextComponent
import MultilineTextComponent
import BalancedTextComponent
import TelegramPresentationData
import TelegramStringFormatting
import Markdown

private final class ScheduleVideoChatSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let scheduleAction: (Int32) -> Void
    let dismiss: () -> Void
    
    init(
        scheduleAction: @escaping (Int32) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.scheduleAction = scheduleAction
        self.dismiss = dismiss
    }
    
    static func ==(lhs: ScheduleVideoChatSheetContentComponent, rhs: ScheduleVideoChatSheetContentComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let button = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let mainText = ComponentView<Empty>()
        private var pickerView: UIDatePicker?
        
        private let calendar = Calendar(identifier: .gregorian)
        private let dateFormatter: DateFormatter
        
        private var component: ScheduleVideoChatSheetContentComponent?
        private weak var state: EmptyComponentState?
        
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
        
        deinit {
        }
        
        @objc private func scheduleDatePickerUpdated() {
            self.state?.updated(transition: .immediate)
        }
        
        private func updateSchedulePickerLimits() {
            let timeZone = TimeZone(secondsFromGMT: 0)!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let currentDate = Date()
            var components = calendar.dateComponents(Set([.era, .year, .month, .day, .hour, .minute, .second]), from: currentDate)
            components.second = 0
            
            let roundedDate = calendar.date(from: components)!
            let next1MinDate = calendar.date(byAdding: .minute, value: 1, to: roundedDate)
            
            let minute = components.minute ?? 0
            components.minute = 0
            let roundedToHourDate = calendar.date(from: components)!
            components.hour = 0
        
            let roundedToMidnightDate = calendar.date(from: components)!
            let nextTwoHourDate = calendar.date(byAdding: .hour, value: minute > 30 ? 4 : 3, to: roundedToHourDate)
            let maxDate = calendar.date(byAdding: .day, value: 8, to: roundedToMidnightDate)
        
            if let date = calendar.date(byAdding: .day, value: 365, to: currentDate) {
                self.pickerView?.maximumDate = date
            }
            if let next1MinDate = next1MinDate, let nextTwoHourDate = nextTwoHourDate {
                self.pickerView?.minimumDate = next1MinDate
                self.pickerView?.maximumDate = maxDate
                self.pickerView?.date = nextTwoHourDate
            }
        }
        
        func update(component: ScheduleVideoChatSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            let _ = previousComponent
            
            self.component = component
            self.state = state
            
            let environment = environment[EnvironmentType.self].value
            
            let sideInset: CGFloat = 16.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 16.0
            
            //TODO:localize
            let titleString = NSMutableAttributedString()
            titleString.append(NSAttributedString(string: "Schedule Video Chat", font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(titleString),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize))
            }
            contentHeight += titleSize.height
            contentHeight += 16.0
            
            let pickerView: UIDatePicker
            if let current = self.pickerView {
                pickerView = current
            } else {
                let textColor = UIColor.white
                UILabel.setDateLabel(textColor)
                
                pickerView = UIDatePicker()
                pickerView.timeZone = TimeZone(secondsFromGMT: 0)
                pickerView.datePickerMode = .countDownTimer
                pickerView.datePickerMode = .dateAndTime
                pickerView.locale = Locale.current
                pickerView.timeZone = TimeZone.current
                pickerView.minuteInterval = 1
                self.addSubview(pickerView)
                pickerView.addTarget(self, action: #selector(self.scheduleDatePickerUpdated), for: .valueChanged)
                if #available(iOS 13.4, *) {
                    pickerView.preferredDatePickerStyle = .wheels
                }
                pickerView.setValue(textColor, forKey: "textColor")
                self.pickerView = pickerView
                self.addSubview(pickerView)
                
                self.updateSchedulePickerLimits()
            }
            
            let pickerFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: 216.0))
            transition.setFrame(view: pickerView, frame: pickerFrame)
            contentHeight += pickerFrame.height
            contentHeight += 26.0
            
            let date = pickerView.date
            let calendar = Calendar(identifier: .gregorian)
            let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            let timestamp = Int32(date.timeIntervalSince1970)
            let time = stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: PresentationDateTimeFormat())
            let buttonTitle: String
            if calendar.isDateInToday(date) {
                buttonTitle = environment.strings.ScheduleVoiceChat_ScheduleToday(time).string
            } else if calendar.isDateInTomorrow(date) {
                buttonTitle = environment.strings.ScheduleVoiceChat_ScheduleTomorrow(time).string
            } else {
                buttonTitle = environment.strings.ScheduleVoiceChat_ScheduleOn(self.dateFormatter.string(from: date), time).string
            }
            
            let delta = timestamp - currentTimestamp
            
            let isGroup = "".isEmpty
            let intervalString = scheduledTimeIntervalString(strings: environment.strings, value: max(60, delta))
            
            let text: String = isGroup ? environment.strings.ScheduleVoiceChat_GroupText(intervalString).string : environment.strings.ScheduleLiveStream_ChannelText(intervalString).string
            
            let mainText = NSMutableAttributedString()
            mainText.append(parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(
                    font: Font.regular(14.0),
                    textColor: UIColor(rgb: 0x8e8e93)
                ),
                bold: MarkdownAttributeSet(
                    font: Font.semibold(14.0),
                    textColor: UIColor(rgb: 0x8e8e93)
                ),
                link: MarkdownAttributeSet(
                    font: Font.regular(14.0),
                    textColor: environment.theme.list.itemAccentColor,
                    additionalAttributes: [:]
                ),
                linkAttribute: { attributes in
                    return ("URL", "")
                }
            )))
            
            let mainTextSize = self.mainText.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(mainText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let mainTextView = self.mainText.view {
                if mainTextView.superview == nil {
                    self.addSubview(mainTextView)
                }
                transition.setFrame(view: mainTextView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - mainTextSize.width) * 0.5), y: contentHeight), size: mainTextSize))
            }
            contentHeight += mainTextSize.height
            contentHeight += 10.0
            
            var buttonContents: [AnyComponentWithIdentity<Empty>] = []
            buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                Text(text: buttonTitle, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
            )))
            let buttonTransition = transition
            let buttonSize = self.button.update(
                transition: buttonTransition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: UIColor(rgb: 0x3252EF),
                        foreground: .white,
                        pressedColor: UIColor(rgb: 0x3252EF).withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        HStack(buttonContents, spacing: 5.0)
                    )),
                    isEnabled: true,
                    tintWhenDisabled: false,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component, let pickerView = self.pickerView else {
                            return
                        }
                        component.scheduleAction(Int32(pickerView.date.timeIntervalSince1970))
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            contentHeight += buttonSize.height
            contentHeight += 10.0
            
            let cancelButtonSize = self.cancelButton.update(
                transition: buttonTransition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: UIColor(rgb: 0x2B2B2F),
                        foreground: .white,
                        pressedColor: UIColor(rgb: 0x2B2B2F).withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        Text(text: "Cancel", font: Font.semibold(17.0), color: environment.theme.list.itemPrimaryTextColor)
                    )),
                    isEnabled: true,
                    tintWhenDisabled: false,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            let cancelButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: cancelButtonSize)
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }
            contentHeight += cancelButtonSize.height
            
            if environment.safeInsets.bottom.isZero {
                contentHeight += 16.0
            } else {
                contentHeight += environment.safeInsets.bottom + 14.0
            }
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ScheduleVideoChatSheetScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let scheduleAction: (Int32) -> Void
    
    init(
        context: AccountContext,
        scheduleAction: @escaping (Int32) -> Void
    ) {
        self.context = context
        self.scheduleAction = scheduleAction
    }
    
    static func ==(lhs: ScheduleVideoChatSheetScreenComponent, rhs: ScheduleVideoChatSheetScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var component: ScheduleVideoChatSheetScreenComponent?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ScheduleVideoChatSheetScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            let sheetEnvironment = SheetComponentEnvironment(
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
                    content: AnyComponent(ScheduleVideoChatSheetContentComponent(
                        scheduleAction: { [weak self] timestamp in
                            guard let self else {
                                return
                            }
                            self.sheetAnimateOut.invoke(Action { [weak self] _ in
                                guard let self, let component = self.component else {
                                    return
                                }
                                if let controller = self.environment?.controller() {
                                    controller.dismiss(completion: nil)
                                }
                                
                                component.scheduleAction(timestamp)
                            })
                        },
                        dismiss: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sheetAnimateOut.invoke(Action { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                if let controller = self.environment?.controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(UIColor(rgb: 0x1C1C1E)),
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

public class ScheduleVideoChatSheetScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, scheduleAction: @escaping (Int32) -> Void) {
        super.init(context: context, component: ScheduleVideoChatSheetScreenComponent(
            context: context,
            scheduleAction: scheduleAction
        ), navigationBarAppearance: .none, theme: .dark)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
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
