import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import ViewControllerComponent
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import MultilineTextComponent
import ButtonComponent
import UndoUI
import BundleIconComponent
import ListSectionComponent
import ListItemSliderSelectorComponent
import ListActionItemComponent
import Markdown
import BlurredBackgroundComponent

final class AffiliateProgramSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialContent: AffiliateProgramSetupScreen.Content

    init(
        context: AccountContext,
        initialContent: AffiliateProgramSetupScreen.Content
    ) {
        self.context = context
        self.initialContent = initialContent
    }

    static func ==(lhs: AffiliateProgramSetupScreenComponent, rhs: AffiliateProgramSetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }

        return true
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: UIScrollView
        
        private let title = ComponentView<Empty>()
        private let titleTransformContainer: UIView
        private let subtitle = ComponentView<Empty>()
        
        private let introBackground = ComponentView<Empty>()
        private var introIconItems: [Int: ComponentView<Empty>] = [:]
        private var introTitleItems: [Int: ComponentView<Empty>] = [:]
        private var introTextItems: [Int: ComponentView<Empty>] = [:]
        
        private let commissionSection = ComponentView<Empty>()
        private let durationSection = ComponentView<Empty>()
        private let existingProgramsSection = ComponentView<Empty>()
        private let endProgramSection = ComponentView<Empty>()
        
        private let bottomPanelSeparator = SimpleLayer()
        private let bottomPanelBackground = ComponentView<Empty>()
        private let bottomPanelButton = ComponentView<Empty>()
        private let bottomPanelText = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: AffiliateProgramSetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            
            self.titleTransformContainer = UIView()
            self.scrollView.addSubview(self.titleTransformContainer)
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.layer.addSublayer(self.bottomPanelSeparator)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, self.scrollView.contentOffset.y / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
        }
        
        func update(component: AffiliateProgramSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
                self.bottomPanelSeparator.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            self.component = component
            self.state = state
            
            let topInset: CGFloat = environment.navigationHeight + 87.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 16.0
            let sectionSpacing: CGFloat = 24.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += topInset
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Affiliate Program", font: Font.bold(30.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - textSideInset * 2.0, height: 1000.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.titleTransformContainer.addSubview(titleView)
                }
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                transition.setPosition(view: self.titleTransformContainer, position: titleFrame.center)
            }
            contentHeight += titleSize.height
            contentHeight += 10.0
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Reward those who help grow your userbase.", font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - textSideInset * 2.0, height: 1000.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.scrollView.addSubview(subtitleView)
                    subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
                    transition.setPosition(view: subtitleView, position: subtitleFrame.center)
                }
            }
            contentHeight += subtitleSize.height
            contentHeight += 24.0
            
            let introItems: [(icon: String, title: String, text: String)] = [
                (
                    "Chat/Context Menu/Smile",
                    "Share revenue with affiliates",
                    "Set the commission for revenue generated by users referred to you."
                ),
                (
                    "Chat/Context Menu/Smile",
                    "Launch your affiliate program",
                    "Telegram will feature your program for millions of potential affiliates."
                ),
                (
                    "Chat/Context Menu/Smile",
                    "Let affiliates promote you",
                    "Affiliates will share your referral link with their audience."
                )
            ]
            var introItemsHeight: CGFloat = 17.0
            let introItemIconX: CGFloat = sideInset + 19.0
            let introItemTextX: CGFloat = sideInset + 56.0
            let introItemTextRightInset: CGFloat = sideInset + 10.0
            let introItemSpacing: CGFloat = 22.0
            for i in 0 ..< introItems.count {
                if i != 0 {
                    introItemsHeight += introItemSpacing
                }
                
                let item = introItems[i]
                
                let itemIcon: ComponentView<Empty>
                let itemTitle: ComponentView<Empty>
                let itemText: ComponentView<Empty>
                
                if let current = self.introIconItems[i] {
                    itemIcon = current
                } else {
                    itemIcon = ComponentView()
                    self.introIconItems[i] = itemIcon
                }
                
                if let current = self.introTitleItems[i] {
                    itemTitle = current
                } else {
                    itemTitle = ComponentView()
                    self.introTitleItems[i] = itemTitle
                }
                
                if let current = self.introTextItems[i] {
                    itemText = current
                } else {
                    itemText = ComponentView()
                    self.introTextItems[i] = itemText
                }
                
                let iconSize = itemIcon.update(
                    transition: .immediate,
                    component: AnyComponent(BundleIconComponent(
                        name: item.icon,
                        tintColor: environment.theme.list.itemAccentColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let titleSize = itemTitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: item.title, font: Font.semibold(15.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - introItemTextRightInset - introItemTextX, height: 1000.0)
                )
                let textSize = itemText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: item.text, font: Font.regular(15.0), textColor: environment.theme.list.itemSecondaryTextColor)),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - introItemTextRightInset - introItemTextX, height: 1000.0)
                )
                
                let itemIconFrame = CGRect(origin: CGPoint(x: introItemIconX, y: contentHeight + introItemsHeight + 8.0), size: iconSize)
                let itemTitleFrame = CGRect(origin: CGPoint(x: introItemTextX, y: contentHeight + introItemsHeight), size: titleSize)
                let itemTextFrame = CGRect(origin: CGPoint(x: introItemTextX, y: itemTitleFrame.maxY + 5.0), size: textSize)
                
                if let itemIconView = itemIcon.view {
                    if itemIconView.superview == nil {
                        self.scrollView.addSubview(itemIconView)
                    }
                    transition.setFrame(view: itemIconView, frame: itemIconFrame)
                }
                if let itemTitleView = itemTitle.view {
                    if itemTitleView.superview == nil {
                        itemTitleView.layer.anchorPoint = CGPoint()
                        self.scrollView.addSubview(itemTitleView)
                    }
                    transition.setPosition(view: itemTitleView, position: itemTitleFrame.origin)
                    itemTitleView.bounds = CGRect(origin: CGPoint(), size: itemTitleFrame.size)
                }
                if let itemTextView = itemText.view {
                    if itemTextView.superview == nil {
                        itemTextView.layer.anchorPoint = CGPoint()
                        self.scrollView.addSubview(itemTextView)
                    }
                    transition.setPosition(view: itemTextView, position: itemTextFrame.origin)
                    itemTextView.bounds = CGRect(origin: CGPoint(), size: itemTextFrame.size)
                }
                introItemsHeight = itemTextFrame.maxY - contentHeight
            }
            introItemsHeight += 19.0
            
            let introBackgroundFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: introItemsHeight))
            let _ = self.introBackground.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: environment.theme.list.itemBlocksBackgroundColor,
                    cornerRadius: .value(5.0),
                    smoothCorners: true
                )),
                environment: {},
                containerSize: introBackgroundFrame.size
            )
            if let introBackgroundView = self.introBackground.view {
                if introBackgroundView.superview == nil, let firstIconItemView = self.introIconItems[0]?.view {
                    self.scrollView.insertSubview(introBackgroundView, belowSubview: firstIconItemView)
                }
                transition.setFrame(view: introBackgroundView, frame: introBackgroundFrame)
            }
            contentHeight += introItemsHeight
            contentHeight += sectionSpacing + 6.0
            
            let commissionSectionSize = self.commissionSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "COMMISSION",
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Define the percentage of star revenue your affiliates earn for referring users to your bot.",
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemSliderSelectorComponent(
                            theme: environment.theme,
                            content: .continuous(ListItemSliderSelectorComponent.Continuous(
                                value: 0.0,
                                lowerBoundTitle: "1%",
                                upperBoundTitle: "90%",
                                title: "1%",
                                valueUpdated: { [weak self] value in
                                    guard let self else {
                                        return
                                    }
                                    let _ = self
                                }
                            ))
                        )))
                    ],
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let commissionSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: commissionSectionSize)
            if let commissionSectionView = self.commissionSection.view {
                if commissionSectionView.superview == nil {
                    self.scrollView.addSubview(commissionSectionView)
                }
                transition.setFrame(view: commissionSectionView, frame: commissionSectionFrame)
            }
            contentHeight += commissionSectionSize.height
            contentHeight += sectionSpacing + 12.0
            
            let durationItems: [(months: Int32, title: String, selectedTitle: String)] = [
                (1, "1m", "1 MONTH"),
                (3, "3m", "3 MONTHS"),
                (6, "6m", "6 MONTHS"),
                (12, "1y", "1 YEAR"),
                (2 * 12, "2y", "2 YEARS"),
                (3 * 12, "3y", "3 YEARS"),
                (Int32.max, "∞", "INDEFINITELY")
            ]
            let durationSectionSize = self.durationSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(HStack([
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "DURATION",
                                font: Font.regular(13.0),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        ))),
                        AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: durationItems[0].selectedTitle,
                                font: Font.regular(13.0),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )))
                    ], spacing: 4.0, alignment: .alternatingLeftRight)),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Set the duration for which affiliates will earn commissions from referred users.",
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemSliderSelectorComponent(
                            theme: environment.theme,
                            content: .discrete(ListItemSliderSelectorComponent.Discrete(
                                values: durationItems.map(\.title),
                                markPositions: true,
                                selectedIndex: 0,
                                title: nil,
                                selectedIndexUpdated: { [weak self] value in
                                    guard let self else {
                                        return
                                    }
                                    let _ = self
                                }
                            ))
                        )))
                    ],
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let durationSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: durationSectionSize)
            if let durationSectionView = self.durationSection.view {
                if durationSectionView.superview == nil {
                    self.scrollView.addSubview(durationSectionView)
                }
                transition.setFrame(view: durationSectionView, frame: durationSectionFrame)
            }
            contentHeight += durationSectionSize.height
            contentHeight += sectionSpacing + 12.0
            
            let existingProgramsSectionSize = self.existingProgramsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Explore what other mini apps offer.",
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: "View Existing Programs",
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .left, spacing: 2.0)),
                            accessory: .arrow,
                            action: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                
                                let _ = self
                            }
                        )))
                    ],
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let existingProgramsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: existingProgramsSectionSize)
            if let existingProgramsSectionView = self.existingProgramsSection.view {
                if existingProgramsSectionView.superview == nil {
                    self.scrollView.addSubview(existingProgramsSectionView)
                }
                transition.setFrame(view: existingProgramsSectionView, frame: existingProgramsSectionFrame)
            }
            contentHeight += existingProgramsSectionSize.height
            contentHeight += sectionSpacing + 12.0
            
            let endProgramSectionSize = self.endProgramSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: "End Affiliate Program",
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemDestructiveColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .center, spacing: 2.0)),
                            accessory: nil,
                            action: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                
                                let _ = self
                            }
                        )))
                    ],
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let endProgramSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: endProgramSectionSize)
            if let endProgramSectionView = self.endProgramSection.view {
                if endProgramSectionView.superview == nil {
                    self.scrollView.addSubview(endProgramSectionView)
                }
                transition.setFrame(view: endProgramSectionView, frame: endProgramSectionFrame)
            }
            contentHeight += endProgramSectionSize.height
            contentHeight += sectionSpacing
            
            contentHeight += bottomInset
            
            let bottomPanelTextSize = self.bottomPanelText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: "By creating an affiliate program, you afree to the [terms and conditions](https://telegram.org/terms) of Affiliate Programs.",
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.itemSecondaryTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                            linkAttribute: { url in
                                return ("URL", url)
                            }
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            
            let bottomPanelButtonInsets = UIEdgeInsets(top: 10.0, left: sideInset, bottom: 10.0, right: sideInset)
            
            let bottomPanelButtonSize = self.bottomPanelButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(Text(text: "Start Affiliate Program", font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor))),
                    isEnabled: true,
                    allowActionWhenDisabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        let _ = self
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - bottomPanelButtonInsets.left - bottomPanelButtonInsets.right, height: 50.0)
            )
            
            let bottomPanelHeight: CGFloat = bottomPanelButtonInsets.top + bottomPanelButtonSize.height + bottomPanelButtonInsets.bottom + bottomPanelTextSize.height + 8.0 + environment.safeInsets.bottom
            let bottomPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight), size: CGSize(width: availableSize.width, height: bottomPanelHeight))
            
            let _ = self.bottomPanelBackground.update(
                transition: transition,
                component: AnyComponent(BlurredBackgroundComponent(
                    color: environment.theme.rootController.navigationBar.blurredBackgroundColor
                )),
                environment: {},
                containerSize: bottomPanelFrame.size
            )
            
            if let bottomPanelBackgroundView = self.bottomPanelBackground.view {
                if bottomPanelBackgroundView.superview == nil {
                    self.addSubview(bottomPanelBackgroundView)
                }
                transition.setFrame(view: bottomPanelBackgroundView, frame: bottomPanelFrame)
            }
            transition.setFrame(layer: self.bottomPanelSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: bottomPanelFrame.minY - UIScreenPixel), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            let bottomPanelButtonFrame = CGRect(origin: CGPoint(x: bottomPanelFrame.minX + bottomPanelButtonInsets.left, y: bottomPanelFrame.minY + bottomPanelButtonInsets.top), size: bottomPanelButtonSize)
            if let bottomPanelButtonView = self.bottomPanelButton.view {
                if bottomPanelButtonView.superview == nil {
                    self.addSubview(bottomPanelButtonView)
                }
                transition.setFrame(view: bottomPanelButtonView, frame: bottomPanelButtonFrame)
            }
            
            let bottomPanelTextFrame = CGRect(origin: CGPoint(x: bottomPanelFrame.minX + floor((bottomPanelFrame.width - bottomPanelTextSize.width) * 0.5), y: bottomPanelButtonFrame.maxY + bottomPanelButtonInsets.bottom), size: bottomPanelTextSize)
            if let bottomPanelTextView = self.bottomPanelText.view {
                if bottomPanelTextView.superview == nil {
                    self.addSubview(bottomPanelTextView)
                }
                transition.setPosition(view: bottomPanelTextView, position: bottomPanelTextFrame.center)
                bottomPanelTextView.bounds = CGRect(origin: CGPoint(), size: bottomPanelTextFrame.size)
            }
            
            contentHeight += bottomPanelFrame.height
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
            if self.scrollView.scrollIndicatorInsets != scrollInsets {
                self.scrollView.scrollIndicatorInsets = scrollInsets
            }
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class AffiliateProgramSetupScreen: ViewControllerComponentContainer {
    public final class Content: AffiliateProgramSetupScreenInitialData {
        let peerId: EnginePeer.Id

        init(
            peerId: EnginePeer.Id
        ) {
            self.peerId = peerId
        }
    }
    
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        initialContent: Content
    ) {
        self.context = context
        
        super.init(context: context, component: AffiliateProgramSetupScreenComponent(
            context: context,
            initialContent: initialContent
        ), navigationBarAppearance: .default, theme: .default)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? AffiliateProgramSetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? AffiliateProgramSetupScreenComponent.View else {
                return true
            }
            
            return componentView.attemptNavigation(complete: complete)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    public static func content(context: AccountContext, peerId: EnginePeer.Id) -> Signal<AffiliateProgramSetupScreenInitialData, NoError> {
        return .single(Content(
            peerId: peerId
        ))
    }
}
