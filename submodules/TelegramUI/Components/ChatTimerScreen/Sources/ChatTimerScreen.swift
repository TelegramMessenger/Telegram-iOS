import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import ButtonComponent
import BundleIconComponent
import GlassBarButtonComponent

public enum ChatTimerScreenStyle {
    case `default`
    case media
}

public enum ChatTimerScreenMode {
    case sendTimer
    case autoremove
    case mute
}

private protocol TimerPickerView: UIView {
}

private final class TimerCustomPickerView: UIPickerView, TimerPickerView {
    var selectorColor: UIColor? = nil {
        didSet {
            for subview in self.subviews {
                if subview.bounds.height <= 1.0 {
                    subview.backgroundColor = self.selectorColor
                }
            }
        }
    }

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)

        if let selectorColor = self.selectorColor, subview.bounds.height <= 1.0 {
            subview.backgroundColor = selectorColor
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if let selectorColor = self.selectorColor {
            for subview in self.subviews where subview.bounds.height <= 1.0 {
                subview.backgroundColor = selectorColor
            }
        }
    }
}

private final class TimerDatePickerView: UIDatePicker, TimerPickerView {
    var selectorColor: UIColor? = nil {
        didSet {
            for subview in self.subviews {
                if subview.bounds.height <= 1.0 {
                    subview.backgroundColor = self.selectorColor
                }
            }
        }
    }

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)

        if let selectorColor = self.selectorColor, subview.bounds.height <= 1.0 {
            subview.backgroundColor = selectorColor
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if let selectorColor = self.selectorColor {
            for subview in self.subviews where subview.bounds.height <= 1.0 {
                subview.backgroundColor = selectorColor
            }
        }
    }
}

private let digitsCharacterSet = CharacterSet(charactersIn: "0123456789")
private let nondigitsCharacterSet = CharacterSet(charactersIn: "0123456789").inverted

private final class TimerPickerItemView: UIView {
    let valueLabel = UILabel()
    let unitLabel = UILabel()

    var textColor: UIColor? = nil {
        didSet {
            self.valueLabel.textColor = self.textColor
            self.unitLabel.textColor = self.textColor
        }
    }

    var value: (Int32, String)? {
        didSet {
            if let (value, string) = self.value {
                let components = string.components(separatedBy: " ")
                if value == viewOnceTimeout || string.rangeOfCharacter(from: digitsCharacterSet) == nil {
                    self.valueLabel.text = string
                    self.unitLabel.text = ""
                } else if components.count > 1 {
                    self.valueLabel.text = components[0]
                    self.unitLabel.text = components[1]
                } else {
                    self.valueLabel.text = string.trimmingCharacters(in: nondigitsCharacterSet)
                    self.unitLabel.text = string.trimmingCharacters(in: digitsCharacterSet)
                }
            }

            self.setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        self.valueLabel.backgroundColor = nil
        self.valueLabel.isOpaque = false
        self.valueLabel.font = Font.regular(24.0)

        self.unitLabel.backgroundColor = nil
        self.unitLabel.isOpaque = false
        self.unitLabel.font = Font.medium(16.0)

        super.init(frame: frame)

        self.addSubview(self.valueLabel)
        self.addSubview(self.unitLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.valueLabel.sizeToFit()
        self.unitLabel.sizeToFit()

        if self.unitLabel.text?.isEmpty ?? false {
            self.valueLabel.frame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((self.frame.width - self.valueLabel.frame.size.width) / 2.0),
                    y: floor((self.frame.height - self.valueLabel.frame.height) / 2.0)
                ),
                size: self.valueLabel.frame.size
            )
        } else {
            self.valueLabel.frame = CGRect(
                origin: CGPoint(
                    x: self.frame.width / 2.0 - 28.0 - self.valueLabel.frame.size.width,
                    y: floor((self.frame.height - self.valueLabel.frame.height) / 2.0)
                ),
                size: self.valueLabel.frame.size
            )
            self.unitLabel.frame = CGRect(
                origin: CGPoint(
                    x: self.frame.width / 2.0 - 20.0,
                    y: floor((self.frame.height - self.unitLabel.frame.height) / 2.0) + 2.0
                ),
                size: self.unitLabel.frame.size
            )
        }
    }
}

