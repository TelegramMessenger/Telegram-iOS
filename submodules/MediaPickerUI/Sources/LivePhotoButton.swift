import Foundation
import UIKit
import Display
import LegacyComponents
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import MultilineTextComponent
import GlassBackgroundComponent
import ContextUI
import TelegramPresentationData
import AccountContext
import BundleIconComponent

final class LivePhotoButton: UIView, TGLivePhotoButton {
    private let backgroundView: GlassContextExtractableContainer
    private let icon = ComponentView<Empty>()
    private let label = ComponentView<Empty>()
    private let arrow = ComponentView<Empty>()
    private let button = HighlightTrackingButton()
    
    private var mode: TGMediaLivePhotoMode = .off
    
    public var modeUpdated: ((TGMediaLivePhotoMode) -> Void)?
    
    let context: AccountContext
    var present: ((ViewController, Any?) -> Void)?
    
    var view: UIView {
        return self
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -16.0, dy: -16.0).contains(point)
    }
        
    init(context: AccountContext) {
        self.context = context
        
        self.backgroundView = GlassContextExtractableContainer()
        
        super.init(frame: .zero)
        
        self.addSubview(self.backgroundView)
        self.backgroundView.contentView.addSubview(self.button)
                
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        
        self.update()
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    @objc private func buttonPressed() {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
        
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_LivePhoto_Live, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LiveOn"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
            self?.presentTooltip(.live)
            self?.modeUpdated?(.live)
            
            f(.default)
        })))
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_LivePhoto_Loop, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LiveLoop"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
            self?.presentTooltip(.loop)
            self?.modeUpdated?(.loop)
            
            f(.default)
        })))
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_LivePhoto_Bounce, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LiveBounce"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
            self?.presentTooltip(.bounce)
            self?.modeUpdated?(.bounce)
            
            f(.default)
        })))
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_LivePhoto_LiveOff, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LiveOff"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
            self?.presentTooltip(.off)
            self?.modeUpdated?(.off)
            
            f(.default)
        })))
        
        let contextController = makeContextController(presentationData: presentationData, source: .reference(LivePhotoReferenceContentSource(sourceView: self.backgroundView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
        self.present?(contextController, nil)
    }
    
    private func presentTooltip(_ mode: TGMediaLivePhotoMode) {
        guard self.mode != mode else {
            return
        }
        let iconName: String
        let text: String
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        switch mode {
        case .live:
            iconName = "Media Editor/LiveLargeOn"
            text = presentationData.strings.MediaPicker_LivePhoto_Tooltip_Live
        case .loop:
            iconName = "Media Editor/LiveLargeLoop"
            text = presentationData.strings.MediaPicker_LivePhoto_Tooltip_Loop
        case .bounce:
            iconName = "Media Editor/LiveLargeBounce"
            text = presentationData.strings.MediaPicker_LivePhoto_Tooltip_Bounce
        case .off:
            iconName = "Media Editor/LiveLargeOff"
            text = presentationData.strings.MediaPicker_LivePhoto_Tooltip_LiveOff
        default:
            iconName = ""
            text = ""
        }
        
        let controller = TooltipInfoScreen(
            context: self.context,
            content: AnyComponent(HStack([
                AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                    BundleIconComponent(name: iconName, tintColor: .white)
                )),
                AnyComponentWithIdentity(id: "label", component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)))
                ))
            ], spacing: 11.0)),
            alignment: .center
        )
        self.present?(controller, nil)
    }
    
    func updateFrame(_ frame: CGRect) {
        let transition: ContainedViewLayoutTransition
        if self.frame.width.isZero {
            transition = .immediate
        } else {
            transition = .animated(duration: 0.4, curve: .spring)
        }
        transition.updateFrame(view: self, frame: frame)
    }
    
    func setLivePhotoMode(_ mode: TGMediaLivePhotoMode) {
        self.mode = mode
        self.update()
    }
    
    func update() {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        let iconName: String
        let labelText: String
        switch self.mode {
        case .live:
            labelText = presentationData.strings.MediaPicker_LivePhoto_Live
            iconName = "Media Editor/LiveOn"
        case .loop:
            labelText = presentationData.strings.MediaPicker_LivePhoto_Loop
            iconName = "Media Editor/LiveLoop"
        case .bounce:
            labelText = presentationData.strings.MediaPicker_LivePhoto_Bounce
            iconName = "Media Editor/LiveBounce"
        default:
            labelText = presentationData.strings.MediaPicker_LivePhoto_LiveOff
            iconName = "Media Editor/LiveOff"
        }
        
        let iconSize = self.icon.update(
            transition: .immediate,
            component: AnyComponent(
                BundleIconComponent(name: iconName, tintColor: .white)
            ),
            environment: {},
            containerSize: CGSize(width: 18.0, height: 18.0)
        )
        let iconFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((18.0 - iconSize.height) / 2.0)), size: iconSize)
        if let iconView = self.icon.view {
            if iconView.superview == nil {
                iconView.isUserInteractionEnabled = false
                self.backgroundView.contentView.addSubview(iconView)
            }
            iconView.frame = iconFrame
        }
        
        let labelSize = self.label.update(
            transition: .immediate,
            component: AnyComponent(
                Text(text: labelText.uppercased(), font: Font.regular(12.0), color: .white)
            ),
            environment: {},
            containerSize: CGSize(width: 200.0, height: 18.0)
        )
        let labelFrame = CGRect(origin: CGPoint(x: 19.0, y: floorToScreenPixels((18.0 - labelSize.height) / 2.0)), size: labelSize)
        if let labelView = self.label.view {
            if labelView.superview == nil {
                labelView.isUserInteractionEnabled = false
                self.backgroundView.contentView.addSubview(labelView)
            }
            labelView.frame = labelFrame
        }
        
        let arrowSize = self.arrow.update(
            transition: .immediate,
            component: AnyComponent(
                BundleIconComponent(name: "Media Editor/DownArrow", tintColor: .white)
            ),
            environment: {},
            containerSize: CGSize(width: 8.0, height: 5.0)
        )
        let arrowFrame = CGRect(origin: CGPoint(x: 19.0 + labelSize.width + 2.0 + UIScreenPixel, y: floorToScreenPixels((18.0 - arrowSize.height) / 2.0)), size: arrowSize)
        if let arrowView = self.arrow.view {
            if arrowView.superview == nil {
                arrowView.isUserInteractionEnabled = false
                self.backgroundView.contentView.addSubview(arrowView)
            }
            arrowView.frame = arrowFrame
        }
        
        let size = CGSize(width: 19.0 + labelSize.width + 16.0, height: 18.0)
        self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: true, tintColor: .init(kind: .panel), isInteractive: true, transition: .immediate)
        self.backgroundView.frame = CGRect(origin: .zero, size: size)
        self.button.frame = CGRect(origin: .zero, size: size).insetBy(dx: -16.0, dy: -16.0)
    }
}

