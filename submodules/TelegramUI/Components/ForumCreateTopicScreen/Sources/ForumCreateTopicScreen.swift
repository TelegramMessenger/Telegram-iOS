import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import EntityKeyboard
import PagerComponent
import MultilineTextComponent
import EmojiStatusComponent
import Postbox
import PremiumUI

private final class TitleFieldComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let textColor: UIColor
    let accentColor: UIColor
    let placeholderColor: UIColor
    let fileId: Int64
    let iconColor: Int32
    let text: String
    let textUpdated: (String) -> Void
    
    init(
        context: AccountContext,
        textColor: UIColor,
        accentColor: UIColor,
        placeholderColor: UIColor,
        fileId: Int64,
        iconColor: Int32,
        text: String,
        textUpdated: @escaping (String) -> Void
    ) {
        self.context = context
        self.textColor = textColor
        self.accentColor = accentColor
        self.placeholderColor = placeholderColor
        self.fileId = fileId
        self.iconColor = iconColor
        self.text = text
        self.textUpdated = textUpdated
    }
    
    static func ==(lhs: TitleFieldComponent, rhs: TitleFieldComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.placeholderColor != rhs.placeholderColor {
            return false
        }
        if lhs.fileId != rhs.fileId {
            return false
        }
        if lhs.iconColor != rhs.iconColor {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let iconView: ComponentView<Empty>
        private let textField: TextFieldNodeView
        
        private var component: TitleFieldComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.iconView = ComponentView<Empty>()
            self.textField = TextFieldNodeView(frame: .zero)
            
            super.init(frame: frame)
            
            self.textField.placeholder = "What do you want to discuss?"
            self.textField.addTarget(self, action: #selector(self.textChanged(_:)), for: .editingChanged)
            
            self.addSubview(self.textField)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        @objc func textChanged(_ sender: Any) {
            self.component?.textUpdated(self.textField.text ?? "")
        }
        
        func update(component: TitleFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.textField.textColor = component.textColor
            self.textField.text = component.text
            self.textField.font = Font.regular(17.0)
            
            self.component = component
            self.state = state
            
            let iconContent: EmojiStatusComponent.Content
            if component.fileId == 0 {
                iconContent = .topic(title: String(component.text.prefix(1)), color: component.iconColor, size: CGSize(width: 32.0, height: 32.0))
            } else {
                iconContent = .animation(content: .customEmoji(fileId: component.fileId), size: CGSize(width: 48.0, height: 48.0), placeholderColor: component.placeholderColor, themeColor: component.accentColor, loopMode: .count(2))
            }
            
            let iconSize = self.iconView.update(
                transition: .easeInOut(duration: 0.2),
                component: AnyComponent(EmojiStatusComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    content: iconContent,
                    isVisibleForAnimations: true,
                    action: nil
                )),
                environment: {},
                containerSize: CGSize(width: 32.0, height: 32.0)
            )
            
            if let iconComponentView = self.iconView.view {
                if iconComponentView.superview == nil {
                    self.addSubview(iconComponentView)
                }
                
                iconComponentView.frame = CGRect(origin: CGPoint(x: 15.0, y: floorToScreenPixels((availableSize.height - iconSize.height) / 2.0)), size: iconSize)
                
                self.textField.becomeFirstResponder()
            }
            
            self.textField.frame = CGRect(x: 15.0 + iconSize.width + 15.0, y: 0.0, width: availableSize.width - 46.0 - iconSize.width, height: 44.0)
                        
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class TopicIconSelectionComponent: Component {
    public typealias EnvironmentType = Empty
    
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let deviceMetrics: DeviceMetrics
    public let emojiContent: EmojiPagerContentComponent
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        deviceMetrics: DeviceMetrics,
        emojiContent: EmojiPagerContentComponent,
        backgroundColor: UIColor,
        separatorColor: UIColor
    ) {
        self.theme = theme
        self.strings = strings
        self.deviceMetrics = deviceMetrics
        self.emojiContent = emojiContent
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
    }
    
    public static func ==(lhs: TopicIconSelectionComponent, rhs: TopicIconSelectionComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings != rhs.strings {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        if lhs.emojiContent != rhs.emojiContent {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let keyboardView: ComponentView<Empty>
        private let keyboardClippingView: UIView
        private let panelHostView: PagerExternalTopPanelContainer
        private let panelBackgroundView: BlurredBackgroundView
        private let panelSeparatorView: UIView
        
        private var component: TopicIconSelectionComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.keyboardView = ComponentView<Empty>()
            self.keyboardClippingView = UIView()
            self.panelHostView = PagerExternalTopPanelContainer()
            self.panelBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.panelSeparatorView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.keyboardClippingView)
            self.addSubview(self.panelBackgroundView)
            self.addSubview(self.panelSeparatorView)
            self.addSubview(self.panelHostView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: TopicIconSelectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.backgroundColor = component.backgroundColor
            let panelBackgroundColor = component.backgroundColor.withMultipliedAlpha(0.85)
            self.panelBackgroundView.updateColor(color: panelBackgroundColor, transition: .immediate)
            self.panelSeparatorView.backgroundColor = component.separatorColor
            
            self.component = component
            self.state = state
            
            let topPanelHeight: CGFloat = 42.0
            
            let keyboardSize = self.keyboardView.update(
                transition: transition.withUserData(EmojiPagerContentComponent.SynchronousLoadBehavior(isDisabled: true)),
                component: AnyComponent(EntityKeyboardComponent(
                    theme: component.theme,
                    strings: component.strings,
                    isContentInFocus: true,
                    containerInsets: UIEdgeInsets(top: topPanelHeight - 34.0, left: 0.0, bottom: 0.0, right: 0.0),
                    topPanelInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    emojiContent: component.emojiContent,
                    stickerContent: nil,
                    gifContent: nil,
                    hasRecentGifs: false,
                    availableGifSearchEmojies: [],
                    defaultToEmojiTab: true,
                    externalTopPanelContainer: self.panelHostView,
                    topPanelExtensionUpdated: { _, _ in },
                    hideInputUpdated: { _, _, _ in },
                    hideTopPanelUpdated: { _, _ in },
                    switchToTextInput: {},
                    switchToGifSubject: { _ in },
                    reorderItems: { _, _ in },
                    makeSearchContainerNode: { _ in return nil },
                    deviceMetrics: component.deviceMetrics,
                    hiddenInputHeight: 0.0,
                    displayBottomPanel: false,
                    isExpanded: true
                )),
                environment: {},
                containerSize: availableSize
            )
            if let keyboardComponentView = self.keyboardView.view {
                if keyboardComponentView.superview == nil {
                    self.keyboardClippingView.addSubview(keyboardComponentView)
                }
                
                if panelBackgroundColor.alpha < 0.01 {
                    self.keyboardClippingView.clipsToBounds = true
                } else {
                    self.keyboardClippingView.clipsToBounds = false
                }
                
                transition.setFrame(view: self.keyboardClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight), size: CGSize(width: availableSize.width, height: availableSize.height - topPanelHeight)))
                
                transition.setFrame(view: keyboardComponentView, frame: CGRect(origin: CGPoint(x: 0.0, y: -topPanelHeight), size: keyboardSize))
                transition.setFrame(view: self.panelHostView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight - 34.0), size: CGSize(width: keyboardSize.width, height: 0.0)))
                
                transition.setFrame(view: self.panelBackgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: keyboardSize.width, height: topPanelHeight)))
                self.panelBackgroundView.update(size: self.panelBackgroundView.bounds.size, transition: transition.containedViewLayoutTransition)
                
                transition.setFrame(view: self.panelSeparatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight), size: CGSize(width: keyboardSize.width, height: UIScreenPixel)))
                transition.setAlpha(view: self.panelSeparatorView, alpha: 1.0)
            }
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ForumCreateTopicScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let mode: ForumCreateTopicScreen.Mode
    let titleUpdated: (String) -> Void
    let iconUpdated: (Int64?) -> Void
    let openPremium: () -> Void
    
    init(context: AccountContext, peerId: EnginePeer.Id, mode: ForumCreateTopicScreen.Mode, titleUpdated:  @escaping (String) -> Void, iconUpdated: @escaping (Int64?) -> Void, openPremium: @escaping () -> Void) {
        self.context = context
        self.peerId = peerId
        self.mode = mode
        self.titleUpdated = titleUpdated
        self.iconUpdated = iconUpdated
        self.openPremium = openPremium
    }
    
    static func ==(lhs: ForumCreateTopicScreenComponent, rhs: ForumCreateTopicScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let titleUpdated: (String) -> Void
        private let iconUpdated: (Int64?) -> Void
        private let openPremium: () -> Void
        
        var emojiContent: EmojiPagerContentComponent?
        private let emojiContentDisposable = MetaDisposable()
        
        private var isPremiumDisposable: Disposable?
        
        private var defaultIconFilesDisposable: Disposable?
        private var defaultIconFiles = Set<Int64>()
        
        var title: String
        var fileId: Int64
        var iconColor: Int32
        
        private var hasPremium: Bool = false
        
        init(context: AccountContext, mode: ForumCreateTopicScreen.Mode, titleUpdated: @escaping (String) -> Void, iconUpdated: @escaping (Int64?) -> Void, openPremium: @escaping () -> Void) {
            self.context = context
            self.titleUpdated = titleUpdated
            self.iconUpdated = iconUpdated
            self.openPremium = openPremium
            
            switch mode {
            case .create:
                self.title = ""
                self.fileId = 0
                
                let colors: [Int32] = [0x6FB9F0, 0xFFD67E, 0xCB86DB, 0x8EEE98,0xFF93B2, 0xFB6F5F]
                self.iconColor = colors.randomElement() ?? 0x0
            case let .edit(info):
                self.title = info.title
                self.fileId = info.icon ?? 0
                self.iconColor = info.iconColor
            }
            
            super.init()
            
            self.emojiContentDisposable.set((
                EmojiPagerContentComponent.emojiInputData(
                    context: self.context,
                    animationCache: self.context.animationCache,
                    animationRenderer: self.context.animationRenderer,
                    isStandalone: false,
                    isStatusSelection: false,
                    isReactionSelection: false,
                    isTopicIconSelection: true,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: self.context.account.peerId,
                    selectedItems: Set(),
                    topicTitle: self.title,
                    topicColor: self.iconColor
                )
            |> deliverOnMainQueue).start(next: { [weak self] content in
                self?.emojiContent = content
                self?.updated(transition: .immediate)
            }))
            
            self.isPremiumDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                guard case let .user(user) = peer else {
                    return false
                }
                return user.isPremium
            }
            |> distinctUntilChanged).start(next: { [weak self] hasPremium in
                self?.hasPremium = hasPremium
            })
            
            self.defaultIconFilesDisposable = (context.engine.stickers.loadedStickerPack(reference: .iconTopicEmoji, forceActualized: false)
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case let .result(_, items, _):
                    strongSelf.defaultIconFiles = Set(items.map(\.file.fileId.id))
                default:
                    break
                }
            })
        }
        
        deinit {
            self.emojiContentDisposable.dispose()
            self.defaultIconFilesDisposable?.dispose()
            self.isPremiumDisposable?.dispose()
        }
        
        func updateTitle(_ text: String) {
            self.title = text
            self.updated(transition: .immediate)
            
            self.titleUpdated(text)
            
            self.emojiContentDisposable.set((
                EmojiPagerContentComponent.emojiInputData(
                    context: self.context,
                    animationCache: self.context.animationCache,
                    animationRenderer: self.context.animationRenderer,
                    isStandalone: false,
                    isStatusSelection: false,
                    isReactionSelection: false,
                    isTopicIconSelection: true,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: self.context.account.peerId,
                    selectedItems: Set([MediaId(namespace: Namespaces.Media.CloudFile, id: self.fileId)]),
                    topicTitle: self.title,
                    topicColor: self.iconColor
                )
            |> deliverOnMainQueue).start(next: { [weak self] content in
                self?.emojiContent = content
                self?.updated(transition: .immediate)
            }))
        }
        
        func applyItem(groupId: AnyHashable, item: EmojiPagerContentComponent.Item?) {
            guard let item = item else {
                return
            }
            
            if let fileId = item.itemFile?.fileId.id {
                if !self.hasPremium && !self.defaultIconFiles.contains(fileId) {
                    self.openPremium()
                    return
                }
                
                self.fileId = fileId
            } else {
                self.fileId = 0
            }
            
            self.updated(transition: .immediate)
            
            self.iconUpdated(self.fileId != 0 ? self.fileId : nil)
            
            self.emojiContentDisposable.set((
                EmojiPagerContentComponent.emojiInputData(
                    context: self.context,
                    animationCache: self.context.animationCache,
                    animationRenderer: self.context.animationRenderer,
                    isStandalone: false,
                    isStatusSelection: false,
                    isReactionSelection: false,
                    isTopicIconSelection: true,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: self.context.account.peerId,
                    selectedItems: Set([MediaId(namespace: Namespaces.Media.CloudFile, id: self.fileId)]),
                    topicTitle: self.title,
                    topicColor: self.iconColor
                )
            |> deliverOnMainQueue).start(next: { [weak self] content in
                self?.emojiContent = content
                self?.updated(transition: .immediate)
            }))
        }
    }
    
    func makeState() -> State {
        return State(
            context: self.context,
            mode: self.mode,
            titleUpdated: self.titleUpdated,
            iconUpdated: self.iconUpdated,
            openPremium: self.openPremium
        )
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let titleHeader = Child(MultilineTextComponent.self)
        let titleBackground = Child(RoundedRectangle.self)
        let titleField = Child(TitleFieldComponent.self)
        
        let iconHeader = Child(MultilineTextComponent.self)
        let iconBackground = Child(RoundedRectangle.self)
        let iconSelector = Child(TopicIconSelectionComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self].value
            let state = context.state
                        
            let background = background.update(
                component: Rectangle(
                    color: environment.theme.list.blocksBackgroundColor
                ),
                environment: {},
                availableSize: context.availableSize,
                transition: context.transition
            )
                                    
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            let sideInset: CGFloat = 16.0
            let topInset: CGFloat = 16.0 + environment.navigationHeight
            let headerSpacing: CGFloat = 6.0
            let sectionSpacing: CGFloat = 30.0
            
            var contentHeight = topInset
            
            let titleHeader = titleHeader.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "ENTER TOPIC TITLE",
                        font: Font.regular(13.0),
                        textColor: environment.theme.list.freeTextColor,
                        paragraphAlignment: .natural)
                    ),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(titleHeader
                .position(CGPoint(x: sideInset * 2.0 + titleHeader.size.width / 2.0, y: contentHeight + titleHeader.size.height / 2.0))
            )
            contentHeight += titleHeader.size.height + headerSpacing
            
            let titleBackground = titleBackground.update(
                component: RoundedRectangle(
                    color: environment.theme.list.itemBlocksBackgroundColor,
                    cornerRadius: 10.0
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 44.0),
                transition: context.transition
            )
            context.add(titleBackground
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + titleBackground.size.height / 2.0))
            )
            
            let titleField = titleField.update(
                component: TitleFieldComponent(
                    context: context.component.context,
                    textColor: environment.theme.list.itemPrimaryTextColor,
                    accentColor: environment.theme.list.itemAccentColor,
                    placeholderColor: environment.theme.list.disclosureArrowColor,
                    fileId: state.fileId,
                    iconColor: state.iconColor,
                    text: state.title,
                    textUpdated: { [weak state] text in
                        state?.updateTitle(text)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 44.0),
                transition: context.transition
            )
            context.add(titleField
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + titleBackground.size.height / 2.0))
            )
            
            contentHeight += titleBackground.size.height + sectionSpacing
            
            let iconHeader = iconHeader.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "SELECT TOPIC ICON",
                        font: Font.regular(13.0),
                        textColor: environment.theme.list.freeTextColor,
                        paragraphAlignment: .natural)
                    ),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(
                    width: context.availableSize.width - sideInset * 2.0,
                    height: CGFloat.greatestFiniteMagnitude
                ),
                transition: .immediate
            )
            context.add(iconHeader
                .position(CGPoint(x: sideInset * 2.0 + iconHeader.size.width / 2.0, y: contentHeight + iconHeader.size.height / 2.0))
            )
            contentHeight += iconHeader.size.height + headerSpacing
            
            let bottomInset = max(environment.safeInsets.bottom, 12.0)
            
            let iconBackground = iconBackground.update(
                component: RoundedRectangle(
                    color: environment.theme.list.itemBlocksBackgroundColor,
                    cornerRadius: 10.0
                ),
                availableSize: CGSize(
                    width: context.availableSize.width - sideInset * 2.0,
                    height: context.availableSize.height - contentHeight - bottomInset
                ),
                transition: context.transition
            )
            context.add(iconBackground
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + iconBackground.size.height / 2.0))
            )
            
            if let emojiContent = state.emojiContent {
                let availableHeight = context.availableSize.height - contentHeight - max(bottomInset, environment.inputHeight)
                
                let iconSelector = iconSelector.update(
                    component: TopicIconSelectionComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        deviceMetrics: environment.deviceMetrics,
                        emojiContent: emojiContent,
                        backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                        separatorColor: environment.theme.list.blocksBackgroundColor
                    ),
                    environment: {},
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: availableHeight),
                    transition: context.transition
                )
                context.add(iconSelector
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + iconSelector.size.height / 2.0))
                    .cornerRadius(10.0)
                    .clipsToBounds(true)
                )
                
                let accountContext = context.component.context
                emojiContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                    performItemAction: { [weak state] groupId, item, _, _, _, _ in
                        state?.applyItem(groupId: groupId, item: item)
                    },
                    deleteBackwards: {
                    },
                    openStickerSettings: {
                    },
                    openFeatured: {
                    },
                    addGroupAction: { groupId, isPremiumLocked in
                        guard let collectionId = groupId.base as? ItemCollectionId else {
                            return
                        }
                        
                        let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
                        let _ = (accountContext.account.postbox.combinedView(keys: [viewKey])
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { views in
                            guard let view = views.views[viewKey] as? OrderedItemListView else {
                                return
                            }
                            for featuredEmojiPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                                if featuredEmojiPack.info.id == collectionId {
//                                    if let strongSelf = self {
//                                        strongSelf.scheduledEmojiContentAnimationHint = EmojiPagerContentComponent.ContentAnimation(type: .groupInstalled(id: collectionId))
//                                    }
                                    let _ = accountContext.engine.stickers.addStickerPackInteractively(info: featuredEmojiPack.info, items: featuredEmojiPack.topItems).start()
                                    
                                    break
                                }
                            }
                        })
                    },
                    clearGroup: { _ in
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
                    updateSearchQuery: { _, _ in
                    },
                    chatPeerId: nil,
                    peekBehavior: nil,
                    customLayout: nil,
                    externalBackground: nil,
                    externalExpansionView: nil,
                    useOpaqueTheme: true
                )
            }
            
            return context.availableSize
        }
    }
}

