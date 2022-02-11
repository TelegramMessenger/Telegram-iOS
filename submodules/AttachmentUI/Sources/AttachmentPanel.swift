import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import AccountContext

let panelButtonSize = CGSize(width: 80.0, height: 72.0)
let smallPanelButtonSize = CGSize(width: 54.0, height: 46.0)

private let iconSize = CGSize(width: 54.0, height: 42.0)
private let sideInset: CGFloat = 3.0
private let smallSideInset: CGFloat = 0.0

private enum AttachmentButtonTransition {
    case transitionIn
    case selection
}

private func generateShadowImage() -> UIImage? {
    return generateImage(CGSize(width: 90.0, height: 90.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
//        let rect = bounds.insetBy(dx: 12.0, dy: 24.0)
//        let path = UIBezierPath(roundedRect: CGRect(origin: rect.origin, size: CGSize(width: rect.width, height: rect.height + 33.0)), cornerRadius: 24.0).cgPath
//        context.addRect(bounds)
//        context.addPath(path)
//        context.clip(using: .evenOdd)
//
//        context.addPath(path)
//        context.setShadow(offset: CGSize(width: 0.0, height: 0.0), blur: 40.0, color: UIColor(rgb: 0x000000, alpha: 0.06).cgColor)
//        context.setFillColor(UIColor.white.cgColor)
//        context.setBlendMode(.multiply)
//        context.fillPath()
//
//        context.resetClip()
//        context.setBlendMode(.normal)
        
        var locations: [CGFloat] = [0.0, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0x000000, alpha: 0.0).cgColor, UIColor(rgb: 0x000000, alpha: 0.2).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [])
    })?.stretchableImage(withLeftCapWidth: 45, topCapHeight: 70)
}

private func generateBackgroundImage(colors: [UIColor]) -> UIImage? {
    return generateImage(iconSize, rotatedContext: { size, context in
        var locations: [CGFloat]
        if colors.count == 3 {
            locations = [1.0, 0.5, 0.0]
        } else {
            locations = [1.0, 0.0]
        }
        let colors: [CGColor] = colors.map { $0.cgColor }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        if colors.count == 2 {
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: .drawsAfterEndLocation)
        } else if colors.count == 3 {
            context.drawLinearGradient(gradient, start:  CGPoint(x: 0.0, y: size.height), end: CGPoint(x: size.width, y: 0.0), options: .drawsAfterEndLocation)
        }
//        let center = CGPoint(x: 10.0, y: 10.0)
//        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: size.width, options: .drawsAfterEndLocation)
    })
}

private let buttonGlowImage: UIImage? = {
    let inset: CGFloat = 6.0
    return generateImage(CGSize(width: iconSize.width + inset * 2.0, height: iconSize.height + inset * 2.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 21.0).cgPath
        context.addRect(bounds)
        context.addPath(path)
        context.clip(using: .evenOdd)
        
        context.addPath(path)
        context.setShadow(offset: CGSize(), blur: 14.0, color: UIColor(rgb: 0xffffff, alpha: 0.8).cgColor)
        context.setFillColor(UIColor.white.cgColor)
        context.fillPath()
    })?.withRenderingMode(.alwaysTemplate)
}()

private let buttonSelectionMaskImage: UIImage? = {
    let inset: CGFloat = 3.0
    return generateImage(CGSize(width: iconSize.width + inset * 2.0, height: iconSize.height + inset * 2.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 23.0).cgPath
        context.addPath(path)
        context.setFillColor(UIColor(rgb: 0xffffff).cgColor)
        context.fillPath()
    })?.withRenderingMode(.alwaysTemplate)
}()

private let ringImage: UIImage? = {
    return generateFilledCircleImage(diameter: iconSize.width, color: nil, strokeColor: .white, strokeWidth: 2.0, backgroundColor: nil)
}()

