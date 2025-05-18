import Foundation
import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import Postbox
import MultilineTextComponent
import AvatarNode
import TelegramPresentationData
import CheckNode
import TelegramStringFormatting
import AppBundle
import PeerPresenceStatusManager
import EmojiStatusComponent
import ContextUI
import EmojiTextAttachmentView
import TextFormat
import PhotoResources
import ListSectionComponent
import ListItemSwipeOptionContainer

private let avatarFont = avatarPlaceholderFont(size: 15.0)
private let readIconImage: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/MenuReadIcon"), color: .white)?.withRenderingMode(.alwaysTemplate)
private let repostIconImage: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Stories/HeaderRepost"), color: .white)?.withRenderingMode(.alwaysTemplate)
private let forwardIconImage: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Stories/HeaderForward"), color: .white)?.withRenderingMode(.alwaysTemplate)
private let checkImage: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: .white)?.withRenderingMode(.alwaysTemplate)

private func generateDisclosureImage() -> UIImage? {
    return generateImage(CGSize(width: 7.0, height: 12.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(UIColor.white.cgColor)
        
        let lineWidth: CGFloat = 2.0
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        
        context.move(to: CGPoint(x: lineWidth * 0.5, y: lineWidth * 0.5))
        context.addLine(to: CGPoint(x: size.width - lineWidth * 0.5, y: size.height * 0.5))
        context.addLine(to: CGPoint(x: lineWidth * 0.5, y: size.height - lineWidth * 0.5))
        context.strokePath()
    })?.withRenderingMode(.alwaysTemplate)
}
private let disclosureImage: UIImage? = generateDisclosureImage()

public final class PeerListItemComponent: Component {
    public final class TransitionHint {
        public let synchronousLoad: Bool
        
        public init(synchronousLoad: Bool) {
            self.synchronousLoad = synchronousLoad
        }
    }
    
    public enum Style {
        case generic
        case compact
    }
    
