import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import ListSectionComponent
import BundleIconComponent
import LottieComponent
import ListSwitchItemComponent
import ListSwitchItemComponent
import ListActionItemComponent
import Markdown
import TelegramStringFormatting
import MessagePriceItem
import ListItemComponentAdaptor

final class PostSuggestionsSettingsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let usdWithdrawRate: Int64
    let peer: EnginePeer?
    let initialPrice: StarsAmount?
    let completion: () -> Void

    init(
        context: AccountContext,
        usdWithdrawRate: Int64,
        peer: EnginePeer?,
        initialPrice: StarsAmount?,
        completion: @escaping () -> Void
    ) {
        self.context = context
        self.usdWithdrawRate = usdWithdrawRate
        self.peer = peer
        self.initialPrice = initialPrice
        self.completion = completion
    }

    static func ==(lhs: PostSuggestionsSettingsScreenComponent, rhs: PostSuggestionsSettingsScreenComponent) -> Bool {
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        
        private let navigationTitle = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let switchSection = ComponentView<Empty>()
        private let contentSection = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: PostSuggestionsSettingsScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var areSuggestionsEnabled: Bool = false
        private var starCount: Int = 0
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.scrollView.layer.addSublayer(self.topOverscrollLayer)
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
            guard let component = self.component else {
                return true
            }
            guard let peer = component.peer else {
                return true
            }

            let currentAmount: StarsAmount?
            if self.areSuggestionsEnabled {
                currentAmount = StarsAmount(value: Int64(self.starCount), nanos: 0)
            } else {
                currentAmount = nil
            }
            
            if component.initialPrice != currentAmount {
                let _ = component.context.engine.peers.updateChannelPaidMessagesStars(peerId: peer.id, stars: currentAmount, broadcastMessagesAllowed: currentAmount != nil).startStandalone()
            }
            
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        var scrolledUp = true
        private func updateScrolling(transition: ComponentTransition) {
            let navigationRevealOffsetY: CGFloat = 0.0
            
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, (self.scrollView.contentOffset.y - navigationRevealOffsetY) / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
            
            var scrolledUp = false
            if navigationAlpha < 0.5 {
                scrolledUp = true
            } else if navigationAlpha > 0.5 {
                scrolledUp = false
            }
            
            if self.scrolledUp != scrolledUp {
                self.scrolledUp = scrolledUp
                if !self.isUpdating {
                    self.state?.updated()
                }
            }
            
            if let navigationTitleView = self.navigationTitle.view {
                transition.setAlpha(view: navigationTitleView, alpha: 1.0)
            }
        }
        
        func update(component: PostSuggestionsSettingsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                if let initialPrice = component.initialPrice {
                    self.starCount = Int(initialPrice.value)
                    self.areSuggestionsEnabled = true
                } else {
                    self.starCount = 20
                    self.areSuggestionsEnabled = false
                }
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let alphaTransition: ComponentTransition
            if !transition.animation.isImmediate {
                alphaTransition = .easeInOut(duration: 0.25)
            } else {
                alphaTransition = .immediate
            }
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.ChannelMessages_Title, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let navigationTitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - navigationTitleSize.width) / 2.0), y: environment.statusBarHeight + floor((environment.navigationHeight - environment.statusBarHeight - navigationTitleSize.height) / 2.0)), size: navigationTitleSize)
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                        navigationBar.view.addSubview(navigationTitleView)
                    }
                }
                transition.setFrame(view: navigationTitleView, frame: navigationTitleFrame)
            }
            
            let bottomContentInset: CGFloat = 24.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 24.0
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += environment.navigationHeight
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "ChannelMessages"),
                    loop: false
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: contentHeight + 11.0), size: iconSize)
            if let iconView = self.icon.view as? LottieComponent.View {
                if iconView.superview == nil {
                    self.scrollView.addSubview(iconView)
                    iconView.playOnce()
                }
                transition.setPosition(view: iconView, position: iconFrame.center)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }
            
            contentHeight += 129.0
            
            let subtitleString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.ChannelMessages_Info, attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                linkAttribute: { attributes in
                    return ("URL", "")
                }), textAlignment: .center
            ))
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(subtitleString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.25,
                    highlightColor: environment.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                            return NSAttributedString.Key(rawValue: "URL")
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] _, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        let _ = component
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.scrollView.addSubview(subtitleView)
                }
                transition.setPosition(view: subtitleView, position: subtitleFrame.center)
                subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
            }
            contentHeight += subtitleSize.height
            contentHeight += 27.0
            
            var switchSectionItems: [AnyComponentWithIdentity<Empty>] = []
            switchSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.ChannelMessages_SwitchTitle,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.areSuggestionsEnabled, isInteractive: false)),
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.areSuggestionsEnabled = !self.areSuggestionsEnabled
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
            ))))
            
            let switchSectionSize = self.switchSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: switchSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let switchSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: switchSectionSize)
            if let switchSectionView = self.switchSection.view {
                if switchSectionView.superview == nil {
                    self.scrollView.addSubview(switchSectionView)
                    self.switchSection.parentState = state
                }
                transition.setFrame(view: switchSectionView, frame: switchSectionFrame)
            }
            contentHeight += switchSectionSize.height
            contentHeight += sectionSpacing
            
            var contentSectionItems: [AnyComponentWithIdentity<Empty>] = []
            
            let usdRate = Double(component.usdWithdrawRate) / 1000.0 / 100.0
            let price = self.starCount == 0 ? "" : "≈\(formatTonUsdValue(Int64(self.starCount), divide: false, rate: usdRate, dateTimeFormat: presentationData.dateTimeFormat))"
            
            contentSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                itemGenerator: MessagePriceItem(
                    theme: environment.theme,
                    strings: environment.strings,
                    isEnabled: true, minValue: 0, maxValue: 10000,
                    value: Int64(self.starCount),
                    price: price,
                    sectionId: 0,
                    updated: { [weak self] value, _ in
                        guard let self else {
                            return
                        }
                        
                        self.starCount = Int(value)
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    },
                    openSetCustom: { [weak self] in
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        
                        let currentAmount: StarsAmount = StarsAmount(value: Int64(self.starCount), nanos: 0)
                        let starsScreen = component.context.sharedContext.makeStarsWithdrawalScreen(context: component.context, subject: .enterAmount(current: currentAmount, minValue: StarsAmount(value: 0, nanos: 0), fractionAfterCommission: 85, kind: .postSuggestion), completion: { [weak self] amount in
                            guard let self else {
                                return
                            }
                            
                            self.starCount = Int(amount)
                            if !self.isUpdating {
                                self.state?.updated(transition: .immediate)
                            }
                        })
                        environment.controller()?.push(starsScreen)
                    },
                    openPremiumInfo: nil
                ),
                params: ListViewItemLayoutParams(width: availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
            ))))
            
            let contentSectionSize = self.contentSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.ChannelMessages_PriceSectionTitle,
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.ChannelMessages_PriceSectionFooter,
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: contentSectionItems,
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let contentSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: contentSectionSize)
            if let contentSectionView = self.contentSection.view {
                if contentSectionView.superview == nil {
                    self.scrollView.addSubview(contentSectionView)
                }
                transition.setFrame(view: contentSectionView, frame: contentSectionFrame)
                alphaTransition.setAlpha(view: contentSectionView, alpha: self.areSuggestionsEnabled ? 1.0 : 0.0)
            }
            
            if self.areSuggestionsEnabled {
                contentHeight += contentSectionSize.height
            }
            
            contentHeight += bottomContentInset
            contentHeight += environment.safeInsets.bottom
            
            let previousBounds = self.scrollView.bounds
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.scrollIndicatorInsets != scrollInsets {
                self.scrollView.scrollIndicatorInsets = scrollInsets
            }
                        
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            
            self.topOverscrollLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -3000.0), size: CGSize(width: availableSize.width, height: 3000.0))
            
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

@available(iOS 13.0, *)
public final class PostSuggestionsSettingsScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    @MainActor
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        completion: @escaping () -> Void
    ) async {
        self.context = context
        
        let configuration = StarsSubscriptionConfiguration.with(appConfiguration: context.currentAppConfiguration.with({ $0 }))
        
        let peer = await context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
        ).get()
        
        let initialPrice: StarsAmount?
        if case let .channel(channel) = peer, case let .broadcast(info) = channel.info, info.flags.contains(.hasMonoforum), let linkedMonoforumId = channel.linkedMonoforumId {
            initialPrice = await context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.SendMessageToChannelPrice(id: linkedMonoforumId)
            ).get() ?? StarsAmount(value: 0, nanos: 0)
        } else {
            initialPrice = await context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.SendMessageToChannelPrice(id: peerId)
            ).get()
        }
        
        super.init(context: context, component: PostSuggestionsSettingsScreenComponent(
            context: context,
            usdWithdrawRate: configuration.usdWithdrawRate,
            peer: peer,
            initialPrice: initialPrice,
            completion: completion
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? PostSuggestionsSettingsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? PostSuggestionsSettingsScreenComponent.View else {
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
}
