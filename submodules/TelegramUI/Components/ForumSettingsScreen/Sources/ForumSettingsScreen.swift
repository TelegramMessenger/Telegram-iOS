import Foundation
import UIKit
import Photos
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
import ListActionItemComponent
import BundleIconComponent
import LottieComponent
import PlainButtonComponent
import TelegramStringFormatting
import Markdown

final class ForumSettingsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id

    init(
        context: AccountContext,
        peerId: EnginePeer.Id
    ) {
        self.context = context
        self.peerId = peerId
    }

    static func ==(lhs: ForumSettingsScreenComponent, rhs: ForumSettingsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
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
        private let generalSection = ComponentView<Empty>()
        private let modeSection = ComponentView<Empty>()
        
        private var ignoreScrolling: Bool = false
        private var isUpdating: Bool = false
        
        private var component: ForumSettingsScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var peer: EnginePeer?
        private var peerDisposable: Disposable?
        private var peerIdPromise = ValuePromise<EnginePeer.Id>()
        
        private var isOn = false
        private var mode: ForumModeComponent.Mode = .tabs
                
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
            self.peerDisposable?.dispose()
        }
        
        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
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
        
        func toggleTopicsEnabled(_ enabled: Bool) {
            guard let component = self.component, let peer = self.peer else {
                return
            }
            self.isOn = enabled
            let displayForumAsTabs = self.mode == .tabs
            
            if self.isOn {
                if case .legacyGroup = peer {
                    let context = component.context
                    let signal: Signal<EnginePeer.Id?, NoError> = context.engine.peers.convertGroupToSupergroup(peerId: peer.id, additionalProcessing: { upgradedPeerId -> Signal<Never, NoError> in
                        return context.engine.peers.setChannelForumMode(id: upgradedPeerId, isForum: true, displayForumAsTabs: displayForumAsTabs)
                    })
                    |> map(Optional.init)
                    |> `catch` { [weak self] error -> Signal<PeerId?, NoError> in
                        guard let self, let controller = self.environment?.controller() else {
                            return .single(nil)
                        }
                        switch error {
                        case .tooManyChannels:
                            Queue.mainQueue().async {
                                let oldChannelsController = context.sharedContext.makeOldChannelsController(context: context, updatedPresentationData: nil, intent: .upgrade, completed: { result in
                                    
                                })
                                controller.push(oldChannelsController)
                            }
                        default:
                            break
                        }
                        return .single(nil)
                    }
                    |> mapToSignal { upgradedPeerId -> Signal<PeerId?, NoError> in
                        guard let upgradedPeerId = upgradedPeerId else {
                            return .single(nil)
                        }
                        return .single(upgradedPeerId)
                    }
                    |> deliverOnMainQueue
                    
                    let _ = signal.startStandalone(next: { [weak self] resultPeerId in
                        guard let self else {
                            return
                        }
                        if let resultPeerId {
                            self.peerIdPromise.set(resultPeerId)
                        } else {
                            self.isOn = false
                            self.state?.updated(transition: .easeInOut(duration: 0.2))
                        }
                    })
                } else {
                    let _ = component.context.engine.peers.setChannelForumMode(id: peer.id, isForum: true, displayForumAsTabs: displayForumAsTabs).startStandalone()
                }
            } else {
                let _ = component.context.engine.peers.setChannelForumMode(id: peer.id, isForum: false, displayForumAsTabs: displayForumAsTabs).startStandalone()
            }
            self.state?.updated(transition: .spring(duration: 0.4))
        }
                
        func update(component: ForumSettingsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.peerIdPromise.set(component.peerId)
                
                self.peerDisposable = (self.peerIdPromise.get()
                |> mapToSignal { peerId in
                    component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                }
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self else {
                        return
                    }
                    self.peer = peer
                    if case let .channel(channel) = peer {
                        self.isOn = channel.flags.contains(.isForum)
                        if self.isOn {
                            self.mode = channel.flags.contains(.displayForumAsTabs) ? .tabs : .list
                        }
                    }
                    self.state?.updated()
                })
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? transition : transition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.PeerInfo_Topics_Title, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
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
            let sectionSpacing: CGFloat = 32.0
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += environment.navigationHeight
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "Topics"),
                    loop: false
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: contentHeight + 8.0), size: iconSize)
            if let iconView = self.icon.view as? LottieComponent.View {
                if iconView.superview == nil {
                    self.scrollView.addSubview(iconView)
                    iconView.playOnce()
                }
                transition.setPosition(view: iconView, position: iconFrame.center)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }
            
            contentHeight += 124.0
            
            let subtitleString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.PeerInfo_Topics_EnableTopicsInfo, attributes: MarkdownAttributes(
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
                        
            var generalSectionItems: [AnyComponentWithIdentity<Empty>] = []
            generalSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.PeerInfo_Topics_EnableTopics,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.isOn, action: { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.toggleTopicsEnabled(value)
                })),
                action: nil
            ))))
            
            let generalSectionSize = self.generalSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: generalSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let generalSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: generalSectionSize)
            if let generalSectionView = self.generalSection.view {
                if generalSectionView.superview == nil {
                    self.scrollView.addSubview(generalSectionView)
                }
                transition.setFrame(view: generalSectionView, frame: generalSectionFrame)
            }
            contentHeight += generalSectionSize.height
            contentHeight += sectionSpacing
            
            var otherSectionsHeight: CGFloat = 0.0
            
            let modeSectionSize = self.modeSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.PeerInfo_Topics_DisplayAs,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: environment.strings.PeerInfo_Topics_DisplayAsInfo,
                            attributes: MarkdownAttributes(
                                body: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: environment.theme.list.freeTextColor),
                                bold: MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: environment.theme.list.freeTextColor),
                                link: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: environment.theme.list.itemAccentColor),
                                linkAttribute: { _ in
                                    return nil
                                }
                            )
                        ),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(
                            id: 0,
                            component: AnyComponent(
                                ForumModeComponent(
                                    theme: environment.theme,
                                    strings: environment.strings,
                                    mode: self.isOn ? self.mode : nil,
                                    modeUpdated: { [weak self] mode in
                                        guard let self else {
                                            return
                                        }
                                        self.mode = mode
                                        let displayForumAsTabs = self.mode == .tabs
                                        let _ = component.context.engine.peers.setChannelForumMode(id: component.peerId, isForum: true, displayForumAsTabs: displayForumAsTabs).startStandalone()
                                        self.state?.updated(transition: .spring(duration: 0.4))
                                    }
                                )
                            )
                        )
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let modeSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + otherSectionsHeight), size: modeSectionSize)
            if let modeSectionView = self.modeSection.view {
                if modeSectionView.superview == nil {
                    modeSectionView.layer.allowsGroupOpacity = true
                    self.scrollView.addSubview(modeSectionView)
                }
                transition.setFrame(view: modeSectionView, frame: modeSectionFrame)
                alphaTransition.setAlpha(view: modeSectionView, alpha: self.isOn ? 1.0 : 0.0)
            }
            otherSectionsHeight += modeSectionSize.height
            otherSectionsHeight += sectionSpacing
            
            if self.isOn {
                contentHeight += otherSectionsHeight
            }
            
            contentHeight += bottomContentInset
            contentHeight += environment.safeInsets.bottom
            
            let previousBounds = self.scrollView.bounds
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            self.ignoreScrolling = true
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
            self.ignoreScrolling = false
                        
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

public final class ForumSettingsScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    public init(context: AccountContext, peerId: EnginePeer.Id) {
        self.context = context
        
        super.init(context: context, component: ForumSettingsScreenComponent(
            context: context,
            peerId: peerId
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? ForumSettingsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
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
