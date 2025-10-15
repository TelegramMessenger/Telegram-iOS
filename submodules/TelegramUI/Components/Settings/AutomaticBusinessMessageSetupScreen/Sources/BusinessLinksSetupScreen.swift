import Foundation
import UIKit
import Display
import ComponentFlow
import ListSectionComponent
import TelegramPresentationData
import AppBundle
import AccountContext
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import LottieComponent
import Markdown
import SwiftSignalKit
import TelegramCore
import ListActionItemComponent
import BundleIconComponent
import TextFormat
import UndoUI
import ShareController
import ContextUI

final class BusinessLinksSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: BusinessLinksSetupScreen.InitialData

    init(
        context: AccountContext,
        initialData: BusinessLinksSetupScreen.InitialData
    ) {
        self.context = context
        self.initialData = initialData
    }

    static func ==(lhs: BusinessLinksSetupScreenComponent, rhs: BusinessLinksSetupScreenComponent) -> Bool {
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
        private let createLinkSection = ComponentView<Empty>()
        private let linksSection = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: BusinessLinksSetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var refreshLinksDisposable: Disposable?
        private var links: [TelegramBusinessChatLinks.Link] = []
        private var linksDisposable: Disposable?
        
        private var isCreatingLink: Bool = false
        private var createLinkDisposable: Disposable?
        
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
            self.refreshLinksDisposable?.dispose()
            self.linksDisposable?.dispose()
            self.createLinkDisposable?.dispose()
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
        
        private func createLink() {
            guard let component = self.component else {
                return
            }
            if self.isCreatingLink {
                return
            }
            self.isCreatingLink = true
            if !self.isUpdating {
                self.state?.updated(transition: .immediate)
            }
            
            self.createLinkDisposable?.dispose()
            self.createLinkDisposable = (component.context.engine.accountData.createBusinessChatLink(message: "", entities: [], title: nil)
            |> deliverOnMainQueue).startStrict(next: { [weak self] link in
                guard let self else {
                    return
                }
                
                self.isCreatingLink = false
                self.state?.updated(transition: .immediate)
                
                self.openLink(link: link, openKeyboard: true)
            }, error: { [weak self] error in
                guard let self, let component = self.component, let environment = self.environment else {
                    return
                }
                
                self.isCreatingLink = false
                self.state?.updated(transition: .immediate)
                
                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                
                let errorText: String
                switch error {
                case .generic:
                    errorText = presentationData.strings.Login_UnknownError
                case .tooManyLinks:
                    errorText = presentationData.strings.Business_Links_ErrorTooManyLinks
                }
                
                environment.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                    })
                ]), in: .window(.root))
            })
        }
        
        private func openLink(url: String) {
            if let link = self.links.first(where: { $0.url == url }) {
                self.openLink(link: link, openKeyboard: false)
            }
        }
        
        private func openLink(link: TelegramBusinessChatLinks.Link, openKeyboard: Bool) {
            guard let component = self.component else {
                return
            }
            
            let contents = BusinessLinkChatContents(
                context: component.context,
                kind: .businessLinkSetup(link: link)
            )
            let chatController = component.context.sharedContext.makeChatController(
                context: component.context,
                chatLocation: .customChatContents,
                subject: .customChatContents(contents: contents),
                botStart: nil,
                mode: .standard(.default),
                params: nil
            )
            if openKeyboard {
                chatController.activateInput(type: .text)
            }
            chatController.navigationPresentation = .modal
            self.environment?.controller()?.push(chatController)
        }
        
        private func openDeleteLink(url: String) {
            guard let component = self.component else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Business_Links_DeleteItemConfirmationAction, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    let _ = component.context.engine.accountData.deleteBusinessChatLink(url: url).startStandalone()
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            self.environment?.controller()?.present(actionSheet, in: .window(.root))
        }
        
        private func openShareLink(url: String) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            guard let link = self.links.first(where: { $0.url == url }) else {
                return
            }
            
            environment.controller()?.present(ShareController(context: component.context, subject: .url(link.url), showInChat: nil, externalShare: false, immediateExternalShare: false), in: .window(.root))
        }
        
        func update(component: BusinessLinksSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.links = component.initialData.businessLinks?.links ?? []
                self.linksDisposable = (component.context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.BusinessChatLinks(id: component.context.account.peerId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] links in
                    guard let self else {
                        return
                    }
                    let links = links?.links ?? []
                    if self.links != links {
                        self.links = links
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    }
                })
                
                self.refreshLinksDisposable = component.context.engine.accountData.refreshBusinessChatLinks().startStrict()
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
            
            let _ = alphaTransition
            let _ = presentationData
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.Business_Links, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
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
            
            let _ = sectionSpacing
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "MessageLinkEmoji"),
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
            
            let subtitleString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Business_Links_Text, attributes: MarkdownAttributes(
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
                    tapAction: { _, _ in
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
            
            var createLinkSectionItems: [AnyComponentWithIdentity<Empty>] = []
            createLinkSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Business_Links_CreateAction,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemAccentColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(
                    name: "Item List/AddLinkIcon",
                    tintColor: environment.theme.list.itemAccentColor
                ))), false),
                accessory: nil,
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.createLink()
                }
            ))))
            
            let footerText: String
            if let addressName = component.initialData.accountPeer?.addressName, let phoneNumber = component.initialData.accountPeer?.phone, component.initialData.displayPhone {
                footerText = environment.strings.Business_Links_SimpleLinkInfoUsernamePhone(addressName, phoneNumber).string
            } else if let addressName = component.initialData.accountPeer?.addressName {
                footerText = environment.strings.Business_Links_SimpleLinkInfoUsername(addressName).string
            } else if let phoneNumber = component.initialData.accountPeer?.phone, component.initialData.displayPhone {
                footerText = environment.strings.Business_Links_SimpleLinkInfoPhone(phoneNumber).string
            } else {
                footerText = ""
            }
            let createLinkSectionSize = self.createLinkSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: footerText.isEmpty ? nil : AnyComponent(MultilineTextComponent(
                        text: .markdown(text: footerText, attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.freeTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.freeTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                            linkAttribute: { link in
                                return ("URL", link)
                            }
                        )),
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
                        tapAction: { [weak self] attributes, _ in
                            guard let self, let component = self.component, let environment = self.environment else {
                                return
                            }
                            guard let url = attributes[NSAttributedString.Key(rawValue: "URL")] as? String else {
                                return
                            }
                            
                            let linkValue: String
                            if url == "phone", let phoneNumber = component.initialData.accountPeer?.phone {
                                linkValue = "t.me/+\(phoneNumber)"
                            } else if url == "username", let addressName = component.initialData.accountPeer?.addressName {
                                linkValue = "t.me/\(addressName)"
                            } else {
                                return
                            }
                            UIPasteboard.general.string = linkValue
                            
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                            
                            var animateAsReplacement = false
                            if let controller = environment.controller() {
                                controller.forEachController { c in
                                    if let c = c as? UndoOverlayController {
                                        animateAsReplacement = true
                                        c.dismiss()
                                    }
                                    return true
                                }
                            }
                            let controller = UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.GroupInfo_InviteLink_CopyAlert_Success), elevatedLayout: false, position: .bottom, animateInAsReplacement: animateAsReplacement, action: { _ in
                                return false
                            })
                            environment.controller()?.present(controller, in: .current)
                        }
                    )),
                    items: createLinkSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let createLinkSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: createLinkSectionSize)
            if let createLinkSectionView = self.createLinkSection.view {
                if createLinkSectionView.superview == nil {
                    self.scrollView.addSubview(createLinkSectionView)
                    self.createLinkSection.parentState = state
                }
                transition.setFrame(view: createLinkSectionView, frame: createLinkSectionFrame)
            }
            contentHeight += createLinkSectionSize.height
            contentHeight += sectionSpacing
            
            var linksSectionItems: [AnyComponentWithIdentity<Empty>] = []
            for link in self.links {
                linksSectionItems.append(AnyComponentWithIdentity(id: link.url, component: AnyComponent(BusinessLinkListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    link: link,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openLink(url: link.url)
                    },
                    deleteAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openDeleteLink(url: link.url)
                    },
                    shareAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openShareLink(url: link.url)
                    },
                    contextAction: { [weak self] sourceView, gesture in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        
                        var itemList: [ContextMenuItem] = []
                        itemList.append(.action(ContextMenuActionItem(
                            text: presentationData.strings.Business_Links_ItemActionShare,
                            textColor: .primary,
                            icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Share"), color: theme.contextMenu.primaryColor) },
                            action: { [weak self] c, _ in
                                c?.dismiss(completion: {
                                    guard let self else {
                                        return
                                    }
                                    self.openShareLink(url: link.url)
                                })
                            })
                        ))
                        itemList.append(.action(ContextMenuActionItem(
                            text: presentationData.strings.Common_Delete,
                            textColor: .destructive,
                            icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) },
                            action: { [weak self] c, _ in
                                c?.dismiss(completion: {
                                    guard let self else {
                                        return
                                    }
                                    self.openDeleteLink(url: link.url)
                                })
                            })
                        ))
                        let items = ContextController.Items(content: .list(itemList))
                        
                        let controller = ContextController(
                            presentationData: presentationData,
                            source: .extracted(BusineesLinkListContextExtractedContentSource(contentView: sourceView)), items: .single(items), recognizer: nil, gesture: gesture)
                        
                        self.environment?.controller()?.forEachController({ controller in
                            if let controller = controller as? UndoOverlayController {
                                controller.dismiss()
                            }
                            return true
                        })
                        self.environment?.controller()?.presentInGlobalOverlay(controller)
                    }
                ))))
            }
            let linksSectionSize = self.linksSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Business_Links_LinksSectionHeader,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: linksSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let linksSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: linksSectionSize)
            if let linksSectionView = self.linksSection.view {
                if linksSectionView.superview == nil {
                    self.scrollView.addSubview(linksSectionView)
                    self.linksSection.parentState = state
                }
                transition.setFrame(view: linksSectionView, frame: linksSectionFrame)
                alphaTransition.setAlpha(view: linksSectionView, alpha: self.links.isEmpty ? 0.0 : 1.0)
            }
            contentHeight += linksSectionSize.height
            
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
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
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

