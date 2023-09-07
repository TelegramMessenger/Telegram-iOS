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

private enum MediaToolsSection: Equatable {
    case adjustments
    case tint
    case blur
    case curves
}

private final class ToolIconComponent: Component {
    typealias EnvironmentType = Empty
    
    let icon: UIImage?
    let isActive: Bool
    let isSelected: Bool
    
    init(
        icon: UIImage?,
        isActive: Bool,
        isSelected: Bool
    ) {
        self.icon = icon
        self.isActive = isActive
        self.isSelected = isSelected
    }
    
    static func ==(lhs: ToolIconComponent, rhs: ToolIconComponent) -> Bool {
        if lhs.icon !== rhs.icon {
            return false
        }
        if lhs.isActive != rhs.isActive {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let selection = SimpleShapeLayer()
        private let icon = ComponentView<Empty>()
                
        private var component: ToolIconComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
         
            self.selection.path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: 33.0, height: 33.0)), cornerRadius: 10.0).cgPath
            self.selection.fillColor = UIColor(rgb: 0xd1d1d1).cgColor
            self.layer.addSublayer(self.selection)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: ToolIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
                        
            let iconColor: UIColor
            if component.isSelected {
                iconColor = .black
            } else {
                iconColor = component.isActive ? UIColor(rgb: 0xf8d74a) : .white
            }
            
            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(
                    Image(
                        image: component.icon,
                        tintColor: iconColor,
                        size: CGSize(width: 30.0, height: 30.0)
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let size = CGSize(width: 33.0, height: 33.0)
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - iconSize.width) / 2.0), y: floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
            if let view = self.icon.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: iconFrame)
            }
            
            self.selection.isHidden = !component.isSelected
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}


