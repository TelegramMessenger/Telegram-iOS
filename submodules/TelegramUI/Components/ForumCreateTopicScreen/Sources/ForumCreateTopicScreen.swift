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
import PremiumUI
import ProgressNavigationButtonNode
import Postbox
import SwitchComponent

private final class TitleFieldComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let textColor: UIColor
    let accentColor: UIColor
    let placeholderColor: UIColor
    let isGeneral: Bool
    let fileId: Int64
    let iconColor: Int32
    let text: String
    let placeholderText: String
    let isEditing: Bool
    let textUpdated: (String) -> Void
    let iconPressed: () -> Void
    
    init(
        context: AccountContext,
        textColor: UIColor,
        accentColor: UIColor,
        placeholderColor: UIColor,
        isGeneral: Bool,
        fileId: Int64,
        iconColor: Int32,
        text: String,
        placeholderText: String,
        isEditing: Bool,
        textUpdated: @escaping (String) -> Void,
        iconPressed: @escaping () -> Void
    ) {
        self.context = context
        self.textColor = textColor
        self.accentColor = accentColor
        self.placeholderColor = placeholderColor
        self.isGeneral = isGeneral
        self.fileId = fileId
        self.iconColor = iconColor
        self.text = text
        self.placeholderText = placeholderText
        self.isEditing = isEditing
        self.textUpdated = textUpdated
        self.iconPressed = iconPressed
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
        if lhs.isGeneral != rhs.isGeneral {
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
        if lhs.placeholderText != rhs.placeholderText {
            return false
        }
        if lhs.isEditing != rhs.isEditing {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate {
        private let iconButton: HighlightTrackingButton
        private let iconView: ComponentView<Empty>
        private let placeholderView: ComponentView<Empty>
        private let textField: TextFieldNodeView
        
        private var component: TitleFieldComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.iconButton = HighlightTrackingButton()
            self.iconView = ComponentView<Empty>()
            self.placeholderView = ComponentView<Empty>()
            self.textField = TextFieldNodeView(frame: .zero)

            super.init(frame: frame)

            self.textField.delegate = self
            self.textField.addTarget(self, action: #selector(self.textChanged(_:)), for: .editingChanged)
            
            self.addSubview(self.textField)
            self.addSubview(self.iconButton)
            
            self.iconButton.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self, let iconView = strongSelf.iconView.view {
                    if highlighted {
                        iconView.layer.animateScale(from: 1.0, to: 0.8, duration: 0.25, removeOnCompletion: false)
                    } else if let presentationLayer = iconView.layer.presentation() {
                        iconView.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.2, removeOnCompletion: false)
                    }
                }
            }
            self.iconButton.addTarget(self, action: #selector(self.iconButtonPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc func iconButtonPressed() {
            self.component?.iconPressed()
        }
        
        @objc func textChanged(_ sender: Any) {
            let text = self.textField.text ?? ""
            self.component?.textUpdated(text)
            self.placeholderView.view?.isHidden = !text.isEmpty
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            if newText.count > 128 {
                textField.layer.addShakeAnimation()
                let hapticFeedback = HapticFeedback()
                hapticFeedback.error()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
                    let _ = hapticFeedback
                })
                return false
            }
            return true
        }
        
        func update(component: TitleFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.textField.textColor = component.textColor
            self.textField.text = component.text
            self.textField.font = Font.regular(17.0)
            
            self.component = component
            self.state = state
            
            let iconContent: EmojiStatusComponent.Content
            if component.isGeneral {
                iconContent = .image(image: generateTintedImage(image: UIImage(bundleImageName: "Chat List/GeneralTopicIcon"), color: component.placeholderColor))
                self.iconButton.isUserInteractionEnabled = false
            } else if component.fileId == 0 {
                iconContent = .topic(title: String(component.text.prefix(1)), color: component.iconColor, size: CGSize(width: 32.0, height: 32.0))
                self.iconButton.isUserInteractionEnabled = true
            } else {
                iconContent = .animation(content: .customEmoji(fileId: component.fileId), size: CGSize(width: 48.0, height: 48.0), placeholderColor: component.placeholderColor, themeColor: component.accentColor, loopMode: .count(2))
                self.iconButton.isUserInteractionEnabled = false
            }
            self.iconButton.isUserInteractionEnabled = !component.isEditing
            
            let placeholderSize = self.placeholderView.update(
                transition: .easeInOut(duration: 0.2),
                component: AnyComponent(
                    Text(
                        text: component.placeholderText,
                        font: Font.regular(17.0),
                        color: component.placeholderColor
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            if let placeholderComponentView = self.placeholderView.view {
                if placeholderComponentView.superview == nil {
                    self.insertSubview(placeholderComponentView, at: 0)
                }
                
                placeholderComponentView.frame = CGRect(origin: CGPoint(x: 62.0, y: floorToScreenPixels((availableSize.height - placeholderSize.height) / 2.0) + 1.0 - UIScreenPixel), size: placeholderSize)
            }
            
            self.placeholderView.view?.isHidden = !component.text.isEmpty
            
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
                    self.insertSubview(iconComponentView, at: 0)
                }
                
                iconComponentView.frame = CGRect(origin: CGPoint(x: 15.0, y: floorToScreenPixels((availableSize.height - iconSize.height) / 2.0)), size: iconSize)
                self.iconButton.frame = iconComponentView.frame.insetBy(dx: -4.0, dy: -4.0)
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
                    isContentInFocus: false,
                    containerInsets: UIEdgeInsets(top: topPanelHeight - 34.0, left: 0.0, bottom: 0.0, right: 0.0),
                    topPanelInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    emojiContent: component.emojiContent,
                    stickerContent: nil,
                    maskContent: nil,
                    gifContent: nil,
                    hasRecentGifs: false,
                    availableGifSearchEmojies: [],
                    defaultToEmojiTab: true,
                    externalTopPanelContainer: self.panelHostView,
                    externalBottomPanelContainer: nil,
                    displayTopPanelBackground: .blur,
                    topPanelExtensionUpdated: { _, _ in },
                    topPanelScrollingOffset: { _, _ in },
                    hideInputUpdated: { _, _, _ in },
                    hideTopPanelUpdated: { _, _ in },
                    switchToTextInput: {},
                    switchToGifSubject: { _ in },
                    reorderItems: { _, _ in },
                    makeSearchContainerNode: { _ in return nil },
                    contentIdUpdated: { _ in },
                    deviceMetrics: component.deviceMetrics,
                    hiddenInputHeight: 0.0,
                    inputHeight: 0.0,
                    displayBottomPanel: false,
                    isExpanded: true,
                    clipContentToTopPanel: false,
                    useExternalSearchContainer: false
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
    let ready: Promise<Bool>
    let peerId: EnginePeer.Id
    let mode: ForumCreateTopicScreen.Mode
    let titleUpdated: (String) -> Void
    let iconUpdated: (Int64?) -> Void
    let iconColorUpdated: (Int32) -> Void
    let isHiddenUpdated: (Bool) -> Void
    let openPremium: () -> Void
    
    init(
        context: AccountContext,
        ready: Promise<Bool>,
        peerId: EnginePeer.Id,
        mode: ForumCreateTopicScreen.Mode,
        titleUpdated:  @escaping (String) -> Void,
        iconUpdated: @escaping (Int64?) -> Void,
        iconColorUpdated: @escaping (Int32) -> Void,
        isHiddenUpdated: @escaping (Bool) -> Void,
        openPremium: @escaping () -> Void
    ) {
        self.context = context
        self.ready = ready
        self.peerId = peerId
        self.mode = mode
        self.titleUpdated = titleUpdated
        self.iconUpdated = iconUpdated
        self.iconColorUpdated = iconColorUpdated
        self.isHiddenUpdated = isHiddenUpdated
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
        private let ready: Promise<Bool>
        private let titleUpdated: (String) -> Void
        private let iconUpdated: (Int64?) -> Void
        private let iconColorUpdated: (Int32) -> Void
        private let isHiddenUpdated: (Bool) -> Void
        private let openPremium: () -> Void
        
        var emojiContent: EmojiPagerContentComponent?
        private let emojiContentDisposable = MetaDisposable()
        
        private var isPremiumDisposable: Disposable?
        
        private var defaultIconFilesDisposable: Disposable?
        private var defaultIconFiles = Set<Int64>()
        
        let isGeneral: Bool
        var title: String
        var fileId: Int64
        var iconColor: Int32
        var isHidden: Bool
        
        private var hasPremium: Bool = false
        
        init(context: AccountContext, ready: Promise<Bool>, mode: ForumCreateTopicScreen.Mode, titleUpdated: @escaping (String) -> Void, iconUpdated: @escaping (Int64?) -> Void, iconColorUpdated: @escaping (Int32) -> Void, isHiddenUpdated: @escaping (Bool) -> Void, openPremium: @escaping () -> Void) {
            self.context = context
            self.ready = ready
            self.titleUpdated = titleUpdated
            self.iconUpdated = iconUpdated
            self.iconColorUpdated = iconColorUpdated
            self.isHiddenUpdated = isHiddenUpdated
            self.openPremium = openPremium
            
            switch mode {
            case .create:
                self.isGeneral = false
                self.title = ""
                self.fileId = 0
                self.iconColor = ForumCreateTopicScreen.iconColors.randomElement() ?? 0x0
                self.isHidden = false
                iconColorUpdated(self.iconColor)
            case let .edit(threadId, info, isHidden):
                self.isGeneral = threadId == 1
                self.title = info.title
                self.fileId = info.icon ?? 0
                self.iconColor = info.iconColor
                self.isHidden = isHidden
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
                    isEmojiSelection: false,
                    hasTrending: false,
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
            self.updateEmojiContent()
        }
        
        func updateIsHidden(_ isHidden: Bool) {
            self.isHidden = isHidden
            self.updated(transition: .immediate)
            self.isHiddenUpdated(isHidden)
        }
        
        func updateEmojiContent() {
            self.emojiContentDisposable.set((
                EmojiPagerContentComponent.emojiInputData(
                    context: self.context,
                    animationCache: self.context.animationCache,
                    animationRenderer: self.context.animationRenderer,
                    isStandalone: false,
                    isStatusSelection: false,
                    isReactionSelection: false,
                    isEmojiSelection: false,
                    hasTrending: false,
                    isTopicIconSelection: true,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: self.context.account.peerId,
                    selectedItems: Set([EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: self.fileId)]),
                    topicTitle: self.title,
                    topicColor: self.iconColor
                )
            |> deliverOnMainQueue).start(next: { [weak self] content in
                self?.emojiContent = content
                self?.updated(transition: .immediate)
                
                self?.ready.set(.single(true))
            }))
        }
        
        func switchIcon() {
            let colors = ForumCreateTopicScreen.iconColors
            if let index = colors.firstIndex(where: { $0 == self.iconColor }) {
                let nextIndex = (index + 1) % colors.count
                self.iconColor = colors[nextIndex]
            } else {
                self.iconColor = colors.first ?? 0
            }
            self.updated(transition: .immediate)
            self.iconColorUpdated(self.iconColor)
            self.updateEmojiContent()
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
            self.updateEmojiContent()
        }
    }
    
    func makeState() -> State {
        return State(
            context: self.context,
            ready: self.ready,
            mode: self.mode,
            titleUpdated: self.titleUpdated,
            iconUpdated: self.iconUpdated,
            iconColorUpdated: self.iconColorUpdated,
            isHiddenUpdated: self.isHiddenUpdated,
            openPremium: self.openPremium
        )
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let titleHeader = Child(MultilineTextComponent.self)
        let titleBackground = Child(RoundedRectangle.self)
        let titleField = Child(TitleFieldComponent.self)
        
        let hideBackground = Child(RoundedRectangle.self)
        let hideTitle = Child(MultilineTextComponent.self)
        let hideSwitch = Child(SwitchComponent.self)
        let hideInfo = Child(MultilineTextComponent.self)
        
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
                        string: environment.strings.CreateTopic_EnterTopicTitle,
                        font: Font.regular(13.0),
                        textColor: environment.theme.list.freeTextColor,
                        paragraphAlignment: .natural)
                    ),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0  - environment.safeInsets.left - environment.safeInsets.right, height: CGFloat.greatestFiniteMagnitude),
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
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right, height: 44.0),
                transition: context.transition
            )
            context.add(titleBackground
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + titleBackground.size.height / 2.0))
            )
            
            var isEditing = false
            if case .edit = context.component.mode {
                isEditing = true
            }
            
            let titleField = titleField.update(
                component: TitleFieldComponent(
                    context: context.component.context,
                    textColor: environment.theme.list.itemPrimaryTextColor,
                    accentColor: environment.theme.list.itemAccentColor,
                    placeholderColor: environment.theme.list.disclosureArrowColor,
                    isGeneral: state.isGeneral,
                    fileId: state.fileId,
                    iconColor: state.iconColor,
                    text: state.title,
                    placeholderText: environment.strings.CreateTopic_EnterTopicTitlePlaceholder,
                    isEditing: isEditing,
                    textUpdated: { [weak state] text in
                        state?.updateTitle(text)
                    },
                    iconPressed: { [weak state] in
                        state?.switchIcon()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right, height: 44.0),
                transition: context.transition
            )
            context.add(titleField
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + titleBackground.size.height / 2.0))
            )
            
            contentHeight += titleBackground.size.height + sectionSpacing
            
            if case let .edit(threadId, _, _) = context.component.mode, threadId == 1 {
                let hideBackground = hideBackground.update(
                    component: RoundedRectangle(
                        color: environment.theme.list.itemBlocksBackgroundColor,
                        cornerRadius: 10.0
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right, height: 44.0),
                    transition: context.transition
                )
                context.add(hideBackground
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + hideBackground.size.height / 2.0))
                )
                
                let hideTitle = hideTitle.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreateTopic_ShowGeneral,
                            font: Font.regular(17.0),
                            textColor: environment.theme.list.itemPrimaryTextColor,
                            paragraphAlignment: .natural)
                        ),
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 0
                    ),
                    availableSize: CGSize(
                        width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right,
                        height: CGFloat.greatestFiniteMagnitude
                    ),
                    transition: .immediate
                )
                context.add(hideTitle
                    .position(CGPoint(x: environment.safeInsets.left + sideInset + 16.0 + hideTitle.size.width / 2.0, y: contentHeight + hideBackground.size.height / 2.0))
                )
                
                let hideSwitch = hideSwitch.update(
                    component: SwitchComponent(
                        value: !state.isHidden,
                        valueUpdated: { [weak state] newValue in
                            state?.updateIsHidden(!newValue)
                        }
                    ),
                    availableSize: CGSize(
                        width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right,
                        height: CGFloat.greatestFiniteMagnitude
                    ),
                    transition: .immediate
                )
                context.add(hideSwitch
                    .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - sideInset - 16.0 - hideSwitch.size.width / 2.0, y: contentHeight + hideBackground.size.height / 2.0))
                )
                
                contentHeight += hideBackground.size.height
                
                let hideInfo = hideInfo.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreateTopic_ShowGeneralInfo,
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor,
                            paragraphAlignment: .natural)
                        ),
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 0
                    ),
                    availableSize: CGSize(
                        width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right,
                        height: CGFloat.greatestFiniteMagnitude
                    ),
                    transition: .immediate
                )
                context.add(hideInfo
                    .position(CGPoint(x: environment.safeInsets.left + sideInset + 16.0 + hideInfo.size.width / 2.0, y: contentHeight + 7.0 + hideInfo.size.height / 2.0))
                )
            } else {
                let iconHeader = iconHeader.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreateTopic_SelectTopicIcon,
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor,
                            paragraphAlignment: .natural)
                        ),
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(
                        width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right,
                        height: CGFloat.greatestFiniteMagnitude
                    ),
                    transition: .immediate
                )
                context.add(iconHeader
                    .position(CGPoint(x: environment.safeInsets.left + sideInset + 16.0 + iconHeader.size.width / 2.0, y: contentHeight + iconHeader.size.height / 2.0))
                )
                contentHeight += iconHeader.size.height + headerSpacing
                
                let bottomInset = max(environment.safeInsets.bottom, 12.0)
                
                let iconBackground = iconBackground.update(
                    component: RoundedRectangle(
                        color: environment.theme.list.itemBlocksBackgroundColor,
                        cornerRadius: 10.0
                    ),
                    availableSize: CGSize(
                        width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right,
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
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right, height: availableHeight),
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
                        openSearch: {
                        },
                        addGroupAction: { groupId, isPremiumLocked, _ in
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
                }
            }
            
            return context.availableSize
        }
    }
}

