import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import AnimatedStickerComponent
import SolidRoundedButtonComponent
import MultilineTextComponent
import PresentationDataUtils
import PrefixSectionGroupComponent
import TextInputComponent
import CreditCardInputComponent
import Markdown

public final class ScrollChildEnvironment: Equatable {
    public let insets: UIEdgeInsets
    
    public init(insets: UIEdgeInsets) {
        self.insets = insets
    }
    
    public static func ==(lhs: ScrollChildEnvironment, rhs: ScrollChildEnvironment) -> Bool {
        if lhs.insets != rhs.insets {
            return false
        }
        
        return true
    }
}

public final class ScrollComponent<ChildEnvironment: Equatable>: Component {
    public typealias EnvironmentType = ChildEnvironment
    
    public let content: AnyComponent<(ChildEnvironment, ScrollChildEnvironment)>
    public let contentInsets: UIEdgeInsets
    
    public init(
        content: AnyComponent<(ChildEnvironment, ScrollChildEnvironment)>,
        contentInsets: UIEdgeInsets
    ) {
        self.content = content
        self.contentInsets = contentInsets
    }
    
    public static func ==(lhs: ScrollComponent, rhs: ScrollComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.contentInsets != rhs.contentInsets {
            return false
        }
        
        return true
    }
    
    public final class View: UIScrollView {
        private let contentView: ComponentHostView<(ChildEnvironment, ScrollChildEnvironment)>
        
        override init(frame: CGRect) {
            self.contentView = ComponentHostView()
            
            super.init(frame: frame)
            
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.contentInsetAdjustmentBehavior = .never
            }
            
            self.addSubview(self.contentView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ScrollComponent<ChildEnvironment>, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ChildEnvironment>, transition: Transition) -> CGSize {
            let contentSize = self.contentView.update(
                transition: transition,
                component: component.content,
                environment: {
                    environment[ChildEnvironment.self]
                    ScrollChildEnvironment(insets: component.contentInsets)
                },
                containerSize: CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
            )
            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: contentSize), completion: nil)
            
            self.contentSize = contentSize
            self.scrollIndicatorInsets = component.contentInsets
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ChildEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private struct CardEntryModel: Equatable {
    var number: String
    var name: String
    var expiration: String
    var code: String
}

private extension CardEntryModel {
    var isValid: Bool {
        if self.number.count != 4 * 4 {
            return false
        }
        if self.name.isEmpty {
            return false
        }
        if self.expiration.isEmpty {
            return false
        }
        if self.code.count != 3 {
            return false
        }
        return true
    }
}

private final class PaymentCardEntryScreenContentComponent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    let context: AccountContext
    let model: CardEntryModel
    let updateModelKey: (WritableKeyPath<CardEntryModel, String>, String) -> Void
    
    init(context: AccountContext, model: CardEntryModel, updateModelKey: @escaping (WritableKeyPath<CardEntryModel, String>, String) -> Void) {
        self.context = context
        self.model = model
        self.updateModelKey = updateModelKey
    }
    
