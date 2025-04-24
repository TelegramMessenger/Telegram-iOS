import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import TelegramStringFormatting
import ViewControllerComponent
import SheetComponent
import BundleIconComponent
import MultilineTextComponent
import ButtonComponent
import ListSectionComponent
import ListActionItemComponent
import AccountContext
import AvatarNode

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peer: EnginePeer
    let existingKeys: [WebAppSecureStorage.ExistingKey]
    let completion: (String) -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        peer: EnginePeer,
        existingKeys: [WebAppSecureStorage.ExistingKey],
        completion: @escaping (String) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.peer = peer
        self.existingKeys = existingKeys
        self.completion = completion
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.existingKeys != rhs.existingKeys {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var selectedUuid: String?
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
        
        let title = Child(MultilineTextComponent.self)
        let avatar = Child(AvatarComponent.self)
        let text = Child(MultilineTextComponent.self)
        let keys = Child(ListSectionComponent.self)
        let button = Child(ButtonComponent.self)
                        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 32.0 + environment.safeInsets.left
            
            let titleFont = Font.semibold(17.0)
            let textFont = Font.regular(13.0)
            let boldTextFont = Font.semibold(13.0)
            let textColor = theme.actionSheet.primaryTextColor
        
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
        
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Text(text: strings.Common_Cancel, font: Font.regular(17.0), color: theme.actionSheet.controlAccentColor)),
                    action: { [weak component] in
                        component?.dismiss()
                    }
                ),
                availableSize: CGSize(width: 100.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: environment.safeInsets.left + 16.0 + closeButton.size.width / 2.0, y: 28.0))
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: strings.WebApp_ImportData_Title, font: titleFont, textColor: textColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 24.0
            
            let avatar = avatar.update(
                component: AvatarComponent(
                    context: component.context,
                    peer: component.peer,
                    size: CGSize(width: 80.0, height: 80.0)
                ),
                availableSize: CGSize(width: 80.0, height: 80.0),
                transition: .immediate
            )
            context.add(avatar
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + avatar.size.height / 2.0))
            )
            contentSize.height += avatar.size.height
            contentSize.height += 22.0
            
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(
                        text: strings.WebApp_ImportData_Description(component.peer.compactDisplayTitle).string,
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                            bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                            link: MarkdownAttributeSet(font: textFont, textColor: textColor),
                            linkAttribute: { _ in return nil }
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += 29.0
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            for key in component.existingKeys {
                var titleComponents: [AnyComponentWithIdentity<Empty>] = []
                titleComponents.append(
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: key.accountName,
                            font: Font.semibold(presentationData.listsFontSize.itemListBaseFontSize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )))
                )
                titleComponents.append(
                    AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.WebApp_ImportData_CreatedOn(stringForMediumCompactDate(timestamp: key.timestamp, strings: strings, dateTimeFormat: environment.dateTimeFormat)).string,
                            font: Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize * 15.0 / 17.0)),
                            textColor: environment.theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )))
                )
                items.append(AnyComponentWithIdentity(id: key.uuid, component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    title: AnyComponent(VStack(titleComponents, alignment: .left, spacing: 3.0)),
                    contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                    leftIcon: .check(ListActionItemComponent.LeftIcon.Check(isSelected: key.uuid == state.selectedUuid, isEnabled: true, toggle: nil)),
                    accessory: nil,
                    action: { [weak state] _ in
                        if let state {
                            state.selectedUuid = key.uuid
                            state.updated(transition: .spring(duration: 0.3))
                        }
                    }
                ))))
            }
            
            let keys = keys.update(
                component: ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.WebApp_ImportData_AccountHeader.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: items
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 1000.0),
                transition: context.transition
            )
            context.add(keys
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + keys.size.height / 2.0))
            )
            contentSize.height += keys.size.height
            contentSize.height += 24.0
            
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable("import"),
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: strings.WebApp_ImportData_Import, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)))
                        )
                    ),
                    isEnabled: state.selectedUuid != nil,
                    allowActionWhenDisabled: true,
                    displaysProgress: false,
                    action: { [weak state] in
                        guard let state else {
                            return
                        }
                        if let selectedUuid = state.selectedUuid {
                            component.completion(selectedUuid)
                            component.dismiss()
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
                .cornerRadius(10.0)
            )
            contentSize.height += button.size.height
            contentSize.height += 7.0
                                      
            let effectiveBottomInset: CGFloat = environment.metrics.isTablet ? 0.0 : environment.safeInsets.bottom
            contentSize.height += 5.0 + effectiveBottomInset
                                    
            return contentSize
        }
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peer: EnginePeer
    let existingKeys: [WebAppSecureStorage.ExistingKey]
    let completion: (String) -> Void
    
    init(
        context: AccountContext,
        peer: EnginePeer,
        existingKeys: [WebAppSecureStorage.ExistingKey],
        completion: @escaping (String) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.existingKeys = existingKeys
        self.completion = completion
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.existingKeys != rhs.existingKeys {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let theme = environment.theme.withModalBlocksBackground()
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        peer: context.component.peer,
                        existingKeys: context.component.existingKeys,
                        completion: context.component.completion,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(theme.list.blocksBackgroundColor),
                    followContentSizeChanges: true,
                    externalState: sheetExternalState,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(environment.safeInsets.bottom, sheetExternalState.contentHeight), right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}


final class WebAppSecureStorageTransferScreen: ViewControllerComponentContainer {
    init(
        context: AccountContext,
        peer: EnginePeer,
        existingKeys: [WebAppSecureStorage.ExistingKey],
        completion: @escaping (String?) -> Void
    ) {
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                peer: peer,
                existingKeys: existingKeys,
                completion: completion
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class AvatarComponent: Component {
    let context: AccountContext
    let peer: EnginePeer
    let size: CGSize?

    init(context: AccountContext, peer: EnginePeer, size: CGSize? = nil) {
        self.context = context
        self.peer = peer
        self.size = size
    }

    static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }

    final class View: UIView {
        private var avatarNode: AvatarNode?
        
        private var component: AvatarComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = component.size ?? availableSize

            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: floor(size.width * 0.5)))
                avatarNode.displaysAsynchronously = false
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            avatarNode.frame = CGRect(origin: CGPoint(), size: size)
            avatarNode.setPeer(
                context: component.context,
                theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                peer: component.peer,
                synchronousLoad: true,
                displayDimensions: size
            )
            avatarNode.updateSize(size: size)
            
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