private let timerValues: [Int32] = {
    var values: [Int32] = []
    for i in 1 ..< 20 {
        values.append(Int32(i))
    }
    for i in 0 ..< 9 {
        values.append(Int32(20 + i * 5))
    }
    return values
}()

private let autoremoveTimerValues: [Int32] = [
    1 * 24 * 60 * 60 as Int32,
    2 * 24 * 60 * 60 as Int32,
    3 * 24 * 60 * 60 as Int32,
    4 * 24 * 60 * 60 as Int32,
    5 * 24 * 60 * 60 as Int32,
    6 * 24 * 60 * 60 as Int32,
    1 * 7 * 24 * 60 * 60 as Int32,
    2 * 7 * 24 * 60 * 60 as Int32,
    3 * 7 * 24 * 60 * 60 as Int32,
    1 * 31 * 24 * 60 * 60 as Int32,
    2 * 30 * 24 * 60 * 60 as Int32,
    3 * 31 * 24 * 60 * 60 as Int32,
    4 * 30 * 24 * 60 * 60 as Int32,
    5 * 31 * 24 * 60 * 60 as Int32,
    6 * 30 * 24 * 60 * 60 as Int32,
    365 * 24 * 60 * 60 as Int32
]

public final class ChatTimerPickerContentComponent: Component {
    public typealias EnvironmentType = Empty

    public final class LeadingAction: Equatable {
        public enum Icon {
            case close
            case back
        }

        public let icon: Icon
        public let action: () -> Void

        public init(
            icon: Icon,
            action: @escaping () -> Void
        ) {
            self.icon = icon
            self.action = action
        }

        public static func ==(lhs: LeadingAction, rhs: LeadingAction) -> Bool {
            return lhs === rhs
        }
    }

    public let configuration: ChatTimerScreen.Configuration
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let safeInsets: UIEdgeInsets
    public let leadingAction: LeadingAction?
    public let completion: (Int32?) -> Void

    public init(
        configuration: ChatTimerScreen.Configuration,
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        safeInsets: UIEdgeInsets,
        leadingAction: LeadingAction?,
        completion: @escaping (Int32?) -> Void
    ) {
        self.configuration = configuration
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.safeInsets = safeInsets
        self.leadingAction = leadingAction
        self.completion = completion
    }

    public static func ==(lhs: ChatTimerPickerContentComponent, rhs: ChatTimerPickerContentComponent) -> Bool {
        return false
    }

    public final class View: UIView, UIPickerViewDataSource, UIPickerViewDelegate {
        private struct PickerConfigurationSignature: Equatable {
            enum Picker: Equatable {
                case timeOfDay
                case date
                case dateTime
                case fixedValues(values: [Int32], selectionStrategy: ChatTimerScreen.Configuration.FixedSelectionStrategy)
            }

            let picker: Picker
            let currentValue: Int32?
            let minimumDate: Date?
            let maximumDate: Date?
            let pickerValueMapping: ChatTimerScreen.Configuration.PickerValueMapping
        }

        private let leadingButton = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let primaryButton = ComponentView<Empty>()
        private let secondaryButton = ComponentView<Empty>()

        private var component: ChatTimerPickerContentComponent?
        private weak var state: EmptyComponentState?

        private var pickerView: TimerPickerView?
        private var isCompleting = false

        public override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func pickerTextColor(configuration: ChatTimerScreen.Configuration, theme: PresentationTheme) -> UIColor {
            if let pickerTextColor = configuration.pickerTextColor {
                return pickerTextColor(theme)
            }

            switch configuration.style {
            case .default:
                return theme.actionSheet.primaryTextColor
            case .media:
                return .white
            }
        }

