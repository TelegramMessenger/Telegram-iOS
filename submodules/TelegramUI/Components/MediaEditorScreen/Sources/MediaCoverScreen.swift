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
import MediaEditor
import MediaScrubberComponent
import ButtonComponent

private final class MediaCoverScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mediaEditor: Signal<MediaEditor?, NoError>
    let exclusive: Bool
    
    init(
        context: AccountContext,
        mediaEditor: Signal<MediaEditor?, NoError>,
        exclusive: Bool
    ) {
        self.context = context
        self.mediaEditor = mediaEditor
        self.exclusive = exclusive
    }
    
    static func ==(lhs: MediaCoverScreenComponent, rhs: MediaCoverScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.exclusive != rhs.exclusive {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var playerStateDisposable: Disposable?
        var playerState: MediaEditorPlayerState?
        
        private(set) var mediaEditor: MediaEditor?
        
        init(mediaEditor: Signal<MediaEditor?, NoError>) {
            super.init()
                        
            let _ = (mediaEditor
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] mediaEditor in
                if let self, let mediaEditor {
                    self.mediaEditor = mediaEditor
                    
                    self.playerStateDisposable = (mediaEditor.playerState(framesCount: 16)
                    |> deliverOnMainQueue).start(next: { [weak self] playerState in
                        if let self {
                            if self.playerState != playerState {
                                self.playerState = playerState
                                self.updated()
                            }
                        }
                    })
                }
            })
        }
        
        deinit {
            self.playerStateDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(mediaEditor: self.mediaEditor)
    }

    public final class View: UIView {
        private let buttonsContainerView = UIView()
        private let buttonsBackgroundView = UIImageView()
        private let previewContainerView = UIView()
        private let cancelButton = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
        private let scrubber = ComponentView<Empty>()
        
        private let fadeView = UIView()
                        
        private var component: MediaCoverScreenComponent?
        private weak var state: State?
        private var environment: ViewControllerComponentContainer.Environment?
        
        override init(frame: CGRect) {
            self.buttonsContainerView.clipsToBounds = true

            self.fadeView.alpha = 0.0
            self.fadeView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.7)
            
            self.buttonsBackgroundView.image = generateImage(CGSize(width: 22.0, height: 22.0), rotatedContext: { size, context in
                context.setFillColor(UIColor.black.cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                
                context.setBlendMode(.clear)
                context.setFillColor(UIColor.clear.cgColor)
                context.addPath(CGPath(roundedRect: CGRect(x: 0.0, y: -11.0, width: size.width, height: 22.0), cornerWidth: 11.0, cornerHeight: 11.0, transform: nil))
                context.fillPath()
            })?.stretchableImage(withLeftCapWidth: 11, topCapHeight: 11)
            
            super.init(frame: frame)
            
            self.backgroundColor = .clear

            self.addSubview(self.buttonsContainerView)
            self.buttonsContainerView.addSubview(self.buttonsBackgroundView)
            
            self.addSubview(self.fadeView)
            self.addSubview(self.previewContainerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    
        func animateInFromEditor() {
            self.buttonsBackgroundView.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: .zero, duration: 0.2, additive: true)
            
            self.label.view?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            
            if let view = self.doneButton.view {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
            }
        }
                
        private var animatingOut = false
        func animateOutToEditor(completion: @escaping () -> Void) {
            self.animatingOut = true
                        
            self.fadeView.layer.animateAlpha(from: self.fadeView.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
            self.buttonsBackgroundView.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 44.0), duration: 0.2, removeOnCompletion: false, additive: true)
            
            self.label.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)

            if let view = self.scrubber.view {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    completion()
                })
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
            
            if let view = self.cancelButton.view {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
            
            if let view = self.doneButton.view {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
                        
            self.state?.updated()
        }
        
        func update(component: MediaCoverScreenComponent, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            guard let controller = environment.controller() as? MediaCoverScreen else {
                return .zero
            }
            
            self.component = component
            self.state = state
            
            let isTablet: Bool
            if case .regular = environment.metrics.widthClass {
                isTablet = true
            } else {
                isTablet = false
            }
            
            let buttonSideInset: CGFloat = 16.0
            var controlsBottomInset: CGFloat = 0.0
            let previewSize: CGSize
            var topInset: CGFloat = environment.statusBarHeight + 5.0
            if isTablet {
                let previewHeight = availableSize.height - topInset - 75.0
                previewSize = CGSize(width: floorToScreenPixels(previewHeight / 1.77778), height: previewHeight)
            } else {
                previewSize = CGSize(width: availableSize.width, height: floorToScreenPixels(availableSize.width * 1.77778))
                if availableSize.height < previewSize.height + 30.0 {
                    topInset = 0.0
                    controlsBottomInset = -75.0
                }
            }
                        
            let previewContainerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - previewSize.width) / 2.0), y: topInset), size: CGSize(width: previewSize.width, height: availableSize.height - environment.safeInsets.top - environment.safeInsets.bottom + controlsBottomInset))
            let buttonsContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - environment.safeInsets.bottom + controlsBottomInset), size: CGSize(width: availableSize.width, height: environment.safeInsets.bottom - controlsBottomInset))
                                    
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Common_Cancel, font: Font.regular(17.0), textColor: .white)))
                    ),
                    action: { [weak controller] in
                        controller?.requestDismiss(animated: true)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 44.0)
            )
            let cancelButtonFrame = CGRect(
                origin: CGPoint(x: 16.0, y: previewContainerFrame.minY + 28.0),
                size: cancelButtonSize
            )
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                    setupButtonShadow(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }
            
            let doneButtonSize = self.doneButton.update(
                transition: transition,
                component: AnyComponent(
                    ButtonComponent(
                        background: ButtonComponent.Background(
                            color: environment.theme.list.itemCheckColors.fillColor,
                            foreground: environment.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(ButtonTextContentComponent(
                                text: environment.strings.Story_SaveCover,
                                badge: 0,
                                textColor: environment.theme.list.itemCheckColors.foregroundColor,
                                badgeBackground: .clear,
                                badgeForeground: .clear
                            ))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak controller, weak self] in
                            guard let controller else {
                                return
                            }
                            if let playerState = self?.state?.playerState, let mediaEditor = self?.state?.mediaEditor, let image = mediaEditor.resultImage {
                                mediaEditor.setCoverImageTimestamp(playerState.position)
                                controller.completed(playerState.position, image)
                            }
                            if !controller.exclusive {
                                controller.requestDismiss(animated: true)
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - buttonSideInset * 2.0, height: 50.0)
            )
            let doneButtonFrame = CGRect(
                origin: CGPoint(x: floor((availableSize.width - doneButtonSize.width) / 2.0), y: min(buttonsContainerFrame.minY, availableSize.height - doneButtonSize.height - buttonSideInset)),
                size: doneButtonSize
            )
            if let doneButtonView = self.doneButton.view {
                if doneButtonView.superview == nil {
                    self.addSubview(doneButtonView)
                }
                transition.setFrame(view: doneButtonView, frame: doneButtonFrame)
            }
            
            let labelSize = self.label.update(
                transition: transition,
                component: AnyComponent(Text(text: environment.strings.Story_Cover, font: Font.semibold(17.0), color: UIColor(rgb: 0xffffff))),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 88.0, height: 44.0)
            )
            let labelFrame = CGRect(
                origin: CGPoint(x: floorToScreenPixels((availableSize.width - labelSize.width) / 2.0), y: previewContainerFrame.minY + 28.0),
                size: labelSize
            )
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    self.addSubview(labelView)
                    setupButtonShadow(labelView)
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
            
            let buttonCoverFrame = CGRect(origin: CGPoint(x: 0.0, y: doneButtonFrame.minY - buttonSideInset - 11.0), size: CGSize(width: previewContainerFrame.width, height: 100.0))
                        
            transition.setFrame(view: self.buttonsContainerView, frame: buttonCoverFrame)
            transition.setFrame(view: self.buttonsBackgroundView, frame: CGRect(origin: .zero, size: buttonCoverFrame.size))
            
            transition.setFrame(view: self.previewContainerView, frame: previewContainerFrame)
            
            if let playerState = state.playerState {
                let visibleTracks = playerState.tracks.filter { $0.id == 0 }.map { MediaScrubberComponent.Track($0) }
                
                let scrubberInset: CGFloat = buttonSideInset
                let scrubberSize = self.scrubber.update(
                    transition: transition,
                    component: AnyComponent(MediaScrubberComponent(
                        context: component.context,
                        style: .cover,
                        theme: environment.theme,
                        generationTimestamp: playerState.generationTimestamp,
                        position: playerState.position,
                        minDuration: 1.0,
                        maxDuration: storyMaxVideoDuration,
                        isPlaying: playerState.isPlaying,
                        tracks: visibleTracks,
                        portalView: controller.portalView,
                        positionUpdated: { [weak state] position, apply in
                            if let mediaEditor = state?.mediaEditor {
                                mediaEditor.seek(position, andPlay: false)
                            }
                        },
                        coverPositionUpdated: { [weak state] position, tap, commit in
                            if let mediaEditor = state?.mediaEditor {
                                if tap {
                                    mediaEditor.setOnNextDisplay {
                                        commit()
                                    }
                                    mediaEditor.seek(position, andPlay: false)
                                } else {
                                    mediaEditor.seek(position, andPlay: false)
                                    commit()
                                }
                            }
                        },
                        trackTrimUpdated: { _, _, _, _, _ in
                        },
                        trackOffsetUpdated: { _, _, _ in
                        },
                        trackLongPressed: { _, _ in
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: previewSize.width - scrubberInset * 2.0, height: availableSize.height)
                )
                
                let scrubberFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - scrubberSize.width) / 2.0), y: min(previewContainerFrame.maxY, buttonCoverFrame.minY) - scrubberSize.height - 4.0), size: scrubberSize)
                if let scrubberView = self.scrubber.view {
                    var animateIn = false
                    if scrubberView.superview == nil {
                        animateIn = true
                        self.addSubview(scrubberView)
                    }
                    if animateIn {
                        scrubberView.frame = scrubberFrame
                    } else {
                        transition.setFrame(view: scrubberView, frame: scrubberFrame)
                    }
                    if animateIn {
                        scrubberView.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        scrubberView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        scrubberView.layer.animateScale(from: 0.6, to: 1.0, duration: 0.2)
                    }
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

final class MediaCoverScreen: ViewController {
    fileprivate final class Node: ViewControllerTracingNode, ASGestureRecognizerDelegate {
        private weak var controller: MediaCoverScreen?
        private let context: AccountContext
    
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>

        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        init(controller: MediaCoverScreen) {
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
            if let view = self.componentHost.view as? MediaCoverScreenComponent.View {
                view.animateInFromEditor()
            }
        }
        
        func animateOutToEditor(completion: @escaping () -> Void) {
            if let view = self.componentHost.view as? MediaCoverScreenComponent.View {
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
                    MediaCoverScreenComponent(
                        context: self.context,
                        mediaEditor: controller.mediaEditor,
                        exclusive: controller.exclusive
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
    fileprivate let mediaEditor: Signal<MediaEditor?, NoError>
    fileprivate let previewView: MediaEditorPreviewView
    fileprivate let portalView: PortalView
    fileprivate let exclusive: Bool
    
    func withMediaEditor(_ f: @escaping (MediaEditor) -> Void) {
        let _ = (self.mediaEditor
        |> take(1)
        |> deliverOnMainQueue).start(next: { mediaEditor in
            if let mediaEditor {
                f(mediaEditor)
            }
        })
    }
    
    var completed: (Double, UIImage) -> Void = { _, _ in }
    var dismissed: () -> Void = {}
    
    init(
        context: AccountContext,
        mediaEditor: Signal<MediaEditor?, NoError>,
        previewView: MediaEditorPreviewView,
        portalView: PortalView,
        exclusive: Bool
    ) {
        self.context = context
        self.mediaEditor = mediaEditor
        self.previewView = previewView
        self.portalView = portalView
        self.exclusive = exclusive
        
        super.init(navigationBarPresentationData: nil)
        self.navigationPresentation = .flatModal
                    
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = .White
        
        self.withMediaEditor { mediaEditor in
            if let coverImageTimestamp = mediaEditor.values.coverImageTimestamp {
                mediaEditor.seek(coverImageTimestamp, andPlay: false)
            } else {
                mediaEditor.seek(mediaEditor.values.videoTrimRange?.lowerBound ?? 0.0, andPlay: false)
            }
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }
                
    func requestDismiss(animated: Bool) {
        self.dismissed()
        
        self.node.animateOutToEditor(completion: {
            if !self.exclusive {
                self.dismiss()
            }
        })
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
    }
}

private func setupButtonShadow(_ view: UIView, radius: CGFloat = 2.0) {
    view.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
    view.layer.shadowRadius = radius
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOpacity = 0.35
}
