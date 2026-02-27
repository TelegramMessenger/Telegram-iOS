import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AccountContext
import LottieComponent
import MultilineTextComponent
import BalancedTextComponent
import ButtonComponent
import BundleIconComponent

final class PasskeysScreenIntroComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let insets: UIEdgeInsets
    let displaySkip: Bool
    let createPasskeyAction: () -> Void
    let skipAction: () -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        insets: UIEdgeInsets,
        displaySkip: Bool,
        createPasskeyAction: @escaping () -> Void,
        skipAction: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.insets = insets
        self.displaySkip = displaySkip
        self.createPasskeyAction = createPasskeyAction
        self.skipAction = skipAction
    }
    
    static func ==(lhs: PasskeysScreenIntroComponent, rhs: PasskeysScreenIntroComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.displaySkip != rhs.displaySkip {
            return false
        }
        return true
    }
    
    private final class ScrollViewImpl: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }

    private final class Item {
        let icon = ComponentView<Empty>()
        let title = ComponentView<Empty>()
        let text = ComponentView<Empty>()
        
        init() {
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollViewImpl
        private let contentContainer: UIView

        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        private var skipButton: ComponentView<Empty>?

        private var items: [Item] = []

        private var component: PasskeysScreenIntroComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollViewImpl()
            self.contentContainer = UIView()
            self.scrollView.addSubview(self.contentContainer)

            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: PasskeysScreenIntroComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            self.backgroundColor = component.theme.list.plainBackgroundColor

            let sideInset: CGFloat = 16.0
            let sideIconInset: CGFloat = 40.0
            let itemsSideInset: CGFloat = sideInset + 20.0

            var contentHeight: CGFloat = 0.0

            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "passkey_logo"),
                    loop: false
                )),
                environment: {},
                containerSize: CGSize(width: 124.0, height: 124.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: contentHeight), size: iconSize)
            if let iconView = self.icon.view as? LottieComponent.View {
                if iconView.superview == nil {
                    self.contentContainer.addSubview(iconView)
                    iconView.playOnce()
                }
                transition.setPosition(view: iconView, position: iconFrame.center)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }
            contentHeight += iconSize.height
            contentHeight += 10.0

            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.Passkeys_Into_Title, font: Font.bold(27.0), textColor: component.theme.list.itemPrimaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.contentContainer.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            contentHeight += titleSize.height
            contentHeight += 10.0
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.Passkeys_Subtitle, font: Font.regular(16.0), textColor: component.theme.list.itemPrimaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.contentContainer.addSubview(subtitleView)
                }
                transition.setPosition(view: subtitleView, position: subtitleFrame.center)
                subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
            }
            contentHeight += subtitleSize.height
            contentHeight += 47.0

            struct ItemDesc {
                var icon: String
                var title: String
                var text: String
            }
            let itemDescs: [ItemDesc] = [
                ItemDesc(
                    icon: "Settings/Passkeys/Intro1",
                    title: component.strings.Passkeys_Into_Title0,
                    text: component.strings.Passkeys_Into_Text0
                ),
                ItemDesc(
                    icon: "Settings/Passkeys/Intro2",
                    title: component.strings.Passkeys_Into_Title1,
                    text: component.strings.Passkeys_Into_Text1
                ),
                ItemDesc(
                    icon: "Settings/Passkeys/Intro3",
                    title: component.strings.Passkeys_Into_Title2,
                    text: component.strings.Passkeys_Into_Text2
                )
            ]
            for i in 0 ..< itemDescs.count {
                if i != 0 {
                    contentHeight += 24.0
                }
                
                let item: Item
                if self.items.count > i {
                    item = self.items[i]
                } else {
                    item = Item()
                    self.items.append(item)
                }
                
                let itemDesc = itemDescs[i]
                
                let iconSize = item.icon.update(
                    transition: .immediate,
                    component: AnyComponent(BundleIconComponent(
                        name: itemDesc.icon,
                        tintColor: component.theme.list.itemAccentColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let titleSize = item.title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: itemDesc.title, font: Font.semibold(15.0), textColor: component.theme.list.itemPrimaryTextColor)),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - itemsSideInset * 2.0 - sideIconInset, height: 1000.0)
                )
                let textSize = item.text.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: itemDesc.text, font: Font.regular(15.0), textColor: component.theme.list.itemSecondaryTextColor)),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.18
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - itemsSideInset * 2.0 - sideIconInset, height: 1000.0)
                )
                
                if let iconView = item.icon.view {
                    if iconView.superview == nil {
                        self.contentContainer.addSubview(iconView)
                    }
                    transition.setFrame(view: iconView, frame: CGRect(origin: CGPoint(x: itemsSideInset, y: contentHeight + 4.0), size: iconSize))
                }
                
                if let titleView = item.title.view {
                    if titleView.superview == nil {
                        self.contentContainer.addSubview(titleView)
                    }
                    transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: itemsSideInset + sideIconInset, y: contentHeight), size: titleSize))
                }
                contentHeight += titleSize.height
                contentHeight += 2.0
                
                if let textView = item.text.view {
                    if textView.superview == nil {
                        self.contentContainer.addSubview(textView)
                    }
                    transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: itemsSideInset + sideIconInset, y: contentHeight), size: textSize))
                }
                contentHeight += textSize.height
            }

            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: component.insets.bottom, innerDiameter: 52.0, sideInset: 32.0)
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 52.0 * 0.5
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.strings.Passkeys_ButtonCreate, font: Font.semibold(17.0), textColor: component.theme.list.itemCheckColors.foregroundColor))))
                    ),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.createPasskeyAction()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0)
            )
            
            var skipButtonSize: CGSize?
            if component.displaySkip {
                let skipButton: ComponentView<Empty>
                if let current = self.skipButton {
                    skipButton = current
                } else {
                    skipButton = ComponentView()
                    self.skipButton = skipButton
                }
                skipButtonSize = skipButton.update(
                    transition: transition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: component.theme.chatList.unreadBadgeInactiveBackgroundColor,
                            foreground: component.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: component.theme.chatList.unreadBadgeInactiveBackgroundColor.withMultipliedAlpha(0.9),
                            cornerRadius: 52.0 * 0.5
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.strings.Passkeys_ButtonSkip, font: Font.semibold(17.0), textColor: component.theme.list.itemCheckColors.foregroundColor))))
                        ),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.skipAction()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0)
                )
            } else if let skipButton = self.skipButton {
                self.skipButton = nil
                skipButton.view?.removeFromSuperview()
            }

            var buttonFrame = CGRect(origin: CGPoint(x: buttonInsets.left, y: availableSize.height - buttonInsets.bottom - actionButtonSize.height), size: actionButtonSize)
            if let skipButtonSize, let skipButtonView = self.skipButton?.view {
                let skipButtonFrame = buttonFrame
                buttonFrame = buttonFrame.offsetBy(dx: 0.0, dy: -8.0 - skipButtonSize.height)
                
                if skipButtonView.superview == nil {
                    self.addSubview(skipButtonView)
                }
                transition.setFrame(view: skipButtonView, frame: skipButtonFrame)
            }

            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: buttonFrame)
            }

            let contentTopInset = component.insets.top
            let contentBottomInset = availableSize.height - buttonFrame.minY

            let contentContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: max(contentTopInset, floor((availableSize.height - contentTopInset - contentBottomInset - contentHeight) * 0.5))), size: CGSize(width: availableSize.width, height: contentHeight))
            transition.setFrame(view: self.contentContainer, frame: contentContainerFrame)

            self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            let scrollContentSize = CGSize(width: availableSize.width, height: contentContainerFrame.maxY)
            if self.scrollView.contentSize != scrollContentSize {
                self.scrollView.contentSize = scrollContentSize
            }
            let scrollInsets = UIEdgeInsets(top: component.insets.top, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