private final class AttachButtonComponent: CombinedComponent {
    let context: AccountContext
    let type: AttachmentButtonType
    let isSelected: Bool
    let isCollapsed: Bool
    let transitionFraction: CGFloat
    let strings: PresentationStrings
    let theme: PresentationTheme
    let action: () -> Void
    
    init(
        context: AccountContext,
        type: AttachmentButtonType,
        isSelected: Bool,
        isCollapsed: Bool,
        transitionFraction: CGFloat,
        strings: PresentationStrings,
        theme: PresentationTheme,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.type = type
        self.isSelected = isSelected
        self.isCollapsed = isCollapsed
        self.transitionFraction = transitionFraction
        self.strings = strings
        self.theme = theme
        self.action = action
    }

    static func ==(lhs: AttachButtonComponent, rhs: AttachButtonComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.type != rhs.type {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.isCollapsed != rhs.isCollapsed {
            return false
        }
        if lhs.transitionFraction != rhs.transitionFraction {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    static var body: Body {
        let icon = Child(AttachButtonIconComponent.self)
        let title = Child(Text.self)

        return { context in
            let name: String
            let animationName: String?
            let imageName: String?
            let backgroundColors: [UIColor]
            let foregroundColor: UIColor = .white
            
            let isCollapsed = context.component.isCollapsed
            
            switch context.component.type {
            case .camera:
                name = context.component.strings.Attachment_Camera
                animationName = "anim_camera"
                imageName = "Chat/Attach Menu/Camera"
                backgroundColors = [UIColor(rgb: 0xba4aae), UIColor(rgb: 0xdd4e6f), UIColor(rgb: 0xf3b76c)]
            case .gallery:
                name = context.component.strings.Attachment_Gallery
                animationName = "anim_gallery"
                imageName = "Chat/Attach Menu/Gallery"
                backgroundColors = [UIColor(rgb: 0x2071f1), UIColor(rgb: 0x1bc9fa)]
            case .file:
                name = context.component.strings.Attachment_File
                animationName = "anim_file"
                imageName = "Chat/Attach Menu/File"
                backgroundColors = [UIColor(rgb: 0xed705d), UIColor(rgb: 0xffa14c)]
            case .location:
                name = context.component.strings.Attachment_Location
                animationName = "anim_location"
                imageName = "Chat/Attach Menu/Location"
                backgroundColors = [UIColor(rgb: 0x5fb84f), UIColor(rgb: 0x99de6f)]
            case .contact:
                name = context.component.strings.Attachment_Contact
                animationName = "anim_contact"
                imageName = "Chat/Attach Menu/Contact"
                backgroundColors = [UIColor(rgb: 0xaa47d6), UIColor(rgb: 0xd67cf4)]
            case .poll:
                name = context.component.strings.Attachment_Poll
                animationName = "anim_poll"
                imageName = "Chat/Attach Menu/Poll"
                backgroundColors = [UIColor(rgb: 0xe9484f), UIColor(rgb: 0xee707e)]
            case let .app(appName):
                name = appName
                animationName = nil
                imageName = nil
                backgroundColors = [UIColor(rgb: 0x000000), UIColor(rgb: 0x000000)]
            }
            
            let icon = icon.update(
                component: AttachButtonIconComponent(
                    animationName: animationName,
                    imageName: imageName,
                    isSelected: context.component.isSelected,
                    backgroundColors: backgroundColors,
                    foregroundColor: foregroundColor,
                    theme: context.component.theme,
                    context: context.component.context,
                    action: context.component.action
                ),
                availableSize: iconSize,
                transition: context.transition
            )

            let title = title.update(
                component: Text(
                    text: name,
                    font: Font.regular(11.0),
                    color: context.component.theme.actionSheet.primaryTextColor
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )

            let topInset: CGFloat = 8.0
            let spacing: CGFloat = 3.0 + UIScreenPixel

            let normalIconScale = isCollapsed ? 0.7 : 1.0
            let smallIconScale = isCollapsed ? 0.5 : 0.6
            
            let iconScale = normalIconScale - (normalIconScale - smallIconScale) * abs(context.component.transitionFraction)
            let iconOffset: CGFloat = (isCollapsed ? 10.0 : 20.0) * context.component.transitionFraction
            let iconFrame = CGRect(origin: CGPoint(x: floor((context.availableSize.width - icon.size.width) / 2.0) + iconOffset, y: isCollapsed ? 3.0 : topInset), size: icon.size)
            var titleFrame = CGRect(origin: CGPoint(x: floor((context.availableSize.width - title.size.width) / 2.0) + iconOffset, y: iconFrame.midY + (iconFrame.height * 0.5 * iconScale) + spacing), size: title.size)
            if isCollapsed {
                titleFrame.origin.y = floor(iconFrame.midY - title.size.height / 2.0)
            }
            
            context.add(title
                .position(CGPoint(x: titleFrame.midX, y: titleFrame.midY))
                .opacity(isCollapsed ? 0.0 : 1.0 - abs(context.component.transitionFraction))
            )

            context.add(icon
                .position(CGPoint(x: iconFrame.midX, y: iconFrame.midY))
                .scale(iconScale)
            )
            
            return context.availableSize
        }
    }
}

private final class AttachButtonIconComponent: Component {
    let animationName: String?
    let imageName: String?
    let isSelected: Bool
    let backgroundColors: [UIColor]
    let foregroundColor: UIColor
    let theme: PresentationTheme
    let context: AccountContext
    
    let action: () -> Void

    init(
        animationName: String?,
        imageName: String?,
        isSelected: Bool,
        backgroundColors: [UIColor],
        foregroundColor: UIColor,
        theme: PresentationTheme,
        context: AccountContext,
        action: @escaping () -> Void
    ) {
        self.animationName = animationName
        self.imageName = imageName
        self.isSelected = isSelected
        self.backgroundColors = backgroundColors
        self.foregroundColor = foregroundColor
        self.theme = theme
        self.context = context
        self.action = action
    }

    static func ==(lhs: AttachButtonIconComponent, rhs: AttachButtonIconComponent) -> Bool {
        if lhs.animationName != rhs.animationName {
            return false
        }
        if lhs.imageName != rhs.imageName {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.backgroundColors != rhs.backgroundColors {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private let glowView: UIImageView
        private let selectionView: UIImageView
        private let backgroundView: UIView
        private let iconView: UIImageView
    
        private var action: (() -> Void)?
        
        private var currentColors: [UIColor] = []
        private var currentImageName: String?
        private var currentIsSelected: Bool?
            
        init() {
            self.glowView = UIImageView()
            self.glowView.image = buttonGlowImage
            self.glowView.isUserInteractionEnabled = false
            
            self.selectionView = UIImageView()
            self.selectionView.image = buttonSelectionMaskImage
            self.selectionView.isUserInteractionEnabled = false
            
            self.backgroundView = UIView()
            self.backgroundView.clipsToBounds = true
            self.backgroundView.isUserInteractionEnabled = false
            self.backgroundView.layer.cornerRadius = 21.0
            
            self.iconView = UIImageView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.glowView)
            self.addSubview(self.selectionView)
            self.addSubview(self.backgroundView)
            self.addSubview(self.iconView)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.highligthedChanged = { _ in

            }
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        @objc private func pressed() {
            self.action?()
        }

        func update(component: AttachButtonIconComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.action = component.action
            
            if self.currentColors != component.backgroundColors {
                self.currentColors = component.backgroundColors
                self.backgroundView.layer.contents = generateBackgroundImage(colors: component.backgroundColors)?.cgImage
                
                if let color = component.backgroundColors.last {
                    self.glowView.tintColor = color
                    self.selectionView.tintColor = color.withAlphaComponent(0.2)
                }
            }
            
            if self.currentImageName != component.imageName {
                self.currentImageName = component.imageName
                if let imageName = component.imageName, let image = UIImage(bundleImageName: imageName) {
                    self.iconView.image = image
                    
                    let scale: CGFloat = 0.875
                    let iconSize = CGSize(width: floorToScreenPixels(image.size.width * scale), height: floorToScreenPixels(image.size.height * scale))
                    self.iconView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - iconSize.width) / 2.0), y: floorToScreenPixels((availableSize.height - iconSize.height) / 2.0)), size: iconSize)
                }
            }
            
            if self.currentIsSelected != component.isSelected {
                self.currentIsSelected = component.isSelected

                transition.setScale(view: self.selectionView, scale: component.isSelected ? 1.0 : 0.8)
            }
            
            let contentFrame = CGRect(origin: CGPoint(), size: availableSize)
            self.backgroundView.frame = contentFrame
            
            self.glowView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: contentFrame.width + 12.0, height: contentFrame.height + 12.0))
            self.glowView.center = CGPoint(x: contentFrame.midX, y: contentFrame.midY)
            
            self.selectionView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: contentFrame.width + 6.0, height: contentFrame.height + 6.0))
            self.selectionView.center = CGPoint(x: contentFrame.midX, y: contentFrame.midY)
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class AttachmentPanel: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private let shadowNode: ASImageNode
    private let containerNode: ASDisplayNode
    private var effectView: UIVisualEffectView?
    private let scrollNode: ASScrollNode
    private let backgroundNode: ASDisplayNode
    private var buttonViews: [Int: ComponentHostView<Empty>] = [:]
    
