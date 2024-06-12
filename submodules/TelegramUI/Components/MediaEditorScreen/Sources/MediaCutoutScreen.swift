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
import DustEffect
import PlainButtonComponent
import ImageObjectSeparation

private final class MediaCutoutScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mediaEditor: MediaEditor
    
    init(
        context: AccountContext,
        mediaEditor: MediaEditor
    ) {
        self.context = context
        self.mediaEditor = mediaEditor
    }
    
    static func ==(lhs: MediaCutoutScreenComponent, rhs: MediaCutoutScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        enum ImageKey: Hashable {
            case done
        }
        private var cachedImages: [ImageKey: UIImage] = [:]
        func image(_ key: ImageKey) -> UIImage {
            if let image = self.cachedImages[key] {
                return image
            } else {
                var image: UIImage
                switch key {
                case .done:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Done"), color: .white)!
                }
                cachedImages[key] = image
                return image
            }
        }
    }
    
    func makeState() -> State {
        return State()
    }

    public final class View: UIView {
        private let buttonsContainerView = UIView()
        private let buttonsBackgroundView = UIView()
        private let previewContainerView = UIView()
        private let cancelButton = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
    
        private let fadeView = UIView()
        private var outlineViews: [StickerCutoutOutlineView] = []
                        
        private var component: MediaCutoutScreenComponent?
        private weak var state: State?
        private var environment: ViewControllerComponentContainer.Environment?
        
        override init(frame: CGRect) {
            self.buttonsContainerView.clipsToBounds = true

            self.fadeView.alpha = 0.0
            self.fadeView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.7)
            
            super.init(frame: frame)
            
            self.backgroundColor = .clear

            self.addSubview(self.buttonsContainerView)
            self.buttonsContainerView.addSubview(self.buttonsBackgroundView)
            
            self.addSubview(self.fadeView)
            self.addSubview(self.previewContainerView)
            
            self.previewContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.previewTap(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func previewTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let component = self.component, let controller = self.environment?.controller() as? MediaCutoutScreen else {
                return
            }
            
            let location = gestureRecognizer.location(in: controller.drawingView)
            
            let point = CGPoint(
                x: location.x / controller.drawingView.bounds.width,
                y: location.y / controller.drawingView.bounds.height
            )
            let validRange: Range<CGFloat> = 0.0 ..< 1.0
            guard validRange.contains(point.x) && validRange.contains(point.y) else {
                return
            }
            
            component.mediaEditor.processImage { [weak self] originalImage, _ in
                cutoutImage(from: originalImage, crop: nil, target: .point(point), includeExtracted: false, completion: { [weak self] results in
                    Queue.mainQueue().async {
                        if let self, let _ = self.component, let result = results.first, let maskImage = result.maskImage, let controller = self.environment?.controller() as? MediaCutoutScreen {
                            if case let .image(mask, _) = maskImage {
                                self.playDissolveAnimation()
                                component.mediaEditor.setSegmentationMask(mask)
                                if let maskData = mask.pngData() {
                                    controller.drawingView.setup(withDrawing: maskData)
                                }
                            }
                        }
                    }
                })
            }
            
            HapticFeedback().impact(.medium)
        }
        
        var initialOutlineValue: Float?
        func animateInFromEditor() {
            guard let controller = self.environment?.controller() as? MediaCutoutScreen else {
                return
            }
            
            let mediaEditor = controller.mediaEditor
            self.initialOutlineValue = mediaEditor.getToolValue(.stickerOutline) as? Float
            mediaEditor.setToolValue(.stickerOutline, value: nil)
            mediaEditor.isSegmentationMaskEnabled = false
            controller.previewView.mask = controller.maskWrapperView
            
            self.buttonsBackgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.label.view?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            
            if let view = self.doneButton.view {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
            }
                        
            guard [.erase, .restore].contains(controller.mode) else {
                return
            }
            controller.drawingView.isUserInteractionEnabled = true
           
            self.updateBackgroundViews()
        }
        
        func updateBackgroundViews() {
            guard let controller = self.environment?.controller() as? MediaCutoutScreen else {
                return
            }
            let overlayView = controller.overlayView
            let backgroundView = controller.backgroundView
            
            let overlayAlpha: CGFloat
            let backgroundAlpha: CGFloat
            switch controller.mode {
            case .restore:
                overlayAlpha = 1.0
                backgroundAlpha = 0.0
            default:
                overlayAlpha = 0.0
                backgroundAlpha = 1.0
            }
            let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
            transition.setAlpha(view: overlayView, alpha: overlayAlpha)
            transition.setAlpha(view: backgroundView, alpha: backgroundAlpha)
        }
        
        private var animatingOut = false
        func animateOutToEditor(completion: @escaping () -> Void) {
            guard let controller = self.environment?.controller() as? MediaCutoutScreen else {
                return
            }
            
            let mediaEditor = controller.mediaEditor
            if let drawingImage = controller.drawingView.drawingImage {
                mediaEditor.setSegmentationMask(drawingImage, andEnable: true)
            }
            let initialOutlineValue = self.initialOutlineValue
            mediaEditor.setOnNextDisplay { [weak controller, weak mediaEditor] in
                controller?.previewView.mask = nil
                if let initialOutlineValue {
                    mediaEditor?.setToolValue(.stickerOutline, value: initialOutlineValue)
                }
                controller?.completed()
            }
            
            self.animatingOut = true
            
            self.cancelButton.view?.isHidden = true
            
            self.fadeView.layer.animateAlpha(from: self.fadeView.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
            for outlineView in self.outlineViews {
                outlineView.layer.animateAlpha(from: self.fadeView.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
            }
            self.buttonsBackgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.label.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            
            if let view = self.doneButton.view {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
                        
            self.state?.updated()
            
            guard [.erase, .restore].contains(controller.mode) else {
                return
            }
            controller.drawingView.isUserInteractionEnabled = false
            
            controller.overlayView.alpha = 0.0
            controller.backgroundView.alpha = 1.0
        }
        
        public func playDissolveAnimation() {
            guard let component = self.component, let resultImage = component.mediaEditor.resultImage, let environment = self.environment, let controller = environment.controller() as? MediaCutoutScreen else {
                return
            }
            let previewView = controller.previewView
            
            let maxSize = CGSize(width: 320.0, height: 568.0)
            let fittedSize = previewView.bounds.size.aspectFitted(maxSize)
            let scale = previewView.bounds.width / fittedSize.width
            
            let dustEffectLayer = DustEffectLayer()
            dustEffectLayer.position = previewView.center
            dustEffectLayer.bounds = CGRect(origin: .zero, size: fittedSize)
            dustEffectLayer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            previewView.superview?.layer.insertSublayer(dustEffectLayer, below: previewView.layer)
            
            dustEffectLayer.animationSpeed = 2.2
            dustEffectLayer.becameEmpty = { [weak dustEffectLayer] in
                dustEffectLayer?.removeFromSuperlayer()
            }

            dustEffectLayer.addItem(frame: dustEffectLayer.bounds, image: resultImage)
            
            controller.completedWithCutout()
            controller.requestDismiss(animated: true)
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if let controller = self.environment?.controller() as? MediaCutoutScreen, [.erase, .restore].contains(controller.mode), result == self.previewContainerView {
                return nil
            }
            return result
        }
        
        func update(component: MediaCutoutScreenComponent, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            guard let controller = environment.controller() as? MediaCutoutScreen else {
                return .zero
            }
            
            let isFirstTime = self.component == nil
            self.component = component
            self.state = state
            
            let isTablet: Bool
            if case .regular = environment.metrics.widthClass {
                isTablet = true
            } else {
                isTablet = false
            }
            
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
                    controlsBottomInset = -75.0
                } else {
                    self.buttonsBackgroundView.backgroundColor = .clear
                }
            }
            
            let previewContainerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - previewSize.width) / 2.0), y: environment.safeInsets.top), size: CGSize(width: previewSize.width, height: availableSize.height - environment.safeInsets.top - environment.safeInsets.bottom + controlsBottomInset))
            let buttonsContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - environment.safeInsets.bottom + controlsBottomInset), size: CGSize(width: availableSize.width, height: environment.safeInsets.bottom - controlsBottomInset))
                                    
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(
                        LottieAnimationComponent(
                            animation: LottieAnimationComponent.AnimationItem(
                                name: "media_backToCancel",
                                mode: .animating(loop: false),
                                range: self.animatingOut ? (0.5, 1.0) : (0.0, 0.5)
                            ),
                            colors: ["__allcolors__": .white],
                            size: CGSize(width: 33.0, height: 33.0)
                        )
                    ),
                    action: { [weak controller] in
                        controller?.requestDismiss(animated: true)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let cancelButtonFrame = CGRect(
                origin: CGPoint(x: buttonSideInset, y: buttonBottomInset),
                size: cancelButtonSize
            )
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.buttonsContainerView.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }
            
            if case .cutout = controller.mode {
            } else {
                let doneButtonSize = self.doneButton.update(
                    transition: transition,
                    component: AnyComponent(Button(
                        content: AnyComponent(Image(
                            image: state.image(.done),
                            size: CGSize(width: 33.0, height: 33.0)
                        )),
                        action: { [weak controller] in
                            controller?.requestDismiss(animated: true)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                let doneButtonFrame = CGRect(
                    origin: CGPoint(x: availableSize.width - buttonSideInset - doneButtonSize.width, y: buttonBottomInset),
                    size: doneButtonSize
                )
                if let doneButtonView = self.doneButton.view {
                    if doneButtonView.superview == nil {
                        self.buttonsContainerView.addSubview(doneButtonView)
                    }
                    transition.setFrame(view: doneButtonView, frame: doneButtonFrame)
                }
            }
            
            let helpText: String
            switch controller.mode {
            case .cutout:
                helpText = environment.strings.MediaEditor_CutoutInfo
            case .erase:
                helpText = environment.strings.MediaEditor_EraseInfo
            case .restore:
                helpText = environment.strings.MediaEditor_RestoreInfo
            }
            
            let labelSize = self.label.update(
                transition: transition,
                component: AnyComponent(Text(text: helpText, font: Font.regular(17.0), color: UIColor(rgb: 0x8d8d93))),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 88.0, height: 44.0)
            )
            let labelFrame = CGRect(
                origin: CGPoint(x: floorToScreenPixels((availableSize.width - labelSize.width) / 2.0), y: buttonBottomInset + 4.0),
                size: labelSize
            )
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    self.buttonsContainerView.addSubview(labelView)
                }
                if labelView.bounds.width > 0.0 && labelFrame.width != labelView.bounds.width {
                    if let snapshotView = labelView.snapshotView(afterScreenUpdates: false) {
                        snapshotView.center = labelView.center
                        self.buttonsContainerView.addSubview(snapshotView)
                        
                        labelView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                            snapshotView.removeFromSuperview()
                        })
                    }
                }
                labelView.bounds = CGRect(origin: .zero, size: labelFrame.size)
                transition.setPosition(view: labelView, position: labelFrame.center)
            }
                        
            transition.setFrame(view: self.buttonsContainerView, frame: buttonsContainerFrame)
            transition.setFrame(view: self.buttonsBackgroundView, frame: CGRect(origin: .zero, size: buttonsContainerFrame.size))
            
            transition.setFrame(view: self.previewContainerView, frame: previewContainerFrame)

            if case .cutout = controller.mode {
                for view in self.outlineViews {
                    transition.setFrame(view: view, frame: previewContainerFrame)
                }
                
                let frameWidth = floorToScreenPixels(previewContainerFrame.width * 0.97)
                self.fadeView.frame = CGRect(x: floorToScreenPixels((previewContainerFrame.width - frameWidth) / 2.0), y: previewContainerFrame.minY + floorToScreenPixels((previewContainerFrame.height - frameWidth) / 2.0), width: frameWidth, height: frameWidth)
                self.fadeView.layer.cornerRadius = frameWidth / 8.0
                
                if isFirstTime {
                    let values = component.mediaEditor.values
                    component.mediaEditor.processImage { originalImage, editedImage in
                        cutoutImage(from: originalImage, editedImage: editedImage, crop: values.cropValues, target: .all, completion: { results in
                            Queue.mainQueue().async {
                                if !results.isEmpty {
                                    for result in results {
                                        if let extractedImage = result.extractedImage, let maskImage = result.edgesMaskImage {
                                            if case let .image(image, _) = extractedImage, case let .image(_, mask) = maskImage {
                                                let outlineView = StickerCutoutOutlineView(frame: self.previewContainerView.frame)
                                                outlineView.update(image: image, maskImage: mask, size: self.previewContainerView.bounds.size, values: values)
                                                self.insertSubview(outlineView, belowSubview: self.previewContainerView)
                                                self.outlineViews.append(outlineView)
                                            }
                                        }
                                    }
                                    self.state?.updated(transition: .easeInOut(duration: 0.4))
                                }
                            }
                        })
                    }
                } else {
                    transition.setAlpha(view: self.fadeView, alpha: !self.outlineViews.isEmpty ? 1.0 : 0.0)
                }
            }
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

