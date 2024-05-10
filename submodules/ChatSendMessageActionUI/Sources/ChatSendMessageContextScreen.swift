import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ContextUI
import TelegramCore
import Postbox
import TextFormat
import ReactionSelectionNode
import ViewControllerComponent
import ComponentFlow
import ComponentDisplayAdapters
import WallpaperBackgroundNode
import ReactionSelectionNode
import EntityKeyboard
import LottieMetal
import TelegramAnimatedStickerNode
import AnimatedStickerNode
import ChatInputTextNode
import UndoUI

func convertFrame(_ frame: CGRect, from fromView: UIView, to toView: UIView) -> CGRect {
    let sourceWindowFrame = fromView.convert(frame, to: nil)
    var targetWindowFrame = toView.convert(sourceWindowFrame, from: nil)
    
    if let fromWindow = fromView.window, let toWindow = toView.window {
        targetWindowFrame.origin.x += toWindow.bounds.width - fromWindow.bounds.width
    }
    return targetWindowFrame
}

final class ChatSendMessageContextScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id?
    let isScheduledMessages: Bool
    let forwardMessageIds: [EngineMessage.Id]?
    let hasEntityKeyboard: Bool
    let gesture: ContextGesture
    let sourceSendButton: ASDisplayNode
    let textInputView: UITextView
    let emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
    let wallpaperBackgroundNode: WallpaperBackgroundNode?
    let attachment: Bool
    let canSendWhenOnline: Bool
    let completion: () -> Void
    let sendMessage: (ChatSendMessageActionSheetController.SendMode, ChatSendMessageActionSheetController.MessageEffect?) -> Void
    let schedule: (ChatSendMessageActionSheetController.MessageEffect?) -> Void
    let reactionItems: [ReactionItem]?
    let availableMessageEffects: AvailableMessageEffects?
    let isPremium: Bool

    init(
        context: AccountContext,
        peerId: EnginePeer.Id?,
        isScheduledMessages: Bool,
        forwardMessageIds: [EngineMessage.Id]?,
        hasEntityKeyboard: Bool,
        gesture: ContextGesture,
        sourceSendButton: ASDisplayNode,
        textInputView: UITextView,
        emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?,
        wallpaperBackgroundNode: WallpaperBackgroundNode?,
        attachment: Bool,
        canSendWhenOnline: Bool,
        completion: @escaping () -> Void,
        sendMessage: @escaping (ChatSendMessageActionSheetController.SendMode, ChatSendMessageActionSheetController.MessageEffect?) -> Void,
        schedule: @escaping (ChatSendMessageActionSheetController.MessageEffect?) -> Void,
        reactionItems: [ReactionItem]?,
        availableMessageEffects: AvailableMessageEffects?,
        isPremium: Bool
    ) {
        self.context = context
        self.peerId = peerId
        self.isScheduledMessages = isScheduledMessages
        self.forwardMessageIds = forwardMessageIds
        self.hasEntityKeyboard = hasEntityKeyboard
        self.gesture = gesture
        self.sourceSendButton = sourceSendButton
        self.textInputView = textInputView
        self.emojiViewProvider = emojiViewProvider
        self.wallpaperBackgroundNode = wallpaperBackgroundNode
        self.attachment = attachment
        self.canSendWhenOnline = canSendWhenOnline
        self.completion = completion
        self.sendMessage = sendMessage
        self.schedule = schedule
        self.reactionItems = reactionItems
        self.availableMessageEffects = availableMessageEffects
        self.isPremium = isPremium
    }

    static func ==(lhs: ChatSendMessageContextScreenComponent, rhs: ChatSendMessageContextScreenComponent) -> Bool {
        return true
    }
    
    enum PresentationAnimationState {
        enum Key {
            case initial
            case animatedIn
            case animatedOut
        }
        
        case initial
        case animatedIn
        case animatedOut(completion: () -> Void)
        
        var key: Key {
            switch self {
            case .initial:
                return .initial
            case .animatedIn:
                return .animatedIn
            case .animatedOut:
                return .animatedOut
            }
        }
    }
    
    final class View: UIView {
        private let backgroundView: BlurredBackgroundView
        
        private var sendButton: SendButton?
        private var messageItemView: MessageItemView?
        private var actionsStackNode: ContextControllerActionsStackNode?
        private var reactionContextNode: ReactionContextNode?
        
        private let scrollView: UIScrollView
        
        private var component: ChatSendMessageContextScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let messageEffectDisposable = MetaDisposable()
        private var selectedMessageEffect: AvailableMessageEffects.MessageEffect?
        private var standaloneReactionAnimation: AnimatedStickerNode?
        
        private var isLoadingEffectAnimation: Bool = false
        private var loadEffectAnimationDisposable: Disposable?
        
        private var presentationAnimationState: PresentationAnimationState = .initial
        private var appliedAnimationState: PresentationAnimationState = .initial
        private var animateOutToEmpty: Bool = false
        
        private var initializationDisplayLink: SharedDisplayLinkDriver.Link?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            
            self.addSubview(self.scrollView)
            
            self.backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onBackgroundTap(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.messageEffectDisposable.dispose()
            self.loadEffectAnimationDisposable?.dispose()
        }
        
        @objc private func onBackgroundTap(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.environment?.controller()?.dismiss()
            }
        }
        
        @objc private func onSendButtonPressed() {
            guard let component = self.component else {
                return
            }
            self.animateOutToEmpty = true
            component.sendMessage(.generic, self.selectedMessageEffect.flatMap({ ChatSendMessageActionSheetController.MessageEffect(id: $0.id) }))
            self.environment?.controller()?.dismiss()
        }
        
        func animateIn() {
            if case .initial = self.presentationAnimationState {
                self.presentationAnimationState = .animatedIn
                self.state?.updated(transition: .spring(duration: 0.42))
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            if case .animatedOut = self.presentationAnimationState {
            } else {
                self.presentationAnimationState = .animatedOut(completion: completion)
                self.state?.updated(transition: .spring(duration: 0.4))
            }
        }
        
        private func requestUpdateOverlayWantsToBeBelowKeyboard(transition: ContainedViewLayoutTransition) {
            guard let controller = self.environment?.controller() as? ChatSendMessageContextScreen else {
                return
            }
            controller.overlayWantsToBeBelowKeyboardUpdated(transition: transition)
        }
        
        func wantsToBeBelowKeyboard() -> Bool {
            if let reactionContextNode = self.reactionContextNode {
                return reactionContextNode.wantsDisplayBelowKeyboard()
            }
            return false
        }

        func update(component: ChatSendMessageContextScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousAnimationState = self.appliedAnimationState
            self.appliedAnimationState = self.presentationAnimationState
            
            let messageActionsSpacing: CGFloat = 7.0
            
            let alphaTransition: Transition
            if transition.animation.isImmediate {
                alphaTransition = .immediate
            } else {
                alphaTransition = .easeInOut(duration: 0.25)
            }
            let _ = alphaTransition
            
            let environment = environment[EnvironmentType.self].value
            
            let themeUpdated = environment.theme !== self.environment?.theme
            
            if self.component == nil {
                component.gesture.externalUpdated = { [weak self] view, location in
                    guard let self, let actionsStackNode = self.actionsStackNode else {
                        return
                    }
                    actionsStackNode.highlightGestureMoved(location: actionsStackNode.view.convert(location, from: view))
                }
                component.gesture.externalEnded = { [weak self] viewAndLocation in
                    guard let self, let actionsStackNode = self.actionsStackNode else {
                        return
                    }
                    if let (view, location) = viewAndLocation {
                        actionsStackNode.highlightGestureMoved(location: actionsStackNode.view.convert(location, from: view))
                        actionsStackNode.highlightGestureFinished(performAction: true)
                    } else {
                        actionsStackNode.highlightGestureFinished(performAction: false)
                    }
                }
            }
            
            self.component = component
            self.environment = environment
            self.state = state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            
            if themeUpdated {
                self.backgroundView.updateColor(
                    color: environment.theme.contextMenu.dimColor,
                    enableBlur: true,
                    forceKeepBlur: true,
                    transition: .immediate
                )
            }
            
            let sendButton: SendButton
            if let current = self.sendButton {
                sendButton = current
            } else {
                sendButton = SendButton()
                sendButton.accessibilityLabel = environment.strings.MediaPicker_Send
                sendButton.addTarget(self, action: #selector(self.onSendButtonPressed), for: .touchUpInside)
                /*if let snapshotView = component.sourceSendButton.view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.isUserInteractionEnabled = false
                    sendButton.addSubview(snapshotView)
                }*/
                self.sendButton = sendButton
                self.addSubview(sendButton)
            }
            
            let sourceSendButtonFrame = convertFrame(component.sourceSendButton.bounds, from: component.sourceSendButton.view, to: self)
            
            sendButton.update(
                context: component.context,
                presentationData: presentationData,
                backgroundNode: component.wallpaperBackgroundNode,
                isLoadingEffectAnimation: self.isLoadingEffectAnimation,
                size: sourceSendButtonFrame.size,
                transition: transition
            )
            
            let sendButtonScale: CGFloat
            switch self.presentationAnimationState {
            case .initial:
                sendButtonScale = 0.75
            default:
                sendButtonScale = 1.0
            }
            
            let actionsStackNode: ContextControllerActionsStackNode
            if let current = self.actionsStackNode {
                actionsStackNode = current
            } else {
                actionsStackNode = ContextControllerActionsStackNode(
                    getController: {
                        return nil
                    },
                    requestDismiss: { _ in
                    },
                    requestUpdate: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: Transition(transition))
                        }
                    }
                )
                actionsStackNode.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                
                var reminders = false
                var isSecret = false
                var canSchedule = false
                if let peerId = component.peerId {
                    reminders = peerId == component.context.account.peerId
                    isSecret = peerId.namespace == Namespaces.Peer.SecretChat
                    canSchedule = !isSecret
                }
                if component.isScheduledMessages {
                    canSchedule = false
                }
                
                var items: [ContextMenuItem] = []
                if !reminders {
                    items.append(.action(ContextMenuActionItem(
                        text: environment.strings.Conversation_SendMessage_SendSilently,
                        icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            self.animateOutToEmpty = true
                            component.sendMessage(.silently, self.selectedMessageEffect.flatMap({ ChatSendMessageActionSheetController.MessageEffect(id: $0.id) }))
                            self.environment?.controller()?.dismiss()
                        }
                    )))
                    
                    if component.canSendWhenOnline && canSchedule {
                        items.append(.action(ContextMenuActionItem(
                            text: environment.strings.Conversation_SendMessage_SendWhenOnline,
                            icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/WhenOnlineIcon"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, _ in
                                guard let self, let component = self.component else {
                                    return
                                }
                                self.animateOutToEmpty = true
                                component.sendMessage(.whenOnline, self.selectedMessageEffect.flatMap({ ChatSendMessageActionSheetController.MessageEffect(id: $0.id) }))
                                self.environment?.controller()?.dismiss()
                            }
                        )))
                    }
                }
                if canSchedule {
                    items.append(.action(ContextMenuActionItem(
                        text: reminders ? environment.strings.Conversation_SendMessage_SetReminder: environment.strings.Conversation_SendMessage_ScheduleMessage,
                        icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.schedule(nil)
                            self.environment?.controller()?.dismiss()
                        }
                    )))
                }
                
                actionsStackNode.push(
                    item: ContextControllerActionsListStackItem(
                        id: nil,
                        items: items,
                        reactionItems: nil,
                        tip: nil,
                        tipSignal: .single(nil),
                        dismissed: nil
                    ),
                    currentScrollingState: nil,
                    positionLock: nil,
                    animated: false
                )
                self.actionsStackNode = actionsStackNode
                self.addSubview(actionsStackNode.view)
            }
            let actionsStackSize = actionsStackNode.update(
                presentationData: presentationData,
                constrainedSize: availableSize,
                presentation: .modal,
                transition: transition.containedViewLayoutTransition
            )
            
            let messageItemView: MessageItemView
            if let current = self.messageItemView {
                messageItemView = current
            } else {
                messageItemView = MessageItemView(frame: CGRect())
                self.messageItemView = messageItemView
                self.addSubview(messageItemView)
            }
            
            let textString: NSAttributedString
            if let attributedText = component.textInputView.attributedText {
                textString = attributedText
            } else {
                textString = NSAttributedString(string: " ", font: Font.regular(17.0), textColor: .black)
            }
            
            let localSourceTextInputViewFrame = convertFrame(component.textInputView.bounds, from: component.textInputView, to: self)
            
            let sourceMessageTextInsets = UIEdgeInsets(top: 7.0, left: 12.0, bottom: 6.0, right: 20.0)
            let sourceBackgroundSize = CGSize(width: localSourceTextInputViewFrame.width + 32.0, height: localSourceTextInputViewFrame.height + 4.0)
            let explicitMessageBackgroundSize: CGSize?
            switch self.presentationAnimationState {
            case .initial:
                explicitMessageBackgroundSize = sourceBackgroundSize
            case .animatedOut:
                if self.animateOutToEmpty {
                    explicitMessageBackgroundSize = nil
                } else {
                    explicitMessageBackgroundSize = sourceBackgroundSize
                }
            case .animatedIn:
                explicitMessageBackgroundSize = nil
            }
            
            let messageTextInsets = sourceMessageTextInsets
            
            var maxTextHeight: CGFloat = availableSize.height - 8.0
            if let reactionItems = component.reactionItems, !reactionItems.isEmpty {
                if let reactionContextNode = self.reactionContextNode, reactionContextNode.isExpanded {
                    maxTextHeight -= 300.0 + 8.0
                } else {
                    maxTextHeight -= 60.0 + 14.0
                }
            }
            maxTextHeight -= environment.statusBarHeight + 14.0
            if environment.inputHeight != 0.0 {
                maxTextHeight -= environment.inputHeight
            } else {
                maxTextHeight -= actionsStackSize.height
                maxTextHeight -= environment.safeInsets.bottom
            }
            
            let messageItemSize = messageItemView.update(
                context: component.context,
                presentationData: presentationData,
                backgroundNode: component.wallpaperBackgroundNode,
                textString: textString,
                sourceTextInputView: component.textInputView as? ChatInputTextView,
                textInsets: messageTextInsets,
                explicitBackgroundSize: explicitMessageBackgroundSize,
                maxTextWidth: localSourceTextInputViewFrame.width,
                maxTextHeight: maxTextHeight,
                effect: self.presentationAnimationState.key == .animatedIn ? self.selectedMessageEffect : nil,
                transition: transition
            )
            let sourceMessageItemFrame = CGRect(origin: CGPoint(x: localSourceTextInputViewFrame.minX - sourceMessageTextInsets.left, y: localSourceTextInputViewFrame.minY - 2.0), size: messageItemSize)
            
            if let reactionItems = component.reactionItems, !reactionItems.isEmpty {
                let reactionContextNode: ReactionContextNode
                if let current = self.reactionContextNode {
                    reactionContextNode = current
                } else {
                    //TODO:localize
                    reactionContextNode = ReactionContextNode(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        presentationData: presentationData,
                        items: reactionItems.map { item in
                            var icon: EmojiPagerContentComponent.Item.Icon = .none
                            if !component.isPremium, case let .custom(sourceEffectId) = item.reaction.rawValue, let availableMessageEffects = component.availableMessageEffects {
                                for messageEffect in availableMessageEffects.messageEffects {
                                    if messageEffect.id == sourceEffectId || messageEffect.effectSticker.fileId.id == sourceEffectId {
                                        if messageEffect.isPremium {
                                            icon = .locked
                                        }
                                        break
                                    }
                                }
                            }
                            
                            return ReactionContextItem.reaction(item: item, icon: icon)
                        },
                        selectedItems: Set(),
                        title: "Add an animated effect",
                        reactionsLocked: false,
                        alwaysAllowPremiumReactions: false,
                        allPresetReactionsAreAvailable: true,
                        getEmojiContent: { animationCache, animationRenderer in
                            return EmojiPagerContentComponent.messageEffectsInputData(
                                context: component.context,
                                animationCache: animationCache,
                                animationRenderer: animationRenderer,
                                hasSearch: true,
                                hideBackground: false
                            )
                        },
                        isExpandedUpdated: { [weak self] transition in
                            guard let self else {
                                return
                            }
                            if !self.isUpdating {
                                self.state?.updated(transition: Transition(transition))
                            }
                        },
                        requestLayout: { [weak self] transition in
                            guard let self else {
                                return
                            }
                            if !self.isUpdating {
                                self.state?.updated(transition: Transition(transition))
                            }
                        },
                        requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                            guard let self else {
                                return
                            }
                            self.requestUpdateOverlayWantsToBeBelowKeyboard(transition: transition)
                        }
                    )
                    reactionContextNode.reactionSelected = { [weak self] updateReaction, _ in
                        guard let self, let component = self.component, let reactionContextNode = self.reactionContextNode else {
                            return
                        }
                        
                        guard case let .custom(sourceEffectId, _) = updateReaction else {
                            return
                        }
                        
                        let messageEffect: Signal<AvailableMessageEffects.MessageEffect?, NoError>
                        messageEffect = component.context.engine.stickers.availableMessageEffects()
                        |> take(1)
                        |> map { availableMessageEffects -> AvailableMessageEffects.MessageEffect? in
                            guard let availableMessageEffects else {
                                return nil
                            }
                            for messageEffect in availableMessageEffects.messageEffects {
                                if messageEffect.id == sourceEffectId || messageEffect.effectSticker.fileId.id == sourceEffectId {
                                    return messageEffect
                                }
                            }
                            return nil
                        }
                        
                        self.messageEffectDisposable.set((messageEffect
                        |> deliverOnMainQueue).startStrict(next: { [weak self] messageEffect in
                            guard let self, let component = self.component else {
                                return
                            }
                            guard let messageEffect else {
                                return
                            }
                            let effectId = messageEffect.id
                            
                            if let selectedMessageEffect = self.selectedMessageEffect {
                                if selectedMessageEffect.id == effectId {
                                    self.selectedMessageEffect = nil
                                    reactionContextNode.selectedItems = Set([])
                                    self.loadEffectAnimationDisposable?.dispose()
                                    self.isLoadingEffectAnimation = false
                                    
                                    if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                                        self.standaloneReactionAnimation = nil
                                        standaloneReactionAnimation.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak standaloneReactionAnimation] _ in
                                            standaloneReactionAnimation?.removeFromSupernode()
                                        })
                                    }
                                    
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                                    }
                                    return
                                } else {
                                    self.selectedMessageEffect = messageEffect
                                    reactionContextNode.selectedItems = Set([AnyHashable(updateReaction.reaction)])
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                                    }
                                    
                                    HapticFeedback().tap()
                                }
                            } else {
                                self.selectedMessageEffect = messageEffect
                                reactionContextNode.selectedItems = Set([AnyHashable(updateReaction.reaction)])
                                if !self.isUpdating {
                                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                                }
                                
                                HapticFeedback().tap()
                            }
                            
                            self.loadEffectAnimationDisposable?.dispose()
                            self.isLoadingEffectAnimation = true
                            if !self.isUpdating {
                                self.state?.updated(transition: .easeInOut(duration: 0.2))
                            }
                            
                            if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                                self.standaloneReactionAnimation = nil
                                standaloneReactionAnimation.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak standaloneReactionAnimation] _ in
                                    standaloneReactionAnimation?.removeFromSupernode()
                                })
                            }
                            
                            var customEffectResource: (FileMediaReference, MediaResource)?
                            if let effectAnimation = messageEffect.effectAnimation {
                                customEffectResource = (FileMediaReference.standalone(media: effectAnimation), effectAnimation.resource)
                            } else {
                                let effectSticker = messageEffect.effectSticker
                                if let effectFile = effectSticker.videoThumbnails.first {
                                    customEffectResource = (FileMediaReference.standalone(media: effectSticker), effectFile.resource)
                                }
                            }
                            guard let (customEffectResourceFileReference, customEffectResource) = customEffectResource else {
                                return
                            }
                            
                            let context = component.context
                            var loadEffectAnimationSignal: Signal<Never, NoError>
                            loadEffectAnimationSignal = Signal { subscriber in
                                let fetchDisposable = freeMediaFileResourceInteractiveFetched(account: context.account, userLocation: .other, fileReference: customEffectResourceFileReference, resource: customEffectResource).start()
                                
                                let dataDisposabke = (context.account.postbox.mediaBox.resourceStatus(customEffectResource)
                                |> filter { status in
                                    if status == .Local {
                                        return true
                                    } else {
                                        return false
                                    }
                                }
                                |> take(1)).start(next: { _ in
                                    subscriber.putCompletion()
                                })
                                
                                return ActionDisposable {
                                    fetchDisposable.dispose()
                                    dataDisposabke.dispose()
                                }
                            }
                            #if DEBUG
                            loadEffectAnimationSignal = loadEffectAnimationSignal |> delay(1.0, queue: .mainQueue())
                            #endif
                            
                            self.loadEffectAnimationDisposable = (loadEffectAnimationSignal
                            |> deliverOnMainQueue).start(completed: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                
                                self.isLoadingEffectAnimation = false
                                
                                guard let targetView = self.messageItemView?.effectIconView else {
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                                    }
                                    return
                                }
                                
                                let standaloneReactionAnimation: AnimatedStickerNode
                                #if targetEnvironment(simulator)
                                standaloneReactionAnimation = DirectAnimatedStickerNode()
                                #else
                                standaloneReactionAnimation = LottieMetalAnimatedStickerNode()
                                #endif
                                
                                standaloneReactionAnimation.isUserInteractionEnabled = false
                                let effectSize = CGSize(width: 380.0, height: 380.0)
                                var effectFrame = effectSize.centered(around: targetView.convert(targetView.bounds.center, to: self))
                                effectFrame.origin.x -= effectFrame.width * 0.3
                                self.standaloneReactionAnimation = standaloneReactionAnimation
                                standaloneReactionAnimation.frame = effectFrame
                                standaloneReactionAnimation.updateLayout(size: effectFrame.size)
                                self.addSubnode(standaloneReactionAnimation)
                                
                                let pathPrefix = component.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(customEffectResource.id)
                                let source = AnimatedStickerResourceSource(account: component.context.account, resource: customEffectResource, fitzModifier: nil)
                                standaloneReactionAnimation.setup(source: source, width: Int(effectSize.width), height: Int(effectSize.height), playbackMode: .once, mode: .direct(cachePathPrefix: pathPrefix))
                                standaloneReactionAnimation.completed = { [weak self, weak standaloneReactionAnimation] _ in
                                    guard let self else {
                                        return
                                    }
                                    if let standaloneReactionAnimation {
                                        standaloneReactionAnimation.removeFromSupernode()
                                        if self.standaloneReactionAnimation === standaloneReactionAnimation {
                                            self.standaloneReactionAnimation = nil
                                        }
                                    }
                                }
                                standaloneReactionAnimation.visibility = true
                                
                                if !self.isUpdating {
                                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                                }
                            })
                        }))
                    }
                    reactionContextNode.premiumReactionsSelected = { [weak self] _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        //TODO:localize
                        let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                        self.environment?.controller()?.present(UndoOverlayController(
                            presentationData: presentationData,
                            content: .premiumPaywall(
                                title: nil,
                                text: "Subscribe to [TelegramPremium]() to add this animated effect.",
                                customUndoText: nil,
                                timeout: nil,
                                linkAction: nil
                            ),
                            elevatedLayout: false,
                            action: { [weak self] action in
                                guard let self, let component = self.component else {
                                    return false
                                }
                                if case .info = action {
                                    self.window?.endEditing(true)
                                    
                                    //TODO:localize
                                    let premiumController = component.context.sharedContext.makePremiumIntroController(context: component.context, source: .animatedEmoji, forceDark: false, dismissed: nil)
                                    let _ = premiumController
                                    //parentNavigationController.pushViewController(premiumController)
                                }
                                return false
                            }
                        ), in: .current)
                    }
                    reactionContextNode.displayTail = true
                    reactionContextNode.forceTailToRight = false
                    reactionContextNode.forceDark = false
                    reactionContextNode.isMessageEffects = true
                    self.reactionContextNode = reactionContextNode
                    self.addSubview(reactionContextNode.view)
                }
            }
            
            let sourceActionsStackFrame = CGRect(origin: CGPoint(x: sourceSendButtonFrame.minX + 1.0 - actionsStackSize.width, y: sourceMessageItemFrame.maxY + messageActionsSpacing), size: actionsStackSize)
            
            var readySendButtonFrame = CGRect(origin: CGPoint(x: sourceSendButtonFrame.minX, y: sourceSendButtonFrame.minY), size: sourceSendButtonFrame.size)
            var readyMessageItemFrame = CGRect(origin: CGPoint(x: readySendButtonFrame.minX + 8.0 - messageItemSize.width, y: readySendButtonFrame.maxY - 6.0 - messageItemSize.height), size: messageItemSize)
            var readyActionsStackFrame = CGRect(origin: CGPoint(x: readySendButtonFrame.minX + 1.0 - actionsStackSize.width, y: readyMessageItemFrame.maxY + messageActionsSpacing), size: actionsStackSize)
            
            let bottomOverflow = readyActionsStackFrame.maxY - (availableSize.height - environment.safeInsets.bottom)
            if bottomOverflow > 0.0 {
                readyMessageItemFrame.origin.y -= bottomOverflow
                readyActionsStackFrame.origin.y -= bottomOverflow
                readySendButtonFrame.origin.y -= bottomOverflow
            }
            
            let inputCoverOverflow = readyMessageItemFrame.maxY + 7.0 - (availableSize.height - environment.inputHeight)
            if inputCoverOverflow > 0.0 {
                readyMessageItemFrame.origin.y -= inputCoverOverflow
                readyActionsStackFrame.origin.y -= inputCoverOverflow
                readySendButtonFrame.origin.y -= inputCoverOverflow
            }
            
            let messageItemFrame: CGRect
            let actionsStackFrame: CGRect
            let sendButtonFrame: CGRect
            switch self.presentationAnimationState {
            case .initial:
                messageItemFrame = sourceMessageItemFrame
                actionsStackFrame = sourceActionsStackFrame
                sendButtonFrame = sourceSendButtonFrame
            case .animatedOut:
                if self.animateOutToEmpty {
                    messageItemFrame = readyMessageItemFrame
                    actionsStackFrame = readyActionsStackFrame
                    sendButtonFrame = readySendButtonFrame
                } else {
                    messageItemFrame = sourceMessageItemFrame
                    actionsStackFrame = sourceActionsStackFrame
                    sendButtonFrame = sourceSendButtonFrame
                }
            case .animatedIn:
                messageItemFrame = readyMessageItemFrame
                actionsStackFrame = readyActionsStackFrame
                sendButtonFrame = readySendButtonFrame
            }
            
            transition.setFrame(view: messageItemView, frame: messageItemFrame)
            
            transition.setPosition(view: actionsStackNode.view, position: CGPoint(x: actionsStackFrame.maxX, y: actionsStackFrame.minY))
            transition.setBounds(view: actionsStackNode.view, bounds: CGRect(origin: CGPoint(), size: actionsStackFrame.size))
            if !transition.animation.isImmediate && previousAnimationState.key != self.presentationAnimationState.key {
                switch self.presentationAnimationState {
                case .initial:
                    break
                case .animatedIn:
                    transition.setAlpha(view: actionsStackNode.view, alpha: 1.0)
                    Transition.immediate.setScale(view: actionsStackNode.view, scale: 1.0)
                    actionsStackNode.layer.animateSpring(from: 0.001 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.42, damping: 104.0)
                case .animatedOut:
                    transition.setAlpha(view: actionsStackNode.view, alpha: 0.0)
                    transition.setScale(view: actionsStackNode.view, scale: 0.001)
                }
            } else {
                switch self.presentationAnimationState {
                case .animatedIn:
                    transition.setAlpha(view: actionsStackNode.view, alpha: 1.0)
                    transition.setScale(view: actionsStackNode.view, scale: 1.0)
                case .animatedOut, .initial:
                    transition.setAlpha(view: actionsStackNode.view, alpha: 0.0)
                    transition.setScale(view: actionsStackNode.view, scale: 0.001)
                }
            }
            
            if let reactionContextNode = self.reactionContextNode {
                let size = availableSize
                let reactionsAnchorRect = messageItemFrame
                transition.setFrame(view: reactionContextNode.view, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
                reactionContextNode.updateLayout(size: size, insets: UIEdgeInsets(), anchorRect: reactionsAnchorRect, centerAligned: false, isCoveredByInput: false, isAnimatingOut: false, transition: transition.containedViewLayoutTransition)
                reactionContextNode.updateIsIntersectingContent(isIntersectingContent: false, transition: .immediate)
                if self.presentationAnimationState.key == .animatedIn && previousAnimationState.key == .initial {
                    reactionContextNode.animateIn(from: reactionsAnchorRect)
                } else if self.presentationAnimationState.key == .animatedOut && previousAnimationState.key == .animatedIn {
                    reactionContextNode.animateOut(to: nil, animatingOutToReaction: false)
                }
            }
            if case .animatedOut = self.presentationAnimationState {
                if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                    self.standaloneReactionAnimation = nil
                    standaloneReactionAnimation.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak standaloneReactionAnimation] _ in
                        standaloneReactionAnimation?.removeFromSupernode()
                    })
                }
            }
            
            transition.setPosition(view: sendButton, position: sendButtonFrame.center)
            transition.setBounds(view: sendButton, bounds: CGRect(origin: CGPoint(), size: sendButtonFrame.size))
            transition.setScale(view: sendButton, scale: sendButtonScale)
            sendButton.updateGlobalRect(rect: sendButtonFrame, within: availableSize, transition: transition)
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.backgroundView.update(size: availableSize, transition: transition.containedViewLayoutTransition)
            let backgroundAlpha: CGFloat
            switch self.presentationAnimationState {
            case .animatedIn:
                if previousAnimationState.key == .initial && self.initializationDisplayLink == nil {
                    self.initializationDisplayLink = SharedDisplayLinkDriver.shared.add({ [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        self.initializationDisplayLink?.invalidate()
                        self.initializationDisplayLink = nil
                        
                        guard let component = self.component else {
                            return
                        }
                        component.textInputView.isHidden = true
                        component.sourceSendButton.isHidden = true
                    })
                }
                
                backgroundAlpha = 1.0
            case .animatedOut:
                backgroundAlpha = 0.0
                
                if self.animateOutToEmpty {
                    component.textInputView.isHidden = false
                    component.sourceSendButton.isHidden = false
                    
                    transition.setAlpha(view: sendButton, alpha: 0.0)
                    if let messageItemView = self.messageItemView {
                        transition.setAlpha(view: messageItemView, alpha: 0.0)
                    }
                }
            default:
                backgroundAlpha = 0.0
            }
            
            transition.setAlpha(view: self.backgroundView, alpha: backgroundAlpha, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                if case let .animatedOut(completion) = self.presentationAnimationState {
                    if let component = self.component, !self.animateOutToEmpty {
                        component.textInputView.isHidden = false
                        component.sourceSendButton.isHidden = false
                    }
                    completion()
                }
            })
            
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

