import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramStringFormatting
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import ButtonComponent
import GlassBarButtonComponent
import AnimatedTextComponent
import BundleIconComponent

enum LocationDistancePickerScreenStyle {
    case `default`
    case media
}

final class LocationDistancePickerScreen: ViewControllerComponentContainer {
    private let willDismissImpl: () -> Void
    private var didCallWillDismiss = false
    
    init(context: AccountContext, style: LocationDistancePickerScreenStyle, compactDisplayTitle: String?, distances: Signal<[Double], NoError>, updated: @escaping (Int32?) -> Void, completion: @escaping (Int32, @escaping () -> Void) -> Void, willDismiss: @escaping () -> Void) {
        self.willDismissImpl = willDismiss
        
        super.init(
            context: context,
            component: LocationDistancePickerScreenComponent(
                context: context,
                style: style,
                compactDisplayTitle: compactDisplayTitle,
                distances: distances,
                updated: { distance in
                    updated(distance)
                },
                completion: completion,
                willDismiss: willDismiss
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore
        )
        
        self.blocksBackgroundWhenInOverlay = true
        self.navigationPresentation = .flatModal
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func performWillDismissOnce() {
        if self.didCallWillDismiss {
            return
        }
        self.didCallWillDismiss = true
        self.willDismissImpl()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if let componentView = self.node.hostView.componentView as? LocationDistancePickerScreenComponent.View {
            componentView.requestDismiss(completion: completion)
        } else {
            self.performWillDismissOnce()
            super.dismiss(animated: false, completion: completion)
        }
    }
    
    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if flag {
            self.dismiss(completion: completion)
        } else {
            super.dismiss(animated: false, completion: completion)
        }
    }
}

private final class TimerPickerView: UIPickerView {
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
        
        if let selectorColor = self.selectorColor {
            if subview.bounds.height <= 1.0 {
                subview.backgroundColor = selectorColor
            }
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if let selectorColor = self.selectorColor {
            for subview in self.subviews {
                if subview.bounds.height <= 1.0 {
                    subview.backgroundColor = selectorColor
                }
            }
        }
    }
}

private let unitValues: [Int32] = {
    var values: [Int32] = []
    for i in 0 ..< 99 {
        values.append(Int32(i))
    }
    return values
}()

private let smallUnitValues: [Int32] = {
    var values: [Int32] = []
    values.append(0)
    values.append(5)
    for i in 1 ..< 10 {
        values.append(Int32(i * 10))
    }
    return values
}()

private final class LocationDistancePickerScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let style: LocationDistancePickerScreenStyle
    let compactDisplayTitle: String?
    let distances: Signal<[Double], NoError>
    let updated: (Int32) -> Void
    let completion: (Int32, @escaping () -> Void) -> Void
    let willDismiss: () -> Void
    
    init(
        context: AccountContext,
        style: LocationDistancePickerScreenStyle,
        compactDisplayTitle: String?,
        distances: Signal<[Double], NoError>,
        updated: @escaping (Int32) -> Void,
        completion: @escaping (Int32, @escaping () -> Void) -> Void,
        willDismiss: @escaping () -> Void
    ) {
        self.context = context
        self.style = style
        self.compactDisplayTitle = compactDisplayTitle
        self.distances = distances
        self.updated = updated
        self.completion = completion
        self.willDismiss = willDismiss
    }
    