    static func ==(lhs: PaymentCardEntryScreenContentComponent, rhs: PaymentCardEntryScreenContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.model != rhs.model {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let animation = Child(AnimatedStickerComponent.self)
        let text = Child(MultilineTextComponent.self)
        let inputSection = Child(PrefixSectionGroupComponent.self)
        let infoText = Child(MultilineTextComponent.self)
        
        return { context in
            let sideInset: CGFloat = 16.0
            
            let scrollEnvironment = context.environment[ScrollChildEnvironment.self].value
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let updateModelKey = context.component.updateModelKey
            
            var size = CGSize(width: context.availableSize.width, height: scrollEnvironment.insets.top)
            size.height += 18.0
            
            let animation = animation.update(
                component: AnimatedStickerComponent(
                    account: context.component.context.account,
                    animation: AnimatedStickerComponent.Animation(
                        source: .bundle(name: "CreateStream"),
                        loop: true
                    ),
                    size: CGSize(width: 84.0, height: 84.0)
                ),
                availableSize: CGSize(width: 84.0, height: 84.0),
                transition: context.transition
            )
            
            context.add(animation
                .position(CGPoint(x: size.width / 2.0, y: size.height + animation.size.height / 2.0))
            )
            size.height += animation.size.height
            size.height += 35.0
            
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Enter your card information or take a photo.", font: UIFont.systemFont(ofSize: 13.0), textColor: environment.theme.list.freeTextColor, paragraphAlignment: .center))
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 100.0),
                transition: context.transition
            )
            
            context.add(text
                .position(CGPoint(x: size.width / 2.0, y: size.height + text.size.height / 2.0))
            )
            size.height += text.size.height
            size.height += 32.0
            
            let inputSection = inputSection.update(
                component: PrefixSectionGroupComponent(
                    items: [
                        PrefixSectionGroupComponent.Item(
                            prefix: AnyComponentWithIdentity(
                                id: "numberLabel",
                                component: AnyComponent(Text(text: "Number", font: Font.regular(17.0), color: environment.theme.list.itemPrimaryTextColor))
                            ),
                            content: AnyComponentWithIdentity(
                                id: "numberInput",
                                component: AnyComponent(CreditCardInputComponent(
                                    dataType: .cardNumber,
                                    text: context.component.model.number,
                                    textColor: environment.theme.list.itemPrimaryTextColor,
                                    errorTextColor: environment.theme.list.itemDestructiveColor,
                                    placeholder: "Card Number",
                                    placeholderColor: environment.theme.list.itemPlaceholderTextColor,
                                    updated: { value in
                                        updateModelKey(\.number, value)
                                    }
                                ))
                            )
                        ),
                        PrefixSectionGroupComponent.Item(
                            prefix: AnyComponentWithIdentity(
                                id: "nameLabel",
                                component: AnyComponent(Text(text: "Name", font: Font.regular(17.0), color: environment.theme.list.itemPrimaryTextColor))
                            ),
                            content: AnyComponentWithIdentity(
                                id: "nameInput",
                                component: AnyComponent(TextInputComponent(
                                    text: context.component.model.name,
                                    textColor: environment.theme.list.itemPrimaryTextColor,
                                    placeholder: "Cardholder",
                                    placeholderColor: environment.theme.list.itemPlaceholderTextColor,
                                    updated: { value in
                                        updateModelKey(\.name, value)
                                    }
                                ))
                            )
                        ),
                        PrefixSectionGroupComponent.Item(
                            prefix: AnyComponentWithIdentity(
                                id: "expiresLabel",
                                component: AnyComponent(Text(text: "Expires", font: Font.regular(17.0), color: environment.theme.list.itemPrimaryTextColor))
                            ),
                            content: AnyComponentWithIdentity(
                                id: "expiresInput",
                                component: AnyComponent(CreditCardInputComponent(
                                    dataType: .expirationDate,
                                    text: context.component.model.expiration,
                                    textColor: environment.theme.list.itemPrimaryTextColor,
                                    errorTextColor: environment.theme.list.itemDestructiveColor,
                                    placeholder: "MM/YY",
                                    placeholderColor: environment.theme.list.itemPlaceholderTextColor,
                                    updated: { value in
                                        updateModelKey(\.expiration, value)
                                    }
                                ))
                            )
                        ),
                        PrefixSectionGroupComponent.Item(
                            prefix: AnyComponentWithIdentity(
                                id: "cvvLabel",
                                component: AnyComponent(Text(text: "CVV", font: Font.regular(17.0), color: environment.theme.list.itemPrimaryTextColor))
                            ),
                            content: AnyComponentWithIdentity(
                                id: "cvvInput",
                                component: AnyComponent(TextInputComponent(
                                    text: context.component.model.code,
                                    textColor: environment.theme.list.itemPrimaryTextColor,
                                    placeholder: "123",
                                    placeholderColor: environment.theme.list.itemPlaceholderTextColor,
                                    updated: { value in
                                        updateModelKey(\.code, value)
                                    }
                                ))
                            )
                        )
                    ],
                    backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                    separatorColor: environment.theme.list.itemBlocksSeparatorColor
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(inputSection
                .position(CGPoint(x: size.width / 2.0, y: size.height + inputSection.size.height / 2.0))
            )
            size.height += inputSection.size.height
            size.height += 8.0
            
            let body = MarkdownAttributeSet(font: UIFont.systemFont(ofSize: 13.0), textColor: environment.theme.list.freeTextColor)
            let link = MarkdownAttributeSet(font: UIFont.systemFont(ofSize: 13.0), textColor: environment.theme.list.itemAccentColor, additionalAttributes: ["URL": true as NSNumber])
            let attributes = MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in
                return nil
            })
            let infoText = infoText.update(
                component: MultilineTextComponent(
                    text: .markdown(text: "By adding a card, you agree to the [Terms of Service](terms).", attributes: attributes)
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 100.0),
                transition: context.transition
            )
            context.add(infoText
                .position(CGPoint(x: sideInset + sideInset + infoText.size.width / 2.0, y: size.height + infoText.size.height / 2.0))
            )
            size.height += text.size.height
            
            size.height += scrollEnvironment.insets.bottom
            
            return size
        }
    }
}

