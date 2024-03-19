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
import ListActionItemComponent
import ListMultilineTextFieldItemComponent
import BundleIconComponent
import LottieComponent
import EntityKeyboard
import PeerAllowedReactionsScreen
import EmojiActionIconComponent
import TextFieldComponent

final class BusinessIntroSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: BusinessIntroSetupScreen.InitialData

    init(
        context: AccountContext,
        initialData: BusinessIntroSetupScreen.InitialData
    ) {
        self.context = context
        self.initialData = initialData
    }

    static func ==(lhs: BusinessIntroSetupScreenComponent, rhs: BusinessIntroSetupScreenComponent) -> Bool {
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
        private let introContent = ComponentView<Empty>()
        private let introSection = ComponentView<Empty>()
        private let deleteSection = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: BusinessIntroSetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private let introPlaceholderTag = NSObject()
        private let titleInputState = ListMultilineTextFieldItemComponent.ExternalState()
        private let titleInputTag = NSObject()
        private var resetTitle: String?
        private let textInputState = ListMultilineTextFieldItemComponent.ExternalState()
        private let textInputTag = NSObject()
        private var resetText: String?
        
        private var recenterOnTag: NSObject?
        
        private var stickerFile: TelegramMediaFile?
        private var stickerContent: EmojiPagerContentComponent?
        private var stickerContentDisposable: Disposable?
        private var displayStickerInput: Bool = false
        private var stickerSelectionControl: ComponentView<Empty>?
        
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
            self.stickerContentDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            guard let component = self.component, let environment = self.environment else {
                return true
            }
            let _ = environment
            
            let title = self.titleInputState.text.string
            let text = self.textInputState.text.string
            
            let intro: TelegramBusinessIntro?
            if !title.isEmpty || !text.isEmpty || self.stickerFile != nil {
                intro = TelegramBusinessIntro(title: title, text: text, stickerFile: self.stickerFile)
            } else {
                intro = nil
            }
            if intro != component.initialData.intro {
                let _ = component.context.engine.accountData.updateBusinessIntro(intro: intro).startStandalone()
            }
            
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        private var scrolledUp = true
        private func updateScrolling(transition: Transition) {
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
        
        func update(component: BusinessIntroSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                if let intro = component.initialData.intro {
                    self.resetTitle = intro.title
                    self.resetText = intro.text
                    self.stickerFile = intro.stickerFile
                }
            }
            
            if self.stickerContentDisposable == nil {
                let stickerContent = EmojiPagerContentComponent.stickerInputData(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    stickerNamespaces: [Namespaces.ItemCollection.CloudStickerPacks],
                    stickerOrderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudAllPremiumStickers],
                    chatPeerId: nil,
                    hasSearch: false,
                    hasTrending: false,
                    forceHasPremium: true
                )
                self.stickerContentDisposable = (stickerContent
                |> deliverOnMainQueue).start(next: { [weak self] stickerContent in
                    guard let self else {
                        return
                    }
                    self.stickerContent = stickerContent
                    
                    stickerContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                        performItemAction: { [weak self] _, item, _, _, _, _ in
                            guard let self else {
                                return
                            }
                            guard let itemFile = item.itemFile else {
                                return
                            }
                            
                            self.stickerFile = itemFile
                            self.displayStickerInput = false
                            
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.25))
                            }
                        },
                        deleteBackwards: {
                        },
                        openStickerSettings: {
                        },
                        openFeatured: {
                        },
                        openSearch: {
                        },
                        addGroupAction: { _, _, _ in
                        },
                        clearGroup: { _ in
                        },
                        editAction: { _ in
                        },
                        pushController: { c in
                        },
                        presentController: { c in
                        },
                        presentGlobalOverlayController: { c in
                        },
                        navigationController: {
                            return nil
                        },
                        requestUpdate: { _ in
                        },
                        updateSearchQuery: { _ in
                        },
                        updateScrollingToItemGroup: {
                        },
                        onScroll: {},
                        chatPeerId: nil,
                        peekBehavior: nil,
                        customLayout: nil,
                        externalBackground: nil,
                        externalExpansionView: nil,
                        customContentView: nil,
                        useOpaqueTheme: true,
                        hideBackground: false,
                        stateContext: nil,
                        addImage: nil
                    )
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                })
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let alphaTransition: Transition
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
            
            //TODO:localize
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Intro", font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
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
            contentHeight += 26.0
            
            self.recenterOnTag = nil
            if let hint = transition.userData(TextFieldComponent.AnimationHint.self), let targetView = hint.view {
                if let titleView = self.introSection.findTaggedView(tag: self.titleInputTag) {
                    if targetView.isDescendant(of: titleView) {
                        self.recenterOnTag = self.titleInputTag
                    }
                }
                if let textView = self.introSection.findTaggedView(tag: self.textInputTag) {
                    if targetView.isDescendant(of: textView) {
                        self.recenterOnTag = self.textInputTag
                    }
                }
            }
            
            var introSectionItems: [AnyComponentWithIdentity<Empty>] = []
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(Rectangle(color: .clear, height: 346.0, tag: self.introPlaceholderTag))))
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(ListMultilineTextFieldItemComponent(
                externalState: self.titleInputState,
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                initialText: "",
                resetText: self.resetTitle.flatMap {
                    return ListMultilineTextFieldItemComponent.ResetText(value: $0)
                },
                placeholder: "Enter Title",
                autocapitalizationType: .none,
                autocorrectionType: .no,
                characterLimit: 32,
                allowEmptyLines: false,
                updated: { _ in
                },
                textUpdateTransition: .spring(duration: 0.4),
                tag: self.titleInputTag
            ))))
            self.resetTitle = nil
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(ListMultilineTextFieldItemComponent(
                externalState: self.textInputState,
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                initialText: "",
                resetText: self.resetText.flatMap {
                    return ListMultilineTextFieldItemComponent.ResetText(value: $0)
                },
                placeholder: "Enter Message",
                autocapitalizationType: .none,
                autocorrectionType: .no,
                characterLimit: 70,
                allowEmptyLines: false,
                updated: { _ in
                },
                textUpdateTransition: .spring(duration: 0.4),
                tag: self.textInputTag
            ))))
            self.resetText = nil
            
            let stickerIcon: ListActionItemComponent.Icon
            if let stickerFile = self.stickerFile {
                stickerIcon = ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(EmojiActionIconComponent(
                    context: component.context,
                    color: environment.theme.list.itemPrimaryTextColor,
                    fileId: stickerFile.fileId.id,
                    file: stickerFile
                ))))
            } else {
                stickerIcon = ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "Random",
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: environment.theme.list.itemSecondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                ))))
            }
            
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Choose Sticker",
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                icon: stickerIcon,
                accessory: .none,
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    
                    self.displayStickerInput = true
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.5))
                    }
                }
            ))))
            let introSectionSize = self.introSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "CUSTOMIZE YOUR INTRO",
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "You can customize the message people see before they start a chat with you.",
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: introSectionItems,
                    itemUpdateOrder: introSectionItems.map(\.id).reversed()
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let introSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: introSectionSize)
            if let introSectionView = self.introSection.view {
                if introSectionView.superview == nil {
                    self.scrollView.addSubview(introSectionView)
                    self.introSection.parentState = state
                }
                transition.setFrame(view: introSectionView, frame: introSectionFrame)
            }
            contentHeight += introSectionSize.height
            contentHeight += sectionSpacing
            
            let titleText: String
            if self.titleInputState.text.string.isEmpty {
                titleText = "No messages here yet..."
            } else {
                titleText = self.titleInputState.text.string
            }
            
            let textText: String
            if self.textInputState.text.string.isEmpty {
                textText = "Send a message or tap on the greeting below"
            } else {
                textText = self.textInputState.text.string
            }
            
            let introContentSize = self.introContent.update(
                transition: transition,
                component: AnyComponent(ChatIntroItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    stickerFile: stickerFile,
                    title: titleText,
                    text: textText
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            if let introContentView = self.introContent.view {
                if introContentView.superview == nil {
                    if let placeholderView = self.introSection.findTaggedView(tag: self.introPlaceholderTag) {
                        placeholderView.addSubview(introContentView)
                    }
                }
                transition.setFrame(view: introContentView, frame: CGRect(origin: CGPoint(), size: introContentSize))
            }
            
            let displayDelete = !self.titleInputState.text.string.isEmpty || !self.textInputState.text.string.isEmpty || self.stickerFile != nil
            
            var deleteSectionHeight: CGFloat = 0.0
            deleteSectionHeight += sectionSpacing
            let deleteSectionSize = self.deleteSection.update(
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
                                        string: "Reset to Default",
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemDestructiveColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .center, spacing: 2.0, fillWidth: true)),
                            accessory: nil,
                            action: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                
                                self.resetTitle = ""
                                self.resetText = ""
                                self.stickerFile = nil
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        )))
                    ],
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let deleteSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + deleteSectionHeight), size: deleteSectionSize)
            if let deleteSectionView = self.deleteSection.view {
                if deleteSectionView.superview == nil {
                    self.scrollView.addSubview(deleteSectionView)
                }
                transition.setFrame(view: deleteSectionView, frame: deleteSectionFrame)
                
                if displayDelete {
                    alphaTransition.setAlpha(view: deleteSectionView, alpha: 1.0)
                } else {
                    alphaTransition.setAlpha(view: deleteSectionView, alpha: 0.0)
                }
            }
            deleteSectionHeight += deleteSectionSize.height
            if displayDelete {
                contentHeight += deleteSectionHeight
            }
            
            contentHeight += bottomContentInset
            
            var inputHeight: CGFloat = environment.inputHeight
            if self.displayStickerInput, let stickerContent = self.stickerContent {
                let stickerSelectionControl: ComponentView<Empty>
                var animateIn = false
                if let current = self.stickerSelectionControl {
                    stickerSelectionControl = current
                } else {
                    animateIn = true
                    stickerSelectionControl = ComponentView()
                    self.stickerSelectionControl = stickerSelectionControl
                }
                var selectedItems = Set<MediaId>()
                if let stickerFile = self.stickerFile {
                    selectedItems.insert(stickerFile.fileId)
                }
                let stickerSelectionControlSize = stickerSelectionControl.update(
                    transition: animateIn ? .immediate : transition,
                    component: AnyComponent(EmojiSelectionComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        sideInset: environment.safeInsets.left,
                        bottomInset: environment.safeInsets.bottom,
                        deviceMetrics: environment.deviceMetrics,
                        emojiContent: stickerContent.withSelectedItems(selectedItems),
                        backgroundIconColor: nil,
                        backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                        separatorColor: environment.theme.list.itemBlocksSeparatorColor,
                        backspace: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: min(340.0, max(50.0, availableSize.height - 200.0)))
                )
                let stickerSelectionControlFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - stickerSelectionControlSize.height), size: stickerSelectionControlSize)
                if let stickerSelectionControlView = stickerSelectionControl.view {
                    if stickerSelectionControlView.superview == nil {
                        self.addSubview(stickerSelectionControlView)
                    }
                    if animateIn {
                        stickerSelectionControlView.frame = stickerSelectionControlFrame
                        transition.animatePosition(view: stickerSelectionControlView, from: CGPoint(x: 0.0, y: stickerSelectionControlFrame.height), to: CGPoint(), additive: true)
                    } else {
                        transition.setFrame(view: stickerSelectionControlView, frame: stickerSelectionControlFrame)
                    }
                }
                inputHeight = stickerSelectionControlSize.height
            } else if let stickerSelectionControl = self.stickerSelectionControl {
                self.stickerSelectionControl = nil
                if let stickerSelectionControlView = stickerSelectionControl.view {
                    transition.setPosition(view: stickerSelectionControlView, position: CGPoint(x: stickerSelectionControlView.center.x, y: availableSize.height + stickerSelectionControlView.bounds.height * 0.5), completion: { [weak stickerSelectionControlView] _ in
                        stickerSelectionControlView?.removeFromSuperview()
                    })
                }
            }
            
            let combinedBottomInset = max(inputHeight, environment.safeInsets.bottom)
            contentHeight += combinedBottomInset
            
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
            
            if let recenterOnTag = self.recenterOnTag {
                self.recenterOnTag = nil
                
                if let targetView = self.introSection.findTaggedView(tag: recenterOnTag) {
                    let caretRect = targetView.convert(targetView.bounds, to: self.scrollView)
                    var scrollViewBounds = self.scrollView.bounds
                    let minButtonDistance: CGFloat = 16.0
                    if -scrollViewBounds.minY + caretRect.maxY > availableSize.height - combinedBottomInset - minButtonDistance {
                        scrollViewBounds.origin.y = -(availableSize.height - combinedBottomInset - minButtonDistance - caretRect.maxY)
                        if scrollViewBounds.origin.y < 0.0 {
                            scrollViewBounds.origin.y = 0.0
                        }
                    }
                    if self.scrollView.bounds != scrollViewBounds {
                        transition.setBounds(view: self.scrollView, bounds: scrollViewBounds)
                    }
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class BusinessIntroSetupScreen: ViewControllerComponentContainer {
    public final class InitialData: BusinessIntroSetupScreenInitialData {
        fileprivate let intro: TelegramBusinessIntro?
        
        fileprivate init(intro: TelegramBusinessIntro?) {
            self.intro = intro
        }
    }
    
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        initialData: InitialData
    ) {
        self.context = context
        
        super.init(context: context, component: BusinessIntroSetupScreenComponent(
            context: context,
            initialData: initialData
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessIntroSetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessIntroSetupScreenComponent.View else {
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
    
    public static func initialData(context: AccountContext) -> Signal<BusinessIntroSetupScreenInitialData, NoError> {
        return context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.BusinessIntro(id: context.account.peerId)
        )
        |> map { intro -> BusinessIntroSetupScreenInitialData in
            let value: TelegramBusinessIntro?
            switch intro {
            case let .known(intro):
                value = intro
            case .unknown:
                value = nil
            }
            return InitialData(intro: value)
        }
    }
}
