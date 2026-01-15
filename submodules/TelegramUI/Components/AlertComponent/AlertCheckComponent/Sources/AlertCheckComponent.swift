import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramPresentationData
import AlertComponent
import PlainButtonComponent
import MultilineTextComponent
import CheckComponent
import TextFormat
import Markdown

public final class AlertCheckComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
        
    public class ExternalState {
        public fileprivate(set) var value: Bool
        fileprivate var valuePromise = Promise<Bool>()
        public var valueSignal: Signal<Bool, NoError>
        
        public init() {
            self.value = false
            self.valueSignal = self.valuePromise.get()
        }
    }
    
    let title: String
    let initialValue: Bool
    let externalState: ExternalState
    let linkAction: (() -> Void)?
    
    public init(
        title: String,
        initialValue: Bool,
        externalState: ExternalState,
        linkAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.initialValue = initialValue
        self.externalState = externalState
        self.linkAction = linkAction
    }
    
    public static func ==(lhs: AlertCheckComponent, rhs: AlertCheckComponent) -> Bool {
        return true
    }
    
    public final class View: UIView {
        private let button = ComponentView<Empty>()
        
        private var component: AlertCheckComponent?
        private weak var state: EmptyComponentState?
        
        private var isUpdating = false
        
        private var valuePromise = ValuePromise<Bool>(false)
        
        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            func findTextView(view: UIView?) -> ImmediateTextView? {
                if let view {
                    if let view = view as? ImmediateTextView {
                        return view
                    }
                    for view in view.subviews {
                        if let result = findTextView(view: view) {
                            return result
                        }
                    }
                }
                return nil
            }
            let result = super.hitTest(point, with: event)
            if let textView = findTextView(view: result) {
                if let (_, attributes) = textView.attributesAtPoint(self.convert(point, to: textView)) {
                    if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] != nil {
                        return textView
                    }
                }
            }
            return result
        }
        
        func update(component: AlertCheckComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            if self.component == nil {
                component.externalState.value = component.initialValue
                component.externalState.valuePromise.set(self.valuePromise.get())
            }
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let checkTheme = CheckComponent.Theme(
                backgroundColor: environment.theme.list.itemCheckColors.fillColor,
                strokeColor: environment.theme.list.itemCheckColors.foregroundColor,
                borderColor: environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.15),
                overlayBorder: false,
                hasInset: false,
                hasShadow: false
            )
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = environment.theme.actionSheet.primaryTextColor
            let linkColor = environment.theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: linkColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
            
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(HStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(CheckComponent(
                            theme: checkTheme,
                            size: CGSize(width: 18.0, height: 18.0),
                            selected: component.externalState.value
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                            text: .markdown(text: component.title, attributes: markdownAttributes),
                            maximumNumberOfLines: 2,
                            highlightColor: linkColor.withAlphaComponent(0.1),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { attributes, _ in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                    component.linkAction?()
                                }
                            }
                        )))
                    ], spacing: 10.0)),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.externalState.value = !component.externalState.value
                        self.valuePromise.set(component.externalState.value)
                        
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    animateAlpha: false,
                    animateScale: false
                )),
                environment: {
                },
                containerSize: CGSize(width: availableSize.width + 20.0, height: 1000.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - buttonSize.width) / 2.0), y: 7.0), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            
            return CGSize(width: availableSize.width, height: buttonSize.height + 7.0)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