        private func pickerConfigurationSignature(_ configuration: ChatTimerScreen.Configuration) -> PickerConfigurationSignature {
            let picker: PickerConfigurationSignature.Picker
            switch configuration.picker {
            case .timeOfDay:
                picker = .timeOfDay
            case .date:
                picker = .date
            case .dateTime:
                picker = .dateTime
            case let .fixedValues(values, selectionStrategy, _):
                picker = .fixedValues(values: values, selectionStrategy: selectionStrategy)
            }
            return PickerConfigurationSignature(
                picker: picker,
                currentValue: configuration.currentValue,
                minimumDate: configuration.minimumDate,
                maximumDate: configuration.maximumDate,
                pickerValueMapping: configuration.pickerValueMapping
            )
        }

        private func mapPickerTimestamp(_ timestamp: Int32, mapping: ChatTimerScreen.Configuration.PickerValueMapping) -> Int32 {
            switch mapping {
            case .rawTimestamp:
                return timestamp
            case .roundDateToDaysUTC:
                return roundDateToDays(timestamp)
            case .secondsFromMidnightGMT:
                return timestamp
            }
        }

        private func selectedValue() -> Int32? {
            guard let component = self.component, let pickerView = self.pickerView else {
                return nil
            }

            switch component.configuration.picker {
            case let .fixedValues(values, _, _):
                guard let pickerView = pickerView as? TimerCustomPickerView else {
                    return nil
                }
                let row = pickerView.selectedRow(inComponent: 0)
                guard row >= 0, row < values.count else {
                    return nil
                }
                return values[row]
            case .timeOfDay, .date, .dateTime:
                guard let pickerView = pickerView as? TimerDatePickerView else {
                    return nil
                }
                return self.mapPickerTimestamp(Int32(pickerView.date.timeIntervalSince1970), mapping: component.configuration.pickerValueMapping)
            }
        }

        private func fixedValueSelectionIndex(
            values: [Int32],
            selectedValue: Int32,
            strategy: ChatTimerScreen.Configuration.FixedSelectionStrategy
        ) -> Int {
            switch strategy {
            case .exact:
                return values.firstIndex(of: selectedValue) ?? 0
            case .closestLowerOrEqual:
                var index = 0
                for i in 0 ..< values.count {
                    if values[i] <= selectedValue {
                        index = i
                    }
                }
                return index
            case .firstGreaterOrEqual:
                var index = max(0, values.count - 1)
                for i in 0 ..< values.count {
                    if selectedValue <= values[i] {
                        index = i
                        break
                    }
                }
                return index
            }
        }

