import Foundation
import UIKit
import Display
import ComponentFlow
import LegacyComponents
import TelegramCore
import Postbox
import LottieAnimationComponent

enum DrawingTextStyle: Equatable {
    case regular
    case filled
    case semi
    case stroke
    
    init(style: DrawingTextEntity.Style) {
        switch style {
        case .regular:
            self = .regular
        case .filled:
            self = .filled
        case .semi:
            self = .semi
        case .stroke:
            self = .stroke
        }
    }
}

enum DrawingTextAnimation: Equatable {
    case none
    case typing
    case wiggle
    case zoomIn
    
    init(animation: DrawingTextEntity.Animation) {
        switch animation {
        case .none:
            self = .none
        case .typing:
            self = .typing
        case .wiggle:
            self = .wiggle
        case .zoomIn:
            self = .zoomIn
        }
    }
}

enum DrawingTextAlignment: Equatable {
    case left
    case center
    case right
    
    init(alignment: DrawingTextEntity.Alignment) {
        switch alignment {
        case .left:
            self = .left
        case .center:
            self = .center
        case .right:
            self = .right
        }
    }
}

enum DrawingTextFont: Equatable, Hashable {
    case sanFrancisco
    case other(String, String)
    
    init(font: DrawingTextEntity.Font) {
        switch font {
        case .sanFrancisco:
            self = .sanFrancisco
        case let .other(font, name):
            self = .other(font, name)
        }
    }
    
    var font: DrawingTextEntity.Font {
        switch self {
        case .sanFrancisco:
            return .sanFrancisco
        case let .other(font, name):
            return .other(font, name)
        }
    }
    
    var title: String {
        switch self {
        case .sanFrancisco:
            return "San Francisco"
        case let .other(_, name):
            return name
        }
    }
    
    func uiFont(size: CGFloat) -> UIFont {
        switch self {
        case .sanFrancisco:
            return Font.with(size: size, design: .round, weight: .semibold)
        case let .other(font, _):
            return UIFont(name: font, size: size) ?? Font.semibold(size)
        }
    }
}

final class TextAlignmentComponent: Component {
    let alignment: DrawingTextAlignment
    
    init(alignment: DrawingTextAlignment) {
        self.alignment = alignment
    }
    
    static func == (lhs: TextAlignmentComponent, rhs: TextAlignmentComponent) -> Bool {
        return lhs.alignment == rhs.alignment
    }
    