final class MediaCutoutScreen: ViewController {
    fileprivate final class Node: ViewControllerTracingNode, ASGestureRecognizerDelegate {
        private weak var controller: MediaCutoutScreen?
        private let context: AccountContext
    
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>

        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        init(controller: MediaCutoutScreen) {
            self.controller = controller
            self.context = controller.context

            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
            self.componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
            
            super.init()
            
            self.backgroundColor = .clear
        }
                
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveModalDismiss = true
            self.view.disablesInteractiveKeyboardGestureRecognizer = true
        }
        
        @objc func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func animateInFromEditor() {
            if let view = self.componentHost.view as? MediaCutoutScreenComponent.View {
                view.animateInFromEditor()
            }
        }
        
        func animateOutToEditor(completion: @escaping () -> Void) {
            if let mediaEditor = self.controller?.mediaEditor {
                mediaEditor.play()
            }
            if let view = self.componentHost.view as? MediaCutoutScreenComponent.View {
                view.animateOutToEditor(completion: completion)
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result === self.view {
                return nil
            }
            return result
        }
        
        func requestLayout(transition: ComponentTransition) {
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout: layout, forceUpdate: true, transition: transition)
                
                if let view = self.componentHost.view as? MediaCutoutScreenComponent.View {
                    view.updateBackgroundViews()
                }
            }
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, animateOut: Bool = false, transition: ComponentTransition) {
            guard let controller = self.controller else {
                return
            }
            let isFirstTime = self.validLayout == nil
            self.validLayout = layout
            
            let isTablet = layout.metrics.isTablet

            let previewSize: CGSize
            let topInset: CGFloat = (layout.statusBarHeight ?? 0.0) + 5.0
            if isTablet {
                let previewHeight = layout.size.height - topInset - 75.0
                previewSize = CGSize(width: floorToScreenPixels(previewHeight / 1.77778), height: previewHeight)
            } else {
                previewSize = CGSize(width: layout.size.width, height: floorToScreenPixels(layout.size.width * 1.77778))
            }
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
                additionalInsets: layout.additionalInsets,
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
                    MediaCutoutScreenComponent(
                        context: self.context,
                        mediaEditor: controller.mediaEditor
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
                let componentFrame = CGRect(origin: .zero, size: componentSize)
                transition.setFrame(view: componentView, frame: CGRect(origin: componentFrame.origin, size: CGSize(width: componentFrame.width, height: componentFrame.height)))
            }
            
            if isFirstTime {
                self.animateInFromEditor()
            }
        }
    }
    
    fileprivate var node: Node {
        return self.displayNode as! Node
    }
    
    fileprivate let context: AccountContext
    public var mode: Mode {
        didSet {
            self.updateDrawingState()
            self.node.requestLayout(transition: .easeInOut(duration: 0.2))
        }
    }
    fileprivate let mediaEditor: MediaEditor
    fileprivate let maskWrapperView: UIView
    fileprivate let previewView: MediaEditorPreviewView
    fileprivate let drawingView: DrawingView
    fileprivate let overlayView: UIView
    fileprivate let backgroundView: UIView
    
    var completed: () -> Void = {}
    var completedWithCutout: () -> Void = {}
    var dismissed: () -> Void = {}
    
    private var initialValues: MediaEditorValues
        
    enum Mode {
        case cutout
        case erase
        case restore
    }
    
    init(
        context: AccountContext,
        mode: Mode,
        mediaEditor: MediaEditor,
        previewView: MediaEditorPreviewView,
        maskWrapperView: UIView,
        drawingView: DrawingView,
        overlayView: UIView,
        backgroundView: UIView
    ) {
        self.context = context
        self.mode = mode
        self.mediaEditor = mediaEditor
        self.previewView = previewView
        self.maskWrapperView = maskWrapperView
        self.drawingView = drawingView
        self.overlayView = overlayView
        self.backgroundView = backgroundView
        self.initialValues = mediaEditor.values.makeCopy()
        
        super.init(navigationBarPresentationData: nil)
        self.navigationPresentation = .flatModal
                    
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = .White
        
        self.updateDrawingState()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }
    
    private func updateDrawingState() {
        if let toolState = self.drawingView.appliedToolState {
            if case .erase = mode {
                self.drawingView.updateToolState(toolState.withUpdatedColor(DrawingColor(color: .black)))
            } else if case .restore = mode {
                self.drawingView.updateToolState(toolState.withUpdatedColor(DrawingColor(color: .white)))
            }
        }
    }
            
    func requestDismiss(animated: Bool) {
        self.dismissed()
        
        self.node.animateOutToEditor(completion: {
            self.dismiss()
        })
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
    }
}
