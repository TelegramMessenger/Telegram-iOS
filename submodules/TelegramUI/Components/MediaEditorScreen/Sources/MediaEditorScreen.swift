import Foundation
import UIKit
import CoreServices
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import DrawingUI
import MediaEditor
import Photos
import LottieAnimationComponent
import MessageInputPanelComponent
import TextFieldComponent
import EntityKeyboard
import TooltipUI
import PlainButtonComponent
import AvatarNode
import ShareWithPeersScreen
import PresentationDataUtils
import ContextUI
import BundleIconComponent
import CameraButtonComponent
import UndoUI
import ChatEntityKeyboardInputNode
import ChatPresentationInterfaceState
import TextFormat
import DeviceAccess
import LocationUI

enum DrawingScreenType {
    case drawing
    case text
    case sticker
}

private let muteButtonTag = GenericComponentViewTag()
private let saveButtonTag = GenericComponentViewTag()

final class MediaEditorScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    public final class ExternalState {
        public fileprivate(set) var derivedInputHeight: CGFloat = 0.0
        
        public init() {
        }
    }
    
    let context: AccountContext
    let externalState: ExternalState
    let isDisplayingTool: Bool
    let isInteractingWithEntities: Bool
    let isSavingAvailable: Bool
    let hasAppeared: Bool
    let isDismissing: Bool
    let bottomSafeInset: CGFloat
    let mediaEditor: Signal<MediaEditor?, NoError>
    let privacy: MediaEditorResultPrivacy
    let selectedEntity: DrawingEntity?
    let entityViewForEntity: (DrawingEntity) -> DrawingEntityView?
    let openDrawing: (DrawingScreenType) -> Void
    let openTools: () -> Void
    
    init(
        context: AccountContext,
        externalState: ExternalState,
        isDisplayingTool: Bool,
        isInteractingWithEntities: Bool,
        isSavingAvailable: Bool,
        hasAppeared: Bool,
        isDismissing: Bool,
        bottomSafeInset: CGFloat,
        mediaEditor: Signal<MediaEditor?, NoError>,
        privacy: MediaEditorResultPrivacy,
        selectedEntity: DrawingEntity?,
        entityViewForEntity: @escaping (DrawingEntity) -> DrawingEntityView?,
        openDrawing: @escaping (DrawingScreenType) -> Void,
        openTools: @escaping () -> Void
    ) {
        self.context = context
        self.externalState = externalState
        self.isDisplayingTool = isDisplayingTool
        self.isInteractingWithEntities = isInteractingWithEntities
        self.isSavingAvailable = isSavingAvailable
        self.hasAppeared = hasAppeared
        self.isDismissing = isDismissing
        self.bottomSafeInset = bottomSafeInset
        self.mediaEditor = mediaEditor
        self.privacy = privacy
        self.selectedEntity = selectedEntity
        self.entityViewForEntity = entityViewForEntity
        self.openDrawing = openDrawing
        self.openTools = openTools
    }
    
    static func ==(lhs: MediaEditorScreenComponent, rhs: MediaEditorScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.isDisplayingTool != rhs.isDisplayingTool {
            return false
        }
        if lhs.isInteractingWithEntities != rhs.isInteractingWithEntities {
            return false
        }
        if lhs.isSavingAvailable != rhs.isSavingAvailable {
            return false
        }
        if lhs.hasAppeared != rhs.hasAppeared {
            return false
        }
        if lhs.isDismissing != rhs.isDismissing {
            return false
        }
        if lhs.bottomSafeInset != rhs.bottomSafeInset {
            return false
        }
        if lhs.privacy != rhs.privacy {
            return false
        }
        if lhs.selectedEntity?.uuid != rhs.selectedEntity?.uuid {
            return false
        }
        return true
    }

    final class State: ComponentState {
        enum ImageKey: Hashable {
            case draw
            case text
            case sticker
            case tools
            case done
        }
        private var cachedImages: [ImageKey: UIImage] = [:]
        func image(_ key: ImageKey) -> UIImage {
            if let image = self.cachedImages[key] {
                return image
            } else {
                var image: UIImage
                switch key {
                case .draw:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Pencil"), color: .white)!
                case .text:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/AddText"), color: .white)!
                case .sticker:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/AddSticker"), color: .white)!
                case .tools:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Tools"), color: .white)!
                case .done:
                    image = generateImage(CGSize(width: 33.0, height: 33.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(UIColor.white.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                        context.setBlendMode(.copy)
                        context.setStrokeColor(UIColor.black.cgColor)
                        context.setLineWidth(2.0)
                        context.setLineCap(.round)
                        context.setLineJoin(.round)
                        
                        context.translateBy(x: 5.45, y: 4.0)
                        
                        context.saveGState()
                        context.translateBy(x: 4.0, y: 4.0)
                        let _ = try? drawSvgPath(context, path: "M1,7 L7,1 L13,7 S ")
                        context.restoreGState()
                        
                        context.saveGState()
                        context.translateBy(x: 10.0, y: 4.0)
                        let _ = try? drawSvgPath(context, path: "M1,16 V1 S ")
                        context.restoreGState()
                    })!
                }
                cachedImages[key] = image
                return image
            }
        }
        
        let context: AccountContext
        var playerStateDisposable: Disposable?
        var playerState: MediaEditorPlayerState?
        
        var isPremium = false
        var isPremiumDisposable: Disposable?
        
        init(context: AccountContext, mediaEditor: Signal<MediaEditor?, NoError>) {
            self.context = context
            
            super.init()
            
            self.playerStateDisposable = (mediaEditor
            |> mapToSignal { mediaEditor in
                if let mediaEditor {
                    return mediaEditor.playerState(framesCount: 16)
                } else {
                    return .complete()
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] playerState in
                if let self {
                    self.playerState = playerState
                    self.updated()
                }
            })
            
            self.isPremiumDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                if let self {
                    self.isPremium = peer?.isPremium ?? false
                    self.updated()
                }
            })
        }
        
        deinit {
            self.playerStateDisposable?.dispose()
            self.isPremiumDisposable?.dispose()
        }
        
        var muteDidChange = false
    }
    
    func makeState() -> State {
        return State(
            context: self.context,
            mediaEditor: self.mediaEditor
        )
    }
    
    public final class View: UIView {
        private let cancelButton = ComponentView<Empty>()
        private let drawButton = ComponentView<Empty>()
        private let textButton = ComponentView<Empty>()
        private let stickerButton = ComponentView<Empty>()
        private let toolsButton = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
        
        private let fadeView = UIButton()
        
        fileprivate let inputPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        private let inputPanelBackground = ComponentView<Empty>()
        
        private let scrubber = ComponentView<Empty>()
        
        private let flipStickerButton = ComponentView<Empty>()
        private let muteButton = ComponentView<Empty>()
        private let saveButton = ComponentView<Empty>()
        
        private let textCancelButton = ComponentView<Empty>()
        private let textDoneButton = ComponentView<Empty>()
        private let textSize =  ComponentView<Empty>()
        
        private var isDismissed = false
        
        private var isEditingCaption = false
        private var currentInputMode: MessageInputPanelComponent.InputMode = .text
        
        private var didInitializeInputMediaNodeDataPromise = false
        private var inputMediaNodeData: ChatEntityKeyboardInputNode.InputData?
        private var inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
        private var inputMediaNodeDataDisposable: Disposable?
        private var inputMediaNodeStateContext = ChatEntityKeyboardInputNode.StateContext()
        private var inputMediaInteraction: ChatEntityKeyboardInputNode.Interaction?
        private var inputMediaNode: ChatEntityKeyboardInputNode?
                
        private var component: MediaEditorScreenComponent?
        private weak var state: State?
        private var environment: ViewControllerComponentContainer.Environment?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                        
            self.backgroundColor = .clear
            
            self.fadeView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
            self.fadeView.addTarget(self, action: #selector(self.deactivateInput), for: .touchUpInside)
            self.fadeView.alpha = 0.0
            
            self.addSubview(self.fadeView)
            
            self.inputMediaNodeDataDisposable = (self.inputMediaNodeDataPromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let self else {
                    return
                }
                self.inputMediaNodeData = value
            })
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.inputMediaNodeDataDisposable?.dispose()
        }
        
        private func setupIfNeeded() {
            guard let component = self.component else {
                return
            }
            
            if !self.didInitializeInputMediaNodeDataPromise {
                self.didInitializeInputMediaNodeDataPromise = true
                
                let context = component.context
                
                self.inputMediaNodeDataPromise.set(
                    ChatEntityKeyboardInputNode.inputData(
                        context: context,
                        chatPeerId: nil,
                        areCustomEmojiEnabled: true,
                        hasSearch: true,
                        hideBackground: true,
                        sendGif: nil
                    ) |> map { inputData -> ChatEntityKeyboardInputNode.InputData in
                        return ChatEntityKeyboardInputNode.InputData(
                            emoji: inputData.emoji,
                            stickers: nil,
                            gifs: nil,
                            availableGifSearchEmojies: []
                        )
                    }
                )
                
                self.inputMediaInteraction = ChatEntityKeyboardInputNode.Interaction(
                    sendSticker: { _, _, _, _, _, _, _, _, _ in
                        return false
                    },
                    sendEmoji: { [weak self] text, attribute, bool1 in
                        if let self {
                            let _ = self
                        }
                    },
                    sendGif: { _, _, _, _, _ in
                        return false
                    },
                    sendBotContextResultAsGif: { _, _, _, _, _, _ in
                        return false
                    },
                    updateChoosingSticker: { _ in },
                    switchToTextInput: { [weak self] in
                        if let self {
                            self.activateInput()
                        }
                    },
                    dismissTextInput: {

                    },
                    insertText: { [weak self] text in
                        if let self {
                            self.inputPanelExternalState.insertText(text)
                        }
                    },
                    backwardsDeleteText: { [weak self] in
                        if let self {
                            self.inputPanelExternalState.deleteBackward()
                        }
                    },
                    presentController: { [weak self] c, a in
                        if let self {
                            self.environment?.controller()?.present(c, in: .window(.root), with: a)
                        }
                    },
                    presentGlobalOverlayController: { [weak self] c, a in
                        if let self {
                            self.environment?.controller()?.presentInGlobalOverlay(c, with: a)
                        }
                    },
                    getNavigationController: { [weak self] in
                        if let self {
                            return self.environment?.controller()?.navigationController as? NavigationController
                        } else {
                            return nil
                        }
                    },
                    requestLayout: { [weak self] transition in
                        if let self {
                            (self.environment?.controller() as? MediaEditorScreen)?.node.requestLayout(forceUpdate: true, transition: Transition(transition))
                        }
                    }
                )
                self.inputMediaInteraction?.forceTheme = defaultDarkColorPresentationTheme
            }
        }
        
        private func activateInput() {
            self.currentInputMode = .text
            if !hasFirstResponder(self) {
                if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
                    view.activateInput()
                }
            } else {
                self.state?.updated(transition: .immediate)
            }
        }
        
        private var nextTransitionUserData: Any?
        @objc private func deactivateInput() {
            guard let _ = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            self.currentInputMode = .text
            if hasFirstResponder(self) {
                if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
                    self.nextTransitionUserData = TextFieldComponent.AnimationHint(kind: .textFocusChanged)
                    if view.isActive {
                        view.deactivateInput(force: true)
                    } else {
                        self.endEditing(true)
                    }
                }
            } else {
                self.state?.updated(transition: .spring(duration: 0.4).withUserData(TextFieldComponent.AnimationHint(kind: .textFocusChanged)))
            }
        }
        
        private var animatingButtons = false
        enum TransitionAnimationSource {
            case camera
            case gallery
        }
        func animateIn(from source: TransitionAnimationSource, completion: @escaping () -> Void = {}) {
            let buttons = [
                self.drawButton,
                self.textButton,
                self.stickerButton,
                self.toolsButton
            ]
            
            if let view = self.cancelButton.view {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
            }
            
            if let view = self.doneButton.view {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
            }
            
            if case .camera = source {
                self.animatingButtons = true
                var delay: Double = 0.0
                for button in buttons {
                    if let view = button.view {
                        view.alpha = 0.0
                        Queue.mainQueue().after(delay, {
                            view.alpha = 1.0
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: 64.0), to: .zero, duration: 0.3, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.0)
                            view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2, delay: 0.0)
                        })
                        delay += 0.03
                    }
                }
                Queue.mainQueue().after(0.45, {
                    self.animatingButtons = false
                    completion()
                })
                
                if let view = self.saveButton.view {
                    view.layer.animateAlpha(from: 0.0, to: view.alpha, duration: 0.2)
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
                
                if let view = self.muteButton.view {
                    view.layer.animateAlpha(from: 0.0, to: view.alpha, duration: 0.2)
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
                
                if let view = self.inputPanel.view {
                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    view.layer.animateScale(from: 0.6, to: 1.0, duration: 0.2)
                }
                
                if let view = self.scrubber.view {
                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    view.layer.animateScale(from: 0.6, to: 1.0, duration: 0.2)
                }
            }
        }
        
        func animateOut(to source: TransitionAnimationSource) {
            self.isDismissed = true
                        
            let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
            if let view = self.cancelButton.view {
                transition.setAlpha(view: view, alpha: 0.0)
                transition.setScale(view: view, scale: 0.1)
            }
            
            let buttons = [
                self.drawButton,
                self.textButton,
                self.stickerButton,
                self.toolsButton
            ]
            
            for button in buttons {
                if let view = button.view {
                    view.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 64.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                    view.layer.animateAlpha(from: view.alpha, to: 0.0, duration: 0.15, removeOnCompletion: false)
                    view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
                }
            }
            
            if let view = self.doneButton.view {
                transition.setAlpha(view: view, alpha: 0.0)
                transition.setScale(view: view, scale: 0.1)
            }
            
            if case .camera = source {
                if let view = self.inputPanel.view {
                    view.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 44.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                    view.layer.animateAlpha(from: view.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
                    view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
                }
                
                if let view = self.scrubber.view {
                    view.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 44.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                    view.layer.animateAlpha(from: view.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
                    view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
                }
            }
            
            if let view = self.saveButton.view {
                transition.setAlpha(view: view, alpha: 0.0)
                transition.setScale(view: view, scale: 0.1)
            }
            
            if let view = self.muteButton.view {
                transition.setAlpha(view: view, alpha: 0.0)
                transition.setScale(view: view, scale: 0.1)
            }
            
            if let view = self.scrubber.view {
                view.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 44.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                view.layer.animateAlpha(from: view.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
        }
        
        func animateOutToTool(transition: Transition) {
            if let view = self.cancelButton.view {
                view.alpha = 0.0
            }
            
            let buttons = [
                self.drawButton,
                self.textButton,
                self.stickerButton,
                self.toolsButton
            ]
            
            for button in buttons {
                if let view = button.view {
                    view.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -44.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
                }
            }
            
            if let view = self.doneButton.view {
                transition.setScale(view: view, scale: 0.1)
            }
            
            if let view = self.inputPanel.view {
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
            
            if let view = self.scrubber.view {
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
        }
        
        func animateInFromTool(transition: Transition) {
            if let view = self.cancelButton.view {
                view.alpha = 1.0
            }
            
            if let buttonView = self.cancelButton.view as? Button.View, let view = buttonView.content as? LottieAnimationComponent.View {
                view.playOnce()
            }
            
            let buttons = [
                self.drawButton,
                self.textButton,
                self.stickerButton,
                self.toolsButton
            ]
            
            for button in buttons {
                if let view = button.view {
                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: -44.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
            }
            
            if let view = self.doneButton.view {
                transition.setScale(view: view, scale: 1.0)
            }
            
            if let view = self.inputPanel.view {
                view.layer.animateScale(from: 0.0, to: 1.0, duration: 0.2)
            }
            
            if let view = self.scrubber.view {
                view.layer.animateScale(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
        
        func getInputText() -> NSAttributedString {
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return NSAttributedString()
            }
            var inputText = NSAttributedString()
            switch inputPanelView.getSendMessageInput() {
            case let .text(text):
                inputText = text
            }
            return inputText
        }
        
        func update(component: MediaEditorScreenComponent, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            guard !self.isDismissed else {
                return availableSize
            }
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            var transition = transition
            if let nextTransitionUserData = self.nextTransitionUserData {
                self.nextTransitionUserData = nil
                transition = transition.withUserData(nextTransitionUserData)
            }
            
            var isEditingStory = false
            if let controller = environment.controller() as? MediaEditorScreen {
                isEditingStory = controller.isEditingStory
                if self.component == nil {
                    if let initialCaption = controller.initialCaption {
                        self.inputPanelExternalState.initialText = initialCaption
                    } else if case let .draft(draft, _) = controller.node.subject {
                        self.inputPanelExternalState.initialText = draft.caption
                    }
                }
            }
            
            self.component = component
            self.state = state
            
            self.setupIfNeeded()
                        
            let isTablet = environment.metrics.isTablet
            
            let openDrawing = component.openDrawing
            let openTools = component.openTools
            
            let buttonSideInset: CGFloat
            let buttonBottomInset: CGFloat = 8.0
            var controlsBottomInset: CGFloat = 0.0
            let previewSize: CGSize
            var topInset: CGFloat = environment.statusBarHeight + 5.0
            if isTablet {
                let previewHeight = availableSize.height - topInset - 75.0
                previewSize = CGSize(width: floorToScreenPixels(previewHeight / 1.77778), height: previewHeight)
                buttonSideInset = 30.0
            } else {
                previewSize = CGSize(width: availableSize.width, height: floorToScreenPixels(availableSize.width * 1.77778))
                buttonSideInset = 10.0
                if availableSize.height < previewSize.height + 30.0 {
                    topInset = 0.0
                    controlsBottomInset = -50.0
                }
            }
            
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(
                        LottieAnimationComponent(
                            animation: LottieAnimationComponent.AnimationItem(
                                name: "media_backToCancel",
                                mode: .still(position: .end),
                                range: (0.5, 1.0)
                            ),
                            colors: ["__allcolors__": .white],
                            size: CGSize(width: 33.0, height: 33.0)
                        )
                    ),
                    action: {
                        guard let controller = environment.controller() as? MediaEditorScreen else {
                            return
                        }
                        controller.maybePresentDiscardAlert()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let cancelButtonFrame = CGRect(
                origin: CGPoint(x: buttonSideInset, y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset),
                size: cancelButtonSize
            )
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setPosition(view: cancelButtonView, position: cancelButtonFrame.center)
                transition.setBounds(view: cancelButtonView, bounds: CGRect(origin: .zero, size: cancelButtonFrame.size))
                transition.setAlpha(view: cancelButtonView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
            }
            
            var doneButtonTitle = environment.strings.Story_Editor_Next
            if let controller = environment.controller() as? MediaEditorScreen, controller.isEditingStory {
                doneButtonTitle = environment.strings.Story_Editor_Done
            }
            
            let doneButtonSize = self.doneButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(DoneButtonContentComponent(
                        backgroundColor: UIColor(rgb: 0x007aff),
                        icon: UIImage(bundleImageName: "Media Editor/Next")!,
                        title: doneButtonTitle.uppercased())),
                    effectAlignment: .center,
                    action: {
                        guard let controller = environment.controller() as? MediaEditorScreen else {
                            return
                        }
                        guard controller.checkCaptionLimit() else {
                            return
                        }
                        if controller.isEditingStory {
                            controller.requestCompletion(animated: true)
                        } else {
                            controller.openPrivacySettings(completion: { [weak controller] in
                                controller?.requestCompletion(animated: true)
                            })
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 44.0)
            )
            let doneButtonFrame = CGRect(
                origin: CGPoint(x: availableSize.width - buttonSideInset - doneButtonSize.width, y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset),
                size: doneButtonSize
            )
            if let doneButtonView = self.doneButton.view {
                if doneButtonView.superview == nil {
                    self.addSubview(doneButtonView)
                }
                transition.setPosition(view: doneButtonView, position: doneButtonFrame.center)
                transition.setBounds(view: doneButtonView, bounds: CGRect(origin: .zero, size: doneButtonFrame.size))
                transition.setAlpha(view: doneButtonView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
            }
            
            let buttonsAvailableWidth: CGFloat
            let buttonsLeftOffset: CGFloat
            if isTablet {
                buttonsAvailableWidth = previewSize.width + 180.0
                buttonsLeftOffset = floorToScreenPixels((availableSize.width - buttonsAvailableWidth) / 2.0)
            } else {
                buttonsAvailableWidth = floor(availableSize.width - cancelButtonSize.width * 0.66 - (doneButtonSize.width - cancelButtonSize.width * 0.33) - buttonSideInset * 2.0)
                buttonsLeftOffset = floorToScreenPixels(buttonSideInset + cancelButtonSize.width * 0.66)
            }
            
            let drawButtonSize = self.drawButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Image(
                        image: state.image(.draw),
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    action: {
                        openDrawing(.drawing)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let drawButtonFrame = CGRect(
                origin: CGPoint(x: buttonsLeftOffset + floorToScreenPixels(buttonsAvailableWidth / 5.0 - drawButtonSize.width / 2.0 - 3.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset + 1.0),
                size: drawButtonSize
            )
            if let drawButtonView = self.drawButton.view {
                if drawButtonView.superview == nil {
                    self.addSubview(drawButtonView)
                }
                transition.setPosition(view: drawButtonView, position: drawButtonFrame.center)
                transition.setBounds(view: drawButtonView, bounds: CGRect(origin: .zero, size: drawButtonFrame.size))
                if !self.animatingButtons {
                    transition.setAlpha(view: drawButtonView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
                }
            }
            
            let textButtonSize = self.textButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Image(
                        image: state.image(.text),
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    action: {
                        openDrawing(.text)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let textButtonFrame = CGRect(
                origin: CGPoint(x: buttonsLeftOffset + floorToScreenPixels(buttonsAvailableWidth / 5.0 * 2.0 - textButtonSize.width / 2.0 - 1.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset + 2.0),
                size: textButtonSize
            )
            if let textButtonView = self.textButton.view {
                if textButtonView.superview == nil {
                    self.addSubview(textButtonView)
                }
                transition.setPosition(view: textButtonView, position: textButtonFrame.center)
                transition.setBounds(view: textButtonView, bounds: CGRect(origin: .zero, size: textButtonFrame.size))
                if !self.animatingButtons {
                    transition.setAlpha(view: textButtonView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
                }
            }
            
            let stickerButtonSize = self.stickerButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Image(
                        image: state.image(.sticker),
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    action: {
                        openDrawing(.sticker)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let stickerButtonFrame = CGRect(
                origin: CGPoint(x: buttonsLeftOffset + floorToScreenPixels(buttonsAvailableWidth / 5.0 * 3.0 - stickerButtonSize.width / 2.0 + 1.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset + 2.0),
                size: stickerButtonSize
            )
            if let stickerButtonView = self.stickerButton.view {
                if stickerButtonView.superview == nil {
                    self.addSubview(stickerButtonView)
                }
                transition.setPosition(view: stickerButtonView, position: stickerButtonFrame.center)
                transition.setBounds(view: stickerButtonView, bounds: CGRect(origin: .zero, size: stickerButtonFrame.size))
                if !self.animatingButtons {
                    transition.setAlpha(view: stickerButtonView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
                }
            }
            
            let toolsButtonSize = self.toolsButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Image(
                        image: state.image(.tools),
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    action: {
                        openTools()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let toolsButtonFrame = CGRect(
                origin: CGPoint(x: buttonsLeftOffset + floorToScreenPixels(buttonsAvailableWidth / 5.0 * 4.0 - toolsButtonSize.width / 2.0 + 3.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset + 1.0),
                size: toolsButtonSize
            )
            if let toolsButtonView = self.toolsButton.view {
                if toolsButtonView.superview == nil {
                    self.addSubview(toolsButtonView)
                }
                transition.setPosition(view: toolsButtonView, position: toolsButtonFrame.center)
                transition.setBounds(view: toolsButtonView, bounds: CGRect(origin: .zero, size: toolsButtonFrame.size))
                if !self.animatingButtons {
                    transition.setAlpha(view: toolsButtonView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
                }
            }
            
            var mediaEditor: MediaEditor?
            if let controller = environment.controller() as? MediaEditorScreen {
                mediaEditor = controller.node.mediaEditor
            }
            
            var scrubberBottomInset: CGFloat = 0.0
            if let playerState = state.playerState {
                let scrubberInset: CGFloat = 9.0
                let scrubberSize = self.scrubber.update(
                    transition: transition,
                    component: AnyComponent(VideoScrubberComponent(
                        context: component.context,
                        generationTimestamp: playerState.generationTimestamp,
                        duration: playerState.duration,
                        startPosition: playerState.timeRange?.lowerBound ?? 0.0,
                        endPosition: playerState.timeRange?.upperBound ?? min(playerState.duration, storyMaxVideoDuration),
                        position: playerState.position,
                        maxDuration: storyMaxVideoDuration,
                        isPlaying: playerState.isPlaying,
                        frames: playerState.frames,
                        framesUpdateTimestamp: playerState.framesUpdateTimestamp,
                        trimUpdated: { [weak mediaEditor] start, end, updatedEnd, done in
                            if let mediaEditor {
                                mediaEditor.setVideoTrimRange(start..<end, apply: done)
                                if done {
                                    mediaEditor.seek(start, andPlay: true)
                                } else {
                                    mediaEditor.seek(updatedEnd ? end : start, andPlay: false)
                                }
                            }
                        },
                        positionUpdated: { position, done in
                            if let mediaEditor {
                                mediaEditor.seek(position, andPlay: done)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: previewSize.width - scrubberInset * 2.0, height: availableSize.height)
                )
                
                let scrubberFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - scrubberSize.width) / 2.0), y: availableSize.height - environment.safeInsets.bottom - scrubberSize.height - 8.0 + controlsBottomInset), size: scrubberSize)
                if let scrubberView = self.scrubber.view {
                    var animateIn = false
                    if scrubberView.superview == nil {
                        animateIn = true
                        if let inputPanelBackgroundView = self.inputPanelBackground.view, inputPanelBackgroundView.superview != nil {
                            self.insertSubview(scrubberView, belowSubview: inputPanelBackgroundView)
                        } else {
                            self.addSubview(scrubberView)
                        }
                    }
                    transition.setFrame(view: scrubberView, frame: scrubberFrame)
                    if !self.animatingButtons {
                        transition.setAlpha(view: scrubberView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
                    } else if animateIn {
                        scrubberView.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        scrubberView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        scrubberView.layer.animateScale(from: 0.6, to: 1.0, duration: 0.2)
                    }
                }
                
                scrubberBottomInset = scrubberSize.height + 10.0
            } else {
                
            }
            
            var timeoutValue: String
            switch component.privacy.timeout {
            case 21600:
                timeoutValue = "6"
            case 43200:
                timeoutValue = "12"
            case 86400:
                timeoutValue = "24"
            case 172800:
                timeoutValue = "48"
            default:
                timeoutValue = "24"
            }
            
            var inputPanelAvailableWidth = previewSize.width
            var inputPanelAvailableHeight = 103.0
            if case .regular = environment.metrics.widthClass {
                if (self.inputPanelExternalState.isEditing || self.inputPanelExternalState.hasText) {
                    inputPanelAvailableWidth += 200.0
                }
            }
            
            let keyboardWasHidden = self.inputPanelExternalState.isKeyboardHidden
            if environment.inputHeight > 0.0 || self.currentInputMode == .emoji || keyboardWasHidden {
                inputPanelAvailableHeight = 200.0
            }
            
            var inputHeight = environment.inputHeight
            var keyboardHeight = environment.deviceMetrics.standardInputHeight(inLandscape: false)
            
            if case .emoji = self.currentInputMode, let inputData = self.inputMediaNodeData {
                let inputMediaNode: ChatEntityKeyboardInputNode
                if let current = self.inputMediaNode {
                    inputMediaNode = current
                } else {
                    inputMediaNode = ChatEntityKeyboardInputNode(
                        context: component.context,
                        currentInputData: inputData,
                        updatedInputData: self.inputMediaNodeDataPromise.get(),
                        defaultToEmojiTab: true,
                        opaqueTopPanelBackground: false,
                        interaction: self.inputMediaInteraction,
                        chatPeerId: nil,
                        stateContext: self.inputMediaNodeStateContext
                    )
                    inputMediaNode.externalTopPanelContainerImpl = nil
                    inputMediaNode.useExternalSearchContainer = true
                    if let inputPanelView = self.inputPanel.view, inputMediaNode.view.superview == nil {
                        self.insertSubview(inputMediaNode.view, belowSubview: inputPanelView)
                    }
                    self.inputMediaNode = inputMediaNode
                }
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
                let presentationInterfaceState = ChatPresentationInterfaceState(
                    chatWallpaper: .builtin(WallpaperSettings()),
                    theme: presentationData.theme,
                    strings: presentationData.strings,
                    dateTimeFormat: presentationData.dateTimeFormat,
                    nameDisplayOrder: presentationData.nameDisplayOrder,
                    limitsConfiguration: component.context.currentLimitsConfiguration.with { $0 },
                    fontSize: presentationData.chatFontSize,
                    bubbleCorners: presentationData.chatBubbleCorners,
                    accountPeerId: component.context.account.peerId,
                    mode: .standard(previewing: false),
                    chatLocation: .peer(id: component.context.account.peerId),
                    subject: nil,
                    peerNearbyData: nil,
                    greetingData: nil,
                    pendingUnpinnedAllMessages: false,
                    activeGroupCallInfo: nil,
                    hasActiveGroupCall: false,
                    importState: nil,
                    threadData: nil,
                    isGeneralThreadClosed: nil
                )
                
                let availableInputMediaWidth = previewSize.width
                let heightAndOverflow = inputMediaNode.updateLayout(width: availableInputMediaWidth, leftInset: 0.0, rightInset: 0.0, bottomInset: component.bottomSafeInset, standardInputHeight: environment.deviceMetrics.standardInputHeight(inLandscape: false), inputHeight: environment.inputHeight, maximumHeight: availableSize.height, inputPanelHeight: 0.0, transition: .immediate, interfaceState: presentationInterfaceState, layoutMetrics: environment.metrics, deviceMetrics: environment.deviceMetrics, isVisible: true, isExpanded: false)
                let inputNodeHeight = heightAndOverflow.0
                let inputNodeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - availableInputMediaWidth) / 2.0), y: availableSize.height - inputNodeHeight), size: CGSize(width: availableInputMediaWidth, height: inputNodeHeight))
                transition.setFrame(layer: inputMediaNode.layer, frame: inputNodeFrame)
                  
                if inputNodeHeight > 0.0 {
                    inputHeight = inputNodeHeight
                }
            } else if let inputMediaNode = self.inputMediaNode {
                self.inputMediaNode = nil
                
                var dismissingInputHeight = environment.inputHeight
                if self.currentInputMode == .emoji || (dismissingInputHeight.isZero && keyboardWasHidden) {
                    dismissingInputHeight = max(inputHeight, environment.deviceMetrics.standardInputHeight(inLandscape: false))
                }
                
                if let animationHint = transition.userData(TextFieldComponent.AnimationHint.self), case .textFocusChanged = animationHint.kind {
                    dismissingInputHeight = 0.0
                }
                
                var targetFrame = inputMediaNode.frame
                if dismissingInputHeight > 0.0 {
                    targetFrame.origin.y = availableSize.height - dismissingInputHeight
                } else {
                    targetFrame.origin.y = availableSize.height
                }
                transition.setFrame(view: inputMediaNode.view, frame: targetFrame, completion: { [weak inputMediaNode] _ in
                    if let inputMediaNode {
                        Queue.mainQueue().after(0.2) {
                            inputMediaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputMediaNode] _ in
                                inputMediaNode?.view.removeFromSuperview()
                            })
                        }
                    }
                })
            }
            
            let nextInputMode: MessageInputPanelComponent.InputMode
            switch self.currentInputMode {
            case .text:
                nextInputMode = .emoji
            case .emoji:
                nextInputMode = .text
            default:
                nextInputMode = .emoji
            }
            
            self.inputPanel.parentState = state
            let inputPanelSize = self.inputPanel.update(
                transition: transition,
                component: AnyComponent(MessageInputPanelComponent(
                    externalState: self.inputPanelExternalState,
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    style: .editor,
                    placeholder: .plain(environment.strings.Story_Editor_InputPlaceholderAddCaption),
                    maxLength: Int(component.context.userLimits.maxStoryCaptionLength),
                    queryTypes: [.mention],
                    alwaysDarkWhenHasText: false,
                    resetInputContents: nil,
                    nextInputMode: { _ in  return nextInputMode },
                    areVoiceMessagesAvailable: false,
                    presentController: { [weak self] c in
                        guard let self, let _ = self.component, let environment = self.environment, let controller = environment.controller() as? MediaEditorScreen else {
                            return
                        }
                        controller.present(c, in: .window(.root))
                    },
                    presentInGlobalOverlay: {[weak self] c in
                        guard let self, let _ = self.component, let environment = self.environment, let controller = environment.controller() as? MediaEditorScreen else {
                            return
                        }
                        controller.presentInGlobalOverlay(c)
                    },
                    sendMessageAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.deactivateInput()
                    },
                    sendMessageOptionsAction: nil,
                    sendStickerAction: { _ in },
                    setMediaRecordingActive: nil,
                    lockMediaRecording: nil,
                    stopAndPreviewMediaRecording: nil,
                    discardMediaRecordingPreview: nil,
                    attachmentAction: nil,
                    myReaction: nil,
                    likeAction: nil,
                    likeOptionsAction: nil,
                    inputModeAction: { [weak self] in
                        if let self {
                            switch self.currentInputMode {
                            case .text:
                                self.currentInputMode = .emoji
                            case .emoji:
                                self.currentInputMode = .text
                            default:
                                self.currentInputMode = .emoji
                            }
                            if self.currentInputMode == .text {
                                self.activateInput()
                            } else {
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    },
                    timeoutAction: isEditingStory ? nil : { [weak self] view, gesture in
                        guard let self, let controller = self.environment?.controller() as? MediaEditorScreen else {
                            return
                        }
                        let context = controller.context
                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                        |> deliverOnMainQueue).start(next: { [weak controller] peer in
                            let hasPremium: Bool
                            if case let .user(user) = peer {
                                hasPremium = user.isPremium
                            } else {
                                hasPremium = false
                            }
                            controller?.presentTimeoutSetup(sourceView: view, gesture: gesture, hasPremium: hasPremium)
                        })
                    },
                    forwardAction: nil,
                    moreAction: nil,
                    presentVoiceMessagesUnavailableTooltip: nil,
                    presentTextLengthLimitTooltip: { [weak self] in
                        guard let self, let controller = self.environment?.controller() as? MediaEditorScreen else {
                            return
                        }
                        controller.presentCaptionLimitPremiumSuggestion(isPremium: self.state?.isPremium ?? false)
                    },
                    presentTextFormattingTooltip: { [weak self] in
                        guard let self, let controller = self.environment?.controller() as? MediaEditorScreen else {
                            return
                        }
                        controller.presentCaptionEntitiesPremiumSuggestion()
                    },
                    paste: { [weak self] data in
                        guard let self, let environment = self.environment, let controller = environment.controller() as? MediaEditorScreen else {
                            return
                        }
                        switch data {
                        case let .sticker(image, _):
                            if max(image.size.width, image.size.height) > 1.0 {
                                let entity = DrawingStickerEntity(content: .image(image, .sticker))
                                controller.node.interaction?.insertEntity(entity, scale: 1.0)
                                self.deactivateInput()
                            }
                        case let .images(images):
                            if images.count == 1, let image = images.first, max(image.size.width, image.size.height) > 1.0 {
                                let entity = DrawingStickerEntity(content: .image(image, .rectangle))
                                controller.node.interaction?.insertEntity(entity, scale: 2.5)
                                self.deactivateInput()
                            }
                        case .text:
                            Queue.mainQueue().after(0.1) {
                                let text = self.getInputText()
                                if text.length > component.context.userLimits.maxStoryCaptionLength {
                                    controller.presentCaptionLimitPremiumSuggestion(isPremium: self.state?.isPremium ?? false)
                                }
                            }
                        default:
                            break
                        }
                    },
                    audioRecorder: nil,
                    videoRecordingStatus: nil,
                    isRecordingLocked: false,
                    recordedAudioPreview: nil,
                    hasRecordedVideoPreview: false,
                    wasRecordingDismissed: false,
                    timeoutValue: timeoutValue,
                    timeoutSelected: false,
                    displayGradient: false,
                    bottomInset: 0.0,
                    isFormattingLocked: !state.isPremium,
                    hideKeyboard: self.currentInputMode == .emoji,
                    customInputView: nil,
                    forceIsEditing: self.currentInputMode == .emoji,
                    disabledPlaceholder: nil,
                    isChannel: false,
                    storyItem: nil,
                    chatLocation: nil
                )),
                environment: {},
                containerSize: CGSize(width: inputPanelAvailableWidth, height: inputPanelAvailableHeight)
            )
            
            if self.inputPanelExternalState.isEditing {
                if let controller = self.environment?.controller() as? MediaEditorScreen {
                    if controller.node.entitiesView.hasSelection {
                        Queue.mainQueue().justDispatch {
                            controller.node.entitiesView.selectEntity(nil)
                        }
                    }
                }
            }
            
            if self.inputPanelExternalState.isEditing {
                if self.currentInputMode == .emoji || (inputHeight.isZero && keyboardWasHidden) {
                    inputHeight = max(inputHeight, environment.deviceMetrics.standardInputHeight(inLandscape: false))
                }
            }
            keyboardHeight = inputHeight
            
            let fadeTransition = Transition(animation: .curve(duration: 0.3, curve: .easeInOut))
            if self.inputPanelExternalState.isEditing {
                fadeTransition.setAlpha(view: self.fadeView, alpha: 1.0)
            } else {
                fadeTransition.setAlpha(view: self.fadeView, alpha: 0.0)
            }
            transition.setFrame(view: self.fadeView, frame: CGRect(origin: .zero, size: availableSize))

            let isEditingCaption = self.inputPanelExternalState.isEditing
            if self.isEditingCaption != isEditingCaption {
                self.isEditingCaption = isEditingCaption
                
                if isEditingCaption {
                    if let controller = environment.controller() as? MediaEditorScreen {
                        controller.dismissAllTooltips()
                    }
                    mediaEditor?.stop()
                } else {
                    mediaEditor?.play()
                }
            }
    
            let inputPanelBackgroundSize = self.inputPanelBackground.update(
                transition: transition,
                component: AnyComponent(BlurredGradientComponent(position: .bottom, tag: nil)),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: keyboardHeight + 60.0)
            )
            if let inputPanelBackgroundView = self.inputPanelBackground.view {
                if inputPanelBackgroundView.superview == nil {
                    self.addSubview(inputPanelBackgroundView)
                }
                let isVisible = isEditingCaption && inputHeight > 44.0
                transition.setFrame(view: inputPanelBackgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: isVisible ? availableSize.height - inputPanelBackgroundSize.height : availableSize.height), size: inputPanelBackgroundSize))
                if !self.animatingButtons {
                    transition.setAlpha(view: inputPanelBackgroundView, alpha: isVisible ? 1.0 : 0.0, delay: isVisible ? 0.0 : 0.4)
                }
            }
                  
            var isEditingTextEntity = false
            var sizeSliderVisible = false
            var sizeValue: CGFloat?
            if let textEntity = component.selectedEntity as? DrawingTextEntity, let entityView = component.entityViewForEntity(textEntity) as? DrawingTextEntityView {
                sizeSliderVisible = true
                isEditingTextEntity = entityView.isEditing
                sizeValue = textEntity.fontSize
            }
            
            var inputPanelBottomInset: CGFloat = scrubberBottomInset - controlsBottomInset
            if inputHeight > 0.0 {
                inputPanelBottomInset = inputHeight - environment.safeInsets.bottom
            }
            let inputPanelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - inputPanelSize.width) / 2.0), y: availableSize.height - environment.safeInsets.bottom - inputPanelBottomInset - inputPanelSize.height - 3.0), size: inputPanelSize)
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    self.addSubview(inputPanelView)
                }
                transition.setFrame(view: inputPanelView, frame: inputPanelFrame)
                transition.setAlpha(view: inputPanelView, alpha: isEditingTextEntity || component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
            }
            
            let displayTopButtons = !(self.inputPanelExternalState.isEditing || isEditingTextEntity || component.isDisplayingTool)
                
            let saveContentComponent: AnyComponentWithIdentity<Empty>
            if component.hasAppeared {
                saveContentComponent = AnyComponentWithIdentity(
                    id: "animatedIcon",
                    component: AnyComponent(
                        LottieAnimationComponent(
                            animation: LottieAnimationComponent.AnimationItem(
                                name: "anim_storysave",
                                mode: .still(position: .begin),
                                range: nil
                            ),
                            colors: ["__allcolors__": .white],
                            size: CGSize(width: 30.0, height: 30.0)
                        ).tagged(saveButtonTag)
                    )
                )
            } else {
                saveContentComponent = AnyComponentWithIdentity(
                    id: "staticIcon",
                    component: AnyComponent(
                        BundleIconComponent(
                            name: "Media Editor/SaveIcon",
                            tintColor: nil
                        )
                    )
                )
            }
            
            let saveButtonSize = self.saveButton.update(
                transition: transition,
                component: AnyComponent(CameraButton(
                    content: saveContentComponent,
                    action: { [weak self] in
                        if let view = self?.saveButton.findTaggedView(tag: saveButtonTag) as? LottieAnimationComponent.View {
                            view.playOnce()
                        }
                        if let controller = environment.controller() as? MediaEditorScreen {
                            controller.requestSave()
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let saveButtonFrame = CGRect(
                origin: CGPoint(x: availableSize.width - 20.0 - saveButtonSize.width, y: max(environment.statusBarHeight + 10.0, environment.safeInsets.top + 20.0)),
                size: saveButtonSize
            )
            if let saveButtonView = self.saveButton.view {
                if saveButtonView.superview == nil {
                    saveButtonView.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
                    saveButtonView.layer.shadowRadius = 2.0
                    saveButtonView.layer.shadowColor = UIColor.black.cgColor
                    saveButtonView.layer.shadowOpacity = 0.35
                    self.addSubview(saveButtonView)
                }

                let saveButtonAlpha = component.isSavingAvailable ? 1.0 : 0.3
                saveButtonView.isUserInteractionEnabled = component.isSavingAvailable

                transition.setPosition(view: saveButtonView, position: saveButtonFrame.center)
                transition.setBounds(view: saveButtonView, bounds: CGRect(origin: .zero, size: saveButtonFrame.size))
                transition.setScale(view: saveButtonView, scale: displayTopButtons ? 1.0 : 0.01)
                transition.setAlpha(view: saveButtonView, alpha: displayTopButtons && !component.isDismissing && !component.isInteractingWithEntities ? saveButtonAlpha : 0.0)
            }
             
            if let playerState = state.playerState {
                if playerState.hasAudio {
                    let isVideoMuted = mediaEditor?.values.videoIsMuted ?? false
                    
                    let muteContentComponent: AnyComponentWithIdentity<Empty>
                    if component.hasAppeared {
                        muteContentComponent = AnyComponentWithIdentity(
                            id: "animatedIcon",
                            component: AnyComponent(
                                LottieAnimationComponent(
                                    animation: LottieAnimationComponent.AnimationItem(
                                        name: "anim_storymute",
                                        mode: state.muteDidChange ? .animating(loop: false) : .still(position: .begin),
                                        range: isVideoMuted ? (0.0, 0.5) : (0.5, 1.0)
                                    ),
                                    colors: ["__allcolors__": .white],
                                    size: CGSize(width: 30.0, height: 30.0)
                                ).tagged(muteButtonTag)
                            )
                        )
                    } else {
                        muteContentComponent = AnyComponentWithIdentity(
                            id: "staticIcon",
                            component: AnyComponent(
                                BundleIconComponent(
                                    name: "Media Editor/MuteIcon",
                                    tintColor: nil
                                )
                            )
                        )
                    }
                    
                    let muteButtonSize = self.muteButton.update(
                        transition: transition,
                        component: AnyComponent(CameraButton(
                            content: muteContentComponent,
                            action: { [weak state, weak mediaEditor] in
                                if let mediaEditor {
                                    state?.muteDidChange = true
                                    let isMuted = !mediaEditor.values.videoIsMuted
                                    mediaEditor.setVideoIsMuted(isMuted)
                                    state?.updated()
                                    
                                    if let controller = environment.controller() as? MediaEditorScreen {
                                        controller.node.presentMutedTooltip()
                                    }
                                }
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: 44.0, height: 44.0)
                    )
                    let muteButtonFrame = CGRect(
                        origin: CGPoint(x: availableSize.width - 20.0 - muteButtonSize.width - 50.0, y: max(environment.statusBarHeight + 10.0, environment.safeInsets.top + 20.0)),
                        size: muteButtonSize
                    )
                    if let muteButtonView = self.muteButton.view {
                        if muteButtonView.superview == nil {
                            muteButtonView.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
                            muteButtonView.layer.shadowRadius = 2.0
                            muteButtonView.layer.shadowColor = UIColor.black.cgColor
                            muteButtonView.layer.shadowOpacity = 0.35
                            self.addSubview(muteButtonView)
                            
                            muteButtonView.layer.animateAlpha(from: 0.0, to: muteButtonView.alpha, duration: self.animatingButtons ? 0.1 : 0.2)
                            muteButtonView.layer.animateScale(from: 0.4, to: 1.0, duration: self.animatingButtons ? 0.1 : 0.2)
                        }
                        transition.setPosition(view: muteButtonView, position: muteButtonFrame.center)
                        transition.setBounds(view: muteButtonView, bounds: CGRect(origin: .zero, size: muteButtonFrame.size))
                        transition.setScale(view: muteButtonView, scale: displayTopButtons ? 1.0 : 0.01)
                        transition.setAlpha(view: muteButtonView, alpha: displayTopButtons && !component.isDismissing && !component.isInteractingWithEntities ? 1.0 : 0.0)
                    }
                } else if let muteButtonView = self.muteButton.view, muteButtonView.superview != nil {
                    muteButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak muteButtonView] _ in
                        muteButtonView?.removeFromSuperview()
                    })
                    muteButtonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                }
            } else if let muteButtonView = self.muteButton.view, muteButtonView.superview != nil {
                muteButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak muteButtonView] _ in
                    muteButtonView?.removeFromSuperview()
                })
                muteButtonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            }
            
            let textCancelButtonSize = self.textCancelButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(
                        Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: .white)
                    ),
                    action: {
                        if let controller = environment.controller() as? MediaEditorScreen {
                            controller.node.interaction?.endTextEditing(reset: true)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 30.0)
            )
            let textCancelButtonFrame = CGRect(
                origin: CGPoint(x: 13.0, y: max(environment.statusBarHeight + 10.0, environment.safeInsets.top + 20.0)),
                size: textCancelButtonSize
            )
            if let textCancelButtonView = self.textCancelButton.view {
                if textCancelButtonView.superview == nil {
                    self.addSubview(textCancelButtonView)
                }
                transition.setPosition(view: textCancelButtonView, position: textCancelButtonFrame.center)
                transition.setBounds(view: textCancelButtonView, bounds: CGRect(origin: .zero, size: textCancelButtonFrame.size))
                transition.setScale(view: textCancelButtonView, scale: isEditingTextEntity ? 1.0 : 0.01)
                transition.setAlpha(view: textCancelButtonView, alpha: isEditingTextEntity ? 1.0 : 0.0)
            }
            
            let textDoneButtonSize = self.textDoneButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(
                        Text(text: environment.strings.Common_Done, font: Font.regular(17.0), color: .white)
                    ),
                    action: {
                        if let controller = environment.controller() as? MediaEditorScreen {
                            controller.node.interaction?.endTextEditing(reset: false)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 30.0)
            )
            let textDoneButtonFrame = CGRect(
                origin: CGPoint(x: availableSize.width - textDoneButtonSize.width - 13.0, y: max(environment.statusBarHeight + 10.0, environment.safeInsets.top + 20.0)),
                size: textDoneButtonSize
            )
            if let textDoneButtonView = self.textDoneButton.view {
                if textDoneButtonView.superview == nil {
                    self.addSubview(textDoneButtonView)
                }
                transition.setPosition(view: textDoneButtonView, position: textDoneButtonFrame.center)
                transition.setBounds(view: textDoneButtonView, bounds: CGRect(origin: .zero, size: textDoneButtonFrame.size))
                transition.setScale(view: textDoneButtonView, scale: isEditingTextEntity ? 1.0 : 0.01)
                transition.setAlpha(view: textDoneButtonView, alpha: isEditingTextEntity ? 1.0 : 0.0)
            }
            
            let textSizeSize = self.textSize.update(
                transition: transition,
                component: AnyComponent(TextSizeSliderComponent(
                    value: sizeValue ?? 0.5,
                    tag: nil,
                    updated: { [weak state] size in
                        if let controller = environment.controller() as? MediaEditorScreen {
                            controller.node.interaction?.updateEntitySize(size)
                            state?.updated()
                        }
                    }, released: {
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 240.0)
            )
            let textSizeTopInset = max(environment.safeInsets.top, environment.statusBarHeight)
            let bottomInset: CGFloat = inputHeight > 0.0 ? inputHeight : environment.safeInsets.bottom
            let textSizeFrame = CGRect(
                origin: CGPoint(x: 0.0, y: textSizeTopInset + (availableSize.height - textSizeTopInset - bottomInset) / 2.0 - textSizeSize.height / 2.0),
                size: textSizeSize
            )
            if let textSizeView = self.textSize.view {
                if textSizeView.superview == nil {
                    self.addSubview(textSizeView)
                }
                transition.setPosition(view: textSizeView, position: textSizeFrame.center)
                transition.setBounds(view: textSizeView, bounds: CGRect(origin: .zero, size: textSizeFrame.size))
                transition.setAlpha(view: textSizeView, alpha: sizeSliderVisible && !component.isInteractingWithEntities ? 1.0 : 0.0)
            }
            
            component.externalState.derivedInputHeight = inputHeight
       
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private let storyDimensions = CGSize(width: 1080.0, height: 1920.0)
private let storyMaxVideoDuration: Double = 60.0

public final class MediaEditorScreen: ViewController, UIDropInteractionDelegate {
    public enum TransitionIn {
        public final class GalleryTransitionIn {
            public weak var sourceView: UIView?
            public let sourceRect: CGRect
            public let sourceImage: UIImage?
            
            public init(
                sourceView: UIView,
                sourceRect: CGRect,
                sourceImage: UIImage?
            ) {
                self.sourceView = sourceView
                self.sourceRect = sourceRect
                self.sourceImage = sourceImage
            }
        }
        
        case camera
        case gallery(GalleryTransitionIn)
    }
    
    public final class TransitionOut {
        public weak var destinationView: UIView?
        public let destinationRect: CGRect
        public let destinationCornerRadius: CGFloat
        
        public init(
            destinationView: UIView,
            destinationRect: CGRect,
            destinationCornerRadius: CGFloat
        ) {
            self.destinationView = destinationView
            self.destinationRect = destinationRect
            self.destinationCornerRadius = destinationCornerRadius
        }
    }
    
    struct State {
        var privacy: MediaEditorResultPrivacy = MediaEditorResultPrivacy(
            privacy: EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: []),
            timeout: 86400,
            isForwardingDisabled: false,
            pin: true
        )
    }
    
    var state = State() {
        didSet {
            if self.isNodeLoaded {
                self.node.requestUpdate()
            }
        }
    }
    
    fileprivate final class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        private weak var controller: MediaEditorScreen?
        private let context: AccountContext
        fileprivate var interaction: DrawingToolsInteraction?
        private let initializationTimestamp = CACurrentMediaTime()
        
        fileprivate var subject: MediaEditorScreen.Subject?
        private var subjectDisposable: Disposable?
        private var appInForegroundDisposable: Disposable?
        private var wasPlaying = false
        
        private let backgroundDimView: UIView
        fileprivate let containerView: UIView
        fileprivate let componentExternalState = MediaEditorScreenComponent.ExternalState()
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        fileprivate let storyPreview: ComponentView<Empty>
        fileprivate let toolValue: ComponentView<Empty>
        
        private let previewContainerView: UIView
        private var transitionInView: UIImageView?
        
        private let gradientView: UIImageView
        private var gradientColorsDisposable: Disposable?
        
        fileprivate let entitiesContainerView: UIView
        fileprivate let entitiesView: DrawingEntitiesView
        fileprivate let selectionContainerView: DrawingSelectionContainerView
        fileprivate let drawingView: DrawingView
        fileprivate let previewView: MediaEditorPreviewView
        fileprivate var mediaEditor: MediaEditor?
        fileprivate var mediaEditorPromise = Promise<MediaEditor?>()
        
        fileprivate let ciContext = CIContext(options: [.workingColorSpace : NSNull()])
        
        private let stickerPickerInputData = Promise<StickerPickerInputData>()
        
        private var dismissPanGestureRecognizer: UIPanGestureRecognizer?
        
        private var isDisplayingTool = false
        private var isInteractingWithEntities = false
        private var isEnhancing = false
        
        private var hasAppeared = false
        private var isDismissing = false
        private var dismissOffset: CGFloat = 0.0
        private var isDismissed = false
        private var isDismissBySwipeSuppressed = false
        
        fileprivate var hasAnyChanges = false
        
        private var playbackPositionDisposable: Disposable?
        
        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        init(controller: MediaEditorScreen) {
            self.controller = controller
            self.context = controller.context
            
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.backgroundDimView = UIView()
            self.backgroundDimView.isHidden = true
            self.backgroundDimView.backgroundColor = .black
            
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            
            self.componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
            self.storyPreview = ComponentView<Empty>()
            self.toolValue = ComponentView<Empty>()
            
            self.previewContainerView = UIView()
            self.previewContainerView.alpha = 0.0
            self.previewContainerView.clipsToBounds = true
            self.previewContainerView.layer.cornerRadius = 12.0
            if #available(iOS 13.0, *) {
                self.previewContainerView.layer.cornerCurve = .continuous
            }
            
            self.gradientView = UIImageView()
            
            self.entitiesContainerView = UIView(frame: CGRect(origin: .zero, size: storyDimensions))
            self.entitiesView = DrawingEntitiesView(context: controller.context, size: storyDimensions, hasBin: true)
            self.entitiesView.getEntityCenterPosition = {
                return CGPoint(x: storyDimensions.width / 2.0, y: storyDimensions.height / 2.0)
            }
            self.entitiesView.getEntityEdgePositions = {
                return UIEdgeInsets(top: 160.0, left: 36.0, bottom: storyDimensions.height - 160.0, right: storyDimensions.width - 36.0)
            }
            self.previewView = MediaEditorPreviewView(frame: .zero)
            self.drawingView = DrawingView(size: storyDimensions)
            self.drawingView.isUserInteractionEnabled = false
            
            self.selectionContainerView = DrawingSelectionContainerView(frame: .zero)
            self.entitiesView.selectionContainerView = self.selectionContainerView
            
            super.init()
            
            self.backgroundColor = .clear
            
            self.view.addSubview(self.backgroundDimView)
            self.view.addSubview(self.containerView)
            self.containerView.addSubview(self.previewContainerView)
            self.previewContainerView.addSubview(self.gradientView)
            self.previewContainerView.addSubview(self.entitiesContainerView)
            self.entitiesContainerView.addSubview(self.entitiesView)
            self.entitiesView.addSubview(self.drawingView)
            self.previewContainerView.addSubview(self.selectionContainerView)
            
            self.subjectDisposable = (
                controller.subject
                |> filter {
                    $0 != nil
                }
                |> take(1)
                |> deliverOnMainQueue
            ).start(next: { [weak self] subject in
                if let self, let subject {
                    self.setup(with: subject)
                }
            })
            
            let stickerPickerInputData = self.stickerPickerInputData
            Queue.concurrentDefaultQueue().after(0.5, {
                let emojiItems = EmojiPagerContentComponent.emojiInputData(
                    context: controller.context,
                    animationCache: controller.context.animationCache,
                    animationRenderer: controller.context.animationRenderer,
                    isStandalone: false,
                    isStatusSelection: false,
                    isReactionSelection: false,
                    isEmojiSelection: true,
                    hasTrending: true,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: true,
                    areCustomEmojiEnabled: true,
                    chatPeerId: controller.context.account.peerId,
                    hasSearch: true,
                    forceHasPremium: true
                )
                
                let stickerItems = EmojiPagerContentComponent.stickerInputData(
                    context: controller.context,
                    animationCache: controller.context.animationCache,
                    animationRenderer: controller.context.animationRenderer,
                    stickerNamespaces: [Namespaces.ItemCollection.CloudStickerPacks],
                    stickerOrderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudAllPremiumStickers],
                    chatPeerId: controller.context.account.peerId,
                    hasSearch: true,
                    hasTrending: true,
                    forceHasPremium: true
                )
                                
                let signal = combineLatest(queue: .mainQueue(),
                                           emojiItems,
                                           stickerItems
                ) |> map { emoji, stickers -> StickerPickerInputData in
                    return StickerPickerInputData(emoji: emoji, stickers: stickers, gifs: nil)
                }
                
                stickerPickerInputData.set(signal)
            })
            
            self.entitiesView.edgePreviewUpdated = { [weak self] preview in
                if let self {
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                    if let storyPreviewView = self.storyPreview.view {
                        transition.updateAlpha(layer: storyPreviewView.layer, alpha: preview ? 0.4 : 0.0)
                    }
                }
            }
            
            self.appInForegroundDisposable = (controller.context.sharedContext.applicationBindings.applicationInForeground
            |> deliverOnMainQueue).start(next: { [weak self] inForeground in
                if let self, let mediaEditor = self.mediaEditor {
                    if inForeground && self.wasPlaying {
                        mediaEditor.play()
                    } else if !inForeground {
                        self.wasPlaying = mediaEditor.isPlaying
                        mediaEditor.stop()
                    }
                }
            })
        }
        
        deinit {
            self.subjectDisposable?.dispose()
            self.gradientColorsDisposable?.dispose()
            self.appInForegroundDisposable?.dispose()
            self.playbackPositionDisposable?.dispose()
        }
        
        private func setup(with subject: MediaEditorScreen.Subject) {
            self.subject = subject
            guard let controller = self.controller else {
                return
            }
            
            if case let .draft(draft, _) = subject, let privacy = draft.privacy {
                controller.state.privacy = privacy
            }
            
            var isFromCamera = false
            let isSavingAvailable: Bool
            switch subject {
            case .image, .video:
                isSavingAvailable = !controller.isEditingStory
                isFromCamera = true
            case .draft:
                isSavingAvailable = true
            default:
                isSavingAvailable = false
            }
            controller.isSavingAvailable = isSavingAvailable
            controller.requestLayout(transition: .immediate)
            
            let mediaDimensions = subject.dimensions
            let maxSide: CGFloat = 1920.0 / UIScreen.main.scale
            let fittedSize = mediaDimensions.cgSize.fitted(CGSize(width: maxSide, height: maxSide))
            let mediaEntity = DrawingMediaEntity(content: subject.mediaContent, size: fittedSize)
            mediaEntity.position = CGPoint(x: storyDimensions.width / 2.0, y: storyDimensions.height / 2.0)
            if fittedSize.height > fittedSize.width {
                mediaEntity.scale = max(storyDimensions.width / fittedSize.width, storyDimensions.height / fittedSize.height)
            } else {
                mediaEntity.scale = storyDimensions.width / fittedSize.width
            }

            let initialPosition = mediaEntity.position
            let initialScale = mediaEntity.scale
            let initialRotation = mediaEntity.rotation
            
            if isFromCamera && mediaDimensions.width > mediaDimensions.height {
                mediaEntity.scale = storyDimensions.height / fittedSize.height
            }

            self.entitiesView.add(mediaEntity, announce: false)
                       
            let initialValues: MediaEditorValues?
            if case let .draft(draft, _) = subject {
                initialValues = draft.values

                for entity in draft.values.entities {
                    self.entitiesView.add(entity.entity, announce: false)
                }
                
                if let drawingData = initialValues?.drawing?.pngData() {
                    self.drawingView.setup(withDrawing: drawingData)
                }
            } else {
                initialValues = nil
            }
            
            if let entityView = self.entitiesView.getView(for: mediaEntity.uuid) as? DrawingMediaEntityView {
                self.entitiesView.sendSubviewToBack(entityView)
                entityView.previewView = self.previewView
                entityView.updated = { [weak self, weak mediaEntity] in
                    if let self, let mediaEntity {
                        let rotationDelta = mediaEntity.rotation - initialRotation
                        let positionDelta = CGPoint(x: mediaEntity.position.x - initialPosition.x, y: mediaEntity.position.y - initialPosition.y)
                        let scaleDelta = mediaEntity.scale / initialScale
                        self.mediaEditor?.setCrop(offset: positionDelta, scale: scaleDelta, rotation: rotationDelta, mirroring: false)
                    }
                }
                
                if let initialValues {
                    mediaEntity.position = mediaEntity.position.offsetBy(dx: initialValues.cropOffset.x, dy: initialValues.cropOffset.y)
                    mediaEntity.rotation = mediaEntity.rotation + initialValues.cropRotation
                    mediaEntity.scale = mediaEntity.scale * initialValues.cropScale
                }
            }
            
            let mediaEditor = MediaEditor(context: self.context, subject: subject.editorSubject, values: initialValues, hasHistogram: true)
            if let initialVideoPosition = self.controller?.initialVideoPosition {
                mediaEditor.seek(initialVideoPosition, andPlay: true)
            }
            mediaEditor.attachPreviewView(self.previewView)
            mediaEditor.valuesUpdated = { [weak self] values in
                if let self, let controller = self.controller, values.gradientColors != nil, controller.previousSavedValues != values {
                    if !isSavingAvailable && controller.previousSavedValues == nil {
                        controller.previousSavedValues = values
                        controller.isSavingAvailable = false
                    } else {
                        self.hasAnyChanges = true
                        controller.isSavingAvailable = true
                    }
                    controller.requestLayout(transition: .animated(duration: 0.25, curve: .easeInOut))
                }
            }
            
            if case let .image(_, _, additionalImage, position) = subject, let additionalImage {
                let image = generateImage(CGSize(width: additionalImage.size.width, height: additionalImage.size.width), contextGenerator: { size, context in
                    let bounds = CGRect(origin: .zero, size: size)
                    context.clear(bounds)
                    context.addEllipse(in: bounds)
                    context.clip()
                    
                    if let cgImage = additionalImage.cgImage {
                        context.draw(cgImage, in: CGRect(origin: CGPoint(x: (size.width - additionalImage.size.width) / 2.0, y: (size.height - additionalImage.size.height) / 2.0), size: additionalImage.size))
                    }
                }, scale: 1.0)
                let imageEntity = DrawingStickerEntity(content: .image(image ?? additionalImage, .dualPhoto))
                imageEntity.referenceDrawingSize = storyDimensions
                imageEntity.scale = 1.625
                imageEntity.position = position.getPosition(storyDimensions)
                self.entitiesView.add(imageEntity, announce: false)
            } else if case let .video(_, _, mirror, additionalVideoPath, _, _, _, changes, position) = subject {
                mediaEditor.setVideoIsMirrored(mirror)
                if let additionalVideoPath {
                    let videoEntity = DrawingStickerEntity(content: .dualVideoReference)
                    videoEntity.referenceDrawingSize = storyDimensions
                    videoEntity.scale = 1.625
                    videoEntity.position = position.getPosition(storyDimensions)
                    self.entitiesView.add(videoEntity, announce: false)
                    
                    mediaEditor.setAdditionalVideo(additionalVideoPath, positionChanges: changes.map { VideoPositionChange(additional: $0.0, timestamp: $0.1) })
                    mediaEditor.setAdditionalVideoPosition(videoEntity.position, scale: videoEntity.scale, rotation: videoEntity.rotation)
                    if let entityView = self.entitiesView.getView(for: videoEntity.uuid) as? DrawingStickerEntityView {
                        entityView.updated = { [weak videoEntity, weak self] in
                            if let self, let videoEntity {
                                self.mediaEditor?.setAdditionalVideoPosition(videoEntity.position, scale: videoEntity.scale, rotation: videoEntity.rotation)
                            }
                        }
                    }
                }
            }
            
            self.gradientColorsDisposable = mediaEditor.gradientColors.start(next: { [weak self] colors in
                if let self, let colors {
                    let (topColor, bottomColor) = colors
                    let gradientImage = generateGradientImage(size: CGSize(width: 5.0, height: 640.0), colors: [topColor, bottomColor], locations: [0.0, 1.0])
                    Queue.mainQueue().async {
                        self.gradientView.image = gradientImage
                        
                        if self.controller?.isEditingStory == true && subject.isVideo {
                            
                        } else {
                            self.previewContainerView.alpha = 1.0
                            if CACurrentMediaTime() - self.initializationTimestamp > 0.2, case .image = subject {
                                self.previewContainerView.layer.allowsGroupOpacity = true
                                self.previewContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { _ in
                                    self.previewContainerView.layer.allowsGroupOpacity = false
                                    self.previewContainerView.alpha = 1.0
                                    self.backgroundDimView.isHidden = false
                                })
                            } else {
                                self.backgroundDimView.isHidden = false
                            }
                        }
                    }
                }
            })
            self.mediaEditor = mediaEditor
            self.mediaEditorPromise.set(.single(mediaEditor))
            
            if self.controller?.isEditingStory == true && subject.isVideo {
                mediaEditor.onFirstDisplay = { [weak self] in
                    if let self {
                        self.previewContainerView.alpha = 1.0
                        self.backgroundDimView.isHidden = false
                    }
                }
            }
            
            mediaEditor.onPlaybackAction = { [weak self] action in
                if let self {
                    switch action {
                    case .play:
                        self.entitiesView.play()
                    case .pause:
                        self.entitiesView.pause()
                    case let .seek(timestamp):
                        self.entitiesView.seek(to: timestamp)
                    }
                }
            }
        }
       
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveModalDismiss = true
            self.view.disablesInteractiveKeyboardGestureRecognizer = true
            
            let dismissPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handleDismissPan(_:)))
            dismissPanGestureRecognizer.delegate = self
            dismissPanGestureRecognizer.maximumNumberOfTouches = 1
            self.previewContainerView.addGestureRecognizer(dismissPanGestureRecognizer)
            self.dismissPanGestureRecognizer = dismissPanGestureRecognizer
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            panGestureRecognizer.delegate = self
            panGestureRecognizer.minimumNumberOfTouches = 1
            panGestureRecognizer.maximumNumberOfTouches = 2
            self.previewContainerView.addGestureRecognizer(panGestureRecognizer)
            
            let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinch(_:)))
            pinchGestureRecognizer.delegate = self
            self.previewContainerView.addGestureRecognizer(pinchGestureRecognizer)
            
            let rotateGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(self.handleRotate(_:)))
            rotateGestureRecognizer.delegate = self
            self.previewContainerView.addGestureRecognizer(rotateGestureRecognizer)
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
            tapGestureRecognizer.delegate = self
            self.previewContainerView.addGestureRecognizer(tapGestureRecognizer)
            
            self.interaction = DrawingToolsInteraction(
                context: self.context,
                drawingView: self.drawingView,
                entitiesView: self.entitiesView,
                contentWrapperView: self.previewContainerView,
                selectionContainerView: self.selectionContainerView,
                isVideo: false,
                autoselectEntityOnPan: true,
                updateSelectedEntity: { [weak self] _ in
                    if let self {
                        self.requestUpdate(transition: .easeInOut(duration: 0.2))
                    }
                },
                updateVideoPlayback: { [weak self] isPlaying in
                    if let self, let mediaEditor = self.mediaEditor {
                        if isPlaying {
                            mediaEditor.play()
                        } else {
                            mediaEditor.stop()
                        }
                    }
                },
                updateColor: { [weak self] color in
                    if let self, let selectedEntityView = self.entitiesView.selectedEntityView {
                        selectedEntityView.entity.color = color
                        selectedEntityView.update(animated: false)
                    }
                },
                onInteractionUpdated: { [weak self] isInteracting in
                    if let self {
                        if let selectedEntityView = self.entitiesView.selectedEntityView as? DrawingStickerEntityView, let entity = selectedEntityView.entity as? DrawingStickerEntity, case .dualVideoReference = entity.content {
                            if isInteracting {
                                self.mediaEditor?.stop()
                            } else {
                                self.mediaEditor?.play()
                            }
                        } else if self.mediaEditor?.sourceIsVideo == true {
                            if isInteracting {
                                self.mediaEditor?.stop()
                            } else {
                                self.mediaEditor?.play()
                            }
                        }
                        self.isInteractingWithEntities = isInteracting
                        if !isInteracting {
                            self.controller?.isSavingAvailable = true
                            self.hasAnyChanges = true
                        }
                        self.requestUpdate(transition: .easeInOut(duration: 0.2))
                    }
                },
                onTextEditingEnded: { [weak self] reset in
                    if let self, !reset, let entity = self.entitiesView.selectedEntityView?.entity as? DrawingTextEntity, !entity.text.string.isEmpty {
                        let _ = updateMediaEditorStoredStateInteractively(engine: self.context.engine, { current in
                            let textSettings = MediaEditorStoredTextSettings(style: entity.style, font: entity.font, fontSize: entity.fontSize, alignment: entity.alignment)
                            if let current {
                                return current.withUpdatedTextSettings(textSettings)
                            } else {
                                return MediaEditorStoredState(privacy: nil, textSettings: textSettings)
                            }
                        }).start()
                    }
                },
                editEntity: { [weak self] entity in
                    if let self {
                        if let location = entity as? DrawingLocationEntity {
                            self.presentLocationPicker(location)
                        }
                    }
                },
                getCurrentImage: { [weak self] in
                    guard let self else {
                        return nil
                    }
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let imageSize = CGSize(width: 1080, height: 1920)
                    let context = DrawingContext(size: imageSize, scale: 1.0, opaque: true, colorSpace: colorSpace)
                    
                    context?.withFlippedContext { context in
                        if let gradientImage = self.gradientView.image?.cgImage {
                            context.draw(gradientImage, in: CGRect(origin: .zero, size: imageSize))
                        }
                        if let image = self.mediaEditor?.resultImage, let values = self.mediaEditor?.values {
                            let initialScale: CGFloat
                            if image.size.height > image.size.width {
                                initialScale = max(imageSize.width / image.size.width, imageSize.height / image.size.height)
                            } else {
                                initialScale = imageSize.width / image.size.width
                            }
                            let scale = initialScale * values.cropScale
                            context.translateBy(x: imageSize.width / 2.0 + values.cropOffset.x, y: imageSize.height / 2.0 - values.cropOffset.y)
                            context.rotate(by: -values.cropRotation)
                            context.scaleBy(x: scale, y: scale)
                                                                                                                            
                            if let cgImage = image.cgImage {
                                context.draw(cgImage, in: CGRect(x: -image.size.width / 2.0, y: -image.size.height / 2.0, width: image.size.width, height: image.size.height))
                            }
                        }
                    }
                    
                    return context?.generateImage(colorSpace: colorSpace)
                },
                getControllerNode: { [weak self] in
                    return self
                },
                present: { [weak self] c, i, a in
                    if let self {
                        self.controller?.present(c, in: i, with: a)
                    }
                },
                addSubview: { [weak self] view in
                    if let self {
                        self.view.addSubview(view)
                    }
                }
            )
        }
        
        @objc func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if let panRecognizer = gestureRecognizer as? UIPanGestureRecognizer, panRecognizer.minimumNumberOfTouches == 1, panRecognizer.state == .changed {
                if otherGestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIRotationGestureRecognizer {
                    return true
                } else {
                    return false
                }
            } else if let panRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer, panRecognizer.minimumNumberOfTouches == 1, panRecognizer.state == .changed {
                return false
            } else if gestureRecognizer is UITapGestureRecognizer, (otherGestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIRotationGestureRecognizer) && otherGestureRecognizer.state == .changed {
                return false
            }
            return true
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if self.entitiesView.isEditingText {
                return false
            }
            if gestureRecognizer === self.dismissPanGestureRecognizer {
                let location = gestureRecognizer.location(in: self.entitiesView)
                if self.isDisplayingTool || self.entitiesView.hasSelection || self.entitiesView.getView(at: location) != nil {
                    return false
                }
                return true
            } else {
                return true
            }
        }
        
        private var enhanceInitialTranslation: Float?
        
        @objc func handleDismissPan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let controller = self.controller, let layout = self.validLayout, (layout.inputHeight ?? 0.0).isZero else {
                return
            }
            
            var hasSwipeToDismiss = false
            if let subject = self.subject {
                if case .asset = subject {
                    hasSwipeToDismiss = true
                } else if case .draft = subject {
                    hasSwipeToDismiss = true
                }
            }
            
            let translation = gestureRecognizer.translation(in: self.view)
            let velocity = gestureRecognizer.velocity(in: self.view)
            switch gestureRecognizer.state {
            case .changed:
                if abs(translation.y) > 10.0 && !self.isEnhancing && hasSwipeToDismiss {
                    if !self.isDismissing {
                        self.isDismissing = true
                        self.isDismissBySwipeSuppressed = controller.isEligibleForDraft()
                        controller.requestLayout(transition: .animated(duration: 0.25, curve: .easeInOut))
                    }
                } else if abs(translation.x) > 10.0 && !self.isDismissing && !self.isEnhancing {
                    self.isEnhancing = true
                    controller.requestLayout(transition: .animated(duration: 0.3, curve: .easeInOut))
                }
                
                if self.isDismissing {
                    self.dismissOffset = translation.y
                    controller.requestLayout(transition: .immediate)
                    
                    if abs(self.dismissOffset) > 20.0, controller.isEligibleForDraft() {
                        gestureRecognizer.isEnabled = false
                        gestureRecognizer.isEnabled = true
                        controller.maybePresentDiscardAlert()
                    }
                } else if self.isEnhancing {
                    if let mediaEditor = self.mediaEditor {
                        let value = mediaEditor.getToolValue(.enhance) as? Float ?? 0.0
                        
                        if self.enhanceInitialTranslation == nil && value != 0.0 {
                            self.enhanceInitialTranslation = value
                        }
                        
                        let delta = Float((translation.x / self.frame.width) * 1.8)
                        var updatedValue = max(-1.0, min(1.0, value + delta))
                        if let enhanceInitialTranslation = self.enhanceInitialTranslation {
                            if enhanceInitialTranslation > 0.0 {
                                updatedValue = max(0.0, updatedValue)
                            } else {
                                updatedValue = min(0.0, updatedValue)
                            }
                        }
                        mediaEditor.setToolValue(.enhance, value: updatedValue)
                    }
                    self.requestUpdate()
                    gestureRecognizer.setTranslation(.zero, in: self.view)
                }
            case .ended, .cancelled:
                self.enhanceInitialTranslation = nil
                if self.isDismissing {
                    if abs(translation.y) > self.view.frame.height * 0.33 || abs(velocity.y) > 1000.0, !controller.isEligibleForDraft() {
                        controller.requestDismiss(saveDraft: false, animated: true)
                    } else {
                        self.dismissOffset = 0.0
                        self.isDismissing = false
                        controller.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
                    }
                } else {
                    self.isEnhancing = false
                    Queue.mainQueue().after(0.5) {
                        controller.requestLayout(transition: .animated(duration: 0.3, curve: .easeInOut))
                    }
                }
            default:
                break
            }
        }
        
        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            self.entitiesView.handlePan(gestureRecognizer)
        }
        
        @objc func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
            self.entitiesView.handlePinch(gestureRecognizer)
        }
        
        @objc func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
            self.entitiesView.handleRotate(gestureRecognizer)
        }
        
        @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            let location = gestureRecognizer.location(in: self.view)
            var entitiesHitTestResult = self.entitiesView.hitTest(self.view.convert(location, to: self.entitiesView), with: nil)
            if entitiesHitTestResult is DrawingMediaEntityView {
                entitiesHitTestResult = nil
            }
            let selectionHitTestResult = self.selectionContainerView.hitTest(self.view.convert(location, to: self.selectionContainerView), with: nil)
            if entitiesHitTestResult == nil && selectionHitTestResult == nil {
                if self.entitiesView.hasSelection {
                    self.entitiesView.selectEntity(nil)
                    self.view.endEditing(true)
                } else {
                    if let layout = self.validLayout, (layout.inputHeight ?? 0.0) > 0.0 {
                        self.view.endEditing(true)
                    } else {
                        self.insertTextEntity()
                    }
                }
            }
        }
        
        private func insertTextEntity() {
            let _ = (mediaEditorStoredState(engine: self.context.engine)
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self else {
                    return
                }
                var style: DrawingTextEntity.Style = .filled
                var font: DrawingTextEntity.Font = .sanFrancisco
                var alignment: DrawingTextEntity.Alignment = .center
                var fontSize: CGFloat = 1.0
                if let textSettings = state?.textSettings {
                    style = textSettings.style
                    font = textSettings.font
                    alignment = textSettings.alignment
                    fontSize = textSettings.fontSize
                }
                let textEntity = DrawingTextEntity(text: NSAttributedString(), style: style, animation: .none, font: font, alignment: alignment, fontSize: fontSize, color: DrawingColor(color: .white))
                self.interaction?.insertEntity(textEntity)
            })
        }
        
        private func setupTransitionImage(_ image: UIImage) {
            self.previewContainerView.alpha = 1.0
            
            let transitionInView = UIImageView(image: image)
            transitionInView.contentMode = .scaleAspectFill
            var initialScale: CGFloat
            if image.size.height > image.size.width {
                initialScale = max(self.previewContainerView.bounds.width / image.size.width, self.previewContainerView.bounds.height / image.size.height)
            } else {
                initialScale = self.previewContainerView.bounds.width / image.size.width
            }
            transitionInView.center = CGPoint(x: self.previewContainerView.bounds.width / 2.0, y: self.previewContainerView.bounds.height / 2.0)
            transitionInView.transform = CGAffineTransformMakeScale(initialScale, initialScale)
            self.previewContainerView.addSubview(transitionInView)
            self.transitionInView = transitionInView
            
            self.mediaEditor?.onFirstDisplay = { [weak self] in
                if let self, let transitionInView = self.transitionInView  {
                    self.transitionInView = nil
                    transitionInView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak transitionInView] _ in
                        transitionInView?.removeFromSuperview()
                    })
                }
            }
        }
        
        func animateIn() {
            let completion: () -> Void = { [weak self] in
                Queue.mainQueue().after(0.1) {
                    self?.requestUpdate(hasAppeared: true, transition: .immediate)
                }
            }
            
            if let transitionIn = self.controller?.transitionIn {
                switch transitionIn {
                case .camera:
                    if let view = self.componentHost.view as? MediaEditorScreenComponent.View {
                        view.animateIn(from: .camera, completion: completion)
                    }
                    
                    if let subject = self.subject, case let .video(_, mainTransitionImage, _, _, additionalTransitionImage, _, _, positionChangeTimestamps, pipPosition) = subject, let mainTransitionImage {
                        var transitionImage = mainTransitionImage
                        if let additionalTransitionImage {
                            var backgroundImage = mainTransitionImage
                            var foregroundImage = additionalTransitionImage
                            if let change = positionChangeTimestamps.first, change.0 {
                                backgroundImage = additionalTransitionImage
                                foregroundImage = mainTransitionImage
                            }
                            if let combinedTransitionImage = generateImage(CGSize(width: 1080, height: 1920), scale: 1.0, rotatedContext: { size, context in
                                UIGraphicsPushContext(context)
                                backgroundImage.draw(in: CGRect(origin: CGPoint(x: (size.width - backgroundImage.size.width) / 2.0, y: (size.height - backgroundImage.size.height) / 2.0), size: backgroundImage.size))
                                
                                let ellipsePosition =  pipPosition.getPosition(storyDimensions)
                                let ellipseSize = CGSize(width: 439.0, height: 439.0)
                                let ellipseRect = CGRect(origin: CGPoint(x: ellipsePosition.x - ellipseSize.width / 2.0, y: ellipsePosition.y - ellipseSize.height / 2.0), size: ellipseSize)
                                let foregroundSize = foregroundImage.size.aspectFilled(ellipseSize)
                                let foregroundRect = CGRect(origin: CGPoint(x: ellipseRect.center.x - foregroundSize.width / 2.0, y: ellipseRect.center.y - foregroundSize.height / 2.0), size: foregroundSize)
                                context.addEllipse(in: ellipseRect)
                                context.clip()
                                
                                foregroundImage.draw(in: foregroundRect)
                                
                                UIGraphicsPopContext()
                            }) {
                                transitionImage = combinedTransitionImage
                            }
                        }
                        self.setupTransitionImage(transitionImage)
                    }
                case let .gallery(transitionIn):
                    if let sourceImage = transitionIn.sourceImage {
                        self.setupTransitionImage(sourceImage)
                    }
                    if let sourceView = transitionIn.sourceView {
                        if let view = self.componentHost.view as? MediaEditorScreenComponent.View {
                            view.animateIn(from: .gallery)
                        }
                        
                        let sourceLocalFrame = sourceView.convert(transitionIn.sourceRect, to: self.view)
                        let sourceScale = sourceLocalFrame.width / self.previewContainerView.frame.width
                        let sourceAspectRatio = sourceLocalFrame.height / sourceLocalFrame.width
                        
                        let duration: Double = 0.4
                        
                        self.previewContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: self.previewContainerView.center, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
                            completion()
                        })
                        self.previewContainerView.layer.animateScale(from: sourceScale, to: 1.0, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                        self.previewContainerView.layer.animateBounds(from: CGRect(origin: CGPoint(x: 0.0, y: (self.previewContainerView.bounds.height - self.previewContainerView.bounds.width * sourceAspectRatio) / 2.0), size: CGSize(width: self.previewContainerView.bounds.width, height: self.previewContainerView.bounds.width * sourceAspectRatio)), to: self.previewContainerView.bounds, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                        
                        self.backgroundDimView.isHidden = false
                        self.backgroundDimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        
                        if let componentView = self.componentHost.view {
                            componentView.layer.animatePosition(from: sourceLocalFrame.center, to: componentView.center, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            componentView.layer.animateScale(from: sourceScale, to: 1.0, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            componentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        }
                    }
                }
            } else {
                if let view = self.componentHost.view as? MediaEditorScreenComponent.View {
                    view.animateIn(from: .camera, completion: completion)
                }
            }
        }
        
        func animateOut(finished: Bool, saveDraft: Bool, completion: @escaping () -> Void) {
            guard let controller = self.controller else {
                return
            }
            self.isDismissed = true
            controller.statusBar.statusBarStyle = .Ignore
            self.isUserInteractionEnabled = false
            
            if self.entitiesView.hasSelection {
                self.entitiesView.selectEntity(nil)
            }
            
            let previousDimAlpha = self.backgroundDimView.alpha
            self.backgroundDimView.alpha = 0.0
            self.backgroundDimView.layer.animateAlpha(from: previousDimAlpha, to: 0.0, duration: 0.15)
            
            var isNew: Bool? = false
            if let subject = self.subject {
                if saveDraft {
                    isNew = true
                }
                if case .draft = subject, !saveDraft {
                    isNew = nil
                }
            }
            
            if isNew == true {
                self.entitiesView.seek(to: 0.0)
            }
            
            if let transitionOut = controller.transitionOut(finished, isNew), let destinationView = transitionOut.destinationView {
                var destinationTransitionView: UIView?
                if !finished {
                    if let transitionIn = controller.transitionIn, case let .gallery(galleryTransitionIn) = transitionIn, let sourceImage = galleryTransitionIn.sourceImage, isNew != true {
                        let sourceSuperView = galleryTransitionIn.sourceView?.superview?.superview
                        let destinationTransitionOutView = UIImageView(image: sourceImage)
                        destinationTransitionOutView.clipsToBounds = true
                        destinationTransitionOutView.contentMode = .scaleAspectFill
                        destinationTransitionOutView.frame = self.previewContainerView.convert(self.previewContainerView.bounds, to: sourceSuperView)
                        sourceSuperView?.addSubview(destinationTransitionOutView)
                        destinationTransitionView = destinationTransitionOutView
                    }
                    if let view = self.componentHost.view as? MediaEditorScreenComponent.View {
                        view.animateOut(to: .gallery)
                    }
                }
                let destinationLocalFrame = destinationView.convert(transitionOut.destinationRect, to: self.view)
                let destinationScale = destinationLocalFrame.width / self.previewContainerView.frame.width
                let destinationAspectRatio = destinationLocalFrame.height / destinationLocalFrame.width
                
                var destinationSnapshotView: UIView?
                if let destinationNode = destinationView.asyncdisplaykit_node as? AvatarNode {
                    let destinationTransitionView: UIView?
                    if let image = destinationNode.unroundedImage {
                        destinationTransitionView = UIImageView(image: image)
                        destinationTransitionView?.bounds = destinationNode.bounds
                        destinationTransitionView?.layer.cornerRadius = destinationNode.bounds.width / 2.0
                    } else if let snapshotView = destinationView.snapshotView(afterScreenUpdates: false) {
                        destinationTransitionView = snapshotView
                    } else {
                        destinationTransitionView = nil
                    }
                    destinationView.isHidden = true
                    
                    if let destinationTransitionView {
                        destinationTransitionView.layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
                        let snapshotScale = self.previewContainerView.bounds.width / destinationTransitionView.frame.width
                        destinationTransitionView.center = CGPoint(x: 0.0, y: self.previewContainerView.bounds.height / 2.0)
                        destinationTransitionView.layer.transform = CATransform3DMakeScale(snapshotScale, snapshotScale, 1.0)
                        
                        destinationTransitionView.alpha = 0.0
                        Queue.mainQueue().after(0.15) {
                            destinationTransitionView.alpha = 1.0
                            destinationTransitionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                        
                        self.previewContainerView.addSubview(destinationTransitionView)
                        destinationSnapshotView = destinationTransitionView
                    }
                }
                
                self.previewContainerView.layer.animatePosition(from: self.previewContainerView.center, to: destinationLocalFrame.center, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                    destinationView.isHidden = false
                    destinationSnapshotView?.removeFromSuperview()
                    completion()
                    if let view = self.entitiesView.getView(where: { $0 is DrawingMediaEntityView }) as? DrawingMediaEntityView {
                        view.previewView = nil
                    }
                })
                self.previewContainerView.layer.animateScale(from: 1.0, to: destinationScale, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.previewContainerView.layer.animateBounds(from: self.previewContainerView.bounds, to: CGRect(origin: CGPoint(x: 0.0, y: (self.previewContainerView.bounds.height - self.previewContainerView.bounds.width * destinationAspectRatio) / 2.0), size: CGSize(width: self.previewContainerView.bounds.width, height: self.previewContainerView.bounds.width * destinationAspectRatio)), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                
                if let destinationTransitionView {
                    self.previewContainerView.layer.allowsGroupOpacity = true
                    self.previewContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                    destinationTransitionView.layer.animateFrame(from: destinationTransitionView.frame, to: destinationView.convert(destinationView.bounds, to: destinationTransitionView.superview), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak destinationTransitionView] _ in
                        destinationTransitionView?.removeFromSuperview()
                    })
                }
                
                let targetCornerRadius: CGFloat
                if transitionOut.destinationCornerRadius > 0.0 {
                    targetCornerRadius = self.previewContainerView.bounds.width
                } else {
                    targetCornerRadius = 0.0
                }
                
                self.previewContainerView.layer.animate(
                    from: self.previewContainerView.layer.cornerRadius as NSNumber,
                    to: targetCornerRadius / 2.0 as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.4,
                    removeOnCompletion: false
                )
                
                if let componentView = self.componentHost.view {
                    componentView.clipsToBounds = true
                    componentView.layer.animatePosition(from: componentView.center, to: destinationLocalFrame.center, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    componentView.layer.animateScale(from: 1.0, to: destinationScale, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    componentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                    if finished {
                        componentView.layer.animateBounds(from: componentView.bounds, to: CGRect(origin: CGPoint(x: 0.0, y: (componentView.bounds.height - componentView.bounds.width) / 2.0), size: CGSize(width: componentView.bounds.width, height: componentView.bounds.width)), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                        componentView.layer.animate(
                            from: componentView.layer.cornerRadius as NSNumber,
                            to: componentView.bounds.width / 2.0 as NSNumber,
                            keyPath: "cornerRadius",
                            timingFunction: kCAMediaTimingFunctionSpring,
                            duration: 0.4,
                            removeOnCompletion: false
                        )
                    }
                }
            } else if let transitionIn = controller.transitionIn, case .camera = transitionIn {
                if let view = self.componentHost.view as? MediaEditorScreenComponent.View {
                    view.animateOut(to: .camera)
                }
                let transition = Transition(animation: .curve(duration: 0.25, curve: .easeInOut))
                transition.setAlpha(view: self.previewContainerView, alpha: 0.0, completion: { _ in
                    completion()
                })
            } else {
                if controller.isEditingStory {
                    if let view = self.componentHost.view as? MediaEditorScreenComponent.View {
                        view.animateOut(to: .gallery)
                    }
                    
                    self.layer.allowsGroupOpacity = true
                    self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.4, removeOnCompletion: false, completion: { _ in
                        completion()
                    })
                } else {
                    self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.4, removeOnCompletion: false)
                    self.layer.animateScale(from: 1.0, to: 0.8, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    self.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: self.bounds.height), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { _ in
                        completion()
                    })
                }
            }
        }
        
        func animateOutToTool() {
            self.isDisplayingTool = true
            
            let transition: Transition = .easeInOut(duration: 0.2)
            if let view = self.componentHost.view as? MediaEditorScreenComponent.View {
                view.animateOutToTool(transition: transition)
            }
            self.requestUpdate(transition: transition)
        }
        
        func animateInFromTool() {
            self.isDisplayingTool = false
            
            let transition: Transition = .easeInOut(duration: 0.2)
            if let view = self.componentHost.view as? MediaEditorScreenComponent.View {
                view.animateInFromTool(transition: transition)
            }
            self.requestUpdate(transition: transition)
        }
                
        private weak var muteTooltip: ViewController?
        func presentMutedTooltip() {
            guard let sourceView = self.componentHost.findTaggedView(tag: muteButtonTag) else {
                return
            }

            if let muteTooltip = self.muteTooltip {
                muteTooltip.dismiss()
                self.muteTooltip = nil
            }
            
            let isMuted = self.mediaEditor?.values.videoIsMuted ?? false
            
            let parentFrame = self.view.convert(self.bounds, to: nil)
            let absoluteFrame = sourceView.convert(sourceView.bounds, to: nil).offsetBy(dx: -parentFrame.minX, dy: 0.0)
            let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.maxY + 3.0), size: CGSize())
            
            let text: String
            if isMuted {
                text = self.presentationData.strings.Story_Editor_TooltipMuted
            } else {
                text = self.presentationData.strings.Story_Editor_TooltipUnmuted
            }
            
            let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: text), location: .point(location, .top), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .ignore
            })
            self.muteTooltip = tooltipController
            self.controller?.present(tooltipController, in: .current)
        }
        
        private weak var saveTooltip: SaveProgressScreen?
        func presentSaveTooltip() {
            guard let controller = self.controller else {
                return
            }
            
            if let saveTooltip = self.saveTooltip {
                if case .completion = saveTooltip.content {
                    saveTooltip.dismiss()
                    self.saveTooltip = nil
                }
            }
            
            let text: String
            let isVideo = self.mediaEditor?.resultIsVideo ?? false
            if isVideo {
                text = self.presentationData.strings.Story_Editor_TooltipVideoSavedToPhotos
            } else {
                text = self.presentationData.strings.Story_Editor_TooltipImageSavedToPhotos
            }
            
            if let tooltipController = self.saveTooltip {
                tooltipController.content = .completion(text)
            } else {
                let tooltipController = SaveProgressScreen(context: self.context, content: .completion(text))
                controller.present(tooltipController, in: .current)
                self.saveTooltip = tooltipController
            }
        }
        
        func updateEditProgress(_ progress: Float, cancel: @escaping () -> Void) {
            guard let controller = self.controller else {
                return
            }
            
            if let saveTooltip = self.saveTooltip {
                if case .completion = saveTooltip.content {
                    saveTooltip.dismiss()
                    self.saveTooltip = nil
                }
            }
            
            let text = self.presentationData.strings.Story_Editor_Uploading
            if let tooltipController = self.saveTooltip {
                tooltipController.content = .progress(text, progress)
            } else {
                let tooltipController = SaveProgressScreen(context: self.context, content: .progress(text, 0.0))
                tooltipController.cancelled = { [weak self] in
                    cancel()
                    if let self, let controller = self.controller {
                        controller.cancelVideoExport()
                    }
                }
                controller.present(tooltipController, in: .current)
                self.saveTooltip = tooltipController
            }
        }
        
        func updateVideoExportProgress(_ progress: Float) {
            guard let controller = self.controller else {
                return
            }
            
            if let saveTooltip = self.saveTooltip {
                if case .completion = saveTooltip.content {
                    saveTooltip.dismiss()
                    self.saveTooltip = nil
                }
            }
            
            let text = self.presentationData.strings.Story_Editor_PreparingVideo
            if let tooltipController = self.saveTooltip {
                tooltipController.content = .progress(text, progress)
            } else {
                let tooltipController = SaveProgressScreen(context: self.context, content: .progress(text, 0.0))
                tooltipController.cancelled = { [weak self] in
                    if let self, let controller = self.controller {
                        controller.isSavingAvailable = true
                        controller.cancelVideoExport()
                        controller.requestLayout(transition: .animated(duration: 0.25, curve: .easeInOut))
                    }
                }
                controller.present(tooltipController, in: .current)
                self.saveTooltip = tooltipController
            }
        }
                
        func presentGallery(parentController: ViewController? = nil) {
            guard let controller = self.controller else {
                return
            }
            let parentController = parentController ?? controller
            let galleryController = self.context.sharedContext.makeMediaPickerScreen(context: self.context, hasSearch: true, completion: { [weak self] result in
                guard let self else {
                    return
                }
                
                func roundedImageWithTransparentCorners(image: UIImage, cornerRadius: CGFloat) -> UIImage? {
                    let rect = CGRect(origin: .zero, size: image.size)
                    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
                    let context = UIGraphicsGetCurrentContext()
                    
                    if let context = context {
                        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
                        context.addPath(path.cgPath)
                        context.clip()
                        image.draw(in: rect)
                    }
                    
                    let newImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    return newImage
                }
                
                let completeWithImage: (UIImage) -> Void = { [weak self] image in
                    let updatedImage = roundedImageWithTransparentCorners(image: image, cornerRadius: floor(image.size.width * 0.03))!
                    self?.interaction?.insertEntity(DrawingStickerEntity(content: .image(updatedImage, .rectangle)), scale: 2.5)
                }
                
                if let asset = result as? PHAsset {
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                        if let image {
                            Queue.mainQueue().async {
                                completeWithImage(image)
                            }
                        }
                    }
                } else if let image = result as? UIImage {
                    completeWithImage(image)
                }
            })
            galleryController.customModalStyleOverlayTransitionFactorUpdated = { [weak self, weak galleryController] transition in
                if let self, let galleryController {
                    let transitionFactor = galleryController.modalStyleOverlayTransitionFactor
                    self.updateModalTransitionFactor(transitionFactor, transition: transition)
                }
            }
            parentController.push(galleryController)
        }
        
        private let staticEmojiPack = Promise<LoadedStickerPack>()
        private var didSetupStaticEmojiPack = false
        
        func presentLocationPicker(_ existingEntity: DrawingLocationEntity? = nil) {
            guard let controller = self.controller else {
                return
            }
            
            if !self.didSetupStaticEmojiPack {
                self.staticEmojiPack.set(self.context.engine.stickers.loadedStickerPack(reference: .name("staticemoji"), forceActualized: false))
            }
            
            func flag(countryCode: String) -> String {
                let base : UInt32 = 127397
                var flagString = ""
                for v in countryCode.uppercased().unicodeScalars {
                    flagString.unicodeScalars.append(UnicodeScalar(base + v.value)!)
                }
                return flagString
            }
            
            var location: CLLocationCoordinate2D?
            if let subject = self.subject {
                if case let .asset(asset) = subject {
                    location = asset.location?.coordinate
                } else if case let .draft(draft, _) = subject {
                    location = draft.location
                }
            }
            let locationController = storyLocationPickerController(
                context: self.context,
                location: location,
                dismissed: { [weak self] in
                    if let self {
                        self.mediaEditor?.play()
                    }
                },
                completion: { [weak self] location, queryId, resultId, address, countryCode in
                if let self  {
                    let emojiFile: Signal<TelegramMediaFile?, NoError>
                    if let countryCode {
                        let flagEmoji = flag(countryCode: countryCode)
                        emojiFile = self.staticEmojiPack.get()
                        |> filter { result in
                            if case .result = result {
                                return true
                            } else {
                                return false
                            }
                        }
                        |> take(1)
                        |> map { result -> TelegramMediaFile? in
                            if case let .result(_, items, _) = result, let match = items.first(where: { item in
                                var displayText: String?
                                for attribute in item.file.attributes {
                                    if case let .CustomEmoji(_, _, alt, _) = attribute {
                                        displayText = alt
                                        break
                                    }
                                }
                                if let displayText, displayText.hasPrefix(flagEmoji) {
                                    return true
                                } else {
                                    return false
                                }
                            }) {
                                return match.file
                            } else {
                                return nil
                            }
                        }
                    } else {
                        emojiFile = .single(nil)
                    }
                    
                    let _ = emojiFile.start(next: { [weak self] emojiFile in
                        guard let self else {
                            return
                        }
                        let title: String
                        if let venueTitle = location.venue?.title {
                            title = venueTitle
                        } else {
                            title = address ?? "Location"
                        }
                        let position = existingEntity?.position
                        let scale = existingEntity?.scale ?? 1.0
                        if let existingEntity {
                            self.entitiesView.remove(uuid: existingEntity.uuid, animated: true)
                        }
                        self.interaction?.insertEntity(
                            DrawingLocationEntity(
                                title: title,
                                style: existingEntity?.style ?? .white,
                                location: location,
                                icon: emojiFile,
                                queryId: queryId,
                                resultId: resultId
                            ),
                            scale: scale,
                            position: position
                        )
                    })
                }
            })
            locationController.customModalStyleOverlayTransitionFactorUpdated = { [weak self, weak locationController] transition in
                if let self, let locationController {
                    let transitionFactor = locationController.modalStyleOverlayTransitionFactor
                    self.updateModalTransitionFactor(transitionFactor, transition: transition)
                }
            }
            controller.push(locationController)
        }
        
        func updateModalTransitionFactor(_ value: CGFloat, transition: ContainedViewLayoutTransition) {
            guard let layout = self.validLayout, case .compact = layout.metrics.widthClass else {
                return
            }
            
            let progress = 1.0 - value
            let maxScale = (layout.size.width - 16.0 * 2.0) / layout.size.width
            
            let topInset: CGFloat = (layout.statusBarHeight ?? 0.0) + 5.0
            let targetTopInset = ceil((layout.statusBarHeight ?? 0.0) - (layout.size.height - layout.size.height * maxScale) / 2.0)
            let deltaOffset = (targetTopInset - topInset)
            
            let scale = 1.0 * progress + (1.0 - progress) * maxScale
            let offset = (1.0 - progress) * deltaOffset
            transition.updateSublayerTransformScaleAndOffset(layer: self.containerView.layer, scale: scale, offset: CGPoint(x: 0.0, y: offset), beginWithCurrentState: true)
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.componentHost.view {
                let point = self.view.convert(point, to: self.previewContainerView)
                return self.previewContainerView.hitTest(point, with: event)
            }
            return result
        }
        
        func requestUpdate(hasAppeared: Bool = false, transition: Transition = .immediate) {
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout: layout, hasAppeared: hasAppeared, transition: transition)
            }
        }
        
        fileprivate var drawingScreen: DrawingScreen?
        fileprivate var stickerScreen: StickerPickerScreen?
        private var defaultToEmoji = false
        
        private var previousDrawingData: Data?
        private var previousDrawingEntities: [DrawingEntity]?
        
        func requestLayout(forceUpdate: Bool, transition: Transition) {
            guard let layout = self.validLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, forceUpdate: forceUpdate, hasAppeared: self.hasAppeared, transition: transition)
        }
                
        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, hasAppeared: Bool = false, transition: Transition) {
            guard let controller = self.controller, !self.isDismissed else {
                return
            }
            let isFirstTime = self.validLayout == nil
            self.validLayout = layout
            
            let isTablet: Bool
            if case .regular = layout.metrics.widthClass {
                isTablet = true
            } else {
                isTablet = false
            }

            var topInset: CGFloat = (layout.statusBarHeight ?? 0.0) + 5.0
            let previewSize: CGSize
            if isTablet {
                let previewHeight = layout.size.height - topInset - 75.0
                previewSize = CGSize(width: floorToScreenPixels(previewHeight / 1.77778), height: previewHeight)
            } else {
                previewSize = CGSize(width: layout.size.width, height: floorToScreenPixels(layout.size.width * 1.77778))
                if layout.size.height < previewSize.height + 30.0 {
                    topInset = 0.0
                }
            }
            let bottomInset = max(0.0, layout.size.height - previewSize.height - topInset)
            
            var layoutInputHeight = layout.inputHeight ?? 0.0
            if self.stickerScreen != nil {
                layoutInputHeight = 0.0
            }
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: 0.0,
                safeInsets: UIEdgeInsets(
                    top: topInset,
                    left: layout.safeInsets.left,
                    bottom: bottomInset,
                    right: layout.safeInsets.right
                ),
                inputHeight: layoutInputHeight,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: nil,
                isVisible: true,
                theme: defaultDarkPresentationTheme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )
            
            if hasAppeared && !self.hasAppeared {
                self.hasAppeared = hasAppeared
            }

            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    MediaEditorScreenComponent(
                        context: self.context,
                        externalState: self.componentExternalState,
                        isDisplayingTool: self.isDisplayingTool,
                        isInteractingWithEntities: self.isInteractingWithEntities,
                        isSavingAvailable: controller.isSavingAvailable,
                        hasAppeared: self.hasAppeared,
                        isDismissing: self.isDismissing && !self.isDismissBySwipeSuppressed,
                        bottomSafeInset: layout.intrinsicInsets.bottom,
                        mediaEditor: self.mediaEditorPromise.get(),
                        privacy: controller.state.privacy,
                        selectedEntity: self.isDisplayingTool ? nil : self.entitiesView.selectedEntityView?.entity,
                        entityViewForEntity: { [weak self] entity in
                            if let self {
                                return self.entitiesView.getView(for: entity.uuid)
                            } else {
                                return nil
                            }
                        },
                        openDrawing: { [weak self] mode in
                            if let self {
                                if self.entitiesView.hasSelection {
                                    self.entitiesView.selectEntity(nil)
                                }
                                switch mode {
                                case .sticker:
                                    self.mediaEditor?.stop()
                                    let controller = StickerPickerScreen(context: self.context, inputData: self.stickerPickerInputData.get(), defaultToEmoji: self.defaultToEmoji, hasGifs: true)
//                                    controller.completion = { [weak self] content in
//                                        if let self {
//                                            if let content {
//                                                if case let .file(file, _) = content {
//                                                    if file.isCustomEmoji {
//                                                        self.defaultToEmoji = true
//                                                    } else {
//                                                        self.defaultToEmoji = false
//                                                    }
//                                                }
//                                                                                                
//                                                let stickerEntity = DrawingStickerEntity(content: content)
//                                                let scale: CGFloat
//                                                if case .image = content {
//                                                    scale = 2.5
//                                                } else if case .video = content {
//                                                    scale = 2.5
//                                                } else {
//                                                    scale = 1.33
//                                                }
//                                                self.interaction?.insertEntity(stickerEntity, scale: scale)
//                                                
//                                                self.hasAnyChanges = true
//                                                self.controller?.isSavingAvailable = true
//                                                self.controller?.requestLayout(transition: .immediate)
//                                            }
//                                            self.stickerScreen = nil
//                                            self.mediaEditor?.play()
//                                        }
//                                    }
                                    controller.customModalStyleOverlayTransitionFactorUpdated = { [weak self, weak controller] transition in
                                        if let self, let controller {
                                            let transitionFactor = controller.modalStyleOverlayTransitionFactor
                                            self.updateModalTransitionFactor(transitionFactor, transition: transition)
                                        }
                                    }
                                    controller.presentGallery = { [weak self] in
                                        if let self {
                                            self.stickerScreen = nil
                                            self.presentGallery()
                                        }
                                    }
                                    controller.presentLocationPicker = { [weak self, weak controller] in
                                        if let self {
                                            self.stickerScreen = nil
                                            controller?.dismiss(animated: true)
                                            self.presentLocationPicker()
                                        }
                                    }
                                    self.stickerScreen = controller
                                    self.controller?.present(controller, in: .window(.root))
                                    return
                                case .text:
                                    self.mediaEditor?.stop()
                                    self.insertTextEntity()
                                    
                                    self.hasAnyChanges = true
                                    self.controller?.isSavingAvailable = true
                                    self.controller?.requestLayout(transition: .immediate)
                                    return
                                case .drawing:
                                    self.previousDrawingData = self.drawingView.drawingData
                                    self.previousDrawingEntities = self.entitiesView.entities
                                    
                                    self.interaction?.deactivate()
                                    let controller = DrawingScreen(
                                        context: self.context,
                                        sourceHint: .storyEditor,
                                        size: self.previewContainerView.frame.size,
                                        originalSize: storyDimensions,
                                        isVideo: self.mediaEditor?.sourceIsVideo ?? false,
                                        isAvatar: false,
                                        drawingView: self.drawingView,
                                        entitiesView: self.entitiesView,
                                        selectionContainerView: self.selectionContainerView,
                                        existingStickerPickerInputData: self.stickerPickerInputData
                                    )
                                    controller.presentGallery = { [weak self] in
                                        if let self {
                                            self.presentGallery()
                                        }
                                    }
                                    controller.getCurrentImage = { [weak self] in
                                        return self?.interaction?.getCurrentImage()
                                    }
                                    controller.updateVideoPlayback = { [weak self] play in
                                        guard let self else {
                                            return
                                        }
                                        if play {
                                            self.mediaEditor?.play()
                                        } else {
                                            self.mediaEditor?.stop()
                                        }
                                    }
                                    self.drawingScreen = controller
                                    self.drawingView.isUserInteractionEnabled = true

                                    controller.requestDismiss = { [weak controller, weak self] in
                                        guard let self else {
                                            return
                                        }
                                        self.drawingScreen = nil
                                        controller?.animateOut({
                                            controller?.dismiss()
                                        })
                                        self.drawingView.isUserInteractionEnabled = false
                                        self.animateInFromTool()

                                        self.interaction?.reset()
                                        
                                        self.interaction?.activate()
                                        self.entitiesView.selectEntity(nil)
                                        
                                        self.drawingView.setup(withDrawing: self.previousDrawingData)
                                        self.entitiesView.setup(with: self.previousDrawingEntities ?? [])
                                        
                                        self.previousDrawingData = nil
                                        self.previousDrawingEntities = nil
                                    }
                                    controller.requestApply = { [weak controller, weak self] in
                                        guard let self else {
                                            return
                                        }
                                        self.drawingScreen = nil
                                        controller?.animateOut({
                                            controller?.dismiss()
                                        })
                                        self.drawingView.isUserInteractionEnabled = false
                                        self.animateInFromTool()
                                        
                                        self.interaction?.reset()

                                        if let result = controller?.generateDrawingResultData() {
                                            self.mediaEditor?.setDrawingAndEntities(data: result.data, image: result.drawingImage, entities: result.entities)
                                        } else {
                                            self.mediaEditor?.setDrawingAndEntities(data: nil, image: nil, entities: [])
                                        }

                                        self.interaction?.activate()
                                        self.entitiesView.selectEntity(nil)
                                    }
                                    self.controller?.present(controller, in: .current)
                                    self.animateOutToTool()
                                }
                            }
                        },
                        openTools: { [weak self] in
                            if let self, let mediaEditor = self.mediaEditor {
                                if self.entitiesView.hasSelection {
                                    self.entitiesView.selectEntity(nil)
                                }
                                let controller = MediaToolsScreen(context: self.context, mediaEditor: mediaEditor)
                                controller.dismissed = { [weak self] in
                                    if let self {
                                        self.animateInFromTool()
                                    }
                                }
                                self.controller?.present(controller, in: .window(.root))
                                self.animateOutToTool()
                            }
                        }
                    )
                ),
                environment: {
                    environment
                },
                forceUpdate: forceUpdate,
                containerSize: layout.size
            )
            if let componentView = self.componentHost.view {
                if componentView.superview == nil {
                    self.containerView.addSubview(componentView)
                    componentView.clipsToBounds = true
                }
                transition.setFrame(view: componentView, frame: CGRect(origin: CGPoint(x: 0.0, y: self.dismissOffset), size: componentSize))
            }
            
            let inputHeight = self.componentExternalState.derivedInputHeight
            
            let storyPreviewSize = self.storyPreview.update(
                transition: transition,
                component: AnyComponent(
                    StoryPreviewComponent(
                        context: self.context,
                        caption: ""
                    )
                ),
                environment: {},
                forceUpdate: false,
                containerSize: previewSize
            )
            if let storyPreviewView = self.storyPreview.view {
                if storyPreviewView.superview == nil {
                    storyPreviewView.alpha = 0.0
                    storyPreviewView.isUserInteractionEnabled = false
                    self.previewContainerView.addSubview(storyPreviewView)
                }
                transition.setFrame(view: storyPreviewView, frame: CGRect(origin: CGPoint(x: 0.0, y: self.dismissOffset), size: storyPreviewSize))
            }
            
            let enhanceValue = self.mediaEditor?.getToolValue(.enhance) as? Float ?? 0.0
            let toolValueSize = self.toolValue.update(
                transition: transition,
                component: AnyComponent(
                    ToolValueComponent(
                        title: environment.strings.Story_Editor_Tool_Enhance,
                        value: "\(Int(abs(enhanceValue) * 100.0))"
                    )
                ),
                environment: {},
                forceUpdate: false,
                containerSize: CGSize(width: previewSize.width, height: 120.0)
            )
            if let toolValueView = self.toolValue.view {
                if toolValueView.superview == nil {
                    toolValueView.alpha = 0.0
                    toolValueView.isUserInteractionEnabled = false
                    self.previewContainerView.addSubview(toolValueView)
                }
                transition.setFrame(view: toolValueView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((previewSize.width - toolValueSize.width) / 2.0), y: 88.0), size: toolValueSize))
                transition.setAlpha(view: toolValueView, alpha: self.isEnhancing ? 1.0 : 0.0)
            }
            
            transition.setFrame(view: self.backgroundDimView, frame: CGRect(origin: .zero, size: layout.size))
            transition.setAlpha(view: self.backgroundDimView, alpha: self.isDismissing && !self.isDismissBySwipeSuppressed ? 0.0 : 1.0)
            
            var bottomInputOffset: CGFloat = 0.0
            if inputHeight > 0.0 {
                if self.stickerScreen == nil {
                    if self.entitiesView.selectedEntityView != nil || self.isDisplayingTool {
                        bottomInputOffset = inputHeight / 2.0
                    } else {
                        bottomInputOffset = 0.0
                    }
                }
            }
            
            transition.setPosition(view: self.containerView, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0))
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: .zero, size: layout.size))
            
            let previewFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - previewSize.width) / 2.0), y: topInset - bottomInputOffset + self.dismissOffset), size: previewSize)
            transition.setFrame(view: self.previewContainerView, frame: previewFrame)
            let entitiesViewScale = previewSize.width / storyDimensions.width
            self.entitiesContainerView.transform = CGAffineTransformMakeScale(entitiesViewScale, entitiesViewScale)
            self.entitiesContainerView.frame = CGRect(origin: .zero, size: previewFrame.size)
            transition.setFrame(view: self.gradientView, frame: CGRect(origin: .zero, size: previewFrame.size))
            transition.setFrame(view: self.drawingView, frame: CGRect(origin: .zero, size: self.entitiesView.bounds.size))
                        
            transition.setFrame(view: self.selectionContainerView, frame: CGRect(origin: .zero, size: previewFrame.size))
            
            self.interaction?.containerLayoutUpdated(layout: layout, transition: transition)
            
            var layout = layout
            layout.intrinsicInsets.top = topInset
            controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
            
            if isFirstTime {
                self.animateIn()
            }
        }
    }
    
    fileprivate var node: Node {
        return self.displayNode as! Node
    }
    
    public enum PIPPosition {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
        
        func getPosition(_ size: CGSize) -> CGPoint {
            let topOffset = CGPoint(x: 267.0, y: 438.0)
            let bottomOffset = CGPoint(x: 267.0, y: 438.0)
            switch self {
            case .topLeft:
                return CGPoint(x: topOffset.x, y: topOffset.y)
            case .topRight:
                return CGPoint(x: size.width - topOffset.x, y: topOffset.y)
            case .bottomLeft:
                return CGPoint(x: bottomOffset.x, y: size.height - bottomOffset.y)
            case .bottomRight:
                return CGPoint(x: size.width - bottomOffset.x, y: size.height - bottomOffset.y)
            }
        }
    }
    
    public enum Subject {
        case image(UIImage, PixelDimensions, UIImage?, PIPPosition)
        case video(String, UIImage?, Bool, String?, UIImage?, PixelDimensions, Double, [(Bool, Double)], PIPPosition)
        case asset(PHAsset)
        case draft(MediaEditorDraft, Int64?)
        
        var dimensions: PixelDimensions {
            switch self {
            case let .image(_, dimensions, _, _), let .video(_, _, _, _, _, dimensions, _, _, _):
                return dimensions
            case let .asset(asset):
                return PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
            case let .draft(draft, _):
                return draft.dimensions
            }
        }
        
        var editorSubject: MediaEditor.Subject {
            switch self {
            case let .image(image, dimensions, _, _):
                return .image(image, dimensions)
            case let .video(videoPath, transitionImage, mirror, additionalVideoPath, _, dimensions, duration, _, _):
                return .video(videoPath, transitionImage, mirror, additionalVideoPath, dimensions, duration)
            case let .asset(asset):
                return .asset(asset)
            case let .draft(draft, _):
                return .draft(draft)
            }
        }
        
        var mediaContent: DrawingMediaEntity.Content {
            switch self {
            case let .image(image, dimensions, _, _):
                return .image(image, dimensions)
            case let .video(videoPath, _, _, _, _, dimensions, _, _, _):
                return .video(videoPath, dimensions)
            case let .asset(asset):
                return .asset(asset)
            case let .draft(draft, _):
                return .image(draft.thumbnail, draft.dimensions)
            }
        }
        
        var isPhoto: Bool {
            return !self.isVideo
        }
        
        var isVideo: Bool {
            switch self {
            case .image:
                return false
            case .video:
                return true
            case let .asset(asset):
                return asset.mediaType == .video
            case let .draft(draft, _):
                return draft.isVideo
            }
        }
    }
    
    public enum Result {
        public enum VideoResult {
            case imageFile(path: String)
            case videoFile(path: String)
            case asset(localIdentifier: String)
        }
        case image(image: UIImage, dimensions: PixelDimensions)
        case video(video: VideoResult, coverImage: UIImage?, values: MediaEditorValues, duration: Double, dimensions: PixelDimensions)
    }
    
    fileprivate let context: AccountContext
    fileprivate let subject: Signal<Subject?, NoError>
    fileprivate let isEditingStory: Bool
    
    fileprivate let initialCaption: NSAttributedString?
    fileprivate let initialPrivacy: EngineStoryPrivacy?
    fileprivate let initialMediaAreas: [MediaArea]?
    fileprivate let initialVideoPosition: Double?
    
    fileprivate let transitionIn: TransitionIn?
    fileprivate let transitionOut: (Bool, Bool?) -> TransitionOut?
        
    public var cancelled: (Bool) -> Void = { _ in }
    public var completion: (Int64, MediaEditorScreen.Result?, [MediaArea], NSAttributedString, MediaEditorResultPrivacy, [TelegramMediaFile], @escaping (@escaping () -> Void) -> Void) -> Void = { _, _, _, _, _, _, _ in }
    public var dismissed: () -> Void = { }
    public var willDismiss: () -> Void = { }
    
    private var closeFriends = Promise<[EnginePeer]>()
    private let storiesBlockedPeers: BlockedPeersContext
    
    private let hapticFeedback = HapticFeedback()
    
    public init(
        context: AccountContext,
        subject: Signal<Subject?, NoError>,
        isEditing: Bool,
        initialCaption: NSAttributedString? = nil,
        initialPrivacy: EngineStoryPrivacy? = nil,
        initialMediaAreas: [MediaArea]? = nil,
        initialVideoPosition: Double? = nil,
        transitionIn: TransitionIn?,
        transitionOut: @escaping (Bool, Bool?) -> TransitionOut?,
        completion: @escaping (Int64, MediaEditorScreen.Result?, [MediaArea], NSAttributedString, MediaEditorResultPrivacy, [TelegramMediaFile], @escaping (@escaping () -> Void) -> Void) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.isEditingStory = isEditing
        self.initialCaption = initialCaption
        self.initialPrivacy = initialPrivacy
        self.initialMediaAreas = initialMediaAreas
        self.initialVideoPosition = initialVideoPosition
        self.transitionIn = transitionIn
        self.transitionOut = transitionOut
        self.completion = completion
        
        self.storiesBlockedPeers = BlockedPeersContext(account: context.account, subject: .stories)
        
        if let transitionIn, case .camera = transitionIn {
            self.isSavingAvailable = true
        }
        
        super.init(navigationBarPresentationData: nil)
                
        self.automaticallyControlPresentationContextLayout = false
        
        self.navigationPresentation = .flatModal
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBar.statusBarStyle = .White
        
        if isEditing {
            if let initialPrivacy {
                self.state.privacy = MediaEditorResultPrivacy(
                    privacy: initialPrivacy,
                    timeout: 86400,
                    isForwardingDisabled: false,
                    pin: false
                )
            }
        } else {
            let _ = combineLatest(
                queue: Queue.mainQueue(),
                mediaEditorStoredState(engine: self.context.engine),
                self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
            ).start(next: { [weak self] state, peer in
                if let self, var privacy = state?.privacy {
                    if case let .user(user) = peer, !user.isPremium && privacy.timeout != 86400 {
                        privacy = MediaEditorResultPrivacy(privacy: privacy.privacy, timeout: 86400, isForwardingDisabled: privacy.isForwardingDisabled, pin: privacy.pin)
                    }
                    self.state.privacy = privacy
                }
            })
        }
        
        updateStorySources(engine: self.context.engine)
        updateStoryDrafts(engine: self.context.engine)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.exportDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
        
        let dropInteraction = UIDropInteraction(delegate: self)
        self.displayNode.view.addInteraction(dropInteraction)
        
        Queue.mainQueue().after(1.0) {
            self.closeFriends.set(self.context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.CloseFriends()))
        }
    }
            
    func openPrivacySettings(_ privacy: MediaEditorResultPrivacy? = nil, completion: @escaping () -> Void = {}) {
        self.node.mediaEditor?.stop()
        
        self.hapticFeedback.impact(.light)
    
        let privacy = privacy ?? self.state.privacy
        
        let text = self.getCaption().string
        let mentions = generateTextEntities(text, enabledTypes: [.mention], currentEntities: []).map { (text as NSString).substring(with: NSRange(location: $0.range.lowerBound + 1, length: $0.range.upperBound - $0.range.lowerBound - 1)) }
                
        let stateContext = ShareWithPeersScreen.StateContext(
            context: self.context,
            subject: .stories(editing: false),
            editing: false,
            initialPeerIds: Set(privacy.privacy.additionallyIncludePeers),
            closeFriends: self.closeFriends.get(),
            blockedPeersContext: self.storiesBlockedPeers
        )
        let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let self else {
                return
            }
            let initialPrivacy = privacy.privacy
            let timeout = privacy.timeout
            
            let controller = ShareWithPeersScreen(
                context: self.context,
                initialPrivacy: initialPrivacy,
                allowScreenshots: !privacy.isForwardingDisabled,
                pin: privacy.pin,
                timeout: privacy.timeout,
                mentions: mentions,
                stateContext: stateContext,
                completion: { [weak self] privacy, allowScreenshots, pin, _, completed in
                    guard let self else {
                        return
                    }
                    self.state.privacy = MediaEditorResultPrivacy(privacy: privacy, timeout: timeout, isForwardingDisabled: !allowScreenshots, pin: pin)
                    if completed {
                        completion()
                    }
                },
                editCategory: { [weak self] privacy, allowScreenshots, pin in
                    guard let self else {
                        return
                    }
                    self.openEditCategory(privacy: privacy, isForwardingDisabled: !allowScreenshots, pin: pin, blockedPeers: false, completion: { [weak self] privacy in
                        guard let self else {
                            return
                        }
                        self.openPrivacySettings(MediaEditorResultPrivacy(
                            privacy: privacy,
                            timeout: timeout,
                            isForwardingDisabled: !allowScreenshots,
                            pin: pin
                        ), completion: completion)
                    })
                },
                editBlockedPeers: { [weak self] privacy, allowScreenshots, pin in
                    guard let self else {
                        return
                    }
                    self.openEditCategory(privacy: privacy, isForwardingDisabled: !allowScreenshots, pin: pin, blockedPeers: true, completion: { [weak self] privacy in
                        guard let self else {
                            return
                        }
                        self.openPrivacySettings(MediaEditorResultPrivacy(
                            privacy: privacy,
                            timeout: timeout,
                            isForwardingDisabled: !allowScreenshots,
                            pin: pin
                        ), completion: completion)
                    })
                }
            )
            controller.customModalStyleOverlayTransitionFactorUpdated = { [weak self, weak controller] transition in
                if let self, let controller {
                    let transitionFactor = controller.modalStyleOverlayTransitionFactor
                    self.node.updateModalTransitionFactor(transitionFactor, transition: transition)
                }
            }
            controller.dismissed = {
                self.node.mediaEditor?.play()
            }
            self.push(controller)
        })
    }
    
    private func openEditCategory(privacy: EngineStoryPrivacy, isForwardingDisabled: Bool, pin: Bool, blockedPeers: Bool, completion: @escaping (EngineStoryPrivacy) -> Void) {
        let subject: ShareWithPeersScreen.StateContext.Subject
        if blockedPeers {
            subject = .chats(blocked: true)
        } else if privacy.base == .nobody {
            subject = .chats(blocked: false)
        } else {
            subject = .contacts(base: privacy.base)
        }
        let stateContext = ShareWithPeersScreen.StateContext(
            context: self.context,
            subject: subject,
            editing: false,
            initialPeerIds: Set(privacy.additionallyIncludePeers),
            blockedPeersContext: self.storiesBlockedPeers
        )
        let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let self else {
                return
            }
            let controller = ShareWithPeersScreen(
                context: self.context,
                initialPrivacy: privacy,
                allowScreenshots: !isForwardingDisabled,
                pin: pin,
                stateContext: stateContext,
                completion: { [weak self] result, isForwardingDisabled, pin, peers, completed in
                    guard let self, completed else {
                        return
                    }
                    if blockedPeers {
                        let _ = self.storiesBlockedPeers.updatePeerIds(result.additionallyIncludePeers).start()
                        completion(privacy)
                    } else if case .closeFriends = privacy.base {
                        let _ = self.context.engine.privacy.updateCloseFriends(peerIds: result.additionallyIncludePeers).start()
                        self.closeFriends.set(.single(peers))
                        completion(EngineStoryPrivacy(base: .closeFriends, additionallyIncludePeers: []))
                    } else {
                        completion(result)
                    }
                },
                editCategory: { _, _, _ in },
                editBlockedPeers: { _, _, _ in }
            )
            controller.customModalStyleOverlayTransitionFactorUpdated = { [weak self, weak controller] transition in
                if let self, let controller {
                    let transitionFactor = controller.modalStyleOverlayTransitionFactor
                    self.node.updateModalTransitionFactor(transitionFactor, transition: transition)
                }
            }
            controller.dismissed = {
                self.node.mediaEditor?.play()
            }
            self.push(controller)
        })
    }
    
    func presentTimeoutSetup(sourceView: UIView, gesture: ContextGesture?, hasPremium: Bool) {
        self.hapticFeedback.impact(.light)
        
        var items: [ContextMenuItem] = []

        let updateTimeout: (Int?) -> Void = { [weak self] timeout in
            guard let self else {
                return
            }
            self.state.privacy = MediaEditorResultPrivacy(privacy: self.state.privacy.privacy, timeout: timeout ?? 86400, isForwardingDisabled: self.state.privacy.isForwardingDisabled, pin: self.state.privacy.pin)
        }
                
        let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkPresentationTheme)
        let title = presentationData.strings.Story_Editor_ExpirationText
        let currentValue = self.state.privacy.timeout
        let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil
        
        items.append(.action(ContextMenuActionItem(text: title, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction)))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Story_Editor_ExpirationValue(6), icon: { theme in
            if !hasPremium {
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/TextLockIcon"), color: theme.contextMenu.secondaryColor)
            } else {
                return currentValue == 3600 * 6 ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }
        }, action: { [weak self] _, a in
            a(.default)
            
            if hasPremium {
                updateTimeout(3600 * 6)
            } else {
                self?.presentTimeoutPremiumSuggestion()
            }
        })))
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Story_Editor_ExpirationValue(12), icon: { theme in
            if !hasPremium {
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/TextLockIcon"), color: theme.contextMenu.secondaryColor)
            } else {
                return currentValue == 3600 * 12 ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }
        }, action: { [weak self] _, a in
            a(.default)
            
            if hasPremium {
                updateTimeout(3600 * 12)
            } else {
                self?.presentTimeoutPremiumSuggestion()
            }
        })))
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Story_Editor_ExpirationValue(24), icon: { theme in
            return currentValue == 86400 ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
        }, action: { _, a in
            a(.default)
            
            updateTimeout(86400)
        })))
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Story_Editor_ExpirationValue(48), icon: { theme in
            if !hasPremium {
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/TextLockIcon"), color: theme.contextMenu.secondaryColor)
            } else {
                return currentValue == 86400 * 2 ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }
        }, action: { [weak self] _, a in
            a(.default)
            
            if hasPremium {
                updateTimeout(86400 * 2)
            } else {
                self?.presentTimeoutPremiumSuggestion()
            }
        })))
        
        let contextController = ContextController(account: self.context.account, presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: self, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.present(contextController, in: .window(.root))
    }
    
    fileprivate func presentTimeoutPremiumSuggestion() {
        self.dismissAllTooltips()
        
        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let text = presentationData.strings.Story_Editor_TooltipPremiumExpiration
                
        let controller = UndoOverlayController(presentationData: presentationData, content: .autoDelete(isOn: true, title: nil, text: text, customUndoText: nil), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { [weak self] action in
            if case .info = action, let self {
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .storiesExpirationDurations, forceDark: true, dismissed: nil)
                self.push(controller)
            }
            return false }
        )
        self.present(controller, in: .current)
    }
    
    fileprivate func presentCaptionLimitPremiumSuggestion(isPremium: Bool) {
        self.dismissAllTooltips()
        
        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let title = presentationData.strings.Story_Editor_TooltipPremiumCaptionLimitTitle
        let text =  presentationData.strings.Story_Editor_TooltipPremiumCaptionLimitText
                
        let controller = UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_read", scale: 0.25, colors: [:], title: title, text: text, customUndoText: nil, timeout: nil), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { [weak self] action in
            if case .info = action, let self {
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .stories, forceDark: true, dismissed: {
                    
                })
                self.push(controller)
            }
            return false }
        )
        self.present(controller, in: .current)
    }
    
    fileprivate func presentCaptionEntitiesPremiumSuggestion() {
        self.dismissAllTooltips()
        
        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let text = presentationData.strings.Story_Editor_TooltipPremiumCaptionEntities
                
        let controller = UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: text), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { [weak self] action in
            if case .info = action, let self {
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .storiesFormatting, forceDark: true, dismissed: nil)
                self.push(controller)
            }
            return false }
        )
        self.present(controller, in: .current)
    }
    
    func isEligibleForDraft() -> Bool {
        if self.isEditingStory {
            return false
        }
        guard let mediaEditor = self.node.mediaEditor else {
            return false
        }
        let entities = self.node.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
        let codableEntities = DrawingEntitiesView.encodeEntities(entities, entitiesView: self.node.entitiesView)
        mediaEditor.setDrawingAndEntities(data: nil, image: mediaEditor.values.drawing, entities: codableEntities)
        
        let caption = self.getCaption()
        
        if let subject = self.node.subject, case .asset = subject, self.node.mediaEditor?.values.hasChanges == false && caption.string.isEmpty {
            return false
        }
        return true
    }
    
    func maybePresentDiscardAlert() {
        self.hapticFeedback.impact(.light)
        if !self.isEligibleForDraft() {
            self.requestDismiss(saveDraft: false, animated: true)
            return
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let title: String
        let save: String
        if case .draft = self.node.subject {
            title = presentationData.strings.Story_Editor_DraftDiscardDraft
            save = presentationData.strings.Story_Editor_DraftKeepDraft
        } else {
            title = presentationData.strings.Story_Editor_DraftDiscardMedia
            save = presentationData.strings.Story_Editor_DraftKeepMedia
        }
        let theme = defaultDarkPresentationTheme
        let controller = textAlertController(
            context: self.context,
            forceTheme: theme,
            title: title,
            text: presentationData.strings.Story_Editor_DraftDiscaedText,
            actions: [
                TextAlertAction(type: .destructiveAction, title: presentationData.strings.Story_Editor_DraftDiscard, action: { [weak self] in
                    if let self {
                        self.requestDismiss(saveDraft: false, animated: true)
                    }
                }),
                TextAlertAction(type: .genericAction, title: save, action: { [weak self] in
                    if let self {
                        self.requestDismiss(saveDraft: true, animated: true)
                    }
                }),
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                    
                })
            ],
            actionLayout: .vertical
        )
        self.present(controller, in: .window(.root))
    }
    
    func requestDismiss(saveDraft: Bool, animated: Bool) {
        self.dismissAllTooltips()
        
        var showDraftTooltip = saveDraft
        if let subject = self.node.subject, case .draft = subject {
            showDraftTooltip = false
        }
        if saveDraft {
            self.saveDraft(id: nil)
        } else {
            if case let .draft(draft, id) = self.node.subject, id == nil {
                removeStoryDraft(engine: self.context.engine, path: draft.path, delete: true)
            }
        }
        
        if let mediaEditor = self.node.mediaEditor {
            mediaEditor.invalidate()
        }
        self.node.entitiesView.invalidate()
        
        self.cancelled(showDraftTooltip)
        
        self.willDismiss()
        
        self.node.animateOut(finished: false, saveDraft: saveDraft, completion: { [weak self] in
            self?.dismiss()
            self?.dismissed()
        })
    }
    
    private func getCaption() -> NSAttributedString {
        return (self.node.componentHost.view as? MediaEditorScreenComponent.View)?.getInputText() ?? NSAttributedString()
    }
    
    private func saveDraft(id: Int64?) {
        guard let subject = self.node.subject, let mediaEditor = self.node.mediaEditor else {
            return
        }
        try? FileManager.default.createDirectory(atPath: draftPath(engine: self.context.engine), withIntermediateDirectories: true)
        
        let values = mediaEditor.values
        let privacy = self.state.privacy
        let caption = self.getCaption()
        let duration = mediaEditor.duration ?? 0.0
        
        let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        var timestamp: Int32
        var location: CLLocationCoordinate2D?
        let expiresOn: Int32
        if case let .draft(draft, _) = subject {
            timestamp = draft.timestamp
            location = draft.location
            if let _ = id {
                expiresOn = draft.expiresOn ?? currentTimestamp + 3600 * 24 * 7
            } else {
                expiresOn = currentTimestamp + 3600 * 24 * 7
            }
        } else {
            timestamp = currentTimestamp
            if case let .asset(asset) = subject {
                location = asset.location?.coordinate
            }
            if let _ = id {
                expiresOn = currentTimestamp + Int32(self.state.privacy.timeout)
            } else {
                expiresOn = currentTimestamp + 3600 * 24 * 7
            }
        }
        
        if let resultImage = mediaEditor.resultImage {
            mediaEditor.seek(0.0, andPlay: false)
            makeEditorImageComposition(context: self.node.ciContext, account: self.context.account, inputImage: resultImage, dimensions: storyDimensions, values: values, time: .zero, textScale: 2.0, completion: { resultImage in
                guard let resultImage else {
                    return
                }
                let fittedSize = resultImage.size.aspectFitted(CGSize(width: 128.0, height: 128.0))
                
                let context = self.context
                let saveImageDraft: (UIImage, PixelDimensions) -> Void = { image, dimensions in
                    if let thumbnailImage = generateScaledImage(image: resultImage, size: fittedSize) {
                        let path = "\(Int64.random(in: .min ... .max)).jpg"
                        if let data = image.jpegData(compressionQuality: 0.87) {
                            let draft = MediaEditorDraft(path: path, isVideo: false, thumbnail: thumbnailImage, dimensions: dimensions, duration: nil, values: values, caption: caption, privacy: privacy, timestamp: timestamp, location: location, expiresOn: expiresOn)
                            try? data.write(to: URL(fileURLWithPath: draft.fullPath(engine: context.engine)))
                            if let id {
                                saveStorySource(engine: context.engine, item: draft, peerId: context.account.peerId, id: id)
                            } else {
                                addStoryDraft(engine: context.engine, item: draft)
                            }
                        }
                    }
                }
                
                let saveVideoDraft: (String, PixelDimensions, Double) -> Void = { videoPath, dimensions, duration in
                    if let thumbnailImage = generateScaledImage(image: resultImage, size: fittedSize) {
                        let path = "\(Int64.random(in: .min ... .max)).mp4"
                        let draft = MediaEditorDraft(path: path, isVideo: true, thumbnail: thumbnailImage, dimensions: dimensions, duration: duration, values: values, caption: caption, privacy: privacy, timestamp: timestamp, location: location, expiresOn: expiresOn)
                        try? FileManager.default.copyItem(atPath: videoPath, toPath: draft.fullPath(engine: context.engine))
                        if let id {
                            saveStorySource(engine: context.engine, item: draft, peerId: context.account.peerId, id: id)
                        } else {
                            addStoryDraft(engine: context.engine, item: draft)
                        }
                    }
                }
                
                switch subject {
                case let .image(image, dimensions, _, _):
                    saveImageDraft(image, dimensions)
                case let .video(path, _, _, _, _, dimensions, _, _, _):
                    saveVideoDraft(path, dimensions, duration)
                case let .asset(asset):
                    if asset.mediaType == .video {
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let urlAsset = avAsset as? AVURLAsset {
                                saveVideoDraft(urlAsset.url.relativePath, PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight)), duration)
                            }
                        }
                    } else {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                            if let image {
                                saveImageDraft(image, PixelDimensions(image.size))
                            }
                        }
                    }
                case let .draft(draft, _):
                    if draft.isVideo {
                        saveVideoDraft(draft.fullPath(engine: context.engine), draft.dimensions, draft.duration ?? 0.0)
                    } else if let image = UIImage(contentsOfFile: draft.fullPath(engine: context.engine)) {
                        saveImageDraft(image, draft.dimensions)
                    }
                    removeStoryDraft(engine: self.context.engine, path: draft.path, delete: false)
                }
            })
        }
    }
    
    fileprivate func checkCaptionLimit() -> Bool {
        let caption = self.getCaption()
        if caption.length > self.context.userLimits.maxStoryCaptionLength {
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                if let self {
                    self.presentCaptionLimitPremiumSuggestion(isPremium: peer?.isPremium ?? false)
                }
            })
            return false
        }
        return true
    }
        
    private var didComplete = false
    func requestCompletion(animated: Bool) {
        guard let mediaEditor = self.node.mediaEditor, let subject = self.node.subject, !self.didComplete else {
            return
        }
        self.didComplete = true
        
        self.dismissAllTooltips()
        
        mediaEditor.stop()
        mediaEditor.invalidate()
        self.node.entitiesView.invalidate()
        
        let context = self.context
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.updateRootContainerTransitionOffset(0.0, transition: .immediate)
        }
        
        let entities = self.node.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
        let codableEntities = DrawingEntitiesView.encodeEntities(entities, entitiesView: self.node.entitiesView)
        mediaEditor.setDrawingAndEntities(data: nil, image: mediaEditor.values.drawing, entities: codableEntities)
        
        var caption = self.getCaption()
        caption = convertMarkdownToAttributes(caption)
        
        let randomId: Int64
        if case let .draft(_, id) = subject, let id {
            randomId = id
        } else {
            randomId = Int64.random(in: .min ... .max)
        }
        
        var mediaAreas: [MediaArea] = []
        if case .draft = subject {
        } else {
            mediaAreas = self.initialMediaAreas ?? []
        }
        
        var stickers: [TelegramMediaFile] = []
        for entity in codableEntities {
            switch entity {
            case let .sticker(stickerEntity):
                if case let .file(file) = stickerEntity.content {
                    stickers.append(file)
                }
            case let .text(textEntity):
                if let subEntities = textEntity.renderSubEntities {
                    for entity in subEntities {
                        if let stickerEntity = entity as? DrawingStickerEntity, case let .file(file) = stickerEntity.content {
                            stickers.append(file)
                        }
                    }
                }
            default:
                break
            }
            if let mediaArea = entity.mediaArea {
                mediaAreas.append(mediaArea)
            }
        }
        
        if self.isEditingStory && !self.node.hasAnyChanges {
            self.completion(randomId, nil, [], caption, self.state.privacy, stickers, { [weak self] finished in
                self?.node.animateOut(finished: true, saveDraft: false, completion: { [weak self] in
                    self?.dismiss()
                    Queue.mainQueue().justDispatch {
                        finished()
                    }
                })
            })
            
            return
        }
        
        if !self.isEditingStory {
            let privacy = self.state.privacy
            let _ = updateMediaEditorStoredStateInteractively(engine: self.context.engine, { current in
                if let current {
                    return current.withUpdatedPrivacy(privacy)
                } else {
                    return MediaEditorStoredState(privacy: privacy, textSettings: nil)
                }
            }).start()
        }
        
        if mediaEditor.resultIsVideo {
            self.saveDraft(id: randomId)
            
            var firstFrame: Signal<(UIImage?, UIImage?), NoError>
            let firstFrameTime = CMTime(seconds: mediaEditor.values.videoTrimRange?.lowerBound ?? 0.0, preferredTimescale: CMTimeScale(60))

            let videoResult: Result.VideoResult
            var videoIsMirrored = false
            let duration: Double
            switch subject {
            case let .image(image, _, _, _):
                let tempImagePath = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).jpg"
                if let data = image.jpegData(compressionQuality: 0.85) {
                    try? data.write(to: URL(fileURLWithPath: tempImagePath))
                }
                videoResult = .imageFile(path: tempImagePath)
                duration = 5.0
                
                firstFrame = .single((image, nil))
            case let .video(path, _, mirror, additionalPath, _, _, durationValue, _, _):
                videoIsMirrored = mirror
                videoResult = .videoFile(path: path)
                if let videoTrimRange = mediaEditor.values.videoTrimRange {
                    duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
                } else {
                    duration = durationValue
                }
                                
                firstFrame = Signal<(UIImage?, UIImage?), NoError> { subscriber in
                    let avAsset = AVURLAsset(url: URL(fileURLWithPath: path))
                    let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
                    avAssetGenerator.appliesPreferredTrackTransform = true
                    avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { _, cgImage, _, _, _ in
                        if let cgImage {
                            if let additionalPath {
                                let avAsset = AVURLAsset(url: URL(fileURLWithPath: additionalPath))
                                let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
                                avAssetGenerator.appliesPreferredTrackTransform = true
                                avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { _, additionalCGImage, _, _, _ in
                                    if let additionalCGImage {
                                        subscriber.putNext((UIImage(cgImage: cgImage), UIImage(cgImage: additionalCGImage)))
                                        subscriber.putCompletion()
                                    } else {
                                        subscriber.putNext((UIImage(cgImage: cgImage), nil))
                                        subscriber.putCompletion()
                                    }
                                })
                            } else {
                                subscriber.putNext((UIImage(cgImage: cgImage), nil))
                                subscriber.putCompletion()
                            }
                        }
                    })
                    return ActionDisposable {
                        avAssetGenerator.cancelAllCGImageGeneration()
                    }
                }
            case let .asset(asset):
                videoResult = .asset(localIdentifier: asset.localIdentifier)
                if asset.mediaType == .video {
                    if let videoTrimRange = mediaEditor.values.videoTrimRange {
                        duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
                    } else {
                        duration = min(asset.duration, storyMaxVideoDuration)
                    }
                } else {
                    duration = 5.0
                }
                firstFrame = Signal<(UIImage?, UIImage?), NoError> { subscriber in
                    if asset.mediaType == .video {
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let avAsset {
                                let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
                                avAssetGenerator.appliesPreferredTrackTransform = true
                                avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { _, cgImage, _, _, _ in
                                    if let cgImage {
                                        subscriber.putNext((UIImage(cgImage: cgImage), nil))
                                        subscriber.putCompletion()
                                    }
                                })
                            }
                        }
                    } else {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                            if let image {
                                subscriber.putNext((image, nil))
                                subscriber.putCompletion()
                            }
                        }
                    }
                    return EmptyDisposable
                }
            case let .draft(draft, _):
                let draftPath = draft.fullPath(engine: context.engine)
                if draft.isVideo {
                    videoResult = .videoFile(path: draftPath)
                    if let videoTrimRange = mediaEditor.values.videoTrimRange {
                        duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
                    } else {
                        duration = min(draft.duration ?? 5.0, storyMaxVideoDuration)
                    }
                    firstFrame = Signal<(UIImage?, UIImage?), NoError> { subscriber in
                        let avAsset = AVURLAsset(url: URL(fileURLWithPath: draftPath))
                        let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
                        avAssetGenerator.appliesPreferredTrackTransform = true
                        avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { _, cgImage, _, _, _ in
                            if let cgImage {
                                subscriber.putNext((UIImage(cgImage: cgImage), nil))
                                subscriber.putCompletion()
                            }
                        })
                        return ActionDisposable {
                            avAssetGenerator.cancelAllCGImageGeneration()
                        }
                    }
                } else {
                    videoResult = .imageFile(path: draftPath)
                    duration = 5.0
                    
                    if let image = UIImage(contentsOfFile: draftPath) {
                        firstFrame = .single((image, nil))
                    } else {
                        firstFrame = .single((UIImage(), nil))
                    }
                }
            }
            
            let _ = (firstFrame
            |> deliverOnMainQueue).start(next: { [weak self] image, additionalImage in
                if let self {
                    var currentImage = mediaEditor.resultImage
                    if let image {
                        mediaEditor.replaceSource(image, additionalImage: additionalImage, time: firstFrameTime)
                        if let updatedImage = mediaEditor.getResultImage(mirror: videoIsMirrored) {
                            currentImage = updatedImage
                        }
                    }
                    
                    var inputImage: UIImage
                    if let currentImage {
                        inputImage = currentImage
                    } else if let image {
                        inputImage = image
                    } else {
                        inputImage = UIImage()
                    }

                    makeEditorImageComposition(context: self.node.ciContext, account: self.context.account, inputImage: inputImage, dimensions: storyDimensions, values: mediaEditor.values, time: firstFrameTime, textScale: 2.0, completion: { [weak self] coverImage in
                        if let self {
                            Logger.shared.log("MediaEditor", "Completed with video \(videoResult)")
                            self.completion(randomId, .video(video: videoResult, coverImage: coverImage, values: mediaEditor.values, duration: duration, dimensions: mediaEditor.values.resultDimensions), mediaAreas, caption, self.state.privacy, stickers, { [weak self] finished in
                                self?.node.animateOut(finished: true, saveDraft: false, completion: { [weak self] in
                                    self?.dismiss()
                                    Queue.mainQueue().justDispatch {
                                        finished()
                                    }
                                })
                            })
                        }
                    })
                }
            })
        
            if case let .draft(draft, id) = subject, id == nil {
                removeStoryDraft(engine: self.context.engine, path: draft.path, delete: false)
            }
        } else {
            if let image = mediaEditor.resultImage {
                self.saveDraft(id: randomId)
                
                makeEditorImageComposition(context: self.node.ciContext, account: self.context.account, inputImage: image, dimensions: storyDimensions, values: mediaEditor.values, time: .zero, textScale: 2.0, completion: { [weak self] resultImage in
                    if let self, let resultImage {
                        Logger.shared.log("MediaEditor", "Completed with image \(resultImage)")
                        self.completion(randomId, .image(image: resultImage, dimensions: PixelDimensions(resultImage.size)), mediaAreas, caption, self.state.privacy, stickers, { [weak self] finished in
                            self?.node.animateOut(finished: true, saveDraft: false, completion: { [weak self] in
                                self?.dismiss()
                                Queue.mainQueue().justDispatch {
                                    finished()
                                }
                            })
                        })
                        if case let .draft(draft, id) = subject, id == nil {
                            removeStoryDraft(engine: self.context.engine, path: draft.path, delete: true)
                        }
                    }
                })
            }
        }
    }
    
    private var videoExport: MediaEditorVideoExport?
    private var exportDisposable = MetaDisposable()
    
    fileprivate var isSavingAvailable = false
    private var previousSavedValues: MediaEditorValues?
    
    func requestSave() {
        let context = self.context
        DeviceAccess.authorizeAccess(to: .mediaLibrary(.save), presentationData: context.sharedContext.currentPresentationData.with { $0 }, present: { c, a in
            context.sharedContext.presentGlobalController(c, a)
        }, openSettings: context.sharedContext.applicationBindings.openSettings, { [weak self] authorized in
            if !authorized {
                return
            }
            self?.performSave()
        })
    }
    
    private func performSave() {
        guard let mediaEditor = self.node.mediaEditor, let subject = self.node.subject, self.isSavingAvailable else {
            return
        }
            
        let context = self.context
        
        let entities = self.node.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
        let codableEntities = DrawingEntitiesView.encodeEntities(entities, entitiesView: self.node.entitiesView)
        mediaEditor.setDrawingAndEntities(data: nil, image: mediaEditor.values.drawing, entities: codableEntities)
                
        self.hapticFeedback.impact(.light)
        
        self.previousSavedValues = mediaEditor.values
        self.isSavingAvailable = false
        self.requestLayout(transition: .animated(duration: 0.25, curve: .easeInOut))
        
        let tempVideoPath = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).mp4"
        let saveToPhotos: (String, Bool) -> Void = { path, isVideo in
            PHPhotoLibrary.shared().performChanges({
                if isVideo {
                    if let _ = try? FileManager.default.copyItem(atPath: path, toPath: tempVideoPath) {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: path))
                    }
                } else {
                    if let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: fileData, options: nil)
                    }
                }
            }, completionHandler: { _, error in
                if let error = error {
                    print("\(error)")
                }
                let _ = try? FileManager.default.removeItem(atPath: tempVideoPath)
            })
        }
        
        if mediaEditor.resultIsVideo {
            mediaEditor.stop()
            self.node.entitiesView.pause()
            
            let exportSubject: Signal<MediaEditorVideoExport.Subject, NoError>
            switch subject {
            case let .video(path, _, _, _, _, _, _, _, _):
                let asset = AVURLAsset(url: NSURL(fileURLWithPath: path) as URL)
                exportSubject = .single(.video(asset))
            case let .image(image, _, _, _):
                exportSubject = .single(.image(image))
            case let .asset(asset):
                exportSubject = Signal { subscriber in
                    if asset.mediaType == .video {
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let avAsset {
                                subscriber.putNext(.video(avAsset))
                                subscriber.putCompletion()
                            }
                        }
                    } else {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                            if let image {
                                subscriber.putNext(.image(image))
                                subscriber.putCompletion()
                            }
                        }
                    }
                    return EmptyDisposable
                }
            case let .draft(draft, _):
                if draft.isVideo {
                    let asset = AVURLAsset(url: NSURL(fileURLWithPath: draft.fullPath(engine: context.engine)) as URL)
                    exportSubject = .single(.video(asset))
                } else {
                    if let image = UIImage(contentsOfFile: draft.fullPath(engine: context.engine)) {
                        exportSubject = .single(.image(image))
                    } else {
                        fatalError()
                    }
                }
            }
            
            let _ = exportSubject.start(next: { [weak self] exportSubject in
                guard let self else {
                    return
                }
                var duration: Double = 0.0
                if case let .video(video) = exportSubject {
                    duration = video.duration.seconds
                }
                let configuration = recommendedVideoExportConfiguration(values: mediaEditor.values, duration: duration, forceFullHd: true, frameRate: 60.0)
                let outputPath = NSTemporaryDirectory() + "\(Int64.random(in: 0 ..< .max)).mp4"
                let videoExport = MediaEditorVideoExport(account: self.context.account, subject: exportSubject, configuration: configuration, outputPath: outputPath, textScale: 2.0)
                self.videoExport = videoExport
                
                videoExport.start()
                
                self.exportDisposable.set((videoExport.status
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let self {
                        switch status {
                        case .completed:
                            self.videoExport = nil
                            saveToPhotos(outputPath, true)
                            self.node.presentSaveTooltip()
                            
                            self.node.mediaEditor?.play()
                            self.node.entitiesView.play()
                        case let .progress(progress):
                            if self.videoExport != nil {
                                self.node.updateVideoExportProgress(progress)
                            }
                        case .failed:
                            self.videoExport = nil
                            self.node.mediaEditor?.play()
                            self.node.entitiesView.play()
                        case .unknown:
                            break
                        }
                    }
                }))
            })
        } else {
            if let image = mediaEditor.resultImage {
                Queue.concurrentDefaultQueue().async {
                    makeEditorImageComposition(context: self.node.ciContext, account: self.context.account, inputImage: image, dimensions: storyDimensions, values: mediaEditor.values, time: .zero, textScale: 2.0, completion: { resultImage in
                        if let data = resultImage?.jpegData(compressionQuality: 0.8) {
                            let outputPath = NSTemporaryDirectory() + "\(Int64.random(in: 0 ..< .max)).jpg"
                            try? data.write(to: URL(fileURLWithPath: outputPath))
                            Queue.mainQueue().async {
                                saveToPhotos(outputPath, false)
                            }
                        }
                    })
                }
                self.node.presentSaveTooltip()
            }
        }
    }
    
    fileprivate func cancelVideoExport() {
        if let videoExport = self.videoExport {
            self.previousSavedValues = nil
            
            videoExport.cancel()
            self.videoExport = nil
            self.exportDisposable.set(nil)
            
            self.node.mediaEditor?.play()
            self.node.entitiesView.play()
        }
    }
    
    public func updateEditProgress(_ progress: Float, cancel: @escaping () -> Void) {
        self.node.updateEditProgress(progress, cancel: cancel)
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            if let controller = controller as? SaveProgressScreen {
                controller.dismiss()
            }
            return true
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: Transition(transition))
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.hasItemsConforming(toTypeIdentifiers: [kUTTypeImage as String])
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        let operation: UIDropOperation
        operation = .copy
        return UIDropProposal(operation: operation)
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { [weak self] imageItems in
            guard let self else {
                return
            }
            let images = imageItems as! [UIImage]
            if images.count == 1, let image = images.first, max(image.size.width, image.size.height) > 1.0 {
                self.node.interaction?.insertEntity(DrawingStickerEntity(content: .image(image, .sticker)), scale: 2.5)
            }
        }
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
    }
}

