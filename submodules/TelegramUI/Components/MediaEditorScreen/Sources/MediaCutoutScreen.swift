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

    public final class View: UIView {
        private let buttonsContainerView = UIView()
        private let buttonsBackgroundView = UIView()
        private let previewContainerView = UIView()
        private let cancelButton = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
        
        private let fadeView = UIView()
        private let separatedImageView = UIImageView()
                                
        private var component: MediaCutoutScreenComponent?
        private weak var state: State?
        private var environment: ViewControllerComponentContainer.Environment?
        
        override init(frame: CGRect) {
            self.buttonsContainerView.clipsToBounds = true

            self.fadeView.alpha = 0.0
            self.fadeView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.6)

            self.separatedImageView.contentMode = .scaleAspectFit
            
            super.init(frame: frame)
            
            self.backgroundColor = .clear

            self.addSubview(self.buttonsContainerView)
            self.buttonsContainerView.addSubview(self.buttonsBackgroundView)
            
            self.addSubview(self.fadeView)
            self.addSubview(self.separatedImageView)
            self.addSubview(self.previewContainerView)
            
            self.previewContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.previewTap(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func previewTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            let location = gestureRecognizer.location(in: gestureRecognizer.view)
            
            let point = CGPoint(
                x: location.x / self.previewContainerView.frame.width,
                y: location.y / self.previewContainerView.frame.height
            )
            component.mediaEditor.setSeparationMask(point: point)
            
            self.playDissolveAnimation()
        }
        
        func animateInFromEditor() {
            self.buttonsBackgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.label.view?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        
        private var animatingOut = false
        func animateOutToEditor(completion: @escaping () -> Void) {
            self.animatingOut = true
            
            self.cancelButton.view?.isHidden = true
            
            self.fadeView.layer.animateAlpha(from: self.fadeView.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
            self.buttonsBackgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.label.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            
            self.state?.updated()
        }
        
        public func playDissolveAnimation() {
            guard let component = self.component, let resultImage = component.mediaEditor.resultImage, let environment = self.environment, let controller = environment.controller() as? MediaCutoutScreen else {
                return
            }
            let previewView = controller.previewView
            
            let dustEffectLayer = DustEffectLayer()
            dustEffectLayer.position = previewView.center
            dustEffectLayer.bounds = previewView.bounds
            previewView.superview?.layer.insertSublayer(dustEffectLayer, below: previewView.layer)
            
            dustEffectLayer.animationSpeed = 2.2
            dustEffectLayer.becameEmpty = { [weak dustEffectLayer] in
                dustEffectLayer?.removeFromSuperlayer()
            }

            dustEffectLayer.addItem(frame: previewView.bounds, image: resultImage)
            
            controller.requestDismiss(animated: true)
        }
        
        func update(component: MediaCutoutScreenComponent, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
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
                    action: {
                        guard let controller = environment.controller() as? MediaCutoutScreen else {
                            return
                        }
                        controller.requestDismiss(animated: true)
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
            
            let labelSize = self.label.update(
                transition: transition,
                component: AnyComponent(Text(text: "Tap an object to cut it out", font: Font.regular(17.0), color: .white)),
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
                transition.setFrame(view: labelView, frame: labelFrame)
            }
                        
            transition.setFrame(view: self.buttonsContainerView, frame: buttonsContainerFrame)
            transition.setFrame(view: self.buttonsBackgroundView, frame: CGRect(origin: .zero, size: buttonsContainerFrame.size))
            
            transition.setFrame(view: self.previewContainerView, frame: previewContainerFrame)
            transition.setFrame(view: self.separatedImageView, frame: previewContainerFrame)
            
            let frameWidth = floor(previewContainerFrame.width * 0.97)
            
            self.fadeView.frame = CGRect(x: floorToScreenPixels((previewContainerFrame.width - frameWidth) / 2.0), y: previewContainerFrame.minY + floorToScreenPixels((previewContainerFrame.height - frameWidth) / 2.0), width: frameWidth, height: frameWidth)
            self.fadeView.layer.cornerRadius = frameWidth / 8.0
            
            if isFirstTime {
                let _ = (component.mediaEditor.getSeparatedImage(point: nil)
                |> deliverOnMainQueue).start(next: { [weak self] image in
                    guard let self else {
                        return
                    }
                    self.separatedImageView.image = image
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                })
            } else {
                if let _ = self.separatedImageView.image {
                    transition.setAlpha(view: self.fadeView, alpha: 1.0)
                } else {
                    transition.setAlpha(view: self.fadeView, alpha: 0.0)
                }
            }
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class MediaCutoutScreen: ViewController {
    fileprivate final class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
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
        
        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, animateOut: Bool = false, transition: Transition) {
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
    fileprivate let mediaEditor: MediaEditor
    fileprivate let previewView: MediaEditorPreviewView
    
    public var dismissed: () -> Void = {}
    
    private var initialValues: MediaEditorValues
        
    public init(context: AccountContext, mediaEditor: MediaEditor, previewView: MediaEditorPreviewView) {
        self.context = context
        self.mediaEditor = mediaEditor
        self.previewView = previewView
        self.initialValues = mediaEditor.values.makeCopy()
        
        super.init(navigationBarPresentationData: nil)
        self.navigationPresentation = .flatModal
                    
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = .White
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }
            
    func requestDismiss(animated: Bool) {
        self.dismissed()
        
        self.node.animateOutToEditor(completion: {
            self.dismiss()
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: Transition(transition))
    }
}
