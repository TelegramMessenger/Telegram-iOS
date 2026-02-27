import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode
import ReactionSelectionNode
import TelegramCore
import SwiftSignalKit
import AccountContext
import TextNodeWithEntities
import EntityKeyboard
import AnimationCache
import MultiAnimationRenderer
import UndoUI
import UIKitRuntimeUtils

public protocol ContextControllerProtocol: ViewController {
    var useComplexItemsTransitionAnimation: Bool { get set }
    var immediateItemsTransitionAnimation: Bool { get set }
    var getOverlayViews: (() -> [UIView])? { get set }

    func dismiss(completion: (() -> Void)?)
    func dismiss(result: ContextMenuActionResult, completion: (() -> Void)?)
    
    func getActionsMinHeight() -> ContextController.ActionsHeight?
    func setItems(_ items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?, animated: Bool)
    func setItems(_ items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?, previousActionsTransition: ContextController.PreviousActionsTransition)
    func pushItems(items: Signal<ContextController.Items, NoError>)
    func popItems()
}

public enum ContextMenuActionItemTextLayout {
    case singleLine
    case twoLinesMax
    case secondLineWithValue(String)
    case secondLineWithAttributedValue(NSAttributedString)
    case multiline
}

public enum ContextMenuActionItemTextColor {
    case primary
    case destructive
    case disabled
}

public enum ContextMenuActionResult {
    case `default`
    case dismissWithoutContent
    
    case custom(ContainedViewLayoutTransition)
}

public enum ContextMenuActionItemFont {
    case regular
    case small
    case custom(font: UIFont, height: CGFloat?, verticalOffset: CGFloat?)
}

public struct ContextMenuActionItemIconSource {
    public let size: CGSize
    public let contentMode: UIView.ContentMode
    public let cornerRadius: CGFloat
    public let signal: Signal<UIImage?, NoError>
    
    public init(size: CGSize, contentMode: UIView.ContentMode = .scaleToFill, cornerRadius: CGFloat = 0.0, signal: Signal<UIImage?, NoError>) {
        self.size = size
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.signal = signal
    }
}

public enum ContextMenuActionItemIconPosition {
    case left
    case right
}

public enum ContextMenuActionBadgeColor {
    case accent
    case inactive
}

public struct ContextMenuActionBadge: Equatable {
    public enum Style {
        case badge
        case label
    }
    
    public var value: String
    public var color: ContextMenuActionBadgeColor
    public var style: Style
    
    public init(value: String, color: ContextMenuActionBadgeColor, style: Style = .badge) {
        self.value = value
        self.color = color
        self.style = style
    }
}

public final class ContextMenuActionItem {
    public final class Action {
        public let controller: ContextControllerProtocol?
        public let dismissWithResult: (ContextMenuActionResult) -> Void
        public let updateAction: (AnyHashable, ContextMenuActionItem) -> Void

        public init(controller: ContextControllerProtocol?, dismissWithResult: @escaping (ContextMenuActionResult) -> Void, updateAction: @escaping (AnyHashable, ContextMenuActionItem) -> Void) {
            self.controller = controller
            self.dismissWithResult = dismissWithResult
            self.updateAction = updateAction
        }
    }
    
    public struct IconAnimation: Equatable {
        public var name: String
        public var loop: Bool
        
        public init(name: String, loop: Bool = false) {
            self.name = name
            self.loop = loop
        }
    }

    public let id: AnyHashable?
    public let text: String
    public let entities: [MessageTextEntity]
    public let entityFiles: [Int64: TelegramMediaFile]
    public let enableEntityAnimations: Bool
    public let textColor: ContextMenuActionItemTextColor
    public let textFont: ContextMenuActionItemFont
    public let textLayout: ContextMenuActionItemTextLayout
    public let customTextInsets: UIEdgeInsets?
    public let parseMarkdown: Bool
    public let badge: ContextMenuActionBadge?
    public let icon: (PresentationTheme) -> UIImage?
    public let additionalLeftIcon: ((PresentationTheme) -> UIImage?)?
    public let iconSource: ContextMenuActionItemIconSource?
    public let iconPosition: ContextMenuActionItemIconPosition
    public let animationName: String?
    public let iconAnimation: IconAnimation?
    public let textIcon: (PresentationTheme) -> UIImage?
    public let textLinkAction: () -> Void
    public let action: ((Action) -> Void)?
    public let longPressAction: ((Action) -> Void)?
    