public class ChatSendMessageContextScreen: ViewControllerComponentContainer, ChatSendMessageActionSheetController {
    private let context: AccountContext
    
    private var processedDidAppear: Bool = false
    private var processedDidDisappear: Bool = false
    
    override public var overlayWantsToBeBelowKeyboard: Bool {
        if let componentView = self.node.hostView.componentView as? ChatSendMessageContextScreenComponent.View {
            return componentView.wantsToBeBelowKeyboard()
        } else {
            return false
        }
    }
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
        peerId: EnginePeer.Id?,
        isScheduledMessages: Bool,
        forwardMessageIds: [EngineMessage.Id]?,
        hasEntityKeyboard: Bool,
        gesture: ContextGesture,
        sourceSendButton: ASDisplayNode,
        textInputView: UITextView,
        emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?,
        wallpaperBackgroundNode: WallpaperBackgroundNode?,
        attachment: Bool,
        canSendWhenOnline: Bool,
        completion: @escaping () -> Void,
        sendMessage: @escaping (ChatSendMessageActionSheetController.SendMode, ChatSendMessageActionSheetController.MessageEffect?) -> Void,
        schedule: @escaping (ChatSendMessageActionSheetController.MessageEffect?) -> Void,
        reactionItems: [ReactionItem]?,
        availableMessageEffects: AvailableMessageEffects?,
        isPremium: Bool
    ) {
        self.context = context
        
        super.init(
            context: context,
            component: ChatSendMessageContextScreenComponent(
                context: context,
                peerId: peerId,
                isScheduledMessages: isScheduledMessages,
                forwardMessageIds: forwardMessageIds,
                hasEntityKeyboard: hasEntityKeyboard,
                gesture: gesture,
                sourceSendButton: sourceSendButton,
                textInputView: textInputView,
                emojiViewProvider: emojiViewProvider,
                wallpaperBackgroundNode: wallpaperBackgroundNode,
                attachment: attachment,
                canSendWhenOnline: canSendWhenOnline,
                completion: completion,
                sendMessage: sendMessage,
                schedule: schedule,
                reactionItems: reactionItems,
                availableMessageEffects: availableMessageEffects,
                isPremium: isPremium
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .none,
            presentationMode: .default
        )
        
        self.lockOrientation = true
        self.blocksBackgroundWhenInOverlay = true
        
        /*gesture.externalEnded = { [weak self] _ in
            guard let self else {
                return
            }
            self.dismiss()
        }*/
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.processedDidAppear {
            self.processedDidAppear = true
            if let componentView = self.node.hostView.componentView as? ChatSendMessageContextScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
    
    private func superDismiss() {
        super.dismiss()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.processedDidDisappear {
            self.processedDidDisappear = true
            
            if let componentView = self.node.hostView.componentView as? ChatSendMessageContextScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    if let self {
                        self.superDismiss()
                    }
                    completion?()
                })
            } else {
                super.dismiss(completion: completion)
            }
        }
    }
}