    static func ==(lhs: LocationDistancePickerScreenComponent, rhs: LocationDistancePickerScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.compactDisplayTitle != rhs.compactDisplayTitle {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var component: LocationDistancePickerScreenComponent?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isDismissed = false
        private var didCallWillDismiss = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func performWillDismissOnce() {
            if self.didCallWillDismiss {
                return
            }
            self.didCallWillDismiss = true
            
            if let controller = self.environment?.controller() as? LocationDistancePickerScreen {
                controller.performWillDismissOnce()
            } else {
                self.component?.willDismiss()
            }
        }
        
        func requestDismiss(completion: (() -> Void)? = nil) {
            self.performWillDismissOnce()
            
            if self.isDismissed {
                completion?()
                return
            }
            self.isDismissed = true
            
            self.sheetAnimateOut.invoke(Action { [weak self] _ in
                guard let self else {
                    completion?()
                    return
                }
                if let controller = self.environment?.controller() {
                    controller.dismiss(animated: false, completion: completion)
                } else {
                    completion?()
                }
            })
        }
        
        func update(component: LocationDistancePickerScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            
            let sheetEnvironment = SheetComponentEnvironment(
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                isDisplaying: environment.isVisible,
                isCentered: environment.presentsFloatingPanels,
                hasInputHeight: !environment.inputHeight.isZero,
                regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                dismiss: { [weak self] _ in
                    self?.requestDismiss()
                }
            )
            
            let backgroundColor: SheetComponent<ViewControllerComponentContainer.Environment>.BackgroundColor
            switch component.style {
            case .default:
                backgroundColor = .color(environment.theme.list.modalPlainBackgroundColor)
            case .media:
                backgroundColor = .color(UIColor(rgb: 0x1c1c1e))
            }
            
            let _ = self.sheet.update(
                transition: transition,
                component: AnyComponent(
                    SheetComponent<ViewControllerComponentContainer.Environment>(
                        content: AnyComponent(
                            LocationDistancePickerContentComponent(
                                style: component.style,
                                compactDisplayTitle: component.compactDisplayTitle,
                                distances: component.distances,
                                updated: component.updated,
                                completion: { [weak self] distance in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    component.completion(distance, { [weak self] in
                                        self?.requestDismiss()
                                    })
                                },
                                dismiss: { [weak self] in
                                    self?.requestDismiss()
                                }
                            )
                        ),
                        style: .glass,
                        backgroundColor: backgroundColor,
                        hasDimView: false,
                        animateOut: self.sheetAnimateOut,
                        willDismiss: { [weak self] in
                            self?.performWillDismissOnce()
                        }
                    )
                ),
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class LocationDistancePickerContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let style: LocationDistancePickerScreenStyle
    let compactDisplayTitle: String?
    let distances: Signal<[Double], NoError>
    let updated: (Int32) -> Void
    let completion: (Int32) -> Void
    let dismiss: () -> Void
    
    init(
        style: LocationDistancePickerScreenStyle,
        compactDisplayTitle: String?,
        distances: Signal<[Double], NoError>,
        updated: @escaping (Int32) -> Void,
        completion: @escaping (Int32) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.style = style
        self.compactDisplayTitle = compactDisplayTitle
        self.distances = distances
        self.updated = updated
        self.completion = completion
        self.dismiss = dismiss
    }
    
    static func ==(lhs: LocationDistancePickerContentComponent, rhs: LocationDistancePickerContentComponent) -> Bool {
        if lhs.style != rhs.style {
            return false
        }
        if lhs.compactDisplayTitle != rhs.compactDisplayTitle {
            return false
        }
        return true
    }
    
    final class View: UIView, UIPickerViewDataSource, UIPickerViewDelegate {
        private let closeButton = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let unitLabel = ComponentView<Empty>()
        private let smallUnitLabel = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        private let warningText = ComponentView<Empty>()
        
        private var pickerView: TimerPickerView?
        private var pickerTimer: SwiftSignalKit.Timer?
        private var distancesDisposable: Disposable?
        
        private var component: LocationDistancePickerContentComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        private var distances: [Double] = []
        private var previousReportedValue: Int32?
        private var isCompleting = false
        
        private var isUpdating = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.distancesDisposable?.dispose()
            self.pickerTimer?.invalidate()
        }
        
        private var usesMetricSystem: Bool {
            guard let environment = self.environment else {
                return true
            }
            let locale = localeWithStrings(environment.strings)
            if locale.identifier.hasSuffix("GB") {
                return false
            }
            return locale.usesMetricSystem
        }
        
        private func setupDistancesIfNeeded(component: LocationDistancePickerContentComponent) {
            if self.distancesDisposable != nil {
                return
            }
            self.distancesDisposable = (component.distances
            |> deliverOnMainQueue).start(next: { [weak self] distances in
                guard let self else {
                    return
                }
                self.distances = distances
                if !self.isUpdating {
                    self.state?.updated(transition: .immediate)
                }
            })
        }
        
        private func setupPickerViewIfNeeded() {
            if self.pickerView != nil {
                return
            }
            
            let pickerView = TimerPickerView()
            pickerView.selectorColor = UIColor(rgb: 0xffffff, alpha: 0.18)
            pickerView.dataSource = self
            pickerView.delegate = self
            pickerView.selectRow(0, inComponent: 0, animated: false)
            if self.usesMetricSystem {
                pickerView.selectRow(6, inComponent: 1, animated: false)
            } else {
                pickerView.selectRow(4, inComponent: 1, animated: false)
            }
            self.addSubview(pickerView)
            self.pickerView = pickerView
            
            let pickerTimer = SwiftSignalKit.Timer(timeout: 0.4, repeat: true, completion: { [weak self] in
                guard let self else {
                    return
                }
                if self.reportSelectedValue() {
                    self.state?.updated(transition: .immediate)
                }
            }, queue: Queue.mainQueue())
            self.pickerTimer = pickerTimer
            pickerTimer.start()
            
            let _ = self.reportSelectedValue()
        }
        
        private func selectedDistance() -> (value: Int32, convertedValue: Int32, convertedDistance: Double, distanceText: String)? {
            guard let pickerView = self.pickerView, let environment = self.environment else {
                return nil
            }
            
            let selectedLargeRow = pickerView.selectedRow(inComponent: 0)
            var selectedSmallRow = pickerView.selectedRow(inComponent: 1)
            if selectedLargeRow == 0 && selectedSmallRow == 0 {
                selectedSmallRow = 1
            }
            
            let largeValue = unitValues[selectedLargeRow]
            let smallValue = smallUnitValues[selectedSmallRow]
            
            let value = largeValue * 1000 + smallValue * 10
            var formattedValue = String(format: "%0.1f", CGFloat(value) / 1000.0)
            if smallValue == 5 {
                formattedValue = formattedValue.replacingOccurrences(of: ".1", with: ".05").replacingOccurrences(of: ",1", with: ",05")
            }
            let distanceText = self.usesMetricSystem ? "\(formattedValue) \(environment.strings.Location_ProximityNotification_DistanceKM)" : "\(formattedValue) \(environment.strings.Location_ProximityNotification_DistanceMI)"
            
            var convertedDistance = Double(value)
            if !self.usesMetricSystem {
                convertedDistance = convertedDistance * 1.60934
            }
            
            return (value, Int32(convertedDistance), convertedDistance, distanceText)
        }
        
        private func reportSelectedValue() -> Bool {
            guard let selectedDistance = self.selectedDistance(), let component = self.component else {
                return false
            }
            if let previousReportedValue = self.previousReportedValue, selectedDistance.convertedValue == previousReportedValue {
                return false
            }
            self.previousReportedValue = selectedDistance.convertedValue
            component.updated(selectedDistance.convertedValue)
            return true
        }
        
        func update(component: LocationDistancePickerContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousEnvironment = self.environment
            self.component = component
            self.state = state
            
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            
            self.setupDistancesIfNeeded(component: component)
            self.setupPickerViewIfNeeded()
            
            if let previousEnvironment, previousEnvironment.strings !== environment.strings || previousEnvironment.theme !== environment.theme {
                self.pickerView?.reloadAllComponents()
            }
            
            let textColor: UIColor
            let secondaryTextColor: UIColor
            let buttonFillColor: UIColor
            let buttonForegroundColor: UIColor
            switch component.style {
            case .default:
                textColor = environment.theme.actionSheet.primaryTextColor
                secondaryTextColor = environment.theme.actionSheet.secondaryTextColor
                buttonFillColor = environment.theme.list.itemCheckColors.fillColor
                buttonForegroundColor = environment.theme.list.itemCheckColors.foregroundColor
            case .media:
                textColor = .white
                secondaryTextColor = UIColor(white: 1.0, alpha: 0.7)
                buttonFillColor = environment.theme.list.itemCheckColors.fillColor
                buttonForegroundColor = environment.theme.list.itemCheckColors.foregroundColor
            }
            
            let sideInset: CGFloat = 16.0
            let topInset: CGFloat = 16.0
            let titleHeight: CGFloat = 54.0
            let pickerHeight: CGFloat = 216.0
            let buttonHeight: CGFloat = 52.0
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: buttonHeight, sideInset: 30.0)
            let buttonWidth = availableSize.width - buttonInsets.left - buttonInsets.right
            
            let selectedDistance = self.selectedDistance()
            let distanceText = selectedDistance?.distanceText ?? ""
            let isTooFar: Bool
            if let selectedDistance, let maximumDistance = self.distances.last {
                isTooFar = selectedDistance.convertedDistance > maximumDistance
            } else {
                isTooFar = false
            }
            
            let closeButtonSize = CGSize(width: 44.0, height: 44.0)
            let closeSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(
                    GlassBarButtonComponent(
                        size: closeButtonSize,
                        backgroundColor: nil,
                        isDark: component.style == .media ? true : environment.theme.overallDarkAppearance,
                        state: .glass,
                        component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                            BundleIconComponent(
                                name: "Navigation/Close",
                                tintColor: environment.theme.chat.inputPanel.panelControlColor
                            )
                        )),
                        action: { [weak self] _ in
                            self?.component?.dismiss()
                        }
                    )
                ),
                environment: {},
                containerSize: closeButtonSize
            )
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: CGRect(origin: CGPoint(x: sideInset, y: topInset), size: closeSize))
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(Text(
                    text: environment.strings.Location_ProximityNotification_Title,
                    font: Font.bold(17.0),
                    color: textColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 120.0, height: titleHeight)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) * 0.5), y: topInset + floorToScreenPixels((closeButtonSize.height - titleSize.height) * 0.5)), size: titleSize))
            }
            
            let pickerFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset + titleHeight), size: CGSize(width: availableSize.width, height: pickerHeight))
            if let pickerView = self.pickerView {
                transition.setFrame(view: pickerView, frame: pickerFrame)
            }
            
            let unitLabelSize = self.unitLabel.update(
                transition: transition,
                component: AnyComponent(Text(
                    text: self.usesMetricSystem ? environment.strings.Location_ProximityNotification_DistanceKM : environment.strings.Location_ProximityNotification_DistanceMI,
                    font: Font.regular(15.0),
                    color: textColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: titleHeight)
            )
            if let unitLabelView = self.unitLabel.view {
                if unitLabelView.superview == nil {
                    self.addSubview(unitLabelView)
                }
                transition.setFrame(view: unitLabelView, frame: CGRect(origin: CGPoint(x: floor(pickerFrame.width / 4.0) + 50.0, y: floor(pickerFrame.midY - unitLabelSize.height / 2.0)), size: unitLabelSize))
            }
            
            let smallUnitLabelSize = self.smallUnitLabel.update(
                transition: transition,
                component: AnyComponent(Text(
                    text: self.usesMetricSystem ? environment.strings.Location_ProximityNotification_DistanceM : "",
                    font: Font.regular(15.0),
                    color: textColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: titleHeight)
            )
            if let smallUnitLabelView = self.smallUnitLabel.view {
                if smallUnitLabelView.superview == nil {
                    self.addSubview(smallUnitLabelView)
                }
                transition.setFrame(view: smallUnitLabelView, frame: CGRect(origin: CGPoint(x: floor(pickerFrame.width / 4.0 * 3.0) + 50.0, y: floor(pickerFrame.midY - smallUnitLabelSize.height / 2.0)), size: smallUnitLabelSize))
            }
            
            let bottomY = pickerFrame.maxY + 17.0
            var buttonTitle = environment.strings.Location_ProximityNotification_Notify(distanceText).string
            if let displayTitle = component.compactDisplayTitle {
                let longTitle = environment.strings.Location_ProximityNotification_NotifyLong(displayTitle, distanceText).string
                let titleSize = NSAttributedString(string: longTitle, font: Font.semibold(17.0), textColor: .black).boundingRect(with: CGSize(width: availableSize.width * 2.0, height: 50.0), options: .usesLineFragmentOrigin, context: nil).size
                if titleSize.width < availableSize.width - 70.0 {
                    buttonTitle = longTitle
                }
            }
                        
            var buttonTransition = transition
            if transition.animation.isImmediate {
                buttonTransition = buttonTransition.withAnimation(.curve(duration: 0.2, curve: .easeInOut))
            }
            let buttonSize = self.button.update(
                transition: buttonTransition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: buttonFillColor,
                        foreground: buttonForegroundColor,
                        pressedColor: buttonFillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable("title"), component: AnyComponent(
                        AnimatedTextComponent(
                            font: Font.semibold(17.0),
                            color: buttonForegroundColor,
                            items: [
                                AnimatedTextComponent.Item(id: AnyHashable("title"), content: .text(buttonTitle))
                            ],
                            noDelay: true
                        )
                    )),
                    isEnabled: !isTooFar && !self.isCompleting,
                    tintWhenDisabled: false,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component, let selectedDistance = self.selectedDistance() else {
                            return
                        }
                        self.isCompleting = true
                        self.state?.updated(transition: .immediate)
                        component.completion(selectedDistance.convertedValue)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: buttonHeight)
            )
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: CGRect(origin: CGPoint(x: buttonInsets.left, y: bottomY), size: buttonSize))
                buttonTransition.setAlpha(view: buttonView, alpha: isTooFar ? 0.0 : 1.0)
            }
            
            let warningSize = self.warningText.update(
                transition: transition,
                component: AnyComponent(Text(
                    text: environment.strings.Location_ProximityNotification_AlreadyClose(distanceText).string,
                    font: Font.regular(14.0),
                    color: secondaryTextColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: buttonHeight)
            )
            if let warningTextView = self.warningText.view {
                if warningTextView.superview == nil {
                    self.addSubview(warningTextView)
                }
                transition.setFrame(view: warningTextView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - warningSize.width) * 0.5), y: bottomY + floorToScreenPixels((buttonHeight - warningSize.height) * 0.5)), size: warningSize))
                buttonTransition.setAlpha(view: warningTextView, alpha: isTooFar ? 1.0 : 0.0)
            }
            
            return CGSize(width: availableSize.width, height: bottomY + buttonHeight + buttonInsets.bottom)
        }
        
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 2
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            if component == 0 {
                return unitValues.count
            } else if component == 1 {
                return smallUnitValues.count
            } else {
                return 1
            }
        }
        
        func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
            guard let environment = self.environment else {
                return nil
            }
            
            let font = Font.regular(17.0)
            let string: String
            if component == 0 {
                let value = unitValues[row]
                string = "\(value)"
            } else {
                if self.usesMetricSystem {
                    let value = String(format: "%d", smallUnitValues[row] * 10)
                    string = "\(value)"
                } else {
                    let value = smallUnitValues[row]
                    if value == 0 {
                        string = ".0"
                    } else if value == 5 {
                        string = ".05"
                    } else {
                        string = ".\(value / 10)"
                    }
                }
            }
            
            let textColor: UIColor
            switch self.component?.style {
            case .media:
                textColor = .white
            default:
                textColor = environment.theme.actionSheet.primaryTextColor
            }
            return NSAttributedString(string: string, font: font, textColor: textColor)
        }
        
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if pickerView.selectedRow(inComponent: 0) == 0 && pickerView.selectedRow(inComponent: 1) == 0 {
                pickerView.selectRow(1, inComponent: 1, animated: true)
            }
            let _ = self.reportSelectedValue()
            self.state?.updated(transition: .immediate)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
