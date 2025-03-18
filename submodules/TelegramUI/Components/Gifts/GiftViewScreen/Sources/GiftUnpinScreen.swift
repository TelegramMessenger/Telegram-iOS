import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BundleIconComponent
import BalancedTextComponent
import MultilineTextComponent
import ButtonComponent
import PlainButtonComponent
import GiftItemComponent
import AccountContext

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let gifts: [ProfileGiftsContext.State.StarGift]
    let completion: (StarGiftReference) -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        gifts: [ProfileGiftsContext.State.StarGift],
        completion: @escaping (StarGiftReference) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.gifts = gifts
        self.completion = completion
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gifts != rhs.gifts {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var selectedGift: StarGiftReference?
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
        
        let title = Child(BalancedTextComponent.self)
        let text = Child(BalancedTextComponent.self)
        let gifts = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let button = Child(ButtonComponent.self)
                
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let theme = environment.theme
            let strings = environment.strings
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 32.0 + environment.safeInsets.left
            
            let titleFont = Font.semibold(17.0)
            let subtitleFont = Font.regular(12.0)
            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
        
            var contentSize = CGSize(width: context.availableSize.width, height: 10.0)
        
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
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: "Too Many Pinned Gifts", font: titleFont, textColor: textColor)),
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
            
            let text = text.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: "Select a gift to unpin below:", font: subtitleFont, textColor: secondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += 17.0
            
            let itemsSideInset = environment.safeInsets.left + 16.0
            let spacing: CGFloat = 10.0
            let itemsInRow = 3
            let width = (context.availableSize.width - itemsSideInset * 2.0 - spacing * CGFloat(itemsInRow - 1)) / CGFloat(itemsInRow)
            
            var updatedGifts: [_UpdatedChildComponent] = []
            var index = 0
            var nextOriginX = itemsSideInset
            for gift in component.gifts {
                guard case let .unique(uniqueGift) = gift.gift else {
                    continue
                }
                var ribbonColor: GiftItemComponent.Ribbon.Color = .blue
                for attribute in uniqueGift.attributes {
                    if case let .backdrop(_, innerColor, outerColor, _, _, _) = attribute {
                        ribbonColor = .custom(outerColor, innerColor)
                        break
                    }
                }
                
                updatedGifts.append(
                    gifts[index].update(
                        component: AnyComponent(
                            PlainButtonComponent(
                                content: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: theme,
                                        strings: strings,
                                        subject: .uniqueGift(gift: uniqueGift),
                                        ribbon: GiftItemComponent.Ribbon(text: "#\(uniqueGift.number)", font: .monospaced, color: ribbonColor),
                                        isSelected: state.selectedGift == gift.reference,
                                        mode: .grid
                                    )
                                ),
                                effectAlignment: .center,
                                action: { [weak state] in
                                    guard let state else {
                                        return
                                    }
                                    state.selectedGift = gift.reference
                                    state.updated(transition: .spring(duration: 0.3))
                                },
                                animateAlpha: false
                            )
                        ),
                        availableSize: CGSize(width: width, height: width),
                        transition: context.transition
                    )
                )
                context.add(updatedGifts[index]
                    .position(CGPoint(x: nextOriginX + updatedGifts[index].size.width / 2.0, y: contentSize.height + updatedGifts[index].size.height / 2.0))
                )
                
                nextOriginX += updatedGifts[index].size.width + spacing
                if nextOriginX > context.availableSize.width - itemsSideInset {
                    contentSize.height += updatedGifts[index].size.height + spacing
                    nextOriginX = itemsSideInset
                }
            
                index += 1
            }
            contentSize.height += 14.0
            
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable("unpin"),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Unpin", font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    ),
                    isEnabled: state.selectedGift != nil,
                    displaysProgress: false,
                    action: { [weak state] in
                        guard let state else {
                            return
                        }
                        if let selectedGift = state.selectedGift {
                            component.completion(selectedGift)
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
    let gifts: [ProfileGiftsContext.State.StarGift]
    let completion: (StarGiftReference) -> Void
    
    init(
        context: AccountContext,
        gifts: [ProfileGiftsContext.State.StarGift],
        completion: @escaping (StarGiftReference) -> Void
    ) {
        self.context = context
        self.gifts = gifts
        self.completion = completion
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gifts != rhs.gifts {
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
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        gifts: context.component.gifts,
                        completion: context.component.completion,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
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


public class GiftUnpinScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let gifts: [ProfileGiftsContext.State.StarGift]
    private let completion: (StarGiftReference) -> Void
        
    public init(
        context: AccountContext,
        gifts: [ProfileGiftsContext.State.StarGift],
        completion: @escaping (StarGiftReference) -> Void
    ) {
        self.context = context
        self.gifts = gifts
        self.completion = completion

        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                gifts: gifts,
                completion: completion
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