    convenience public init(
        id: AnyHashable? = nil,
        text: String,
        entities: [MessageTextEntity] = [],
        entityFiles: [Int64: TelegramMediaFile] = [:],
        enableEntityAnimations: Bool = true,
        textColor: ContextMenuActionItemTextColor = .primary,
        textLayout: ContextMenuActionItemTextLayout = .twoLinesMax,
        customTextInsets: UIEdgeInsets? = nil,
        textFont: ContextMenuActionItemFont = .regular,
        parseMarkdown: Bool = false,
        badge: ContextMenuActionBadge? = nil,
        icon: @escaping (PresentationTheme) -> UIImage?,
        additionalLeftIcon: ((PresentationTheme) -> UIImage?)? = nil,
        iconSource: ContextMenuActionItemIconSource? = nil,
        iconPosition: ContextMenuActionItemIconPosition = .right,
        animationName: String? = nil,
        iconAnimation: IconAnimation? = nil,
        textIcon: @escaping (PresentationTheme) -> UIImage? = { _ in return nil },
        textLinkAction: @escaping () -> Void = {},
        action: ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)?,
        longPressAction: ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)? = nil
    ) {
        self.init(
            id: id,
            text: text,
            entities: entities,
            entityFiles: entityFiles,
            enableEntityAnimations: enableEntityAnimations,
            textColor: textColor,
            textLayout: textLayout,
            customTextInsets: customTextInsets,
            textFont: textFont,
            parseMarkdown: parseMarkdown,
            badge: badge,
            icon: icon,
            additionalLeftIcon: additionalLeftIcon,
            iconSource: iconSource,
            iconPosition: iconPosition,
            animationName: animationName,
            iconAnimation: iconAnimation,
            textIcon: textIcon,
            textLinkAction: textLinkAction,
            action: action.flatMap { action in
                return { impl in
                    action(impl.controller, impl.dismissWithResult)
                }
            },
            longPressAction: longPressAction.flatMap { longPressAction in
                return { impl in
                    longPressAction(impl.controller, impl.dismissWithResult)
                }
            }
        )
    }

    public init(
        id: AnyHashable? = nil,
        text: String,
        entities: [MessageTextEntity] = [],
        entityFiles: [Int64: TelegramMediaFile] = [:],
        enableEntityAnimations: Bool = true,
        textColor: ContextMenuActionItemTextColor = .primary,
        textLayout: ContextMenuActionItemTextLayout = .twoLinesMax,
        customTextInsets: UIEdgeInsets? = nil,
        textFont: ContextMenuActionItemFont = .regular,
        parseMarkdown: Bool = false,
        badge: ContextMenuActionBadge? = nil,
        icon: @escaping (PresentationTheme) -> UIImage?,
        additionalLeftIcon: ((PresentationTheme) -> UIImage?)? = nil,
        iconSource: ContextMenuActionItemIconSource? = nil,
        iconPosition: ContextMenuActionItemIconPosition = .right,
        animationName: String? = nil,
        iconAnimation: IconAnimation? = nil,
        textIcon: @escaping (PresentationTheme) -> UIImage? = { _ in return nil },
        textLinkAction: @escaping () -> Void = {},
        action: ((Action) -> Void)?,
        longPressAction: ((Action) -> Void)? = nil
    ) {
        self.id = id
        self.text = text
        self.entities = entities
        self.entityFiles = entityFiles
        self.enableEntityAnimations = enableEntityAnimations
        self.textColor = textColor
        self.textFont = textFont
        self.textLayout = textLayout
        self.customTextInsets = customTextInsets
        self.parseMarkdown = parseMarkdown
        self.badge = badge
        self.icon = icon
        self.additionalLeftIcon = additionalLeftIcon
        self.iconSource = iconSource
        self.iconPosition = iconPosition
        self.animationName = animationName
        self.iconAnimation = iconAnimation
        self.textIcon = textIcon
        self.textLinkAction = textLinkAction
        self.action = action
        self.longPressAction = longPressAction
    }
}

