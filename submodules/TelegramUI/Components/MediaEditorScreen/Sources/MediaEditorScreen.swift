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
import MultilineTextComponent
import DrawingUI
import MediaEditor
import Photos
import LottieAnimationComponent
import MessageInputPanelComponent
import EntityKeyboard
import TooltipUI
import BlurredBackgroundComponent
import AvatarNode
import ShareWithPeersScreen
import PresentationDataUtils
import ContextUI
import BundleIconComponent

enum DrawingScreenType {
    case drawing
    case text
    case sticker
}

private let privacyButtonTag = GenericComponentViewTag()
private let muteButtonTag = GenericComponentViewTag()
private let saveButtonTag = GenericComponentViewTag()

final class MediaEditorScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let isDisplayingTool: Bool
    let isInteractingWithEntities: Bool
    let isSavingAvailable: Bool
    let isDismissing: Bool
    let mediaEditor: MediaEditor?
    let privacy: MediaEditorResultPrivacy
    let selectedEntity: DrawingEntity?
    let entityViewForEntity: (DrawingEntity) -> DrawingEntityView?
    let openDrawing: (DrawingScreenType) -> Void
    let openTools: () -> Void
    
    init(
        context: AccountContext,
        isDisplayingTool: Bool,
        isInteractingWithEntities: Bool,
        isSavingAvailable: Bool,
        isDismissing: Bool,
        mediaEditor: MediaEditor?,
        privacy: MediaEditorResultPrivacy,
        selectedEntity: DrawingEntity?,
        entityViewForEntity: @escaping (DrawingEntity) -> DrawingEntityView?,
        openDrawing: @escaping (DrawingScreenType) -> Void,
        openTools: @escaping () -> Void
    ) {
        self.context = context
        self.isDisplayingTool = isDisplayingTool
        self.isInteractingWithEntities = isInteractingWithEntities
        self.isSavingAvailable = isSavingAvailable
        self.isDismissing = isDismissing
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
        if lhs.isDismissing != rhs.isDismissing {
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
        
        init(context: AccountContext, mediaEditor: MediaEditor?) {
            self.context = context
            
            super.init()
            
            if let mediaEditor {
                self.playerStateDisposable = (mediaEditor.playerState(framesCount: 16)
                |> deliverOnMainQueue).start(next: { [weak self] playerState in
                    if let self {
                        self.playerState = playerState
                        self.updated()
                    }
                })
            }
        }
        
        deinit {
            self.playerStateDisposable?.dispose()
        }
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
        
        private let inputPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        
        private let scrubber = ComponentView<Empty>()
        
        private let privacyButton = ComponentView<Empty>()
        private let flipStickerButton = ComponentView<Empty>()
        private let muteButton = ComponentView<Empty>()
        private let saveButton = ComponentView<Empty>()
        private let settingsButton = ComponentView<Empty>()
        
        private let textCancelButton = ComponentView<Empty>()
        private let textDoneButton = ComponentView<Empty>()
        private let textSize =  ComponentView<Empty>()
        
        private var isDismissed = false
        
        private var component: MediaEditorScreenComponent?
        private weak var state: State?
        private var environment: ViewControllerComponentContainer.Environment?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                        
            self.backgroundColor = .clear
            
            self.fadeView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
            self.fadeView.addTarget(self, action: #selector(self.fadePressed), for: .touchUpInside)
            self.fadeView.alpha = 0.0
            
            self.addSubview(self.fadeView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func fadePressed() {
            self.endEditing(true)
        }
        
        enum TransitionAnimationSource {
            case camera
            case gallery
        }
        func animateIn(from source: TransitionAnimationSource) {
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
            
            var delay: Double = 0.0
            for button in buttons {
                if let view = button.view {
                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: 64.0), to: .zero, duration: 0.3, delay: delay, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: delay)
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2, delay: delay)
                    delay += 0.05
                }
            }
                        
            if let view = self.doneButton.view {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
            }
            
            if case .camera = source {
                if let view = self.saveButton.view {
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
                
                if let view = self.muteButton.view {
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
                
                if let view = self.settingsButton.view {
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
                
                if let view = self.privacyButton.view {
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
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
                    view.layer.animateAlpha(from: view.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
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
            
            if let view = self.settingsButton.view {
                transition.setAlpha(view: view, alpha: 0.0)
                transition.setScale(view: view, scale: 0.1)
            }
            
            if let view = self.privacyButton.view {
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
        
        private var isEditingCaption = false
        func update(component: MediaEditorScreenComponent, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            guard !self.isDismissed else {
                return availableSize
            }
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let openDrawing = component.openDrawing
            let openTools = component.openTools
            
            let buttonSideInset: CGFloat = 10.0
            let buttonBottomInset: CGFloat = 8.0
            
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(
                        LottieAnimationComponent(
                            animation: LottieAnimationComponent.AnimationItem(
                                name: "media_backToCancel",
                                mode: .still(position: .begin),
                                range: nil
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
                origin: CGPoint(x: buttonSideInset, y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset),
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
            
            let doneButtonSize = self.doneButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Image(
                        image: state.image(.done),
                        size: CGSize(width: 33.0, height: 33.0)
                    )),
                    action: { [weak self] in
                        guard let self, let controller = environment.controller() as? MediaEditorScreen else {
                            return
                        }
                        guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                            return
                        }
                        var inputText = NSAttributedString(string: "")
                        switch inputPanelView.getSendMessageInput() {
                        case let .text(text):
                            inputText = NSAttributedString(string: text)
                        }
                        
                        controller.requestCompletion(caption: inputText, animated: true)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let doneButtonFrame = CGRect(
                origin: CGPoint(x: availableSize.width - buttonSideInset - doneButtonSize.width, y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset),
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
                origin: CGPoint(x: floorToScreenPixels(availableSize.width / 4.0 - 3.0 - drawButtonSize.width / 2.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + 1.0),
                size: drawButtonSize
            )
            if let drawButtonView = self.drawButton.view {
                if drawButtonView.superview == nil {
                    self.addSubview(drawButtonView)
                }
                transition.setPosition(view: drawButtonView, position: drawButtonFrame.center)
                transition.setBounds(view: drawButtonView, bounds: CGRect(origin: .zero, size: drawButtonFrame.size))
                transition.setAlpha(view: drawButtonView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
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
                origin: CGPoint(x: floorToScreenPixels(availableSize.width / 2.5 + 5.0 - textButtonSize.width / 2.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + 1.0),
                size: textButtonSize
            )
            if let textButtonView = self.textButton.view {
                if textButtonView.superview == nil {
                    self.addSubview(textButtonView)
                }
                transition.setPosition(view: textButtonView, position: textButtonFrame.center)
                transition.setBounds(view: textButtonView, bounds: CGRect(origin: .zero, size: textButtonFrame.size))
                transition.setAlpha(view: textButtonView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
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
                origin: CGPoint(x: floorToScreenPixels(availableSize.width - availableSize.width / 2.5 - 5.0 - stickerButtonSize.width / 2.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + 1.0),
                size: stickerButtonSize
            )
            if let stickerButtonView = self.stickerButton.view {
                if stickerButtonView.superview == nil {
                    self.addSubview(stickerButtonView)
                }
                transition.setPosition(view: stickerButtonView, position: stickerButtonFrame.center)
                transition.setBounds(view: stickerButtonView, bounds: CGRect(origin: .zero, size: stickerButtonFrame.size))
                transition.setAlpha(view: stickerButtonView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
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
                origin: CGPoint(x: floorToScreenPixels(availableSize.width / 4.0 * 3.0 + 3.0 - toolsButtonSize.width / 2.0), y: availableSize.height - environment.safeInsets.bottom + buttonBottomInset + 1.0),
                size: toolsButtonSize
            )
            if let toolsButtonView = self.toolsButton.view {
                if toolsButtonView.superview == nil {
                    self.addSubview(toolsButtonView)
                }
                transition.setPosition(view: toolsButtonView, position: toolsButtonFrame.center)
                transition.setBounds(view: toolsButtonView, bounds: CGRect(origin: .zero, size: toolsButtonFrame.size))
                transition.setAlpha(view: toolsButtonView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
            }
            
            let mediaEditor = component.mediaEditor
            
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
                    containerSize: CGSize(width: availableSize.width - scrubberInset * 2.0, height: availableSize.height)
                )
                
                let scrubberFrame = CGRect(origin: CGPoint(x: scrubberInset, y: availableSize.height - environment.safeInsets.bottom - scrubberSize.height - 8.0), size: scrubberSize)
                if let scrubberView = self.scrubber.view {
                    if scrubberView.superview == nil {
                        self.addSubview(scrubberView)
                    }
                    transition.setFrame(view: scrubberView, frame: scrubberFrame)
                    transition.setAlpha(view: scrubberView, alpha: component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
                }
                
                scrubberBottomInset = scrubberSize.height + 10.0
            } else {
                
            }
            
            var timeoutValue: String
            let timeoutSelected: Bool
            switch component.privacy {
            case let .story(_, timeout, archive):
                switch timeout {
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
                if archive {
                    timeoutValue = "∞"
                }
                timeoutSelected = false
            case let .message(_, timeout):
                timeoutValue = "\(timeout ?? 1)"
                timeoutSelected = timeout != nil
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
                    placeholder: "Add a caption...",
                    alwaysDarkWhenHasText: false,
                    presentController: { [weak self] c in
                        guard let self, let _ = self.component else {
                            return
                        }
                        //component.presentController(c)
                    },
                    sendMessageAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.endEditing(true)
                    },
                    setMediaRecordingActive: nil,
                    lockMediaRecording: nil,
                    stopAndPreviewMediaRecording: nil,
                    discardMediaRecordingPreview: nil,
                    attachmentAction: nil,
                    timeoutAction: { [weak self] view in
                        guard let self, let controller = self.environment?.controller() as? MediaEditorScreen else {
                            return
                        }
                        controller.presentTimeoutSetup(sourceView: view)
                    },
                    forwardAction: nil,
                    audioRecorder: nil,
                    videoRecordingStatus: nil,
                    isRecordingLocked: false,
                    recordedAudioPreview: nil,
                    wasRecordingDismissed: false,
                    timeoutValue: timeoutValue,
                    timeoutSelected: timeoutSelected,
                    displayGradient: false,
                    bottomInset: 0.0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 200.0)
            )
            
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
                    mediaEditor?.stop()
                } else {
                    mediaEditor?.play()
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
            
            var inputPanelOffset: CGFloat = 0.0
            var inputPanelBottomInset: CGFloat = scrubberBottomInset
            if environment.inputHeight > 0.0 {
                inputPanelBottomInset = environment.inputHeight - environment.safeInsets.bottom
                inputPanelOffset = inputPanelBottomInset
            }
            let inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - environment.safeInsets.bottom - inputPanelBottomInset - inputPanelSize.height - 3.0), size: inputPanelSize)
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    self.addSubview(inputPanelView)
                }
                transition.setFrame(view: inputPanelView, frame: inputPanelFrame)
                transition.setAlpha(view: inputPanelView, alpha: isEditingTextEntity || component.isDisplayingTool || component.isDismissing || component.isInteractingWithEntities ? 0.0 : 1.0)
            }
            
            let privacyText: String
            switch component.privacy {
            case let .story(privacy, _, _):
                switch privacy.base {
                case .everyone:
                    privacyText = "Everyone"
                case .closeFriends:
                    privacyText = "Close Friends"
                case .contacts:
                    privacyText = "Contacts"
                case .nobody:
                    privacyText = "Selected Contacts"
                }
            case let .message(peerIds, _):
                if peerIds.count == 1 {
                    privacyText = "1 Recipient"
                } else {
                    privacyText = "\(peerIds.count) Recipients"
                }
            }
            
            let displayTopButtons = !(self.inputPanelExternalState.isEditing || isEditingTextEntity || component.isDisplayingTool)
            
            let privacyButtonSize = self.privacyButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(
                        PrivacyButtonComponent(
                            icon: UIImage(bundleImageName: "Media Editor/Recipient")!,
                            text: privacyText
                        )
                    ),
                    action: {
                        if let controller = environment.controller() as? MediaEditorScreen {
                            controller.openPrivacySettings()
                        }
                    }
                ).tagged(privacyButtonTag)),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let privacyButtonFrame = CGRect(
                origin: CGPoint(x: 16.0, y: environment.safeInsets.top + 20.0 - inputPanelOffset),
                size: privacyButtonSize
            )
            if let privacyButtonView = self.privacyButton.view {
                if privacyButtonView.superview == nil {
                    self.addSubview(privacyButtonView)
                }
                transition.setPosition(view: privacyButtonView, position: privacyButtonFrame.center)
                transition.setBounds(view: privacyButtonView, bounds: CGRect(origin: .zero, size: privacyButtonFrame.size))
                transition.setScale(view: privacyButtonView, scale: displayTopButtons ? 1.0 : 0.01)
                transition.setAlpha(view: privacyButtonView, alpha: displayTopButtons && !component.isDismissing && !component.isInteractingWithEntities ? 1.0 : 0.0)
            }
            
            let saveButtonSize = self.saveButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(
                        LottieAnimationComponent(
                            animation: LottieAnimationComponent.AnimationItem(
                                name: "anim_storysave",
                                mode: .still(position: .begin),
                                range: nil
                            ),
                            colors: ["__allcolors__": .white],
                            size: CGSize(width: 33.0, height: 33.0)
                        ).tagged(saveButtonTag)
                    ),
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
                origin: CGPoint(x: availableSize.width - 20.0 - saveButtonSize.width, y: environment.safeInsets.top + 20.0 - inputPanelOffset),
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
             
            if let playerState = state.playerState, playerState.hasAudio {
                let isVideoMuted = component.mediaEditor?.values.videoIsMuted ?? false
                let muteButtonSize = self.muteButton.update(
                    transition: transition,
                    component: AnyComponent(Button(
                        content: AnyComponent(
                            LottieAnimationComponent(
                                animation: LottieAnimationComponent.AnimationItem(
                                    name: "anim_storymute",
                                    mode: .animating(loop: false),
                                    range: isVideoMuted ? (0.0, 0.5) : (0.5, 1.0)
                                ),
                                colors: ["__allcolors__": .white],
                                size: CGSize(width: 33.0, height: 33.0)
                            ).tagged(muteButtonTag)
                        ),
                        action: { [weak self, weak state] in
                            if let self, let mediaEditor = self.component?.mediaEditor {
                                mediaEditor.setVideoIsMuted(!mediaEditor.values.videoIsMuted)
                                state?.updated()
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                let muteButtonFrame = CGRect(
                    origin: CGPoint(x: availableSize.width - 20.0 - muteButtonSize.width - 50.0, y: environment.safeInsets.top + 20.0 - inputPanelOffset),
                    size: muteButtonSize
                )
                if let muteButtonView = self.muteButton.view {
                    if muteButtonView.superview == nil {
                        muteButtonView.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
                        muteButtonView.layer.shadowRadius = 2.0
                        muteButtonView.layer.shadowColor = UIColor.black.cgColor
                        muteButtonView.layer.shadowOpacity = 0.35
                        self.addSubview(muteButtonView)
                    }
                    transition.setPosition(view: muteButtonView, position: muteButtonFrame.center)
                    transition.setBounds(view: muteButtonView, bounds: CGRect(origin: .zero, size: muteButtonFrame.size))
                    transition.setScale(view: muteButtonView, scale: displayTopButtons ? 1.0 : 0.01)
                    transition.setAlpha(view: muteButtonView, alpha: displayTopButtons && !component.isDismissing && !component.isInteractingWithEntities ? 1.0 : 0.0)
                }
            }
            
            if let _ = state.playerState {
                let settingsButtonSize = self.settingsButton.update(
                    transition: transition,
                    component: AnyComponent(Button(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Chat/Input/Media/EntityInputSettingsIcon",
                                tintColor: UIColor(rgb: 0xffffff)
                            )
                        ),
                        action: {
                            if let controller = environment.controller() as? MediaEditorScreen {
                                controller.requestSettings()
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                let settingsButtonFrame = CGRect(
                    origin: CGPoint(x: floorToScreenPixels((availableSize.width - settingsButtonSize.width) / 2.0), y: environment.safeInsets.top + 20.0 - inputPanelOffset),
                    size: settingsButtonSize
                )
                if let settingsButtonView = self.settingsButton.view {
                    if settingsButtonView.superview == nil {
                        settingsButtonView.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
                        settingsButtonView.layer.shadowRadius = 2.0
                        settingsButtonView.layer.shadowColor = UIColor.black.cgColor
                        settingsButtonView.layer.shadowOpacity = 0.35
                        //self.addSubview(settingsButtonView)
                    }
                    transition.setPosition(view: settingsButtonView, position: settingsButtonFrame.center)
                    transition.setBounds(view: settingsButtonView, bounds: CGRect(origin: .zero, size: settingsButtonFrame.size))
                    transition.setScale(view: settingsButtonView, scale: displayTopButtons ? 1.0 : 0.01)
                    transition.setAlpha(view: settingsButtonView, alpha: displayTopButtons && !component.isDismissing && !component.isInteractingWithEntities ? 1.0 : 0.0)
                }
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
                origin: CGPoint(x: 13.0, y: environment.statusBarHeight + 20.0),
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
                origin: CGPoint(x: availableSize.width - textDoneButtonSize.width - 13.0, y: environment.statusBarHeight + 20.0),
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
            let bottomInset: CGFloat = environment.inputHeight > 0.0 ? environment.inputHeight : environment.safeInsets.bottom
            let textSizeFrame = CGRect(
                origin: CGPoint(x: 0.0, y: environment.safeInsets.top + (availableSize.height - environment.safeInsets.top - bottomInset) / 2.0 - textSizeSize.height / 2.0),
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

public final class MediaEditorScreen: ViewController {
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
        var privacy: MediaEditorResultPrivacy = .story(privacy: EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: []), timeout: 86400, archive: false)
    }
    
    var state = State() {
        didSet {
            self.node.requestUpdate()
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
        
        private let stickerPickerInputData = Promise<StickerPickerInputData>()
        
        private var dismissPanGestureRecognizer: UIPanGestureRecognizer?
        
        private var isDisplayingTool = false
        private var isInteractingWithEntities = false
        private var isEnhacing = false
        private var isDismissing = false
        private var dismissOffset: CGFloat = 0.0
        private var isDismissed = false
        
        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        init(controller: MediaEditorScreen) {
            self.controller = controller
            self.context = controller.context
            
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.backgroundDimView = UIView()
            self.backgroundDimView.isHidden = true
            self.backgroundDimView.backgroundColor = .black
            
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
            self.entitiesView = DrawingEntitiesView(context: controller.context, size: storyDimensions)
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
            self.view.addSubview(self.previewContainerView)
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
                    hasTrending: false,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: true,
                    areCustomEmojiEnabled: true,
                    chatPeerId: controller.context.account.peerId,
                    hasSearch: false,
                    forceHasPremium: true
                )
                
                let stickerItems = EmojiPagerContentComponent.stickerInputData(
                    context: controller.context,
                    animationCache: controller.context.animationCache,
                    animationRenderer: controller.context.animationRenderer,
                    stickerNamespaces: [Namespaces.ItemCollection.CloudStickerPacks],
                    stickerOrderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudAllPremiumStickers],
                    chatPeerId: controller.context.account.peerId,
                    hasSearch: false,
                    hasTrending: true,
                    forceHasPremium: true
                )
                
                let maskItems = EmojiPagerContentComponent.stickerInputData(
                    context: controller.context,
                    animationCache: controller.context.animationCache,
                    animationRenderer: controller.context.animationRenderer,
                    stickerNamespaces: [Namespaces.ItemCollection.CloudMaskPacks],
                    stickerOrderedItemListCollectionIds: [],
                    chatPeerId: controller.context.account.peerId,
                    hasSearch: false,
                    hasTrending: false,
                    forceHasPremium: true
                )
                
                let signal = combineLatest(queue: .mainQueue(),
                                           emojiItems,
                                           stickerItems,
                                           maskItems
                ) |> map { emoji, stickers, masks -> StickerPickerInputData in
                    return StickerPickerInputData(emoji: emoji, stickers: stickers, masks: masks)
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
        }
        
        private func setup(with subject: MediaEditorScreen.Subject) {
            self.subject = subject
            guard let controller = self.controller else {
                return
            }
            
            let isSavingAvailable: Bool
            switch subject {
            case .image, .video:
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
            self.entitiesView.add(mediaEntity, announce: false)
            
            let initialPosition = mediaEntity.position
            let initialScale = mediaEntity.scale
            let initialRotation = mediaEntity.rotation
            
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
            }
            
            let initialValues: MediaEditorValues?
            if case let .draft(draft, _) = subject {
                initialValues = draft.values
                
                for entity in draft.values.entities {
                    entitiesView.add(entity.entity, announce: false)
                }
            } else {
                initialValues = nil
            }
            let mediaEditor = MediaEditor(subject: subject.editorSubject, values: initialValues, hasHistogram: true)
            mediaEditor.attachPreviewView(self.previewView)
            mediaEditor.valuesUpdated = { [weak self] values in
                if let self, let controller = self.controller, values.gradientColors != nil, controller.previousSavedValues != values {
                    if !isSavingAvailable && controller.previousSavedValues == nil {
                        controller.previousSavedValues = values
                    } else {
                        controller.isSavingAvailable = true
                        controller.requestLayout(transition: .animated(duration: 0.25, curve: .easeInOut))
                    }
                }
            }
            
            self.gradientColorsDisposable = mediaEditor.gradientColors.start(next: { [weak self] colors in
                if let self, let colors {
                    let (topColor, bottomColor) = colors
                    let gradientImage = generateGradientImage(size: CGSize(width: 5.0, height: 640.0), colors: [topColor, bottomColor], locations: [0.0, 1.0])
                    Queue.mainQueue().async {
                        self.gradientView.image = gradientImage
                        
                        self.previewContainerView.alpha = 1.0
                        if CACurrentMediaTime() - self.initializationTimestamp > 0.2 {
                            self.previewContainerView.layer.allowsGroupOpacity = true
                            self.previewContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { _ in
                                self.previewContainerView.layer.allowsGroupOpacity = false
                                self.backgroundDimView.isHidden = false
                            })
                        } else {
                            self.backgroundDimView.isHidden = false
                        }
                    }
                }
            })
            self.mediaEditor = mediaEditor
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
            panGestureRecognizer.minimumNumberOfTouches = 2
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
                selectionContainerView: self.selectionContainerView,
                isVideo: false,
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
                        self.isInteractingWithEntities = isInteracting
                        self.requestUpdate(transition: .easeInOut(duration: 0.2))
                    }
                },
                getCurrentImage: {
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
        }
        
        @objc func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if let panRecognizer = gestureRecognizer as? UIPanGestureRecognizer, panRecognizer.minimumNumberOfTouches == 1, panRecognizer.state == .changed {
                return false
            } else if let panRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer, panRecognizer.minimumNumberOfTouches == 1, panRecognizer.state == .changed {
                return false
            } else if gestureRecognizer is UITapGestureRecognizer, (otherGestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIRotationGestureRecognizer) && otherGestureRecognizer.state == .changed {
                return false
            }
            return true
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === self.dismissPanGestureRecognizer {
                if self.isDisplayingTool || self.entitiesView.hasSelection {
                    return false
                }
                return true
            } else {
                return true
            }
        }
        
        private var enhanceGestureOffset: CGFloat?
        
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
                if abs(translation.y) > 10.0 && !self.isEnhacing && hasSwipeToDismiss {
                    if !self.isDismissing {
                        self.isDismissing = true
                        controller.requestLayout(transition: .animated(duration: 0.25, curve: .easeInOut))
                    }
                } else if abs(translation.x) > 10.0 && !self.isDismissing {
                    self.isEnhacing = true
                    controller.requestLayout(transition: .animated(duration: 0.3, curve: .easeInOut))
                }
                
                if self.isDismissing {
                    self.dismissOffset = translation.y
                    controller.requestLayout(transition: .immediate)
                } else if self.isEnhacing {
                    if let mediaEditor = self.mediaEditor {
                        let value = mediaEditor.getToolValue(.enhance) as? Float ?? 0.0
                        let delta = Float((translation.x / self.frame.width) * 1.5)
                        let updatedValue = max(-1.0, min(1.0, value + delta))
                        mediaEditor.setToolValue(.enhance, value: updatedValue)
                    }
                    self.requestUpdate()
                    gestureRecognizer.setTranslation(.zero, in: self.view)
                }
            case .ended, .cancelled:
                if self.isDismissing {
                    if abs(translation.y) > self.view.frame.height * 0.33 || abs(velocity.y) > 1000.0 {
                        controller.requestDismiss(saveDraft: false, animated: true)
                    } else {
                        self.dismissOffset = 0.0
                        self.isDismissing = false
                        controller.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
                    }
                } else {
                    self.isEnhacing = false
                    controller.requestLayout(transition: .animated(duration: 0.3, curve: .easeInOut))
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
                        let textEntity = DrawingTextEntity(text: NSAttributedString(), style: .regular, animation: .none, font: .sanFrancisco, alignment: .center, fontSize: 1.0, color: DrawingColor(color: .white))
                        self.interaction?.insertEntity(textEntity)
                    }
                }
            }
        }
        
        private func setupTransitionImage(_ image: UIImage) {
            self.previewContainerView.alpha = 1.0
            
            let transitionInView = UIImageView(image: image)
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
            if let transitionIn = self.controller?.transitionIn {
                switch transitionIn {
                case .camera:
                    if let view = self.componentHost.view as? MediaEditorScreenComponent.View {
                        view.animateIn(from: .camera)
                    }
                    if let subject = self.subject, case let .video(_, transitionImage, _) = subject, let transitionImage {
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
                        
                        self.previewContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: self.previewContainerView.center, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
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
                    view.animateIn(from: .camera)
                }
            }
            
            //            Queue.mainQueue().after(0.5) {
            //                self.presentPrivacyTooltip()
            //            }
        }
        
        func animateOut(finished: Bool, completion: @escaping () -> Void) {
            guard let controller = self.controller else {
                return
            }
            self.isDismissed = true
            controller.statusBar.statusBarStyle = .Ignore
            
            let previousDimAlpha = self.backgroundDimView.alpha
            self.backgroundDimView.alpha = 0.0
            self.backgroundDimView.layer.animateAlpha(from: previousDimAlpha, to: 0.0, duration: 0.15)
            
            if finished, case .message = controller.state.privacy {
                if let view = self.componentHost.view as? MediaEditorScreenComponent.View {
                    view.animateOut(to: .camera)
                }
                let transition = Transition(animation: .curve(duration: 0.25, curve: .easeInOut))
                transition.setAlpha(view: self.previewContainerView, alpha: 0.0, completion: { _ in
                    completion()
                    if let view = self.entitiesView.getView(where: { $0 is DrawingMediaEntityView }) as? DrawingMediaEntityView {
                        view.previewView = nil
                    }
                })
            } else if let transitionOut = controller.transitionOut(finished), let destinationView = transitionOut.destinationView {
                var destinationTransitionView: UIView?
                if !finished {
                    if let transitionIn = controller.transitionIn, case let .gallery(galleryTransitionIn) = transitionIn, let sourceImage = galleryTransitionIn.sourceImage {
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
                if let destinationNode = destinationView.asyncdisplaykit_node, destinationNode is AvatarNode, let snapshotView = destinationView.snapshotView(afterScreenUpdates: false) {
                    destinationView.isHidden = true
                    
                    snapshotView.layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
                    let snapshotScale = self.previewContainerView.bounds.width / snapshotView.frame.width
                    snapshotView.center = CGPoint(x: 0.0, y: self.previewContainerView.bounds.height / 2.0)
                                                        
                    let snapshotTransform = CATransform3DMakeScale(0.001, snapshotScale, 1.0)
                    //snapshotTransform.m34 = 1.0 / -500
                    //snapshotTransform = CATransform3DRotate(snapshotTransform, -90.0 * .pi / 180.0, 0.0, 1.0, 0.0)
                    
                    let targetTransform = CATransform3DMakeScale(snapshotScale, snapshotScale, 1.0)
                    //snapshotTransform
                    //targetTransform = CATransform3DRotate(targetTransform, 0.0, 0.0, 1.0, 0.0)
                    
                    snapshotView.layer.transform = snapshotTransform
                    Queue.mainQueue().after(0.15) {
                        snapshotView.layer.transform = targetTransform
                        snapshotView.layer.animate(from: NSValue(caTransform3D: snapshotTransform), to: NSValue(caTransform3D: targetTransform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
                    }
                    
                    self.previewContainerView.addSubview(snapshotView)
                    destinationSnapshotView = snapshotView
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
                completion()
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
        
        func presentPrivacyTooltip() {
            guard let sourceView = self.componentHost.findTaggedView(tag: privacyButtonTag) else {
                return
            }
            
            let parentFrame = self.view.convert(self.bounds, to: nil)
            let absoluteFrame = sourceView.convert(sourceView.bounds, to: nil).offsetBy(dx: -parentFrame.minX, dy: 0.0)
            let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.maxY + 3.0), size: CGSize())
            
            let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: "You can set who can view this story", location: .point(location, .top), displayDuration: .manual, inset: 16.0, shouldDismissOnTouch: { _ in
                return .ignore
            })
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
                text = "Video saved to Photos."
            } else {
                text = "Image saved to Photos."
            }
            
            if let tooltipController = self.saveTooltip {
                tooltipController.content = .completion(text)
            } else {
                let tooltipController = SaveProgressScreen(context: self.context, content: .completion(text))
                controller.present(tooltipController, in: .current)
                self.saveTooltip = tooltipController
            }
        }
        
        func updateEditProgress(_ progress: Float) {
            guard let controller = self.controller else {
                return
            }
            
            if let saveTooltip = self.saveTooltip {
                if case .completion = saveTooltip.content {
                    saveTooltip.dismiss()
                    self.saveTooltip = nil
                }
            }
            
            let text = "Uploading..."
            
            if let tooltipController = self.saveTooltip {
                tooltipController.content = .progress(text, progress)
            } else {
                let tooltipController = SaveProgressScreen(context: self.context, content: .progress(text, 0.0))
                tooltipController.cancelled = { [weak self] in
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
            
            let text = "Preparing video..."
            
            if let tooltipController = self.saveTooltip {
                tooltipController.content = .progress(text, progress)
            } else {
                let tooltipController = SaveProgressScreen(context: self.context, content: .progress(text, 0.0))
                tooltipController.cancelled = { [weak self] in
                    if let self, let controller = self.controller {
                        controller.cancelVideoExport()
                    }
                }
                controller.present(tooltipController, in: .current)
                self.saveTooltip = tooltipController
            }
        }
        
        private weak var storyArchiveTooltip: ViewController?
        func presentStoryArchiveTooltip(sourceView: UIView) {
            guard let controller = self.controller, case let .story(_, _, archive) = controller.state.privacy else {
                return
            }
            
            if let storyArchiveTooltip = self.storyArchiveTooltip {
                storyArchiveTooltip.dismiss(animated: true)
                self.storyArchiveTooltip = nil
            }
            
            let parentFrame = self.view.convert(self.bounds, to: nil)
            let absoluteFrame = sourceView.convert(sourceView.bounds, to: nil).offsetBy(dx: -parentFrame.minX, dy: 0.0)
            let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY - 5.0), size: CGSize())
            
            let text: String
            if archive {
                text = "Story will be kept on your page."
            } else {
                text = "Story will disappear in 24 hours."
            }
            
            let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: text, location: .point(location, .bottom), displayDuration: .default, inset: 7.0, cornerRadius: 9.0, shouldDismissOnTouch: { _ in
                return .ignore
            })
            self.storyArchiveTooltip = tooltipController
            self.controller?.present(tooltipController, in: .current)
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.componentHost.view {
                let point = self.view.convert(point, to: self.previewContainerView)
                return self.previewContainerView.hitTest(point, with: event)
            }
            return result
        }
        
        func requestUpdate(transition: Transition = .immediate) {
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout: layout, transition: transition)
            }
        }
        
        private var drawingScreen: DrawingScreen?
        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, animateOut: Bool = false, transition: Transition) {
            guard let controller = self.controller, !self.isDismissed else {
                return
            }
            let isFirstTime = self.validLayout == nil
            self.validLayout = layout

            let previewSize = CGSize(width: layout.size.width, height: floorToScreenPixels(layout.size.width * 1.77778))
            let topInset: CGFloat = (layout.statusBarHeight ?? 0.0) + 12.0 //floorToScreenPixels(layout.size.height - previewSize.height) / 2.0
            let bottomInset = layout.size.height - previewSize.height - topInset
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: 0.0,
                safeInsets: UIEdgeInsets(
                    top: topInset,
                    left: layout.safeInsets.left,
                    bottom: bottomInset,
                    right: layout.safeInsets.right
                ),
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: nil,
                isVisible: true,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )

            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    MediaEditorScreenComponent(
                        context: self.context,
                        isDisplayingTool: self.isDisplayingTool,
                        isInteractingWithEntities: self.isInteractingWithEntities,
                        isSavingAvailable: controller.isSavingAvailable,
                        isDismissing: self.isDismissing,
                        mediaEditor: self.mediaEditor,
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
                                    let controller = StickerPickerScreen(context: self.context, inputData: self.stickerPickerInputData.get())
                                    controller.completion = { [weak self] file in
                                        if let self, let file {
                                            let stickerEntity = DrawingStickerEntity(content: .file(file))
                                            self.interaction?.insertEntity(stickerEntity)
                                            
                                            self.controller?.isSavingAvailable = true
                                            self.controller?.requestLayout(transition: .immediate)
                                        }
                                    }
                                    self.controller?.present(controller, in: .current)
                                    return
                                case .text:
                                    let textEntity = DrawingTextEntity(text: NSAttributedString(), style: .regular, animation: .none, font: .sanFrancisco, alignment: .center, fontSize: 1.0, color: DrawingColor(color: .white))
                                    self.interaction?.insertEntity(textEntity)
                                    
                                    self.controller?.isSavingAvailable = true
                                    self.controller?.requestLayout(transition: .immediate)
                                    return
                                case .drawing:
                                    self.interaction?.deactivate()
                                    let controller = DrawingScreen(context: self.context, sourceHint: .storyEditor, size: self.previewContainerView.frame.size, originalSize: storyDimensions, isVideo: false, isAvatar: false, drawingView: self.drawingView, entitiesView: self.entitiesView, selectionContainerView: self.selectionContainerView, existingStickerPickerInputData: self.stickerPickerInputData)
                                    self.drawingScreen = controller
                                    self.drawingView.isUserInteractionEnabled = true

                                    controller.requestDismiss = { [weak controller, weak self] in
                                        self?.drawingScreen = nil
                                        controller?.animateOut({
                                            controller?.dismiss()
                                        })
                                        self?.drawingView.isUserInteractionEnabled = false
                                        self?.animateInFromTool()

                                        self?.interaction?.activate()
                                        self?.entitiesView.selectEntity(nil)
                                    }
                                    controller.requestApply = { [weak controller, weak self] in
                                        self?.drawingScreen = nil
                                        controller?.animateOut({
                                            controller?.dismiss()
                                        })
                                        self?.drawingView.isUserInteractionEnabled = false
                                        self?.animateInFromTool()

                                        if let result = controller?.generateDrawingResultData() {
                                            self?.mediaEditor?.setDrawingAndEntities(data: result.data, image: result.drawingImage, entities: result.entities)
                                        } else {
                                            self?.mediaEditor?.setDrawingAndEntities(data: nil, image: nil, entities: [])
                                        }

                                        self?.interaction?.activate()
                                        self?.entitiesView.selectEntity(nil)
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
                                self.controller?.present(controller, in: .current)
                                self.animateOutToTool()
                            }
                        }
                    )
                ),
                environment: {
                    environment
                },
                forceUpdate: forceUpdate || animateOut,
                containerSize: layout.size
            )
            if let componentView = self.componentHost.view {
                if componentView.superview == nil {
                    self.view.insertSubview(componentView, at: 3)
                    componentView.clipsToBounds = true
                }
                transition.setFrame(view: componentView, frame: CGRect(origin: CGPoint(x: 0.0, y: self.dismissOffset), size: componentSize))
            }
            
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
                        title: "Enhance",
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
                transition.setAlpha(view: toolValueView, alpha: self.isEnhacing ? 1.0 : 0.0)
            }
            
            transition.setFrame(view: self.backgroundDimView, frame: CGRect(origin: .zero, size: layout.size))
            transition.setAlpha(view: self.backgroundDimView, alpha: self.isDismissing ? 0.0 : 1.0)
            
            var bottomInputOffset: CGFloat = 0.0
            if let inputHeight = layout.inputHeight, inputHeight > 0.0 {
                if self.entitiesView.selectedEntityView != nil || self.isDisplayingTool {
                    bottomInputOffset = inputHeight / 2.0
                } else {
                    bottomInputOffset = inputHeight - bottomInset - 17.0
                }
            }
            
            let previewFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset - bottomInputOffset + self.dismissOffset), size: previewSize)
            transition.setFrame(view: self.previewContainerView, frame: previewFrame)
            let entitiesViewScale = previewSize.width / storyDimensions.width
            self.entitiesContainerView.transform = CGAffineTransformMakeScale(entitiesViewScale, entitiesViewScale)
            self.entitiesContainerView.frame = CGRect(origin: .zero, size: previewFrame.size)
            transition.setFrame(view: self.gradientView, frame: CGRect(origin: .zero, size: previewFrame.size))
            transition.setFrame(view: self.drawingView, frame: CGRect(origin: .zero, size: self.entitiesView.bounds.size))
                        
            transition.setFrame(view: self.selectionContainerView, frame: CGRect(origin: .zero, size: previewFrame.size))
            
            self.interaction?.containerLayoutUpdated(layout: layout, transition: transition)
            
            if isFirstTime {
                self.animateIn()
            }
        }
    }
    
    fileprivate var node: Node {
        return self.displayNode as! Node
    }
    
    public enum Subject {
        case image(UIImage, PixelDimensions)
        case video(String, UIImage?, PixelDimensions)
        case asset(PHAsset)
        case draft(MediaEditorDraft, Int64?)
        
        var dimensions: PixelDimensions {
            switch self {
            case let .image(_, dimensions), let .video(_, _, dimensions):
                return dimensions
            case let .asset(asset):
                return PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
            case let .draft(draft, _):
                return draft.dimensions
            }
        }
        
        var editorSubject: MediaEditor.Subject {
            switch self {
            case let .image(image, dimensions):
                return .image(image, dimensions)
            case let .video(videoPath, transitionImage, dimensions):
                return .video(videoPath, transitionImage, dimensions)
            case let .asset(asset):
                return .asset(asset)
            case let .draft(draft, _):
                return .draft(draft)
            }
        }
        
        var mediaContent: DrawingMediaEntity.Content {
            switch self {
            case let .image(image, dimensions):
                return .image(image, dimensions)
            case let .video(videoPath, _, dimensions):
                return .video(videoPath, dimensions)
            case let .asset(asset):
                return .asset(asset)
            case let .draft(draft, _):
                return .image(draft.thumbnail, draft.dimensions)
            }
        }
    }
    
    public enum Result {
        public enum VideoResult {
            case imageFile(path: String)
            case videoFile(path: String)
            case asset(localIdentifier: String)
        }
        case image(image: UIImage, dimensions: PixelDimensions, caption: NSAttributedString?)
        case video(video: VideoResult, coverImage: UIImage?, values: MediaEditorValues, duration: Double, dimensions: PixelDimensions, caption: NSAttributedString?)
    }
    
    fileprivate let context: AccountContext
    fileprivate let subject: Signal<Subject?, NoError>
    fileprivate let transitionIn: TransitionIn?
    fileprivate let transitionOut: (Bool) -> TransitionOut?
        
    public var cancelled: (Bool) -> Void = { _ in }
    public var completion: (Int64, MediaEditorScreen.Result, MediaEditorResultPrivacy, @escaping (@escaping () -> Void) -> Void) -> Void = { _, _, _, _ in }
    public var dismissed: () -> Void = { }
    
    private let hapticFeedback = HapticFeedback()
    
    public init(
        context: AccountContext,
        subject: Signal<Subject?, NoError>,
        transitionIn: TransitionIn?,
        transitionOut: @escaping (Bool) -> TransitionOut?,
        completion: @escaping (Int64, MediaEditorScreen.Result, MediaEditorResultPrivacy, @escaping (@escaping () -> Void) -> Void) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.transitionIn = transitionIn
        self.transitionOut = transitionOut
        self.completion = completion
        
        if let transitionIn, case .camera = transitionIn {
            self.isSavingAvailable = true
        }
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .flatModal
                    
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = .White
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
    }
            
    func openPrivacySettings() {
        self.hapticFeedback.impact(.light)
    
        if case .message(_, _) = self.state.privacy {
            self.openSendAsMessage()
        } else {
            let stateContext = ShareWithPeersScreen.StateContext(context: self.context, subject: .stories)
            let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                
                var archive = true
                var timeout: Int = 86400
                let initialPrivacy: EngineStoryPrivacy
                if case let .story(privacy, timeoutValue, archiveValue) = self.state.privacy {
                    initialPrivacy = privacy
                    timeout = timeoutValue
                    archive = archiveValue
                } else {
                    initialPrivacy = EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: [])
                }
                
                self.push(
                    ShareWithPeersScreen(
                        context: self.context,
                        initialPrivacy: initialPrivacy,
                        stateContext: stateContext,
                        completion: { [weak self] privacy in
                            guard let self else {
                                return
                            }
                            self.state.privacy = .story(privacy: privacy, timeout: timeout, archive: archive)
                        },
                        editCategory: { [weak self] privacy in
                            guard let self else {
                                return
                            }
                            self.openEditCategory(privacy: privacy, completion: { [weak self] privacy in
                                guard let self else {
                                    return
                                }
                                self.state.privacy = .story(privacy: privacy, timeout: timeout, archive: archive)
                                self.openPrivacySettings()
                            })
                        },
                        secondaryAction: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.openSendAsMessage()
                        }
                    )
                )
            })
        }
    }
    
    private func openEditCategory(privacy: EngineStoryPrivacy, completion: @escaping (EngineStoryPrivacy) -> Void) {
        let stateContext = ShareWithPeersScreen.StateContext(context: self.context, subject: .contacts(privacy.base))
        let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let self else {
                return
            }
            
            self.push(
                ShareWithPeersScreen(
                    context: self.context,
                    initialPrivacy: privacy,
                    stateContext: stateContext,
                    completion: { [weak self] result in
                        guard let self else {
                            return
                        }
                        if case .closeFriends = privacy.base {
                            let _ = self.context.engine.privacy.updateCloseFriends(peerIds: result.additionallyIncludePeers).start()
                        }
                        completion(result)
                    },
                    editCategory: { _ in },
                    secondaryAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openSendAsMessage()
                    }
                )
            )
        })
    }
    
    private func openSendAsMessage() {
        var initialPeerIds = Set<EnginePeer.Id>()
        if case let .message(peers, _) = self.state.privacy {
            initialPeerIds = Set(peers)
        }
        let stateContext = ShareWithPeersScreen.StateContext(context: self.context, subject: .chats, initialPeerIds: initialPeerIds)
        let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let self else {
                return
            }
            
            self.push(
                ShareWithPeersScreen(
                    context: self.context,
                    initialPrivacy: EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: []),
                    stateContext: stateContext,
                    completion: { [weak self] privacy in
                        guard let self else {
                            return
                        }
                        self.state.privacy = .message(peers: privacy.additionallyIncludePeers, timeout: nil)
                    },
                    editCategory: { _ in },
                    secondaryAction: {}
                )
            )
        })
    }
    
    func presentTimeoutSetup(sourceView: UIView) {
        self.hapticFeedback.impact(.light)
        
        var items: [ContextMenuItem] = []

        let updateTimeout: (Int?, Bool) -> Void = { [weak self] timeout, archive in
            guard let self else {
                return
            }
            switch self.state.privacy {
            case let .story(privacy, _, _):
                self.state.privacy = .story(privacy: privacy, timeout: timeout ?? 86400, archive: archive)
            case let .message(peers, _):
                self.state.privacy = .message(peers: peers, timeout: timeout)
            }
        }
        
        var currentValue: Int?
        var currentArchived = false
        let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil
        let title: String
        switch self.state.privacy {
        case let .story(_, timeoutValue, archivedValue):
            title = "Choose how long the story will be visible."
            currentValue = timeoutValue
            currentArchived = archivedValue
        case let .message(_, timeoutValue):
            title = "Choose how long the media will be kept after opening."
            currentValue = timeoutValue
        }
        
        items.append(.action(ContextMenuActionItem(text: title, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction)))
        
        switch self.state.privacy {
        case .story:
            items.append(.action(ContextMenuActionItem(text: "6 Hours", icon: { theme in
                return currentValue == 3600 * 6 ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(3600 * 6, false)
            })))
            items.append(.action(ContextMenuActionItem(text: "12 Hours", icon: { theme in
                return currentValue == 3600 * 12 ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(3600 * 12, false)
            })))
            items.append(.action(ContextMenuActionItem(text: "24 Hours", icon: { theme in
                return currentValue == 86400 && !currentArchived ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(86400, false)
            })))
            items.append(.action(ContextMenuActionItem(text: "48 Hours", icon: { theme in
                return currentValue == 86400 * 2 ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(86400 * 2, false)
            })))
            items.append(.action(ContextMenuActionItem(text: "Keep Always", icon: { theme in
                return currentArchived ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(86400, true)
            })))
            items.append(.separator)
            items.append(.action(ContextMenuActionItem(text: "Select 'Keep Always' to always show the story in your profile.", textLayout: .multiline, textFont: .small, icon: { theme in
                return nil
            }, action: { _, _ in
            })))
        case .message:
            items.append(.action(ContextMenuActionItem(text: "Until First View", icon: { _ in
                return nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(1, false)
            })))
            items.append(.action(ContextMenuActionItem(text: "3 Seconds", icon: { _ in
                return nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(3, false)
            })))
            items.append(.action(ContextMenuActionItem(text: "10 Seconds", icon: { _ in
                return nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(10, false)
            })))
            items.append(.action(ContextMenuActionItem(text: "1 Minute", icon: { _ in
                return nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(60, false)
            })))
            items.append(.action(ContextMenuActionItem(text: "Keep Always", icon: { _ in
                return nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(nil, false)
            })))
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkPresentationTheme)
        let contextController = ContextController(account: self.context.account, presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: self, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
        self.present(contextController, in: .window(.root))
    }
    
    func maybePresentDiscardAlert() {
        self.hapticFeedback.impact(.light)
        if "".isEmpty {
            self.requestDismiss(saveDraft: false, animated: true)
            return
        }
        if let subject = self.node.subject, case .asset = subject, self.node.mediaEditor?.values.hasChanges == false {
            self.requestDismiss(saveDraft: false, animated: true)
            return
        }
        let title: String
        let save: String
        if case .draft = self.node.subject {
            title = "Discard Draft?"
            save = "Keep Draft"
        } else {
            title = "Discard Media?"
            save = "Save Draft"
        }
        let theme = defaultDarkPresentationTheme
        let controller = textAlertController(
            context: self.context,
            forceTheme: theme,
            title: title,
            text: "If you go back now, you will lose any changes that you've made.",
            actions: [
                TextAlertAction(type: .destructiveAction, title: "Discard", action: { [weak self] in
                    if let self {
                        self.requestDismiss(saveDraft: false, animated: true)
                    }
                }),
                TextAlertAction(type: .genericAction, title: save, action: { [weak self] in
                    if let self {
                        self.requestDismiss(saveDraft: true, animated: true)
                    }
                }),
                TextAlertAction(type: .genericAction, title: "Cancel", action: {
                    
                })
            ],
            actionLayout: .vertical
        )
        self.present(controller, in: .window(.root))
    }
    
    func requestDismiss(saveDraft: Bool, animated: Bool) {
        self.dismissAllTooltips()
        
        if saveDraft {
            self.saveDraft(id: nil)
        } else {
//            if case let .draft(draft) = self.node.subject {
//                removeStoryDraft(engine: self.context.engine, path: draft.path, delete: true)
//            }
        }
        
        if let mediaEditor = self.node.mediaEditor {
            mediaEditor.invalidate()
        }
        
        self.cancelled(saveDraft)
        
        self.node.animateOut(finished: false, completion: { [weak self] in
            self?.dismiss()
            self?.dismissed()
        })
    }
    
    private func saveDraft(id: Int64?) {
        guard let subject = self.node.subject, let values = self.node.mediaEditor?.values else {
            return
        }
        try? FileManager.default.createDirectory(atPath: draftPath(), withIntermediateDirectories: true)
        
        let privacy = self.state.privacy
        
        if let resultImage = self.node.mediaEditor?.resultImage {
            self.node.mediaEditor?.seek(0.0, andPlay: false)
            makeEditorImageComposition(account: self.context.account, inputImage: resultImage, dimensions: storyDimensions, values: values, time: .zero, completion: { resultImage in
                guard let resultImage else {
                    return
                }
                let fittedSize = resultImage.size.aspectFitted(CGSize(width: 128.0, height: 128.0))
                
                let saveImageDraft: (UIImage, PixelDimensions) -> Void = { image, dimensions in
                    if let thumbnailImage = generateScaledImage(image: resultImage, size: fittedSize) {
                        let path = draftPath() + "/\(Int64.random(in: .min ... .max)).jpg"
                        if let data = image.jpegData(compressionQuality: 0.87) {
                            try? data.write(to: URL(fileURLWithPath: path))
                            let draft = MediaEditorDraft(path: path, isVideo: false, thumbnail: thumbnailImage, dimensions: dimensions, values: values, caption: NSAttributedString(), privacy: privacy)
                            if let id {
                                saveStorySource(engine: self.context.engine, item: draft, id: id)
                            } else {
                                addStoryDraft(engine: self.context.engine, item: draft)
                            }
                        }
                    }
                }
                
                let saveVideoDraft: (String, PixelDimensions) -> Void = { videoPath, dimensions in
                    if let thumbnailImage = generateScaledImage(image: resultImage, size: fittedSize) {
                        let path = draftPath() + "/\(Int64.random(in: .min ... .max)).mp4"
                        try? FileManager.default.moveItem(atPath: videoPath, toPath: path)
                        let draft = MediaEditorDraft(path: path, isVideo: true, thumbnail: thumbnailImage, dimensions: dimensions, values: values, caption: NSAttributedString(), privacy: privacy)
                        if let id {
                            saveStorySource(engine: self.context.engine, item: draft, id: id)
                        } else {
                            addStoryDraft(engine: self.context.engine, item: draft)
                        }
                    }
                }
                
                switch subject {
                case let .image(image, dimensions):
                    saveImageDraft(image, dimensions)
                case let .video(path, _, dimensions):
                    saveVideoDraft(path, dimensions)
                case let .asset(asset):
                    if asset.mediaType == .video {
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let urlAsset = avAsset as? AVURLAsset {
                                saveVideoDraft(urlAsset.url.absoluteString, PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight)))
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
                        saveVideoDraft(draft.path, draft.dimensions)
                    } else if let image = UIImage(contentsOfFile: draft.path) {
                        saveImageDraft(image, draft.dimensions)
                    }
//                    if let thumbnailImage = generateScaledImage(image: resultImage, size: fittedSize) {
//                        removeStoryDraft(engine: self.context.engine, path: draft.path, delete: false)
//                        let draft = MediaEditorDraft(path: draft.path, isVideo: draft.isVideo, thumbnail: thumbnailImage, dimensions: draft.dimensions, values: values)
//                        addStoryDraft(engine: self.context.engine, item: draft)
//                    }
                }
            })
        }
    }
        
    private var didComplete = false
    func requestCompletion(caption: NSAttributedString, animated: Bool) {
        guard let mediaEditor = self.node.mediaEditor, let subject = self.node.subject, !self.didComplete else {
            return
        }
        self.didComplete = true
        
        self.dismissAllTooltips()
        
        mediaEditor.invalidate()
        
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.updateRootContainerTransitionOffset(0.0, transition: .immediate)
        }
        
        let entities = self.node.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
        let codableEntities = DrawingEntitiesView.encodeEntities(entities, entitiesView: self.node.entitiesView)
        mediaEditor.setDrawingAndEntities(data: nil, image: mediaEditor.values.drawing, entities: codableEntities)
        
        let randomId: Int64
        if case let .draft(_, id) = subject, let id {
            randomId = id
        } else {
            randomId = Int64.random(in: .min ... .max)
        }
        
        if mediaEditor.resultIsVideo {
            let videoResult: Result.VideoResult
            let duration: Double
            switch subject {
            case let .image(image, _):
                let tempImagePath = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).jpg"
                if let data = image.jpegData(compressionQuality: 0.85) {
                    try? data.write(to: URL(fileURLWithPath: tempImagePath))
                }
                videoResult = .imageFile(path: tempImagePath)
                duration = 5.0
            case let .video(path, _, _):
                videoResult = .videoFile(path: path)
                if let videoTrimRange = mediaEditor.values.videoTrimRange {
                    duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
                } else {
                    duration = 5.0
                }
            case let .asset(asset):
                videoResult = .asset(localIdentifier: asset.localIdentifier)
                if asset.mediaType == .video {
                    if let videoTrimRange = mediaEditor.values.videoTrimRange {
                        duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
                    } else {
                        duration = asset.duration
                    }
                } else {
                    duration = 5.0
                }
            case let .draft(draft, _):
                if draft.isVideo {
                    videoResult = .videoFile(path: draft.path)
                    if let videoTrimRange = mediaEditor.values.videoTrimRange {
                        duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
                    } else {
                        duration = 5.0
                    }
                } else {
                    videoResult = .imageFile(path: draft.path)
                    duration = 5.0
                }
            }
            self.completion(randomId, .video(video: videoResult, coverImage: nil, values: mediaEditor.values, duration: duration, dimensions: mediaEditor.values.resultDimensions, caption: caption), self.state.privacy, { [weak self] finished in
                self?.node.animateOut(finished: true, completion: { [weak self] in
                    self?.dismiss()
                    Queue.mainQueue().justDispatch {
                        finished()
                    }
                })
            })
            
            if case let .draft(draft, id) = subject, id == nil {
                removeStoryDraft(engine: self.context.engine, path: draft.path, delete: true)
            }
        } else {
            if let image = mediaEditor.resultImage {
                self.saveDraft(id: randomId)
                
                makeEditorImageComposition(account: self.context.account, inputImage: image, dimensions: storyDimensions, values: mediaEditor.values, time: .zero, completion: { [weak self] resultImage in
                    if let self, let resultImage {
                        self.completion(randomId, .image(image: resultImage, dimensions: PixelDimensions(resultImage.size), caption: caption), self.state.privacy, { [weak self] finished in
                            self?.node.animateOut(finished: true, completion: { [weak self] in
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
        guard let mediaEditor = self.node.mediaEditor, let subject = self.node.subject, self.isSavingAvailable else {
            return
        }
            
        let entities = self.node.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
        let codableEntities = DrawingEntitiesView.encodeEntities(entities, entitiesView: self.node.entitiesView)
        mediaEditor.setDrawingAndEntities(data: nil, image: mediaEditor.values.drawing, entities: codableEntities)
        
        if let previousSavedValues = self.previousSavedValues, mediaEditor.values == previousSavedValues {
            return
        }
        
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
            case let .video(path, _, _):
                let asset = AVURLAsset(url: NSURL(fileURLWithPath: path) as URL)
                exportSubject = .single(.video(asset))
            case let .image(image, _):
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
                    let asset = AVURLAsset(url: NSURL(fileURLWithPath: draft.path) as URL)
                    exportSubject = .single(.video(asset))
                } else {
                    if let image = UIImage(contentsOfFile: draft.path) {
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
                let configuration = recommendedVideoExportConfiguration(values: mediaEditor.values, forceFullHd: true, frameRate: 60.0)
                let outputPath = NSTemporaryDirectory() + "\(Int64.random(in: 0 ..< .max)).mp4"
                let videoExport = MediaEditorVideoExport(account: self.context.account, subject: exportSubject, configuration: configuration, outputPath: outputPath)
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
                    makeEditorImageComposition(account: self.context.account, inputImage: image, dimensions: storyDimensions, values: mediaEditor.values, time: .zero, completion: { resultImage in
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
    
    func requestSettings() {
        
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
    
    public func updateEditProgress(_ progress: Float) {
        self.node.updateEditProgress(progress)
    }
    
    private func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
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
}

final class PrivacyButtonComponent: CombinedComponent {
    let icon: UIImage
    let text: String

    init(
        icon: UIImage,
        text: String
    ) {
        self.icon = icon
        self.text = text
    }

    static func ==(lhs: PrivacyButtonComponent, rhs: PrivacyButtonComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        return true
    }

    static var body: Body {
        let background = Child(BlurredBackgroundComponent.self)
        let icon = Child(Image.self)
        let text = Child(Text.self)

        return { context in
            let icon = icon.update(
                component: Image(image: context.component.icon, size: CGSize(width: 9.0, height: 11.0)),
                availableSize: CGSize(width: 180.0, height: 100.0),
                transition: .immediate
            )
            
            let text = text.update(
                component: Text(
                    text: "\(context.component.text)",
                    font: Font.medium(14.0),
                    color: .white
                ),
                availableSize: CGSize(width: 180.0, height: 100.0),
                transition: .immediate
            )

            let backgroundSize = CGSize(width: text.size.width + 38.0, height: 30.0)
            let background = background.update(
                component: BlurredBackgroundComponent(color: UIColor(white: 0.0, alpha: 0.5)),
                availableSize: backgroundSize,
                transition: .immediate
            )

            context.add(background
                .position(CGPoint(x: backgroundSize.width / 2.0, y: backgroundSize.height / 2.0))
                .cornerRadius(min(backgroundSize.width, backgroundSize.height) / 2.0)
                .clipsToBounds(true)
            )
            
            context.add(icon
                .position(CGPoint(x: 16.0, y: backgroundSize.height / 2.0))
            )

            context.add(text
                .position(CGPoint(x: backgroundSize.width / 2.0 + 7.0, y: backgroundSize.height / 2.0))
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

private func draftPath() -> String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/storyDrafts"
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
                self.hapticFeedback.impact(.click05)
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