final class DoneButtonContentComponent: CombinedComponent {
    let backgroundColor: UIColor
    let icon: UIImage
    let title: String?

    init(
        backgroundColor: UIColor,
        icon: UIImage,
        title: String?
    ) {
        self.backgroundColor = backgroundColor
        self.icon = icon
        self.title = title
    }

    static func ==(lhs: DoneButtonContentComponent, rhs: DoneButtonContentComponent) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }

    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let icon = Child(Image.self)
        let text = Child(Text.self)

        return { context in
            let icon = icon.update(
                component: Image(image: context.component.icon, tintColor: .white, size: CGSize(width: 10.0, height: 16.0)),
                availableSize: CGSize(width: 180.0, height: 100.0),
                transition: .immediate
            )
            
            let backgroundHeight: CGFloat = 33.0
            var backgroundSize = CGSize(width: backgroundHeight, height: backgroundHeight)
            
            let textSpacing: CGFloat = 8.0
            
            var title: _UpdatedChildComponent?
            var hideTitle = false
            if let titleText = context.component.title {
                title = text.update(
                    component: Text(
                        text: titleText,
                        font: Font.with(size: 16.0, design: .round, weight: .semibold),
                        color: .white
                    ),
                    availableSize: CGSize(width: 180.0, height: 100.0),
                    transition: .immediate
                )
                
                let updatedBackgroundWidth = backgroundSize.width + textSpacing + title!.size.width
                if updatedBackgroundWidth < 126.0 {
                    backgroundSize.width = updatedBackgroundWidth
                } else {
                    hideTitle = true
                }
            }

            let background = background.update(
                component: RoundedRectangle(color: context.component.backgroundColor, cornerRadius: backgroundHeight / 2.0),
                availableSize: backgroundSize,
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: backgroundSize.width / 2.0, y: backgroundSize.height / 2.0))
                .cornerRadius(min(backgroundSize.width, backgroundSize.height) / 2.0)
                .clipsToBounds(true)
            )
            
            if let title {
                context.add(title
                    .position(CGPoint(x: title.size.width / 2.0 + 15.0, y: backgroundHeight / 2.0))
                    .opacity(hideTitle ? 0.0 : 1.0)
                )
            }
            
            context.add(icon
                .position(CGPoint(x: background.size.width - 16.0, y: backgroundSize.height / 2.0))
            )

            return backgroundSize
        }
    }
}