public protocol ContextMenuCustomNode: ASDisplayNode {
    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void)
    func updateTheme(presentationData: PresentationData)
    
    func canBeHighlighted() -> Bool
    func updateIsHighlighted(isHighlighted: Bool)
    func performAction()
    
    var needsSeparator: Bool { get }
    var needsPadding: Bool { get }
}

public extension ContextMenuCustomNode {
    var needsSeparator: Bool {
        return true
    }
    
    var needsPadding: Bool {
        return true
    }
}

public protocol ContextMenuCustomItem {
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode
}

public enum ContextMenuItem {
    case action(ContextMenuActionItem)
    case custom(ContextMenuCustomItem, Bool)
    case separator
}

public final class ContextControllerLocationViewInfo {
    public let location: CGPoint
    public let contentAreaInScreenSpace: CGRect
    public let insets: UIEdgeInsets
    
    public init(location: CGPoint, contentAreaInScreenSpace: CGRect, insets: UIEdgeInsets = UIEdgeInsets()) {
        self.location = location
        self.contentAreaInScreenSpace = contentAreaInScreenSpace
        self.insets = insets
    }
}

public protocol ContextLocationContentSource: AnyObject {
    var shouldBeDismissed: Signal<Bool, NoError> { get }
    
    func transitionInfo() -> ContextControllerLocationViewInfo?
}

public extension ContextLocationContentSource {
    var shouldBeDismissed: Signal<Bool, NoError> {
        return .single(false)
    }
}

public final class ContextControllerReferenceViewInfo {
    public enum ActionsPosition {
        case bottom
        case top
    }
    public let referenceView: UIView
    public let contentAreaInScreenSpace: CGRect
    public let insets: UIEdgeInsets
    public let customPosition: CGPoint?
    public let actionsPosition: ActionsPosition
    
    public init(referenceView: UIView, contentAreaInScreenSpace: CGRect, insets: UIEdgeInsets = UIEdgeInsets(), customPosition: CGPoint? = nil, actionsPosition: ActionsPosition = .bottom) {
        self.referenceView = referenceView
        self.contentAreaInScreenSpace = contentAreaInScreenSpace
        self.insets = insets
        self.customPosition = customPosition
        self.actionsPosition = actionsPosition
    }
}

public protocol ContextReferenceContentSource: AnyObject {
    var keepInPlace: Bool { get }
    var shouldBeDismissed: Signal<Bool, NoError> { get }
    var forceDisplayBelowKeyboard: Bool { get }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo?
}

public extension ContextReferenceContentSource {
    var keepInPlace: Bool {
        return false
    }
    
    var forceDisplayBelowKeyboard: Bool {
        return false
    }
    
    var shouldBeDismissed: Signal<Bool, NoError> {
        return .single(false)
    }
}

public final class ContextControllerTakeViewInfo {
    public enum ContainingItem {
        case node(ContextExtractedContentContainingNode)
        case view(ContextExtractedContentContainingView)
    }
    
    public let containingItem: ContainingItem
    public let contentAreaInScreenSpace: CGRect
    public let maskView: UIView?
    
    public init(containingItem: ContainingItem, contentAreaInScreenSpace: CGRect, maskView: UIView? = nil) {
        self.containingItem = containingItem
        self.contentAreaInScreenSpace = contentAreaInScreenSpace
        self.maskView = maskView
    }
}

public final class ContextControllerPutBackViewInfo {
    public let contentAreaInScreenSpace: CGRect
    public let maskView: UIView?
    
