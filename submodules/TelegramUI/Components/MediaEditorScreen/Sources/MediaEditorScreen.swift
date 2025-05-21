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
import Postbox
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
import LegacyMediaPickerUI
import ReactionSelectionNode
import VolumeSliderContextItem
import TelegramStringFormatting
import ForwardInfoPanelComponent
import ContextReferenceButtonComponent
import MediaScrubberComponent
import BlurredBackgroundComponent
import WebPBinding
import StickerResources
import StickerPeekUI
import StickerPackEditTitleController
import StickerPickerScreen
import UIKitRuntimeUtils
import ImageObjectSeparation
import SaveProgressScreen
import TelegramNotices

private let playbackButtonTag = GenericComponentViewTag()
private let muteButtonTag = GenericComponentViewTag()
private let saveButtonTag = GenericComponentViewTag()
private let switchCameraButtonTag = GenericComponentViewTag()
private let drawButtonTag = GenericComponentViewTag()
private let textButtonTag = GenericComponentViewTag()
private let stickerButtonTag = GenericComponentViewTag()
private let dayNightButtonTag = GenericComponentViewTag()
private let selectionButtonTag = GenericComponentViewTag()

final class MediaEditorScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    public final class ExternalState {
        public fileprivate(set) var derivedInputHeight: CGFloat = 0.0
        public fileprivate(set) var timelineHeight: CGFloat = 0.0
        