        private func setupPickerView(configuration: ChatTimerScreen.Configuration, theme: PresentationTheme, strings: PresentationStrings) {
            let previousSelectedValue = self.selectedValue()
            let previousDate = (self.pickerView as? TimerDatePickerView)?.date

            self.pickerView?.removeFromSuperview()

            switch configuration.picker {
            case let .fixedValues(values, selectionStrategy, _):
                let pickerView = TimerCustomPickerView()
                pickerView.dataSource = self
                pickerView.delegate = self
                pickerView.selectorColor = self.pickerTextColor(configuration: configuration, theme: theme).withMultipliedAlpha(0.18)
                self.addSubview(pickerView)
                self.pickerView = pickerView

                if let selectedValue = previousSelectedValue ?? configuration.currentValue {
                    let index = self.fixedValueSelectionIndex(values: values, selectedValue: selectedValue, strategy: selectionStrategy)
                    pickerView.selectRow(index, inComponent: 0, animated: false)
                }
            case .timeOfDay:
                let pickerView = TimerDatePickerView()
                pickerView.datePickerMode = .time
                pickerView.timeZone = TimeZone(secondsFromGMT: 0)
                pickerView.locale = Locale.current
                if #available(iOS 13.4, *) {
                    pickerView.preferredDatePickerStyle = .wheels
                }
                pickerView.setValue(self.pickerTextColor(configuration: configuration, theme: theme), forKey: "textColor")
                pickerView.selectorColor = self.pickerTextColor(configuration: configuration, theme: theme).withMultipliedAlpha(0.18)
                pickerView.addTarget(self, action: #selector(self.datePickerChanged), for: .valueChanged)
                let initialTimestamp: Int32
                if let currentValue = configuration.currentValue {
                    initialTimestamp = self.mapPickerTimestamp(currentValue, mapping: configuration.pickerValueMapping)
                } else {
                    initialTimestamp = 0
                }
                let date = previousDate ?? Date(timeIntervalSince1970: Double(initialTimestamp))
                pickerView.date = date
                self.addSubview(pickerView)
                self.pickerView = pickerView
            case .date:
                let pickerView = TimerDatePickerView()
                pickerView.datePickerMode = .date
                pickerView.timeZone = TimeZone(secondsFromGMT: 0)
                pickerView.locale = localeWithStrings(strings)
                if #available(iOS 13.4, *) {
                    pickerView.preferredDatePickerStyle = .wheels
                }
                pickerView.minimumDate = configuration.minimumDate
                pickerView.maximumDate = configuration.maximumDate ?? Date(timeIntervalSince1970: Double(Int32.max - 1))
                pickerView.setValue(self.pickerTextColor(configuration: configuration, theme: theme), forKey: "textColor")
                pickerView.selectorColor = self.pickerTextColor(configuration: configuration, theme: theme).withMultipliedAlpha(0.18)
                pickerView.addTarget(self, action: #selector(self.datePickerChanged), for: .valueChanged)
                let initialTimestamp: Int32
                if let currentValue = configuration.currentValue {
                    initialTimestamp = self.mapPickerTimestamp(currentValue, mapping: configuration.pickerValueMapping)
                } else {
                    initialTimestamp = Int32(Date().timeIntervalSince1970)
                }
                var initialDate = previousDate ?? Date(timeIntervalSince1970: Double(initialTimestamp))
                if let minimumDate = pickerView.minimumDate, initialDate < minimumDate {
                    initialDate = minimumDate
                }
                if let maximumDate = pickerView.maximumDate, initialDate > maximumDate {
                    initialDate = maximumDate
                }
                pickerView.date = initialDate
                self.addSubview(pickerView)
                self.pickerView = pickerView
            case .dateTime:
                let pickerView = TimerDatePickerView()
                pickerView.datePickerMode = .dateAndTime
                pickerView.locale = localeWithStrings(strings)
                pickerView.minimumDate = configuration.minimumDate ?? Date()
                pickerView.maximumDate = configuration.maximumDate
                if #available(iOS 13.4, *) {
                    pickerView.preferredDatePickerStyle = .wheels
                }
                pickerView.setValue(self.pickerTextColor(configuration: configuration, theme: theme), forKey: "textColor")
                pickerView.setValue(false, forKey: "highlightsToday")
                pickerView.selectorColor = self.pickerTextColor(configuration: configuration, theme: theme).withMultipliedAlpha(0.18)
                pickerView.addTarget(self, action: #selector(self.datePickerChanged), for: .valueChanged)

                var date = previousDate ?? configuration.currentValue.flatMap { Date(timeIntervalSince1970: Double($0)) } ?? Date()
                if let minimumDate = pickerView.minimumDate, date < minimumDate {
                    date = minimumDate
                }
                if let maximumDate = pickerView.maximumDate, date > maximumDate {
                    date = maximumDate
                }
                pickerView.date = date
                self.addSubview(pickerView)
                self.pickerView = pickerView
            }
        }

        @objc private func datePickerChanged() {
            self.state?.updated(transition: .immediate)
        }

        private func complete(selectedValue: Int32?) {
            guard !self.isCompleting else {
                return
            }
            self.isCompleting = true

            let transformedValue: Int32?
            if let component = self.component {
                transformedValue = component.configuration.completionValueTransform(selectedValue)
            } else {
                transformedValue = nil
            }
            self.component?.completion(transformedValue)
        }