    private var buttons: [AttachmentButtonType] = []
    private var selectedIndex: Int = 1
    private var isCollapsed: Bool = false
    
    private var validLayout: CGSize?
    private var scrollLayout: (width: CGFloat, contentSize: CGSize)?
    
    var selectionChanged: (AttachmentButtonType, Bool) -> Void = { _, _ in }
    
    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.shadowNode = ASImageNode()
        self.shadowNode.contentMode = .scaleToFill
        self.shadowNode.displaysAsynchronously = false
        self.shadowNode.image = generateShadowImage()
        
        self.containerNode = ASDisplayNode()
        self.containerNode.clipsToBounds = true
        
        self.scrollNode = ASScrollNode()
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = self.presentationData.theme.actionSheet.itemBackgroundColor
        
        super.init()
                        
        self.addSubnode(self.shadowNode)
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.scrollNode)
    }
    
    override func didLoad() {
        super.didLoad()
        if #available(iOS 13.0, *) {
            self.containerNode.layer.cornerCurve = .continuous
        }
        self.containerNode.layer.cornerRadius = 23.0
        
        self.scrollNode.view.delegate = self
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        
        let effect: UIVisualEffect
        switch self.presentationData.theme.actionSheet.backgroundType {
        case .light:
            effect = UIBlurEffect(style: .light)
        case .dark:
            effect = UIBlurEffect(style: .dark)
        }
        let effectView = UIVisualEffectView(effect: effect)
        self.effectView = effectView
        self.containerNode.view.insertSubview(effectView, at: 0)
    }
    
    func updateViews(transition: Transition) {
        guard let _ = self.validLayout else {
            return
        }
        
        let visibleRect = self.scrollNode.bounds.insetBy(dx: -180.0, dy: 0.0)
        let actualVisibleRect = self.scrollNode.bounds
        var validButtons = Set<Int>()
        
        let buttonSize = self.isCollapsed ? smallPanelButtonSize : panelButtonSize
        
        for i in 0 ..< self.buttons.count {
            let buttonFrame = CGRect(origin: CGPoint(x: (self.isCollapsed ? smallSideInset : sideInset) + buttonSize.width * CGFloat(i), y: 0.0), size: buttonSize)
            if !visibleRect.intersects(buttonFrame) {
                continue
            }
            validButtons.insert(i)
            
            let edge = buttonSize.width * 0.75
            let leftEdge = max(-edge, min(0.0, buttonFrame.minX - actualVisibleRect.minX)) / -edge
            let rightEdge = min(edge, max(0.0, buttonFrame.maxX - actualVisibleRect.maxX)) / edge
            
            let transitionFraction: CGFloat
            if leftEdge > rightEdge {
                transitionFraction = leftEdge
            } else {
                transitionFraction = -rightEdge
            }
            
            var buttonTransition = transition
            let buttonView: ComponentHostView<Empty>
            if let current = self.buttonViews[i] {
                buttonView = current
            } else {
                buttonTransition = .immediate
                buttonView = ComponentHostView<Empty>()
                self.buttonViews[i] = buttonView
                self.scrollNode.view.addSubview(buttonView)
            }
            
            let type = self.buttons[i]
            let _ = buttonView.update(
                transition: buttonTransition,
                component: AnyComponent(AttachButtonComponent(
                    context: self.context,
                    type: type,
                    isSelected: i == self.selectedIndex,
                    isCollapsed: self.isCollapsed,
                    transitionFraction: transitionFraction,
                    strings: self.presentationData.strings,
                    theme: self.presentationData.theme,
                    action: { [weak self] in
                        if let strongSelf = self {
                            let ascending = i > strongSelf.selectedIndex
                            strongSelf.selectedIndex = i
                            strongSelf.selectionChanged(type, ascending)
                            strongSelf.updateViews(transition: .init(animation: .curve(duration: 0.2, curve: .spring)))
                        }
                    })
                ),
                environment: {},
                containerSize: buttonSize
            )
            buttonTransition.setFrame(view: buttonView, frame: buttonFrame)
        }
    }
    
    private func updateScrollLayoutIfNeeded(force: Bool, transition: ContainedViewLayoutTransition) -> Bool {
        guard let size = self.validLayout else {
            return false
        }
        if self.scrollLayout?.width == size.width && !force {
            return false
        }

        let buttonSize = self.isCollapsed ? smallPanelButtonSize : panelButtonSize
        let contentSize = CGSize(width: (self.isCollapsed ? smallSideInset : sideInset) * 2.0 + CGFloat(self.buttons.count) * buttonSize.width, height: buttonSize.height)
        self.scrollLayout = (size.width, contentSize)

        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
        self.scrollNode.view.contentSize = contentSize

        return true
    }
    
    func update(buttons: [AttachmentButtonType], isCollapsed: Bool, size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        self.buttons = buttons
        
        let isCollapsedUpdated = self.isCollapsed != isCollapsed
        self.isCollapsed = isCollapsed
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        let containerTransition: ContainedViewLayoutTransition
        let containerFrame: CGRect
        if isCollapsed {
            containerFrame = CGRect(origin: CGPoint(x: 0.0, y: bounds.height - smallPanelButtonSize.height), size: CGSize(width: bounds.width, height: smallPanelButtonSize.height))
        } else {
            containerFrame = bounds
        }
        let containerBounds = CGRect(origin: CGPoint(), size: containerFrame.size)
        if isCollapsedUpdated {
            containerTransition = .animated(duration: 0.25, curve: .easeInOut)
        } else {
            containerTransition = transition
        }
        
        containerTransition.updateFrame(node: self.containerNode, frame: containerFrame)
        if let effectView = self.effectView {
            containerTransition.updateFrame(view: effectView, frame: bounds)
        }
        containerTransition.updateFrame(node: self.backgroundNode, frame: containerBounds)
        
        var shadowFrame = bounds.insetBy(dx: -16.0, dy: -24.0)
        shadowFrame.size.height += 44.0
        transition.updateFrame(node: self.shadowNode, frame: shadowFrame)
        
        let _ = self.updateScrollLayoutIfNeeded(force: isCollapsedUpdated, transition: containerTransition)
        
        var buttonTransition: Transition = .immediate
        if isCollapsedUpdated {
            buttonTransition = .easeInOut(duration: 0.25)
        }
        
        self.updateViews(transition: buttonTransition)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateViews(transition: .immediate)
    }
}