private final class PaymentCardEntryScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let model: CardEntryModel
    let updateModelKey: (WritableKeyPath<CardEntryModel, String>, String) -> Void
    
    init(context: AccountContext, model: CardEntryModel, updateModelKey: @escaping(WritableKeyPath<CardEntryModel, String>, String) -> Void) {
        self.context = context
        self.model = model
        self.updateModelKey = updateModelKey
    }
    
    static func ==(lhs: PaymentCardEntryScreenComponent, rhs: PaymentCardEntryScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.model != rhs.model {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let scrollContent = Child(ScrollComponent<EnvironmentType>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self].value
            
            let background = background.update(component: Rectangle(color: environment.theme.list.blocksBackgroundColor), environment: {}, availableSize: context.availableSize, transition: context.transition)
            
            let scrollContent = scrollContent.update(
                component: ScrollComponent<EnvironmentType>(
                    content: AnyComponent(PaymentCardEntryScreenContentComponent(
                        context: context.component.context,
                        model: context.component.model,
                        updateModelKey: context.component.updateModelKey
                    )),
                    contentInsets: UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
                ),
                environment: { environment },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            context.add(scrollContent
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class PaymentCardEntryScreen: ViewControllerComponentContainer {
    public struct EnteredCardInfo: Equatable {
        public var id: UInt64
        public var number: String
        public var name: String
        public var expiration: String
        public var code: String
    }
    
    private let context: AccountContext
    private let completion: (EnteredCardInfo) -> Void
    
    private var doneItem: UIBarButtonItem?
    
    private var model: CardEntryModel
    
    public init(context: AccountContext, completion: @escaping (EnteredCardInfo) -> Void) {
        self.context = context
        self.completion = completion
        
        self.model = CardEntryModel(number: "", name: "", expiration: "", code: "")
        
        var updateModelKeyImpl: ((WritableKeyPath<CardEntryModel, String>, String) -> Void)?
        
        super.init(context: context, component: PaymentCardEntryScreenComponent(context: context, model: self.model, updateModelKey: { key, value in
            updateModelKeyImpl?(key, value)
        }), navigationBarAppearance: .transparent)
        
        self.title = "Add Payment Method"
        
        self.doneItem = UIBarButtonItem(title: "Add", style: .done, target: self, action: #selector(self.donePressed))
        self.navigationItem.setRightBarButton(self.doneItem, animated: false)
        self.doneItem?.isEnabled = false
        
        self.navigationPresentation = .modal
        
        updateModelKeyImpl = { [weak self] key, value in
            self?.updateModelKey(key: key, value: value)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func donePressed() {
        self.dismiss(completion: nil)
        self.completion(EnteredCardInfo(id: UInt64.random(in: 0 ... UInt64.max), number: self.model.number, name: self.model.name, expiration: self.model.expiration, code: self.model.code))
    }
    
    private func updateModelKey(key: WritableKeyPath<CardEntryModel, String>, value: String) {
        self.model[keyPath: key] = value
        self.updateComponent(component: AnyComponent(PaymentCardEntryScreenComponent(context: self.context, model: self.model, updateModelKey: { [weak self] key, value in
            self?.updateModelKey(key: key, value: value)
        })), transition: .immediate)
        
        self.doneItem?.isEnabled = self.model.isValid
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    }
}