public class ForumCreateTopicScreen: ViewControllerComponentContainer {
    public enum Mode: Equatable {
        case create
        case edit(topic: EngineMessageHistoryThread.Info)
    }
    
    private var state: (String, Int64?) = ("", nil)
    public var completion: (String, Int64?) -> Void = { _, _ in }
    
    public init(context: AccountContext, peerId: EnginePeer.Id, mode: ForumCreateTopicScreen.Mode) {
        var titleUpdatedImpl: ((String) -> Void)?
        var iconUpdatedImpl: ((Int64?) -> Void)?
        var openPremiumImpl: (() -> Void)?
        
        super.init(context: context, component: ForumCreateTopicScreenComponent(context: context, peerId: peerId, mode: mode, titleUpdated: { title in
            titleUpdatedImpl?(title)
        }, iconUpdated: { fileId in
            iconUpdatedImpl?(fileId)
        }, openPremium: {
            openPremiumImpl?()
        }), navigationBarAppearance: .transparent)
        
        //TODO:localize
        let title: String
        let doneTitle: String
        switch mode {
            case .create:
                title = "New Topic"
                doneTitle = "Create"
            case .edit:
                title = "Edit Topic"
                doneTitle = "Done"
        }
        
        self.title = title
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: doneTitle, style: .done, target: self, action: #selector(self.createPressed))
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        
        if case .edit = mode {
            self.navigationItem.rightBarButtonItem?.isEnabled = true
        }
        
        titleUpdatedImpl = { [weak self] title in
            guard let strongSelf = self else {
                return
            }
            strongSelf.navigationItem.rightBarButtonItem?.isEnabled = !title.isEmpty
            
            strongSelf.state = (title, strongSelf.state.1)
        }
        
        iconUpdatedImpl = { [weak self] fileId in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.state = (strongSelf.state.0, fileId)
        }
        
        openPremiumImpl = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            var replaceImpl: ((ViewController) -> Void)?
            let controller = PremiumDemoScreen(context: context, subject: .uniqueReactions, action: {
                let controller = PremiumIntroScreen(context: context, source: .reactions)
                replaceImpl?(controller)
            })
            replaceImpl = { [weak controller] c in
                controller?.replace(with: c)
            }
            strongSelf.push(controller)
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
    
    @objc private func createPressed() {
        self.completion(self.state.0, self.state.1)
    }
}
