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
import ListSectionComponent
import ListActionItemComponent
import TelegramCore
import EmojiStatusComponent

final class PasskeysScreenListComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let insets: UIEdgeInsets
    let passkeys: [TelegramPasskey]
    let addPasskeyAction: () -> Void
    let deletePasskeyAction: (String) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        insets: UIEdgeInsets,
        passkeys: [TelegramPasskey],
        addPasskeyAction: @escaping () -> Void,
        deletePasskeyAction: @escaping (String) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.insets = insets
        self.passkeys = passkeys
        self.addPasskeyAction = addPasskeyAction
        self.deletePasskeyAction = deletePasskeyAction
    }
    
    static func ==(lhs: PasskeysScreenListComponent, rhs: PasskeysScreenListComponent) -> Bool {
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
        if lhs.passkeys != rhs.passkeys {
            return false
        }
        return true
    }
    
    private final class ScrollViewImpl: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollViewImpl
        private let contentContainer: UIView

        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let listSection = ComponentView<Empty>()

        private var component: PasskeysScreenListComponent?
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
        
        func update(component: PasskeysScreenListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            var maxPasskeys = 5
            if let data = component.context.currentAppConfiguration.with({ $0 }).data, let maxValue = data["passkeys_account_passkeys_max"] as? Double {
                maxPasskeys = Int(maxValue)
            }
            
            self.backgroundColor = component.theme.list.blocksBackgroundColor

            let sideInset: CGFloat = 16.0 + component.insets.left

            var contentHeight: CGFloat = 0.0
            contentHeight += component.insets.top
            contentHeight += 8.0

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
                    text: .plain(NSAttributedString(string: component.strings.Passkeys_Title, font: Font.bold(27.0), textColor: component.theme.list.itemPrimaryTextColor)),
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
            contentHeight += 32.0
            
            var listSectionItems: [AnyComponentWithIdentity<Empty>] = []
            for passkey in component.passkeys {
                if listSectionItems.contains(where: { $0.id == AnyHashable(passkey.id) }) {
                    continue
                }
                let passkeyId = passkey.id
                let dateFormatter = DateFormatter()
                dateFormatter.timeStyle = .none
                dateFormatter.dateStyle = .medium
                let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: Double(passkey.date)))
                
                let iconComponent: AnyComponentWithIdentity<Empty>
                if let emojiId = passkey.emojiId {
                    iconComponent = AnyComponentWithIdentity(
                        id: "lottie",
                        component: AnyComponent(TransformContents<Empty>(
                            content: AnyComponent(EmojiStatusComponent(
                                context: component.context,
                                animationCache: component.context.animationCache,
                                animationRenderer: component.context.animationRenderer,
                                content: .animation(
                                    content: .customEmoji(fileId: emojiId),
                                    size: CGSize(width: 40.0, height: 40.0),
                                    placeholderColor: component.theme.list.mediaPlaceholderColor,
                                    themeColor: nil,
                                    loopMode: .count(1)
                                ),
                                size: CGSize(width: 40.0, height: 40.0),
                                isVisibleForAnimations: true,
                                action: nil
                            )),
                            translation: CGPoint(x: 0.0, y: 1.0)
                        ))
                    )
                } else {
                    iconComponent = AnyComponentWithIdentity(
                        id: "icon",
                        component: AnyComponent(BundleIconComponent(name: "Settings/Menu/Passkeys", tintColor: nil))
                    )
                }
                
                let subtitleString: String
                if let lastUsageDate = passkey.lastUsageDate {
                    let lastUsedDateString = dateFormatter.string(from: Date(timeIntervalSince1970: Double(lastUsageDate)))
                    subtitleString = component.strings.Passkeys_PasskeyCreatedAndUsedPattern(dateString, lastUsedDateString).string
                } else {
                    subtitleString = component.strings.Passkeys_PasskeyCreatedPattern(dateString).string
                }
                
                listSectionItems.append(AnyComponentWithIdentity(id: passkey.id, component: AnyComponent(ListActionItemComponent(
                    theme: component.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: passkey.name.isEmpty ? component.strings.Passkeys_EmptyName : passkey.name,
                                font: Font.regular(17.0),
                                textColor: component.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: subtitleString,
                                font: Font.regular(14.0),
                                textColor: component.theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    ], alignment: .left, spacing: 2.0)),
                    leftIcon: .custom(
                        iconComponent,
                        false
                    ),
                    accessory: nil,
                    contextOptions: [ListActionItemComponent.ContextOption(
                        id: "delete",
                        title: component.strings.Common_Delete,
                        color: component.theme.list.itemDisclosureActions.destructive.fillColor,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.deletePasskeyAction(passkeyId)
                        }
                    )],
                    action: nil,
                    highlighting: .default
                ))))
            }
            
            if component.passkeys.count < maxPasskeys {
                listSectionItems.append(AnyComponentWithIdentity(id: "_add", component: AnyComponent(ListActionItemComponent(
                    theme: component.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: component.strings.Passkeys_AddPasskey,
                                font: Font.regular(17.0),
                                textColor: component.theme.list.itemAccentColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    ], alignment: .left, spacing: 2.0)),
                    leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(
                        name: "Chat List/AddIcon",
                        tintColor: component.theme.list.itemAccentColor
                    ))), false),
                    accessory: nil,
                    action: { [weak self] _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.addPasskeyAction()
                    },
                    highlighting: .default
                ))))
            }
            
            let listSectionSize = self.listSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: component.theme,
                    style: .glass,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.strings.Passkeys_ListFooter,
                            font: Font.regular(13.0),
                            textColor: component.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: listSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let listSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: listSectionSize)
            if let listSectionView = self.listSection.view as? ListSectionComponent.View {
                if listSectionView.superview == nil {
                    self.contentContainer.addSubview(listSectionView)
                    self.listSection.parentState = state
                }
                transition.setFrame(view: listSectionView, frame: listSectionFrame)
            }
            contentHeight += listSectionSize.height
            contentHeight += 8.0
            contentHeight += component.insets.bottom

            let contentContainerFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: contentHeight))
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