private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    var keepInPlace: Bool {
        return true
    }

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: .top)
    }
}

private final class ToolValueComponent: Component {
    typealias EnvironmentType = Empty
    
    let title: String
    let value: String
    
    init(
        title: String,
        value: String
    ) {
        self.title = title
        self.value = value
    }
    
    static func ==(lhs: ToolValueComponent, rhs: ToolValueComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
        
    public final class View: UIView {
        private let title = ComponentView<Empty>()
        private let value = ComponentView<Empty>()
        
        private let hapticFeedback = HapticFeedback()
        
        private var component: ToolValueComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundColor = .clear
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ToolValueComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousValue = self.component?.value
            self.component = component
            self.state = state
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.title,
                    font: Font.light(34.0),
                    color: .white
                )),
                environment: {},
                containerSize: CGSize(width: 180.0, height: 44.0)
            )
            let titleFrame = CGRect(
                origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: 0.0),
                size: titleSize
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
                    titleView.layer.shadowRadius = 3.0
                    titleView.layer.shadowColor = UIColor.black.cgColor
                    titleView.layer.shadowOpacity = 0.35
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: .zero, size: titleFrame.size)
            }
            
            let valueSize = self.value.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.value,
                    font: Font.with(size: 90.0, weight: .thin, traits: .monospacedNumbers),
                    color: .white
                )),
                environment: {},
                containerSize: CGSize(width: 180.0, height: 44.0)
            )
            let valueFrame = CGRect(
                origin: CGPoint(x: floorToScreenPixels((availableSize.width - valueSize.width) / 2.0), y: 40.0),
                size: valueSize
            )
            if let valueView = self.value.view {
                if valueView.superview == nil {
                    valueView.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
                    valueView.layer.shadowRadius = 3.0
                    valueView.layer.shadowColor = UIColor.black.cgColor
                    valueView.layer.shadowOpacity = 0.35
                    self.addSubview(valueView)
                }
                transition.setPosition(view: valueView, position: valueFrame.center)
                valueView.bounds = CGRect(origin: .zero, size: valueFrame.size)
            }
            
            if let previousValue, component.value != previousValue, self.alpha > 0.0 {
                if component.value == "100" || component.value == "0" {
                    self.hapticFeedback.impact(.medium)
                } else {
                    self.hapticFeedback.impact(.click05)
                }
            }
           
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class BlurredGradientComponent: Component {
    public enum Position {
        case top
        case bottom
    }
    
    let position: Position
    let dark: Bool
    let tag: AnyObject?

    public init(
        position: Position,
        dark: Bool = false,
        tag: AnyObject?
    ) {
        self.position = position
        self.dark = dark
        self.tag = tag
    }
    
    public static func ==(lhs: BlurredGradientComponent, rhs: BlurredGradientComponent) -> Bool {
        if lhs.position != rhs.position {
            return false
        }
        if lhs.dark != rhs.dark {
            return false
        }
        return true
    }
    
    public final class View: BlurredBackgroundView, ComponentTaggedView {
        private var component: BlurredGradientComponent?
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private var gradientMask = UIImageView()
        private var gradientBackground = SimpleLayer()
        private var gradientForeground = SimpleGradientLayer()
        
        public func update(component: BlurredGradientComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            self.isUserInteractionEnabled = false
            
            self.updateColor(color: UIColor(rgb: 0x000000, alpha: component.position == .top ? 0.15 : 0.25), transition: transition.containedViewLayoutTransition)
           
            let gradientHeight: CGFloat = 100.0
            if self.mask == nil {
                self.mask = self.gradientMask
                self.gradientMask.image = generateGradientImage(
                    size: CGSize(width: 1.0, height: gradientHeight),
                    colors: [UIColor(rgb: 0xffffff, alpha: 1.0), UIColor(rgb: 0xffffff, alpha: 1.0), UIColor(rgb: 0xffffff, alpha: 0.0)],
                    locations: component.position == .top ? [0.0, 0.8, 1.0] : [1.0, 0.20, 0.0],
                    direction: .vertical
                )
                self.gradientMask.layer.addSublayer(self.gradientBackground)
                
                self.gradientBackground.backgroundColor = UIColor(rgb: 0xffffff).cgColor
                
                if component.dark {
                    self.gradientForeground.colors = [UIColor(rgb: 0x000000, alpha: 0.4).cgColor, UIColor(rgb: 0x000000, alpha: 0.4).cgColor, UIColor(rgb: 0x000000, alpha: 0.0).cgColor]
                    self.gradientForeground.locations = [0.0, 0.8, 1.0]
                } else {
                    self.gradientForeground.colors = [UIColor(rgb: 0x000000, alpha: 0.35).cgColor, UIColor(rgb: 0x000000, alpha: 0.0).cgColor]
                }
                self.gradientForeground.startPoint = CGPoint(x: 0.5, y: component.position == .top ? 0.0 : 1.0)
                self.gradientForeground.endPoint = CGPoint(x: 0.5, y: component.position == .top ? 1.0 : 0.0)
                
                self.layer.addSublayer(self.gradientForeground)
            }
            
            transition.setFrame(view: self.gradientMask, frame: CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: gradientHeight)))
            transition.setFrame(layer: self.gradientBackground, frame: CGRect(origin: CGPoint(x: 0.0, y: gradientHeight), size: availableSize))
            transition.setFrame(layer: self.gradientForeground, frame: CGRect(origin: .zero, size: availableSize))
            
            self.update(size: availableSize, transition: transition.containedViewLayoutTransition)
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(color: nil, enableBlur: true)
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

func draftPath(engine: TelegramEngine) -> String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/storyDrafts_\(engine.account.peerId.toInt64())"
}

func hasFirstResponder(_ view: UIView) -> Bool {
    if view.isFirstResponder {
        return true
    }
    for subview in view.subviews {
        if hasFirstResponder(subview) {
            return true
        }
    }
    return false
}
