import Foundation
import UIKit
import Display
import LegacyComponents
import ComponentFlow
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
    
    var context: AccountContext?
    var present: ((ViewController, Any?) -> Void)?
    
    var view: UIView {
        return self
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -16.0, dy: -16.0).contains(point)
    }
        
    override init(frame: CGRect) {
        self.backgroundView = GlassContextExtractableContainer()
        
        super.init(frame: frame)
        
        self.addSubview(self.backgroundView)
        self.backgroundView.contentView.addSubview(self.button)
                
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        
        self.update()
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    @objc private func buttonPressed() {
        guard let context = self.context else {
            return
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
        
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: "Live", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LiveOn"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
            self?.modeUpdated?(.live)
            
            f(.default)
        })))
        items.append(.action(ContextMenuActionItem(text: "Loop", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LiveLoop"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
            self?.modeUpdated?(.loop)
            
            f(.default)
        })))
        items.append(.action(ContextMenuActionItem(text: "Bounce", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LiveBounce"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
            self?.modeUpdated?(.bounce)
            
            f(.default)
        })))
        items.append(.action(ContextMenuActionItem(text: "Live Off", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LiveOff"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
            self?.modeUpdated?(.off)
            
            f(.default)
        })))
        
        let contextController = makeContextController(presentationData: presentationData, source: .reference(LivePhotoReferenceContentSource(sourceView: self.backgroundView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
        self.present?(contextController, nil)
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
        let iconName: String
        let labelText: String
        switch self.mode {
        case .live:
            labelText = "Live"
            iconName = "Media Editor/LiveOn"
        case .loop:
            labelText = "Loop"
            iconName = "Media Editor/LiveLoop"
        case .bounce:
            labelText = "Bounce"
            iconName = "Media Editor/LiveBounce"
        default:
            labelText = "Live Off"
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
        self.button.frame = CGRect(origin: .zero, size: size)
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