private final class MediaToolsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mediaEditor: MediaEditor
    let section: MediaToolsSection
    let sectionUpdated: (MediaToolsSection) -> Void
    
    init(
        context: AccountContext,
        mediaEditor: MediaEditor,
        section: MediaToolsSection,
        sectionUpdated: @escaping (MediaToolsSection) -> Void
    ) {
        self.context = context
        self.mediaEditor = mediaEditor
        self.section = section
        self.sectionUpdated = sectionUpdated
    }
    
    static func ==(lhs: MediaToolsScreenComponent, rhs: MediaToolsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.section != rhs.section {
            return false
        }
        return true
    }

    final class State: ComponentState {
        enum ImageKey: Hashable {
            case adjustments
            case tint
            case blur
            case curves
            case done
        }
        private var cachedImages: [ImageKey: UIImage] = [:]
        func image(_ key: ImageKey) -> UIImage {
            if let image = self.cachedImages[key] {
                return image
            } else {
                var image: UIImage
                switch key {
                case .adjustments:
                    image = UIImage(bundleImageName: "Media Editor/Tools")!
                case .tint:
                    image = UIImage(bundleImageName: "Media Editor/Tint")!
                case .blur:
                    image = UIImage(bundleImageName: "Media Editor/Blur")!
                case .curves:
                    image = UIImage(bundleImageName: "Media Editor/Curves")!
                case .done:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Done"), color: .white)!
                }
                cachedImages[key] = image
                return image
            }
        }
        
        let context: AccountContext
        var histogram: MediaEditorHistogram?
        private var histogramDisposable: Disposable?
                        
        init(context: AccountContext, mediaEditor: MediaEditor) {
            self.context = context
         
            super.init()
            
            self.histogramDisposable = (mediaEditor.histogram
            |> deliverOnMainQueue).start(next: { [weak self] data in
                if let self {
                    self.histogram = MediaEditorHistogram(data: data)
                    self.updated()
                }
            })
        }
        
        deinit {
            self.histogramDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(
            context: self.context,
            mediaEditor: self.mediaEditor
        )
    }
    
    public final class View: UIView {
        private let buttonsContainerView = UIView()
        private let buttonsBackgroundView = UIView()
        private let cancelButton = ComponentView<Empty>()
        private let adjustmentsButton = ComponentView<Empty>()
        private let tintButton = ComponentView<Empty>()
        private let blurButton = ComponentView<Empty>()
        private let curvesButton = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
        
        private let previewContainerView = UIView()
        private var optionsContainerView = UIView()
        private var optionsBackgroundView = UIView()
        private var toolOptions = ComponentView<Empty>()
        private var toolScreen: ComponentView<Empty>?
        
        private var curvesState: CurvesInternalState?
                
        private var component: MediaToolsScreenComponent?
        private weak var state: State?
        private var environment: ViewControllerComponentContainer.Environment?
        
        override init(frame: CGRect) {
            self.buttonsContainerView.clipsToBounds = true
            self.previewContainerView.clipsToBounds = true
            
            self.optionsContainerView.clipsToBounds = true
            self.optionsBackgroundView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.9)
            
            super.init(frame: frame)
            
            self.backgroundColor = .clear

            self.addSubview(self.previewContainerView)
            self.addSubview(self.buttonsContainerView)
            self.previewContainerView.addSubview(self.optionsContainerView)
            self.optionsContainerView.addSubview(self.optionsBackgroundView)
            self.buttonsContainerView.addSubview(self.buttonsBackgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func animateInFromEditor() {
            let buttons = [
                self.adjustmentsButton,
                self.tintButton,
                self.blurButton,
                self.curvesButton
            ]
            
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
            
            if let view = self.doneButton.view {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
            }
            
            self.buttonsBackgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            
            self.optionsContainerView.layer.animatePosition(from: CGPoint(x: 0.0, y: self.optionsContainerView.frame.height), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
        }
        
        private var animatingOut = false
        func animateOutToEditor(completion: @escaping () -> Void) {
            self.animatingOut = true
            
            self.cancelButton.view?.isHidden = true
            
            let buttons = [
                self.adjustmentsButton,
                self.tintButton,
                self.blurButton,
                self.curvesButton
            ]
            
            for button in buttons {
                if let view = button.view {
                    view.layer.animatePosition(from: .zero, to:  CGPoint(x: 0.0, y: 64.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true, completion: { _ in
                        completion()
                    })
                    view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                    view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
                }
            }
            
            if let view = self.doneButton.view {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
            }
            
            if let view = self.toolScreen?.view {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            }
            
            self.buttonsBackgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            
            self.optionsContainerView.layer.animatePosition(from: .zero, to:  CGPoint(x: 0.0, y: self.optionsContainerView.frame.height), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            
            self.state?.updated()
        }
        
        func update(component: MediaToolsScreenComponent, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            let previousSection = self.component?.section
            self.component = component
            self.state = state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let isTablet: Bool
            if case .regular = environment.metrics.widthClass {
                isTablet = true
            } else {
                isTablet = false
            }
            
            let mediaEditor = (environment.controller() as? MediaToolsScreen)?.mediaEditor
            
            let sectionUpdated = component.sectionUpdated
            
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
//                    self.buttonsBackgroundView.backgroundColor = .black
                } else {
                    self.buttonsBackgroundView.backgroundColor = .clear
                }
            }
            
            var previewContainerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - previewSize.width) / 2.0), y: environment.safeInsets.top), size: CGSize(width: previewSize.width, height: availableSize.height - environment.safeInsets.top - environment.safeInsets.bottom + controlsBottomInset))
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
                        guard let controller = environment.controller() as? MediaToolsScreen else {
                            return
                        }
                        controller.requestDismiss(reset: true, animated: true)
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
            
            let doneButtonSize = self.doneButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Image(
                        image: state.image(.done),
                        size: CGSize(width: 33.0, height: 33.0)
                    )),
                    action: {
                        guard let controller = environment.controller() as? MediaToolsScreen else {
                            return
                        }
                        controller.requestDismiss(reset: false, animated: true)
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
            
            let buttonsAvailableWidth: CGFloat
            let buttonsLeftOffset: CGFloat
            if isTablet {
                buttonsAvailableWidth = previewSize.width + 260.0
                buttonsLeftOffset = floorToScreenPixels((availableSize.width - buttonsAvailableWidth) / 2.0)
            } else {
                buttonsAvailableWidth = availableSize.width
                buttonsLeftOffset = 0.0
            }
            
            let adjustmentsButtonSize = self.adjustmentsButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(ToolIconComponent(
                        icon: state.image(.adjustments),
                        isActive: mediaEditor?.values.hasAdjustments ?? false,
                        isSelected: component.section == .adjustments
                    )),
                    action: {
                        sectionUpdated(.adjustments)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let adjustmentsButtonFrame = CGRect(
                origin: CGPoint(x: buttonsLeftOffset + floorToScreenPixels(buttonsAvailableWidth / 4.0 - 3.0 - adjustmentsButtonSize.width / 2.0), y: buttonBottomInset),
                size: adjustmentsButtonSize
            )
            if let adjustmentsButtonView = self.adjustmentsButton.view {
                if adjustmentsButtonView.superview == nil {
                    self.buttonsContainerView.addSubview(adjustmentsButtonView)
                }
                transition.setFrame(view: adjustmentsButtonView, frame: adjustmentsButtonFrame)
            }
            
            let tintButtonSize = self.tintButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(ToolIconComponent(
                        icon: state.image(.tint),
                        isActive: mediaEditor?.values.hasTint ?? false,
                        isSelected: component.section == .tint
                    )),
                    action: {
                        sectionUpdated(.tint)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let tintButtonFrame = CGRect(
                origin: CGPoint(x: buttonsLeftOffset + floorToScreenPixels(buttonsAvailableWidth / 2.5 + 5.0 - tintButtonSize.width / 2.0), y: buttonBottomInset),
                size: tintButtonSize
            )
            if let tintButtonView = self.tintButton.view {
                if tintButtonView.superview == nil {
                    self.buttonsContainerView.addSubview(tintButtonView)
                }
                transition.setFrame(view: tintButtonView, frame: tintButtonFrame)
            }
            
            let blurButtonSize = self.blurButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(ToolIconComponent(
                        icon: state.image(.blur),
                        isActive: mediaEditor?.values.hasBlur ?? false,
                        isSelected: component.section == .blur
                    )),
                    action: {
                        sectionUpdated(.blur)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let blurButtonFrame = CGRect(
                origin: CGPoint(x: floorToScreenPixels(availableSize.width - buttonsLeftOffset - buttonsAvailableWidth / 2.5 - 5.0 - blurButtonSize.width / 2.0), y: buttonBottomInset),
                size: blurButtonSize
            )
            if let blurButtonView = self.blurButton.view {
                if blurButtonView.superview == nil {
                    self.buttonsContainerView.addSubview(blurButtonView)
                }
                transition.setFrame(view: blurButtonView, frame: blurButtonFrame)
            }
            
            let curvesButtonSize = self.curvesButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(ToolIconComponent(
                        icon: state.image(.curves),
                        isActive: mediaEditor?.values.hasCurves ?? false,
                        isSelected: component.section == .curves
                    )),
                    action: {
                        sectionUpdated(.curves)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let curvesButtonFrame = CGRect(
                origin: CGPoint(x: buttonsLeftOffset + floorToScreenPixels(buttonsAvailableWidth / 4.0 * 3.0 + 3.0 - curvesButtonSize.width / 2.0), y: buttonBottomInset),
                size: curvesButtonSize
            )
            if let curvesButtonView = self.curvesButton.view {
                if curvesButtonView.superview == nil {
                    self.buttonsContainerView.addSubview(curvesButtonView)
                }
                transition.setFrame(view: curvesButtonView, frame: curvesButtonFrame)
            }
            
            var sectionChanged = false
            if previousSection != component.section {
                sectionChanged = true
                if let previousView = self.toolOptions.view {
                    previousView.layer.allowsGroupOpacity = true
                    previousView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak previousView] _ in
                        previousView?.removeFromSuperview()
                    })
                }
                self.toolOptions = ComponentView<Empty>()
            }
                        
            var toolScreen: ComponentView<Empty>?
            
            if sectionChanged && previousSection != nil, let view = self.toolScreen?.view {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak view] _ in
                    view?.removeFromSuperview()
                })
            }
            
            var needsHistogram = false
            let screenSize: CGSize
            let optionsSize: CGSize
            let optionsTransition: Transition = sectionChanged ? .immediate : transition
            switch component.section {
            case .adjustments:
                self.curvesState = nil
                var tools: [AdjustmentTool] = [
                    AdjustmentTool(
                        key: .enhance,
                        title: presentationData.strings.Story_Editor_Tool_Enhance,
                        value: mediaEditor?.getToolValue(.enhance) as? Float ?? 0.0,
                        minValue: 0.0,
                        maxValue: 1.0,
                        startValue: 0.0
                    ),
                    AdjustmentTool(
                        key: .brightness,
                        title: presentationData.strings.Story_Editor_Tool_Brightness,
                        value: mediaEditor?.getToolValue(.brightness) as? Float ?? 0.0,
                        minValue: -1.0,
                        maxValue: 1.0,
                        startValue: 0.0
                    ),
                    AdjustmentTool(
                        key: .contrast,
                        title: presentationData.strings.Story_Editor_Tool_Contrast,
                        value: mediaEditor?.getToolValue(.contrast) as? Float ?? 0.0,
                        minValue: -1.0,
                        maxValue: 1.0,
                        startValue: 0.0
                    ),
                    AdjustmentTool(
                        key: .saturation,
                        title: presentationData.strings.Story_Editor_Tool_Saturation,
                        value: mediaEditor?.getToolValue(.saturation) as? Float ?? 0.0,
                        minValue: -1.0,
                        maxValue: 1.0,
                        startValue: 0.0
                    ),
                    AdjustmentTool(
                        key: .warmth,
                        title: presentationData.strings.Story_Editor_Tool_Warmth,
                        value: mediaEditor?.getToolValue(.warmth) as? Float ?? 0.0,
                        minValue: -1.0,
                        maxValue: 1.0,
                        startValue: 0.0
                    ),
                    AdjustmentTool(
                        key: .fade,
                        title: presentationData.strings.Story_Editor_Tool_Fade,
                        value: mediaEditor?.getToolValue(.fade) as? Float ?? 0.0,
                        minValue: 0.0,
                        maxValue: 1.0,
                        startValue: 0.0
                    ),
                    AdjustmentTool(
                        key: .highlights,
                        title: presentationData.strings.Story_Editor_Tool_Highlights,
                        value: mediaEditor?.getToolValue(.highlights) as? Float ?? 0.0,
                        minValue: -1.0,
                        maxValue: 1.0,
                        startValue: 0.0
                    ),
                    AdjustmentTool(
                        key: .shadows,
                        title: presentationData.strings.Story_Editor_Tool_Shadows,
                        value: mediaEditor?.getToolValue(.shadows) as? Float ?? 0.0,
                        minValue: -1.0,
                        maxValue: 1.0,
                        startValue: 0.0
                    ),
                    AdjustmentTool(
                        key: .vignette,
                        title: presentationData.strings.Story_Editor_Tool_Vignette,
                        value: mediaEditor?.getToolValue(.vignette) as? Float ?? 0.0,
                        minValue: 0.0,
                        maxValue: 1.0,
                        startValue: 0.0
                    )
//                    AdjustmentTool(
//                        key: .sharpen,
//                        title: "Sharpen",
//                        value: mediaEditor?.getToolValue(.sharpen) as? Float ?? 0.0,
//                        minValue: 0.0,
//                        maxValue: 1.0,
//                        startValue: 0.0
//                    )
                ]
                
                if !component.mediaEditor.sourceIsVideo {
                    tools.insert(AdjustmentTool(
                        key: .grain,
                        title: presentationData.strings.Story_Editor_Tool_Grain,
                        value: mediaEditor?.getToolValue(.grain) as? Float ?? 0.0,
                        minValue: 0.0,
                        maxValue: 1.0,
                        startValue: 0.0
                    ), at: tools.count - 1)
                }
                
                optionsSize = self.toolOptions.update(
                    transition: optionsTransition,
                    component: AnyComponent(AdjustmentsComponent(
                        tools: tools,
                        valueUpdated: { [weak state] key, value in
                            if let controller = environment.controller() as? MediaToolsScreen {
                                controller.mediaEditor.setToolValue(key, value: value)
                                state?.updated()
                            }
                        },
                        isTrackingUpdated: { [weak self] isTracking in
                            if let self {
                                let transition: Transition
                                if isTracking {
                                    transition = .immediate
                                } else {
                                    transition = .easeInOut(duration: 0.25)
                                }
                                transition.setAlpha(view: self.optionsBackgroundView, alpha: isTracking ? 0.0 : 1.0)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: previewContainerFrame.size
                )
                
                let adjustmentsToolScreen: ComponentView<Empty>
                if let current = self.toolScreen, !sectionChanged {
                    adjustmentsToolScreen = current
                } else {
                    adjustmentsToolScreen = ComponentView<Empty>()
                    self.toolScreen = adjustmentsToolScreen
                }
                toolScreen = adjustmentsToolScreen
                screenSize = adjustmentsToolScreen.update(
                    transition: optionsTransition,
                    component: AnyComponent(
                        AdjustmentsScreenComponent(
                            toggleUneditedPreview: { preview in
                                if let controller = environment.controller() as? MediaToolsScreen {
                                    controller.mediaEditor.setPreviewUnedited(preview)
                                }
                            }
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: previewContainerFrame.width, height: previewContainerFrame.height - optionsSize.height)
                )
            case .tint:
                self.curvesState = nil
                optionsSize = self.toolOptions.update(
                    transition: optionsTransition,
                    component: AnyComponent(TintComponent(
                        strings: presentationData.strings,
                        shadowsValue: mediaEditor?.getToolValue(.shadowsTint) as? TintValue ?? TintValue.initial,
                        highlightsValue: mediaEditor?.getToolValue(.highlightsTint) as? TintValue ?? TintValue.initial,
                        shadowsValueUpdated: { [weak state] value in
                            if let controller = environment.controller() as? MediaToolsScreen {
                                controller.mediaEditor.setToolValue(.shadowsTint, value: value)
                                state?.updated()
                            }
                        },
                        highlightsValueUpdated: { [weak state] value in
                            if let controller = environment.controller() as? MediaToolsScreen {
                                controller.mediaEditor.setToolValue(.highlightsTint, value: value)
                                state?.updated()
                            }
                        },
                        isTrackingUpdated: { [weak self] isTracking in
                            if let self {
                                let transition: Transition
                                if isTracking {
                                    transition = .immediate
                                } else {
                                    transition = .easeInOut(duration: 0.25)
                                }
                                transition.setAlpha(view: self.optionsBackgroundView, alpha: isTracking ? 0.0 : 1.0)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: previewContainerFrame.size
                )
                
                let tintToolScreen: ComponentView<Empty>
                if let current = self.toolScreen, !sectionChanged {
                    tintToolScreen = current
                } else {
                    tintToolScreen = ComponentView<Empty>()
                    self.toolScreen = tintToolScreen
                }
                toolScreen = tintToolScreen
                screenSize = tintToolScreen.update(
                    transition: optionsTransition,
                    component: AnyComponent(
                        AdjustmentsScreenComponent(
                            toggleUneditedPreview: { preview in
                                if let controller = environment.controller() as? MediaToolsScreen {
                                    controller.mediaEditor.setPreviewUnedited(preview)
                                }
                            }
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: previewContainerFrame.width, height: previewContainerFrame.height - optionsSize.height)
                )
            case .blur:
                self.curvesState = nil
                optionsSize = self.toolOptions.update(
                    transition: optionsTransition,
                    component: AnyComponent(BlurComponent(
                        strings: presentationData.strings,
                        value: mediaEditor?.getToolValue(.blur) as? BlurValue ?? BlurValue.initial,
                        hasPortrait: mediaEditor?.hasPortraitMask ?? false,
                        valueUpdated: { [weak state] value in
                            if let controller = environment.controller() as? MediaToolsScreen {
                                controller.mediaEditor.setToolValue(.blur, value: value)
                                state?.updated()
                            }
                        },
                        isTrackingUpdated: { [weak self] isTracking in
                            if let self {
                                let transition: Transition
                                if isTracking {
                                    transition = .immediate
                                } else {
                                    transition = .easeInOut(duration: 0.25)
                                }
                                transition.setAlpha(view: self.optionsBackgroundView, alpha: isTracking ? 0.0 : 1.0)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: previewContainerFrame.size
                )
                
                let blurToolScreen: ComponentView<Empty>
                if let current = self.toolScreen, !sectionChanged {
                    blurToolScreen = current
                } else {
                    blurToolScreen = ComponentView<Empty>()
                    self.toolScreen = blurToolScreen
                }
                toolScreen = blurToolScreen
                screenSize = blurToolScreen.update(
                    transition: optionsTransition,
                    component: AnyComponent(
                        BlurScreenComponent(
                            value: mediaEditor?.getToolValue(.blur) as? BlurValue ?? BlurValue.initial,
                            valueUpdated: { [weak state] value in
                                if let controller = environment.controller() as? MediaToolsScreen {
                                    controller.mediaEditor.setToolValue(.blur, value: value)
                                    state?.updated()
                                }
                            },
                            isTrackingUpdated: { [weak self] isTracking in
                                if let self {
                                    let transition: Transition
                                    if isTracking {
                                        transition = .immediate
                                    } else {
                                        transition = .easeInOut(duration: 0.25)
                                    }
                                    transition.setAlpha(view: self.optionsBackgroundView, alpha: isTracking ? 0.0 : 1.0)
                                    if let view = self.toolOptions.view {
                                        transition.setAlpha(view: view, alpha: isTracking ? 0.0 : 1.0)
                                    }
                                }
                            }
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: previewContainerFrame.width, height: previewContainerFrame.height)
                )
            case .curves:
                needsHistogram = true
                let internalState: CurvesInternalState
                if let current = self.curvesState {
                    internalState = current
                } else {
                    internalState = CurvesInternalState()
                    self.curvesState = internalState
                }
                self.toolOptions.parentState = state
                optionsSize = self.toolOptions.update(
                    transition: optionsTransition,
                    component: AnyComponent(CurvesComponent(
                        strings: presentationData.strings,
                        histogram: state.histogram,
                        internalState: internalState
                    )),
                    environment: {},
                    containerSize: previewContainerFrame.size
                )
                
                let curvesToolScreen: ComponentView<Empty>
                if let current = self.toolScreen, !sectionChanged {
                    curvesToolScreen = current
                } else {
                    curvesToolScreen = ComponentView<Empty>()
                    self.toolScreen = curvesToolScreen
                }
                toolScreen = curvesToolScreen
                screenSize = curvesToolScreen.update(
                    transition: optionsTransition,
                    component: AnyComponent(
                        CurvesScreenComponent(
                            value: mediaEditor?.getToolValue(.curves) as? CurvesValue ?? CurvesValue.initial,
                            section: internalState.section,
                            valueUpdated: { [weak state] value in
                                if let controller = environment.controller() as? MediaToolsScreen {
                                    controller.mediaEditor.setToolValue(.curves, value: value)
                                    state?.updated()
                                }
                            }
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: previewContainerFrame.width, height: previewContainerFrame.height - optionsSize.height)
                )
            }
            component.mediaEditor.isHistogramEnabled = needsHistogram
           
            let optionsFrame = CGRect(origin: .zero, size: optionsSize)
            if let optionsView = self.toolOptions.view {
                if optionsView.superview == nil {
                    optionsView.clipsToBounds = true
                    self.optionsContainerView.addSubview(optionsView)
                }
                optionsTransition.setFrame(view: optionsView, frame: optionsFrame)
                
                if sectionChanged && previousSection != nil {
                    optionsView.layer.allowsGroupOpacity = true
                    optionsView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { _ in
                        optionsView.layer.allowsGroupOpacity = false
                    })
                }
            }
            
            previewContainerFrame.size.height -= controlsBottomInset
            
            let optionsBackgroundFrame = CGRect(
                origin: CGPoint(x: 0.0, y: previewContainerFrame.height - optionsSize.height + controlsBottomInset),
                size: CGSize(width: optionsSize.width, height: optionsSize.height - controlsBottomInset)
            )
            transition.setFrame(view: self.optionsContainerView, frame: optionsBackgroundFrame)
            transition.setFrame(view: self.optionsBackgroundView, frame: CGRect(origin: .zero, size: optionsBackgroundFrame.size))
            
            if let toolScreen = toolScreen {
                let screenFrame = CGRect(origin: .zero, size: screenSize)
                if let screenView = toolScreen.view {
                    if screenView.superview == nil {
                        self.previewContainerView.insertSubview(screenView, at: 0)
                        
                        screenView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                    optionsTransition.setFrame(view: screenView, frame: screenFrame)
                }
            }
            
            transition.setFrame(view: self.previewContainerView, frame: previewContainerFrame)
            transition.setFrame(view: self.buttonsContainerView, frame: buttonsContainerFrame)
            transition.setFrame(view: self.buttonsBackgroundView, frame: CGRect(origin: .zero, size: buttonsContainerFrame.size))
            
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

public final class MediaToolsScreen: ViewController {
    fileprivate final class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        private weak var controller: MediaToolsScreen?
        private let context: AccountContext
    
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        private var currentSection: MediaToolsSection = .adjustments

        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        init(controller: MediaToolsScreen) {
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
            if let view = self.componentHost.view as? MediaToolsScreenComponent.View {
                view.animateInFromEditor()
            }
        }
        
        func animateOutToEditor(completion: @escaping () -> Void) {
            if let mediaEditor = self.controller?.mediaEditor {
                mediaEditor.play()
            }
            if let view = self.componentHost.view as? MediaToolsScreenComponent.View {
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
                    MediaToolsScreenComponent(
                        context: self.context,
                        mediaEditor: controller.mediaEditor,
                        section: self.currentSection,
                        sectionUpdated: { [weak self] section in
                            if let self {
                                self.currentSection = section
                                if let mediaEditor = self.controller?.mediaEditor {
                                    if section == .curves {
                                        mediaEditor.stop()
                                    } else {
                                        mediaEditor.play()
                                    }
                                }
                                if let layout = self.validLayout {
                                    self.containerLayoutUpdated(layout: layout, transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
                                }
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
    
    public var dismissed: () -> Void = {}
    
    private var initialValues: MediaEditorValues
        
    public init(context: AccountContext, mediaEditor: MediaEditor) {
        self.context = context
        self.mediaEditor = mediaEditor
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
            
    func requestDismiss(reset: Bool, animated: Bool) {
        if reset {
            self.mediaEditor.values = self.initialValues
        }
        
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