public final class BusinessLinksSetupScreen: ViewControllerComponentContainer {
    public final class InitialData: BusinessLinksSetupScreenInitialData {
        fileprivate let accountPeer: TelegramUser?
        fileprivate let businessLinks: TelegramBusinessChatLinks?
        fileprivate let displayPhone: Bool
        
        fileprivate init(accountPeer: TelegramUser?, businessLinks: TelegramBusinessChatLinks?, displayPhone: Bool) {
            self.accountPeer = accountPeer
            self.businessLinks = businessLinks
            self.displayPhone = displayPhone
        }
    }
    
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        initialData: InitialData
    ) {
        self.context = context
        
        super.init(context: context, component: BusinessLinksSetupScreenComponent(
            context: context,
            initialData: initialData
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessLinksSetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessLinksSetupScreenComponent.View else {
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
    
    public static func makeInitialData(context: AccountContext) -> Signal<BusinessLinksSetupScreenInitialData, NoError> {
        let settingsPromise: Promise<AccountPrivacySettings?>
        if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface, let current = rootController.getPrivacySettings() {
            settingsPromise = current
        } else {
            settingsPromise = Promise()
            settingsPromise.set(.single(nil))
        }
        
        return combineLatest(
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                TelegramEngine.EngineData.Item.Peer.BusinessChatLinks(id: context.account.peerId)
            ),
            settingsPromise.get()
            |> take(1)
        )
        |> map { data, settings in
            let (peer, businessLinks) = data
            
            var accountPeer: TelegramUser?
            if case let .user(user) = peer {
                accountPeer = user
            }
            
            var displayPhone = true
            if let settings {
                displayPhone = settings.phoneDiscoveryEnabled
            }
            
            return InitialData(
                accountPeer: accountPeer,
                businessLinks: businessLinks,
                displayPhone: displayPhone
            )
        }
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
}

private final class BusineesLinkListContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    private let contentView: ContextExtractedContentContainingView
    
    init(contentView: ContextExtractedContentContainingView) {
        self.contentView = contentView
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .view(self.contentView), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