    public init(contentAreaInScreenSpace: CGRect, maskView: UIView? = nil) {
        self.contentAreaInScreenSpace = contentAreaInScreenSpace
        self.maskView = maskView
    }
}

public enum ContextActionsHorizontalAlignment {
    case `default`
    case left
    case center
    case right
}

public protocol ContextExtractedContentSource: AnyObject {
    var initialAppearanceOffset: CGPoint { get }
    var centerVertically: Bool { get }
    var keepInPlace: Bool { get }
    var adjustContentHorizontally: Bool { get }
    var adjustContentForSideInset: Bool { get }
    var ignoreContentTouches: Bool { get }
    var keepDefaultContentTouches: Bool { get }
    var blurBackground: Bool { get }
    var shouldBeDismissed: Signal<Bool, NoError> { get }
    var additionalInsets: UIEdgeInsets { get }
    
    var actionsHorizontalAlignment: ContextActionsHorizontalAlignment { get }
    
    func takeView() -> ContextControllerTakeViewInfo?
    func putBack() -> ContextControllerPutBackViewInfo?
}

public extension ContextExtractedContentSource {
    var initialAppearanceOffset: CGPoint {
        return .zero
    }
    
    var centerVertically: Bool {
        return false
    }
    
    var adjustContentHorizontally: Bool {
        return false
    }
    
    var adjustContentForSideInset: Bool {
        return false
    }
    
    var additionalInsets: UIEdgeInsets {
        return .zero
    }
    
    var actionsHorizontalAlignment: ContextActionsHorizontalAlignment {
        return .default
    }

    var shouldBeDismissed: Signal<Bool, NoError> {
        return .single(false)
    }
    
    var keepDefaultContentTouches: Bool {
        return false
    }
}

public final class ContextControllerTakeControllerInfo {
    public let contentAreaInScreenSpace: CGRect
    public let sourceNode: () -> (UIView, CGRect)?
    
    public init(contentAreaInScreenSpace: CGRect, sourceNode: @escaping () -> (UIView, CGRect)?) {
        self.contentAreaInScreenSpace = contentAreaInScreenSpace
        self.sourceNode = sourceNode
    }
}

public protocol ContextControllerContentSource: AnyObject {
    var controller: ViewController { get }
    var navigationController: NavigationController? { get }
    var passthroughTouches: Bool { get }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo?
    
    func animatedIn()
}

public enum ContextContentSource {
    case location(ContextLocationContentSource)
    case reference(ContextReferenceContentSource)
    case extracted(ContextExtractedContentSource)
    case controller(ContextControllerContentSource)
}

public protocol ContextControllerItemsNode: ASDisplayNode {
    func update(presentationData: PresentationData, constrainedWidth: CGFloat, maxHeight: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> (cleanSize: CGSize, apparentHeight: CGFloat)
    
    var apparentHeight: CGFloat { get }
}

public protocol ContextControllerItemsContent: AnyObject {
    func node(
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerItemsNode
}

public final class ContextControllerSource {
    public let id: AnyHashable
    public let title: String
    public let footer: String?
    public let source: ContextContentSource
    public let items: Signal<ContextController.Items, NoError>
    public let closeActionTitle: String?
    public let closeAction: (() -> Void)?
    
    public init(
        id: AnyHashable,
        title: String,
        footer: String? = nil,
        source: ContextContentSource,
        items: Signal<ContextController.Items, NoError>,
        closeActionTitle: String? = nil,
        closeAction: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.footer = footer
        self.source = source
        self.items = items
        self.closeActionTitle = closeActionTitle
        self.closeAction = closeAction
    }
}

public final class ContextControllerConfiguration {
    public let sources: [ContextControllerSource]
    public let initialId: AnyHashable
    
    public init(sources: [ContextControllerSource], initialId: AnyHashable) {
        self.sources = sources
        self.initialId = initialId
    }
}

public struct ContextControllerItems {
    public enum Content {
        case list([ContextMenuItem])
        case twoLists([ContextMenuItem], [ContextMenuItem])
        case custom(ContextControllerItemsContent)
    }
    