        public init() {
        }
    }
    
    enum DrawingScreenType: Equatable {
        case drawing
        case text
        case sticker
        case tools
        case cutout
        case cutoutErase
        case cutoutRestore
        case cover
    }
    
    let context: AccountContext
    let externalState: ExternalState
    let isDisplayingTool: DrawingScreenType?
    let isInteractingWithEntities: Bool
    let isSavingAvailable: Bool
    let isCollageTimelineOpen: Bool
    let hasAppeared: Bool
    let isDismissing: Bool
    let bottomSafeInset: CGFloat
    let mediaEditor: Signal<MediaEditor?, NoError>
    let privacy: MediaEditorResultPrivacy
    let selectedEntity: DrawingEntity?
    let entityViewForEntity: (DrawingEntity) -> DrawingEntityView?
    let openDrawing: (DrawingScreenType) -> Void
    let cutoutUndo: () -> Void
    
    init(
        context: AccountContext,
        externalState: ExternalState,
        isDisplayingTool: DrawingScreenType?,
        isInteractingWithEntities: Bool,
        isSavingAvailable: Bool,
        isCollageTimelineOpen: Bool,
        hasAppeared: Bool,
        isDismissing: Bool,
        bottomSafeInset: CGFloat,
        mediaEditor: Signal<MediaEditor?, NoError>,
        privacy: MediaEditorResultPrivacy,
        selectedEntity: DrawingEntity?,
        entityViewForEntity: @escaping (DrawingEntity) -> DrawingEntityView?,
        openDrawing: @escaping (DrawingScreenType) -> Void,
        cutoutUndo: @escaping () -> Void
    ) {
        self.context = context
        self.externalState = externalState
        self.isDisplayingTool = isDisplayingTool
        self.isInteractingWithEntities = isInteractingWithEntities
        self.isSavingAvailable = isSavingAvailable
        self.isCollageTimelineOpen = isCollageTimelineOpen
        self.hasAppeared = hasAppeared
        self.isDismissing = isDismissing
        self.bottomSafeInset = bottomSafeInset
        self.mediaEditor = mediaEditor
        self.privacy = privacy
        self.selectedEntity = selectedEntity
        self.entityViewForEntity = entityViewForEntity
        self.openDrawing = openDrawing
        self.cutoutUndo = cutoutUndo
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
        if lhs.isCollageTimelineOpen != rhs.isCollageTimelineOpen {
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
            case rotate
            case flip
            case done
            case cutout
            case undo
            case erase
            case restore
            case outline
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
                case .rotate:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Rotate"), color: .white)!
                case .flip:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Mirror"), color: .white)!
                case .cutout:
                    image = UIImage(bundleImageName: "Media Editor/Cutout")!.withRenderingMode(.alwaysTemplate)
                case .undo:
                    image = UIImage(bundleImageName: "Media Editor/CutoutUndo")!.withRenderingMode(.alwaysTemplate)
                case .erase:
                    image = UIImage(bundleImageName: "Media Editor/Erase")!.withRenderingMode(.alwaysTemplate)
                case .restore:
                    image = UIImage(bundleImageName: "Media Editor/Restore")!.withRenderingMode(.alwaysTemplate)
                case .outline:
                    image = UIImage(bundleImageName: "Media Editor/Outline")!.withRenderingMode(.alwaysTemplate)
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
                    if self.playerState != playerState {
                        self.playerState = playerState
                        self.updated()
                    }
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
        var playbackDidChange = false
        var dayNightDidChange = false
    }
    
    func makeState() -> State {
        return State(
            context: self.context,
            mediaEditor: self.mediaEditor
        )
    }
    
    public final class View: UIView {
        private let cancelButton = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
        private let drawButton = ComponentView<Empty>()
        private let textButton = ComponentView<Empty>()
        private let stickerButton = ComponentView<Empty>()
        private let toolsButton = ComponentView<Empty>()
        
        private let rotateButton = ComponentView<Empty>()
        private let flipButton = ComponentView<Empty>()
        
        private let cutoutButton = ComponentView<Empty>()
        private let undoButton = ComponentView<Empty>()
        private let eraseButton = ComponentView<Empty>()
        private let restoreButton = ComponentView<Empty>()
        private let outlineButton = ComponentView<Empty>()
        
        private let fadeView = UIButton()
        
        fileprivate let inputPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        private let inputPanelBackground = ComponentView<Empty>()
        
        private var scrubber: ComponentView<Empty>?
        private var scrubberLabel: ComponentView<Empty>?
        
        private let playbackButton = ComponentView<Empty>()
        private let muteButton = ComponentView<Empty>()
        private let saveButton = ComponentView<Empty>()
        private let dayNightButton = ComponentView<Empty>()
        
        private let switchCameraButton = ComponentView<Empty>()
        
        private let selectionButton = ComponentView<Empty>()
        private var selectionPanel: ComponentView<Empty>?
        
        private let textCancelButton = ComponentView<Empty>()
        private let textDoneButton = ComponentView<Empty>()
        private let textSize =  ComponentView<Empty>()
        
        private var isDismissed = false
        
        private var isEditingCaption = false
        private var currentInputMode: MessageInputPanelComponent.InputMode = .text
        
        fileprivate var isSelectionPanelOpen = false
        
        private var didInitializeInputMediaNodeDataPromise = false
        private var inputMediaNodeData: ChatEntityKeyboardInputNode.InputData?
        private var inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
        private var inputMediaNodeDataDisposable: Disposable?
        private var inputMediaNodeStateContext = ChatEntityKeyboardInputNode.StateContext()
        private var inputMediaInteraction: ChatEntityKeyboardInputNode.Interaction?
        private var inputMediaNode: ChatEntityKeyboardInputNode?
        
        private var cover: (position: Double, image: UIImage)?
        private var coverApplyTimer: SwiftSignalKit.Timer?
                
        private var videoRecorder: EntityVideoRecorder?
                
        private var component: MediaEditorScreenComponent?
        private weak var state: State?
        private var environment: ViewControllerComponentContainer.Environment?
        
        private var currentVisibleTracks: [MediaScrubberComponent.Track]?
        
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
            self.coverApplyTimer?.invalidate()
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
                    openStickerEditor: {},
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
                            (self.environment?.controller() as? MediaEditorScreenImpl)?.node.requestLayout(forceUpdate: true, transition: ComponentTransition(transition))
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
                    self.nextTransitionUserData = TextFieldComponent.AnimationHint(view: nil, kind: .textFocusChanged(isFocused: false))
                    if view.isActive {
                        view.deactivateInput(force: true)
                    } else {
                        self.endEditing(true)
                    }
                }
            } else {
                self.state?.updated(transition: .spring(duration: 0.4).withUserData(TextFieldComponent.AnimationHint(view: nil, kind: .textFocusChanged(isFocused: false))))
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
                
                if let view = self.playbackButton.view {
                    view.layer.animateAlpha(from: 0.0, to: view.alpha, duration: 0.2)
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
                
                if let view = self.inputPanel.view {
                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    view.layer.animateScale(from: 0.6, to: 1.0, duration: 0.2)
                }
                
                if let view = self.scrubber?.view {
                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    view.layer.animateScale(from: 0.6, to: 1.0, duration: 0.2)
                }
                
                if let view = self.selectionButton.view {
                    view.layer.animateAlpha(from: 0.0, to: view.alpha, duration: 0.2)
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
            }
        }
        
        func animateOut(to source: TransitionAnimationSource) {
            self.isDismissed = true
                        
            let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
            if let view = self.cancelButton.view {
                transition.setAlpha(view: view, alpha: 0.0)
                transition.setScale(view: view, scale: 0.1)
            }
            
            let toolbarButtons = [
                self.drawButton,
                self.textButton,
                self.stickerButton,
                self.toolsButton
            ]
            
            for button in toolbarButtons {
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
            }
            
            let topButtons = [
                self.saveButton,
                self.muteButton,
                self.playbackButton
            ]
            
            for button in topButtons {
                if let view = button.view {
                    transition.setAlpha(view: view, alpha: 0.0)
                    transition.setScale(view: view, scale: 0.1)
                }
            }
            
            if let view = self.scrubber?.view {
                view.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 44.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                view.layer.animateAlpha(from: view.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
            
            let stickerButtons = [
                self.undoButton,
                self.eraseButton,
                self.restoreButton,
                self.outlineButton,
                self.cutoutButton
            ]
            
            for button in stickerButtons {
                if let view = button.view {
                    transition.setAlpha(view: view, alpha: 0.0)
                    transition.setScale(view: view, scale: 0.1)
                }
            }
            
            if let view = self.textSize.view {
                transition.setAlpha(view: view, alpha: 0.0)
                transition.setScale(view: view, scale: 0.1)
            }
            
            if let view = self.selectionButton.view {
                transition.setAlpha(view: view, alpha: 0.0)
                transition.setScale(view: view, scale: 0.1)
            }
        }
        
        func animateOutToTool(inPlace: Bool, transition: ComponentTransition) {
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
                    if !inPlace {
                        view.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -44.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    }
                    view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
                }
            }
            if let view = self.doneButton.view {
                transition.setScale(view: view, scale: 0.1)
            }
            if let view = self.inputPanel.view {
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
            if let view = self.scrubber?.view {
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
        }
        
        func animateInFromTool(inPlace: Bool, transition: ComponentTransition) {
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
                    if !inPlace {
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: -44.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    }
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
            }
            if let view = self.doneButton.view {
                transition.setScale(view: view, scale: 1.0)
            }
            if let view = self.inputPanel.view {
                view.layer.animateScale(from: 0.0, to: 1.0, duration: 0.2)
            }
            if let view = self.scrubber?.view {
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
        
        func setInputText(_ text: NSAttributedString) {
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            inputPanelView.setSendMessageInput(value: .text(text), updateState: true)
        }
        
        private func updateCoverPosition() {
            guard let controller = self.environment?.controller() as? MediaEditorScreenImpl, let mediaEditor = controller.node.mediaEditor else {
                return
            }

            if let image = mediaEditor.resultImage {
                self.cover = (mediaEditor.currentPosition.seconds, image)
            }
            controller.node.requestLayout(forceUpdate: true, transition: .immediate)
            
            self.coverApplyTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak mediaEditor] in
                mediaEditor?.play()
            }, queue: Queue.mainQueue())
            self.coverApplyTimer?.start()
        }
        
        func update(component: MediaEditorScreenComponent, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            guard !self.isDismissed else {
                return availableSize
            }
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            guard let controller = environment.controller() as? MediaEditorScreenImpl else {
                return availableSize
            }
            self.environment = environment
            
            var transition = transition
            if let nextTransitionUserData = self.nextTransitionUserData {
                self.nextTransitionUserData = nil
                transition = transition.withUserData(nextTransitionUserData)
            }
            
            let isEditingStory = controller.isEditingStory || controller.isEditingStoryCover
            if self.component == nil {
                if let initialCaption = controller.initialCaption {
                    self.inputPanelExternalState.initialText = initialCaption
                } else if case let .draft(draft, _) = controller.node.actualSubject {
                    self.inputPanelExternalState.initialText = draft.caption
                }
            }

            let isRecordingAdditionalVideo = controller.node.recording.isActive
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            self.setupIfNeeded()
                        
            let mediaEditor = controller.node.mediaEditor
            
            let isTablet = environment.metrics.isTablet
            
            let openDrawing = component.openDrawing
            let cutoutUndo = component.cutoutUndo
            
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
            var previewFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - previewSize.width) / 2.0), y: topInset), size: previewSize)
            if availableSize.height < 680.0, case .stickerEditor = controller.mode {
                previewFrame = previewFrame.offsetBy(dx: 0.0, dy: -44.0)
            }
            let topButtonsAlpha: CGFloat = isRecordingAdditionalVideo ? 0.3 : 1.0
            let bottomButtonsAlpha: CGFloat = isRecordingAdditionalVideo ? 0.3 : 1.0
            let buttonsAreHidden = component.isDisplayingTool != nil || component.isDismissing || component.isInteractingWithEntities
            
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
                    action: { [weak controller] in
                        guard let controller else {
                            return
                        }
                        guard !controller.node.recording.isActive else {
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
                transition.setAlpha(view: cancelButtonView, alpha: buttonsAreHidden ? 0.0 : bottomButtonsAlpha)
            }
            
            var doneButtonTitle: String?
            var doneButtonIcon: UIImage?
            switch controller.mode {
            case .storyEditor:
                doneButtonTitle = isEditingStory ? environment.strings.Story_Editor_Done.uppercased() : environment.strings.Story_Editor_Next.uppercased()
                doneButtonIcon = UIImage(bundleImageName: "Media Editor/Next")!
            case .stickerEditor, .avatarEditor, .coverEditor:
                doneButtonTitle = nil
                doneButtonIcon = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Apply"), color: .white)!
            case .botPreview:
                doneButtonTitle = environment.strings.Story_Editor_Add.uppercased()
                doneButtonIcon = nil
            }
            
            let doneButtonSize = self.doneButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(DoneButtonContentComponent(
                        backgroundColor: UIColor(rgb: 0x007aff),
                        icon: doneButtonIcon,
                        title: doneButtonTitle)),
                    effectAlignment: .center,
                    action: { [weak controller] in
                        controller?.node.requestCompletion()
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
                transition.setAlpha(view: doneButtonView, alpha: buttonsAreHidden ? 0.0 : bottomButtonsAlpha)
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
                component: AnyComponent(ContextReferenceButtonComponent(
                    content: AnyComponent(Image(
                        image: state.image(.draw),
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    tag: drawButtonTag,
                    minSize: CGSize(width: 30.0, height: 30.0),
                    action: { [weak controller] _, _ in
                        guard let controller else {
                            return
                        }
                        guard !controller.node.recording.isActive else {
                            return
                        }
                        openDrawing(.drawing)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            var drawButtonFrame = CGRect(
                origin: CGPoint(x: buttonsLeftOffset + floorToScreenPixels(buttonsAvailableWidth / 5.0 - drawButtonSize.width / 2.0 - 3.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset + 1.0),
                size: drawButtonSize
            )         

            let textButtonSize = self.textButton.update(
                transition: transition,
                component: AnyComponent(ContextReferenceButtonComponent(
                    content: AnyComponent(Image(
                        image: state.image(.text),
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    tag: textButtonTag,
                    minSize: CGSize(width: 30.0, height: 30.0),
                    action: { [weak controller] _, _ in
                        guard let controller else {
                            return
                        }
                        guard !controller.node.recording.isActive else {
                            return
                        }
                        openDrawing(.text)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            var textButtonFrame = CGRect(
                origin: CGPoint(x: buttonsLeftOffset + floorToScreenPixels(buttonsAvailableWidth / 5.0 * 2.0 - textButtonSize.width / 2.0 - 1.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset + 2.0),
                size: textButtonSize
            )
            
            let stickerButtonSize = self.stickerButton.update(
                transition: transition,
                component: AnyComponent(ContextReferenceButtonComponent(
                    content: AnyComponent(Image(
                        image: state.image(.sticker),
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    tag: stickerButtonTag,
                    minSize: CGSize(width: 30.0, height: 30.0),
                    action: { [weak controller] view, gesture in
                        guard let controller else {
                            return
                        }
                        guard !controller.node.recording.isActive else {
                            return
                        }
                        if let gesture {
                            controller.presentEntityShortcuts(sourceView: view, gesture: gesture)
                        } else {
                            openDrawing(.sticker)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            var stickerButtonFrame = CGRect(
                origin: CGPoint(x: buttonsLeftOffset + floorToScreenPixels(buttonsAvailableWidth / 5.0 * 3.0 - stickerButtonSize.width / 2.0 + 1.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset + 2.0),
                size: stickerButtonSize
            )
            
            let rotateButtonSize = self.rotateButton.update(
                transition: transition,
                component: AnyComponent(ContextReferenceButtonComponent(
                    content: AnyComponent(Image(
                        image: state.image(.rotate),
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    tag: textButtonTag,
                    minSize: CGSize(width: 30.0, height: 30.0),
                    action: { [weak controller, weak mediaEditor] _, _ in
                        guard let controller, let mediaEditor else {
                            return
                        }
                        guard !controller.node.recording.isActive else {
                            return
                        }
                        mediaEditor.setCrop(
                            offset: mediaEditor.values.cropOffset,
                            scale: mediaEditor.values.cropScale,
                            rotation: mediaEditor.values.cropRotation - .pi / 2.0,
                            mirroring: mediaEditor.values.cropMirroring
                        )
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let rotateButtonFrame = CGRect(
                origin: CGPoint(x: drawButtonFrame.origin.x, y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset + 2.0),
                size: rotateButtonSize
            )
            
            let flipButtonSize = self.flipButton.update(
                transition: transition,
                component: AnyComponent(ContextReferenceButtonComponent(
                    content: AnyComponent(Image(
                        image: state.image(.flip),
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    tag: textButtonTag,
                    minSize: CGSize(width: 30.0, height: 30.0),
                    action: { [weak controller, weak mediaEditor] _, _ in
                        guard let controller, let mediaEditor else {
                            return
                        }
                        guard !controller.node.recording.isActive else {
                            return
                        }
                        mediaEditor.setCrop(
                            offset: mediaEditor.values.cropOffset,
                            scale: mediaEditor.values.cropScale,
                            rotation: mediaEditor.values.cropRotation,
                            mirroring: !mediaEditor.values.cropMirroring
                        )
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let flipButtonFrame = CGRect(
                origin: CGPoint(x: textButtonFrame.origin.x, y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + controlsBottomInset + 2.0),
                size: flipButtonSize
            )
            
            var isAvatarEditor = false
            var isCoverEditor = false
            if case .avatarEditor = controller.mode {
                isAvatarEditor = true
            } else if case .coverEditor = controller.mode {
                isCoverEditor = true
            }
            
            if isAvatarEditor || isCoverEditor {
                drawButtonFrame.origin.x = stickerButtonFrame.origin.x
                                
                if let rotateButtonView = self.rotateButton.view {
                    if rotateButtonView.superview == nil {
                        self.addSubview(rotateButtonView)
                    }
                    transition.setPosition(view: rotateButtonView, position: rotateButtonFrame.center)
                    transition.setBounds(view: rotateButtonView, bounds: CGRect(origin: .zero, size: rotateButtonFrame.size))
                    if !self.animatingButtons {
                        transition.setAlpha(view: rotateButtonView, alpha: buttonsAreHidden ? 0.0 : bottomButtonsAlpha)
                    }
                }
                
                if let flipButtonView = self.flipButton.view {
                    if flipButtonView.superview == nil {
                        self.addSubview(flipButtonView)
                    }
                    transition.setPosition(view: flipButtonView, position: flipButtonFrame.center)
                    transition.setBounds(view: flipButtonView, bounds: CGRect(origin: .zero, size: flipButtonFrame.size))
                    if !self.animatingButtons {
                        transition.setAlpha(view: flipButtonView, alpha: buttonsAreHidden ? 0.0 : bottomButtonsAlpha)
                    }
                }
            } else if let subject = controller.node.subject, case .empty = subject {
                let distance = floor((stickerButtonFrame.minX - textButtonFrame.minX) * 1.2)
                textButtonFrame.origin.x = availableSize.width / 2.0 - textButtonFrame.width / 2.0
                drawButtonFrame.origin.x = textButtonFrame.origin.x - distance
                stickerButtonFrame.origin.x = textButtonFrame.origin.x + distance
            }
            
            if let drawButtonView = self.drawButton.view {
                if drawButtonView.superview == nil {
                    self.addSubview(drawButtonView)
                }
                transition.setPosition(view: drawButtonView, position: drawButtonFrame.center)
                transition.setBounds(view: drawButtonView, bounds: CGRect(origin: .zero, size: drawButtonFrame.size))
                if !self.animatingButtons {
                    transition.setAlpha(view: drawButtonView, alpha: buttonsAreHidden ? 0.0 : bottomButtonsAlpha)
                }
            }
            
            if !isAvatarEditor && !isCoverEditor, let textButtonView = self.textButton.view {
                if textButtonView.superview == nil {
                    self.addSubview(textButtonView)
                }
                transition.setPosition(view: textButtonView, position: textButtonFrame.center)
                transition.setBounds(view: textButtonView, bounds: CGRect(origin: .zero, size: textButtonFrame.size))
                if !self.animatingButtons {
                    transition.setAlpha(view: textButtonView, alpha: buttonsAreHidden ? 0.0 : bottomButtonsAlpha)
                }
            }
            
            if !isAvatarEditor && !isCoverEditor, let stickerButtonView = self.stickerButton.view {
                if stickerButtonView.superview == nil {
                    self.addSubview(stickerButtonView)
                }
                transition.setPosition(view: stickerButtonView, position: stickerButtonFrame.center)
                transition.setBounds(view: stickerButtonView, bounds: CGRect(origin: .zero, size: stickerButtonFrame.size))
                if !self.animatingButtons {
                    transition.setAlpha(view: stickerButtonView, alpha: buttonsAreHidden ? 0.0 : bottomButtonsAlpha)
                }
            }
            
            if let subject = controller.node.subject, case .empty = subject {
                if let toolsButtonView = self.toolsButton.view, toolsButtonView.superview != nil {
                    toolsButtonView.removeFromSuperview()
                }
            } else {
                let toolsButtonSize = self.toolsButton.update(
                    transition: transition,
                    component: AnyComponent(Button(
                        content: AnyComponent(Image(
                            image: state.image(.tools),
                            size: CGSize(width: 30.0, height: 30.0)
                        )),
                        action: { [weak controller] in
                            guard let controller else {
                                return
                            }
                            guard !controller.node.recording.isActive else {
                                return
                            }
                            openDrawing(.tools)
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
                        transition.setAlpha(view: toolsButtonView, alpha: buttonsAreHidden ? 0.0 : bottomButtonsAlpha)
                    }
                }
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
                    mode: .standard(.default),
                    chatLocation: .peer(id: component.context.account.peerId),
                    subject: nil,
                    peerNearbyData: nil,
                    greetingData: nil,
                    pendingUnpinnedAllMessages: false,
                    activeGroupCallInfo: nil,
                    hasActiveGroupCall: false,
                    importState: nil,
                    threadData: nil,
                    isGeneralThreadClosed: nil,
                    replyMessage: nil,
                    accountPeerColor: nil,
                    businessIntro: nil
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
            
            var header: AnyComponent<Empty>?
            if let (forwardAuthor, forwardStory) = controller.forwardSource, !forwardStory.text.isEmpty {
                let authorName = forwardAuthor.displayTitle(strings: environment.strings, displayOrder: .firstLast)
                header = AnyComponent(
                    ForwardInfoPanelComponent(
                        context: component.context,
                        authorName: authorName,
                        text: forwardStory.text,
                        entities: forwardStory.entities,
                        isChannel: forwardAuthor.id.isGroupOrChannel,
                        isVibrant: true,
                        fillsWidth: true
                    )
                )
            }
            
            var isOutlineActive = false
            if let value = mediaEditor?.values.toolValues[.stickerOutline] as? Float, value > 0.0 {
                isOutlineActive = true
            }
            
            var isEditingTextEntity = false
            var sizeSliderVisible = false
            var sizeValue: CGFloat?
            if let textEntity = component.selectedEntity as? DrawingTextEntity, let entityView = component.entityViewForEntity(textEntity) as? DrawingTextEntityView {
                sizeSliderVisible = true
                isEditingTextEntity = entityView.isEditing
                sizeValue = textEntity.fontSize
            } else if [.cutoutErase, .cutoutRestore].contains(component.isDisplayingTool) {
                sizeSliderVisible = true
                sizeValue = controller.node.stickerMaskDrawingView?.appliedToolState?.size ?? 0.5
            } else if isOutlineActive {
                sizeSliderVisible = true
                if let value = mediaEditor?.values.toolValues[.stickerOutline] as? Float {
                    sizeValue = CGFloat(value)
                } else {
                    sizeValue = 0.5
                }
            }
            
            let displayTopButtons = !(self.inputPanelExternalState.isEditing || isEditingTextEntity || component.isDisplayingTool != nil)
            
            var inputPanelSize: CGSize = .zero
            if case .storyEditor = controller.mode {
                let nextInputMode: MessageInputPanelComponent.InputMode
                switch self.currentInputMode {
                case .text:
                    nextInputMode = .emoji
                case .emoji:
                    nextInputMode = .text
                default:
                    nextInputMode = .emoji
                }
                
                var canRecordVideo = true
                if let subject = controller.node.subject {
                    if case let .video(_, _, _, additionalPath, _, _, _, _, _, _) = subject, additionalPath != nil {
                        canRecordVideo = false
                    }
                    if case .videoCollage = subject {
                        canRecordVideo = false
                    }
                }
                
                self.inputPanel.parentState = state
                inputPanelSize = self.inputPanel.update(
                    transition: transition,
                    component: AnyComponent(MessageInputPanelComponent(
                        externalState: self.inputPanelExternalState,
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        style: .editor,
                        placeholder: .plain(environment.strings.Story_Editor_InputPlaceholderAddCaption),
                        sendPaidMessageStars: nil,
                        maxLength: Int(component.context.userLimits.maxStoryCaptionLength),
                        queryTypes: [.mention, .hashtag],
                        alwaysDarkWhenHasText: false,
                        useGrayBackground: component.isCollageTimelineOpen,
                        resetInputContents: nil,
                        nextInputMode: { _ in  return nextInputMode },
                        areVoiceMessagesAvailable: false,
                        presentController: { [weak controller] c in
                            guard let controller else {
                                return
                            }
                            controller.present(c, in: .window(.root))
                        },
                        presentInGlobalOverlay: { [weak controller] c in
                            guard let controller else {
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
                        setMediaRecordingActive: canRecordVideo ? { [weak controller] isActive, _, finished, sourceView in
                            guard let controller else {
                                return
                            }
                            controller.node.recording.setMediaRecordingActive(isActive, finished: finished, sourceView: sourceView)
                        } : nil,
                        lockMediaRecording: { [weak controller, weak self] in
                            guard let controller, let self else {
                                return
                            }
                            controller.node.recording.isLocked = true
                            self.state?.updated(transition: .easeInOut(duration: 0.2))
                        },
                        stopAndPreviewMediaRecording: { [weak controller] in
                            guard let controller else {
                                return
                            }
                            controller.node.recording.setMediaRecordingActive(false, finished: true, sourceView: nil)
                        },
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
                        timeoutAction: isEditingStory ? nil : { [weak controller] view, gesture in
                            guard let controller else {
                                return
                            }
                            controller.presentTimeoutSetup(sourceView: view, gesture: gesture)
                        },
                        forwardAction: nil,
                        moreAction: nil,
                        presentCaptionPositionTooltip: nil,
                        presentVoiceMessagesUnavailableTooltip: nil,
                        presentTextLengthLimitTooltip: { [weak controller] in
                            guard let controller else {
                                return
                            }
                            controller.presentCaptionLimitPremiumSuggestion(isPremium: controller.context.isPremium)
                        },
                        presentTextFormattingTooltip: { [weak controller] in
                            guard let controller else {
                                return
                            }
                            controller.presentCaptionEntitiesPremiumSuggestion()
                        },
                        paste: { [weak self, weak controller] data in
                            guard let self, let controller else {
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
                        videoRecordingStatus: controller.node.recording.status,
                        isRecordingLocked: controller.node.recording.isLocked,
                        hasRecordedVideo: mediaEditor?.values.additionalVideoPath != nil,
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
                        header: header,
                        isChannel: false,
                        storyItem: nil,
                        chatLocation: controller.customTarget.flatMap { .peer(id: $0) }
                    )),
                    environment: {},
                    containerSize: CGSize(width: inputPanelAvailableWidth, height: inputPanelAvailableHeight)
                )
                                
                if self.inputPanelExternalState.isEditing && controller.node.entitiesView.hasSelection {
                    Queue.mainQueue().justDispatch {
                        controller.node.entitiesView.selectEntity(nil)
                    }
                }
                
                if self.inputPanelExternalState.isEditing {
                    if self.currentInputMode == .emoji || (inputHeight.isZero && keyboardWasHidden) {
                        inputHeight = max(inputHeight, environment.deviceMetrics.standardInputHeight(inLandscape: false))
                    }
                }
                keyboardHeight = inputHeight
                
                let fadeTransition = ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut))
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
                        controller.dismissAllTooltips()
                        mediaEditor?.maybePauseVideo()
                    } else {
                        mediaEditor?.maybeUnpauseVideo()
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
                            
                var inputPanelBottomInset: CGFloat = -controlsBottomInset
                if inputHeight > 0.0 {
                    inputPanelBottomInset = inputHeight - environment.safeInsets.bottom
                }
                let inputPanelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - inputPanelSize.width) / 2.0), y: availableSize.height - environment.safeInsets.bottom - inputPanelBottomInset - inputPanelSize.height - 3.0), size: inputPanelSize)
                if let inputPanelView = self.inputPanel.view {
                    if inputPanelView.superview == nil {
                        self.addSubview(inputPanelView)
                    }
                    transition.setFrame(view: inputPanelView, frame: inputPanelFrame)
                    transition.setAlpha(view: inputPanelView, alpha: isEditingTextEntity || component.isDisplayingTool != nil || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
                }
                                                  
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
                
                var animateRightButtonsSwitch = false
                if let previousComponent, previousComponent.isCollageTimelineOpen != component.isCollageTimelineOpen {
                    animateRightButtonsSwitch = true
                }
                
                var buttonTransition = transition
                if animateRightButtonsSwitch {
                    buttonTransition = .immediate
                    for button in [self.muteButton, self.playbackButton] {
                        if let view = button.view {
                            if let snapshotView = view.snapshotView(afterScreenUpdates: false) {
                                snapshotView.frame = view.frame
                                view.superview?.addSubview(snapshotView)
                                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                    snapshotView.removeFromSuperview()
                                })
                                snapshotView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                                
                                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                                view.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                            }
                        }
                    }
                }
                
                let saveButtonSize = self.saveButton.update(
                    transition: transition,
                    component: AnyComponent(CameraButton(
                        content: saveContentComponent,
                        action: { [weak self, weak controller] in
                            guard let self, let controller else {
                                return
                            }
                            guard !controller.node.recording.isActive else {
                                return
                            }
                            if let view = self.saveButton.findTaggedView(tag: saveButtonTag) as? LottieAnimationComponent.View {
                                view.playOnce()
                            }
                            controller.requestSave()
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
                        setupButtonShadow(saveButtonView)
                        self.addSubview(saveButtonView)
                    }

                    let saveButtonAlpha = component.isSavingAvailable ? topButtonsAlpha : 0.3
                    saveButtonView.isUserInteractionEnabled = component.isSavingAvailable

                    buttonTransition.setPosition(view: saveButtonView, position: saveButtonFrame.center)
                    buttonTransition.setBounds(view: saveButtonView, bounds: CGRect(origin: .zero, size: saveButtonFrame.size))
                    transition.setScale(view: saveButtonView, scale: displayTopButtons ? 1.0 : 0.01)
                    transition.setAlpha(view: saveButtonView, alpha: displayTopButtons && !component.isDismissing && !component.isInteractingWithEntities ? saveButtonAlpha : 0.0)
                }
                 
                var topButtonOffsetX: CGFloat = 0.0
                var topButtonOffsetY: CGFloat = 0.0
                
                var hasDayNightSelection = false
                if let subject = controller.node.subject {
                    switch subject {
                    case .message, .gift:
                        hasDayNightSelection = true
                    default:
                        break
                    }
                }
                
                if hasDayNightSelection {
                    let isNightTheme = mediaEditor?.values.nightTheme == true
                    
                    let dayNightContentComponent: AnyComponentWithIdentity<Empty>
                    if component.hasAppeared {
                        dayNightContentComponent = AnyComponentWithIdentity(
                            id: "animatedIcon",
                            component: AnyComponent(
                                LottieAnimationComponent(
                                    animation: LottieAnimationComponent.AnimationItem(
                                        name: isNightTheme ? "anim_sun" : "anim_sun_reverse",
                                        mode: state.dayNightDidChange ? .animating(loop: false) : .still(position: .end)
                                    ),
                                    colors: ["__allcolors__": .white],
                                    size: CGSize(width: 30.0, height: 30.0)
                                ).tagged(dayNightButtonTag)
                            )
                        )
                    } else {
                        dayNightContentComponent = AnyComponentWithIdentity(
                            id: "staticIcon",
                            component: AnyComponent(
                                BundleIconComponent(
                                    name: "Media Editor/MuteIcon",
                                    tintColor: nil
                                )
                            )
                        )
                    }
                    
                    let dayNightButtonSize = self.dayNightButton.update(
                        transition: transition,
                        component: AnyComponent(CameraButton(
                            content: dayNightContentComponent,
                            action: { [weak controller, weak state, weak mediaEditor] in
                                guard let controller, let state else {
                                    return
                                }
                                guard !controller.node.recording.isActive else {
                                    return
                                }
                                if let mediaEditor {
                                    state.dayNightDidChange = true
                                    
                                    if let snapshotView = controller.node.previewContainerView.snapshotView(afterScreenUpdates: false) {
                                        controller.node.previewContainerView.addSubview(snapshotView)
                                        
                                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, delay: 0.1, removeOnCompletion: false, completion: { _ in
                                            snapshotView.removeFromSuperview()
                                        })
                                    }
                                    
                                    Queue.mainQueue().after(0.1) {
                                        mediaEditor.toggleNightTheme()
                                        controller.node.entitiesView.eachView { view in
                                            if let stickerEntityView = view as? DrawingStickerEntityView {
                                                stickerEntityView.isNightTheme = mediaEditor.values.nightTheme
                                            }
                                        }
                                    }
                                }
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: 44.0, height: 44.0)
                    )
                    let dayNightButtonFrame = CGRect(
                        origin: CGPoint(x: availableSize.width - 20.0 - dayNightButtonSize.width - 50.0, y: max(environment.statusBarHeight + 10.0, environment.safeInsets.top + 20.0)),
                        size: dayNightButtonSize
                    )
                    if let dayNightButtonView = self.dayNightButton.view {
                        if dayNightButtonView.superview == nil {
                            setupButtonShadow(dayNightButtonView)
                            self.addSubview(dayNightButtonView)
                            
                            dayNightButtonView.layer.animateAlpha(from: 0.0, to: dayNightButtonView.alpha, duration: self.animatingButtons ? 0.1 : 0.2)
                            dayNightButtonView.layer.animateScale(from: 0.4, to: 1.0, duration: self.animatingButtons ? 0.1 : 0.2)
                        }
                        transition.setPosition(view: dayNightButtonView, position: dayNightButtonFrame.center)
                        transition.setBounds(view: dayNightButtonView, bounds: CGRect(origin: .zero, size: dayNightButtonFrame.size))
                        transition.setScale(view: dayNightButtonView, scale: displayTopButtons ? 1.0 : 0.01)
                        transition.setAlpha(view: dayNightButtonView, alpha: displayTopButtons && !component.isDismissing && !component.isInteractingWithEntities ? topButtonsAlpha : 0.0)
                    }
                    
                    topButtonOffsetX += 50.0
                } else {
                    if let dayNightButtonView = self.dayNightButton.view, dayNightButtonView.superview != nil {
                        dayNightButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak dayNightButtonView] _ in
                            dayNightButtonView?.removeFromSuperview()
                        })
                        dayNightButtonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                    }
                }
                
                if let playerState = state.playerState, playerState.hasAudio {
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
                            action: { [weak state, weak controller] in
                                guard let controller else {
                                    return
                                }
                                guard !controller.node.recording.isActive else {
                                    return
                                }
                                
                                if let mediaEditor {
                                    state?.muteDidChange = true
                                    let isMuted = !mediaEditor.values.videoIsMuted
                                    mediaEditor.setVideoIsMuted(isMuted)
                                    state?.updated()
                                    
                                    controller.node.presentMutedTooltip()
                                }
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: 44.0, height: 44.0)
                    )
                    
                    var xOffset: CGFloat
                    var yOffset: CGFloat = 0.0
                    if component.isCollageTimelineOpen {
                        xOffset = 0.0
                        yOffset = 50.0 + topButtonOffsetY
                    } else {
                        xOffset = -50.0 - topButtonOffsetX
                        yOffset = 0.0
                    }
                    
                    let muteButtonFrame = CGRect(
                        origin: CGPoint(x: availableSize.width - 20.0 - muteButtonSize.width + xOffset, y: max(environment.statusBarHeight + 10.0, environment.safeInsets.top + 20.0) + yOffset),
                        size: muteButtonSize
                    )
                    if let muteButtonView = self.muteButton.view {
                        if muteButtonView.superview == nil {
                            setupButtonShadow(muteButtonView)
                            self.addSubview(muteButtonView)
                            
                            muteButtonView.layer.animateAlpha(from: 0.0, to: muteButtonView.alpha, duration: self.animatingButtons ? 0.1 : 0.2)
                            muteButtonView.layer.animateScale(from: 0.4, to: 1.0, duration: self.animatingButtons ? 0.1 : 0.2)
                        }
                        buttonTransition.setPosition(view: muteButtonView, position: muteButtonFrame.center)
                        buttonTransition.setBounds(view: muteButtonView, bounds: CGRect(origin: .zero, size: muteButtonFrame.size))
                        transition.setScale(view: muteButtonView, scale: displayTopButtons ? 1.0 : 0.01)
                        transition.setAlpha(view: muteButtonView, alpha: displayTopButtons && !component.isDismissing && !component.isInteractingWithEntities ? topButtonsAlpha : 0.0)
                    }
                    
                    topButtonOffsetX += 50.0
                    topButtonOffsetY += 50.0
                } else {
                    if let muteButtonView = self.muteButton.view, muteButtonView.superview != nil {
                        muteButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak muteButtonView] _ in
                            muteButtonView?.removeFromSuperview()
                        })
                        muteButtonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                    }
                }
                
                if let playerState = state.playerState {
                    let playbackContentComponent: AnyComponentWithIdentity<Empty>
                    if component.hasAppeared {
                        playbackContentComponent = AnyComponentWithIdentity(
                            id: "animatedIcon",
                            component: AnyComponent(
                                LottieAnimationComponent(
                                    animation: LottieAnimationComponent.AnimationItem(
                                        name: "anim_storyplayback",
                                        mode: state.playbackDidChange ? .animating(loop: false) : .still(position: .end),
                                        range: playerState.isPlaying ? (0.5, 1.0) : (0.0, 0.5)
                                    ),
                                    colors: ["__allcolors__": .white],
                                    size: CGSize(width: 30.0, height: 30.0)
                                ).tagged(playbackButtonTag)
                            )
                        )
                    } else {
                        playbackContentComponent = AnyComponentWithIdentity(
                            id: "staticIcon",
                            component: AnyComponent(
                                BundleIconComponent(
                                    name: playerState.isPlaying ? "Media Editor/Pause" : "Media Editor/Play",
                                    tintColor: nil
                                )
                            )
                        )
                    }
                    
                    let playbackButtonSize = self.playbackButton.update(
                        transition: transition,
                        component: AnyComponent(CameraButton(
                            content: playbackContentComponent,
                            action: { [weak controller, weak mediaEditor, weak state] in
                                guard let controller else {
                                    return
                                }
                                guard !controller.node.recording.isActive else {
                                    return
                                }
                                if let mediaEditor {
                                    state?.playbackDidChange = true
                                    mediaEditor.togglePlayback()
                                }
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: 44.0, height: 44.0)
                    )
                    
                    
                    var xOffset: CGFloat
                    var yOffset: CGFloat = 0.0
                    if component.isCollageTimelineOpen {
                        xOffset = 0.0
                        yOffset = 50.0 + topButtonOffsetY
                    } else {
                        xOffset = -50.0 - topButtonOffsetX
                        yOffset = 0.0
                    }
                    
                    let playbackButtonFrame = CGRect(
                        origin: CGPoint(x: availableSize.width - 20.0 - playbackButtonSize.width + xOffset, y: max(environment.statusBarHeight + 10.0, environment.safeInsets.top + 20.0) + yOffset),
                        size: playbackButtonSize
                    )
                    if let playbackButtonView = self.playbackButton.view {
                        if playbackButtonView.superview == nil {
                            setupButtonShadow(playbackButtonView)
                            self.addSubview(playbackButtonView)
                            
                            playbackButtonView.layer.animateAlpha(from: 0.0, to: playbackButtonView.alpha, duration: self.animatingButtons ? 0.1 : 0.2)
                            playbackButtonView.layer.animateScale(from: 0.4, to: 1.0, duration: self.animatingButtons ? 0.1 : 0.2)
                        }
                        buttonTransition.setPosition(view: playbackButtonView, position: playbackButtonFrame.center)
                        buttonTransition.setBounds(view: playbackButtonView, bounds: CGRect(origin: .zero, size: playbackButtonFrame.size))
                        transition.setScale(view: playbackButtonView, scale: displayTopButtons ? 1.0 : 0.01)
                        transition.setAlpha(view: playbackButtonView, alpha: displayTopButtons && !component.isDismissing && !component.isInteractingWithEntities ? topButtonsAlpha : 0.0)
                    }
                    
                    topButtonOffsetX += 50.0
                    topButtonOffsetY += 50.0
                } else {
                    if let playbackButtonView = self.playbackButton.view, playbackButtonView.superview != nil {
                        playbackButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak playbackButtonView] _ in
                            playbackButtonView?.removeFromSuperview()
                        })
                        playbackButtonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                    }
                }
                
                let switchCameraButtonSize = self.switchCameraButton.update(
                    transition: transition,
                    component: AnyComponent(Button(
                        content: AnyComponent(
                            FlipButtonContentComponent(tag: switchCameraButtonTag)
                        ),
                        action: { [weak self, weak controller] in
                            if let self, let controller {
                                controller.node.recording.togglePosition()
                                
                                if let view = self.switchCameraButton.findTaggedView(tag: switchCameraButtonTag) as? FlipButtonContentComponent.View {
                                    view.playAnimation()
                                }
                            }
                        }
                    ).withIsExclusive(false)),
                    environment: {},
                    containerSize: CGSize(width: 48.0, height: 48.0)
                )
                let switchCameraButtonFrame = CGRect(
                    origin: CGPoint(x: 12.0, y: max(environment.statusBarHeight + 10.0, inputPanelFrame.minY - switchCameraButtonSize.height - 3.0)),
                    size: switchCameraButtonSize
                )
                if let switchCameraButtonView = self.switchCameraButton.view {
                    if switchCameraButtonView.superview == nil {
                        self.addSubview(switchCameraButtonView)
                    }
                    transition.setPosition(view: switchCameraButtonView, position: switchCameraButtonFrame.center)
                    transition.setBounds(view: switchCameraButtonView, bounds: CGRect(origin: .zero, size: switchCameraButtonFrame.size))
                    transition.setScale(view: switchCameraButtonView, scale: isRecordingAdditionalVideo ? 1.0 : 0.01)
                    transition.setAlpha(view: switchCameraButtonView, alpha: isRecordingAdditionalVideo ? 1.0 : 0.0)
                }
            } else {
                inputPanelSize = CGSize(width: 0.0, height: 12.0)
            }
            
            if case .stickerEditor = controller.mode {
                
            } else {
                var selectionButtonInset: CGFloat = 0.0
                
                if let playerState = state.playerState {
                    let scrubberInset: CGFloat = 9.0
                    
                    let minDuration: Double
                    let maxDuration: Double
                    var segmentDuration: Double?
                    if playerState.isAudioOnly {
                        minDuration = 5.0
                        maxDuration = 15.0
                    } else {
                        minDuration = 1.0
                        if case .avatarEditor = controller.mode {
                            maxDuration = avatarMaxVideoDuration
                        } else {
                            if controller.node.items.count > 0 {
                                maxDuration = storyMaxVideoDuration
                            } else {
                                if case let .storyEditor(remainingCount) = controller.mode, remainingCount > 1 {
                                    maxDuration = min(storyMaxCombinedVideoDuration, Double(remainingCount) * storyMaxVideoDuration)
                                    segmentDuration = storyMaxVideoDuration
                                } else {
                                    maxDuration = storyMaxVideoDuration
                                }
                            }
                        }
                    }
                    
                    let previousTrackCount = self.currentVisibleTracks?.count
                    let visibleTracks = playerState.tracks.filter { $0.visibleInTimeline }.map { MediaScrubberComponent.Track($0) }
                    self.currentVisibleTracks = visibleTracks
                    
                    var scrubberTransition = transition
                    if let previousTrackCount, previousTrackCount != visibleTracks.count {
                        scrubberTransition = .easeInOut(duration: 0.2)
                    }
                    
                    let isAudioOnly = playerState.isAudioOnly
                    let hasMainVideoTrack = playerState.tracks.contains(where: { $0.id == 0 })
                    
                    var isCollage = false
                    if let mediaEditor, !mediaEditor.values.collage.isEmpty {
                        var videoCount = 1
                        for item in mediaEditor.values.collage {
                            if item.content.isVideo {
                                videoCount += 1
                            }
                        }
                        isCollage = videoCount > 1
                    }
                    
                    var scrubberBottomOffset: CGFloat = 0.0
                    if case .avatarEditor = controller.mode {
                        let scrubberLabel: ComponentView<Empty>
                        if let current = self.scrubberLabel {
                            scrubberLabel = current
                        } else {
                            scrubberLabel = ComponentView<Empty>()
                            self.scrubberLabel = scrubberLabel
                        }
                        
                        let scrubberLabelSize = scrubberLabel.update(
                            transition: scrubberTransition,
                            component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: environment.strings.PhotoEditor_SelectCoverFrame, font: Font.regular(14.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.7)))
                            )),
                            environment: {},
                            containerSize: availableSize
                        )
                        if let view = scrubberLabel.view {
                            if view.superview == nil {
                                self.addSubview(view)
                            }
                            
                            let scrubberLabelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - scrubberLabelSize.width) / 2.0), y: availableSize.height - environment.safeInsets.bottom - scrubberLabelSize.height + controlsBottomInset - inputPanelSize.height + 2.0), size: scrubberLabelSize)
                            view.frame = scrubberLabelFrame
                            
                            scrubberBottomOffset += scrubberLabelSize.height + 12.0
                        }
                    }
                  
                    let scrubber: ComponentView<Empty>
                    if let current = self.scrubber {
                        scrubber = current
                    } else {
                        scrubber = ComponentView<Empty>()
                        self.scrubber = scrubber
                    }
                    
                    let scrubberSize = scrubber.update(
                        transition: scrubberTransition,
                        component: AnyComponent(MediaScrubberComponent(
                            context: component.context,
                            style: .editor,
                            theme: environment.theme,
                            generationTimestamp: playerState.generationTimestamp,
                            position: playerState.position,
                            minDuration: minDuration,
                            maxDuration: maxDuration,
                            segmentDuration: segmentDuration,
                            isPlaying: playerState.isPlaying,
                            tracks: visibleTracks,
                            isCollage: isCollage,
                            isCollageSelected: component.isCollageTimelineOpen,
                            collageSamples: playerState.collageSamples,
                            cover: self.cover,
                            getCoverSourceView: { [weak controller] in
                                return controller?.node.stickerBackgroundView
                            },
                            positionUpdated: { [weak self, weak controller, weak mediaEditor] position, apply in
                                if let self, let mediaEditor {
                                    var apply = apply
                                    if !apply, self.coverApplyTimer != nil {
                                        self.coverApplyTimer?.invalidate()
                                        self.coverApplyTimer = nil
                                    }
                                    if apply, let controller, case .avatarEditor = controller.mode {
                                        apply = false
                                        self.updateCoverPosition()
                                    }
                                    mediaEditor.seek(position, andPlay: apply)
                                }
                            },
                            trackTrimUpdated: { [weak mediaEditor] trackId, start, end, updatedEnd, apply in
                                guard let mediaEditor else {
                                    return
                                }
                                let trimRange = start..<end
                                if trackId == 1000 {
                                    mediaEditor.setAudioTrackTrimRange(trimRange, apply: apply)
                                    if isAudioOnly {
                                        let offset = (mediaEditor.values.audioTrackOffset ?? 0.0)
                                        if apply {
                                            mediaEditor.seek(offset + start, andPlay: true)
                                        } else {
                                            mediaEditor.seek(offset + start, andPlay: false)
                                            mediaEditor.stop()
                                        }
                                    } else {
                                        if apply {
                                            mediaEditor.play()
                                        } else {
                                            mediaEditor.stop()
                                        }
                                    }
                                } else if trackId > 0 {
                                    mediaEditor.setAdditionalVideoTrimRange(trimRange, trackId: isCollage ? trackId : nil, apply: apply)
                                    if hasMainVideoTrack {
                                        if apply {
                                            mediaEditor.play()
                                        } else {
                                            mediaEditor.stop()
                                        }
                                    } else {
                                        if apply {
                                            mediaEditor.seek(start, andPlay: true)
                                        } else {
                                            mediaEditor.seek(updatedEnd ? end : start, andPlay: false)
                                        }
                                    }
                                } else {
                                    mediaEditor.setVideoTrimRange(trimRange, apply: apply)
                                    if apply {
                                        mediaEditor.seek(start, andPlay: true)
                                    } else {
                                        mediaEditor.seek(updatedEnd ? end : start, andPlay: false)
                                    }
                                }
                            },
                            trackOffsetUpdated: { trackId, offset, apply in
                                guard let mediaEditor else {
                                    return
                                }
                                if trackId == 1000 {
                                    mediaEditor.setAudioTrackOffset(offset, apply: apply)
                                    if isAudioOnly {
                                        let offset = (mediaEditor.values.audioTrackOffset ?? 0.0)
                                        let start = (mediaEditor.values.audioTrackTrimRange?.lowerBound ?? 0.0)
                                        if apply {
                                            mediaEditor.seek(offset + start, andPlay: true)
                                        } else {
                                            mediaEditor.seek(offset + start, andPlay: false)
                                            mediaEditor.stop()
                                        }
                                    } else {
                                        if apply {
                                            let audioStart = mediaEditor.values.audioTrackTrimRange?.lowerBound ?? 0.0
                                            let audioOffset = min(0.0, mediaEditor.values.audioTrackOffset ?? 0.0)
                                            
                                            var start = -audioOffset + audioStart
                                            if let duration = mediaEditor.duration {
                                                let lowerBound = mediaEditor.values.videoTrimRange?.lowerBound ?? 0.0
                                                let upperBound = mediaEditor.values.videoTrimRange?.upperBound ?? duration
                                                if start >= upperBound {
                                                    start = lowerBound
                                                } else if start < lowerBound {
                                                    start = lowerBound
                                                }
                                            }
                                            
                                            mediaEditor.seek(start, andPlay: true)
                                            mediaEditor.play()
                                        } else {
                                            mediaEditor.stop()
                                        }
                                    }
                                } else if trackId > 0 {
                                    mediaEditor.setAdditionalVideoOffset(offset, trackId: isCollage ? trackId : nil, apply: apply)
                                }
                            },
                            trackLongPressed: { [weak controller] trackId, sourceView in
                                guard let controller else {
                                    return
                                }
                                controller.node.presentTrackOptions(trackId: trackId, sourceView: sourceView)
                            },
                            collageSelectionUpdated: { [weak controller] in
                                guard let controller else {
                                    return
                                }
                                controller.node.openCollageTimeline()
                            },
                            trackSelectionUpdated: { [weak controller] trackId in
                                guard let controller else {
                                    return
                                }
                                controller.node.highlightCollageItem(trackId: trackId)
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: previewSize.width - scrubberInset * 2.0, height: availableSize.height)
                    )
                    if component.isCollageTimelineOpen {
                        component.externalState.timelineHeight = scrubberSize.height + 65.0
                    } else {
                        component.externalState.timelineHeight = 0.0
                    }
                    
                    let scrubberFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - scrubberSize.width) / 2.0), y: availableSize.height - environment.safeInsets.bottom - scrubberSize.height + controlsBottomInset - inputPanelSize.height + 3.0 - scrubberBottomOffset), size: scrubberSize)
                    selectionButtonInset = scrubberSize.height + 11.0
                    if let scrubberView = scrubber.view {
                        var animateIn = false
                        if scrubberView.superview == nil {
                            animateIn = true
                            if let inputPanelBackgroundView = self.inputPanelBackground.view, inputPanelBackgroundView.superview != nil {
                                self.insertSubview(scrubberView, belowSubview: inputPanelBackgroundView)
                            } else {
                                self.addSubview(scrubberView)
                            }
                        }
                        if animateIn {
                            scrubberView.frame = scrubberFrame
                        } else {
                            scrubberTransition.setFrame(view: scrubberView, frame: scrubberFrame)
                        }
                        if !self.animatingButtons && !(!hasMainVideoTrack && animateIn) {
                            let scrubberAlpha = component.isDisplayingTool != nil || component.isDismissing || component.isInteractingWithEntities || isEditingCaption || isRecordingAdditionalVideo || isEditingTextEntity ? 0.0 : 1.0
                            transition.setAlpha(view: scrubberView, alpha: scrubberAlpha)
                            if let scrubberLabelView = self.scrubberLabel?.view {
                                transition.setAlpha(view: scrubberLabelView, alpha: scrubberAlpha)
                            }
                        } else if animateIn {
                            scrubberView.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            scrubberView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            scrubberView.layer.animateScale(from: 0.6, to: 1.0, duration: 0.2)
                            
                            if let scrubberLabelView = self.scrubberLabel?.view {
                                scrubberLabelView.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                                scrubberLabelView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        }
                    }
                } else {
                    if let scrubber = self.scrubber {
                        self.scrubber = nil
                        if let scrubberView = scrubber.view {
                            scrubberView.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 44.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                            scrubberView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                                scrubberView.removeFromSuperview()
                            })
                            scrubberView.layer.animateScale(from: 1.0, to: 0.6, duration: 0.2, removeOnCompletion: false)
                        }
                    }
                }
                
                if controller.node.items.count > 1 {
                    let selectionButtonSize = self.selectionButton.update(
                        transition: transition,
                        component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(
                                SelectionPanelButtonContentComponent(
                                    count: Int32(controller.node.items.count(where: { $0.isEnabled })),
                                    isSelected: self.isSelectionPanelOpen,
                                    tag: nil
                                )
                            ),
                            effectAlignment: .center,
                            action: { [weak self, weak controller] in
                                if let self, let controller {
                                    self.isSelectionPanelOpen = !self.isSelectionPanelOpen
                                    if let mediaEditor = controller.node.mediaEditor {
                                        if self.isSelectionPanelOpen {
                                            mediaEditor.maybePauseVideo()
                                        } else {
                                            Queue.mainQueue().after(0.1) {
                                                mediaEditor.maybeUnpauseVideo()
                                            }
                                        }
                                    }
                                    self.state?.updated(transition: .spring(duration: 0.3))
                                    
                                    controller.hapticFeedback.impact(.light)
                                }
                            },
                            animateAlpha: false,
                            tag: selectionButtonTag
                        )),
                        environment: {},
                        containerSize: CGSize(width: 33.0, height: 33.0)
                    )
                    let selectionButtonFrame = CGRect(
                        origin: CGPoint(x: availableSize.width - selectionButtonSize.width - 12.0, y: availableSize.height - environment.safeInsets.bottom - selectionButtonSize.height + controlsBottomInset - inputPanelSize.height - 3.0 - selectionButtonInset),
                        size: selectionButtonSize
                    )
                    if let selectionButtonView = self.selectionButton.view as? PlainButtonComponent.View {
                        if selectionButtonView.superview == nil {
                            self.addSubview(selectionButtonView)
                        }
                        transition.setPosition(view: selectionButtonView, position: selectionButtonFrame.center)
                        transition.setBounds(view: selectionButtonView, bounds: CGRect(origin: .zero, size: selectionButtonFrame.size))
                        transition.setScale(view: selectionButtonView, scale: displayTopButtons && !isRecordingAdditionalVideo ? 1.0 : 0.01)
                        transition.setAlpha(view: selectionButtonView, alpha: displayTopButtons && !component.isDismissing && !component.isInteractingWithEntities && !isRecordingAdditionalVideo ? 1.0 : 0.0)
                        
                        if self.isSelectionPanelOpen {
                            let selectionPanelFrame = CGRect(
                                origin: CGPoint(x: 12.0, y: selectionButtonFrame.minY - 130.0),
                                size: CGSize(width: availableSize.width - 24.0, height: 120.0)
                            )
                            
                            var selectedItemId = ""
                            if let subject = controller.node.subject, let item = controller.node.items.first(where: { $0.source.identifier == subject.sourceIdentifier }) {
                                selectedItemId = item.identifier
                            }
                            
                            let selectionPanel: ComponentView<Empty>
                            if let current = self.selectionPanel {
                                selectionPanel = current
                            } else {
                                selectionPanel = ComponentView<Empty>()
                                self.selectionPanel = selectionPanel
                            }
                            
                            let _ = selectionPanel.update(
                                transition: transition,
                                component: AnyComponent(
                                    SelectionPanelComponent(
                                        previewContainerView: controller.node.previewContentContainerView,
                                        frame: selectionPanelFrame,
                                        items: controller.node.items,
                                        selectedItemId: selectedItemId,
                                        itemTapped: { [weak self, weak controller] id in
                                            guard let self, let controller else {
                                                return
                                            }
                                            self.isSelectionPanelOpen = false
                                            self.state?.updated(transition: id == nil ? .spring(duration: 0.3) : .immediate)
                                            
                                            if let id {
                                                controller.node.switchToItem(id)
                                                
                                                controller.hapticFeedback.impact(.light)
                                            }
                                        },
                                        itemSelectionToggled: { [weak self, weak controller] id in
                                            guard let self, let controller else {
                                                return
                                            }
                                            if let itemIndex = controller.node.items.firstIndex(where: { $0.identifier == id }) {
                                                controller.node.items[itemIndex].isEnabled = !controller.node.items[itemIndex].isEnabled
                                            }
                                            self.state?.updated(transition: .spring(duration: 0.3))
                                        },
                                        itemReordered: { [weak self, weak controller] fromId, toId in
                                            guard let self, let controller else {
                                                return
                                            }
                                            guard let fromIndex = controller.node.items.firstIndex(where: { $0.identifier == fromId }), let toIndex = controller.node.items.firstIndex(where: { $0.identifier == toId }), toIndex < controller.node.items.count else {
                                                return
                                            }
                                            let fromItem = controller.node.items[fromIndex]
                                            let toItem = controller.node.items[toIndex]
                                            controller.node.items[fromIndex] = toItem
                                            controller.node.items[toIndex] = fromItem
                                            self.state?.updated(transition: .spring(duration: 0.3))
                                            
                                            controller.hapticFeedback.tap()
                                        }
                                    )
                                ),
                                environment: {},
                                containerSize: availableSize
                            )
                            if let selectionPanelView = selectionPanel.view as? SelectionPanelComponent.View {
                                if selectionPanelView.superview == nil {
                                    self.insertSubview(selectionPanelView, belowSubview: selectionButtonView)
                                    if let buttonView = selectionButtonView.contentView as? SelectionPanelButtonContentComponent.View {
                                        selectionPanelView.animateIn(from: buttonView)
                                    }
                                }
                                selectionPanelView.frame = CGRect(origin: .zero, size: availableSize)
                            }
                        } else if let selectionPanel = self.selectionPanel {
                            self.selectionPanel = nil
                            if let selectionPanelView = selectionPanel.view as? SelectionPanelComponent.View {
                                if !transition.animation.isImmediate, let buttonView = selectionButtonView.contentView as? SelectionPanelButtonContentComponent.View {
                                    selectionPanelView.animateOut(to: buttonView, completion: { [weak selectionPanelView] in
                                        selectionPanelView?.removeFromSuperview()
                                    })
                                } else {
                                    selectionPanelView.removeFromSuperview()
                                }
                            }
                        }
                    }
                }
            }
            
            if case .stickerEditor = controller.mode {
                var stickerButtonsHidden = buttonsAreHidden
                if let displayingTool = component.isDisplayingTool, [.cutoutErase, .cutoutRestore].contains(displayingTool) {
                    stickerButtonsHidden = false
                }
                let stickerButtonsAlpha = stickerButtonsHidden ? 0.0 : bottomButtonsAlpha
                
                let stickerFrameWidth = floorToScreenPixels(previewSize.width * 0.97)
                let stickerFrameRect = CGRect(origin: CGPoint(x: previewFrame.minX + floorToScreenPixels((previewSize.width - stickerFrameWidth) / 2.0), y: previewFrame.minY + floorToScreenPixels((previewSize.height - stickerFrameWidth) / 2.0)), size: CGSize(width: stickerFrameWidth, height: stickerFrameWidth))
                                
                var hasCutoutButton = false
                var hasUndoButton = false
                var hasEraseButton = false
                var hasRestoreButton = false
                var hasOutlineButton = false
                              
                if let subject = controller.node.subject, case .empty = subject {
                    
                } else if case let .known(canCutout, _, hasTransparency) = controller.node.stickerCutoutStatus {
                    if controller.node.isCutout || controller.node.stickerMaskDrawingView?.internalState.canUndo == true {
                        hasUndoButton = true
                    }
                    if canCutout && !controller.node.isCutout {
                        hasCutoutButton = true
                    } else {
                        hasEraseButton = true
                        if hasUndoButton {
                            hasRestoreButton = true
                        }
                    }
                    if hasUndoButton || hasTransparency {
                        hasOutlineButton = true
                    }
                }

                if hasUndoButton {
                    let undoButtonSize = self.undoButton.update(
                        transition: transition,
                        component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(CutoutButtonContentComponent(
                                backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.18),
                                icon: state.image(.undo),
                                title: environment.strings.MediaEditor_Undo
                            )),
                            effectAlignment: .center,
                            action: {
                                cutoutUndo()
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width, height: 44.0)
                    )
                    let undoButtonFrame = CGRect(
                        origin: CGPoint(x: floorToScreenPixels((availableSize.width - undoButtonSize.width) / 2.0), y: stickerFrameRect.minY - 35.0 - undoButtonSize.height),
                        size: undoButtonSize
                    )
                    if let undoButtonView = self.undoButton.view {
                        var positionTransition = transition
                        if undoButtonView.superview == nil {
                            self.addSubview(undoButtonView)
                            
                            undoButtonView.alpha = stickerButtonsAlpha
                            undoButtonView.layer.animateAlpha(from: 0.0, to: stickerButtonsAlpha, duration: 0.2, delay: 0.0)
                            undoButtonView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2, delay: 0.0)
                            positionTransition = .immediate
                        }
                        positionTransition.setPosition(view: undoButtonView, position: undoButtonFrame.center)
                        undoButtonView.bounds = CGRect(origin: .zero, size: undoButtonFrame.size)
                        transition.setAlpha(view: undoButtonView, alpha: !isEditingTextEntity && !component.isDismissing ? stickerButtonsAlpha : 0.0)
                        transition.setScale(view: undoButtonView, scale: !isEditingTextEntity ? 1.0 : 0.01)
                    }
                } else {
                    if let undoButtonView = self.undoButton.view, undoButtonView.superview != nil {
                        undoButtonView.alpha = 0.0
                        undoButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.0, completion: { _ in
                            undoButtonView.removeFromSuperview()
                        })
                        undoButtonView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, delay: 0.0)
                    }
                }
                
                if hasCutoutButton {
                    let cutoutButtonSize = self.cutoutButton.update(
                        transition: transition,
                        component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(CutoutButtonContentComponent(
                                backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.18),
                                icon: state.image(.cutout),
                                title: environment.strings.MediaEditor_Cutout
                            )),
                            effectAlignment: .center,
                            action: {
                                openDrawing(.cutout)
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width, height: 44.0)
                    )
                    let cutoutButtonFrame = CGRect(
                        origin: CGPoint(x: floorToScreenPixels((availableSize.width - cutoutButtonSize.width) / 2.0), y: stickerFrameRect.maxY + 35.0),
                        size: cutoutButtonSize
                    )
                    if let cutoutButtonView = self.cutoutButton.view {
                        var positionTransition = transition
                        if cutoutButtonView.superview == nil {
                            self.addSubview(cutoutButtonView)
                            
                            cutoutButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: 64.0), to: .zero, duration: 0.3, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            cutoutButtonView.layer.animateAlpha(from: 0.0, to: stickerButtonsAlpha, duration: 0.2, delay: 0.0)
                            cutoutButtonView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2, delay: 0.0)
                            positionTransition = .immediate
                        }
                        positionTransition.setPosition(view: cutoutButtonView, position: cutoutButtonFrame.center)
                        cutoutButtonView.bounds = CGRect(origin: .zero, size: cutoutButtonFrame.size)
                        transition.setAlpha(view: cutoutButtonView, alpha: stickerButtonsAlpha)
                    }
                } else {
                    if let cutoutButtonView = self.cutoutButton.view, cutoutButtonView.superview != nil {
                        cutoutButtonView.alpha = 0.0
                        if transition.animation.isImmediate {
                            cutoutButtonView.removeFromSuperview()
                        } else {
                            cutoutButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.0, completion: { _ in
                                cutoutButtonView.removeFromSuperview()
                            })
                            cutoutButtonView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, delay: 0.0)
                        }
                    }
                }
                
                if hasEraseButton {
                    let buttonSpacing: CGFloat = hasRestoreButton ? 10.0 : 0.0
                    var totalButtonsWidth = buttonSpacing
                    
                    let eraseButtonSize = self.eraseButton.update(
                        transition: transition,
                        component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(CutoutButtonContentComponent(
                                backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.18),
                                icon: state.image(.erase),
                                title: environment.strings.MediaEditor_Erase,
                                minWidth: 160.0,
                                selected: component.isDisplayingTool == .cutoutErase
                            )),
                            effectAlignment: .center,
                            action: {
                                openDrawing(.cutoutErase)
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width, height: 44.0)
                    )
                    totalButtonsWidth += eraseButtonSize.width
                    
                    var buttonOriginX = floorToScreenPixels((availableSize.width - totalButtonsWidth) / 2.0)
                       
                    if hasRestoreButton {
                        let restoreButtonSize = self.restoreButton.update(
                            transition: transition,
                            component: AnyComponent(PlainButtonComponent(
                                content: AnyComponent(CutoutButtonContentComponent(
                                    backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.18),
                                    icon: state.image(.restore),
                                    title: environment.strings.MediaEditor_Restore,
                                    minWidth: 160.0,
                                    selected: component.isDisplayingTool == .cutoutRestore
                                )),
                                effectAlignment: .center,
                                action: {
                                    openDrawing(.cutoutRestore)
                                }
                            )),
                            environment: {},
                            containerSize: CGSize(width: availableSize.width, height: 44.0)
                        )
                        totalButtonsWidth += restoreButtonSize.width
                        
                        buttonOriginX = floorToScreenPixels((availableSize.width - totalButtonsWidth) / 2.0)
                        let restoreButtonFrame = CGRect(
                            origin: CGPoint(x: buttonOriginX + eraseButtonSize.width + buttonSpacing, y: stickerFrameRect.maxY + 35.0),
                            size: restoreButtonSize
                        )
                        if let restoreButtonView = self.restoreButton.view {
                            var positionTransition = transition
                            if restoreButtonView.superview == nil {
                                self.addSubview(restoreButtonView)
                                
                                restoreButtonView.alpha = stickerButtonsAlpha
                                restoreButtonView.layer.animateAlpha(from: 0.0, to: stickerButtonsAlpha, duration: 0.2, delay: 0.0)
                                restoreButtonView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2, delay: 0.0)
                                restoreButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: 64.0), to: .zero, duration: 0.3, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                                positionTransition = .immediate
                            }
                            positionTransition.setPosition(view: restoreButtonView, position: restoreButtonFrame.center)
                            restoreButtonView.bounds = CGRect(origin: .zero, size: restoreButtonFrame.size)
                            transition.setAlpha(view: restoreButtonView, alpha: stickerButtonsAlpha)
                        }
                    }
                    
                    let eraseButtonFrame = CGRect(
                        origin: CGPoint(x: buttonOriginX, y: stickerFrameRect.maxY + 35.0),
                        size: eraseButtonSize
                    )
                    if let eraseButtonView = self.eraseButton.view {
                        var positionTransition = transition
                        if eraseButtonView.superview == nil {
                            self.addSubview(eraseButtonView)
                            
                            eraseButtonView.alpha = stickerButtonsAlpha
                            eraseButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: 64.0), to: .zero, duration: 0.3, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            eraseButtonView.layer.animateAlpha(from: 0.0, to: stickerButtonsAlpha, duration: 0.2, delay: 0.0)
                            eraseButtonView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2, delay: 0.0)
                            positionTransition = .immediate
                        }
                        positionTransition.setPosition(view: eraseButtonView, position: eraseButtonFrame.center)
                        eraseButtonView.bounds = CGRect(origin: .zero, size: eraseButtonFrame.size)
                        transition.setAlpha(view: eraseButtonView, alpha: stickerButtonsAlpha)
                    }
                } else {
                    if let eraseButtonView = self.eraseButton.view, eraseButtonView.superview != nil {
                        eraseButtonView.alpha = 0.0
                        eraseButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.0, completion: { _ in
                            eraseButtonView.removeFromSuperview()
                        })
                        eraseButtonView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, delay: 0.0)
                    }
                }
                if !hasRestoreButton {
                    if let restoreButtonView = self.restoreButton.view, restoreButtonView.superview != nil {
                        restoreButtonView.alpha = 0.0
                        restoreButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.0, completion: { _ in
                            restoreButtonView.removeFromSuperview()
                        })
                        restoreButtonView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, delay: 0.0)
                    }
                }
                
                if hasOutlineButton {
                    let outlineButtonSize = self.outlineButton.update(
                        transition: transition,
                        component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(CutoutButtonContentComponent(
                                backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.18),
                                icon: state.image(.outline),
                                title: environment.strings.MediaEditor_Outline,
                                minWidth: 160.0,
                                selected: isOutlineActive
                            )),
                            effectAlignment: .center,
                            action: { [weak self, weak controller] in
                                guard let self, let mediaEditor = controller?.node.mediaEditor else {
                                    return
                                }
                                if let value = mediaEditor.values.toolValues[.stickerOutline] as? Float, value > 0.0 {
                                    mediaEditor.setToolValue(.stickerOutline, value: Float(0.0))
                                } else {
                                    mediaEditor.setToolValue(.stickerOutline, value: Float(0.5))
                                }
                                self.state?.updated(transition: .easeInOut(duration: 0.25))
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width, height: 44.0)
                    )
                    
                    let outlineButtonFrame = CGRect(
                        origin: CGPoint(x: floorToScreenPixels((availableSize.width - outlineButtonSize.width) / 2.0), y: stickerFrameRect.maxY + 35.0 + 40.0 + 16.0),
                        size: outlineButtonSize
                    )
                    if let outlineButtonView = self.outlineButton.view {
                        let outlineButtonAlpha = buttonsAreHidden ? 0.0 : bottomButtonsAlpha
                        var positionTransition = transition
                        if outlineButtonView.superview == nil {
                            self.addSubview(outlineButtonView)
                            
                            outlineButtonView.alpha = outlineButtonAlpha
                            outlineButtonView.layer.animateAlpha(from: 0.0, to: outlineButtonAlpha, duration: 0.2, delay: 0.0)
                            outlineButtonView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2, delay: 0.0)
                            outlineButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: 64.0), to: .zero, duration: 0.3, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            
                            positionTransition = .immediate
                        }
                        positionTransition.setPosition(view: outlineButtonView, position: outlineButtonFrame.center)
                        outlineButtonView.bounds = CGRect(origin: .zero, size: outlineButtonFrame.size)
                        transition.setAlpha(view: outlineButtonView, alpha: outlineButtonAlpha)
                    }
                } else {
                    if let outlineButtonView = self.outlineButton.view, outlineButtonView.superview != nil {
                        outlineButtonView.alpha = 0.0
                        outlineButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.0, completion: { _ in
                            outlineButtonView.removeFromSuperview()
                        })
                        outlineButtonView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, delay: 0.0)
                    }
                }
            }
            
            let textCancelButtonSize = self.textCancelButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(
                        Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: .white)
                    ),
                    action: { [weak controller] in
                        if let controller {
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
                    action: { [weak controller] in
                        if let controller {
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
                    updated: { [weak self, weak controller] size in
                        if let self, let controller, let component = self.component {
                            if let _ = component.selectedEntity {
                                controller.node.interaction?.updateEntitySize(size)
                            } else if [.cutoutErase, .cutoutRestore].contains(component.isDisplayingTool), let stickerMaskDrawingView = controller.node.stickerMaskDrawingView {
                                if let appliedState = stickerMaskDrawingView.appliedToolState {
                                    stickerMaskDrawingView.updateToolState(appliedState.withUpdatedSize(size))
                                }
                            } else {
                                controller.node.mediaEditor?.setToolValue(.stickerOutline, value: max(0.1, Float(size)))
                            }
                            self.state?.updated()
                        }
                    }, 
                    released: {
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
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

let storyDimensions = CGSize(width: 1080.0, height: 1920.0)
let storyMaxVideoDuration: Double = 60.0
let storyMaxCombinedVideoCount: Int = 3
let storyMaxCombinedVideoDuration: Double = storyMaxVideoDuration * Double(storyMaxCombinedVideoCount)

let avatarMaxVideoDuration: Double = 10.0

public final class MediaEditorScreenImpl: ViewController, MediaEditorScreen, UIDropInteractionDelegate {
    public enum Mode {
        public enum StickerEditorMode {
            case generic
            case addingToPack
            case editing
            case businessIntro
        }
        
        case storyEditor(remainingCount: Int32)
        case stickerEditor(mode: StickerEditorMode)
        case botPreview
        case avatarEditor
        case coverEditor(dimensions: CGSize)
    }
    
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
        case noAnimation
    }
    
    public final class TransitionOut {
        public weak var destinationView: UIView?
        public let destinationRect: CGRect
        public let destinationCornerRadius: CGFloat
        public let completion: (() -> Void)?
        
        public init(
            destinationView: UIView,
            destinationRect: CGRect,
            destinationCornerRadius: CGFloat,
            completion: (() -> Void)? = nil
        ) {
            self.destinationView = destinationView
            self.destinationRect = destinationRect
            self.destinationCornerRadius = destinationCornerRadius
            self.completion = completion
        }
    }
    
    struct State {
        var privacy: MediaEditorResultPrivacy = MediaEditorResultPrivacy(
            sendAsPeerId: nil,
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
    
    struct EditingItem: Equatable {
        enum Source: Equatable {
            case image(UIImage, PixelDimensions)
            case video(String, UIImage?, PixelDimensions, Double)
            case asset(PHAsset)
            
            static func ==(lhs: Source, rhs: Source) -> Bool {
                switch lhs {
                case let .image(lhsImage, _):
                    if case let .image(rhsImage, _) = rhs {
                        return lhsImage === rhsImage
                    }
                case let .video(lhsPath, _, _, _):
                    if case let .video(rhsPath, _, _, _) = rhs {
                        return lhsPath == rhsPath
                    }
                case let .asset(lhsAsset):
                    if case let .asset(rhsAsset) = rhs {
                        return lhsAsset.localIdentifier == rhsAsset.localIdentifier
                    }
                }
                return false
            }
            
            var identifier: String {
                switch self {
                case let .image(image, _):
                    return "\(Unmanaged.passUnretained(image).toOpaque())"
                case let .video(videoPath, _, _, _):
                    return videoPath
                case let .asset(asset):
                    return asset.localIdentifier
                }
            }
            
            var subject: MediaEditorScreenImpl.Subject {
                switch self {
                case let .image(image, dimensions):
                    return .image(image: image, dimensions: dimensions, additionalImage: nil, additionalImagePosition: .bottomLeft, fromCamera: false)
                case let .video(videoPath, thumbnail, dimensions, duration):
                    return .video(videoPath: videoPath, thumbnail: thumbnail, mirror: false, additionalVideoPath: nil, additionalThumbnail: nil, dimensions: dimensions, duration: duration, videoPositionChanges: [], additionalVideoPosition: .bottomLeft, fromCamera: false)
                case let .asset(asset):
                    return .asset(asset)
                }
            }
            
            var isVideo: Bool {
                switch self {
                case .image:
                    return false
                case .video:
                    return true
                case let .asset(asset):
                    return asset.mediaType == .video
                }
            }
        }
        
        var identifier: String
        var source: Source
        var values: MediaEditorValues?
        var caption = NSAttributedString()
        var thumbnail: UIImage?
        var isEnabled = true
        var version: Int = 0
        
        init?(subject: MediaEditorScreenImpl.Subject) {
            self.identifier = "\(Int64.random(in: 0 ..< .max))"
            switch subject {
            case let .image(image, dimensions, _, _, _):
                self.source = .image(image, dimensions)
            case let .video(videoPath, thumbnail, _, _, _, dimensions, duration, _, _, _):
                self.source = .video(videoPath, thumbnail, dimensions, duration)
            case let .asset(asset):
                self.source = .asset(asset)
            default:
                return nil
            }
        }
        
        public static func ==(lhs: EditingItem, rhs: EditingItem) -> Bool {
            if lhs.source != rhs.source {
                return false
            }
            if lhs.values != rhs.values {
                return false
            }
            if lhs.caption != rhs.caption {
                return false
            }
            if lhs.thumbnail != rhs.thumbnail {
                return false
            }
            if lhs.version != rhs.version {
                return false
            }
            return true
        }
    }
    
    final class Node: ViewControllerTracingNode, ASGestureRecognizerDelegate, UIScrollViewDelegate {
        private weak var controller: MediaEditorScreenImpl?
        private let context: AccountContext
        fileprivate var interaction: DrawingToolsInteraction?
        private let initializationTimestamp = CACurrentMediaTime()
        
        var subject: MediaEditorScreenImpl.Subject?
        var actualSubject: MediaEditorScreenImpl.Subject?
        var items: [EditingItem] = []
        
        private var subjectDisposable: Disposable?
        private var appInForegroundDisposable: Disposable?
        
        private let backgroundDimView: UIView
        fileprivate let containerView: UIView
        fileprivate let componentExternalState = MediaEditorScreenComponent.ExternalState()
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        fileprivate let storyPreview: ComponentView<Empty>
        fileprivate let toolValue: ComponentView<Empty>
        
        fileprivate let previewContainerView: UIView
        fileprivate let previewScrollView: UIScrollView
        fileprivate let previewContentContainerView: PortalSourceView
        private var transitionInView: UIImageView?
        
        private let gradientView: UIImageView
        private var gradientColorsDisposable: Disposable?
        
        fileprivate var cropScrollView: CropScrollView?
        fileprivate var stickerBackgroundView: UIImageView?
        private var stickerOverlayLayer: SimpleShapeLayer?
        private var stickerFrameLayer: SimpleShapeLayer?
        
        fileprivate let entitiesContainerView: UIView
        let entitiesView: DrawingEntitiesView
        fileprivate let selectionContainerView: DrawingSelectionContainerView
        let drawingView: DrawingView
        fileprivate let previewView: MediaEditorPreviewView
        
        fileprivate var stickerMaskWrapperView: UIView
        fileprivate var stickerMaskDrawingView: DrawingView?
        fileprivate var stickerMaskPreviewView: UIView
        
        var mediaEditor: MediaEditor?
        fileprivate var mediaEditorPromise = Promise<MediaEditor?>()
        private var mediaEntityInitialValues: (position: CGPoint, scale: CGFloat, rotation: CGFloat)?
        
        let ciContext = CIContext(options: [.workingColorSpace : NSNull()])
        
        private let stickerPickerInputData = Promise<StickerPickerInput>()
        
        fileprivate var availableReactions: [ReactionItem] = []
        private var availableReactionsDisposable: Disposable?
        
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var pinchGestureRecognizer: UIPinchGestureRecognizer?
        private var rotationGestureRecognizer: UIRotationGestureRecognizer?
        private var dismissPanGestureRecognizer: UIPanGestureRecognizer?
        
        private var isDisplayingTool: MediaEditorScreenComponent.DrawingScreenType? = nil
        private var isInteractingWithEntities = false
        private var isEnhancing = false
        
        private var hasAppeared = false
        private var isDismissing = false
        private var dismissOffset: CGFloat = 0.0
        private var isDismissed = false
        private var isDismissBySwipeSuppressed = false
        
        fileprivate var stickerCutoutStatus: MediaEditor.CutoutStatus = .unknown
        private var stickerCutoutStatusDisposable: Disposable?
        fileprivate var isCutout = false
        
        private(set) var hasAnyChanges = false
        
        fileprivate var drawingScreen: DrawingScreen?
        fileprivate var stickerScreen: StickerPickerScreen?
        fileprivate weak var cutoutScreen: MediaCutoutScreen?
        fileprivate weak var coverScreen: MediaCoverScreen?
        private var defaultToEmoji = false
        
        private var previousDrawingData: Data?
        private var previousDrawingEntities: [DrawingEntity]?
            
        private var weatherPromise: Promise<StickerPickerScreen.Weather>?
        
        private var playbackPositionDisposable: Disposable?
        
        var recording: MediaEditorScreenImpl.Recording
        
        private let locationManager = LocationManager()
        
        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        private let readyValue = Promise<Bool>()
        
        var componentHostView: MediaEditorScreenComponent.View? {
            return self.componentHost.view as? MediaEditorScreenComponent.View
        }
        
        init(controller: MediaEditorScreenImpl) {
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
            
            self.previewScrollView = UIScrollView()
            self.previewScrollView.contentInsetAdjustmentBehavior = .never
            self.previewScrollView.contentInset = .zero
            self.previewScrollView.showsHorizontalScrollIndicator = false
            self.previewScrollView.showsVerticalScrollIndicator = false
            self.previewScrollView.panGestureRecognizer.minimumNumberOfTouches = 2
            self.previewScrollView.isScrollEnabled = false
            
            self.previewContentContainerView = PortalSourceView()
            
            self.gradientView = UIImageView()
       
            var isStickerEditor = false
            var isAvatarEditor = false
            var isCoverEditor = false
            if case .stickerEditor = controller.mode {
                isStickerEditor = true
            } else if case .avatarEditor = controller.mode {
                isAvatarEditor = true
            } else if case .coverEditor = controller.mode {
                isCoverEditor = true
            }
            
            self.entitiesContainerView = UIView(frame: CGRect(origin: .zero, size: storyDimensions))
            self.entitiesView = DrawingEntitiesView(context: controller.context, size: storyDimensions, hasBin: !isStickerEditor && !isAvatarEditor && !isCoverEditor, isStickerEditor: isStickerEditor)
            self.entitiesView.getEntityCenterPosition = {
                return CGPoint(x: storyDimensions.width / 2.0, y: storyDimensions.height / 2.0)
            }
            self.entitiesView.getEntityEdgePositions = {
                return UIEdgeInsets(top: 160.0, left: 36.0, bottom: storyDimensions.height - 160.0, right: storyDimensions.width - 36.0)
            }
            self.previewView = MediaEditorPreviewView(frame: .zero)
            if case .stickerEditor = controller.mode {
                self.previewView.isOpaque = false
                self.previewView.backgroundColor = .clear
            }
            self.drawingView = DrawingView(size: storyDimensions)
            self.drawingView.isUserInteractionEnabled = false
            
            self.selectionContainerView = DrawingSelectionContainerView(frame: .zero)
            self.entitiesView.selectionContainerView = self.selectionContainerView
            
            self.stickerMaskWrapperView = UIView(frame: .zero)
            self.stickerMaskWrapperView.backgroundColor = .white
            self.stickerMaskWrapperView.isUserInteractionEnabled = false
            
            self.stickerMaskPreviewView = UIView(frame: .zero)
            self.stickerMaskPreviewView.alpha = 0.0
            self.stickerMaskPreviewView.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.3)
            self.stickerMaskPreviewView.isUserInteractionEnabled = false
            
            self.recording = MediaEditorScreenImpl.Recording(controller: controller)
            
            super.init()
            
            self.backgroundColor = .clear
            
            self.view.addSubview(self.backgroundDimView)
            self.view.addSubview(self.containerView)
            
            self.previewScrollView.delegate = self
            
            self.containerView.addSubview(self.previewContainerView)
            
            switch controller.mode {
            case .stickerEditor:
                let rowsCount = 40
                let stickerBackgroundView = UIImageView()
                stickerBackgroundView.clipsToBounds = true
                stickerBackgroundView.image = generateImage(CGSize(width: rowsCount, height: rowsCount), opaque: true, scale: 1.0, rotatedContext: { size, context in
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(CGRect(origin: .zero, size: size))
                    context.setFillColor(UIColor(rgb: 0x2b2b2d).cgColor)
                    
                    for row in 0 ..< rowsCount {
                        for column in 0 ..< rowsCount {
                            if (row + column).isMultiple(of: 2) {
                                context.addRect(CGRect(x: column, y: row, width: 1, height: 1))
                            }
                        }
                    }
                    context.fillPath()
                })
                stickerBackgroundView.layer.magnificationFilter = .nearest
                stickerBackgroundView.layer.shouldRasterize = true
                stickerBackgroundView.layer.rasterizationScale = UIScreenScale
                self.stickerBackgroundView = stickerBackgroundView
                self.previewContainerView.addSubview(stickerBackgroundView)
            case .avatarEditor, .coverEditor:
                let stickerBackgroundView = UIImageView()
                self.stickerBackgroundView = stickerBackgroundView
                self.previewContainerView.addSubview(stickerBackgroundView)
                
                let cropScrollView = CropScrollView(frame: .zero)
                cropScrollView.updated = { [weak self] position, scale in
                    guard let self, let mediaEntityView = self.entitiesView.getView(where: { $0 is DrawingMediaEntityView }) as? DrawingMediaEntityView, let mediaEntity = mediaEntityView.entity as? DrawingMediaEntity, let (initialPosition, initialScale, _) = self.mediaEntityInitialValues else {
                        return
                    }
                    mediaEntity.position = initialPosition.offsetBy(dx: position.x * initialScale, dy: position.y * initialScale)
                    mediaEntity.scale = initialScale * scale
                    mediaEntityView.update(animated: false)
                }
                self.cropScrollView = cropScrollView
            default:
                self.previewContainerView.addSubview(self.gradientView)
            }
            
            self.previewContainerView.addSubview(self.previewScrollView)
            self.previewScrollView.addSubview(self.previewContentContainerView)
            
            self.previewContentContainerView.addSubview(self.previewView)
            self.previewContentContainerView.addSubview(self.entitiesContainerView)
            self.entitiesContainerView.addSubview(self.entitiesView)
            self.entitiesView.addSubview(self.drawingView)
            
            switch controller.mode {
            case .stickerEditor, .avatarEditor, .coverEditor:
                let stickerOverlayLayer = SimpleShapeLayer()
                stickerOverlayLayer.fillColor = UIColor(rgb: 0x000000, alpha: 0.7).cgColor
                stickerOverlayLayer.fillRule = .evenOdd
                self.stickerOverlayLayer = stickerOverlayLayer
                self.previewContainerView.layer.addSublayer(stickerOverlayLayer)
                
                let stickerFrameLayer = SimpleShapeLayer()
                stickerFrameLayer.fillColor = UIColor.clear.cgColor
                stickerFrameLayer.strokeColor = UIColor(rgb: 0xffffff, alpha: 0.55).cgColor
                stickerFrameLayer.lineDashPattern = [12, 12] as [NSNumber]
                stickerFrameLayer.lineCap = .round
                
                self.stickerFrameLayer = stickerFrameLayer
                self.previewContainerView.layer.addSublayer(stickerFrameLayer)
            default:
                break
            }
            
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
                    self.actualSubject = subject
                    
                    var effectiveSubject = subject
                    switch subject {
                    case let .multiple(subjects):
                        effectiveSubject = subjects.first!
                        self.items = subjects.compactMap { EditingItem(subject: $0) }
                    case let .draft(draft, _):
                        for entity in draft.values.entities {
                            if case let .sticker(sticker) = entity {
                                switch sticker.content {
                                case let .message(ids, _, _, _, _):
                                    effectiveSubject = .message(ids)
                                case let .gift(gift, _):
                                    effectiveSubject = .gift(gift)
                                default:
                                    break
                                }
                            }
                        }
                    default:
                        break
                    }
                    
                    var privacy: MediaEditorResultPrivacy?
                    var values: MediaEditorValues?
                    var isDraft = false
                    if case let .draft(draft, _) = subject {
                        privacy = draft.privacy
                        values = draft.values
                        isDraft = true
                    }
                                        
                    self.setup(
                        subject: effectiveSubject,
                        privacy: privacy,
                        values: values,
                        caption: nil,
                        isDraft: isDraft
                    )
                }
            })
            
            let stickerPickerInputData = self.stickerPickerInputData
            Queue.concurrentDefaultQueue().after(0.5, {
                let emojiItems = EmojiPagerContentComponent.emojiInputData(
                    context: controller.context,
                    animationCache: controller.context.animationCache,
                    animationRenderer: controller.context.animationRenderer,
                    isStandalone: false,
                    subject: .emoji,
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
                                
                let signal = combineLatest(
                    queue: .mainQueue(),
                    emojiItems,
                    stickerItems
                ) |> map { emoji, stickers -> StickerPickerInput in
                    return StickerPickerInputData(emoji: emoji, stickers: stickers, gifs: nil)
                } |> afterNext { [weak self] _ in
                    if let self {
                        self.controller?.checkPostingAvailability()
                    }
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
                    if inForeground {
                        mediaEditor.maybeUnpauseVideo()
                    } else {
                        mediaEditor.maybePauseVideo()
                    }
                }
            })
            
            self.entitiesView.getAvailableReactions = { [weak self] in
                return self?.availableReactions ?? []
            }
            self.entitiesView.present = { [weak self] c in
                if let self {
                    self.controller?.dismissAllTooltips()
                    self.controller?.present(c, in: .current)
                }
            }
            self.entitiesView.push = { [weak self] c in
                if let self {
                    self.controller?.push(c)
                }
            }
            self.entitiesView.externalEntityRemoved = { [weak self] entity in
                if let self, let stickerEntity = entity as? DrawingStickerEntity, case let .dualVideoReference(isAdditional) = stickerEntity.content, isAdditional {
                    self.mediaEditor?.setAdditionalVideo(nil, positionChanges: [])
                }
            }
            self.entitiesView.canInteract = { [weak self] in
                if let self, let controller = self.controller {
                    if controller.node.recording.isActive {
                        return false
                    } else if case .avatarEditor = controller.mode, self.drawingScreen == nil {
                        return false
                    }
                }
                return true
            }
            
            self.availableReactionsDisposable = (allowedStoryReactions(context: controller.context)
            |> deliverOnMainQueue).start(next: { [weak self] reactions in
                if let self {
                    self.availableReactions = reactions
                }
            })
            
            if controller.isEditingStoryCover {
                Queue.mainQueue().justDispatch {
                    self.openCoverSelection(exclusive: true)
                }
            }
        }
        
        deinit {
            self.subjectDisposable?.dispose()
            self.gradientColorsDisposable?.dispose()
            self.appInForegroundDisposable?.dispose()
            self.playbackPositionDisposable?.dispose()
            self.availableReactionsDisposable?.dispose()
            self.stickerCutoutStatusDisposable?.dispose()
        }
        
        func setup(
            subject: MediaEditorScreenImpl.Subject,
            privacy: MediaEditorResultPrivacy? = nil,
            values: MediaEditorValues?,
            caption: NSAttributedString?,
            isDraft: Bool = false
        ) {
            guard let controller = self.controller else {
                return
            }
            
            self.subject = subject
            
            Queue.mainQueue().justDispatch {
                controller.setupAudioSessionIfNeeded()
            }

            if let privacy {
                controller.state.privacy = privacy
            }
            
            var isFromCamera = false
            let isSavingAvailable: Bool
            switch subject {
            case let .image(_, _, _, _, fromCamera):
                isFromCamera = fromCamera
                isSavingAvailable = !controller.isEmbeddedEditor
            case let .video(_, _, _, _, _, _, _, _, _, fromCamera):
                isFromCamera = fromCamera
                isSavingAvailable = !controller.isEmbeddedEditor
            case .draft, .message,. gift:
                isSavingAvailable = true
            default:
                isSavingAvailable = false
            }
            controller.isSavingAvailable = isSavingAvailable
            controller.requestLayout(transition: .immediate)
            
            let mediaDimensions = subject.dimensions
            let maxSide: CGFloat = 1920.0 / UIScreen.main.scale
            let fittedSize = mediaDimensions.cgSize.fitted(CGSize(width: maxSide, height: maxSide))
            let mediaEntity = DrawingMediaEntity(size: fittedSize)
            mediaEntity.position = CGPoint(x: storyDimensions.width / 2.0, y: storyDimensions.height / 2.0)
            switch controller.mode {
            case .storyEditor, .botPreview:
                if fittedSize.height > fittedSize.width {
                    mediaEntity.scale = max(storyDimensions.width / fittedSize.width, storyDimensions.height / fittedSize.height)
                } else {
                    mediaEntity.scale = storyDimensions.width / fittedSize.width
                }
            case .stickerEditor, .avatarEditor:
                if fittedSize.height > fittedSize.width {
                    mediaEntity.scale = storyDimensions.width / fittedSize.width
                } else {
                    mediaEntity.scale = storyDimensions.width / fittedSize.height
                }
            case let .coverEditor(dimensions):
                let fittedStoryDimensions = dimensions.aspectFitted(storyDimensions)
                mediaEntity.scale = max(fittedStoryDimensions.width / fittedSize.width, fittedStoryDimensions.height / fittedSize.height)
            }

            let initialPosition = mediaEntity.position
            let initialScale = mediaEntity.scale
            let initialRotation = mediaEntity.rotation
            self.mediaEntityInitialValues = (initialPosition, initialScale, initialRotation)
            
            if isFromCamera && mediaDimensions.width > mediaDimensions.height {
                mediaEntity.scale = storyDimensions.height / fittedSize.height
            }
            
            if case .botPreview = controller.mode {
                if fittedSize.width / fittedSize.height < storyDimensions.width / storyDimensions.height {
                    mediaEntity.scale = storyDimensions.height / fittedSize.height
                }
            }
             
            let initialValues: MediaEditorValues?
            if let values {
                initialValues = values

                for entity in values.entities {
                    self.entitiesView.add(entity.entity.duplicate(copy: true), announce: false)
                }
                
                if let drawingData = values.drawing?.pngData() {
                    self.drawingView.setup(withDrawing: drawingData)
                }
            } else {
                initialValues = nil
            }
            
            let mediaEditorMode: MediaEditor.Mode
            switch controller.mode {
            case .stickerEditor:
                mediaEditorMode = .sticker
            case .avatarEditor, .coverEditor:
                mediaEditorMode = .avatar
            default:
                mediaEditorMode = .default
            }
               
            if let mediaEntityView = self.entitiesView.add(mediaEntity, announce: false) as? DrawingMediaEntityView {
                self.entitiesView.sendSubviewToBack(mediaEntityView)
                mediaEntityView.updated = { [weak self, weak mediaEntity] in
                    if let self, let mediaEditor = self.mediaEditor, let mediaEntity {
                        let rotation = mediaEntity.rotation - initialRotation
                        let position = CGPoint(x: mediaEntity.position.x - initialPosition.x, y: mediaEntity.position.y - initialPosition.y)
                        let scale = mediaEntity.scale / initialScale
                        let mirroring = mediaEditor.values.cropMirroring
                        mediaEditor.setCrop(offset: position, scale: scale, rotation: rotation, mirroring: mirroring)
                        
                        self.updateMaskDrawingView(position: position, scale: scale, rotation: rotation)
                    }
                }
                
                if let initialValues {
                    mediaEntity.position = mediaEntity.position.offsetBy(dx: initialValues.cropOffset.x, dy: initialValues.cropOffset.y)
                    mediaEntity.rotation = mediaEntity.rotation + initialValues.cropRotation
                    mediaEntity.scale = mediaEntity.scale * initialValues.cropScale
                } else if case .sticker = subject {
                    mediaEntity.scale = mediaEntity.scale * 0.97
                }
            }
                        
            let mediaEditor = MediaEditor(
                context: self.context,
                mode: mediaEditorMode,
                subject: subject.editorSubject,
                values: initialValues,
                hasHistogram: true
            )
            if case let .storyEditor(remainingCount) = controller.mode, self.items.isEmpty {
                mediaEditor.maxDuration = min(storyMaxCombinedVideoDuration, Double(remainingCount) * storyMaxVideoDuration)
            } else if case .avatarEditor = controller.mode {
                mediaEditor.maxDuration = avatarMaxVideoDuration
            }
            
            if case .avatarEditor = controller.mode {
                mediaEditor.setVideoIsMuted(true)
            } else if case let .coverEditor(dimensions) = controller.mode {
                mediaEditor.setCoverDimensions(dimensions)
            }
            if let initialVideoPosition = controller.initialVideoPosition {
                if controller.isEditingStoryCover {
                    mediaEditor.setCoverImageTimestamp(initialVideoPosition)
                } else {
                    mediaEditor.seek(initialVideoPosition, andPlay: true)
                }
            }
            if !isDraft, self.context.sharedContext.currentPresentationData.with({$0}).autoNightModeTriggered {
                switch subject {
                case .message, .gift:
                    mediaEditor.setNightTheme(true)
                default:
                    break
                }
            }
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
            if case .stickerEditor = controller.mode {
                self.stickerCutoutStatusDisposable = (mediaEditor.cutoutStatus
                |> deliverOnMainQueue).start(next: { [weak self] cutoutStatus in
                    guard let self else {
                        return
                    }
                    self.stickerCutoutStatus = cutoutStatus
                    self.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.25))
                })
                mediaEditor.maskUpdated = { [weak self] mask, apply in
                    guard let self else {
                        return
                    }
                    if self.stickerMaskDrawingView == nil {
                        self.setupMaskDrawingView(size: mask.size)
                    }
                    if apply, let maskData = mask.pngData() {
                        self.stickerMaskDrawingView?.setup(withDrawing: maskData, storeAsClear: true)
                    }
                }
                mediaEditor.classificationUpdated = { [weak self] classes in
                    guard let  self else {
                        return
                    }
                    self.controller?.stickerRecommendedEmoji = emojiForClasses(classes.map { $0.0 })
                }
            }
            mediaEditor.attachPreviewView(self.previewView, andPlay: !(self.controller?.isEditingStoryCover ?? false))
            
            if case .empty = subject {
                self.stickerMaskDrawingView?.emptyColor = .black
                self.stickerMaskDrawingView?.clearWithEmptyColor()
            }
            
            switch subject {
            case .message, .gift:
                break
            default:
                self.readyValue.set(.single(true))
            }
            
            switch subject {
            case let .image(_, _, additionalImage, position, _):
                if let additionalImage {
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
                }
            case let .video(_, _, mirror, additionalVideoPath, _, _, _, changes, position, _):
                mediaEditor.setVideoIsMirrored(mirror)
                if let additionalVideoPath {
                    let videoEntity = DrawingStickerEntity(content: .dualVideoReference(false))
                    videoEntity.referenceDrawingSize = storyDimensions
                    videoEntity.scale = 1.625
                    videoEntity.position = position.getPosition(storyDimensions)
                    self.entitiesView.add(videoEntity, announce: false)
                    
                    mediaEditor.setAdditionalVideo(additionalVideoPath, isDual: true, positionChanges: changes.map { VideoPositionChange(additional: $0.0, timestamp: $0.1) })
                    mediaEditor.setAdditionalVideoPosition(videoEntity.position, scale: videoEntity.scale, rotation: videoEntity.rotation)
                    if let entityView = self.entitiesView.getView(for: videoEntity.uuid) as? DrawingStickerEntityView {
                        entityView.updated = { [weak self, weak videoEntity] in
                            if let self, let videoEntity {
                                self.mediaEditor?.setAdditionalVideoPosition(videoEntity.position, scale: videoEntity.scale, rotation: videoEntity.rotation)
                            }
                        }
                    }
                }
            case let .videoCollage(items):
                mediaEditor.setupCollage(items.map { $0.editorItem })
            case let .sticker(_, emoji):
                controller.stickerSelectedEmoji = emoji
            case .message, .gift:
                var isGift = false
                let messages: Signal<[Message], NoError>
                if case let .message(messageIds) = subject {
                    messages = self.context.engine.data.get(
                        EngineDataMap(messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init(id:)))
                    )
                    |> map { result in
                        var messages: [Message] = []
                        for id in messageIds {
                            if let maybeMessage = result[id], let message = maybeMessage {
                                messages.append(message._asMessage())
                            }
                        }
                        return messages
                    }
                } else if case let .gift(gift) = subject {
                    isGift = true
                    let media: [Media] = [TelegramMediaAction(action: .starGiftUnique(gift: .unique(gift), isUpgrade: false, isTransferred: false, savedToProfile: false, canExportDate: nil, transferStars: nil, isRefunded: false, peerId: nil, senderId: nil, savedId: nil, resaleStars: nil, canTransferDate: nil, canResaleDate: nil))]
                    let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: self.context.account.peerId, namespace: Namespaces.Message.Cloud, id: -1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: media, peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                    messages = .single([message])
                } else {
                    fatalError()
                }
                
                let isNightTheme = mediaEditor.values.nightTheme
                let _ = (messages
                |> deliverOnMainQueue).start(next: { [weak self] messages in
                    guard let self else {
                        return
                    }
                    var messageFile: TelegramMediaFile?
                    if let maybeFile = messages.first?.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile, maybeFile.isVideo, let _ = self.context.account.postbox.mediaBox.completedResourcePath(maybeFile.resource, pathExtension: nil) {
                        messageFile = maybeFile
                    }
                    if "".isEmpty {
                        messageFile = nil
                    }
                    
                    let wallpaperColors: Signal<(UIColor?, UIColor?), NoError>
                    if case .gift = subject {
                        wallpaperColors = self.mediaEditorPromise.get()
                        |> mapToSignal { mediaEditor in
                            if let mediaEditor {
                                return mediaEditor.wallpapers
                                |> filter {
                                    $0 != nil
                                }
                                |> take(1)
                                |> map { result in
                                    if let (dayImage, nightImage) = result {
                                        return (getAverageColor(image: dayImage), nightImage.flatMap { getAverageColor(image: $0) })
                                    }
                                    return (nil, nil)
                                }
                            }
                            return .complete()
                        }
                    
                    } else {
                        wallpaperColors = .single((nil, nil))
                    }
                    
                    let _ = (wallpaperColors
                    |> deliverOnMainQueue).start(next: { [weak self] wallpaperColors in
                        guard let self else {
                            return
                        }
                        let renderer = DrawingMessageRenderer(context: self.context, messages: messages, parentView: self.view, isGift: isGift, wallpaperDayColor: wallpaperColors.0, wallpaperNightColor: wallpaperColors.1)
                        renderer.render(completion: { result in
                            if isDraft, let existingEntityView = self.entitiesView.getView(where: { entityView in
                                if let stickerEntityView = entityView as? DrawingStickerEntityView {
                                    if case .message = (stickerEntityView.entity as! DrawingStickerEntity).content {
                                        return true
                                    } else if case .gift = (stickerEntityView.entity as! DrawingStickerEntity).content {
                                        return true
                                    }
                                }
                                return false
                            }) as? DrawingStickerEntityView {
                                existingEntityView.isNightTheme = isNightTheme
                                let messageEntity = existingEntityView.entity as! DrawingStickerEntity
                                messageEntity.renderImage = result.dayImage
                                messageEntity.secondaryRenderImage = result.nightImage
                                messageEntity.overlayRenderImage = result.overlayImage
                                existingEntityView.update(animated: false)
                            } else {
                                var content: DrawingStickerEntity.Content
                                var position: CGPoint
                                switch subject {
                                case let .message(messageIds):
                                    content = .message(messageIds, result.size, messageFile, result.mediaFrame?.rect, result.mediaFrame?.cornerRadius)
                                    position = CGPoint(x: storyDimensions.width / 2.0 - 54.0, y: storyDimensions.height / 2.0)
                                case let .gift(gift):
                                    content = .gift(gift, result.size)
                                    position = CGPoint(x: storyDimensions.width / 2.0, y: storyDimensions.height / 2.0)
                                default:
                                    fatalError()
                                }
                                
                                let messageEntity = DrawingStickerEntity(content: content)
                                messageEntity.renderImage = result.dayImage
                                messageEntity.secondaryRenderImage = result.nightImage
                                messageEntity.overlayRenderImage = result.overlayImage
                                messageEntity.referenceDrawingSize = storyDimensions
                                messageEntity.position = position
                                
                                let fraction = max(result.size.width, result.size.height) / 353.0
                                messageEntity.scale = min(6.0, 3.3 * fraction)
                                
                                if let entityView = self.entitiesView.add(messageEntity, announce: false) as? DrawingStickerEntityView {
                                    if isNightTheme {
                                        entityView.isNightTheme = true
                                    }
                                }
                            }
                            
                            self.readyValue.set(.single(true))
                        })
                    })
                })
            default:
                break
            }
                        
            self.gradientColorsDisposable = mediaEditor.gradientColors.start(next: { [weak self] colors in
                if let self, let colors {
                    let gradientImage = generateGradientImage(size: CGSize(width: 5.0, height: 640.0), colors: colors.array, locations: [0.0, 1.0])
                    Queue.mainQueue().async {
                        self.gradientView.image = gradientImage
                        
                        if self.controller?.isEmbeddedEditor == true {
                            
                        } else {
                            if case .videoCollage = subject {
                                Queue.mainQueue().after(0.7) {
                                    self.previewContainerView.alpha = 1.0
                                    self.previewContainerView.layer.allowsGroupOpacity = true
                                    self.previewContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { _ in
                                        self.previewContainerView.layer.allowsGroupOpacity = false
                                        self.previewContainerView.alpha = 1.0
                                        self.backgroundDimView.isHidden = false
                                    })
                                }
                            } else if CACurrentMediaTime() - self.initializationTimestamp > 0.2, case .image = subject, self.items.isEmpty {
                                self.previewContainerView.alpha = 1.0
                                self.previewContainerView.layer.allowsGroupOpacity = true
                                self.previewContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { _ in
                                    self.previewContainerView.layer.allowsGroupOpacity = false
                                    self.previewContainerView.alpha = 1.0
                                    self.backgroundDimView.isHidden = false
                                })
                            } else {
                                self.previewContainerView.alpha = 1.0
                                self.backgroundDimView.isHidden = false
                            }
                        }
                    }
                }
            })
            self.mediaEditor = mediaEditor
            self.mediaEditorPromise.set(.single(mediaEditor))
            
            if controller.isEmbeddedEditor {
                mediaEditor.onFirstDisplay = { [weak self] in
                    if let self {
                        if let transitionInView = self.transitionInView  {
                            self.transitionInView = nil
                            transitionInView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak transitionInView] _ in
                                transitionInView?.removeFromSuperview()
                            })
                        }
                        
                        if subject.isPhoto {
                            self.previewContainerView.layer.allowsGroupOpacity = true
                            self.previewContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { _ in
                                self.previewContainerView.layer.allowsGroupOpacity = false
                                self.previewContainerView.alpha = 1.0
                                self.backgroundDimView.isHidden = false
                            })
                        } else {
                            self.previewContainerView.alpha = 1.0
                            self.backgroundDimView.isHidden = false
                        }
                    }
                }
            } else {
                if let caption {
                    mediaEditor.onFirstDisplay = { [weak self] in
                        self?.componentHostView?.setInputText(caption)
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
            
            if let initialLink = controller.initialLink {
                self.addInitialLink(initialLink)
            }
        }
        
        private var initialMaskScale: CGFloat = .zero
        private var initialMaskPosition: CGPoint = .zero
        private func setupMaskDrawingView(size: CGSize) {
            guard let mediaEntityView = self.entitiesView.getView(where: { $0 is DrawingMediaEntityView }) as? DrawingMediaEntityView else {
                return
            }
            let mediaEntitySize = mediaEntityView.bounds.size
            let scaledDimensions = size
            let maskDrawingSize = scaledDimensions.aspectFilled(mediaEntitySize)
            
            let stickerMaskDrawingView = DrawingView(size: scaledDimensions, gestureView: self.previewContainerView)
            stickerMaskDrawingView.stateUpdated = { [weak self] _ in
                if let self {
                    self.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.25))
                }
            }
            stickerMaskDrawingView.emptyColor = .white
            stickerMaskDrawingView.updateToolState(.pen(DrawingToolState.BrushState(color: DrawingColor(color: .black), size: 0.5)))
            stickerMaskDrawingView.isUserInteractionEnabled = false
            stickerMaskDrawingView.animationsEnabled = false
            stickerMaskDrawingView.clearWithEmptyColor()
            if let filter = makeLuminanceToAlphaFilter() {
                self.stickerMaskWrapperView.layer.filters = [filter]
            }
            self.stickerMaskWrapperView.addSubview(stickerMaskDrawingView)
            self.stickerMaskWrapperView.addSubview(self.stickerMaskPreviewView)
            self.stickerMaskDrawingView = stickerMaskDrawingView
            
            let previewSize = self.previewView.bounds.size
            self.stickerMaskWrapperView.frame = CGRect(origin: .zero, size: previewSize)
            self.stickerMaskPreviewView.frame = CGRect(origin: .zero, size: previewSize)
            
            let maskScale = previewSize.width / min(maskDrawingSize.width, maskDrawingSize.height)
            self.initialMaskScale = maskScale
            self.initialMaskPosition = CGPoint(x: previewSize.width / 2.0, y: previewSize.height / 2.0)
            stickerMaskDrawingView.bounds = CGRect(origin: .zero, size: maskDrawingSize)
            
            self.updateMaskDrawingView(position: .zero, scale: 1.0, rotation: 0.0)
        }
        
        private func updateMaskDrawingView(position: CGPoint, scale: CGFloat, rotation: CGFloat) {
            guard let stickerMaskDrawingView = self.stickerMaskDrawingView else {
                return
            }
            let maskScale = self.initialMaskPosition.x * 2.0 / 1080.0
            stickerMaskDrawingView.center = self.initialMaskPosition.offsetBy(dx: position.x * maskScale, dy: position.y * maskScale)
            stickerMaskDrawingView.transform = CGAffineTransform(scaleX: self.initialMaskScale * scale, y: self.initialMaskScale * scale).rotated(by: rotation)
        }
       
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveModalDismiss = true
            self.view.disablesInteractiveKeyboardGestureRecognizer = true
            
            let dismissPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handleDismissPan(_:)))
            dismissPanGestureRecognizer.delegate = self.wrappedGestureRecognizerDelegate
            dismissPanGestureRecognizer.maximumNumberOfTouches = 1
            self.previewContainerView.addGestureRecognizer(dismissPanGestureRecognizer)
            self.dismissPanGestureRecognizer = dismissPanGestureRecognizer
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            panGestureRecognizer.delegate = self.wrappedGestureRecognizerDelegate
            panGestureRecognizer.minimumNumberOfTouches = 1
            panGestureRecognizer.maximumNumberOfTouches = 2
            self.view.addGestureRecognizer(panGestureRecognizer)
            self.panGestureRecognizer = panGestureRecognizer
            
            let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinch(_:)))
            pinchGestureRecognizer.delegate = self.wrappedGestureRecognizerDelegate
            self.previewContainerView.addGestureRecognizer(pinchGestureRecognizer)
            self.pinchGestureRecognizer = pinchGestureRecognizer
            
            let rotateGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(self.handleRotate(_:)))
            rotateGestureRecognizer.delegate = self.wrappedGestureRecognizerDelegate
            self.previewContainerView.addGestureRecognizer(rotateGestureRecognizer)
            self.rotationGestureRecognizer = rotateGestureRecognizer
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
            tapGestureRecognizer.delegate = self.wrappedGestureRecognizerDelegate
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
                        let selectedEntity = selectedEntityView.entity
                        if let textEntity = selectedEntity as? DrawingTextEntity, let textEntityView = selectedEntityView as? DrawingTextEntityView, textEntityView.isEditing {
                            textEntity.setColor(color, range: textEntityView.selectedRange)
                            textEntityView.update(animated: false, keepSelectedRange: true)
                        } else {
                            selectedEntity.color = color
                            selectedEntityView.update(animated: false)
                        }
                    }
                },
                onInteractionUpdated: { [weak self] isInteracting in
                    if let self {
                        if let selectedEntityView = self.entitiesView.selectedEntityView as? DrawingStickerEntityView, let entity = selectedEntityView.entity as? DrawingStickerEntity, case .dualVideoReference = entity.content {
                            if isInteracting {
                                self.mediaEditor?.maybePauseVideo()
                            } else {
                                self.mediaEditor?.maybeUnpauseVideo()
                            }
                        } else if self.mediaEditor?.sourceIsVideo == true {
                            if isInteracting {
                                self.mediaEditor?.maybePauseVideo()
                            } else {
                                self.mediaEditor?.maybeUnpauseVideo()
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
                        } else if let link = entity as? DrawingLinkEntity {
                            self.addOrEditLink(link)
                        }
                    }
                },
                shouldDeleteEntity: { [weak self] entity in
                    if let self {
                        if let stickerEntity = entity as? DrawingStickerEntity, case .dualVideoReference(true) = stickerEntity.content {
                            self.presentVideoRemoveConfirmation()
                            return false
                        }
                    }
                    return true
                },
                getCurrentImage: { [weak self] in
                    guard let mediaEditor = self?.mediaEditor else {
                        return nil
                    }
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let imageSize = storyDimensions
                    if let context = DrawingContext(size: imageSize, scale: 1.0, opaque: true, colorSpace: colorSpace) {
                        context.withFlippedContext { context in
                            if let image = mediaEditor.resultImage?.cgImage {
                                context.draw(image, in: CGRect(origin: .zero, size: imageSize))
                            }
                        }
                        return context.generateImage(colorSpace: colorSpace)
                    }
                    return nil
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
            
            Queue.mainQueue().after(0.1) {
                self.previewScrollView.pinchGestureRecognizer?.isEnabled = false
            }
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
                if self.controller?.isEmbeddedEditor == true || self.isDisplayingTool != nil || self.entitiesView.hasSelection || self.entitiesView.getView(at: location) != nil || self.componentHostView?.isSelectionPanelOpen == true {
                    return false
                }
                return true
            } else if gestureRecognizer === self.panGestureRecognizer {
                let location = gestureRecognizer.location(in: self.view)
                if location.x < 36.0 {
                    return false
                }
                if location.x > self.view.frame.width - 44.0 && location.y > self.view.frame.height - 180.0 {
                    return false
                }
                if let reactionNode = self.view.subviews.last?.asyncdisplaykit_node as? ReactionContextNode {
                    if let hitTestResult = self.view.hitTest(location, with: nil), hitTestResult.isDescendant(of: reactionNode.view) {
                        return false
                    }
                }
                if self.stickerScreen != nil {
                    return false
                }
                if self.stickerMaskDrawingView?.isUserInteractionEnabled == true {
                    return false
                }
                return true
            } else if gestureRecognizer === self.pinchGestureRecognizer {
                if self.stickerScreen != nil {
                    return false
                }
                if self.stickerMaskDrawingView?.isUserInteractionEnabled == true {
                    return false
                }
                return true
            } else if gestureRecognizer === self.rotationGestureRecognizer {
                if self.stickerScreen != nil {
                    return false
                }
                if self.stickerMaskDrawingView?.isUserInteractionEnabled == true {
                    return false
                }
                return true
            } else {
                let location = gestureRecognizer.location(in: self.view)
                if let reactionNode = self.view.subviews.last?.asyncdisplaykit_node as? ReactionContextNode {
                    if let hitTestResult = self.view.hitTest(location, with: nil), hitTestResult.isDescendant(of: reactionNode.view) {
                        return false
                    }
                }
                return true
            }
        }
        
        private var canEnhance: Bool {
            switch self.subject {
            case .message, .gift:
                return false
            default:
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

            var hasSwipeToEnhance = true
            if case .stickerEditor = controller.mode {
                hasSwipeToDismiss = false
                hasSwipeToEnhance = false
            } else if case .avatarEditor = controller.mode {
                hasSwipeToDismiss = false
                hasSwipeToEnhance = false
            } else if case .coverEditor = controller.mode {
                hasSwipeToDismiss = false
                hasSwipeToEnhance = false
            } else if self.isCollageTimelineOpen {
                hasSwipeToEnhance = false
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
                } else if abs(translation.x) > 10.0 && !self.isDismissing && !self.isEnhancing && self.canEnhance && hasSwipeToEnhance {
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
                } else if self.isEnhancing {
                    self.isEnhancing = false
                    Queue.mainQueue().after(0.5) {
                        controller.requestLayout(transition: .animated(duration: 0.3, curve: .easeInOut))
                    }
                }
            default:
                break
            }
        }
        
        private var previousPanTimestamp: Double?
        private var previousPinchTimestamp: Double?
        private var previousRotateTimestamp: Double?
        
        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard !self.isCollageTimelineOpen && !(self.componentHostView?.isSelectionPanelOpen ?? false) else {
                return
            }
            if gestureRecognizer.numberOfTouches == 2, let subject = self.subject, !self.entitiesView.hasSelection {
                switch self.controller?.mode {
                case .avatarEditor, .coverEditor:
                    return
                default:
                    break
                }
                
                switch subject {
                case .message, .gift:
                    return
                default:
                    break
                }
            }
            let currentTimestamp = CACurrentMediaTime()
            if let previousPanTimestamp = self.previousPanTimestamp, currentTimestamp - previousPanTimestamp < 0.016, case .changed = gestureRecognizer.state {
                return
            }
            self.previousPanTimestamp = currentTimestamp
            self.entitiesView.handlePan(gestureRecognizer)
        }
        
        @objc func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
            guard !self.isCollageTimelineOpen else {
                return
            }
            if gestureRecognizer.numberOfTouches == 2, let subject = self.subject, !self.entitiesView.hasSelection {
                switch self.controller?.mode {
                case .avatarEditor, .coverEditor:
                    return
                default:
                    break
                }
                
                switch subject {
                case .message, .gift:
                    return
                default:
                    break
                }
            }
            let currentTimestamp = CACurrentMediaTime()
            if let previousPinchTimestamp = self.previousPinchTimestamp, currentTimestamp - previousPinchTimestamp < 0.016, case .changed = gestureRecognizer.state {
                return
            }
            self.previousPinchTimestamp = currentTimestamp
            self.entitiesView.handlePinch(gestureRecognizer)
        }
        
        @objc func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
            guard !self.isCollageTimelineOpen else {
                return
            }
            if gestureRecognizer.numberOfTouches == 2, let subject = self.subject, !self.entitiesView.hasSelection {
                switch self.controller?.mode {
                case .avatarEditor, .coverEditor:
                    return
                default:
                    break
                }
                
                switch subject {
                case .message, .gift:
                    return
                default:
                    break
                }
            }
            let currentTimestamp = CACurrentMediaTime()
            if let previousRotateTimestamp = self.previousRotateTimestamp, currentTimestamp - previousRotateTimestamp < 0.016, case .changed = gestureRecognizer.state {
                return
            }
            self.entitiesView.handleRotate(gestureRecognizer)
        }
        
        @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard !self.recording.isActive, let controller = self.controller else {
                return
            }
            
            if self.isCollageTimelineOpen {
                self.isCollageTimelineOpen = false
                self.requestLayout(forceUpdate: true, transition: .spring(duration: 0.4))
                return
            }
            
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
                        if case .storyEditor = controller.mode {
                            self.insertTextEntity()
                        }
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
            guard let controller = self.controller else {
                return
            }
            self.previewContainerView.alpha = 1.0
            
            let transitionInView = UIImageView(image: image)
            transitionInView.contentMode = .scaleAspectFill
            var initialScale: CGFloat
            switch controller.mode {
            case .storyEditor, .botPreview:
                if image.size.height > image.size.width {
                    initialScale = max(self.previewContainerView.bounds.width / image.size.width, self.previewContainerView.bounds.height / image.size.height)
                } else {
                    initialScale = self.previewContainerView.bounds.width / image.size.width
                }
            case .stickerEditor, .avatarEditor, .coverEditor:
                if image.size.height > image.size.width {
                    initialScale = self.previewContainerView.bounds.width / image.size.width
                } else {
                    initialScale = self.previewContainerView.bounds.width / image.size.height
                }
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
                case .noAnimation:
                    self.layer.allowsGroupOpacity = true
                    self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    completion()
                case .camera:
                    self.componentHostView?.animateIn(from: .camera, completion: completion)
                    
                    if let subject = self.subject, case let .video(_, mainTransitionImage, _, _, additionalTransitionImage, _, _, positionChangeTimestamps, pipPosition, _) = subject, let mainTransitionImage {
                        var transitionImage = mainTransitionImage
                        if let additionalTransitionImage {
                            var backgroundImage = mainTransitionImage
                            var foregroundImage = additionalTransitionImage
                            if let change = positionChangeTimestamps.first, change.0 {
                                backgroundImage = additionalTransitionImage
                                foregroundImage = mainTransitionImage
                            }
                            if let combinedTransitionImage = generateImage(storyDimensions, scale: 1.0, rotatedContext: { size, context in
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
                        self.componentHostView?.animateIn(from: .gallery)
                        
                        let sourceLocalFrame = sourceView.convert(transitionIn.sourceRect, to: self.view)
                        let sourceScale = sourceLocalFrame.width / self.previewContainerView.frame.width
                        let sourceAspectRatio = sourceLocalFrame.height / sourceLocalFrame.width
                        
                        let duration: Double = 0.4
                        let timingFunction = kCAMediaTimingFunctionSpring
                        
                        self.previewContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: self.previewContainerView.center, duration: duration, timingFunction: timingFunction, completion: { _ in
                            completion()
                        })
                        self.previewContainerView.layer.animateScale(from: sourceScale, to: 1.0, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                        self.previewContainerView.layer.animateBounds(from: CGRect(origin: CGPoint(x: 0.0, y: (self.previewContainerView.bounds.height - self.previewContainerView.bounds.width * sourceAspectRatio) / 2.0), size: CGSize(width: self.previewContainerView.bounds.width, height: self.previewContainerView.bounds.width * sourceAspectRatio)), to: self.previewContainerView.bounds, duration: duration, timingFunction: timingFunction)
                        
                        self.backgroundDimView.isHidden = false
                        self.backgroundDimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.35)
                        
                        if let componentView = self.componentHostView {
                            componentView.layer.animatePosition(from: sourceLocalFrame.center, to: componentView.center, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            componentView.layer.animateScale(from: sourceScale, to: 1.0, duration: duration, timingFunction: timingFunction)
                            componentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        }
                    }
                }
            } else {
                var animateIn = false
                if let subject {
                    switch subject {
                    case .empty, .message, .gift, .sticker, .image:
                        animateIn = true
                    default:
                        break
                    }
                }
                if animateIn, let layout = self.validLayout {
                    self.layer.animatePosition(from: CGPoint(x: 0.0, y: layout.size.height), to: .zero, duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    completion()
                } else {
                    self.componentHostView?.animateIn(from: .camera, completion: completion)
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
            
            self.saveTooltip?.dismiss()
            
            if self.entitiesView.hasSelection {
                self.entitiesView.selectEntity(nil)
            }
            
            let previousDimAlpha = self.backgroundDimView.alpha
            self.backgroundDimView.alpha = 0.0
            self.backgroundDimView.layer.animateAlpha(from: previousDimAlpha, to: 0.0, duration: 0.15)
            
            var isNew: Bool? = false
            if let subject = self.actualSubject {
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
                var destinationTransitionRect: CGRect = .zero
                let transitionOutCompletion = transitionOut.completion
                if !finished {
                    if let transitionIn = controller.transitionIn, case let .gallery(galleryTransitionIn) = transitionIn, let sourceImage = galleryTransitionIn.sourceImage, isNew != true {
                        let sourceSuperView = galleryTransitionIn.sourceView?.superview?.superview
                        let destinationTransitionOutView = UIImageView(image: sourceImage)
                        destinationTransitionOutView.clipsToBounds = true
                        destinationTransitionOutView.contentMode = .scaleAspectFill
                        destinationTransitionOutView.frame = self.previewContainerView.convert(self.previewContainerView.bounds, to: sourceSuperView)
                        sourceSuperView?.addSubview(destinationTransitionOutView)
                        destinationTransitionView = destinationTransitionOutView
                        destinationTransitionRect = galleryTransitionIn.sourceRect
                    }
                    self.componentHostView?.animateOut(to: .gallery)
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
                } else if let destinationNode = destinationView.asyncdisplaykit_node as? AvatarNode.ContentNode {
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
                    transitionOutCompletion?()
                })
                self.previewContainerView.layer.animateScale(from: 1.0, to: destinationScale, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.previewContainerView.layer.animateBounds(from: self.previewContainerView.bounds, to: CGRect(origin: CGPoint(x: 0.0, y: (self.previewContainerView.bounds.height - self.previewContainerView.bounds.width * destinationAspectRatio) / 2.0), size: CGSize(width: self.previewContainerView.bounds.width, height: self.previewContainerView.bounds.width * destinationAspectRatio)), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                
                if let destinationTransitionView {
                    self.previewContainerView.layer.allowsGroupOpacity = true
                    self.previewContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                    destinationTransitionView.layer.animateFrame(from: destinationTransitionView.frame, to: destinationView.convert(destinationTransitionRect, to: destinationTransitionView.superview), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak destinationTransitionView] _ in
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
                
                if let componentView = self.componentHostView {
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
                self.componentHostView?.animateOut(to: .camera)
                let transition = ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut))
                transition.setAlpha(view: self.previewContainerView, alpha: 0.0, completion: { _ in
                    completion()
                })
            } else {
                if controller.isEmbeddedEditor {
                    self.componentHostView?.animateOut(to: .gallery)
                    
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
        
        func animateOutToTool(tool: MediaEditorScreenComponent.DrawingScreenType, inPlace: Bool = false) {
            self.isDisplayingTool = tool
            
            let transition: ComponentTransition = .easeInOut(duration: 0.2)
            self.componentHostView?.animateOutToTool(inPlace: inPlace, transition: transition)
            self.requestUpdate(transition: transition)
        }
        
        func animateInFromTool(inPlace: Bool = false) {
            self.isDisplayingTool = nil
            
            let transition: ComponentTransition = .easeInOut(duration: 0.2)
            self.componentHostView?.animateInFromTool(inPlace: inPlace, transition: transition)
            self.requestUpdate(transition: transition)
        }
                
        private weak var muteTooltip: ViewController?
        func presentMutedTooltip() {
            guard let mediaEditor = self.mediaEditor, let sourceView = self.componentHost.findTaggedView(tag: muteButtonTag) else {
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
            if mediaEditor.values.audioTrack != nil || (mediaEditor.sourceIsVideo && mediaEditor.values.additionalVideoPath != nil) {
                if isMuted {
                    text = self.presentationData.strings.Story_Editor_TooltipMutedWithAudio
                } else {
                    text = self.presentationData.strings.Story_Editor_TooltipUnmutedWithAudio
                }
            } else {
                if isMuted {
                    text = self.presentationData.strings.Story_Editor_TooltipMuted
                } else {
                    text = self.presentationData.strings.Story_Editor_TooltipUnmuted
                }
            }
            
            let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: text), location: .point(location, .top), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .ignore
            })
            self.muteTooltip = tooltipController
            self.controller?.present(tooltipController, in: .current)
        }
        
        private var displayedSelectionTooltip = false
        func presentSelectionTooltip() {
            guard let sourceView = self.componentHost.findTaggedView(tag: selectionButtonTag), !self.displayedSelectionTooltip, self.items.count > 1 else {
                return
            }
            
            self.displayedSelectionTooltip = true
            
            let _ = (ApplicationSpecificNotice.getMultipleStoriesTooltip(accountManager: self.context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { [weak self] count in
                guard let self, count < 3 else {
                    return
                }
                let parentFrame = self.view.convert(self.bounds, to: nil)
                let absoluteFrame = sourceView.convert(sourceView.bounds, to: nil).offsetBy(dx: -parentFrame.minX, dy: 0.0)
                let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY - 3.0), size: CGSize())
                            
                let text = self.presentationData.strings.Story_Editor_TooltipSelection(Int32(self.items.count))
                let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: text), location: .point(location, .bottom), displayDuration: .default, inset: 8.0, shouldDismissOnTouch: { _, _ in
                    return .dismiss(consume: false)
                })
                self.controller?.present(tooltipController, in: .current)
                
                let _ = ApplicationSpecificNotice.incrementMultipleStoriesTooltip(accountManager: self.context.sharedContext.accountManager).start()
            })
        }
        
        fileprivate weak var saveTooltip: SaveProgressScreen?
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
                controller.present(tooltipController, in: .window(.root))
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
                controller.present(tooltipController, in: .window(.root))
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
                    let entity = DrawingStickerEntity(content: .image(updatedImage, .rectangle))
                    entity.canCutOut = false
                    
                    let _ = (cutoutStickerImage(from: image, onlyCheck: true)
                    |> deliverOnMainQueue).start(next: { [weak entity] result in
                        if result != nil, let entity {
                            entity.canCutOut = true
                        }
                    })
                    
                    self?.interaction?.insertEntity(entity, scale: 2.5)
                    
                    self?.hasAnyChanges = true
                    self?.controller?.isSavingAvailable = true
                    self?.controller?.requestLayout(transition: .immediate)
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
                self.didSetupStaticEmojiPack = true
                self.staticEmojiPack.set(self.context.engine.stickers.loadedStickerPack(reference: .name("staticemoji"), forceActualized: false))
            }
                        
            var location: CLLocationCoordinate2D?
            if case let .draft(draft, _) = self.actualSubject {
                location = draft.location
            } else if case let .asset(asset) = self.subject {
                location = asset.location?.coordinate
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
                            let flag = flagEmoji(countryCode: countryCode)
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
                                    if let alt = item.file.customEmojiAlt {
                                        displayText = alt
                                    }
                                    if let displayText, displayText.hasPrefix(flag) {
                                        return true
                                    } else {
                                        return false
                                    }
                                }) {
                                    return match.file._parse()
                                } else {
                                    return nil
                                }
                            }
                        } else {
                            emojiFile = .single(nil)
                        }
                        
                        let _ = (emojiFile
                        |> deliverOnMainQueue).start(next: { [weak self] emojiFile in
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
                }
            )
            locationController.customModalStyleOverlayTransitionFactorUpdated = { [weak self, weak locationController] transition in
                if let self, let locationController {
                    let transitionFactor = locationController.modalStyleOverlayTransitionFactor
                    self.updateModalTransitionFactor(transitionFactor, transition: transition)
                }
            }
            controller.push(locationController)
        }
        
        func presentAudioPicker() {
            var isSettingTrack = false
            self.controller?.present(legacyICloudFilePicker(theme: self.presentationData.theme, mode: .import, documentTypes: ["public.mp3", "public.mpeg-4-audio", "public.aac-audio", "org.xiph.flac"], forceDarkTheme: true, dismissed: { [weak self] in
                if let self {
                    Queue.mainQueue().after(0.1) {
                        if !isSettingTrack {
                            self.mediaEditor?.play()
                        }
                    }
                }
            }, completion: { [weak self] urls in
                guard let self, let mediaEditor = self.mediaEditor, !urls.isEmpty, let url = urls.first else {
                    return
                }
                isSettingTrack = true
                
                try? FileManager.default.createDirectory(atPath: draftPath(engine: self.context.engine), withIntermediateDirectories: true)
                
                let isScopedResource = url.startAccessingSecurityScopedResource()
                Logger.shared.log("MediaEditor", "isScopedResource = \(isScopedResource)")
                
                let coordinator = NSFileCoordinator(filePresenter: nil)
                var error: NSError?
                coordinator.coordinate(readingItemAt: url, options: .forUploading, error: &error, byAccessor: { sourceUrl in
                    let fileName =  "audio_\(sourceUrl.lastPathComponent)"
                    let copyPath = fullDraftPath(peerId: self.context.account.peerId, path: fileName)
                    
                    try? FileManager.default.removeItem(atPath: copyPath)
                    do {
                        try FileManager.default.copyItem(at: sourceUrl, to: URL(fileURLWithPath: copyPath))
                    } catch let e {
                        Logger.shared.log("MediaEditor", "copy file error \(e)")
                        if isScopedResource {
                            url.stopAccessingSecurityScopedResource()
                        }
                        return
                    }
                    
                    Queue.mainQueue().async {
                        let audioAsset = AVURLAsset(url: URL(fileURLWithPath: copyPath))
                        
                        func loadValues(asset: AVAsset, retryCount: Int, completion: @escaping () -> Void) {
                            asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"], completionHandler: {
                                if asset.statusOfValue(forKey: "tracks", error: nil) == .loading {
                                    if retryCount < 2 {
                                        Queue.mainQueue().after(0.1, {
                                            loadValues(asset: asset, retryCount: retryCount + 1, completion: completion)
                                        })
                                    } else {
                                        completion()
                                    }
                                } else {
                                    completion()
                                }
                            })
                        }
                        
                        loadValues(asset: audioAsset, retryCount: 0, completion: {
                            var audioDuration: Double = 0.0
                            guard let track = audioAsset.tracks(withMediaType: .audio).first else {
                                Logger.shared.log("MediaEditor", "track is nil")
                                if isScopedResource {
                                    url.stopAccessingSecurityScopedResource()
                                }
                                return
                            }
                            
                            audioDuration = track.timeRange.duration.seconds
                            if audioDuration.isZero {
                                Logger.shared.log("MediaEditor", "duration is zero")
                                if isScopedResource {
                                    url.stopAccessingSecurityScopedResource()
                                }
                                return
                            }
                            
                            func maybeFixMisencodedText(_ text: String) -> String {
                                let charactersToSearchFor = CharacterSet(charactersIn: "àåèîóûþÿ")
                                if text.lowercased().rangeOfCharacter(from: charactersToSearchFor) != nil {
                                    if let data = text.data(using: .windowsCP1252), let string = String(data: data, encoding: .windowsCP1251) {
                                        return string
                                    } else {
                                        return text
                                    }
                                } else {
                                    return text
                                }
                            }
                            
                            var artist: String?
                            var title: String?
                            for data in audioAsset.commonMetadata {
                                if data.commonKey == .commonKeyArtist, let value = data.stringValue {
                                    artist = maybeFixMisencodedText(value)
                                }
                                if data.commonKey == .commonKeyTitle, let value = data.stringValue {
                                    title = maybeFixMisencodedText(value)
                                }
                            }
                            
                            Queue.mainQueue().async {
                                var audioTrimRange: Range<Double>?
                                var audioOffset: Double?
                                
                                if let videoDuration = mediaEditor.originalCappedDuration {
                                    if let videoStart = mediaEditor.values.videoTrimRange?.lowerBound {
                                        audioOffset = -videoStart
                                    } else if let _ = mediaEditor.values.additionalVideoPath, let videoStart = mediaEditor.values.additionalVideoTrimRange?.lowerBound {
                                        audioOffset = -videoStart
                                    }
                                    audioTrimRange = 0 ..< min(videoDuration, audioDuration)
                                } else {
                                    audioTrimRange = 0 ..< min(15, audioDuration)
                                }
                                
                                mediaEditor.setAudioTrack(MediaAudioTrack(path: fileName, artist: artist, title: title, duration: audioDuration), trimRange: audioTrimRange, offset: audioOffset)

                                mediaEditor.seek(mediaEditor.values.videoTrimRange?.lowerBound ?? 0.0, andPlay: true)
                                
                                self.requestUpdate(transition: .easeInOut(duration: 0.2))
                                if isScopedResource {
                                    url.stopAccessingSecurityScopedResource()
                                }
                                
                                mediaEditor.play()
                            }
                        })
                    }
                })
                
                if let error {
                    Logger.shared.log("MediaEditor", "coordinator error \(error)")
                }
            }), in: .window(.root))
        }
        
        func presentVideoRemoveConfirmation() {
            guard let controller = self.controller else {
                return
            }
            let presentationData = controller.context.sharedContext.currentPresentationData.with { $0 }
            let alertController = textAlertController(
                context: controller.context,
                forceTheme: defaultDarkColorPresentationTheme,
                title: nil,
                text: presentationData.strings.MediaEditor_VideoRemovalConfirmation,
                actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                    }),
                    TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: { [weak mediaEditor, weak entitiesView] in
                        mediaEditor?.setAdditionalVideo(nil, positionChanges: [])
                        if let entityView = entitiesView?.getView(where: { entityView in
                            if let entity = entityView.entity as? DrawingStickerEntity, case .dualVideoReference = entity.content {
                                return true
                            } else {
                                return false
                            }
                        }) {
                            entitiesView?.remove(uuid: entityView.entity.uuid, animated: false)
                        }
                    })
                ]
            )
            controller.present(alertController, in: .window(.root))
        }
        
        func presentTrackOptions(trackId: Int32, sourceView: UIView) {
            guard let mediaEditor = self.mediaEditor else {
                return
            }
            let isVideo = trackId != 1000
            let actionTitle: String = isVideo ? self.presentationData.strings.MediaEditor_RemoveVideo : self.presentationData.strings.MediaEditor_RemoveAudio
            let isCollage = !mediaEditor.values.collage.isEmpty
            
            let value: CGFloat
            if trackId == 1000 {
                value = mediaEditor.values.audioTrackVolume ?? 1.0
            } else if trackId == 0 {
                value = mediaEditor.values.videoVolume ?? 1.0
            } else if trackId > 0 {
                if !isCollage {
                    value = mediaEditor.values.additionalVideoVolume ?? 1.0
                } else if let index = mediaEditor.collageItemIndexForTrackId(trackId) {
                    value = mediaEditor.values.collage[index].videoVolume ?? 1.0
                } else {
                    value = 1.0
                }
            } else {
                value = 1.0
            }
            
            var items: [ContextMenuItem] = []
            items.append(
                .custom(VolumeSliderContextItem(minValue: 0.0, maxValue: 1.5, value: value, valueChanged: { [weak self] value, _ in
                    if let self, let mediaEditor = self.mediaEditor {
                        if trackId == 1000 {
                            mediaEditor.setAudioTrackVolume(value)
                        } else if trackId == 0 {
                            if mediaEditor.values.videoIsMuted {
                                mediaEditor.setVideoIsMuted(false)
                            }
                            mediaEditor.setVideoVolume(value)
                        } else if trackId > 0 {
                            mediaEditor.setAdditionalVideoVolume(value, trackId: isCollage ? trackId : nil)
                        }
                    }
                }), false)
            )
            
            if trackId != 0 && !isCollage {
                items.append(
                    .action(
                        ContextMenuActionItem(
                            text: actionTitle,
                            icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.primaryColor)},
                            action: { [weak self] f in
                                f.dismissWithResult(.default)
                                if let self, let mediaEditor = self.mediaEditor {
                                    if trackId == 1 {
                                        self.presentVideoRemoveConfirmation()
                                    } else {
                                        mediaEditor.setAudioTrack(nil)
                                        if !mediaEditor.sourceIsVideo && !mediaEditor.isPlaying {
                                            mediaEditor.play()
                                        }
                                    }
                                    self.requestUpdate(transition: .easeInOut(duration: 0.25))
                                }
                            }
                        )
                    )
                )
            }
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
            let contextController = ContextController(presentationData: presentationData, source: .reference(ReferenceContentSource(sourceView: sourceView, contentArea: UIScreen.main.bounds, customPosition: CGPoint(x: 0.0, y: -3.0))), items: .single(ContextController.Items(content: .list(items))))
            self.controller?.present(contextController, in: .window(.root))
        }
        
        func addOrEditLink(_ existingEntity: DrawingLinkEntity? = nil) {
            guard let controller = self.controller else {
                return
            }
            
            if existingEntity == nil {
                let maxLinkCount = self.context.userLimits.maxStoriesLinksCount
                var currentLinkCount = 0
                self.entitiesView.eachView { entityView in
                    if entityView.entity is DrawingLinkEntity {
                        currentLinkCount += 1
                    }
                }
                if currentLinkCount >= maxLinkCount {
                    controller.presentLinkLimitTooltip()
                    return
                }
            }
            
            var link: CreateLinkScreen.Link?
            if let existingEntity {
                link = CreateLinkScreen.Link(
                    url: existingEntity.url,
                    name: existingEntity.name,
                    webpage: existingEntity.webpage,
                    positionBelowText: existingEntity.positionBelowText,
                    largeMedia: existingEntity.largeMedia,
                    isDark: existingEntity.style == .black
                )
            }
                        
            let linkController = CreateLinkScreen(context: controller.context, link: link, snapshotImage: self.mediaEditor?.resultImage, completion: { [weak self] result in
                guard let self else {
                    return
                }
                
                let style: DrawingLinkEntity.Style
                if let existingEntity {
                    if ![.white, .black].contains(existingEntity.style), result.webpage != nil {
                        style = .white
                    } else {
                        style = existingEntity.style
                    }
                } else {
                    style = .white
                }

                let entity = DrawingLinkEntity(url: result.url, name: result.name, webpage: result.webpage, positionBelowText: result.positionBelowText, largeMedia: result.largeMedia, style: style)
                entity.whiteImage = result.image
                entity.blackImage = result.nightImage
                                
                if let existingEntity {
                    self.entitiesView.remove(uuid: existingEntity.uuid, animated: true)
                }
                self.interaction?.insertEntity(
                    entity,
                    scale: existingEntity?.scale ?? 1.0,
                    position: existingEntity?.position
                )
            })
            controller.push(linkController)
        }
        
        func addInitialLink(_ link: (url: String, name: String?)) {
            guard self.context.isPremium else {
                Queue.mainQueue().after(0.3) {
                    let context = self.context
                    var replaceImpl: ((ViewController) -> Void)?
                    let demoController = context.sharedContext.makePremiumDemoController(context: context, subject: .stories, forceDark: true, action: {
                        let controller = context.sharedContext.makePremiumIntroController(context: context, source: .storiesLinks, forceDark: true, dismissed: {})
                        replaceImpl?(controller)
                    }, dismissed: {})
                    replaceImpl = { [weak self, weak demoController] c in
                        demoController?.dismiss(animated: true, completion: {
                            guard let self else {
                                return
                            }
                            self.controller?.push(c)
                        })
                    }
                    self.controller?.push(demoController)
                }
                return
            }
            
            let entity = DrawingLinkEntity(url: link.url, name: link.name ?? "", webpage: nil, positionBelowText: false, largeMedia: nil, style: .white)
            self.interaction?.insertEntity(entity, position: CGPoint(x: storyDimensions.width / 2.0, y: storyDimensions.width / 3.0 * 4.0), select: false)
        }
        
        func addReaction() {
            guard let controller = self.controller else {
                return
            }
            let maxReactionCount = self.context.userLimits.maxStoriesSuggestedReactions
            var currentReactionCount = 0
            self.entitiesView.eachView { entityView in
                if let stickerEntity = entityView.entity as? DrawingStickerEntity, case let .file(_, type) = stickerEntity.content, case .reaction = type {
                    currentReactionCount += 1
                }
            }
            if currentReactionCount >= maxReactionCount {
                controller.presentReactionPremiumSuggestion()
                return
            }
        
            let heart = "❤️".strippedEmoji
            if let reaction = self.availableReactions.first(where: { reaction in
                return reaction.reaction.rawValue == .builtin(heart)
            }) {
                let stickerEntity = DrawingStickerEntity(content: .file(.standalone(media: reaction.stillAnimation._parse()), .reaction(.builtin(heart), .white)))
                self.interaction?.insertEntity(stickerEntity, scale: 1.175)
            }
            
            self.mediaEditor?.play()
        }
        
        func requestWeather() {
            
        }
        
        func presentLocationAccessAlert() {
            DeviceAccess.authorizeAccess(to: .location(.weather), locationManager: self.locationManager, presentationData: self.presentationData, present: { [weak self] c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            }, openSettings: { [weak self] in
                self?.context.sharedContext.applicationBindings.openSettings()
            }, { [weak self] authorized in
                guard let self, authorized else {
                    return
                }
                let weatherPromise = Promise<StickerPickerScreen.Weather>()
                weatherPromise.set(getWeather(context: self.context, load: true))
                self.weatherPromise = weatherPromise
                
                let _ = (weatherPromise.get()
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    if let self, case let .loaded(weather) = result {
                        self.addWeather(weather)
                    }
                })
            })
        }
        
        func addWeather(_ weather: StickerPickerScreen.Weather.LoadedWeather?) {
            guard let weather else {
                return
            }
            let maxWeatherCount = 1
            var currentWeatherCount = 0
            self.entitiesView.eachView { entityView in
                if entityView.entity is DrawingWeatherEntity {
                    currentWeatherCount += 1
                }
            }
            if currentWeatherCount >= maxWeatherCount {
                self.controller?.presentWeatherLimitTooltip()
                return
            }
            
            self.interaction?.insertEntity(
                DrawingWeatherEntity(
                    emoji: weather.emoji,
                    emojiFile: weather.emojiFile,
                    temperature: weather.temperature,
                    style: .white
                ),
                scale: nil,
                position: nil
            )
        }
        
        func getCaption() -> NSAttributedString {
            return self.componentHostView?.getInputText() ?? NSAttributedString()
        }
        
        func switchToItem(_ identifier: String) {
            guard let controller = self.controller, let mediaEditor = self.mediaEditor, let itemIndex = self.items.firstIndex(where: { $0.identifier == identifier }), let subject = self.subject, let currentItemIndex = self.items.firstIndex(where: { $0.source.identifier == subject.sourceIdentifier }) else {
                return
            }
            
            let entities = self.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
            let codableEntities = DrawingEntitiesView.encodeEntities(entities, entitiesView: self.entitiesView)
            mediaEditor.setDrawingAndEntities(data: nil, image: mediaEditor.values.drawing, entities: codableEntities)
            
            var updatedCurrentItem = self.items[currentItemIndex]
            updatedCurrentItem.caption = self.getCaption()
            
            if (mediaEditor.values.hasChanges && updatedCurrentItem.values != mediaEditor.values) || updatedCurrentItem.values?.gradientColors == nil {
                updatedCurrentItem.values = mediaEditor.values
                updatedCurrentItem.version += 1
                
                if let resultImage = mediaEditor.resultImage {
                    mediaEditor.seek(0.0, andPlay: false)
                    makeEditorImageComposition(
                        context: self.ciContext,
                        postbox: self.context.account.postbox,
                        inputImage: resultImage,
                        dimensions: storyDimensions,
                        values: mediaEditor.values,
                        time: .zero,
                        textScale: 2.0,
                        completion: { [weak self] resultImage in
                            updatedCurrentItem.version += 1
                            updatedCurrentItem.thumbnail = resultImage
                            self?.items[currentItemIndex] = updatedCurrentItem
                        }
                    )
                }
            } else {
                updatedCurrentItem.version += 1
                self.items[currentItemIndex] = updatedCurrentItem
            }
            
            self.entitiesView.clearAll()
            
            let targetItem = self.items[itemIndex]
            controller.node.setup(
                subject: targetItem.source.subject,
                values: targetItem.values,
                caption: targetItem.caption
            )
        }
        
        func requestCompletion(playHaptic: Bool = true) {
            guard let controller = self.controller else {
                return
            }
            switch controller.mode {
            case .storyEditor:
                guard !controller.node.recording.isActive else {
                    return
                }
                guard controller.checkCaptionLimit() else {
                    return
                }
                if controller.isEditingStory || controller.isEditingStoryCover {
                    controller.requestStoryCompletion(animated: true)
                } else {
                    if controller.checkIfCompletionIsAllowed() {
                        controller.hapticFeedback.impact(.light)
                        controller.openPrivacySettings(completion: { [weak controller] in
                            controller?.requestStoryCompletion(animated: true)
                        })
                    }
                }
            case .stickerEditor:
                controller.requestStickerCompletion(animated: true)
            case .coverEditor:
                controller.requestCoverCompletion(animated: true)
            case .botPreview:
                controller.requestStoryCompletion(animated: true)
            case .avatarEditor:
                controller.requestStoryCompletion(animated: true)
            }
        }
        
        func openCoverSelection(exclusive: Bool) {
            guard let portalView = PortalView(matchPosition: false) else {
                return
            }
            portalView.view.layer.rasterizationScale = UIScreenScale
            self.previewContentContainerView.addPortal(view: portalView)
            
            let scale = 48.0 / self.previewContentContainerView.frame.height
            portalView.view.transform = CGAffineTransformMakeScale(scale, scale)
            
            if self.entitiesView.hasSelection {
                self.entitiesView.selectEntity(nil)
            }
            let coverController = MediaCoverScreen(
                context: self.context,
                mediaEditor: self.mediaEditorPromise.get(),
                previewView: self.previewView,
                portalView: portalView,
                exclusive: exclusive
            )
            coverController.dismissed = { [weak self] in
                if let self {
                    if exclusive {
                        self.controller?.requestDismiss(saveDraft: false, animated: true)
                    } else {
                        self.animateInFromTool()
                        self.requestCompletion(playHaptic: false)
                    }
                }
            }
            coverController.completed = { [weak self] position, image in
                if let self {
                    self.controller?.currentCoverImage = image
                    if exclusive {
                        self.requestCompletion()
                    }
                }
            }
            self.controller?.present(coverController, in: .current)
            self.coverScreen = coverController
            
            if exclusive {
                self.isDisplayingTool = .cover
                self.requestUpdate(transition: .immediate)
            } else {
                self.animateOutToTool(tool: .cover)
            }
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
            if result == self.componentHostView {
                let point = self.view.convert(point, to: self.previewContainerView)
                if let previewResult = self.previewContainerView.hitTest(point, with: event) {
                    return previewResult
                }
            }
            return result
        }
        
        func requestUpdate(hasAppeared: Bool = false, transition: ComponentTransition = .immediate) {
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout: layout, hasAppeared: hasAppeared, transition: transition)
            }
        }
        
        private func adjustPreviewZoom(updating: Bool = false) {
            let minScale: CGFloat = 0.05
            let maxScale: CGFloat = 3.0
            
            if self.previewScrollView.minimumZoomScale != minScale {
                self.previewScrollView.minimumZoomScale = minScale
            }
            if self.previewScrollView.maximumZoomScale != maxScale {
                self.previewScrollView.maximumZoomScale = maxScale
            }
            
            let boundsSize = self.previewScrollView.frame.size
            var contentFrame = self.previewContentContainerView.frame
            if boundsSize.width > contentFrame.size.width {
                contentFrame.origin.x = (boundsSize.width - contentFrame.size.width) / 2.0
            } else {
                contentFrame.origin.x = 0.0
            }
            
            if boundsSize.height > contentFrame.size.height {
                contentFrame.origin.y = (boundsSize.height - contentFrame.size.height) / 2.0
            } else {
                contentFrame.origin.y = 0.0
            }
            self.previewContentContainerView.frame = contentFrame
            
            if !updating {
                self.stickerMaskDrawingView?.updateZoomScale(self.previewScrollView.zoomScale)
            }
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            self.adjustPreviewZoom()
        }
        
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            self.adjustPreviewZoom()
            
            if scrollView.zoomScale < 1.0 {
                scrollView.setZoomScale(1.0, animated: true)
            }
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return self.previewContentContainerView
        }
        
        private var isCollageTimelineOpen = false
        func openCollageTimeline() {
            self.isCollageTimelineOpen = true
            self.requestLayout(forceUpdate: true, transition: .spring(duration: 0.4))
        }
                
        func highlightCollageItem(trackId: Int32) {
            if let collageIndex = self.mediaEditor?.collageItemIndexForTrackId(trackId), let frame = self.mediaEditor?.values.collage[collageIndex].frame {
                let mappedFrame = CGRect(
                    x: frame.minX / storyDimensions.width * self.previewContainerView.bounds.width,
                    y: frame.minY / storyDimensions.height * self.previewContainerView.bounds.height,
                    width: frame.width / storyDimensions.width * self.previewContainerView.bounds.width,
                    height: frame.height / storyDimensions.height * self.previewContainerView.bounds.height
                )
                
                var corners: CACornerMask = []
                if frame.minX <= .ulpOfOne && frame.minY <= .ulpOfOne {
                    corners.insert(.layerMinXMinYCorner)
                }
                if frame.minX <= .ulpOfOne && frame.maxY >= storyDimensions.height - .ulpOfOne {
                    corners.insert(.layerMinXMaxYCorner)
                }
                if frame.maxX >= storyDimensions.width - .ulpOfOne && frame.minY <= .ulpOfOne {
                    corners.insert(.layerMaxXMinYCorner)
                }
                if frame.maxX >= storyDimensions.width - .ulpOfOne && frame.maxY >= storyDimensions.height - .ulpOfOne {
                    corners.insert(.layerMaxXMaxYCorner)
                }
                
                let highlightView = CollageHighlightView()
                highlightView.update(size: mappedFrame.size, corners: corners, completion: { [weak highlightView] in
                    highlightView?.removeFromSuperview()
                })
                highlightView.frame = mappedFrame
                self.previewContainerView.addSubview(highlightView)
            }
        }
        
        func requestLayout(forceUpdate: Bool, transition: ComponentTransition) {
            guard let layout = self.validLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, forceUpdate: forceUpdate, hasAppeared: self.hasAppeared, transition: transition)
        }
                
        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, hasAppeared: Bool = false, transition: ComponentTransition) {
            guard let controller = self.controller, !self.isDismissed else {
                return
            }
            let isFirstTime = self.validLayout == nil
            self.validLayout = layout
            
            let isTablet = layout.metrics.isTablet

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
                additionalInsets: layout.additionalInsets,
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
                
                self.presentSelectionTooltip()
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
                        isCollageTimelineOpen: self.isCollageTimelineOpen,
                        hasAppeared: self.hasAppeared,
                        isDismissing: self.isDismissing && !self.isDismissBySwipeSuppressed,
                        bottomSafeInset: layout.intrinsicInsets.bottom,
                        mediaEditor: self.mediaEditorPromise.get(),
                        privacy: controller.state.privacy,
                        selectedEntity: self.isDisplayingTool != nil ? nil : self.entitiesView.selectedEntityView?.entity,
                        entityViewForEntity: { [weak self] entity in
                            if let self {
                                return self.entitiesView.getView(for: entity.uuid)
                            } else {
                                return nil
                            }
                        },
                        openDrawing: { [weak self] mode in
                            if let self, let mediaEditor = self.mediaEditor {
                                if self.entitiesView.hasSelection {
                                    self.entitiesView.selectEntity(nil)
                                }
                                switch mode {
                                case .sticker:
                                    mediaEditor.maybePauseVideo()

                                    var hasInteractiveStickers = true
                                    if let controller = self.controller {
                                        switch controller.mode {
                                        case .stickerEditor, .botPreview, .avatarEditor, .coverEditor:
                                            hasInteractiveStickers = false
                                        default:
                                            break
                                        }
                                    }
                                    
                                    let editorConfiguration = MediaEditorConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
                                    
                                    var weatherSignal: Signal<StickerPickerScreen.Weather, NoError>
                                    if hasInteractiveStickers {
                                        let weatherPromise: Promise<StickerPickerScreen.Weather>
                                        if let current = self.weatherPromise {
                                            weatherPromise = current
                                        } else {
                                            weatherPromise = Promise()
                                            weatherPromise.set(getWeather(context: self.context, load: editorConfiguration.preloadWeather))
                                            self.weatherPromise = weatherPromise
                                        }
                                        weatherSignal = weatherPromise.get()
                                    } else {
                                        weatherSignal = .single(.none)
                                    }
                                    
                                    let controller = StickerPickerScreen(context: self.context, inputData: self.stickerPickerInputData.get(), forceDark: true, defaultToEmoji: self.defaultToEmoji, hasGifs: true, hasInteractiveStickers: hasInteractiveStickers, weather: weatherSignal)
                                    controller.completion = { [weak self] content in
                                        guard let self else {
                                            return false
                                        }
                                        if let content {
                                            if case let .file(file, _) = content {
                                                self.defaultToEmoji = file.media.isCustomEmoji
                                            }
                                                                                            
                                            let stickerEntity = DrawingStickerEntity(content: content)
                                            let scale: CGFloat
                                            if case .image = content {
                                                scale = 2.5
                                            } else if case .video = content {
                                                scale = 2.5
                                            } else {
                                                scale = 1.33
                                            }
                                            self.interaction?.insertEntity(stickerEntity, scale: scale)
                                            
                                            self.hasAnyChanges = true
                                            self.controller?.isSavingAvailable = true
                                            self.controller?.requestLayout(transition: .immediate)
                                        }
                                        self.stickerScreen = nil
                                        self.mediaEditor?.maybeUnpauseVideo()
                                        return true
                                    }
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
                                    controller.presentAudioPicker = { [weak self, weak controller] in
                                        if let self {
                                            self.stickerScreen = nil
                                            controller?.dismiss(animated: true)
                                            self.presentAudioPicker()
                                        }
                                    }
                                    controller.addReaction = { [weak self, weak controller] in
                                        if let self {
                                            self.addReaction()
                                            
                                            self.stickerScreen = nil
                                            controller?.dismiss(animated: true)
                                        }
                                    }
                                    controller.addLink = { [weak self, weak controller] in
                                        if let self {
                                            self.addOrEditLink()
                                            
                                            self.stickerScreen = nil
                                            controller?.dismiss(animated: true)
                                        }
                                    }
                                    controller.addWeather = { [weak self, weak controller] in
                                        if let self {
                                            if let weatherPromise = self.weatherPromise {
                                                let _ = (weatherPromise.get()
                                                |> take(1)).start(next: { [weak self] result in
                                                    if let self {
                                                        switch result {
                                                        case let .loaded(weather):
                                                            self.addWeather(weather)
                                                        case .notPreloaded:
                                                            weatherPromise.set(getWeather(context: self.context, load: true))
                                                            let _ = (weatherPromise.get()
                                                            |> take(1)).start(next: { [weak self] result in
                                                                if let self, case let .loaded(weather) = result {
                                                                    self.addWeather(weather)
                                                                }
                                                            })
                                                        case .notDetermined, .notAllowed:
                                                            self.presentLocationAccessAlert()
                                                        default:
                                                            break
                                                        }
                                                    }
                                                })
                                            }
                                            
                                            self.stickerScreen = nil
                                            controller?.dismiss(animated: true)
                                        }
                                    }
                                    controller.pushController = { [weak self] c in
                                        self?.controller?.push(c)
                                    }
                                    self.stickerScreen = controller
                                    self.controller?.present(controller, in: .current)
                                case .text:
                                    mediaEditor.maybePauseVideo()
                                    self.insertTextEntity()
                                    
                                    self.hasAnyChanges = true
                                    self.controller?.isSavingAvailable = true
                                    self.controller?.requestLayout(transition: .immediate)
                                case .drawing:
                                    self.previousDrawingData = self.drawingView.drawingData
                                    self.previousDrawingEntities = self.entitiesView.entities
                                    
                                    self.cropScrollView?.isUserInteractionEnabled = false
                                    
                                    self.interaction?.deactivate()
                                    let controller = DrawingScreen(
                                        context: self.context,
                                        sourceHint: .storyEditor,
                                        size: self.previewContainerView.bounds.size,
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
                                        
                                        self.cropScrollView?.isUserInteractionEnabled = true
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
                                        
                                        self.cropScrollView?.isUserInteractionEnabled = true
                                    }
                                    self.controller?.present(controller, in: .current)
                                    self.animateOutToTool(tool: mode)
                                case .cutout, .cutoutErase, .cutoutRestore:
                                    let cutoutMode: MediaCutoutScreen.Mode
                                    switch mode {
                                    case .cutout:
                                        cutoutMode = .cutout
                                    case .cutoutErase:
                                        cutoutMode = .erase
                                    case .cutoutRestore:
                                        cutoutMode = .restore
                                    default:
                                        cutoutMode = .cutout
                                    }
                                    
                                    if self.isDisplayingTool != nil {
                                        guard self.isDisplayingTool != mode else {
                                            return
                                        }
                                        self.isDisplayingTool = mode
                                        self.cutoutScreen?.mode = cutoutMode
                                        self.requestUpdate(transition: .easeInOut(duration: 0.2))
                                        return
                                    }
                                    guard let mediaEditor = self.mediaEditor, let stickerMaskDrawingView = self.stickerMaskDrawingView, let stickerBackgroundView = self.stickerBackgroundView else {
                                        return
                                    }
                                    
                                    if [.cutoutErase, .cutoutRestore].contains(mode) {
                                        self.previewScrollView.isScrollEnabled = true
                                        self.previewScrollView.pinchGestureRecognizer?.isEnabled = true
                                    }
                                    
                                    let cutoutController = MediaCutoutScreen(
                                        context: self.context,
                                        mode: cutoutMode,
                                        mediaEditor: mediaEditor,
                                        previewView: self.previewView,
                                        maskWrapperView: self.stickerMaskWrapperView,
                                        drawingView: stickerMaskDrawingView,
                                        overlayView: self.stickerMaskPreviewView,
                                        backgroundView: stickerBackgroundView
                                    )
                                    cutoutController.completedWithCutout = { [weak self] in
                                        if let self {
                                            self.isCutout = true
                                            self.requestLayout(forceUpdate: true, transition: .immediate)
                                        }
                                    }
                                    cutoutController.completed = { [weak self] in
                                        if let self {
                                            self.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.25))
                                        }
                                    }
                                    cutoutController.dismissed = { [weak self] in
                                        if let self {
                                            self.previewScrollView.setZoomScale(1.0, animated: true)
                                            self.previewScrollView.isScrollEnabled = false
                                            self.previewScrollView.pinchGestureRecognizer?.isEnabled = false
                                            self.animateInFromTool(inPlace: true)
                                        }
                                    }
                                    self.controller?.present(cutoutController, in: .window(.root))
                                    self.cutoutScreen = cutoutController
                                    self.animateOutToTool(tool: mode, inPlace: true)
                                    
                                    self.controller?.hapticFeedback.impact(.medium)
                                case .tools:
                                    if self.entitiesView.hasSelection {
                                        self.entitiesView.selectEntity(nil)
                                    }
                                    var hiddenTools: [EditorToolKey] = []
                                    if !self.canEnhance {
                                        hiddenTools.append(.enhance)
                                    }
                                    if let controller = self.controller, case .stickerEditor = controller.mode {
                                        hiddenTools.append(.grain)
                                        hiddenTools.append(.vignette)
                                    }
                                    let controller = MediaToolsScreen(context: self.context, mediaEditor: mediaEditor, hiddenTools: hiddenTools)
                                    controller.dismissed = { [weak self] in
                                        if let self {
                                            self.animateInFromTool()
                                        }
                                    }
                                    self.controller?.present(controller, in: .window(.root))
                                    self.animateOutToTool(tool: .tools)
                                case .cover:
                                    self.openCoverSelection(exclusive: false)
                                }
                            }
                        },
                        cutoutUndo: { [weak self] in
                            if let self, let mediaEditor = self.mediaEditor, let stickerMaskDrawingView = self.stickerMaskDrawingView {
                                if self.entitiesView.hasSelection {
                                    self.entitiesView.selectEntity(nil)
                                }
                                
                                if stickerMaskDrawingView.internalState.canUndo {
                                    stickerMaskDrawingView.performAction(.undo)
                                    if let drawingImage = stickerMaskDrawingView.drawingImage {
                                        mediaEditor.setSegmentationMask(drawingImage)
                                    }
                                    
                                    if self.isDisplayingTool == .cutoutRestore && !stickerMaskDrawingView.internalState.canUndo && !self.isCutout {
                                        self.cutoutScreen?.mode = .erase
                                        self.isDisplayingTool = .cutoutErase
                                        self.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.25))
                                    }
                                } else if self.isCutout {
                                    let action = { [weak self, weak mediaEditor] in
                                        guard let self, let mediaEditor else {
                                            return
                                        }
                                        let snapshotView = self.previewView.snapshotView(afterScreenUpdates: false)
                                        if let snapshotView {
                                            self.previewView.superview?.insertSubview(snapshotView, aboveSubview: self.previewView)
                                        }
                                        self.previewView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, completion: { _ in
                                            snapshotView?.removeFromSuperview()
                                        })
                                        mediaEditor.removeSegmentationMask()
                                        self.stickerMaskDrawingView?.clearWithEmptyColor()
                                        
                                        self.isCutout = false
                                        self.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.25))
                                    }
                                    
                                    if let value = mediaEditor.getToolValue(.stickerOutline) as? Float, value > 0.0 {
                                        mediaEditor.setToolValue(.stickerOutline, value: nil)
                                        mediaEditor.setOnNextDisplay {
                                            action()
                                        }
                                    } else {
                                        action()
                                    }
                                    
                                    if let cutoutScreen = self.cutoutScreen {
                                        cutoutScreen.requestDismiss(animated: true)
                                    }
                                }
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
                    if self.entitiesView.selectedEntityView != nil || self.isDisplayingTool != nil {
                        bottomInputOffset = inputHeight / 2.0
                    } else {
                        bottomInputOffset = 0.0
                    }
                }
            }
            
            transition.setPosition(view: self.containerView, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0))
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: .zero, size: layout.size))
            
            var previewFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - previewSize.width) / 2.0), y: topInset - bottomInputOffset + self.dismissOffset), size: previewSize)
            if layout.size.height < 680.0, case .stickerEditor = controller.mode {
                previewFrame = previewFrame.offsetBy(dx: 0.0, dy: -44.0)
            }
            
            var previewScale: CGFloat = 1.0
            var previewOffset: CGFloat = 0.0
            if self.componentExternalState.timelineHeight > 0.0 {
                let clippedHeight = previewFrame.size.height - self.componentExternalState.timelineHeight
                previewOffset = -self.componentExternalState.timelineHeight / 2.0
                previewScale = clippedHeight / previewFrame.size.height
            }
            
            transition.setBounds(view: self.previewContainerView, bounds: CGRect(origin: .zero, size: previewFrame.size))
            transition.setPosition(view: self.previewContainerView, position: previewFrame.center.offsetBy(dx: 0.0, dy: previewOffset))
            transition.setScale(view: self.previewContainerView, scale: previewScale)
            
            transition.setFrame(view: self.previewScrollView, frame: CGRect(origin: .zero, size: previewSize))
            
            if self.previewScrollView.contentSize == .zero {
                self.previewScrollView.zoomScale = 1.0
                self.previewScrollView.contentSize = previewSize
            }
            
            if abs(self.previewContentContainerView.bounds.width - previewSize.width) > 1.0 {
                transition.setFrame(view: self.previewContentContainerView, frame: CGRect(origin: .zero, size: previewSize))
            }
            
            self.adjustPreviewZoom(updating: true)
            transition.setFrame(view: self.previewView, frame: CGRect(origin: .zero, size: previewSize))
            
            let entitiesViewScale = previewSize.width / storyDimensions.width
            self.entitiesContainerView.transform = CGAffineTransformMakeScale(entitiesViewScale, entitiesViewScale)
            self.entitiesContainerView.frame = CGRect(origin: .zero, size: previewFrame.size)
            transition.setFrame(view: self.gradientView, frame: CGRect(origin: .zero, size: previewFrame.size))
            transition.setFrame(view: self.drawingView, frame: CGRect(origin: .zero, size: self.entitiesView.bounds.size))
                        
            transition.setFrame(view: self.selectionContainerView, frame: CGRect(origin: .zero, size: previewFrame.size))
            
            if let stickerBackgroundView = self.stickerBackgroundView, let stickerOverlayLayer = self.stickerOverlayLayer, let stickerFrameLayer = self.stickerFrameLayer {
                let stickerFrameFraction: CGFloat
                switch controller.mode {
                case .stickerEditor:
                    stickerFrameFraction = 0.97
                default:
                    stickerFrameFraction = 1.0
                }

                let stickerFrameWidth = floorToScreenPixels(previewSize.width * stickerFrameFraction)
                stickerOverlayLayer.frame = CGRect(origin: .zero, size: previewSize)
                
                let stickerFrameRect = CGRect(
                    origin: CGPoint(x: floorToScreenPixels((previewSize.width - stickerFrameWidth) / 2.0), y: floorToScreenPixels((previewSize.height - stickerFrameWidth) / 2.0)),
                    size: CGSize(width: stickerFrameWidth, height: stickerFrameWidth)
                )
                 
                let overlayOuterRect = UIBezierPath(rect: CGRect(origin: .zero, size: previewSize))
                let overlayInnerRect: UIBezierPath
                
                var cropScrollRect = CGSize(width: previewSize.width, height: previewSize.width).centered(around: stickerFrameRect.center)
                
                switch controller.mode {
                case .avatarEditor:
                    overlayInnerRect = UIBezierPath(cgPath: CGPath(ellipseIn: stickerFrameRect, transform: nil))
                    stickerFrameLayer.isHidden = true
                case let .coverEditor(dimensions):
                    let fittedSize: CGSize
                    if dimensions.width > dimensions.height {
                        fittedSize = dimensions.aspectFitted(stickerFrameRect.size)
                    } else {
                        fittedSize = dimensions.aspectFilled(stickerFrameRect.size)
                    }
                    overlayInnerRect = UIBezierPath(rect: fittedSize.centered(around: stickerFrameRect.center))
                    stickerFrameLayer.isHidden = true
                    
                    cropScrollRect = fittedSize.centered(around: stickerFrameRect.center)
                default:
                    overlayInnerRect = UIBezierPath(cgPath: CGPath(roundedRect: stickerFrameRect, cornerWidth: stickerFrameWidth / 8.0, cornerHeight: stickerFrameWidth / 8.0, transform: nil))
                }
                
                let overlayLineWidth: CGFloat = 2.0 - UIScreenPixel
                overlayOuterRect.append(overlayInnerRect)
                overlayOuterRect.usesEvenOddFillRule = true
                stickerOverlayLayer.path = overlayOuterRect.cgPath
                
                stickerFrameLayer.frame = stickerOverlayLayer.frame
                stickerFrameLayer.lineWidth = overlayLineWidth
                stickerFrameLayer.path = CGPath(roundedRect: stickerFrameRect.insetBy(dx: -overlayLineWidth / 2.0, dy: -overlayLineWidth / 2.0), cornerWidth: stickerFrameWidth / 8.0 * 1.02, cornerHeight: stickerFrameWidth / 8.0 * 1.02, transform: nil)
                
                transition.setFrame(view: stickerBackgroundView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((previewSize.width - stickerFrameWidth) / 2.0), y: floorToScreenPixels((previewSize.height - stickerFrameWidth) / 2.0)), size: CGSize(width: stickerFrameWidth, height: stickerFrameWidth)))
                stickerBackgroundView.layer.cornerRadius = stickerFrameWidth / 8.0
                
                if let cropScrollView = self.cropScrollView {
                    cropScrollView.frame = cropScrollRect
                    if cropScrollView.superview == nil {
                        self.previewContainerView.addSubview(cropScrollView)
                        
                        if let dimensions = self.subject?.dimensions {
                            let filledCropSize = dimensions.cgSize.aspectFilled(cropScrollRect.size)
                            cropScrollView.setContentSize(filledCropSize)
                        }
                    }
                }
            }
            
            self.interaction?.containerLayoutUpdated(layout: layout, transition: transition)
            
            var layout = layout
            layout.intrinsicInsets.top = topInset
            controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
            
            if isFirstTime {
                self.isHidden = true
                let _ = (self.readyValue.get()
                |> take(1)).start(next: { [weak self] _ in
                    if let self {
                        self.isHidden = false
                        self.animateIn()
                    }
                })
            }
        }
    }
    
    var node: Node {
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
        public struct VideoCollageItem {
            public enum Content {
                case image(UIImage)
                case video(String, Double)
                case asset(PHAsset)
                
                var editorContent: MediaEditor.Subject.VideoCollageItem.Content {
                    switch self {
                    case let .image(image):
                        return .image(image)
                    case let .video(path, duration):
                        return .video(path, duration)
                    case let .asset(asset):
                        return .asset(asset)
                    }
                }
                
                var duration: Double {
                    switch self {
                    case .image:
                        return 0.0
                    case let .video(_, duration):
                        return duration
                    case let .asset(asset):
                        return asset.duration
                    }
                }
            }
            public let content: Content
            public let frame: CGRect
            public let contentScale: CGFloat
            public let contentOffset: CGPoint
            
            var editorItem: MediaEditor.Subject.VideoCollageItem {
                return MediaEditor.Subject.VideoCollageItem(
                    content: self.content.editorContent,
                    frame: self.frame,
                    contentScale: self.contentScale,
                    contentOffset: self.contentOffset
                )
            }
            
            public init(
                content: Content,
                frame: CGRect,
                contentScale: CGFloat,
                contentOffset: CGPoint
            ) {
                self.content = content
                self.frame = frame
                self.contentScale = contentScale
                self.contentOffset = contentOffset
            }
        }
        
        case empty(PixelDimensions)
        case image(image: UIImage, dimensions: PixelDimensions, additionalImage: UIImage?, additionalImagePosition: PIPPosition, fromCamera: Bool)
        case video(videoPath: String, thumbnail: UIImage?, mirror: Bool, additionalVideoPath: String?, additionalThumbnail: UIImage?, dimensions: PixelDimensions, duration: Double, videoPositionChanges: [(Bool, Double)], additionalVideoPosition: PIPPosition, fromCamera: Bool)
        case videoCollage(items: [VideoCollageItem])
        case asset(PHAsset)
        case draft(MediaEditorDraft, Int64?)
        case message([MessageId])
        case gift(StarGift.UniqueGift)
        case sticker(TelegramMediaFile, [String])
        case multiple([Subject])
        
        var sourceIdentifier: String {
            switch self {
            case let .image(image, _, _, _, _):
                return "\(Unmanaged.passUnretained(image).toOpaque())"
            case let .video(videoPath, _, _, _, _, _, _, _, _, _):
                return videoPath
            case let .asset(asset):
                return asset.localIdentifier
            default:
                fatalError()
            }
        }
        
        var dimensions: PixelDimensions {
            switch self {
            case let .empty(dimensions):
                return dimensions
            case let .image(_, dimensions, _, _, _), let .video(_, _, _, _, _, dimensions, _, _, _, _):
                return dimensions
            case let .asset(asset):
                return PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
            case let .draft(draft, _):
                return draft.dimensions
            case .message, .gift, .sticker, .videoCollage, .multiple:
                return PixelDimensions(storyDimensions)
            }
        }
        
        var editorSubject: MediaEditor.Subject {
            switch self {
            case let .empty(dimensions):
                let image = generateImage(dimensions.cgSize, opaque: false, scale: 1.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                })!
                return .image(image, dimensions)
            case let .image(image, dimensions, _, _, _):
                return .image(image, dimensions)
            case let .video(videoPath, transitionImage, mirror, additionalVideoPath, _, dimensions, duration, _, _, _):
                return .video(videoPath, transitionImage, mirror, additionalVideoPath, dimensions, duration)
            case let .videoCollage(items):
                return .videoCollage(items.map { $0.editorItem })
            case let .asset(asset):
                return .asset(asset)
            case let .draft(draft, _):
                return .draft(draft)
            case let .message(messageIds):
                return .message(messageIds.first!)
            case let .gift(gift):
                return .gift(gift)
            case let .sticker(sticker, _):
                return .sticker(sticker)
            case let .multiple(subjects):
                return subjects.first!.editorSubject
            }
        }
        
        var isPhoto: Bool {
            return !self.isVideo
        }
        
        var isVideo: Bool {
            switch self {
            case .empty:
                return false
            case .image:
                return false
            case .video:
                return true
            case .videoCollage:
                return true
            case let .asset(asset):
                return asset.mediaType == .video
            case let .draft(draft, _):
                return draft.isVideo
            case .message:
                return false
            case .gift:
                return false
            case .sticker:
                return false
            case .multiple:
                return false
            }
        }
    }
    
    public enum MediaResult {
        public enum VideoResult {
            case imageFile(path: String)
            case videoFile(path: String)
            case asset(localIdentifier: String)
        }
        
        case image(image: UIImage, dimensions: PixelDimensions)
        case video(video: VideoResult, coverImage: UIImage?, values: MediaEditorValues, duration: Double, dimensions: PixelDimensions)
        case sticker(file: TelegramMediaFile, emoji: [String])
    }
    
    public struct Result {
        public let media: MediaResult?
        public let mediaAreas: [MediaArea]
        public let caption: NSAttributedString
        public let coverTimestamp: Double?
        public let options: MediaEditorResultPrivacy
        public let stickers: [TelegramMediaFile]
        public let randomId: Int64
        
        init() {
            self.media = nil
            self.mediaAreas = []
            self.caption = NSAttributedString()
            self.coverTimestamp = nil
            self.options = MediaEditorResultPrivacy(sendAsPeerId: nil, privacy: EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: []), timeout: 0, isForwardingDisabled: false, pin: false)
            self.stickers = []
            self.randomId = 0
        }
        
        init(
            media: MediaResult?,
            mediaAreas: [MediaArea] = [],
            caption: NSAttributedString = NSAttributedString(),
            coverTimestamp: Double? = nil,
            options: MediaEditorResultPrivacy = MediaEditorResultPrivacy(sendAsPeerId: nil, privacy: EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: []), timeout: 0, isForwardingDisabled: false, pin: false),
            stickers: [TelegramMediaFile] = [],
            randomId: Int64 = 0
        ) {
            self.media = media
            self.mediaAreas = mediaAreas
            self.caption = caption
            self.coverTimestamp = coverTimestamp
            self.options = options
            self.stickers = stickers
            self.randomId = randomId
        }
    }
    
    let context: AccountContext
    let mode: Mode
    let subject: Signal<Subject?, NoError>
    let isEditingStory: Bool
    let isEditingStoryCover: Bool
    fileprivate let customTarget: EnginePeer.Id?
    let forwardSource: (EnginePeer, EngineStoryItem)?
    
    let initialCaption: NSAttributedString?
    let initialPrivacy: EngineStoryPrivacy?
    let initialMediaAreas: [MediaArea]?
    let initialVideoPosition: Double?
    let initialLink: (url: String, name: String?)?
    
    fileprivate let transitionIn: TransitionIn?
    fileprivate let transitionOut: (Bool, Bool?) -> TransitionOut?
        
    var didComplete = false
    
    public var cancelled: (Bool) -> Void = { _ in }
    public var willComplete: (UIImage?, Bool, @escaping () -> Void) -> Void
    public var completion: ([MediaEditorScreenImpl.Result], @escaping (@escaping () -> Void) -> Void) -> Void
    public var dismissed: () -> Void = { }
    public var willDismiss: () -> Void = { }
    public var sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?
    
    private var adminedChannels = Promise<[EnginePeer]>()
    private var closeFriends = Promise<[EnginePeer]>()
    private let storiesBlockedPeers: BlockedPeersContext
    
    fileprivate let hapticFeedback = HapticFeedback()
    
    private var audioSessionDisposable: Disposable?
    private let postingAvailabilityPromise = Promise<StoriesUploadAvailability>()
    private var postingAvailabilityDisposable: Disposable?
    
    fileprivate var myStickerPacks: [(StickerPackCollectionInfo, StickerPackItem?)] = []
    private var myStickerPacksDisposable: Disposable?
            
    public init(
        context: AccountContext,
        mode: Mode,
        subject: Signal<Subject?, NoError>,
        customTarget: EnginePeer.Id? = nil,
        isEditing: Bool = false,
        isEditingCover: Bool = false,
        forwardSource: (EnginePeer, EngineStoryItem)? = nil,
        initialCaption: NSAttributedString? = nil,
        initialPrivacy: EngineStoryPrivacy? = nil,
        initialMediaAreas: [MediaArea]? = nil,
        initialVideoPosition: Double? = nil,
        initialLink: (url: String, name: String?)? = nil,
        transitionIn: TransitionIn?,
        transitionOut: @escaping (Bool, Bool?) -> TransitionOut?,
        willComplete: @escaping (UIImage?, Bool, @escaping () -> Void) -> Void = { _, _, commit in commit() },
        completion: @escaping ([MediaEditorScreenImpl.Result], @escaping (@escaping () -> Void) -> Void) -> Void
    ) {
        self.context = context
        self.mode = mode
        self.subject = subject
        self.customTarget = customTarget
        self.isEditingStory = isEditing
        self.isEditingStoryCover = isEditingCover
        self.forwardSource = forwardSource
        self.initialCaption = initialCaption
        self.initialPrivacy = initialPrivacy
        self.initialMediaAreas = initialMediaAreas
        self.initialVideoPosition = initialVideoPosition
        self.initialLink = initialLink
        self.transitionIn = transitionIn
        self.transitionOut = transitionOut
        self.willComplete = willComplete
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
                    sendAsPeerId: nil,
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
                        privacy = MediaEditorResultPrivacy(sendAsPeerId: nil, privacy: privacy.privacy, timeout: 86400, isForwardingDisabled: privacy.isForwardingDisabled, pin: privacy.pin)
                    } else {
                        privacy = MediaEditorResultPrivacy(sendAsPeerId: nil, privacy: privacy.privacy, timeout: privacy.timeout, isForwardingDisabled: privacy.isForwardingDisabled, pin: privacy.pin)
                    }
                    self.state.privacy = privacy
                }
            })
        }
        
        updateStorySources(engine: self.context.engine)
        updateStoryDrafts(engine: self.context.engine)
        
        if case .stickerEditor = mode {
            self.myStickerPacksDisposable = (self.context.engine.stickers.getMyStickerSets()
            |> deliverOnMainQueue).start(next: { [weak self] packs in
                guard let self else {
                    return
                }
                self.myStickerPacks = packs
            })
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.exportDisposable.dispose()
        self.audioSessionDisposable?.dispose()
        self.postingAvailabilityDisposable?.dispose()
        self.myStickerPacksDisposable?.dispose()
    }
    
    fileprivate func setupAudioSessionIfNeeded() {
        guard let subject = self.node.subject else {
            return
        }
        var needsAudioSession = false
        var checkPostingAvailability = false
        if self.forwardSource != nil {
            needsAudioSession = true
            checkPostingAvailability = true
        }
        if self.isEditingStory {
            needsAudioSession = true
        }
        switch subject {
        case .message, .gift:
            needsAudioSession = true
            checkPostingAvailability = true
        default:
            break
        }
        if needsAudioSession {
            self.audioSessionDisposable = self.context.sharedContext.mediaManager.audioSession.push(audioSessionType: .record(speaker: false, video: true, withOthers: true), activate: { _ in
                if #available(iOS 13.0, *) {
                    try? AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(true)
                }
            }, deactivate: { _ in
                return .single(Void())
            })
        }
        if checkPostingAvailability {
            self.postingAvailabilityPromise.set(self.context.engine.messages.checkStoriesUploadAvailability(target: .myStories))
        }
    }
    
    fileprivate func checkPostingAvailability() {
        guard self.postingAvailabilityDisposable == nil && !self.isEditingStory else {
            return
        }
        self.postingAvailabilityDisposable = (self.postingAvailabilityPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] availability in
            guard let self else {
                return
            }
            if case .available = availability {
                return
            }
            
            let subject: PremiumLimitSubject
            switch availability {
            case .expiringLimit:
                subject = .expiringStories
            case .weeklyLimit:
                subject = .storiesWeekly
            case .monthlyLimit:
                subject = .storiesMonthly
            default:
                subject = .expiringStories
            }
            
            let context = self.context
            var replaceImpl: ((ViewController) -> Void)?
            let controller = self.context.sharedContext.makePremiumLimitController(context: self.context, subject: subject, count: 10, forceDark: true, cancel: { [weak self] in
                self?.requestDismiss(saveDraft: false, animated: true)
            }, action: { [weak self] in
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .stories, forceDark: true, dismissed: { [weak self] in
                    guard let self else {
                        return
                    }
                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                        guard let self else {
                            return
                        }
                        let isPremium = peer?.isPremium ?? false
                        if !isPremium {
                            self.requestDismiss(saveDraft: false, animated: true)
                        }
                    })
                })
                replaceImpl?(controller)
                return true
            })
            replaceImpl = { [weak controller] c in
                controller?.replace(with: c)
            }
            if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
                navigationController.pushViewController(controller)
            }
        })
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
        
        let dropInteraction = UIDropInteraction(delegate: self)
        self.displayNode.view.addInteraction(dropInteraction)
        
        Queue.mainQueue().after(0.4) {
            self.adminedChannels.set(.single([]) |> then(self.context.engine.peers.channelsForStories()))
            self.closeFriends.set(self.context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.CloseFriends()))
        }
    }
    
    var isEmbeddedEditor: Bool {
        return self.isEditingStory || self.isEditingStoryCover || self.forwardSource != nil
    }
     
    private var currentCoverImage: UIImage?
    func openPrivacySettings(_ privacy: MediaEditorResultPrivacy? = nil, completion: @escaping () -> Void = {}) {
        guard let mediaEditor = self.node.mediaEditor else {
            return
        }
        mediaEditor.maybePauseVideo()
        mediaEditor.seek(mediaEditor.values.videoTrimRange?.lowerBound ?? 0.0, andPlay: false)
            
        let privacy = privacy ?? self.state.privacy
        
        let text = self.node.getCaption().string
        let mentions = generateTextEntities(text, enabledTypes: [.mention], currentEntities: []).map { (text as NSString).substring(with: NSRange(location: $0.range.lowerBound + 1, length: $0.range.upperBound - $0.range.lowerBound - 1)) }
                
        let coverImage: UIImage?
        if mediaEditor.sourceIsVideo {
            coverImage = self.currentCoverImage ?? mediaEditor.resultImage
        } else {
            coverImage = nil
        }
        
        var storyCount: Int32 = 0
        if self.node.items.count > 0 {
            storyCount = Int32(self.node.items.count(where: { $0.isEnabled }))
        } else {
            if case let .asset(asset) = self.node.subject {
                let duration: Double
                if let playerDuration = mediaEditor.duration {
                    duration = playerDuration
                } else {
                    duration = asset.duration
                }
                if duration > storyMaxVideoDuration {
                    storyCount = Int32(min(storyMaxCombinedVideoCount, Int(ceil(duration / storyMaxVideoDuration))))
                }
            }
        }
        
        let stateContext = ShareWithPeersScreen.StateContext(
            context: self.context,
            subject: .stories(editing: false, count: storyCount),
            editing: false,
            initialPeerIds: Set(privacy.privacy.additionallyIncludePeers),
            closeFriends: self.closeFriends.get(),
            adminedChannels: self.adminedChannels.get(),
            blockedPeersContext: self.storiesBlockedPeers
        )
        let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).startStandalone(next: { [weak self] _ in
            guard let self else {
                return
            }
            let sendAsPeerId = privacy.sendAsPeerId
            let initialPrivacy = privacy.privacy
            let timeout = privacy.timeout
            
            var editCoverImpl: (() -> Void)?
            
            let controller = ShareWithPeersScreen(
                context: self.context,
                initialPrivacy: initialPrivacy,
                initialSendAsPeerId: self.customTarget,
                allowScreenshots: !privacy.isForwardingDisabled,
                pin: privacy.pin,
                timeout: privacy.timeout,
                mentions: mentions,
                coverImage: coverImage,
                stateContext: stateContext,
                completion: { [weak self] sendAsPeerId, privacy, allowScreenshots, pin, _, completed in
                    guard let self else {
                        return
                    }
                    self.state.privacy = MediaEditorResultPrivacy(
                        sendAsPeerId: sendAsPeerId,
                        privacy: privacy,
                        timeout: timeout,
                        isForwardingDisabled: !allowScreenshots,
                        pin: pin
                    )
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
                            sendAsPeerId: sendAsPeerId,
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
                            sendAsPeerId: sendAsPeerId,
                            privacy: privacy,
                            timeout: timeout,
                            isForwardingDisabled: !allowScreenshots,
                            pin: pin
                        ), completion: completion)
                    })
                },
                editCover: {
                    editCoverImpl?()
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
            
            editCoverImpl = { [weak self] in
                if let self {
                    self.node.openCoverSelection(exclusive: false)
                }
            }
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
                completion: { [weak self] _, result, isForwardingDisabled, pin, peers, completed in
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
    
    func presentEntityShortcuts(sourceView: UIView, gesture: ContextGesture) {
        self.hapticFeedback.impact(.light)
        
        let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkPresentationTheme)
        
        var items: [ContextMenuItem] = []
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_Shortcut_Image, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Image"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] _, a in
            a(.default)
            
            self?.node.presentGallery()
        })))
        if self.context.isPremium {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_Shortcut_Link, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, a in
                a(.default)
                
                self?.node.addOrEditLink()
            })))
        }
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_Shortcut_Location, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LocationSmall"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] _, a in
            a(.default)
            
            self?.node.presentLocationPicker()
        })))
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_Shortcut_Reaction, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reactions"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] _, a in
            a(.default)
            
            self?.node.addReaction()
        })))
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_Shortcut_Audio, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/AudioSmall"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] _, a in
            a(.default)
            
            self?.node.presentAudioPicker()
        })))
        
        let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: self, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.present(contextController, in: .window(.root))
    }
    
    func presentTimeoutSetup(sourceView: UIView, gesture: ContextGesture?) {
        self.hapticFeedback.impact(.light)
        
        let hasPremium = self.context.isPremium
        let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkPresentationTheme)
        let currentValue = self.state.privacy.timeout
        let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil
        
        let updateTimeout: (Int?) -> Void = { [weak self] timeout in
            guard let self else {
                return
            }
            self.state.privacy = MediaEditorResultPrivacy(
                sendAsPeerId: self.state.privacy.sendAsPeerId,
                privacy: self.state.privacy.privacy,
                timeout: timeout ?? 86400,
                isForwardingDisabled: self.state.privacy.isForwardingDisabled,
                pin: self.state.privacy.pin
            )
        }
        
        let timeoutOptions: [(hours: Int, requiresPremium: Bool)] = [
            (6, true),
            (12, true),
            (24, false),
            (48, true)
        ]
        
        var items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(
                text: presentationData.strings.Story_Editor_ExpirationText,
                textLayout: .multiline,
                textFont: .small,
                icon: { _ in return nil },
                action: emptyAction
            ))
        ]
        
        for option in timeoutOptions {
            let text = presentationData.strings.Story_Editor_ExpirationValue(Int32(option.hours))
            let value = option.hours * 3600

            items.append(.action(ContextMenuActionItem(
                text: text,
                icon: { theme in
                    if option.requiresPremium && !hasPremium {
                        return generateTintedImage(
                            image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/TextLockIcon"),
                            color: theme.contextMenu.secondaryColor
                        )
                    } else if currentValue == value {
                        return generateTintedImage(
                            image: UIImage(bundleImageName: "Chat/Context Menu/Check"),
                            color: theme.contextMenu.primaryColor
                        )
                    } else {
                        return nil
                    }
                },
                action: { [weak self] _, a in
                    a(.default)
                    
                    if !option.requiresPremium || hasPremium {
                        updateTimeout(value)
                    } else {
                        self?.presentTimeoutPremiumSuggestion()
                    }
                }
            )))
        }
    
        let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: self, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
            return false
        })
        self.present(controller, in: .current)
    }
    
    fileprivate func presentReactionPremiumSuggestion() {
        self.hapticFeedback.impact(.light)
        
        self.dismissAllTooltips()
        
        let context = self.context
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true))
        |> deliverOnMainQueue).start(next: { [weak self] premiumLimits in
            guard let self else {
                return
            }
          
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let limit = context.userLimits.maxStoriesSuggestedReactions
            
            let content: UndoOverlayContent
            if context.isPremium {
                let value = presentationData.strings.Story_Editor_TooltipPremiumReactionLimitValue(limit)
                content = .info(
                    title: presentationData.strings.Story_Editor_TooltipReachedReactionLimitTitle,
                    text: presentationData.strings.Story_Editor_TooltipReachedReactionLimitText(value).string,
                    timeout: nil,
                    customUndoText: nil
                )
            } else {
                let value = presentationData.strings.Story_Editor_TooltipPremiumReactionLimitValue(premiumLimits.maxStoriesSuggestedReactions)
                content = .premiumPaywall(
                    title: presentationData.strings.Story_Editor_TooltipPremiumReactionLimitTitle,
                    text: presentationData.strings.Story_Editor_TooltipPremiumReactionLimitText(value).string,
                    customUndoText: nil,
                    timeout: nil,
                    linkAction: nil
                )
            }
                    
            let controller = UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: true, position: .top, animateInAsReplacement: false, action: { [weak self] action in
                if case .info = action, let self {
                    if let stickerScreen = self.node.stickerScreen {
                        self.node.stickerScreen = nil
                        stickerScreen.dismiss(animated: true)
                    }
                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .storiesSuggestedReactions, forceDark: true, dismissed: nil)
                    self.push(controller)
                }
                return true
            })
            self.present(controller, in: .window(.root))
        })
    }
    
    fileprivate func presentUnavailableReactionPremiumSuggestion(file: TelegramMediaFile) {
        self.hapticFeedback.error()
        
        self.dismissAllTooltips()
        
        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let controller = UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: presentationData.strings.Story_Editor_TooltipPremiumReaction, undoText: nil, customAction: nil), elevatedLayout: true, position: .top, animateInAsReplacement: false, appearance: UndoOverlayController.Appearance(isBlurred: true), action: { [weak self] action in
            if case .info = action, let self {
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .storiesExpirationDurations, forceDark: true, dismissed: nil)
                self.push(controller)
            }
            return false
        })
        self.present(controller, in: .window(.root))
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
            return false
        })
        self.present(controller, in: .current)
    }
    
    fileprivate func presentCaptionEntitiesPremiumSuggestion() {
        self.dismissAllTooltips()
        
        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let text = presentationData.strings.Story_Editor_TooltipPremiumCaptionEntities
                
        let controller = UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: text), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { [weak self] action in
            if case .info = action, let self {
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .storiesFormatting, forceDark: true, dismissed: nil)
                self.push(controller)
            }
            return false }
        )
        self.present(controller, in: .current)
    }
    
    fileprivate func presentLinkLimitTooltip() {
        self.hapticFeedback.impact(.light)
        
        self.dismissAllTooltips()
        
        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let limit: Int32 = 3
        
        let value = presentationData.strings.Story_Editor_TooltipLinkLimitValue(limit)
        let content: UndoOverlayContent = .info(
            title: nil,
            text: presentationData.strings.Story_Editor_TooltipReachedLinkLimitText(value).string,
            timeout: nil,
            customUndoText: nil
        )
        
        let controller = UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: true, position: .top, animateInAsReplacement: false, action: { _ in
            return true
        })
        self.present(controller, in: .window(.root))
    }
    
    fileprivate func presentWeatherLimitTooltip() {
        self.hapticFeedback.impact(.light)
        
        self.dismissAllTooltips()
        
        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let content: UndoOverlayContent = .info(
            title: nil,
            text: presentationData.strings.Story_Editor_TooltipWeatherLimitText,
            timeout: nil,
            customUndoText: nil
        )
        
        let controller = UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: true, position: .top, animateInAsReplacement: false, action: { _ in
            return true
        })
        self.present(controller, in: .window(.root))
    }
        
    func maybePresentDiscardAlert() {
        self.hapticFeedback.impact(.light)
        if !self.isEligibleForDraft() {
            self.requestDismiss(saveDraft: false, animated: true)
            return
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        var title: String
        var text: String
        var save: String?
        switch self.mode {
        case .storyEditor:
            if case .draft = self.node.actualSubject {
                title = presentationData.strings.Story_Editor_DraftDiscardDraft
                save = presentationData.strings.Story_Editor_DraftKeepDraft
            } else {
                title = presentationData.strings.Story_Editor_DraftDiscardMedia
                save = presentationData.strings.Story_Editor_DraftKeepMedia
            }
            text = presentationData.strings.Story_Editor_DraftDiscaedText
        case .stickerEditor, .botPreview, .avatarEditor, .coverEditor:
            title = presentationData.strings.Story_Editor_DraftDiscardMedia
            text = presentationData.strings.Story_Editor_DiscardText
        }
        
        var actions: [TextAlertAction] = []
        actions.append(TextAlertAction(type: .destructiveAction, title: presentationData.strings.Story_Editor_DraftDiscard, action: { [weak self] in
            if let self {
                self.requestDismiss(saveDraft: false, animated: true)
            }
        }))
        if let save {
            actions.append(TextAlertAction(type: .genericAction, title: save, action: { [weak self] in
                if let self {
                    self.requestDismiss(saveDraft: true, animated: true)
                }
            }))
        }
        actions.append(TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
            
        }))
        let controller = textAlertController(
            context: self.context,
            forceTheme: defaultDarkPresentationTheme,
            title: title,
            text: text,
            actions: actions,
            actionLayout: .vertical
        )
        self.present(controller, in: .window(.root))
    }
    
    func requestDismiss(saveDraft: Bool, animated: Bool) {
        self.dismissAllTooltips()
        
        var showDraftTooltip = saveDraft
        if let subject = self.node.actualSubject, case .draft = subject {
            showDraftTooltip = false
        }
        if saveDraft {
            self.saveDraft(id: nil)
        } else {
            if case let .draft(draft, id) = self.node.actualSubject, id == nil {
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
        
    fileprivate func checkCaptionLimit() -> Bool {
        let caption = self.node.getCaption()
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
    
    func checkIfCompletionIsAllowed() -> Bool {
        if !self.context.isPremium {
            let entities = self.node.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
            for entity in entities {
                if let stickerEntity = entity as? DrawingStickerEntity, case let .file(file, type) = stickerEntity.content, case let .reaction(reaction, _) = type, case .custom = reaction {
                    self.presentUnavailableReactionPremiumSuggestion(file: file.media)
                    return false
                }
            }
        }
        return true
    }
    
    func requestStickerCompletion(animated: Bool) {
        guard let mediaEditor = self.node.mediaEditor else {
            return
        }
                
        if let subject = self.node.subject, case .empty = subject {
            if !self.node.hasAnyChanges && !self.node.drawingView.internalState.canUndo {
                self.hapticFeedback.error()
                
                self.node.componentHost.findTaggedView(tag: drawButtonTag)?.layer.addShakeAnimation()
                self.node.componentHost.findTaggedView(tag: stickerButtonTag)?.layer.addShakeAnimation()
                self.node.componentHost.findTaggedView(tag: textButtonTag)?.layer.addShakeAnimation()
                
                return
            }
        }
        
        self.dismissAllTooltips()
        
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.updateRootContainerTransitionOffset(0.0, transition: .immediate)
        }
            
        self.updateMediaEditorEntities()
    
        if let image = mediaEditor.resultImage {
            let values = mediaEditor.values.withUpdatedQualityPreset(.sticker)
            makeEditorImageComposition(context: self.node.ciContext, postbox: self.context.account.postbox, inputImage: image, dimensions: storyDimensions, outputDimensions: CGSize(width: 512, height: 512), values: values, time: .zero, textScale: 2.0, completion: { [weak self] resultImage in
                if let self, let resultImage {
                    self.presentStickerPreview(image: resultImage)
                }
            })
        }
    }
    
    func requestCoverCompletion(animated: Bool) {
        guard let mediaEditor = self.node.mediaEditor, case let .coverEditor(dimensions) = self.mode else {
            return
        }
                
        self.dismissAllTooltips()
        
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.updateRootContainerTransitionOffset(0.0, transition: .immediate)
        }
         
        self.updateMediaEditorEntities()
        
        if let image = mediaEditor.resultImage {
            let values = mediaEditor.values.withUpdatedCoverDimensions(dimensions)
            makeEditorImageComposition(context: self.node.ciContext, postbox: self.context.account.postbox, inputImage: image, dimensions: storyDimensions, outputDimensions: dimensions.aspectFitted(CGSize(width: 1080, height: 1080)), values: values, time: .zero, textScale: 2.0, completion: { [weak self] resultImage in
                if let self, let resultImage {
                    self.completion([MediaEditorScreenImpl.Result(media: .image(image: resultImage, dimensions: PixelDimensions(resultImage.size)))], { [weak self] finished in
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
    }
    
    private var stickerRecommendedEmoji: [String] = []
    private var stickerSelectedEmoji: [String] = []
   
    private func effectiveStickerEmoji() -> [String] {
        let filtered = self.stickerSelectedEmoji.filter { !$0.isEmpty }
        guard !filtered.isEmpty else {
            for entity in self.node.entitiesView.entities {
                if let stickerEntity = entity as? DrawingStickerEntity, case let .file(file, _) = stickerEntity.content {
                    for attribute in file.media.attributes {
                        if case let .Sticker(displayText, _, _) = attribute {
                            return [displayText]
                        }
                    }
                    break
                }
            }
            return ["🫥"]
        }
        return filtered
    }
    
    private func preferredStickerDuration() -> Double {
        if let duration = self.node.mediaEditor?.duration, duration > 0.0 {
            return min(3.0, duration)
        }
        var duration: Double = 3.0
        var stickerDurations: [Double] = []
        self.node.entitiesView.eachView { entityView in
            if let stickerEntityView = entityView as? DrawingStickerEntityView {
                if let duration = stickerEntityView.duration, duration > 0.0 {
                    stickerDurations.append(duration)
                }
            }
        }
        if !stickerDurations.isEmpty {
            duration = stickerDurations.max() ?? 3.0
        }
        return min(3.0, duration)
    }
    
    private weak var stickerResultController: PeekController?
    func presentStickerPreview(image: UIImage) {
        guard let mediaEditor = self.node.mediaEditor else {
            return
        }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
        
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        let thumbnailResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        
        var isVideo = false
        if mediaEditor.resultIsVideo {
            isVideo = true
        }
        let imagesReady = ValuePromise<Bool>(false, ignoreRepeated: true)
        Queue.concurrentDefaultQueue().async {
            if !isVideo, let data = try? WebP.convert(toWebP: image, quality: 97.0) {
                self.context.account.postbox.mediaBox.storeResourceData(isVideo ? thumbnailResource.id : resource.id, data: data, synchronous: true)
            }
            if let thumbnailImage = generateScaledImage(image: image, size: CGSize(width: 320.0, height: 320.0), opaque: false, scale: 1.0), let data = try? WebP.convert(toWebP: thumbnailImage, quality: 90.0) {
                self.context.account.postbox.mediaBox.storeResourceData(thumbnailResource.id, data: data, synchronous: true)
            }
            imagesReady.set(true)
        }
        var file = stickerFile(resource: resource, thumbnailResource: thumbnailResource, size: Int64(0), dimensions: PixelDimensions(image.size), duration: self.preferredStickerDuration(), isVideo: isVideo)
        
        var menuItems: [ContextMenuItem] = []
        var hasEmojiSelection = true
        if case let .stickerEditor(mode) = self.mode {
            switch mode {
            case .generic:
                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.StickerPack_Send, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                    guard let self else {
                        return
                    }
                    
                    if !isVideo {
                        self.stickerResultController?.disappeared = nil
                    }
                    
                    let _ = (imagesReady.get()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if isVideo {
                            self.uploadSticker(file, action: .send)
                        } else {
                            self.completion([MediaEditorScreenImpl.Result(
                                media: .sticker(file: file, emoji: self.effectiveStickerEmoji()),
                                mediaAreas: [],
                                caption: NSAttributedString(),
                                coverTimestamp: nil,
                                options: MediaEditorResultPrivacy(sendAsPeerId: nil, privacy: EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: []), timeout: 0, isForwardingDisabled: false, pin: false),
                                stickers: [],
                                randomId: 0
                            )], { [weak self] finished in
                                self?.node.animateOut(finished: true, saveDraft: false, completion: { [weak self] in
                                    self?.dismiss()
                                    Queue.mainQueue().justDispatch {
                                        finished()
                                    }
                                })
                            })
                        }
                    })
                    
                    f(.default)
                })))
                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                    f(.default)
                    guard let self else {
                        return
                    }
                    let _ = (imagesReady.get()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.uploadSticker(file, action: .addToFavorites)
                    })
                })))
                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_AddToStickerPack, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddSticker"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                    guard let self else {
                        return
                    }
                    
                    var contextItems: [ContextMenuItem] = []
                    contextItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Common_Back, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                    }, iconPosition: .left, action: { c, _ in
                        c?.popItems()
                    })))
                    
                    contextItems.append(.separator)
                    
                    contextItems.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_CreateNewPack, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddCircle"), color: theme.contextMenu.primaryColor) }, iconPosition: .left, action: { [weak self] _, f in
                        if let self {
                            self.presentCreateStickerPack(file: file, completion: {
                                f(.default)
                            })
                        }
                    })))
                              
                    contextItems.append(.custom(StickerPackListContextItem(context: self.context, packs: self.myStickerPacks, packSelected: { [weak self] pack in
                        guard let self else {
                            return true
                        }
                        if pack.count >= 120 {
                            let controller = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.MediaEditor_StickersTooMuch, timeout: nil, customUndoText: nil), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { [weak self] action in
                                if case .info = action, let self {
                                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .stories, forceDark: true, dismissed: {
                                        
                                    })
                                    self.push(controller)
                                }
                                return false
                            })
                            self.hapticFeedback.error()
                            self.present(controller, in: .window(.root))
                            return false
                        } else {
                            let _ = (imagesReady.get()
                            |> filter { $0 }
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                self.uploadSticker(file, action: .addToStickerPack(pack: .id(id: pack.id.id, accessHash: pack.accessHash), title: pack.title))
                            })
                            return true
                        }
                    }), false))

                    let items = ContextController.Items(
                        id: 1,
                        content: .list(contextItems),
                        context: nil,
                        reactionItems: [],
                        selectedReactionItems: Set(),
                        reactionsTitle: nil,
                        reactionsLocked: false,
                        animationCache: nil,
                        alwaysAllowPremiumReactions: false,
                        allPresetReactionsAreAvailable: false,
                        getEmojiContent: nil,
                        disablePositionLock: false,
                        tip: nil,
                        tipSignal: nil,
                        dismissed: nil
                    )
                    c?.pushItems(items: .single(items))
                })))
            case .editing:
                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_ReplaceSticker, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replace"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                    guard let self else {
                        return
                    }
                    f(.default)
                    
                    var action: StickerAction = .upload
                    if !self.node.hasAnyChanges && !self.node.drawingView.internalState.canUndo, case let .sticker(sticker, _) = self.node.subject {
                        file = sticker
                        action = .update
                    }
                    let _ = (imagesReady.get()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.uploadSticker(file, action: action)
                    })
                })))
            case .addingToPack:
                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_AddToStickerPack, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddSticker"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                    guard let self else {
                        return
                    }
                    f(.default)
                    
                    let _ = (imagesReady.get()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.uploadSticker(file, action: .upload)
                    })
                })))
            case .businessIntro:
                hasEmojiSelection = false
                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_SetAsIntroSticker, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                    guard let self else {
                        return
                    }
                    f(.default)
                    
                    let _ = (imagesReady.get()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.uploadSticker(file, action: .upload)
                    })
                })))
            }
        }
        
        Queue.mainQueue().justDispatch {
            self.node.entitiesView.selectEntity(nil)
        }
        
        guard let portalView = PortalView(matchPosition: false) else {
            return
        }
        portalView.view.layer.rasterizationScale = UIScreenScale
        self.node.previewContentContainerView.addPortal(view: portalView)
        
        let stickerResultController = PeekController(
            presentationData: presentationData,
            content: StickerPreviewPeekContent(
                context: self.context,
                theme: presentationData.theme,
                strings: presentationData.strings,
                item: .portal(portalView),
                isCreating: hasEmojiSelection,
                selectedEmoji: self.stickerSelectedEmoji,
                selectedEmojiUpdated: { [weak self] selectedEmoji in
                    if let self {
                        self.stickerSelectedEmoji = selectedEmoji
                    }
                },
                recommendedEmoji: self.stickerRecommendedEmoji,
                menu: menuItems,
                openPremiumIntro: {}
            ), 
            sourceView: { [weak self] in
                if let self {
                    let previewContainerFrame = self.node.previewContainerView.frame
                    let size = CGSize(width: floorToScreenPixels(previewContainerFrame.width * 0.97), height: floorToScreenPixels(previewContainerFrame.width * 0.97))
                    return (self.view, CGRect(origin: CGPoint(x: previewContainerFrame.midX - size.width / 2.0, y: previewContainerFrame.midY - size.height / 2.0), size: size))
                } else {
                    return nil
                }
            },
            activateImmediately: true
        )
        stickerResultController.appeared = { [weak self] in
            if let self {
                self.node.previewContentContainerView.alpha = 0.0
                self.node.previewContentContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                
                let scale = 180.0 / (self.node.previewContentContainerView.bounds.width * 1.04)
                self.node.previewContentContainerView.layer.animateSpring(from: 1.0 as NSNumber, to: scale as NSNumber, keyPath: "transform.scale", duration: 0.4, initialVelocity: 0.0, damping: 110.0)
            }
        }
        stickerResultController.disappeared = { [weak self] in
            if let self {
                self.node.previewContentContainerView.alpha = 1.0
                self.node.previewContentContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                
                let scale = 180.0 / (self.node.previewContentContainerView.bounds.width * 1.04)
                self.node.previewContentContainerView.layer.animateScale(from: scale, to: 1.0, duration: 0.25)
            }
        }
        self.stickerResultController = stickerResultController
        self.present(stickerResultController, in: .window(.root))
    }
    
    private enum StickerAction {
        case addToFavorites
        case createStickerPack(title: String)
        case addToStickerPack(pack: StickerPackReference, title: String)
        case upload
        case update
        case send
    }
    
    private func presentCreateStickerPack(file: TelegramMediaFile, completion: @escaping () -> Void) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
        
        var dismissImpl: (() -> Void)?
        let controller = stickerPackEditTitleController(context: self.context, forceDark: true, title: presentationData.strings.MediaEditor_NewStickerPack_Title, text: presentationData.strings.MediaEditor_NewStickerPack_Text, placeholder: presentationData.strings.ImportStickerPack_NamePlaceholder, actionTitle: presentationData.strings.Common_Done, value: nil, maxLength: 64, apply: { [weak self] title in
            guard let self else {
                return
            }
            dismissImpl?()
            completion()
            
            if let title {
                self.uploadSticker(file, action: .createStickerPack(title: title))
            }
        }, cancel: {})
        dismissImpl = { [weak controller] in
            controller?.dismiss()
        }
        self.present(controller, in: .window(.root))
    }
        
    private let stickerUploadDisposable = MetaDisposable()
    private func uploadSticker(_ file: TelegramMediaFile, action: StickerAction) {
        let context = self.context
        let dimensions = PixelDimensions(width: 512, height: 512)
        let duration = file.duration
        let mimeType = file.mimeType
        let isVideo = file.mimeType == "video/webm"
        let emojis = self.effectiveStickerEmoji()
        
        var isUpdate = false
        if case .update = action {
            isUpdate = true
        }
        
        self.updateEditProgress(0.0, cancel: { [weak self] in
            self?.stickerUploadDisposable.set(nil)
        })
        
        enum PrepareStickerStatus {
            case progress(Float)
            case complete(TelegramMediaResource)
            case failed
        }
        let resourceSignal: Signal<PrepareStickerStatus, UploadStickerError>
        if isVideo && !isUpdate {
            self.performSave(toStickerResource: file.resource)
            resourceSignal = self.videoExportPromise.get()
            |> castError(UploadStickerError.self)
            |> filter { $0 != nil }
            |> take(1)
            |> mapToSignal { videoExport -> Signal<PrepareStickerStatus, UploadStickerError> in
                guard let videoExport else {
                    return .complete()
                }
                return videoExport.status
                |> castError(UploadStickerError.self)
                |> mapToSignal { status -> Signal<PrepareStickerStatus, UploadStickerError> in
                    switch status {
                    case .unknown:
                        return .single(.progress(0.0))
                    case let .progress(progress):
                        return .single(.progress(progress))
                    case .completed:
                        return .single(.complete(file.resource))
                        |> delay(0.05, queue: Queue.mainQueue())
                    case .failed:
                        return .single(.failed)
                    }
                }
            }
        } else {
            resourceSignal = .single(.complete(file.resource))
        }
        
        let signal = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> castError(UploadStickerError.self)
        |> mapToSignal { peer -> Signal<(UploadStickerStatus, (StickerPackReference, String)?), UploadStickerError> in
            guard let peer else {
                return .complete()
            }
            return resourceSignal
            |> mapToSignal { result -> Signal<(UploadStickerStatus, (StickerPackReference, String)?), UploadStickerError> in
                switch result {
                case .failed:
                    return .fail(.generic)
                case let .progress(progress):
                    return .single((.progress(progress * 0.5), nil))
                case let .complete(resource):
                    if let resource = resource as? CloudDocumentMediaResource {
                        return .single((.progress(1.0), nil)) |> then(.single((.complete(resource, mimeType), nil)))
                    } else {
                        return context.engine.stickers.uploadSticker(peer: peer._asPeer(), resource: resource, thumbnail: file.previewRepresentations.first?.resource, alt: "", dimensions: dimensions, duration: duration, mimeType: mimeType)
                        |> mapToSignal { status -> Signal<(UploadStickerStatus, (StickerPackReference, String)?), UploadStickerError> in
                            switch status {
                            case let .progress(progress):
                                return .single((.progress(isVideo ? 0.5 + progress * 0.5 : progress), nil))
                            case let .complete(resource, _):
                                let file = stickerFile(resource: resource, thumbnailResource: file.previewRepresentations.first?.resource, size: file.size ?? 0, dimensions: dimensions, duration: file.duration, isVideo: isVideo)
                                switch action {
                                case .send:
                                    return .single((status, nil))
                                case .addToFavorites:
                                    return context.engine.stickers.toggleStickerSaved(file: file, saved: true)
                                    |> `catch` { _ -> Signal<SavedStickerResult, UploadStickerError> in
                                        return .fail(.generic)
                                    }
                                    |> map { _ in
                                        return (status, nil)
                                    }
                                case let .createStickerPack(title):
                                    let sticker = ImportSticker(
                                        resource: .standalone(resource: resource),
                                        emojis: emojis,
                                        dimensions: dimensions,
                                        duration: duration,
                                        mimeType: mimeType,
                                        keywords: ""
                                    )
                                    return context.engine.stickers.createStickerSet(title: title, shortName: "", stickers: [sticker], thumbnail: nil, type: .stickers(content: .image), software: nil)
                                    |> `catch` { _ -> Signal<CreateStickerSetStatus, UploadStickerError> in
                                        return .fail(.generic)
                                    }
                                    |> mapToSignal { innerStatus in
                                        if case let .complete(info, _) = innerStatus {
                                            return .single((status, (.id(id: info.id.id, accessHash: info.accessHash), title)))
                                        } else {
                                            return .complete()
                                        }
                                    }
                                case let .addToStickerPack(pack, title):
                                    let sticker = ImportSticker(
                                        resource: .standalone(resource: resource),
                                        emojis: emojis,
                                        dimensions: dimensions,
                                        duration: duration,
                                        mimeType: mimeType,
                                        keywords: ""
                                    )
                                    return context.engine.stickers.addStickerToStickerSet(packReference: pack, sticker: sticker)
                                    |> `catch` { _ -> Signal<Bool, UploadStickerError> in
                                        return .fail(.generic)
                                    }
                                    |> map { _ in
                                        return (status, (pack, title))
                                    }
                                case .upload, .update:
                                    return .single((status, nil))
                                }
                            }
                        }
                    }
                }
            }
        }
        self.stickerUploadDisposable.set((signal
        |> deliverOnMainQueue).startStandalone(next: { [weak self] (status, packReferenceAndTitle) in
            guard let self else {
                return
            }
            
            switch status {
            case let .progress(progress):
                self.updateEditProgress(progress, cancel: { [weak self] in
                    self?.videoExport?.cancel()
                    self?.videoExport = nil
                    self?.exportDisposable.set(nil)
                    self?.stickerUploadDisposable.set(nil)
                })
            case let .complete(resource, _):
                let navigationController = self.navigationController as? NavigationController
                
                let result: MediaEditorScreenImpl.Result
                switch action {
                case .update:
                    result = MediaEditorScreenImpl.Result(media: .sticker(file: file, emoji: emojis))
                case .upload, .send:
                    let file = stickerFile(resource: resource, thumbnailResource: file.previewRepresentations.first?.resource, size: resource.size ?? 0, dimensions: dimensions, duration: self.preferredStickerDuration(), isVideo: isVideo)
                    result = MediaEditorScreenImpl.Result(media: .sticker(file: file, emoji: emojis))
                default:
                    result = MediaEditorScreenImpl.Result()
                }

                self.completion([result], { [weak self] finished in
                    self?.node.animateOut(finished: true, saveDraft: false, completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                        self.dismiss()
                        Queue.mainQueue().justDispatch {
                            finished()
                            
                            switch action {
                            case .addToFavorites:
                                if let parentController = navigationController?.viewControllers.last as? ViewController {
                                    parentController.present(UndoOverlayController(presentationData: presentationData, content: .sticker(context: self.context, file: file, loop: true, title: nil, text: presentationData.strings.Conversation_StickerAddedToFavorites, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                                }
                            case .addToStickerPack, .createStickerPack:
                                if let (packReference, packTitle) = packReferenceAndTitle, let navigationController = self.navigationController as? NavigationController {
                                    Queue.mainQueue().after(0.2) {
                                        let controller = self.context.sharedContext.makeStickerPackScreen(context: self.context, updatedPresentationData: nil, mainStickerPack: packReference, stickerPacks: [packReference], loadedStickerPacks: [], actionTitle: nil, isEditing: false, expandIfNeeded: true, parentNavigationController: navigationController, sendSticker: self.sendSticker, actionPerformed: nil)
                                        (navigationController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root))
                                        
                                        Queue.mainQueue().after(0.1) {
                                            controller.present(UndoOverlayController(presentationData: presentationData, content: .sticker(context: self.context, file: file, loop: true, title: nil, text: presentationData.strings.StickerPack_StickerAdded(packTitle).string, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                                        }
                                    }
                                }
                            default:
                                break
                            }
                        }
                    })
                })
            }
        }))
    }
    
    private var videoExport: MediaEditorVideoExport? {
        didSet {
            self.videoExportPromise.set(.single(self.videoExport))
        }
    }
    private var videoExportPromise = Promise<MediaEditorVideoExport?>(nil)
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
            self?.hapticFeedback.impact(.light)
            self?.performSave()
        })
    }
        
    private func performSave(toStickerResource: MediaResource? = nil) {
        guard let mediaEditor = self.node.mediaEditor, let subject = self.node.subject else {
            return
        }
        
        self.updateMediaEditorEntities()
        
        let isSticker = toStickerResource != nil
        if !isSticker {
            self.previousSavedValues = mediaEditor.values
            self.isSavingAvailable = false
            self.requestLayout(transition: .animated(duration: 0.25, curve: .easeInOut))
        }
        
        let fileExtension = isSticker ? "webm" : "mp4"
        let saveToPhotos: (String, Bool) -> Void = { path, isVideo in
            let tempVideoPath = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).\(fileExtension)"
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
        
        let context = self.context
        if mediaEditor.resultIsVideo {
            if !isSticker {
                mediaEditor.maybePauseVideo()
                self.node.entitiesView.pause()
            }
            
            let exportSubject: Signal<MediaEditorVideoExport.Subject, NoError>
            switch subject {
            case let .empty(dimensions):
                let image = generateImage(dimensions.cgSize, opaque: false, scale: 1.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                })!
                exportSubject = .single(.image(image: image))
            case let .video(path, _, _, _, _, _, _, _, _, _):
                let asset = AVURLAsset(url: NSURL(fileURLWithPath: path) as URL)
                exportSubject = .single(.video(asset: asset, isStory: true))
            case let .videoCollage(items):
                var maxDurationItem: (Double, Subject.VideoCollageItem)?
                for item in items {
                    switch item.content {
                    case .image:
                        break
                    case let .video(_, duration):
                        if let (maxDuration, _) = maxDurationItem {
                            if duration > maxDuration {
                                maxDurationItem = (duration, item)
                            }
                        } else {
                            maxDurationItem = (duration, item)
                        }
                    case let .asset(asset):
                        if let (maxDuration, _) = maxDurationItem {
                            if asset.duration > maxDuration {
                                maxDurationItem = (asset.duration, item)
                            }
                        } else {
                            maxDurationItem = (asset.duration, item)
                        }
                    }
                }
                guard let (_, mainItem) = maxDurationItem else {
                    fatalError()
                }
                let assetSignal: Signal<AVAsset, NoError>
                switch mainItem.content {
                case let .video(path, _):
                    assetSignal = .single(AVURLAsset(url: NSURL(fileURLWithPath: path) as URL))
                case let .asset(asset):
                    assetSignal = Signal { subscriber in
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let avAsset {
                                subscriber.putNext(avAsset)
                                subscriber.putCompletion()
                            }
                        }
                        return EmptyDisposable
                    }
                default:
                    fatalError()
                }
                exportSubject = assetSignal
                |> map { asset in
                    return .video(asset: asset, isStory: true)
                }
            case let .image(image, _, _, _, _):
                exportSubject = .single(.image(image: image))
            case let .asset(asset):
                exportSubject = Signal { subscriber in
                    if asset.mediaType == .video {
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let avAsset {
                                subscriber.putNext(.video(asset: avAsset, isStory: true))
                                subscriber.putCompletion()
                            }
                        }
                    } else {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                            if let image {
                                subscriber.putNext(.image(image: image))
                                subscriber.putCompletion()
                            }
                        }
                    }
                    return EmptyDisposable
                }
            case let .draft(draft, _):
                if draft.isVideo {
                    let asset = AVURLAsset(url: NSURL(fileURLWithPath: draft.fullPath(engine: context.engine)) as URL)
                    exportSubject = .single(.video(asset: asset, isStory: true))
                } else {
                    if let image = UIImage(contentsOfFile: draft.fullPath(engine: context.engine)) {
                        exportSubject = .single(.image(image: image))
                    } else {
                        fatalError()
                    }
                }
            case let .message(messages):
                let isNightTheme = mediaEditor.values.nightTheme
                exportSubject = getChatWallpaperImage(context: self.context, peerId: messages.first!.peerId)
                |> mapToSignal { _, image, nightImage -> Signal<MediaEditorVideoExport.Subject, NoError> in
                    if isNightTheme {
                        let effectiveImage = nightImage ?? image
                        return effectiveImage.flatMap({ .single(.image(image: $0)) }) ?? .complete()
                    } else {
                        return image.flatMap({ .single(.image(image: $0)) }) ?? .complete()
                    }
                }
            case .gift:
                let isNightTheme = mediaEditor.values.nightTheme
                exportSubject = getChatWallpaperImage(context: self.context, peerId: self.context.account.peerId)
                |> mapToSignal { _, image, nightImage -> Signal<MediaEditorVideoExport.Subject, NoError> in
                    if isNightTheme {
                        let effectiveImage = nightImage ?? image
                        return effectiveImage.flatMap({ .single(.image(image: $0)) }) ?? .complete()
                    } else {
                        return image.flatMap({ .single(.image(image: $0)) }) ?? .complete()
                    }
                }
            case let .sticker(file, _):
                exportSubject = .single(.sticker(file: file))
            case .multiple:
                fatalError()
            }
            
            let _ = (exportSubject
            |> deliverOnMainQueue).start(next: { [weak self] exportSubject in
                guard let self else {
                    return
                }
                var values = mediaEditor.values
                var duration: Double = 0.0
                if case let .video(video, _) = exportSubject {
                    duration = video.duration.seconds
                }
                if isSticker {
                    duration = self.preferredStickerDuration()
                    if case .sticker = subject {
                    } else {
                        values = values.withUpdatedMaskDrawing(maskDrawing: self.node.stickerMaskDrawingView?.drawingImage)
                    }
                }
                let configuration = recommendedVideoExportConfiguration(values: values, duration: duration, forceFullHd: true, frameRate: 60.0, isSticker: isSticker)
                let outputPath = NSTemporaryDirectory() + "\(Int64.random(in: 0 ..< .max)).\(fileExtension)"
                let videoExport = MediaEditorVideoExport(postbox: self.context.account.postbox, subject: exportSubject, configuration: configuration, outputPath: outputPath, textScale: 2.0)
                self.videoExport = videoExport
                                
                let status: Signal<MediaEditorVideoExport.ExportStatus, NoError> = .single(.progress(0.0))
                |> then(videoExport.status)
            
                self.exportDisposable.set((status
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let self {
                        switch status {
                        case .completed:
                            self.videoExport = nil
                            if let toStickerResource {
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: outputPath)) {
                                    self.context.account.postbox.mediaBox.storeResourceData(toStickerResource.id, data: data, synchronous: true)
                                }
                            } else {
                                saveToPhotos(outputPath, true)
                                self.node.presentSaveTooltip()
                            }
                            
                            if let mediaEditor = self.node.mediaEditor, mediaEditor.maybeUnpauseVideo() {
                                self.node.entitiesView.play()
                            }
                        case let .progress(progress):
                            if !isSticker && self.videoExport != nil {
                                self.node.updateVideoExportProgress(progress)
                            }
                        case .failed:
                            self.videoExport = nil
                            if let mediaEditor = self.node.mediaEditor, mediaEditor.maybeUnpauseVideo() {
                                self.node.entitiesView.play()
                            }
                        case .unknown:
                            break
                        }
                    }
                }))
            })
        } else {
            if let image = mediaEditor.resultImage {
                Queue.concurrentDefaultQueue().async {
                    makeEditorImageComposition(context: self.node.ciContext, postbox: self.context.account.postbox, inputImage: image, dimensions: storyDimensions, values: mediaEditor.values, time: .zero, textScale: 2.0, completion: { resultImage in
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
        guard let videoExport = self.videoExport else {
            return
        }
        videoExport.cancel()
        
        self.videoExport = nil
        self.exportDisposable.set(nil)
        
        self.previousSavedValues = nil
        
        self.node.mediaEditor?.play()
        self.node.entitiesView.play()
    }
    
    public func updateEditProgress(_ progress: Float, cancel: @escaping () -> Void) {
        self.node.updateEditProgress(progress, cancel: cancel)
    }
    
    func dismissAllTooltips() {
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

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
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

private final class DoneButtonContentComponent: CombinedComponent {
    let backgroundColor: UIColor
    let icon: UIImage?
    let title: String?

    init(
        backgroundColor: UIColor,
        icon: UIImage?,
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
            var iconChild: _UpdatedChildComponent?
            if let iconImage = context.component.icon {
                iconChild = icon.update(
                    component: Image(image: iconImage, tintColor: .white, size: iconImage.size),
                    availableSize: CGSize(width: 180.0, height: 100.0),
                    transition: .immediate
                )
            }
            
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
                
                var updatedBackgroundWidth = backgroundSize.width + title!.size.width
                if let _ = iconChild {
                    updatedBackgroundWidth += textSpacing
                }
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
                var titlePosition = backgroundSize.width / 2.0
                if let _ = iconChild {
                    titlePosition = title.size.width / 2.0 + 15.0
                }
                context.add(title
                    .position(CGPoint(x: titlePosition, y: backgroundHeight / 2.0))
                    .opacity(hideTitle ? 0.0 : 1.0)
                )
            }
            
            if let iconChild {
                context.add(iconChild
                    .position(CGPoint(x: background.size.width - 16.0, y: backgroundSize.height / 2.0))
                )
            }
            
            return backgroundSize
        }
    }
}

final class CutoutButtonContentComponent: CombinedComponent {
    let backgroundColor: UIColor
    let icon: UIImage
    let title: String?
    let minWidth: CGFloat?
    let selected: Bool
    
    init(
        backgroundColor: UIColor,
        icon: UIImage,
        title: String?,
        minWidth: CGFloat? = nil,
        selected: Bool = false
    ) {
        self.backgroundColor = backgroundColor
        self.icon = icon
        self.title = title
        self.minWidth = minWidth
        self.selected = selected
    }

    static func ==(lhs: CutoutButtonContentComponent, rhs: CutoutButtonContentComponent) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.minWidth != rhs.minWidth {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        return true
    }

    static var body: Body {
        let background = Child(BlurredBackgroundComponent.self)
        let selection = Child(RoundedRectangle.self)
        let icon = Child(Image.self)
        let text = Child(Text.self)

        return { context in
            let textColor: UIColor = context.component.selected ? .black : .white
            
            let iconSize = context.component.icon.size
            let icon = icon.update(
                component: Image(image: context.component.icon, tintColor: textColor, size: iconSize),
                availableSize: CGSize(width: 180.0, height: 40.0),
                transition: .immediate
            )
            
            let backgroundHeight: CGFloat = 40.0
            var backgroundSize = CGSize(width: backgroundHeight, height: backgroundHeight)
            
            let textSpacing: CGFloat = 8.0
            
            var title: _UpdatedChildComponent?
            if let titleText = context.component.title {
                title = text.update(
                    component: Text(
                        text: titleText,
                        font: Font.with(size: 17.0, weight: .semibold),
                        color: textColor
                    ),
                    availableSize: CGSize(width: 240.0, height: 100.0),
                    transition: .immediate
                )
                
                let updatedBackgroundWidth = backgroundSize.width + textSpacing + title!.size.width
                backgroundSize.width = updatedBackgroundWidth + 18.0
            }
            if let minWidth = context.component.minWidth {
                backgroundSize.width = max(minWidth, backgroundSize.width)
            }

            let background = background.update(
                component: BlurredBackgroundComponent(color: context.component.backgroundColor, tintContainerView: nil, cornerRadius: backgroundHeight / 2.0),
                availableSize: backgroundSize,
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: backgroundSize.width / 2.0, y: backgroundSize.height / 2.0))
                .cornerRadius(min(backgroundSize.width, backgroundSize.height) / 2.0)
                .clipsToBounds(true)
            )
                        
            if context.component.selected {
                let selection = selection.update(
                    component: RoundedRectangle(color: .white, cornerRadius: backgroundHeight / 2.0),
                    availableSize: backgroundSize,
                    transition: .immediate
                )
                context.add(selection
                    .position(CGPoint(x: backgroundSize.width / 2.0, y: backgroundSize.height / 2.0))
                    .cornerRadius(min(backgroundSize.width, backgroundSize.height) / 2.0)
                    .clipsToBounds(true)
                )
            }
            
            if let title {
                let spacing: CGFloat = 7.0
                let totalWidth = icon.size.width + spacing + title.size.width
                let originX = floorToScreenPixels((backgroundSize.width - totalWidth) / 2.0)
                context.add(icon
                    .position(CGPoint(x: originX + icon.size.width / 2.0, y: backgroundSize.height / 2.0))
                )
                context.add(title
                    .position(CGPoint(x: originX + icon.size.width + spacing + title.size.width / 2.0, y: backgroundHeight / 2.0))
                )
            } else {
                context.add(icon
                    .position(CGPoint(x: 36.0, y: backgroundSize.height / 2.0))
                )
            }

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
        
        func update(component: ToolValueComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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
                    setupButtonShadow(titleView, radius: 3.0)
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
                    setupButtonShadow(valueView, radius: 3.0)
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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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
        
        public func update(component: BlurredGradientComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

func draftPath(engine: TelegramEngine) -> String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/storyDrafts_\(engine.account.peerId.toInt64())"
}

private func fullDraftPath(peerId: EnginePeer.Id, path: String) -> String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/storyDrafts_\(peerId.toInt64())/" + path
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

private func allowedStoryReactions(context: AccountContext) -> Signal<[ReactionItem], NoError> {
    let viewKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudTopReactions)
    let topReactions = context.account.postbox.combinedView(keys: [viewKey])
    |> map { views -> [RecentReactionItem] in
        guard let view = views.views[viewKey] as? OrderedItemListView else {
            return []
        }
        return view.items.compactMap { item -> RecentReactionItem? in
            return item.contents.get(RecentReactionItem.self)
        }
    }

    return combineLatest(
        context.engine.stickers.availableReactions(),
        topReactions
    )
    |> take(1)
    |> map { availableReactions, topReactions -> [ReactionItem] in
        guard let availableReactions = availableReactions else {
            return []
        }
        
        var result: [ReactionItem] = []
        
        var existingIds = Set<MessageReaction.Reaction>()
        
        for topReaction in topReactions {
            switch topReaction.content {
            case let .builtin(value):
                if let reaction = availableReactions.reactions.first(where: { $0.value == .builtin(value) }) {
                    guard let centerAnimation = reaction.centerAnimation else {
                        continue
                    }
                    guard let aroundAnimation = reaction.aroundAnimation else {
                        continue
                    }
                    
                    if existingIds.contains(reaction.value) {
                        continue
                    }
                    existingIds.insert(reaction.value)
                    
                    result.append(ReactionItem(
                        reaction: ReactionItem.Reaction(rawValue: reaction.value),
                        appearAnimation: reaction.appearAnimation,
                        stillAnimation: reaction.selectAnimation,
                        listAnimation: centerAnimation,
                        largeListAnimation: reaction.activateAnimation,
                        applicationAnimation: aroundAnimation,
                        largeApplicationAnimation: reaction.effectAnimation,
                        isCustom: false
                    ))
                } else {
                    continue
                }
            case let .custom(file):
                if existingIds.contains(.custom(file.fileId.id)) {
                    continue
                }
                existingIds.insert(.custom(file.fileId.id))
                
                result.append(ReactionItem(
                    reaction: ReactionItem.Reaction(rawValue: .custom(file.fileId.id)),
                    appearAnimation: file,
                    stillAnimation: file,
                    listAnimation: file,
                    largeListAnimation: file,
                    applicationAnimation: nil,
                    largeApplicationAnimation: nil,
                    isCustom: true
                ))
            case .stars:
                break
            }
        }
        
        for reaction in availableReactions.reactions {
            guard let centerAnimation = reaction.centerAnimation else {
                continue
            }
            guard let aroundAnimation = reaction.aroundAnimation else {
                continue
            }
            if !reaction.isEnabled {
                continue
            }
            
            if existingIds.contains(reaction.value) {
                continue
            }
            existingIds.insert(reaction.value)
            
            result.append(ReactionItem(
                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                appearAnimation: reaction.appearAnimation,
                stillAnimation: reaction.selectAnimation,
                listAnimation: centerAnimation,
                largeListAnimation: reaction.activateAnimation,
                applicationAnimation: aroundAnimation,
                largeApplicationAnimation: reaction.effectAnimation,
                isCustom: false
            ))
        }

        return result
    }
}

private final class ReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    private let contentArea: CGRect
    private let customPosition: CGPoint
    
    init(sourceView: UIView, contentArea: CGRect, customPosition: CGPoint) {
        self.sourceView = sourceView
        self.contentArea = contentArea
        self.customPosition = customPosition
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: self.contentArea, customPosition: self.customPosition, actionsPosition: .top)
    }
}

private func setupButtonShadow(_ view: UIView, radius: CGFloat = 2.0) {
    view.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
    view.layer.shadowRadius = radius
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOpacity = 0.35
}

extension MediaScrubberComponent.Track {
    public init(_ track: MediaEditorPlayerState.Track) {
        let content: MediaScrubberComponent.Track.Content
        switch track.content {
        case let .video(frames, framesUpdateTimestamp):
            content = .video(frames: frames, framesUpdateTimestamp: framesUpdateTimestamp)
        case let .audio(artist, title, samples, peak):
            content = .audio(artist: artist, title: title, samples: samples, peak: peak, isTimeline: false)
        }
        self.init(
            id: track.id,
            content: content,
            duration: track.duration,
            trimRange: track.trimRange,
            offset: track.offset,
            isMain: track.isMain
        )
    }
}

private func stickerFile(resource: TelegramMediaResource, thumbnailResource: TelegramMediaResource?, size: Int64, dimensions: PixelDimensions, duration: Double?, isVideo: Bool) -> TelegramMediaFile {
    var fileAttributes: [TelegramMediaFileAttribute] = []
    fileAttributes.append(.FileName(fileName: isVideo ? "sticker.webm" : "sticker.webp"))
    fileAttributes.append(.Sticker(displayText: "", packReference: nil, maskData: nil))
    if isVideo {
        fileAttributes.append(.Video(duration: duration ?? 3.0, size: dimensions, flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil))
    } else {
        fileAttributes.append(.ImageSize(size: dimensions))
    }
    var previewRepresentations: [TelegramMediaImageRepresentation] = []
    if let thumbnailResource {
        previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil))
    }
    
    return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: isVideo ? "video/webm" : "image/webp", size: size, attributes: fileAttributes, alternativeRepresentations: [])
}

private struct MediaEditorConfiguration {
    static var defaultValue: MediaEditorConfiguration {
        return MediaEditorConfiguration(preloadWeather: true)
    }
    
    let preloadWeather: Bool
    
    fileprivate init(preloadWeather: Bool) {
        self.preloadWeather = preloadWeather
    }
    
    static func with(appConfiguration: AppConfiguration) -> MediaEditorConfiguration {
        if let data = appConfiguration.data {
            var preloadWeather = false
            if let value = data["story_weather_preload"] as? Bool {
                preloadWeather = value
            }
            return MediaEditorConfiguration(preloadWeather: preloadWeather)
        } else {
            return .defaultValue
        }
    }
}
