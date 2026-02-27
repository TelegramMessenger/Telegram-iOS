import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import UrlEscaping
import ComponentFlow
import AlertComponent
import StarsWithdrawalScreen

func giftAuctionCustomBidController(
    context: AccountContext,
    title: String,
    text: String,
    placeholder: String,
    action: String,
    minValue: Int64,
    value: Int64,
    apply: @escaping (Int64) -> Void,
    cancel: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let inputState = AlertAmountFieldComponent.ExternalState()
        
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(text))
        )
    ))
    
    var applyImpl: (() -> Void)?
    content.append(AnyComponentWithIdentity(
        id: "input",
        component: AnyComponent(
            AlertAmountFieldComponent(
                context: context,
                initialValue: value,
                minValue: minValue,
                maxValue: nil,
                placeholder: placeholder,
                isInitiallyFocused: true,
                externalState: inputState,
                returnKeyAction: {
                    applyImpl?()
                }
            )
        )
    ))
    
    let alertController = AlertScreen(
        context: context,
        configuration: AlertScreen.Configuration(allowInputInset: true),
        content: content,
        actions: [
            .init(title: strings.Common_Cancel, action: {
                cancel()
            }),
            .init(title: action, type: .default, action: {
                applyImpl?()
            }, autoDismiss: false)
        ]
    )
    applyImpl = {
        if let value = inputState.value, value >= minValue {
            apply(value)
        } else {
            inputState.resetToMinValue()
            inputState.animateError()
        }
    }
    return alertController
}

private final class AlertAmountFieldComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    public class ExternalState {
        public fileprivate(set) var value: Int64?
        public fileprivate(set) var animateError: () -> Void = {}
        public fileprivate(set) var activateInput: () -> Void = {}
        public fileprivate(set) var resetToMinValue: () -> Void = {}
        fileprivate let valuePromise = ValuePromise<Int64?>(nil)
        public var valueSignal: Signal<Int64?, NoError> {
            return self.valuePromise.get()
        }
        
        public init() {
        }
    }
    
    let context: AccountContext
    let initialValue: Int64?
    let minValue: Int64?
    let maxValue: Int64?
    let placeholder: String
    let isInitiallyFocused: Bool
    let externalState: ExternalState
    let returnKeyAction: (() -> Void)?
    
    public init(
        context: AccountContext,
        initialValue: Int64? = nil,
        minValue: Int64? = nil,
        maxValue: Int64? = nil,
        placeholder: String,
        isInitiallyFocused: Bool = false,
        externalState: ExternalState,
        returnKeyAction: (() -> Void)? = nil
    ) {
        self.context = context
        self.initialValue = initialValue
        self.minValue = minValue
        self.maxValue = maxValue
        self.placeholder = placeholder
        self.isInitiallyFocused = isInitiallyFocused
        self.externalState = externalState
        self.returnKeyAction = returnKeyAction
    }
    
    public static func ==(lhs: AlertAmountFieldComponent, rhs: AlertAmountFieldComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.initialValue != rhs.initialValue {
            return false
        }
        if lhs.minValue != rhs.minValue {
            return false
        }
        if lhs.maxValue != rhs.maxValue {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.isInitiallyFocused != rhs.isInitiallyFocused {
            return false
        }
        return true
    }
        
    public final class View: UIView, UITextFieldDelegate {
        private let background = ComponentView<Empty>()
        private let amountField = ComponentView<Empty>()
        
        private var currentValue: Int64?
        
        private var component: AlertAmountFieldComponent?
        private weak var state: EmptyComponentState?
        
        private var isUpdating = false
        
        func activateInput() {
            if let amountFieldView = self.amountField.view as? AmountFieldComponent.View {
                amountFieldView.activateInput()
            }
        }
        
        func resetToMinValue() {
            self.currentValue = self.component?.minValue
            self.state?.updated()
            
            if let amountFieldView = self.amountField.view as? AmountFieldComponent.View {
                amountFieldView.resetValue()
                amountFieldView.selectAll()
            }
        }
        
        func animateError() {
            if let amountFieldView = self.amountField.view as? AmountFieldComponent.View {
                amountFieldView.animateError()
            }
        }
        
        func update(component: AlertAmountFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.currentValue = component.initialValue
                
                component.externalState.animateError = { [weak self] in
                    self?.animateError()
                }
                component.externalState.activateInput = { [weak self] in
                    self?.activateInput()
                }
                component.externalState.resetToMinValue = { [weak self] in
                    self?.resetToMinValue()
                }
            }
            
            let isFirstTime = self.component == nil
            
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let topInset: CGFloat = 15.0
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let amountFieldSize = self.amountField.update(
                transition: .immediate,
                component: AnyComponent(
                    AmountFieldComponent(
                        textColor: environment.theme.actionSheet.primaryTextColor,
                        secondaryColor: environment.theme.actionSheet.secondaryTextColor,
                        placeholderColor: environment.theme.actionSheet.inputPlaceholderColor,
                        accentColor: environment.theme.actionSheet.controlAccentColor,
                        value: self.currentValue,
                        minValue: component.minValue,
                        forceMinValue: false,
                        allowZero: false,
                        maxValue: nil,
                        placeholderText: component.placeholder,
                        textFieldOffset: CGPoint(x: -4.0, y: -1.0),
                        labelText: nil,
                        currency: .stars,
                        dateTimeFormat: presentationData.dateTimeFormat,
                        amountUpdated: { [weak self] value in
                            guard let self else {
                                return
                            }
                            self.currentValue = value
                            component.externalState.value = value
                            component.externalState.valuePromise.set(value)
                        },
                        tag: nil
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 44.0)
            )
            var amountFieldFrame = CGRect(origin: CGPoint(x: -16.0, y: topInset - 1.0 + UIScreenPixel), size: amountFieldSize)
            if let amountFieldView = self.amountField.view {
                if amountFieldView.superview == nil {
                    amountFieldView.clipsToBounds = true
                    self.addSubview(amountFieldView)
                }
                amountFieldFrame.size.width -= 14.0
                amountFieldView.frame = amountFieldFrame
            }
            
            let backgroundPadding: CGFloat = 14.0
            let size = CGSize(width: availableSize.width, height: 50.0)
            
            let backgroundSize = self.background.update(
                transition: transition,
                component: AnyComponent(
                    FilledRoundedRectangleComponent(color: environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1), cornerRadius: .value(25.0), smoothCorners: false)
                ),
                environment: {},
                containerSize: CGSize(width: size.width + backgroundPadding * 2.0, height: size.height)
            )
            let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - backgroundSize.width) / 2.0), y: topInset ), size: backgroundSize)
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            if isFirstTime && component.isInitiallyFocused {
                self.activateInput()
            }
                        
            return CGSize(width: availableSize.width, height: size.height + topInset)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