    public var id: AnyHashable?
    public var content: Content
    public var context: AccountContext?
    public var reactionItems: [ReactionContextItem]
    public var selectedReactionItems: Set<MessageReaction.Reaction>
    public var reactionsTitle: String?
    public var reactionsLocked: Bool
    public var animationCache: AnimationCache?
    public var alwaysAllowPremiumReactions: Bool
    public var allPresetReactionsAreAvailable: Bool
    public var getEmojiContent: ((AnimationCache, MultiAnimationRenderer) -> Signal<EmojiPagerContentComponent, NoError>)?
    public var disablePositionLock: Bool
    public var previewReaction: TelegramMediaFile?
    public var tip: ContextControllerTip?
    public var tipSignal: Signal<ContextControllerTip?, NoError>?
    public var dismissed: (() -> Void)?

    public init(
        id: AnyHashable? = nil,
        content: Content,
        context: AccountContext? = nil,
        reactionItems: [ReactionContextItem] = [],
        selectedReactionItems: Set<MessageReaction.Reaction> = Set(),
        reactionsTitle: String? = nil,
        reactionsLocked: Bool = false,
        animationCache: AnimationCache? = nil,
        alwaysAllowPremiumReactions: Bool = false,
        allPresetReactionsAreAvailable: Bool = false,
        getEmojiContent: ((AnimationCache, MultiAnimationRenderer) -> Signal<EmojiPagerContentComponent, NoError>)? = nil,
        disablePositionLock: Bool = false,
        previewReaction: TelegramMediaFile? = nil,
        tip: ContextControllerTip? = nil,
        tipSignal: Signal<ContextControllerTip?, NoError>? = nil,
        dismissed: (() -> Void)? = nil
    ) {
        self.id = id
        self.content = content
        self.context = context
        self.animationCache = animationCache
        self.reactionItems = reactionItems
        self.selectedReactionItems = selectedReactionItems
        self.reactionsTitle = reactionsTitle
        self.reactionsLocked = reactionsLocked
        self.alwaysAllowPremiumReactions = alwaysAllowPremiumReactions
        self.allPresetReactionsAreAvailable = allPresetReactionsAreAvailable
        self.getEmojiContent = getEmojiContent
        self.disablePositionLock = disablePositionLock
        self.previewReaction = previewReaction
        self.tip = tip
        self.tipSignal = tipSignal
        self.dismissed = dismissed
    }

    public init() {
        self.id = nil
        self.content = .list([])
        self.context = nil
        self.reactionItems = []
        self.selectedReactionItems = Set()
        self.reactionsTitle = nil
        self.reactionsLocked = false
        self.alwaysAllowPremiumReactions = false
        self.allPresetReactionsAreAvailable = false
        self.getEmojiContent = nil
        self.disablePositionLock = false
        self.previewReaction = nil
        self.tip = nil
        self.tipSignal = nil
        self.dismissed = nil
    }
}

public enum ContextControllerPreviousActionsTransition {
    case scale
    case slide(forward: Bool)
}

public enum ContextControllerTip: Equatable {
    case textSelection
    case quoteSelection
    case messageViewsPrivacy
    case messageCopyProtection(isChannel: Bool)
    case animatedEmoji(text: String?, arguments: TextNodeWithEntities.Arguments?, file: TelegramMediaFile?, action: (() -> Void)?)
    case notificationTopicExceptions(text: String, action: (() -> Void)?)
    case starsReactions(topCount: Int)
    case videoProcessing
    case collageReordering
    