private final class LivePhotoReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    
    let forceDisplayBelowKeyboard = true
    
    init(sourceView: UIView) {
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class TooltipInfoContent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let content: AnyComponent<Empty>
    let alignment: TooltipInfoScreen.Alignment
    
    init(
        context: AccountContext,
        content: AnyComponent<Empty>,
        alignment: TooltipInfoScreen.Alignment
    ) {
        self.context = context
        self.content = content
        self.alignment = alignment
    }
    
    static func ==(lhs: TooltipInfoContent, rhs: TooltipInfoContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.alignment != rhs.alignment {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let backgroundView = GlassBackgroundView()
        private let contentView = ComponentView<Empty>()
        
        private var component: TooltipInfoContent?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var isDismissed = false
        func dismiss() {
            guard !self.isDismissed, let controller = self.environment?.controller() else {
                return
            }
            self.isDismissed = true
            
            let transition = ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut))
            transition.setBlur(layer: self.backgroundView.layer, radius: 10.0)
            self.backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                controller.dismiss()
            })
        }
        
        func update(component: TooltipInfoContent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            let insets = UIEdgeInsets(top: 12.0, left: 10.0, bottom: 12.0, right: 18.0)
            let contentSize = self.contentView.update(
                transition: .immediate,
                component: component.content,
                environment: {},
                containerSize: availableSize
            )
            if let contentView = self.contentView.view {
                if contentView.superview == nil {
                    self.backgroundView.contentView.addSubview(contentView)
                }
                contentView.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: contentSize)
            }
            
            let backgroundSize = CGSize(width: contentSize.width + insets.left + insets.right, height: contentSize.height + insets.top + insets.bottom)
            self.backgroundView.update(size: backgroundSize, cornerRadius: backgroundSize.height * 0.5, isDark: true, tintColor: .init(kind: .panel), transition: .immediate)
            
            let backgroundFrame: CGRect
            switch component.alignment {
            case .center:
                backgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - backgroundSize.width) / 2.0), y: floor((availableSize.height - backgroundSize.height) / 2.0)), size: backgroundSize)
            case .bottom:
                backgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - backgroundSize.width) / 2.0), y: availableSize.height - backgroundSize.height - environment.additionalInsets.bottom - backgroundSize.height - 38.0), size: backgroundSize)
            }
            
            self.backgroundView.frame = backgroundFrame
            self.environment = environment
            if self.component == nil {
                self.backgroundView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
                self.backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                
                Queue.mainQueue().after(2.5) {
                    self.dismiss()
                }
            }
            self.component = component
            
            return availableSize
        }
        
        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            self.dismiss()
            
            return nil
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class TooltipInfoScreen: ViewControllerComponentContainer {
    enum Alignment {
        case center
        case bottom
    }
    
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        content: AnyComponent<Empty>,
        alignment: Alignment
    ) {
        self.context = context
        
        super.init(
            context: context,
            component: TooltipInfoContent(
                context: context,
                content: content,
                alignment: alignment
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
}