    public final class View: UIView {
        private let line1 = SimpleLayer()
        private let line2 = SimpleLayer()
        private let line3 = SimpleLayer()
        private let line4 = SimpleLayer()
            
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            let lines = [self.line1, self.line2, self.line3, self.line4]
            lines.forEach { line in
                line.backgroundColor = UIColor.white.cgColor
                line.cornerRadius = 1.0
                line.masksToBounds = true
                self.layer.addSublayer(line)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: TextAlignmentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let height = 2.0 - UIScreenPixel
            let spacing: CGFloat = 3.0 + UIScreenPixel
            let long = 21.0
            let short = 13.0
            
            let size = CGSize(width: long, height: 18.0)
            
            switch component.alignment {
            case .left:
                transition.setFrame(layer: self.line1, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: long, height: height)))
                transition.setFrame(layer: self.line2, frame: CGRect(origin: CGPoint(x: 0.0, y: height + spacing), size: CGSize(width: short, height: height)))
                transition.setFrame(layer: self.line3, frame: CGRect(origin: CGPoint(x: 0.0, y: height + spacing + height + spacing), size: CGSize(width: long, height: height)))
                transition.setFrame(layer: self.line4, frame: CGRect(origin: CGPoint(x: 0.0, y: height + spacing + height + spacing + height + spacing), size: CGSize(width: short, height: height)))
            case .center:
                transition.setFrame(layer: self.line1, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - long) / 2.0), y: 0.0), size: CGSize(width: long, height: height)))
                transition.setFrame(layer: self.line2, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - short) / 2.0), y: height + spacing), size: CGSize(width: short, height: height)))
                transition.setFrame(layer: self.line3, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - long) / 2.0), y: height + spacing + height + spacing), size: CGSize(width: long, height: height)))
                transition.setFrame(layer: self.line4, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - short) / 2.0), y: height + spacing + height + spacing + height + spacing), size: CGSize(width: short, height: height)))
            case .right:
                transition.setFrame(layer: self.line1, frame: CGRect(origin: CGPoint(x: size.width - long, y: 0.0), size: CGSize(width: long, height: height)))
                transition.setFrame(layer: self.line2, frame: CGRect(origin: CGPoint(x: size.width - short, y: height + spacing), size: CGSize(width: short, height: height)))
                transition.setFrame(layer: self.line3, frame: CGRect(origin: CGPoint(x: size.width - long, y: height + spacing + height + spacing), size: CGSize(width: long, height: height)))
                transition.setFrame(layer: self.line4, frame: CGRect(origin: CGPoint(x: size.width - short, y: height + spacing + height + spacing + height + spacing), size: CGSize(width: short, height: height)))
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class TextFontComponent: Component {
    let selectedValue: DrawingTextFont
    let tag: AnyObject?
    let tapped: () -> Void
    
    init(selectedValue: DrawingTextFont, tag: AnyObject?, tapped: @escaping () -> Void) {
        self.selectedValue = selectedValue
        self.tag = tag
        self.tapped = tapped
    }
    
    static func == (lhs: TextFontComponent, rhs: TextFontComponent) -> Bool {
        return lhs.selectedValue == rhs.selectedValue
    }
    
    final class View: UIView, ComponentTaggedView {
        private var button = HighlightableButton()
        private let icon = SimpleLayer()
        
        private var component: TextFontComponent?
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.button)
            self.button.layer.addSublayer(self.icon)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed(_ sender: HighlightableButton) {
            if let component = self.component {
                component.tapped()
            }
        }
                        
        func update(component: TextFontComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            if self.icon.contents == nil {
                self.icon.contents = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/FontArrow"), color: UIColor(rgb: 0xffffff, alpha: 0.5))?.cgImage
            }
            
            let value = component.selectedValue
            
            var disappearingSnapshotView: UIView?
            let previousTitle = self.button.title(for: .normal)
            if previousTitle != value.title {
                if let snapshotView = self.button.titleLabel?.snapshotView(afterScreenUpdates: false) {
                    snapshotView.center = self.button.titleLabel?.center ?? snapshotView.center
                    self.button.addSubview(snapshotView)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    self.button.titleLabel?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    disappearingSnapshotView = snapshotView
                }
            }
            
            self.button.clipsToBounds = true
            self.button.setTitle(value.title, for: .normal)
            self.button.titleLabel?.font = value.uiFont(size: 13.0)
            self.button.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 20.0)
            var buttonSize = self.button.sizeThatFits(availableSize)
            buttonSize.width += 20.0
            buttonSize.height = 30.0
            transition.setFrame(view: self.button, frame: CGRect(origin: .zero, size: buttonSize))
            self.button.layer.cornerRadius = 11.0
            self.button.layer.borderWidth = 1.0 - UIScreenPixel
            self.button.layer.borderColor = UIColor.white.cgColor
            self.button.addTarget(self, action: #selector(self.pressed(_:)), for: .touchUpInside)
            
            let iconSize = CGSize(width: 16.0, height: 16.0)
            let iconFrame = CGRect(origin: CGPoint(x: buttonSize.width - iconSize.width - 8.0, y: floorToScreenPixels((buttonSize.height - iconSize.height) / 2.0)), size: iconSize)
            transition.setFrame(layer: self.icon, frame: iconFrame)
            
            if let disappearingSnapshotView, let titleLabel = self.button.titleLabel {
                disappearingSnapshotView.layer.animatePosition(from: disappearingSnapshotView.center, to: titleLabel.center, duration: 0.2, removeOnCompletion: false)
                self.button.titleLabel?.layer.animatePosition(from: disappearingSnapshotView.center, to: titleLabel.center, duration: 0.2)
            }
            
            return CGSize(width: self.button.frame.width, height: availableSize.height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class TextSettingsComponent: CombinedComponent {
    let color: DrawingColor?
    let style: DrawingTextStyle
    let animation: DrawingTextAnimation
    let alignment: DrawingTextAlignment
    let font: DrawingTextFont
    let isEmojiKeyboard: Bool
    let tag: AnyObject?
    let fontTag: AnyObject?

    let presentColorPicker: () -> Void
    let presentFastColorPicker: (GenericComponentViewTag) -> Void
    let updateFastColorPickerPan: (CGPoint) -> Void
    let dismissFastColorPicker: () -> Void
    let toggleStyle: () -> Void
    let toggleAnimation: () -> Void
    let toggleAlignment: () -> Void
    let presentFontPicker: () -> Void
    let toggleKeyboard: (() -> Void)?
    
    init(
        color: DrawingColor?,
        style: DrawingTextStyle,
        animation: DrawingTextAnimation,
        alignment: DrawingTextAlignment,
        font: DrawingTextFont,
        isEmojiKeyboard: Bool,
        tag: AnyObject?,
        fontTag: AnyObject?,
        presentColorPicker: @escaping () -> Void = {},
        presentFastColorPicker: @escaping (GenericComponentViewTag) -> Void = { _ in },
        updateFastColorPickerPan: @escaping (CGPoint) -> Void = { _ in },
        dismissFastColorPicker: @escaping () -> Void = {},
        toggleStyle: @escaping () -> Void,
        toggleAnimation: @escaping () -> Void,
        toggleAlignment: @escaping () -> Void,
        presentFontPicker: @escaping () -> Void,
        toggleKeyboard: (() -> Void)?
    ) {
        self.color = color
        self.style = style
        self.animation = animation
        self.alignment = alignment
        self.font = font
        self.isEmojiKeyboard = isEmojiKeyboard
        self.tag = tag
        self.fontTag = fontTag
        self.presentColorPicker = presentColorPicker
        self.presentFastColorPicker = presentFastColorPicker
        self.updateFastColorPickerPan = updateFastColorPickerPan
        self.dismissFastColorPicker = dismissFastColorPicker
        self.toggleStyle = toggleStyle
        self.toggleAnimation = toggleAnimation
        self.toggleAlignment = toggleAlignment
        self.presentFontPicker = presentFontPicker
        self.toggleKeyboard = toggleKeyboard
    }
    
    static func ==(lhs: TextSettingsComponent, rhs: TextSettingsComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.animation != rhs.animation {
            return false
        }
        if lhs.alignment != rhs.alignment {
            return false
        }
        if lhs.font != rhs.font {
            return false
        }
        if lhs.isEmojiKeyboard != rhs.isEmojiKeyboard {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        enum ImageKey: Hashable {
            case regular
            case filled
            case semi
            case stroke
            case keyboard
            case emoji
        }
        private var cachedImages: [ImageKey: UIImage] = [:]
        func image(_ key: ImageKey) -> UIImage {
            if let image = self.cachedImages[key] {
                return image
            } else {
                var image: UIImage
                switch key {
                case .regular:
                    image = UIImage(bundleImageName: "Media Editor/TextDefault")!
                case .filled:
                    image = UIImage(bundleImageName: "Media Editor/TextFilled")!
                case .semi:
                    image = UIImage(bundleImageName: "Media Editor/TextSemi")!
                case .stroke:
                    image = UIImage(bundleImageName: "Media Editor/TextStroke")!
                case .keyboard:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/AccessoryIconKeyboard"), color: .white)!
                case .emoji:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/EntityInputEmojiIcon"), color: .white)!
                }
                cachedImages[key] = image
                return image
            }
        }
    }
    
    class View: UIView, ComponentTaggedView {
        var componentTag: AnyObject?
        
        public func matches(tag: Any) -> Bool {
            if let componentTag = self.componentTag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        func animateIn() {
            var delay: Double = 0.0
            for view in self.subviews {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: delay)
                view.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2, delay: delay)
                delay += 0.02
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            var isFirst = true
            for view in self.subviews {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: isFirst ? { _ in
                    completion()
                } : nil)
                view.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                isFirst = false
            }
        }
    }
    
    func makeView() -> View {
        let view = View()
        view.componentTag = self.tag
        return view
    }
    
    func makeState() -> State {
        State()
    }
        
    static var body: Body {
        let colorButton = Child(ColorSwatchComponent.self)
        let colorButtonTag = GenericComponentViewTag()
        
        let alignmentButton = Child(Button.self)
        let styleButton = Child(Button.self)
        let keyboardButton = Child(Button.self)
        let font = Child(TextFontComponent.self)
        
        return { context in
            let component = context.component
            let state = context.state
            
            let toggleStyle = component.toggleStyle
            let toggleAlignment = component.toggleAlignment
            
            var offset: CGFloat = 6.0
            if let color = component.color {
                let presentColorPicker = component.presentColorPicker
                let presentFastColorPicker = component.presentFastColorPicker
                let updateFastColorPickerPan = component.updateFastColorPickerPan
                let dismissFastColorPicker = component.dismissFastColorPicker
                
                let colorButton = colorButton.update(
                    component: ColorSwatchComponent(
                        type: .main,
                        color: color,
                        tag: colorButtonTag,
                        action: {
                            presentColorPicker()
                        },
                        holdAction: {
                            presentFastColorPicker(colorButtonTag)
                        },
                        pan: { point in
                            updateFastColorPickerPan(point)
                        },
                        release: {
                            dismissFastColorPicker()
                        }
                    ),
                    availableSize: CGSize(width: 44.0, height: 44.0),
                    transition: context.transition
                )
                context.add(colorButton
                    .position(CGPoint(x: colorButton.size.width / 2.0 + 2.0, y: context.availableSize.height / 2.0))
                )
                offset += 42.0
            }
                        
            let styleImage: UIImage
            switch component.style {
            case .regular:
                styleImage = state.image(.regular)
            case .filled:
                styleImage = state.image(.filled)
            case .semi:
                styleImage = state.image(.semi)
            case .stroke:
                styleImage = state.image(.stroke)
            }
            
            var fontAvailableWidth: CGFloat = context.availableSize.width
            if component.color != nil {
                fontAvailableWidth -= 72.0
            }
            
            let styleButton = styleButton.update(
                component: Button(
                    content: AnyComponent(
                        Image(
                            image: styleImage
                        )
                    ),
                    action: {
                        toggleStyle()
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .easeInOut(duration: 0.2)
            )
            context.add(styleButton
                .position(CGPoint(x: offset + styleButton.size.width / 2.0, y: context.availableSize.height / 2.0))
                .update(Transition.Update { _, view, transition in
                    if let snapshot = view.snapshotView(afterScreenUpdates: false) {
                        transition.setAlpha(view: snapshot, alpha: 0.0, completion: { [weak snapshot] _ in
                            snapshot?.removeFromSuperview()
                        })
                        snapshot.frame = view.frame
                        transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                        view.superview?.addSubview(snapshot)
                    }
                })
            )
            offset += 44.0
            
            let alignmentButton = alignmentButton.update(
                component: Button(
                    content: AnyComponent(
                        TextAlignmentComponent(
                            alignment: component.alignment
                        )
                    ),
                    action: {
                        toggleAlignment()
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)),
                availableSize: context.availableSize,
                transition: .easeInOut(duration: 0.2)
            )
            context.add(alignmentButton
                .position(CGPoint(x: offset + alignmentButton.size.width / 2.0, y: context.availableSize.height / 2.0 + 1.0 - UIScreenPixel))
            )
            offset += 45.0
            
            if let toggleKeyboard = component.toggleKeyboard {
                let keyboardButton = keyboardButton.update(
                    component: Button(
                        content: AnyComponent(
                            LottieAnimationComponent(
                                animation: LottieAnimationComponent.AnimationItem(name: !component.isEmojiKeyboard ? "input_anim_smileToKey" : "input_anim_keyToSmile" , mode: .animateTransitionFromPrevious),
                                colors: ["__allcolors__": UIColor.white],
                                size: CGSize(width: 32.0, height: 32.0)
                            )
                        ),
                        action: {
                            toggleKeyboard()
                        }
                    ).minSize(CGSize(width: 44.0, height: 44.0)),
                    availableSize: CGSize(width: 32.0, height: 32.0),
                    transition: .easeInOut(duration: 0.15)
                )
                context.add(keyboardButton
                    .position(CGPoint(x: offset + keyboardButton.size.width / 2.0 + (component.isEmojiKeyboard ? 3.0 : 0.0), y: context.availableSize.height / 2.0))
                )
            }
                 
            let font = font.update(
                component: TextFontComponent(
                    selectedValue: component.font,
                    tag: component.fontTag,
                    tapped: {
                        component.presentFontPicker()
                    }
                ),
                availableSize: CGSize(width: fontAvailableWidth, height: 30.0),
                transition: .easeInOut(duration: 0.2)
            )
            context.add(font
                .position(CGPoint(x: context.availableSize.width - font.size.width / 2.0 - 16.0, y: context.availableSize.height / 2.0))
            )
                         
            return context.availableSize
        }
    }
}

private func generateMaskPath(size: CGSize, topRadius: CGFloat, bottomRadius: CGFloat) -> UIBezierPath {
    let path = UIBezierPath()
    path.addArc(withCenter: CGPoint(x: size.width / 2.0, y: topRadius), radius: topRadius, startAngle: .pi, endAngle: 0, clockwise: true)
    path.addArc(withCenter: CGPoint(x: size.width / 2.0, y: size.height - bottomRadius), radius: bottomRadius, startAngle: 0, endAngle: .pi, clockwise: true)
    path.close()
    return path
}

private func generateKnobImage() -> UIImage? {
    let side: CGFloat = 32.0
    let margin: CGFloat = 10.0
    
    let image = generateImage(CGSize(width: side + margin * 2.0, height: side + margin * 2.0), opaque: false, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
                
        context.setShadow(offset: CGSize(width: 0.0, height: 0.0), blur: 9.0, color: UIColor(rgb: 0x000000, alpha: 0.3).cgColor)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: margin, y: margin), size: CGSize(width: side, height: side)))
    })
    return image?.stretchableImage(withLeftCapWidth: Int(margin + side * 0.5), topCapHeight: Int(margin + side * 0.5))
}

final class TextSizeSliderComponent: Component {
    let value: CGFloat
    let tag: AnyObject?
    let updated: (CGFloat) -> Void
    let released: () -> Void
    
    public init(
        value: CGFloat,
        tag: AnyObject?,
        updated: @escaping (CGFloat) -> Void,
        released: @escaping () -> Void
    ) {
        self.value = value
        self.tag = tag
        self.updated = updated
        self.released = released
    }
    
    public static func ==(lhs: TextSizeSliderComponent, rhs: TextSizeSliderComponent) -> Bool {
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    final class View: UIView, UIGestureRecognizerDelegate, ComponentTaggedView {
        private var validSize: CGSize?
        
        private let backgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0x888888, alpha: 0.3))
        private let maskLayer = SimpleShapeLayer()
        
        private let knobContainer = SimpleLayer()
        private let knob = SimpleLayer()
    
        fileprivate var updated: (CGFloat) -> Void = { _ in }
        fileprivate var released: () -> Void = { }
        
        private var component: TextSizeSliderComponent?
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        init() {
            super.init(frame: CGRect())

            self.layer.allowsGroupOpacity = true
            self.isExclusiveTouch = true
            
            let pressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePress(_:)))
            pressGestureRecognizer.minimumPressDuration = 0.01
            pressGestureRecognizer.delegate = self
            self.addGestureRecognizer(pressGestureRecognizer)
            self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:))))
        }
                    
        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        private var isTracking: Bool?
        private var isPanning = false
        private var isPressing = false
        
        @objc func handlePress(_ gestureRecognizer: UILongPressGestureRecognizer) {
            guard self.frame.height > 0.0 else {
                return
            }
            switch gestureRecognizer.state {
            case .began:
                self.isPressing = true
                if let size = self.validSize, let component = self.component {
                    let _ = self.updateLayout(size: size, component: component, transition: .easeInOut(duration: 0.2))
                }
                
                let location = gestureRecognizer.location(in: self).offsetBy(dx: 0.0, dy: -12.0)
                let value = 1.0 - max(0.0, min(1.0, location.y / (self.frame.height - 24.0)))
                self.updated(value)
            case .ended, .cancelled:
                self.isPressing = false
                if let size = self.validSize, let component = self.component {
                    let _ = self.updateLayout(size: size, component: component, transition: .easeInOut(duration: 0.2))
                }
                self.released()
            default:
                break
            }
        }
        
        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard self.frame.height > 0.0 else {
                return
            }
            switch gestureRecognizer.state {
            case .began, .changed:
                self.isPanning = true
                if let size = self.validSize, let component = self.component {
                    let _ = self.updateLayout(size: size, component: component, transition: .easeInOut(duration: 0.2))
                }
                let location = gestureRecognizer.location(in: self).offsetBy(dx: 0.0, dy: -12.0)
                let value = 1.0 - max(0.0, min(1.0, location.y / (self.frame.height - 24.0)))
                self.updated(value)
            case .ended, .cancelled:
                self.isPanning = false
                if let size = self.validSize, let component = self.component {
                    let _ = self.updateLayout(size: size, component: component, transition: .easeInOut(duration: 0.2))
                }
                self.released()
            default:
                break
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func updateLayout(size: CGSize, component: TextSizeSliderComponent, transition: Transition) -> CGSize {
            self.component = component
            
            let previousSize = self.validSize
            self.validSize = size
            
            if self.backgroundNode.view.superview == nil {
                self.addSubview(self.backgroundNode.view)
            }
            if self.knobContainer.superlayer == nil {
                self.layer.addSublayer(self.knobContainer)
            }
            if self.knob.superlayer == nil {
                self.knob.contents = generateKnobImage()?.cgImage
                self.knobContainer.addSublayer(self.knob)
            }
            
            let isTracking = self.isPanning || self.isPressing
            if self.isTracking != isTracking {
                self.isTracking = isTracking
                transition.setSublayerTransform(view: self, transform: isTracking ? CATransform3DMakeTranslation(8.0, 0.0, 0.0) : CATransform3DMakeTranslation(-size.width / 2.0, 0.0, 0.0))
                transition.setSublayerTransform(layer: self.knobContainer, transform: isTracking ? CATransform3DIdentity : CATransform3DMakeTranslation(4.0, 0.0, 0.0))
            }
            
            let knobTransition = self.isPanning ? transition.withAnimation(.none) : transition
            let knobSize = CGSize(width: 52.0, height: 52.0)
            let knobFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - knobSize.width) / 2.0), y: -12.0 + floorToScreenPixels((size.height + 24.0 - knobSize.height) * (1.0 - component.value))), size: knobSize)
            knobTransition.setFrame(layer: self.knob, frame: knobFrame)
            
            transition.setFrame(view: self.backgroundNode.view, frame: CGRect(origin: CGPoint(), size: size))
            self.backgroundNode.update(size: size, transition: transition.containedViewLayoutTransition)
            
            transition.setFrame(layer: self.knobContainer, frame: CGRect(origin: CGPoint(), size: size))
            
            if previousSize != size {
                transition.setFrame(layer: self.maskLayer, frame: CGRect(origin: .zero, size: size))
                self.maskLayer.path = generateMaskPath(size: size, topRadius: 15.0, bottomRadius: 3.0).cgPath
                self.backgroundNode.layer.mask = self.maskLayer
            }
        
            return size
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        view.updated = self.updated
        view.released = self.released
        return view.updateLayout(size: availableSize, component: self, transition: transition)
    }
}