    public static func ==(lhs: ContextControllerTip, rhs: ContextControllerTip) -> Bool {
        switch lhs {
        case .textSelection:
            if case .textSelection = rhs {
                return true
            } else {
                return false
            }
        case .quoteSelection:
            if case .quoteSelection = rhs {
                return true
            } else {
                return false
            }
        case .messageViewsPrivacy:
            if case .messageViewsPrivacy = rhs {
                return true
            } else {
                return false
            }
        case let .messageCopyProtection(isChannel):
            if case .messageCopyProtection(isChannel) = rhs {
                return true
            } else {
                return false
            }
        case let .animatedEmoji(text, _, file, _):
            if case let .animatedEmoji(rhsText, _, rhsFile, _) = rhs {
                if text != rhsText {
                    return false
                }
                if file?.fileId != rhsFile?.fileId {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .notificationTopicExceptions(text, _):
            if case .notificationTopicExceptions(text, _) = rhs {
                return true
            } else {
                return false
            }
        case let .starsReactions(topCount):
            if case .starsReactions(topCount) = rhs {
                return true
            } else {
                return false
            }
        case .videoProcessing:
            if case .videoProcessing = rhs {
                return true
            } else {
                return false
            }
        case .collageReordering:
            if case .collageReordering = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public final class ContextControllerActionsHeight {
    public let minY: CGFloat
    public let contentOffset: CGFloat

    public init(minY: CGFloat, contentOffset: CGFloat) {
        self.minY = minY
        self.contentOffset = contentOffset
    }
}

public enum ContextControllerHandledTouchEvent {
    case ignore
    case dismiss(consume: Bool, result: UIView?)
}

public enum ContextActionSibling {
    case none
    case item
    case separator
}

public protocol ContextActionNodeProtocol: ASDisplayNode {
    func setIsHighlighted(_ value: Bool)
    func performAction()
    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol
    var isActionEnabled: Bool { get }
}

public protocol ContextController: ViewController, StandalonePresentableController, ContextControllerProtocol, KeyShortcutResponder {
    typealias ContentSource = ContextContentSource
    typealias ItemsNode = ContextControllerItemsNode
    typealias ItemsContent = ContextControllerItemsContent
    typealias Source = ContextControllerSource
    typealias Configuration = ContextControllerConfiguration
    typealias Items = ContextControllerItems
    typealias PreviousActionsTransition = ContextControllerPreviousActionsTransition
    typealias Tip = ContextControllerTip
    typealias ActionsHeight = ContextControllerActionsHeight
    typealias HandledTouchEvent = ContextControllerHandledTouchEvent
    
    var dismissed: (() -> Void)? { get set }
    var dismissedForCancel: (() -> Void)? { get set }
    var passthroughTouchEvent: ((UIView, CGPoint) -> HandledTouchEvent)? { get set }
    var reactionSelected: ((UpdateMessageReaction, Bool) -> Void)? { get set }
    var premiumReactionsSelected: (() -> Void)? { get set }
    var getOverlayViews: (() -> [UIView])? { get set }
    
    func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition)
    func updateTheme(presentationData: PresentationData)
    func dismissWithCustomTransition(transition: ContainedViewLayoutTransition, completion: (() -> Void)?)
    func dismissWithoutContent()
    func dismissNow()
    func dismissWithReaction(value: MessageReaction.Reaction, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, onHit: (() -> Void)?, completion: (() -> Void)?)
    func animateDismissalIfNeeded()
    func cancelReactionAnimation()
}

public func makeContextController(
    context: AccountContext? = nil,
    presentationData: PresentationData,
    source: ContextContentSource,
    items: Signal<ContextController.Items, NoError>,
    recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil,
    gesture: ContextGesture? = nil,
    workaroundUseLegacyImplementation: Bool = false,
    disableScreenshots: Bool = false,
    hideReactionPanelTail: Bool = false
) -> ContextController {
    return makeContextController(
        context: context,
        presentationData: presentationData,
        configuration: ContextController.Configuration(
            sources: [ContextController.Source(
                id: AnyHashable(0 as Int),
                title: "",
                source: source,
                items: items
            )],
            initialId: AnyHashable(0 as Int)
        ),
        recognizer: recognizer,
        gesture: gesture,
        workaroundUseLegacyImplementation: workaroundUseLegacyImplementation,
        disableScreenshots: disableScreenshots,
        hideReactionPanelTail: hideReactionPanelTail
    )
}

public var makeContextControllerImpl: ((
    _ context: AccountContext?,
    _ presentationData: PresentationData,
    _ configuration: ContextController.Configuration,
    _ recognizer: TapLongTapOrDoubleTapGestureRecognizer?,
    _ gesture: ContextGesture?,
    _ workaroundUseLegacyImplementation: Bool,
    _ disableScreenshots: Bool,
    _ hideReactionPanelTail: Bool
) -> ContextController)? = nil

public func makeContextController(
    context: AccountContext? = nil,
    presentationData: PresentationData,
    configuration: ContextController.Configuration,
    recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil,
    gesture: ContextGesture? = nil,
    workaroundUseLegacyImplementation: Bool = false,
    disableScreenshots: Bool = false,
    hideReactionPanelTail: Bool = false
) -> ContextController {
    return makeContextControllerImpl!(
        context,
        presentationData,
        configuration,
        recognizer,
        gesture,
        workaroundUseLegacyImplementation,
        disableScreenshots,
        hideReactionPanelTail
    )
}

public enum ContextControllerActionsStackNodePresentation {
    case modal
    case inline
    case additional
}

public protocol ContextControllerActionsStackItemNode: ASDisplayNode {
    var wantsFullWidth: Bool { get }
    
    func update(
        presentationData: PresentationData,
        constrainedSize: CGSize,
        standardMinWidth: CGFloat,
        standardMaxWidth: CGFloat,
        additionalBottomInset: CGFloat,
        transition: ContainedViewLayoutTransition
    ) -> (size: CGSize, apparentHeight: CGFloat)
    
    func highlightGestureShouldBegin(location: CGPoint) -> Bool
    func highlightGestureMoved(location: CGPoint)
    func highlightGestureFinished(performAction: Bool)
    
    func decreaseHighlightedIndex()
    func increaseHighlightedIndex()
}

public protocol ContextControllerActionsStackItem: AnyObject {
    func node(
        context: AccountContext?,
        getController: @escaping () -> ContextControllerProtocol?,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerActionsStackItemNode
    
    var id: AnyHashable? { get }
    var tip: ContextController.Tip? { get }
    var tipSignal: Signal<ContextController.Tip?, NoError>? { get }
    var reactionItems: ContextControllerReactionItems? { get }
    var previewReaction: ContextControllerPreviewReaction? { get }
    var dismissed: (() -> Void)? { get }
}

public struct ContextControllerReactionItems {
    public var context: AccountContext
    public var reactionItems: [ReactionContextItem]
    public var selectedReactionItems: Set<MessageReaction.Reaction>
    public var reactionsTitle: String?
    public var reactionsLocked: Bool
    public var animationCache: AnimationCache
    public var alwaysAllowPremiumReactions: Bool
    public var allPresetReactionsAreAvailable: Bool
    public var getEmojiContent: ((AnimationCache, MultiAnimationRenderer) -> Signal<EmojiPagerContentComponent, NoError>)?
    
    public init(context: AccountContext, reactionItems: [ReactionContextItem], selectedReactionItems: Set<MessageReaction.Reaction>, reactionsTitle: String?, reactionsLocked: Bool, animationCache: AnimationCache, alwaysAllowPremiumReactions: Bool, allPresetReactionsAreAvailable: Bool, getEmojiContent: ((AnimationCache, MultiAnimationRenderer) -> Signal<EmojiPagerContentComponent, NoError>)?) {
        self.context = context
        self.reactionItems = reactionItems
        self.selectedReactionItems = selectedReactionItems
        self.reactionsTitle = reactionsTitle
        self.reactionsLocked = reactionsLocked
        self.animationCache = animationCache
        self.alwaysAllowPremiumReactions = alwaysAllowPremiumReactions
        self.allPresetReactionsAreAvailable = allPresetReactionsAreAvailable
        self.getEmojiContent = getEmojiContent
    }
}

public final class ContextControllerPreviewReaction {
    public let context: AccountContext
    public let file: TelegramMediaFile
    
    public init(context: AccountContext, file: TelegramMediaFile) {
        self.context = context
        self.file = file
    }
}

public protocol ContextControllerActionsStackNode: ASDisplayNode {
    typealias Presentation = ContextControllerActionsStackNodePresentation
    
    var topReactionItems: ContextControllerReactionItems? { get }
    var topPreviewReaction: ContextControllerPreviewReaction? { get }
    var topPositionLock: CGFloat? { get }
    var storedScrollingState: CGFloat? { get }
    
    func replace(item: ContextControllerActionsStackItem, animated: Bool?)
    func push(item: ContextControllerActionsStackItem, currentScrollingState: CGFloat?, positionLock: CGFloat?, animated: Bool)
    func clearStoredScrollingState()
    func pop()
    func update(
        presentationData: PresentationData,
        constrainedSize: CGSize,
        presentation: Presentation,
        transition: ContainedViewLayoutTransition
    ) -> CGSize
    func highlightGestureMoved(location: CGPoint)
    func highlightGestureFinished(performAction: Bool)
    func decreaseHighlightedIndex()
    func increaseHighlightedIndex()
    func updatePanSelection(isEnabled: Bool)
    func animateIn()
}

public var makeContextControllerActionsListStackItemImpl: ((
    _ id: AnyHashable?,
    _ items: [ContextMenuItem],
    _ reactionItems: ContextControllerReactionItems?,
    _ previewReaction: ContextControllerPreviewReaction?,
    _ tip: ContextController.Tip?,
    _ tipSignal: Signal<ContextController.Tip?, NoError>?,
    _ dismissed: (() -> Void)?
) -> ContextControllerActionsStackItem)?

public func makeContextControllerActionsListStackItem(
    id: AnyHashable?,
    items: [ContextMenuItem],
    reactionItems: ContextControllerReactionItems?,
    previewReaction: ContextControllerPreviewReaction?,
    tip: ContextController.Tip?,
    tipSignal: Signal<ContextController.Tip?, NoError>?,
    dismissed: (() -> Void)?
) -> ContextControllerActionsStackItem {
    return makeContextControllerActionsListStackItemImpl!(
        id,
        items,
        reactionItems,
        previewReaction,
        tip,
        tipSignal,
        dismissed
    )
}

public var makeContextControllerActionsStackNodeImpl: ((
    _ context: AccountContext?,
    _ getController: @escaping () -> ContextControllerProtocol?,
    _ requestDismiss: @escaping (ContextMenuActionResult) -> Void,
    _ requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void
) -> ContextControllerActionsStackNode)?

public func makeContextControllerActionsStackNode(
    context: AccountContext?,
    getController: @escaping () -> ContextControllerProtocol?,
    requestDismiss: @escaping (ContextMenuActionResult) -> Void,
    requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void
) -> ContextControllerActionsStackNode {
    return makeContextControllerActionsStackNodeImpl!(
        context,
        getController,
        requestDismiss,
        requestUpdate
    )
}

public var makeContextActionNodeImpl: ((
    _ presentationData: PresentationData,
    _ action: ContextMenuActionItem,
    _ getController: @escaping () -> ContextControllerProtocol?,
    _ actionSelected: @escaping (ContextMenuActionResult) -> Void,
    _ requestLayout: @escaping () -> Void,
    _ requestUpdateAction: @escaping (AnyHashable, ContextMenuActionItem) -> Void
) -> ContextActionNodeProtocol)?

public func makeContextActionNode(
    presentationData: PresentationData,
    action: ContextMenuActionItem,
    getController: @escaping () -> ContextControllerProtocol?,
    actionSelected: @escaping (ContextMenuActionResult) -> Void,
    requestLayout: @escaping () -> Void,
    requestUpdateAction: @escaping (AnyHashable, ContextMenuActionItem) -> Void
) -> ContextActionNodeProtocol {
    return makeContextActionNodeImpl!(
        presentationData,
        action,
        getController,
        actionSelected,
        requestLayout,
        requestUpdateAction
    )
}