        public func update(
            component: ChatTimerPickerContentComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            let previousComponent = self.component
            let themeUpdated = previousComponent?.theme !== component.theme
            let stringsUpdated = previousComponent?.strings !== component.strings
            let pickerConfigurationUpdated: Bool
            if let previousConfiguration = previousComponent?.configuration {
                pickerConfigurationUpdated = self.pickerConfigurationSignature(previousConfiguration) != self.pickerConfigurationSignature(component.configuration)
            } else {
                pickerConfigurationUpdated = true
            }

            self.component = component
            self.state = state

            if self.pickerView == nil || themeUpdated || stringsUpdated || pickerConfigurationUpdated {
                self.setupPickerView(configuration: component.configuration, theme: component.theme, strings: component.strings)
            }

            let titleColor: UIColor
            switch component.configuration.style {
            case .default:
                titleColor = component.theme.actionSheet.primaryTextColor
            case .media:
                titleColor = .white
            }

            let barButtonSize = CGSize(width: 44.0, height: 44.0)
            if let leadingAction = component.leadingAction {
                let iconName: String
                switch leadingAction.icon {
                case .close:
                    iconName = "Navigation/Close"
                case .back:
                    iconName = "Navigation/Back"
                }
                let leadingButtonSize = self.leadingButton.update(
                    transition: transition,
                    component: AnyComponent(
                        GlassBarButtonComponent(
                            size: barButtonSize,
                            backgroundColor: nil,
                            isDark: component.theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: iconName, component: AnyComponent(
                                BundleIconComponent(
                                    name: iconName,
                                    tintColor: component.theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { [weak self] _ in
                                self?.component?.leadingAction?.action()
                            }
                        )
                    ),
                    environment: {},
                    containerSize: barButtonSize
                )
                if let leadingButtonView = self.leadingButton.view {
                    if leadingButtonView.superview == nil {
                        self.addSubview(leadingButtonView)
                    }
                    transition.setFrame(view: leadingButtonView, frame: CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: leadingButtonSize))
                }
            } else if let leadingButtonView = self.leadingButton.view, leadingButtonView.superview != nil {
                leadingButtonView.removeFromSuperview()
            }

            let titleText = component.configuration.title(component.strings)
            if let titleText, !titleText.isEmpty {
                let titleWidth = availableSize.width - (component.leadingAction != nil ? 120.0 : 60.0)
                let titleSize = self.title.update(
                    transition: transition,
                    component: AnyComponent(
                        Text(text: titleText, font: Font.semibold(17.0), color: titleColor)
                    ),
                    environment: {},
                    containerSize: CGSize(width: titleWidth, height: 44.0)
                )
                if let titleView = self.title.view {
                    if titleView.superview == nil {
                        self.addSubview(titleView)
                    }
                    transition.setFrame(
                        view: titleView,
                        frame: CGRect(
                            origin: CGPoint(
                                x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0),
                                y: floorToScreenPixels(16.0 + (barButtonSize.height - titleSize.height) / 2.0)
                            ),
                            size: titleSize
                        )
                    )
                }
            } else if let titleView = self.title.view, titleView.superview != nil {
                titleView.removeFromSuperview()
            }

            var contentHeight: CGFloat = 68.0

            let pickerHeight: CGFloat = 216.0
            if let pickerView = self.pickerView {
                transition.setFrame(view: pickerView as UIView, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: availableSize.width, height: pickerHeight)))
            }
            contentHeight += pickerHeight
            contentHeight += 17.0

            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: component.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let selectedValue = self.selectedValue()
            let primaryButtonTitle = component.configuration.primaryActionTitle(component.strings, component.dateTimeFormat, selectedValue)
            let primaryButtonSize = self.primaryButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(primaryButtonTitle), component: AnyComponent(
                        Text(text: primaryButtonTitle, font: Font.semibold(17.0), color: component.theme.list.itemCheckColors.foregroundColor)
                    )),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        self?.complete(selectedValue: self?.selectedValue())
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0)
            )
            if let primaryButtonView = self.primaryButton.view {
                if primaryButtonView.superview == nil {
                    self.addSubview(primaryButtonView)
                }
                transition.setFrame(view: primaryButtonView, frame: CGRect(origin: CGPoint(x: buttonInsets.left, y: contentHeight), size: primaryButtonSize))
            }
            contentHeight += primaryButtonSize.height

            if let secondaryAction = component.configuration.secondaryAction {
                contentHeight += 8.0

                let foregroundColor: UIColor
                switch secondaryAction.style {
                case .accent:
                    foregroundColor = component.theme.actionSheet.controlAccentColor
                case .destructive:
                    foregroundColor = component.theme.list.itemDestructiveColor
                }
                let secondaryButtonTitle = secondaryAction.title(component.strings)
                let secondaryButtonSize = self.secondaryButton.update(
                    transition: transition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: foregroundColor.withMultipliedAlpha(0.1),
                            foreground: foregroundColor,
                            pressedColor: foregroundColor.withMultipliedAlpha(0.2)
                        ),
                        content: AnyComponentWithIdentity(id: AnyHashable(secondaryButtonTitle), component: AnyComponent(
                            Text(text: secondaryButtonTitle, font: Font.semibold(17.0), color: foregroundColor)
                        )),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak self] in
                            self?.complete(selectedValue: secondaryAction.value())
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0)
                )
                if let secondaryButtonView = self.secondaryButton.view {
                    if secondaryButtonView.superview == nil {
                        self.addSubview(secondaryButtonView)
                    }
                    transition.setFrame(view: secondaryButtonView, frame: CGRect(origin: CGPoint(x: buttonInsets.left, y: contentHeight), size: secondaryButtonSize))
                }
                contentHeight += secondaryButtonSize.height
            } else if let secondaryButtonView = self.secondaryButton.view, secondaryButtonView.superview != nil {
                secondaryButtonView.removeFromSuperview()
            }

            contentHeight += buttonInsets.bottom

            return CGSize(width: availableSize.width, height: contentHeight)
        }

        public func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 1
        }

        public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            guard let configuration = self.component?.configuration else {
                return 0
            }

            switch configuration.picker {
            case let .fixedValues(values, _, _):
                return values.count
            case .timeOfDay, .date, .dateTime:
                return 0
            }
        }

        public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent componentIndex: Int, reusing view: UIView?) -> UIView {
            guard let component = self.component else {
                return UIView()
            }

            let itemView: TimerPickerItemView
            if let current = view as? TimerPickerItemView {
                itemView = current
            } else {
                itemView = TimerPickerItemView()
            }
            itemView.textColor = self.pickerTextColor(configuration: component.configuration, theme: component.theme)

            switch component.configuration.picker {
            case let .fixedValues(values, _, formatter):
                let value = values[row]
                itemView.value = (value, formatter(component.strings, value))
            case .timeOfDay, .date, .dateTime:
                break
            }

            return itemView
        }

        public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            self.state?.updated(transition: .immediate)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ChatTimerSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let configuration: ChatTimerScreen.Configuration
    let dismiss: () -> Void

    init(
        configuration: ChatTimerScreen.Configuration,
        dismiss: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.dismiss = dismiss
    }

    static func ==(lhs: ChatTimerSheetContentComponent, rhs: ChatTimerSheetContentComponent) -> Bool {
        return lhs.configuration == rhs.configuration
    }

    final class View: UIView {
        private let content = ComponentView<Empty>()

        private var component: ChatTimerSheetContentComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: ChatTimerSheetContentComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value

            self.component = component
            self.environment = environment
            self.state = state

            self.content.parentState = state
            let contentSize = self.content.update(
                transition: transition,
                component: AnyComponent(ChatTimerPickerContentComponent(
                    configuration: component.configuration,
                    theme: environment.theme,
                    strings: environment.strings,
                    dateTimeFormat: environment.dateTimeFormat,
                    safeInsets: environment.safeInsets,
                    leadingAction: ChatTimerPickerContentComponent.LeadingAction(
                        icon: .close,
                        action: { [weak self] in
                            self?.component?.dismiss()
                        }
                    ),
                    completion: { [weak self] value in
                        guard let self, let controller = self.environment?.controller() as? ChatTimerScreen else {
                            return
                        }
                        controller.completion(value)
                        self.component?.dismiss()
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: CGRect(origin: .zero, size: contentSize))
            }

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

private final class ChatTimerSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let configuration: ChatTimerScreen.Configuration

    init(configuration: ChatTimerScreen.Configuration) {
        self.configuration = configuration
    }

    static func ==(lhs: ChatTimerSheetComponent, rhs: ChatTimerSheetComponent) -> Bool {
        return lhs.configuration == rhs.configuration
    }

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()

        private var component: ChatTimerSheetComponent?
        private var environment: EnvironmentType?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func dismiss() {
            self.sheetAnimateOut.invoke(Action { [weak self] _ in
                guard let self, let controller = self.environment?.controller() else {
                    return
                }
                controller.dismiss(completion: nil)
            })
        }

        func update(component: ChatTimerSheetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component

            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment

            let sheetEnvironment = SheetComponentEnvironment(
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                isDisplaying: environment.isVisible,
                isCentered: environment.presentsFloatingPanels,
                hasInputHeight: !environment.inputHeight.isZero,
                regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                dismiss: { [weak self] _ in
                    self?.dismiss()
                }
            )

            let backgroundColor: UIColor
            switch component.configuration.style {
            case .default:
                backgroundColor = environment.theme.actionSheet.opaqueItemBackgroundColor
            case .media:
                backgroundColor = UIColor(rgb: 0x1c1c1e)
            }

            let _ = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent(
                    content: AnyComponent(ChatTimerSheetContentComponent(
                        configuration: component.configuration,
                        dismiss: { [weak self] in
                            self?.dismiss()
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(backgroundColor),
                    followContentSizeChanges: true,
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

public final class ChatTimerScreen: ViewControllerComponentContainer {
    public final class Configuration: Equatable {
        public enum ActionStyle {
            case accent
            case destructive
        }

        public enum PickerValueMapping {
            case rawTimestamp
            case roundDateToDaysUTC
            case secondsFromMidnightGMT
        }

        public enum FixedSelectionStrategy {
            case exact
            case closestLowerOrEqual
            case firstGreaterOrEqual
        }

        public final class SecondaryAction: Equatable {
            public let title: (PresentationStrings) -> String
            public let style: ActionStyle
            public let value: () -> Int32?

            public init(
                title: @escaping (PresentationStrings) -> String,
                style: ActionStyle,
                value: @escaping () -> Int32?
            ) {
                self.title = title
                self.style = style
                self.value = value
            }

            public static func ==(lhs: SecondaryAction, rhs: SecondaryAction) -> Bool {
                return lhs === rhs
            }
        }

        public enum PickerKind {
            case timeOfDay
            case date
            case dateTime
            case fixedValues(
                values: [Int32],
                selectionStrategy: FixedSelectionStrategy,
                formatter: (PresentationStrings, Int32) -> String
            )
        }

        public let style: ChatTimerScreenStyle
        public let title: (PresentationStrings) -> String?
        public let picker: PickerKind
        public let currentValue: Int32?
        public let minimumDate: Date?
        public let maximumDate: Date?
        public let pickerValueMapping: PickerValueMapping
        public let primaryActionTitle: (PresentationStrings, PresentationDateTimeFormat, Int32?) -> String
        public let secondaryAction: SecondaryAction?
        public let completionValueTransform: (Int32?) -> Int32?
        public let pickerTextColor: ((PresentationTheme) -> UIColor)?

        public init(
            style: ChatTimerScreenStyle,
            title: @escaping (PresentationStrings) -> String? = { _ in nil },
            picker: PickerKind,
            currentValue: Int32?,
            minimumDate: Date? = nil,
            maximumDate: Date? = nil,
            pickerValueMapping: PickerValueMapping,
            primaryActionTitle: @escaping (PresentationStrings, PresentationDateTimeFormat, Int32?) -> String,
            secondaryAction: SecondaryAction? = nil,
            completionValueTransform: @escaping (Int32?) -> Int32? = { $0 },
            pickerTextColor: ((PresentationTheme) -> UIColor)? = nil
        ) {
            self.style = style
            self.title = title
            self.picker = picker
            self.currentValue = currentValue
            self.minimumDate = minimumDate
            self.maximumDate = maximumDate
            self.pickerValueMapping = pickerValueMapping
            self.primaryActionTitle = primaryActionTitle
            self.secondaryAction = secondaryAction
            self.completionValueTransform = completionValueTransform
            self.pickerTextColor = pickerTextColor
        }

        public static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
            return lhs === rhs
        }
    }

    fileprivate let completion: (Int32?) -> Void

    private static func legacyConfiguration(
        style: ChatTimerScreenStyle,
        mode: ChatTimerScreenMode,
        currentTime: Int32?
    ) -> Configuration {
        switch mode {
        case .sendTimer:
            return Configuration(
                style: style,
                title: { strings in
                    strings.Conversation_Timer_Title
                },
                picker: .fixedValues(
                    values: [viewOnceTimeout] + timerValues,
                    selectionStrategy: .exact,
                    formatter: { strings, value in
                        if value == viewOnceTimeout {
                            return strings.MediaPicker_Timer_ViewOnce
                        } else {
                            return timeIntervalString(strings: strings, value: value)
                        }
                    }
                ),
                currentValue: currentTime ?? viewOnceTimeout,
                pickerValueMapping: .rawTimestamp,
                primaryActionTitle: { strings, _, _ in
                    strings.Conversation_Timer_Send
                },
                pickerTextColor: { _ in
                    .white
                }
            )
        case .autoremove:
            return Configuration(
                style: style,
                title: { strings in
                    strings.Conversation_DeleteTimer_SetupTitle
                },
                picker: .fixedValues(
                    values: autoremoveTimerValues,
                    selectionStrategy: .closestLowerOrEqual,
                    formatter: { strings, value in
                        timeIntervalString(strings: strings, value: value)
                    }
                ),
                currentValue: currentTime,
                pickerValueMapping: .rawTimestamp,
                primaryActionTitle: { strings, _, _ in
                    strings.Conversation_DeleteTimer_Apply
                },
                secondaryAction: currentTime != nil ? Configuration.SecondaryAction(
                    title: { strings in
                        strings.Conversation_DeleteTimer_Disable
                    },
                    style: .destructive,
                    value: {
                        0
                    }
                ) : nil,
                pickerTextColor: { theme in
                    if case .media = style {
                        return .white
                    } else {
                        return theme.list.itemPrimaryTextColor
                    }
                }
            )
        case .mute:
            return Configuration(
                style: style,
                title: { strings in
                    strings.Conversation_Mute_SetupTitle
                },
                picker: .dateTime,
                currentValue: currentTime,
                minimumDate: Date(),
                pickerValueMapping: .rawTimestamp,
                primaryActionTitle: { strings, dateTimeFormat, selectedValue in
                    if let selectedValue {
                        let now = Int32(Date().timeIntervalSince1970)
                        let timeInterval = max(0, selectedValue - now)
                        if timeInterval > 0 {
                            let timeString = stringForPreciseRelativeTimestamp(
                                strings: strings,
                                relativeTimestamp: selectedValue,
                                relativeTo: now,
                                dateTimeFormat: dateTimeFormat
                            )
                            return strings.Conversation_Mute_ApplyMuteUntil(timeString).string
                        }
                    }
                    return strings.Common_Close
                },
                completionValueTransform: { selectedValue in
                    guard let selectedValue else {
                        return nil
                    }
                    return max(0, selectedValue - Int32(Date().timeIntervalSince1970))
                },
                pickerTextColor: { theme in
                    if case .media = style {
                        return .white
                    } else {
                        return theme.list.itemPrimaryTextColor
                    }
                }
            )
        }
    }

    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        configuration: Configuration,
        completion: @escaping (Int32?) -> Void
    ) {
        self.completion = completion

        super.init(
            context: context,
            component: ChatTimerSheetComponent(configuration: configuration),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: configuration.style == .media ? .dark : .default,
            updatedPresentationData: updatedPresentationData
        )

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }

    public convenience init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        style: ChatTimerScreenStyle,
        mode: ChatTimerScreenMode = .sendTimer,
        currentTime: Int32? = nil,
        completion: @escaping (Int32) -> Void
    ) {
        let configuration = Self.legacyConfiguration(style: style, mode: mode, currentTime: currentTime)
        self.init(
            context: context,
            updatedPresentationData: updatedPresentationData,
            configuration: configuration,
            completion: { value in
                completion(value ?? 0)
            }
        )
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.view.disablesInteractiveModalDismiss = true
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