    public enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool, isTinted: Bool)
    }
    
    public enum SelectionPosition: Equatable {
        case left
        case right
    }
    
    public enum SubtitleAccessory: Equatable {
        case none
        case checks
        case repost
        case forward
    }
    
    public enum RightAccessory: Equatable {
        case none
        case disclosure
        case check
    }
    
    public struct Avatar: Equatable {
        public var icon: String
        public var color: AvatarBackgroundColor
        public var clipStyle: AvatarNodeClipStyle
        
        public init(icon: String, color: AvatarBackgroundColor, clipStyle: AvatarNodeClipStyle) {
            self.icon = icon
            self.color = color
            self.clipStyle = clipStyle
        }
    }
    
    public final class InlineAction: Equatable {
        public enum Color: Equatable {
            case destructive
        }
        
        public let id: AnyHashable
        public let title: String
        public let color: Color
        public let action: () -> Void
        
        public init(id: AnyHashable, title: String, color: Color, action: @escaping () -> Void) {
            self.id = id
            self.title = title
            self.color = color
            self.action = action
        }
        
        public static func ==(lhs: InlineAction, rhs: InlineAction) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.color != rhs.color {
                return false
            }
            return true
        }
    }
    
    public final class InlineActionsState: Equatable {
        public let actions: [InlineAction]
        
        public init(actions: [InlineAction]) {
            self.actions = actions
        }
        
        public static func ==(lhs: InlineActionsState, rhs: InlineActionsState) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.actions != rhs.actions {
                return false
            }
            return true
        }
    }
    
    public final class Reaction: Equatable {
        public let reaction: MessageReaction.Reaction
        public let file: TelegramMediaFile?
        public let animationFileId: Int64?
        
        public init(
            reaction: MessageReaction.Reaction,
            file: TelegramMediaFile?,
            animationFileId: Int64?
        ) {
            self.reaction = reaction
            self.file = file
            self.animationFileId = animationFileId
        }
        
        public static func ==(lhs: Reaction, rhs: Reaction) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.reaction != rhs.reaction {
                return false
            }
            if lhs.file?.fileId != rhs.file?.fileId {
                return false
            }
            if lhs.animationFileId != rhs.animationFileId {
                return false
            }
            
            return true
        }
    }
    
    public struct Subtitle: Equatable {
        public enum Color: Equatable {
            case neutral
            case accent
            case constructive
        }
        
        public var text: String
        public var color: Color
        
        public init(text: String, color: Color) {
            self.text = text
            self.color = color
        }
    }
    
    public final class ExtractedTheme: Equatable {
        public let inset: CGFloat
        public let background: UIColor
        
        public init(inset: CGFloat, background: UIColor) {
            self.inset = inset
            self.background = background
        }
        
        public static func ==(lhs: ExtractedTheme, rhs: ExtractedTheme) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.inset != rhs.inset {
                return false
            }
            if lhs.background != rhs.background {
                return false
            }
            return true
        }
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let style: Style
    let sideInset: CGFloat
    let title: String
    let avatar: Avatar?
    let avatarComponent: AnyComponent<Empty>?
    let peer: EnginePeer?
    let storyStats: PeerStoryStats?
    let subtitle: Subtitle?
    let subtitleComponent: AnyComponent<Empty>?
    let subtitleAccessory: SubtitleAccessory
    let presence: EnginePeer.Presence?
    let rightAccessory: RightAccessory
    let rightAccessoryComponent: AnyComponentWithIdentity<Empty>?
    let reaction: Reaction?
    let story: EngineStoryItem?
    let message: EngineMessage?
    let selectionState: SelectionState
    let selectionPosition: SelectionPosition
    let isEnabled: Bool
    let hasNext: Bool
    let extractedTheme: ExtractedTheme?
    let insets: UIEdgeInsets?
    let action: ((EnginePeer, EngineMessage.Id?, PeerListItemComponent.View) -> Void)?
    let inlineActions: InlineActionsState?
    let contextAction: ((EnginePeer, ContextExtractedContentContainingView, ContextGesture) -> Void)?
    let openStories: ((EnginePeer, AvatarNode) -> Void)?
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        style: Style,
        sideInset: CGFloat,
        title: String,
        avatar: Avatar? = nil,
        avatarComponent: AnyComponent<Empty>? = nil,
        peer: EnginePeer?,
        storyStats: PeerStoryStats? = nil,
        subtitle: Subtitle?,
        subtitleComponent: AnyComponent<Empty>? = nil,
        subtitleAccessory: SubtitleAccessory,
        presence: EnginePeer.Presence?,
        rightAccessory: RightAccessory = .none,
        rightAccessoryComponent: AnyComponentWithIdentity<Empty>? = nil,
        reaction: Reaction? = nil,
        story: EngineStoryItem? = nil,
        message: EngineMessage? = nil,
        selectionState: SelectionState,
        selectionPosition: SelectionPosition = .left,
        isEnabled: Bool = true,
        hasNext: Bool,
        extractedTheme: ExtractedTheme? = nil,
        insets: UIEdgeInsets? = nil,
        action: ((EnginePeer, EngineMessage.Id?, PeerListItemComponent.View) -> Void)?,
        inlineActions: InlineActionsState? = nil,
        contextAction: ((EnginePeer, ContextExtractedContentContainingView, ContextGesture) -> Void)? = nil,
        openStories: ((EnginePeer, AvatarNode) -> Void)? = nil
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.style = style
        self.sideInset = sideInset
        self.title = title
        self.avatar = avatar
        self.avatarComponent = avatarComponent
        self.peer = peer
        self.storyStats = storyStats
        self.subtitle = subtitle
        self.subtitleComponent = subtitleComponent
        self.subtitleAccessory = subtitleAccessory
        self.presence = presence
        self.rightAccessory = rightAccessory
        self.rightAccessoryComponent = rightAccessoryComponent
        self.reaction = reaction
        self.story = story
        self.message = message
        self.selectionState = selectionState
        self.selectionPosition = selectionPosition
        self.isEnabled = isEnabled
        self.hasNext = hasNext
        self.extractedTheme = extractedTheme
        self.insets = insets
        self.action = action
        self.inlineActions = inlineActions
        self.contextAction = contextAction
        self.openStories = openStories
    }
    
    public static func ==(lhs: PeerListItemComponent, rhs: PeerListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.avatar != rhs.avatar {
            return false
        }
        if lhs.avatarComponent != rhs.avatarComponent {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.storyStats != rhs.storyStats {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.subtitleComponent != rhs.subtitleComponent {
            return false
        }
        if lhs.subtitleAccessory != rhs.subtitleAccessory {
            return false
        }
        if lhs.presence != rhs.presence {
            return false
        }
        if lhs.rightAccessory != rhs.rightAccessory {
            return false
        }
        if lhs.rightAccessoryComponent != rhs.rightAccessoryComponent {
            return false
        }
        if lhs.reaction != rhs.reaction {
            return false
        }
        if lhs.story != rhs.story {
            return false
        }
        if lhs.message != rhs.message {
            return false
        }
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        if lhs.selectionPosition != rhs.selectionPosition {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.extractedTheme != rhs.extractedTheme {
            return false
        }
        if lhs.inlineActions != rhs.inlineActions {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        if (lhs.contextAction == nil) != (rhs.contextAction == nil) {
            return false
        }
        return true
    }
    
    public final class View: ContextControllerSourceView, ListSectionComponent.ChildView {
        public let extractedContainerView: ContextExtractedContentContainingView
        private let containerButton: HighlightTrackingButton
        
        private let swipeOptionContainer: ListItemSwipeOptionContainer
        
        private let title = ComponentView<Empty>()
        private var label = ComponentView<Empty>()
        private var subtitleView: ComponentView<Empty>?
        private let separatorLayer: SimpleLayer
        private var avatarNode: AvatarNode?
        private var avatarImageView: UIImageView?
        private let avatarButtonView: HighlightTrackingButton
        private var avatarIcon: ComponentView<Empty>?
        
        private var avatarComponentView: ComponentView<Empty>?
        
        private var rightIconView: UIImageView?
        private var iconView: UIImageView?
        private var checkLayer: CheckLayer?
        private var rightAccessoryComponentView: ComponentView<Empty>?
        
        private var reactionLayer: InlineStickerItemLayer?
        private var heartReactionIcon: UIImageView?
        private var iconFrame: CGRect?
        private var file: TelegramMediaFile?
        private var fileDisposable: Disposable?
        
        private var imageButtonView: HighlightTrackingButton?
        public private(set) var imageNode: TransformImageNode?
        
        private var component: PeerListItemComponent?
        private weak var state: EmptyComponentState?
        
        private var presenceManager: PeerPresenceStatusManager?
        
        public var avatarFrame: CGRect {
            if let avatarComponentView = self.avatarComponentView, let avatarComponentViewImpl = avatarComponentView.view {
                return avatarComponentViewImpl.frame
            } else if let avatarNode = self.avatarNode {
                return avatarNode.frame
            } else {
                return CGRect(origin: CGPoint(), size: CGSize())
            }
        }
        
        public var titleFrame: CGRect? {
            return self.title.view?.frame
        }
        
        public var labelFrame: CGRect? {
            guard var value = self.label.view?.frame else {
                return nil
            }
            if let iconView = self.iconView {
                value.size.width += value.minX - iconView.frame.minX
                value.origin.x = iconView.frame.minX
            }
            return value
        }
        
        private var isExtractedToContextMenu: Bool = false
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public private(set) var separatorInset: CGFloat = 0.0
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            
            self.extractedContainerView = ContextExtractedContentContainingView()
            self.containerButton = HighlightTrackingButton()
            self.containerButton.layer.anchorPoint = CGPoint()
            self.containerButton.isExclusiveTouch = true
            
            self.swipeOptionContainer = ListItemSwipeOptionContainer(frame: CGRect())
            
            self.avatarButtonView = HighlightTrackingButton()
            
            super.init(frame: frame)
            
            self.addSubview(self.extractedContainerView)
            self.targetViewForActivationProgress = self.extractedContainerView.contentView
            
            self.extractedContainerView.contentView.addSubview(self.swipeOptionContainer)
            
            self.swipeOptionContainer.addSubview(self.containerButton)
            
            self.layer.addSublayer(self.separatorLayer)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.addSubview(self.avatarButtonView)
            self.avatarButtonView.addTarget(self, action: #selector(self.avatarButtonPressed), for: .touchUpInside)
            
            self.extractedContainerView.isExtractedToContextPreviewUpdated = { [weak self] value in
                guard let self, let component = self.component else {
                    return
                }
                
                let extractedBackgroundColor: UIColor
                if let extractedTheme = component.extractedTheme {
                    extractedBackgroundColor = extractedTheme.background
                } else {
                    extractedBackgroundColor = component.theme.rootController.navigationBar.blurredBackgroundColor
                }
                
                self.containerButton.clipsToBounds = value
                self.containerButton.backgroundColor = value ? extractedBackgroundColor : nil
                self.containerButton.layer.cornerRadius = value ? 10.0 : 0.0
            }
            self.extractedContainerView.willUpdateIsExtractedToContextPreview = { [weak self] value, transition in
                guard let self else {
                    return
                }
                self.isExtractedToContextMenu = value
                
                let mappedTransition: ComponentTransition
                if value {
                    mappedTransition = ComponentTransition(transition)
                } else {
                    mappedTransition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                }
                self.state?.updated(transition: mappedTransition)
            }
            
            self.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component, let peer = component.peer else {
                    gesture.cancel()
                    return
                }
                component.contextAction?(peer, self.extractedContainerView, gesture)
            }
            
            self.containerButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if let customUpdateIsHighlighted = self.customUpdateIsHighlighted {
                    customUpdateIsHighlighted(highlighted)
                }
            }
            
            self.swipeOptionContainer.updateRevealOffset = { [weak self] offset, transition in
                guard let self else {
                    return
                }
                transition.setBounds(view: self.containerButton, bounds: CGRect(origin: CGPoint(x: -offset, y: 0.0), size: self.containerButton.bounds.size))
            }
            self.swipeOptionContainer.revealOptionSelected = { [weak self] option, _ in
                guard let self, let component = self.component else {
                    return
                }
                guard let inlineActions = component.inlineActions else {
                    return
                }
                self.swipeOptionContainer.setRevealOptionsOpened(false, animated: true)
                if let inlineAction = inlineActions.actions.first(where: { $0.id == option.key }) {
                    inlineAction.action()
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.fileDisposable?.dispose()
        }
        
        @objc private func pressed() {
            guard let component = self.component, let peer = component.peer else {
                return
            }
            component.action?(peer, component.message?.id, self)
        }
        
        @objc private func avatarButtonPressed() {
            guard let component = self.component, let peer = component.peer else {
                return
            }
            if let avatarNode = self.avatarNode {
                component.openStories?(peer, avatarNode)
            }
        }
        
        private func updateReactionLayer() {
            guard let component = self.component else {
                return
            }
            
            if let reactionLayer = self.reactionLayer {
                self.reactionLayer = nil
                reactionLayer.removeFromSuperlayer()
            }
            
            guard let file = self.file else {
                return
            }
            
            let reactionLayer = InlineStickerItemLayer(
                context: component.context,
                userLocation: .other,
                attemptSynchronousLoad: false,
                emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file),
                file: file,
                cache: component.context.animationCache,
                renderer: component.context.animationRenderer,
                placeholderColor: UIColor(white: 0.0, alpha: 0.1),
                pointSize: CGSize(width: 64.0, height: 64.0)
            )
            self.reactionLayer = reactionLayer
            
            if let reaction = component.reaction, case .custom = reaction.reaction {
                reactionLayer.isVisibleForAnimations = true
            }
            self.containerButton.layer.addSublayer(reactionLayer)
            
            if var iconFrame = self.iconFrame {
                if let reaction = component.reaction, case .builtin = reaction.reaction {
                    iconFrame = iconFrame.insetBy(dx: -iconFrame.width * 0.5, dy: -iconFrame.height * 0.5)
                }
                reactionLayer.frame = iconFrame
            }
        }
        
        public func updateIsPreviewing(isPreviewing: Bool) {
            self.imageNode?.isHidden = isPreviewing
        }
        
        func update(component: PeerListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            
            var synchronousLoad = false
            if let hint = transition.userData(TransitionHint.self) {
                synchronousLoad = hint.synchronousLoad
            }
            
            self.isGestureEnabled = component.contextAction != nil
            
            let themeUpdated = self.component?.theme !== component.theme
            
            var hasSelectionUpdated = false
            if let previousComponent = self.component {
                switch previousComponent.selectionState {
                case .none:
                    if case .none = component.selectionState {
                    } else {
                        hasSelectionUpdated = true
                    }
                case .editing:
                    if case .editing = component.selectionState {
                    } else {
                        hasSelectionUpdated = true
                    }
                }
            }
            
            if let presence = component.presence {
                let presenceManager: PeerPresenceStatusManager
                if let current = self.presenceManager {
                    presenceManager = current
                } else {
                    presenceManager = PeerPresenceStatusManager(update: { [weak self] in
                        self?.state?.updated(transition: .immediate)
                    })
                    self.presenceManager = presenceManager
                }
                presenceManager.reset(presence: presence)
            } else {
                if self.presenceManager != nil {
                    self.presenceManager = nil
                }
            }
            
            self.component = component
            self.state = state
            
            self.containerButton.alpha = component.isEnabled ? 1.0 : 0.3
            self.containerButton.isEnabled = component.action != nil
            
            self.avatarButtonView.isUserInteractionEnabled = component.storyStats != nil && component.openStories != nil
            
            let labelData: (String, Subtitle.Color)
            if let presence = component.presence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                let dateTimeFormat = component.context.sharedContext.currentPresentationData.with { $0 }.dateTimeFormat
                let labelDataValue = stringAndActivityForUserPresence(strings: component.strings, dateTimeFormat: dateTimeFormat, presence: presence, relativeTo: Int32(timestamp))
                labelData = (labelDataValue.0, labelDataValue.1 ? .accent : .neutral)
            } else if let subtitle = component.subtitle {
                labelData = (subtitle.text, subtitle.color)
            } else {
                labelData = ("", .neutral)
            }
            
            let contextInset: CGFloat
            if self.isExtractedToContextMenu {
                if let extractedTheme = component.extractedTheme {
                    contextInset = extractedTheme.inset
                } else {
                    contextInset = 12.0
                }
            } else {
                contextInset = 0.0
            }
            
            let verticalInset: CGFloat = component.insets?.top ?? 1.0
            
            var leftInset: CGFloat = 53.0 + component.sideInset
            if case .generic = component.style {
                leftInset += 9.0
            }
            var rightInset: CGFloat = contextInset * 2.0 + 8.0 + component.sideInset
            if component.reaction != nil || component.rightAccessory != .none {
                rightInset += 32.0
            }
            if component.story != nil {
                rightInset += 40.0
            }
            
            var subtitleComponentSize: CGSize?
            if let subtitleComponent = component.subtitleComponent {
                let subtitleView: ComponentView<Empty>
                if let current = self.subtitleView {
                    subtitleView = current
                } else {
                    subtitleView = ComponentView()
                    self.subtitleView = subtitleView
                }
                subtitleComponentSize = subtitleView.update(
                    transition: transition,
                    component: subtitleComponent,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
                )
            } else if let subtitleView = self.subtitleView {
                self.subtitleView = nil
                subtitleView.view?.removeFromSuperview()
            }
            
            var height: CGFloat
            let titleFont: UIFont
            let subtitleFont: UIFont
            switch component.style {
            case .generic:
                titleFont = Font.semibold(17.0)
                subtitleFont = Font.regular(15.0)
                if let subtitleComponentSize {
                    height = 40.0 + subtitleComponentSize.height + verticalInset * 2.0
                } else if labelData.0.isEmpty {
                    height = 48.0 + verticalInset * 2.0
                } else {
                    height = 58.0 + verticalInset * 2.0
                }
            case .compact:
                titleFont = Font.semibold(14.0)
                subtitleFont = Font.regular(14.0)
                if let subtitleComponentSize {
                    height = 20.0 + subtitleComponentSize.height + verticalInset * 2.0
                } else {
                    height = 40.0 + verticalInset * 2.0
                }
            }

            if let rightAccessoryComponentView = self.rightAccessoryComponentView, component.rightAccessoryComponent?.id != previousComponent?.rightAccessoryComponent?.id {
                self.rightAccessoryComponentView = nil
                rightAccessoryComponentView.view?.removeFromSuperview()
            }
            
            var rightAccessoryComponentSize: CGSize?
            if let rightAccessoryComponent = component.rightAccessoryComponent?.component {
                var rightAccessoryComponentTransition = transition
                let rightAccessoryComponentView: ComponentView<Empty>
                if let current = self.rightAccessoryComponentView {
                    rightAccessoryComponentView = current
                } else {
                    rightAccessoryComponentTransition = rightAccessoryComponentTransition.withAnimation(.none)
                    rightAccessoryComponentView = ComponentView()
                    self.rightAccessoryComponentView = rightAccessoryComponentView
                }
                rightAccessoryComponentSize = rightAccessoryComponentView.update(
                    transition: rightAccessoryComponentTransition,
                    component: rightAccessoryComponent,
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            } else if let rightAccessoryComponentView = self.rightAccessoryComponentView {
                self.rightAccessoryComponentView = nil
                rightAccessoryComponentView.view?.removeFromSuperview()
            }
            if let rightAccessoryComponentSize {
                rightInset += 8.0 + rightAccessoryComponentSize.width
            }
            
            var avatarLeftInset: CGFloat = component.sideInset + 10.0
            
            if case let .editing(isSelected, isTinted) = component.selectionState {
                let checkSize: CGFloat = 22.0
                let checkOriginX: CGFloat
                switch component.selectionPosition {
                case .left:
                    leftInset += 44.0
                    avatarLeftInset += 44.0
                    checkOriginX = floor((54.0 - checkSize) * 0.5)
                case .right:
                    rightInset += 44.0
                    checkOriginX = availableSize.width - 11.0 - checkSize
                }
                
                let checkLayer: CheckLayer
                if let current = self.checkLayer {
                    checkLayer = current
                    if themeUpdated {
                        var theme = CheckNodeTheme(theme: component.theme, style: .plain)
                        if isTinted {
                            theme.backgroundColor = theme.backgroundColor.mixedWith(component.theme.list.itemBlocksBackgroundColor, alpha: 0.5)
                        }
                        checkLayer.theme = theme
                    }
                    checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
                } else {
                    var theme = CheckNodeTheme(theme: component.theme, style: .plain)
                    if isTinted {
                        theme.backgroundColor = theme.backgroundColor.mixedWith(component.theme.list.itemBlocksBackgroundColor, alpha: 0.5)
                    }
                    checkLayer = CheckLayer(theme: theme)
                    self.checkLayer = checkLayer
                    self.containerButton.layer.addSublayer(checkLayer)
                    checkLayer.frame = CGRect(origin: CGPoint(x: -checkSize, y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize))
                    checkLayer.setSelected(isSelected, animated: false)
                    checkLayer.setNeedsDisplay()
                }
                transition.setFrame(layer: checkLayer, frame: CGRect(origin: CGPoint(x: checkOriginX, y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize)))
            } else {
                if let checkLayer = self.checkLayer {
                    self.checkLayer = nil
                    transition.setPosition(layer: checkLayer, position: CGPoint(x: -checkLayer.bounds.width * 0.5, y: checkLayer.position.y), completion: { [weak checkLayer] _ in
                        checkLayer?.removeFromSuperlayer()
                    })
                }
            }
            
            let avatarSize: CGFloat = component.style == .compact ? 30.0 : 40.0
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarLeftInset, y: floorToScreenPixels((height - verticalInset * 2.0 - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
            
            var statusIcon: EmojiStatusComponent.Content?
            var particleColor: UIColor?
            if let peer = component.peer {
                if peer.isScam {
                    statusIcon = .text(color: component.theme.chat.message.incoming.scamColor, string: component.strings.Message_ScamAccount.uppercased())
                } else if peer.isFake {
                    statusIcon = .text(color: component.theme.chat.message.incoming.scamColor, string: component.strings.Message_FakeAccount.uppercased())
                } else if let emojiStatus = peer.emojiStatus {
                    statusIcon = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 20.0, height: 20.0), placeholderColor: component.theme.list.mediaPlaceholderColor, themeColor: component.theme.list.itemAccentColor, loopMode: .count(2))
                    if let color = emojiStatus.color {
                        particleColor = UIColor(rgb: UInt32(bitPattern: color))
                    }
                } else if peer.isVerified {
                    statusIcon = .verified(fillColor: component.theme.list.itemCheckColors.fillColor, foregroundColor: component.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
                } else if peer.isPremium {
                    statusIcon = .premium(color: component.theme.list.itemAccentColor)
                }
            }
            
            if let avatarComponent = component.avatarComponent {
                let avatarComponentView: ComponentView<Empty>
                var avatarComponentTransition = transition
                if let current = self.avatarComponentView {
                    avatarComponentView = current
                } else {
                    avatarComponentTransition = avatarComponentTransition.withAnimation(.none)
                    avatarComponentView = ComponentView()
                    self.avatarComponentView = avatarComponentView
                }
                
                let _ = avatarComponentView.update(
                    transition: avatarComponentTransition,
                    component: avatarComponent,
                    environment: {},
                    containerSize: avatarFrame.size
                )
                if let avatarComponentViewImpl = avatarComponentView.view {
                    if avatarComponentViewImpl.superview == nil {
                        self.containerButton.insertSubview(avatarComponentViewImpl, at: 0)
                    }
                    avatarComponentTransition.setFrame(view: avatarComponentViewImpl, frame: avatarFrame)
                }
                
                if let avatarNode = self.avatarNode {
                    self.avatarNode = nil
                    avatarNode.layer.removeFromSuperlayer()
                }
            } else {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarFont)
                    avatarNode.isLayerBacked = false
                    avatarNode.isUserInteractionEnabled = false
                    self.avatarNode = avatarNode
                    self.containerButton.layer.insertSublayer(avatarNode.layer, at: 0)
                }
                
                if avatarNode.bounds.isEmpty {
                    avatarNode.frame = avatarFrame
                } else {
                    transition.setFrame(layer: avatarNode.layer, frame: avatarFrame)
                }
                
                if let peer = component.peer {
                    let clipStyle: AvatarNodeClipStyle
                    if case let .channel(channel) = peer, channel.isForumOrMonoForum {
                        clipStyle = .roundedRect
                    } else {
                        clipStyle = .round
                    }
                    let _ = clipStyle
                    let _ = synchronousLoad
                    
                    if peer.smallProfileImage != nil {
                        avatarNode.setPeerV2(
                            context: component.context,
                            theme: component.theme,
                            peer: peer,
                            authorOfMessage: nil,
                            overrideImage: nil,
                            emptyColor: nil,
                            clipStyle: .round,
                            synchronousLoad: synchronousLoad,
                            displayDimensions: CGSize(width: avatarSize, height: avatarSize)
                        )
                    } else {
                        avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, clipStyle: clipStyle, synchronousLoad: synchronousLoad, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                    }
                    avatarNode.setStoryStats(storyStats: component.storyStats.flatMap { storyStats -> AvatarNode.StoryStats in
                        return AvatarNode.StoryStats(
                            totalCount: storyStats.totalCount == 0 ? 0 : 1,
                            unseenCount: storyStats.unseenCount == 0 ? 0 : 1,
                            hasUnseenCloseFriendsItems: storyStats.hasUnseenCloseFriends
                        )
                    }, presentationParams: AvatarNode.StoryPresentationParams(
                        colors: AvatarNode.Colors(theme: component.theme),
                        lineWidth: 1.33,
                        inactiveLineWidth: 1.33
                    ), transition: transition)
                    avatarNode.isHidden = false
                } else {
                    avatarNode.isHidden = true
                }
                
                if let avatarComponentView = self.avatarComponentView {
                    self.avatarComponentView = nil
                    avatarComponentView.view?.removeFromSuperview()
                }
            }
            
            transition.setFrame(view: self.avatarButtonView, frame: avatarFrame)
            
            if let avatar = component.avatar {
                let avatarImageView: UIImageView
                if let current = self.avatarImageView {
                    avatarImageView = current
                } else {
                    avatarImageView = UIImageView()
                    self.avatarImageView = avatarImageView
                    self.containerButton.addSubview(avatarImageView)
                }
                if previousComponent?.avatar != avatar {
                    avatarImageView.image = generateAvatarImage(size: avatarFrame.size, icon: generateTintedImage(image: UIImage(bundleImageName: avatar.icon), color: .white), cornerRadius: 12.0, color: avatar.color)
                }
                transition.setFrame(view: avatarImageView, frame: avatarFrame)
            } else {
                if let avatarImageView = self.avatarImageView {
                    self.avatarImageView = nil
                    avatarImageView.removeFromSuperview()
                }
            }
                        
            let previousTitleFrame = self.title.view?.frame
            var previousTitleContents: UIView?
            if hasSelectionUpdated && !"".isEmpty {
                previousTitleContents = self.title.view?.snapshotView(afterScreenUpdates: false)
            }
            
            let availableTextWidth = availableSize.width - leftInset - rightInset
            var titleAvailableWidth = component.style == .compact ? availableTextWidth * 0.7 : availableSize.width - leftInset - rightInset
            switch component.rightAccessory {
            case .disclosure:
                titleAvailableWidth -= 32.0
            case .check:
                titleAvailableWidth -= 20.0
            case .none:
                break
            }
            
            if statusIcon != nil {
                titleAvailableWidth -= 14.0
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: titleFont, textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: titleAvailableWidth, height: 100.0)
            )
            
            let labelAvailableWidth = component.style == .compact ? availableTextWidth - titleSize.width : availableSize.width - leftInset - rightInset
            let labelColor: UIColor
            switch labelData.1 {
            case .neutral:
                labelColor = component.theme.list.itemSecondaryTextColor
            case .accent:
                labelColor = component.theme.list.itemAccentColor
            case .constructive:
                //TODO:release
                labelColor = UIColor(rgb: 0x33C758)
            }
            
            var animateLabelDirection: Bool?
            if !transition.animation.isImmediate, let previousComponent, let previousSubtitle = previousComponent.subtitle, let subtitle = component.subtitle, subtitle.color != previousSubtitle.color {
                let animateLabelDirectionValue: Bool
                if case .constructive = subtitle.color {
                    animateLabelDirectionValue = true
                } else {
                    animateLabelDirectionValue = false
                }
                animateLabelDirection = animateLabelDirectionValue
                if let labelView = self.label.view {
                    transition.setPosition(view: labelView, position: labelView.center.offsetBy(dx: 0.0, dy: animateLabelDirectionValue ? -6.0 : 6.0))
                    labelView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak labelView] _ in
                        labelView?.removeFromSuperview()
                    })
                }
                self.label = ComponentView()
            }
            
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: labelData.0, font: subtitleFont, textColor: labelColor))
                )),
                environment: {},
                containerSize: CGSize(width: labelAvailableWidth, height: 100.0)
            )
            
            let titleSpacing: CGFloat = 2.0
            let titleVerticalOffset: CGFloat = 0.0
            let centralContentHeight: CGFloat
            if let subtitleComponentSize {
                centralContentHeight = titleSize.height + subtitleComponentSize.height + titleSpacing
            } else if labelSize.height > 0.0, case .generic = component.style {
                centralContentHeight = titleSize.height + labelSize.height + titleSpacing
            } else {
                centralContentHeight = titleSize.height
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: titleVerticalOffset + floor((height - verticalInset * 2.0 - centralContentHeight) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
                if let previousTitleFrame, previousTitleFrame.origin.x != titleFrame.origin.x {
                    transition.animatePosition(view: titleView, from: CGPoint(x: previousTitleFrame.origin.x - titleFrame.origin.x, y: 0.0), to: CGPoint(), additive: true)
                }
                
                if let previousTitleFrame, let previousTitleContents, previousTitleFrame.size != titleSize {
                    previousTitleContents.frame = CGRect(origin: previousTitleFrame.origin, size: previousTitleFrame.size)
                    self.addSubview(previousTitleContents)
                    
                    transition.setFrame(view: previousTitleContents, frame: CGRect(origin: titleFrame.origin, size: previousTitleFrame.size))
                    transition.setAlpha(view: previousTitleContents, alpha: 0.0, completion: { [weak previousTitleContents] _ in
                        previousTitleContents?.removeFromSuperview()
                    })
                    transition.animateAlpha(view: titleView, from: 0.0, to: 1.0)
                }
            }
            
            if let statusIcon, case .generic = component.style {
                let animationCache = component.context.animationCache
                let animationRenderer = component.context.animationRenderer
                
                let avatarIcon: ComponentView<Empty>
                var avatarIconTransition = transition
                if let current = self.avatarIcon {
                    avatarIcon = current
                } else {
                    avatarIconTransition = transition.withAnimation(.none)
                    avatarIcon = ComponentView<Empty>()
                    self.avatarIcon = avatarIcon
                }
                
                let avatarIconComponent = EmojiStatusComponent(
                    context: component.context,
                    animationCache: animationCache,
                    animationRenderer: animationRenderer,
                    content: statusIcon,
                    particleColor: particleColor,
                    isVisibleForAnimations: true,
                    action: nil,
                    emojiFileUpdated: nil
                )
                let iconSize = avatarIcon.update(
                    transition: avatarIconTransition,
                    component: AnyComponent(avatarIconComponent),
                    environment: {},
                    containerSize: CGSize(width: 20.0, height: 20.0)
                )
                
                if let avatarIconView = avatarIcon.view {
                    if avatarIconView.superview == nil {
                        avatarIconView.isUserInteractionEnabled = false
                        self.containerButton.addSubview(avatarIconView)
                    }
                    avatarIconTransition.setFrame(view: avatarIconView, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floorToScreenPixels(titleFrame.midY - iconSize.height / 2.0)), size: iconSize))
                }
            } else if let avatarIcon = self.avatarIcon {
                self.avatarIcon = nil
                avatarIcon.view?.removeFromSuperview()
            }
            
            if let labelView = self.label.view {
                var iconLabelOffset: CGFloat = 0.0
                
                if case .none = component.subtitleAccessory {
                    if let iconView = self.iconView {
                        self.iconView = nil
                        iconView.removeFromSuperview()
                    }
                } else {
                    let iconView: UIImageView
                    if let current = self.iconView {
                        iconView = current
                    } else {
                        var image: UIImage?
                        var color: UIColor = component.theme.list.itemSecondaryTextColor
                        if case .checks = component.subtitleAccessory {
                            image = readIconImage
                        } else if case .repost = component.subtitleAccessory {
                            image = repostIconImage
                            color = UIColor(rgb: 0x34c759)
                        } else if case .forward = component.subtitleAccessory {
                            image = forwardIconImage
                            color = UIColor(rgb: 0x34c759)
                        }
                        iconView = UIImageView(image: image)
                        iconView.tintColor = color
                        self.iconView = iconView
                        self.containerButton.addSubview(iconView)
                    }
                    
                    if let image = iconView.image {
                        iconLabelOffset = image.size.width + 4.0
                        transition.setFrame(view: iconView, frame: CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + titleSpacing + 2.0 + floor((labelSize.height - image.size.height) * 0.5)), size: image.size))
                    }
                }
                
                let labelFrame: CGRect
                switch component.style {
                case .generic:
                    labelFrame = CGRect(origin: CGPoint(x: titleFrame.minX + iconLabelOffset, y: titleFrame.maxY + titleSpacing), size: labelSize)
                case .compact:
                    labelFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floor((height - verticalInset * 2.0 - centralContentHeight) / 2.0)), size: labelSize)
                }
                
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    labelView.layer.anchorPoint = CGPoint()
                    self.containerButton.addSubview(labelView)
                    
                    labelView.center = labelFrame.origin
                } else {
                    transition.setPosition(view: labelView, position: labelFrame.origin)
                }
                
                labelView.bounds = CGRect(origin: CGPoint(), size: labelFrame.size)
                
                if let animateLabelDirection {
                    transition.animatePosition(view: labelView, from: CGPoint(x: 0.0, y: animateLabelDirection ? 6.0 : -6.0), to: CGPoint(), additive: true)
                    if !transition.animation.isImmediate {
                        labelView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                    }
                }
            }
            
            if let subtitleComponentView = self.subtitleView?.view, let subtitleComponentSize {
                let subtitleFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + titleSpacing), size: subtitleComponentSize)

                if subtitleComponentView.superview == nil {
                    subtitleComponentView.isUserInteractionEnabled = false
                    subtitleComponentView.layer.anchorPoint = CGPoint()
                    self.containerButton.addSubview(subtitleComponentView)
                }
                transition.setFrame(view: subtitleComponentView, frame: subtitleFrame)
            }
            
            let imageSize = CGSize(width: 22.0, height: 22.0)
            self.iconFrame = CGRect(origin: CGPoint(x: availableSize.width - (contextInset * 2.0 + 14.0 + component.sideInset) - imageSize.width, y: floor((height - verticalInset * 2.0 - imageSize.height) * 0.5)), size: imageSize)
            
            if case .none = component.rightAccessory {
                if case .none = component.subtitleAccessory {
                    if let rightIconView = self.rightIconView {
                        self.rightIconView = nil
                        rightIconView.removeFromSuperview()
                    }
                }
            } else {
                let rightIconView: UIImageView
                if let current = self.rightIconView {
                    rightIconView = current
                } else {
                    var image: UIImage?
                    var color: UIColor = component.theme.list.itemSecondaryTextColor
                    switch component.rightAccessory {
                    case .check:
                        image = checkImage
                        color = component.theme.list.itemAccentColor
                    case .disclosure:
                        image = disclosureImage
                        color = component.theme.list.disclosureArrowColor
                    case .none:
                        break
                    }
                    rightIconView = UIImageView(image: image)
                    rightIconView.tintColor = color
                    self.rightIconView = rightIconView
                    self.containerButton.addSubview(rightIconView)
                }
                
                if let image = rightIconView.image {
                    let iconFrame: CGRect
                    switch component.rightAccessory {
                    case .disclosure:
                        iconFrame = CGRect(origin: CGPoint(x: availableSize.width - image.size.width - 16.0 - contextInset, y: floor((height - verticalInset * 2.0 - image.size.height) / 2.0)), size: image.size)
                    default:
                        iconFrame = CGRect(origin: CGPoint(x: availableSize.width - image.size.width, y: floor((height - verticalInset * 2.0 - image.size.height) / 2.0)), size: image.size)
                    }
                    
                    transition.setFrame(view: rightIconView, frame: iconFrame)
                }
            }
            
            if let rightAccessoryComponentViewImpl = self.rightAccessoryComponentView?.view, let rightAccessoryComponentSize {
                var rightAccessoryComponentTransition = transition
                if rightAccessoryComponentViewImpl.superview == nil {
                    rightAccessoryComponentViewImpl.isUserInteractionEnabled = false
                    rightAccessoryComponentTransition = rightAccessoryComponentTransition.withAnimation(.none)
                    self.containerButton.addSubview(rightAccessoryComponentViewImpl)
                }
                rightAccessoryComponentTransition.setFrame(view: rightAccessoryComponentViewImpl, frame: CGRect(origin: CGPoint(x: availableSize.width - (contextInset * 2.0 + component.sideInset) - rightAccessoryComponentSize.width, y: floor((height - verticalInset * 2.0 - rightAccessoryComponentSize.width) / 2.0)), size: rightAccessoryComponentSize))
            }
            
            var reactionIconTransition = transition
            if previousComponent?.reaction != component.reaction {
                if let reaction = component.reaction, case .builtin("❤") = reaction.reaction {
                    self.file = nil
                    self.updateReactionLayer()
                    
                    let heartReactionIcon: UIImageView
                    if let current = self.heartReactionIcon {
                        heartReactionIcon = current
                    } else {
                        reactionIconTransition = reactionIconTransition.withAnimation(.none)
                        heartReactionIcon = UIImageView()
                        self.heartReactionIcon = heartReactionIcon
                        self.containerButton.addSubview(heartReactionIcon)
                        heartReactionIcon.image = PresentationResourcesChat.storyViewListLikeIcon(component.theme)
                    }
                } else {
                    if let heartReactionIcon = self.heartReactionIcon {
                        self.heartReactionIcon = nil
                        heartReactionIcon.removeFromSuperview()
                    }
                    
                    if let reaction = component.reaction {
                        switch reaction.reaction {
                        case .builtin:
                            self.file = reaction.file
                            self.updateReactionLayer()
                        case let .custom(fileId):
                            self.fileDisposable = (component.context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                            |> deliverOnMainQueue).start(next: { [weak self] files in
                                guard let self, let file = files[fileId] else {
                                    return
                                }
                                self.file = file
                                self.updateReactionLayer()
                            })
                        case .stars:
                            self.file = reaction.file
                            self.updateReactionLayer()
                        }
                    } else {
                        self.file = nil
                        self.updateReactionLayer()
                    }
                }
            }
            
            if let heartReactionIcon = self.heartReactionIcon, let image = heartReactionIcon.image, let iconFrame = self.iconFrame {
                reactionIconTransition.setFrame(view: heartReactionIcon, frame: image.size.centered(around: iconFrame.center))
            }
            
            if let reactionLayer = self.reactionLayer, let iconFrame = self.iconFrame {
                var adjustedIconFrame = iconFrame
                if let reaction = component.reaction, case .builtin = reaction.reaction {
                    adjustedIconFrame = adjustedIconFrame.insetBy(dx: -adjustedIconFrame.width * 0.5, dy: -adjustedIconFrame.height * 0.5)
                }
                transition.setFrame(layer: reactionLayer, frame: adjustedIconFrame)
            }
            
            
            var mediaReference: AnyMediaReference?
            if let peer = component.peer, let peerReference = PeerReference(peer._asPeer()) {
                if let story = component.story {
                    mediaReference = .story(peer: peerReference, id: story.id, media: story.media._asMedia())
                } else if let message = component.message {
                    var selectedMedia: Media?
                    for media in message.media {
                        if let image = media as? TelegramMediaImage {
                            selectedMedia = image
                        } else if let file = media as? TelegramMediaFile {
                            selectedMedia = file
                        }
                    }
                    if let media = selectedMedia {
                        mediaReference = .message(message: MessageReference(message._asMessage()), media: media)
                    }
                }
            }
            
            if let peer = component.peer, let mediaReference {
                let contentImageSize = CGSize(width: 30.0, height: 42.0)
                var dimensions: CGSize?
                if let imageMedia = mediaReference.media as? TelegramMediaImage {
                    dimensions = largestRepresentationForPhoto(imageMedia)?.dimensions.cgSize
                } else if let imageMedia = mediaReference.media as? TelegramMediaFile {
                    dimensions = imageMedia.dimensions?.cgSize
                }
                
                let imageButtonView: HighlightTrackingButton
                let imageNode: TransformImageNode
                if let current = self.imageNode, let currentButton = self.imageButtonView {
                    imageNode = current
                    imageButtonView = currentButton
                } else {
                    imageNode = TransformImageNode()
                    imageNode.displaysAsynchronously = false
                    imageNode.isUserInteractionEnabled = false
                    self.imageNode = imageNode
                    
                    imageButtonView = HighlightTrackingButton()
                    imageButtonView.isEnabled = false
                    self.imageButtonView = imageButtonView
                    
                    self.containerButton.addSubview(imageNode.view)
                    self.addSubview(imageButtonView)
                    
                    var imageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                    if let imageReference = mediaReference.concrete(TelegramMediaImage.self) {
                        imageSignal = mediaGridMessagePhoto(account: component.context.account, userLocation: .peer(peer.id), photoReference: imageReference)
                    } else if let fileReference = mediaReference.concrete(TelegramMediaFile.self) {
                        imageSignal = mediaGridMessageVideo(postbox: component.context.account.postbox, userLocation: .peer(peer.id), videoReference: fileReference, autoFetchFullSizeThumbnail: true)
                    }
                    if let imageSignal {
                        imageNode.setSignal(imageSignal)
                    }
                }
                
                if let dimensions {
                    let makeImageLayout = imageNode.asyncLayout()
                    let applyImageLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(radius: 5.0), imageSize: dimensions.aspectFilled(contentImageSize), boundingSize: contentImageSize, intrinsicInsets: UIEdgeInsets()))
                    applyImageLayout()
                    
                    let imageFrame = CGRect(origin: CGPoint(x: availableSize.width - contentImageSize.width - 10.0 - contextInset, y: floorToScreenPixels((height - contentImageSize.height) / 2.0)), size: contentImageSize)
                    imageNode.frame = imageFrame
                    transition.setFrame(view: imageButtonView, frame: imageFrame)
                }
            } else {
                self.imageNode?.removeFromSupernode()
                self.imageNode = nil
                self.imageButtonView?.removeFromSuperview()
                self.imageButtonView = nil
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext
            
            let resultBounds = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height))
            transition.setFrame(view: self.extractedContainerView, frame: resultBounds)
            transition.setFrame(view: self.extractedContainerView.contentView, frame: resultBounds)
            self.extractedContainerView.contentRect = resultBounds
            
            let containerFrame = CGRect(origin: CGPoint(x: contextInset, y: verticalInset), size: CGSize(width: availableSize.width - contextInset * 2.0, height: height - verticalInset * 2.0))
            
            let swipeOptionContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: height))
            transition.setFrame(view: self.swipeOptionContainer, frame: swipeOptionContainerFrame)
            
            transition.setPosition(view: self.containerButton, position: containerFrame.origin)
            transition.setBounds(view: self.containerButton, bounds: CGRect(origin: self.containerButton.bounds.origin, size: containerFrame.size))
            
            self.separatorInset = leftInset
            
            self.swipeOptionContainer.updateLayout(size: swipeOptionContainerFrame.size, leftInset: 0.0, rightInset: 0.0)
            
            var rightOptions: [ListItemSwipeOptionContainer.Option] = []
            if let inlineActions = component.inlineActions {
                rightOptions = inlineActions.actions.map { action in
                    let color: UIColor
                    let textColor: UIColor
                    switch action.color {
                    case .destructive:
                        color = component.theme.list.itemDisclosureActions.destructive.fillColor
                        textColor = component.theme.list.itemDisclosureActions.destructive.foregroundColor
                    }
                    
                    return ListItemSwipeOptionContainer.Option(
                        key: action.id,
                        title: action.title,
                        icon: .none,
                        color: color,
                        textColor: textColor
                    )
                }
            }
            self.swipeOptionContainer.setRevealOptions(([], rightOptions))
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