public class ForumCreateTopicScreen: ViewControllerComponentContainer {
    public static let iconColors: [Int32] = [0x6FB9F0, 0xFFD67E, 0xCB86DB, 0x8EEE98, 0xFF93B2, 0xFB6F5F]
    
    public enum Mode: Equatable {
        case create
        case edit(threadId: Int64, threadInfo: EngineMessageHistoryThread.Info, isHidden: Bool)
    }
    
    private let context: AccountContext
    private let mode: Mode
    
    private var doneBarItem: UIBarButtonItem?
    
    private var state: (title: String, icon: Int64?, iconColor: Int32, isHidden: Bool?) = ("", nil, 0, nil)
    public var completion: (_ title: String, _ icon: Int64?, _ iconColor: Int32, _ isHidden: Bool?) -> Void = { _, _, _, _ in }
    
    public var isInProgress: Bool = false {
        didSet {
            if self.isInProgress != oldValue {
                if self.isInProgress {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: presentationData.theme.rootController.navigationBar.accentTextColor))
                } else {
                    self.navigationItem.rightBarButtonItem = self.doneBarItem
                }
            }
        }
    }
    
    private let readyValue = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self.readyValue
    }
    
    public init(context: AccountContext, peerId: EnginePeer.Id, mode: ForumCreateTopicScreen.Mode) {
        self.context = context
        self.mode = mode
        
        var titleUpdatedImpl: ((String) -> Void)?
        var iconUpdatedImpl: ((Int64?) -> Void)?
        var iconColorUpdatedImpl: ((Int32) -> Void)?
        var isHiddenUpdatedImpl: ((Bool) -> Void)?
        var openPremiumImpl: (() -> Void)?
        
        let componentReady = Promise<Bool>()
        super.init(context: context, component: ForumCreateTopicScreenComponent(context: context, ready: componentReady, peerId: peerId, mode: mode, titleUpdated: { title in
            titleUpdatedImpl?(title)
        }, iconUpdated: { fileId in
            iconUpdatedImpl?(fileId)
        }, iconColorUpdated: { iconColor in
            iconColorUpdatedImpl?(iconColor)
        }, isHiddenUpdated: { isHidden in
            isHiddenUpdatedImpl?(isHidden)
        }, openPremium: {
            openPremiumImpl?()
        }), navigationBarAppearance: .transparent)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let title: String
        let doneTitle: String
        switch mode {
        case .create:
            title = presentationData.strings.CreateTopic_CreateTitle
            doneTitle = presentationData.strings.CreateTopic_Create
        case let .edit(threadId, topic, isHidden):
            title = presentationData.strings.CreateTopic_EditTitle
            doneTitle = presentationData.strings.Common_Done
            
            self.state = (topic.title, topic.icon, topic.iconColor, threadId == 1 ? isHidden : nil)
        }
        
        self.title = title
        
        self.readyValue.set(componentReady.get() |> timeout(0.3, queue: .mainQueue(), alternate: .single(true)))
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.doneBarItem = UIBarButtonItem(title: doneTitle, style: .done, target: self, action: #selector(self.createPressed))
        self.navigationItem.rightBarButtonItem = self.doneBarItem
        self.doneBarItem?.isEnabled = false
        
        if case .edit = mode {
            self.doneBarItem?.isEnabled = true
        }
        
        titleUpdatedImpl = { [weak self] title in
            guard let strongSelf = self else {
                return
            }
            strongSelf.doneBarItem?.isEnabled = !title.isEmpty
            
            strongSelf.state = (title, strongSelf.state.icon, strongSelf.state.iconColor, strongSelf.state.isHidden)
        }
        
        iconUpdatedImpl = { [weak self] fileId in
            guard let strongSelf = self else {
                return
            }
            strongSelf.state = (strongSelf.state.title, fileId, strongSelf.state.iconColor, strongSelf.state.isHidden)
        }
        
        iconColorUpdatedImpl = { [weak self] iconColor in
            guard let strongSelf = self else {
                return
            }
            strongSelf.state = (strongSelf.state.title, strongSelf.state.icon, iconColor, strongSelf.state.isHidden)
        }
        
        isHiddenUpdatedImpl = { [weak self] isHidden in
            guard let strongSelf = self else {
                return
            }
            strongSelf.state = (strongSelf.state.title, strongSelf.state.icon, strongSelf.state.iconColor, isHidden)
        }
        
        openPremiumImpl = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            var replaceImpl: ((ViewController) -> Void)?
            let controller = PremiumDemoScreen(context: context, subject: .animatedEmoji, action: {
                let controller = PremiumIntroScreen(context: context, source: .animatedEmoji)
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
        self.completion(self.state.title, self.state.icon, self.state.iconColor, self.state.isHidden)
    }
}
